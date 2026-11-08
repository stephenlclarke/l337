import Foundation

/// The actual owner's rod-locked plan, sampled in the same native leg. It
/// supplies zero actuator work and retains the full instantaneous source tensor.
struct CurrentNewtNativeCoastCurve: Sendable {
  let actor: ActorIdentity
  let before: CurrentNewtKitReceipt.BodyState
  let mass: CurrentNewtKitReceipt.MassProperties
  let interval: CurrentNewtMechanicalInterval
  let maximumPointSpeed: Double
  let flow: CurrentNewtRigidCoast
  private struct Part: Sendable {
    let value: CurrentNewtKitComponent
    let offset: Vector3
  }
  private let parts: [Part]
  private let localExtent: Double

  fileprivate init?(plan: CurrentNewtCoastPlan, source: CurrentNewtKitSource) {
    guard plan.interval.valid,
      let flow = CurrentNewtRigidCoast(
        initial: plan.initial, mass: plan.mass,
        duration: plan.interval.end - plan.interval.start,
        maximumAngularSpeed: source.maximumAngularSpeed)
    else { return nil }
    let extent =
      plan.components.map { part in
        (part.pose.position - plan.initial.pose.position).length
          + (part.collisionMesh?.vertices.map(\.length).max() ?? 0)
      }.max() ?? .infinity
    guard let speed = flow.pointSpeedBound(localExtent: extent) else { return nil }
    let r = plan.initial.pose.orientation
    let x = r.y.cross(r.z)
    let y = r.z.cross(r.x)
    let z = r.x.cross(r.y)
    let determinant = r.x.dot(x)
    guard determinant.isFinite, determinant > 0 else { return nil }
    var local: [Part] = []
    for part in plan.components {
      guard part.pose.orientation == r else { return nil }
      let relative = part.pose.position - plan.initial.pose.position
      let offset = Vector3(relative.dot(x), relative.dot(y), relative.dot(z)) * (1 / determinant)
      guard offset.finite else { return nil }
      local.append(.init(value: part, offset: offset))
    }
    actor = plan.actor
    before = plan.before
    mass = plan.mass
    interval = plan.interval
    maximumPointSpeed = speed
    self.flow = flow
    parts = local
    localExtent = extent
  }

  private init(copy original: Self, interval: CurrentNewtMechanicalInterval) {
    actor = original.actor
    before = original.before
    mass = original.mass
    self.interval = interval
    maximumPointSpeed = original.maximumPointSpeed
    flow = original.flow
    parts = original.parts
    localExtent = original.localExtent
  }

  /// Retain the same prepared full-tensor flow; do not integrate a new coast
  /// merely because another real event selected an earlier physical endpoint.
  func prefix(through end: Double) -> Self? {
    guard end > interval.start, end <= interval.end, state(at: end) != nil else { return nil }
    return .init(copy: self, interval: .init(start: interval.start, end: end))
  }

  func pointSpeedBound(relativeTo reference: Vector3) -> Double? {
    flow.pointSpeedBound(localExtent: localExtent, relativeTo: reference)
  }

  func state(at time: Double) -> CurrentNewtKitReceipt.BodyState? {
    flow.state(at: time - interval.start)
  }

  func components(at time: Double) -> [CurrentNewtKitComponent]? {
    guard let body = state(at: time) else { return nil }
    if time == interval.start { return parts.map(\.value) }
    return parts.map { part in
      let offset = body.pose.orientation.apply(part.offset)
      return .init(
        id: part.value.id, collisionMesh: part.value.collisionMesh,
        displayMesh: part.value.displayMesh,
        pose: .init(position: body.pose.position + offset, orientation: body.pose.orientation),
        massProperties: part.value.massProperties,
        velocity: body.velocity + body.angularVelocity.cross(offset),
        angularVelocity: body.angularVelocity)
    }
  }
}

extension Game {
  /// Consume the SAME actual coast plans, not a second actor/load discovery.
  func currentNewtNativeCoasts(
    mechanics: CurrentNewtMechanicalPlan, excluding moving: Set<ActorIdentity>
  ) -> [CurrentNewtNativeCoastCurve]? {
    guard commander.flightSimulation.physicalTime == mechanics.interval.start else { return nil }
    var result: [CurrentNewtNativeCoastCurve] = []
    for plan in mechanics.coasts {
      guard !moving.contains(plan.actor), plan.interval.start == mechanics.interval.start,
        plan.interval.end == mechanics.interval.end,
        let body = bodies.first(where: { $0.physical?.identity == plan.actor }),
        currentNewtBodyState(body) == plan.before,
        let source = CurrentNewtKitSource.current,
        let parts = try? currentNewtGeometryComponents(for: body),
        parts.count == plan.components.count,
        Set(parts.map(\.id)) == Set(plan.components.map(\.id))
      else { return nil }
      let expected: [CurrentNewtKitComponent]
      if let brakeAt = plan.internalBrakeAt {
        guard brakeAt == mechanics.interval.start, plan.initial.pose == plan.before.pose,
          let braked = CurrentNewtKitBrake.retainedState(
            components: parts, mass: plan.mass,
            before: plan.before, maximumAngularSpeed: source.maximumAngularSpeed),
          source.matchesState(braked, plan.initial)
        else { return nil }
        expected = parts.map { part in
          .init(
            id: part.id, collisionMesh: part.collisionMesh, displayMesh: part.displayMesh,
            pose: part.pose, massProperties: part.massProperties,
            velocity: braked.velocity
              + braked.angularVelocity.cross(part.pose.position - braked.pose.position),
            angularVelocity: braked.angularVelocity)
        }
      } else {
        guard plan.before == plan.initial else { return nil }
        expected = parts
      }
      guard
        expected.allSatisfy({ actual in
          guard let proposed = plan.components.first(where: { $0.id == actual.id }) else {
            return false
          }
          return actual.pose == proposed.pose && actual.massProperties == proposed.massProperties
            && actual.velocity == proposed.velocity
            && actual.angularVelocity == proposed.angularVelocity
            && actual.collisionMesh?.vertices == proposed.collisionMesh?.vertices
            && actual.collisionMesh?.faces == proposed.collisionMesh?.faces
            && actual.displayMesh?.vertices == proposed.displayMesh?.vertices
            && actual.displayMesh?.faces == proposed.displayMesh?.faces
            && actual.displayMesh?.faceMaterials == proposed.displayMesh?.faceMaterials
            && actual.displayMesh?.materials == proposed.displayMesh?.materials
        })
      else { return nil }
      switch plan.source {
      case .parent(let stock, let load, let cell):
        guard body.physical?.currentNewtKitStock == stock,
          currentNewtKitLoad(for: body) == load,
          let mass = source.loadedMechanicalMass(stock: stock, load: load, cell: cell),
          source.matchesMass(plan.mass, mass),
          plan.internalBrakeAt != nil
            || (stock.work.rodVelocity == 0
              && (stock.phase == .stowed || stock.interruptedAt != nil
                || stock.work.rodMetres == source.stroke))
        else { return nil }
      case .pod(let receipt):
        guard body.physical?.currentNewtKitReceipt == receipt,
          source.matchesMass(plan.mass, source.podMass),
          currentOccupiedNewtPodHasCurrentCustody(body)
        else { return nil }
      }
      guard let curve = CurrentNewtNativeCoastCurve(plan: plan, source: source) else { return nil }
      result.append(curve)
    }
    return result
  }
}
