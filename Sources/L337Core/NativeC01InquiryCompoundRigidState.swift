import Foundation

/// Instantaneous source mechanics. Actual registration/currentness and the
/// validated curve own authority; this value cannot advance a physical step.
struct NativeC01InquiryCompoundRigidState: Sendable {
  let representation: NativeC01InquiryCompoundRepresentation
  let centreOfMassPose: ShipPose
  let linearMomentum: Vector3
  let worldAngularMomentum: Vector3

  private init(representation: NativeC01InquiryCompoundRepresentation, pose: ShipPose,
    linearMomentum: Vector3, angularMomentum: Vector3)
  {
    self.representation = representation; centreOfMassPose = pose
    self.linearMomentum = linearMomentum; worldAngularMomentum = angularMomentum
  }

  static func make(representation: NativeC01InquiryCompoundRepresentation, pose: ShipPose,
    linearMomentum: Vector3, worldAngularMomentum: Vector3) -> Self?
  {
    guard pose.position.finite, pose.orientation.validRotation,
      pose.orientation.x.cross(pose.orientation.y).dot(pose.orientation.z) > 0,
      linearMomentum.finite, worldAngularMomentum.finite,
      representation.mass.massKilograms.isFinite, representation.mass.massKilograms > 0
    else { return nil }
    let result = Self(representation: representation, pose: pose,
      linearMomentum: linearMomentum, angularMomentum: worldAngularMomentum)
    guard result.velocity.finite, result.angularVelocity?.finite == true else { return nil }
    return result
  }

  var velocity: Vector3 { linearMomentum * (1 / representation.mass.massKilograms) }

  /// Recomputed from the current orientation and retained WORLD momentum.
  /// It must never be stored as a constant-omega continuation of this state.
  var angularVelocity: Vector3? { inverseWorldTensor(worldAngularMomentum) }

  func inverseWorldTensor(_ vector: Vector3) -> Vector3? {
    let body = centreOfMassPose.shipVector(vector)
    guard let solved = Self.solve(representation.mass.inertiaAtCentreOfMass, body) else { return nil }
    let world = centreOfMassPose.orientation.apply(solved)
    return world.finite ? world : nil
  }

  func contactVelocity(at point: Vector3) -> Vector3? {
    guard point.finite, let omega = angularVelocity else { return nil }
    let result = velocity + omega.cross(point - centreOfMassPose.position)
    return result.finite ? result : nil
  }

  func applyingImpulse(_ impulse: Vector3, at point: Vector3) -> Self? {
    guard impulse.finite, point.finite else { return nil }
    return Self.make(representation: representation, pose: centreOfMassPose,
      linearMomentum: linearMomentum + impulse,
      worldAngularMomentum: worldAngularMomentum + (point - centreOfMassPose.position).cross(impulse))
  }

  struct ReleasedPart: Sendable {
    let role: NativeC01InquiryFixtureGeometry.Part
    let centreOfMassPose: ShipPose
    let velocity: Vector3
    let angularVelocity: Vector3
    let linearMomentum: Vector3
    let worldAngularMomentum: Vector3
  }

  /// Current kinematic partition only. G1 must join actual accepted event,
  /// material routing and survivor-subset mass before any separation commit.
  func releasedPart(_ role: NativeC01InquiryFixtureGeometry.Part) -> ReleasedPart? {
    guard let part = representation.mass.parts.first(where: { $0.kind == role }),
      let omega = angularVelocity else { return nil }
    let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: role)
    let localCOM = descriptor.centreNative + part.centreOfMassLocal - representation.mass.centreOfMassSource
    let lever = centreOfMassPose.orientation.apply(localCOM)
    let point = centreOfMassPose.position + lever
    let velocity = self.velocity + omega.cross(lever)
    guard velocity.finite else { return nil }
    let spin = centreOfMassPose.orientation.apply(Self.apply(part.inertiaAtCentreOfMass,
      centreOfMassPose.shipVector(omega)))
    let momentum = velocity * part.massKilograms
    guard point.finite, spin.finite, momentum.finite else { return nil }
    return .init(role: role, centreOfMassPose: .init(position: point,
      orientation: centreOfMassPose.orientation), velocity: velocity, angularVelocity: omega,
      linearMomentum: momentum, worldAngularMomentum: spin)
  }

  /// Inherited instantaneous component candidate. The native owner must retain
  /// the parent represented geometry/curve and prove coordinate re-expression;
  /// this rounded COM projection cannot authorize a pose snap or curve reseed.
  func component(parts roles: [NativeC01InquiryFixtureGeometry.Part]) -> Self? {
    guard roles.allSatisfy({ role in representation.mass.parts.contains { $0.kind == role } }),
      let selected = NativeC01InquiryCompoundRepresentation.make(parts: roles),
      let omega = angularVelocity else { return nil }
    let lever = centreOfMassPose.orientation.apply(
      selected.mass.centreOfMassSource - representation.mass.centreOfMassSource)
    let centre = centreOfMassPose.position + lever
    let velocity = self.velocity + omega.cross(lever)
    let spin = centreOfMassPose.orientation.apply(Self.apply(selected.mass.inertiaAtCentreOfMass,
      centreOfMassPose.shipVector(omega)))
    return Self.make(representation: selected,
      pose: .init(position: centre, orientation: centreOfMassPose.orientation),
      linearMomentum: velocity * selected.mass.massKilograms, worldAngularMomentum: spin)
  }

  private static func apply(_ i: NativeC01InquiryCompoundMassProperties.Tensor, _ v: Vector3) -> Vector3 {
    .init(i.xx * v.x + i.xy * v.y + i.xz * v.z,
      i.xy * v.x + i.yy * v.y + i.yz * v.z,
      i.xz * v.x + i.yz * v.y + i.zz * v.z)
  }

  private static func solve(_ i: NativeC01InquiryCompoundMassProperties.Tensor, _ v: Vector3) -> Vector3? {
    guard i.finitePositiveDefinite, v.finite else { return nil }
    let a = i.yy * i.zz - i.yz * i.yz
    let b = i.xz * i.yz - i.xy * i.zz
    let c = i.xy * i.yz - i.xz * i.yy
    let d = i.xx * i.zz - i.xz * i.xz
    let e = i.xy * i.xz - i.xx * i.yz
    let f = i.xx * i.yy - i.xy * i.xy
    let determinant = i.xx * a + i.xy * b + i.xz * c
    guard determinant.isFinite, determinant > 0 else { return nil }
    let result = Vector3(a * v.x + b * v.y + c * v.z,
      b * v.x + d * v.y + e * v.z, c * v.x + e * v.y + f * v.z) * (1 / determinant)
    return result.finite ? result : nil
  }
}
