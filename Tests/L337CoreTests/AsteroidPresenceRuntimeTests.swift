import Foundation
import Testing

@testable import L337Core

private func currentPresenceSystem() throws -> StarSystem {
  try #require(
    Universe.galaxy().first { system in
      AsteroidBeltDefinition.isPresent(system: system, galaxy: 0, policy: .economyWeighted)
    })
}
struct AsteroidPresenceRuntimeTests {
  @Test func nativeSceneAndMinerPlannerShareCurrentResolvedAbsence() throws {
    var game = Game(executive: false)
    game.commander.system = try #require(
      game.systems.first {
        $0.government == 7 && !MiningLedger().ringPresence(system: $0, galaxy: 0)
      }?.id)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.miningFields.isEmpty)
    game.bodies = [.init(id: 80, hull: .cobra, position: .init(0, 0, 5000))]
    game.nextBodyID = 81
    game.ensurePhysicalActors()
    game.bodies[0].physical?.npc?.role = .miner
    let actor = try #require(game.bodies[0].physical?.identity)
    let context = try #require(game.gameplayContext())
    #expect(context.miningPresence == .init(ringPresent: false, includingLegacy: false))
    let idle = try #require(TrafficIntent.intents(context: context).first { $0.actor == actor })
    #expect(idle.action == .navigate(position: context.actors[0].position, speedUnitsPerSecond: 0))
  }

  @Test func firstStationSavePersistsFreshWeightedPolicyInsteadOfBecomingLegacyOnReload()
    async throws
  {
    var game = Game(executive: false)
    game.commander.system = try currentPresenceSystem().id
    try game.commander.prepareEquipment(legacy: false)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(pointer.schemaVersion == 26)
    let loaded = GameRuntime()
    try await loaded.load(from: file)
    let restored = await loaded.snapshot()
    #expect(restored.commander.miningLedger.usesEconomyWeightedPresence)
    #expect(
      restored.resolvedMiningPresence.ringPresent
        && !restored.resolvedMiningPresence.includingLegacy)
  }

  @Test func futurePresenceKeysRejectNullAndOlderHeadersBeforeAnyMiningStateCanDisappear() throws {
    for key in ["legacyClusters", "presenceOverrides"] {
      let bytes = try JSONSerialization.data(withJSONObject: ["savedMiningLedger": [key: NSNull()]])
      #expect(throws: SaveError.self) { try EconomyMiningVersionedSave.rejectFields(bytes) }
      var object = try #require(
        JSONSerialization.jsonObject(
          with: JSONEncoder().encode(MiningLedger())) as? [String: Any])
      object[key] = NSNull()
      let poisoned = try JSONSerialization.data(withJSONObject: object)
      #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(MiningLedger.self, from: poisoned)
      }
    }
    let generation = try JSONSerialization.data(withJSONObject: [
      "savedMiningLedger": ["generation": 2]
    ])
    #expect(throws: SaveError.self) { try EconomyMiningVersionedSave.rejectFields(generation) }
  }
}
