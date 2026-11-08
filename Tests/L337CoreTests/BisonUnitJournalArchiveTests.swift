import Foundation
import Testing

@testable import L337Core

/// Logical reservations are obtained through the existing unpublished fixture.
/// Qualified Bison admission stays closed; no test claims physical birth or stock.
struct BisonUnitJournalArchiveTests {
  @Test
  func actualRuntimeSaveAndFreshLoadPreserveOnlyPendingJournal() async throws {
    let (game, request, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let saved = await runtime.snapshot()
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let checkpoint = try #require(pointer.bisonUnitJournalCheckpoint)
    let (header, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(world.bisonUnitJournalCheckpoint == checkpoint)
    #expect(header.savedBisonUnitAllocations == saved.commander.savedBisonUnitAllocations)
    let fresh = GameRuntime(game: Game(executive: false))
    try await fresh.load(from: url, persistMigrations: false)
    let restored = await fresh.snapshot()
    let journal = try #require(restored.commander.savedBisonUnitAllocations)
    #expect(try journal.owner(for: request, in: restored) == owner)
    #expect(journal == saved.commander.savedBisonUnitAllocations)
    #expect(BisonUnitJournalSave.sceneIsConsistent(restored.bodies, commander: restored.commander))
    #expect(!restored.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(owner.units.allSatisfy { $0.operative == .unobserved && $0.physicalRoster == .unobserved })
    #expect(CurrentNewtKitSource.bison?.sourceQualifiedForBirth == false)
  }

  @Test(arguments: ["missing-journal", "missing-pointer", "missing-world", "foreign-journal", "changed-binding",
    "unknown-journal-field", "misplaced-journal", "null-journal", "null-marker", "duplicate-journal", "truncated-chunk", "raw-header", "escaped-misplaced", "unknown-marker", "misplaced-marker"])
  func actualColdLoadRejectsMissingForgedAndPartialArchiveWithoutPublication(fault: String) async throws {
    let (game, _, _, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let before = await runtime.snapshot()
    let originalPointer = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let commanderURL = directory.appendingPathComponent("commander.json")
    let worldURL = directory.appendingPathComponent("world.json")
    let commanderInput = try Data(contentsOf: commanderURL)
    let decodedCommander = try JSONSerialization.jsonObject(with: commanderInput)
    var commander = try #require(decodedCommander as? [String: Any])
    let worldInput = try Data(contentsOf: worldURL)
    let decodedWorld = try JSONSerialization.jsonObject(with: worldInput)
    var world = try #require(decodedWorld as? [String: Any])
    let decodedPointer = try JSONSerialization.jsonObject(with: originalPointer)
    var published = try #require(decodedPointer as? [String: Any])
    let originalJournal = try #require(commander[BisonUnitJournalSave.journalField] as? [String: Any])
    switch fault {
    case "missing-journal": commander.removeValue(forKey: BisonUnitJournalSave.journalField)
    case "missing-pointer": published.removeValue(forKey: BisonUnitJournalSave.checkpointField)
    case "missing-world": world.removeValue(forKey: BisonUnitJournalSave.checkpointField)
    case "foreign-journal":
      let (_, _, _, _, foreign) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
      commander[BisonUnitJournalSave.journalField] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(foreign))
    case "changed-binding":
      var marker = try #require(published[BisonUnitJournalSave.checkpointField] as? [String: Any])
      marker["checkpointSHA256"] = String(repeating: "0", count: 64)
      published[BisonUnitJournalSave.checkpointField] = marker
    case "unknown-journal-field":
      var journal = originalJournal
      journal["qualifiedBirth"] = true
      commander[BisonUnitJournalSave.journalField] = journal
    case "misplaced-journal": world["forged"] = [BisonUnitJournalSave.journalField: originalJournal]
    case "null-journal": commander[BisonUnitJournalSave.journalField] = NSNull()
    case "null-marker": published[BisonUnitJournalSave.checkpointField] = NSNull()
    case "unknown-marker":
      var marker = try #require(published[BisonUnitJournalSave.checkpointField] as? [String: Any])
      marker["operative"] = true
      published[BisonUnitJournalSave.checkpointField] = marker
    case "misplaced-marker": commander[BisonUnitJournalSave.checkpointField] = published[BisonUnitJournalSave.checkpointField]
    case "duplicate-journal", "truncated-chunk", "raw-header", "escaped-misplaced": break
    default: Issue.record("Unknown archive negative control"); return
    }
    var commanderBytes = try JSONSerialization.data(withJSONObject: commander)
    if fault == "duplicate-journal" {
      let journalBytes = try JSONSerialization.data(withJSONObject: originalJournal)
      let leaf = try #require(String(data: journalBytes, encoding: .utf8))
      let header = try #require(String(data: commanderBytes, encoding: .utf8))
      commanderBytes = Data(("{\"savedBisonUnitAllocations\":" + leaf + "," + header.dropFirst()).utf8)
    } else if fault == "truncated-chunk" {
      commanderBytes = Data(commanderBytes.prefix(commanderBytes.count / 2))
    }
    var worldBytes = try JSONSerialization.data(withJSONObject: world)
    if fault == "escaped-misplaced" {
      let journalBytes = try JSONSerialization.data(withJSONObject: originalJournal)
      let leaf = try #require(String(data: journalBytes, encoding: .utf8))
      let originalWorld = try #require(String(data: worldBytes, encoding: .utf8))
      worldBytes = Data(("{\"savedBisonUnit\\u0041llocations\":" + leaf + "," + originalWorld.dropFirst()).utf8)
    }
    try commanderBytes.write(to: commanderURL)
    try worldBytes.write(to: worldURL)
    var hashes = try #require(published["hashes"] as? [String: String])
    hashes["commander.json"] = ScriptPackLibrary.hash(commanderBytes)
    hashes["world.json"] = ScriptPackLibrary.hash(worldBytes)
    published["hashes"] = hashes
    let input = fault == "raw-header" ? commanderBytes : try JSONSerialization.data(withJSONObject: published)
    try input.write(to: url)
    var refused = false
    do { try await runtime.load(from: url, persistMigrations: false) } catch { refused = true }
    let after = await runtime.snapshot()
    #expect(refused && after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch && after.ecmControl.epoch == before.ecmControl.epoch)
    #expect(try Data(contentsOf: url) == input)
    #expect(try Data(contentsOf: commanderURL) == commanderBytes)
    #expect(try Data(contentsOf: worldURL) == worldBytes)
  }

  @Test(arguments: ["actor", "spawn", "emp-source", "pod-source"])
  func pendingReservationRejectsActualWorldAliasesBeforeSave(fault: String) throws {
    let (game, _, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var world = game.scriptWorldSave
    let other = try #require(game.commander.flightSimulation.anchors?.station.identity)
    var body = SpaceBody(id: world.nextBodyID, hull: .cargo, position: .init(1000, 0, 0))
    body.physical = .init(identity: fault == "actor" ? owner.birthActor : other, population: .cargo,
      velocity: .init(0, 0, 0), spawnIdentity: fault == "spawn" ? owner.birthSpawn : nil)
    if fault == "emp-source" { body.physical?.empSource = owner.birthActor }
    if fault == "pod-source" { body.physical?.empCrewPod = .init(source: owner.birthActor, ordinal: 7) }
    world.bodies.append(body)
    world.nextBodyID += 1
    #expect(!BisonUnitJournalSave.sceneIsConsistent(world.bodies, commander: game.commander))
    #expect(throws: SaveError.invalidCommander) {
      try BisonUnitJournalSave.preparedWorld(world, commander: game.commander)
    }
  }

  @Test(arguments: ["bound", "unbound", "terminal"])
  func completeNPCCensusRejectsReservationHiddenOutsideLiveWorld(state: String) throws {
    let (initialGame, _, owner, context, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
    npc.resources = NPCResources.stock(source.performance)
    var body = SpaceBody(id: game.nextBodyID, hull: .cobra, position: .init(1000, 0, 0))
    body.energy = source.performance.energy
    body.missiles = source.performance.missiles
    body.physical = .init(identity: owner.birthActor, population: .civilian, npc: npc,
      velocity: .init(0, 0, 0), catalogueShipID: "SH029")
    // Negative custody input only: this snapshot is not a physical Bison birth.
    // The actual NPC owner accepts its own typed SH029 snapshot, then the Bison
    // cross-owner check must detect its reserved actor even without a live body.
    let snapshot = try #require(NPCPersistenceSnapshot.capture(body: body,
      pose: game.commander.flightSimulation.pose, physicalTime: context.physicalTime, protection: context.protection))
    var ledger = NPCPersistenceLedger()
    let registered = ledger.capture(snapshot, protection: context.protection)
    #expect(registered == .registered(owner.birthActor))
    if state == "unbound" { ledger.cull(actor: owner.birthActor) }
    if state == "terminal" {
      let terminal = ledger.terminal(actor: owner.birthActor, reason: .expired)
      #expect(terminal)
    }
    game.commander.npcPersistence = ledger
    #expect(ledger.valid && !game.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(ledger.conflictsWithUnpublishedBison(actors: [owner.birthActor], spawns: [owner.birthSpawn]))
    #expect(!BisonUnitJournalSave.sceneIsConsistent(game.bodies, commander: game.commander))
  }

  @Test
  func savePreparationRejectsJournalLossBeforeAnyPublisher() throws {
    let (game, _, _, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var candidate = game
    candidate.commander.savedBisonUnitAllocations = nil
    #expect(throws: SaveError.invalidCommander) {
      try BisonUnitJournalSave.validatePreservation(from: game, to: candidate)
    }
    var raw = game
    let before = raw
    let loaded = raw.load(game.commander)
    #expect(!loaded)
    #expect(raw.commander == before.commander && raw.bodies == before.bodies)
  }

  @Test
  func exclusivePointerFailureLeavesWrittenGenerationUnpublishedAndLiveJournalUnchanged() async throws {
    let (game, _, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("original.json")
    let raced = folder.appendingPathComponent("registered.json")
    let originalRuntime = GameRuntime(game: game)
    try await originalRuntime.save(to: original)
    let originalPointer = try Data(contentsOf: original)
    let oldPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: raced)
    // A genuine other publication wins the registered path before first write.
    // Copy its complete archive under this path, preserving the old pointer.
    try FileManager.default.copyItem(at: original.appendingPathExtension("missions"),
      to: raced.appendingPathExtension("missions"))
    try originalPointer.write(to: raced)
    let before = await runtime.snapshot()
    let generationsBefore = try FileManager.default.contentsOfDirectory(atPath: raced.appendingPathExtension("missions").path)
    var refused = false
    do { try await runtime.save(to: raced) } catch { refused = true }
    let after = await runtime.snapshot()
    #expect(refused && after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.pendingNewSaveDestination == before.pendingNewSaveDestination)
    #expect(try Data(contentsOf: raced) == originalPointer)
    let generationsAfter = try FileManager.default.contentsOfDirectory(atPath: raced.appendingPathExtension("missions").path)
    let unpublished = Set(generationsAfter).subtracting(generationsBefore)
    #expect(unpublished.count == 1 && unpublished.first != oldPointer.generation)
    for name in unpublished {
      let directory = raced.appendingPathExtension("missions").appendingPathComponent(name)
      for chunk in ["commander.json", "world.json", "missions.json", "contracts.json"] {
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(chunk).path))
      }
    }
    let (header, world) = try ScriptSaveStore.read(originalPointer, from: raced)
    #expect(header.savedBisonUnitAllocations == game.commander.savedBisonUnitAllocations)
    #expect(!world.bodies.contains { $0.physical?.identity == owner.birthActor })
    let receipt = await runtime.takeNewCommanderSaveReceipt()
    #expect(receipt == nil)
  }
}
