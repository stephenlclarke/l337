import Foundation
import Testing

@testable import L337Core

/// Controlled remote location, NOT a flown route. Bootstrap, swept native berth entry,
/// ordinary purchase, board confirmation and current writer use their real producers.
/// No trade, item, stock, acceptance or live contact receipt is injected. UNRUN.
private final class PublicRecordOpeningFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime

  init(buy: Bool = true) async throws {
    let storage = try ScriptFreightFixture()
    files = storage
    var ready = false
    defer { if !ready { storage.clean() } }
    try FileManager.default.createDirectory(
      at: storage.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: storage.save)
    let born = await boot.snapshot()
    try #require(born.nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
    try game.departOrdinarySimulation()
    let issuer = NativePublicRecordDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledPublicRecordDirectory)]
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
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
    try #require(arrived.systemIdentity == issuer && arrived.publicRecordPack != nil)
    if buy { try await Self.buyOne(runtime) }
    try await runtime.save(to: storage.save)
    ready = true
  }

  func clean() { files.clean() }

  static func buyOne(_ runtime: GameRuntime) async throws {
    let before = await runtime.snapshot()
    let index = try #require(before.market.indices.first {
      Commodity.all[$0].unit == "t" && before.market[$0].quantity > 0
        && before.market[$0].price > 0 && before.commander.availableCredits >= before.market[$0].price
    })
    try #require(before.stationAllowsMarketServices)
    await runtime.nativeCommand { game in
      game.screen = .buy
      game.selection = index
    }
    await runtime.key("return")
    let after = await runtime.snapshot()
    try #require(after.commander.cargo[index] == before.commander.cargo[index] + 1)
    try #require(after.market[index].quantity == before.market[index].quantity - 1)
    try #require(after.commander.credits == before.commander.credits - before.market[index].price)
    try #require(NativeFirstCommodityTradeSave.validateClaims(after.commander))
    let actual = try #require(after.commander.scriptState.firstNativeCommodityTrade)
    try #require(actual.side == .buy)
    if before.commander.scriptState.firstNativeCommodityTrade == nil {
      try #require(actual.commodity == index && actual.quantity == 1)
      try #require(actual.before.stock == before.market[index].quantity)
      try #require(actual.after.stock == after.market[index].quantity)
      try #require(actual.before.credits == before.commander.credits)
      try #require(actual.after.credits == after.commander.credits)
    }
    // A genuine purchase alone qualifies; sale-only consumers retain their old contract.
    try #require(after.commander.scriptState.firstNativeCommoditySale == nil)
  }

  func review(_ action: NativePublicRecordAction) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.publicRecord == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.publicRecord == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.publicRecordQuote?.action == action)
    return detail
  }

  func confirm(_ action: NativePublicRecordAction) async throws -> Game {
    let detail = try await review(action)
    try #require(detail.contractBoard.publicRecordQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    let instance = try #require(result.publicRecordMission)
    try #require(instance.savedPublicRecord != nil)
    return result
  }
}

struct NativePublicRecordOpeningUnitTests {
  @Test func actualPurchaseAndCommissionSurviveColdLoadWithoutIssuingTheReference() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    try #require(preview.contractBoard.publicRecordQuote?.allowed == true)
    let pack = try #require(preview.publicRecordPack)
    #expect(NativePublicRecordDefinition.matches(pack))
    let bundled = ScriptPackLibrary.defaultLibrary(
      directory: fixture.files.root.appendingPathComponent("empty-user-packs"))
    #expect(bundled.packs.filter(NativePublicRecordDefinition.matches).count == 1)
    #expect(Display.contractDetailRows(preview, width: preview.viewportWidth)
      .joined(separator: " ").contains("Acceptance issues no"))
    #expect(pack.manifest.mission.milestones == NativePublicRecordOriginalStage.allCases.map(\.objective))
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.publicRecordMission)
    let state = try #require(instance.savedPublicRecord)
    #expect(state.acceptance.ordinaryTrade == accepted.commander.scriptState.firstNativeCommodityTrade?.operation)
    #expect(state.acceptance.dock.station.system == NativePublicRecordDefinition.issuer)
    #expect(instance.milestones == [0] && instance.receipts == [NativePublicRecordDefinition.acceptReceipt])
    #expect(instance.journal == NativePublicRecordDefinition.briefing && instance.gearIssues.isEmpty)
    #expect(instance.completionReceipt == nil && instance.outcome == .active)
    #expect(accepted.commander.equipmentInventory == preview.commander.equipmentInventory)
    #expect(accepted.commander.credits == preview.commander.credits && accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.nativePeople == preview.commander.nativePeople)
    #expect(accepted.commander.flightSimulation == preview.commander.flightSimulation)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativePublicRecordReferenceDefinition.occupiedTonnes(in: accepted.commander.equipmentInventory) == 0)
    #expect(NativePublicRecordSave.validateClaims(accepted.commander))
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.scriptState.instances[instance.id]?.savedPublicRecord == state)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.publicRecordMission?.savedPublicRecord == state)
    #expect(loaded.nativeStationRuntimeEpoch != accepted.nativeStationRuntimeEpoch)
    #expect(loaded.commander.equipmentInventory == accepted.commander.equipmentInventory)
    #expect(!loaded.publicRecordReview(.accept).allowed)
    #expect(NativePublicRecordSave.validateClaims(loaded.commander))
    #expect(loaded.publicRecordMission?.completionReceipt == nil)
  }

  @Test func noTradeBackStaleResourcesAndOldEpochCannotAcceptTheCommission() async throws {
    let fixture = try await PublicRecordOpeningFixture(buy: false)
    defer { fixture.clean() }
    let blocked = try await fixture.review(.accept)
    #expect(blocked.contractBoard.publicRecordQuote?.allowed == false)
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    #expect(await fixture.runtime.snapshot().commander == blocked.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    try await PublicRecordOpeningFixture.buyOne(fixture.runtime)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.publicRecordQuote)
    try #require(quote.allowed)
    try await PublicRecordOpeningFixture.buyOne(fixture.runtime)
    var stale = await fixture.runtime.snapshot()
    // Negative transient context only, never a positive contact or trade record.
    stale.screen = .contracts
    stale.contractBoard = chosen.contractBoard
    let before = stale.commander
    #expect(throws: MissionPackError.self) { try stale.confirmPublicRecord(quote) }
    #expect(stale.commander == before && stale.publicRecordMission == nil)
    var epoch = chosen
    epoch.nativeStationRuntimeEpoch = UUID()
    #expect(throws: MissionPackError.self) { try epoch.confirmPublicRecord(quote) }
    #expect(epoch.commander == chosen.commander)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.publicRecordMission?.milestones == [0])
  }

  @Test func actualWriterRefusalRollsBackCommissionAndRetryCannotIssueItTwice() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let before = await fixture.runtime.snapshot()
    let quote = try #require(before.contractBoard.publicRecordQuote)
    try #require(quote.allowed)
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let parked = try fixture.files.blockWrites("public-record-accept")
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.scriptCommand { candidate in
        do { try candidate.confirmPublicRecord(quote) }
        catch { Issue.record(error); throw error } // A producer error is not writer-refusal proof.
      }
    }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == before.commander && refused.publicRecordMission == nil)
    #expect(try ScriptFinanceTestFixture.files(parked) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(parked, files: files)
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.publicRecordMission)
    #expect(instance.milestones == [0] && instance.gearIssues.isEmpty)
    #expect(accepted.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(accepted.commander.credits == before.commander.credits && accepted.commander.cargo == before.commander.cargo)
    var repeated = before
    repeated.commander = accepted.commander
    #expect(throws: MissionPackError.self) { try repeated.confirmPublicRecord(quote) }
    #expect(repeated.commander == accepted.commander)
    #expect(NativePublicRecordSave.validateClaims(accepted.commander))
  }

  @Test func genericAcceptanceReplayedCommandsAndForeignPackCannotGrantProgressOrPayment() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.publicRecordPack)
    let before = game.commander
    #expect(!NativePublicRecordDefinition.applies(fixture.files.pack))
    #expect(game.publicRecordGalleryEntry(fixture.files.pack) == nil)
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.publicRecordMission == nil)
    #expect(throws: MissionPackError.self) {
      _ = try game.makeScriptTrial(packDigest: pack.digest, seed: 1)
    }
    #expect(game.commander == before && game.publicRecordMission == nil)
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.publicRecordMission)
    let saved = try #require(instance.savedPublicRecord)
    // The real historical sequence is deliberately replayed outside its pending live event.
    let event = ScriptEvent(sequence: saved.acceptance.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(1)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(63000)]),
      .object(["op": .string("payload.add"), "id": .string("false-reference"),
        "key": .string(NativePublicRecordReferenceDefinition.logicalResource), "amount": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativePublicRecordDefinition.briefing[0])]),
    ]
    for command in commands {
      let fields = try #require(command.object)
      // Exercise the mission boundary itself as well as the shared command route below.
      #expect(throws: MissionPackError.self) {
        try accepted.validatePublicRecordScriptCommand(fields, event: event, pack: pack,
          state: instance, candidate: accepted.commander)
      }
      var state = instance
      var candidate = accepted.commander
      #expect(throws: (any Error).self) {
        try accepted.applyScriptCommand(command, event: event, pack: pack, state: &state, candidate: &candidate)
      }
      #expect(state == instance && candidate == accepted.commander)
    }
    let foreignCommand = ScriptValue.object([
      "op": .string("journal.append"), "text": .string(NativePublicRecordDefinition.briefing[0]),
    ])
    let foreignFields = try #require(foreignCommand.object)
    #expect(throws: MissionPackError.self) {
      try accepted.validatePublicRecordScriptCommand(foreignFields, event: event,
        pack: fixture.files.pack, state: instance, candidate: accepted.commander)
    }
    var foreignState = instance
    var foreignCandidate = accepted.commander
    #expect(throws: (any Error).self) {
      try accepted.applyScriptCommand(foreignCommand, event: event, pack: fixture.files.pack,
        state: &foreignState, candidate: &foreignCandidate)
    }
    #expect(foreignState == instance && foreignCandidate == accepted.commander)
    #expect(NativePublicRecordSave.validateClaims(accepted.commander))
  }

  @Test func strictCurrentLeafAndHistoricalClaimsRefuseMissingMixedOrInventedProgress() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.publicRecordMission)
    let encoded = try JSONEncoder().encode(instance)
    let value = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    func archive(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: value]])
    }
    try NativePublicRecordSave.validateFields(try archive(value), part: .missions)
    var missing = value
    missing.removeValue(forKey: NativePublicRecordSave.field)
    var mixed = value
    mixed["digest"] = String(repeating: "0", count: 64)
    var unknown = value
    var leaf = try #require(value[NativePublicRecordSave.field] as? [String: Any])
    leaf["replyLeaseSeconds"] = 120
    unknown[NativePublicRecordSave.field] = leaf
    var nested = value
    var nestedLeaf = try #require(value[NativePublicRecordSave.field] as? [String: Any])
    var nestedAcceptance = try #require(nestedLeaf["acceptance"] as? [String: Any])
    nestedAcceptance["independentRecordings"] = [900]
    nestedLeaf["acceptance"] = nestedAcceptance
    nested[NativePublicRecordSave.field] = nestedLeaf
    for broken in [missing, mixed, unknown, nested] {
      #expect(throws: (any Error).self) {
        try NativePublicRecordSave.validateFields(try archive(broken), part: .missions)
      }
    }
    let misplaced = try JSONSerialization.data(withJSONObject: ["savedScriptState":
      ["instances": [instance.id.uuidString: value]]])
    #expect(throws: (any Error).self) { try NativePublicRecordSave.validateFields(misplaced, part: .commander) }
    var falseProgress = accepted.commander
    falseProgress.scriptState.instances[instance.id]?.milestones.insert(1)
    #expect(!NativePublicRecordSave.validateClaims(falseProgress))
    var noTrade = accepted.commander
    noTrade.scriptState.firstNativeCommodityTrade = nil
    #expect(!NativePublicRecordSave.validateClaims(noTrade))
    // Negative-only state edits above grant no source, item, observation or event.
    #expect(NativePublicRecordSave.validateClaims(accepted.commander))
  }

  @Test func galleryKeepsEightPhysicalObjectivesUnavailableAndReadingCannotAdvanceThem() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let pack = try #require(initial.publicRecordPack)
    let available = try #require(initial.publicRecordGalleryEntry(pack))
    #expect(available.status == .available && available.completed == 0)
    #expect(available.trialDigest == nil && available.milestones.count == 9)
    let accepted = try await fixture.confirm(.accept)
    let entry = try #require(accepted.publicRecordGalleryEntry(pack))
    #expect(entry.completed == 1 && entry.status == .locked && entry.trialDigest == nil)
    #expect(entry.milestones.first?.state == "Complete")
    #expect(entry.milestones.dropFirst().allSatisfy { $0.state == "Unavailable" })
    let visible = accepted.scriptGallery.filter { $0.name == "Public Record" }
    #expect(visible.count == 1 && visible.first?.completed == 1)
    #expect(entry.objective.contains("reference"))
    let before = accepted.commander
    await fixture.runtime.key("gallery-open")
    let shown = await fixture.runtime.snapshot()
    #expect(shown.commander == before && shown.publicRecordMission?.milestones == [0])
    var missingPack = shown
    missingPack.scriptPacks = []
    let instance = try #require(missingPack.publicRecordMission)
    let absent = try #require(missingPack.publicRecordMissingGalleryEntry(instance))
    #expect(absent.status == .locked && absent.trialDigest == nil && absent.completed == 1)
    #expect(absent.milestones.first?.state == "Complete")
    #expect(missingPack.commander == before)
    let filesBeforeLoad = try ScriptFinanceTestFixture.files(fixture.files.root)
    let withoutContent = GameRuntime(game: missingPack, saveURL: fixture.files.save)
    try await withoutContent.load(from: fixture.files.save, persistMigrations: false)
    let reloadedMissing = await withoutContent.snapshot()
    let retained = try #require(reloadedMissing.publicRecordMission)
    #expect(retained.savedPublicRecord == instance.savedPublicRecord)
    #expect(retained.milestones == [0] && retained.payloads.isEmpty && retained.gearIssues.isEmpty)
    #expect(retained.suspension != nil && retained.journal == NativePublicRecordDefinition.briefing)
    #expect(NativePublicRecordSave.validateClaims(reloadedMissing.commander))
    let retainedEntry = try #require(reloadedMissing.publicRecordMissingGalleryEntry(retained))
    #expect(retainedEntry.completed == 1 && retainedEntry.trialDigest == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == filesBeforeLoad)
  }
  @Test func actualAcceptedLeafCopiesEncodeAndCompareWithoutMutatingTheOriginal() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.publicRecordMission)
    let saved = try #require(instance.savedPublicRecord)
    var detached = instance
    detached.savedPublicRecord = nil
    #expect(detached != instance && instance.savedPublicRecord == saved)
    var copied = accepted.commander
    copied.scriptState.instances[instance.id]?.savedPublicRecord = nil
    #expect(copied != accepted.commander)
    #expect(accepted.commander.scriptState.instances[instance.id]?.savedPublicRecord == saved)
    #expect(!NativePublicRecordSave.validateClaims(copied))
    let encoded = try JSONEncoder().encode(instance)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: encoded)
    #expect(decoded == instance && decoded.savedPublicRecord == saved)
    #expect(NativePublicRecordSave.validateClaims(accepted.commander))
  }

  @Test func rehashedCurrentArchiveClaimsRefuseThroughTheActualLoaderWithoutChangingLiveStateOrFiles() async throws {
    let fixture = try await PublicRecordOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.publicRecordMission)
    let originalPointer = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let missionsURL = directory.appendingPathComponent("missions.json")
    let originalMissions = try Data(contentsOf: missionsURL)
    let root = try #require(JSONSerialization.jsonObject(with: originalMissions) as? [String: Any])
    // Valid current archive control: negative loads must reach the C37 gate, not a broken baseline.
    let control = try ScriptSaveStore.read(originalPointer, from: fixture.files.save).0
    try #require(control.scriptState.instances[instance.id]?.savedPublicRecord != nil)
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
    let missing = try corrupted { _ = $0.removeValue(forKey: NativePublicRecordSave.field) }
    let nested = try corrupted { value in
      var leaf = try #require(value[NativePublicRecordSave.field] as? [String: Any])
      var opening = try #require(leaf["acceptance"] as? [String: Any])
      opening["independentRecordings"] = [900]
      leaf["acceptance"] = opening
      value[NativePublicRecordSave.field] = leaf
    }
    let originalText = try #require(String(data: originalMissions, encoding: .utf8))
    let key = "\"savedPublicRecord\":"
    let keyRange = try #require(originalText.range(of: key))
    var duplicateText = originalText
    duplicateText.replaceSubrange(keyRange, with: key + "null," + key)
    let corruptions = [missing, nested, Data(duplicateText.utf8)]
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
    #expect(restored.scriptState.instances[instance.id]?.savedPublicRecord
      == instance.savedPublicRecord)
  }
}
