import Foundation

public enum OrdnanceProfile: String, Codable, Sendable, CaseIterable {
  case standardMissile, plasma, alienSeeker

  public var speed: Double {
    switch self {
    case .standardMissile: 792
    case .plasma: 600
    case .alienSeeker: Self.standardMissile.speed * 1.25
    }
  }
  public var damage: Double {
    switch self {
    case .standardMissile: 160
    case .plasma: 40
    case .alienSeeker: Self.standardMissile.damage * 1.25
    }
  }
  public var energyCost: Double { self == .plasma ? 12 : 0 }
  public var heat: Double { self == .plasma ? 8 : 0 }
  public var firingInterval: Double { 1 }
  // Finite flight bounds are project constraints, separate from native missile speed.
  public var range: Double { self == .plasma ? 1200 : 6000 }
  public var lifetime: Double { self == .plasma ? 2 : 24 }
  public var attackKind: AttackKind { self == .plasma ? .plasma : .missile }
}

/// The caller supplies identities only while their actual ECM fields are active/in range.
public struct ECMActivationIdentity: Hashable, Codable, Sendable {
  public let emitter: ActorIdentity
  public let sequence: UInt64
  public init(emitter: ActorIdentity, sequence: UInt64) {
    self.emitter = emitter
    self.sequence = sequence
  }
}

public enum OrdnanceEnd: String, Codable, Sendable {
  case impact, rangeExpired, lifetimeExpired, targetLost, culled, ecm, destroyed, invalidState
}

private struct OrdnanceMotion: Sendable {
  let start: Vector3
  let end: Vector3
  let elapsed: Double
}

/// All motion is in canonical system space. Camera motion never changes this state.
public struct OrdnanceState: Equatable, Codable, Sendable {
  public let profile: OrdnanceProfile
  public let origin: AttackOrigin
  public let target: ActorIdentity?
  public let emissionPosition: Vector3
  public let inheritedVelocity: Vector3
  public private(set) var position: Vector3
  public private(set) var direction: Vector3
  public private(set) var propulsionTravel = 0.0
  public private(set) var lastUpdatedAt: Double
  public private(set) var muzzleCleared = false
  public private(set) var resistedECM: ECMActivationIdentity?
  public private(set) var termination: OrdnanceEnd?

  public init?(
    profile: OrdnanceProfile, origin: AttackOrigin, target: ActorIdentity? = nil,
    position: Vector3, direction: Vector3, launcherVelocity: Vector3 = .init(0, 0, 0),
    emissionPosition: Vector3? = nil
  ) {
    guard position.finite, emissionPosition?.finite ?? true, launcherVelocity.finite,
      let direction = Self.normalized(direction),
      origin.emissionID > 0, origin.emittedAt.isFinite, origin.emittedAt >= 0,
      let ordnance = origin.ordnance, ordnance != origin.owner,
      ordnance.system == origin.owner.system, ordnance.visit == origin.owner.visit,
      target != origin.owner, target != ordnance,
      profile == .plasma || target != nil
    else { return nil }
    if let target,
      target.system != origin.owner.system || target.visit != origin.owner.visit
    {
      return nil
    }
    self.profile = profile
    self.origin = origin
    self.target = target
    self.emissionPosition = emissionPosition ?? position
    self.position = position
    self.direction = direction
    self.inheritedVelocity = profile == .plasma ? launcherVelocity : .init(0, 0, 0)
    self.lastUpdatedAt = origin.emittedAt
  }

  public var velocity: Vector3 { direction * profile.speed + inheritedVelocity }
  public var valid: Bool {
    position.finite && emissionPosition.finite && inheritedVelocity.finite && direction.finite
      && abs(direction.length - 1) < 1e-6 && propulsionTravel.isFinite && propulsionTravel >= 0
      && propulsionTravel <= profile.range + 1e-6 && lastUpdatedAt.isFinite
      && origin.emittedAt.isFinite && origin.emittedAt >= 0 && lastUpdatedAt >= origin.emittedAt
      && lastUpdatedAt <= origin.emittedAt + profile.lifetime + 1e-6
      && origin.emissionID > 0
      && origin.ordnance.map {
        $0 != origin.owner && $0.system == origin.owner.system && $0.visit == origin.owner.visit
      } == true
      && (profile == .plasma || target != nil) && target != origin.owner
      && target != origin.ordnance
      && (target.map { $0.system == origin.owner.system && $0.visit == origin.owner.visit } ?? true)
  }

  /// One resisted activation is enough history: a different activation terminates the seeker.
  fileprivate mutating func receiveECM(_ pulses: [ECMActivationIdentity]) -> Bool {
    guard termination == nil, profile != .plasma else { return false }
    let ordered = pulses.filter {
      $0.emitter.system == origin.owner.system && $0.emitter.visit == origin.owner.visit
    }.sorted {
      $0.sequence == $1.sequence ? $0.emitter.entity < $1.emitter.entity : $0.sequence < $1.sequence
    }
    var resisted = false
    for pulse in ordered {
      if resistedECM == pulse { continue }
      if profile == .alienSeeker && resistedECM == nil {
        resistedECM = pulse
        resisted = true
      } else {
        termination = .ecm
        break
      }
    }
    return resisted
  }

  fileprivate mutating func clearMuzzle() { muzzleCleared = true }

  fileprivate mutating func finish(_ reason: OrdnanceEnd) {
    if termination == nil { termination = reason }
  }

  fileprivate mutating func move(context: EncounterContext) -> OrdnanceMotion? {
    move(until: context.physicalTime, target: target.flatMap { Self.actor($0, context: context) })
  }

  private mutating func move(until time: Double, target actor: ActorSnapshot?) -> OrdnanceMotion? {
    guard termination == nil, time - lastUpdatedAt > 1e-10 else { return nil }
    let remainingRange = max(0, profile.range - propulsionTravel) / profile.speed
    let remainingLife = max(0, origin.emittedAt + profile.lifetime - lastUpdatedAt)
    let guidanceStep = profile == .alienSeeker ? 1.0 / 120 : time - lastUpdatedAt
    let delta = min(
      time - lastUpdatedAt, guidanceStep, remainingRange, remainingLife)
    guard delta > 1e-10 else {
      finish(propulsionTravel >= profile.range - 1e-6 ? .rangeExpired : .lifetimeExpired)
      return nil
    }
    if profile != .plasma {
      guard let actor, actor.energy > 0
      else {
        finish(.targetLost)
        return nil
      }
      if let desired = Self.normalized(actor.position - position) {
        direction =
          profile == .alienSeeker
          ? Self.turned(direction, toward: desired, maximumAngle: 3 * delta) : desired
      }
    }
    let start = position
    position = position + velocity * delta
    guard position.finite else {
      position = start
      finish(.invalidState)
      return nil
    }
    propulsionTravel = min(profile.range, propulsionTravel + profile.speed * delta)
    lastUpdatedAt += delta
    return .init(start: start, end: position, elapsed: delta)
  }

  fileprivate mutating func impact(_ world: Vector3, fraction: Double, motion: OrdnanceMotion) {
    position = world
    propulsionTravel = max(0, propulsionTravel - profile.speed * motion.elapsed * (1 - fraction))
    lastUpdatedAt = max(origin.emittedAt, lastUpdatedAt - motion.elapsed * (1 - fraction))
    finish(.impact)
  }

  fileprivate mutating func enforceBounds() {
    if propulsionTravel >= profile.range - 1e-6 {
      finish(.rangeExpired)
    } else if lastUpdatedAt >= origin.emittedAt + profile.lifetime - 1e-8 {
      finish(.lifetimeExpired)
    }
  }

  private static func actor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot?
  {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private static func normalized(_ vector: Vector3) -> Vector3? {
    guard vector.finite else { return nil }
    let scale = max(abs(vector.x), max(abs(vector.y), abs(vector.z)))
    guard scale > 0 else { return nil }
    let scaled = Vector3(vector.x / scale, vector.y / scale, vector.z / scale)
    return scaled * (1 / hypot(hypot(scaled.x, scaled.y), scaled.z))
  }

  private static func turned(_ from: Vector3, toward to: Vector3, maximumAngle: Double) -> Vector3 {
    let angle = acos(max(-1, min(1, from.dot(to))))
    guard angle > maximumAngle else { return to }
    let cardinals = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
    let cardinal = cardinals.min { abs(from.dot($0)) < abs(from.dot($1)) } ?? cardinals[0]
    let axis = normalized(from.cross(to)) ?? normalized(from.cross(cardinal)) ?? cardinal
    let result = from * cos(maximumAngle) + axis.cross(from) * sin(maximumAngle)
    return normalized(result) ?? from
  }
}

public struct OrdnanceUpdate: Equatable, Sendable {
  public let bodyID: Int
  public let position: Vector3
  public let velocity: Vector3
  public let termination: OrdnanceEnd?
  public let hit: GameplayHit?
  public let incident: CombatIncident?
  public let resistedECM: Bool
  public let endedNow: Bool
}

/// Sealed only by the actual native swept-ordnance producer below; never decoded from a save.
struct NativeMissionOrdnanceImpactProof: Sendable {
  let projectileBody: SpaceBody
  let ordnance: OrdnanceState
  let contact: MissionCollisionContact
  let start: Vector3
  let end: Vector3
  let ignored: Set<Int>
  let includePlayer: Bool
  let physicalTime: Double
  let sceneRevision: UInt64
  let damage: Double
  fileprivate let curve: CurrentNewtOrdnanceCurveContact?

  fileprivate init(
    projectileBody: SpaceBody, ordnance: OrdnanceState, contact: MissionCollisionContact,
    start: Vector3, end: Vector3, ignored: Set<Int>, includePlayer: Bool,
    physicalTime: Double, sceneRevision: UInt64, damage: Double,
    curve: CurrentNewtOrdnanceCurveContact? = nil
  ) {
    self.projectileBody = projectileBody
    self.ordnance = ordnance
    self.contact = contact
    self.start = start
    self.end = end
    self.ignored = ignored
    self.includePlayer = includePlayer
    self.physicalTime = physicalTime
    self.sceneRevision = sceneRevision
    self.damage = damage
    self.curve = curve
  }
}

extension Game {
  @discardableResult
  mutating func advanceOrdnance(
    bodyID: Int, state: inout OrdnanceState, context: EncounterContext,
    activeECM: [ECMActivationIdentity] = []
  ) -> OrdnanceUpdate {
    advanceOrdnance(bodyID: bodyID, state: &state, context: context,
      activeECM: activeECM, preparedSteps: nil, terminal: nil, allocation: nil).update
  }

  @inline(never)
  private mutating func advanceOrdnance(
    bodyID: Int, state: inout OrdnanceState, context: EncounterContext,
    activeECM: [ECMActivationIdentity], preparedSteps: [PreparedOrdnanceStep]?,
    terminal: OrdnanceState?, allocation: GameplayOrdnanceAllocation?,
    nativeLeg: CurrentNewtNativeOrdnanceLeg? = nil, boundaryOnly: Bool = false
  ) -> GameplayOrdnanceAdvance {
    defer { observeSafeGunneryMissileEnd(state) }
    guard state.valid, context.physicalTime.isFinite,
      context.system == state.origin.owner.system, context.visit == state.origin.owner.visit,
      context.physicalTime >= state.lastUpdatedAt,
      context.system == storedFlightSimulation().system,
      context.visit == storedFlightSimulation().visit,
      abs(context.physicalTime - storedFlightSimulation().physicalTime) < 1e-8
    else { return .init(update: endOrdnance(bodyID: bodyID, state: &state, reason: .invalidState), outcome: .terminal) }
    guard
      let index = bodies.firstIndex(where: {
        $0.id == bodyID && $0.physical?.identity == state.origin.ordnance
      })
    else { return .init(update: endOrdnance(bodyID: bodyID, state: &state, reason: .culled), outcome: .terminal) }
    guard bodies[index].energy > 0 else {
      return .init(update: endOrdnance(bodyID: bodyID, state: &state, reason: .destroyed), outcome: .terminal)
    }
    let wasActive = state.termination == nil
    let resisted = state.receiveECM(activeECM)
    var outcome: GameplayOrdnanceAdvance.Outcome = state.termination == nil ? .unchanged : .terminal
    if boundaryOnly, state.termination == nil {
      if !state.preparedTargetIsLive(context: context) { state.finish(.targetLost) }
      else { state.enforceBounds() }
      if state.termination != nil { outcome = .terminal }
    } else if nativeLeg != nil, state.termination == nil,
      !state.preparedTargetIsLive(context: context) {
      // An earlier genuine same-frontier effect may have ended the original
      // target. Apply the existing lost-target policy even for a zero step.
      state.finish(.targetLost)
      outcome = .terminal
    }
    var hit: GameplayHit?
    var incident: CombatIncident?
    let beforeMotion = state
    var prepared = (preparedSteps ?? []).makeIterator()
    do {
      while true {
        let next: OrdnanceMotion?
        if preparedSteps != nil {
          guard state.termination == nil else { break }
          if let step = prepared.next() {
            if !state.preparedTargetIsLive(context: context) {
              state.finish(.targetLost)
              outcome = .terminal
              break
            }
            guard let motion = state.retainPreparedStep(step) else {
              throw NativeMissionImpactError.staleProof
            }
            next = motion
          } else {
            if let terminal, terminal.termination == .targetLost,
              context.physicalTime > state.lastUpdatedAt {
              state.finish(.targetLost)
              outcome = .terminal
            }
            next = nil
          }
        } else {
          next = state.move(context: context)
          if state.termination != nil { outcome = .terminal }
        }
        let motion: OrdnanceMotion
        if let next { motion = next }
        else if let observation = nativeLeg?.contact,
          observation.upperPhysicalTime == beforeMotion.lastUpdatedAt,
          observation.native.lowerTime == 0, observation.native.upperTime == 0,
          state.termination == nil {
          // A genuine initial solid observation consumes no invented motion.
          motion = .init(start: state.position, end: state.position, elapsed: 0)
        } else { break }
        updateMuzzleClearance(state: &state, position: motion.start, context: context)
        let observed: MissionCollisionContact?
        if let nativeLeg {
          if let observation = nativeLeg.contact {
            guard observation.upperPhysicalTime == state.lastUpdatedAt,
              observation.native.centre == state.position else { throw NativeMissionImpactError.staleProof }
            observed = try bindNativeOrdnanceCurveContact(observation)
          } else { observed = nil }
        } else {
          observed = try ordnanceCollision(bodyID: bodyID, state: state, motion: motion, context: context)
        }
        if let contact = observed {
          let retained = try retainOrdnanceContact(contact, bodyID: bodyID, index: index,
            state: &state, context: context, motion: motion, allocation: allocation, nativeLeg: nativeLeg)
          hit = retained.hit
          incident = retained.incident
          outcome = .terminal
          break
        }
        updateMuzzleClearance(state: &state, position: motion.end, context: context)
        state.enforceBounds()
        outcome = state.termination == nil ? .advanced : .terminal
      }
    } catch {
      // Admission/event pressure is retryable: neither an impact nor motion is committed.
      state = beforeMotion
      outcome = .refused
      hit = nil
      incident = nil
      if !(error is ScriptMissionEventCapacityError) {
        notify("ORDNANCE COLLISION UNAVAILABLE", voiced: false)
      }
    }
    bodies[index].position = storedFlightSimulation().pose.shipPoint(state.position)
    bodies[index].physical?.velocity = state.velocity
    if state.termination != nil {
      bodies[index].energy = 0
      commander.crimeLedger.finishEmission(state.origin.emissionID)
    }
    return .init(update: .init(
      bodyID: bodyID, position: state.position, velocity: state.velocity,
      termination: state.termination, hit: hit, incident: incident, resistedECM: resisted,
      endedNow: wasActive && state.termination != nil), outcome: outcome)
  }
  @inline(never)
  private mutating func retainOrdnanceContact(
    _ contact: MissionCollisionContact, bodyID: Int, index: Int, state: inout OrdnanceState,
    context: EncounterContext, motion: OrdnanceMotion, allocation: GameplayOrdnanceAllocation?,
    nativeLeg: CurrentNewtNativeOrdnanceLeg?
  ) throws -> (hit: GameplayHit, incident: CombatIncident?) {
    var incident: CombatIncident?
    let collision = contact.hit
    if handleNativePracticeContact(
      contact, origin: state.origin, kind: state.profile.attackKind, projectile: state)
    {
      incident = nil
    } else if contact.selectedTargetBody?.scriptNPC != nil {
      incident = try retainMissionOrdnanceContact(contact, bodyID: bodyID, index: index,
        state: state, context: context, motion: motion, allocation: allocation, nativeLeg: nativeLeg)
    } else {
      if let observation = nativeLeg?.contact {
        guard let allocation, let effect = applyNativeOrdnanceCurveHit(observation)
        else { throw NativeMissionImpactError.staleProof }
        incident = effect.incident
        allocation.effects.append(.combat(effect))
      } else if let allocation {
        guard let effect = applyNativeCombatHit(
          collision, origin: state.origin, kind: state.profile.attackKind,
          damage: ordnanceImpactDamage(state: state, hit: collision),
          emissionPosition: state.emissionPosition)
        else { throw NativeMissionImpactError.staleProof }
        incident = effect.incident
        allocation.effects.append(.combat(effect))
      } else {
        incident = applyCombatHit(
          collision, origin: state.origin, kind: state.profile.attackKind,
          damage: ordnanceImpactDamage(state: state, hit: collision),
          emissionPosition: state.emissionPosition)
      }
    }
    if let observation = nativeLeg?.contact {
      // The prepared actual path is already at this witnessed frontier.
      state.impact(observation.native.centre, fraction: 1, motion: motion)
    } else {
      let length = (motion.end - motion.start).length
      let fraction = length > 0 ? max(0, min(1, collision.distance / length)) : 0
      state.impact(
        storedFlightSimulation().pose.systemPoint(collision.point), fraction: fraction,
        motion: motion)
    }
    return (collision, incident)
  }

  @inline(never)
  private mutating func retainMissionOrdnanceContact(
    _ contact: MissionCollisionContact, bodyID: Int, index: Int, state: OrdnanceState,
    context: EncounterContext, motion: OrdnanceMotion, allocation: GameplayOrdnanceAllocation?,
    nativeLeg: CurrentNewtNativeOrdnanceLeg?
  ) throws -> CombatIncident {
    let collision = contact.hit
    let incident: CombatIncident
    let policy = ordnanceCollisionPolicy(bodyID: bodyID, state: state, context: context)
    let proof = NativeMissionOrdnanceImpactProof(
      projectileBody: bodies[index], ordnance: try requireStoredOrdnance(bodyID),
      contact: contact, start: storedFlightSimulation().pose.shipPoint(motion.start),
      end: storedFlightSimulation().pose.shipPoint(motion.end), ignored: policy.ignored,
      includePlayer: policy.includePlayer, physicalTime: context.physicalTime,
      sceneRevision: context.revision,
      damage: ordnanceImpactDamage(state: state, hit: collision), curve: nativeLeg?.contact)
    if let allocation {
      let applied = try applyNativeMissionOrdnanceImpact(proof)
      projectScriptMissionImpact(applied.receipt)
      incident = applied.incident
      allocation.effects.append(.mission(applied.clockEffect))
    } else {
      let applied = try applyMissionImpact(proof)
      projectScriptMissionImpact(applied.receipt)
      incident = applied.incident
    }
    return incident
  }


  @discardableResult
  mutating func endOrdnance(bodyID: Int, state: inout OrdnanceState, reason: OrdnanceEnd)
    -> OrdnanceUpdate
  {
    let wasActive = state.termination == nil
    state.finish(reason)
    if let index = bodies.firstIndex(where: {
      $0.id == bodyID && $0.physical?.identity == state.origin.ordnance
    }) {
      bodies[index].energy = 0
    }
    commander.crimeLedger.finishEmission(state.origin.emissionID)
    return .init(
      bodyID: bodyID, position: state.position, velocity: state.velocity,
      termination: state.termination, hit: nil, incident: nil, resistedECM: false,
      endedNow: wasActive)
  }

  private func updateMuzzleClearance(
    state: inout OrdnanceState, position: Vector3, context: EncounterContext
  ) {
    guard !state.muzzleCleared else { return }
    let center: Vector3
    let radius: Double
    if state.origin.owner == context.player.identity {
      center = context.player.position
      radius = commander.playerMesh.vertices.map(\.length).max() ?? 0
    } else if let body = bodies.first(where: {
      $0.physical?.identity == state.origin.owner && $0.energy > 0
    }) {
      center = commander.flightSimulation.pose.systemPoint(body.position)
      radius =
        body.scriptNPC == nil
        ? (gameplayMesh(for: body).vertices.map(\.length).max() ?? 0) : scriptNPCRadius(body)
    } else {
      state.clearMuzzle()
      return
    }
    if (position - center).length > radius + 1e-6 { state.clearMuzzle() }
  }

  private func requireStoredOrdnance(_ bodyID: Int) throws -> OrdnanceState {
    guard let state = bodies.first(where: { $0.id == bodyID })?.physical?.ordnance else {
      throw NativeMissionImpactError.staleProof
    }
    return state
  }

  private func ordnanceCollisionPolicy(
    bodyID: Int, state: OrdnanceState, context: EncounterContext
  ) -> (ignored: Set<Int>, includePlayer: Bool) {
    var ignored: Set<Int> = [bodyID]
    if !state.muzzleCleared,
      let owner = bodies.first(where: { $0.physical?.identity == state.origin.owner })
    {
      ignored.insert(owner.id)
    }
    return (
      ignored, energy > 0 && (state.muzzleCleared || state.origin.owner != context.player.identity)
    )
  }

  @inline(never)
  private func ordnanceCollision(
    bodyID: Int, state: OrdnanceState, motion: OrdnanceMotion, context: EncounterContext
  ) throws -> MissionCollisionContact? {
    let pose = storedFlightSimulation().pose
    let start = pose.shipPoint(motion.start)
    let end = pose.shipPoint(motion.end)
    let difference = end - start
    guard difference.length > 1e-8 else { return nil }
    let policy = ordnanceCollisionPolicy(bodyID: bodyID, state: state, context: context)
    return try nearestMissionCollision(
      from: start, direction: difference.unit, range: difference.length, radius: 0,
      excludingBodyIDs: policy.ignored, includePlayer: policy.includePlayer)
  }

  @inline(never)
  func validateNativeMissionOrdnanceImpactProof(_ proof: NativeMissionOrdnanceImpactProof) throws {
    if let observation = proof.curve {
      try validateNativeMissionOrdnanceCurveImpactProof(proof, observation: observation)
      return
    }
    try validateStaticNativeMissionOrdnanceImpactProof(proof)
  }

  @inline(never)
  private func validateStaticNativeMissionOrdnanceImpactProof(_ proof: NativeMissionOrdnanceImpactProof) throws {
    guard let context = gameplayContext(), context.physicalTime == proof.physicalTime,
      context.revision == proof.sceneRevision,
      nativeMissionProjectileBodyMatches(proof.projectileBody),
      proof.projectileBody.energy > 0, proof.projectileBody.scriptShot == nil,
      proof.projectileBody.physical?.ordnance == proof.ordnance, proof.ordnance.valid,
      proof.ordnance.termination == nil,
      proof.projectileBody.physical?.identity == proof.ordnance.origin.ordnance,
      proof.ordnance.origin.owner.system == context.system,
      proof.ordnance.origin.owner.visit == context.visit,
      proof.ordnance.lastUpdatedAt <= context.physicalTime,
      proof.start.finite, proof.end.finite, (proof.end - proof.start).length > 1e-8,
      proof.damage == ordnanceImpactDamage(state: proof.ordnance, hit: proof.contact.hit),
      let contact = try nearestMissionCollision(
        from: proof.start, direction: (proof.end - proof.start).unit,
        range: (proof.end - proof.start).length, radius: 0,
        excludingBodyIDs: proof.ignored, includePlayer: proof.includePlayer),
      contact == proof.contact
    else { throw NativeMissionImpactError.staleProof }
  }

  @inline(never)
  private func validateNativeMissionOrdnanceCurveImpactProof(_ proof: NativeMissionOrdnanceImpactProof,
    observation: CurrentNewtOrdnanceCurveContact) throws {
    try requireNativeMissionOrdnanceCurveInputs(proof, observation: observation)
    guard try bindNativeOrdnanceCurveContact(observation) == proof.contact
    else { throw NativeMissionImpactError.staleProof }
  }

  @inline(never)
  private func requireNativeMissionOrdnanceCurveInputs(_ proof: NativeMissionOrdnanceImpactProof,
    observation: CurrentNewtOrdnanceCurveContact) throws {
    guard let context = gameplayContext(), context.physicalTime == proof.physicalTime,
      context.revision == proof.sceneRevision, proof.physicalTime == observation.upperPhysicalTime,
      proof.contact.nativeCurveObservation === observation,
      nativeMissionProjectileBodyMatches(proof.projectileBody),
      proof.projectileBody.energy > 0, proof.projectileBody.scriptShot == nil,
      proof.projectileBody.physical?.ordnance == proof.ordnance, proof.ordnance.valid,
      proof.ordnance.termination == nil,
      proof.projectileBody.physical?.identity == observation.opening.actor,
      proof.projectileBody.physical?.attackOrigin == proof.ordnance.origin,
      observation.opening.matchesCurrentState(proof.ordnance,
        at: observation.scene.motion.opening.interval.start),
      proof.damage == ordnanceImpactDamage(state: proof.ordnance, hit: proof.contact.hit)
    else { throw NativeMissionImpactError.staleProof }
  }

  @inline(never)
  private func nativeOrdnanceUniqueBodyIndex(id: Int) -> Int? {
    bodies.withUnsafeBufferPointer { stored in
      var selected: Int?
      var count = 0
      for index in stored.indices {
        if stored.baseAddress!.advanced(by: index).pointee.id == id {
          count += 1; selected = index
        }
      }
      return count == 1 ? selected : nil
    }
  }

  @inline(never)
  private func nativeMissionProjectileBodyMatches(_ body: borrowing SpaceBody) -> Bool {
    withUnsafePointer(to: body) { expected in
      bodies.withUnsafeBufferPointer { stored in
        var selected: Int?
        var count = 0
        for index in stored.indices {
          if stored.baseAddress!.advanced(by: index).pointee.id == expected.pointee.id {
            count += 1; selected = index
          }
        }
        guard count == 1, let selected else { return false }
        return stored.baseAddress!.advanced(by: selected).pointee == expected.pointee
      }
    }
  }

  func ordnanceImpactDamage(state: OrdnanceState, hit: GameplayHit) -> Double {
    // Native energy-only targets were destroyed by one missile, including the 252-energy
    // Constrictor. New shielded NPC profiles use the finite weapon's actual damage instead.
    if state.profile == .standardMissile, case .body(let id) = hit.target,
      let body = bodies.first(where: { $0.id == id }), body.hull.isTargetShip,
      body.scriptNPC == nil,
      body.physical?.npc?.resources?.profile == .legacyEnergyOnly
    {
      return max(state.profile.damage, body.energy)
    }
    return state.profile.damage
  }
}

extension OrdnanceState {
  /// Pure preparation from an actual synchronized opening snapshot. This never writes Game,
  /// consumes ECM, seals a hit, advances a real clock or grants a native source capability.
  func prepareOuterTrajectory(until endTime: Double, context: EncounterContext)
    -> OuterOrdnanceTrajectory?
  {
    guard let prepared = prepareOuterSteps(until: endTime, context: context) else { return nil }
    return .init(before: self, proposed: prepared.proposed, endTime: endTime,
      legs: prepared.steps.map {
        .init(startTime: $0.after.lastUpdatedAt - $0.motion.elapsed, endTime: $0.after.lastUpdatedAt,
          start: $0.motion.start, end: $0.motion.end, velocity: $0.after.velocity)
      })
  }

  fileprivate func prepareOuterSteps(until endTime: Double, context: EncounterContext)
    -> (proposed: Self, steps: [PreparedOrdnanceStep])?
  {
    guard valid, termination == nil, context.system == origin.owner.system,
      context.visit == origin.owner.visit, context.physicalTime == lastUpdatedAt,
      endTime.isFinite, endTime >= context.physicalTime,
      endTime - context.physicalTime <= 0.1 + 1e-9
    else { return nil }
    let actor = target.flatMap { Self.actor($0, context: context) }
    var proposed = self
    var steps: [PreparedOrdnanceStep] = []
    while true {
      let before = proposed
      guard let motion = proposed.move(until: endTime, target: actor) else { break }
      steps.append(.init(before: before, after: proposed, motion: motion))
      proposed.enforceBounds()
    }
    return (proposed, steps)
  }
}

fileprivate struct PreparedOrdnanceStep: Sendable {
  let before: OrdnanceState
  let after: OrdnanceState
  let motion: OrdnanceMotion
}

/// One actual opening body and one prepared use of the existing guidance kernel.
/// Neither a decoded state nor caller-supplied IDs can construct this opening.
final class GameplayOrdnanceOpening: Sendable {
  let body: SpaceBody
  let actor: ActorIdentity
  let state: OrdnanceState
  let context: EncounterContext
  let epoch: UUID
  let endTime: Double
  let trajectory: OuterOrdnanceTrajectory
  fileprivate let steps: [PreparedOrdnanceStep]

  fileprivate init(body: SpaceBody, actor: ActorIdentity, state: OrdnanceState,
    context: EncounterContext, epoch: UUID, endTime: Double,
    proposed: OrdnanceState, steps: [PreparedOrdnanceStep])
  {
    self.body = body
    self.actor = actor
    self.state = state
    self.context = context
    self.epoch = epoch
    self.endTime = endTime
    self.steps = steps
    trajectory = .init(before: state, proposed: proposed, endTime: endTime,
      legs: steps.map {
        .init(startTime: $0.after.lastUpdatedAt - $0.motion.elapsed, endTime: $0.after.lastUpdatedAt,
          start: $0.motion.start, end: $0.motion.end, velocity: $0.after.velocity)
      })
  }

  /// Samples the original path, including guidance already selected for each leg.
  /// The result has no native contact, muzzle, ECM or allocation authority.
  func state(at time: Double) -> OrdnanceState? {
    guard time.isFinite, time >= state.lastUpdatedAt, time <= endTime else { return nil }
    if time == state.lastUpdatedAt { return state }
    for step in steps where time > step.before.lastUpdatedAt && time <= step.after.lastUpdatedAt {
      return step.before.samplePreparedStep(step, at: time)
    }
    return nil
  }

  /// Pure expected-path join for the actual scene owner. Actor, source, epoch
  /// and live clock qualification remain with that owner.
  func matchesCurrentState(_ candidate: OrdnanceState, at time: Double) -> Bool {
    guard let expected = state(at: time) else { return false }
    return candidate.lastUpdatedAt == time && candidate.hasPreparedKinematics(expected)
  }

  /// Actual selected kernel step, including a partial prefix's original end.
  /// Callers do not infer a new guidance clock from one-over-120 constants.
  func guidanceLeg(at time: Double) -> OuterOrdnanceTrajectory.Leg? {
    guard time.isFinite, let step = steps.first(where: {
      time >= $0.before.lastUpdatedAt && time < $0.after.lastUpdatedAt
    }) else { return nil }
    return .init(startTime: step.before.lastUpdatedAt, endTime: step.after.lastUpdatedAt,
      start: step.motion.start, end: step.motion.end, velocity: step.after.velocity)
  }

  func clockSamplingTimeError(start: Double, end: Double) -> Double? {
    let relevant = steps.filter { $0.after.lastUpdatedAt >= start && $0.before.lastUpdatedAt <= end }
    return CurrentNewtQueryFrame.clockSamplingTimeError(start: start, end: end,
      origins: relevant.map { $0.before.lastUpdatedAt }, aliases: relevant.map {
        .init(clock: $0.after.lastUpdatedAt, origin: $0.before.lastUpdatedAt, elapsed: $0.motion.elapsed)
      })
  }

  fileprivate func substeps(from start: Double, through end: Double) -> [PreparedOrdnanceStep]? {
    guard start.isFinite, end.isFinite, start >= state.lastUpdatedAt,
      end >= start, end <= endTime else { return nil }
    var result: [PreparedOrdnanceStep] = []
    for step in steps {
      let a = max(start, step.before.lastUpdatedAt)
      let b = min(end, step.after.lastUpdatedAt)
      guard b > a else { continue }
      guard let before = a == step.before.lastUpdatedAt ? step.before : state(at: a),
        let after = state(at: b) else { return nil }
      result.append(.init(before: before, after: after,
        motion: .init(start: before.position, end: after.position, elapsed: b - a)))
    }
    return result
  }
}

/// Native T0 collision preparation only. The real clock and live impact owners
/// must independently accept this same prefix before any effect can be retained.
final class GameplayOrdnancePreparedSlice: Sendable {
  let opening: GameplayOrdnanceOpening
  let before: OrdnanceState
  let context: EncounterContext
  let requestedEnd: Double
  let attainedEnd: Double
  let proposed: OrdnanceState
  let contact: MissionCollisionContact?
  let eventCapacity: ScriptMissionEventCapacityPlan?

  fileprivate init(opening: GameplayOrdnanceOpening, before: OrdnanceState,
    context: EncounterContext, requestedEnd: Double, proposed: OrdnanceState,
    contact: MissionCollisionContact?, eventCapacity: ScriptMissionEventCapacityPlan?)
  {
    self.opening = opening
    self.before = before
    self.context = context
    self.requestedEnd = requestedEnd
    self.proposed = proposed
    self.contact = contact
    self.eventCapacity = eventCapacity
    switch proposed.termination {
    case .impact, .rangeExpired, .lifetimeExpired: attainedEnd = proposed.lastUpdatedAt
    default: attainedEnd = requestedEnd
    }
  }
}

enum GameplayOrdnanceClockEffect: Sendable {
  case combat(NativeCombatHitClockEffect)
  case mission(NativeMissionOrdnanceClockEffect)

  func applying(to before: FlightSimulationState) -> FlightSimulationState? {
    switch self {
    case .combat(let effect): return effect.applying(to: before)
    case .mission(let effect): return effect.applying(to: before)
    }
  }
}

private final class GameplayOrdnanceAllocation {
  var effects: [GameplayOrdnanceClockEffect] = []
}

/// Reported by the actual motion/effect owner, including its caught refusal.
/// A restored cursor near a requested time cannot manufacture accepted motion.
private struct GameplayOrdnanceAdvance {
  enum Outcome { case unchanged, advanced, terminal, refused }
  let update: OrdnanceUpdate
  let outcome: Outcome

  var accepted: Bool {
    switch outcome {
    case .advanced, .terminal: return true
    case .unchanged, .refused: return false
    }
  }
}

/// Actual retained native effects. Replays only certificates returned by the real
/// combat owners; no closing counters or decoded incident can create an effect.
struct GameplayOrdnanceRetention: Sendable {
  let update: OrdnanceUpdate
  let motionRetained: Bool
  let clockEffects: [GameplayOrdnanceClockEffect]
  fileprivate let opening: FlightSimulationState
  fileprivate let closing: FlightSimulationState

  func applying(to before: FlightSimulationState) -> FlightSimulationState? {
    guard before == opening else { return nil }
    var expected = before
    for effect in clockEffects {
      guard let next = effect.applying(to: expected) else { return nil }
      expected = next
    }
    return expected == closing ? expected : nil
  }
}

extension OrdnanceState {
  fileprivate func preparedTargetIsLive(context: EncounterContext) -> Bool {
    profile == .plasma || (target.flatMap { Self.actor($0, context: context) }?.energy ?? 0) > 0
  }

  fileprivate func samplePreparedStep(_ step: PreparedOrdnanceStep, at time: Double) -> Self? {
    guard time > step.before.lastUpdatedAt, time <= step.after.lastUpdatedAt else { return nil }
    if time == step.after.lastUpdatedAt { return step.after }
    let elapsed = time - step.before.lastUpdatedAt
    var result = step.after
    result.position = step.before.position + step.after.velocity * elapsed
    result.propulsionTravel = min(profile.range, step.before.propulsionTravel + profile.speed * elapsed)
    result.lastUpdatedAt = time
    return result
  }

  fileprivate func hasPreparedKinematics(_ expected: Self) -> Bool {
    var comparison = self
    comparison.muzzleCleared = expected.muzzleCleared
    comparison.resistedECM = expected.resistedECM
    return comparison == expected
  }

  fileprivate mutating func retainPreparedStep(_ step: PreparedOrdnanceStep) -> OrdnanceMotion? {
    guard termination == nil, hasPreparedKinematics(step.before) else { return nil }
    position = step.after.position
    direction = step.after.direction
    propulsionTravel = step.after.propulsionTravel
    lastUpdatedAt = step.after.lastUpdatedAt
    return step.motion
  }
}

extension Game {
  /// Consume a source-sealed native clear/contact leg at its actually attained
  /// clock. The caller atomically retains the same shared scene and clock leg.
  /// A contact uses its true upper clock; clear uses the source-sealed subset.
  @inline(never)
  mutating func retainCurrentNewtNativeOrdnance(_ leg: CurrentNewtNativeOrdnanceLeg,
    activeECM: [ECMActivationIdentity] = [], admittedAtBoundary: CurrentNewtEndBirths? = nil
  ) throws -> GameplayOrdnanceRetention? {
    guard let inputs = try prepareCurrentNativeOrdnanceRetention(leg, activeECM: activeECM,
      admittedAtBoundary: admittedAtBoundary) else { return nil }
    return retainCurrentNativeOrdnance(leg, activeECM: activeECM, inputs: inputs)
  }

  private final class CurrentNativeOrdnanceRetentionInputs {
    let context: EncounterContext
    let index: Int
    let before: OrdnanceState
    let steps: [PreparedOrdnanceStep]
    init(context: EncounterContext, index: Int, before: OrdnanceState, steps: [PreparedOrdnanceStep]) {
      self.context = context; self.index = index; self.before = before; self.steps = steps
    }
  }

  @inline(never)
  private func prepareCurrentNativeOrdnanceRetention(_ leg: CurrentNewtNativeOrdnanceLeg,
    activeECM: [ECMActivationIdentity], admittedAtBoundary: CurrentNewtEndBirths?
  ) throws -> CurrentNativeOrdnanceRetentionInputs? {
    let interval = leg.scene.motion.opening.interval
    let attained = leg.attainedEnd
    guard interval.valid, attained >= interval.start, attained <= interval.end,
      leg.opening.epoch == nativeStationRuntimeEpoch,
      leg.scene.motion.opening.before.nativeStationRuntimeEpoch == nativeStationRuntimeEpoch,
      let frame = leg.scene.ordnanceFrame,
      frame.entries.contains(where: { $0 === leg.opening }),
      frame.epoch == nativeStationRuntimeEpoch,
      let context = gameplayContext(), context.system == frame.context.system,
      context.visit == frame.context.visit, context.physicalTime == attained,
      let index = nativeOrdnanceUniqueBodyIndex(id: leg.opening.body.id),
      bodies[index].energy > 0, bodies[index].physical?.identity == leg.opening.actor,
      let before = bodies[index].physical?.ordnance, before.valid, before.termination == nil,
      bodies[index].physical?.attackOrigin == before.origin,
      leg.opening.matchesCurrentState(before, at: interval.start),
      let guidance = leg.opening.guidanceLeg(at: interval.start), interval.end <= guidance.endTime,
      let steps = leg.opening.substeps(from: interval.start, through: attained), steps.count <= 1,
      try nativeOrdnanceSceneMatches(leg, at: attained, admittedAtBoundary: admittedAtBoundary)
    else { return nil }
    if let observation = leg.contact {
      guard observation.scene === leg.scene, observation.opening === leg.opening,
        observation.upperPhysicalTime == attained,
        observation.native.clockWindow?.start == interval.start,
        observation.native.clockWindow?.end == interval.end,
        observation.native.upperPhysicalTime == attained,
        attained > interval.start || (observation.native.lowerTime == 0 && observation.native.upperTime == 0)
      else { return nil }
    } else if attained <= interval.start { return nil }
    var preview = before
    _ = preview.receiveECM(activeECM)
    if preview.termination == nil, !preview.preparedTargetIsLive(context: context) {
      preview.finish(.targetLost)
    }
    if preview.termination == nil, let observation = leg.contact {
      let contact = try bindNativeOrdnanceCurveContact(observation)
      if contact.selectedTargetBody?.scriptNPC != nil && !nativePracticeReservedTarget(contact.hit) {
        _ = try preflightNativeMissionOrdnanceContact(bodyID: leg.opening.body.id,
          state: before, contact: contact)
      }
    }
    return .init(context: context, index: index, before: before, steps: steps)
  }

  @inline(never)
  private mutating func retainCurrentNativeOrdnance(_ leg: CurrentNewtNativeOrdnanceLeg,
    activeECM: [ECMActivationIdentity], inputs: CurrentNativeOrdnanceRetentionInputs
  ) -> GameplayOrdnanceRetention? {
    let context = inputs.context
    let index = inputs.index
    let before = inputs.before
    let steps = inputs.steps
    let openingFlight = storedFlightSimulation()
    var retained = self
    let allocation = GameplayOrdnanceAllocation()
    let missile = bodies[index]
    var state = before
    let result = retained.advanceOrdnance(bodyID: leg.opening.body.id, state: &state, context: context,
      activeECM: activeECM, preparedSteps: steps, terminal: leg.opening.trajectory.proposed,
      allocation: allocation, nativeLeg: leg)
    retained.bodies[index].physical?.ordnance = state
    retained.finishGameplayOrdnanceUpdate(result.update, missile: missile)
    let receipt = GameplayOrdnanceRetention(update: result.update, motionRetained: result.accepted,
      clockEffects: allocation.effects, opening: openingFlight, closing: retained.storedFlightSimulation())
    guard receipt.motionRetained, state.valid, retained.storedFlightSimulation().valid,
      receipt.applying(to: openingFlight) != nil else {
      return .init(update: .init(bodyID: leg.opening.body.id, position: before.position,
        velocity: before.velocity, termination: before.termination, hit: nil, incident: nil,
        resistedECM: false, endedNow: false), motionRetained: false, clockEffects: [],
        opening: openingFlight, closing: openingFlight)
    }
    self = retained
    return receipt
  }

  /// Rejoin the source-qualified captured scene after the actual common mover.
  /// The shared clock owner retains the real cause of earlier damage/removal;
  /// a fresh actor, changed fitting or unsupported component pose is refused.
  private func nativeOrdnanceSceneMatches(_ leg: CurrentNewtNativeOrdnanceLeg, at time: Double,
    admittedAtBoundary: CurrentNewtEndBirths?) throws -> Bool {
    let captured = leg.scene.motion.opening.before
    let start = leg.scene.motion.opening.interval.start
    let elapsed = time - start
    let originals = captured.bodies
    let originalActors = Set(originals.compactMap { $0.physical?.identity })
    let live = bodies.filter { $0.energy > 0 }
    let born: Set<ActorIdentity>
    let bornParts: [ActorIdentity: [CurrentNewtKitComponent]]
    if let admittedAtBoundary {
      guard admittedAtBoundary.matchesNewtBirths(self),
        let parts = admittedAtBoundary.components(in: self) else { return false }
      born = admittedAtBoundary.actors; bornParts = parts
    } else { born = []; bornParts = [:] }
    guard Set(live.map(\.id)).count == live.count,
      Set(live.compactMap { $0.physical?.identity }).count == live.count,
      live.allSatisfy({
      $0.physical.map { originalActors.contains($0.identity) || born.contains($0.identity) } == true
    }), celestials.count == captured.celestials.count,
      zip(celestials, captured.celestials).allSatisfy({ current, original in
        current.radius == original.radius
          && (commander.flightSimulation.pose.systemPoint(current.position)
            - captured.commander.flightSimulation.pose.systemPoint(original.position)).length < 1e-7
      }) else { return false }
    func samePose(_ a: ShipPose, _ b: ShipPose) -> Bool {
      // Same retained-transform join as G1's closed contact binder. This is
      // not a collision clearance or an absolute-clock error allowance.
      (a.position - b.position).length < 1e-7
        && (a.orientation.x - b.orientation.x).length < 1e-7
        && (a.orientation.y - b.orientation.y).length < 1e-7
        && (a.orientation.z - b.orientation.z).length < 1e-7
    }
    func samePart(_ part: CurrentNewtKitComponent, _ collider: CurrentNewtNativeCollider) -> Bool {
      guard let mesh = part.collisionMesh, let expected = collider.poseAt(elapsed) else { return false }
      return mesh.vertices == collider.mesh.vertices && mesh.faces == collider.mesh.faces
        && samePose(part.pose, expected)
    }
    // Only the actual Game-private mechanical-birth cohort may transfer an
    // existing attached component to its genuinely released endpoint actor.
    for (actor, parts) in bornParts where !originalActors.contains(actor) {
      guard let body = bodies.first(where: { $0.physical?.identity == actor }),
        let receipt = body.physical?.currentNewtKitReceipt, receipt.releasedAt == time,
        let parent = originals.first(where: { $0.physical?.identity == receipt.actuation.parent }),
        parent.physical?.currentNewtKitStock?.issue == receipt.issue,
        parts.filter({ $0.collisionMesh != nil }).allSatisfy({ part in
          leg.scene.colliders.contains {
            $0.actor == receipt.actuation.parent && $0.component == part.id && samePart(part, $0)
          }
        }) else { return false }
    }
    var partCache: [ActorIdentity: [CurrentNewtKitComponent]] = [:]
    for collider in leg.scene.colliders {
      guard let actor = collider.actor else { continue }
      if actor == commander.flightSimulation.player {
        if energy > 0 {
          guard let expected = collider.poseAt(elapsed), samePose(commander.flightSimulation.pose, expected),
            commander.playerMesh.vertices == collider.mesh.vertices,
            commander.playerMesh.faces == collider.mesh.faces else { return false }
        }
        continue
      }
      guard let original = originals.first(where: { $0.physical?.identity == actor }),
        let body = bodies.first(where: { $0.id == original.id && $0.physical?.identity == actor }),
        body.hull == original.hull, body.missionActorID == original.missionActorID,
        body.missionInstanceID == original.missionInstanceID,
        body.physical?.catalogueShipID == original.physical?.catalogueShipID,
        body.physical?.spawnIdentity == original.physical?.spawnIdentity,
        body.scriptNPC?.fit == original.scriptNPC?.fit
      else { return false }
      if body.energy <= 0 { continue }
      if let npc = body.scriptNPC, let oldNPC = original.scriptNPC {
        guard npc.components.allSatisfy({ key, value in
          oldNPC.components[key]?.identity == value.identity
        }) else { return false }
      }
      if let state = body.physical?.ordnance {
        guard body.physical?.attackOrigin == state.origin,
          let entry = leg.scene.ordnanceFrame?.entries.first(where: { $0.actor == actor }),
          entry.matchesCurrentState(state, at: start) || entry.matchesCurrentState(state, at: time)
        else { return false }
        continue // Other genuine projectiles are retained in the same transaction.
      }
      guard let expected = collider.poseAt(elapsed) else { return false }
      if body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil {
        let parts: [CurrentNewtKitComponent]
        if let cached = partCache[actor] { parts = cached }
        else {
          guard let current = try currentNewtGeometryComponents(for: body) else { return false }
          parts = current; partCache[actor] = current
        }
        if let part = parts.first(where: { $0.id == collider.component }) {
          guard samePart(part, collider) else { return false }
        } else {
          let released = bornParts.contains { podActor, podParts in
            guard let pod = bodies.first(where: { $0.physical?.identity == podActor }),
              let receipt = pod.physical?.currentNewtKitReceipt,
              receipt.actuation.parent == actor, receipt.releasedAt == time,
              receipt.issue == original.physical?.currentNewtKitStock?.issue
            else { return false }
            return podParts.contains { $0.id == collider.component && samePart($0, collider) }
          }
          guard released else { return false }
        }
      } else {
        guard samePose(modelPose(of: body), expected) else { return false }
      }
    }
    return true
  }

  /// Settle only a real current-clock terminal cause before a scene/guidance
  /// query. An empty guidance path never borrows a positive motion step.
  mutating func retainCurrentNewtNativeOrdnanceBoundary(_ opening: GameplayOrdnanceOpening,
    activeECM: [ECMActivationIdentity] = []) -> GameplayOrdnanceRetention? {
    guard opening.epoch == nativeStationRuntimeEpoch, let context = gameplayContext(),
      context.system == opening.context.system, context.visit == opening.context.visit,
      let index = bodies.firstIndex(where: { $0.id == opening.body.id }),
      bodies.filter({ $0.id == opening.body.id }).count == 1,
      bodies[index].energy > 0, bodies[index].physical?.identity == opening.actor,
      let before = bodies[index].physical?.ordnance, before.valid, before.termination == nil,
      bodies[index].physical?.attackOrigin == before.origin,
      context.physicalTime == before.lastUpdatedAt,
      opening.matchesCurrentState(before, at: context.physicalTime)
    else { return nil }
    var preview = before
    _ = preview.receiveECM(activeECM)
    if preview.termination == nil {
      if !preview.preparedTargetIsLive(context: context) { preview.finish(.targetLost) }
      else { preview.enforceBounds() }
    }
    guard preview.termination != nil else { return nil }
    let flight = commander.flightSimulation
    var retained = self
    var state = before
    let allocation = GameplayOrdnanceAllocation()
    let result = retained.advanceOrdnance(bodyID: opening.body.id, state: &state, context: context,
      activeECM: activeECM, preparedSteps: [], terminal: nil, allocation: allocation, boundaryOnly: true)
    retained.bodies[index].physical?.ordnance = state
    retained.finishGameplayOrdnanceUpdate(result.update, missile: bodies[index])
    let receipt = GameplayOrdnanceRetention(update: result.update, motionRetained: result.accepted,
      clockEffects: allocation.effects, opening: flight, closing: retained.commander.flightSimulation)
    guard receipt.motionRetained, state.valid, receipt.applying(to: flight) != nil else { return nil }
    self = retained
    return receipt
  }

  /// The scene query shares the actual native T0 muzzle rule without moving a
  /// copied Game to another time or inventing an emitter collision envelope.
  func preparedOrdnanceMuzzleCleared(_ state: OrdnanceState, context: EncounterContext) -> Bool {
    var prepared = state
    updateMuzzleClearance(state: &prepared, position: state.position, context: context)
    return prepared.muzzleCleared
  }

  func prepareGameplayOrdnanceOpening(bodyID: Int, until endTime: Double) -> GameplayOrdnanceOpening? {
    guard let context = gameplayContext(),
      let body = bodies.first(where: { $0.id == bodyID }), body.energy > 0,
      let physical = body.physical, let state = physical.ordnance,
      physical.identity == state.origin.ordnance, physical.attackOrigin == state.origin,
      let prepared = state.prepareOuterSteps(until: endTime, context: context)
    else { return nil }
    return .init(body: body, actor: physical.identity, state: state, context: context,
      epoch: nativeStationRuntimeEpoch, endTime: endTime,
      proposed: prepared.proposed, steps: prepared.steps)
  }

  func prepareGameplayOrdnanceSlice(_ opening: GameplayOrdnanceOpening, until endTime: Double)
    throws -> GameplayOrdnancePreparedSlice?
  {
    guard opening.epoch == nativeStationRuntimeEpoch, let context = gameplayContext(),
      context.system == opening.context.system, context.visit == opening.context.visit,
      let body = bodies.first(where: { $0.id == opening.body.id }), body.energy > 0,
      body.physical?.identity == opening.actor,
      let state = body.physical?.ordnance, state.valid, state.termination == nil,
      context.physicalTime == state.lastUpdatedAt,
      let expected = opening.state(at: context.physicalTime), state.hasPreparedKinematics(expected),
      let steps = opening.substeps(from: context.physicalTime, through: endTime)
    else { return nil }
    let sweep = try prepareOrdnanceSweep(bodyID: body.id, state: state,
      steps: steps, context: context, terminal: opening.trajectory.proposed, until: endTime)
    var eventCapacity: ScriptMissionEventCapacityPlan?
    if let contact = sweep.contact, contact.selectedTargetBody?.scriptNPC != nil,
      !nativePracticeReservedTarget(contact.hit) {
      eventCapacity = try preflightNativeMissionOrdnanceContact(bodyID: body.id, state: state, contact: contact)
    }
    return .init(opening: opening, before: state, context: context, requestedEnd: endTime,
      proposed: sweep.state, contact: sweep.contact, eventCapacity: eventCapacity)
  }

  @inline(never)
  private func prepareOrdnanceSweep(bodyID: Int, state initial: OrdnanceState,
    steps: [PreparedOrdnanceStep], context: EncounterContext, terminal: OrdnanceState,
    until endTime: Double)
    throws -> (state: OrdnanceState, contact: MissionCollisionContact?)
  {
    var state = initial
    for step in steps {
      guard state.termination == nil else { break }
      if !state.preparedTargetIsLive(context: context) {
        state.finish(.targetLost)
        break
      }
      guard let motion = state.retainPreparedStep(step) else { throw NativeMissionImpactError.staleProof }
      updateMuzzleClearance(state: &state, position: motion.start, context: context)
      if let contact = try ordnanceCollision(bodyID: bodyID, state: state, motion: motion, context: context) {
        let length = (motion.end - motion.start).length
        let fraction = length > 0 ? max(0, min(1, contact.hit.distance / length)) : 0
        state.impact(storedFlightSimulation().pose.systemPoint(contact.hit.point),
          fraction: fraction, motion: motion)
        return (state, contact)
      }
      updateMuzzleClearance(state: &state, position: motion.end, context: context)
      state.enforceBounds()
    }
    if steps.isEmpty, endTime > initial.lastUpdatedAt,
      let reason = terminal.termination, terminal.lastUpdatedAt == state.lastUpdatedAt {
      state.finish(reason)
    }
    return (state, nil)
  }

  /// Consume only this actually attained positive-time prefix. The immutable
  /// opening path is reused; no guidance, firing, RNG or real clock runs here.
  @inline(never)
  mutating func retainPreparedGameplayOrdnance(
    _ slice: GameplayOrdnancePreparedSlice, activeECM: [ECMActivationIdentity] = []
  ) throws -> GameplayOrdnanceRetention? {
    guard let rejoined = try rejoinPreparedGameplayOrdnance(slice, activeECM: activeECM) else { return nil }
    return retainRejoinedGameplayOrdnance(slice, activeECM: activeECM, rejoined: rejoined)
  }

  private final class RejoinedGameplayOrdnance {
    let context: EncounterContext
    let index: Int
    let steps: [PreparedOrdnanceStep]
    init(context: EncounterContext, index: Int, steps: [PreparedOrdnanceStep]) {
      self.context = context; self.index = index; self.steps = steps
    }
  }

  @inline(never)
  private func rejoinPreparedGameplayOrdnance(
    _ slice: GameplayOrdnancePreparedSlice, activeECM: [ECMActivationIdentity]
  ) throws -> RejoinedGameplayOrdnance? {
    guard slice.opening.epoch == nativeStationRuntimeEpoch, let context = gameplayContext(),
      context.system == slice.context.system, context.visit == slice.context.visit,
      context.physicalTime == slice.attainedEnd,
      slice.attainedEnd > slice.context.physicalTime,
      let index = bodies.firstIndex(where: { $0.id == slice.opening.body.id }),
      bodies[index].energy > 0, bodies[index].physical?.identity == slice.opening.actor,
      bodies[index].physical?.attackOrigin == slice.before.origin,
      bodies[index].physical?.ordnance == slice.before,
      let steps = slice.opening.substeps(
        from: slice.context.physicalTime,
        through: slice.contact == nil ? slice.attainedEnd : slice.requestedEnd)
    else { return nil }
    // A contact repeats its original segment so the rounded impact clock is not
    // converted back into a potentially shorter ray. Its real first hit must
    // still match at exactly the already attained clock before effects run.
    // Rejoin genuine current geometry at the attained clock. A T0 prediction
    // alone cannot authorize damage after an intervening contact or scene change.
    var preview = slice.before
    _ = preview.receiveECM(activeECM)
    if preview.termination == nil {
      let current = try prepareOrdnanceSweep(bodyID: slice.opening.body.id, state: preview,
        steps: steps, context: context, terminal: slice.opening.trajectory.proposed,
        until: slice.contact == nil ? slice.attainedEnd : slice.requestedEnd)
      guard samePreparedOrdnanceContact(slice, current: current) else { return nil }
      if slice.contact != nil {
        guard current.state.lastUpdatedAt == slice.attainedEnd else { return nil }
      }
    }
    return .init(context: context, index: index, steps: steps)
  }

  @inline(never)
  private mutating func retainRejoinedGameplayOrdnance(
    _ slice: GameplayOrdnancePreparedSlice, activeECM: [ECMActivationIdentity],
    rejoined: RejoinedGameplayOrdnance
  ) -> GameplayOrdnanceRetention? {
    let context = rejoined.context
    let index = rejoined.index
    let steps = rejoined.steps
    let openingFlight = storedFlightSimulation()
    // This is a transaction at the already attained real clock. The candidate
    // supplies no future geometry, origin, contact or allocation authority.
    var retained = self
    let allocation = GameplayOrdnanceAllocation()
    let missile = bodies[index]
    var state = slice.before
    let result = retained.advanceOrdnance(bodyID: slice.opening.body.id, state: &state, context: context,
      activeECM: activeECM, preparedSteps: steps,
      terminal: slice.opening.trajectory.proposed, allocation: allocation)
    retained.bodies[index].physical?.ordnance = state
    retained.finishGameplayOrdnanceUpdate(result.update, missile: missile)
    let receipt = GameplayOrdnanceRetention(update: result.update,
      motionRetained: result.accepted,
      clockEffects: allocation.effects,
      opening: openingFlight, closing: retained.storedFlightSimulation())
    guard receipt.motionRetained, state.valid, state.lastUpdatedAt <= slice.attainedEnd,
      retained.storedFlightSimulation().valid,
      receipt.applying(to: openingFlight) != nil else {
      return .init(update: .init(bodyID: slice.opening.body.id,
        position: slice.before.position, velocity: slice.before.velocity,
        termination: slice.before.termination, hit: nil, incident: nil,
        resistedECM: false, endedNow: false), motionRetained: false,
        clockEffects: [], opening: openingFlight, closing: openingFlight)
    }
    self = retained
    return receipt
  }

  private func samePreparedOrdnanceContact(_ slice: GameplayOrdnancePreparedSlice,
    current: (state: OrdnanceState, contact: MissionCollisionContact?))
    -> Bool
  {
    switch (slice.contact, current.contact) {
    case (nil, nil):
      return current.state.hasPreparedKinematics(slice.proposed)
    case (let before?, let now?):
      return before.hit.target == now.hit.target && before.victimPart == now.victimPart
        && before.componentUUID == now.componentUUID
        && (current.state.position - slice.proposed.position).length < 1e-7
        && abs(current.state.lastUpdatedAt - slice.proposed.lastUpdatedAt) < 1e-8
        && current.state.termination == .impact
    default: return false
    }
  }
}
