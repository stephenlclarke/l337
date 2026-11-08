import Foundation

/// A spatial enclosure for this one pulse/brake pair. It carries no admission authority.
struct ManualControlPairEnvelope {
  let position: Vector3
  let radius: Double
  var valid: Bool { position.finite && radius.isFinite && radius >= 0 }

  static func l1(_ value: Vector3) -> Double {
    ((abs(value.x) + abs(value.y)).nextUp + abs(value.z)).nextUp
  }
  static func sum(_ values: Double...) -> Double {
    values.reduce(0) { ($0 + $1).nextUp }
  }
  static func product(_ a: Double, _ b: Double) -> Double { (a * b).nextUp }

  // Covers the scalar roundoff of the two zero-angle camera advances, frame transforms
  // and finite native envelope arithmetic. This is an error bound, not a speed/size cap.
  static func roundoff(_ scale: Double) -> Double {
    product(product(max(1, scale), Double.ulpOfOne), 256)
  }

  static func transformedRadius(_ radius: Double, basis: Basis3) -> Double {
    let axes = [basis.x, basis.y, basis.z]
    var squaredNorm = 0.0
    for i in axes.indices {
      var row = 0.0
      for j in axes.indices {
        let error = roundoff(product(l1(axes[i]), l1(axes[j])))
        row = sum(row, abs(axes[i].dot(axes[j])), error)
      }
      squaredNorm = max(squaredNorm, row)
    }
    // Gershgorin bounds the largest eigenvalue of B^T B. Keep the actual rounded
    // basis, with outward arithmetic, rather than assuming an exact isometry.
    return sum(product(radius, max(1, sqrt(squaredNorm).nextUp)), roundoff(radius))
  }

  static func reexpressionNorm(_ basis: Basis3) -> Double {
    let error = roundoff(sum(l1(basis.x), l1(basis.y), l1(basis.z)))
    return [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].map { axis in
      sum(l1(basis.apply(basis.inverse(axis)) - axis), error)
    }.max() ?? .infinity
  }

  static func nativeExteriorPair(
    normal: Vector3, floor: Double, source: ShipPose,
    start: ShipPose, afterPulse: ShipPose, afterBrake: ShipPose
  ) -> Bool {
    guard normal.finite, floor.isFinite, source.position.finite,
      source.orientation.validRotation else { return false }
    let inverse = source.orientation.transposed
    let direction = inverse.apply(start.orientation.apply(.init(0, 0, 1)))
    guard direction.finite,
      ManualFlightThrottleKernel.outwardComponentsAgree(normal: normal, direction: direction)
    else { return false }
    let initial = inverse.apply(start.position - source.position)
    let initialMargin = normal.dot(initial) - floor
    guard initial.finite, initialMargin.isFinite, initialMargin >= 0 else { return false }
    let transform = max(l1(inverse.x), l1(inverse.y), l1(inverse.z))
    for pose in [afterPulse, afterBrake] {
      // Exactly the preserved ValidateStep arithmetic, in its actual native source frame.
      let local = inverse.apply(pose.position - source.position)
      let margin = normal.dot(local) - floor
      let coordinates = sum(l1(pose.position), l1(source.position))
      let scale = sum(product(l1(normal), product(transform, coordinates)), abs(floor))
      let error = roundoff(scale)
      // Require real numerical room at the new endpoint; never lower the locked floor.
      guard local.finite, margin.isFinite, error.isFinite, margin > error else { return false }
    }
    return true
  }
}

extension Game {
  /// Only the original zero-angle pulse/brake pair. The plane supplies a constraint;
  /// native state supplies every pose, hull and future-birth envelope.
  mutating func admitManualControlPair(
    source identity: NativeStationIdentity, actor: ActorIdentity, bodyID: Int,
    exteriorNormal: Vector3, exteriorFloor: Double, delta: Double
  ) -> Bool {
    let flight = commander.flightSimulation
    let craft = commander.performance
    let native = commander.nativePerformance
    guard delta == 0.1, flight.valid, flight.pose.position.finite,
      [native.speed, native.acceleration, native.pitch, native.roll, native.yaw].allSatisfy({
        $0.isFinite && $0 > 0
      }),
      craft.speed == native.speed, craft.acceleration == native.acceleration,
      craft.pitch == native.pitch, craft.roll == native.roll, craft.yaw == native.yaw,
      let inventory = commander.equipmentInventory,
      commander.equipmentOwnerID == inventory.owner,
      commander.hullInstanceID == inventory.activeHull,
      inventory.owner == identity.world,
      time.isFinite, time >= 0, !isMissionTrial,
      flight.pose.orientation.validRotation, screen == .front, !docked, !paused,
      energy.isFinite, energy > 0, !playerEMPDisabled, !commander.xyzzyActive,
      craft.acceleration.isFinite, craft.acceleration > 0, craft.speed.isFinite, craft.speed > 0,
      speed == 0, autoPilot.velocity == .init(0, 0, 0),
      autoPilot.targetID == nil, !autoPilot.manualEngagement, !dockingComputer,
      !stationAutoDockingActive,
      !spin.mode, spin.actualRate == 0, jumpCountdown == nil,
      workGuidance == nil, workBraking == nil, workRecoveryRock == nil,
      workRecoveryAdmissionDeadline == nil, stationAutoDefence == nil,
      pendingNativeSalvageCollections.isEmpty,
      pendingNativeStationDock == nil, !ecmControl.ownFieldActive, ecmFrames == 0,
      retaliation.pendingResponse(time: time) == nil,
      commander.alienStorageState == nil,
      commander.savedEMPState == nil || commander.savedEMPState == EMPState(),
      commander.savedEMPCharge == nil, !nativeCrimboLifecycleAvailable,
      miningFields.isEmpty, salvageSites.isEmpty,
      commander.miningLedger.breakups.isEmpty, commander.miningLedger.pendingPayloads.isEmpty,
      commander.salvageLedger.pendingLots.isEmpty,
      commander.npcPersistence.unboundSnapshots.isEmpty,
      missionEncounter("constrictor-hunt", location: false) == nil,
      missionEncounter("plans-ambush", location: false) == nil,
      manualControlPairCallbacksAreQuiet(), exteriorNormal.finite, exteriorFloor.isFinite,
      let world = commander.nativeStations, world.valid, world.stationInertia.isEmpty,
      world.ledger.world == inventory.owner,
      let player = flight.player, player.system == identity.system,
      player.visit == actor.visit, actor.system == player.system,
      let binding = NativeStationSource.binding(for: identity), binding.rotationRate == 0,
      let point = world.currentPosition(for: .originalStation(identity), at: flight.physicalTime),
      let orientation = world.currentOrientation(for: identity, at: flight.physicalTime)
    else { return false }
    let firstTime = flight.physicalTime + delta
    let endTime = firstTime + delta
    guard firstTime.isFinite, firstTime > flight.physicalTime,
      endTime.isFinite, endTime > firstTime,
      world.currentPosition(for: .originalStation(identity), at: firstTime) == point,
      world.currentPosition(for: .originalStation(identity), at: endTime) == point,
      world.currentOrientation(for: identity, at: firstTime) == orientation,
      world.currentOrientation(for: identity, at: endTime) == orientation
    else { return false }
    if let director = commander.encounterDirector,
      director.system == player.system, director.visit == player.visit,
      (!director.pendingRequests.isEmpty || !director.nextDecisionTime.isFinite
        || director.nextDecisionTime <= endTime)
    { return false }
    guard let hull = preparedWorkHull(mesh: commander.playerMesh, key: "manual-pair-player")
    else { return false }
    let radius = ManualControlPairEnvelope.transformedRadius(hull.radius, basis: flight.pose.orientation)
    guard radius.isFinite,
      let motions = manualControlPairMotions(delta: delta, playerRadius: radius),
      motions.first.end.position != motions.first.start.position,
      motions.second.end.position == motions.second.start.position,
      ManualControlPairEnvelope.nativeExteriorPair(
        normal: exteriorNormal, floor: exteriorFloor,
        source: .init(position: point, orientation: orientation),
        start: motions.first.start, afterPulse: motions.first.end, afterBrake: motions.second.end),
      let obstacles = manualControlPairScene(
        source: identity, actor: actor, bodyID: bodyID,
        sourcePose: .init(position: point, orientation: orientation), endTime: endTime,
        horizon: max(ManualControlPairEnvelope.sum(delta, delta), (endTime - flight.physicalTime).nextUp),
        playerScale: ManualControlPairEnvelope.sum(
          ManualControlPairEnvelope.l1(motions.first.start.position),
          ManualControlPairEnvelope.l1(motions.first.end.position), radius),
        playerTravel: ManualControlPairEnvelope.sum(
          ManualControlPairEnvelope.l1(motions.first.end.position - motions.first.start.position),
          ManualControlPairEnvelope.roundoff(ManualControlPairEnvelope.sum(
            ManualControlPairEnvelope.l1(motions.first.start.position),
            ManualControlPairEnvelope.l1(motions.first.end.position)))))
    else { return false }
    return HullSweepSafety.validateSceneMotion(motions.first, player: hull, obstacles: obstacles).safe
      && HullSweepSafety.validateSceneMotion(motions.second, player: hull, obstacles: obstacles).safe
  }

  private mutating func manualControlPairScene(
    source identity: NativeStationIdentity, actor: ActorIdentity, bodyID: Int,
    sourcePose: ShipPose, endTime: Double,
    horizon: Double, playerScale: Double, playerTravel: Double
  ) -> [HullSweepObstacle]? {
    typealias Bound = ManualControlPairEnvelope
    let flight = commander.flightSimulation
    guard let world = commander.nativeStations, let player = flight.player,
      bodies.count <= AdmissionBudget().maximum, horizon.isFinite,
      let cargoMesh = manualControlPairHullMesh(.cargo),
      let cargoRadius = manualControlPairMeshExtent(cargoMesh),
      let missileMesh = manualControlPairHullMesh(.missile),
      let missileRadius = manualControlPairMeshExtent(missileMesh),
      let retainedCargo = commander.cargoDebrisLedger.manualControlPairEnvelopes(
        from: flight.physicalTime, through: endTime, horizon: horizon)
    else { return nil }
    var volumes: [Bound] = []
    var obstacles: [HullSweepObstacle] = []
    var bodyIDs: Set<Int> = []
    var actors: Set<ActorIdentity> = []
    var stations: Set<NativeStationIdentity> = []
    var foundSource = false
    var mainStation: StationAnchor?
    var mainRotation = 0.0
    for body in bodies {
      guard bodyIDs.insert(body.id).inserted,
        let physical = manualControlPairPhysical(body, player: player),
        actors.insert(physical.identity).inserted else { return nil }
      if let station = body.nativeStationIdentity {
        guard stations.insert(station).inserted,
          let obstacle = manualControlPairStationObstacle(
            body, physical: physical, station: station, world: world, flight: flight,
            source: identity, actor: actor, bodyID: bodyID,
            sourcePose: sourcePose, playerScale: playerScale, endTime: endTime)
        else { return nil }
        obstacles.append(obstacle)
        foundSource = foundSource || station == identity
        continue
      }
      let observed = flight.pose.systemPoint(body.position)
      let position = physical.ordnance?.position ?? observed
      let observedDeviation = Bound.l1(observed - position)
      let firstRotation = body.rotation + 0.1 * body.rotationRate
      let endRotation = firstRotation + 0.1 * body.rotationRate
      guard position.finite, observed.finite, observedDeviation.isFinite,
        Bound.product(2, Bound.l1(position)).isFinite,
        firstRotation.isFinite, endRotation.isFinite
      else { return nil }
      if body.hull == .station {
        guard body.id == 0, body.energy > 0, physical.npc == nil,
          physical.velocity == .init(0, 0, 0), let anchors = flight.anchors,
          physical.identity == anchors.station.identity else { return nil }
        mainStation = Self.projectedGameplayAnchors(body, flight: flight, canonical: anchors).station
        mainRotation = Bound.sum(abs(firstRotation - body.rotation), abs(endRotation - firstRotation))
        // A native main-station restoration uses the canonical anchor. Include it even
        // when the rendered main body has accumulated a different rounded projection.
      }
      guard let motion = manualControlPairBodyEnvelope(
        body, physical: physical, horizon: horizon,
        scale: Bound.sum(playerScale, Bound.l1(position)), playerTravel: playerTravel),
        let mesh = manualControlPairBodyMesh(body, physical: physical),
        let radius = manualControlPairMeshExtent(mesh) else { return nil }
      // Geometry is available only after source admission. Retain the original
      // shape-sized roundoff as an additional enclosure, never a smaller bound.
      let travel = Bound.sum(motion.travel,
        Bound.roundoff(Bound.sum(playerScale, Bound.l1(position), radius)))
      if body.hull == .station, let anchors = flight.anchors {
        volumes.append(.init(position: anchors.station.position, radius: Bound.product(2, radius)))
      }
      if body.energy > 0 {
        var extent = Bound.sum(travel, observedDeviation)
        if body.missiles > 0, physical.npc != nil {
          extent = Bound.sum(extent, 2 * NativeMissileMuzzleDescription.distance, 2 * missileRadius,
            Bound.product(2, Bound.product(OrdnanceProfile.standardMissile.speed, horizon)))
        }
        volumes.append(.init(position: position, radius: Bound.sum(2 * radius, extent)))
      }
      if let npc = physical.npc, !npc.ordinaryCargo.isEmpty {
        // Future native steering may rotate the death pose. Enclose every native slot
        // under any supported rotation, plus inherited motion and ejection, through H.
        let extent = Bound.sum(
          Bound.product(2, CargoDebrisBirthDescription.maximumOffsetL1), travel,
          Bound.product(5, Bound.product(
            Bound.sum(motion.speed, 4 * CargoDebrisBirthDescription.ejectionSpeed), horizon)),
          2 * cargoRadius)
        volumes.append(.init(position: position, radius: extent))
      }
    }
    guard foundSource, let mainStation,
      Set(world.ledger.records.filter {
        $0.identity.system == player.system && $0.tombstone == nil
      }.map(\.identity)) == stations,
      let launches = commander.stationSecurity.manualControlPairLaunchEnvelopes(
        station: mainStation, rotation: mainRotation),
      let craft = ShipCatalogue.nativeShip(StationSecurityLaunchDescription.hull)?.game,
      craft.acceleration.isFinite, craft.acceleration * 18 >= 1,
      let policeMesh = manualControlPairHullMesh(StationSecurityLaunchDescription.hull),
      let policeRadius = manualControlPairMeshExtent(policeMesh)
    else { return nil }
    guard let future = manualControlPairFutureObstacles(
      volumes: volumes, retainedCargo: retainedCargo, launches: launches, craft: craft,
      cargoRadius: cargoRadius, missileRadius: missileRadius, policeRadius: policeRadius,
      horizon: horizon, playerScale: playerScale, flight: flight)
    else { return nil }
    return obstacles + future
  }

  private func manualControlPairPhysical(_ body: SpaceBody, player: ActorIdentity) -> PhysicalActorState? {
    guard body.position.finite,
      body.orientation.validRotation, body.rotation.isFinite, body.rotationRate.isFinite,
      body.energy.isFinite,
      body.scriptNPC == nil, body.scriptShot == nil, body.missionActorID == nil,
      body.missionInstanceID == nil, body.blackjackRole == nil, !body.navalTarget,
      body.destroyedByPlayer != true,
      let physical = body.physical, physical.identity.system == player.system,
      physical.identity.visit == player.visit,
      physical.velocity.finite, physical.velocity.length.isFinite,
      physical.angularVelocity == .init(0, 0, 0), physical.rock == nil,
      physical.empSource == nil, physical.empCrewPod == nil, physical.salvage == nil
    else { return nil }
    if let payload = physical.payload {
      guard case .wreck = payload else { return nil }
    }
    guard physical.npc == nil || physical.ordnance == nil else { return nil }
    guard physical.suspendedNPCIntention == nil else { return nil }
    guard physical.payload == nil || physical.ordnance == nil else { return nil }
    if body.hull == .station, physical.npc != nil || physical.ordnance != nil { return nil }
    if physical.ordnance == nil, body.enemyMissile || body.playerMissileTarget != nil { return nil }
    if physical.ordnance?.origin.owner == player { return nil }
    return physical
  }

  private mutating func manualControlPairFutureObstacles(
    volumes initial: [ManualControlPairEnvelope], retainedCargo: [ManualControlPairEnvelope],
    launches: [(volume: ManualControlPairEnvelope, speed: Double)], craft: ShipPerformance,
    cargoRadius: Double, missileRadius: Double, policeRadius: Double,
    horizon: Double, playerScale: Double, flight: FlightSimulationState
  ) -> [HullSweepObstacle]? {
    typealias Bound = ManualControlPairEnvelope
    var volumes = initial
    var obstacles: [HullSweepObstacle] = []
    let reexpression = Bound.reexpressionNorm(flight.pose.orientation)
    guard reexpression.isFinite else { return nil }
    for cargo in retainedCargo {
      volumes.append(.init(position: cargo.position, radius: Bound.sum(cargo.radius, 2 * cargoRadius)))
    }
    for launch in launches {
      let speed = Bound.sum(launch.speed, Bound.product(4, Bound.product(craft.acceleration * 18, horizon)))
      let extent = Bound.sum(launch.volume.radius, 2 * policeRadius,
        Bound.product(4, Bound.product(speed, horizon)), 2 * NativeMissileMuzzleDescription.distance,
        2 * missileRadius, Bound.product(2, Bound.product(OrdnanceProfile.standardMissile.speed, horizon)))
      volumes.append(.init(position: launch.volume.position, radius: extent))
    }
    for celestial in celestials {
      guard celestial.radius.isFinite, celestial.radius > 0 else { return nil }
      volumes.append(.init(position: flight.pose.systemPoint(celestial.position), radius: celestial.radius))
    }
    for (index, volume) in volumes.enumerated() {
      // A native spawn uses Q^T, not an exact inverse. At most two births/rebindings
      // occur in the two ticks; 2*mu*(1+mu) encloses their composed affine error.
      let relative = Bound.sum(Bound.l1(volume.position - flight.pose.position), volume.radius, playerScale)
      let projected = Bound.product(2, Bound.product(reexpression,
        Bound.product(Bound.sum(1, reexpression), relative)))
      let extent = Bound.sum(volume.radius, projected,
        Bound.roundoff(Bound.sum(playerScale, Bound.l1(volume.position), volume.radius)))
      guard volume.valid, extent.isFinite, extent > 0,
        Bound.sum(Bound.l1(volume.position), extent).isFinite,
        let hull = preparedWorkHull(mesh: workObstacleBox(extent), key: "manual-pair-envelope:\(index)")
      else { return nil }
      obstacles.append(.init(hull: hull, pose: .init(position: volume.position), clearanceOverride: 0))
    }
    return obstacles
  }

  private mutating func manualControlPairStationObstacle(
    _ body: SpaceBody, physical: PhysicalActorState, station: NativeStationIdentity,
    world: NativeStationWorld, flight: FlightSimulationState, source identity: NativeStationIdentity,
    actor: ActorIdentity, bodyID: Int,
    sourcePose: ShipPose, playerScale: Double, endTime: Double
  ) -> HullSweepObstacle? {
    typealias Bound = ManualControlPairEnvelope
    guard nativeStationBodyIsCurrent(body),
      world.bodyRigidPoseIsConsistent(body, flight: flight),
      let source = NativeStationSource.binding(for: station),
      (endTime * source.rotationRate).isFinite,
      let point = world.currentPosition(for: .originalStation(station), at: flight.physicalTime)
    else { return nil }
    if station == identity {
      guard body.id == bodyID, physical.identity == actor, physical.npc == nil,
        body.energy > 0, physical.velocity == .init(0, 0, 0),
        physical.angularVelocity == .init(0, 0, 0), physical.canonicalSpin != true,
        body.rotationRate == 0, body.rotation == 0,
        let hull = preparedWorkHull(mesh: source.geometry.mesh, key: "manual-pair-source")
      else { return nil }
      let actual = modelPose(of: body)
      let axes = max(
        Bound.l1(actual.orientation.x - sourcePose.orientation.x),
        Bound.l1(actual.orientation.y - sourcePose.orientation.y),
        Bound.l1(actual.orientation.z - sourcePose.orientation.z))
      // Native pose consistency has a tolerance. Enclose the measured rendered/native
      // displacement and basis difference rather than treating transpose as exact inverse.
      let deviation = Bound.sum(Bound.l1(actual.position - point), Bound.product(2 * hull.radius, axes))
      let clearance = Bound.sum(deviation,
        Bound.roundoff(Bound.sum(playerScale, Bound.l1(point), hull.radius)))
      guard clearance.isFinite else { return nil }
      return .init(identity: physical.identity, hull: hull, pose: sourcePose,
        clearanceOverride: clearance)
    }
    guard body.energy > 0, let radius = manualControlPairMeshExtent(source.geometry.mesh) else { return nil }
    let actual = modelPose(of: body).position
    let horizon = max(Bound.sum(0.1, 0.1), (endTime - flight.physicalTime).nextUp)
    let drift = Bound.product(4, Bound.product(Bound.l1(physical.velocity), horizon))
    let extent = Bound.sum(2 * radius, Bound.l1(actual - point), drift,
      Bound.roundoff(Bound.sum(playerScale, Bound.l1(point), radius)))
    guard extent.isFinite,
      let hull = preparedWorkHull(mesh: workObstacleBox(extent), key: "manual-pair-station:\(body.id)")
    else { return nil }
    return .init(identity: physical.identity, hull: hull, pose: .init(position: point), clearanceOverride: 0)
  }

  private func manualControlPairBodyEnvelope(
    _ body: SpaceBody, physical: PhysicalActorState,
    horizon: Double, scale: Double, playerTravel: Double
  ) -> (speed: Double, travel: Double)? {
    typealias Bound = ManualControlPairEnvelope
    var velocity = Bound.l1(physical.velocity)
    var legacySpeed = 0.0
    if let npc = physical.npc {
      guard [.trader, .police].contains(npc.role),
        ![Hull.thargoid, .thargon, .constrictor].contains(body.hull),
        let craft = ShipCatalogue.nativeShip(body.hull)?.game,
        craft.acceleration.isFinite, craft.acceleration * 18 >= 1,
        craft.speed.isFinite, (craft.speed * 18).isFinite,
        npc.resources?.valid == true else { return nil }
      if let intention = npc.intention {
        switch intention {
        case .scoop, .mine: return nil
        case .navigate(let position, let speed):
          guard position.finite, Bound.product(2, Bound.l1(position)).isFinite,
            speed.isFinite, speed >= 0 else { return nil }
        default: break
        }
      }
      if physical.spawnIdentity == nil {
        guard let speed = body.nativeNavalCombat?.speed, speed.isFinite, speed >= 0 else { return nil }
        legacySpeed = Bound.product(speed, 18)
        velocity = max(velocity, Bound.sum(2 * legacySpeed, Bound.roundoff(scale) / 0.1))
      }
      // One traffic plus one security intent per tick; each impulse has L1 <= 2*a*dt.
      velocity = Bound.sum(velocity, Bound.product(4, Bound.product(craft.acceleration * 18, horizon)))
    } else if let ordnance = physical.ordnance {
      velocity = Bound.sum(Bound.l1(ordnance.inheritedVelocity), 2 * ordnance.profile.speed)
    } else if body.hull != .cargo && body.hull != .station {
      return nil
    }
    var travel = Bound.sum(Bound.product(4, Bound.product(velocity, horizon)),
      Bound.product(2, Bound.product(legacySpeed, horizon)), Bound.roundoff(scale))
    if physical.npc != nil, physical.spawnIdentity == nil {
      let viewReach = Bound.sum(Bound.product(2, Bound.product(legacySpeed, horizon)),
        Bound.product(2, playerTravel), Bound.roundoff(scale))
      if manualControlPairRemainsInBubble(body, reach: viewReach) {
        // The legacy actor has no physical-velocity translation while its binding remains.
        // Keep its native speed envelope; the inferred velocity still bounds future cargo.
        travel = Bound.sum(Bound.product(2, Bound.product(legacySpeed, horizon)), Bound.roundoff(scale))
      }
    }
    return velocity.isFinite && travel.isFinite ? (velocity, travel) : nil
  }

  private func manualControlPairRemainsInBubble(_ body: SpaceBody, reach: Double) -> Bool {
    guard reach.isFinite, reach >= 0 else { return false }
    // The native sphere/box bubble is convex. Its eight enclosing corners discharge
    // the existing cull predicate without copying its distances or running any AI.
    for x in [-1.0, 1.0] {
      for y in [-1.0, 1.0] {
        for z in [-1.0, 1.0] {
          var corner = body
          corner.position = body.position + Vector3(x, y, z) * reach
          guard corner.position.finite, !corner.leavesLocalBubble else { return false }
        }
      }
    }
    return true
  }

  private mutating func manualControlPairMeshExtent(_ mesh: Mesh) -> Double? {
    let key = "manual-pair-extent:\(mesh.vertices.count):\(mesh.faces.count)"
    guard let hull = preparedWorkHull(mesh: mesh, key: key), hull.radius.isFinite, hull.radius > 0
    else { return nil }
    return hull.radius
  }

  private func manualControlPairHullMesh(_ hull: Hull) -> Mesh? {
    switch hull {
    case .station: return MainStationGeometry.mesh
    case .cargo, .missile: return Mesh.hull(hull)  // Existing native built-ins have no trap branch.
    default:
      guard ShipCatalogue.nativeShip(hull) != nil else { return nil }
      return ShipCatalogue.nativeMesh(hull)
    }
  }

  private func manualControlPairBodyMesh(_ body: SpaceBody, physical: PhysicalActorState) -> Mesh? {
    guard !hasNativePracticeReservation(body) else { return nil }
    if let id = physical.catalogueShipID, ShipCatalogue.ship(id) == nil { return nil }
    if physical.ordnance?.profile == .alienSeeker { return AlienMissileMesh.mesh }
    if body.hull == .station { return MainStationGeometry.mesh }
    if let id = physical.catalogueShipID { return ShipCatalogue.rawMesh(id) }
    return manualControlPairHullMesh(body.hull)
  }

  private func manualControlPairCallbacksAreQuiet() -> Bool {
    let state = commander.scriptState
    guard state.pendingEvents.isEmpty, state.worldJobs.isEmpty, state.projectiles.isEmpty,
      state.wormholeTransit == nil, state.savedC01Inquiry == nil,
      state.savedMeasuredExtractionSource == nil, state.savedRecordRecoverySource == nil,
      state.savedIdentifiedSalvageSource == nil else { return false }
    if let frame = scriptReferenceFrame, !frame.valid { return false }
    for instance in state.instances.values {
      guard let pack = scriptPack(for: instance), WayfarerFieldRelief.matches(pack),
        instance.timers.isEmpty, instance.ownedEncounters.isEmpty else { return false }
      do { try WayfarerFieldReliefSave.validateDeclaration(pack.manifest) }
      catch { return false }
    }
    for entry in missionPacks.entries
    where packMatchesSave(entry) && entry.pack.mission.binding != "naval" {
      let state = progress(for: entry)
      guard !entry.pack.transitions.contains(where: { $0.from == state.stage && $0.event == .clock })
      else { return false }
    }
    return true
  }

  /// Project only the exact original zero-angle manual pulse and its matching brake.
  /// This value calculation neither advances the clock nor creates contact authority.
  private func manualControlPairMotions(
    delta: Double, playerRadius: Double
  ) -> (first: HullSceneMotion, second: HullSceneMotion)? {
    let craft = commander.performance
    var pose = commander.flightSimulation.pose
    var cruise = speed
    var residual = autoPilot.velocity
    var usesResidual = manualResidualFlight
    var motions: [HullSceneMotion] = []
    for throttle in [1.0, -1.0] {
      if usesResidual {
        let velocity = residual + Vector3(0, 0, cruise * 18)
        let magnitude = velocity.length
        let acceleration = craft.acceleration * 18
        let maximum = craft.speed * 18
        guard let next = ManualFlightThrottleKernel.residual(
          velocity: velocity, magnitude: magnitude, acceleration: acceleration, maximum: maximum,
          throttle: throttle, delta: delta)
        else { return nil }
        cruise = 0
        residual = next
        if next == .init(0, 0, 0) { usesResidual = false }
      } else {
        cruise = ManualFlightThrottleKernel.cruise(
          speed: cruise, throttle: throttle, delta: delta,
          acceleration: craft.acceleration, maximum: craft.speed)
      }
      let velocity = pose.orientation.apply(residual + Vector3(0, 0, cruise * 18))
      residual = residual.rotated(pitch: 0, roll: 0, yaw: 0)
      var end = pose
      end.advanceView(
        pitch: 0, roll: 0, yaw: 0,
        translation: residual * delta + Vector3(0, 0, cruise * delta * 18))
      guard velocity.finite, end.position.finite, end.orientation.validRotation else { return nil }
      motions.append(.init(
        start: pose, end: end, initialVelocity: velocity, acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: delta, playerRadius: playerRadius))
      pose = end
    }
    guard motions.count == 2, residual + Vector3(0, 0, cruise * 18) == .init(0, 0, 0)
    else { return nil }
    return (motions[0], motions[1])
  }

  mutating func preparedWorkHull(mesh: Mesh, key: String) -> PreparedHull? {
    let cacheKey = "work:" + key
    if let cached = salvageAdmissionGeometry[cacheKey],
      cached.mesh.vertices == mesh.vertices, cached.mesh.faces == mesh.faces
    {
      return cached.hull
    }
    guard let hull = try? PreparedHull(mesh: mesh) else { return nil }
    if salvageAdmissionGeometry.count >= 128 {
      salvageAdmissionGeometry.removeAll(keepingCapacity: true)
    }
    salvageAdmissionGeometry[cacheKey] = .init(mesh: mesh, hull: hull)
    return hull
  }

  /// Legacy AI runs before the proof. Its whole ensuing linear displacement is an obstacle,
  /// and it is not run again after the approved player motion.
  mutating func planWorkScene(delta: Double) {
    guard !playerEMPDisabled, workGuidance != nil || workBraking != nil else { return }
    workScenePlanned = true
    if missionLoopCounter & 7 == 0 { navalTactics() }
    let actors = bodies.filter {
      $0.hostile && $0.energy > 0 && $0.physical?.spawnIdentity == nil
    }.map(\.id)
    for id in actors {
      guard let index = bodies.firstIndex(where: { $0.id == id }) else { continue }
      let before = bodies[index]
      let start = modelPose(of: before)
      let radius = gameplayMesh(for: before).vertices.map(\.length).max() ?? 0
      enemyAction(index: index, dt: delta)
      guard let after = bodies.first(where: { $0.id == id }),
        let hull = preparedWorkHull(mesh: workObstacleBox(radius), key: "legacy:\(id)")
      else { continue }
      let velocity = (modelPose(of: after).position - start.position) * (1 / delta)
      plannedLegacyWorkMotion[id] = .init(
        identity: before.physical?.identity, hull: hull,
        pose: .init(position: start.position), velocity: velocity, clearanceOverride: 0)
    }
  }

  /// Include every current actor. Other loose pods remain obstacles after one is collected.
  mutating func workObstacles(
    excluding primary: ActorIdentity?, delta: Double,
    bornAtEnd: Set<ActorIdentity> = []
  )
    -> [HullSweepObstacle]?
  {
    var result: [HullSweepObstacle] = []
    for body in bodies
    where body.energy > 0 && (primary == nil || body.physical?.identity != primary) {
      guard let physical = body.physical else { return nil }
      if bornAtEnd.contains(physical.identity) { continue }
      if physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil {
        guard let parts = currentNewtRigidWorkObstacles(for: body) else { return nil }
        result.append(contentsOf: parts)
        continue
      }
      if let planned = plannedLegacyWorkMotion[body.id] {
        result.append(planned)
        continue
      }
      let mesh = gameplayMesh(for: body)
      if physical.canonicalSpin == true {
        guard let hull = preparedWorkHull(mesh: mesh, key: "actor:\(body.id)") else { return nil }
        result.append(
          .init(
            identity: physical.identity, hull: hull, pose: modelPose(of: body),
            velocity: physical.spawnIdentity == nil ? .init(0, 0, 0) : physical.velocity,
            angularVelocity: physical.angularVelocity, clearanceOverride: 0))
      } else {
        // The enclosing box covers the complete legacy model spin. Turning projectiles get
        // a full one-step travel envelope rather than an assumed straight trajectory.
        var radius = mesh.vertices.map(\.length).max() ?? 0
        if let projectile = physical.ordnance { radius += projectile.velocity.length * delta }
        guard let hull = preparedWorkHull(mesh: workObstacleBox(radius), key: "envelope:\(body.id)")
        else { return nil }
        let velocity =
          physical.spawnIdentity != nil && physical.ordnance == nil
          ? physical.velocity : Vector3(0, 0, 0)
        result.append(
          .init(
            identity: physical.identity, hull: hull,
            pose: .init(position: modelPose(of: body).position), velocity: velocity,
            clearanceOverride: 0))
      }
    }
    let pose = commander.flightSimulation.pose
    for (index, celestial) in celestials.enumerated() {
      guard
        let hull = preparedWorkHull(
          mesh: workObstacleBox(celestial.radius), key: "celestial:\(index)")
      else { return nil }
      result.append(
        .init(
          hull: hull, pose: .init(position: pose.systemPoint(celestial.position)),
          clearanceOverride: 0))
    }
    return result
  }

  /// Consume one accepted endpoint. No Euler integration of its end velocity follows it.
  @discardableResult
  mutating func moveWorkFrame(delta: Double, bornAtEnd: Set<ActorIdentity> = []) -> Bool {
    guard workGuidance != nil || workBraking != nil else { return false }
    let start = commander.flightSimulation.pose
    let motion = approvedWorkMotion
    let accepted = motion.map { $0.start == start && $0.duration == delta } ?? false
    let initialVelocity = flightWorldVelocity
    let end: ShipPose
    let velocity: Vector3
    let omega: Vector3
    if accepted, let motion {
      end = motion.end
      velocity = motion.initialVelocity + motion.acceleration * delta
      omega = motion.worldAngularVelocity
      lastAppliedWorkMotion = motion
    } else {
      // A failed clearance proof cannot authorize thrust or a new rotation. Physical inertia
      // continues; this is an unpowered coast, not a claim of collision-free motion.
      end = .init(
        position: start.position + initialVelocity * delta, orientation: start.orientation)
      velocity = initialVelocity
      omega = .init(0, 0, 0)
      lastAppliedWorkMotion = nil
    }
    approvedWorkMotion = nil
    commander.flightSimulation.pose = end
    rotateScriptNPCVelocities(from: start, to: end)
    let change = start.orientation.workFrameRelative(to: end.orientation)
    for index in bodies.indices {
      bodies[index].position = end.shipPoint(start.systemPoint(bodies[index].position))
      bodies[index].orientation = change.composed(with: bodies[index].orientation)
      if let actor = bodies[index].physical?.identity, bornAtEnd.contains(actor) { continue }
      advanceBodyModelRotation(at: index, delta: delta)
      advanceCanonicalModelSpin(at: index, delta: delta)
      if let physical = bodies[index].physical, physical.spawnIdentity != nil,
        physical.ordnance == nil, bodies[index].scriptShot == nil,
        bodies[index].scriptNPC == nil || c01SurveyorActor(bodies[index]) != nil
          || c01TimingStandardPart(bodies[index]) != nil
          || c01LaneRepairTarget(bodies[index]) != nil
          || c01ClinicCradleDeclared(bodies[index])
      {
        bodies[index].position = bodies[index].position + end.shipVector(physical.velocity) * delta
      }
    }
    for index in celestials.indices {
      celestials[index].position = end.shipPoint(start.systemPoint(celestials[index].position))
    }
    workGuidance?.velocity = velocity
    workGuidance?.angularVelocity = omega
    workBraking?.velocity = velocity
    workBraking?.angularVelocity = omega
    autoPilot.setApproachVelocity(.init(0, 0, 0))
    speed = 0
    if workGuidance == nil, velocity.length < 1e-9 {
      workBraking = nil
    }
    return true
  }

  func workObstacleBox(_ radius: Double) -> Mesh {
    let r = radius
    return .init(
      vertices: [
        .init(-r, -r, -r), .init(r, -r, -r), .init(r, r, -r), .init(-r, r, -r),
        .init(-r, -r, r), .init(r, -r, r), .init(r, r, r), .init(-r, r, r),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
      ])
  }

  /// A real T1 admission has no preceding trajectory. Its complete authenticated
  /// collision geometry still has to clear the proposed retained endpoint.
  mutating func workBirthEndpointIsClear(
    _ motion: HullSceneMotion,
    bornAtEnd: CurrentNewtEndBirths?
  ) -> Bool {
    guard let bornAtEnd, !bornAtEnd.actors.isEmpty else { return true }
    guard bornAtEnd.matchesNewtBirths(self) else {
      nativeEncounterBirthDiagnostic?.recordEndpointRefusal("stage=birth-identity-or-clock")
      return false
    }
    guard let player = preparedWorkHull(mesh: commander.playerMesh, key: "player") else {
      nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
        "stage=player-preparation ship=\(commander.shipID) endpoint=\(motion.end)"
        + " vertices=\(commander.playerMesh.vertices.count) faces=\(commander.playerMesh.faces.count)")
      return false
    }
    var remaining = HullSweepBudget.standard
    for actor in bornAtEnd.actors {
      guard let body = bodies.first(where: { $0.physical?.identity == actor }) else {
        nativeEncounterBirthDiagnostic?.recordEndpointRefusal("stage=missing-birth actor=\(actor)")
        return false
      }
      let parts: [CurrentNewtKitComponent]
      do {
        guard let actual = try currentNewtGeometryComponents(for: body) else {
          nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
            "stage=component-source-nil actor=\(actor)")
          return false
        }
        parts = actual
      } catch {
        nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
          "stage=component-source actor=\(actor) error=\(error)"
          + " actualPlayerPose=\(storedFlightSimulation().pose) proposedEndpoint=\(motion.end)"
          + " predicateEvidence=[\(nativeEncounterBirthDiagnostic?.componentSourceRefusal(actor: actor) ?? "not-observed")]"
          + " producerEvidence=[\(nativeEncounterBirthDiagnostic?.detail() ?? "not-observed")]")
        return false
      }
      for part in parts {
        guard let mesh = part.collisionMesh else { continue }
        let hull: PreparedHull
        do { hull = try PreparedHull(mesh: mesh, maximumTriangles: 512) } catch {
          nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
            "stage=component-preparation actor=\(actor) component=\(part.id) error=\(error)"
            + " vertices=\(mesh.vertices.count) faces=\(mesh.faces.count)"
            + " sourcePose=\(motion.end) targetPose=\(part.pose)")
          return false
        }
        let result = HullSweepSafety.currentNewtEndpointPairClearance(
          source: player,
          sourcePose: motion.end, target: hull, targetPose: part.pose, budget: remaining)
        guard result.safe else {
          nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
            "stage=endpoint-query actor=\(actor) component=\(part.id)"
            + " sourcePose=\(motion.end) targetPose=\(part.pose)"
            + " sourceRadius=\(player.radius) sourceTriangles=\(player.triangleCount)"
            + " targetRadius=\(hull.radius) targetTriangles=\(hull.triangleCount)"
            + " targetVelocity=\(part.velocity) targetSpin=\(part.angularVelocity)"
            + " budget=\(remaining) result=\(result)")
          return false
        }
        remaining.distanceQueries -= result.distanceQueries
        remaining.triangleTests -= result.triangleTests
        remaining.nodeVisits -= result.nodeVisits
      }
    }
    return true
  }
}

extension Basis3 {
  /// Re-express an orientation in an admitted work frame without normalizing either basis.
  /// A represented rotation is only approximately orthogonal: its transpose is not its inverse.
  func workFrameRelative(to frame: Basis3) -> Basis3 {
    let first = frame.y.cross(frame.z)
    let second = frame.z.cross(frame.x)
    let third = frame.x.cross(frame.y)
    let inverseDeterminant = 1 / frame.x.dot(first)
    func coordinates(_ vector: Vector3) -> Vector3 {
      .init(
        vector.dot(first) * inverseDeterminant, vector.dot(second) * inverseDeterminant,
        vector.dot(third) * inverseDeterminant)
    }
    var result = Basis3()
    result.x = coordinates(x)
    result.y = coordinates(y)
    result.z = coordinates(z)
    return result
  }
}
