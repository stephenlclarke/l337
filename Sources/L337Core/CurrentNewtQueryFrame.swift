import Foundation

/// Pure query coordinates. Neither poses in the simulation nor velocity/stock
/// ownership change. Both curves MUST use this same origin, velocity and epoch.
struct CurrentNewtQueryFrame: Sendable {
  let origin: Vector3
  let velocity: Vector3
  let timeOrigin: Double

  init?(origin: Vector3, velocity: Vector3, timeOrigin: Double = 0) {
    guard origin.finite, velocity.finite, timeOrigin.isFinite else { return nil }
    self.origin = origin; self.velocity = velocity; self.timeOrigin = timeOrigin
  }

  func pose(_ world: ShipPose, at time: Double) -> ShipPose? {
    guard time.isFinite, world.position.finite else { return nil }
    let position = world.position - origin - velocity * (time - timeOrigin)
    return position.finite ? .init(position: position, orientation: world.orientation) : nil
  }

  func worldPoint(_ point: Vector3, at time: Double) -> Vector3? {
    guard point.finite, time.isFinite else { return nil }
    let world = point + origin + velocity * (time - timeOrigin)
    return world.finite ? world : nil
  }

  /// Include the subtract/add arithmetic scale even when query positions are
  /// small. A change of frame must not erase native position roundoff.
  func roundoffScale(at time: Double) -> Double {
    origin.length + velocity.length * abs(time - timeOrigin)
  }

  /// Derivative of the SAME cubic RK dense extension. Its quadratic Bernstein
  /// controls are k0, k1+k2-(k0+k3)/2, k3. Subtract the reference BEFORE norms
  /// and coefficient combinations; subtracting two speed magnitudes is invalid.
  static func denseDerivativeBound(slopes: [[Double]], at index: Int,
    relativeTo reference: Vector3 = .init(0, 0, 0)) -> Double?
  {
    guard slopes.count == 4, index >= 0,
      slopes.allSatisfy({ $0.count >= index + 3 && $0.allSatisfy(\.isFinite) }), reference.finite
    else { return nil }
    let stages = slopes.map { Vector3($0[index], $0[index + 1], $0[index + 2]) }
    let k = stages.map { $0 - reference }
    let controls = [k[0], k[1] + k[2] - (k[0] + k[3]) * 0.5, k[3]]
    let error = 256 * Double.ulpOfOne
      * max(1, stages.reduce(reference.length) { $0 + $1.length })
    let bound = (controls.map(\.length).max() ?? .infinity) + error
    return bound.isFinite && bound >= 0 ? bound.nextUp : nil
  }

  /// Cubic Bernstein hull of an actual represented basis column, not a unit
  /// basis assumption. The curve's unprojected RK orientation is retained.
  static func denseValueBound(initial: Vector3, slopes: [[Double]], at index: Int,
    duration h: Double) -> Double?
  {
    guard initial.finite, h.isFinite, h > 0, slopes.count == 4, index >= 0,
      slopes.allSatisfy({ $0.count >= index + 3 && $0.allSatisfy(\.isFinite) }) else { return nil }
    let k = slopes.map { Vector3($0[index], $0[index + 1], $0[index + 2]) }
    let controls = [initial, initial + k[0] * (h / 3),
      initial + (k[0] + k[1] * 2 + k[2] * 2 - k[3]) * (h / 6),
      initial + (k[0] + k[1] * 2 + k[2] * 2 + k[3]) * (h / 6)]
    let error = 256 * Double.ulpOfOne
      * max(1, initial.length + h * k.reduce(0) { $0 + $1.length })
    let bound = (controls.map(\.length).max() ?? .infinity) + error
    return bound.isFinite ? bound.nextUp : nil
  }

  /// Actual constant-acceleration/Rodrigues curve, also usable by the existing
  /// ordinary trajectory owner. This does not manufacture a trajectory/chord.
  static func pointSpeedBound(motion: HullSceneMotion, localExtent: Double,
    relativeTo reference: Vector3) -> Double?
  {
    guard reference.finite, localExtent.isFinite, localExtent >= 0,
      motion.duration.isFinite, motion.duration > 0,
      motion.initialVelocity.finite, motion.acceleration.finite, motion.worldAngularVelocity.finite
    else { return nil }
    let start = motion.initialVelocity - reference
    let end = start + motion.acceleration * motion.duration
    let basisNorm = sqrt(motion.start.orientation.x.dot(motion.start.orientation.x)
      + motion.start.orientation.y.dot(motion.start.orientation.y)
      + motion.start.orientation.z.dot(motion.start.orientation.z))
    let bound = max(start.length, end.length)
      + motion.worldAngularVelocity.length * basisNorm * localExtent
    let error = 256 * Double.ulpOfOne * max(1, motion.initialVelocity.length + reference.length + bound)
    return bound.isFinite && error.isFinite ? (bound + error).nextUp : nil
  }
}

/// Numeric clock conditioning only, never permission to advance a real clock.
struct NativeCurveClockWindow: Sendable {
  let start: Double
  let end: Double
  var duration: Double { end - start }

  init?(start: Double, end: Double) {
    guard start.isFinite, end.isFinite, start >= 0, end >= start,
      (end - start).isFinite else { return nil }
    self.start = start; self.end = end
  }

  /// A witness is sampled again at the actual representable retained frontier.
  /// A positive nominal time rounded to T0 supplies no positive-time credit.
  func frontier(at elapsed: Double) -> (elapsed: Double, physical: Double)? {
    guard elapsed.isFinite, elapsed >= 0, elapsed <= duration else { return nil }
    let physical = start + elapsed
    let represented = physical - start
    guard physical.isFinite, physical >= start, physical <= end,
      represented >= 0, represented <= duration, start + represented == physical,
      elapsed == 0 || physical > start else { return nil }
    return (represented, physical)
  }

  /// Error-free TwoSum determines the outward lower clock; nearest rounding
  /// must not move an earlier-clear bracket forward past its actual lower bound.
  func lowerBound(at elapsed: Double) -> Double? {
    guard elapsed.isFinite, elapsed >= 0, elapsed <= duration else { return nil }
    let sum = start + elapsed
    let other = sum - start
    let error = (start - (sum - other)) + (elapsed - other)
    guard sum.isFinite, error.isFinite else { return nil }
    return max(start, error < 0 ? sum.nextDown : sum)
  }
}

extension CurrentNewtQueryFrame {
  struct ClockAlias: Sendable {
    let clock: Double
    let origin: Double
    let elapsed: Double
  }

  /// Each source supplies its actual absolute subtraction origins and cached
  /// endpoint aliases. The full-ULP bounds enclose rounding, not a fixed margin.
  static func clockSamplingTimeError(start: Double, end: Double, origins: [Double],
    aliases: [ClockAlias] = [], normalizedDurations: [Double] = []) -> Double?
  {
    guard start.isFinite, end.isFinite, start >= 0, end >= start,
      origins.allSatisfy({ $0.isFinite && $0 >= 0 }),
      aliases.allSatisfy({ $0.clock.isFinite && $0.clock >= 0 && $0.origin.isFinite
        && $0.origin >= 0 && $0.elapsed.isFinite && $0.elapsed >= 0 }),
      normalizedDurations.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
    let addition = start == 0 ? 0 : max(start.ulp, end.ulp)
    func subtraction(_ a: Double, _ b: Double, origin: Double) -> Double {
      // Sterbenz: these actual same-sign subtractions are exact throughout
      // this range. Zero-origin subtraction is also exact.
      if origin == 0 || (a >= origin * 0.5 && b * 0.5 <= origin) { return 0 }
      return max(abs(a - origin), abs(b - origin)).nextUp.ulp
    }
    var error = 0.0
    for origin in origins {
      let value = addition + subtraction(start, end, origin: origin)
      error = max(error, value == 0 ? 0 : value.nextUp)
    }
    var aliasJumps = 0.0
    for alias in aliases {
      let difference = alias.clock - alias.origin
      let bias = abs(difference - alias.elapsed)
      let aliasError = subtraction(alias.clock, alias.clock, origin: alias.origin)
      let rounding = addition + aliasError
      error = max(error, rounding == 0 ? 0 : rounding.nextUp)
      // Several original guidance boundaries can lie between two samples.
      // Bound their total variation, not just the largest endpoint jump.
      let jump = aliasError + (bias == 0 ? 0 : bias.nextUp)
      if jump > 0 { aliasJumps = (aliasJumps + jump).nextUp }
    }
    // The real dense drive divides by its own accepted integration duration.
    // A normalized fraction in [0,1] has rounding error at most ulp(1).
    let normalized = normalizedDurations.map { ($0 * Double.ulpOfOne).nextUp }.max() ?? 0
    let result = error == 0 && normalized == 0 && aliasJumps == 0
      ? 0 : ((error + aliasJumps).nextUp + normalized).nextUp
    return result.isFinite && result >= 0 ? result : nil
  }
}
