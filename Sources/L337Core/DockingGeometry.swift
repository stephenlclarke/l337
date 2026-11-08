import Foundation

extension SpaceBody {
  public var containsPlayer: Bool {
    let relative = entrancePosition * -1
    guard relative.dot(entranceNormal) < 0 else { return false }
    let axes = [modelVector(.init(1, 0, 0)), entranceUp, modelVector(.init(0, 0, 1))]
    return axes.allSatisfy { abs(relative.dot($0)) < 90 }
  }
  var dockingRollPhase: Double { atan2(entranceUp.x, entranceUp.y) }
  var dockingMatchRollRate: Double { -rotationRate * orientation.z.z }
  var dockingPhaseAligned: Bool { abs(dockingRollPhase) < 0.1 }

  public func canEnter(roll: Double, speed: Double) -> Bool {
    let toPlayer = entrancePosition * -1
    let x = toPlayer.dot(modelVector(.init(1, 0, 0)))
    let y = toPlayer.dot(entranceUp)
    let depth = toPlayer.dot(entranceNormal)
    let facing = entranceNormal.z < -0.98
    let matchedRate = abs(roll - dockingMatchRollRate) < 0.1
    return abs(x) < 25 && abs(y) < 8 && depth <= 1 && depth > -25 && facing && dockingPhaseAligned
      && speed < 144 && (matchedRate || abs(roll) < 0.15)
  }
}
