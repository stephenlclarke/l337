import Foundation

public struct BlackjackEncounter: Sendable, Codable, Equatable {
  public let identity: UUID
  public let role: BlackjackTarget
  public var body: SpaceBody
  public init(role: BlackjackTarget, id: Int) {
    identity = UUID()
    self.role = role
    body = SpaceBody(id: id, hull: .cobra, position: .init(0, 0, 0), hostile: true)
    body.blackjackIdentity = identity
    body.blackjackRole = role
    body.energy = BlackjackTarget.energy
    body.missiles = 3
    body.ecmEnabled = true
  }
  public var valid: Bool {
    body.blackjackIdentity == identity && body.blackjackRole == role && body.hull == .cobra
      && body.energy.isFinite && body.energy <= BlackjackTarget.energy && body.energy >= 0
      && (0...3).contains(body.missiles) && body.position.finite
      && body.position.length <= 1_000_000 && body.orientation.validRotation
      && body.rotation.isFinite && body.rotationRate.isFinite
      && (body.blackjackLaserCooldown ?? 0).isFinite
      && (body.blackjackLaserCooldown ?? 0) >= 0
      && (body.physical?.npc?.resources?.valid ?? true)
  }
}
extension Vector3 { var finite: Bool { x.isFinite && y.isFinite && z.isFinite } }
extension Basis3 {
  var finite: Bool { x.finite && y.finite && z.finite }
  var validRotation: Bool {
    finite && [x, y, z].allSatisfy { abs($0.length - 1) < 0.0001 }
      && abs(x.dot(y)) < 0.0001 && abs(x.dot(z)) < 0.0001 && abs(y.dot(z)) < 0.0001
  }
  func inverse(_ value: Vector3) -> Vector3 { .init(value.dot(x), value.dot(y), value.dot(z)) }
  func relative(to anchor: Basis3) -> Self {
    var result = Self()
    result.x = anchor.inverse(x)
    result.y = anchor.inverse(y)
    result.z = anchor.inverse(z)
    return result
  }
  func transformed(by anchor: Basis3) -> Self {
    var result = Self()
    result.x = anchor.apply(x)
    result.y = anchor.apply(y)
    result.z = anchor.apply(z)
    return result
  }
}
extension Game {
  mutating func persistBlackjackTargets() {
    guard commanderGalaxy == 1 else { return }
    persistBlackjackTargetsInGalaxyOne()
  }

  @inline(never)
  private mutating func persistBlackjackTargetsInGalaxyOne() {
    guard commander.galaxy == 1, let anchor = bodies.first(where: { $0.hull == .station }) else {
      return
    }
    var mission = commander.blackjack
    for body in bodies where body.blackjackIdentity != nil {
      guard let role = body.blackjackRole, role.system == commander.system else { continue }
      var encounter = role == .bolts ? mission.bolts : mission.witness
      guard encounter?.identity == body.blackjackIdentity else { continue }
      encounter?.body = body
      encounter?.body.energy = max(0, body.energy)
      encounter?.body.position = anchor.orientation.inverse(body.position - anchor.position)
      encounter?.body.orientation = body.orientation.relative(to: anchor.orientation)
      if role == .bolts { mission.bolts = encounter } else { mission.witness = encounter }
    }
    commander.blackjack = mission
  }
  mutating func retainPendingBlackjackEncounter() {
    guard !docked, commander.galaxy == 1,
      let anchor = bodies.first(where: { $0.hull == .station })
    else { return }
    let role: BlackjackTarget
    switch commander.blackjack.stage {
    case .huntBolts: role = .bolts
    case .huntWitness: role = .witness
    default: return
    }
    guard commander.system == role.system else { return }
    let existing = role == .bolts ? commander.blackjack.bolts : commander.blackjack.witness
    guard existing == nil else { return }

    // Keep the station-relative save record while its exact role hull is unavailable.
    var pending = BlackjackEncounter(role: role, id: nextBodyID)
    pending.body.position = anchor.orientation.inverse(anchor.position * -0.9)
    if role == .bolts {
      commander.blackjack.bolts = pending
    } else {
      commander.blackjack.witness = pending
    }
  }
  mutating func blackjackTargetDestroyed(_ body: SpaceBody) {
    guard body.energy <= 0, commander.galaxy == 1, let role = body.blackjackRole,
      commander.system == role.system, commander.blackjack.stage == role.requiredStage
    else { return }
    let saved = role == .bolts ? commander.blackjack.bolts : commander.blackjack.witness
    guard saved?.identity == body.blackjackIdentity else { return }
    _ = dispatchMission(.targetDestroyed, target: role.rawValue)
    persistBlackjackTargets()
  }
  mutating func advanceBlackjackNPC(index: Int, delta: Double) {
    rechargeBlackjackNPCForFlight(index: index, delta: delta)
    let distance = bodies[index].position.length
    if distance > 0 {
      bodies[index].position =
        bodies[index].position * max(0, 1 - BlackjackTarget.speed * delta / distance)
    }
    advanceBlackjackNPCWeaponEffects(index: index, delta: delta, distance: distance)
  }

  /// Actual effect clauses only. The native outer owner still supplies its real current
  /// actor/index, positive attained interval and Blackjack's actual opening distance.
  /// True means the eligible phase ran, not that a native beam hit or was admitted.
  @discardableResult
  @inline(never)
  mutating func applyLegacyNPCFlightEffects(
    index: Int, delta: Double, blackjackStartingDistance: Double? = nil,
    native: CurrentNewtLegacyEffectContext? = nil
  ) -> Bool {
    // Both original outer callers select live actors; recheck that cohort at attained time.
    guard bodies[index].energy > 0, !isEMPDisabled(bodies[index]),
      bodies[index].physical?.empCrewPod == nil
    else { return false }
    if let native {
      guard native.decision.actor == bodies[index].physical?.identity,
        native.decision.bodyID == bodies[index].id, native.decision.duration == delta
      else { return false }
    }
    if bodies[index].blackjackRole != nil {
      guard let distance = blackjackStartingDistance else { return false }
      rechargeBlackjackNPCForFlight(index: index, delta: delta)
      advanceBlackjackNPCWeaponEffects(
        index: index, delta: delta, distance: distance, native: native)
      return true
    }
    // Retain the exact ordinary current-player source guard at this effect boundary too.
    guard legacyNPCPlayerEffectSourceIsCurrent(index: index) else { return false }
    if (native?.decision.end.length ?? bodies[index].position.length) < 1500 {
      let damage = delta * (bodies[index].nativeNavalCombat?.laserDamage ?? 6) * 2
      emitLegacyNPCBeam(
        bodyID: bodies[index].id, damage: damage, energyMultiplier: 2, native: native)
    }
    return true
  }

  @inline(never)
  func legacyNPCPlayerEffectSourceIsCurrent(index: Int) -> Bool {
    let flight = storedFlightSimulation()
    guard let player = flight.player, player.system == systemIdentity,
      let physical = bodies[index].physical,
      physical.identity.system == player.system, physical.identity.visit == player.visit,
      physical.identity.entity >= 2, physical.identity.entity < flight.nextActor,
      physical.npc?.intention == .engage(player)
    else { return false }
    return true
  }

  // These raw clauses stay private to the original controller and guarded effect entry.
  // Their placement preserves recharge-before-motion and cooldown/fire-after-motion.
  private mutating func rechargeBlackjackNPCForFlight(index: Int, delta: Double) {
    bodies[index].energy = min(
      BlackjackTarget.energy, bodies[index].energy + BlackjackTarget.recharge * delta)
  }

  private mutating func advanceBlackjackNPCWeaponEffects(
    index: Int, delta: Double, distance: Double, native: CurrentNewtLegacyEffectContext? = nil
  ) {
    let cooldown = max(0, (bodies[index].blackjackLaserCooldown ?? 0) - delta)
    bodies[index].blackjackLaserCooldown = cooldown
    if distance < 1500 && cooldown == 0 {
      emitLegacyNPCBeam(
        bodyID: bodies[index].id, damage: BlackjackTarget.weaponEnergy, native: native)
      bodies[index].blackjackLaserCooldown = LaserKind.pulse.firingInterval
    }
  }

}
extension SpaceBody {
  /// Numeric slots are scene-local; the mission UUID remains stable across scenes.
  func withID(_ id: Int) -> Self {
    var copy = self
    copy.id = id
    return copy
  }
}
