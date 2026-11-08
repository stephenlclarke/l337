import Foundation

/// Ideal collimated geometric reference in one caller-supplied local length unit/frame.
/// No factory supplies actual C25 optics, SI calibration, measured error, fitting or custody.
/// This calculator cannot produce an optical sample, qualified reading or mission receipt.
enum NativeMemoryAtlasFinitePupilReference {
  struct Pupil: Sendable {
    let centre: Vector3
    let axis: Vector3
    let radius: Double

    /// The emitting axis is its boresight; the receiving axis faces the incoming light.
    /// Normalizing an axis adopts no global axes, length scale or instrument calibration.
    init?(centre: Vector3, axis: Vector3, radius: Double) {
      guard centre.x.isFinite, centre.y.isFinite, centre.z.isFinite,
        radius.isFinite, radius > 0,
        axis.x.isFinite, axis.y.isFinite, axis.z.isFinite
      else { return nil }
      let scale = max(abs(axis.x), max(abs(axis.y), abs(axis.z)))
      guard scale > 0 else { return nil }
      // Divide components before taking the norm, avoiding huge/tiny input-axis overflow.
      let scaled = Vector3(axis.x / scale, axis.y / scale, axis.z / scale)
      let norm = sqrt(scaled.dot(scaled))
      self.centre = centre
      self.axis = scaled * (1 / norm)
      self.radius = radius
    }
  }

  struct FootprintBound: Sendable {
    let chiefRayPoint: Vector3
    let chiefRayTravel: Double
    let minimumRayTravel: Double
    let centreOffset: Double
    let incidenceCosine: Double
    let containingRadius: Double
    let nominalClearance: Double

    /// Sufficient circular containment in the ideal model only. A negative margin can
    /// reject a usable oblique ellipse because this bound uses its largest semiaxis.
    /// Floating-point arithmetic is not an independent metrology/error certificate.
    var circularBoundFits: Bool { nominalClearance >= 0 }
  }

  /// Project the entire finite emitting pupil along its normal onto the receiver plane.
  /// Every ray must have strictly positive travel, including the emitting disk's edge.
  /// The projected disk's largest semiaxis is radius / abs(direction dot receiverNormal).
  /// Offset + that radius bounds the footprint about the receiving pupil centre.
  /// This models neither diffraction/refraction nor occlusion, motion or instrument error.
  static func project(emitter: Pupil, receiver: Pupil) -> FootprintBound? {
    let separation = receiver.centre - emitter.centre
    guard separation.x.isFinite, separation.y.isFinite, separation.z.isFinite else { return nil }
    let denominator = emitter.axis.dot(receiver.axis)
    guard denominator < 0 else { return nil }  // Parallel or back-facing receiver.
    let planeDistance = separation.dot(receiver.axis)
    let travel = planeDistance / denominator
    guard travel.isFinite, travel > 0 else { return nil }
    // For disk offset q perpendicular to d, t(q) = t(0) - (q dot n) / (d dot n).
    // Its minimum is (-separation dot n - radius * |d cross n|) / abs(d dot n).
    // Take the difference before division so a touching edge cannot gain clearance
    // from subtracting separately rounded travel values. Cross products retain tiny
    // tilts that sqrt(1 - cosine * cosine) can erase near coaxial alignment.
    let cross = emitter.axis.cross(receiver.axis)
    let sine = hypot(hypot(cross.x, cross.y), cross.z)
    let minimumPlaneGap = -planeDistance - emitter.radius * sine
    guard minimumPlaneGap.isFinite, minimumPlaneGap > 0 else { return nil }
    let minimumTravel = minimumPlaneGap / -denominator
    guard minimumTravel.isFinite, minimumTravel > 0 else { return nil }
    let point = emitter.centre + emitter.axis * travel
    guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return nil }
    let offset = point - receiver.centre
    let radial = hypot(hypot(offset.x, offset.y), offset.z)
    // Roundoff in normalized dot products must not shrink the disk below its own radius.
    let cosine = min(1, -denominator)
    let radius = emitter.radius / cosine
    let extent = radial + radius
    let clearance = receiver.radius - extent
    guard radial.isFinite, radius.isFinite, extent.isFinite, clearance.isFinite else { return nil }
    return .init(
      chiefRayPoint: point, chiefRayTravel: travel, minimumRayTravel: minimumTravel,
      centreOffset: radial,
      incidenceCosine: cosine, containingRadius: radius, nominalClearance: clearance)
  }
}
