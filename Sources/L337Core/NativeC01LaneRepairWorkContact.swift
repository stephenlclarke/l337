import Foundation

struct NativeC01LaneRepairReview: Sendable, Equatable {
  let nonce: UUID
  let mission: UUID
  let revision: UInt64
  let target: NativeC01LaneRepair.Target
  let actor: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
}

enum NativeC01LaneRepairIntervalResult: String, Sendable {
  case missingStart, missingEnd, authorityRefused, clockRefused
  case attainedRefused, observerRefused, credited
  case attained, attainedShapeRefused, attainedProjectionRefused, attainedRotationMarginRefused
  case attainedStationaryRefused, attainedSightlineSweepRefused
  case attainedQualificationRefused, attainedPlayerSweepRefused
}

struct NativeC01LaneRepairWorkRuntime: Sendable {
  var review: NativeC01LaneRepairReview?
  var arm: NativeC01LaneRepairLiveArm?
  var reason = "Select an original Lareria relay; Return reviews calibration."
  var lastIntervalResult: NativeC01LaneRepairIntervalResult?
  var dirty = false
  var publishedSeconds = 0.0
}

final class NativeC01LaneRepairEndpoint: Sendable {
  let arm: UUID
  let target: NativeC01LaneRepair.Target
  let actor: ActorIdentity
  let player: ActorIdentity
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let time: Double
  let range: Double
  let speed: Double
  let aim: Double

  fileprivate let pose: ShipPose
  fileprivate let velocity: Vector3
  fileprivate let playerMesh: Mesh
  fileprivate let playerHull: PreparedHull
  fileprivate let sightlineHull: PreparedHull
  fileprivate let stationaryPlayerIntegration: Bool
  fileprivate let playerPerformance: ShipPerformance
  fileprivate let obstacles: [HullSweepObstacle]
  fileprivate let projections: [Int: Projection]

  fileprivate struct Projection: Sendable {
    let identity: ActorIdentity
    let pose: ShipPose
    let velocity: Vector3
    let angularVelocity: Vector3
    let energy: Double
    let mesh: Mesh
    let hull: PreparedHull
    let angularRateBound: Double
    let profile: ScriptNPCDefinition?
    let modelRotationRate: Double
  }

  fileprivate init?(game: inout Game) {
    guard !game.docked, !game.paused, game.screen == .front, game.energy > 0,
      !game.playerEMPDisabled, game.systemIdentity == NativeC01LaneRepair.location,
      let live = game.c01LaneRepairWorkRuntime.arm,
      live.binding.epoch == game.nativeStationRuntimeEpoch,
      live.binding.carrier == game.commander.hullInstanceID,
      live.binding.inventoryRevision == game.commander.equipmentInventory?.revision,
      let mission = game.glassMeridianMission, let opening = mission.savedGlassMeridian,
      let state = opening.laneRepair, state.installation == nil,
      opening.surveyor?.held == true, opening.timingStandard?.held == true,
      state.source.mission == live.binding.mission,
      state.source.permission == live.binding.permission,
      state.source.standard == live.binding.standard,
      state.source.owner == live.binding.owner,
      game.commander.equipmentOwnerID == live.binding.owner,
      game.commander.flightSimulation.player == live.binding.player,
      !state.receipts.contains(where: { $0.target == live.binding.target }),
      let progress = state.progress.first(where: { $0.target == live.binding.target }),
      (progress.completionArm ?? progress.segments.last?.arm) == live.binding,
      let actor = game.c01LaneRepairActor(source: state.source, target: live.binding.target),
      actor.body.physical?.identity == live.binding.actor, game.weaponsTargetID == actor.body.id,
      let physical = actor.body.physical, physical.canonicalSpin == true,
      let prop = try? NativeC01Props.relay.get(),
      let contact = try? game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 150.000001,
        radius: 0, includePlayer: false), contact.hit.target == .body(actor.body.id)
    else { return nil }
    let playerPose = game.commander.flightSimulation.pose
    let targetPose = game.modelPose(of: actor.body)
    let worldHit = playerPose.systemPoint(contact.hit.point)
    let localHit = targetPose.shipPoint(worldHit)
    guard prop.interactionFace.contains(localHit, in: prop.nativeDesign) else { return nil }
    let normal = targetPose.orientation.apply(prop.interactionFace.outward)
    let center = targetPose.systemPoint(prop.interactionFace.center)
    let offset = center - playerPose.position
    let rayRange = contact.hit.distance
    let angularPointVelocity = physical.angularVelocity.cross(worldHit - targetPose.position)
    let relativeSpeed = (game.flightWorldVelocity - physical.velocity - angularPointVelocity).length
    let aiming = acos(max(-1, min(1, playerPose.orientation.z.dot(offset.unit))))
    let mesh = game.commander.playerMesh
    guard mesh.vertices.count >= 4,
      let support = mesh.vertices.map({ playerPose.orientation.apply($0).dot(normal * -1) }).max(),
      support.isFinite,
      normal.dot(playerPose.position - center) >= max(50, support + 5),
      NativeC01LaneRepair.qualifies(range: rayRange, speed: relativeSpeed, aim: aiming),
      let prepared = game.preparedWorkHull(
        mesh: mesh, key: "c01-lane-player:\(live.binding.carrier):\(live.binding.inventoryRevision)")
    else { return nil }
    // This closed query volume contains every point of the full forward work ray.
    // Obstacles retain their actual native meshes; unresolved sweeps refuse visibility.
    guard let sightlineHull = game.preparedWorkHull(
      mesh: NativeC01LaneRepair.sightlineMesh, key: "c01-lane-stationary-sightline-150m-1mm-v1")
    else { return nil }
    var obstacles: [HullSweepObstacle] = []
    for (index, celestial) in game.celestials.enumerated() {
      guard let hull = game.preparedWorkHull(
        mesh: game.workObstacleBox(celestial.radius), key: "c01-lane-celestial:\(index)")
      else { return nil }
      obstacles.append(.init(
        hull: hull, pose: .init(position: playerPose.systemPoint(celestial.position)),
        clearanceOverride: 5))
    }
    var projections: [Int: Projection] = [:]
    for body in game.bodies where body.energy > 0 {
      guard let native = body.physical, native.velocity.finite, native.angularVelocity.finite,
        projections[body.id] == nil
      else { return nil }
      let bodyMesh = game.gameplayMesh(for: body)
      guard let hull = game.preparedWorkHull(
        mesh: bodyMesh, key: "c01-lane-body:\(native.identity)")
      else { return nil }
      let profile = body.scriptNPC?.fit.definition
      let steeringBound = profile.map { abs($0.pitch) + abs($0.yaw) + abs($0.roll) } ?? 0
      let angularRateBound = native.angularVelocity.length + abs(body.rotationRate) * 1.4
        + steeringBound
      guard angularRateBound.isFinite else { return nil }
      projections[body.id] = .init(
        identity: native.identity, pose: game.modelPose(of: body), velocity: native.velocity,
        angularVelocity: native.angularVelocity, energy: body.energy, mesh: bodyMesh, hull: hull,
        angularRateBound: angularRateBound, profile: profile, modelRotationRate: body.rotationRate)
    }
    self.arm = live.binding.operation
    target = live.binding.target
    self.actor = physical.identity
    player = live.binding.player
    owner = live.binding.owner
    carrier = live.binding.carrier
    inventoryRevision = live.binding.inventoryRevision
    epoch = live.binding.epoch
    time = game.commander.flightSimulation.physicalTime
    range = rayRange
    speed = relativeSpeed
    aim = aiming
    pose = playerPose
    velocity = game.flightWorldVelocity
    playerMesh = mesh
    playerHull = prepared
    self.obstacles = obstacles
    self.projections = projections
    self.sightlineHull = sightlineHull
    playerPerformance = game.commander.performance
    // Actual tick uses these fixed rates for its one integration. Reject controllers or spin
    // that could turn/reverse between equal endpoint poses; a visual pose comparison is insufficient.
    stationaryPlayerIntegration = game.speed == 0 && game.pitch == 0 && game.yaw == 0
      && game.roll == 0 && !game.spin.mode && game.spin.actualRate == 0
      && game.spin.commandedRate == 0 && game.autoPilot.targetID == nil
      && game.autoPilot.velocity.length == 0 && game.autoPilot.rollRate == 0
      && game.workGuidance == nil && game.workBraking == nil && !game.manualResidualFlight
      && game.lastAppliedWorkMotion == nil
  }

  func sameAuthority(_ other: NativeC01LaneRepairEndpoint) -> Bool {
    arm == other.arm && target == other.target && actor == other.actor && player == other.player
      && owner == other.owner && carrier == other.carrier
      && inventoryRevision == other.inventoryRevision && epoch == other.epoch
  }
}

extension Game {
  mutating func c01LaneRepairEndpoint() -> NativeC01LaneRepairEndpoint? {
    NativeC01LaneRepairEndpoint(game: &self)
  }

  /// Continuous full-hull proof uses only the two endpoints attained by the real game frame.
  func c01LaneRepairAttained(
    from start: NativeC01LaneRepairEndpoint, to end: NativeC01LaneRepairEndpoint
  ) -> NativeC01LaneRepairIntervalResult {
    guard start.sameAuthority(end), start.pose.orientation.validRotation,
      start.playerMesh.vertices == end.playerMesh.vertices,
      start.playerMesh.faces == end.playerMesh.faces,
      start.projections.count == end.projections.count,
      start.obstacles.count == end.obstacles.count,
      zip(start.obstacles, end.obstacles).allSatisfy({ before, after in
        before.pose == after.pose && before.hull.radius == after.hull.radius
          && before.velocity == after.velocity && before.angularVelocity == after.angularVelocity
          && before.clearanceOverride == after.clearanceOverride
      }),
      let prop = try? NativeC01Props.relay.get(),
      let motion = NativeC01TimingStandard.rigidMotion(
        from: start.pose, to: end.pose, duration: end.time - start.time,
        radius: start.playerHull.radius)
    else { return .attainedShapeRefused }
    let duration = end.time - start.time
    var obstacles = start.obstacles
    var targetMotion: HullSceneMotion?
    var sightlineRotationMargins: [ActorIdentity: Double] = [:]
    for (id, before) in start.projections {
      guard let after = end.projections[id], before.identity == after.identity,
        before.mesh.vertices == after.mesh.vertices, before.mesh.faces == after.mesh.faces,
        before.energy == after.energy, before.profile == after.profile,
        before.modelRotationRate == after.modelRotationRate,
        max(before.angularRateBound, after.angularRateBound) * duration < 1,
        let actual = NativeC01TimingStandard.rigidMotion(
          from: before.pose, to: after.pose, duration: duration, radius: before.hull.radius)
      else { return .attainedProjectionRefused }
      // Bound every actual declared spin/steering arc around the initial native mesh.
      // This also covers noncommuting pitch/yaw/roll paths rather than assuming that
      // equal endpoint orientations imply no intervening rotation.
      let rotationBound = max(
        max(before.angularRateBound, after.angularRateBound), actual.worldAngularVelocity.length)
      let rotationMargin = before.hull.radius * rotationBound * duration
      guard rotationMargin.isFinite else { return .attainedRotationMarginRefused }
      sightlineRotationMargins[before.identity] = rotationMargin
      obstacles.append(.init(
        identity: before.identity, hull: before.hull, pose: before.pose,
        velocity: actual.initialVelocity, angularVelocity: actual.worldAngularVelocity,
        clearanceOverride: 5))
      if before.identity == start.actor { targetMotion = actual }
    }
    guard let targetMotion,
      // A stationary actual player/relay frame preserves the exact first native-face hit
      // throughout this interval. Moving face contact needs its own continuous proof.
      start.stationaryPlayerIntegration, end.stationaryPlayerIntegration,
      start.playerPerformance == end.playerPerformance,
      start.pose == end.pose, start.velocity.length == 0, end.velocity.length == 0,
      let targetBefore = start.projections.values.first(where: { $0.identity == start.actor }),
      let targetAfter = end.projections.values.first(where: { $0.identity == end.actor }),
      targetBefore.pose == targetAfter.pose,
      targetBefore.velocity.length == 0, targetAfter.velocity.length == 0,
      targetBefore.angularVelocity.length == 0, targetAfter.angularVelocity.length == 0,
      let sightlineMotion = NativeC01TimingStandard.rigidMotion(
        from: start.pose, to: end.pose, duration: duration, radius: start.sightlineHull.radius)
    else { return .attainedStationaryRefused }
    // The whole ray exists at every instant; sweeping a point down it would miss transverse
    // crossings. Only the proven stationary selected native target may be excluded here.
    // Other native meshes translate with actual attained motion. Their complete rotation is
    // enclosed by the radius*angular-travel clearance, including steering path uncertainty.
    let sightlineObstacles = obstacles.filter { $0.identity != start.actor }.map {
      HullSweepObstacle(
        identity: $0.identity, hull: $0.hull, pose: $0.pose,
        velocity: $0.velocity, angularVelocity: .init(0, 0, 0),
        clearanceOverride: $0.identity.flatMap { sightlineRotationMargins[$0] } ?? 0)
    }
    guard HullSweepSafety.validateSceneMotion(
      sightlineMotion, player: start.sightlineHull, obstacles: sightlineObstacles).safe
    else { return .attainedSightlineSweepRefused }
    let conservativeRelativeSpeed =
      (motion.initialVelocity - targetMotion.initialVelocity).length
      + targetMotion.worldAngularVelocity.length * prop.interactionFace.center.length
    guard NativeC01LaneRepair.qualifies(
      range: start.range, speed: max(start.speed, conservativeRelativeSpeed), aim: start.aim),
      NativeC01LaneRepair.qualifies(
        range: end.range, speed: max(end.speed, conservativeRelativeSpeed), aim: end.aim)
    else { return .attainedQualificationRefused }
    let safe = HullSweepSafety.validateSceneMotion(
      motion, player: start.playerHull, obstacles: obstacles).safe
    return safe ? .attained : .attainedPlayerSweepRefused
  }
}

extension NativeC01LaneRepair {
  /// A conservative line-query volume, not a replacement shape for any actual obstacle.
  fileprivate static let sightlineMesh = Mesh(
    vertices: [
      .init(-0.001, -0.001, -0.001), .init(0.001, -0.001, -0.001),
      .init(0.001, 0.001, -0.001), .init(-0.001, 0.001, -0.001),
      .init(-0.001, -0.001, 150.001), .init(0.001, -0.001, 150.001),
      .init(0.001, 0.001, 150.001), .init(-0.001, 0.001, 150.001),
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
      [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ], preserveWinding: true)
}
