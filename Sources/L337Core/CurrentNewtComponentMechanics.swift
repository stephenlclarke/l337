import Foundation

/// Instantaneous mechanical quantities, without motion/admission authority.
/// The caller supplies the complete source-validated component list, including
/// mass-only allocations and the actual velocities of internally moving rods.
struct CurrentNewtComponentMomentum: Sendable {
  let massKilograms: Double
  let linearMomentum: Vector3
  let angularMomentum: Vector3
  let kineticEnergyJoules: Double
}

enum CurrentNewtComponentMechanics {
  static func momentum(
    _ components: [CurrentNewtKitComponent], about origin: Vector3
  ) -> CurrentNewtComponentMomentum? {
    guard origin.finite, !components.isEmpty,
      components.allSatisfy(\.validForCurrentNewtQuery),
      Set(components.map(\.id)).count == components.count
    else { return nil }
    var mass = 0.0
    var linear = Vector3(0, 0, 0)
    var angular = Vector3(0, 0, 0)
    var energy = 0.0
    for component in components {
      let properties = component.massProperties
      let offset = component.pose.orientation.apply(properties.centreOfMassMetres)
      let centre = component.pose.position + offset
      let velocity = component.velocity + component.angularVelocity.cross(offset)
      let momentum = velocity * properties.massKilograms
      let bodyOmega = component.pose.shipVector(component.angularVelocity)
      let spin = component.pose.orientation.apply(
        CurrentNewtKitMass.product(properties.inertiaKgM2, bodyOmega))
      mass += properties.massKilograms
      linear = linear + momentum
      angular = angular + (centre - origin).cross(momentum) + spin
      energy += 0.5 * properties.massKilograms * velocity.dot(velocity)
        + 0.5 * component.angularVelocity.dot(spin)
    }
    guard mass.isFinite, mass > 0, linear.finite, angular.finite,
      energy.isFinite, energy >= 0
    else { return nil }
    return .init(massKilograms: mass, linearMomentum: linear,
      angularMomentum: angular, kineticEnergyJoules: energy)
  }
}
