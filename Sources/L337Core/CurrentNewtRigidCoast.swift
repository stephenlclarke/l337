import Foundation

/// Pure rigid-body mechanics for an already authenticated current mass. This
/// supplies one native trajectory; it installs no actor, hardware or clock leg.
struct CurrentNewtRigidCoast: Sendable {
  let initial: CurrentNewtKitReceipt.BodyState
  let mass: CurrentNewtKitReceipt.MassProperties
  let duration: Double
  let maximumAngularSpeed: Double
  private let centre: Vector3
  private let centreVelocity: Vector3
  private let spin: Vector3
  private let angularBound: Double
  private let rotationStep: Double
  private let principalRotation: Bool
  private let angularGrowth: Double

  var maximumWorldAngularSpeed: Double { angularBound }
  var maximumWorldAngularAcceleration: Double { angularGrowth * angularBound * angularBound }

  init?(initial: CurrentNewtKitReceipt.BodyState, mass: CurrentNewtKitReceipt.MassProperties,
    duration: Double, maximumAngularSpeed: Double)
  {
    guard initial.structurallyValid, mass.structurallyValid,
      duration.isFinite, duration > 0,
      maximumAngularSpeed.isFinite, maximumAngularSpeed > 0,
      initial.angularVelocity.length <= maximumAngularSpeed
    else { return nil }
    self.initial = initial; self.mass = mass; self.duration = duration
    self.maximumAngularSpeed = maximumAngularSpeed
    centre = CurrentNewtKitMass.centre(mass, state: initial)
    centreVelocity = CurrentNewtKitMass.centreVelocity(mass, state: initial)
    spin = CurrentNewtKitMass.spin(mass, state: initial)
    principalRotation = initial.angularVelocity.cross(spin) == Vector3(0, 0, 0)
    let tensor = Self.worldTensor(mass.inertiaKgM2, rotation: initial.pose.orientation)
    guard centre.finite, centreVelocity.finite, spin.finite,
      let x = CurrentNewtKitMass.solve(tensor, .init(1, 0, 0)),
      let y = CurrentNewtKitMass.solve(tensor, .init(0, 1, 0)),
      let z = CurrentNewtKitMass.solve(tensor, .init(0, 0, 1))
    else { return nil }
    let inverseNorm = sqrt(x.dot(x) + y.dot(y) + z.dot(z))
    let isotropic = (tensor[0] + tensor[4] + tensor[8]) / 3
    let anisotropy = tensor.indices.reduce(0.0) { sum, index in
      let value = tensor[index] - (index == 0 || index == 4 || index == 8 ? isotropic : 0)
      return sum + value * value
    }
    let tensorNorm = sqrt(tensor.reduce(0.0) { $0 + $1 * $1 })
    // Euler: |omegaDot| <= ||I^-1|| ||I-lambda*1|| |omega|^2.
    // These world tensor norms are invariant under the torque-free rotation.
    // The isotropic term cancels in omega cross I*omega, so an isotropic
    // body retains its genuine spin instead of failing an inflated |H| bound.
    let growth = inverseNorm * (sqrt(anisotropy) + 512 * Double.ulpOfOne * tensorNorm)
    angularGrowth = growth
    let initialSpeed = initial.angularVelocity.length
    let denominator = 1 - growth * initialSpeed * duration
    guard growth.isFinite else { return nil }
    let finiteHorizon = denominator > 0 ? (initialSpeed / denominator).nextUp : .infinity
    // For a <= each principal inertia <= b, H^2 <= (a+b)*2E-a*b*omega^2.
    // The two conserved quadratics therefore also give a duration-independent
    // bound, including long genuine archive gaps and isotropic/principal spin.
    var lower = Double.infinity, upper = 0.0
    for row in 0..<3 {
      let off = (0..<3).filter { $0 != row }.reduce(0.0) {
        ($0 + max(abs(tensor[row * 3 + $1]), abs(tensor[$1 * 3 + row]))).nextUp
      }
      lower = min(lower, (tensor[row * 3 + row] - off).nextDown)
      upper = max(upper, (tensor[row * 3 + row] + off).nextUp)
    }
    if lower <= 0 { lower = (1 / inverseNorm).nextDown }
    let twoEnergy = initial.angularVelocity.dot(spin)
    let energyError = 128 * Double.ulpOfOne * initialSpeed * spin.length
    let spinSquared = spin.dot(spin)
    let spinLower = max(0, spinSquared.nextDown - 128 * Double.ulpOfOne * spinSquared)
    let numerator = (((lower + upper).nextUp * (twoEnergy + energyError).nextUp).nextUp - spinLower).nextUp
    let product = (lower * upper).nextDown
    guard lower > 0, upper.isFinite, numerator >= 0, product > 0 else { return nil }
    let globalBound = sqrt((numerator / product).nextUp).nextUp
    angularBound = principalRotation ? initialSpeed : min(finiteHorizon, globalBound)
    guard angularBound.isFinite, angularBound <= maximumAngularSpeed else { return nil }
    let lipschitz = 8 * inverseNorm * tensorNorm * maximumAngularSpeed
    rotationStep = min(0.1, min(0.125 / max(lipschitz, Double.leastNormalMagnitude),
      0.005 / max(angularBound, Double.leastNormalMagnitude)))
    guard rotationStep.isFinite, rotationStep > 0 else { return nil }
  }

  func state(at time: Double) -> CurrentNewtKitReceipt.BodyState? {
    guard time.isFinite, time >= 0, time <= duration else { return nil }
    if time == 0 { return initial }
    if principalRotation {
      // This exact source-tensor eigenvector condition proves constant omega;
      // it is not a fallback for nonprincipal motion or an exhausted work budget.
      let seed = HullSceneMotion(start: initial.pose, end: initial.pose,
        initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
        worldAngularVelocity: initial.angularVelocity, duration: time, playerRadius: 0)
      let rotation = HullSweepSafety.shipPose(seed, at: time).orientation
      let lever = rotation.apply(mass.centreOfMassMetres)
      let state = CurrentNewtKitReceipt.BodyState(
        pose: .init(position: centre + centreVelocity * time - lever, orientation: rotation),
        velocity: centreVelocity - initial.angularVelocity.cross(lever),
        angularVelocity: initial.angularVelocity)
      return state.structurallyValid ? state : nil
    }
    var rotation = initial.pose.orientation
    var elapsed = 0.0
    var count = 0
    while elapsed < time {
      // A finite work budget refuses without modifying the archive. The
      // requested physical duration is never clipped or treated as completed.
      guard count < 65_536 else { return nil }
      let h = min(rotationStep, time - elapsed)
      guard elapsed + h > elapsed else { return nil }
      guard let k1 = derivative(rotation),
        let k2 = derivative(adding(rotation, k1, h * 0.5)),
        let k3 = derivative(adding(rotation, k2, h * 0.5)),
        let k4 = derivative(adding(rotation, k3, h))
      else { return nil }
      rotation.x = rotation.x + (k1.x + k2.x * 2 + k3.x * 2 + k4.x) * (h / 6)
      rotation.y = rotation.y + (k1.y + k2.y * 2 + k3.y * 2 + k4.y) * (h / 6)
      rotation.z = rotation.z + (k1.z + k2.z * 2 + k3.z * 2 + k4.z) * (h / 6)
      elapsed += h; count += 1
    }
    guard rotation.validRotation, let omega = angularVelocity(rotation) else { return nil }
    let lever = rotation.apply(mass.centreOfMassMetres)
    let state = CurrentNewtKitReceipt.BodyState(
      pose: .init(position: centre + centreVelocity * time - lever, orientation: rotation),
      velocity: centreVelocity - omega.cross(lever), angularVelocity: omega)
    return state.structurallyValid ? state : nil
  }

  func pointSpeedBound(localExtent: Double, relativeTo reference: Vector3 = .init(0, 0, 0)) -> Double? {
    guard reference.finite, localExtent.isFinite, localExtent >= 0 else { return nil }
    let bound = (centreVelocity - reference).length + 2 * angularBound
      * (mass.centreOfMassMetres.length + localExtent)
    let error = 256 * Double.ulpOfOne * max(1, centreVelocity.length + reference.length + bound)
    return bound.isFinite && error.isFinite ? (bound + error).nextUp : nil
  }

  func pointAccelerationBound(localExtent: Double) -> Double? {
    guard localExtent.isFinite, localExtent >= 0 else { return nil }
    let bound = 2 * (maximumWorldAngularAcceleration + angularBound * angularBound)
      * (mass.centreOfMassMetres.length + localExtent)
    return bound.isFinite ? bound.nextUp : nil
  }

  private func angularVelocity(_ rotation: Basis3) -> Vector3? {
    guard rotation.validRotation,
      let omega = CurrentNewtKitMass.solve(Self.worldTensor(mass.inertiaKgM2, rotation: rotation), spin)
    else { return nil }
    return omega.finite && omega.length <= maximumAngularSpeed ? omega : nil
  }

  private static func worldTensor(_ tensor: [Double], rotation: Basis3) -> [Double] {
    let axes = [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)]
    let columns = axes.map { axis in
      let local = Vector3(axis.dot(rotation.x), axis.dot(rotation.y), axis.dot(rotation.z))
      return rotation.apply(CurrentNewtKitMass.product(tensor, local))
    }
    return [columns[0].x, columns[1].x, columns[2].x,
      columns[0].y, columns[1].y, columns[2].y,
      columns[0].z, columns[1].z, columns[2].z]
  }

  private func derivative(_ rotation: Basis3) -> Basis3? {
    guard let omega = angularVelocity(rotation) else { return nil }
    var rate = Basis3()
    rate.x = omega.cross(rotation.x); rate.y = omega.cross(rotation.y); rate.z = omega.cross(rotation.z)
    return rate
  }

  private func adding(_ rotation: Basis3, _ rate: Basis3, _ scale: Double) -> Basis3 {
    var result = rotation
    result.x = rotation.x + rate.x * scale; result.y = rotation.y + rate.y * scale
    result.z = rotation.z + rate.z * scale
    return result
  }
}
