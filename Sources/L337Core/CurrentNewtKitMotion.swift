import Foundation

extension CurrentNewtKitSource {
  struct Motion: Sendable {
    let parent: State
    let pod: State
    let parentMass: Mass
    let podMass: Mass
    let assemblyMass: Mass
    let workJoules: Double
    let charges: CurrentNewtKitStock.Charges
  }

  private struct Terms {
    let mass: Mass
    let parentMass: Mass
    let centreRate: Vector3
    let internalSpin: Vector3
    let parts: [MovingMass]
  }

  func mechanicalEndpoints(_ a: CurrentNewtKitStock.Actuation) -> [Double] {
    phaseEndpoints.map { a.startedAt + $0 }
  }

  private var phaseEndpoints: [Double] {
    let accelerationTime = releaseSpeed / ejectionAcceleration
    let accelerationDistance = 0.5 * releaseSpeed * accelerationTime
    let rodEnd = accelerationDistance >= stroke
      ? sqrt(2 * stroke / ejectionAcceleration)
      : accelerationTime + (stroke - accelerationDistance) / releaseSpeed
    return [dropDuration * 0.5, dropDuration, dropDuration + accelerationTime,
      dropDuration + rodEnd, duration].filter { $0 > 0 && $0 <= duration }.sorted()
  }

  private func terms(at elapsed: Double, extra: [Mass]) -> Terms? {
    let p = phase(elapsed: elapsed)
    var parts = movingMasses(p)
    parts += extra.map { .init(properties: $0, relativeVelocity: .init(0, 0, 0)) }
    guard let whole = CurrentNewtKitMass.combined(parts.map(\.properties)),
      let parent = CurrentNewtKitMass.combined(
        Array(parts.prefix(1 + retainedParts.count)).map(\.properties) + extra)
    else { return nil }
    let rate = parts.reduce(Vector3(0, 0, 0)) {
      $0 + $1.relativeVelocity * ($1.properties.massKilograms / whole.massKilograms)
    }
    let spin = parts.reduce(Vector3(0, 0, 0)) {
      $0 + ($1.properties.centreOfMassMetres - whole.centreOfMassMetres)
        .cross(($1.relativeVelocity - rate) * $1.properties.massKilograms)
    }
    return .init(mass: whole, parentMass: parent, centreRate: rate,
      internalSpin: spin, parts: parts)
  }

  /// Conserve WORLD linear/angular momentum while actual source parts translate.
  /// Orientation is integrated; angular velocity is solved from the full current
  /// tensor/internal momentum, never held fixed across changing mass distribution.
  func motion(_ a: CurrentNewtKitStock.Actuation, at time: Double) -> Motion? {
    guard time.isFinite, time >= a.startedAt, time <= a.unlockAt + 1e-9,
      let model = loadModel, model.matchesInventory(a.load),
      let extra = model.masses(a.load), let beginning = terms(at: 0, extra: extra),
      a.initialParent.structurallyValid,
      a.initialParent.angularVelocity.length <= maximumInitialAngularSpeed
    else { return nil }
    let elapsed = min(duration, time - a.startedAt)
    let initial = a.initialParent
    let initialLocalOmega = local(initial.angularVelocity, in: initial.pose.orientation)
    let worldSpin = initial.pose.orientation.apply(
      CurrentNewtKitMass.product(beginning.mass.inertiaKgM2, initialLocalOmega))
    let initialCentre = initial.pose.position
      + initial.pose.orientation.apply(beginning.mass.centreOfMassMetres)
    let centreVelocity = initial.velocity + initial.angularVelocity.cross(
      initial.pose.orientation.apply(beginning.mass.centreOfMassMetres))
    guard let rotation = rotation(initial.pose.orientation, through: elapsed,
      extra: extra, worldSpin: worldSpin), let end = terms(at: elapsed, extra: extra),
      let omega = angularVelocity(rotation, terms: end, worldSpin: worldSpin)
    else { return nil }
    let origin = initialCentre + centreVelocity * elapsed
      - rotation.apply(end.mass.centreOfMassMetres)
    let originVelocity = centreVelocity - omega.cross(rotation.apply(end.mass.centreOfMassMetres))
      - rotation.apply(end.centreRate)
    let parent = State(pose: .init(position: origin, orientation: rotation),
      velocity: originVelocity, angularVelocity: omega)
    let p = phase(elapsed: elapsed)
    let offset = podOrigin + direction * p.distance
    let pod = State(pose: .init(position: origin + rotation.apply(offset), orientation: rotation),
      velocity: originVelocity + omega.cross(rotation.apply(offset))
        + rotation.apply(direction * p.speed), angularVelocity: omega)
    let localOmega = local(omega, in: rotation)
    let relativeKinetic = end.parts.reduce(0.0) { sum, part in
      let r = part.properties.centreOfMassMetres - end.mass.centreOfMassMetres
      let v = localOmega.cross(r) + part.relativeVelocity - end.centreRate
      return sum + 0.5 * part.properties.massKilograms * v.dot(v)
        + 0.5 * localOmega.dot(CurrentNewtKitMass.product(part.properties.inertiaKgM2, localOmega))
    }
    let initialKinetic = 0.5 * initialLocalOmega.dot(
      CurrentNewtKitMass.product(beginning.mass.inertiaKgM2, initialLocalOmega))
    let work = dropWork * p.lower + ejectWork * p.rod
    guard parent.structurallyValid, pod.structurallyValid, omega.length <= maximumAngularSpeed,
      relativeKinetic.isFinite, relativeKinetic - initialKinetic <= work + 1e-6,
      work <= initialCharges.guideMechanicalJoules + initialCharges.ejectionMechanicalJoules
    else { return nil }
    return .init(parent: parent, pod: pod, parentMass: end.parentMass, podMass: podMass,
      assemblyMass: end.mass, workJoules: work, charges: charges(at: time, actuation: a))
  }

  private func angularVelocity(_ rotation: Basis3, terms: Terms, worldSpin: Vector3) -> Vector3? {
    let h = local(worldSpin, in: rotation) - terms.internalSpin
    guard let solved = CurrentNewtKitMass.solve(terms.mass.inertiaKgM2, h) else { return nil }
    let omega = rotation.apply(solved)
    return omega.finite && omega.length <= maximumAngularSpeed ? omega : nil
  }

  private func local(_ v: Vector3, in r: Basis3) -> Vector3 {
    .init(v.dot(r.x), v.dot(r.y), v.dot(r.z))
  }

  private struct Derivative {
    let x: Vector3
    let y: Vector3
    let z: Vector3
  }

  private func derivative(_ r: Basis3, elapsed: Double, extra: [Mass],
    worldSpin: Vector3) -> Derivative?
  {
    guard let mass = terms(at: elapsed, extra: extra),
      let omega = angularVelocity(r, terms: mass, worldSpin: worldSpin)
    else { return nil }
    return .init(x: omega.cross(r.x), y: omega.cross(r.y), z: omega.cross(r.z))
  }

  private func added(_ r: Basis3, _ d: Derivative, scale: Double) -> Basis3 {
    var result = r
    result.x = r.x + d.x * scale
    result.y = r.y + d.y * scale
    result.z = r.z + d.z * scale
    return result
  }

  private func rotation(_ initial: Basis3, through elapsed: Double,
    extra: [Mass], worldSpin: Vector3) -> Basis3?
  {
    guard elapsed >= 0, elapsed <= duration else { return nil }
    var r = initial
    var time = 0.0
    var count = 0
    // The source maximum is bounded; phase discontinuities are explicit endpoints.
    let limit = Int(ceil(duration / 0.01)) + phaseEndpoints.count + 2
    while time < elapsed {
      let endpoint = phaseEndpoints.first(where: { $0 > time + 1e-12 }) ?? elapsed
      let h = min(0.01, min(elapsed - time, endpoint - time))
      guard h > 0, count < limit,
        let k1 = derivative(r, elapsed: time, extra: extra, worldSpin: worldSpin),
        let k2 = derivative(added(r, k1, scale: h * 0.5), elapsed: time + h * 0.5,
          extra: extra, worldSpin: worldSpin),
        let k3 = derivative(added(r, k2, scale: h * 0.5), elapsed: time + h * 0.5,
          extra: extra, worldSpin: worldSpin),
        let k4 = derivative(added(r, k3, scale: h), elapsed: time + h,
          extra: extra, worldSpin: worldSpin)
      else { return nil }
      r.x = r.x + (k1.x + k2.x * 2 + k3.x * 2 + k4.x) * (h / 6)
      r.y = r.y + (k1.y + k2.y * 2 + k3.y * 2 + k4.y) * (h / 6)
      r.z = r.z + (k1.z + k2.z * 2 + k3.z * 2 + k4.z) * (h / 6)
      r.x = r.x.unit
      r.y = (r.y - r.x * r.x.dot(r.y)).unit
      r.z = r.x.cross(r.y).unit
      r.y = r.z.cross(r.x).unit
      time += h
      count += 1
    }
    return r.validRotation ? r : nil
  }
}
