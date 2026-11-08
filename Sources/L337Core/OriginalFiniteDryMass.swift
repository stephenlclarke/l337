import Foundation

/// Pure full-tensor empty-mass mathematics. This value grants no source, load or actor authority.
struct OriginalFiniteDryMass: Decodable, Sendable, Equatable {
  let id: String
  let massKg: Double
  let centreMetres: [Double]
  let inertiaAboutCentreOfMassKgM2: [Double]

  var centre: Vector3 { .init(centreMetres[0], centreMetres[1], centreMetres[2]) }

  var valid: Bool {
    guard massKg.isFinite, massKg > 0, centreMetres.count == 3,
      centreMetres.allSatisfy(\.isFinite), inertiaAboutCentreOfMassKgM2.count == 9,
      inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite)
    else { return false }
    let a = inertiaAboutCentreOfMassKgM2
    guard abs(a[1] - a[3]) < 1e-7, abs(a[2] - a[6]) < 1e-7,
      abs(a[5] - a[7]) < 1e-7
    else { return false }
    return solveInertia(.init(1, 1, 1)) != nil
  }

  /// Cholesky retains the full symmetric tensor, including products of inertia.
  private func solveInertia(_ value: Vector3) -> Vector3? {
    let a = inertiaAboutCentreOfMassKgM2
    guard a.count == 9, a.allSatisfy(\.isFinite), a[0] > 0 else { return nil }
    let l00 = sqrt(a[0])
    let l10 = a[3] / l00, l20 = a[6] / l00
    let d11 = a[4] - l10 * l10
    guard d11.isFinite, d11 > 0 else { return nil }
    let l11 = sqrt(d11), l21 = (a[7] - l20 * l10) / sqrt(d11)
    let d22 = a[8] - l20 * l20 - l21 * l21
    guard d22.isFinite, d22 > 0 else { return nil }
    let l22 = sqrt(d22)
    let y0 = value.x / l00
    let y1 = (value.y - l10 * y0) / l11
    let y2 = (value.z - l20 * y0 - l21 * y1) / l22
    let z = y2 / l22
    let y = (y1 - l21 * z) / l11
    let x = (y0 - l10 * y - l20 * z) / l00
    let result = Vector3(x, y, z)
    return result.finite ? result : nil
  }

  func responseFromRest(impulse: Vector3, atLocalPoint point: Vector3) -> OriginalFiniteDryImpulseResponse? {
    guard valid, impulse.finite, point.finite else { return nil }
    let moment = (point - centre).cross(impulse)
    guard moment.finite, let angular = solveInertia(moment) else { return nil }
    let linear = impulse * (1 / massKg)
    let energy = (impulse.dot(linear) + moment.dot(angular)) / 2
    guard linear.finite, energy.isFinite, energy >= 0 else { return nil }
    return .init(centreVelocityDelta: linear, angularVelocityDelta: angular,
      angularMomentumDelta: moment, kineticEnergyFromRestJoules: energy)
  }
}

struct OriginalFiniteDryImpulseResponse: Sendable {
  let centreVelocityDelta: Vector3
  let angularVelocityDelta: Vector3
  let angularMomentumDelta: Vector3
  let kineticEnergyFromRestJoules: Double
}
