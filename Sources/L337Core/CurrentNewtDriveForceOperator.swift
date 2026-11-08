import Foundation

/// Instantaneous finite-force response. No pose, stock, clock or receipt is
/// committed here; the native curve/contact owner must validate its whole interval.
struct CurrentNewtDriveForceResponse: Sendable {
  let acceleration: [Double]
  let surfaces: [CurrentNewtDriveSurface]
  let normalForces: [Double]
  let netActuatorForce: Double
}

enum CurrentNewtDriveForceOperator {
  static func response(
    plan: CurrentNewtDrivePlan, source: CurrentNewtKitSource,
    parent: CurrentNewtKitReceipt.BodyState, pod: CurrentNewtKitReceipt.BodyState,
    parentComponents: [CurrentNewtKitComponent], podComponents: [CurrentNewtKitComponent],
    work: CurrentNewtKitStock.WorkState, duration: Double, freePrediction: Bool = false
  ) -> CurrentNewtDriveForceResponse? {
    guard plan.interval.valid, duration.isFinite, duration > 0,
      duration <= plan.interval.end - plan.interval.start,
      (source.validWork(work) || incomingStrokeWork(work, source: source)), work.loweredFraction == 1,
      plan.maximumForceNewtons.isFinite, plan.maximumForceNewtons > 0,
      plan.maximumGuideFrictionNewtons.isFinite, plan.maximumGuideFrictionNewtons >= 0,
      plan.maximumGuideFrictionNewtons < plan.maximumForceNewtons,
      plan.strokeLimitMetres == source.stroke,
      plan.targetRelativeSpeedMetresPerSecond == source.releaseSpeed
    else { return nil }
    let direction = parent.pose.orientation.apply(source.direction)
    let rods = parentComponents.filter { $0.id.hasPrefix("moving-rod-") }
    let shoes = podComponents.filter { $0.id.hasPrefix("portable-thrust-shoe-") }
    guard rods.count == 2, shoes.count == 2,
      let metric = CurrentNewtDriveMassOperator(parent: parent, pod: pod,
        parentComponents: parentComponents, podComponents: podComponents,
        rodIDs: Set(rods.map(\.id)), direction: direction)
    else { return nil }
    var surfaces: [CurrentNewtDriveSurface] = []
    // Only the drive factory's strictly separated opening selects a free
    // prediction. It contributes no shoe reaction; native solid queries must
    // prove that prefix and find any later contact before it can be retained.
    if !freePrediction {
      for rod in rods {
        let matches = shoes.compactMap { CurrentNewtDriveContact.surface(rod: rod, shoe: $0, source: source) }
        guard matches.count == 1, let surface = matches.first else { return nil }
        let numerical = 128 * Double.ulpOfOne * max(1, surface.point.length)
        // Positive gaps are ordinary free motion; an initial closing collision
        // needs its own actual native impact, never actuator-work credit.
        if surface.gapMetres <= numerical {
          guard surface.relativeNormalVelocity >= -1e-7 else { return nil }
          // A separating pair carries no unilateral force. The continuous native
          // curve must still prove free separation or find its later re-contact.
          if surface.relativeNormalVelocity <= 1e-7 { surfaces.append(surface) }
        }
      }
    }
    guard Set(surfaces.map(\.shoeID)).count == surfaces.count else { return nil }
    let velocities = CurrentNewtDriveMassOperator.velocities(parent: parent, pod: pod,
      rodVelocity: work.rodVelocity)
    guard let momentum = metric.momentum(velocities: velocities) else { return nil }
    let parentP = Vector3(momentum[0], momentum[1], momentum[2])
    let podP = Vector3(momentum[6], momentum[7], momentum[8])
    let parentTransport = parent.velocity.cross(parentP) * -1
    let podTransport = pod.velocity.cross(podP) * -1
    let axisRate = parent.angularVelocity.cross(direction)
    let centrifugal = rods.reduce(0.0) { sum, rod in
      let mass = rod.massProperties
      let velocity = rod.velocity + rod.angularVelocity.cross(
        rod.pose.orientation.apply(mass.centreOfMassMetres))
      return sum + mass.massKilograms * velocity.dot(axisRate)
    }
    var bias = Array(repeating: 0.0, count: CurrentNewtDriveMassOperator.dimension)
    bias[3] = parentTransport.x; bias[4] = parentTransport.y; bias[5] = parentTransport.z
    bias[9] = podTransport.x; bias[10] = podTransport.y; bias[11] = podTransport.z
    bias[12] = centrifugal
    for row in bias.indices {
      for column in velocities.indices {
        bias[row] -= metric.derivative[row * CurrentNewtDriveMassOperator.dimension + column]
          * velocities[column]
      }
    }
    var jacobians: [[Double]] = []
    var jacobianRates: [[Double]] = []
    for surface in surfaces {
      guard let row = CurrentNewtDriveMassOperator.contactJacobian(
        point: surface.point, normal: surface.normal, direction: direction,
        parent: parent, pod: pod)
      else { return nil }
      let parentLever = surface.point - parent.pose.position
      let podLever = surface.point - pod.pose.position
      let pointVelocity = parent.velocity + parent.angularVelocity.cross(parentLever)
        + direction * work.rodVelocity
      let parentLeverRate = pointVelocity - parent.velocity
      let podLeverRate = pointVelocity - pod.velocity
      let normalRate = pod.angularVelocity.cross(surface.normal)
      let parentTorqueRate = parentLeverRate.cross(surface.normal) + parentLever.cross(normalRate)
      let podTorqueRate = podLeverRate.cross(surface.normal) + podLever.cross(normalRate)
      jacobians.append(row)
      jacobianRates.append([-normalRate.x, -normalRate.y, -normalRate.z,
        -parentTorqueRate.x, -parentTorqueRate.y, -parentTorqueRate.z,
        normalRate.x, normalRate.y, normalRate.z,
        podTorqueRate.x, podTorqueRate.y, podTorqueRate.z,
        -normalRate.dot(direction) - surface.normal.dot(axisRate)])
    }
    func evaluate(_ netForce: Double) -> (acceleration: [Double], forces: [Double])? {
      var right = bias
      right[12] += netForce
      guard let free = metric.solve(right) else { return nil }
      let derivatives = zip(jacobians, jacobianRates).map { row, rate in
        dot(row, free) + dot(rate, velocities)
      }
      let inverseRows = jacobians.compactMap(metric.solve)
      guard inverseRows.count == jacobians.count,
        let forces = unilateralForces(bias: derivatives,
          matrix: jacobians.map { row in inverseRows.map { dot(row, $0) } })
      else { return nil }
      var acceleration = free
      for index in forces.indices {
        for column in acceleration.indices { acceleration[column] += inverseRows[index][column] * forces[index] }
      }
      return (acceleration, forces)
    }
    // The source permits finite governor dissipation. Brake the finite rod mass
    // before its stop; the independent pod receives no prescribed speed or pose.
    let rodMass = rods.reduce(0.0) { $0 + $1.massProperties.massKilograms }
    let remaining = max(0, plan.strokeLimitMetres - work.rodMetres)
    let stoppingSpeed = sqrt(2 * plan.maximumForceNewtons * remaining / rodMass)
    let target = min(plan.targetRelativeSpeedMetresPerSecond, stoppingSpeed)
    let desiredAcceleration = (target - work.rodVelocity) / duration
    var lower = -plan.maximumForceNewtons
    var upper = plan.maximumForceNewtons - plan.maximumGuideFrictionNewtons
    guard let minimum = evaluate(lower), let maximum = evaluate(upper) else { return nil }
    let selected: Double
    if maximum.acceleration[12] <= desiredAcceleration { selected = upper }
    else if minimum.acceleration[12] >= desiredAcceleration { selected = lower }
    else {
      // The two-contact complementarity operator is monotone along this one
      // physical actuator coordinate. All candidate forces retain source bounds.
      for _ in 0..<32 {
        let middle = (lower + upper) * 0.5
        guard let result = evaluate(middle) else { return nil }
        if result.acceleration[12] > desiredAcceleration { upper = middle }
        else { lower = middle }
      }
      selected = (lower + upper) * 0.5
    }
    guard let result = evaluate(selected), result.acceleration.allSatisfy(\.isFinite),
      result.forces.allSatisfy({ $0.isFinite && $0 >= 0 }),
      result.forces.reduce(0, +) <= plan.maximumForceNewtons + 1e-6
    else { return nil }
    return .init(acceleration: result.acceleration, surfaces: surfaces,
      normalForces: result.forces, netActuatorForce: selected)
  }

  /// Dedicated incoming joint boundary, never a stock observation. The native
  /// event locates the first exact limit and applies the real internal brake.
  private static func incomingStrokeWork(_ work: CurrentNewtKitStock.WorkState,
    source: CurrentNewtKitSource) -> Bool {
    guard work.rodMetres == source.stroke, work.rodVelocity > 0,
      work.rodVelocity <= source.releaseSpeed else { return false }
    return source.validWork(.init(loweredFraction: work.loweredFraction,
      rodMetres: work.rodMetres, rodVelocity: 0, guideWorkJoules: work.guideWorkJoules,
      ejectionWorkJoules: work.ejectionWorkJoules))
  }

  private static func dot(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
  }

  /// At most two original rod/shoe contacts, with nonnegative normal force.
  private static func unilateralForces(bias: [Double], matrix: [[Double]]) -> [Double]? {
    guard bias.count <= 2, matrix.count == bias.count,
      matrix.allSatisfy({ $0.count == bias.count && $0.allSatisfy(\.isFinite) }),
      bias.allSatisfy(\.isFinite)
    else { return nil }
    if bias.isEmpty { return [] }
    if bias.allSatisfy({ $0 >= 0 }) { return Array(repeating: 0, count: bias.count) }
    for active in bias.indices {
      guard matrix[active][active] > 0 else { return nil }
      let force = -bias[active] / matrix[active][active]
      if force >= 0 && bias.indices.allSatisfy({
        $0 == active || bias[$0] + matrix[$0][active] * force >= 0
      }) {
        var result = Array(repeating: 0.0, count: bias.count)
        result[active] = force
        return result
      }
    }
    guard bias.count == 2 else { return nil }
    let determinant = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
    guard determinant.isFinite, determinant > 0 else { return nil }
    let result = [(-bias[0] * matrix[1][1] + bias[1] * matrix[0][1]) / determinant,
      (-bias[1] * matrix[0][0] + bias[0] * matrix[1][0]) / determinant]
    return result.allSatisfy({ $0.isFinite && $0 >= 0 }) ? result : nil
  }
}
