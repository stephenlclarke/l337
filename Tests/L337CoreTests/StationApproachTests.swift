import Foundation
import Testing

@testable import L337Core

private func approachGame(
  position: Vector3, pitch: Double = 0, roll: Double = 0, yaw: Double = 0,
  spin: Double = 0.3, speed: Double = 0
) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("current targeting unit fixture"))
  game.launch()
  try #require(!game.docked && game.screen == .front && game.commander.valid)
  #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .docking)
  game.commander.autoTarget = true
  game.speed = speed
  let anchor = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  var orientation = Basis3()
  orientation.rotate(pitch: pitch, roll: roll, yaw: yaw)
  // Move the observer, preserving the launched station's native anchor and physical identity.
  let camera = anchor.orientation.composed(with: orientation.transposed)
  NativeStationTestFixture.reframe(
    &game,
    to: .init(position: anchor.position - camera.apply(position), orientation: camera))
  game.bodies.removeAll { $0.id != 0 }
  let index = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  game.bodies[index].rotation = 1.4
  game.bodies[index].rotationRate = spin
  try #require(game.bodies[index].physical?.identity == anchor.identity)
  #expect((game.bodies[index].position - position).length < 1e-8)
  for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
    #expect((game.bodies[index].orientation.apply(axis) - orientation.apply(axis)).length < 1e-8)
  }
  try engageMainApproachStation(&game, identity: anchor.identity)
  return game
}

private func engageMainApproachStation(_ game: inout Game, identity: ActorIdentity) throws {
  game.ensurePhysicalActors()
  // A retained partial cycle may already have visited main; finish it and allow one fresh cycle.
  for _ in 0..<(game.bodies.count * 2) {
    game.key("tab")
    if game.autoPilot.targetActor == identity { break }
  }
  try #require(game.autoPilot.targetID == 0 && game.autoPilot.targetActor == identity)
}

// Pure attained-step geometry/control setup; it mints no docking or arrival receipt.
private func originalMainStationStep(
  lateral: Double = 3, hullPitch: Double = 0, delta: Double = 0.1
) throws -> (Game, ShipPose) {
  var game = Game(executive: false)
  game.commander.shipID = "SH025"
  game.commander.fuel = game.commander.fuelCapacity
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("current targeting unit fixture"))
  game.launch()
  try #require(!game.docked && game.commander.valid)
  let anchor = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  try engageMainApproachStation(&game, identity: anchor.identity)
  let station = try #require(game.bodies.first { $0.id == 0 })
  let model = game.modelPose(of: station)
  let port = MainStationGeometry.docking
  var before = ShipPose()
  before.position = model.systemPoint(
    port.center + port.outward * 6 + port.up.cross(port.outward) * lateral)
  before.orientation.z = model.orientation.apply(port.outward) * -1
  before.orientation.y = model.orientation.apply(port.up)
  before.orientation.x = before.orientation.y.cross(before.orientation.z)
  before.orientation.rotate(pitch: hullPitch, roll: 0, yaw: 0)
  NativeStationTestFixture.reframe(&game, to: before)
  game.speed = 0
  game.pitch = 0
  game.yaw = 0
  game.roll = station.rotationRate
  game.autoPilot.setApproachVelocity(.init(0, 0, 48))
  var after = before
  after.advanceView(
    pitch: 0, roll: game.roll * delta, yaw: 0, translation: .init(0, 0, 48 * delta))
  NativeStationTestFixture.reframe(&game, to: after)
  game.commander.flightSimulation.advancePhysicalTime(delta)
  let index = try #require(game.bodies.firstIndex { $0.id == 0 })
  try #require(game.bodies[index].rotationRate == 0.3)
  game.bodies[index].rotation = station.rotation + station.rotationRate * delta
  return (game, before)
}

@Test func attainedOriginalSH025StepUsesTheSamePortAndWholeHullProof() throws {
  let (game, before) = try originalMainStationStep()
  let station = try #require(game.bodies.first { $0.id == 0 })
  let player = game.commander.playerMesh
  let port = MainStationGeometry.docking
  let radius = try #require(player.vertices.map(\.length).max())
  let stationRadius = try #require(MainStationGeometry.mesh.vertices.map(\.length).max())
  let coarse = (radius + stationRadius) * (abs(game.roll) + abs(station.rotationRate)) * 0.1
  let halfWidth = try #require(port.aperture.map(\.x).max())
  let support = try #require(player.vertices.map { abs($0.x) }.max())
  #expect(halfWidth == 62.32 && port.aperture.map(\.y).max() == 50.8 && port.fits(player))
  #expect(halfWidth - support - 3 > 0 && halfWidth - support - 3 < coarse)
  #expect(
    game.nativeMainStationHullCourseIsClear(
      station, from: before, to: game.commander.flightSimulation.pose, delta: 0.1))
  #expect(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
  #expect(!game.nativeMainStationDockEvidenceIsCurrent)
}

@Test func originalPortRefusesOversizeOrientationWallContactAndStaleAttainedMotion() throws {
  let wallOffset = try #require(MainStationGeometry.docking.aperture.map(\.x).max())
  for (lateral, hullPitch) in [(wallOffset, 0.0), (3.0, Double.pi / 2)] {
    let (game, before) = try originalMainStationStep(lateral: lateral, hullPitch: hullPitch)
    let station = try #require(game.bodies.first { $0.id == 0 })
    #expect(
      !game.nativeMainStationHullCourseIsClear(
        station, from: before, to: game.commander.flightSimulation.pose, delta: 0.1))
    #expect(
      !game.nativeMainStationHullCourseIsClear(
        station, from: before, to: game.commander.flightSimulation.pose,
        delta: 0.1, requireAperture: false))
  }
  var (game, before) = try originalMainStationStep()
  let station = try #require(game.bodies.first { $0.id == 0 })
  let end = game.commander.flightSimulation.pose
  try #require(game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
  game.autoPilot.setApproachVelocity(.init(0, 0, 24))
  #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
  game.autoPilot.setApproachVelocity(.init(0, 0, 48))
  game.dockingComputer = false
  #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
  game.dockingComputer = true
  var proposed = end
  proposed.position.z += 0.001
  #expect(
    !game.nativeMainStationHullCourseIsClear(station, from: before, to: proposed, delta: 0.1))
  game.bodies.append(station)
  #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
  #expect(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
  // The old SH171/32-half-height input does not describe this original port.
  // The unchanged 64-interval production cap is not exercised or credited by this fixture.
}

@Test func rearAvoidanceWaypointDoesNotOrbitWithTheStationDoorwayPhase() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(300, 100, 2400))
  station.orientation.rotate(pitch: 0.1, roll: 0.4, yaw: .pi)
  var first = AutoTargetControl()
  let baseline = first.steer(target: station, delta: 0.02)
  for phase in [0.7, 1.4, 2.8, 4.2] {
    station.rotation = phase
    var control = AutoTargetControl()
    let steering = control.steer(target: station, delta: 0.02)
    #expect(abs(steering.pitch - baseline.pitch) < 1e-12)
    #expect(abs(steering.yaw - baseline.yaw) < 1e-12)
    #expect(control.velocity == first.velocity)
  }
}

@Test func stationTransitFacesItsSafeWaypointThenStopsBeforeFacingTheDoor() throws {
  var game = try approachGame(position: .init(0, 0, 2400), yaw: 0)
  var forwardTransitFrames = 0
  var stoppedAlignmentFrames = 0
  for _ in 0..<9000 where !game.autoPilot.finalApproach && !game.docked {
    game.tick(delta: 0.02)
    game.bodies.removeAll { $0.hull != .station }
    let control = game.autoPilot
    if control.status == "APPROACHING" && control.facingError < 0.08 && control.velocity.length > 20
    {
      forwardTransitFrames += 1
      #expect(control.velocity.z > control.velocity.length * 0.96)
    }
    if control.status == "ALIGNING" && control.velocity.length < 1 {
      stoppedAlignmentFrames += 1
      #expect(control.positionError < 40)
    }
  }
  #expect(forwardTransitFrames > 100)
  #expect(stoppedAlignmentFrames > 20)
  #expect(game.autoPilot.finalApproach)
  #expect(game.autoPilot.facingError < 0.02)
}

@Test func stationApproachCompletesForwardAndCollisionFreeForBehindTiltedAndFastStarts() throws {
  let starts: [(Vector3, Double, Double, Double, Double, Double)] = [
    (.init(0, 0, 2400), 0, 0, 0, 0.3, 0),
    (.init(0, 0, -2400), 0, 0, 0, -0.3, 0),
    (.init(0, 0, 2400), 0, 0, .pi, -0.3, 24),
    (.init(600, 400, 2400), 0.21, 0, 0.7, 0.3, 32),
    (.init(1200, 700, 1600), 0.6, 0.4, 0.8, -0.3, 0),
    (.init(0, 0, 1090), 0, 0, 0, 0.3, 0),
  ]
  for (position, pitch, roll, yaw, spin, speed) in starts {
    var game = try approachGame(
      position: position, pitch: pitch, roll: roll, yaw: yaw, spin: spin, speed: speed)
    var collided = false
    var finalFrames = 0
    var shortestDoorDistance = Double.infinity
    var stoppedTransitFrames = 0
    var longestStoppedTransit = 0
    for _ in 0..<9000 where !game.docked {
      let before = game.bodies.first { $0.hull == .station }!
      shortestDoorDistance = min(shortestDoorDistance, before.entrancePosition.length)
      game.tick(delta: 0.02)
      game.bodies.removeAll { $0.hull != .station }
      collided = collided || game.message == "DOCKING COLLISION"
      let control = game.autoPilot
      if control.status == "APPROACHING" && control.velocity.length < 1 {
        stoppedTransitFrames += 1
        longestStoppedTransit = max(longestStoppedTransit, stoppedTransitFrames)
      } else {
        stoppedTransitFrames = 0
      }
      if let after = game.bodies.first(where: { $0.hull == .station }) {
        // Rotation preserves range. Every positional change must come from actual
        // bounded flight translation, including travel around the station's rear.
        #expect(
          abs(after.position.length - before.position.length) <= control.velocity.length * 0.02
            + 0.001)
        if !control.finalApproach { #expect(after.position.length >= 399.9) }
        if control.status == "FINAL APPROACH" {
          finalFrames += 1
          #expect(control.velocity.z > 0)
          #expect(after.entrancePosition.length < before.entrancePosition.length)
        }
      }
    }
    #expect(game.docked && game.screen == .status, "Start: \(position), yaw: \(yaw)")
    #expect(!collided)
    #expect(finalFrames > 100)
    #expect(shortestDoorDistance < 2)
    #expect(longestStoppedTransit < 750)
  }
}

@Test func stationTurnBrakesExistingCruiseWithoutInstantVelocityChangesAndManualInputCancels()
  throws
{
  var game = try approachGame(position: .init(0, 0, -2400), speed: 32)
  let initialSpeed = game.autoPilot.velocity.length
  game.tick(delta: 0.02)
  #expect(game.autoPilot.velocity.length > initialSpeed - 4.81)
  #expect(game.autoPilot.velocity.length < initialSpeed)
  #expect(game.autoPilot.status == "APPROACHING")
  for _ in 0..<60 { game.tick(delta: 0.02) }
  #expect(game.autoPilot.targetID != nil)
  var controls = Controls()
  controls.yaw = 0.4
  let beforeTakeoverVelocity = game.flightWorldVelocity
  let beforeTakeoverPosition = game.commander.flightSimulation.pose.position
  game.tick(delta: 0.02, controls: controls)
  #expect(game.autoPilot.targetID == nil && game.manualResidualFlight && game.speed == 0)
  #expect((game.flightWorldVelocity - beforeTakeoverVelocity).length < 1e-8)
  #expect(
    (game.commander.flightSimulation.pose.position - beforeTakeoverPosition
      - beforeTakeoverVelocity * 0.02).length < 1e-8)
  #expect(!game.dockingComputer)
  let releasedPosition = game.commander.flightSimulation.pose.position
  game.tick(delta: 0.02)
  #expect(
    (game.flightWorldVelocity - beforeTakeoverVelocity).length
      <= game.workLimits.acceleration * 0.02 + 1e-8)
  #expect(
    (game.commander.flightSimulation.pose.position - releasedPosition
      - beforeTakeoverVelocity * 0.02).length < 1e-8)
  let anchor = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  let momentum = game.flightWorldVelocity
  let pose = ShipPose(
    position: anchor.position - anchor.orientation.apply(.init(500, 0, 2400)),
    orientation: anchor.orientation)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.autoPilot.setApproachVelocity(pose.shipVector(momentum))
  game.speed = 0
  try engageMainApproachStation(&game, identity: anchor.identity)
  for _ in 0..<100 { game.tick(delta: 0.02) }
  #expect(game.autoPilot.status == "APPROACHING" && !game.autoPilot.finalApproach)
}

@Test func freshLaunchCurrentPeregrineAndOkapiDockFromTheActualCloseRearStation() throws {
  for shipID in ["SH025", "SH029"] {
    var game = Game(executive: false)
    game.commander.shipID = shipID
    game.commander.fuel = game.commander.fuelCapacity
    try #require(game.commander.valid)
    try game.commander.prepareEquipment(legacy: false)
    try game.commander.grantEquipment(
      TargetingTier.docking.equipmentName, at: .targetingCore,
      provenance: .grant("current targeting unit fixture"))
    game.launch()
    try #require(!game.docked && game.screen == .front)
    game.bodies.removeAll { $0.hull != .station }
    #expect(game.speed == 8)
    #expect(try #require(game.bodies.first).position == Vector3(0, 0, -500))
    game.key("tab")
    var collided = false
    var finalFrames = 0
    var minimumTransitRange = Double.infinity
    var elapsed = 0.0
    for _ in 0..<9000 where !game.docked {
      game.tick(delta: 0.02)
      elapsed += 0.02
      game.bodies.removeAll { $0.hull != .station }
      collided = collided || game.message == "DOCKING COLLISION"
      if game.autoPilot.status == "FINAL APPROACH" { finalFrames += 1 }
      if !game.autoPilot.finalApproach, let station = game.bodies.first {
        minimumTransitRange = min(minimumTransitRange, station.position.length)
      }
    }
    #expect(
      game.docked,
      "\(shipID): \(game.autoPilot.status), facing \(game.autoPilot.facingError), goal \(game.autoPilot.positionError), velocity \(game.autoPilot.velocity)"
    )
    #expect(!collided && minimumTransitRange >= 399.9)
    #expect(finalFrames > 100 && elapsed < 90, "\(shipID): \(elapsed) simulated seconds")
  }
}
