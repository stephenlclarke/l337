import Foundation

extension CurrentNewtKitSource {
  /// Bound the nonlinear attached path by actual component extents and source
  /// angular/rack speed limits. Consumers must evaluate the real source path;
  /// an endpoint chord alone does not describe this motion.
  func attachedPointSpeedBound(actuation: CurrentNewtKitStock.Actuation,
    components: [CurrentNewtKitComponent], parent: State,
    relativeTo reference: Vector3 = .init(0, 0, 0)) -> Double?
  {
    guard reference.finite, let initial = assemblyMass(at: phase(elapsed: 0)), let model = loadModel,
      let extra = model.masses(actuation.load),
      let loaded = CurrentNewtKitMass.combined([initial] + extra) else { return nil }
    var radius = loaded.centreOfMassMetres.length
    for component in components {
      let origin = (component.pose.position - parent.pose.position).length
      let extent = max(component.massProperties.centreOfMassMetres.length,
        component.collisionMesh?.vertices.map(\.length).max() ?? 0)
      radius = max(radius, origin + extent)
    }
    let translations = retainedParts.map {
      ($0.lowered.centreOfMassMetres - $0.stowed.centreOfMassMetres).length
    }
    let maximumTranslation = translations.max() ?? 0
    radius += maximumTranslation
    let maximumRelativeSpeed = maximumTranslation * 2 / dropDuration
    let internalCentreSpeed = zip(retainedParts, translations).reduce(0.0) {
      $0 + $1.0.stowed.massKilograms * $1.1 * 2 / dropDuration / loaded.massKilograms
    }
    let centreVelocity = actuation.initialParent.velocity
      + actuation.initialParent.angularVelocity.cross(
        actuation.initialParent.pose.orientation.apply(loaded.centreOfMassMetres))
    let bound = (centreVelocity - reference).length + maximumAngularSpeed * radius * 2
      + internalCentreSpeed + maximumRelativeSpeed
    let error = 256 * Double.ulpOfOne * max(1, centreVelocity.length + reference.length + bound)
    return bound.isFinite && bound >= 0 && error.isFinite ? (bound + error).nextUp : nil
  }
}
