import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

private func destroyOutlookMarker(
  _ runtime: GameRuntime, fixture: NativeOrbitalOutlookFixture, ordinal: Int
) async throws {
  let source = try await fixture.source(runtime)
  let boarding = try #require(source.boarding)
  let alias = NativeOrbitalOutlookJourney.views[ordinal]
  try await fixture.aim(runtime, ordinal: ordinal)
  await runtime.key("u")
  var controls = Controls()
  controls.fire = true
  await runtime.setControls(controls)
  for _ in 0..<500 {
    let game = await runtime.snapshot()
    if game.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
      NativeOrbitalOutlookJourney.encounterID]?.actors[alias]?.presence == .destroyed
    {
      break
    }
    _ = await runtime.advance(delta: 0.05)
  }
  await runtime.setControls(Controls())
  let game = await runtime.snapshot()
  let marker = try #require(
    game.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
      NativeOrbitalOutlookJourney.encounterID]?.actors[alias])
  try #require(marker.presence == .destroyed)
  try #require(marker.identity == NativeOrbitalOutlookJourney.markerIdentity(
    mission: boarding.mission, ordinal: ordinal))
  #expect(!game.bodies.contains { $0.missionActorID == marker.identity && $0.energy > 0 })
}

struct NativeOrbitalOutlookMarkerLossTests {
  @Test(arguments: [1, 2])
  func unreadMarkerLossKeepsBothPeopleUntilActualCareReturnWithWriterRetry(ordinal: Int)
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let installed = f.files.root.appendingPathComponent("outlook-loss-library", isDirectory: true)
    try await runtime.installScriptPack(
      from: ScriptPackLibrary.bundledOrbitalOutlookDirectory, destination: installed)
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    try #require(source.references.count == 2 && boarding.berths.count == 2)
    #expect(await runtime.snapshot().orbitalOutlookMarkerLossNotice == nil)
    try await f.renas(runtime)
    #expect(await runtime.snapshot().orbitalOutlookMarkerLossNotice == nil)
    try await f.view(runtime, ordinal: 0)
    let measured = try await f.source(runtime)
    try await destroyOutlookMarker(runtime, fixture: f, ordinal: ordinal)
    let destroyed = await runtime.snapshot()
    let notice = try #require(destroyed.orbitalOutlookMarkerLossNotice)
    #expect(notice.contains(NativeOrbitalOutlookJourney.views[ordinal]))
    #expect(notice.contains("Return both passengers to Avenor care"))
    #expect(destroyed.orbitalOutlookScanStatus == notice)
    #expect(destroyed.orbitalOutlookDetail(.cancel).contains(notice))
    #expect(destroyed.commander.nativePeople?.outlookJourney?.readings == measured.readings)
    #expect(destroyed.commander.nativePeople?.outlookJourney?.authorities == measured.authorities)
    #expect(destroyed.commander.scriptState.instances[boarding.mission]?.outcome == .active)
    #expect(destroyed.commander.nativePeople?.outlookJourney?.terminalOperation == nil)
    #expect(source.references.allSatisfy { person in
      destroyed.commander.nativePeople?.held.contains { $0.person == person } == true
    })
    if ordinal == 2 { try await f.view(runtime, ordinal: 1) }
    let retained = try await f.source(runtime)
    #expect(retained.readings.count == ordinal)
    try await runtime.save(to: f.save)
    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(world.consistent(with: saved) && NativeOrbitalOutlookJourneySave.validateClaims(saved))
    let cold = GameRuntime(game: Game(executive: false), saveURL: f.save)
    await cold.loadScriptPacks(directory: installed)
    try #require(await cold.snapshot().orbitalOutlookPack?.digest == f.pack.digest)
    try await cold.load(from: f.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    try #require(loaded.orbitalOutlookPack?.digest == f.pack.digest)
    let activeMission = try #require(loaded.commander.scriptState.instances[boarding.mission])
    try #require(activeMission.outcome == .active && activeMission.suspension == nil)
    #expect(loaded.commander.nativePeople?.outlookJourney == retained)
    #expect(loaded.orbitalOutlookMarkerLossNotice != nil)
    await cold.key("0")
    try await f.base.flight.dock(cold)
    await cold.key("0")
    _ = await cold.advance(delta: 0.1)
    let revisited = await cold.snapshot()
    let lostID = NativeOrbitalOutlookJourney.markerIdentity(
      mission: boarding.mission, ordinal: ordinal)
    let encounter = try #require(
      revisited.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
        NativeOrbitalOutlookJourney.encounterID])
    #expect(encounter.actors.count == 3)
    #expect(encounter.actors[NativeOrbitalOutlookJourney.views[ordinal]]?.identity == lostID)
    #expect(encounter.actors[NativeOrbitalOutlookJourney.views[ordinal]]?.presence == .destroyed)
    #expect(!revisited.bodies.contains { $0.missionActorID == lostID && $0.energy > 0 })
    #expect(revisited.orbitalOutlookMarkerLossNotice != nil)
    #expect(revisited.commander.accommodation.fittedBerths.filter { $0.use.used }.count == 2)
    try await f.returnHome(cold)
    let atOffice = await cold.snapshot()
    try #require(atOffice.nativeMainStationDockEvidenceIsCurrent)
    try #require(atOffice.orbitalOutlookQuote(.cancel).allowed)
    #expect(!atOffice.orbitalOutlookQuote(.receive).allowed)
    let activeCount = OriginalServiceReservationPolicy.activeCount(atOffice.commander.scriptState)
    let back = try await NativePeopleTestFixture.review(cold, row: .outlook(.cancel))
    #expect(await cold.snapshot().contractBoard.action == .back)
    await cold.scriptPageKey("return", expected: back)
    #expect(await cold.snapshot().commander == atOffice.commander)
    let page = try await NativePeopleTestFixture.review(cold, row: .outlook(.cancel))
    let quote = try #require(await cold.snapshot().contractBoard.peopleQuote)
    try #require(quote.allowed && quote.members == source.references && quote.price == 0)
    await cold.scriptPageKey("right", expected: page)
    let before = await cold.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("outlook-lost-marker-care")
    await cold.scriptPageKey("return", expected: page)
    let refused = await cold.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.scriptWorldSave == before.scriptWorldSave)
    #expect(refused.contractBoard.peopleQuote?.reviewToken == quote.reviewToken)
    try f.files.restoreWrites(held, files: files)
    await cold.scriptPageKey("return", expected: page)
    let cancelled = await cold.snapshot()
    let terminal = try await f.source(cold)
    let mission = try #require(cancelled.commander.scriptState.instances[boarding.mission])
    try #require(mission.outcome == .abandoned)
    let transfer = try #require(cancelled.commander.nativePeople?.transfers.last)
    #expect(transfer.kind == .care && transfer.members == source.references && transfer.price == 0)
    #expect(transfer.dock == cancelled.commander.nativeStations?.currentMainDock)
    #expect(transfer.beforeCash == transfer.afterCash)
    #expect(terminal.terminalOperation == transfer.operation)
    #expect(terminal.boarding == retained.boarding && terminal.references == source.references)
    #expect(terminal.readings == retained.readings && terminal.authorities == retained.authorities)
    #expect(cancelled.commander.nativePeople?.held.isEmpty == true)
    #expect(cancelled.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(cancelled.commander.accommodation.ownedBerths.map(\.id) == before.commander.accommodation.ownedBerths.map(\.id))
    #expect(mission.contract?.settlementAmount == 0)
    #expect(cancelled.commander.credits == before.commander.credits)
    #expect(cancelled.commander.cargo == before.commander.cargo)
    #expect(cancelled.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(cancelled.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(OriginalServiceReservationPolicy.activeCount(cancelled.commander.scriptState) == activeCount - 1)
    #expect(cancelled.orbitalOutlookMarkerLossNotice == nil)
    #expect(cancelled.orbitalOutlookScanStatus == nil && cancelled.orbitalOutlookRows.isEmpty)
    let (closed, closedWorld) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(closed == cancelled.commander && closedWorld.consistent(with: closed))
    let terminalCold = GameRuntime(game: Game(executive: false), saveURL: f.save)
    await terminalCold.loadScriptPacks(directory: installed)
    try #require(await terminalCold.snapshot().orbitalOutlookPack?.digest == f.pack.digest)
    try await terminalCold.load(from: f.save, persistMigrations: false)
    let restored = await terminalCold.snapshot()
    try #require(restored.orbitalOutlookPack?.digest == f.pack.digest)
    #expect(restored.commander == cancelled.commander)
    #expect(restored.commander.nativePeople?.outlookJourney == terminal)
    #expect(restored.orbitalOutlookRows.isEmpty && restored.orbitalOutlookMarkerLossNotice == nil)
  }

  @Test func destroyedAlreadyViewedMarkerPreservesBothPassengersViewsAndGenuineReception()
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    let measured = try await f.source(runtime)
    try await destroyOutlookMarker(runtime, fixture: f, ordinal: 0)
    let destroyed = await runtime.snapshot()
    #expect(destroyed.orbitalOutlookMarkerLossNotice == nil)
    #expect(destroyed.commander.nativePeople?.outlookJourney?.readings == measured.readings)
    #expect(destroyed.commander.nativePeople?.outlookJourney?.authorities == measured.authorities)
    try await runtime.save(to: f.save)
    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(world.consistent(with: saved) && NativeOrbitalOutlookJourneySave.validateClaims(saved))
    try await f.view(runtime, ordinal: 1)
    try await f.view(runtime, ordinal: 2)
    #expect(await runtime.snapshot().orbitalOutlookScanStatus?.contains("OUTLOOK 3/3") == true)
    try await f.returnHome(runtime)
    let before = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    let complete = try #require(done.commander.scriptState.instances[boarding.mission])
    try #require(complete.outcome == .complete)
    #expect(done.commander.nativePeople?.outlookJourney?.readings.first == measured.readings.first)
    #expect(done.commander.nativePeople?.outlookJourney?.authorities.first == measured.authorities.first)
    #expect(done.commander.nativePeople?.transfers.last?.members == source.references)
    #expect(done.commander.nativePeople?.transfers.last?.kind == .care)
    #expect(done.commander.nativePeople?.held.isEmpty == true)
    #expect(done.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(done.commander.credits == before + NativeOrbitalOutlookJourney.reward)
    #expect(done.commander.scriptState.savedClueJournal?.awards[NativeOrbitalOutlookJourney.stateID] != nil)
    #expect(done.orbitalOutlookRows.isEmpty && done.orbitalOutlookMarkerLossNotice == nil)
    let (closed, closedWorld) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(closed == done.commander && closedWorld.consistent(with: closed))
  }
}
