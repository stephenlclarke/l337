import Foundation

struct CurrentNewtNativeCollider: Sendable {
  let actor: ActorIdentity?
  let component: String
  let newt: Bool
  let debris: Bool
  let asteroid: Bool
  let station: Bool
  let hull: PreparedHull
  let mesh: Mesh
  let centre: Vector3
  let radius: Double
  let maximumPointSpeed: Double
  let clockSamplingTimeError: Double
  let referenceVelocity: Vector3
  let pointSpeedRelativeTo: @Sendable (Vector3) -> Double?
  let poseAt: @Sendable (Double) -> ShipPose?
  var victimPart: String? = nil
  var componentUUID: UUID? = nil

  /// Producer metadata stays exact for local elapsed callbacks. A caller that
  /// actually adds/subtracts a physical clock must also enclose that adapter.
  func samplingPositionError(adapterTimeError: Double) -> Double? {
    guard adapterTimeError.isFinite, adapterTimeError >= 0,
      clockSamplingTimeError.isFinite, clockSamplingTimeError >= 0,
      maximumPointSpeed.isFinite, maximumPointSpeed >= 0 else { return nil }
    let seconds = clockSamplingTimeError == 0 && adapterTimeError == 0
      ? 0 : (clockSamplingTimeError + adapterTimeError).nextUp
    let error = seconds == 0 || maximumPointSpeed == 0 ? 0 : (maximumPointSpeed * seconds).nextUp
    return error.isFinite ? error : nil
  }

  /// Canonical physical sampling, including a suffix after an earlier impact.
  /// This is a pose observation; a positive sample rounded to T0 earns no time.
  func pose(at elapsed: Double, in window: NativeCurveClockWindow, rootClock: Double) -> ShipPose? {
    let physical = window.start + elapsed
    let rootElapsed = physical - rootClock
    guard rootClock.isFinite, rootClock >= 0, rootClock <= window.start,
      elapsed.isFinite, elapsed >= 0, elapsed <= window.duration,
      physical.isFinite, physical >= window.start, physical <= window.end,
      rootElapsed >= 0, rootClock + rootElapsed == physical else { return nil }
    return poseAt(rootElapsed)
  }
}

/// Source-qualified real geometry/curves. Only the native scene owner in this
/// file constructs a scene after joining the actual opening and mechanical plan.
final class CurrentNewtNativeQueryScene: Sendable {
  let motion: CurrentNewtNativeSegmentPlan
  let colliders: [CurrentNewtNativeCollider]
  let solidColliders: [CurrentNewtNativeCollider]
  let drives: [CurrentNewtNativeDriveCurve]
  let coasts: [CurrentNewtNativeCoastCurve]
  let ordnanceFrame: GameplayOrdnanceFrame?
  fileprivate let outcomes: [CurrentNewtDriveOutcome]

  fileprivate init(
    motion: CurrentNewtNativeSegmentPlan, colliders: [CurrentNewtNativeCollider],
    solidColliders: [CurrentNewtNativeCollider], drives: [CurrentNewtNativeDriveCurve],
    coasts: [CurrentNewtNativeCoastCurve],
    outcomes: [CurrentNewtDriveOutcome], ordnanceFrame: GameplayOrdnanceFrame?
  ) {
    self.ordnanceFrame = ordnanceFrame
    self.motion = motion
    self.colliders = colliders
    self.solidColliders = solidColliders
    self.drives = drives
    self.coasts = coasts
    self.outcomes = outcomes
  }
}

private struct CurrentNewtImpactState: Sendable {
  let state: CurrentNewtKitReceipt.BodyState
  let mass: CurrentNewtImpactMass
  let components: [CurrentNewtKitComponent]
  let maximumAngularSpeed: Double
}

private struct CurrentNewtSelectedImpact {
  let source: CurrentNewtNativeCollider
  let target: CurrentNewtNativeCollider
  let contact: NativeHullContact
  let lowerPhysicalTime: Double
  let upperPhysicalTime: Double
}

extension Game {
  /// Pure T0 source/contact preparation. The returned mover and outcomes are the
  /// same immutable candidates G1 consumes after its one pure clock leg.
  func prepareCurrentNewtNativeContact(
    opening: CurrentNewtNativeSegmentOpening, mechanics: CurrentNewtMechanicalPlan
  ) -> CurrentNewtPreparedNativeContact? {
    guard let scene = prepareCurrentNewtNativeQueryScene(opening: opening, mechanics: mechanics)
    else { return nil }
    return prepareCurrentNewtNativeContact(in: scene)
  }

  func prepareCurrentNewtNativeContact(in scene: CurrentNewtNativeQueryScene)
    -> CurrentNewtPreparedNativeContact?
  {
    var report = CurrentNewtOrdnanceQueryWork(
      candidatePairs: 0, distanceQueries: 0,
      triangleTests: 0, nodeVisits: 0)
    return prepareCurrentNewtNativeContact(
      in: scene, budget: .standard,
      maximumPairs: AsteroidImpactPolicy.maximumCandidatePairs, report: &report)
  }

  func prepareCurrentNewtNativeContact(
    in scene: CurrentNewtNativeQueryScene,
    budget: HullSweepBudget, maximumPairs: Int, report: inout CurrentNewtOrdnanceQueryWork
  )
    -> CurrentNewtPreparedNativeContact?
  {
    let motion = scene.motion
    guard currentNewtNativeCommanderMatches(motion.opening.before), bodies == motion.opening.before.bodies,
      nativeStationRuntimeEpoch == motion.opening.before.nativeStationRuntimeEpoch,
      let resolution = currentNewtResolveImpacts(
        motion: motion, colliders: scene.solidColliders,
        drives: scene.drives, coasts: scene.coasts, initialOutcomes: scene.outcomes,
        budget: budget, maximumPairs: maximumPairs, workReport: &report),
      validateCurrentNewtMechanicalResult(
        motion.mechanicalResult(resolution), for: motion.mechanics)
    else { return nil }
    return .init(motion: motion, resolution: resolution)
  }

  func prepareCurrentNewtNativeQueryScene(
    opening: CurrentNewtNativeSegmentOpening, mechanics: CurrentNewtMechanicalPlan,
    ordnanceFrame: GameplayOrdnanceFrame? = nil,
    report: ((CurrentNewtPreparationRefusal) -> Void)? = nil
  ) -> CurrentNewtNativeQueryScene? {
    let interval = opening.interval
    guard interval.valid, storedFlightSimulation().physicalTime == interval.start,
      mechanics.interval.start == interval.start, mechanics.interval.end == interval.end,
      currentNewtNativeCommanderMatches(opening.before), bodies == opening.before.bodies,
      nativeStationRuntimeEpoch == opening.before.nativeStationRuntimeEpoch
    else {
      report?(.init(phase: .queryScene, checkpoint: 1, bodyID: nil, component: nil))
      return nil
    }
    var overrides = mechanics.proposals
    var drives: [CurrentNewtNativeDriveCurve] = []
    var outcomes: [CurrentNewtDriveOutcome] = []
    for plan in mechanics.drives {
      guard let owner = mechanics.owners.first(where: { $0.parent == plan.parentActor }),
        let curve = CurrentNewtNativeDriveCurve.make(plan: plan, stock: owner.stock),
        let end = curve.sample(at: interval.end), let outcome = curve.outcome(at: interval.end),
        let source = CurrentNewtKitSource.current,
        let mass = source.loadedParentMass(work: end.work, load: plan.load)
      else {
        report?(.init(phase: .queryScene, checkpoint: 2, bodyID: nil, component: nil))
        return nil
      }
      drives.append(curve)
      outcomes.append(outcome)
      overrides.append(
        .init(
          actor: plan.parentActor, before: plan.parent, after: end.parent,
          beforeMass: plan.parentMass, afterMass: mass))
      overrides.append(
        .init(
          actor: plan.podActor, before: plan.pod, after: end.pod,
          beforeMass: plan.podMass, afterMass: plan.podMass))
    }
    guard
      let coasts = currentNewtNativeCoasts(
        mechanics: mechanics,
        excluding: Set(overrides.map(\.actor)))
    else {
      report?(.init(phase: .queryScene, checkpoint: 3, bodyID: nil, component: nil))
      return nil
    }
    let coastFlows = Dictionary(uniqueKeysWithValues: coasts.map { ($0.actor, $0) })
    guard Set(overrides.map(\.actor)).count == overrides.count,
      let motion = prepareCurrentNewtNativeSegment(
        opening, mechanics: mechanics,
        mechanical: overrides, coasts: coastFlows)
    else {
      report?(.init(phase: .queryScene, checkpoint: 4, bodyID: nil, component: nil))
      return nil
    }
    return assembleCurrentNewtNativeQueryScene(
      motion: motion, drives: drives, coasts: coasts,
      outcomes: outcomes, ordnanceFrame: ordnanceFrame, report: report)
  }

  /// A true prefix of the same prepared curves. Source work and mechanical
  /// validation use the actual shorter plan, while drive/coast kinematics keep
  /// their original flow rather than being recomputed on a different window.
  func prefixCurrentNewtNativeQueryScene(
    _ scene: CurrentNewtNativeQueryScene,
    through end: Double, trajectory: CurrentNewtOuterMotion
  ) -> CurrentNewtNativeQueryScene? {
    let old = scene.motion.opening
    guard currentNewtNativeCommanderMatches(old.before), bodies == old.before.bodies,
      nativeStationRuntimeEpoch == old.before.nativeStationRuntimeEpoch,
      end > old.interval.start, end <= old.interval.end,
      trajectory.subrange(old.interval) == old.playerMotion
    else { return nil }
    if end == old.interval.end { return scene }
    let interval = CurrentNewtMechanicalInterval(start: old.interval.start, end: end)
    guard let motion = trajectory.subrange(interval), let player = trajectory.state(at: end),
      let opening = beginCurrentNewtNativeSegment(
        interval, playerMotion: motion, playerEnd: player,
        workEnergyRate: old.workEnergyRate, npcFrame: old.npcFrame),
      let mechanics = currentNewtMechanicalPlan(interval), let source = CurrentNewtKitSource.current
    else { return nil }
    let moving = Set(scene.drives.flatMap { [$0.plan.parentActor, $0.plan.podActor] })
    var overrides = mechanics.proposals.filter { !moving.contains($0.actor) }
    var outcomes: [CurrentNewtDriveOutcome] = []
    for curve in scene.drives {
      guard let sample = curve.sample(at: end), let outcome = curve.outcome(at: end),
        let mass = source.loadedParentMass(work: sample.work, load: curve.plan.load)
      else { return nil }
      outcomes.append(outcome)
      overrides.append(
        .init(
          actor: curve.plan.parentActor, before: curve.plan.parent,
          after: sample.parent, beforeMass: curve.plan.parentMass, afterMass: mass))
      overrides.append(
        .init(
          actor: curve.plan.podActor, before: curve.plan.pod,
          after: sample.pod, beforeMass: curve.plan.podMass, afterMass: curve.plan.podMass))
    }
    var coasts: [CurrentNewtNativeCoastCurve] = []
    for original in scene.coasts {
      guard let prefix = original.prefix(through: end) else { return nil }
      coasts.append(prefix)
    }
    guard
      let retained = prepareCurrentNewtNativeSegment(
        opening, mechanics: mechanics,
        mechanical: overrides,
        coasts: Dictionary(uniqueKeysWithValues: coasts.map { ($0.actor, $0) }))
    else { return nil }
    return assembleCurrentNewtNativeQueryScene(
      motion: retained, drives: scene.drives,
      coasts: coasts, outcomes: outcomes, ordnanceFrame: scene.ordnanceFrame)
  }

  private func assembleCurrentNewtNativeQueryScene(
    motion: CurrentNewtNativeSegmentPlan,
    drives: [CurrentNewtNativeDriveCurve], coasts: [CurrentNewtNativeCoastCurve],
    outcomes: [CurrentNewtDriveOutcome], ordnanceFrame: GameplayOrdnanceFrame?,
    report: ((CurrentNewtPreparationRefusal) -> Void)? = nil
  )
    -> CurrentNewtNativeQueryScene?
  {
    // Both component and whole-body passes read the same actual immutable cohorts.
    let sourceBodies = bodies
    let proposedBodies = motion.proposed.bodies
    let sourceCelestials = celestials
    guard
      let colliders = currentNewtNativeColliders(
        motion: motion, drives: drives, coasts: coasts,
        bodies: sourceBodies, proposedBodies: proposedBodies, celestials: sourceCelestials,
        ordnanceFrame: ordnanceFrame, splitMissionTargets: ordnanceFrame != nil, report: report)
    else {
      report?(.init(phase: .sceneAssembly, checkpoint: 1, bodyID: nil, component: nil))
      return nil
    }
    let solids: [CurrentNewtNativeCollider]
    if let ordnanceFrame {
      guard
        let wholeBodies = currentNewtNativeColliders(
          motion: motion, drives: drives,
          coasts: coasts, bodies: sourceBodies, proposedBodies: proposedBodies,
          celestials: sourceCelestials,
          ordnanceFrame: ordnanceFrame, splitMissionTargets: false, report: report)
      else {
        report?(.init(phase: .sceneAssembly, checkpoint: 2, bodyID: nil, component: nil))
        return nil
      }
      let projectileActors = Set(ordnanceFrame.entries.map(\.actor))
      solids = wholeBodies.filter { $0.actor.map { !projectileActors.contains($0) } ?? true }
    } else {
      solids = colliders
    }
    return .init(
      motion: motion, colliders: colliders, solidColliders: solids,
      drives: drives, coasts: coasts, outcomes: outcomes, ordnanceFrame: ordnanceFrame)
  }

  /// The genuine nonhostile launch cohort has no selected AI decision. Its original
  /// per-body phase still changes camera/model/canonical spin. Join that exact
  /// already-prepared opening/proposed motion to the current native hull source;
  /// this neither steers an actor nor supplies an effect or source authority.
  @inline(never)
  private func currentNewtOrdinaryNPCMotion(
    _ body: SpaceBody, proposed: SpaceBody, closingCamera: ShipPose, interval: CurrentNewtMechanicalInterval
  ) -> CurrentNewtNPCMotion? {
    guard !body.hostile, body.energy > 0, body.scriptNPC == nil,
      body.missionInstanceID == nil, body.blackjackRole == nil,
      body.scriptShot == nil, body.playerMissileTarget == nil, !body.enemyMissile,
      let physical = body.physical, physical.spawnIdentity == nil,
      physical.ordnance == nil, physical.empCrewPod == nil,
      let npc = physical.npc, npc.routeProvenance == .generated,
      let sourceID = physical.catalogueShipID,
      let source = OriginalFleetRuntimeHullSource.source(for: sourceID),
      !OriginalDetailedHullStage.blocksRuntime(body),
      source.ship.nativeHull == nil || source.ship.nativeHull == body.hull,
      NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
        catalogueShipID: sourceID, hull: body.hull, npc: npc, missiles: body.missiles),
      let player = storedFlightSimulation().player,
      physical.identity.system == player.system, physical.identity.visit == player.visit,
      physical.identity.entity >= 2, physical.identity.entity < storedFlightSimulation().nextActor,
      proposed.id == body.id, proposed.hull == body.hull, !proposed.hostile,
      proposed.scriptNPC == nil, proposed.missionInstanceID == nil,
      proposed.physical?.identity == physical.identity,
      proposed.physical?.catalogueShipID == sourceID, proposed.physical?.npc == npc
    else { return nil }
    let before = currentNewtBodyState(body)
    let end = Self.modelPose(of: proposed, player: closingCamera)
    let mesh = gameplayMesh(for: body)
    guard let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0,
      let motion = debrisRigidMotion(
        from: before.pose, to: end, duration: interval.end - interval.start, radius: radius)
    else { return nil }
    return .init(
      actor: physical.identity, bodyID: body.id, missionActor: nil, missionInstance: nil,
      before: before, originalNPC: nil, decision: nil, legacy: nil, motion: motion,
      startTime: interval.start, modelPhase: body.rotation, modelPhaseRate: body.rotationRate)
  }

  private func currentNewtNativeColliders(
    motion: CurrentNewtNativeSegmentPlan, drives: [CurrentNewtNativeDriveCurve],
    coasts: [CurrentNewtNativeCoastCurve],
    bodies: [SpaceBody], proposedBodies: [SpaceBody], celestials: [CelestialBody],
    ordnanceFrame: GameplayOrdnanceFrame?, splitMissionTargets: Bool,
    report: ((CurrentNewtPreparationRefusal) -> Void)?
  ) -> [CurrentNewtNativeCollider]? {
    var refusalBodyID: Int? = nil
    let interval = motion.opening.interval
    let duration = interval.end - interval.start
    var result: [CurrentNewtNativeCollider] = []
    func append(
      mesh: Mesh, actor: ActorIdentity?, id: String, newt: Bool,
      speed: Double, clockError: Double, referenceVelocity: Vector3,
      relativeSpeed: @escaping @Sendable (Vector3) -> Double?,
      pose: @escaping @Sendable (Double) -> ShipPose?,
      missionPart: String? = nil, missionComponent: UUID? = nil
    ) -> Bool {
      guard !mesh.vertices.isEmpty, mesh.vertices.allSatisfy(\.finite), speed.isFinite, speed >= 0,
        clockError.isFinite, clockError >= 0,
        referenceVelocity.finite,
        let hull = try? PreparedHull(mesh: mesh, maximumTriangles: newt ? 512 : 20_000)
      else {
        report?(.init(phase: .colliderAppend, checkpoint: 1, bodyID: refusalBodyID, component: id))
        return false
      }
      // The mean lies in the vertex convex hull, so its speed shares the actual
      // point-speed bound. This changes no source mesh or physical model origin.
      let centre = mesh.vertices.reduce(Vector3(0, 0, 0)) {
        $0 + $1 * (1 / Double(mesh.vertices.count))
      }
      guard let initialPose = pose(0) else {
        report?(.init(phase: .colliderAppend, checkpoint: 2, bodyID: refusalBodyID, component: id))
        return false
      }
      let rawRadius =
        mesh.vertices.map {
          initialPose.orientation.apply($0 - centre).length
        }.max() ?? 0
      // A fixed T0 enclosing sphere plus the actual all-point travel bound
      // needs no assumed future orthogonality or model-origin radius.
      let radius = rawRadius.nextUp
      guard centre.finite, radius.isFinite, radius > 0 else {
        report?(.init(phase: .colliderAppend, checkpoint: 3, bodyID: refusalBodyID, component: id))
        return false
      }
      var asteroid = false
      var debris = false
      var station = false
      if let actor, let body = bodies.first(where: { $0.physical?.identity == actor }) {
        // Same eligibility inputs as the existing AsteroidContactFrame producer.
        asteroid = asteroidDebrisMassKg(body) != nil
        let identity = stationInertialIdentity(for: body, at: interval.start)
        station = identity != nil
        let movingStation =
          identity.map { storedNativeStationWorld()?.inertia(for: $0) != nil } ?? false
        let surveyor =
          c01SurveyorCollision(body) ?? c01TimingStandardCollision(body)
          ?? c01LaneRepairCollision(body) ?? c01ClinicCollision(body)
        debris = asteroid || movingStation || surveyor != nil
      }
      result.append(
        .init(
          actor: actor, component: id, newt: newt,
          debris: debris, asteroid: asteroid, station: station, hull: hull, mesh: mesh,
          centre: centre, radius: radius, maximumPointSpeed: speed,
          clockSamplingTimeError: clockError,
          referenceVelocity: referenceVelocity, pointSpeedRelativeTo: relativeSpeed, poseAt: pose,
          victimPart: missionPart, componentUUID: missionComponent))
      return true
    }
    for body in bodies where body.energy > 0 {
      refusalBodyID = body.id
      guard let physical = body.physical,
        let endBody = proposedBodies.first(where: {
          $0.id == body.id && $0.physical?.identity == physical.identity
        })
      else {
        report?(.init(phase: .collider, checkpoint: 1, bodyID: refusalBodyID, component: nil))
        return nil
      }
      // These paths still belong to G1's later native operators. Until their
      // real preflight trajectories are supplied, a static endpoint cannot
      // stand in for a moving scene obstacle.
      if let state = physical.ordnance {
        // This target exists only through its genuine prepared native opening.
        // Default solid-scene preparation still refuses projectiles until the
        // point/contact owner is actually integrated; no static fake is used.
        guard let frame = ordnanceFrame, frame.epoch == nativeStationRuntimeEpoch,
          frame.context.system == storedFlightSimulation().system,
          frame.context.visit == storedFlightSimulation().visit,
          frame.context.physicalTime <= interval.start, frame.endTime >= interval.end,
          let entry = frame.entries.first(where: { $0.actor == physical.identity }),
          entry.body.id == body.id, entry.epoch == nativeStationRuntimeEpoch,
          physical.attackOrigin == state.origin,
          (modelPose(of: body).position - state.position).length < 1e-7,
          entry.matchesCurrentState(state, at: interval.start),
          body.rotationRate == 0, physical.angularVelocity == .init(0, 0, 0),
          !OriginalDetailedHullStage.blocksRuntime(body),
          entry.state(at: interval.end) != nil
        else {
          report?(.init(phase: .collider, checkpoint: 2, bodyID: refusalBodyID, component: nil))
          return nil
        }
        let mesh = gameplayMesh(for: body)
        let axes = modelPose(of: body).orientation
        let velocity = state.velocity
        let relevant = entry.trajectory.legs.filter {
          $0.endTime >= interval.start && $0.startTime <= interval.end
        }
        guard !relevant.isEmpty else {
          report?(.init(phase: .collider, checkpoint: 3, bodyID: refusalBodyID, component: nil))
          return nil
        }
        let bound: @Sendable (Vector3) -> Double? = { reference in
          guard reference.finite else { return nil }
          let speeds = relevant.map { ($0.velocity - reference).length }
          guard speeds.allSatisfy({ $0.isFinite && $0 >= 0 }), let speed = speeds.max()
          else { return nil }
          return speed.nextUp
        }
        guard let speed = bound(.init(0, 0, 0)),
          let clockError = entry.clockSamplingTimeError(start: interval.start, end: interval.end),
          append(
            mesh: mesh, actor: physical.identity, id: "ordnance", newt: false,
            speed: speed, clockError: clockError, referenceVelocity: velocity, relativeSpeed: bound,
            pose: { elapsed in
              guard let sampled = entry.state(at: interval.start + elapsed) else { return nil }
              return .init(position: sampled.position, orientation: axes)
            })
        else {
          report?(.init(phase: .collider, checkpoint: 4, bodyID: refusalBodyID, component: nil))
          return nil
        }
        continue
      }
      let npcPath = motion.opening.npcFrame?.entries[physical.identity]
        ?? currentNewtOrdinaryNPCMotion(
          body, proposed: endBody,
          closingCamera: motion.proposed.storedFlightSimulation().pose, interval: interval)
      let nativeInertia =
        c01SurveyorActor(body) != nil || c01TimingStandardPart(body) != nil
        || c01LaneRepairTarget(body) != nil || c01ClinicCradleDeclared(body)
      if physical.ordnance != nil || body.scriptShot != nil
        || body.playerMissileTarget != nil || body.enemyMissile
        || (body.scriptNPC != nil && npcPath == nil && !nativeInertia)
        || (npcPath == nil && !nativeInertia && physical.npc != nil
          && physical.spawnIdentity == nil)
      {
        report?(.init(phase: .collider, checkpoint: 22, bodyID: refusalBodyID, component: nil))
        return nil
      }
      if let npcPath {
        guard !OriginalDetailedHullStage.blocksRuntime(body) else {
          report?(.init(phase: .collider, checkpoint: 5, bodyID: refusalBodyID, component: nil))
          return nil
        }
        let parts: [(id: String, part: String?, component: UUID?, mesh: Mesh)]
        if splitMissionTargets, body.scriptNPC != nil {
          guard let qualified = currentNewtMissionCollisionParts(body) else {
            report?(.init(phase: .collider, checkpoint: 6, bodyID: refusalBodyID, component: nil))
            return nil
          }
          parts = qualified
        } else {
          parts = [("body", nil, nil, scriptNPCMesh(body) ?? gameplayMesh(for: body))]
        }
        for part in parts {
          let extent = part.mesh.vertices.map(\.length).max() ?? .infinity
          guard
            let speed = npcPath.pointSpeedBound(relativeTo: .init(0, 0, 0), localExtent: extent),
            let clockError = CurrentNewtQueryFrame.clockSamplingTimeError(
              start: interval.start, end: interval.end, origins: [npcPath.startTime],
              aliases: [
                .init(
                  clock: npcPath.startTime + npcPath.motion.duration,
                  origin: npcPath.startTime, elapsed: npcPath.motion.duration)
              ]),
            append(
              mesh: part.mesh, actor: physical.identity, id: part.id, newt: false, speed: speed,
              clockError: clockError,
              referenceVelocity: npcPath.motion.initialVelocity,
              relativeSpeed: { npcPath.pointSpeedBound(relativeTo: $0, localExtent: extent) },
              pose: { npcPath.state(at: interval.start + $0)?.pose },
              missionPart: part.part, missionComponent: part.component)
          else {
            report?(.init(phase: .collider, checkpoint: 7, bodyID: refusalBodyID, component: nil))
            return nil
          }
        }
        continue
      }
      if let drive = drives.first(where: {
        $0.plan.parentActor == physical.identity || $0.plan.podActor == physical.identity
      }) {
        let parent = drive.plan.parentActor == physical.identity
        let parts = parent ? drive.plan.parentComponents : drive.plan.podComponents
        for part in parts {
          guard let mesh = part.collisionMesh else { continue }
          let id = part.id
          guard
            let clockError = drive.clockSamplingTimeError(start: interval.start, end: interval.end),
            append(
              mesh: mesh, actor: physical.identity, id: id, newt: true,
              speed: parent ? drive.maximumParentPointSpeed : drive.maximumPodPointSpeed,
              clockError: clockError,
              referenceVelocity: parent ? drive.plan.parent.velocity : drive.plan.pod.velocity,
              relativeSpeed: { drive.pointSpeedBound(parent: parent, relativeTo: $0) },
              pose: { elapsed in
                guard let sample = drive.sample(at: interval.start + elapsed) else { return nil }
                return (parent ? sample.parentComponents : sample.podComponents).first {
                  $0.id == id
                }?.pose
              })
          else {
            report?(.init(phase: .collider, checkpoint: 8, bodyID: refusalBodyID, component: nil))
            return nil
          }
        }
        continue
      }
      if let coast = coasts.first(where: { $0.actor == physical.identity }) {
        guard let parts = coast.components(at: interval.start) else {
          report?(.init(phase: .collider, checkpoint: 9, bodyID: refusalBodyID, component: nil))
          return nil
        }
        for part in parts {
          guard let mesh = part.collisionMesh else { continue }
          let id = part.id
          guard
            let clockError = CurrentNewtQueryFrame.clockSamplingTimeError(
              start: interval.start, end: interval.end, origins: [coast.interval.start]),
            append(
              mesh: mesh, actor: physical.identity, id: id, newt: true,
              speed: coast.maximumPointSpeed, clockError: clockError,
              referenceVelocity: coast.flow.initial.velocity,
              relativeSpeed: { coast.pointSpeedBound(relativeTo: $0) },
              pose: { coast.components(at: interval.start + $0)?.first { $0.id == id }?.pose })
          else {
            report?(.init(phase: .collider, checkpoint: 10, bodyID: refusalBodyID, component: nil))
            return nil
          }
        }
        continue
      }
      if let proposal = motion.mechanics.proposals.first(where: { $0.actor == physical.identity }) {
        guard let scene = currentNewtMechanicalContactScene(proposal, interval: interval) else {
          report?(.init(phase: .collider, checkpoint: 11, bodyID: refusalBodyID, component: nil))
          return nil
        }
        for part in scene.before {
          guard let mesh = part.collisionMesh else { continue }
          let id = part.id
          guard let actuation = scene.stock.actuation,
            let clockError = CurrentNewtQueryFrame.clockSamplingTimeError(
              start: interval.start, end: interval.end, origins: [actuation.startedAt]),
            append(
              mesh: mesh, actor: physical.identity, id: id, newt: true,
              speed: scene.maximumWorldPointSpeed, clockError: clockError,
              referenceVelocity: proposal.before.velocity,
              relativeSpeed: { scene.pointSpeedBound(relativeTo: $0) },
              pose: { elapsed in
                scene.components(at: interval.start + elapsed)?.first { $0.id == id }?.pose
              })
          else {
            report?(.init(phase: .collider, checkpoint: 12, bodyID: refusalBodyID, component: nil))
            return nil
          }
        }
        continue
      }
      let before = currentNewtBodyState(body)
      let after = motion.proposed.currentNewtBodyState(endBody)
      guard
        let rigid = debrisRigidMotion(
          from: before.pose, to: after.pose,
          duration: duration, radius: 0)
      else {
        report?(.init(phase: .collider, checkpoint: 13, bodyID: refusalBodyID, component: nil))
        return nil
      }
      if physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil {
        guard let parts = try? currentNewtGeometryComponents(for: body) else {
          report?(.init(phase: .collider, checkpoint: 14, bodyID: refusalBodyID, component: nil))
          return nil
        }
        for part in parts {
          guard let mesh = part.collisionMesh else { continue }
          guard
            let offset = Self.currentNewtExactCoordinates(
              part.pose.position - before.pose.position,
              in: before.pose.orientation)
          else {
            report?(.init(phase: .collider, checkpoint: 15, bodyID: refusalBodyID, component: nil))
            return nil
          }
          let relative = part.pose.orientation.workFrameRelative(to: before.pose.orientation)
          let extent = offset.length + (mesh.vertices.map { relative.apply($0).length }.max() ?? 0)
          let speed = rigid.initialVelocity.length + 2 * rigid.worldAngularVelocity.length * extent
          guard
            append(
              mesh: mesh, actor: physical.identity, id: part.id, newt: true, speed: speed,
              clockError: 0,
              referenceVelocity: rigid.initialVelocity,
              relativeSpeed: {
                CurrentNewtQueryFrame.pointSpeedBound(
                  motion: rigid,
                  localExtent: extent, relativeTo: $0)
              },
              pose: { elapsed in
                if elapsed == 0 { return part.pose }
                let state = HullSweepSafety.shipPose(rigid, at: elapsed)
                return .init(
                  position: state.systemPoint(offset),
                  orientation: state.orientation.composed(with: relative))
              })
          else {
            report?(.init(phase: .collider, checkpoint: 16, bodyID: refusalBodyID, component: nil))
            return nil
          }
        }
      } else {
        guard !OriginalDetailedHullStage.blocksRuntime(body) else {
          report?(.init(phase: .collider, checkpoint: 17, bodyID: refusalBodyID, component: nil))
          return nil
        }
        let mesh = scriptNPCMesh(body) ?? gameplayMesh(for: body)
        let extent = mesh.vertices.map(\.length).max() ?? .infinity
        let speed = rigid.initialVelocity.length + 2 * rigid.worldAngularVelocity.length * extent
        guard
          append(
            mesh: mesh, actor: physical.identity, id: "body", newt: false,
            speed: speed, clockError: 0, referenceVelocity: rigid.initialVelocity,
            relativeSpeed: {
              CurrentNewtQueryFrame.pointSpeedBound(
                motion: rigid,
                localExtent: extent, relativeTo: $0)
            },
            pose: { HullSweepSafety.shipPose(rigid, at: $0) })
        else {
          report?(.init(phase: .collider, checkpoint: 18, bodyID: refusalBodyID, component: nil))
          return nil
        }
      }
    }
    refusalBodyID = nil
    let player = motion.opening.playerMotion
    let playerExtent = nativeGuidanceStoredPlayerMesh().vertices.map(\.length).max() ?? .infinity
    let playerSpeed =
      player.initialVelocity.length + player.acceleration.length * duration
      + 2 * player.worldAngularVelocity.length * playerExtent
    guard
      append(
        mesh: nativeGuidanceStoredPlayerMesh(), actor: storedFlightSimulation().player,
        id: "player", newt: false, speed: playerSpeed, clockError: 0,
        referenceVelocity: player.initialVelocity,
        relativeSpeed: {
          CurrentNewtQueryFrame.pointSpeedBound(
            motion: player,
            localExtent: playerExtent, relativeTo: $0)
        },
        pose: { HullSweepSafety.shipPose(player, at: $0) })
    else {
      report?(.init(phase: .collider, checkpoint: 19, bodyID: refusalBodyID, component: nil))
      return nil
    }
    for (index, celestial) in celestials.enumerated() {
      guard celestial.radius.isFinite, celestial.radius > 0 else {
        report?(.init(phase: .collider, checkpoint: 20, bodyID: refusalBodyID, component: nil))
        return nil
      }
      let pose = ShipPose(position: storedFlightSimulation().pose.systemPoint(celestial.position))
      // A conservative enclosure can prove clearance. Its contact can only
      // refuse this candidate, never assert an actual sphere impact or damage.
      guard
        append(
          mesh: workObstacleBox(celestial.radius), actor: nil,
          id: "celestial-\(index)", newt: false, speed: 0, clockError: 0,
          referenceVelocity: .init(0, 0, 0),
          relativeSpeed: { $0.finite ? $0.length.nextUp : nil }, pose: { _ in pose })
      else {
        report?(.init(phase: .collider, checkpoint: 21, bodyID: refusalBodyID, component: nil))
        return nil
      }
    }
    return result
  }

  /// Same authenticated root/installed-component geometry and transforms as
  /// native mission ray queries, retained as separate actual damage identities.
  private func currentNewtMissionCollisionParts(_ body: SpaceBody)
    -> [(id: String, part: String?, component: UUID?, mesh: Mesh)]?
  {
    guard let npc = body.scriptNPC, npc.valid,
      OriginalScopedScriptedHull.referenced(by: npc.fit.definition)?.permits(npc.fit) != false,
      let root = scriptModel(npc.fit.definition.model, fit: npc.fit)
    else { return nil }
    let scale = npc.fit.definition.scale
    func mesh(_ source: Mesh, position: Vector3, axes: Basis3, factor: Double) -> Mesh {
      .init(
        vertices: source.vertices.map { (position + axes.apply($0 * factor)) * scale },
        faces: source.faces, details: source.details, materials: source.materials,
        faceMaterials: source.faceMaterials, faceTextures: source.faceTextures,
        preserveWinding: true)
    }
    var result: [(id: String, part: String?, component: UUID?, mesh: Mesh)] = [
      ("body", nil, nil, mesh(root, position: .init(0, 0, 0), axes: .init(), factor: 1))
    ]
    for spec in npc.fit.definition.components ?? [] {
      guard let component = npc.components[spec.id], component.energy > 0 else { continue }
      guard let source = scriptModel(spec.model, fit: npc.fit), spec.position.finite,
        spec.orientation.validRotation, spec.scale.isFinite, spec.scale > 0
      else { return nil }
      result.append(
        (
          "mission-component:" + spec.id, spec.id, component.identity,
          mesh(source, position: spec.position, axes: spec.orientation, factor: spec.scale)
        ))
    }
    return result
  }

  private func currentNewtPairHasDriveProof(
    _ a: CurrentNewtNativeCollider, _ b: CurrentNewtNativeCollider,
    drives: [CurrentNewtNativeDriveCurve], coasts: [CurrentNewtNativeCoastCurve]
  ) -> Bool {
    for drive in drives {
      if a.actor == drive.plan.parentActor && b.actor == drive.plan.podActor,
        drive.provesGovernedPair(rodID: a.component, shoeID: b.component)
      {
        return true
      }
      if b.actor == drive.plan.parentActor && a.actor == drive.plan.podActor,
        drive.provesGovernedPair(rodID: b.component, shoeID: a.component)
      {
        return true
      }
    }
    for (parent, pod) in [(a, b), (b, a)] {
      guard let parentActor = parent.actor, let podActor = pod.actor,
        let body = bodies.first(where: { $0.physical?.identity == parentActor }),
        let receipt = body.physical?.currentNewtKitStock?.receipt,
        bodies.first(where: { $0.physical?.identity == podActor })?
          .physical?.currentNewtKitReceipt == receipt,
        let p = coasts.first(where: { $0.actor == parentActor }),
        let c = coasts.first(where: { $0.actor == podActor }),
        let rod = p.components(at: p.interval.start)?.first(where: { $0.id == parent.component }),
        let shoe = c.components(at: c.interval.start)?.first(where: { $0.id == pod.component }),
        let source = CurrentNewtKitSource.current
      else { continue }
      if CurrentNewtOpeningContactProof.proves(
        rod: rod, shoe: shoe,
        parent: p.flow, pod: c.flow, duration: p.interval.end - p.interval.start, source: source)
      {
        return true
      }
    }
    return false
  }

  private static func currentNewtExactCoordinates(_ value: Vector3, in basis: Basis3) -> Vector3? {
    let x = basis.y.cross(basis.z)
    let y = basis.z.cross(basis.x)
    let z = basis.x.cross(basis.y)
    let determinant = basis.x.dot(x)
    guard determinant.isFinite, determinant > 0 else { return nil }
    let result = Vector3(value.dot(x), value.dot(y), value.dot(z)) * (1 / determinant)
    return result.finite ? result : nil
  }
}

extension Game {
  private func currentNewtResolveImpacts(
    motion: CurrentNewtNativeSegmentPlan, colliders: [CurrentNewtNativeCollider],
    drives: [CurrentNewtNativeDriveCurve], coasts: [CurrentNewtNativeCoastCurve],
    initialOutcomes: [CurrentNewtDriveOutcome], budget: HullSweepBudget, maximumPairs: Int,
    workReport: inout CurrentNewtOrdnanceQueryWork
  ) -> CurrentNewtNativeContactResolution? {
    let interval = motion.opening.interval
    guard let player = storedFlightSimulation().player else { return nil }
    var continuations: [ActorIdentity: CurrentNewtImpactContinuation] = [:]
    var outcomes = initialOutcomes
    var stopped: [ActorIdentity: Double] = [:]
    var impacts: [CurrentNewtNativeImpactApplication] = []
    var offset = 0.0
    var pairs = 0
    var queryBudget = budget
    defer {
      workReport = .init(
        candidatePairs: pairs,
        distanceQueries: budget.distanceQueries - queryBudget.distanceQueries,
        triangleTests: budget.triangleTests - queryBudget.triangleTests,
        nodeVisits: budget.nodeVisits - queryBudget.nodeVisits)
    }
    var clearPairs: Set<Int> = []
    while offset < interval.end - interval.start {
      let now = interval.start + offset
      let remaining = interval.end - now
      guard remaining > 0,
        let clockWindow = NativeCurveClockWindow(start: now, end: interval.end),
        let adapterError = CurrentNewtQueryFrame.clockSamplingTimeError(
          start: now, end: interval.end, origins: [interval.start]),
        let current = currentNewtImpactColliders(
          colliders, start: interval.start, continuations: continuations)
      else { return nil }
      func pose(_ collider: CurrentNewtNativeCollider, at elapsed: Double) -> ShipPose? {
        collider.pose(at: elapsed, in: clockWindow, rootClock: interval.start)
      }
      var candidates: [CurrentNewtSelectedImpact] = []
      for a in current.indices {
        for b in current.indices where b > a {
          let pairKey = a * current.count + b
          if clearPairs.contains(pairKey) { continue }
          var left = current[a]
          var right = current[b]
          if currentNewtSwapImpactSource(left, right, player: player) { swap(&left, &right) }
          let playerPair = left.actor == player || right.actor == player
          guard left.newt || right.newt || left.debris || right.debris || playerPair else {
            continue
          }
          if let actor = left.actor, actor == right.actor { continue }
          if left.actor.flatMap({ continuations[$0] }) == nil,
            right.actor.flatMap({ continuations[$0] }) == nil,
            currentNewtPairHasDriveProof(left, right, drives: drives, coasts: coasts)
          {
            continue
          }
          if currentNewtInterruptedPairProof(
            left, right, at: now,
            continuations: continuations)
          {
            continue
          }
          guard let ap = pose(left, at: 0), let bp = pose(right, at: 0),
            let leftError = left.samplingPositionError(adapterTimeError: adapterError),
            let rightError = right.samplingPositionError(adapterTimeError: adapterError)
          else { return nil }
          let aRadius =
            (left.mesh.vertices.map { ap.orientation.apply($0 - left.centre).length }.max()
            ?? .infinity).nextUp
          let bRadius =
            (right.mesh.vertices.map { bp.orientation.apply($0 - right.centre).length }.max()
            ?? .infinity).nextUp
          let separation =
            (ap.systemPoint(left.centre) - bp.systemPoint(right.centre)).length
            - aRadius - bRadius
          let reference = left.referenceVelocity
          guard let leftSpeed = left.pointSpeedRelativeTo(reference),
            let rightSpeed = right.pointSpeedRelativeTo(reference),
            leftSpeed.isFinite, leftSpeed >= 0, rightSpeed.isFinite, rightSpeed >= 0,
            let queryFrame = CurrentNewtQueryFrame(
              origin: ap.position,
              velocity: reference, timeOrigin: 0)
          else { return nil }
          let travel = ((leftSpeed + rightSpeed).nextUp * remaining).nextUp
          let numerical =
            128 * Double.ulpOfOne
            * max(1, ap.position.length + bp.position.length + left.radius + right.radius)
          guard separation.isFinite, travel.isFinite, numerical.isFinite else { return nil }
          if HullSweepSafety.currentNewtCurvePairClearanceProven(separation: separation,
            travel: travel, numerical: numerical, sourceSamplingError: leftError,
            targetSamplingError: rightError) { continue }
          pairs += 1
          guard pairs <= maximumPairs && pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
            return nil
          }
          var report = HullSweepResult(
            failure: nil, obstacle: nil, minimumSampledClearance: nil,
            distanceQueries: 0, triangleTests: 0, nodeVisits: 0)
          let contact = HullSweepSafety.firstCurrentNewtCurveContact(
            source: left.hull, target: right.hull, duration: remaining,
            sourcePointSpeed: leftSpeed, targetPointSpeed: rightSpeed,
            sourceAt: { pose(left, at: $0) }, targetAt: { pose(right, at: $0) },
            queryFrame: queryFrame, sourceSamplingError: leftError, targetSamplingError: rightError,
            clockWindow: clockWindow, budget: queryBudget, report: &report)
          queryBudget.distanceQueries -= report.distanceQueries
          queryBudget.triangleTests -= report.triangleTests
          queryBudget.nodeVisits -= report.nodeVisits
          switch contact {
          case .clear: clearPairs.insert(pairKey)
          case .refused: return nil
          case .contact(let found):
            guard found.clockWindow?.start == now, found.clockWindow?.end == interval.end,
              let lower = found.lowerPhysicalTime, let upper = found.upperPhysicalTime,
              lower >= now, upper > now, upper >= lower, upper <= interval.end,
              found.upperTime == upper - now,
              found.sourcePose == pose(left, at: upper - now),
              found.targetPose == pose(right, at: upper - now) else { return nil }
            candidates.append(.init(source: left, target: right, contact: found,
              lowerPhysicalTime: lower, upperPhysicalTime: upper))
          }
        }
      }
      if candidates.isEmpty { break }
      guard
        let selected = CurrentNewtContactChronology.earliest(
          candidates.map {
            .init(lower: $0.lowerPhysicalTime - now, upper: $0.upperPhysicalTime - now)
          })
      else { return nil }
      let hit = candidates[selected]
      let time = hit.lowerPhysicalTime
      let effectTime = hit.upperPhysicalTime
      guard time >= now, time < interval.end,
        impacts.isEmpty || (time > now && effectTime >= impacts.last!.contactPhysicalTime),
        let a = hit.source.actor, let b = hit.target.actor, a != player,
        !hit.source.station, !hit.target.station,
        let sourceBody = bodies.first(where: { $0.physical?.identity == a }),
        let sourcePose = hit.source.poseAt(time - interval.start),
        let targetPose = hit.target.poseAt(time - interval.start),
        interval.start + (time - interval.start) == time,
        interval.start + (effectTime - interval.start) == effectTime,
        HullSweepSafety.currentNewtEndpointPairClearance(
          source: hit.source.hull,
          sourcePose: sourcePose, target: hit.target.hull, targetPose: targetPose
        ).safe
      else { return nil }

      guard
        let playerAtImpact = currentNewtImpactState(
          player, at: effectTime, motion: motion,
          drives: drives, coasts: coasts, continuations: continuations),
        let sourceAtImpact = currentNewtImpactState(
          a, at: effectTime, motion: motion,
          drives: drives, coasts: coasts, continuations: continuations),
        let targetAtImpact = currentNewtImpactState(
          b, at: effectTime, motion: motion,
          drives: drives, coasts: coasts, continuations: continuations)
      else { return nil }
      // Stop the force prefix once, including both members of a real drive.
      // These brakes preserve full component P/L and can only remove energy.
      var contactStates: [ActorIdentity: CurrentNewtImpactState] = [:]
      var coupledEffect: AsteroidImpulse?
      for drive in drives
      where
        (drive.plan.parentActor == a || drive.plan.podActor == a
        || drive.plan.parentActor == b || drive.plan.podActor == b)
        && continuations[drive.plan.parentActor] == nil
      {
        guard let source = CurrentNewtKitSource.current,
          let index = outcomes.firstIndex(where: { $0.kitID == drive.plan.issue.kitID })
        else { return nil }
        let parentIsSource = a == drive.plan.parentActor && b == drive.plan.podActor
        let parentIsTarget = b == drive.plan.parentActor && a == drive.plan.podActor
        let rodContact =
          (parentIsSource && hit.source.component.hasPrefix("moving-rod-"))
          || (parentIsTarget && hit.target.component.hasPrefix("moving-rod-"))
        let interrupted:
          (sample: CurrentNewtNativeDriveCurve.Sample, outcome: CurrentNewtDriveOutcome)
        if rodContact {
          let normal = parentIsSource ? hit.contact.normal : hit.contact.normal * -1
          guard let collision = drive.rodImpact(at: time, point: hit.contact.point, normal: normal)
          else { return nil }
          interrupted = (collision.sample, collision.outcome)
          coupledEffect =
            parentIsSource
            ? collision.effect
            : .init(
              source: collision.effect.target,
              target: collision.effect.source, transferred: collision.effect.transferred * -1,
              damage: collision.effect.damage)
        } else {
          guard let brake = drive.interrupted(at: time) else { return nil }
          interrupted = brake
        }
        guard
          let parentMass = source.loadedParentMass(
            work: interrupted.sample.work, load: drive.plan.load)
        else { return nil }
        outcomes[index] = interrupted.outcome
        stopped[drive.plan.parentActor] = time
        contactStates[drive.plan.parentActor] = .init(
          state: interrupted.sample.parent,
          mass: .tensor(parentMass), components: interrupted.sample.parentComponents,
          maximumAngularSpeed: source.maximumAngularSpeed)
        contactStates[drive.plan.podActor] = .init(
          state: interrupted.sample.pod,
          mass: .tensor(drive.plan.podMass), components: interrupted.sample.podComponents,
          maximumAngularSpeed: source.maximumAngularSpeed)
      }
      for actor in [a, b] where contactStates[actor] == nil {
        guard
          var state = currentNewtImpactState(
            actor, at: time, motion: motion,
            drives: drives, coasts: coasts, continuations: continuations)
        else { return nil }
        if motion.mechanics.proposals.contains(where: { $0.actor == actor }),
          continuations[actor] == nil
        {
          guard case .tensor(let mass) = state.mass,
            let braked = CurrentNewtKitBrake.retainedState(
              components: state.components,
              mass: mass, before: state.state, maximumAngularSpeed: state.maximumAngularSpeed)
          else { return nil }
          state = .init(
            state: braked, mass: state.mass, components: state.components,
            maximumAngularSpeed: state.maximumAngularSpeed)
          stopped[actor] = time
        }
        contactStates[actor] = state
      }
      let impulse: AsteroidImpulse
      if let coupledEffect {
        impulse = coupledEffect
      } else {
        guard let beforeA = contactStates[a], let beforeB = contactStates[b],
          let response = CurrentNewtImpactResponse.resolve(
            source: beforeA.state, mass: beforeA.mass,
            target: beforeB.state, mass: beforeB.mass, point: hit.contact.point,
            normal: hit.contact.normal)
        else { return nil }
        contactStates[a] = .init(
          state: response.source, mass: beforeA.mass,
          components: beforeA.components, maximumAngularSpeed: beforeA.maximumAngularSpeed)
        contactStates[b] = .init(
          state: response.target, mass: beforeB.mass,
          components: beforeB.components, maximumAngularSpeed: beforeB.maximumAngularSpeed)
        impulse = response.effect
      }
      if a == player || b == player { stopped[player] = stopped[player] ?? time }
      // A related already free parent/pod may touch on its authentic interface.
      // Restart its unchanged physical coast at the same instant, so the opening
      // support proof reads both actual post-impact trajectories and no old drive.
      for body in bodies {
        guard let actor = body.physical?.identity, contactStates[actor] == nil else { continue }
        let parentReceipt = body.physical?.currentNewtKitStock?.receipt
        let podReceipt = body.physical?.currentNewtKitReceipt
        let related = [a, b].contains { impacted in
          guard let other = bodies.first(where: { $0.physical?.identity == impacted }) else {
            return false
          }
          return (parentReceipt != nil && parentReceipt == other.physical?.currentNewtKitReceipt)
            || (podReceipt != nil && podReceipt == other.physical?.currentNewtKitStock?.receipt)
        }
        if related {
          guard
            let state = currentNewtImpactState(
              actor, at: time, motion: motion,
              drives: drives, coasts: coasts, continuations: continuations)
          else { return nil }
          contactStates[actor] = state
        }
      }
      for (actor, state) in contactStates {
        guard
          let coast = CurrentNewtImpactContinuation(
            actor: actor, start: time, end: interval.end,
            initial: state.state, mass: state.mass, components: state.components,
            maximumAngularSpeed: state.maximumAngularSpeed)
        else { return nil }
        continuations[actor] = coast
      }
      // A complete earlier proof still covers the suffix of two unchanged
      // trajectories. Only pairs containing a changed actor need a new query.
      clearPairs = Set(
        clearPairs.filter { key in
          let left = colliders[key / colliders.count].actor
          let right = colliders[key % colliders.count].actor
          return left.flatMap { contactStates[$0] } == nil
            && right.flatMap { contactStates[$0] } == nil
        })
      // Health/shield/rights use the genuine incoming upper witness frame.
      // Physical response starts at the proved clear lower frontier.
      impacts.append(
        .init(
          contact: hit.contact, impulse: impulse,
          sourceID: sourceBody.id, sourceActor: a,
          targetID: b == player ? nil : bodies.first(where: { $0.physical?.identity == b })?.id,
          targetActor: b, playerPose: playerAtImpact.state.pose,
          sourcePose: sourceAtImpact.state.pose, targetPose: targetAtImpact.state.pose,
          contactPhysicalTime: effectTime))
      guard impacts.count <= AsteroidImpactPolicy.maximumCandidatePairs else { return nil }
      offset = time - interval.start
    }
    var endpoints = Dictionary(uniqueKeysWithValues: motion.mechanical.map { ($0.actor, $0.after) })
    for coast in coasts {
      guard let end = coast.state(at: interval.end) else { return nil }
      endpoints[coast.actor] = end
    }
    var playerEnd = motion.opening.playerEnd
    for (actor, coast) in continuations {
      guard let end = coast.state(at: interval.end) else { return nil }
      if actor == player { playerEnd = end } else { endpoints[actor] = end }
    }
    return .init(
      player: playerEnd, bodies: endpoints, stoppedAt: stopped,
      admitted: true, drives: outcomes, impacts: impacts)
  }
}

extension Game {
  /// Keep the existing one-sided effect roles. For equal eligible roles, use
  /// actual physical issuance order rather than mutable body-array enumeration.
  private func currentNewtSwapImpactSource(
    _ left: CurrentNewtNativeCollider,
    _ right: CurrentNewtNativeCollider, player: ActorIdentity
  ) -> Bool {
    if left.actor == player { return true }
    if right.actor == player { return false }
    if left.station && right.asteroid { return true }
    if left.asteroid && right.station { return false }
    if left.debris != right.debris { return right.debris }
    guard let a = left.actor else { return right.actor != nil }
    guard let b = right.actor else { return false }
    if a.system.galaxy != b.system.galaxy { return a.system.galaxy > b.system.galaxy }
    if a.system.system != b.system.system { return a.system.system > b.system.system }
    if a.visit != b.visit { return a.visit > b.visit }
    return a.entity > b.entity
  }

  private func currentNewtImpactState(
    _ actor: ActorIdentity, at time: Double,
    motion: CurrentNewtNativeSegmentPlan, drives: [CurrentNewtNativeDriveCurve],
    coasts: [CurrentNewtNativeCoastCurve],
    continuations: [ActorIdentity: CurrentNewtImpactContinuation]
  ) -> CurrentNewtImpactState? {
    if let coast = continuations[actor] {
      guard let state = coast.state(at: time) else { return nil }
      let parts = coast.components.compactMap { coast.part($0.id, at: time) }
      guard parts.count == coast.components.count else { return nil }
      return .init(
        state: state, mass: coast.mass, components: parts,
        maximumAngularSpeed: coast.rigidFlow?.maximumAngularSpeed
          ?? AsteroidImpactPolicy.maximumSpeed)
    }
    let interval = motion.opening.interval
    guard time >= interval.start, time <= interval.end else { return nil }
    if let drive = drives.first(where: { $0.plan.parentActor == actor || $0.plan.podActor == actor }
    ) {
      guard let sample = drive.sample(at: time), let source = CurrentNewtKitSource.current else {
        return nil
      }
      let parent = drive.plan.parentActor == actor
      let mass: CurrentNewtKitReceipt.MassProperties
      if parent {
        guard let actual = source.loadedParentMass(work: sample.work, load: drive.plan.load) else {
          return nil
        }
        mass = actual
      } else {
        mass = drive.plan.podMass
      }
      return .init(
        state: parent ? sample.parent : sample.pod, mass: .tensor(mass),
        components: parent ? sample.parentComponents : sample.podComponents,
        maximumAngularSpeed: source.maximumAngularSpeed)
    }
    if let coast = coasts.first(where: { $0.actor == actor }) {
      guard let state = coast.state(at: time), let parts = coast.components(at: time) else {
        return nil
      }
      return .init(
        state: state, mass: .tensor(coast.mass), components: parts,
        maximumAngularSpeed: coast.flow.maximumAngularSpeed)
    }
    if let proposal = motion.mechanics.proposals.first(where: { $0.actor == actor }) {
      guard let scene = currentNewtMechanicalContactScene(proposal, interval: interval),
        let source = CurrentNewtKitSource.current, let actuation = scene.stock.actuation,
        let sample = source.motion(actuation, at: time),
        let body = bodies.first(where: { $0.physical?.identity == actor }),
        let cell = currentNewtCellComponentContract(for: body),
        let parts = source.components(
          stock: scene.stock,
          work: source.work(at: time, actuation: actuation), at: time, parent: sample.parent,
          load: scene.load, cell: cell),
        let mass = CurrentNewtImpactContinuation.mass(of: parts, in: sample.parent.pose)
      else { return nil }
      return .init(
        state: sample.parent, mass: .tensor(mass), components: parts,
        maximumAngularSpeed: source.maximumAngularSpeed)
    }
    let elapsed = time - interval.start
    if storedFlightSimulation().player == actor {
      let path = motion.opening.playerMotion
      return .init(
        state: .init(
          pose: HullSweepSafety.shipPose(path, at: elapsed),
          velocity: path.initialVelocity + path.acceleration * elapsed,
          angularVelocity: path.worldAngularVelocity),
        mass: .translational(AsteroidImpactPolicy.massKg(hull: .cobra)), components: [],
        maximumAngularSpeed: AsteroidImpactPolicy.maximumSpeed)
    }
    if let path = motion.opening.npcFrame?.entries[actor] {
      guard let body = bodies.first(where: { $0.physical?.identity == actor }),
        body.id == path.bodyID, body.physical?.currentNewtKitStock == nil,
        body.physical?.currentNewtKitReceipt == nil, let state = path.state(at: time)
      else { return nil }
      return .init(
        state: state,
        mass: .translational(
          asteroidDebrisMassKg(body) ?? AsteroidImpactPolicy.massKg(hull: body.hull)),
        components: [], maximumAngularSpeed: AsteroidImpactPolicy.maximumSpeed)
    }
    guard let body = bodies.first(where: { $0.physical?.identity == actor }),
      let end = motion.proposed.bodies.first(where: {
        $0.id == body.id && $0.physical?.identity == actor
      }),
      body.physical?.currentNewtKitStock == nil, body.physical?.currentNewtKitReceipt == nil,
      let path = debrisRigidMotion(
        from: currentNewtBodyState(body).pose,
        to: motion.proposed.currentNewtBodyState(end).pose,
        duration: interval.end - interval.start, radius: 0)
    else { return nil }
    return .init(
      state: .init(
        pose: HullSweepSafety.shipPose(path, at: elapsed),
        velocity: path.initialVelocity + path.acceleration * elapsed,
        angularVelocity: path.worldAngularVelocity),
      mass: .translational(
        asteroidDebrisMassKg(body) ?? AsteroidImpactPolicy.massKg(hull: body.hull)),
      components: [], maximumAngularSpeed: AsteroidImpactPolicy.maximumSpeed)
  }

  private func currentNewtImpactColliders(
    _ original: [CurrentNewtNativeCollider], start: Double,
    continuations: [ActorIdentity: CurrentNewtImpactContinuation]
  ) -> [CurrentNewtNativeCollider]? {
    var result: [CurrentNewtNativeCollider] = []
    for collider in original {
      guard let actor = collider.actor, let coast = continuations[actor] else {
        result.append(collider)
        continue
      }
      let extent: Double
      let pose: @Sendable (Double) -> ShipPose?
      if collider.newt {
        guard let part = coast.components.first(where: { $0.id == collider.component }),
          part.collisionMesh != nil
        else { return nil }
        extent =
          (part.pose.position - coast.initial.pose.position).length
          + (collider.mesh.vertices.map(\.length).max() ?? .infinity)
        pose = { elapsed in coast.part(collider.component, at: start + elapsed)?.pose }
      } else {
        extent = collider.mesh.vertices.map(\.length).max() ?? .infinity
        pose = { elapsed in coast.state(at: start + elapsed)?.pose }
      }
      guard let speed = coast.pointSpeedBound(extent: extent),
        let clockError = CurrentNewtQueryFrame.clockSamplingTimeError(
          start: start, end: coast.end, origins: [coast.start])
      else { return nil }
      result.append(
        .init(
          actor: actor, component: collider.component, newt: collider.newt,
          debris: collider.debris, asteroid: collider.asteroid, station: collider.station,
          hull: collider.hull, mesh: collider.mesh, centre: collider.centre,
          radius: collider.radius,
          maximumPointSpeed: speed, clockSamplingTimeError: clockError,
          referenceVelocity: coast.initial.velocity,
          pointSpeedRelativeTo: { coast.pointSpeedBound(extent: extent, relativeTo: $0) },
          poseAt: pose))
    }
    return result
  }

  private func currentNewtInterruptedPairProof(
    _ a: CurrentNewtNativeCollider,
    _ b: CurrentNewtNativeCollider, at time: Double,
    continuations: [ActorIdentity: CurrentNewtImpactContinuation]
  ) -> Bool {
    for (rod, shoe) in [(a, b), (b, a)] {
      guard let parent = rod.actor, let pod = shoe.actor,
        let body = bodies.first(where: { $0.physical?.identity == parent }),
        let receipt = body.physical?.currentNewtKitStock?.receipt,
        bodies.first(where: { $0.physical?.identity == pod })?.physical?.currentNewtKitReceipt
          == receipt,
        let p = continuations[parent], let c = continuations[pod],
        // A proof of the whole post-impact suffix is also a proof of its subranges.
        p.start == c.start, p.end == c.end, time >= p.start,
        let parentFlow = p.rigidFlow, let podFlow = c.rigidFlow,
        let rodPart = p.part(rod.component, at: p.start),
        let shoePart = c.part(shoe.component, at: c.start),
        let source = CurrentNewtKitSource.current
      else { continue }
      if CurrentNewtOpeningContactProof.proves(
        rod: rodPart, shoe: shoePart,
        parent: parentFlow, pod: podFlow, duration: p.end - p.start, source: source)
      {
        return true
      }
    }
    return false
  }
}

/// Selected only from the source-qualified scene and the actual native point
/// query. This is a geometric/contact preparation, not damage or clock credit.
final class CurrentNewtOrdnanceCurveContact: Sendable, Equatable {
  static func == (left: CurrentNewtOrdnanceCurveContact, right: CurrentNewtOrdnanceCurveContact)
    -> Bool
  {
    left === right
  }
  let scene: CurrentNewtNativeQueryScene
  let opening: GameplayOrdnanceOpening
  let target: CurrentNewtNativeCollider
  let native: NativeSphereCurveContact
  let lowerPhysicalTime: Double
  let upperPhysicalTime: Double

  fileprivate init(
    scene: CurrentNewtNativeQueryScene, opening: GameplayOrdnanceOpening,
    target: CurrentNewtNativeCollider, native: NativeSphereCurveContact,
    lowerPhysicalTime: Double, upperPhysicalTime: Double
  ) {
    self.scene = scene
    self.opening = opening
    self.target = target
    self.native = native
    self.lowerPhysicalTime = lowerPhysicalTime
    self.upperPhysicalTime = upperPhysicalTime
  }
}

enum CurrentNewtOrdnanceCurveQueryResult: Sendable {
  case clear(CurrentNewtOrdnanceQueryWork)
  case contact(CurrentNewtOrdnanceCurveContact, CurrentNewtOrdnanceQueryWork)
  case refused(HullSweepFailure, CurrentNewtOrdnanceQueryWork)
}

struct CurrentNewtOrdnanceQueryWork: Sendable {
  let candidatePairs: Int
  let distanceQueries: Int
  let triangleTests: Int
  let nodeVisits: Int
}

extension Game {
  /// One genuine guidance leg. Its source stays a point; interception targets
  /// retain the existing native missile geometry qualified by the scene owner.
  func firstCurrentNewtOrdnanceContact(
    in scene: CurrentNewtNativeQueryScene,
    actor: ActorIdentity, budget: HullSweepBudget = .standard
  ) -> CurrentNewtOrdnanceCurveQueryResult {
    var remaining = budget
    var pairs = 0
    func cost() -> CurrentNewtOrdnanceQueryWork {
      .init(
        candidatePairs: pairs, distanceQueries: budget.distanceQueries - remaining.distanceQueries,
        triangleTests: budget.triangleTests - remaining.triangleTests,
        nodeVisits: budget.nodeVisits - remaining.nodeVisits)
    }
    func charge(_ report: HullSweepResult) {
      remaining.distanceQueries -= report.distanceQueries
      remaining.triangleTests -= report.triangleTests
      remaining.nodeVisits -= report.nodeVisits
    }
    func refused(_ reason: HullSweepFailure) -> CurrentNewtOrdnanceCurveQueryResult {
      .refused(reason, cost())
    }
    let interval = scene.motion.opening.interval
    guard interval.valid, budget.distanceQueries > 0, budget.triangleTests > 0,
      budget.nodeVisits > 0, (0...20).contains(budget.subdivisionDepth),
      currentNewtNativeCommanderMatches(scene.motion.opening.before),
      bodies == scene.motion.opening.before.bodies,
      nativeStationRuntimeEpoch == scene.motion.opening.before.nativeStationRuntimeEpoch,
      let frame = scene.ordnanceFrame, frame.epoch == nativeStationRuntimeEpoch,
      let entry = frame.entries.first(where: { $0.actor == actor }),
      entry.epoch == nativeStationRuntimeEpoch,
      let body = bodies.first(where: { $0.id == entry.body.id && $0.physical?.identity == actor }),
      body.energy > 0, let state = body.physical?.ordnance,
      body.physical?.attackOrigin == state.origin,
      entry.matchesCurrentState(state, at: interval.start),
      let leg = entry.guidanceLeg(at: interval.start), interval.end <= leg.endTime,
      let context = gameplayContext(), context.physicalTime == interval.start,
      let source = scene.colliders.first(where: { $0.actor == actor && $0.component == "ordnance" }
      ),
      let sourcePose = source.poseAt(0), sourcePose.position == state.position,
      let clockWindow = NativeCurveClockWindow(start: interval.start, end: interval.end),
      let sourceTimeError = entry.clockSamplingTimeError(start: interval.start, end: interval.end)
    else { return refused(.invalidMotion) }
    let duration = interval.end - interval.start
    let sourceSamplingError =
      sourceTimeError == 0
      ? 0
      : (leg.velocity.length.nextUp * sourceTimeError).nextUp
    guard sourceSamplingError.isFinite else { return refused(.invalidMotion) }
    let cleared = preparedOrdnanceMuzzleCleared(state, context: context)
    let includePlayer = energy > 0 && (cleared || state.origin.owner != context.player.identity)
    var candidates: [CurrentNewtOrdnanceCurveContact] = []
    for target in scene.colliders {
      if target.actor == actor { continue }
      if target.actor == state.origin.owner && !cleared { continue }
      if target.actor == context.player.identity && !includePlayer { continue }
      guard let pose = target.poseAt(0),
        let targetSpeed = target.pointSpeedRelativeTo(target.referenceVelocity),
        let queryFrame = CurrentNewtQueryFrame(
          origin: sourcePose.position,
          velocity: target.referenceVelocity)
      else { return refused(.invalidMotion) }
      let pointSpeed = (leg.velocity - target.referenceVelocity).length.nextUp
      let targetSamplingError =
        target.clockSamplingTimeError == 0
        ? 0
        : (target.maximumPointSpeed * target.clockSamplingTimeError).nextUp
      let errorSum = sourceSamplingError + targetSamplingError
      let temporal = errorSum == 0 ? 0 : (2 * errorSum.nextUp).nextUp
      guard pointSpeed.isFinite, targetSpeed.isFinite, targetSpeed >= 0 else {
        return refused(.invalidMotion)
      }
      let separation =
        (sourcePose.position - pose.systemPoint(target.centre)).length - target.radius
      let numerical =
        128 * Double.ulpOfOne
        * max(
          1,
          sourcePose.position.length
            + pose.position.length + target.radius)
      let travel = ((pointSpeed + targetSpeed) * duration).nextUp
      guard separation.isFinite, numerical.isFinite, travel.isFinite,
        targetSamplingError.isFinite, temporal.isFinite
      else { return refused(.invalidMotion) }
      if separation > travel + numerical + temporal { continue }
      pairs += 1
      guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
        return refused(.workBudgetExceeded)
      }
      let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(
        target: target.hull,
        radius: 0, duration: duration, pointSpeed: pointSpeed, targetPointSpeed: targetSpeed,
        pointAt: { entry.state(at: interval.start + $0)?.position },
        targetAt: { target.poseAt($0) }, queryFrame: queryFrame,
        pointSamplingError: sourceSamplingError, targetSamplingError: targetSamplingError,
        clockWindow: clockWindow, budget: remaining)
      switch query {
      case .clear(let cost): charge(cost)
      case .refused(let cost):
        charge(cost)
        return refused(cost.failure ?? .unproven)
      case .contact(let contact, let cost):
        charge(cost)
        // Actor-free celestial boxes are conservative enclosures only. Their
        // contact must never be promoted to an actual sphere hit or damage.
        guard target.actor != nil, contact.matches(target.hull),
          contact.clockWindow?.start == interval.start, contact.clockWindow?.end == interval.end,
          let lower = contact.lowerPhysicalTime, let upper = contact.upperPhysicalTime,
          lower >= interval.start, upper >= lower, upper <= interval.end,
          (upper == interval.start && contact.upperTime == 0)
            || (upper > interval.start && upper - interval.start == contact.upperTime)
        else { return refused(.unproven) }
        candidates.append(
          .init(
            scene: scene, opening: entry, target: target, native: contact,
            lowerPhysicalTime: lower, upperPhysicalTime: upper))
      }
    }
    if candidates.isEmpty { return .clear(cost()) }
    guard
      let selected = CurrentNewtContactChronology.earliest(
        candidates.map {
          .init(
            lower: $0.lowerPhysicalTime - interval.start,
            upper: $0.upperPhysicalTime - interval.start)
        })
    else { return refused(.unproven) }
    return .contact(candidates[selected], cost())
  }
}

/// The actual scene owner seals both clear and contact query outcomes. A nil
/// contact cannot be supplied independently to bypass the native first-hit query.
final class CurrentNewtNativeOrdnanceLeg: Sendable {
  let scene: CurrentNewtNativeQueryScene
  let opening: GameplayOrdnanceOpening
  let contact: CurrentNewtOrdnanceCurveContact?
  let work: CurrentNewtOrdnanceQueryWork
  let attainedEnd: Double

  fileprivate init(
    scene: CurrentNewtNativeQueryScene, opening: GameplayOrdnanceOpening,
    contact: CurrentNewtOrdnanceCurveContact?, work: CurrentNewtOrdnanceQueryWork,
    attainedEnd: Double? = nil
  ) {
    self.scene = scene
    self.opening = opening
    self.contact = contact
    self.work = work
    self.attainedEnd =
      attainedEnd ?? contact?.upperPhysicalTime ?? scene.motion.opening.interval.end
  }
}

enum CurrentNewtNativeOrdnancePreparation: Sendable {
  case prepared(CurrentNewtNativeOrdnanceLeg)
  case refused(HullSweepFailure, CurrentNewtOrdnanceQueryWork)
}

extension Game {
  func prepareCurrentNewtNativeOrdnanceLeg(
    in scene: CurrentNewtNativeQueryScene,
    actor: ActorIdentity, budget: HullSweepBudget = .standard
  )
    -> CurrentNewtNativeOrdnancePreparation
  {
    let result = firstCurrentNewtOrdnanceContact(in: scene, actor: actor, budget: budget)
    switch result {
    case .clear(let work):
      guard let opening = scene.ordnanceFrame?.entries.first(where: { $0.actor == actor })
      else { return .refused(.invalidMotion, work) }
      return .prepared(.init(scene: scene, opening: opening, contact: nil, work: work))
    case .contact(let contact, let work):
      return .prepared(.init(scene: scene, opening: contact.opening, contact: contact, work: work))
    case .refused(let failure, let work): return .refused(failure, work)
    }
  }
}

extension Game {
  /// Derive only an already proved subrange. This does not query geometry or
  /// mint a new hit at the shortened endpoint.
  func prefixCurrentNewtNativeOrdnanceLeg(
    _ leg: CurrentNewtNativeOrdnanceLeg,
    through end: Double
  ) -> CurrentNewtNativeOrdnanceLeg? {
    let original = leg.scene.motion.opening
    guard currentNewtNativeCommanderMatches(original.before), bodies == original.before.bodies,
      end > original.interval.start, end <= leg.attainedEnd
    else { return nil }
    if end == leg.attainedEnd { return leg }
    if let contact = leg.contact {
      guard end < contact.lowerPhysicalTime else { return nil }
    }
    return .init(
      scene: leg.scene, opening: leg.opening, contact: nil, work: leg.work,
      attainedEnd: end)
  }
}
