import Foundation

/// A finite-force candidate only. G1 retains the same candidate after the pure
/// clock leg only if the complete native scene and MC1 outcome checks accept it.
final class CurrentNewtNativeDriveCurve: Sendable {
  struct Sample: Sendable {
    let time: Double
    let parent: CurrentNewtKitReceipt.BodyState
    let pod: CurrentNewtKitReceipt.BodyState
    let work: CurrentNewtKitStock.WorkState
    let parentComponents: [CurrentNewtKitComponent]
    let podComponents: [CurrentNewtKitComponent]
    let impulseOnPod: Vector3
  }

  private struct Segment: Sendable {
    let start: Double
    let end: Double
    let integrationDuration: Double
    let initial: [Double]
    let slopes: [[Double]]
    let forces: [CurrentNewtDriveForceResponse]
    let parentSpeed: Double
    let podSpeed: Double

    func coordinates(at time: Double) -> [Double] {
      let h = integrationDuration
      let u = max(0, min(1, (time - start) / h))
      let squared = u * u, cubed = squared * u
      let weights = [u - 1.5 * squared + (2.0 / 3) * cubed,
        squared - (2.0 / 3) * cubed, squared - (2.0 / 3) * cubed,
        -0.5 * squared + (2.0 / 3) * cubed]
      return initial.indices.map { index in
        initial[index] + h * (0..<4).reduce(0) { $0 + weights[$1] * slopes[$1][index] }
      }
    }
  }

  let plan: CurrentNewtDrivePlan
  let maximumParentPointSpeed: Double
  let maximumPodPointSpeed: Double
  private let stock: CurrentNewtKitStock
  private let source: CurrentNewtKitSource
  private let segments: [Segment]
  private let stop: Stop?
  private let freePrediction: Bool

  private init(plan: CurrentNewtDrivePlan, stock: CurrentNewtKitStock,
    source: CurrentNewtKitSource, segments: [Segment], stop: Stop?, freePrediction: Bool)
  {
    self.plan = plan; self.stock = stock; self.source = source; self.segments = segments; self.stop = stop
    self.freePrediction = freePrediction
    maximumParentPointSpeed = max(segments.map(\.parentSpeed).max() ?? 0, stop?.parentSpeed ?? 0)
    maximumPodPointSpeed = max(segments.map(\.podSpeed).max() ?? 0, stop?.podSpeed ?? 0)
  }

  static func make(plan: CurrentNewtDrivePlan, stock: CurrentNewtKitStock) -> CurrentNewtNativeDriveCurve? {
    guard plan.interval.valid, let source = CurrentNewtKitSource.current,
      stock.phase == .released, stock.interruptedAt == nil,
      stock.issue == plan.issue, stock.receipt == plan.receipt, stock.actuation == plan.actuation,
      stock.work == plan.work, stock.observedAt == plan.interval.start,
      source.matches(stock, at: plan.interval.start), source.matches(plan.receipt),
      plan.parentActor == plan.actuation.parent, plan.podActor == plan.receipt.podActor,
      plan.maximumForceNewtons == source.maximumForceNewtons,
      plan.maximumGuideFrictionNewtons == source.maximumGuideFrictionNewtons,
      plan.work.loweredFraction == 1,
      plan.maximumAvailableMechanicalJoules <= stock.charges.ejectionMechanicalJoules,
      let initial = sample(coordinates: coordinates(parent: plan.parent, pod: plan.pod,
        work: plan.work), at: plan.interval.start, plan: plan, stock: stock, source: source)
    else { return nil }
    let initialRods = initial.parentComponents.filter { $0.id.hasPrefix("moving-rod-") }
    let initialShoes = initial.podComponents.filter { $0.id.hasPrefix("portable-thrust-shoe-") }
    guard initialRods.count == 2, initialShoes.count == 2 else { return nil }
    var initialSurfaces: [CurrentNewtDriveSurface] = []
    for rod in initialRods {
      let matches = initialShoes.compactMap { CurrentNewtDriveContact.surface(rod: rod, shoe: $0, source: source) }
      guard matches.count == 1, let surface = matches.first else { return nil }
      initialSurfaces.append(surface)
    }
    // This is an unretained free prediction, like an ordinary collision path.
    // Its possible future penetration never supplies contact force or clearance.
    // Both actual interfaces must be strictly separated at the real opening.
    let freePrediction = initialSurfaces.allSatisfy {
      $0.gapMetres > 128 * Double.ulpOfOne * max(1, $0.point.length)
    }
    let anchor = plan.parent.pose.position
    guard let before = CurrentNewtComponentMechanics.momentum(
      initial.parentComponents + initial.podComponents, about: anchor) else { return nil }
    var values = coordinates(parent: plan.parent, pod: plan.pod, work: plan.work)
    var time = plan.interval.start
    var segments: [Segment] = []
    var stop: Stop?
    // These are internal force stages, not extra public ticks, controls or clocks.
    // Exhaustion refuses the pure candidate instead of crediting unobserved motion.
    while time < plan.interval.end {
      guard segments.count < 256 else { return nil }
      var h = min(0.001, plan.interval.end - time)
      var accepted: Segment?
      for _ in 0..<12 {
        if let value = segment(initial: values, start: time, duration: h,
          plan: plan, stock: stock, source: source, freePrediction: freePrediction) {
          if value.coordinates(at: value.end)[36] >= source.stroke,
            let event = strokeEvent(in: value, plan: plan, stock: stock, source: source),
            let end = event.stop.sample(at: plan.interval.end),
            let momentum = CurrentNewtComponentMechanics.momentum(
              end.parentComponents + end.podComponents, about: anchor),
            conserved(before: before, after: momentum,
              paidWork: end.work.ejectionWorkJoules - plan.work.ejectionWorkJoules) {
            accepted = event.prefix; stop = event.stop; break
          }
          if let end = sample(coordinates: value.coordinates(at: value.end), at: value.end,
            plan: plan, stock: stock, source: source),
            let momentum = CurrentNewtComponentMechanics.momentum(
              end.parentComponents + end.podComponents, about: anchor),
            conserved(before: before, after: momentum,
              paidWork: end.work.ejectionWorkJoules - plan.work.ejectionWorkJoules),
            end.impulseOnPod.length <= plan.maximumForceNewtons * (value.end - plan.interval.start) + 1e-6 {
            accepted = value; break
          }
        }
        h *= 0.5
      }
      guard let accepted, accepted.end > time else { return nil }
      values = accepted.coordinates(at: accepted.end)
      time = accepted.end
      segments.append(accepted)
      if stop != nil { break } // The actual remainder is supplied by its two torque-free flows.
    }
    let curve = CurrentNewtNativeDriveCurve(plan: plan, stock: stock, source: source, segments: segments, stop: stop, freePrediction: freePrediction)
    let rods = plan.parentComponents.filter { $0.id.hasPrefix("moving-rod-") }
    let shoes = plan.podComponents.filter { $0.id.hasPrefix("portable-thrust-shoe-") }
    guard rods.count == 2, shoes.count == 2 else { return nil }
    for rod in rods {
      let matches = shoes.filter { CurrentNewtDriveContact.surface(rod: rod, shoe: $0, source: source) != nil }
      guard matches.count == 1, let shoe = matches.first,
        (freePrediction || curve.provesGovernedPair(rodID: rod.id, shoeID: shoe.id))
      else { return nil }
    }
    return curve
  }

  func sample(at time: Double) -> Sample? {
    guard time.isFinite, time >= plan.interval.start, time <= plan.interval.end else { return nil }
    if let stop, time >= stop.time { return stop.sample(at: time) }
    guard let segment = segments.first(where: { time <= $0.end })
    else { return nil }
    return Self.sample(coordinates: segment.coordinates(at: time), at: time,
      plan: plan, stock: stock, source: source)
  }

  /// Actual accepted dense segments/stop, not guessed clock magnitudes.
  func clockSamplingTimeError(start: Double, end: Double) -> Double? {
    let relevant = segments.filter { $0.end >= start && $0.start <= end }
    var origins = relevant.map(\.start)
    if let stop { origins.append(stop.time) }
    return CurrentNewtQueryFrame.clockSamplingTimeError(start: start, end: end,
      origins: origins, normalizedDurations: relevant.map(\.integrationDuration))
  }

  func outcome(at time: Double, interrupted: Bool = false) -> CurrentNewtDriveOutcome? {
    guard let state = sample(at: time), let initial = sample(at: plan.interval.start),
      !interrupted || state.work.rodVelocity == 0,
      let before = CurrentNewtComponentMechanics.momentum(
        initial.parentComponents + initial.podComponents, about: plan.parent.pose.position),
      let after = CurrentNewtComponentMechanics.momentum(
        state.parentComponents + state.podComponents, about: plan.parent.pose.position),
      Self.conserved(before: before, after: after,
        paidWork: state.work.ejectionWorkJoules - plan.work.ejectionWorkJoules),
      state.impulseOnPod.length <= plan.maximumForceNewtons * (time - plan.interval.start) + 1e-6
    else { return nil }
    return .init(kitID: plan.issue.kitID, parentActor: plan.parentActor, podActor: plan.podActor,
      observedAt: plan.interval.end, work: state.work, impulseOnPod: state.impulseOnPod,
      interruptedAt: interrupted ? time : nil)
  }

  /// External contact ends this real force prefix. Absorb only the retained
  /// rod's internal momentum before applying the external impulse. The pod is
  /// independent and receives no invented ejection or brake impulse.
  func interrupted(at time: Double) -> (sample: Sample, outcome: CurrentNewtDriveOutcome)? {
    guard let incoming = sample(at: time), outcome(at: time) != nil,
      let mass = source.loadedParentMass(work: incoming.work, load: plan.load),
      let parent = CurrentNewtKitBrake.retainedState(components: incoming.parentComponents,
        mass: mass, before: incoming.parent, maximumAngularSpeed: source.maximumAngularSpeed)
    else { return nil }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: incoming.work.loweredFraction,
      rodMetres: incoming.work.rodMetres, rodVelocity: 0,
      guideWorkJoules: incoming.work.guideWorkJoules,
      ejectionWorkJoules: incoming.work.ejectionWorkJoules)
    guard source.validWork(work) else { return nil }
    let parts = incoming.parentComponents.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: parent.velocity + parent.angularVelocity.cross(part.pose.position - parent.pose.position),
        angularVelocity: parent.angularVelocity)
    }
    let result = CurrentNewtDriveOutcome(kitID: plan.issue.kitID,
      parentActor: plan.parentActor, podActor: plan.podActor, observedAt: plan.interval.end,
      work: work, impulseOnPod: incoming.impulseOnPod, interruptedAt: time)
    guard result.valid(for: plan) else { return nil }
    return (.init(time: time, parent: parent, pod: incoming.pod, work: work,
      parentComponents: parts, podComponents: incoming.podComponents,
      impulseOnPod: incoming.impulseOnPod), result)
  }

  /// Native same-kit rod/pod impact: resolve the actual incoming prismatic
  /// degree of freedom FIRST. The subsequent internal brake preserves the
  /// resulting full parent momentum; it cannot erase the incoming closure.
  func rodImpact(at time: Double, point: Vector3, normal: Vector3)
    -> (sample: Sample, outcome: CurrentNewtDriveOutcome, effect: AsteroidImpulse)?
  {
    guard let incoming = sample(at: time), incoming.work.rodVelocity > 0,
      incoming.parent.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      incoming.pod.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      outcome(at: time) != nil,
      let mass = source.loadedParentMass(work: incoming.work, load: plan.load)
    else { return nil }
    let direction = incoming.parent.pose.orientation.apply(source.direction)
    let rodIDs = Set(incoming.parentComponents.filter { $0.id.hasPrefix("moving-rod-") }.map(\.id))
    guard rodIDs.count == 2,
      let metric = CurrentNewtDriveMassOperator(parent: incoming.parent, pod: incoming.pod,
        parentComponents: incoming.parentComponents, podComponents: incoming.podComponents,
        rodIDs: rodIDs, direction: direction),
      let row = CurrentNewtDriveMassOperator.contactJacobian(point: point, normal: normal,
        direction: direction, parent: incoming.parent, pod: incoming.pod),
      let response = metric.solve(row)
    else { return nil }
    let velocity = CurrentNewtDriveMassOperator.velocities(parent: incoming.parent,
      pod: incoming.pod, rodVelocity: incoming.work.rodVelocity)
    let inverse = zip(row, response).reduce(0) { $0 + $1.0 * $1.1 }
    let closing = -zip(row, velocity).reduce(0) { $0 + $1.0 * $1.1 }
    guard inverse.isFinite, inverse > 0, closing.isFinite, closing > 1e-8 else { return nil }
    let magnitude = (1 + AsteroidImpactPolicy.restitution) * closing / inverse
    let outgoing = zip(velocity, response).map { $0.0 + $0.1 * magnitude }
    let normalAfter = zip(row, outgoing).reduce(0) { $0 + $1.0 * $1.1 }
    let scale = row.indices.reduce(0.0) {
      $0 + abs(row[$1]) * (abs(velocity[$1]) + abs(outgoing[$1]))
    }
    guard abs(normalAfter - AsteroidImpactPolicy.restitution * closing)
      <= 512 * Double.ulpOfOne * max(1, scale) else { return nil }
    let parent = CurrentNewtKitReceipt.BodyState(pose: incoming.parent.pose,
      velocity: Self.vector(outgoing, at: 0), angularVelocity: Self.vector(outgoing, at: 3))
    let pod = CurrentNewtKitReceipt.BodyState(pose: incoming.pod.pose,
      velocity: Self.vector(outgoing, at: 6), angularVelocity: Self.vector(outgoing, at: 9))
    guard parent.structurallyValid, pod.structurallyValid,
      parent.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      pod.velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      pod.angularVelocity.length <= source.maximumAngularSpeed
    else { return nil }
    let struckParts = incoming.parentComponents.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: parent.velocity + parent.angularVelocity.cross(part.pose.position - parent.pose.position)
          + (rodIDs.contains(part.id) ? direction * outgoing[12] : Vector3(0, 0, 0)),
        angularVelocity: parent.angularVelocity)
    }
    let podParts = incoming.podComponents.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: pod.velocity + pod.angularVelocity.cross(part.pose.position - pod.pose.position),
        angularVelocity: pod.angularVelocity)
    }
    let origin = incoming.parent.pose.position
    guard let before = CurrentNewtComponentMechanics.momentum(
      incoming.parentComponents + incoming.podComponents, about: origin),
      let after = CurrentNewtComponentMechanics.momentum(struckParts + podParts, about: origin)
    else { return nil }
    let loss = 0.5 * (1 - AsteroidImpactPolicy.restitution * AsteroidImpactPolicy.restitution)
      * closing * closing / inverse
      * AsteroidImpactPolicy.metresPerCollisionUnit * AsteroidImpactPolicy.metresPerCollisionUnit
    guard magnitude.isFinite, magnitude > 0, loss.isFinite, loss > 0,
      (before.linearMomentum - after.linearMomentum).length <= 1e-8 * max(1, before.linearMomentum.length),
      (before.angularMomentum - after.angularMomentum).length <= 1e-8 * max(1, before.angularMomentum.length),
      abs(before.kineticEnergyJoules - after.kineticEnergyJoules - loss)
        <= 1e-8 * max(1, before.kineticEnergyJoules),
      let braked = CurrentNewtKitBrake.retainedState(components: struckParts, mass: mass,
        before: parent, maximumAngularSpeed: source.maximumAngularSpeed)
    else { return nil }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: incoming.work.loweredFraction,
      rodMetres: incoming.work.rodMetres, rodVelocity: 0,
      guideWorkJoules: incoming.work.guideWorkJoules,
      ejectionWorkJoules: incoming.work.ejectionWorkJoules)
    let retained = struckParts.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: braked.velocity + braked.angularVelocity.cross(part.pose.position - braked.pose.position),
        angularVelocity: braked.angularVelocity)
    }
    let result = CurrentNewtDriveOutcome(kitID: plan.issue.kitID,
      parentActor: plan.parentActor, podActor: plan.podActor, observedAt: plan.interval.end,
      work: work, impulseOnPod: incoming.impulseOnPod, interruptedAt: time)
    let damage = loss / AsteroidImpactPolicy.joulesPerEnergy
    guard source.validWork(work), result.valid(for: plan), damage.isFinite,
      (0...1e12).contains(damage) else { return nil }
    return (.init(time: time, parent: braked, pod: pod, work: work,
      parentComponents: retained, podComponents: podParts, impulseOnPod: incoming.impulseOnPod),
      result, .init(source: braked.velocity, target: pod.velocity,
        transferred: normal * magnitude, damage: damage))
  }

  private struct Derivative {
    let values: [Double]
    let forces: CurrentNewtDriveForceResponse
  }

  private static func segment(initial: [Double], start: Double, duration requested: Double,
    plan: CurrentNewtDrivePlan, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    freePrediction: Bool) -> Segment?
  {
    let end = start + requested
    let h = end - start
    guard requested.isFinite, requested > 0, h.isFinite, h > 0,
      let k1 = derivative(initial, time: start, duration: h, plan: plan, stock: stock, source: source, freePrediction: freePrediction),
      let k2 = derivative(adding(initial, k1.values, h * 0.5), time: start + h * 0.5,
        duration: h, plan: plan, stock: stock, source: source, freePrediction: freePrediction),
      let k3 = derivative(adding(initial, k2.values, h * 0.5), time: start + h * 0.5,
        duration: h, plan: plan, stock: stock, source: source, freePrediction: freePrediction),
      let k4 = derivative(adding(initial, k3.values, h), time: start + h,
        duration: h, plan: plan, stock: stock, source: source, freePrediction: freePrediction)
    else { return nil }
    let slopes = [k1.values, k2.values, k3.values, k4.values]
    let forces = [k1.forces, k2.forces, k3.forces, k4.forces]
    guard let parentSpeed = pointSpeed(initial: initial, slopes: slopes, base: 0, components: plan.parentComponents,
      body: plan.parent, h: h, source: source, initialRodMetres: plan.work.rodMetres),
      let podSpeed = pointSpeed(initial: initial, slopes: slopes, base: 18, components: plan.podComponents,
        body: plan.pod, h: h, source: source, initialRodMetres: plan.work.rodMetres)
    else { return nil }
    return .init(start: start, end: end, integrationDuration: h,
      initial: initial, slopes: slopes, forces: forces,
      parentSpeed: parentSpeed, podSpeed: podSpeed)
  }

  private static func derivative(_ values: [Double], time: Double, duration: Double,
    plan: CurrentNewtDrivePlan, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    freePrediction: Bool) -> Derivative?
  {
    guard let state = sample(coordinates: values, at: time, plan: plan, stock: stock, source: source,
        boundaryForDerivative: true),
      let forces = CurrentNewtDriveForceOperator.response(plan: plan, source: source,
        parent: state.parent, pod: state.pod, parentComponents: state.parentComponents,
        podComponents: state.podComponents, work: state.work, duration: duration,
        freePrediction: freePrediction)
    else { return nil }
    var result = Array(repeating: 0.0, count: 41)
    for (base, body, accelerationBase) in [(0, state.parent, 0), (18, state.pod, 6)] {
      put(body.velocity, in: &result, at: base)
      put(body.angularVelocity.cross(body.pose.orientation.x), in: &result, at: base + 3)
      put(body.angularVelocity.cross(body.pose.orientation.y), in: &result, at: base + 6)
      put(body.angularVelocity.cross(body.pose.orientation.z), in: &result, at: base + 9)
      put(vector(forces.acceleration, at: accelerationBase), in: &result, at: base + 12)
      put(vector(forces.acceleration, at: accelerationBase + 3), in: &result, at: base + 15)
    }
    result[36] = state.work.rodVelocity
    result[37] = forces.acceleration[12]
    let impulseRate = zip(forces.surfaces, forces.normalForces).reduce(Vector3(0, 0, 0)) {
      $0 + $1.0.normal * $1.1
    }
    put(impulseRate, in: &result, at: 38)
    return result.allSatisfy(\.isFinite) ? .init(values: result, forces: forces) : nil
  }

  private static func sample(coordinates values: [Double], at time: Double,
    plan: CurrentNewtDrivePlan, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    boundaryForDerivative: Bool = false) -> Sample?
  {
    guard values.count == 41, values.allSatisfy(\.isFinite),
      let parent = body(values, base: 0), let pod = body(values, base: 18),
      parent.angularVelocity.length <= source.maximumAngularSpeed,
      pod.angularVelocity.length <= source.maximumAngularSpeed
    else { return nil }
    // Boundary extension is used ONLY by the pure first-root predictor. An
    // accepted sample never clips a coordinate; the root then owns the stop.
    let rod = boundaryForDerivative ? min(values[36], source.stroke) : values[36]
    let work = CurrentNewtKitStock.WorkState(loweredFraction: plan.work.loweredFraction,
      rodMetres: rod, rodVelocity: values[37], guideWorkJoules: plan.work.guideWorkJoules,
      ejectionWorkJoules: source.maximumForceNewtons * rod)
    let incoming = boundaryForDerivative && rod == source.stroke && work.rodVelocity > 0
    let parentComponents: [CurrentNewtKitComponent]?
    if incoming {
      parentComponents = source.rodStopComponents(stock: stock, work: work, at: time,
        parent: parent, load: plan.load)
    } else {
      parentComponents = source.components(stock: stock, work: work, at: time,
        parent: parent, load: plan.load)
    }
    guard (source.validWork(work) || incoming), work.rodMetres >= plan.work.rodMetres,
      work.ejectionWorkJoules - plan.work.ejectionWorkJoules <= plan.maximumAdditionalWorkJoules,
      work.ejectionWorkJoules - plan.work.ejectionWorkJoules <= plan.maximumAvailableMechanicalJoules,
      let parentComponents,
      let podComponents = source.components(receipt: plan.receipt, at: time, pod: pod)
    else { return nil }
    return .init(time: time, parent: parent, pod: pod, work: work,
      parentComponents: parentComponents, podComponents: podComponents,
      impulseOnPod: vector(values, at: 38))
  }

  /// Only the exact authenticated rod/shoe components can use this full-solid
  /// support/finite-force proof. Every other independent pair stays native.
  func provesGovernedPair(rodID: String, shoeID: String) -> Bool {
    guard !freePrediction, let rod = source.retainedParts.first(where: { $0.id == rodID }),
      let shoe = source.releasedParts.first(where: { $0.id == shoeID }),
      rodID.hasPrefix("moving-rod-"), shoeID.hasPrefix("portable-thrust-shoe-"),
      let shoeMesh = shoe.collisionMesh
    else { return false }
    guard segments.allSatisfy({ segment in
      guard CurrentNewtDriveContactPolynomial.boundsTotalForce(
        segment.forces.map { $0.normalForces.reduce(0, +) }, maximum: plan.maximumForceNewtons,
        fraction: (segment.end - segment.start) / segment.integrationDuration)
      else { return false }
      let stageForces = segment.forces.map { response -> Double in
        guard let index = response.surfaces.firstIndex(where: {
          $0.rodID == rodID && $0.shoeID == shoeID
        }) else { return 0 }
        return response.normalForces[index]
      }
      return CurrentNewtDriveContactPolynomial.proves(
        initial: segment.initial, slopes: segment.slopes, duration: segment.integrationDuration,
        fraction: (segment.end - segment.start) / segment.integrationDuration, rod: rod, shoe: shoeMesh, stroke: source.stroke, stageForces: stageForces,
        maximumForce: plan.maximumForceNewtons)
    }) else { return false }
    guard let stop else { return true }
    return stop.provesOpening(rodID: rodID, shoeID: shoeID)
  }

  var rodStopTime: Double? { stop?.time }
  var rodStopIncoming: Sample? { stop?.incoming }
  var rodStopAfter: Sample? { stop?.after }

  private struct Stop: Sendable {
    let time: Double
    let end: Double
    let incoming: Sample
    let after: Sample
    let parentFlow: CurrentNewtRigidCoast?
    let podFlow: CurrentNewtRigidCoast?
    let parentSpeed: Double
    let podSpeed: Double
    let plan: CurrentNewtDrivePlan
    let stock: CurrentNewtKitStock
    let source: CurrentNewtKitSource

    func sample(at time: Double) -> Sample? {
      guard time >= self.time, time <= end else { return nil }
      if time == self.time { return after }
      guard let parentFlow, let podFlow,
        let parent = parentFlow.state(at: time - self.time),
        let pod = podFlow.state(at: time - self.time),
        let parts = source.components(stock: stock, work: after.work, at: time,
          parent: parent, load: plan.load),
        let podParts = source.components(receipt: plan.receipt, at: time, pod: pod)
      else { return nil }
      return .init(time: time, parent: parent, pod: pod, work: after.work,
        parentComponents: parts, podComponents: podParts, impulseOnPod: after.impulseOnPod)
    }

    func provesOpening(rodID: String, shoeID: String) -> Bool {
      if end == time { return true }
      guard let parentFlow, let podFlow,
        let rod = after.parentComponents.first(where: { $0.id == rodID }),
        let shoe = after.podComponents.first(where: { $0.id == shoeID }) else { return false }
      return CurrentNewtOpeningContactProof.proves(rod: rod, shoe: shoe,
        parent: parentFlow, pod: podFlow, duration: end - time, source: source)
    }
  }

  /// Bound the actual add/subtract/divide round trip through the absolute
  /// clock. Fractional root precision alone is insufficient late in a career.
  static func strokeClockFractionError(start: Double, duration: Double, fraction: Double) -> Double? {
    guard start.isFinite, start >= 0, duration.isFinite, duration > 0,
      fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
    let product = fraction * duration
    let time = start + product
    let difference = time - start
    let represented = difference / duration
    let error = (product.ulp + time.ulp + difference.ulp) / duration + represented.ulp
    return error.isFinite && error >= 0 ? error.nextUp : nil
  }

  /// Locate the first physical prismatic limit on the SAME accepted dense
  /// candidate. Only its proven prefix survives; the real brake owns the rest.
  private static func strokeEvent(in segment: Segment, plan: CurrentNewtDrivePlan,
    stock: CurrentNewtKitStock, source: CurrentNewtKitSource) -> (prefix: Segment, stop: Stop)?
  {
    let h = segment.integrationDuration
    let k = segment.slopes.map { $0[36] }
    let a = h * k[0]
    let b = h * (-1.5 * k[0] + k[1] + k[2] - 0.5 * k[3])
    let c = h * (2.0 / 3) * (k[0] - k[1] - k[2] + k[3])
    func q(_ u: Double) -> Double { segment.initial[36] + u * (a + u * (b + u * c)) }
    func rate(_ u: Double) -> Double { a + 2 * b * u + 3 * c * u * u }
    var rates = [rate(0), rate(1)]
    if c != 0 {
      let turning = -b / (3 * c)
      if turning > 0 && turning < 1 { rates.append(rate(turning)) }
    }
    guard segment.initial[36] < source.stroke, q(1) >= source.stroke,
      rates.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
    var lower = 0.0, upper = 1.0
    for _ in 0..<64 {
      let middle = (lower + upper) * 0.5
      if middle == lower || middle == upper { break }
      if q(middle) < source.stroke { lower = middle } else { upper = middle }
    }
    guard q(lower) <= source.stroke, q(upper) >= source.stroke else { return nil }
    let time = segment.start + upper * h
    guard time > segment.start, time <= segment.end else { return nil }
    var incomingValues = segment.coordinates(at: time)
    // This is the coordinate equation of the certified first-limit event,
    // not a late clamp of an already accepted overstroke endpoint.
    guard let clockFractionError = strokeClockFractionError(start: segment.start,
      duration: h, fraction: upper) else { return nil }
    let uncertainty = rates.max()! * ((upper - lower) + clockFractionError)
      + 128 * Double.ulpOfOne * max(1, abs(q(upper)))
    guard abs(incomingValues[36] - source.stroke) <= uncertainty else { return nil }
    incomingValues[36] = source.stroke
    guard let incoming = sample(coordinates: incomingValues, at: time, plan: plan,
      stock: stock, source: source, boundaryForDerivative: true), incoming.work.rodVelocity > 0
    else { return nil }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: incoming.work.loweredFraction,
      rodMetres: source.stroke, rodVelocity: 0, guideWorkJoules: incoming.work.guideWorkJoules,
      ejectionWorkJoules: source.maximumForceNewtons * source.stroke)
    guard source.validWork(work), let mass = source.loadedParentMass(work: work, load: plan.load),
      let braked = CurrentNewtKitBrake.retainedState(components: incoming.parentComponents,
        mass: mass, before: incoming.parent, maximumAngularSpeed: source.maximumAngularSpeed),
      let parts = source.components(stock: stock, work: work, at: time, parent: braked, load: plan.load),
      let before = CurrentNewtComponentMechanics.momentum(incoming.parentComponents,
        about: incoming.parent.pose.position),
      let after = CurrentNewtComponentMechanics.momentum(parts, about: incoming.parent.pose.position),
      conserved(before: before, after: after, paidWork: 0)
    else { return nil }
    let state = Sample(time: time, parent: braked, pod: incoming.pod, work: work,
      parentComponents: parts, podComponents: incoming.podComponents,
      impulseOnPod: incoming.impulseOnPod)
    let remaining = plan.interval.end - time
    let parentFlow: CurrentNewtRigidCoast?, podFlow: CurrentNewtRigidCoast?
    var parentSpeed = 0.0, podSpeed = 0.0
    if remaining > 0 {
      guard let p = CurrentNewtRigidCoast(initial: braked, mass: mass, duration: remaining,
        maximumAngularSpeed: source.maximumAngularSpeed),
        let b = CurrentNewtRigidCoast(initial: incoming.pod, mass: plan.podMass, duration: remaining,
          maximumAngularSpeed: source.maximumAngularSpeed) else { return nil }
      func extent(_ components: [CurrentNewtKitComponent], state: CurrentNewtKitReceipt.BodyState) -> Double {
        components.map { ($0.pose.position - state.pose.position).length
          + ($0.collisionMesh?.vertices.map(\.length).max() ?? 0) }.max() ?? .infinity
      }
      guard let ps = p.pointSpeedBound(localExtent: extent(parts, state: braked)),
        let bs = b.pointSpeedBound(localExtent: extent(incoming.podComponents, state: incoming.pod))
      else { return nil }
      parentFlow = p; podFlow = b; parentSpeed = ps; podSpeed = bs
    } else { parentFlow = nil; podFlow = nil }
    let stop = Stop(time: time, end: plan.interval.end, incoming: incoming, after: state,
      parentFlow: parentFlow, podFlow: podFlow, parentSpeed: parentSpeed, podSpeed: podSpeed,
      plan: plan, stock: stock, source: source)
    let prefix = Segment(start: segment.start, end: time, integrationDuration: h,
      initial: segment.initial, slopes: segment.slopes, forces: segment.forces,
      parentSpeed: segment.parentSpeed, podSpeed: segment.podSpeed)
    return (prefix, stop)
  }

  private static func conserved(before: CurrentNewtComponentMomentum,
    after: CurrentNewtComponentMomentum, paidWork: Double) -> Bool
  {
    let linearRoundoff = 128 * Double.ulpOfOne
      * max(1, before.linearMomentum.length + after.linearMomentum.length)
    let angularRoundoff = 128 * Double.ulpOfOne
      * max(1, before.angularMomentum.length + after.angularMomentum.length)
    let energyRoundoff = 128 * Double.ulpOfOne
      * max(1, before.kineticEnergyJoules + after.kineticEnergyJoules)
    return abs(before.massKilograms - after.massKilograms) <= 1e-8
      && (before.linearMomentum - after.linearMomentum).length <= 1e-6 + linearRoundoff
      && (before.angularMomentum - after.angularMomentum).length <= 1e-6 + angularRoundoff
      && paidWork.isFinite && paidWork >= 0
      && after.kineticEnergyJoules - before.kineticEnergyJoules <= paidWork + 1e-6 + energyRoundoff
  }

  /// Conservative speed of the actual dense polynomial in ONE common
  /// Galilean query frame, including basis deformation and internal rod travel.
  func pointSpeedBound(parent: Bool, relativeTo reference: Vector3) -> Double? {
    var result = 0.0
    for segment in segments {
      guard let speed = Self.pointSpeed(initial: segment.initial, slopes: segment.slopes,
        base: parent ? 0 : 18,
        components: parent ? plan.parentComponents : plan.podComponents,
        body: parent ? plan.parent : plan.pod, h: segment.integrationDuration,
        source: source, initialRodMetres: plan.work.rodMetres, relativeTo: reference) else { return nil }
      result = max(result, speed)
    }
    if let stop, stop.end > stop.time {
      guard let flow = parent ? stop.parentFlow : stop.podFlow else { return nil }
      let state = parent ? stop.after.parent : stop.after.pod
      let parts = parent ? stop.after.parentComponents : stop.after.podComponents
      let extent = parts.map { ($0.pose.position - state.pose.position).length
        + ($0.collisionMesh?.vertices.map(\.length).max() ?? 0) }.max() ?? .infinity
      guard let speed = flow.pointSpeedBound(localExtent: extent, relativeTo: reference)
      else { return nil }
      result = max(result, speed)
    }
    return result.isFinite ? result.nextUp : nil
  }

  private static func pointSpeed(initial: [Double], slopes: [[Double]], base: Int,
    components: [CurrentNewtKitComponent], body: CurrentNewtKitReceipt.BodyState,
    h: Double, source: CurrentNewtKitSource, initialRodMetres: Double,
    relativeTo reference: Vector3 = .init(0, 0, 0)) -> Double?
  {
    guard initial.count == 41, initial.allSatisfy(\.isFinite),
      let translation = CurrentNewtQueryFrame.denseDerivativeBound(slopes: slopes,
        at: base, relativeTo: reference) else { return nil }
    var derivativeSquared = 0.0, valueSquared = 0.0, maximumStageRotation = 0.0
    for axis in [3, 6, 9] {
      guard let rate = CurrentNewtQueryFrame.denseDerivativeBound(slopes: slopes,
        at: base + axis),
        let value = CurrentNewtQueryFrame.denseValueBound(initial: vector(initial, at: base + axis),
          slopes: slopes, at: base + axis, duration: h) else { return nil }
      derivativeSquared += rate * rate; valueSquared += value * value
      maximumStageRotation = max(maximumStageRotation,
        slopes.map { vector($0, at: base + axis).length }.max() ?? .infinity)
    }
    // Retain the original segment rotation gate; a better speed certificate
    // does not widen the accepted force-integration domain.
    guard maximumStageRotation.isFinite, 4 * h * maximumStageRotation < 0.01 else { return nil }
    let r = body.pose.orientation
    let x = r.y.cross(r.z), y = r.z.cross(r.x), z = r.x.cross(r.y)
    let determinant = r.x.dot(x)
    guard determinant.isFinite, determinant > 0 else { return nil }
    // Frobenius norm bounds the inverse basis operator; no exact unit-basis
    // assumption is made for the source snapshot or its unprojected RK curve.
    let inverseNorm = sqrt(x.dot(x) + y.dot(y) + z.dot(z)) / determinant
    let extent = components.map { component in
      (component.pose.position - body.pose.position).length
        + (component.collisionMesh?.vertices.map(\.length).max() ?? 0)
    }.max() ?? 0
    let travel = base == 0 ? (source.retainedParts.map {
      ($0.extended.centreOfMassMetres - $0.lowered.centreOfMassMetres).length
    }.max() ?? 0) : 0
    var internalSpeed = 0.0, internalTravel = 0.0
    if base == 0 {
      guard source.stroke.isFinite, source.stroke > 0,
        let rodRate = CurrentNewtQueryFrame.denseDerivativeBound(
          slopes: slopes.map { [$0[36], 0, 0] }, at: 0),
        let rodOffset = CurrentNewtQueryFrame.denseValueBound(
          initial: .init(initial[36] - initialRodMetres, 0, 0),
          slopes: slopes.map { [$0[36], 0, 0] }, at: 0, duration: h) else { return nil }
      internalSpeed = rodRate * (travel / source.stroke)
      internalTravel = rodOffset * (travel / source.stroke)
    }
    let bound = translation + sqrt(derivativeSquared) * (extent * inverseNorm + internalTravel)
      + sqrt(valueSquared) * internalSpeed
    let error = 256 * Double.ulpOfOne * max(1, bound)
    return bound.isFinite && bound >= 0 ? (bound + error).nextUp : nil
  }

  private static func coordinates(parent: CurrentNewtKitReceipt.BodyState,
    pod: CurrentNewtKitReceipt.BodyState, work: CurrentNewtKitStock.WorkState) -> [Double]
  {
    var result = Array(repeating: 0.0, count: 41)
    for (base, body) in [(0, parent), (18, pod)] {
      put(body.pose.position, in: &result, at: base)
      put(body.pose.orientation.x, in: &result, at: base + 3)
      put(body.pose.orientation.y, in: &result, at: base + 6)
      put(body.pose.orientation.z, in: &result, at: base + 9)
      put(body.velocity, in: &result, at: base + 12)
      put(body.angularVelocity, in: &result, at: base + 15)
    }
    result[36] = work.rodMetres; result[37] = work.rodVelocity
    return result
  }

  private static func body(_ values: [Double], base: Int) -> CurrentNewtKitReceipt.BodyState? {
    var orientation = Basis3()
    orientation.x = vector(values, at: base + 3)
    orientation.y = vector(values, at: base + 6)
    orientation.z = vector(values, at: base + 9)
    let state = CurrentNewtKitReceipt.BodyState(
      pose: .init(position: vector(values, at: base), orientation: orientation),
      velocity: vector(values, at: base + 12), angularVelocity: vector(values, at: base + 15))
    return state.structurallyValid ? state : nil
  }

  private static func adding(_ a: [Double], _ b: [Double], _ scale: Double) -> [Double] {
    zip(a, b).map { $0 + $1 * scale }
  }
  private static func vector(_ values: [Double], at index: Int) -> Vector3 {
    .init(values[index], values[index + 1], values[index + 2])
  }
  private static func put(_ value: Vector3, in values: inout [Double], at index: Int) {
    values[index] = value.x; values[index + 1] = value.y; values[index + 2] = value.z
  }
}
