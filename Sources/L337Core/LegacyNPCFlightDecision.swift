import Foundation

/// Opening facts and motion only. This is neither actor admission nor permission to
/// recharge, consume randomness, change cooldowns, fire, spawn or commit native effects.
struct LegacyNPCFlightDecision: Sendable {
  enum Driver: Sendable { case ordinaryPlayerEngagement, blackjack }
  let driver: Driver
  let bodyID: Int
  let actor: ActorIdentity?
  let intention: NPCAction?
  let blackjackIdentity: UUID?
  let epoch: UUID
  let physicalTime: Double
  let duration: Double
  let start: Vector3
  let end: Vector3
  let worldStart: Vector3
  let worldEnd: Vector3
  let worldVelocity: Vector3

  /// One captured outer displacement. Cuts do not repeat pursuit/damping or retarget.
  func worldPosition(at time: Double) -> Vector3? {
    guard time.isFinite, time >= physicalTime, time <= physicalTime + duration else { return nil }
    return time == physicalTime + duration
      ? worldEnd : worldStart + worldVelocity * (time - physicalTime)
  }

  /// Exact existing enemyAction movement; scalar inputs alone grant no source role.
  static func ordinaryPosition(_ position: Vector3, maximumSpeed: Double?, delta: Double) -> Vector3 {
    var result = position
    if let maximumSpeed {
      let distance = result.length
      if distance > 0 {
        result = result * max(0, 1 - maximumSpeed * 18 * delta / distance)
      }
    } else {
      result.x *= 1 - delta * 0.25
      result.y *= 1 - delta * 0.25
      if result.z > 300 { result.z -= delta * 60 }
    }
    return result
  }

  /// Blackjack's source speed is already in movement units; there is no factor18.
  static func blackjackPosition(_ position: Vector3, delta: Double) -> Vector3 {
    let distance = position.length
    if distance > 0 {
      return position * max(0, 1 - BlackjackTarget.speed * delta / distance)
    }
    return position
  }
}

extension Game {
  /// Pure opening query for the existing selected legacy cohort. The native owner
  /// must rejoin actual actor/epoch/intent and attained time before any later effect.
  func prepareLegacyNPCFlightDecision(_ body: SpaceBody, frame: ShipPose, delta: Double)
    -> LegacyNPCFlightDecision?
  {
    guard delta.isFinite, delta > 0,
      !isEMPDisabled(body), body.physical?.empCrewPod == nil
    else { return nil }
    let driver: LegacyNPCFlightDecision.Driver
    let end: Vector3
    if body.blackjackRole != nil {
      // Preserve the existing exception before ordinary player-engagement validation.
      driver = .blackjack
      end = LegacyNPCFlightDecision.blackjackPosition(body.position, delta: delta)
    } else {
      let flight = commander.flightSimulation
      guard let player = flight.player, player.system == systemIdentity,
        let physical = body.physical,
        physical.identity.system == player.system, physical.identity.visit == player.visit,
        physical.identity.entity >= 2, physical.identity.entity < flight.nextActor,
        physical.npc?.intention == .engage(player)
      else { return nil }
      driver = .ordinaryPlayerEngagement
      end = LegacyNPCFlightDecision.ordinaryPosition(body.position,
        maximumSpeed: body.nativeNavalCombat?.speed, delta: delta)
    }
    let worldStart = frame.systemPoint(body.position)
    let worldEnd = frame.systemPoint(end)
    return .init(driver: driver, bodyID: body.id, actor: body.physical?.identity,
      intention: body.physical?.npc?.intention, blackjackIdentity: body.blackjackIdentity,
      epoch: nativeStationRuntimeEpoch, physicalTime: commander.flightSimulation.physicalTime,
      duration: delta, start: body.position, end: end,
      worldStart: worldStart, worldEnd: worldEnd, worldVelocity: (worldEnd - worldStart) * (1 / delta))
  }
}
