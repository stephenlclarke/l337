import Foundation
import Testing

@testable import L337Core

private extension C01ClinicPeopleJourneyFixture {
  /// Controlled placement retains the actual native tender. Only the next real tick
  /// and the ordinary receiver can supply the source-owned arrival witness.
  func completionApproach(_ game: inout Game, depth: Double) throws {
    let state = try #require(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort)
    let launch = try #require(state.current)
    let index = try #require(game.bodies.firstIndex {
      $0.missionActorID == NativeC01ClinicEscort.actor(mission: state.source.mission, ordinal: launch.ordinal)
    })
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let stationPose = game.modelPose(of: station)
    let port = MainStationGeometry.docking
    let normal = stationPose.orientation.apply(port.outward)
    let up = stationPose.orientation.apply(port.up)
    let entrance = stationPose.systemPoint(port.center)
    var inward = Basis3()
    inward.z = normal * -1
    inward.y = up
    inward.x = inward.y.cross(inward.z)
    NativeStationTestFixture.reframe(&game,
      to: .init(position: entrance + normal * 600, orientation: inward))
    let ys = try NativeC01SurveyorGeometry.harrier.get().collision.vertices.map(\.y)
    let low = try #require(ys.min())
    let high = try #require(ys.max())
    let position = entrance - up * ((low + high) / 2) + normal * depth
    let velocity = (station.physical?.velocity ?? .init(0, 0, 0)) - normal * 30
    game.bodies[index].position = game.commander.flightSimulation.pose.shipPoint(position)
    game.bodies[index].orientation = inward.relative(to: game.commander.flightSimulation.pose.orientation)
    let relativeVelocity: Vector3 = game.commander.flightSimulation.pose.shipVector(velocity)
    game.bodies[index].scriptNPC?.velocity = relativeVelocity
    game.bodies[index].physical?.velocity = velocity
    game.screen = .front
    game.speed = 0
    game.autoPilot.disengage()
    game.persistScriptActors()
  }

  func genuinelyReceivedClinic() async throws -> Game {
    var game = try await sourceGame()
    try parkAtCradle(&game)
    let launch = GameRuntime(game: game, saveURL: save)
    try await launch.save(to: save)
    await launch.key("return")
    await launch.key("return")
    game = await launch.snapshot()
    try #require(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.current != nil)
    try completionApproach(&game, depth: 100)
    let approaching = GameRuntime(game: game, saveURL: save)
    try await approaching.save(to: save)
    for _ in 0..<3 { _ = await approaching.advance(delta: 0.05) }
    game = await approaching.snapshot()
    try #require(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == nil)
    try completionApproach(&game, depth: 1)
    let receiving = GameRuntime(game: game, saveURL: save)
    try await receiving.save(to: save)
    _ = await receiving.advance(delta: 0.05)
    for _ in 0..<400 {
      if await receiving.snapshot().glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival != nil { break }
      _ = await receiving.advance(delta: 0.05)
    }
    let received = await receiving.snapshot()
    try #require(received.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival != nil)
    try #require(received.commander.valid)
    return received
  }

  func avenorAfterClinic() async throws -> GameRuntime {
    var game = try await genuinelyReceivedClinic()
    game.persistScriptActors(unloading: true)
    try game.departOrdinarySimulation()
    game.commander.system = 7
    game.selectedSystem = 7
    game.market = MarketItem.at(game.currentSystem)
    game.launch()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    let runtime = GameRuntime(game: game, saveURL: save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let docked = await runtime.snapshot()
    try #require(docked.docked && docked.dockedAtMainStation)
    let dock = try #require(docked.commander.nativeStations?.currentMainDock)
    try #require(docked.nativeMainStationArrivalContext(for: dock.station) != nil)
    return runtime
  }
}

struct NativeC01CompletionJourneyTests {
  @Test(arguments: NativeC01EvidenceChoice.allCases, [false, true])
  func genuineClinicChoiceArchiveCurrentSaveAndAtomicWriterFailure(
    _ choice: NativeC01EvidenceChoice, _ failWriter: Bool
  ) async throws {
    let fixture = try await C01ClinicPeopleJourneyFixture()
    defer { fixture.clean() }
    let runtime = try await fixture.avenorAfterClinic()
    let initial = await runtime.snapshot()
    let capture = try #require(initial.glassMeridianMission?.savedGlassMeridian?.surveyor?.capture)
    let standard = initial.glassMeridianMission?.savedGlassMeridian?.timingStandard
    #expect(!initial.c01CompletionReview(.archiveRecorder).allowed)
    let action: NativeGlassMeridianAction = choice == .publicReport ? .publishFullSafetyReport : .submitCrewArbitration
    let review = initial.c01CompletionReview(action)
    try #require(review.allowed)
    try await runtime.scriptCommand { try $0.confirmGlassMeridian(review) }
    let selected = await runtime.snapshot()
    #expect(selected.glassMeridianMission?.milestones == Set(0...7))
    #expect(selected.glassMeridianMission?.savedGlassMeridian?.surveyor?.capture == capture)
    #expect(selected.glassMeridianMission?.savedGlassMeridian?.surveyor?.held == true)
    #expect(selected.commander.credits == initial.commander.credits)
    #expect(selected.commander.scriptState.savedClueJournal == initial.commander.scriptState.savedClueJournal)
    #expect(selected.stationRumour.contains(choice.label))
    #expect(!selected.stationRumour.contains("public lane-safety commendation"))
    // Presentation-only copies do not supply docking or mission authority. The
    // persisted choice is genuine; these copies check the adopted visibility map.
    for system in [0, 7, 91, 162, 164, 185] {
      var regional = selected
      regional.commander.system = system
      #expect(regional.stationRumour.contains(choice.label))
    }
    var unrelated = selected
    unrelated.commander.system = 1
    #expect(unrelated.c01RegionalOutcomeRumour == nil)
    unrelated.commander.galaxy = 1
    unrelated.commander.system = 7
    #expect(unrelated.c01RegionalOutcomeRumour == nil)
    var trial = selected
    trial.isMissionTrial = true
    #expect(trial.c01RegionalOutcomeRumour == nil)
    var baseline = selected
    let selectedID = try #require(selected.glassMeridianMission?.id)
    baseline.commander.scriptState.instances.removeValue(forKey: selectedID)
    #expect(selected.stationRumour.hasSuffix(baseline.stationRumour))
    let archive = selected.c01CompletionReview(.archiveRecorder)
    try #require(archive.allowed)
    if failWriter {
      let pointer = try Data(contentsOf: fixture.save)
      try FileManager.default.removeItem(at: fixture.save)
      try FileManager.default.createDirectory(at: fixture.save, withIntermediateDirectories: false)
      var refused = false
      do { try await runtime.scriptCommand { try $0.confirmGlassMeridian(archive) } }
      catch { refused = true }
      #expect(refused)
      let unchanged = await runtime.snapshot()
      #expect(unchanged.commander == selected.commander)
      try FileManager.default.removeItem(at: fixture.save)
      try pointer.write(to: fixture.save, options: .atomic)
    }
    let fresh = await runtime.snapshot().c01CompletionReview(.archiveRecorder)
    try #require(fresh.allowed)
    try await runtime.scriptCommand { try $0.confirmGlassMeridian(fresh) }
    let completed = await runtime.snapshot()
    let mission = try #require(completed.glassMeridianMission)
    #expect(mission.outcome == .complete && mission.milestones == Set(0...8))
    #expect(completed.commander.credits == selected.commander.credits + 48000)
    #expect(mission.savedGlassMeridian?.surveyor?.capture == capture)
    #expect(mission.savedGlassMeridian?.surveyor?.archive?.source.capture == capture.operation)
    #expect(mission.savedGlassMeridian?.surveyor?.held == false)
    #expect(mission.savedGlassMeridian?.timingStandard == standard)
    let stored = selected.commander.salvageLedger.inventoryMassKg
      + (selected.commander.alienStorageState?.current.storedMassKg ?? 0)
    let releasedTonnes = Int(ceil((stored + 8) / 1000) - ceil(stored / 1000))
    #expect(completed.commander.checkedCargoTonnes == selected.commander.checkedCargoTonnes.map { $0 - releasedTonnes })
    #expect(completed.stationRumour.contains(choice.label))
    #expect(completed.stationRumour.contains("public lane-safety commendation"))
    #expect(mission.completionReceipt?.valid(for: mission, engine: completed.commander.scriptState) == true)
    #expect(completed.commander.scriptState.savedClueJournal?.awards[NativeC01Completion.sourceID]?.completion == mission.completionReceipt)
    #expect(completed.commander.valid)
    // A later cash value is not the historical payment balance. This isolated
    // validator check supplies no receiving, spending or new reward authority.
    var spent = completed
    spent.commander.credits -= 1
    #expect(NativeC01CompletionSave.valid(mission, commander: spent.commander))
    var replayRefused = false
    do { try await runtime.scriptCommand { try $0.confirmGlassMeridian(fresh) } }
    catch { replayRefused = true }
    #expect(replayRefused)
    #expect(await runtime.snapshot().commander == completed.commander)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: fixture.save)
    let loaded = await cold.snapshot()
    #expect(loaded.glassMeridianMission?.savedGlassMeridian == mission.savedGlassMeridian)
    #expect(loaded.glassMeridianMission?.completionReceipt == mission.completionReceipt)
    #expect(loaded.commander.credits == completed.commander.credits)
    #expect(loaded.commander.scriptState.savedClueJournal == completed.commander.scriptState.savedClueJournal)
    #expect(loaded.stationRumour == completed.stationRumour)
    #expect(loaded.commander.valid)
    if choice == .publicReport && !failWriter {
      // Return only the player. Restore the same retained source unit, then attain
      // its real native fatality. No loss/arrival/terminal receipt is constructed here.
      var returning = loaded
      returning.persistScriptActors(unloading: true)
      try returning.departOrdinarySimulation()
      returning.commander.system = 91
      returning.selectedSystem = 91
      returning.market = MarketItem.at(returning.currentSystem)
      returning.launch()
      let clinic = try #require(mission.savedGlassMeridian?.clinicEscort)
      NativeStationTestFixture.reframe(&returning,
        to: .init(position: clinic.source.position + .init(0, 0, 400)))
      try returning.restoreScriptActors()
      let reserve = try #require(returning.bodies.first {
        $0.missionActorID == NativeC01ClinicEscort.actor(mission: mission.id, ordinal: 1)
      })
      let reservePose = returning.modelPose(of: reserve)
      var facing = Basis3()
      facing.z = reservePose.orientation.z * -1
      facing.y = reservePose.orientation.y
      facing.x = facing.y.cross(facing.z)
      NativeStationTestFixture.reframe(&returning, to: .init(
        position: reservePose.position + reservePose.orientation.z * 200, orientation: facing))
      returning.screen = .front
      returning.speed = 0
      returning.autoPilot.disengage()
      returning.weaponsTargetID = reserve.id
      let casualty = GameRuntime(game: returning, saveURL: fixture.save)
      try await casualty.save(to: fixture.save)
      var fire = Controls()
      fire.fire = true
      await casualty.setControls(fire)
      for _ in 0..<1200 {
        if await casualty.snapshot().glassMeridianMission?.savedGlassMeridian?
          .clinicEscort?.loss(for: 1) != nil { break }
        _ = await casualty.advance(delta: 0.05)
      }
      await casualty.setControls(Controls())
      let late = await casualty.snapshot()
      let lateMission = try #require(late.glassMeridianMission)
      let post = try #require(lateMission.savedGlassMeridian?.completion?.postTerminalClinicLoss)
      #expect(post.beforeRevision == mission.revision && post.afterRevision == mission.revision + 1)
      #expect(lateMission.revision == mission.revision + 1)
      #expect(lateMission.completionReceipt == mission.completionReceipt)
      #expect(lateMission.savedGlassMeridian?.completion?.terminal == mission.savedGlassMeridian?.completion?.terminal)
      #expect(lateMission.savedGlassMeridian?.clinicEscort?.arrival == clinic.arrival)
      #expect(lateMission.savedGlassMeridian?.surveyor == mission.savedGlassMeridian?.surveyor)
      #expect(late.commander.scriptState.savedClueJournal == completed.commander.scriptState.savedClueJournal)
      #expect(late.commander.credits == completed.commander.credits)
      #expect(late.commander.valid)
      let finalLoad = GameRuntime(game: Game(executive: false))
      try await finalLoad.load(from: fixture.save)
      let restored = await finalLoad.snapshot()
      #expect(restored.glassMeridianMission?.completionReceipt == mission.completionReceipt)
      #expect(restored.glassMeridianMission?.savedGlassMeridian?.completion == lateMission.savedGlassMeridian?.completion)
      #expect(restored.commander.scriptState.savedClueJournal == completed.commander.scriptState.savedClueJournal)
      #expect(restored.commander.valid)
    }
  }
}
