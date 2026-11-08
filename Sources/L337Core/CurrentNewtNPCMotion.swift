import Foundation

/// One selected outer NPC decision. This is mathematical motion, not an actor,
/// weapon, arrival, transit or clinic control authority.
struct CurrentNewtNPCMotion: Sendable {
  let actor: ActorIdentity
  let bodyID: Int
  let missionActor: UUID?
  let missionInstance: UUID?
  let before: CurrentNewtKitReceipt.BodyState
  let originalNPC: ScriptNPCState?
  let decision: ScriptNPCFlightDecision?
  let legacy: LegacyNPCFlightDecision?
  let motion: HullSceneMotion
  let startTime: Double
  let modelPhase: Double
  let modelPhaseRate: Double

  func state(at time: Double) -> CurrentNewtKitReceipt.BodyState? {
    let endTime = startTime + motion.duration
    guard time.isFinite, time >= startTime, time <= endTime else { return nil }
    let elapsed = time == endTime ? motion.duration : time - startTime
    let pose =
      elapsed == motion.duration ? motion.end : HullSweepSafety.shipPose(motion, at: elapsed)
    return .init(
      pose: pose, velocity: motion.initialVelocity,
      angularVelocity: motion.worldAngularVelocity)
  }

  /// Measure the same path in the query's common translating frame.
  func pointSpeedBound(relativeTo reference: Vector3, localExtent: Double) -> Double? {
    CurrentNewtQueryFrame.pointSpeedBound(
      motion: motion, localExtent: localExtent,
      relativeTo: reference)
  }
}

final class CurrentNewtNPCFrame: Sendable {
  let path: CurrentNewtOuterMotion
  let opening: FlightSimulationState
  let epoch: UUID
  let entries: [ActorIdentity: CurrentNewtNPCMotion]
  let openingActors: Set<ActorIdentity>

  init(
    path: CurrentNewtOuterMotion, opening: FlightSimulationState, epoch: UUID,
    entries: [ActorIdentity: CurrentNewtNPCMotion], openingActors: Set<ActorIdentity>
  ) {
    self.path = path
    self.opening = opening
    self.epoch = epoch
    self.entries = entries
    self.openingActors = openingActors
  }

  func continuing(after resolution: CurrentNewtNativeContactResolution, at time: Double)
    -> CurrentNewtNPCFrame?
  {
    guard time >= path.startTime, time <= path.endTime else { return nil }
    guard time < path.endTime else { return self }
    let impacted = Set(resolution.impacts.flatMap { [$0.sourceActor, $0.targetActor] })
      .union(resolution.stoppedAt.keys)
    var retained = entries
    for actor in impacted {
      guard let entry = entries[actor] else { continue }
      guard let state = resolution.bodies[actor], state.structurallyValid else { return nil }
      let duration = path.endTime - time
      let seed = HullSceneMotion(
        start: state.pose, end: state.pose,
        initialVelocity: state.velocity, acceleration: .init(0, 0, 0),
        worldAngularVelocity: state.angularVelocity, duration: duration,
        playerRadius: entry.motion.playerRadius)
      let end = HullSweepSafety.shipPose(seed, at: duration)
      let coast = HullSceneMotion(
        start: state.pose, end: end,
        initialVelocity: state.velocity, acceleration: .init(0, 0, 0),
        worldAngularVelocity: state.angularVelocity, duration: duration,
        playerRadius: entry.motion.playerRadius)
      retained[actor] = .init(
        actor: actor, bodyID: entry.bodyID,
        missionActor: entry.missionActor, missionInstance: entry.missionInstance,
        before: state, originalNPC: entry.originalNPC, decision: entry.decision,
        legacy: entry.legacy,
        motion: coast, startTime: time,
        modelPhase: entry.modelPhase + (time - entry.startTime) * entry.modelPhaseRate,
        modelPhaseRate: entry.modelPhaseRate)
    }
    return .init(
      path: path, opening: opening, epoch: epoch, entries: retained,
      openingActors: openingActors)
  }
}
