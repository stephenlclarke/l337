import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct NativeFlightReceptionDoorwayTests {
  @Test(arguments: [false, true])
  func refusedApproachWriteCanResumeAtTheActualSameDoorwayAfterColdLoad(protected: Bool)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var initial = try ScriptProcurementFixture.freshG03FlightGame()
    try initial.prepareG03FlightEquipment()
    if protected {
      initial.commander.system = NativeMemoryAtlasWatcherSource.world.system
      initial.selectedSystem = initial.commander.system
      initial.market = MarketItem.at(initial.currentSystem)
    }
    initial.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledFlightReceptionDirectory)
    ]
    let runtime = GameRuntime(game: initial, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    try await confirmPractice(.accept, runtime: runtime)
    let issued = await runtime.snapshot()
    let attempt = try #require(issued.activeFlightReception)
    if issued.screen == .contracts {
      if issued.contractBoard.detail { await runtime.key("escape") }
      await runtime.key("escape")
    }
    await runtime.key("0")
    await runtime.nativeCommand { game in
      _ = Self.framePractice(&game, forDoorway: false)
    }
    let approaching = await runtime.snapshot()
    try #require(approaching.flightReceptionSample() != nil)
    try storage.blockWriter()
    let refused = await runtime.advance(delta: 0.05)
    let pending = try #require(refused.nativeFlightReceptionPending)
    try #require(refused.activeFlightReception?.state.reading == nil)
    try storage.restoreWriter()

    let received = try await runtime.crossPracticeDoorway(protected: protected)
    let arrival = try #require(
      received.nativeMainStationArrivalContext(for: attempt.state.permission.dock.station))
    try #require(arrival.receipt.actor == pending.reading.last.actor)
    try #require(received.nativeStationRuntimeEpoch != pending.reading.first.epoch)
    try #require(received.nativeFlightReceptionPending === pending)
    try #require(received.activeFlightReception?.state.reading == nil)
    var unproved = received
    unproved.nativeMainStationDockEvidence = nil
    #expect(throws: SaveError.self) { try unproved.applyFlightReceptionPending() }
    var invalidated = received
    invalidated.invalidateNativeStationAuthority()
    #expect(invalidated.nativeFlightReceptionPending == nil)

    try await runtime.save(to: storage.url)
    try await runtime.load(from: storage.url, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let resumed = await runtime.snapshot()
    #expect(resumed.nativeFlightReceptionPending == nil)
    #expect(resumed.activeFlightReception?.state.reading == pending.reading)
    try await confirmPractice(.receive, runtime: runtime)
    let finished = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    let completed = try #require(finished.scriptState.instances[attempt.instance.id])
    #expect(completed.outcome == .complete && completed.milestones == [0, 1, 2])
    #expect(completed.savedFlightReception?.terminalDock == arrival.receipt)
    #expect(finished.credits == issued.commander.credits)
    #expect(finished.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      finished.scriptState.savedClueJournal?.awards[NativeFlightReception.stateID]?.completion
        == completed.completionReceipt)
  }

  private func confirmPractice(_ action: NativeFlightReceptionAction, runtime: GameRuntime)
    async throws
  {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(board.rows.firstIndex { $0.flightReception == action })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let review = try #require(await runtime.snapshot().contractBoard.flightReceptionQuote)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: ", ")))
    await runtime.key("right")
    await runtime.key("return")
  }

  fileprivate static func framePractice(_ game: inout Game, forDoorway: Bool) -> Bool {
    guard let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }) else {
      return false
    }
    let previous = game.commander.flightSimulation.pose
    let outward = previous.orientation.apply(station.entranceNormal)
    let anchor = forDoorway ? station.entrancePosition : station.position
    var pose = ShipPose()
    pose.position = previous.systemPoint(anchor) + outward * (forDoorway ? 2 : 1200)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = outward * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.clearManualResidualFlight()
    game.autoPilot.disengage()
    game.speed = 3
    return true
  }
}

extension GameRuntime {
  fileprivate func crossPracticeDoorway(protected: Bool) throws -> Game {
    // Frame geometry on the same live actor. Only native motion can issue the doorway receipt.
    let framed = NativeFlightReceptionDoorwayTests.framePractice(&game, forDoorway: true)
    try #require(framed)
    for _ in 0..<100 {
      if game.docked || game.pendingMemoryAtlasMainDock != nil { break }
      game.tick(delta: 0.1)
    }
    try #require((game.pendingMemoryAtlasMainDock != nil) == protected)
    if protected {
      // Leave publication to the following ordinary save so the live pending object is observable.
      try game.commitPendingMemoryAtlasMainArrival { candidate in
        try #require(candidate.nativeMainStationDockEvidenceIsCurrent)
      }
    }
    return snapshot()
  }
}
