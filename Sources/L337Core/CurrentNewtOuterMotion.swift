import Foundation

/// One native outer trajectory. Subranges sample this same path and never ask
/// the work controller for another approval.
final class CurrentNewtOuterMotion: Sendable {
  let startTime: Double
  let endTime: Double
  let epoch: UUID
  let motion: HullSceneMotion
  let approval: HullSceneMotion?
  let workMode: Bool
  private let origin: CurrentNewtOuterMotion?
  var rootMotion: CurrentNewtOuterMotion { origin ?? self }

  fileprivate init(
    startTime: Double, endTime: Double, epoch: UUID,
    motion: HullSceneMotion, approval: HullSceneMotion?, workMode: Bool,
    origin: CurrentNewtOuterMotion? = nil
  ) {
    self.startTime = startTime
    self.endTime = endTime
    self.epoch = epoch
    self.motion = motion
    self.approval = approval
    self.workMode = workMode
    self.origin = origin
  }

  func state(at time: Double) -> CurrentNewtKitReceipt.BodyState? {
    guard time.isFinite, time >= startTime, time <= endTime else { return nil }
    let elapsed = time == endTime ? motion.duration : time - startTime
    let pose = time == endTime ? motion.end : HullSweepSafety.shipPose(motion, at: elapsed)
    return .init(
      pose: pose, velocity: motion.initialVelocity + motion.acceleration * elapsed,
      angularVelocity: motion.worldAngularVelocity)
  }

  func subrange(_ interval: CurrentNewtMechanicalInterval) -> HullSceneMotion? {
    guard interval.valid, let start = state(at: interval.start), let end = state(at: interval.end)
    else { return nil }
    return .init(
      start: start.pose, end: end.pose, initialVelocity: start.velocity,
      acceleration: motion.acceleration, worldAngularVelocity: motion.worldAngularVelocity,
      duration: interval.end - interval.start, playerRadius: motion.playerRadius,
      requiredClearance: motion.requiredClearance)
  }

  /// A genuine contact can interrupt thrust. The remainder retains its actual
  /// inertia and cannot acquire another powered approval in the same outer frame.
  func coasting(
    from state: CurrentNewtKitReceipt.BodyState, at time: Double
  ) -> CurrentNewtOuterMotion? {
    guard state.structurallyValid, time >= startTime, time < endTime else { return nil }
    let duration = endTime - time
    let seed = HullSceneMotion(
      start: state.pose, end: state.pose,
      initialVelocity: state.velocity, acceleration: .init(0, 0, 0),
      worldAngularVelocity: state.angularVelocity, duration: duration,
      playerRadius: motion.playerRadius, requiredClearance: motion.requiredClearance)
    let end = HullSweepSafety.shipPose(seed, at: duration)
    let coast = HullSceneMotion(
      start: state.pose, end: end, initialVelocity: state.velocity,
      acceleration: .init(0, 0, 0), worldAngularVelocity: state.angularVelocity,
      duration: duration, playerRadius: motion.playerRadius,
      requiredClearance: motion.requiredClearance)
    return .init(
      startTime: time, endTime: endTime, epoch: epoch,
      motion: coast, approval: nil, workMode: workMode, origin: rootMotion)
  }
}

extension Game {
  mutating func prepareCurrentNewtOuterMotion(delta: Double) -> CurrentNewtOuterMotion? {
    let startTime = commander.flightSimulation.physicalTime
    let start = commander.flightSimulation.pose
    guard delta.isFinite, delta > 0, delta <= 0.1,
      let radius = commander.playerMesh.vertices.map(\.length).max(), radius.isFinite, radius > 0
    else { return nil }
    let workMode = workGuidance != nil || workBraking != nil
    if workMode {
      let approved = approvedWorkMotion.flatMap {
        $0.start == start && $0.duration == delta ? $0 : nil
      }
      let path: HullSceneMotion
      if let approved {
        path = approved
      } else {
        let velocity = flightWorldVelocity
        path = .init(
          start: start,
          end: .init(position: start.position + velocity * delta, orientation: start.orientation),
          initialVelocity: velocity, acceleration: .init(0, 0, 0),
          worldAngularVelocity: .init(0, 0, 0), duration: delta, playerRadius: radius)
      }
      return .init(
        startTime: startTime, endTime: startTime + delta,
        epoch: nativeStationRuntimeEpoch, motion: path, approval: approved, workMode: true)
    }
    autoPilot.rotateVelocity(pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    var end = start
    end.advanceView(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta,
      translation: autoPilot.velocity * delta + Vector3(0, 0, speed * delta * 18))
    guard let path = debrisRigidMotion(from: start, to: end, duration: delta, radius: radius)
    else { return nil }
    return .init(
      startTime: startTime, endTime: startTime + delta,
      epoch: nativeStationRuntimeEpoch, motion: path, approval: nil, workMode: false)
  }

  mutating func finishCurrentNewtOuterMotion(_ original: CurrentNewtOuterMotion, attained: Bool) {
    approvedWorkMotion = nil
    lastAppliedWorkMotion = attained ? original.approval : nil
    guard original.workMode else { return }
    // A retained collision has already cancelled powered work and installed
    // actual outgoing inertia. Finishing the old approval cannot erase it.
    if manualResidualFlight && workGuidance == nil && workBraking == nil { return }
    if attained, let state = original.state(at: original.endTime) {
      workGuidance?.velocity = state.velocity
      workGuidance?.angularVelocity = state.angularVelocity
      workBraking?.velocity = state.velocity
      workBraking?.angularVelocity = state.angularVelocity
    }
    autoPilot.setApproachVelocity(.init(0, 0, 0))
    speed = 0
    if workGuidance == nil, (workBraking?.velocity.length ?? 0) < 1e-9 { workBraking = nil }
  }
}
