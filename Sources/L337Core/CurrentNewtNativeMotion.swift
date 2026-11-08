import Foundation

/// Failure-only context from the original preparation guard. This carries no scene,
/// source authority, Game or Commander and never changes a preparation decision.
struct CurrentNewtPreparationRefusal: Sendable {
  enum Phase: String, Sendable {
    case npcFrame, queryScene, sceneAssembly, collider, colliderAppend
  }
  let phase: Phase
  let checkpoint: Int
  let bodyID: Int?
  let component: String?

  var summary: String {
    "\(phase.rawValue) guard\(checkpoint) body=\(bodyID.map(String.init) ?? "none") component=\(component ?? "none")"
  }
}

/// An actual start snapshot and one subrange of the outer admitted trajectory.
/// It is neither saved nor constructed by collision callers.
final class CurrentNewtNativeSegmentOpening: Sendable {
  let interval: CurrentNewtMechanicalInterval
  let before: Game
  let playerMotion: HullSceneMotion
  let playerEnd: CurrentNewtKitReceipt.BodyState
  let workEnergyRate: Double
  let npcFrame: CurrentNewtNPCFrame?

  fileprivate init(
    interval: CurrentNewtMechanicalInterval, before: Game,
    playerMotion: HullSceneMotion, playerEnd: CurrentNewtKitReceipt.BodyState,
    workEnergyRate: Double, npcFrame: CurrentNewtNPCFrame?
  ) {
    self.interval = interval
    self.before = before
    self.playerMotion = playerMotion
    self.playerEnd = playerEnd
    self.workEnergyRate = workEnergyRate
    self.npcFrame = npcFrame
  }
}

/// Predicted whole-scene motion supplied to the native contact owner.
/// Source mechanical proposals remain proposals until the retained endpoint is applied.
struct CurrentNewtNativeSegmentPlan: Sendable {
  let opening: CurrentNewtNativeSegmentOpening
  let proposed: Game
  let mechanical: [CurrentNewtMechanicalProposal]
  let mechanics: CurrentNewtMechanicalPlan
  let coasts: [ActorIdentity: CurrentNewtNativeCoastCurve]
  fileprivate init(
    opening: CurrentNewtNativeSegmentOpening, proposed: Game,
    mechanical: [CurrentNewtMechanicalProposal], mechanics: CurrentNewtMechanicalPlan,
    coasts: [ActorIdentity: CurrentNewtNativeCoastCurve]
  ) {
    self.opening = opening
    self.proposed = proposed
    self.mechanical = mechanical
    self.mechanics = mechanics
    self.coasts = coasts
  }

  func mechanicalResult(_ resolution: CurrentNewtNativeContactResolution)
    -> CurrentNewtMechanicalContactResult
  {
    let stopped = resolution.stoppedAt.filter { actor, _ in
      mechanics.owners.contains { $0.parent == actor }
        || mechanics.drives.contains { $0.podActor == actor }
    }
    return .init(admitted: resolution.admitted, stoppedAt: stopped, drives: resolution.drives)
  }
}

/// Contact retains actual endpoints for affected actors and the player. Other
/// actors consume their one prepared kinematic subrange.
struct CurrentNewtNativeContactResolution: Sendable {
  let player: CurrentNewtKitReceipt.BodyState
  let bodies: [ActorIdentity: CurrentNewtKitReceipt.BodyState]
  let stoppedAt: [ActorIdentity: Double]
  let admitted: Bool
  let drives: [CurrentNewtDriveOutcome]
  let impacts: [CurrentNewtNativeImpactApplication]

  init(
    player: CurrentNewtKitReceipt.BodyState,
    bodies: [ActorIdentity: CurrentNewtKitReceipt.BodyState], stoppedAt: [ActorIdentity: Double],
    admitted: Bool, drives: [CurrentNewtDriveOutcome],
    impacts: [CurrentNewtNativeImpactApplication] = []
  ) {
    self.player = player
    self.bodies = bodies
    self.stoppedAt = stoppedAt
    self.admitted = admitted
    self.drives = drives
    self.impacts = impacts
  }
}

/// Native contact and selected physical response, prepared without publication.
/// The contact itself can only come from the native geometry producer.
struct CurrentNewtNativeImpactApplication: Sendable {
  let contact: NativeHullContact
  let impulse: AsteroidImpulse
  let sourceID: Int
  let sourceActor: ActorIdentity
  let targetID: Int?
  let targetActor: ActorIdentity
  let playerPose: ShipPose
  let sourcePose: ShipPose
  let targetPose: ShipPose
  let contactPhysicalTime: Double
}

extension Game {
  func beginCurrentNewtNativeSegment(
    _ interval: CurrentNewtMechanicalInterval, playerMotion: HullSceneMotion,
    playerEnd: CurrentNewtKitReceipt.BodyState, workEnergyRate: Double = 0,
    npcFrame: CurrentNewtNPCFrame? = nil
  ) -> CurrentNewtNativeSegmentOpening? {
    guard interval.valid, storedFlightSimulation().physicalTime == interval.start,
      playerMotion.duration == interval.end - interval.start,
      playerMotion.start == storedFlightSimulation().pose,
      playerEnd.pose == playerMotion.end,
      playerEnd.structurallyValid, workEnergyRate.isFinite, (0...2).contains(workEnergyRate)
    else { return nil }
    if let npcFrame {
      guard npcFrame.epoch == nativeStationRuntimeEpoch,
        npcFrame.opening.system == storedFlightSimulation().system,
        npcFrame.opening.visit == storedFlightSimulation().visit,
        interval.start >= npcFrame.path.startTime, interval.end <= npcFrame.path.endTime
      else { return nil }
    }
    return .init(
      interval: interval, before: self, playerMotion: playerMotion, playerEnd: playerEnd,
      workEnergyRate: workEnergyRate, npcFrame: npcFrame)
  }

  func prepareCurrentNewtNativeSegment(
    _ opening: CurrentNewtNativeSegmentOpening, mechanics: CurrentNewtMechanicalPlan,
    mechanical: [CurrentNewtMechanicalProposal],
    coasts: [ActorIdentity: CurrentNewtNativeCoastCurve] = [:]
  ) -> CurrentNewtNativeSegmentPlan? {
    let interval = opening.interval
    guard storedFlightSimulation().physicalTime == interval.start,
      mechanics.interval.start == interval.start, mechanics.interval.end == interval.end,
      currentNewtNativeCommanderMatches(opening.before), bodies == opening.before.bodies,
      nativeStationRuntimeEpoch == opening.before.nativeStationRuntimeEpoch,
      Set(mechanical.map(\.actor)).count == mechanical.count,
      coasts.allSatisfy({ actor, coast in
        !mechanical.contains { $0.actor == actor }
          && coast.interval.start == interval.start && coast.interval.end == interval.end
          && bodies.first(where: { $0.physical?.identity == actor }).map {
            currentNewtBodyState($0) == coast.before
          } == true
          && coast.state(at: interval.end) != nil
      })
    else { return nil }
    var proposed = self
    proposed.commander.flightSimulation.advancePhysicalTime(interval.end - interval.start)
    proposed.applyCurrentNewtNativeKinematics(
      end: opening.playerEnd.pose, delta: interval.end - interval.start, mechanical: mechanical,
      coasts: coasts)
    proposed.applyCurrentNewtNPCPaths(opening.npcFrame, at: interval.end)
    return .init(
      opening: opening, proposed: proposed, mechanical: mechanical, mechanics: mechanics,
      coasts: coasts)
  }

  /// Only this owner applies the selected whole-scene result. The contact owner
  /// supplies retained world endpoints, without observing future stock or clocks.
  mutating func retainCurrentNewtNativeSegment(
    _ plan: CurrentNewtNativeSegmentPlan, resolution: CurrentNewtNativeContactResolution,
    clockEffects: inout [NativeDebrisImpactClockEffect]
  ) -> CurrentNewtMechanicalContactResult {
    let result = plan.mechanicalResult(resolution)
    guard validateCurrentNewtMechanicalResult(result, for: plan.mechanics),
      currentNewtNativeCommanderMatches(
        plan.opening.before,
        advancingClockBy: plan.opening.interval.end - plan.opening.interval.start),
      bodies == plan.opening.before.bodies,
      nativeStationRuntimeEpoch == plan.opening.before.nativeStationRuntimeEpoch,
      resolution.player.structurallyValid,
      resolution.bodies.values.allSatisfy(\.structurallyValid),
      plan.mechanical.allSatisfy({ resolution.bodies[$0.actor] != nil }),
      resolution.stoppedAt.values.allSatisfy({
        $0.isFinite && $0 >= plan.opening.interval.start && $0 <= plan.opening.interval.end
      }),
      resolution.bodies.keys.allSatisfy({ actor in
        bodies.contains { $0.physical?.identity == actor }
      }),
      resolution.impacts.count <= AsteroidImpactPolicy.maximumCandidatePairs
    else { return .init(admitted: false, stoppedAt: [:], drives: []) }
    var retained = plan.proposed
    let thrustEnd =
      retained.commander.flightSimulation.player.flatMap { resolution.stoppedAt[$0] }
      ?? plan.opening.interval.end
    let thrustCost = (thrustEnd - plan.opening.interval.start) * plan.opening.workEnergyRate
    guard thrustCost.isFinite, thrustCost >= 0,
      thrustCost == 0 || (retained.energy.isFinite && retained.energy > thrustCost)
    else { return .init(admitted: false, stoppedAt: [:], drives: []) }
    retained.energy -= thrustCost
    var effects: [NativeDebrisImpactClockEffect] = []
    var lastImpact = plan.opening.interval.start
    for impact in resolution.impacts {
      guard impact.contactPhysicalTime >= lastImpact,
        impact.contactPhysicalTime <= plan.opening.interval.end,
        resolution.bodies[impact.sourceActor] != nil,
        impact.targetID == nil || resolution.bodies[impact.targetActor] != nil,
        let receipt = retained.applyNativeDebrisContactEffect(
          contact: impact.contact, impulse: impact.impulse,
          sourceID: impact.sourceID, sourceActor: impact.sourceActor,
          targetID: impact.targetID, targetActor: impact.targetActor,
          playerPose: impact.playerPose, sourcePose: impact.sourcePose,
          targetPose: impact.targetPose,
          contactPhysicalTime: impact.contactPhysicalTime, captureClockEffect: true),
        let effect = receipt.clockEffect
      else { return .init(admitted: false, stoppedAt: [:], drives: []) }
      effects.append(effect)
      lastImpact = impact.contactPhysicalTime
    }
    retained.rebaseCurrentNewtNativeCamera(to: resolution.player.pose)
    for index in retained.bodies.indices {
      guard let actor = retained.bodies[index].physical?.identity,
        let state = resolution.bodies[actor]
      else { continue }
      retained.bodies[index].position = resolution.player.pose.shipPoint(state.pose.position)
      retained.retainCurrentNewtModelPose(state.pose, at: index, camera: resolution.player.pose)
      retained.bodies[index].physical?.velocity = state.velocity
      retained.bodies[index].physical?.angularVelocity = state.angularVelocity
    }
    if let player = retained.commander.flightSimulation.player,
      resolution.stoppedAt[player] != nil
    {
      retained.retainNativePlayerCollisionControls(
        outgoingVelocity: resolution.player.velocity,
        pose: resolution.player.pose)
    } else if retained.workGuidance != nil || retained.workBraking != nil {
      retained.workGuidance?.velocity = resolution.player.velocity
      retained.workGuidance?.angularVelocity = resolution.player.angularVelocity
      retained.workBraking?.velocity = resolution.player.velocity
      retained.workBraking?.angularVelocity = resolution.player.angularVelocity
    } else {
      let local = resolution.player.pose.shipVector(resolution.player.velocity)
      retained.autoPilot.setApproachVelocity(local - Vector3(0, 0, retained.speed * 18))
    }
    self = retained
    clockEffects = effects
    return result
  }

  private mutating func applyCurrentNewtNativeKinematics(
    end: ShipPose, delta: Double, mechanical: [CurrentNewtMechanicalProposal],
    coasts: [ActorIdentity: CurrentNewtNativeCoastCurve]
  ) {
    rebaseCurrentNewtNativeCamera(to: end)
    for index in bodies.indices {
      if let actor = bodies[index].physical?.identity, let coast = coasts[actor],
        let state = coast.state(at: commander.flightSimulation.physicalTime)
      {
        bodies[index].position = end.shipPoint(state.pose.position)
        bodies[index].orientation = state.pose.orientation.relative(to: end.orientation)
        bodies[index].rotation = 0
        bodies[index].physical?.velocity = state.velocity
        bodies[index].physical?.angularVelocity = state.angularVelocity
        continue
      }
      if let actor = bodies[index].physical?.identity,
        let proposal = mechanical.first(where: { $0.actor == actor })
      {
        bodies[index].position = end.shipPoint(proposal.after.pose.position)
        bodies[index].orientation = proposal.after.pose.orientation.relative(to: end.orientation)
        bodies[index].rotation = 0
        bodies[index].physical?.velocity = proposal.after.velocity
        bodies[index].physical?.angularVelocity = proposal.after.angularVelocity
        continue
      }
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
  }

  private mutating func rebaseCurrentNewtNativeCamera(to end: ShipPose) {
    let start = commander.flightSimulation.pose
    commander.flightSimulation.pose = end
    rotateScriptNPCVelocities(from: start, to: end)
    let change = start.orientation.workFrameRelative(to: end.orientation)
    for index in bodies.indices {
      bodies[index].position = end.shipPoint(start.systemPoint(bodies[index].position))
      bodies[index].orientation = change.composed(with: bodies[index].orientation)
    }
    for index in celestials.indices {
      celestials[index].position = end.shipPoint(start.systemPoint(celestials[index].position))
    }
  }

  private mutating func applyCurrentNewtNPCPaths(_ frame: CurrentNewtNPCFrame?, at time: Double) {
    guard let frame else { return }
    let camera = commander.flightSimulation.pose
    for index in bodies.indices {
      guard let actor = bodies[index].physical?.identity, let entry = frame.entries[actor],
        let state = entry.state(at: time)
      else { continue }
      bodies[index].position = camera.shipPoint(state.pose.position)
      bodies[index].rotation = entry.modelPhase + (time - entry.startTime) * entry.modelPhaseRate
      retainCurrentNewtModelPose(state.pose, at: index, camera: camera)
      bodies[index].physical?.velocity = state.velocity
      bodies[index].scriptNPC?.velocity = camera.shipVector(state.velocity)
      // The controlled rotation is not a persistent free-spin command.
    }
  }

  /// Preserve the existing display phase while retaining the exact physical
  /// model pose, as the original debris motion owner does.
  private mutating func retainCurrentNewtModelPose(
    _ pose: ShipPose, at index: Int, camera: ShipPose
  ) {
    let relative = pose.orientation.relative(to: camera.orientation)
    let rotation = bodies[index].rotation
    var spin = Basis3()
    spin.rotate(
      pitch: bodies[index].hull == .station ? 0 : rotation * 0.4,
      roll: rotation, yaw: 0)
    bodies[index].orientation.x = relative.apply(spin.inverse(.init(1, 0, 0)))
    bodies[index].orientation.y = relative.apply(spin.inverse(.init(0, 1, 0)))
    bodies[index].orientation.z = relative.apply(spin.inverse(.init(0, 0, 1)))
  }

  /// The original per-body camera/model/inertial phase, without AI, effects or
  /// a Game clock mutation. Callers supply only this actual selected outer path.
  func currentNewtPostCameraBodies(_ path: CurrentNewtOuterMotion) -> [SpaceBody] {
    let start = path.motion.start
    let end = path.motion.end
    let change = start.orientation.workFrameRelative(to: end.orientation)
    return bodies.map { original in
      var body = original
      body.position = end.shipPoint(start.systemPoint(original.position))
      body.orientation = change.composed(with: original.orientation)
      if let velocity = original.scriptNPC?.velocity {
        body.scriptNPC?.velocity = end.shipVector(start.orientation.apply(velocity))
      }
      if let identity = original.nativeStationIdentity,
        let source = NativeStationSource.binding(for: identity),
        let time = commander.nativeStations?.motionTime(
          for: .originalStation(identity), at: path.endTime)
      {
        body.rotation = (time * source.rotationRate).truncatingRemainder(dividingBy: 2 * .pi)
      } else if original.nativeStationIdentity == nil {
        body.rotation += path.motion.duration * body.rotationRate
      }
      if let physical = original.physical {
        if physical.canonicalSpin == true, physical.angularVelocity.finite,
          physical.angularVelocity.length.isFinite
        {
          let world = original.orientation.transformed(by: start.orientation)
          body.orientation = RelativeWorkController.rotated(
            world, omega: physical.angularVelocity, delta: path.motion.duration
          )
          .workFrameRelative(to: end.orientation)
        }
        if physical.spawnIdentity != nil, physical.ordnance == nil, original.scriptShot == nil,
          original.scriptNPC == nil || c01SurveyorActor(original) != nil
            || c01TimingStandardPart(original) != nil || c01LaneRepairTarget(original) != nil
            || c01ClinicCradleDeclared(original)
        {
          body.position = body.position + end.shipVector(physical.velocity) * path.motion.duration
        }
      }
      return body
    }
  }

  func prepareCurrentNewtNPCFrame(
    _ path: CurrentNewtOuterMotion,
    report: ((CurrentNewtPreparationRefusal) -> Void)? = nil
  ) -> CurrentNewtNPCFrame? {
    var refusalBodyID: Int? = nil
    guard commander.flightSimulation.physicalTime == path.startTime,
      commander.flightSimulation.pose == path.motion.start,
      nativeStationRuntimeEpoch == path.epoch
    else {
      report?(.init(phase: .npcFrame, checkpoint: 1, bodyID: refusalBodyID, component: nil))
      return nil
    }
    // Project plain geometry only; source eligibility stays at this opening.
    let start = path.motion.start
    let end = path.motion.end
    let projectedBodies = currentNewtPostCameraBodies(path)
    let owned = Dictionary(
      projectedBodies.compactMap { body in body.missionActorID.map { ($0, body) } },
      uniquingKeysWith: { first, _ in first })
    let station = projectedBodies.first { $0.id == 0 && $0.hull == .station }
    var entries: [ActorIdentity: CurrentNewtNPCMotion] = [:]
    for body in bodies where body.energy > 0 {
      refusalBodyID = body.id
      guard let npc = body.scriptNPC else { continue }
      if c01SurveyorActor(body) != nil || c01TimingStandardPart(body) != nil
        || c01LaneRepairTarget(body) != nil || c01ClinicCradleDeclared(body)
      {
        continue
      }
      // Special native controllers still require their actual once-only proof
      // and resolver join. Do not turn an unjoined proposal into motion.
      guard let physical = body.physical,
        let projected = projectedBodies.first(where: { $0.physical?.identity == physical.identity }
        ),
        c01ClinicCourse(body, profile: npc.fit.definition, delta: path.motion.duration) == nil,
        inductionArkDockGuidance(body, profile: npc.fit.definition, delta: path.motion.duration)
          == nil,
        inductionRescueDockGuidance(body, profile: npc.fit.definition, delta: path.motion.duration)
          == nil,
        nativeTransitSteeringGoal(body) == nil, nativeTransitExitClearanceGoal(body) == nil,
        commander.scriptState.wormholeTransit?.legs.values.contains(where: {
          $0.actor == body.missionActorID
        }) != true, let projectedNPC = projected.scriptNPC
      else {
        report?(.init(phase: .npcFrame, checkpoint: 2, bodyID: refusalBodyID, component: nil))
        return nil
      }
      let decision = scriptNPCFlightDecision(
        projected, npc: projectedNPC, owned: owned, station: station,
        guidance: nil, delta: path.motion.duration, allowNativeTransit: false)
      let before = currentNewtBodyState(body)
      var endpointBody = projected
      endpointBody.position = decision.translation.end
      endpointBody.orientation = decision.orientation
      let end = Self.modelPose(of: endpointBody, player: path.motion.end)
      let mesh = scriptNPCMesh(body) ?? gameplayMesh(for: body)
      guard let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0,
        let motion = debrisRigidMotion(
          from: before.pose, to: end,
          duration: path.motion.duration, radius: radius), entries[physical.identity] == nil
      else {
        report?(.init(phase: .npcFrame, checkpoint: 3, bodyID: refusalBodyID, component: nil))
        return nil
      }
      entries[physical.identity] = .init(
        actor: physical.identity, bodyID: body.id,
        missionActor: body.missionActorID, missionInstance: body.missionInstanceID,
        before: before, originalNPC: npc, decision: decision, legacy: nil, motion: motion,
        startTime: path.startTime, modelPhase: body.rotation, modelPhaseRate: body.rotationRate)
    }
    for body in bodies
    where body.energy > 0 && body.hostile && body.scriptNPC == nil
      && body.missionInstanceID == nil && body.physical?.spawnIdentity == nil
    {
      refusalBodyID = body.id
      guard let physical = body.physical,
        let projected = projectedBodies.first(where: { $0.physical?.identity == physical.identity })
      else {
        report?(.init(phase: .npcFrame, checkpoint: 4, bodyID: refusalBodyID, component: nil))
        return nil
      }
      // Work planning selects legacy pursuit before changing the camera. The
      // ordinary manual pass selects it after that change. Keep that distinction.
      let selectedBody = path.workMode ? body : projected
      let selectedFrame = path.workMode ? start : end
      guard
        let decision = prepareLegacyNPCFlightDecision(
          selectedBody, frame: selectedFrame, delta: path.motion.duration)
      else { continue }  // An actual ineligible intent has no legacy movement/effects.
      guard entries[physical.identity] == nil else {
        report?(.init(phase: .npcFrame, checkpoint: 5, bodyID: refusalBodyID, component: nil))
        return nil
      }
      let before = currentNewtBodyState(body)
      let projectedPose = Self.modelPose(of: projected, player: end)
      let finish = ShipPose(position: decision.worldEnd, orientation: projectedPose.orientation)
      let mesh = gameplayMesh(for: body)
      guard let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0,
        let motion = debrisRigidMotion(
          from: before.pose, to: finish,
          duration: path.motion.duration, radius: radius)
      else {
        report?(.init(phase: .npcFrame, checkpoint: 6, bodyID: refusalBodyID, component: nil))
        return nil
      }
      entries[physical.identity] = .init(
        actor: physical.identity, bodyID: body.id, missionActor: body.missionActorID,
        missionInstance: body.missionInstanceID, before: before, originalNPC: nil,
        decision: nil, legacy: decision, motion: motion, startTime: path.startTime,
        modelPhase: body.rotation, modelPhaseRate: body.rotationRate)
    }
    return .init(
      path: path, opening: commander.flightSimulation,
      epoch: nativeStationRuntimeEpoch, entries: entries,
      openingActors: Set(bodies.compactMap { $0.physical?.identity }))
  }
}
