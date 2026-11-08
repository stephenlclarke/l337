import Foundation
import Testing

@testable import L337Core

struct CurrentNewtNativeClockTests {
  @Test func foreignCurrentSourceRefusesTheFirstRealFrameBeforePowerOrHeldFire() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyForeignCurrentSourceRefusesTheFirstRealFrameBeforePowerOrHeldFire(&game)
  }

  @inline(never)
  private func verifyForeignCurrentSourceRefusesTheFirstRealFrameBeforePowerOrHeldFire(_ game: inout Game) throws {
    let indexCandidate = game.bodies.firstIndex { $0.physical?.currentNewtKitStock != nil }
    let index = try #require(indexCandidate)
    // Corrupt the catalogue join on a genuinely born finite kit. No replacement
    // stock, actor, save, source approval or positive authority is synthesized.
    game.bodies[index].physical?.catalogueShipID = "SH005"
    let flight = game.commander.flightSimulation
    let main = game.commander.savedPlayerElectrical
    let inventory = game.commander.equipmentInventory
    let history = game.commander.equipmentPurchaseHistory
    let energy = game.energy
    let time = game.time
    let audio = game.dischargeAudio.events
    var controls = Controls()
    controls.fire = true
    game.tick(delta: 0.1, controls: controls)
    let stationAutoOwnedCheck8 = game.paused
    #expect(stationAutoOwnedCheck8)
    let stationAutoOwnedCheck9 = game.commander.flightSimulation == flight
    #expect(stationAutoOwnedCheck9)
    let stationAutoOwnedCheck10 = game.commander.savedPlayerElectrical == main
    #expect(stationAutoOwnedCheck10)
    let stationAutoOwnedCheck11 = game.commander.equipmentInventory == inventory
    #expect(stationAutoOwnedCheck11)
    let stationAutoOwnedCheck12 = game.commander.equipmentPurchaseHistory == history
    #expect(stationAutoOwnedCheck12)
    let stationAutoOwnedCheck13 = game.energy == energy && game.time == time
    #expect(stationAutoOwnedCheck13)
    let stationAutoOwnedCheck14 = game.commander.savedEMPCharge == nil
    #expect(stationAutoOwnedCheck14)
    let stationAutoOwnedCheck15 = game.dischargeAudio.events == audio
    #expect(stationAutoOwnedCheck15)
  }

  @Test func genuineShortNativeIntervalCannotEarnTheLargerOuterElectricalHeader() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyGenuineShortNativeIntervalCannotEarnTheLargerOuterElectricalHeader(&game)
  }

  @inline(never)
  private func verifyGenuineShortNativeIntervalCannotEarnTheLargerOuterElectricalHeader(_ game: inout Game) throws {
    let flight = game.commander.flightSimulation
    let main = game.commander.savedPlayerElectrical
    let inventory = game.commander.equipmentInventory
    let history = game.commander.equipmentPurchaseHistory
    let energy = game.energy
    game.beginEMPPlayerElectricalInterval(delta: 0.1)
    let stationAutoOwnedCheck16 = game.empPlayerElectricalInterval
    let header = try #require(stationAutoOwnedCheck16)
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.04)
    let path = try #require(pathCandidate)
    let interval = game.advanceCurrentNewtNativeInterval(path)
    let evidence = try #require(interval.evidence)
    let stationAutoOwnedCheck17 =
      evidence.verifiedFinalFlight(
        from: flight, usedD: 0.04,
        epoch: game.nativeStationRuntimeEpoch) == game.commander.flightSimulation
    #expect(stationAutoOwnedCheck17)
    let stationAutoOwnedCheck18 = game.commander.flightSimulation.physicalTime == flight.physicalTime + 0.04
    #expect(stationAutoOwnedCheck18)
    let stationAutoOwnedCheck19 = game.commander.flightSimulation.physicalTime < header.end
    #expect(stationAutoOwnedCheck19)
    game.advancePlayerElectrical()
    let stationAutoOwnedCheck20 = game.empPlayerElectricalInterval == nil
    #expect(stationAutoOwnedCheck20)
    let stationAutoOwnedCheck21 = game.commander.savedPlayerElectrical == main
    #expect(stationAutoOwnedCheck21)
    let stationAutoOwnedCheck22 = game.commander.equipmentInventory == inventory
    #expect(stationAutoOwnedCheck22)
    let stationAutoOwnedCheck23 = game.commander.equipmentPurchaseHistory == history
    #expect(stationAutoOwnedCheck23)
    let stationAutoOwnedCheck24 = game.energy == energy && game.commander.savedEMPCharge == nil
    #expect(stationAutoOwnedCheck24)
  }
}

extension CurrentNewtNativeClockTests {
  @Test func realRetainedSceneJoinsOnlyItsActualOpeningAndUnchangedEndpointGeometry() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyRealRetainedSceneJoinsOnlyItsActualOpeningAndUnchangedEndpointGeometry(&game)
  }

  @inline(never)
  private func verifyRealRetainedSceneJoinsOnlyItsActualOpeningAndUnchangedEndpointGeometry(_ game: inout Game) throws {
    let opening = game.commander.flightSimulation
    let before = game.bodies
    let epoch = game.nativeStationRuntimeEpoch
    let pathCandidate2 = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate2)
    let interval = game.advanceCurrentNewtNativeInterval(path)
    let evidence = try #require(interval.evidence)
    try #require(evidence.completedOuterInterval)
    #expect(
      evidence.retainedSceneMatches(
        opening: opening, bodies: before,
        epoch: epoch, current: game))
    let indexCandidate2 = game.bodies.firstIndex { $0.physical?.currentNewtKitStock != nil }
    let index = try #require(indexCandidate2)
    var moved = game
    moved.bodies[index].position.x += 1
    #expect(
      !evidence.retainedSceneMatches(
        opening: opening, bodies: before,
        epoch: epoch, current: moved))
    var foreign = game
    foreign.bodies[index].physical?.catalogueShipID = "SH005"
    #expect(
      !evidence.retainedSceneMatches(
        opening: opening, bodies: before,
        epoch: epoch, current: foreign))
    var later = game
    later.commander.flightSimulation.advancePhysicalTime(0.01)
    #expect(
      !evidence.retainedSceneMatches(
        opening: opening, bodies: before,
        epoch: epoch, current: later))
    #expect(
      !evidence.retainedSceneMatches(
        opening: opening, bodies: before,
        epoch: UUID(), current: game))
    var changedOpening = before
    changedOpening[index].position.x += 1
    #expect(
      !evidence.retainedSceneMatches(
        opening: opening, bodies: changedOpening,
        epoch: epoch, current: game))
    var changedFlight = opening
    _ = changedFlight.allocateEmission()
    #expect(
      !evidence.retainedSceneMatches(
        opening: changedFlight, bodies: before,
        epoch: epoch, current: game))
    let stationAutoOwnedCheck25 = game.commander.flightSimulation.physicalTime == path.endTime
    #expect(stationAutoOwnedCheck25)
  }
}

extension CurrentNewtNativeClockTests {
  @Test func actualIntervalRetainsLaunchedMissileThroughItsRealGuidanceWindow() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyActualIntervalRetainsLaunchedMissileThroughItsRealGuidanceWindow(&game)
  }

  @inline(never)
  private func verifyActualIntervalRetainsLaunchedMissileThroughItsRealGuidanceWindow(_ game: inout Game) throws {
    let targetCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate)
    let missileLaunched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(missileLaunched)
    let missileCandidate = game.bodies.first { $0.physical?.ordnance != nil }
    let missile = try #require(missileCandidate)
    let actor = try #require(missile.physical?.identity)
    let start = game.commander.flightSimulation
    let pathCandidate3 = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate3)
    let ownedPreparationRequired1 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired1)
    let entryCandidate = frame.entries.first { $0.actor == actor }
    let entry = try #require(entryCandidate)
    let firstGuidance = try #require(entry.guidanceLeg(at: path.startTime))
    try #require(firstGuidance.endTime == path.endTime)
    let expected = try #require(entry.state(at: path.endTime))
    let outcome = game.advanceCurrentNewtNativeInterval(path)
    let evidence = try #require(outcome.evidence)
    #expect(outcome.fullMotionAttained && evidence.completedOuterInterval)
    let stationAutoOwnedCheck26 =
      evidence.verifiedFinalFlight(
        from: start, usedD: path.motion.duration,
        epoch: game.nativeStationRuntimeEpoch) == game.commander.flightSimulation
    #expect(stationAutoOwnedCheck26)
    let retainedCandidate = game.bodies.first { $0.physical?.identity == actor }
    let retained = try #require(retainedCandidate)
    let state = try #require(retained.physical?.ordnance)
    #expect(state.lastUpdatedAt == path.endTime && state.termination == nil)
    #expect(entry.matchesCurrentState(state, at: path.endTime))
    #expect(state.position == expected.position && state.velocity == expected.velocity)
    let stationAutoOwnedCheck27 = game.commander.flightSimulation.nextIncident == start.nextIncident
    #expect(stationAutoOwnedCheck27)
  }
}

extension CurrentNewtNativeClockTests {
  @Test func actualZeroTimeFatalMissileSettlesDeathWithoutAdvancingTheClock() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyActualZeroTimeFatalMissileSettlesDeathWithoutAdvancingTheClock(&game)
  }

  @inline(never)
  private func verifyActualZeroTimeFatalMissileSettlesDeathWithoutAdvancingTheClock(_ game: inout Game) throws {
    let sourceCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let source = try #require(sourceCandidate)
    try #require(source.missiles > 0)
    let npcMissileLaunched = game.launchGameplayNPCMissile(bodyID: source.id)
    try #require(npcMissileLaunched)
    let missileCandidate2 = game.bodies.first { $0.physical?.ordnance != nil }
    let missile = try #require(missileCandidate2)
    let shot = try #require(missile.physical?.ordnance)
    // Place the observer at the genuinely launched point. The actual native
    // solid-overlap query must produce the zero-time contact; no witness,
    // origin, projectile state or clock is supplied by the test.
    var observer = game.commander.flightSimulation.pose
    observer.position = shot.position
    NativePagedSalvageFixture.moveObserver(&game, to: observer)
    game.frontShield = 0
    game.rearShield = 0
    game.energy = 1
    let start = game.commander.flightSimulation
    let pathCandidate4 = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate4)
    let outcome = game.advanceCurrentNewtNativeInterval(path)
    let stationAutoOwnedCheck28 = game.screen == .gameOver && game.energy <= 0
    #expect(stationAutoOwnedCheck28)
    let stationAutoOwnedCheck29 = game.commander.flightSimulation.physicalTime == start.physicalTime
    #expect(stationAutoOwnedCheck29)
    #expect(!outcome.fullMotionAttained && outcome.evidence == nil)
    let stationAutoOwnedCheck30 = game.commander.flightSimulation.nextIncident == start.nextIncident + 2
    #expect(stationAutoOwnedCheck30)
    let stationAutoOwnedCheck31 = game.bodies.first { $0.id == missile.id }?.physical?.ordnance
    let retained = try #require(stationAutoOwnedCheck31)
    #expect(retained.termination == .impact && retained.lastUpdatedAt == start.physicalTime)
    #expect(
      retained.position == shot.position && retained.propulsionTravel == shot.propulsionTravel)
    let stationAutoOwnedCheck32 = !game.paused && game.message == "GAME OVER"
    #expect(stationAutoOwnedCheck32)
  }
}
