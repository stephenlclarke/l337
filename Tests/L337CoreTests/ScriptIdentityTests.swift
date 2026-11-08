import Foundation
import Testing

@testable import L337Core

private func identityPack() throws -> ScriptPack {
  try ScriptPackLibrary.read(
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish"))
}
private func identityGame(_ pack: ScriptPack, origin: UUID) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  game.screen = .status
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack, instanceID: origin)
  game.launch()
  return game
}
private func physicalIDs(_ state: ScriptInstance) -> Set<UUID> {
  Set(
    state.ownedEncounters.values.flatMap { cohort in
      cohort.actors.values.flatMap { actor in
        [actor.identity] + (actor.body.scriptNPC?.components.values.map(\.identity) ?? [])
      }
    })
}

@Test func newOwnedPlansPinRootAndComponentIdentitiesWithoutDrawingSimulationRandomness() throws {
  let pack = try identityPack()
  let origin = UUID()
  let base = try identityGame(pack, origin: origin)
  let random = base.scriptSimulationSave.randomState
  var first = base
  var second = base
  var firstState = try #require(first.commander.scriptState.instances[origin])
  var secondState = try #require(second.commander.scriptState.instances[origin])
  let a = try first.ensureScriptEncounter("opponents", pack: pack, state: &firstState)
  let b = try second.ensureScriptEncounter("opponents", pack: pack, state: &secondState)
  #expect(a.0 == "encounter.admitted" && b.0 == "encounter.admitted")
  #expect(firstState.ownedEncounters == secondState.ownedEncounters)
  #expect(physicalIDs(firstState).count == 4)
  #expect(
    first.scriptSimulationSave.randomState == random
      && second.scriptSimulationSave.randomState == random)
  #expect(first.bodies == second.bodies)
}

@Test func separateMissionOriginsCannotAliasIdenticalModelRootsOrComponents() throws {
  let pack = try identityPack()
  let firstID = UUID()
  let secondID = UUID()
  var first = try identityGame(pack, origin: firstID)
  var second = try identityGame(pack, origin: secondID)
  var a = try #require(first.commander.scriptState.instances[firstID])
  var b = try #require(second.commander.scriptState.instances[secondID])
  _ = try first.ensureScriptEncounter("opponents", pack: pack, state: &a)
  _ = try second.ensureScriptEncounter("opponents", pack: pack, state: &b)
  #expect(physicalIDs(a).isDisjoint(with: physicalIDs(b)))
  #expect(physicalIDs(a).count == 4 && physicalIDs(b).count == 4)
}

@Test func currentPreparedPlansKeepCanonicalIdentitiesAndActualDamagedConditionThroughNativeSaves()
  async throws
{
  let pack = try identityPack()
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent("current-plan-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let save = folder.appendingPathComponent("commander.json")
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  // Controlled actor-slot pressure only; these placeholders confer no cargo or material authority.
  game.bodies = [try #require(game.bodies.first { $0.id == 0 })]
  for id in 1..<128 {
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 128
  game.ensurePhysicalActors()
  let coldSeed = game
  var state = try #require(game.commander.scriptState.instances[origin])
  let pending = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  try #require(pending.0 == "encounter.pending")
  let prepared = try #require(state.ownedEncounters["opponents"])
  let identities = physicalIDs(state)
  try #require(identities.count == 4 && !prepared.admitted)
  game.commander.scriptState.instances[origin] = state
  let random = game.scriptSimulationSave.randomState
  try GameRuntime.writeCommander(&game, to: save)
  let bytes = try Data(contentsOf: save)
  let files = try ScriptFinanceTestFixture.files(folder)
  let (stored, world) = try ScriptSaveStore.read(bytes, from: save)
  #expect(stored.valid && world.valid && world.consistent(with: stored))
  #expect(stored.scriptState.instances[origin]?.ownedEncounters["opponents"] == prepared)
  try #require(coldSeed.commander.scriptState.instances[origin]?.ownedEncounters["opponents"] == nil)
  let cold = GameRuntime(game: coldSeed)
  try await cold.load(from: save, persistMigrations: false)
  var restored = await cold.snapshot()
  #expect(restored.commander.scriptState.instances[origin]?.data == state.data)
  #expect(restored.commander.scriptState.instances[origin]?.ownedEncounters["opponents"] == prepared)
  #expect(restored.scriptSimulationSave.randomState == random)
  #expect(try Data(contentsOf: save) == bytes)
  #expect(try ScriptFinanceTestFixture.files(folder) == files)
  restored.bodies.removeAll { $0.hull == .cargo }
  var admittedState = try #require(restored.commander.scriptState.instances[origin])
  let admitted = try restored.ensureScriptEncounter("opponents", pack: pack, state: &admittedState)
  restored.commander.scriptState.instances[origin] = admittedState
  try #require(admitted.0 == "encounter.admitted")
  #expect(physicalIDs(admittedState) == identities && restored.commander.valid)
  #expect(restored.scriptSimulationSave.randomState == random)
  #expect(restored.bodies.filter { $0.missionActorID != nil }.count == 2)
  for (alias, original) in prepared.actors {
    let actual = try #require(admittedState.ownedEncounters["opponents"]?.actors[alias])
    #expect(actual.identity == original.identity && actual.body.energy == original.body.energy)
    #expect(actual.body.scriptNPC?.components == original.body.scriptNPC?.components)
  }
  // Actual player damage must persist; no random identity or spent snapshot is injected.
  let lead = try #require(restored.bodies.first { $0.missionActorID == prepared.actors["lead"]?.identity })
  try #require(lead.position.z > 0 && lead.energy > 0)
  let undamagedSeed = restored
  restored.fireLaser()
  let damaged = try #require(restored.bodies.first { $0.missionActorID == lead.missionActorID })
  try #require(damaged.energy > 0 && damaged.energy < lead.energy)
  let damagedRuntime = GameRuntime(game: restored)
  try await damagedRuntime.save(to: save)
  let finalRuntime = GameRuntime(game: undamagedSeed)
  try await finalRuntime.load(from: save, persistMigrations: false)
  let final = await finalRuntime.snapshot()
  let finalState = try #require(final.commander.scriptState.instances[origin])
  #expect(physicalIDs(finalState) == identities && final.commander.valid)
  #expect(finalState.ownedEncounters["opponents"]?.actors["lead"]?.body.energy == damaged.energy)
  #expect(final.bodies.first { $0.missionActorID == lead.missionActorID }?.energy == damaged.energy)
  #expect(finalState.data == state.data)
}

@Test(arguments: 0..<4)
func currentPreparedPlansStillRejectRandomIdentitiesAndSpentConditionWithoutMigration(change: Int)
  throws
{
  let pack = try identityPack()
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  game.bodies = [try #require(game.bodies.first { $0.id == 0 })]
  for id in 1..<128 {
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 128
  game.ensurePhysicalActors()
  var state = try #require(game.commander.scriptState.instances[origin])
  let pending = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  try #require(pending.0 == "encounter.pending")
  var encounter = try #require(state.ownedEncounters["opponents"])
  var actor = try #require(encounter.actors["lead"])
  if change == 0 {
    let identity = UUID()
    actor.body.missionActorID = identity
    actor = .init(
      identity: identity, alias: actor.alias, body: actor.body, presence: actor.presence)
  } else if change == 1 {
    let part = try #require(actor.body.scriptNPC?.components.keys.first)
    let old = try #require(actor.body.scriptNPC?.components[part])
    actor.body.scriptNPC?.components[part] = .init(
      identity: UUID(), energy: old.energy, guns: old.guns)
  } else if change == 2 {
    actor.body.energy = 41
  } else {
    let part = try #require(actor.body.scriptNPC?.components.keys.first)
    actor.body.scriptNPC?.components[part]?.energy = 16
  }
  encounter.actors["lead"] = actor
  state.ownedEncounters["opponents"] = encounter
  game.commander.scriptState.instances[origin] = state
  game.bodies.removeAll { $0.hull == .cargo }
  let beforeCommander = game.commander
  let beforeBodies = game.bodies
  let beforeNext = game.nextBodyID
  let beforeState = state
  #expect(throws: (any Error).self) {
    _ = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  }
  #expect(game.commander == beforeCommander && game.bodies == beforeBodies)
  #expect(game.nextBodyID == beforeNext && state == beforeState)
}


@Test(arguments: ["unknown", "null-unknown", "oversized-actors", "missing-id"])
func currentEncounterDecoderRejectsUnrecognizedFieldsAndBoundsActorsBeforeChildren(condition: String) throws {
  let pack = try identityPack()
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  var state = try #require(game.commander.scriptState.instances[origin])
  let admission = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  try #require(admission.0 == "encounter.admitted")
  let encounter = try #require(state.ownedEncounters["opponents"])
  let bytes = try JSONEncoder().encode(encounter)
  try #require(try JSONDecoder().decode(ScriptOwnedEncounter.self, from: bytes) == encounter)
  var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  switch condition {
  case "unknown": object["unrecognizedAdmissionReceipt"] = 1
  case "null-unknown": object["unrecognizedAdmissionReceipt"] = NSNull()
  case "oversized-actors":
    object["actors"] = Dictionary(uniqueKeysWithValues: (0..<129).map { ("actor\($0)", NSNull()) })
  case "missing-id": object.removeValue(forKey: "id")
  default:
    Issue.record("Unknown current encounter schema condition")
    return
  }
  let malformed = try JSONSerialization.data(withJSONObject: object)
  if condition == "oversized-actors" {
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(ScriptOwnedEncounter.self, from: malformed)
    }
  } else {
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(ScriptOwnedEncounter.self, from: malformed)
    }
  }
  #expect(try JSONDecoder().decode(ScriptOwnedEncounter.self, from: bytes) == encounter)
}
