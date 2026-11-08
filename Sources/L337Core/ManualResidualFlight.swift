import Foundation

/// One pure owner for the unchanged ordinary and residual manual throttle laws.
/// Callers retain their existing mode, electrical, guidance and delta admission checks.
enum ManualFlightThrottleKernel {
  static func outwardComponentsAgree(normal: Vector3, direction: Vector3) -> Bool {
    let x = (normal.x >= 0 && direction.x >= 0) || (normal.x <= 0 && direction.x <= 0)
    let y = (normal.y >= 0 && direction.y >= 0) || (normal.y <= 0 && direction.y <= 0)
    let z = (normal.z >= 0 && direction.z >= 0) || (normal.z <= 0 && direction.z <= 0)
    let advances =
      (normal.x > 0 && direction.x > 0) || (normal.x < 0 && direction.x < 0)
      || (normal.y > 0 && direction.y > 0) || (normal.y < 0 && direction.y < 0)
      || (normal.z > 0 && direction.z > 0) || (normal.z < 0 && direction.z < 0)
    return x && y && z && advances
  }

  static func cruise(
    speed: Double, throttle: Double, delta: Double, acceleration: Double, maximum: Double
  ) -> Double {
    min(maximum, max(0, speed + throttle * delta * acceleration))
  }

  static func residual(
    velocity: Vector3, magnitude: Double, acceleration: Double, maximum: Double,
    throttle: Double, delta: Double
  ) -> Vector3? {
    guard velocity.finite, magnitude.isFinite,
      acceleration.isFinite, acceleration > 0, maximum.isFinite, maximum > 0
    else { return nil }
    let amount = acceleration * min(1, abs(throttle)) * delta
    var next = velocity
    if throttle < 0 {
      next = amount >= magnitude ? .init(0, 0, 0) : velocity * ((magnitude - amount) / magnitude)
    } else if throttle > 0 {
      let requested = velocity + Vector3(0, 0, amount)
      let capped = requested.limited(to: maximum)
      // External overspeed cannot justify a speed projection beyond the thrust budget.
      if (capped - velocity).length <= amount + 1e-9 { next = capped }
    }
    return next
  }
}

extension Game {
  /// Released work momentum stays entirely in the camera-relative residual so steering
  /// cannot rotate a forward-speed component without applying thrust.
  mutating func applyManualResidualThrottle(delta: Double, throttle: Double) {
    guard !playerEMPDisabled, manualResidualFlight, workGuidance == nil, workBraking == nil,
      autoPilot.targetID == nil, !dockingComputer, !docked,
      delta.isFinite, delta > 0, delta <= 0.1, throttle.isFinite
    else { return }
    let velocity = autoPilot.velocity + Vector3(0, 0, speed * 18)
    let magnitude = velocity.length
    let acceleration = commander.performance.acceleration * 18
    let maximum = commander.performance.speed * 18
    guard let next = ManualFlightThrottleKernel.residual(
      velocity: velocity, magnitude: magnitude, acceleration: acceleration, maximum: maximum,
      throttle: throttle, delta: delta)
    else { return }
    speed = 0
    autoPilot.setApproachVelocity(next)
    if next == .init(0, 0, 0) { manualResidualFlight = false }
  }

  /// Successful scene boundaries own their new cruise state; failed transitions never call this.
  mutating func clearManualResidualFlight() {
    manualResidualFlight = false
    autoPilot.setApproachVelocity(.init(0, 0, 0))
  }

  var cockpitSpeed: Double {
    if manualResidualFlight || workGuidance != nil || workBraking != nil {
      return flightWorldVelocity.length / 18
    }
    return autoTargetBody?.hull == .station ? autoPilot.velocity.length / 18 : speed
  }
}
