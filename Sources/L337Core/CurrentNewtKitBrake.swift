import Foundation

/// Instantaneous internal brake algebra, not a new physics loop or admission
/// authority. The source/contact owner supplies the actual full moving parts.
enum CurrentNewtKitBrake {
  static func retainedState(components: [CurrentNewtKitComponent],
    mass: CurrentNewtKitReceipt.MassProperties,
    before: CurrentNewtKitReceipt.BodyState, maximumAngularSpeed: Double)
    -> CurrentNewtKitReceipt.BodyState?
  {
    guard mass.structurallyValid, before.structurallyValid,
      let momentum = CurrentNewtComponentMechanics.momentum(components, about: before.pose.position),
      abs(momentum.massKilograms - mass.massKilograms) <= 1e-8
    else { return nil }
    let worldCentre = before.pose.orientation.apply(mass.centreOfMassMetres)
    let centreSpin = momentum.angularMomentum - worldCentre.cross(momentum.linearMomentum)
    let localSpin = before.pose.shipVector(centreSpin)
    guard let localOmega = CurrentNewtKitMass.solve(mass.inertiaKgM2, localSpin) else { return nil }
    let omega = before.pose.orientation.apply(localOmega)
    let velocity = momentum.linearMomentum * (1 / mass.massKilograms) - omega.cross(worldCentre)
    let stopped = CurrentNewtKitReceipt.BodyState(pose: before.pose,
      velocity: velocity, angularVelocity: omega)
    guard stopped.structurallyValid, omega.length <= maximumAngularSpeed else { return nil }
    let rigid = components.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: velocity + omega.cross(part.pose.position - before.pose.position), angularVelocity: omega)
    }
    guard let after = CurrentNewtComponentMechanics.momentum(rigid, about: before.pose.position),
      (momentum.linearMomentum - after.linearMomentum).length
        <= 1e-8 * max(1, momentum.linearMomentum.length),
      (momentum.angularMomentum - after.angularMomentum).length
        <= 1e-8 * max(1, momentum.angularMomentum.length),
      after.kineticEnergyJoules <= momentum.kineticEnergyJoules
        + 1e-8 * max(1, momentum.kineticEnergyJoules) else { return nil }
    return stopped
  }
}

extension CurrentNewtKitSource {
  /// Actual transient instant at a native-proved hard-stop event. Positive rod
  /// velocity here is an input to the internal brake, never an accepted stock.
  func rodStopComponents(stock: CurrentNewtKitStock, work: CurrentNewtKitStock.WorkState,
    at time: Double, parent: State, load: CurrentNewtKitLoad) -> [CurrentNewtKitComponent]?
  {
    guard stock.phase == .released, stock.interruptedAt == nil,
      work.rodMetres == stroke, work.rodVelocity > 0, work.rodVelocity <= releaseSpeed,
      work.loweredFraction == 1, work.guideWorkJoules == dropWork,
      abs(work.ejectionWorkJoules - ejectWork) <= 1e-6 else { return nil }
    let stopped = CurrentNewtKitStock.WorkState(loweredFraction: work.loweredFraction,
      rodMetres: work.rodMetres, rodVelocity: 0,
      guideWorkJoules: work.guideWorkJoules, ejectionWorkJoules: work.ejectionWorkJoules)
    guard let parts = components(stock: stock, work: stopped, at: time, parent: parent, load: load)
    else { return nil }
    let relative = parent.pose.orientation.apply(direction * work.rodVelocity)
    return parts.map { part in
      guard part.id.hasPrefix("moving-rod-") else { return part }
      return .init(id: part.id, collisionMesh: part.collisionMesh, displayMesh: part.displayMesh,
        pose: part.pose, massProperties: part.massProperties,
        velocity: part.velocity + relative, angularVelocity: part.angularVelocity)
    }
  }
}
