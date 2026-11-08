import Foundation

/// C01 instantaneous response only. No contact witness, damage, registration or
/// unqualified remainder is issued. Native owner must commit both endpoints.
enum NativeC01InquiryCompoundPointImpulse {
  struct Response: Sendable {
    let normal: Vector3
    let contactVelocity: Vector3
    let inverseEffectiveMass: Double
  }

  struct Resolution: Sendable {
    let compound: NativeC01InquiryCompoundRigidState
    let compoundImpulse: Vector3
    let oppositeImpulse: Vector3
  }

  static func response(_ state: NativeC01InquiryCompoundRigidState,
    point: Vector3, outwardNormal: Vector3) -> Response?
  {
    let length = outwardNormal.length
    guard point.finite, outwardNormal.finite, length.isFinite, length > 0,
      let velocity = state.contactVelocity(at: point)
    else { return nil }
    let normal = outwardNormal * (1 / length)
    let r = point - state.centreOfMassPose.position
    guard let angular = state.inverseWorldTensor(r.cross(normal)) else { return nil }
    let rotational = normal.dot(angular.cross(r))
    let effective = 1 / state.representation.mass.massKilograms + rotational
    guard normal.finite, rotational.isFinite, rotational >= 0,
      effective.isFinite, effective > 0 else { return nil }
    return .init(normal: normal, contactVelocity: velocity, inverseEffectiveMass: effective)
  }

  /// Normal points from the opposing endpoint into C01. Opposing response must
  /// include its actual rotation/full tensor; zero is not an assumed default.
  static func prepare(_ state: NativeC01InquiryCompoundRigidState, point: Vector3,
    outwardNormal: Vector3, opposingContactVelocity: Vector3,
    opposingInverseEffectiveMass: Double, restitution: Double) -> Resolution?
  {
    guard opposingContactVelocity.finite, opposingInverseEffectiveMass.isFinite,
      opposingInverseEffectiveMass >= 0, restitution.isFinite, (0...1).contains(restitution),
      let response = response(state, point: point, outwardNormal: outwardNormal)
    else { return nil }
    let closing = (response.contactVelocity - opposingContactVelocity).dot(response.normal)
    let inverseMass = response.inverseEffectiveMass + opposingInverseEffectiveMass
    guard closing.isFinite, closing < 0, inverseMass.isFinite, inverseMass > 0 else { return nil }
    let magnitude = -(1 + restitution) * closing / inverseMass
    let impulse = response.normal * magnitude
    guard magnitude.isFinite, magnitude > 0,
      let changed = state.applyingImpulse(impulse, at: point) else { return nil }
    return .init(compound: changed, compoundImpulse: impulse, oppositeImpulse: impulse * -1)
  }
}
