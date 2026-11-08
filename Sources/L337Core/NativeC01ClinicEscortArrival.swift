import Foundation

/// A closed immutable copy of the existing native scene observation. Explicit value
/// fields keep the clinic's cross-frame storage Sendable without changing the native API.
struct NativeC01ClinicSceneSample: Sendable {
  let system: SystemIdentity
  let visit: UInt64
  let physicalTime: Double
  let pose: ShipPose
  let bodies: [SpaceBody]

  init(_ observed: borrowing NativeWormholeMotionSample) {
    system = observed.system
    visit = observed.visit
    physicalTime = observed.physicalTime
    pose = observed.pose
    bodies = observed.bodies
  }
}

/// Captured only from the current native game before its physical tick; never decoded.
final class NativeC01ClinicAttainedSample: Sendable {
  let native: NativeC01ClinicSceneSample
  let playerMesh: Mesh
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let source: NativeC01ClinicEscortSource
  let birth: NativeC01ClinicStockBirth
  let launch: NativeC01ClinicLaunch?
  let nextIncident: UInt64
  let stock: [Int: ScriptOwnedActor]

  fileprivate init?(game: borrowing Game) {
    guard !game.docked, !game.paused, game.screen.isFlight, game.energy > 0,
      game.systemIdentity == NativeC01ClinicEscort.location,
      let mission = game.glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      let group = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter], group.admitted,
      let carrier = game.nativeGuidanceStoredEquipmentInventory()?.activeHull,
      let revision = game.nativeGuidanceStoredEquipmentInventory()?.revision
    else { return nil }
    native = .init(NativeWormholeMotionSample(game))
    playerMesh = game.nativeGuidanceStoredPlayerMesh()
    self.carrier = carrier
    inventoryRevision = revision
    epoch = game.nativeStationRuntimeEpoch
    source = state.source
    birth = state.birth
    launch = state.current
    nextIncident = game.storedFlightSimulation().nextIncident
    var observed: [Int: ScriptOwnedActor] = [:]
    for ordinal in 0..<NativeC01ClinicEscort.maximumLaunches {
      guard state.loss(for: ordinal) == nil,
        let body = game.bodies.first(where: {
          $0.missionActorID == NativeC01ClinicEscort.actor(mission: mission.id, ordinal: ordinal)
        }), body.energy > 0,
        let actual = game.c01ClinicStockActor(body, ordinal: ordinal), actual.presence == .present
      else { continue }
      observed[ordinal] = actual
    }
    stock = observed
  }
}

/// Only the actual crossing/full-scene proof in this file can create receiving authority.
final class NativeC01ClinicArrivalWitness: Sendable {
  let source: NativeC01ClinicEscortSource
  let launch: NativeC01ClinicLaunch
  let actor: ScriptOwnedActor
  let stationActor: ActorIdentity
  let from: ShipPose
  let to: ShipPose
  let stationFrom: ShipPose
  let stationTo: ShipPose
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID

  fileprivate init(
    source: NativeC01ClinicEscortSource, launch: NativeC01ClinicLaunch, actor: ScriptOwnedActor,
    stationActor: ActorIdentity, from: ShipPose, to: ShipPose,
    stationFrom: ShipPose, stationTo: ShipPose, startTime: Double,
    physicalTime: Double, epoch: UUID
  ) {
    self.source = source
    self.launch = launch
    self.actor = actor
    self.stationActor = stationActor
    self.from = from
    self.to = to
    self.stationFrom = stationFrom
    self.stationTo = stationTo
    self.startTime = startTime
    self.physicalTime = physicalTime
    self.epoch = epoch
  }
}

extension Game {
  func c01ClinicAttainedSample() -> NativeC01ClinicAttainedSample? {
    NativeC01ClinicAttainedSample(game: self)
  }

  mutating func c01ClinicArrivalWitness(
    from sample: NativeC01ClinicAttainedSample
  ) -> NativeC01ClinicArrivalWitness? {
    let prior = sample.native
    let flight = commander.flightSimulation
    let duration = flight.physicalTime - prior.physicalTime
    guard !docked, !paused, screen.isFlight, energy > 0,
      sample.epoch == nativeStationRuntimeEpoch,
      sample.carrier == commander.hullInstanceID,
      sample.inventoryRevision == commander.equipmentInventory?.revision,
      prior.system == systemIdentity, prior.visit == flight.visit,
      duration.isFinite, duration > 0, duration <= NativeC01LaneRepair.maximumPhysicalInterval,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      state.source == sample.source, state.birth == sample.birth,
      let launch = sample.launch, state.current == launch, state.arrival == nil,
      launch.loss == nil,
      let actor = c01ClinicTenderActor(launch: launch), let physical = actor.body.physical,
      let old = prior.bodies.first(where: { $0.physical?.identity == physical.identity }),
      (modelPose(of: actor.body).position - flight.pose.position).length
        <= NativeC01ClinicEscort.stayNearMetres,
      (Self.clinicModelPose(old, player: prior.pose).position - prior.pose.position).length
        <= NativeC01ClinicEscort.stayNearMetres,
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station && $0.energy > 0 }),
      let stationActor = station.physical?.identity,
      let oldStation = prior.bodies.first(where: { $0.physical?.identity == stationActor }),
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == sample.source.station, facility.observation.actor == stationActor,
      let currentAnchor = currentNativeMainStationAnchor(at: flight.physicalTime),
      let oldAnchor = currentNativeMainStationAnchor(at: prior.physicalTime),
      (prior.pose.systemPoint(oldStation.position) - oldAnchor.position).length < 1e-5,
      (flight.pose.systemPoint(station.position) - currentAnchor.position).length < 1e-5
    else { return nil }
    let from = Self.clinicModelPose(old, player: prior.pose)
    let to = modelPose(of: actor.body)
    let stationFrom = Self.clinicModelPose(oldStation, player: prior.pose)
    let stationTo = modelPose(of: station)
    guard NativeArkDockCrossing.admits(
      from: from, to: to, stationFrom: stationFrom, stationTo: stationTo, delta: duration),
      let original = try? NativeC01SurveyorGeometry.harrier.get(),
      nativeInductionArkHullSweepIsClear(
        original.collision, from: from, to: to,
        stationFrom: stationFrom, stationTo: stationTo, delta: duration, requireAperture: true),
      c01ClinicSceneMotionIsClear(actor.body, from: prior, playerMesh: sample.playerMesh)
    else { return nil }
    return .init(
      source: sample.source, launch: launch, actor: actor, stationActor: stationActor,
      from: from, to: to, stationFrom: stationFrom, stationTo: stationTo,
      startTime: prior.physicalTime, physicalTime: flight.physicalTime,
      epoch: nativeStationRuntimeEpoch)
  }

  /// All scene meshes remain their actual native geometry, including the hollow source cradle.
  mutating func c01ClinicSceneMotionIsClear(
    _ body: SpaceBody, from sample: NativeC01ClinicSceneSample, playerMesh: Mesh,
    includesNativeSpin: Bool = true
  ) -> Bool {
    let flight = storedFlightSimulation()
    let duration = flight.physicalTime - sample.physicalTime
    guard sample.system == systemIdentity, sample.visit == flight.visit,
      duration.isFinite, duration > 0, duration <= NativeC01LaneRepair.maximumPhysicalInterval,
      let identity = body.physical?.identity,
      let prior = sample.bodies.first(where: { $0.physical?.identity == identity }),
      let original = try? NativeC01SurveyorGeometry.harrier.get(),
      let hull = preparedWorkHull(mesh: original.collision, key: "c01-clinic-moving:\(identity)"),
      let movement = NativeC01TimingStandard.rigidMotion(
        from: Self.clinicModelPose(prior, player: sample.pose), to: modelPose(of: body),
        duration: duration, radius: hull.radius),
      body.scriptNPC != nil,
      prior.scriptNPC?.fit == body.scriptNPC?.fit,
      playerMesh.vertices == nativeGuidanceStoredPlayerMesh().vertices,
      playerMesh.faces == nativeGuidanceStoredPlayerMesh().faces
    else { return false }
    guard let proof = c01ClinicEscortRuntime.controls.first(where: { $0.actor == identity }),
      let turnBound = proof.angularTravel(actor: identity, epoch: nativeStationRuntimeEpoch,
        from: Self.clinicModelPose(prior, player: sample.pose), to: modelPose(of: body),
        startTime: sample.physicalTime, duration: duration, includesNativeSpin: includesNativeSpin)
    else { return false }
    let motion = HullSceneMotion(
      start: movement.start, end: movement.end, initialVelocity: movement.initialVelocity,
      acceleration: movement.acceleration, worldAngularVelocity: movement.worldAngularVelocity,
      duration: duration, playerRadius: hull.radius, requiredClearance: 2 * hull.radius * turnBound)
    var obstacles: [HullSweepObstacle] = []
    guard let playerHull = preparedWorkHull(mesh: playerMesh, key: "c01-clinic-escort-player"),
      let playerMotion = NativeC01TimingStandard.rigidMotion(
        from: sample.pose, to: flight.pose, duration: duration, radius: playerHull.radius)
    else { return false }
    let playerRate = max(
      abs(pitch) + abs(yaw) + abs(roll),
      max(workGuidance?.angularVelocity.length ?? 0, workBraking?.angularVelocity.length ?? 0))
    let playerTurn = max(playerRate, playerMotion.worldAngularVelocity.length) * duration
    guard playerTurn.isFinite, playerTurn < 1 else { return false }
    let vesselMargin = 2 * hull.radius * turnBound
    obstacles.append(.init(
      hull: playerHull, pose: sample.pose, velocity: playerMotion.initialVelocity,
      angularVelocity: .init(0, 0, 0),
      clearanceOverride: 5 + vesselMargin + playerHull.radius * playerTurn))
    guard let mission = glassMeridianMission else { return false }
    let stockActors = Set((0..<NativeC01ClinicEscort.maximumLaunches).map {
      NativeC01ClinicEscort.actor(mission: mission.id, ordinal: $0)
    })
    func obstaclePresent(_ candidate: SpaceBody) -> Bool {
      guard candidate.physical?.identity != identity else { return false }
      // Actual source wrecks remain obstacles; a terminal receipt never clears a route.
      return candidate.energy > 0 || (candidate.missionInstanceID == mission.id
        && candidate.missionActorID.map({ stockActors.contains($0) }) == true)
    }
    let live = bodies.filter { obstaclePresent($0) }
    let before = sample.bodies.filter { obstaclePresent($0) }
    guard live.count == before.count else { return false }
    var seen: Set<ActorIdentity> = []
    for obstacle in live {
      guard let physical = obstacle.physical, seen.insert(physical.identity).inserted,
        let old = before.first(where: { $0.physical?.identity == physical.identity }),
        old.scriptNPC?.fit == obstacle.scriptNPC?.fit,
        let oldPhysical = old.physical,
        physical.velocity.finite, physical.angularVelocity.finite,
        oldPhysical.velocity.finite, oldPhysical.angularVelocity.finite
      else { return false }
      let mesh = gameplayMesh(for: obstacle)
      let oldMesh = gameplayMesh(for: old)
      guard mesh.vertices == oldMesh.vertices, mesh.faces == oldMesh.faces,
        let prepared = preparedWorkHull(mesh: mesh, key: "c01-clinic-obstacle:\(physical.identity)"),
        let actual = NativeC01TimingStandard.rigidMotion(
          from: Self.clinicModelPose(old, player: sample.pose), to: modelPose(of: obstacle),
          duration: duration, radius: prepared.radius)
      else { return false }
      let rotation: Double
      if obstacle.missionInstanceID == mission.id,
        obstacle.missionActorID.map({ stockActors.contains($0) }) == true,
        obstacle.energy > 0
      {
        guard let control = c01ClinicEscortRuntime.controls.first(where: {
          $0.actor == physical.identity
        }), let travelled = control.angularTravel(actor: physical.identity,
          epoch: nativeStationRuntimeEpoch,
          from: Self.clinicModelPose(old, player: sample.pose), to: modelPose(of: obstacle),
          startTime: sample.physicalTime, duration: duration, includesNativeSpin: includesNativeSpin)
        else { return false }
        rotation = travelled
      } else {
        let steering = obstacle.scriptNPC.map {
          abs($0.fit.definition.pitch) + abs($0.fit.definition.yaw) + abs($0.fit.definition.roll)
        } ?? 0
        let declared = max(physical.angularVelocity.length, oldPhysical.angularVelocity.length)
          + max(abs(obstacle.rotationRate), abs(old.rotationRate)) * 1.4 + steering
        rotation = max(declared, actual.worldAngularVelocity.length) * duration
      }
      guard rotation.isFinite, rotation >= 0, rotation < 1 else { return false }
      obstacles.append(.init(
        identity: physical.identity, hull: prepared, pose: actual.start,
        velocity: actual.initialVelocity, angularVelocity: .init(0, 0, 0),
        clearanceOverride: 5 + vesselMargin + prepared.radius * rotation))
    }
    for (index, celestial) in celestials.enumerated() {
      guard let prepared = preparedWorkHull(
        mesh: workObstacleBox(celestial.radius), key: "c01-clinic-celestial:\(index)")
      else { return false }
      obstacles.append(.init(hull: prepared,
        pose: .init(position: flight.pose.systemPoint(celestial.position)), clearanceOverride: 5 + vesselMargin))
    }
    return HullSweepSafety.validateSceneMotion(motion, player: hull, obstacles: obstacles).safe
  }

  static func clinicModelPose(_ body: SpaceBody, player: ShipPose) -> ShipPose {
    var orientation = Basis3()
    orientation.x = player.orientation.apply(body.modelVector(.init(1, 0, 0)))
    orientation.y = player.orientation.apply(body.modelVector(.init(0, 1, 0)))
    orientation.z = player.orientation.apply(body.modelVector(.init(0, 0, 1)))
    return .init(position: player.systemPoint(body.position), orientation: orientation)
  }
}

/// Physical evidence only. MC1 must still prepare the exact source/pilot disposition.
/// A saved terminal actor cannot construct this transient observation.
final class NativeC01ClinicFatalTransition: Sendable {
  let source: NativeC01ClinicEscortSource
  let birth: NativeC01ClinicStockBirth
  let ordinal: Int
  let launch: NativeC01ClinicLaunch?
  let actor: ScriptOwnedActor
  let startTime: Double
  let physicalTime: Double
  let preNextIncident: UInt64
  let postNextIncident: UInt64
  let epoch: UUID

  fileprivate init(sample: NativeC01ClinicAttainedSample, ordinal: Int,
    launch: NativeC01ClinicLaunch?, actor: ScriptOwnedActor,
    physicalTime: Double, postNextIncident: UInt64)
  {
    source = sample.source
    birth = sample.birth
    self.ordinal = ordinal
    self.launch = launch
    self.actor = actor
    startTime = sample.native.physicalTime
    self.physicalTime = physicalTime
    preNextIncident = sample.nextIncident
    self.postNextIncident = postNextIncident
    epoch = sample.epoch
  }
}

extension Game {
  /// The before sample comes from this running game before a positive native tick.
  /// Culling and an old saved zero-energy actor do not supply a new death incident.
  func c01ClinicFatalTransition(from sample: NativeC01ClinicAttainedSample,
    ordinal: Int) -> NativeC01ClinicFatalTransition?
  {
    let flight = commander.flightSimulation
    let duration = flight.physicalTime - sample.native.physicalTime
    guard (0..<NativeC01ClinicEscort.maximumLaunches).contains(ordinal),
      sample.epoch == nativeStationRuntimeEpoch,
      sample.native.system == systemIdentity, sample.native.visit == flight.visit,
      duration.isFinite, duration > 0, duration <= NativeC01LaneRepair.maximumPhysicalInterval,
      sample.nextIncident > 0, flight.nextIncident > sample.nextIncident,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      state.source == sample.source, state.birth == sample.birth,
      state.loss(for: ordinal) == nil,
      let old = sample.stock[ordinal], old.presence == .present, old.body.energy > 0,
      let before = old.body.physical,
      before.deathIncidentID == nil, before.deathOrigin == nil,
      let retained = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter]?
        .actors[NativeC01ClinicEscort.stockTarget(ordinal)],
      retained.identity == old.identity, retained.body.id == old.body.id,
      retained.presence == .destroyed, retained.body.energy == 0,
      NativeC01ClinicEscort.original(retained, source: state.source, ordinal: ordinal),
      let after = retained.body.physical, after.identity == before.identity,
      after.spawnIdentity == before.spawnIdentity,
      after.identity.visit == flight.visit, after.identity.entity < flight.nextActor,
      NativeC01ClinicEscort.nativeValid(after, cradle: false),
      let incident = after.deathIncidentID,
      incident >= sample.nextIncident, incident < flight.nextIncident
    else { return nil }
    if let origin = after.deathOrigin {
      guard origin.owner.system == after.identity.system,
        origin.owner.visit > 0, origin.owner.visit <= after.identity.visit,
        origin.owner.entity < flight.nextActor,
        origin.emissionID > 0, origin.emissionID < flight.nextEmission,
        origin.emittedAt.isFinite, origin.emittedAt >= 0,
        origin.emittedAt <= flight.physicalTime
      else { return nil }
    }
    let launch = state.launch(for: ordinal)
    if let launch {
      guard sample.launch?.operation == launch.operation,
        launch.loss == nil, launch.physicalTime <= sample.native.physicalTime
      else { return nil }
    } else {
      guard sample.birth.unit(ordinal) != nil else { return nil }
    }
    return .init(sample: sample, ordinal: ordinal, launch: launch, actor: retained,
      physicalTime: flight.physicalTime, postNextIncident: flight.nextIncident)
  }
}


extension Game {
  /// Retain only actual live observations while the existing durable publisher retries.
  /// This is not encoded and never constructs source custody or a casualty receipt.
  mutating func observeC01ClinicFatalTransitions(from sample: NativeC01ClinicAttainedSample?) {
    guard let sample else { return }
    for ordinal in 0..<NativeC01ClinicEscort.maximumLaunches {
      guard !c01ClinicEscortRuntime.pendingDeaths.contains(where: { $0.ordinal == ordinal }),
        c01ClinicEscortRuntime.pendingDeaths.count < NativeC01ClinicEscort.maximumLaunches,
        let transition = c01ClinicFatalTransition(from: sample, ordinal: ordinal)
      else { continue }
      c01ClinicEscortRuntime.pendingDeaths.append(transition)
    }
  }
}
