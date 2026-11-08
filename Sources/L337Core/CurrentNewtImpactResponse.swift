import Foundation

/// Contact algebra only. Full source tensors are mandatory for kit bodies;
/// ordinary bodies retain the existing authored translational mass policy.
enum CurrentNewtImpactMass: Sendable {
  case tensor(CurrentNewtKitReceipt.MassProperties)
  case translational(Double)

  var kilograms: Double {
    switch self {
    case .tensor(let mass): mass.massKilograms
    case .translational(let mass): mass
    }
  }

  func centreOffset(_ state: CurrentNewtKitReceipt.BodyState) -> Vector3 {
    switch self {
    case .tensor(let mass): state.pose.orientation.apply(mass.centreOfMassMetres)
    case .translational: .init(0, 0, 0)
    }
  }

  func inverseSpin(_ value: Vector3, state: CurrentNewtKitReceipt.BodyState) -> Vector3? {
    guard value.finite else { return nil }
    switch self {
    case .translational: return .init(0, 0, 0)
    case .tensor(let mass):
      guard mass.structurallyValid else { return nil }
      let r = state.pose.orientation
      let columns = [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].map { axis in
        r.apply(CurrentNewtKitMass.product(mass.inertiaKgM2,
          .init(axis.dot(r.x), axis.dot(r.y), axis.dot(r.z))))
      }
      return CurrentNewtKitMass.solve([
        columns[0].x, columns[1].x, columns[2].x,
        columns[0].y, columns[1].y, columns[2].y,
        columns[0].z, columns[1].z, columns[2].z], value)
    }
  }

  func pointVelocity(_ state: CurrentNewtKitReceipt.BodyState, at point: Vector3) -> Vector3 {
    switch self {
    case .tensor: state.velocity + state.angularVelocity.cross(point - state.pose.position)
    case .translational: state.velocity
    }
  }

  func momentum(_ state: CurrentNewtKitReceipt.BodyState, about origin: Vector3)
    -> CurrentNewtComponentMomentum
  {
    let offset = centreOffset(state)
    let velocity = state.velocity + state.angularVelocity.cross(offset)
    let linear = velocity * kilograms
    let spin: Vector3
    switch self {
    case .tensor(let mass): spin = CurrentNewtKitMass.spin(mass, state: state)
    case .translational: spin = .init(0, 0, 0)
    }
    return .init(massKilograms: kilograms, linearMomentum: linear,
      angularMomentum: (state.pose.position - origin + offset).cross(linear) + spin,
      kineticEnergyJoules: 0.5 * kilograms * velocity.dot(velocity)
        + 0.5 * state.angularVelocity.dot(spin))
  }

  func applying(_ impulse: Vector3, at point: Vector3,
    to state: CurrentNewtKitReceipt.BodyState) -> CurrentNewtKitReceipt.BodyState?
  {
    guard kilograms.isFinite, (0.001...1e12).contains(kilograms), state.structurallyValid,
      impulse.finite, point.finite else { return nil }
    let offset = centreOffset(state)
    let lever = point - state.pose.position - offset
    guard let deltaOmega = inverseSpin(lever.cross(impulse), state: state) else { return nil }
    let omega = state.angularVelocity + deltaOmega
    let centreVelocity = state.velocity + state.angularVelocity.cross(offset) + impulse * (1 / kilograms)
    let result = CurrentNewtKitReceipt.BodyState(pose: state.pose,
      velocity: centreVelocity - omega.cross(offset), angularVelocity: omega)
    return result.structurallyValid && result.velocity.length <= AsteroidImpactPolicy.maximumSpeed
      ? result : nil
  }
}

struct CurrentNewtImpactResponse: Sendable {
  let source: CurrentNewtKitReceipt.BodyState
  let target: CurrentNewtKitReceipt.BodyState
  let effect: AsteroidImpulse

  /// The native normal points from source towards target. No geometry witness
  /// or collision permission is manufactured by this mechanical calculation.
  static func resolve(source a: CurrentNewtKitReceipt.BodyState, mass ma: CurrentNewtImpactMass,
    target b: CurrentNewtKitReceipt.BodyState, mass mb: CurrentNewtImpactMass,
    point: Vector3, normal: Vector3) -> CurrentNewtImpactResponse?
  {
    guard a.structurallyValid, b.structurallyValid, point.finite, normal.finite,
      a.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      b.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      abs(normal.length - 1) < 1e-6,
      (0.001...1e12).contains(ma.kilograms), (0.001...1e12).contains(mb.kilograms)
    else { return nil }
    let ra = point - a.pose.position - ma.centreOffset(a)
    let rb = point - b.pose.position - mb.centreOffset(b)
    // Scalar ordinary masses do not authorize invented angular inertia. Mixed
    // contact is supported only when that body's missing torque is provably zero.
    switch (ma, mb) {
    case (.tensor, .translational):
      guard rb.cross(normal).length <= 128 * Double.ulpOfOne * max(1, rb.length) else { return nil }
    case (.translational, .tensor):
      guard ra.cross(normal).length <= 128 * Double.ulpOfOne * max(1, ra.length) else { return nil }
    default: break
    }
    guard let wa = ma.inverseSpin(ra.cross(normal), state: a),
      let wb = mb.inverseSpin(rb.cross(normal), state: b)
    else { return nil }
    let inverse = 1 / ma.kilograms + 1 / mb.kilograms
      + normal.dot(wa.cross(ra) + wb.cross(rb))
    let closing = (ma.pointVelocity(a, at: point) - mb.pointVelocity(b, at: point)).dot(normal)
    guard inverse.isFinite, inverse > 0, closing.isFinite, closing > 1e-8 else { return nil }
    let e = AsteroidImpactPolicy.restitution
    let transfer = normal * ((1 + e) * closing / inverse)
    guard let afterA = ma.applying(transfer * -1, at: point, to: a),
      let afterB = mb.applying(transfer, at: point, to: b)
    else { return nil }
    let outgoing = (ma.pointVelocity(afterA, at: point) - mb.pointVelocity(afterB, at: point)).dot(normal)
    let error = 512 * Double.ulpOfOne * max(1,
      ma.pointVelocity(a, at: point).length + mb.pointVelocity(b, at: point).length
        + ma.pointVelocity(afterA, at: point).length + mb.pointVelocity(afterB, at: point).length)
    let loss = 0.5 * (1 - e * e) * closing * closing / inverse
      * AsteroidImpactPolicy.metresPerCollisionUnit * AsteroidImpactPolicy.metresPerCollisionUnit
    let damage = loss / AsteroidImpactPolicy.joulesPerEnergy
    guard abs(outgoing + e * closing) <= error, damage.isFinite, (0...1e12).contains(damage)
    else { return nil }
    let pa = ma.momentum(a, about: a.pose.position), pb = mb.momentum(b, about: a.pose.position)
    let qa = ma.momentum(afterA, about: a.pose.position), qb = mb.momentum(afterB, about: a.pose.position)
    let beforeP = pa.linearMomentum + pb.linearMomentum
    let afterP = qa.linearMomentum + qb.linearMomentum
    let beforeL = pa.angularMomentum + pb.angularMomentum
    let afterL = qa.angularMomentum + qb.angularMomentum
    let beforeK = pa.kineticEnergyJoules + pb.kineticEnergyJoules
    let afterK = qa.kineticEnergyJoules + qb.kineticEnergyJoules
    guard (beforeP - afterP).length <= 1e-8 * max(1, beforeP.length),
      beforeK.isFinite, afterK.isFinite,
      abs(beforeK - afterK - loss) <= 1e-8 * max(1, max(beforeK, afterK))
    else { return nil }
    switch (ma, mb) {
    case (.translational, .translational): break // Existing authored point-mass response.
    default:
      guard (beforeL - afterL).length <= 1e-8 * max(1, beforeL.length) else { return nil }
    }
    return .init(source: afterA, target: afterB,
      effect: .init(source: afterA.velocity, target: afterB.velocity,
        transferred: transfer, damage: damage))
  }
}
