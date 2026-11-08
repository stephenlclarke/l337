import Foundation

/// One actor's actual post-contact coast. It owns no clock or admission rights.
struct CurrentNewtImpactContinuation: Sendable {
  let actor: ActorIdentity
  let start: Double
  let end: Double
  let initial: CurrentNewtKitReceipt.BodyState
  let mass: CurrentNewtImpactMass
  let components: [CurrentNewtKitComponent]
  private let flow: CurrentNewtRigidCoast?
  private let ordinary: HullSceneMotion?

  init?(actor: ActorIdentity, start: Double, end: Double,
    initial: CurrentNewtKitReceipt.BodyState, mass: CurrentNewtImpactMass,
    components: [CurrentNewtKitComponent], maximumAngularSpeed: Double)
  {
    guard start.isFinite, end.isFinite, end > start, initial.structurallyValid else { return nil }
    self.actor = actor; self.start = start; self.end = end; self.initial = initial
    self.mass = mass; self.components = components
    switch mass {
    case .tensor(let properties):
      guard !components.isEmpty,
        let real = Self.mass(of: components, in: initial.pose),
        CurrentNewtKitMass.close(real, properties, massTolerance: 1e-6,
          centreTolerance: 1e-8, inertiaTolerance: 1e-5),
        let coast = CurrentNewtRigidCoast(initial: initial, mass: properties,
          duration: end - start, maximumAngularSpeed: maximumAngularSpeed)
      else { return nil }
      flow = coast; ordinary = nil
    case .translational:
      guard components.isEmpty else { return nil }
      let seed = HullSceneMotion(start: initial.pose, end: initial.pose,
        initialVelocity: initial.velocity, acceleration: .init(0, 0, 0),
        worldAngularVelocity: initial.angularVelocity, duration: end - start, playerRadius: 0)
      let finish = HullSweepSafety.shipPose(seed, at: end - start)
      ordinary = .init(start: initial.pose, end: finish, initialVelocity: initial.velocity,
        acceleration: .init(0, 0, 0), worldAngularVelocity: initial.angularVelocity,
        duration: end - start, playerRadius: 0)
      flow = nil
    }
    guard state(at: end) != nil else { return nil }
  }

  func state(at time: Double) -> CurrentNewtKitReceipt.BodyState? {
    guard time >= start, time <= end else { return nil }
    if let flow { return flow.state(at: time - start) }
    guard let ordinary else { return nil }
    return .init(pose: HullSweepSafety.shipPose(ordinary, at: time - start),
      velocity: initial.velocity, angularVelocity: initial.angularVelocity)
  }

  func part(_ id: String, at time: Double) -> CurrentNewtKitComponent? {
    guard let part = components.first(where: { $0.id == id }), let body = state(at: time),
      part.pose.orientation == initial.pose.orientation,
      let local = Self.coordinates(part.pose.position - initial.pose.position,
        in: initial.pose.orientation)
    else { return nil }
    let offset = body.pose.orientation.apply(local)
    return .init(id: part.id, collisionMesh: part.collisionMesh, displayMesh: part.displayMesh,
      pose: time == start ? part.pose : .init(position: body.pose.position + offset,
        orientation: body.pose.orientation), massProperties: part.massProperties,
      velocity: body.velocity + body.angularVelocity.cross(offset), angularVelocity: body.angularVelocity)
  }

  func pointSpeedBound(extent: Double, relativeTo reference: Vector3 = .init(0, 0, 0)) -> Double? {
    if let flow { return flow.pointSpeedBound(localExtent: extent, relativeTo: reference) }
    guard let ordinary else { return nil }
    return CurrentNewtQueryFrame.pointSpeedBound(motion: ordinary, localExtent: extent,
      relativeTo: reference)
  }

  var rigidFlow: CurrentNewtRigidCoast? { flow }

  static func mass(of components: [CurrentNewtKitComponent], in pose: ShipPose)
    -> CurrentNewtKitReceipt.MassProperties?
  {
    var parts: [CurrentNewtKitReceipt.MassProperties] = []
    guard !components.isEmpty, Set(components.map(\.id)).count == components.count else { return nil }
    for part in components {
      guard part.validForCurrentNewtQuery, part.pose.orientation == pose.orientation,
        let offset = coordinates(part.pose.position - pose.position, in: pose.orientation)
      else { return nil }
      parts.append(CurrentNewtKitMass.translated(part.massProperties, by: offset))
    }
    return CurrentNewtKitMass.combined(parts)
  }

  private static func coordinates(_ value: Vector3, in r: Basis3) -> Vector3? {
    let x = r.y.cross(r.z), y = r.z.cross(r.x), z = r.x.cross(r.y)
    let determinant = r.x.dot(x)
    guard determinant.isFinite, determinant > 0 else { return nil }
    let result = Vector3(value.dot(x), value.dot(y), value.dot(z)) * (1 / determinant)
    return result.finite ? result : nil
  }
}
