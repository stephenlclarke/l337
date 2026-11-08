import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct NativeOriginalSurveyHullCancellationTests {
  @Test func actualEarnedHullExchangeCanCancelSurveyWithRollbackRetryAndColdTerminal() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    // This prerequisite earns the blueprint through paid EMP, evacuation, cutting and
    // physical intake. No test UUID, granted blueprint or synthetic hull replaces it.
    let runtime = try await NativeOkapiAcquisitionJourneyFixture.preparedExchangeRuntime(
      storage: storage)
    let pack = f.pack
    await runtime.nativeCommand { $0.scriptPacks = [pack] }
    await runtime.procurementRefuel()
    let departing = await runtime.snapshot()
    let systems = departing.systems
    let reach = departing.commander.fullTankJumpDistance
    let adjacency = systems.indices.map { from in
      systems.indices.filter { to in
        from != to && !systems[from].isPlugh && !systems[to].isPlugh
          && systems[from].distance(to: systems[to]) <= reach
      }
    }
    let route = try #require(
      NavigationRouteSearch.path(
        adjacency: adjacency, from: departing.commander.system, to: 7,
        edgeWeight: { _, _, _ in 1 }))
    try await f.base.flight.travel(runtime, path: route)
    await runtime.procurementRefuel()
    let atOffice = await runtime.snapshot()
    try #require(atOffice.nativeMainStationDockEvidenceIsCurrent)
    try #require(atOffice.contractStation == NativeOriginalSurvey.source)
    let otherActive = OriginalServiceReservationPolicy.activeCount(atOffice.commander.scriptState)
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    let accepted = await runtime.snapshot()
    let oldQuote = accepted.originalSurveyReview(.cancel)
    try #require(oldQuote.allowed && oldQuote.carrier == permission.carrier)
    try #require(accepted.commander.shipID == NewCommanderDefaults.shipID)
    let acquisition = try #require(accepted.commander.fleetBlueprintAcquisition(for: "SH029"))
    #expect(OriginalServiceReservationPolicy.activeCount(accepted.commander.scriptState) == otherActive + 1)

    await runtime.key("showroom-open")
    await runtime.key("/")
    for character in "SH029" { await runtime.key(String(character)) }
    await runtime.key("return")
    try #require(await runtime.snapshot().showroom.selection == "SH029")
    await runtime.key("showroom-trade")
    await runtime.key("right")
    let purchase = try #require(await runtime.snapshot().shipTradeQuote)
    try #require(purchase.allowed, Comment(rawValue: purchase.issues.joined(separator: "; ")))
    await runtime.key("return")
    let exchanged = await runtime.snapshot()
    try #require(exchanged.commander.shipID == "SH029" && exchanged.commander.valid)
    try #require(exchanged.commander.hullInstanceID != permission.carrier)
    #expect(exchanged.commander.equipmentOwnerID == source.owner)
    #expect(exchanged.commander.credits == purchase.balance)
    #expect(exchanged.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
    #expect(exchanged.originalSurveyState == source)
    #expect(exchanged.originalSurveyReview(.cancel).allowed)
    let receive = exchanged.originalSurveyReview(.receive)
    #expect(!receive.allowed && receive.issues.contains("Return with the same survey carrier."))

    // A quote painted for the previous carrier remains stale even though a fresh
    // cancellation is allowed. The existing context check must still refuse it.
    do {
      try await runtime.scriptCommand { game in try game.confirmOriginalSurvey(oldQuote) }
      Issue.record("A pre-exchange survey quote was accepted after the actual hull exchange.")
    } catch {}
    #expect(await runtime.snapshot().commander == exchanged.commander)

    await runtime.key("escape")
    await runtime.key("0")
    let launched = await runtime.snapshot()
    try #require(!launched.docked)
    #expect(!launched.originalSurveyReview(.cancel).allowed)
    try await f.base.flight.dock(runtime)
    let page = try await f.review(runtime, .cancel)
    let quote = try #require(await runtime.snapshot().contractBoard.surveyQuote)
    try #require(quote.allowed && quote.carrier != permission.carrier)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.scriptPageKey("return", expected: page)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.scriptWorldSave == before.scriptWorldSave)
    #expect(refused.contractBoard.surveyQuote?.reviewToken == quote.reviewToken)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    // Retry the same quote/page, not a new cancellation, after storage recovers.
    await runtime.scriptPageKey("return", expected: page)
    let done = await runtime.snapshot()
    let terminal = try #require(done.originalSurveyState)
    let mission = try #require(done.commander.scriptState.instances[permission.mission])
    try #require(mission.outcome == .abandoned)
    #expect(terminal.permission == permission && terminal.readings == source.readings)
    #expect(terminal.authorities == source.authorities)
    #expect(terminal.terminalOperation != nil)
    #expect(terminal.terminalDock == done.commander.nativeStations?.currentMainDock)
    #expect(terminal.terminalDock?.sequence != permission.dock.sequence)
    #expect(mission.contract?.settlementAmount == 0)
    #expect(mission.completionReceipt?.outcome == .abandoned)
    #expect(mission.milestones == [0])
    #expect(done.commander.credits == before.commander.credits)
    #expect(done.commander.cargo == before.commander.cargo)
    #expect(done.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(done.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(done.commander.accommodation == before.commander.accommodation)
    #expect(done.commander.nativePeople == before.commander.nativePeople)
    #expect(done.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(done.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
    #expect(OriginalServiceReservationPolicy.activeCount(done.commander.scriptState) == otherActive)
    #expect(done.originalSurveyRows.isEmpty && NativeOriginalSurveySave.validateClaims(done.commander))
    #expect(done.commander.valid)

    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
    #expect(saved == done.commander && world.consistent(with: saved))
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.commander == done.commander)
    #expect(restored.originalSurveyState == terminal && restored.originalSurveyRows.isEmpty)
    #expect(!restored.originalSurveyReview(.cancel).allowed)
    #expect(!restored.originalSurveyReview(.receive).allowed)
    let terminalFiles = try ScriptFinanceTestFixture.files(storage.directory)
    // A duplicate click after the committed terminal cannot create another receipt.
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == done.commander)
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == terminalFiles)
  }
}
