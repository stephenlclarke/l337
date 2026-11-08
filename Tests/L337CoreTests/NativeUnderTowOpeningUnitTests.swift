import Foundation
import Testing

@testable import L337Core

/// Controlled remote location, NOT a flown route. Bootstrap, swept native berth entry,
/// ordinary purchase, board confirmation and current writer use their real producers.
/// No trade, item, stock, acceptance or live contact receipt is injected. UNRUN.
final class UnderTowOpeningFixture {
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
    let issuer = NativeUnderTowDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledUnderTowDirectory)]
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
    try #require(arrived.systemIdentity == issuer && arrived.underTowPack != nil)
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

  func review(_ action: NativeUnderTowAction) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.underTow == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.underTow == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.underTowQuote?.action == action)
    return detail
  }

  func confirm(_ action: NativeUnderTowAction) async throws -> Game {
    let detail = try await review(action)
    try #require(detail.contractBoard.underTowQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    let instance = try #require(result.underTowMission)
    if action == .collectReference { try #require(instance.savedUnderTow?.collection != nil) }
    return result
  }
}

struct NativeUnderTowOpeningUnitTests {
  @Test func purchaseOnlyCommissionAndSeparateOriginalCollectionSurviveCurrentColdLoad() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    try #require(preview.contractBoard.underTowQuote?.allowed == true)
    let inventory = try #require(preview.commander.equipmentInventory)
    try #require(preview.underTowMission == nil)
    await fixture.runtime.key("right")
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let commission = try #require(accepted.underTowMission)
    let acceptance = try #require(commission.savedUnderTow)
    #expect(acceptance.collection == nil && commission.gearIssues.isEmpty)
    #expect(commission.receipts == [NativeUnderTowDefinition.acceptReceipt])
    #expect(commission.milestones == [0] && commission.journal == NativeUnderTowDefinition.briefing)
    #expect(accepted.commander.equipmentInventory == inventory)
    #expect(accepted.commander.credits == preview.commander.credits)
    #expect(accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativeUnderTowSave.validateClaims(accepted.commander))
    let acceptedCold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(acceptedCold.scriptState.instances[commission.id]?.savedUnderTow == acceptance)

    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.underTowMission)
    let state = try #require(instance.savedUnderTow)
    let collection = try #require(state.collection)
    let loan = try NativeUnderTowCustody.resolve(instance: instance, commander: collected.commander)
    #expect(state.acceptance == acceptance.acceptance && instance.id == commission.id)
    #expect(instance.milestones == [0, 1] && instance.receipts.count == 2)
    #expect(instance.outcome == .active && instance.completionReceipt == nil)
    #expect(collection.facts.original == NativeUnderTowReferenceDefinition.serial(mission: instance.id))
    #expect(collection.facts.afterCargoTonnes == collection.facts.beforeCargoTonnes + 1)
    #expect(collection.facts.afterInventoryRevision == inventory.revision + 1)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.cargo == accepted.commander.cargo)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
    #expect(NativeUnderTowSave.validateClaims(collected.commander))
    try await fixture.runtime.save(to: fixture.files.save)
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    let coldInstance = try #require(cold.scriptState.instances[instance.id])
    #expect(coldInstance.savedUnderTow == state)
    #expect(try NativeUnderTowCustody.resolve(instance: coldInstance, commander: cold) == loan)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    let loadedInstance = try #require(loaded.underTowMission)
    #expect(loadedInstance.savedUnderTow == state)
    #expect(loaded.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try NativeUnderTowCustody.resolve(instance: loadedInstance, commander: loaded.commander) == loan)
    #expect(loaded.nativeStationRuntimeEpoch != collected.nativeStationRuntimeEpoch)
    #expect(!loaded.underTowReview(.collectReference).allowed)
    #expect(NativeUnderTowSave.validateClaims(loaded.commander))
  }

  @Test func noTradeBackAndStalePurchaseReviewCannotAccept() async throws {
    let fixture = try await UnderTowOpeningFixture(buy: false)
    defer { fixture.clean() }
    let blocked = try await fixture.review(.accept)
    #expect(blocked.contractBoard.underTowQuote?.allowed == false)
    #expect(blocked.underTowMission == nil)
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.commander == blocked.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    try await UnderTowOpeningFixture.buyOne(fixture.runtime)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.underTowQuote)
    try #require(quote.allowed)
    try await UnderTowOpeningFixture.buyOne(fixture.runtime)
    let changed = await fixture.runtime.snapshot()
    var stale = changed
    // Restore only the old transient screen for this negative check; no source is injected.
    stale.screen = .contracts
    stale.contractBoard = chosen.contractBoard
    let unchanged = stale.commander
    #expect(throws: MissionPackError.self) { try stale.confirmUnderTow(quote) }
    #expect(stale.commander == unchanged && stale.underTowMission == nil)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.underTowMission?.savedUnderTow?.collection == nil)
  }

  @Test func actualWriterRefusalRetainsIssuerOriginalAndRetriesOnce() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    for action in [NativeUnderTowAction.accept, .collectReference] {
      _ = try await fixture.review(action)
      await fixture.runtime.key("right")
      let before = await fixture.runtime.snapshot()
      let quote = try #require(before.contractBoard.underTowQuote)
      try #require(quote.allowed)
      let directory = fixture.files.save.deletingLastPathComponent()
      let files = try ScriptFinanceTestFixture.files(directory)
      let held = try fixture.files.blockWrites("under-tow-" + action.rawValue)
      await #expect(throws: (any Error).self) {
        try await fixture.runtime.scriptCommand { candidate in
          // A producer error is a test failure, not mistaken for the expected writer refusal.
          do { try candidate.confirmUnderTow(quote) }
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
      let instance = try #require(committed.underTowMission)
      if action == .accept {
        #expect(instance.savedUnderTow?.collection == nil && instance.gearIssues.isEmpty)
      } else {
        let state = try #require(instance.savedUnderTow?.collection)
        #expect(instance.gearIssues.count == 1)
        #expect(state.facts.afterInventoryRevision == state.facts.beforeInventoryRevision + 1)
        _ = try NativeUnderTowCustody.resolve(instance: instance, commander: committed.commander)
      }
      #expect(committed.commander.credits == before.commander.credits)
      #expect(committed.commander.cargo == before.commander.cargo)
      #expect(committed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
      #expect(NativeUnderTowSave.validateClaims(committed.commander))
      var repeated = before
      repeated.commander = committed.commander
      #expect(throws: MissionPackError.self) { try repeated.confirmUnderTow(quote) }
      #expect(repeated.commander == committed.commander)
    }
  }

  @Test func genuineIssueCommandCannotMasqueradeAsTheOrdinaryTrade() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.underTowMission)
    let state = try #require(instance.savedUnderTow)
    let issue = try #require(state.collection)
    let original = state.acceptance
    try #require(original.ordinaryTrade != issue.facts.issueCommand)
    // Deliberately false causal link made from two ACTUAL operation identities.
    let wrong = NativeUnderTowAcceptanceFacts(mission: original.mission, owner: original.owner,
      carrier: original.carrier, inventoryRevision: original.inventoryRevision, dock: original.dock,
      ordinaryTrade: issue.facts.issueCommand, eventSequence: original.eventSequence,
      physicalTime: original.physicalTime, calendarSeconds: original.calendarSeconds)
    var falseState = try NativeUnderTowState(acceptance: wrong)
    falseState.collection = issue
    try #require(falseState.shapeValid)
    var invalid = collected
    invalid.commander.scriptState.instances[instance.id]?.savedUnderTow = falseState
    #expect(!NativeUnderTowSave.validateClaims(invalid.commander))
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    #expect(throws: (any Error).self) {
      try GameRuntime.writeCommander(&invalid, to: fixture.files.save)
    }
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    #expect(NativeUnderTowSave.validateClaims(collected.commander))
  }

  @Test func genericAcceptanceAndCommandsCannotGrantCustodyProgressOrPayment() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.underTowPack)
    let before = game.commander
    #expect(!NativeUnderTowDefinition.applies(fixture.files.pack))
    #expect(game.underTowGalleryEntry(fixture.files.pack) == nil)
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.underTowMission == nil)
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.underTowMission)
    let saved = try #require(instance.savedUnderTow)
    // This replay uses the real historical sequence but is NOT a pending live event.
    let event = ScriptEvent(sequence: saved.acceptance.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("success")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(2)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(83000)]),
      .object(["op": .string("payload.add"), "id": .string("false-reference"), "tonnes": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeUnderTowDefinition.briefing[0])]),
    ]
    for command in commands {
      var state = instance
      var candidate = accepted.commander
      #expect(throws: (any Error).self) {
        try accepted.applyScriptCommand(command, event: event, pack: pack, state: &state, candidate: &candidate)
      }
      #expect(state == instance && candidate == accepted.commander)
    }
    #expect(NativeUnderTowSave.validateClaims(accepted.commander))
  }
}

struct NativeUnderTowGalleryUnitTests {
  private func entry(_ game: Game) throws -> GalleryMission {
    let pack = try #require(game.underTowPack)
    let owned = try #require(game.underTowGalleryEntry(pack))
    let visible = game.scriptGallery.filter { $0.name == "Under Tow" }
    try #require(visible.count == 1)
    #expect(visible[0].status == owned.status && visible[0].objective == owned.objective)
    #expect(visible[0].completed == owned.completed && visible[0].savedInstance == owned.savedInstance)
    #expect(visible[0].trialDigest == nil && owned.trialDigest == nil)
    #expect(visible[0].milestones.map(\.title) == owned.milestones.map(\.title))
    #expect(visible[0].milestones.map(\.state) == owned.milestones.map(\.state))
    return owned
  }

  @Test func genuinePurchaseOpensOnlyCommissionAndGalleryInputRemainsReadOnly() async throws {
    let fixture = try await UnderTowOpeningFixture(buy: false)
    defer { fixture.clean() }
    let noTrade = await fixture.runtime.snapshot()
    let locked = try entry(noTrade)
    #expect(locked.status == .locked && locked.completed == 0 && locked.savedInstance == nil)
    #expect(locked.milestones.count == 9 && locked.milestones[0].state == "Upcoming")
    #expect(locked.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    try await UnderTowOpeningFixture.buyOne(fixture.runtime)
    let bought = await fixture.runtime.snapshot()
    let available = try entry(bought)
    #expect(available.status == .available && available.completed == 0)
    #expect(available.prerequisites.isEmpty && available.savedInstance == nil)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    await fixture.runtime.nativeCommand { game in
      game.screen = .status
      game.openGallery()
      if let index = game.missionCatalogue.firstIndex(where: { $0.name == "Under Tow" }) {
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
    #expect(closed.commander == bought.commander && closed.underTowMission == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
  }

  @Test func acceptanceAndOriginalLoanHaveSeparateHistoryWithoutQualifyingAnySurvey() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let first = try entry(accepted)
    #expect(first.status == .active && first.completed == 1)
    #expect(first.milestones[0].state == "Complete" && first.milestones[1].state == "Current")
    #expect(first.briefing.contains("Penn retains the original instrument"))
    #expect(first.destination == "Luera / Galaxy 8")
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.underTowMission)
    let loan = try NativeUnderTowCustody.resolve(instance: instance, commander: collected.commander)
    let before = collected.commander
    let second = try entry(collected)
    #expect(second.status == .locked && second.completed == 2 && second.savedInstance == instance.id)
    #expect(second.milestones.prefix(2).allSatisfy { $0.state == "Complete" })
    #expect(second.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    #expect(second.destination == "Allion / Galaxy 8")
    #expect(second.briefing.contains("same original reference instrument is aboard"))
    #expect(second.briefing.contains("12 uninterrupted seconds"))
    #expect(second.objective.contains("not currently available"))
    #expect(second.trialDigest == nil && instance.outcome == .active)
    #expect(instance.completionReceipt == nil && instance.milestones == [0, 1])
    #expect(collected.commander == before)
    #expect(try NativeUnderTowCustody.resolve(instance: instance, commander: collected.commander) == loan)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
  }

  @Test func currentColdLoadPreservesOnlyActualOpeningHistoryAndNoTrialAction() async throws {
    let fixture = try await UnderTowOpeningFixture()
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
    #expect(restored.underTowMission?.savedUnderTow == collected.underTowMission?.savedUnderTow)
    #expect(restored.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(restored.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
  }

  @Test func falseCountsMissingOriginalItemAndMissingPackNeverAdvertiseCompletion() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.underTowMission)
    let state = try #require(instance.savedUnderTow)
    let collection = try #require(state.collection)
    let pack = try #require(collected.underTowPack)
    for complete in [false, true] {
      var invalid = collected
      invalid.commander.scriptState.instances[instance.id]?.milestones = Set(0..<9)
      if complete { invalid.commander.scriptState.instances[instance.id]?.outcome = .complete }
      let before = invalid.commander
      let page = try #require(invalid.underTowGalleryEntry(pack))
      #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
      #expect(page.reward == "No settlement available." && invalid.commander == before)
    }
    var missingItem = collected
    if let inventory = missingItem.commander.savedEquipmentInventory {
      missingItem.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.id != collection.facts.original })
    }
    let missingPage = try #require(missingItem.underTowGalleryEntry(pack))
    #expect(missingPage.status == .locked && missingPage.completed == 0)
    #expect(missingItem.commander.scriptState.instances[instance.id]?.savedUnderTow == state)
    var missingPack = collected
    missingPack.scriptPacks = []
    let before = missingPack.commander
    let page = try #require(missingPack.underTowMissingGalleryEntry(instance))
    #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
    #expect(page.savedInstance == instance.id && page.objective.contains("history remain recorded"))
    let visible = missingPack.scriptGallery.filter { $0.savedInstance == instance.id }
    try #require(visible.count == 1)
    #expect(visible[0].status == .locked && visible[0].completed == 0)
    #expect(missingPack.commander == before)
    #expect(NativeUnderTowSave.validateClaims(collected.commander))
  }
}
