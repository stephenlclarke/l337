import Foundation
import Testing

@testable import L337Core

/// Controlled remote location, NOT a flown route. Bootstrap, swept native berth entry,
/// ordinary purchase, board confirmation and current writer use their real producers.
/// No trade, item, stock, acceptance or live contact receipt is injected. UNRUN.
private final class SignedPassageOpeningFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime
  let launchedSolar: ScriptSolarSave?
  let launchedBodies: [SpaceBody]

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
    launchedSolar = game.scriptSimulationSave.solar
    launchedBodies = game.bodies
    try game.departOrdinarySimulation()
    let issuer = NativeSignedPassageOpening.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledSignedPassageDirectory)]
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
    try #require(arrived.systemIdentity == issuer && arrived.signedPassageOpeningPack != nil)
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

  func review(_ action: NativeSignedPassageOpeningAction) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.signedPassageOpening == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.signedPassageOpening == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.signedPassageOpeningQuote?.action == action)
    return detail
  }

  func confirm(_ action: NativeSignedPassageOpeningAction) async throws -> Game {
    let detail = try await review(action)
    try #require(detail.contractBoard.signedPassageOpeningQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    let instance = try #require(result.signedPassageOpeningMission)
    try #require(instance.savedNativeSignedPassageOpening != nil)
    return result
  }
}

struct NativeSignedPassageOpeningTests {
  @Test func actualPurchaseAndCommissionSurviveColdLoadWithoutIssuingTheReference() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    try #require(preview.contractBoard.signedPassageOpeningQuote?.allowed == true)
    let pack = try #require(preview.signedPassageOpeningPack)
    #expect(NativeSignedPassageOpening.matches(pack))
    let bundled = ScriptPackLibrary.defaultLibrary(
      directory: fixture.files.root.appendingPathComponent("empty-user-packs"))
    #expect(bundled.packs.filter(NativeSignedPassageOpening.matches).count == 1)
    #expect(Display.contractDetailRows(preview, width: preview.viewportWidth)
      .joined(separator: " ").contains("Acceptance issues no original reference"))
    #expect(pack.manifest.mission.milestones == NativeSignedPassageOpening.Stage.allCases.map(\.objective))
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.signedPassageOpeningMission)
    let state = try #require(instance.savedNativeSignedPassageOpening)
    #expect(state.opening.trade == accepted.commander.scriptState.firstNativeCommodityTrade?.operation)
    #expect(state.opening.dock.station.system == NativeSignedPassageOpening.issuer)
    #expect(instance.milestones == [0] && instance.receipts == [NativeSignedPassageOpening.acceptance])
    #expect(instance.journal == NativeSignedPassageOpening.briefing && instance.gearIssues.isEmpty)
    #expect(instance.completionReceipt == nil && instance.outcome == .active)
    #expect(instance.payloads.isEmpty && instance.timers.isEmpty)
    #expect(NativeSignedPassageOpening.authoredReceipt(event: "mission_contact_confirmed",
      target: "accept-verified", instance: instance) == "l337.courier/accept")
    #expect(NativeSignedPassageOpening.authoredReceipt(event: "mission_contact_confirmed",
      target: "collect-reference-verified", instance: instance) == nil)
    #expect(accepted.commander.equipmentInventory == preview.commander.equipmentInventory)
    #expect(accepted.commander.credits == preview.commander.credits && accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.nativePeople == preview.commander.nativePeople)
    #expect(accepted.commander.flightSimulation == preview.commander.flightSimulation)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativeSignedPassageOpening.Reference.occupiedTonnes(in: accepted.commander.equipmentInventory) == 0)
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.scriptState.instances[instance.id]?.savedNativeSignedPassageOpening == state)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.signedPassageOpeningMission?.savedNativeSignedPassageOpening == state)
    #expect(loaded.nativeStationRuntimeEpoch != accepted.nativeStationRuntimeEpoch)
    #expect(loaded.commander.equipmentInventory == accepted.commander.equipmentInventory)
    #expect(!loaded.signedPassageOpeningReview(.accept).allowed)
    #expect(NativeSignedPassageOpeningSave.validateClaims(loaded.commander))
    #expect(loaded.signedPassageOpeningMission?.completionReceipt == nil)
  }

  @Test func noTradeBackStaleResourcesAndOldEpochCannotAcceptTheCommission() async throws {
    let fixture = try await SignedPassageOpeningFixture(buy: false)
    defer { fixture.clean() }
    let blocked = try await fixture.review(.accept)
    #expect(blocked.contractBoard.signedPassageOpeningQuote?.allowed == false)
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    #expect(await fixture.runtime.snapshot().commander == blocked.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    try await SignedPassageOpeningFixture.buyOne(fixture.runtime)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.signedPassageOpeningQuote)
    try #require(quote.allowed)
    try await SignedPassageOpeningFixture.buyOne(fixture.runtime)
    var stale = await fixture.runtime.snapshot()
    // Negative transient context only, never a positive contact or trade record.
    stale.screen = .contracts
    stale.contractBoard = chosen.contractBoard
    let before = stale.commander
    #expect(throws: MissionPackError.self) { try stale.confirmSignedPassageOpening(quote) }
    #expect(stale.commander == before && stale.signedPassageOpeningMission == nil)
    var epoch = chosen
    epoch.nativeStationRuntimeEpoch = UUID()
    #expect(throws: MissionPackError.self) { try epoch.confirmSignedPassageOpening(quote) }
    #expect(epoch.commander == chosen.commander)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.signedPassageOpeningMission?.milestones == [0])
  }

  @Test func actualWriterRefusalRollsBackCommissionAndRetryCannotIssueItTwice() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let before = await fixture.runtime.snapshot()
    let quote = try #require(before.contractBoard.signedPassageOpeningQuote)
    try #require(quote.allowed)
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let parked = try fixture.files.blockWrites("signed-passage-accept")
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.scriptCommand { candidate in
        do { try candidate.confirmSignedPassageOpening(quote) }
        catch { Issue.record(error); throw error } // A producer error is not writer-refusal proof.
      }
    }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == before.commander && refused.signedPassageOpeningMission == nil)
    #expect(try ScriptFinanceTestFixture.files(parked) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(parked, files: files)
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.signedPassageOpeningMission)
    #expect(instance.milestones == [0] && instance.gearIssues.isEmpty)
    #expect(accepted.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(accepted.commander.credits == before.commander.credits && accepted.commander.cargo == before.commander.cargo)
    var repeated = before
    repeated.commander = accepted.commander
    #expect(throws: MissionPackError.self) { try repeated.confirmSignedPassageOpening(quote) }
    #expect(repeated.commander == accepted.commander)
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
  }

  @Test func genericAcceptanceReplayedCommandsAndForeignPackCannotGrantProgressOrPayment() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.signedPassageOpeningPack)
    let before = game.commander
    #expect(!NativeSignedPassageOpening.applies(fixture.files.pack))
    #expect(game.signedPassageOpeningGalleryEntry(fixture.files.pack) == nil)
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.signedPassageOpeningMission == nil)
    #expect(throws: MissionPackError.self) {
      _ = try game.makeScriptTrial(packDigest: pack.digest, seed: 1)
    }
    #expect(game.commander == before && game.signedPassageOpeningMission == nil)
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.signedPassageOpeningMission)
    let saved = try #require(instance.savedNativeSignedPassageOpening)
    // The real historical sequence is deliberately replayed outside its pending live event.
    let event = ScriptEvent(sequence: saved.opening.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(1)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(43000)]),
      .object(["op": .string("payload.add"), "id": .string("false-reference"),
        "key": .string(NativeSignedPassageOpening.Reference.logicalResource), "amount": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeSignedPassageOpening.briefing[0])]),
    ]
    for command in commands {
      let fields = try #require(command.object)
      // Exercise the mission boundary itself as well as the shared command route below.
      #expect(throws: MissionPackError.self) {
        try accepted.validateSignedPassageOpeningScriptCommand(fields, event: event, pack: pack,
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
      "op": .string("journal.append"), "text": .string(NativeSignedPassageOpening.briefing[0]),
    ])
    let foreignFields = try #require(foreignCommand.object)
    #expect(throws: MissionPackError.self) {
      try accepted.validateSignedPassageOpeningScriptCommand(foreignFields, event: event,
        pack: fixture.files.pack, state: instance, candidate: accepted.commander)
    }
    var foreignState = instance
    var foreignCandidate = accepted.commander
    #expect(throws: (any Error).self) {
      try accepted.applyScriptCommand(foreignCommand, event: event, pack: fixture.files.pack,
        state: &foreignState, candidate: &foreignCandidate)
    }
    #expect(foreignState == instance && foreignCandidate == accepted.commander)
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
  }

  @Test func strictCurrentLeafAndHistoricalClaimsRefuseMissingMixedOrInventedProgress() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.signedPassageOpeningMission)
    let encoded = try JSONEncoder().encode(instance)
    let value = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    func archive(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: value]])
    }
    try NativeSignedPassageOpeningSave.validateFields(try archive(value), part: .missions)
    var missing = value
    missing.removeValue(forKey: NativeSignedPassageOpeningSave.field)
    var mixed = value
    mixed["digest"] = String(repeating: "0", count: 64)
    var unknown = value
    var leaf = try #require(value[NativeSignedPassageOpeningSave.field] as? [String: Any])
    leaf["collection"] = true
    unknown[NativeSignedPassageOpeningSave.field] = leaf
    var nested = value
    var nestedLeaf = try #require(value[NativeSignedPassageOpeningSave.field] as? [String: Any])
    var nestedOpening = try #require(nestedLeaf["opening"] as? [String: Any])
    nestedOpening["collection"] = true
    nestedLeaf["opening"] = nestedOpening
    nested[NativeSignedPassageOpeningSave.field] = nestedLeaf
    for broken in [missing, mixed, unknown, nested] {
      #expect(throws: (any Error).self) {
        try NativeSignedPassageOpeningSave.validateFields(try archive(broken), part: .missions)
      }
    }
    let misplaced = try JSONSerialization.data(withJSONObject: ["savedScriptState":
      ["instances": [instance.id.uuidString: value]]])
    #expect(throws: (any Error).self) { try NativeSignedPassageOpeningSave.validateFields(misplaced, part: .commander) }
    var falseProgress = accepted.commander
    falseProgress.scriptState.instances[instance.id]?.milestones.insert(1)
    #expect(!NativeSignedPassageOpeningSave.validateClaims(falseProgress))
    var falseCollection = accepted.commander
    falseCollection.scriptState.instances[instance.id]?.payloads[NativeSignedPassageOpening.Reference.logicalResource] = 1
    #expect(!NativeSignedPassageOpeningSave.validateClaims(falseCollection))
    var collectionReceipt = accepted.commander
    collectionReceipt.scriptState.instances[instance.id]?.receipts.insert("courier-collect-reference")
    #expect(!NativeSignedPassageOpeningSave.validateClaims(collectionReceipt))
    var noTrade = accepted.commander
    noTrade.scriptState.firstNativeCommodityTrade = nil
    #expect(!NativeSignedPassageOpeningSave.validateClaims(noTrade))
    // Negative-only state edits above grant no source, item, observation or event.
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
  }

  @Test func galleryKeepsEightPhysicalObjectivesUnavailableAndReadingCannotAdvanceThem() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let pack = try #require(initial.signedPassageOpeningPack)
    let available = try #require(initial.signedPassageOpeningGalleryEntry(pack))
    #expect(available.status == .available && available.completed == 0)
    #expect(available.trialDigest == nil && available.milestones.count == 9)
    let accepted = try await fixture.confirm(.accept)
    let entry = try #require(accepted.signedPassageOpeningGalleryEntry(pack))
    #expect(entry.completed == 1 && entry.status == .locked && entry.trialDigest == nil)
    #expect(entry.milestones.first?.state == "Complete")
    #expect(entry.milestones.dropFirst().allSatisfy { $0.state == "Unavailable" })
    let visible = accepted.scriptGallery.filter { $0.name == "Signed Passage" }
    #expect(visible.count == 1 && visible.first?.completed == 1)
    #expect(entry.objective.contains("reference"))
    let before = accepted.commander
    await fixture.runtime.key("gallery-open")
    let shown = await fixture.runtime.snapshot()
    #expect(shown.commander == before && shown.signedPassageOpeningMission?.milestones == [0])
    var missingPack = shown
    missingPack.scriptPacks = []
    let instance = try #require(missingPack.signedPassageOpeningMission)
    let absent = try #require(missingPack.signedPassageOpeningMissingGalleryEntry(instance))
    #expect(absent.status == .locked && absent.trialDigest == nil && absent.completed == 1)
    #expect(absent.milestones.first?.state == "Complete")
    #expect(missingPack.commander == before)
    let filesBeforeLoad = try ScriptFinanceTestFixture.files(fixture.files.root)
    let withoutContent = GameRuntime(game: missingPack, saveURL: fixture.files.save)
    try await withoutContent.load(from: fixture.files.save, persistMigrations: false)
    let reloadedMissing = await withoutContent.snapshot()
    let retained = try #require(reloadedMissing.signedPassageOpeningMission)
    #expect(retained.savedNativeSignedPassageOpening == instance.savedNativeSignedPassageOpening)
    #expect(retained.milestones == [0] && retained.payloads.isEmpty && retained.gearIssues.isEmpty)
    #expect(retained.suspension != nil && retained.journal == NativeSignedPassageOpening.briefing)
    #expect(NativeSignedPassageOpeningSave.validateClaims(reloadedMissing.commander))
    let retainedEntry = try #require(reloadedMissing.signedPassageOpeningMissingGalleryEntry(retained))
    #expect(retainedEntry.completed == 1 && retainedEntry.trialDigest == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == filesBeforeLoad)
  }

  @Test func actualAcceptedLeafCopiesEncodeAndCompareWithoutMutatingTheOriginal() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.signedPassageOpeningMission)
    let saved = try #require(instance.savedNativeSignedPassageOpening)
    var detached = instance
    detached.savedNativeSignedPassageOpening = nil
    #expect(detached != instance && instance.savedNativeSignedPassageOpening == saved)
    var copied = accepted.commander
    copied.scriptState.instances[instance.id]?.savedNativeSignedPassageOpening = nil
    #expect(copied != accepted.commander)
    #expect(accepted.commander.scriptState.instances[instance.id]?.savedNativeSignedPassageOpening == saved)
    #expect(!NativeSignedPassageOpeningSave.validateClaims(copied))
    let encoded = try JSONEncoder().encode(instance)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: encoded)
    #expect(decoded == instance && decoded.savedNativeSignedPassageOpening == saved)
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
  }

  @Test func rehashedCurrentArchiveClaimsRefuseThroughTheActualLoaderWithoutChangingLiveStateOrFiles() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.signedPassageOpeningMission)
    let originalPointer = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let missionsURL = directory.appendingPathComponent("missions.json")
    let originalMissions = try Data(contentsOf: missionsURL)
    let root = try #require(JSONSerialization.jsonObject(with: originalMissions) as? [String: Any])
    // Valid current archive control: negative loads must reach the C38 gate, not a broken baseline.
    let control = try ScriptSaveStore.read(originalPointer, from: fixture.files.save).0
    try #require(control.scriptState.instances[instance.id]?.savedNativeSignedPassageOpening != nil)
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
    let missing = try corrupted { _ = $0.removeValue(forKey: NativeSignedPassageOpeningSave.field) }
    let nested = try corrupted { value in
      var leaf = try #require(value[NativeSignedPassageOpeningSave.field] as? [String: Any])
      var opening = try #require(leaf["opening"] as? [String: Any])
      opening["collection"] = true
      leaf["opening"] = opening
      value[NativeSignedPassageOpeningSave.field] = leaf
    }
    let originalText = try #require(String(data: originalMissions, encoding: .utf8))
    let key = "\"savedNativeSignedPassageOpening\":"
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
    #expect(restored.scriptState.instances[instance.id]?.savedNativeSignedPassageOpening
      == instance.savedNativeSignedPassageOpening)
  }

  @Test func actualWorldValueEqualityRetainsEverySavedFieldAcrossEncodingLayouts() async throws {
    let fixture = try await SignedPassageOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let world = accepted.scriptWorldSave
    let original = try JSONEncoder().encode(world)
    let pretty = JSONEncoder()
    pretty.outputFormatting = [.prettyPrinted]
    let differentLayout = try pretty.encode(world)
    #expect(original != differentLayout)
    let decoded = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptWorldSave.self, from: differentLayout)
    #expect(decoded == world)
    #expect(accepted.scriptWorldSave == world)

    // Negative copies only. Every saved field must remain part of the refusal invariant.
    // These values are never published, loaded into the runtime or used as physical evidence.
    func detects(_ change: (inout ScriptWorldSave) -> Void) {
      var changed = world
      change(&changed)
      #expect(changed != world)
    }
    try #require(world.libraryScreen != nil && world.simulation != nil)
    // Docking unloads flight bodies; retain that actual empty-state invariant.
    try #require(world.bodies.isEmpty)
    try #require(!world.market.isEmpty)
    try #require(!fixture.launchedBodies.isEmpty)
    let station = try #require(fixture.launchedBodies.first { $0.id == 0 && $0.hull == .station })
    detects { $0.libraryScreen = nil }
    detects { $0.simulation = nil }
    detects {
      $0.referenceFrame = world.referenceFrame == nil
        ? .init(galaxy: accepted.commander.galaxy, system: accepted.commander.system, station: station)
        : nil
    }
    detects { $0.contractScreen = world.contractScreen == nil ? accepted.contractBoard.save : nil }
    detects { $0.bodies = fixture.launchedBodies }
    detects { $0.market[0].price += 1 }
    detects { $0.docked.toggle() }
    detects { $0.mainStation.toggle() }
    detects { $0.screen = world.screen == .front ? .status : .front }
    detects { $0.speed += 1 }
    detects { $0.time += 1 }
    detects { $0.energy += 1 }
    detects { $0.frontShield += 1 }
    detects { $0.rearShield += 1 }
    detects { $0.laserHeat += 1 }
    detects { $0.jumpCountdown = world.jumpCountdown == nil ? 0 : nil }
    detects { $0.selectedSystem = (world.selectedSystem + 1) % 257 }
    detects { $0.nextBodyID += 1 }

    // Compare actual launched body values with array presence held fixed as well.
    // These are detached negative copies, never published into the docked runtime.
    var withBodies = world
    withBodies.bodies = fixture.launchedBodies
    var changedBody = withBodies
    changedBody.bodies[0].position.x += 1
    #expect(changedBody != withBodies)

    // Optional presence alone is insufficient: preserve the nested values too.
    detects { $0.libraryScreen?.scroll += 1 }
    let simulation = try #require(world.simulation)
    detects {
      $0.simulation = ScriptSimulationSave(
        randomState: simulation.randomState ^ 1, fireCooldown: simulation.fireCooldown,
        spawnClock: simulation.spawnClock, missionLoopCounter: simulation.missionLoopCounter,
        missionSpawnDelay: simulation.missionSpawnDelay, ecmFrames: simulation.ecmFrames,
        ecmRemainingDuration: simulation.ecmRemainingDuration,
        enemyECMSource: simulation.enemyECMSource, missileCooldown: simulation.missileCooldown,
        cabinTemperature: simulation.cabinTemperature, altitude: simulation.altitude,
        solar: simulation.solar)
    }
    var negativeSolar = accepted
    negativeSolar.solarFuelRemainder = accepted.solarFuelRemainder == 0 ? 0.25 : 0
    detects { $0.simulation = negativeSolar.scriptSimulationSave }
    let controls = world.contractScreen ?? accepted.contractBoard.save
    var withControls = world
    withControls.contractScreen = controls
    var changedControls = withControls
    changedControls.contractScreen = .init(
      selection: controls.selection, detail: !controls.detail, action: controls.action,
      scroll: controls.scroll, previous: controls.previous)
    #expect(changedControls != withControls)
    let frame = world.referenceFrame
      ?? .init(galaxy: accepted.commander.galaxy, system: accepted.commander.system, station: station)
    var withFrame = world
    withFrame.referenceFrame = frame
    var changedFrame = withFrame
    changedFrame.referenceFrame?.station.position.x += 1
    #expect(changedFrame != withFrame)
    // Preserve a genuine launched celestial; docking may clear the current flight scene.
    let celestial = try #require(fixture.launchedSolar?.bodies.first)
    let otherKind = celestial.kind == "planet" ? "sun" : "planet"
    #expect(ScriptCelestialSave(kind: otherKind, position: celestial.position,
      radius: celestial.radius) != celestial)
    var moved = celestial.position
    moved.x += 1
    #expect(ScriptCelestialSave(kind: celestial.kind, position: moved,
      radius: celestial.radius) != celestial)
    #expect(ScriptCelestialSave(kind: celestial.kind, position: celestial.position,
      radius: celestial.radius + 1) != celestial)
    #expect(accepted.scriptWorldSave == world)
    #expect(NativeSignedPassageOpeningSave.validateClaims(accepted.commander))
  }
}
