import Foundation

/// Moment algebra for the authenticated kit parts. No geometry, mass budget,
/// stock, actor or person is created by these calculations.
enum CurrentNewtKitMass {
  typealias Properties = CurrentNewtKitReceipt.MassProperties

  /// Source components may be declared point allocations; the assembled tensor must be SPD.
  static func componentIsValid(_ p: Properties) -> Bool {
    guard p.massKilograms.isFinite, p.massKilograms > 0, p.centreOfMassMetres.finite,
      p.inertiaKgM2.count == 9, p.inertiaKgM2.allSatisfy(\.isFinite)
    else { return false }
    if p.inertiaKgM2.allSatisfy({ $0 == 0 }) { return true }
    return p.structurallyValid
  }

  static func product(_ a: [Double], _ v: Vector3) -> Vector3 {
    .init(a[0] * v.x + a[1] * v.y + a[2] * v.z,
      a[3] * v.x + a[4] * v.y + a[5] * v.z,
      a[6] * v.x + a[7] * v.y + a[8] * v.z)
  }

  static func solve(_ a: [Double], _ v: Vector3) -> Vector3? {
    guard a.count == 9, a.allSatisfy(\.isFinite), v.finite else { return nil }
    let determinant = a[0] * (a[4] * a[8] - a[5] * a[7])
      - a[1] * (a[3] * a[8] - a[5] * a[6])
      + a[2] * (a[3] * a[7] - a[4] * a[6])
    guard determinant.isFinite, determinant > 0 else { return nil }
    let result = Vector3(
      ((a[4] * a[8] - a[5] * a[7]) * v.x + (a[2] * a[7] - a[1] * a[8]) * v.y
        + (a[1] * a[5] - a[2] * a[4]) * v.z) / determinant,
      ((a[5] * a[6] - a[3] * a[8]) * v.x + (a[0] * a[8] - a[2] * a[6]) * v.y
        + (a[2] * a[3] - a[0] * a[5]) * v.z) / determinant,
      ((a[3] * a[7] - a[4] * a[6]) * v.x + (a[1] * a[6] - a[0] * a[7]) * v.y
        + (a[0] * a[4] - a[1] * a[3]) * v.z) / determinant)
    return result.finite ? result : nil
  }

  static func combined(_ parts: [Properties]) -> Properties? {
    guard !parts.isEmpty, parts.allSatisfy(componentIsValid) else { return nil }
    let mass = parts.reduce(0) { $0 + $1.massKilograms }
    guard mass.isFinite, mass > 0 else { return nil }
    let centre = parts.reduce(Vector3(0, 0, 0)) {
      $0 + $1.centreOfMassMetres * ($1.massKilograms / mass)
    }
    var tensor = Array(repeating: 0.0, count: 9)
    for part in parts {
      let offset = part.centreOfMassMetres - centre
      let r = [offset.x, offset.y, offset.z]
      let squared = offset.dot(offset)
      for row in 0..<3 {
        for column in 0..<3 {
          let index = row * 3 + column
          tensor[index] += part.inertiaKgM2[index]
            + part.massKilograms * ((row == column ? squared : 0) - r[row] * r[column])
        }
      }
    }
    let result = Properties(massKilograms: mass, centreOfMassMetres: centre, inertiaKgM2: tensor)
    return result.structurallyValid ? result : nil
  }

  static func translated(_ properties: Properties, by offset: Vector3) -> Properties {
    .init(massKilograms: properties.massKilograms,
      centreOfMassMetres: properties.centreOfMassMetres + offset,
      inertiaKgM2: properties.inertiaKgM2)
  }

  static func centre(_ mass: Properties, state: CurrentNewtKitReceipt.BodyState) -> Vector3 {
    state.pose.position + state.pose.orientation.apply(mass.centreOfMassMetres)
  }

  static func centreVelocity(_ mass: Properties, state: CurrentNewtKitReceipt.BodyState) -> Vector3 {
    state.velocity + state.angularVelocity.cross(state.pose.orientation.apply(mass.centreOfMassMetres))
  }

  static func spin(_ mass: Properties, state: CurrentNewtKitReceipt.BodyState) -> Vector3 {
    let local = state.pose.shipVector(state.angularVelocity)
    return state.pose.orientation.apply(product(mass.inertiaKgM2, local))
  }

  static func kineticEnergy(_ mass: Properties, state: CurrentNewtKitReceipt.BodyState) -> Double {
    let velocity = centreVelocity(mass, state: state)
    return 0.5 * mass.massKilograms * velocity.dot(velocity)
      + 0.5 * state.angularVelocity.dot(spin(mass, state: state))
  }

  static func close(_ a: Properties, _ b: Properties,
    massTolerance: Double, centreTolerance: Double, inertiaTolerance: Double) -> Bool
  {
    a.structurallyValid && b.structurallyValid
      && abs(a.massKilograms - b.massKilograms) <= massTolerance
      && (a.centreOfMassMetres - b.centreOfMassMetres).length <= centreTolerance
      && zip(a.inertiaKgM2, b.inertiaKgM2).allSatisfy { pair in abs(pair.0 - pair.1) <= inertiaTolerance }
  }
}
