import Foundation
import Testing

@testable import L337Core

/// Controlled remote location, NOT a flown route. Bootstrap, swept native berth entry,
/// ordinary purchase, board confirmation and current writer use their real producers.
/// No trade, item, stock, acceptance or live contact receipt is injected. UNRUN.
private final class MemoryAtlasOpeningFixture {
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
    let issuer = NativeMemoryAtlasDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledMemoryAtlasDirectory)]
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
    try #require(arrived.systemIdentity == issuer && arrived.memoryAtlasPack != nil)
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

  func review(_ action: NativeMemoryAtlasAction) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.memoryAtlas == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.memoryAtlas == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.memoryAtlasQuote?.action == action)
    return detail
  }

  func confirm(_ action: NativeMemoryAtlasAction) async throws -> Game {
    let detail = try await review(action)
    try #require(detail.contractBoard.memoryAtlasQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    let instance = try #require(result.memoryAtlasMission)
    if action == .collectReference { try #require(instance.savedMemoryAtlas?.collection != nil) }
    return result
  }
}

struct NativeMemoryAtlasOpeningUnitTests {
  @Test func purchaseOnlyCommissionAndSeparateOriginalCollectionSurviveCurrentColdLoad() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    try #require(preview.contractBoard.memoryAtlasQuote?.allowed == true)
    let inventory = try #require(preview.commander.equipmentInventory)
    try #require(preview.memoryAtlasMission == nil)
    await fixture.runtime.key("right")
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let commission = try #require(accepted.memoryAtlasMission)
    let acceptance = try #require(commission.savedMemoryAtlas)
    #expect(acceptance.collection == nil && commission.gearIssues.isEmpty)
    #expect(commission.receipts == [NativeMemoryAtlasDefinition.acceptReceipt])
    #expect(commission.milestones == [0] && commission.journal == NativeMemoryAtlasDefinition.briefing)
    #expect(accepted.commander.equipmentInventory == inventory)
    #expect(accepted.commander.credits == preview.commander.credits)
    #expect(accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativeMemoryAtlasSave.validateClaims(accepted.commander))
    let acceptedCold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(acceptedCold.scriptState.instances[commission.id]?.savedMemoryAtlas == acceptance)

    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.memoryAtlasMission)
    let state = try #require(instance.savedMemoryAtlas)
    let collection = try #require(state.collection)
    let loan = try NativeMemoryAtlasCustody.resolve(instance: instance, commander: collected.commander)
    #expect(state.acceptance == acceptance.acceptance && instance.id == commission.id)
    #expect(instance.milestones == [0, 1] && instance.receipts.count == 2)
    #expect(instance.outcome == .active && instance.completionReceipt == nil)
    #expect(collection.facts.original == NativeMemoryAtlasDefinition.referenceSerial(mission: instance.id))
    #expect(collection.facts.afterCargoTonnes == collection.facts.beforeCargoTonnes + 1)
    #expect(collection.facts.afterInventoryRevision == inventory.revision + 1)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.cargo == accepted.commander.cargo)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
    #expect(NativeMemoryAtlasSave.validateClaims(collected.commander))
    try await fixture.runtime.save(to: fixture.files.save)
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    let coldInstance = try #require(cold.scriptState.instances[instance.id])
    #expect(coldInstance.savedMemoryAtlas == state)
    #expect(try NativeMemoryAtlasCustody.resolve(instance: coldInstance, commander: cold) == loan)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    let loadedInstance = try #require(loaded.memoryAtlasMission)
    #expect(loadedInstance.savedMemoryAtlas == state)
    #expect(loaded.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try NativeMemoryAtlasCustody.resolve(instance: loadedInstance, commander: loaded.commander) == loan)
    #expect(loaded.nativeStationRuntimeEpoch != collected.nativeStationRuntimeEpoch)
    #expect(!loaded.memoryAtlasReview(.collectReference).allowed)
    #expect(NativeMemoryAtlasSave.validateClaims(loaded.commander))
  }

  @Test func noTradeBackAndStalePurchaseReviewCannotAccept() async throws {
    let fixture = try await MemoryAtlasOpeningFixture(buy: false)
    defer { fixture.clean() }
    let blocked = try await fixture.review(.accept)
    #expect(blocked.contractBoard.memoryAtlasQuote?.allowed == false)
    #expect(blocked.memoryAtlasMission == nil)
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.commander == blocked.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    try await MemoryAtlasOpeningFixture.buyOne(fixture.runtime)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.memoryAtlasQuote)
    try #require(quote.allowed)
    try await MemoryAtlasOpeningFixture.buyOne(fixture.runtime)
    let changed = await fixture.runtime.snapshot()
    var stale = changed
    // Restore only the old transient screen for this negative check; no source is injected.
    stale.screen = .contracts
    stale.contractBoard = chosen.contractBoard
    let unchanged = stale.commander
    #expect(throws: MissionPackError.self) { try stale.confirmMemoryAtlas(quote) }
    #expect(stale.commander == unchanged && stale.memoryAtlasMission == nil)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.memoryAtlasMission?.savedMemoryAtlas?.collection == nil)
  }

  @Test func actualWriterRefusalRetainsIssuerOriginalAndRetriesOnce() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    for action in [NativeMemoryAtlasAction.accept, .collectReference] {
      _ = try await fixture.review(action)
      await fixture.runtime.key("right")
      let before = await fixture.runtime.snapshot()
      let quote = try #require(before.contractBoard.memoryAtlasQuote)
      try #require(quote.allowed)
      let directory = fixture.files.save.deletingLastPathComponent()
      let files = try ScriptFinanceTestFixture.files(directory)
      let held = try fixture.files.blockWrites("memory-atlas-" + action.rawValue)
      await #expect(throws: (any Error).self) {
        try await fixture.runtime.scriptCommand { candidate in
          // A producer error is a test failure, not mistaken for the expected writer refusal.
          do { try candidate.confirmMemoryAtlas(quote) }
          catch { Issue.record(error); throw error }
        }
      }
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == before.commander)
      #expect(try ScriptFinanceTestFixture.files(held) == files)
      #expect(try Data(contentsOf: directory) == Data([1]))
      try fixture.files.restoreWrites(held, files: files)
      await fixture.runtime.key("return")
      let committed = await fixture.runtime.snapshot()
      let instance = try #require(committed.memoryAtlasMission)
      if action == .accept {
        #expect(instance.savedMemoryAtlas?.collection == nil && instance.gearIssues.isEmpty)
      } else {
        let state = try #require(instance.savedMemoryAtlas?.collection)
        #expect(instance.gearIssues.count == 1)
        #expect(state.facts.afterInventoryRevision == state.facts.beforeInventoryRevision + 1)
        _ = try NativeMemoryAtlasCustody.resolve(instance: instance, commander: committed.commander)
      }
      #expect(committed.commander.credits == before.commander.credits)
      #expect(committed.commander.cargo == before.commander.cargo)
      #expect(committed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
      #expect(NativeMemoryAtlasSave.validateClaims(committed.commander))
      var repeated = before
      repeated.commander = committed.commander
      #expect(throws: MissionPackError.self) { try repeated.confirmMemoryAtlas(quote) }
      #expect(repeated.commander == committed.commander)
    }
  }

  @Test func genuineIssueCommandCannotMasqueradeAsTheOrdinaryTrade() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.memoryAtlasMission)
    let state = try #require(instance.savedMemoryAtlas)
    let issue = try #require(state.collection)
    let original = state.acceptance
    try #require(original.ordinaryTrade != issue.facts.issueCommand)
    // Deliberately false causal link made from two ACTUAL operation identities.
    let wrong = NativeMemoryAtlasAcceptanceFacts(mission: original.mission, owner: original.owner,
      carrier: original.carrier, inventoryRevision: original.inventoryRevision, dock: original.dock,
      ordinaryTrade: issue.facts.issueCommand, eventSequence: original.eventSequence,
      physicalTime: original.physicalTime, calendarSeconds: original.calendarSeconds)
    var falseState = try NativeMemoryAtlasState(acceptance: wrong)
    falseState.collection = issue
    try #require(falseState.shapeValid)
    var invalid = collected
    invalid.commander.scriptState.instances[instance.id]?.savedMemoryAtlas = falseState
    #expect(!NativeMemoryAtlasSave.validateClaims(invalid.commander))
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    #expect(throws: (any Error).self) {
      try GameRuntime.writeCommander(&invalid, to: fixture.files.save)
    }
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    #expect(NativeMemoryAtlasSave.validateClaims(collected.commander))
  }

  @Test func genericAcceptanceAndCommandsCannotGrantCustodyProgressOrPayment() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.memoryAtlasPack)
    let before = game.commander
    #expect(!NativeMemoryAtlasDefinition.applies(fixture.files.pack))
    #expect(game.memoryAtlasGalleryEntry(fixture.files.pack) == nil)
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.memoryAtlasMission == nil)
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.memoryAtlasMission)
    let saved = try #require(instance.savedMemoryAtlas)
    // This replay uses the real historical sequence but is NOT a pending live event.
    let event = ScriptEvent(sequence: saved.acceptance.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(2)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(72000)]),
      .object(["op": .string("payload.add"), "id": .string("false-reference"), "key": .string("memory-atlas-reference"), "amount": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeMemoryAtlasDefinition.briefing[0])]),
    ]
    for command in commands {
      let fields = try #require(command.object)
      // Check this mission boundary itself, then the shared route below.
      #expect(throws: MissionPackError.self) {
        try accepted.validateMemoryAtlasScriptCommand(fields, event: event, pack: pack,
          state: instance, candidate: accepted.commander)
      }
      var state = instance
      var candidate = accepted.commander
      #expect(throws: (any Error).self) {
        try accepted.applyScriptCommand(command, event: event, pack: pack, state: &state, candidate: &candidate)
      }
      #expect(state == instance && candidate == accepted.commander)
    }
    #expect(NativeMemoryAtlasSave.validateClaims(accepted.commander))
    let foreignCommand = ScriptValue.object([
      "op": .string("journal.append"), "text": .string(NativeMemoryAtlasDefinition.briefing[0]),
    ])
    let foreignFields = try #require(foreignCommand.object)
    #expect(throws: MissionPackError.self) {
      try accepted.validateMemoryAtlasScriptCommand(foreignFields, event: event,
        pack: fixture.files.pack, state: instance, candidate: accepted.commander)
    }
    var foreignState = instance
    var foreignCandidate = accepted.commander
    #expect(throws: (any Error).self) {
      try accepted.applyScriptCommand(foreignCommand, event: event, pack: fixture.files.pack,
        state: &foreignState, candidate: &foreignCandidate)
    }
    #expect(foreignState == instance && foreignCandidate == accepted.commander)

  }
}

struct NativeMemoryAtlasGalleryUnitTests {
  private func entry(_ game: Game) throws -> GalleryMission {
    let pack = try #require(game.memoryAtlasPack)
    let owned = try #require(game.memoryAtlasGalleryEntry(pack))
    let visible = game.scriptGallery.filter { $0.name == "The Memory Atlas" }
    try #require(visible.count == 1)
    #expect(visible[0].status == owned.status && visible[0].objective == owned.objective)
    #expect(visible[0].completed == owned.completed && visible[0].savedInstance == owned.savedInstance)
    #expect(visible[0].trialDigest == nil && owned.trialDigest == nil)
    #expect(visible[0].milestones.map(\.title) == owned.milestones.map(\.title))
    #expect(visible[0].milestones.map(\.state) == owned.milestones.map(\.state))
    return owned
  }

  @Test func genuinePurchaseOpensOnlyCommissionAndGalleryInputRemainsReadOnly() async throws {
    let fixture = try await MemoryAtlasOpeningFixture(buy: false)
    defer { fixture.clean() }
    let noTrade = await fixture.runtime.snapshot()
    let locked = try entry(noTrade)
    #expect(locked.status == .locked && locked.completed == 0 && locked.savedInstance == nil)
    #expect(locked.milestones.count == 9 && locked.milestones[0].state == "Upcoming")
    #expect(locked.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    try await MemoryAtlasOpeningFixture.buyOne(fixture.runtime)
    let bought = await fixture.runtime.snapshot()
    let available = try entry(bought)
    #expect(available.status == .available && available.completed == 0)
    #expect(available.prerequisites.isEmpty && available.savedInstance == nil)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    await fixture.runtime.nativeCommand { game in
      game.screen = .status
      game.openGallery()
      if let index = game.missionCatalogue.firstIndex(where: { $0.name == "The Memory Atlas" }) {
        game.gallery.selection = index
      }
    }
    let gallery = await fixture.runtime.snapshot()
    try #require(gallery.screen == .gallery && gallery.selectedGalleryMission?.name == available.name)
    #expect(!gallery.canTrialSelectedMission && !gallery.canRetrySelectedMission)
    await fixture.runtime.key("return")
    await fixture.runtime.key("t")
    await fixture.runtime.key("escape")
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.screen == .status && !closed.isMissionTrial)
    #expect(closed.commander == bought.commander && closed.memoryAtlasMission == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
  }

  @Test func acceptanceAndOriginalLoanHaveSeparateHistoryWithoutQualifyingAnySurvey() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let first = try entry(accepted)
    #expect(first.status == .active && first.completed == 1)
    #expect(first.milestones[0].state == "Complete" && first.milestones[1].state == "Current")
    #expect(first.briefing.contains("Vale retains the original instrument"))
    #expect(first.destination == "Reris / Galaxy 1")
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.memoryAtlasMission)
    let loan = try NativeMemoryAtlasCustody.resolve(instance: instance, commander: collected.commander)
    let before = collected.commander
    let second = try entry(collected)
    #expect(second.status == .locked && second.completed == 2 && second.savedInstance == instance.id)
    #expect(second.milestones.prefix(2).allSatisfy { $0.state == "Complete" })
    #expect(second.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    #expect(second.destination == "Nedasen / Galaxy 1")
    #expect(second.briefing.contains("same original reference instrument is aboard"))
    #expect(second.briefing.contains("12 uninterrupted seconds"))
    #expect(second.objective.contains("not currently available"))
    #expect(second.trialDigest == nil && instance.outcome == .active)
    #expect(instance.completionReceipt == nil && instance.milestones == [0, 1])
    #expect(collected.commander == before)
    #expect(try NativeMemoryAtlasCustody.resolve(instance: instance, commander: collected.commander) == loan)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
  }

  @Test func currentColdLoadPreservesOnlyActualOpeningHistoryAndNoTrialAction() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let before = try entry(collected)
    try await fixture.runtime.save(to: fixture.files.save)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let restored = await fixture.runtime.snapshot()
    let after = try entry(restored)
    #expect(after.status == before.status && after.completed == 2 && after.savedInstance == before.savedInstance)
    #expect(after.objective == before.objective && after.destination == before.destination)
    #expect(after.milestones.map(\.title) == before.milestones.map(\.title))
    #expect(after.milestones.map(\.state) == before.milestones.map(\.state))
    #expect(after.trialDigest == nil && after.status != .complete)
    #expect(restored.memoryAtlasMission?.savedMemoryAtlas == collected.memoryAtlasMission?.savedMemoryAtlas)
    #expect(restored.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(restored.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
  }

  @Test func falseCountsMissingOriginalItemAndMissingPackNeverAdvertiseCompletion() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.memoryAtlasMission)
    let state = try #require(instance.savedMemoryAtlas)
    let collection = try #require(state.collection)
    let pack = try #require(collected.memoryAtlasPack)
    for complete in [false, true] {
      var invalid = collected
      invalid.commander.scriptState.instances[instance.id]?.milestones = Set(0..<9)
      if complete { invalid.commander.scriptState.instances[instance.id]?.outcome = .complete }
      let before = invalid.commander
      let page = try #require(invalid.memoryAtlasGalleryEntry(pack))
      #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
      #expect(page.reward == "No settlement available." && invalid.commander == before)
    }
    var missingItem = collected
    let inventory = try #require(missingItem.commander.savedEquipmentInventory)
    try #require(inventory.items.contains { $0.id == collection.facts.original })
    // Deliberately invalid held-original claim; no return, revision advance or issue rewrite.
    let missingOriginalInventory = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: inventory.items.filter { $0.id != collection.facts.original })
    missingItem.commander.savedEquipmentInventory = missingOriginalInventory
    let missingPage = try #require(missingItem.memoryAtlasGalleryEntry(pack))
    #expect(missingPage.status == .locked && missingPage.completed == 0)
    #expect(missingItem.commander.scriptState.instances[instance.id]?.savedMemoryAtlas == state)
    var missingPack = collected
    missingPack.scriptPacks = []
    let before = missingPack.commander
    let page = try #require(missingPack.memoryAtlasMissingGalleryEntry(instance))
    #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
    #expect(page.savedInstance == instance.id && page.objective.contains("history remain recorded"))
    let visible = missingPack.scriptGallery.filter { $0.savedInstance == instance.id }
    try #require(visible.count == 1)
    #expect(visible[0].status == .locked && visible[0].completed == 0)
    #expect(missingPack.commander == before)
    #expect(NativeMemoryAtlasSave.validateClaims(collected.commander))
  }
}

/// Uses the same actual native-arrival/ordinary-trade/writer fixture as the original nine methods.
/// Remote approach remains controlled; no source, original, permission or receipt is injected.
struct NativeMemoryAtlasSourceConservationUnitTests {
  @Test func genuineArrivalRetainsOneAvailableOriginalBeforeCommission() async throws {
    let fixture = try await MemoryAtlasOpeningFixture(buy: false)
    defer { fixture.clean() }
    let arrived = await fixture.runtime.snapshot()
    let projection = try #require(arrived.memoryAtlasWatcherSourceProjection)
    let source = projection.source
    let owner = try #require(arrived.commander.equipmentOwnerID)
    #expect(source.owner == owner && source.station.world == owner)
    #expect(source.station.system == NativeMemoryAtlasDefinition.issuer)
    #expect(source.issuer == NativeMemoryAtlasDefinition.referenceIssuer(owner: owner))
    #expect(source.caseID == NativeMemoryAtlasDefinition.mission(owner: owner))
    #expect(source.original == NativeMemoryAtlasDefinition.referenceSerial(mission: source.caseID))
    #expect(source.sourceRevision == 1 && source.adoptionRevision == 1)
    #expect(projection.available && !projection.owed && source.custody == .available)
    #expect(source.transfer == nil && source.quantity == 1 && source.cargoTonnes == 1)
    #expect(source.heldOnly && source.loan && source.returnPolicy == "all")
    #expect(source.initialization.dock == arrived.commander.nativeStations?.currentMainDock)
    #expect(arrived.nativeMainStationDockEvidenceIsCurrent)
    #expect(source.initialization.eventSequence > 0)
    #expect(source.initialization.eventSequence <= arrived.commander.scriptState.nextEvent)
    #expect(source.initialization.physicalTime <= arrived.commander.flightSimulation.physicalTime)
    #expect(source.initialization.calendarSeconds <= arrived.commander.scriptState.calendarSeconds)
    #expect(arrived.memoryAtlasMission == nil && arrived.memoryAtlasWatcherSourceQuote() == nil)
    let inventory = try #require(arrived.commander.equipmentInventory)
    #expect(!inventory.items.contains { $0.id == source.original })
    #expect(try arrived.commander.equipmentIssueObligations().allSatisfy {
      $0.source.resource != NativeMemoryAtlasReferenceDefinition.logicalResource
    })
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.savedMemoryAtlasWatcherSource == source)
    #expect(NativeMemoryAtlasWatcherSourceSave.validateClaims(cold))
    #expect(!arrived.memoryAtlasReview(.accept).allowed)
    let before = arrived.commander
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)
    for _ in 0..<3 {
      #expect(arrived.memoryAtlasWatcherSourceProjection == projection)
      #expect(arrived.memoryAtlasWatcherSourceQuote() == nil)
    }
    #expect(arrived.commander == before)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
  }

  @Test func reviewAndBackNeverMoveOrRefreshTheSelectedOriginal() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let original = try #require(initial.memoryAtlasWatcherSourceProjection)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("escape")
    let cancelled = await fixture.runtime.snapshot()
    #expect(cancelled.commander == initial.commander)
    #expect(cancelled.memoryAtlasWatcherSourceProjection == original)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.memoryAtlasWatcherSourceProjection == original)
    let captured = try #require(accepted.memoryAtlasWatcherSourceQuote())
    let instance = try #require(accepted.memoryAtlasMission)
    var suspended = accepted
    suspended.commander.scriptState.instances[instance.id]?.suspension = "Negative-only suspended live collection"
    let retained = suspended.commander
    #expect(NativeMemoryAtlasWatcherSourceSave.validateClaims(retained))
    #expect(suspended.memoryAtlasWatcherSourceQuote() == nil)
    #expect(throws: EquipmentIssueError.staleObligation) {
      try suspended.collectMemoryAtlasWatcherSource(captured)
    }
    #expect(suspended.commander == retained)
    let before = accepted.commander
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)
    for _ in 0..<3 {
      let detail = try await fixture.review(.collectReference)
      let quote = try #require(detail.contractBoard.memoryAtlasQuote?.watcherSource)
      #expect(quote.original == original.original && quote.sourceRevision == 1)
      #expect(detail.commander == before && detail.memoryAtlasWatcherSourceProjection == original)
      await fixture.runtime.key("escape")
    }
    let after = await fixture.runtime.snapshot()
    #expect(after.commander == before && after.memoryAtlasWatcherSourceProjection == original)
    #expect(after.memoryAtlasMission?.savedMemoryAtlas?.collection == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
  }

  @Test func sourceTransferWriterRefusalRetriesTheSameOriginalOnce() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    _ = try await fixture.review(.collectReference)
    await fixture.runtime.key("right")
    let before = await fixture.runtime.snapshot()
    let source = try #require(before.memoryAtlasWatcherSourceProjection)
    let quote = try #require(before.contractBoard.memoryAtlasQuote)
    try #require(quote.allowed && quote.watcherSource != nil)
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let held = try fixture.files.blockWrites("memory-atlas-finite-source")
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.scriptCommand { candidate in
        do { try candidate.confirmMemoryAtlas(quote) }
        catch { Issue.record(error); throw error }
      }
    }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.memoryAtlasWatcherSourceProjection == source)
    #expect(try ScriptFinanceTestFixture.files(held) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(held, files: files)
    await fixture.runtime.key("return")
    let committed = await fixture.runtime.snapshot()
    let loan = try #require(committed.memoryAtlasWatcherSourceProjection)
    let instance = try #require(committed.memoryAtlasMission)
    let collection = try #require(instance.savedMemoryAtlas?.collection)
    let transfer = try #require(loan.transfer)
    #expect(loan.sourceRevision == 2 && loan.custody == .onLoan && loan.owed && !loan.available)
    #expect(loan.original == source.original && loan.initialization == source.initialization)
    #expect(transfer.beforeSourceRevision == 1 && transfer.afterSourceRevision == 2)
    #expect(transfer.collection == collection && collection.facts.original == source.original)
    #expect(instance.milestones == [0, 1] && instance.gearIssues.count == 1)
    let inventory = try #require(committed.commander.equipmentInventory)
    let originals = inventory.items.filter { $0.id == source.original }
    #expect(originals.count == 1 && originals[0].node == NativeMemoryAtlasReferenceDefinition.node)
    let obligations = try committed.commander.equipmentIssueObligations().filter {
      $0.source.mission == instance.id && $0.source.resource == NativeMemoryAtlasReferenceDefinition.logicalResource
    }
    #expect(obligations.count == 1 && obligations[0].items == [source.original])
    #expect(committed.commander.credits == before.commander.credits)
    #expect(committed.commander.cargo == before.commander.cargo)
    #expect(committed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    var repeated = committed
    let published = repeated.commander
    #expect(throws: (any Error).self) { try repeated.confirmMemoryAtlas(quote) }
    #expect(repeated.commander == published && repeated.memoryAtlasWatcherSourceProjection == loan)
    #expect(NativeMemoryAtlasWatcherSourceSave.validateClaims(committed.commander))
  }

  @Test func sealedSourceQuotesRefuseActualPurchaseAndColdLoadChanges() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let original = try #require(accepted.memoryAtlasWatcherSourceProjection)
    let purchaseQuote = try #require(accepted.memoryAtlasWatcherSourceQuote())
    try await MemoryAtlasOpeningFixture.buyOne(fixture.runtime)
    let bought = await fixture.runtime.snapshot()
    var stale = bought
    #expect(throws: EquipmentIssueError.staleObligation) {
      try stale.collectMemoryAtlasWatcherSource(purchaseQuote)
    }
    #expect(stale.commander == bought.commander && stale.memoryAtlasWatcherSourceProjection == original)
    let coldQuote = try #require(bought.memoryAtlasWatcherSourceQuote())
    try await fixture.runtime.save(to: fixture.files.save)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    try #require(loaded.nativeStationRuntimeEpoch != bought.nativeStationRuntimeEpoch)
    var oldEpoch = loaded
    #expect(throws: EquipmentIssueError.staleObligation) {
      try oldEpoch.collectMemoryAtlasWatcherSource(coldQuote)
    }
    #expect(oldEpoch.commander == loaded.commander && oldEpoch.memoryAtlasWatcherSourceProjection == original)
    let collected = try await fixture.confirm(.collectReference)
    #expect(collected.memoryAtlasWatcherSourceProjection?.original == original.original)
    #expect(collected.memoryAtlasWatcherSourceProjection?.sourceRevision == 2)
  }

  @Test func currentCopyCodecAndMissingContentRetainTheSameOriginalLoan() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let source = try #require(collected.memoryAtlasWatcherSourceProjection)
    let instance = try #require(collected.memoryAtlasMission)
    let obligations = try collected.commander.equipmentIssueObligations()
    let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(collected.commander))
    #expect(decoded == collected.commander && decoded.savedMemoryAtlasWatcherSource == source.source)
    #expect(decoded.scriptState.instances[instance.id] == instance)
    var detached = collected.commander
    detached.savedMemoryAtlasWatcherSource = nil
    #expect(detached != collected.commander && collected.commander.savedMemoryAtlasWatcherSource == source.source)
    #expect(!NativeMemoryAtlasWatcherSourceSave.validateClaims(detached))
    var detachedCase = instance
    detachedCase.savedMemoryAtlas = nil
    #expect(detachedCase != instance && instance.savedMemoryAtlas != nil)
    try await fixture.runtime.save(to: fixture.files.save)
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(cold.savedMemoryAtlasWatcherSource == source.source)
    #expect(cold.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try cold.equipmentIssueObligations() == obligations)
    var missing = collected
    missing.scriptPacks = []
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)
    let withoutContent = GameRuntime(game: missing, saveURL: fixture.files.save)
    try await withoutContent.load(from: fixture.files.save, persistMigrations: false)
    let restored = await withoutContent.snapshot()
    let retained = try #require(restored.memoryAtlasMission)
    #expect(retained.suspension != nil && retained.savedMemoryAtlas == instance.savedMemoryAtlas)
    #expect(restored.memoryAtlasWatcherSourceProjection == source)
    #expect(restored.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try restored.commander.equipmentIssueObligations() == obligations)
    #expect(restored.memoryAtlasWatcherSourceQuote() == nil)
    #expect(NativeMemoryAtlasWatcherSourceSave.validateClaims(restored.commander))
    let entry = try #require(restored.memoryAtlasMissingGalleryEntry(retained))
    #expect(entry.status == .locked && entry.completed == 0 && entry.trialDigest == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
    // Even re-presented content cannot turn a retained suspended case into a live quote.
    var suspended = restored
    suspended.scriptPacks = collected.scriptPacks
    #expect(suspended.memoryAtlasWatcherSourceQuote() == nil)
    #expect(suspended.commander == restored.commander)
  }

  @Test func rehashedSourceArchivesRefuseTamperingWithoutChangingLiveStateOrFiles() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let source = try #require(collected.memoryAtlasWatcherSourceProjection)
    let pointerBytes = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let commanderURL = directory.appendingPathComponent("commander.json")
    let missionsURL = directory.appendingPathComponent("missions.json")
    let commanderBytes = try Data(contentsOf: commanderURL)
    let missionsBytes = try Data(contentsOf: missionsURL)
    let root = try #require(JSONSerialization.jsonObject(with: commanderBytes) as? [String: Any])
    let leaf = try #require(root[NativeMemoryAtlasWatcherSourceSave.field] as? [String: Any])
    let control = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save).0
    try #require(control.savedMemoryAtlasWatcherSource == source.source)
    defer {
      try? commanderBytes.write(to: commanderURL, options: .atomic)
      try? missionsBytes.write(to: missionsURL, options: .atomic)
      try? pointerBytes.write(to: fixture.files.save, options: .atomic)
    }
    func mutated(_ change: (inout [String: Any]) throws -> Void) throws -> Data {
      var value = root
      try change(&value)
      return try JSONSerialization.data(withJSONObject: value)
    }
    let missing = try mutated { _ = $0.removeValue(forKey: NativeMemoryAtlasWatcherSourceSave.field) }
    let null = try mutated { $0[NativeMemoryAtlasWatcherSourceSave.field] = NSNull() }
    let extra = try mutated { value in
      var changed = leaf
      var initialization = try #require(changed["initialization"] as? [String: Any])
      initialization["fabricatedPermission"] = true
      changed["initialization"] = initialization
      value[NativeMemoryAtlasWatcherSourceSave.field] = changed
    }
    let reset = try mutated { value in
      var changed = leaf
      changed["sourceRevision"] = 1
      changed["custody"] = "available"
      changed.removeValue(forKey: "transfer")
      value[NativeMemoryAtlasWatcherSourceSave.field] = changed
    }
    let originalText = try #require(String(data: commanderBytes, encoding: .utf8))
    let key = "\"savedMemoryAtlasWatcherSource\":"
    let range = try #require(originalText.range(of: key))
    var duplicate = originalText
    duplicate.replaceSubrange(range, with: key + "null," + key)
    var misplaced = try #require(JSONSerialization.jsonObject(with: missionsBytes) as? [String: Any])
    misplaced[NativeMemoryAtlasWatcherSourceSave.field] = leaf
    let badMissions = try JSONSerialization.data(withJSONObject: misplaced)
    let corruptions = [
      ("commander.json", missing), ("commander.json", null), ("commander.json", extra),
      ("commander.json", reset), ("commander.json", Data(duplicate.utf8)),
      ("missions.json", badMissions),
    ]
    for (name, bytes) in corruptions {
      try commanderBytes.write(to: commanderURL, options: .atomic)
      try missionsBytes.write(to: missionsURL, options: .atomic)
      try bytes.write(to: directory.appendingPathComponent(name), options: .atomic)
      var hashRoot = try #require(JSONSerialization.jsonObject(with: pointerBytes) as? [String: Any])
      var hashes = try #require(hashRoot["hashes"] as? [String: String])
      hashes[name] = ScriptPackLibrary.hash(bytes)
      hashRoot["hashes"] = hashes
      let badPointer = try JSONSerialization.data(withJSONObject: hashRoot)
      try badPointer.write(to: fixture.files.save, options: .atomic)
      let before = await fixture.runtime.snapshot()
      let world = before.scriptWorldSave
      let files = try ScriptFinanceTestFixture.files(fixture.files.root)
      await #expect(throws: SaveError.invalidCommander) {
        try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
      }
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == before.commander && refused.bodies == before.bodies)
      #expect(refused.memoryAtlasWatcherSourceProjection == source)
      #expect(refused.scriptWorldSave == world)
      #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
      #expect(refused.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
      #expect(try Data(contentsOf: fixture.files.save) == badPointer)
    }
    try commanderBytes.write(to: commanderURL, options: .atomic)
    try missionsBytes.write(to: missionsURL, options: .atomic)
    try pointerBytes.write(to: fixture.files.save, options: .atomic)
    let restored = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save).0
    #expect(restored.savedMemoryAtlasWatcherSource == source.source)
  }
}


private extension MemoryAtlasOpeningFixture {
  /// Same controlled remote setup as the opening fixture, stopped before real entry.
  /// The original physics producer must mint the ephemeral witness; this helper cannot.
  static func beforeFirstArrival(files: ScriptFreightFixture) async throws -> Game {
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: files.save)
    let born = await boot.snapshot()
    try #require(born.nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
    try game.departOrdinarySimulation()
    let issuer = NativeMemoryAtlasDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledMemoryAtlasDirectory)]
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
    try #require(game.commander.savedMemoryAtlasWatcherSource == nil)
    return game
  }
}

extension NativeMemoryAtlasOpeningUnitTests {
  @Test func firstActualArrivalWriterFailureRetainsUnpublishedEntryAndRetriesOnce() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let approach = try await MemoryAtlasOpeningFixture.beforeFirstArrival(files: files)
    let runtime = GameRuntime(game: approach, saveURL: files.save)
    let directory = files.save.deletingLastPathComponent()
    let originalFiles = try ScriptFinanceTestFixture.files(directory)
    let held = try files.blockWrites("memory-atlas-first-arrival")
    // The same live actor must attain and retain its own ephemeral entry witness.
    // A new GameRuntime intentionally discards authority captured before its lifetime.
    var game = await runtime.snapshot()
    for _ in 0..<100 {
      if game.pendingMemoryAtlasMainDock != nil { break }
      game = await runtime.advance(delta: 0.05)
    }
    let proof = try #require(game.pendingMemoryAtlasMainDock)
    try #require(!game.docked && game.commander.savedMemoryAtlasWatcherSource == nil)
    try #require(game.commander.nativeStations?.currentMainDock == nil)
    let before = game
    let writer = MemoryAtlasArrivalWriterObservation()
    do {
      try game.commitPendingMemoryAtlasMainArrival { candidate in
        try #require(candidate.docked && candidate.nativeMainStationDockEvidenceIsCurrent)
        let source = try #require(candidate.commander.savedMemoryAtlasWatcherSource)
        try #require(source.custody == .available && source.sourceRevision == 1)
        try #require(source.initialization.dock == proof.receipt)
        try #require(candidate.commander.nativeStations?.nextMainDockSequence == proof.receipt.sequence + 1)
        writer.recordAttempt()
        try GameRuntime.writeCommander(&candidate, to: files.save)
      }
      Issue.record("Blocked first-arrival writer unexpectedly returned")
    } catch {
      #expect(try Data(contentsOf: directory) == Data([1]))
    }
    // A producer refusal cannot masquerade as the expected filesystem failure.
    try #require(writer.attempts == 1)
    #expect(game.commander == before.commander)
    #expect(game.scriptWorldSave == before.scriptWorldSave && game.bodies == before.bodies)
    #expect(game.docked == before.docked && game.speed == before.speed)
    #expect(game.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(game.pendingMemoryAtlasMainDock?.receipt == proof.receipt)
    #expect(try ScriptFinanceTestFixture.files(held) == originalFiles)
    let failedRetry = await runtime.advance(delta: 60)
    #expect(failedRetry.commander == before.commander)
    #expect(failedRetry.scriptWorldSave == before.scriptWorldSave)
    #expect(failedRetry.pendingMemoryAtlasMainDock?.receipt == proof.receipt)
    #expect(try ScriptFinanceTestFixture.files(held) == originalFiles)
    try files.restoreWrites(held, files: originalFiles)
    game = await runtime.advance(delta: 60)
    let source = try #require(game.commander.savedMemoryAtlasWatcherSource)
    #expect(source.original == NativeMemoryAtlasWatcherSource.original(owner: source.owner))
    #expect(source.initialization.dock == proof.receipt && source.custody == .available)
    #expect(game.pendingMemoryAtlasMainDock == nil && game.nativeMainStationDockEvidenceIsCurrent)
    #expect(game.commander.nativeStations?.nextMainDockSequence == proof.receipt.sequence + 1)
    #expect(game.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(game.commander.scriptState.nextEvent >= source.initialization.eventSequence)
    #expect(game.commander.flightSimulation.physicalTime == before.commander.flightSimulation.physicalTime)
    #expect(game.commander.scriptState.calendarSeconds == before.commander.scriptState.calendarSeconds)
    let persisted = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save).0
    #expect(persisted.savedMemoryAtlasWatcherSource == source)
    try await runtime.load(from: files.save, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander.savedMemoryAtlasWatcherSource == source)
    #expect(restored.memoryAtlasWatcherSourceProjection?.available == true)
    #expect(restored.commander.nativeStations?.nextMainDockSequence == proof.receipt.sequence + 1)
  }
}


/// Observation of writer invocation only; it supplies no game, geometry or source authority.
private final class MemoryAtlasArrivalWriterObservation: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var attempts: Int { lock.withLock { count } }
  func recordAttempt() { lock.withLock { count += 1 } }
}


extension NativeMemoryAtlasOpeningUnitTests {
  @Test func currentSourceRawGateRejectsNumericCoercionMisplacementAndOversizedLeaves() async throws {
    let fixture = try await MemoryAtlasOpeningFixture(buy: false)
    defer { fixture.clean() }
    let arrived = await fixture.runtime.snapshot()
    let source = try #require(arrived.commander.savedMemoryAtlasWatcherSource)
    let encoded = try JSONEncoder().encode(source)
    let leaf = try #require(String(data: encoded, encoding: .utf8))
    let field = NativeMemoryAtlasWatcherSourceSave.field
    let key = "\"" + field + "\":"
    let root = "{" + key + leaf + "}"
    try NativeMemoryAtlasWatcherEnvelope.validateFields(
      Data(root.utf8), location: .commander, schema: NativeMemoryAtlasWatcherEnvelope.version)
    for schema in [nil, 139, 140, 141, 142] as [Int?] {
      #expect(throws: SaveError.invalidCommander) {
        try NativeMemoryAtlasWatcherEnvelope.validateFields(
          Data(root.utf8), location: .commander, schema: schema)
      }
    }
    for location in [ScriptSaveJSONPreflight.InquiryArchiveLocation.pointer, .missions, .world, .contracts] {
      #expect(throws: SaveError.invalidCommander) {
        try NativeMemoryAtlasWatcherEnvelope.validateFields(
          Data(root.utf8), location: location, schema: NativeMemoryAtlasWatcherEnvelope.version)
      }
    }
    let revision = "\"sourceRevision\":1"
    try #require(leaf.contains(revision))
    let numberSpellings = ["1.0", "1e0", "18446744073709551616", "true", "\"1\""]
    var malformed = numberSpellings.map {
      "{" + key + leaf.replacingOccurrences(of: revision, with: "\"sourceRevision\":" + $0) + "}"
    }
    malformed.append("{\"nested\":{" + key + leaf + "}}")
    // Escaped and plain spellings are the same key and must fail before Foundation decoding.
    malformed.append("{" + key + leaf + ",\"savedMemoryAtlasWatcherSourc\\u0065\":" + leaf + "}")
    malformed.append("{" + key + String(leaf.dropLast()) + String(repeating: " ", count: 32769) + "}}")
    malformed.append("{}")
    malformed.append("{" + key + "null}")
    for raw in malformed {
      #expect(throws: SaveError.invalidCommander) {
        try NativeMemoryAtlasWatcherEnvelope.validateFields(
          Data(raw.utf8), location: .commander, schema: NativeMemoryAtlasWatcherEnvelope.version)
      }
    }
    #expect(arrived.commander.savedMemoryAtlasWatcherSource == source)
  }
}

extension NativeMemoryAtlasSourceConservationUnitTests {
  @Test func lexicalSourceGateClosesEveryNestedObjectBeforeFoundationDecoding() async throws {
    let fixture = try await MemoryAtlasOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let source = try #require(collected.commander.savedMemoryAtlasWatcherSource)
    let data = try JSONEncoder().encode(source)
    let leaf = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let field = NativeMemoryAtlasWatcherSourceSave.field
    let valid = try JSONSerialization.data(withJSONObject: [field: leaf])
    let extracted = try ScriptSaveJSONPreflight.extractMemoryAtlasWatcherSource(
      valid, location: .commander, permitsRoot: true)
    try #require(extracted != nil)
    let paths = [
      [String](), ["initialization"], ["initialization", "dock"],
      ["initialization", "dock", "station"], ["initialization", "dock", "station", "system"],
      ["initialization", "dock", "actor"], ["initialization", "dock", "actor", "system"],
      ["station"], ["node"], ["node", "family"], ["transfer"],
      ["transfer", "collection"], ["transfer", "collection", "facts"],
      ["transfer", "collection", "facts", "source"],
    ]
    func replacing(_ object: [String: Any], path: ArraySlice<String>,
      change: ([String: Any]) throws -> [String: Any]) throws -> [String: Any] {
      guard let key = path.first else { return try change(object) }
      var copy = object
      let child = try #require(copy[key] as? [String: Any])
      copy[key] = try replacing(child, path: path.dropFirst(), change: change)
      return copy
    }
    for path in paths {
      for missing in [false, true] {
        let changed = try replacing(leaf, path: path[...]) { object in
          var result = object
          if missing {
            // transfer is the sole optional field; always remove a required key.
            let key = try #require(result.keys.sorted().first { $0 != "transfer" })
            result.removeValue(forKey: key)
          } else { result["unissuedAuthority"] = true }
          return result
        }
        let raw = try JSONSerialization.data(withJSONObject: [field: changed])
        // Invoke only the lexical gate. A later Foundation decoder cannot satisfy this refusal.
        #expect(throws: SaveError.invalidCommander) {
          _ = try ScriptSaveJSONPreflight.extractMemoryAtlasWatcherSource(
            raw, location: .commander, permitsRoot: true)
        }
      }
    }
  }
}

private extension MemoryAtlasOpeningFixture {
  /// Controlled remote visits and approach, not a flown route. Actual generated-site
  /// admission and the existing native retainer create world history; no lot, hardware or receipt is made here.
  static func retainActualGeneratedWreckForAlienStorage(_ game: inout Game) throws {
    for system in 0..<256 {
      try game.departOrdinarySimulation()
      game.commander.system = system
      game.selectedSystem = system
      game.bodies = []
      game.resetCelestialFlight()
      let began = game.beginGameplayVisit(arriving: true)
      try #require(began)
      guard let site = game.salvageSites.first else { continue }
      NativeStationTestFixture.reframe(&game,
        to: .init(position: site.position + Vector3(0, 0, 2000)))
      game.activateNearbySalvageSites()
      let actor = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
      // Existing native retention validates this actual admitted actor against its generated site.
      // It creates native world history only, with no cutting/collection or owned hardware claim.
      let didRetain = game.retainNativeSalvageWreck(actor)
      try #require(didRetain)
      let retained = try #require(game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
      try #require(retained.binding == actor.physical?.identity)
      try #require(retained.catalogueShipID == site.catalogueShipID)
      try #require(game.commander.usesAlienStorageSaveVersion && game.commander.valid)
      return
    }
    throw SaveError.invalidCommander
  }

  static func returnToRerisBeforeActualEntry(_ game: inout Game) throws {
    let persisted = game.persistSalvagePoses()
    try #require(persisted)
    let parked = game.flushNativeSalvageMotion(parkingSystem: game.systemIdentity)
    try #require(parked)
    try game.departOrdinarySimulation()
    let issuer = NativeMemoryAtlasDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let began = game.beginGameplayVisit(arriving: true)
    try #require(began)
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
  }
}

struct NativeMemoryAtlasEnvelopeCompositionUnitTests {
  @Test func humanWatcherAndActualInquiryRetainTradeAndRefuseRehashedInvalidClaims() async throws {
    try await composition(retainingGeneratedAlienWorld: false)
  }

  @Test func alienWatcherAndActualInquiryRetainNativeWorldAndRefuseWrongRootsAndNamespaces() async throws {
    try await composition(retainingGeneratedAlienWorld: true)
  }

  private func composition(retainingGeneratedAlienWorld alien: Bool) async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    var game = try await MemoryAtlasOpeningFixture.beforeFirstArrival(files: files)
    if alien {
      try MemoryAtlasOpeningFixture.retainActualGeneratedWreckForAlienStorage(&game)
      try MemoryAtlasOpeningFixture.returnToRerisBeforeActualEntry(&game)
    }
    let runtime = GameRuntime(game: game, saveURL: files.save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.commander.usesAlienStorageSaveVersion == alien)
    let source = try #require(arrived.commander.savedMemoryAtlasWatcherSource)
    try await MemoryAtlasOpeningFixture.buyOne(runtime)
    // Existing genuine desk/UI/writer oracle requests the institutional source and case.
    try await c01InquiryJournalActualWriterRollbackOracle(runtime: runtime, files: files)
    try await runtime.save(to: files.save)
    let saved = await runtime.snapshot()
    let inquiry = try #require(saved.commander.scriptState.savedC01Inquiry)
    let trade = try #require(saved.commander.scriptState.firstNativeCommodityTrade)
    let bytes = try Data(contentsOf: files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 144 : 143))
    #expect(pointer.hashes.count == (alien ? 5 : 4))
    #expect((pointer.hashes[AlienStorageVersionedSave.rootName] != nil) == alien)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: files.save)
    let header = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
    let unhydrated = try ScriptValueStorage.decoder(typed: true).decode(Commander.self, from: header)
    #expect((unhydrated.savedAlienStorageReference != nil) == alien)
    if alien {
      #expect(!unhydrated.alienStorageStateValid)
      #expect(pointer.hashes[AlienStorageVersionedSave.rootName] == saved.commander.savedAlienStorageReference?.rootHash)
    }
    let (cold, world) = try ScriptSaveStore.read(bytes, from: files.save)
    #expect(cold.savedMemoryAtlasWatcherSource == source)
    #expect(cold.scriptState.savedC01Inquiry == inquiry && cold.scriptState.firstNativeCommodityTrade == trade)
    #expect(cold.alienStorageState?.current.snapshot == saved.commander.alienStorageState?.current.snapshot)
    #expect(world == saved.scriptWorldSave)
    try await runtime.load(from: files.save, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.savedMemoryAtlasWatcherSource == source)
    #expect(loaded.commander.scriptState.savedC01Inquiry == inquiry)
    #expect(loaded.commander.scriptState.firstNativeCommodityTrade == trade)
    #expect(loaded.commander.alienStorageState?.current.snapshot == cold.alienStorageState?.current.snapshot)
    try await refuseArchiveChanges(runtime: runtime, files: files, pointerBytes: bytes, directory: directory, alien: alien)
  }

  private func refuseArchiveChanges(runtime: GameRuntime, files: ScriptFreightFixture,
    pointerBytes: Data, directory: URL, alien: Bool) async throws {
    let pointer = try #require(JSONSerialization.jsonObject(with: pointerBytes) as? [String: Any])
    let schemaVersion = try #require(pointer["schemaVersion"] as? Int)
    let originalHashes = try #require(pointer["hashes"] as? [String: String])
    let missionsURL = directory.appendingPathComponent("missions.json")
    let originalMissions = try Data(contentsOf: missionsURL)
    let root = try #require(JSONSerialization.jsonObject(with: originalMissions) as? [String: Any])
    let rootURL = directory.appendingPathComponent(AlienStorageVersionedSave.rootName)
    let originalAlienRoot: Data?
    if alien { originalAlienRoot = try Data(contentsOf: rootURL) }
    else { originalAlienRoot = nil }
    var corruptions: [(String?, Data?, [String: Any])] = []
    for schema in [139, 140, 141, 142, alien ? 143 : 144] {
      var changed = pointer
      changed["schemaVersion"] = schema
      corruptions.append((nil, nil, changed))
    }
    var wrongRoot = pointer
    var hashes = originalHashes
    if alien { hashes.removeValue(forKey: AlienStorageVersionedSave.rootName) }
    else { hashes[AlienStorageVersionedSave.rootName] = String(repeating: "a", count: 64) }
    wrongRoot["hashes"] = hashes
    corruptions.append((nil, nil, wrongRoot))
    if alien {
      hashes = originalHashes
      hashes[AlienStorageVersionedSave.rootName] = String(repeating: "b", count: 64)
      var wrongHash = pointer
      wrongHash["hashes"] = hashes
      corruptions.append((nil, nil, wrongHash))
      let invalidRoot = Data("{}".utf8)
      hashes = originalHashes
      hashes[AlienStorageVersionedSave.rootName] = ScriptPackLibrary.hash(invalidRoot)
      var rehashedRoot = pointer
      rehashedRoot["hashes"] = hashes
      corruptions.append((AlienStorageVersionedSave.rootName, invalidRoot, rehashedRoot))
      var changedHeader = try #require(JSONSerialization.jsonObject(
        with: Data(contentsOf: directory.appendingPathComponent("commander.json"))) as? [String: Any])
      changedHeader.removeValue(forKey: "savedAlienStorageReference")
      let data = try JSONSerialization.data(withJSONObject: changedHeader)
      hashes = originalHashes
      hashes["commander.json"] = ScriptPackLibrary.hash(data)
      var changedPointer = pointer
      changedPointer["hashes"] = hashes
      corruptions.append(("commander.json", data, changedPointer))
    }
    for field in ["savedC01Inquiry", NativeFirstCommodityTradeSave.field] {
      var changedRoot = root
      var claim = try #require(changedRoot[field] as? [String: Any])
      claim["unissuedAuthority"] = true
      changedRoot[field] = claim
      let data = try JSONSerialization.data(withJSONObject: changedRoot)
      hashes = originalHashes
      hashes["missions.json"] = ScriptPackLibrary.hash(data)
      var changedPointer = pointer
      changedPointer["hashes"] = hashes
      corruptions.append(("missions.json", data, changedPointer))
    }
    let originalHeader = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
    defer {
      try? originalMissions.write(to: missionsURL, options: .atomic)
      try? originalHeader.write(to: directory.appendingPathComponent("commander.json"), options: .atomic)
      try? originalAlienRoot?.write(to: rootURL, options: .atomic)
      try? pointerBytes.write(to: files.save, options: .atomic)
    }
    for (index, corruption) in corruptions.enumerated() {
      let (name, data, changedPointer) = corruption
      try originalMissions.write(to: missionsURL, options: .atomic)
      try originalHeader.write(to: directory.appendingPathComponent("commander.json"), options: .atomic)
      try originalAlienRoot?.write(to: rootURL, options: .atomic)
      if let name, let data { try data.write(to: directory.appendingPathComponent(name), options: .atomic) }
      let badPointer = try JSONSerialization.data(withJSONObject: changedPointer)
      try badPointer.write(to: files.save, options: .atomic)
      let before = await runtime.snapshot()
      let retainedFiles = try ScriptFinanceTestFixture.files(files.root)
      await #expect(throws: SaveError.invalidCommander,
        "Archive schema \(schemaVersion), corruption \(index), part \(name ?? "pointer")")
      {
        try await runtime.load(from: files.save, persistMigrations: false)
      }
      let refused = await runtime.snapshot()
      #expect(refused.commander == before.commander && refused.bodies == before.bodies)
      #expect(refused.scriptWorldSave == before.scriptWorldSave)
      #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
      #expect(refused.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(try ScriptFinanceTestFixture.files(files.root) == retainedFiles)
    }
  }
}
