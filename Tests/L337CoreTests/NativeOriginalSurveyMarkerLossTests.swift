import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

private func destroyOriginalSurveyMarker(
  _ runtime: GameRuntime, fixture: NativeOriginalSurveyFixture, ordinal: Int
) async throws {
  let source = try await fixture.source(runtime)
  let permission = try #require(source.permission)
  let alias = NativeOriginalSurvey.targets[ordinal]
  try await fixture.aim(runtime, ordinal: ordinal)
  await runtime.key("u")
  var controls = Controls()
  controls.fire = true
  await runtime.setControls(controls)
  for _ in 0..<500 {
    let game = await runtime.snapshot()
    if game.commander.scriptState.instances[permission.mission]?.ownedEncounters[
      NativeOriginalSurvey.encounterID]?.actors[alias]?.presence == .destroyed
    {
      break
    }
    _ = await runtime.advance(delta: 0.05)
  }
  await runtime.setControls(Controls())
  let game = await runtime.snapshot()
  let marker = try #require(
    game.commander.scriptState.instances[permission.mission]?.ownedEncounters[
      NativeOriginalSurvey.encounterID]?.actors[alias])
  try #require(marker.presence == .destroyed)
  try #require(marker.identity == NativeOriginalSurvey.markerIdentity(
    mission: permission.mission, digest: source.digest, ordinal: ordinal))
  #expect(!game.bodies.contains { $0.missionActorID == marker.identity && $0.energy > 0 })
}

struct NativeOriginalSurveyMarkerLossTests {
  @Test(arguments: [1, 2])
  func actualUnreadMarkerLossSurvivesColdReentryAndCanBeCancelledAtomically(ordinal: Int)
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let installed = f.files.root.appendingPathComponent("marker-loss-library", isDirectory: true)
    try await runtime.installScriptPack(
      from: ScriptPackLibrary.bundledOriginalSurveyDirectory, destination: installed)
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    #expect(await runtime.snapshot().originalSurveyMarkerLossNotice == nil)
    try await f.renas(runtime)
    #expect(await runtime.snapshot().originalSurveyMarkerLossNotice == nil)
    try await f.view(runtime, ordinal: 0)
    let measured = try await f.source(runtime)
    try await destroyOriginalSurveyMarker(runtime, fixture: f, ordinal: ordinal)
    let destroyed = await runtime.snapshot()
    let notice = try #require(destroyed.originalSurveyMarkerLossNotice)
    #expect(notice.contains(NativeOriginalSurvey.targets[ordinal]))
    #expect(notice.contains("destroyed before measurement"))
    #expect(notice.contains("Return to Avenor to cancel"))
    #expect(destroyed.originalSurveyScanStatus == notice)
    #expect(destroyed.originalSurveyDetail(.receive).contains(notice))
    #expect(destroyed.originalSurveyState?.readings == measured.readings)
    #expect(destroyed.originalSurveyState?.authorities == measured.authorities)
    #expect(destroyed.commander.scriptState.instances[permission.mission]?.outcome == .active)
    #expect(destroyed.originalSurveyState?.terminalOperation == nil)
    // Losing a later marker must already show the problem, while genuine earlier
    // observations may still be sealed. The notice itself advances no objective.
    if ordinal == 2 { try await f.view(runtime, ordinal: 1) }
    let retained = try await f.source(runtime)
    #expect(retained.readings.count == ordinal)
    let lostID = NativeOriginalSurvey.markerIdentity(
      mission: permission.mission, digest: source.digest, ordinal: ordinal)
    try await runtime.save(to: f.save)
    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(world.consistent(with: saved) && NativeOriginalSurveySave.validateClaims(saved))
    let cold = GameRuntime(game: Game(executive: false), saveURL: f.save)
    await cold.loadScriptPacks(directory: installed)
    try #require(await cold.snapshot().originalSurveyPack?.digest == f.pack.digest)
    try await cold.load(from: f.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    try #require(loaded.originalSurveyPack?.digest == f.pack.digest)
    let activeSurvey = try #require(loaded.commander.scriptState.instances[permission.mission])
    try #require(activeSurvey.digest == f.pack.digest && activeSurvey.suspension == nil)
    try #require(activeSurvey.outcome == .active)
    #expect(loaded.originalSurveyState == retained)
    #expect(await cold.snapshot().originalSurveyMarkerLossNotice != nil)
    // Real docking and launch revisit the existing cohort; no test replaces its
    // presence, energy, identity or native destruction receipt.
    await cold.key("0")
    try await f.base.flight.dock(cold)
    await cold.key("0")
    _ = await cold.advance(delta: 0.1)
    let revisited = await cold.snapshot()
    let encounter = try #require(
      revisited.commander.scriptState.instances[permission.mission]?.ownedEncounters[
        NativeOriginalSurvey.encounterID])
    #expect(encounter.actors.count == 3)
    #expect(encounter.actors[NativeOriginalSurvey.targets[ordinal]]?.identity == lostID)
    #expect(encounter.actors[NativeOriginalSurvey.targets[ordinal]]?.presence == .destroyed)
    #expect(!revisited.bodies.contains { $0.missionActorID == lostID && $0.energy > 0 })
    #expect(revisited.originalSurveyState?.readings == retained.readings)
    #expect(revisited.originalSurveyMarkerLossNotice != nil)
    try await f.returnHome(cold)
    let atOffice = await cold.snapshot()
    try #require(atOffice.nativeMainStationDockEvidenceIsCurrent)
    #expect(!atOffice.originalSurveyReview(.receive).allowed)
    #expect(atOffice.originalSurveyReview(.cancel).allowed)
    let active = OriginalServiceReservationPolicy.activeCount(atOffice.commander.scriptState)
    let back = try await f.review(cold, .cancel)
    #expect(await cold.snapshot().contractBoard.action == .back)
    await cold.scriptPageKey("return", expected: back)
    #expect(await cold.snapshot().commander == atOffice.commander)
    let page = try await f.review(cold, .cancel)
    let quote = try #require(await cold.snapshot().contractBoard.surveyQuote)
    await cold.scriptPageKey("right", expected: page)
    let before = await cold.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("destroyed-survey-marker-cancellation")
    await cold.scriptPageKey("return", expected: page)
    let refused = await cold.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.scriptWorldSave == before.scriptWorldSave)
    #expect(refused.contractBoard.surveyQuote?.reviewToken == quote.reviewToken)
    try f.files.restoreWrites(held, files: files)
    await cold.scriptPageKey("return", expected: page)
    let cancelled = await cold.snapshot()
    let terminal = try #require(cancelled.originalSurveyState)
    let mission = try #require(cancelled.commander.scriptState.instances[permission.mission])
    try #require(mission.outcome == .abandoned)
    #expect(terminal.permission == retained.permission)
    #expect(terminal.readings == retained.readings && terminal.authorities == retained.authorities)
    #expect(terminal.terminalOperation != nil)
    #expect(terminal.terminalDock == cancelled.commander.nativeStations?.currentMainDock)
    #expect(mission.contract?.settlementAmount == 0)
    #expect(cancelled.commander.credits == before.commander.credits)
    #expect(cancelled.commander.cargo == before.commander.cargo)
    #expect(cancelled.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(cancelled.commander.nativePeople == before.commander.nativePeople)
    #expect(cancelled.commander.accommodation == before.commander.accommodation)
    #expect(cancelled.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(OriginalServiceReservationPolicy.activeCount(cancelled.commander.scriptState) == active - 1)
    #expect(cancelled.originalSurveyMarkerLossNotice == nil)
    #expect(cancelled.originalSurveyScanStatus == nil && cancelled.originalSurveyRows.isEmpty)
    let (closed, closedWorld) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(closed == cancelled.commander && closedWorld.consistent(with: closed))
    let terminalCold = GameRuntime(game: Game(executive: false), saveURL: f.save)
    await terminalCold.loadScriptPacks(directory: installed)
    try #require(await terminalCold.snapshot().originalSurveyPack?.digest == f.pack.digest)
    try await terminalCold.load(from: f.save, persistMigrations: false)
    let restored = await terminalCold.snapshot()
    try #require(restored.originalSurveyPack?.digest == f.pack.digest)
    #expect(restored.commander == cancelled.commander)
    #expect(restored.originalSurveyState == terminal && restored.originalSurveyRows.isEmpty)
    #expect(restored.originalSurveyMarkerLossNotice == nil)
  }

  @Test func actualDestructionAfterASealedReadingPreservesThatReadingAndAllowsReception()
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    let measured = try await f.source(runtime)
    try await destroyOriginalSurveyMarker(runtime, fixture: f, ordinal: 0)
    let destroyed = await runtime.snapshot()
    #expect(destroyed.originalSurveyMarkerLossNotice == nil)
    #expect(destroyed.originalSurveyState?.readings == measured.readings)
    #expect(destroyed.originalSurveyState?.authorities == measured.authorities)
    #expect(NativeOriginalSurveySave.validateClaims(destroyed.commander))
    try await runtime.save(to: f.save)
    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(world.consistent(with: saved) && NativeOriginalSurveySave.validateClaims(saved))
    try await f.view(runtime, ordinal: 1)
    try await f.view(runtime, ordinal: 2)
    #expect(await runtime.snapshot().originalSurveyMarkerLossNotice == nil)
    #expect(await runtime.snapshot().originalSurveyScanStatus?.contains("SURVEY 3/3") == true)
    try await f.returnHome(runtime)
    let reception = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    let complete = try #require(done.commander.scriptState.instances[permission.mission])
    try #require(complete.outcome == .complete)
    #expect(done.originalSurveyState?.readings.first == measured.readings.first)
    #expect(done.originalSurveyState?.authorities.first == measured.authorities.first)
    #expect(done.commander.credits == reception + NativeOriginalSurvey.reward)
    #expect(done.commander.scriptState.savedClueJournal?.awards[NativeOriginalSurvey.stateID] != nil)
    #expect(done.originalSurveyMarkerLossNotice == nil && done.originalSurveyRows.isEmpty)
    let (closed, closedWorld) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(closed == done.commander && closedWorld.consistent(with: closed))
  }
}
