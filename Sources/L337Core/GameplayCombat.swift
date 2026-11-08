import Foundation
import OSLog

private let gameplayCombatLogger = Logger(subsystem: "io.xyzzy.l337", category: "GameplayCombat")

/// Only the selected-contact owner below constructs this frame after joining
/// sealed native query geometry to actual retained motion and live sources.
private struct NativeSelectedCombatFrame {
  let worldPoint: Vector3
  let front: Bool
}

/// Local to one native collision call. Only accepted incident producers append.
final class NativeCombatAllocationRecorder {
  fileprivate var incidents: [CombatIncident] = []
  fileprivate init() {}
}

/// A live effect certificate records actual accepted calls, not a caller's
/// closing counter snapshot. It has no Codable or external constructor.
final class NativeCombatHitClockEffect: Sendable {
  private let opening: FlightSimulationState
  private let incidents: [CombatIncident]
  private let kind: AttackKind
  private let beforeBodies: [SpaceBody]
  private let afterBodies: [SpaceBody]
  let incident: CombatIncident

  fileprivate init(
    opening: FlightSimulationState, incidents: [CombatIncident],
    incident: CombatIncident, kind: AttackKind,
    beforeBodies: [SpaceBody], afterBodies: [SpaceBody]
  ) {
    self.opening = opening
    self.incidents = incidents
    self.kind = kind
    self.beforeBodies = beforeBodies
    self.afterBodies = afterBodies
    self.incident = incident
  }

  func applying(to before: FlightSimulationState) -> FlightSimulationState? {
    guard before == opening, !incidents.isEmpty, incidents.count <= 2,
      incidents.first == incident
    else { return nil }
    var expected = before
    for recorded in incidents {
      guard recorded.kind == kind, recorded.physicalTime == before.physicalTime,
        recorded.origin == incident.origin, expected.allocateIncident() == recorded.id
      else { return nil }
    }
    return expected
  }
  func updatedBirthBodies(matching expected: [ActorIdentity: SpaceBody], in game: Game)
    -> [ActorIdentity: SpaceBody]?
  {
    guard applying(to: opening) == game.commander.flightSimulation else { return nil }
    var result: [ActorIdentity: SpaceBody] = [:]
    for (actor, original) in expected {
      guard beforeBodies.filter({ $0.physical?.identity == actor }) == [original],
        let after = afterBodies.first(where: { $0.physical?.identity == actor }),
        afterBodies.filter({ $0.physical?.identity == actor }).count == 1,
        game.bodies.filter({ $0.physical?.identity == actor }) == [after]
      else { return nil }
      result[actor] = after
    }
    return result
  }

}

/// Actual accepted destruction transport. Only this native owner can construct it.
/// Decoding an incident, an actor ID, or nonpositive energy cannot create this value.
struct NativeC01InquiryAcceptedDestruction: Sendable {
  let incident: CombatIncident
  let bodyID: Int
  let actor: ActorIdentity
  let spawn: SpawnIdentity
  let system: SystemIdentity
  let visit: UInt64
  let revision: UInt64
  let nativeEpoch: UUID
  let operation: UUID
  fileprivate init(
    incident: CombatIncident, bodyID: Int, actor: ActorIdentity, spawn: SpawnIdentity,
    system: SystemIdentity, visit: UInt64, revision: UInt64, nativeEpoch: UUID
  ) {
    self.incident = incident
    self.bodyID = bodyID
    self.actor = actor
    self.spawn = spawn
    self.system = system
    self.visit = visit
    self.revision = revision
    self.nativeEpoch = nativeEpoch
    operation = UUID()
  }
}

extension Game {
  /// Capture the emitter once. Projectiles retain this origin even if it disappears.
  @inline(never)
  mutating func makeAttackOrigin(
    owner: ActorIdentity, ordnance: ActorIdentity? = nil, sourcePart: String? = nil,
    playerAmmunition: PlayerAmmunitionSource? = nil
  ) -> AttackOrigin? {
    ensurePhysicalActors()
    guard let context = gameplayContext(),
      let actor = combatActor(owner, context: context), actor.energy > 0,
      let emission = commander.flightSimulation.allocateEmission()
    else { return nil }
    return .init(
      emissionID: emission, owner: owner, ordnance: ordnance,
      emittedAt: context.physicalTime, ownerLegalAtEmission: actor.legal, sourcePart: sourcePart,
      playerAmmunition: playerAmmunition)
  }

  /// Record before changing health or hostility so legal/bounty evidence stays original.
  @discardableResult
  @inline(never)
  mutating func recordCombat(
    origin: AttackOrigin, kind: AttackKind, outcome: AttackOutcome,
    target: GameplayHitTarget?, worldPosition: Vector3, emissionPosition: Vector3? = nil,
    laser: LaserKind? = nil, mount: LaserMount? = nil, victimPart: String? = nil,
    allocation: NativeCombatAllocationRecorder? = nil
  ) -> CombatIncident? {
    if case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), nativePracticeReservation(body) != nil
    {
      return nil
    }
    ensurePhysicalActors()
    guard let context = gameplayContext() else { return nil }
    return recordCombatWithEntitlement(
      origin: origin, kind: kind, outcome: outcome, target: target,
      worldPosition: worldPosition, emissionPosition: emissionPosition, laser: laser, mount: mount,
      victimPart: victimPart, context: context,
      entitlement: combatMissionEntitlement(target, owner: origin.owner, context: context),
      allocation: allocation)
  }

  /// The only caller carrying an entitlement across mutation is this file's uninterrupted
  /// native body-hit/death path. The live-only retained factory remains unchanged.
  @inline(never)
  private mutating func recordCombatWithEntitlement(
    origin: AttackOrigin, kind: AttackKind, outcome: AttackOutcome,
    target: GameplayHitTarget?, worldPosition: Vector3, emissionPosition: Vector3?,
    laser: LaserKind?, mount: LaserMount?, victimPart: String?, context: EncounterContext,
    entitlement: MissionBountyEntitlement?, allocation: NativeCombatAllocationRecorder? = nil
  ) -> CombatIncident? {
    guard worldPosition.finite, emissionPosition?.finite ?? true,
      origin.owner.system == context.system,
      origin.owner.visit == context.visit, origin.emittedAt.isFinite,
      origin.emittedAt >= 0, origin.emittedAt <= context.physicalTime
    else { return nil }
    let victim = combatVictim(target, context: context)
    if case .body = target, victim == nil { return nil }
    guard let id = commander.flightSimulation.allocateIncident() else { return nil }
    let incident = CombatIncident(
      id: id, physicalTime: context.physicalTime, origin: origin, victim: victim?.identity,
      kind: kind, outcome: outcome, position: worldPosition,
      victimLegalBeforeAttack: victim?.legal, firstAggressor: victim?.npc?.firstAggressor,
      victimRole: victim?.npc?.role, victimIsStation: victim?.hull == .station,
      laser: laser, mount: mount, victimPart: victimPart)
    let resolution = commander.crimeLedger.record(
      incident, context: context, emissionPosition: emissionPosition,
      missionEntitlement: entitlement.flatMap {
        $0.owner == origin.owner && $0.victim == victim?.identity ? $0 : nil
      })
    guard resolution.accepted else { return nil }
    allocation?.incidents.append(incident)
    if commander.scriptState.savedC01Inquiry != nil, outcome == .destruction,
      case .body(let bodyID)? = target,
      let body = bodies.first(where: { $0.id == bodyID }),
      body.energy == 0, body.physical?.deathOrigin == incident.origin,
      let physical = body.physical, let spawn = physical.spawnIdentity,
      incident.victim == physical.identity
    {
      _ = recordC01InquiryAcceptedDestruction(.init(incident: incident, bodyID: bodyID,
        actor: physical.identity, spawn: spawn, system: context.system, visit: context.visit,
        revision: context.revision, nativeEpoch: nativeStationRuntimeEpoch))
    }
    gameplayCombatTrace?.append(incident)
    applyCrimeResolution(resolution, target: target, origin: origin, context: context)
    if outcome == .hit {
      observeSafeGunneryOrdinaryHit(incident)
      observeDefensiveFlightOrdinaryHit(incident)
    }
    return incident
  }

  /// The caller supplies the nearest verified hit; this adapter never spawns or removes bodies.
  @discardableResult
  @inline(never)
  mutating func applyCombatHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind? = nil, mount: LaserMount? = nil, emissionPosition: Vector3? = nil,
    energyMultiplier: Double = 1, allocation: NativeCombatAllocationRecorder? = nil
  ) -> CombatIncident? {
    guard damage.isFinite, damage >= 0, hit.distance.isFinite, hit.distance >= 0,
      hit.point.finite, energyMultiplier.isFinite, energyMultiplier >= 0
    else { return nil }
    // Practice attribution belongs to the sealed native contact route, never raw damage.
    if nativePracticeReservedTarget(hit) { return nil }
    ensurePhysicalActors()
    switch hit.target {
    case .body:
      return applyBodyHit(
        hit, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition, allocation: allocation)
    case .player:
      return applyPlayerHit(
        hit, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition, energyMultiplier: energyMultiplier,
        allocation: allocation)
    case .celestial:
      return recordCombat(
        origin: origin, kind: kind, outcome: .hit, target: hit.target,
        worldPosition: commander.flightSimulation.pose.systemPoint(hit.point),
        emissionPosition: emissionPosition, laser: laser, mount: mount, allocation: allocation)
    }
  }

  @inline(never)
  private mutating func applyBodyHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?,
    allocation: NativeCombatAllocationRecorder? = nil,
    selectedFrame: NativeSelectedCombatFrame? = nil
  ) -> CombatIncident? {
    guard case .body(let id) = hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].energy > 0,
      let context = gameplayContext()
    else { return nil }
    let entitlement = combatMissionEntitlement(hit.target, owner: origin.owner, context: context)
    let interception = bodies[index].hull == .missile
    let world = selectedFrame?.worldPoint ?? commander.flightSimulation.pose.systemPoint(hit.point)
    guard
      let incident = recordCombatWithEntitlement(
        origin: origin, kind: kind, outcome: interception ? .ordnanceInterception : .hit,
        target: hit.target, worldPosition: world, emissionPosition: emissionPosition,
        laser: laser, mount: mount, victimPart: nil, context: context, entitlement: entitlement,
        allocation: allocation)
    else { return nil }
    if interception {
      if let emission = currentNativeOrdnanceEmission(bodies[index], context: context) {
        commander.crimeLedger.finishEmission(emission)
      }
      bodies[index].energy = 0
    } else {
      damageBody(
        index: index, incident: incident, damage: damage, point: hit.point,
        frontOverride: selectedFrame?.front)
    }
    if bodies[index].energy <= 0 {
      bodies[index].physical?.deathOrigin = origin
      bodies[index].destroyedByPlayer = origin.owner == commander.flightSimulation.player
      if !interception, let deathContext = gameplayContext() {
        let destruction = recordCombatWithEntitlement(
          origin: origin, kind: kind, outcome: .destruction, target: hit.target,
          worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount,
          victimPart: nil, context: deathContext, entitlement: entitlement, allocation: allocation)
        bodies[index].physical?.deathIncidentID = destruction?.id
      }
    }
    return incident
  }

  private mutating func applyPlayerHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?, energyMultiplier: Double,
    allocation: NativeCombatAllocationRecorder? = nil,
    selectedFrame: NativeSelectedCombatFrame? = nil
  ) -> CombatIncident? {
    let world = selectedFrame?.worldPoint ?? commander.flightSimulation.pose.systemPoint(hit.point)
    guard energy > 0,
      let incident = recordCombat(
        origin: origin, kind: kind, outcome: .hit, target: .player,
        worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount,
        allocation: allocation)
    else { return nil }
    let before = (front: frontShield, rear: rearShield, energy: energy)
    applyDamage(
      damage, front: selectedFrame?.front ?? (hit.point.z >= 0),
      energyMultiplier: energyMultiplier)
    recordPlayerImpactFeedback(contact: hit.point, event: incident.id, before: before)
    if energy <= 0 {
      recordFatalPlayerHit(
        incident, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition, energyMultiplier: energyMultiplier, world: world,
        allocation: allocation)
    }
    return incident
  }

  /// Fatal-only queries and logging do not reserve temporaries in the ordinary hit frame.
  @inline(never)
  private mutating func recordFatalPlayerHit(
    _ incident: CombatIncident, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?, energyMultiplier: Double,
    world: Vector3, allocation: NativeCombatAllocationRecorder? = nil
  ) {
    let revision = gameplayRevision
    let owner = incident.origin.owner
    let loggedLaser: String = incident.laser?.rawValue ?? "none"
    let loggedMount: String = incident.mount?.rawValue ?? "none"
    let ownerLegal = incident.origin.ownerLegalAtEmission.value
    let playerLegal = commander.legal
    var ownerMatches = 0
    var role = "unknown"
    var producer = "unknown"
    var engagesPlayer = "u"
    if let player = commander.flightSimulation.player,
      player.system == owner.system, player.visit == owner.visit
    {
      for body in bodies where body.physical?.identity == owner {
        ownerMatches += 1
        guard ownerMatches == 1 else {
          role = "unknown"
          producer = "unknown"
          engagesPlayer = "u"
          break
        }
        role = body.physical?.npc?.role.rawValue ?? "none"
        producer = body.physical?.spawnIdentity?.producer.rawValue ?? "none"
        engagesPlayer = body.physical?.npc?.intention == .engage(player) ? "1" : "0"
      }
    }
    let ownerContext = (role: role, producer: producer, engagesPlayer: engagesPlayer)
    gameplayCombatLogger.notice(
      "PLAYER_COMBAT_FATAL revision=\(revision, privacy: .public) incident=\(incident.id, privacy: .public) time=\(String(incident.physicalTime), privacy: .public) kind=\(incident.kind.rawValue, privacy: .public) ownerGalaxy=\(owner.system.galaxy, privacy: .public) ownerSystem=\(owner.system.system, privacy: .public) ownerVisit=\(owner.visit, privacy: .public) ownerEntity=\(owner.entity, privacy: .public) ordnance=\(incident.origin.ordnance == nil ? 0 : 1, privacy: .public) damage=\(String(damage), privacy: .public) energyMultiplier=\(String(energyMultiplier), privacy: .public) laser=\(loggedLaser, privacy: .public) mount=\(loggedMount, privacy: .public) role=\(ownerContext.role, privacy: .public) oLegal=\(ownerLegal, privacy: .public) pLegal=\(playerLegal, privacy: .public) producer=\(ownerContext.producer, privacy: .public) engagePlayer=\(ownerContext.engagesPlayer, privacy: .public)"
    )
    recordCombat(
      origin: origin, kind: kind, outcome: .destruction, target: .player,
      worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount,
      allocation: allocation)
  }

  /// Consume only a native selected-geometry hit after the real motion owner
  /// proves that opening and its actual retained scene. The impact's original
  /// bank and world point remain independent of the later camera pose.
  @inline(never)
  mutating func applySelectedNativeNPCBeamHit(
    _ contact: MissionCollisionContact, origin: AttackOrigin, damage: Double,
    emissionPosition: Vector3, energyMultiplier: Double = 1,
    evidence: CurrentNewtNativeClockEvidence,
    admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> NativeCombatHitClockEffect? {
    let hit = contact.hit
    guard let geometry = contact.selectedGeometry,
      contact.selectedEmitter == origin.owner, contact.selectedLaunch == emissionPosition,
      evidence.validatesSelectedBeamGeometry(geometry, closing: self, admittedAtEnd: admittedAtEnd)
    else { return nil }
    return applySelectedNativeNPCBeamAfterEvidence(
      contact, hit: hit, geometry: geometry, origin: origin, damage: damage,
      emissionPosition: emissionPosition, energyMultiplier: energyMultiplier)
  }

  @inline(never)
  private mutating func applySelectedNativeNPCBeamAfterEvidence(
    _ contact: MissionCollisionContact, hit: GameplayHit, geometry: MissionCollisionQueryGeometry,
    origin: AttackOrigin, damage: Double, emissionPosition: Vector3, energyMultiplier: Double
  ) -> NativeCombatHitClockEffect? {
    guard let source = bodies.first(where: { $0.physical?.identity == origin.owner }),
      source.energy > 0, source.scriptNPC == nil, !isEMPDisabled(source),
      geometry.openingBodies.contains(where: { $0.physical?.identity == origin.owner }),
      origin.emittedAt == storedFlightSimulation().physicalTime,
      damage.isFinite, damage >= 0, emissionPosition.finite,
      energyMultiplier.isFinite, energyMultiplier >= 0, hit.point.finite, hit.distance.isFinite,
      hit.distance >= 0,
      !nativePracticeReservedTarget(hit)
    else { return nil }
    let front: Bool
    if case .body(let id) = hit.target {
      guard let selected = contact.selectedTargetBody, selected.id == id,
        selected.scriptNPC == nil, let identity = selected.physical?.identity,
        let current = bodies.first(where: { $0.id == id }),
        current.physical?.identity == identity, current.energy > 0
      else { return nil }
      front = (hit.point - selected.position).dot(selected.modelVector(.init(0, 0, 1))) >= 0
    } else {
      front = hit.point.z >= 0
    }
    let frame = NativeSelectedCombatFrame(
      worldPoint: geometry.selectedFrame.systemPoint(hit.point), front: front)
    guard frame.worldPoint.finite else { return nil }
    let opening = storedFlightSimulation()
    let beforeBodies = bodies
    var retained = self
    let allocation = NativeCombatAllocationRecorder()
    let incident: CombatIncident?
    switch hit.target {
    case .body:
      incident = retained.applyBodyHit(
        hit, origin: origin, kind: .laser, damage: damage,
        laser: nil, mount: nil, emissionPosition: emissionPosition,
        allocation: allocation, selectedFrame: frame)
    case .player:
      incident = retained.applyPlayerHit(
        hit, origin: origin, kind: .laser, damage: damage,
        laser: nil, mount: nil, emissionPosition: emissionPosition,
        energyMultiplier: energyMultiplier,
        allocation: allocation, selectedFrame: frame)
    case .celestial:
      incident = retained.recordCombat(
        origin: origin, kind: .laser, outcome: .hit,
        target: hit.target, worldPosition: frame.worldPoint, emissionPosition: emissionPosition,
        allocation: allocation)
    }
    guard let incident else { return nil }
    let effect = NativeCombatHitClockEffect(
      opening: opening, incidents: allocation.incidents, incident: incident, kind: .laser,
      beforeBodies: beforeBodies, afterBodies: retained.bodies)
    guard effect.applying(to: opening) == retained.storedFlightSimulation() else { return nil }
    self = retained
    return effect
  }

  /// The continuous query owns the contact and the real scene/frontier join.
  /// This shares the original actual damage, bank, law and allocation owners.
  mutating func applyNativeOrdnanceCurveHit(_ observation: CurrentNewtOrdnanceCurveContact)
    -> NativeCombatHitClockEffect? {
    guard let contact = try? bindNativeOrdnanceCurveContact(observation),
      contact.selectedTargetBody?.scriptNPC == nil,
      let projectile = bodies.first(where: { $0.id == observation.opening.body.id }),
      let state = projectile.physical?.ordnance,
      state.origin == observation.opening.state.origin
    else { return nil }
    let hit = contact.hit
    let damage = ordnanceImpactDamage(state: state, hit: hit)
    let front: Bool
    if case .body(let id) = hit.target {
      guard let body = bodies.first(where: { $0.id == id }) else { return nil }
      front = (hit.point - body.position).dot(body.modelVector(.init(0, 0, 1))) >= 0
    } else { front = hit.point.z >= 0 }
    let frame = NativeSelectedCombatFrame(worldPoint: observation.native.centre, front: front)
    let opening = commander.flightSimulation
    let beforeBodies = bodies
    var retained = self
    let allocation = NativeCombatAllocationRecorder()
    let incident: CombatIncident?
    switch hit.target {
    case .body:
      incident = retained.applyBodyHit(hit, origin: state.origin, kind: state.profile.attackKind,
        damage: damage, laser: nil, mount: nil, emissionPosition: state.emissionPosition,
        allocation: allocation, selectedFrame: frame)
    case .player:
      incident = retained.applyPlayerHit(hit, origin: state.origin, kind: state.profile.attackKind,
        damage: damage, laser: nil, mount: nil, emissionPosition: state.emissionPosition,
        energyMultiplier: 1, allocation: allocation, selectedFrame: frame)
    case .celestial: return nil // Conservative enclosures never authorize celestial damage.
    }
    guard let incident else { return nil }
    let effect = NativeCombatHitClockEffect(opening: opening, incidents: allocation.incidents,
      incident: incident, kind: state.profile.attackKind, beforeBodies: beforeBodies,
      afterBodies: retained.bodies)
    guard effect.applying(to: opening) == retained.commander.flightSimulation else { return nil }
    self = retained
    return effect
  }

  /// Record a real selected-source miss through the ordinary discharge owner.
  /// Accepted-body evidence includes any actual law/retaliation changes.
  mutating func recordNativeNPCDischarge(origin: AttackOrigin, position: Vector3)
    -> NativeCombatHitClockEffect?
  {
    let opening = commander.flightSimulation
    let beforeBodies = bodies
    let allocation = NativeCombatAllocationRecorder()
    guard
      let incident = recordCombat(
        origin: origin, kind: .laser, outcome: .discharge,
        target: nil, worldPosition: position, emissionPosition: position, allocation: allocation)
    else { return nil }
    let effect = NativeCombatHitClockEffect(
      opening: opening, incidents: allocation.incidents,
      incident: incident, kind: .laser, beforeBodies: beforeBodies, afterBodies: bodies)
    guard effect.applying(to: opening) == commander.flightSimulation else { return nil }
    return effect
  }

  mutating func applyNativeCollisionHit(
    _ hit: GameplayHit, origin: AttackOrigin, damage: Double
  ) -> NativeCombatHitClockEffect? {
    applyNativeCombatHit(hit, origin: origin, kind: .collision, damage: damage)
  }

  /// Retain the actual accepted hit/destruction allocations from the existing
  /// combat owner. The caller must still supply its genuine contact and origin.
  mutating func applyNativeCombatHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    emissionPosition: Vector3? = nil
  ) -> NativeCombatHitClockEffect? {
    guard [.collision, .missile, .plasma].contains(kind) else { return nil }
    let opening = commander.flightSimulation
    let beforeBodies = bodies
    let allocation = NativeCombatAllocationRecorder()
    guard
      let incident = applyCombatHit(
        hit, origin: origin, kind: kind, damage: damage,
        emissionPosition: emissionPosition, allocation: allocation)
    else { return nil }
    let effect = NativeCombatHitClockEffect(
      opening: opening, incidents: allocation.incidents, incident: incident, kind: kind,
      beforeBodies: beforeBodies, afterBodies: bodies)
    guard effect.applying(to: opening) == commander.flightSimulation else { return nil }
    return effect
  }

  private mutating func damageBody(
    index: Int, incident: CombatIncident, damage: Double, point: Vector3,
    frontOverride: Bool? = nil
  ) {
    guard damage > 0, bodies[index].physical?.empCrewPod == nil,
      bodies[index].hull != .station || nativeStationBodyIsCurrent(bodies[index]),
      incident.kind != .bomb || !bodies[index].nativeNavalBombImmune
    else { return }
    if bodies[index].isAegisPrototype,
      incident.kind == .plasma
        || (incident.kind == .laser && incident.laser != .military && incident.laser != .naval)
    {
      return
    }
    if damagePhysicalAsteroid(index: index, incident: incident, damage: damage) { return }
    if let rockID = bodies[index].physical?.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == rockID })
    {
      switch commander.miningLedger.hit(rock: rock, incident: incident, damage: damage) {
      case .damaged(let remaining): bodies[index].energy = remaining
      case .extracted, .destroyed: bodies[index].energy = 0
      case .ignored, .capacityRefused: break
      }
    } else {
      var remaining = damage
      if incident.kind != .bomb, var resources = bodies[index].physical?.npc?.resources {
        let forward = bodies[index].modelVector(.init(0, 0, 1))
        remaining = resources.absorb(
          damage, front: frontOverride ?? ((point - bodies[index].position).dot(forward) >= 0))
        bodies[index].physical?.npc?.resources = resources
      }
      bodies[index].energy = max(0, bodies[index].energy - remaining)
    }
  }

  @inline(never)
  private mutating func applyCrimeResolution(
    _ resolution: CrimeResolution, target: GameplayHitTarget?, origin: AttackOrigin,
    context: EncounterContext
  ) {
    applyNativeCrimeResolution(
      resolution, target: target, attacker: origin.owner, context: context)
  }

  /// Apply a verified ledger result without manufacturing a current origin for old ordnance.
  @inline(never)
  mutating func applyNativeCrimeResolution(
    _ resolution: CrimeResolution, target: GameplayHitTarget?, attacker: ActorIdentity?,
    context: EncounterContext
  ) {
    if resolution.offender == context.player.identity {
      let baseline = max(0, min(255, commander.legal))
      let penalty = max(0, min(255, resolution.legalPenalty))
      commander.legal = max(commander.legal, min(255, baseline + penalty))
    } else if let index = bodies.firstIndex(where: { $0.physical?.identity == resolution.offender }
    ),
      let legal = bodies[index].physical?.npc?.legal.value
    {
      let baseline = max(0, min(255, legal))
      let penalty = max(0, min(255, resolution.legalPenalty))
      bodies[index].physical?.npc?.legal.value = max(legal, min(255, baseline + penalty))
      if penalty > 0 { bodies[index].physical?.npc?.legalProvenance = .recorded }
    }
    if resolution.unlawful, case .body(let id) = target,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].hull.isTargetShip
    {
      bodies[index].physical?.npc?.firstAggressor = resolution.firstAggressor
      if let attacker = resolution.offender ?? attacker {
        bodies[index].physical?.npc?.intention = .engage(attacker)
        if bodies[index].blackjackRole == nil, bodies[index].missionInstanceID == nil,
          bodies[index].scriptNPC == nil
        {
          bodies[index].hostile = attacker == context.player.identity
        } else if attacker == context.player.identity, !isC01StructuralProp(bodies[index]) {
          // Authored mission and Blackjack drivers retain their existing dispatch projection.
          bodies[index].hostile = true
        }
      }
    }
    if let death = resolution.death { applyNativeCareerDeath(death, context: context) }
    if let report = resolution.report { commander.stationSecurity.receive(report) }
    for notice in resolution.notices where message != notice.text || messageTime <= 0 {
      notify(notice.text)
    }
    observeFleetDestruction(resolution.death, target: target, context: context)
    creditCombatDeath(resolution.death, target: target, context: context)
  }

  @inline(never)
  private mutating func applyNativeCareerDeath(_ death: DeathSettlement, context: EncounterContext) {

    var careers = commander.wantedCareers
    if let ownerBody = bodies.first(where: { $0.physical?.identity == death.owner }),
      wantedCareerIsOrdinary(ownerBody),
      let logical = commander.npcPersistence.logicalIdentity(for: death.owner),
      let observed = NPCPersistenceSnapshot.capture(
        body: ownerBody, pose: commander.flightSimulation.pose,
        physicalTime: context.physicalTime, protection: context.protection)
    {
      careers.observe(
        observed, logical: logical, visible: ownerBody.position.length <= context.perceptionRadius
      )
    }
    let structuralProp = bodies.first(where: { $0.physical?.identity == death.victim })
      .map { isC01StructuralProp($0) || c03PassiveEvidenceKind(of: $0) != nil } ?? false
    let shipDeath =
      death.victim == context.player.identity
      || (!structuralProp
        && context.actors.contains { $0.identity == death.victim && $0.hull.isTargetShip })
    let victimCareer = careers.careers.values.first { $0.binding == death.victim }
    var listed = false
    if let career = victimCareer {
      listed = wantedBoard.contains { $0.identity == career.identity }
    }
    let recorded = careers.record(
      death, player: context.player.identity, shipDeath: shipDeath)
    if careers != commander.wantedCareers { commander.wantedCareers = careers }
    if recorded, listed, let name = victimCareer?.callsign {
      notify("WANTED CAREER CLOSED: " + name)
    }
  }

  @inline(never)
  private mutating func creditCombatDeath(
    _ death: DeathSettlement?, target: GameplayHitTarget?, context: EncounterContext
  ) {
    guard let death, death.owner == context.player.identity, case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), body.hull.isTargetShip,
      !isGlassMeridianClock(body), !isC01Surveyor(body), !isC01StructuralProp(body),
      c03PassiveEvidenceKind(of: body) == nil
    else { return }
    creditQualifiedCombatDeath(death)
  }

  @inline(never)
  private mutating func creditQualifiedCombatDeath(_ death: DeathSettlement) {
    let previousRank = commander.rank
    commander.kills = (commander.kills &+ 1) & 0xffff
    commander.credits = (commander.credits &+ death.bountyTenths) & 0xffff_ffff
    if commander.rank != previousRank { notify("RIGHT ON, COMMANDER") }
  }

  private func combatVictim(_ target: GameplayHitTarget?, context: EncounterContext)
    -> ActorSnapshot?
  {
    switch target {
    case .player: return context.player
    case .body(let id):
      guard let identity = bodies.first(where: { $0.id == id })?.physical?.identity else {
        return nil
      }
      return combatActor(identity, context: context)
    case .celestial, nil: return nil
    }
  }

  private func combatActor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot? {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  @inline(never)
  func combatMissionEntitlement(
    _ target: GameplayHitTarget?, owner: ActorIdentity, context: EncounterContext
  ) -> MissionBountyEntitlement? {
    guard owner == context.player.identity, case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), let victim = body.physical?.identity
    else { return nil }
    if let descriptor = currentMissionActorDescriptor(bodyID: id),
      let binding = try? MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body, context: context), binding.nativeActor == victim,
      let instance = nativeGuidanceStoredMission(id: descriptor.instanceID),
      let pack = scriptPack(for: instance),
      let encounter = pack.manifest.encounters?.first(where: { $0.id == descriptor.encounterID }),
      let declared = encounter.actors.first(where: { $0.id == descriptor.alias })
    {
      let amount =
        body.scriptNPC?.fit.definition.bounty ?? body.nativeNavalCombat?.bounty
        ?? (declared.hostile ? 50 : 0)
      return .init(
        owner: owner, victim: victim, amountTenths: amount,
        authorizesAttack: declared.hostile)
    }
    if let role = body.blackjackRole, commanderGalaxy == 1,
      storedSystemIdentity().system == role.system, nativeQueryStoredBlackjack().stage == role.requiredStage
    {
      let saved = role == .bolts ? nativeQueryStoredBlackjack().bolts : nativeQueryStoredBlackjack().witness
      if saved?.identity == body.blackjackIdentity {
        return .init(
          owner: owner, victim: victim, amountTenths: role.bountyCredits * 10,
          authorizesAttack: role == .bolts)
      }
    }
    if body.isAegisPrototype,
      nativeQueryStoredMissionStage() == .huntingConstrictor
    {
      return .init(
        owner: owner, victim: victim, amountTenths: body.nativeNavalCombat?.bounty ?? 0,
        authorizesAttack: true)
    }
    return nil
  }
}
