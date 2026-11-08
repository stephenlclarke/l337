import Foundation
import Testing

@testable import L337Core

/// Controlled remote scenes, NOT fuel-paid/flown routes. Actual bootstrap, native visits,
/// original station observations and final swept berth use their real producers. No saved
/// observation, dock, clock, commission, witness or item is injected. UNRUN.
private final class BorrowedVoiceOpeningFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime

  init(priorSystems: Int = 4) async throws {
    let storage = try ScriptFreightFixture()
    files = storage
    var ready = false
    defer { if !ready { storage.clean() } }
    try FileManager.default.createDirectory(
      at: storage.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: storage.save)
    try #require(await boot.snapshot().nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledBorrowedVoiceDirectory)]
    for index in 0..<priorSystems {
      // Any actual distinct systems suffice. Prior stations need no docking receipt.
      game = try Self.observeNativeScene(game, world: .init(galaxy: 2, system: 21 + index))
    }
    game = try Self.observeNativeScene(game, world: NativeBorrowedVoiceDefinition.issuer)
    let station = try #require(game.bodies.first { $0.id == 0 })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    runtime = GameRuntime(game: game, saveURL: storage.save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.systemIdentity == NativeBorrowedVoiceDefinition.issuer)
    try #require(arrived.commander.scriptState.firstNativeCommodityTrade == nil)
    try await runtime.save(to: storage.save)
    ready = true
  }

  private static func observeNativeScene(_ original: Game, world: SystemIdentity) throws -> Game {
    var game = original
    game.persistScriptActors(unloading: true)
    try game.departOrdinarySimulation()
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.speed = 0
    game.screen = .front
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let worldState = try #require(game.commander.nativeStations)
    try #require(worldState.mainObservations.contains {
      $0.station.system == world && $0.actor.visit == game.commander.flightSimulation.visit
    })
    return game
  }

  func clean() { files.clean() }

  func review(_ action: NativeBorrowedVoiceAction) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.borrowedVoice == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.borrowedVoice == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.borrowedVoiceQuote?.action == action)
    return detail
  }

  func confirm() async throws -> Game {
    let detail = try await review(.accept)
    try #require(detail.contractBoard.borrowedVoiceQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    _ = try #require(result.borrowedVoiceMission?.savedBorrowedVoice)
    return result
  }

  func revisit(_ world: SystemIdentity) async throws -> GameRuntime {
    await runtime.nativeCommand { $0.screen = .status }
    await runtime.key("0")
    let launched = await runtime.snapshot()
    try #require(!launched.docked)
    let game = try Self.observeNativeScene(launched, world: world)
    let next = GameRuntime(game: game, saveURL: files.save)
    try await next.save(to: files.save)
    return next
  }
}

struct NativeBorrowedVoiceOpeningUnitTests {
  @Test func fiveRealNativeObservationsAcceptWithoutTradeAndSurviveCurrentColdLoad() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    let quote = try #require(preview.contractBoard.borrowedVoiceQuote)
    try #require(quote.allowed)
    let pack = try #require(preview.borrowedVoicePack)
    #expect(NativeBorrowedVoiceDefinition.matches(pack))
    let bundled = ScriptPackLibrary.defaultLibrary(
      directory: fixture.files.root.appendingPathComponent("empty-user-packs"))
    #expect(bundled.packs.filter(NativeBorrowedVoiceDefinition.matches).count == 1)
    #expect(Display.contractDetailRows(preview, width: preview.viewportWidth)
      .joined(separator: " ").contains("five different visited systems"))
    let history = try #require(quote.observations)
    #expect(history.count == 5 && Set(history.map { $0.station.system }).count == 5)
    #expect(preview.commander.scriptState.firstNativeCommodityTrade == nil)
    let world = try #require(preview.commander.nativeStations)
    #expect(history.allSatisfy { world.mainObservations.contains($0) })
    let accepted = try await fixture.confirm()
    let instance = try #require(accepted.borrowedVoiceMission)
    let state = try #require(instance.savedBorrowedVoice)
    #expect(state.acceptance.visited == history)
    #expect(instance.milestones == [0] && instance.receipts == [NativeBorrowedVoiceDefinition.acceptReceipt])
    #expect(instance.journal == NativeBorrowedVoiceDefinition.briefing && instance.gearIssues.isEmpty)
    #expect(instance.outcome == .active && instance.completionReceipt == nil)
    #expect(accepted.commander.equipmentInventory == preview.commander.equipmentInventory)
    #expect(accepted.commander.credits == preview.commander.credits && accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.nativePeople == preview.commander.nativePeople)
    #expect(accepted.commander.flightSimulation == preview.commander.flightSimulation)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativeBorrowedVoiceVerifierDefinition.occupiedTonnes(in: accepted.commander.equipmentInventory) == 0)
    #expect(NativeBorrowedVoiceSave.validateClaims(accepted.commander))
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.scriptState.instances[instance.id]?.savedBorrowedVoice == state)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.borrowedVoiceMission?.savedBorrowedVoice == state)
    #expect(loaded.nativeStationRuntimeEpoch != accepted.nativeStationRuntimeEpoch)
    #expect(!loaded.borrowedVoiceReview(.accept).allowed)
    #expect(NativeBorrowedVoiceSave.validateClaims(loaded.commander))
  }

  @Test func insufficientNativeHistoryBackAndStaleEpochCannotCommissionTheCase() async throws {
    let short = try await BorrowedVoiceOpeningFixture(priorSystems: 0)
    defer { short.clean() }
    let blocked = try await short.review(.accept)
    let refusal = try #require(blocked.contractBoard.borrowedVoiceQuote)
    #expect(!refusal.allowed && refusal.observations == nil)
    #expect(refusal.issues.contains { $0.contains("Five distinct") })
    let bytes = try Data(contentsOf: short.files.save)
    await short.runtime.key("escape")
    #expect(await short.runtime.snapshot().commander == blocked.commander)
    #expect(try Data(contentsOf: short.files.save) == bytes)
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.borrowedVoiceQuote)
    try #require(quote.allowed)
    var stale = chosen
    stale.nativeStationRuntimeEpoch = UUID() // Negative transient change, no positive source.
    #expect(throws: MissionPackError.self) { try stale.confirmBorrowedVoice(quote) }
    #expect(stale.commander == chosen.commander && stale.borrowedVoiceMission == nil)
    var wrongWorld = chosen
    wrongWorld.commander.system = 137
    #expect(throws: MissionPackError.self) { try wrongWorld.confirmBorrowedVoice(quote) }
    #expect(wrongWorld.borrowedVoiceMission == nil)
    #expect(chosen.borrowedVoiceMission == nil)
  }

  @Test func realWriterRefusalAndRetryCommitOnlyOneOriginalCommission() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let before = await fixture.runtime.snapshot()
    let quote = try #require(before.contractBoard.borrowedVoiceQuote)
    try #require(quote.allowed)
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let parked = try fixture.files.blockWrites("borrowed-voice-accept")
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.scriptCommand { candidate in
        do { try candidate.confirmBorrowedVoice(quote) }
        catch { Issue.record(error); throw error } // Producer failure is not writer-refusal proof.
      }
    }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == before.commander && refused.borrowedVoiceMission == nil)
    #expect(try ScriptFinanceTestFixture.files(parked) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(parked, files: files)
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    #expect(accepted.borrowedVoiceMission?.milestones == [0])
    #expect(accepted.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(accepted.commander.nativePeople == before.commander.nativePeople)
    var repeated = before
    repeated.commander = accepted.commander
    #expect(throws: MissionPackError.self) { try repeated.confirmBorrowedVoice(quote) }
    #expect(repeated.commander == accepted.commander)
  }

  @Test func laterNativeRevisitPreservesTheBoundedHistoricalAcceptance() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm()
    let state = try #require(accepted.borrowedVoiceMission?.savedBorrowedVoice)
    let observation = try #require(state.acceptance.visited.first {
      $0.station.system != NativeBorrowedVoiceDefinition.issuer
    })
    let next = try await fixture.revisit(observation.station.system)
    let revisited = await next.snapshot()
    let current = try #require(revisited.commander.nativeStations?.mainObservations.first {
      $0.station == observation.station
    })
    #expect(current.actor.visit > observation.actor.visit)
    #expect(revisited.borrowedVoiceMission?.savedBorrowedVoice == state)
    #expect(NativeBorrowedVoiceSave.validateClaims(revisited.commander))
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.scriptState.instances[state.acceptance.mission]?.savedBorrowedVoice == state)
    #expect(NativeBorrowedVoiceSave.validateClaims(cold))
  }

  @Test func genericEffectsReplayedJournalAndForeignPackCannotCreateWitnessesOrFee() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.borrowedVoicePack)
    let before = game.commander
    #expect(game.borrowedVoiceGalleryEntry(fixture.files.pack) == nil)
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.borrowedVoiceMission == nil)
    #expect(throws: MissionPackError.self) {
      _ = try game.makeScriptTrial(packDigest: pack.digest, seed: 1)
    }
    #expect(game.commander == before && game.borrowedVoiceMission == nil)
    let accepted = try await fixture.confirm()
    let instance = try #require(accepted.borrowedVoiceMission)
    let state = try #require(instance.savedBorrowedVoice)
    let replay = ScriptEvent(sequence: state.acceptance.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(1)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(72000)]),
      .object(["op": .string("payload.add"), "id": .string("false-verifier"), "key": .string("independent-verifier"), "amount": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeBorrowedVoiceDefinition.briefing[0])]),
    ]
    for command in commands {
      let fields = try #require(command.object)
      // Check this mission boundary itself, then the shared route below.
      #expect(throws: MissionPackError.self) {
        try accepted.validateBorrowedVoiceScriptCommand(fields, event: replay, pack: pack,
          state: instance, candidate: accepted.commander)
      }
      var selected = instance
      var candidate = accepted.commander
      #expect(throws: (any Error).self) {
        try accepted.applyScriptCommand(command, event: replay, pack: pack,
          state: &selected, candidate: &candidate)
      }
      #expect(selected == instance && candidate == accepted.commander)
    }
    let foreignCommand = ScriptValue.object([
      "op": .string("journal.append"), "text": .string(NativeBorrowedVoiceDefinition.briefing[0]),
    ])
    let foreignFields = try #require(foreignCommand.object)
    #expect(throws: MissionPackError.self) {
      try accepted.validateBorrowedVoiceScriptCommand(foreignFields, event: replay,
        pack: fixture.files.pack, state: instance, candidate: accepted.commander)
    }
    var foreignState = instance
    var foreignCandidate = accepted.commander
    #expect(throws: (any Error).self) {
      try accepted.applyScriptCommand(foreignCommand, event: replay, pack: fixture.files.pack,
        state: &foreignState, candidate: &foreignCandidate)
    }
    #expect(foreignState == instance && foreignCandidate == accepted.commander)

  }

  @Test func currentRawLeafBoundsHistoryAndGalleryKeepsAllNinePhysicalStagesUnavailable() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm()
    let instance = try #require(accepted.borrowedVoiceMission)
    let value = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(instance)) as? [String: Any])
    func archive(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: value]])
    }
    try NativeBorrowedVoiceSave.validateFields(try archive(value), part: .missions)
    var missing = value
    missing.removeValue(forKey: NativeBorrowedVoiceSave.field)
    var shortHistory = value
    var leaf = try #require(value[NativeBorrowedVoiceSave.field] as? [String: Any])
    var facts = try #require(leaf["acceptance"] as? [String: Any])
    let observations = try #require(facts["visited"] as? [Any])
    facts["visited"] = Array(observations.prefix(4)) // Negative-only deletion from real history.
    leaf["acceptance"] = facts
    shortHistory[NativeBorrowedVoiceSave.field] = leaf
    var inventedReception = value
    var inventedLeaf = try #require(value[NativeBorrowedVoiceSave.field] as? [String: Any])
    var inventedFacts = try #require(inventedLeaf["acceptance"] as? [String: Any])
    inventedFacts["witnessReceived"] = true
    inventedLeaf["acceptance"] = inventedFacts
    inventedReception[NativeBorrowedVoiceSave.field] = inventedLeaf
    for broken in [missing, shortHistory, inventedReception] {
      #expect(throws: (any Error).self) { try NativeBorrowedVoiceSave.validateFields(try archive(broken), part: .missions) }
    }
    var falseProgress = accepted.commander
    falseProgress.scriptState.instances[instance.id]?.milestones.insert(1)
    #expect(!NativeBorrowedVoiceSave.validateClaims(falseProgress))
    let pack = try #require(accepted.borrowedVoicePack)
    let entry = try #require(accepted.borrowedVoiceGalleryEntry(pack))
    #expect(entry.status == .locked && entry.completed == 1 && entry.trialDigest == nil)
    #expect(entry.milestones.count == 10 && entry.milestones.first?.state == "Complete")
    #expect(entry.milestones.dropFirst().allSatisfy { $0.state == "Unavailable" })
    #expect(accepted.scriptGallery.filter { $0.name == "The Borrowed Voice" }.count == 1)
    var missingPack = accepted
    missingPack.scriptPacks = []
    let unavailable = try #require(missingPack.borrowedVoiceMissingGalleryEntry(instance))
    #expect(unavailable.status == .locked && unavailable.completed == 1 && unavailable.trialDigest == nil)
    #expect(missingPack.commander == accepted.commander)
    let filesBeforeLoad = try ScriptFinanceTestFixture.files(fixture.files.root)
    let withoutContent = GameRuntime(game: missingPack, saveURL: fixture.files.save)
    try await withoutContent.load(from: fixture.files.save, persistMigrations: false)
    let reloadedMissing = await withoutContent.snapshot()
    let retained = try #require(reloadedMissing.borrowedVoiceMission)
    #expect(retained.savedBorrowedVoice == instance.savedBorrowedVoice)
    #expect(retained.milestones == [0] && retained.payloads.isEmpty && retained.gearIssues.isEmpty)
    #expect(retained.suspension != nil && retained.journal == NativeBorrowedVoiceDefinition.briefing)
    #expect(NativeBorrowedVoiceSave.validateClaims(reloadedMissing.commander))
    let retainedEntry = try #require(reloadedMissing.borrowedVoiceMissingGalleryEntry(retained))
    #expect(retainedEntry.completed == 1 && retainedEntry.trialDigest == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == filesBeforeLoad)
  }
  @Test func actualAcceptedLeafCopiesEncodeAndCompareWithoutMutatingTheOriginal() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm()
    let instance = try #require(accepted.borrowedVoiceMission)
    let saved = try #require(instance.savedBorrowedVoice)
    var detached = instance
    detached.savedBorrowedVoice = nil
    #expect(detached != instance && instance.savedBorrowedVoice == saved)
    var copied = accepted.commander
    copied.scriptState.instances[instance.id]?.savedBorrowedVoice = nil
    #expect(copied != accepted.commander)
    #expect(accepted.commander.scriptState.instances[instance.id]?.savedBorrowedVoice == saved)
    #expect(!NativeBorrowedVoiceSave.validateClaims(copied))
    let encoded = try JSONEncoder().encode(instance)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: encoded)
    #expect(decoded == instance && decoded.savedBorrowedVoice == saved)
    #expect(NativeBorrowedVoiceSave.validateClaims(accepted.commander))
  }

  @Test func rehashedCurrentArchiveClaimsRefuseThroughTheActualLoaderWithoutChangingLiveStateOrFiles() async throws {
    let fixture = try await BorrowedVoiceOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm()
    let instance = try #require(accepted.borrowedVoiceMission)
    let originalPointer = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let missionsURL = directory.appendingPathComponent("missions.json")
    let originalMissions = try Data(contentsOf: missionsURL)
    let root = try #require(JSONSerialization.jsonObject(with: originalMissions) as? [String: Any])
    // Valid current archive control: negative loads must reach the C04 gate, not a broken baseline.
    let control = try ScriptSaveStore.read(originalPointer, from: fixture.files.save).0
    try #require(control.scriptState.instances[instance.id]?.savedBorrowedVoice != nil)
    defer {
      try? originalMissions.write(to: missionsURL, options: .atomic)
      try? originalPointer.write(to: fixture.files.save, options: .atomic)
    }
    func corrupted(_ change: (inout [String: Any]) throws -> Void) throws -> Data {
      var next = root
      if var entries = next["instances"] as? [String: Any] {
        var value = try #require(entries[instance.id.uuidString] as? [String: Any])
        try change(&value)
        entries[instance.id.uuidString] = value
        next["instances"] = entries
      } else {
        var pairs = try #require(next["instances"] as? [Any])
        let slot = try #require(stride(from: 0, to: pairs.count, by: 2).first {
          pairs[$0] as? String == instance.id.uuidString
        })
        var value = try #require(pairs[slot + 1] as? [String: Any])
        try change(&value)
        pairs[slot + 1] = value
        next["instances"] = pairs
      }
      return try JSONSerialization.data(withJSONObject: next)
    }
    let missing = try corrupted { _ = $0.removeValue(forKey: NativeBorrowedVoiceSave.field) }
    let nested = try corrupted { value in
      var leaf = try #require(value[NativeBorrowedVoiceSave.field] as? [String: Any])
      var opening = try #require(leaf["acceptance"] as? [String: Any])
      opening["witnessReceived"] = true
      leaf["acceptance"] = opening
      value[NativeBorrowedVoiceSave.field] = leaf
    }
    let originalText = try #require(String(data: originalMissions, encoding: .utf8))
    let key = "\"savedBorrowedVoice\":"
    let keyRange = try #require(originalText.range(of: key))
    var duplicateText = originalText
    duplicateText.replaceSubrange(keyRange, with: key + "null," + key)
    let shortHistory = try corrupted { value in
      var leaf = try #require(value[NativeBorrowedVoiceSave.field] as? [String: Any])
      var facts = try #require(leaf["acceptance"] as? [String: Any])
      let visits = try #require(facts["visited"] as? [Any])
      facts["visited"] = Array(visits.prefix(4))
      leaf["acceptance"] = facts
      value[NativeBorrowedVoiceSave.field] = leaf
    }
    let corruptions = [missing, nested, shortHistory, Data(duplicateText.utf8)]
    for bytes in corruptions {
      try bytes.write(to: missionsURL, options: .atomic)
      var hashRoot = try #require(JSONSerialization.jsonObject(with: originalPointer) as? [String: Any])
      var hashes = try #require(hashRoot["hashes"] as? [String: String])
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      hashRoot["hashes"] = hashes
      let poisonedPointer = try JSONSerialization.data(withJSONObject: hashRoot)
      try poisonedPointer.write(to: fixture.files.save, options: .atomic)
      let before = await fixture.runtime.snapshot()
      let world = before.scriptWorldSave
      let files = try ScriptFinanceTestFixture.files(fixture.files.root)
      await #expect(throws: SaveError.invalidCommander) {
        try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
      }
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == before.commander && refused.bodies == before.bodies)
      #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
      #expect(refused.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(refused.scriptWorldSave == world)
      #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
      #expect(try Data(contentsOf: fixture.files.save) == poisonedPointer)
    }
    try originalMissions.write(to: missionsURL, options: .atomic)
    try originalPointer.write(to: fixture.files.save, options: .atomic)
    let restored = try ScriptSaveStore.read(originalPointer, from: fixture.files.save).0
    #expect(restored.scriptState.instances[instance.id]?.savedBorrowedVoice
      == instance.savedBorrowedVoice)
  }
}
