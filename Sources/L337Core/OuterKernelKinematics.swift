import Foundation

/// Kinematic values only: no actor admission, native impact proof or saved authority.
struct OuterNPCTranslation: Sendable {
  let start: Vector3
  let velocity: Vector3
  let duration: Double
  var end: Vector3 { start + velocity * duration }

  init(position: Vector3, velocity: Vector3, desired: Vector3,
    acceleration: Double, delta: Double)
  {
    start = position
    self.velocity = velocity + (desired - velocity).limited(to: acceleration * delta)
    duration = delta
  }

  /// Sample the one prepared semi-implicit outer step; never accelerate again per cut.
  func position(at elapsed: Double) -> Vector3? {
    guard elapsed.isFinite, elapsed >= 0, elapsed <= duration else { return nil }
    return start + velocity * elapsed
  }

  static func steer(_ basis: Basis3, toward vector: Vector3,
    profile: ScriptNPCDefinition, delta: Double) -> Basis3
  {
    let local = basis.inverse(vector)
    let pitch = max(
      -profile.pitch * delta,
      min(
        profile.pitch * delta,
        -atan2(local.y, hypot(local.x, local.z))))
    let yaw = max(-profile.yaw * delta, min(profile.yaw * delta, -atan2(local.x, local.z)))
    var step = Basis3()
    step.rotate(pitch: pitch, roll: 0, yaw: yaw)
    return step.transformed(by: basis)
  }
}

/// The actual producer supplies its current position/velocity/age and emission clock.
/// This arithmetic result is not permission to collide, age or remove a live projectile.
struct OuterScriptProjectileTranslation: Sendable {
  let start: Vector3
  let velocity: Vector3
  let initialAge: Double
  let duration: Double
  let inactive: Double
  var end: Vector3 { start + velocity * duration }
  var age: Double { initialAge + duration }
  var collisionStart: Vector3? {
    duration > inactive ? start + velocity * inactive : nil
  }
  var collisionRange: Double? {
    duration > inactive ? velocity.length * (duration - inactive) : nil
  }

  init(position: Vector3, velocity: Vector3, age: Double, lifetime: Double,
    collisionDelay: Double, delta: Double)
  {
    start = position
    self.velocity = velocity
    initialAge = age
    duration = min(delta, max(0, lifetime - age))
    inactive = max(0, collisionDelay - age)
  }

  func position(at elapsed: Double) -> Vector3? {
    guard elapsed.isFinite, elapsed >= 0, elapsed <= duration else { return nil }
    return start + velocity * elapsed
  }

  /// Pure window arithmetic only. Native callers must read emittedAt from their actual
  /// current archive; a new T1 birth cannot receive the preceding outer-frame delta.
  static func availableDelta(start: Double, end: Double, emittedAt: Double) -> Double? {
    guard start.isFinite, end.isFinite, emittedAt.isFinite, start >= 0,
      end >= start, emittedAt >= 0, emittedAt <= end
    else { return nil }
    return end - max(start, emittedAt)
  }
}

/// Copied-state ordnance motion only. Guidance is prepared once from one selected snapshot.
/// Native contact, ECM, damage, law, projection, death and removal remain separate owners.
struct OuterOrdnanceTrajectory: Sendable {
  struct Leg: Sendable {
    let startTime: Double
    let endTime: Double
    let start: Vector3
    let end: Vector3
    let velocity: Vector3
  }
  let before: OrdnanceState
  let proposed: OrdnanceState
  let endTime: Double
  let legs: [Leg]

  func position(at time: Double) -> Vector3? {
    guard time.isFinite, time >= before.lastUpdatedAt, time <= endTime else { return nil }
    if time == before.lastUpdatedAt { return before.position }
    for leg in legs where time >= leg.startTime && time <= leg.endTime {
      return time == leg.endTime ? leg.end : leg.start + leg.velocity * (time - leg.startTime)
    }
    return nil
  }
}
