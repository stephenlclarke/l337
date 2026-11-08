import Foundation

/// Instantaneous kinetic operator for two independent rigid origins plus the
/// retained rods' one physical prismatic coordinate. This cannot advance a frame.
/// The actual owner must first authenticate the complete source component sets.
struct CurrentNewtDriveMassOperator: Sendable {
  static let dimension = 13
  let matrix: [Double]
  let derivative: [Double]

  init?(
    parent: CurrentNewtKitReceipt.BodyState, pod: CurrentNewtKitReceipt.BodyState,
    parentComponents: [CurrentNewtKitComponent], podComponents: [CurrentNewtKitComponent],
    rodIDs: Set<String>, direction: Vector3
  ) {
    guard parent.structurallyValid, pod.structurallyValid,
      !parentComponents.isEmpty, !podComponents.isEmpty,
      parentComponents.allSatisfy(\.validForCurrentNewtQuery),
      podComponents.allSatisfy(\.validForCurrentNewtQuery),
      !rodIDs.isEmpty, rodIDs.isSubset(of: Set(parentComponents.map(\.id))),
      direction.finite, abs(direction.dot(direction) - 1) <= 1e-9
    else { return nil }
    let axes = [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)]
    var values = Array(repeating: 0.0, count: Self.dimension * Self.dimension)
    var rates = values
    for (parts, state, base) in [(parentComponents, parent, 0), (podComponents, pod, 6)] {
      for part in parts {
        let mass = part.massProperties
        let centre = part.pose.systemPoint(mass.centreOfMassMetres)
        let lever = centre - state.pose.position
        var translation = Array(repeating: Vector3(0, 0, 0), count: Self.dimension)
        var rotation = translation
        var translationRate = translation
        let centreVelocity = part.velocity + part.angularVelocity.cross(
          part.pose.orientation.apply(mass.centreOfMassMetres))
        let leverRate = centreVelocity - state.velocity
        for axis in axes.indices {
          translation[base + axis] = axes[axis]
          translation[base + 3 + axis] = axes[axis].cross(lever)
          rotation[base + 3 + axis] = axes[axis]
          translationRate[base + 3 + axis] = axes[axis].cross(leverRate)
        }
        if base == 0 && rodIDs.contains(part.id) {
          translation[12] = direction
          translationRate[12] = parent.angularVelocity.cross(direction)
        }
        for row in 0..<Self.dimension {
          for column in row..<Self.dimension {
            let local = part.pose.shipVector(rotation[column])
            let tensor = part.pose.orientation.apply(CurrentNewtKitMass.product(mass.inertiaKgM2, local))
            let value = mass.massKilograms * translation[row].dot(translation[column])
              + rotation[row].dot(tensor)
            let spinAxisRate = part.angularVelocity.cross(rotation[column])
            let rotatedInputRate = part.pose.orientation.apply(CurrentNewtKitMass.product(
              mass.inertiaKgM2, part.pose.shipVector(spinAxisRate)))
            let tensorRate = part.angularVelocity.cross(tensor) - rotatedInputRate
            let rate = mass.massKilograms * (translationRate[row].dot(translation[column])
              + translation[row].dot(translationRate[column])) + rotation[row].dot(tensorRate)
            values[row * Self.dimension + column] += value
            rates[row * Self.dimension + column] += rate
            if column != row {
              values[column * Self.dimension + row] += value
              rates[column * Self.dimension + row] += rate
            }
          }
        }
      }
    }
    guard values.allSatisfy(\.isFinite), rates.allSatisfy(\.isFinite) else { return nil }
    matrix = values
    derivative = rates
    guard solve(Array(repeating: 0, count: Self.dimension)) != nil else { return nil }
  }

  func momentum(velocities: [Double]) -> [Double]? {
    guard velocities.count == Self.dimension, velocities.allSatisfy(\.isFinite) else { return nil }
    let result = (0..<Self.dimension).map { row in
      (0..<Self.dimension).reduce(0.0) { $0 + matrix[row * Self.dimension + $1] * velocities[$1] }
    }
    return result.allSatisfy(\.isFinite) ? result : nil
  }

  func solve(_ momentum: [Double]) -> [Double]? {
    let n = Self.dimension
    guard momentum.count == n, momentum.allSatisfy(\.isFinite) else { return nil }
    var lower = Array(repeating: 0.0, count: n * n)
    for row in 0..<n {
      for column in 0...row {
        var value = matrix[row * n + column]
        if column > 0 {
          for k in 0..<column { value -= lower[row * n + k] * lower[column * n + k] }
        }
        if row == column {
          guard value.isFinite, value > 0 else { return nil }
          lower[row * n + column] = sqrt(value)
        } else {
          lower[row * n + column] = value / lower[column * n + column]
        }
      }
    }
    var forward = Array(repeating: 0.0, count: n)
    for row in 0..<n {
      var value = momentum[row]
      if row > 0 { for k in 0..<row { value -= lower[row * n + k] * forward[k] } }
      forward[row] = value / lower[row * n + row]
    }
    var result = forward
    for row in (0..<n).reversed() {
      var value = forward[row]
      if row + 1 < n { for k in (row + 1)..<n { value -= lower[k * n + row] * result[k] } }
      result[row] = value / lower[row * n + row]
    }
    return result.allSatisfy(\.isFinite) ? result : nil
  }

  static func velocities(
    parent: CurrentNewtKitReceipt.BodyState, pod: CurrentNewtKitReceipt.BodyState,
    rodVelocity: Double
  ) -> [Double] {
    [parent.velocity.x, parent.velocity.y, parent.velocity.z,
      parent.angularVelocity.x, parent.angularVelocity.y, parent.angularVelocity.z,
      pod.velocity.x, pod.velocity.y, pod.velocity.z,
      pod.angularVelocity.x, pod.angularVelocity.y, pod.angularVelocity.z, rodVelocity]
  }

  /// Positive multiplier pushes the pod and reacts on the actual parent/rod.
  static func contactJacobian(
    point: Vector3, normal: Vector3, direction: Vector3,
    parent: CurrentNewtKitReceipt.BodyState, pod: CurrentNewtKitReceipt.BodyState
  ) -> [Double]? {
    guard point.finite, normal.finite, direction.finite,
      abs(normal.dot(normal) - 1) <= 1e-9,
      abs(direction.dot(direction) - 1) <= 1e-9
    else { return nil }
    let parentTorque = (point - parent.pose.position).cross(normal)
    let podTorque = (point - pod.pose.position).cross(normal)
    return [-normal.x, -normal.y, -normal.z,
      -parentTorque.x, -parentTorque.y, -parentTorque.z,
      normal.x, normal.y, normal.z, podTorque.x, podTorque.y, podTorque.z,
      -normal.dot(direction)]
  }
}
