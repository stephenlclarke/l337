import Foundation
import os

/// Original synchronous beam queries finish before the live damage path opens.
private final class GameplayNPCBeamPreparation {
  let index: Int
  let owner: ActorIdentity
  let position: Vector3
  let contact: MissionCollisionContact
  let flightBeforeEmission: FlightSimulationState
  let laser: LaserKind

  @inline(never)
  init(
    index: Int, owner: ActorIdentity, position: Vector3,
    contact: consuming MissionCollisionContact,
    flightBeforeEmission: consuming FlightSimulationState, laser: LaserKind
  ) {
    self.index = index
    self.owner = owner
    self.position = position
    self.contact = consume contact
    self.flightBeforeEmission = consume flightBeforeEmission
    self.laser = laser
  }
}

private final class GameplayNPCBeamEmission {
  let preparation: GameplayNPCBeamPreparation
  let origin: AttackOrigin

  @inline(never)
  init(preparation: GameplayNPCBeamPreparation, origin: AttackOrigin) {
    self.preparation = preparation
    self.origin = origin
  }
}

/// Only actual producer outputs and allocator receipts are observed. No replay or recheck.
final class GameplayEncounterBirthDiagnostic: Sendable {
  struct Request: Sendable {
    let identity: SpawnIdentity
    let catalogueShipID: String?
    let configuration: String?
  }
  struct Observation: Sendable {
    let openingDecision: UInt64
    let decision: UInt64
    let admitted: UInt64
    let time: Double
    let requests: [Request]
    let receipts: [SpawnReceipt]
  }
  private let state = OSAllocatedUnfairLock(initialState: [Observation]())
  private let endpointRefusalState = OSAllocatedUnfairLock(initialState: String?.none)

  /// The actual refused query only; this observation grants no clearance or retry authority.
  func recordEndpointRefusal(_ detail: String) {
    endpointRefusalState.withLock { $0 = detail }
  }

  var endpointRefusal: String? { endpointRefusalState.withLock { $0 } }

  @inline(never)
  func record(openingDecision: UInt64, director: borrowing EncounterDirector,
    plan: borrowing EncounterPlan, receipts: [SpawnReceipt], time: Double) {
    guard director.decisionCount != openingDecision || !receipts.isEmpty else { return }
    let observation = Observation(openingDecision: openingDecision, decision: director.decisionCount,
      admitted: director.admittedCount, time: time,
      requests: plan.batches.flatMap(\.requests).prefix(32).map {
        .init(identity: $0.identity, catalogueShipID: $0.catalogueShipID,
          configuration: $0.currentNewtKitConfiguration)
      }, receipts: Array(receipts.prefix(32)))
    state.withLock {
      if $0.count == 8 { $0.removeFirst() }
      $0.append(observation)
    }
  }

  var observations: [Observation] { state.withLock { $0 } }

  func detail() -> String {
    observations.map { observation in
      let requests = observation.requests.map {
        "spawn=\($0.identity),ship=\($0.catalogueShipID ?? "nil"),kit=\($0.configuration ?? "nil")"
      }.joined(separator: ";")
      let receipts = observation.receipts.map {
        "spawn=\($0.request),actor=\(String(describing: $0.actor)),refusal=\(String(describing: $0.refusal))"
      }.joined(separator: ";")
      return "time=\(observation.time),decisions=\(observation.openingDecision)->\(observation.decision)"
        + ",admitted=\(observation.admitted),requests=[\(requests)],receipts=[\(receipts)]"
    }.joined(separator: " | ")
  }
}

/// Values that remain necessary after the encounter producer and source checks return.
private final class GameplayIntentFrame {
  let context: EncounterContext
  let intents: [NPCIntent]
  let bornNewtActors: Set<ActorIdentity>

  @inline(never)
  init(context: consuming EncounterContext, intents: [NPCIntent], bornNewtActors: Set<ActorIdentity>) {
    self.context = consume context
    self.intents = intents
    self.bornNewtActors = bornNewtActors
  }
}

private struct GameplayNPCBeamRequest {
  let bodyID: Int
  let target: ActorIdentity
  let mining: Bool
}

private struct GameplayNPCBeamAim {
  let index: Int
  let owner: ActorIdentity
  let position: Vector3
  let direction: Vector3
  let range: Double
  let alignment: Double
  let distance: Double
}

extension Game {
  @inline(never)
  mutating func advanceGameplayEncounters(delta: Double) {
    guard let frame = prepareGameplayIntentFrame(delta: delta) else { return }
    advanceClassicMissionActors(context: frame.context, delta: delta)
    for intent in frame.intents {
      if frame.bornNewtActors.contains(intent.actor) { continue }
      applyGameplayIntent(intent, context: frame.context, delta: delta)
    }
  }

  @inline(never)
  private mutating func prepareGameplayIntentFrame(delta: Double) -> GameplayIntentFrame? {
    ensurePhysicalActors()
    let openingActors = Set(bodies.compactMap { $0.physical?.identity })
    advanceEMPActors()
    advanceNPCResources(delta: delta)
    _ = persistNPCStates()
    advanceUnboundNPCs()
    admitPersistentNPCs()
    guard let context = gameplayContext() else { return nil }
    let hasStation = bodies.contains { $0.id == 0 && $0.hull == .station && $0.energy > 0 }
    let security: SecurityPlan
    if hasStation {
      security = commander.stationSecurity.advance(context: context)
    } else {
      security = .init(
        encounters: .init(
          system: context.system, visit: context.visit,
          revision: context.revision, batches: [], intents: []), notices: [])
    }
    let policeReceipts = admitEncounterPlan(security.encounters)
    commander.stationSecurity.acknowledge(receipts: policeReceipts)
    for notice in security.notices where message != notice.text || messageTime <= 0 {
      notify(notice.text)
    }
    guard let current = gameplayContext() else { return nil }
    var director = commander.encounterDirector ?? EncounterDirector(context: current)
    let openingDecision = director.decisionCount
    let plan = director.advance(context: current)
    let receipts = admitEncounterPlan(plan)
    director.acknowledge(receipts: receipts)
    nativeEncounterBirthDiagnostic?.record(openingDecision: openingDecision, director: director,
      plan: plan, receipts: receipts, time: current.physicalTime)
    commander.encounterDirector = director
    activateNearbyMiningFields()
    activateNearbySalvageSites()
    admitPendingOre()
    admitPendingCargo()
    admitPendingSalvage()
    if nativeCrimboLifecycleAvailable { advanceNativeCrimbo(delta: delta) }
    guard let live = gameplayContext() else { return nil }
    let intents = (TrafficIntent.intents(context: live) + security.encounters.intents).filter {
      !isNativeCrimboMember($0.actor)
    }
    let bornNewtActors = Set(bodies.compactMap { body -> ActorIdentity? in
      guard let physical = body.physical, !openingActors.contains(physical.identity),
        physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil
      else { return nil }
      return physical.identity
    })
    for index in bodies.indices where bodies[index].physical?.spawnIdentity != nil {
      if let actor = bodies[index].physical?.identity, bornNewtActors.contains(actor) { continue }
      let cooldown = max(0, (bodies[index].physical?.laserCooldown ?? 0) - delta)
      bodies[index].physical?.laserCooldown = cooldown
    }
    return .init(context: live, intents: intents, bornNewtActors: bornNewtActors)
  }

  /// Retained classic hulls use native steering and weapons, with one later translation owner.
  /// Profiled craft keep their authored driver; unjoined bodies gain no mission AI authority.
  @inline(never)
  private mutating func advanceClassicMissionActors(context: EncounterContext, delta: Double) {
    let bodyIDs = bodies.filter {
      $0.energy > 0 && $0.scriptNPC == nil && $0.scriptShot == nil
        && $0.missionActorID != nil && $0.physical?.spawnIdentity != nil
    }.map(\.id)
    for bodyID in bodyIDs {
      guard let intent = classicMissionIntent(bodyID: bodyID, context: context) else { continue }
      applyGameplayIntent(intent, context: context, delta: delta)
    }
  }

  @inline(never)
  private func classicMissionIntent(bodyID: Int, context: EncounterContext) -> NPCIntent? {
    guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID),
      let body = bodies.first(where: { $0.id == bodyID }),
      let binding = try? MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body, context: context),
      let instance = commander.scriptState.instances[descriptor.instanceID],
      let pack = scriptPack(for: instance),
      let encounter = pack.manifest.encounters?.first(where: { $0.id == descriptor.encounterID }),
      let declared = encounter.actors.first(where: { $0.id == descriptor.alias }),
      let action = body.physical?.npc?.intention
    else { return nil }
    switch action {
    case .engage(let target):
      guard declared.hostile, target == context.player.identity else { return nil }
    case .navigate, .flee, .dock: break
    case .mine, .scoop: return nil
    }
    return .init(actor: binding.nativeActor, action: action)
  }

  mutating func activateNearbyMiningFields() {
    guard let context = gameplayContext() else { return }
    let observers =
      [context.player.position]
      + context.actors.filter { $0.npc?.role == .miner && $0.energy > 0 }.map(\.position)
    for field in miningFields
    where observers.contains(where: {
      let observer = $0
      return (observer - field.position).length < 2500
        || field.rocks.contains { rock in
          guard let breakup = commander.miningLedger.breakups[rock.identity] else { return false }
          return (observer - breakup.position(at: context.physicalTime)).length < 2500
        }
    }) {
      let requests = field.rocks.compactMap { rock -> SpawnRequest? in
        guard
          !commander.miningLedger.isDepleted(rock.identity)
            || commander.miningLedger.breakups[rock.identity] != nil,
          !bodies.contains(where: { $0.physical?.rock == rock.identity })
        else { return nil }
        return .init(
          identity: .init(
            system: context.system, visit: context.visit,
            sequence: UInt64(rock.identity.field) * 12 + UInt64(rock.identity.rock) + 1,
            member: 0, producer: .asteroids),
          population: .asteroid, hull: .asteroid,
          position: commander.miningLedger.breakups[rock.identity]?.position(
            at: context.physicalTime)
            ?? rock.position,
          orientation: Basis3(),
          velocity: commander.miningLedger.breakups[rock.identity]?.motion.velocity
            ?? .init(0, 0, 0),
          npc: nil, rock: rock.identity,
          payload: nil, priority: .ordinary)
      }
      let receipts = admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: requests, atomic: false)], intents: []))
      for receipt in receipts where receipt.refusal == nil {
        guard let actor = receipt.actor,
          let request = requests.first(where: { $0.identity == receipt.request }),
          let rock = request.rock, commander.miningLedger.breakups[rock] != nil
        else { continue }
        commander.miningLedger.bindBreakup(rock: rock, actor: actor)
      }
    }
  }

  mutating func admitPendingOre() {
    guard let context = gameplayContext() else { return }
    let requests = commander.miningLedger.pendingSpawnRequests(
      context: context, fields: miningFields)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    commander.miningLedger.acknowledge(receipts: receipts)
  }

  @inline(never)
  private mutating func applyGameplayIntent(
    _ intent: NPCIntent, context: EncounterContext, delta: Double
  ) {
    guard let index = gameplayIntentEnabledIndex(intent, context: context),
      let request = prepareGameplayIntent(intent, index: index, context: context, delta: delta)
    else { return }
    emitGameplayNPCBeam(bodyID: request.bodyID, target: request.target, context: context, mining: request.mining)
  }

  @inline(never)
  private func gameplayIntentEnabledIndex(_ intent: NPCIntent, context: EncounterContext) -> Int? {
    guard
      let index = bodies.firstIndex(where: {
        $0.physical?.identity == intent.actor && $0.energy > 0
          && $0.physical?.spawnIdentity != nil
      }), context.actors.contains(where: { $0.identity == intent.actor })
    else { return nil }
    guard
      bodies[index].physical?.suspendedNPCIntention == nil
        || bodies[index].physical?.npc?.intention != nil
    else { return nil }
    guard !isEMPDisabled(bodies[index]) else { return nil }
    return index
  }

  @inline(never)
  private mutating func prepareGameplayIntent(
    _ intent: NPCIntent, index: Int, context: EncounterContext, delta: Double
  ) -> GameplayNPCBeamRequest? {
    guard let actor = context.actors.first(where: { $0.identity == intent.actor }) else { return nil }
    bodies[index].hostile = intent.action == .engage(context.player.identity)
    // A fleeing trader keeps its original destination for later recovery.
    if bodies[index].physical?.npc?.role != .trader {
      bodies[index].physical?.npc?.intention = intent.action
    }
    switch intent.action {
    case .navigate(let destination, let speed):
      steerGameplayActor(
        index: index, toward: destination, speed: speed, context: context, delta: delta)
    case .flee(let identity):
      guard let threat = gameplayActor(identity, context: context) else { return nil }
      let away = (actor.position - threat.position).unit
      steerGameplayActor(
        index: index, toward: actor.position + away * 6000,
        speed: actor.maximumSpeedUnitsPerSecond, context: context, delta: delta)
    case .engage(let identity):
      observeNPCBeam(.engage, actor: intent.actor, position: bodies[index].position)
      guard let target = gameplayActor(identity, context: context), target.energy > 0 else {
        observeNPCBeam(.targetUnavailable, actor: intent.actor)
        return nil
      }
      var destination = target.position
      if identity == context.player.identity {
        let surface = Self.nativePlayerSurfaceAim(
          from: bodies[index].position, mesh: nativeGuidanceStoredPlayerMesh())
        destination = storedFlightSimulation().pose.systemPoint(surface)
      }
      steerGameplayActor(
        index: index, toward: destination, speed: actor.maximumSpeedUnitsPerSecond,
        stopDistance: 500, context: context, delta: delta)
      return .init(bodyID: bodies[index].id, target: identity, mining: false)
    case .mine(let identity):
      guard let rock = context.actors.first(where: { $0.rock == identity && $0.energy > 0 }) else {
        return nil
      }
      steerGameplayActor(
        index: index, toward: rock.position, speed: actor.maximumSpeedUnitsPerSecond,
        stopDistance: 250, context: context, delta: delta)
      return .init(bodyID: bodies[index].id, target: rock.identity, mining: true)
    case .scoop(let payload):
      guard let pod = context.actors.first(where: { $0.payload == payload && $0.energy > 0 }) else {
        return nil
      }
      steerGameplayActor(
        index: index, toward: pod.position, speed: min(80, actor.maximumSpeedUnitsPerSecond),
        stopDistance: 0, context: context, delta: delta)
      if (pod.position - actor.position).length < 85 {
        collectOreForNPC(actor: intent.actor, payload: payload, context: context)
      }
    case .dock(let station):
      guard station == context.anchors.station.identity else { return nil }
      let permission = commander.stationSecurity.dockingPermission(
        for: actor.identity, context: context)
      let destination =
        permission.allowed
        ? context.anchors.station.position : context.anchors.station.exitPosition
      steerGameplayActor(
        index: index, toward: destination, speed: min(80, actor.maximumSpeedUnitsPerSecond),
        stopDistance: permission.allowed ? 0 : 400, context: context, delta: delta)
      if permission.allowed && (actor.position - destination).length < 80 {
        // Departure is a traffic transition, never a death or bounty settlement.
        let departing = bodies[index]
        guard retireRecoveredEMPActor(actor.identity, reason: .docked) else { return nil }
        _ = commander.npcPersistence.terminal(actor: actor.identity, reason: .docked)
        clearRemovedTarget(departing)
        bodies.removeAll { $0.id == departing.id }
      }
    }
    return nil
  }

  private func gameplayActor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot?
  {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private mutating func steerGameplayActor(
    index: Int, toward destination: Vector3, speed requestedSpeed: Double,
    stopDistance: Double = 100, context: EncounterContext, delta: Double
  ) {
    guard let physical = bodies[index].physical,
      let actor = context.actors.first(where: { $0.identity == physical.identity })
    else { return }
    let craft: ShipPerformance?
    if let id = actor.catalogueShipID, OriginalBisonActivation.contains(id) {
      guard let source = OriginalBisonActivation.source(for: id) else { return }
      craft = source.game
    } else if let id = actor.catalogueShipID {
      guard let source = OriginalFleetRuntimeHullSource.source(for: id) else { return }
      craft = source.performance
    } else {
      craft = ShipCatalogue.nativeShip(actor.hull)?.game
    }
    let acceleration = max(1, (craft?.acceleration ?? 2) * 18)
    let offset = destination - actor.position
    let desired = offset.unit
    let heading = actor.orientation.z.unit
    let axis = heading.cross(desired)
    let angle = acos(max(-1, min(1, heading.dot(desired))))
    let turn = min(angle, max(craft?.pitch ?? 1, craft?.yaw ?? 1) * delta)
    let tangent = axis.length > 1e-8 ? axis.unit : actor.orientation.y
    let forward = (heading * cos(turn) + tangent.cross(heading) * sin(turn)).unit
    let up = abs(forward.y) > 0.95 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
    let right = up.cross(forward).unit
    bodies[index].orientation.x = commander.flightSimulation.pose.shipVector(right)
    bodies[index].orientation.y = commander.flightSimulation.pose.shipVector(
      forward.cross(right).unit)
    bodies[index].orientation.z = commander.flightSimulation.pose.shipVector(forward)
    let brakingSpeed = sqrt(2 * acceleration * max(0, offset.length - stopDistance))
    let speed = max(0, min(requestedSpeed, actor.maximumSpeedUnitsPerSecond, brakingSpeed))
    let desiredVelocity = forward * speed
    let change = desiredVelocity - physical.velocity
    let impulse = min(change.length, acceleration * delta)
    bodies[index].physical?.velocity = physical.velocity + change.unit * impulse
  }

  @inline(never)
  mutating func emitGameplayNPCBeam(
    bodyID: Int, target identity: ActorIdentity, context: EncounterContext, mining: Bool = false
  ) {
    guard
      let preparation = prepareGameplayNPCBeam(
        bodyID: bodyID, target: identity, context: context, mining: mining),
      let emission = prepareGameplayNPCBeamEmission(preparation),
      applyGameplayNPCBeamImpact(emission)
    else { return }
    finishGameplayNPCBeam(emission)
  }

  @inline(never)
  private mutating func prepareGameplayNPCBeam(
    bodyID: Int, target identity: ActorIdentity, context: borrowing EncounterContext, mining: Bool
  ) -> GameplayNPCBeamPreparation? {
    guard let index = gameplayNPCBeamEnabledIndex(bodyID: bodyID),
      let aim = prepareGameplayNPCBeamAim(index: index, target: identity, context: context, mining: mining)
    else { return nil }
    return prepareAimedGameplayNPCBeam(aim, bodyID: bodyID, target: identity, context: context, mining: mining)
  }

  @inline(never)
  private mutating func prepareAimedGameplayNPCBeam(
    _ aim: GameplayNPCBeamAim, bodyID: Int, target identity: ActorIdentity,
    context: borrowing EncounterContext, mining: Bool
  ) -> GameplayNPCBeamPreparation? {
    let contact: MissionCollisionContact
    do {
      guard let candidate = try nearestMissionCollision(
        from: aim.position, direction: aim.direction, range: aim.range, radius: 0,
        excludingBodyIDs: [bodyID], includePlayer: true)
      else {
        observeNPCBeam(.rayMiss, actor: aim.owner, position: aim.position,
          alignment: aim.alignment, distance: aim.distance)
        return nil
      }
      contact = candidate
    } catch {
      observeNPCBeam(.rayQueryRefused, actor: aim.owner, position: aim.position,
        alignment: aim.alignment, distance: aim.distance)
      return nil
    }
    let hit = contact.hit
    let intended =
      identity == context.player.identity
      ? hit.target == .player
      : bodies.first(where: { $0.physical?.identity == identity }).map {
        hit.target == .body($0.id)
      } == true
    // An incoming missile can physically intercept a beam aimed at its actual launcher.
    // Other actors remain obstructions and cannot redirect this emission.
    let incoming = contact.selectedTargetBody
    let system = context.system
    let visit = context.visit
    let interceptsIncomingMissile =
      !mining && incoming?.hull == .missile
      && incoming?.physical?.identity.system == system
      && incoming?.physical?.identity.visit == visit
      && incoming?.physical?.ordnance?.termination == nil
      && incoming?.physical?.ordnance?.target == aim.owner
      && incoming?.physical?.ordnance?.origin.owner == identity
      && incoming?.physical?.ordnance?.origin.ordnance == incoming?.physical?.identity
    let flightBeforeEmission = storedFlightSimulation()
    guard intended || interceptsIncomingMissile else {
      observeNPCBeam(.obstructed, actor: aim.owner, position: aim.position,
        alignment: aim.alignment, contact: hit.target)
      return nil
    }
    let laser: LaserKind = mining ? .mining : .pulse
    if contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: aim.owner, damage: laser.damage, laser: laser, mount: .front)
      } catch {
        observeNPCBeam(.preflight, actor: aim.owner, contact: hit.target)
        return nil
      }
    }
    return .init(
      index: aim.index, owner: aim.owner, position: aim.position, contact: contact,
      flightBeforeEmission: flightBeforeEmission, laser: laser)
  }

  @inline(never)
  private mutating func gameplayNPCBeamEnabledIndex(bodyID: Int) -> Int? {
    guard let index = bodies.firstIndex(where: { $0.id == bodyID }), bodies[index].nativeGeometryHasPhysical()
    else { return nil }
    guard !isEMPDisabled(bodies[index]) else {
      observeNPCBeam(.readiness, actor: bodies[index].nativeGeometryIdentity()!, position: bodies[index].position)
      return nil
    }
    return index
  }

  @inline(never)
  private mutating func prepareGameplayNPCBeamAim(
    index: Int, target identity: ActorIdentity, context: borrowing EncounterContext, mining: Bool
  ) -> GameplayNPCBeamAim? {
    guard let actor = bodies[index].physical else { return nil }
    guard actor.laserCooldown <= 0, bodies[index].energy > 1,
      actor.npc?.resources?.canFire ?? true
    else {
      observeNPCBeam(.readiness, actor: actor.identity, position: bodies[index].position)
      return nil
    }
    guard let target = gameplayActor(identity, context: context) else {
      observeNPCBeam(.targetUnavailable, actor: actor.identity)
      return nil
    }
    if let npc = actor.npc, npc.role != .mission, let id = actor.catalogueShipID {
      guard NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
        catalogueShipID: id, hull: bodies[index].hull, npc: npc, missiles: bodies[index].missiles)
      else {
        observeNPCBeam(.source, actor: actor.identity)
        return nil
      }
    }
    if mining, let id = actor.catalogueShipID {
      guard let source = OriginalFleetRuntimeHullSource.source(for: id),
        source.performance.workTools?.contains(.miningLaser) == true
      else {
        observeNPCBeam(.tool, actor: actor.identity)
        return nil
      }
    }
    let position = bodies[index].position
    let destination = storedFlightSimulation().pose.shipPoint(target.position)
    let direction = destination - position
    let range = mining ? 500.0 : 1500.0
    // Acquisition permits a near-forward target; the fixed front mount still fires forward.
    let beamDirection = bodies[index].orientation.z.unit
    let distance = direction.length
    let alignment = bodies[index].orientation.z.dot(direction.unit)
    guard distance <= range, alignment > 0.98 else {
      observeNPCBeam(.acquisition, actor: actor.identity, position: position,
        alignment: alignment, distance: distance)
      return nil
    }
    return .init(index: index, owner: actor.identity, position: position,
      direction: beamDirection, range: range, alignment: alignment, distance: distance)
  }

  @inline(never)
  private mutating func prepareGameplayNPCBeamEmission(_ preparation: GameplayNPCBeamPreparation)
    -> GameplayNPCBeamEmission?
  {
    guard let origin = makeAttackOrigin(owner: preparation.owner) else {
      observeNPCBeam(.origin, actor: preparation.owner, contact: preparation.contact.hit.target)
      return nil
    }
    return .init(preparation: preparation, origin: origin)
  }

  @inline(never)
  private mutating func applyGameplayNPCBeamImpact(_ emission: GameplayNPCBeamEmission) -> Bool {
    let preparation = emission.preparation
    if preparation.contact.selectedTargetBody?.scriptNPC != nil {
      guard
        let receipt = try? applyNativeMissionContact(
          preparation.contact, origin: emission.origin, damage: preparation.laser.damage,
          laser: preparation.laser, mount: .front,
          emissionPosition: gameplayNPCBeamWorldPosition(preparation.position))
      else {
        commander.flightSimulation = preparation.flightBeforeEmission
        observeNPCBeam(.impact, actor: preparation.owner, contact: preparation.contact.hit.target,
          emission: emission.origin.emissionID)
        return false
      }
      projectScriptMissionImpact(receipt)
    } else {
      let incident = applyCombatHit(
        preparation.contact.hit, origin: emission.origin, kind: .laser,
        damage: preparation.laser.damage, laser: preparation.laser, mount: .front,
        emissionPosition: gameplayNPCBeamWorldPosition(preparation.position))
      observeNPCBeam(incident == nil ? .recordRefused : .recorded, actor: preparation.owner,
        contact: preparation.contact.hit.target, emission: emission.origin.emissionID,
        incident: incident?.id)
    }
    return true
  }

  /// Complete the original pose query before entering the native impact/recording frames.
  @inline(never)
  private func gameplayNPCBeamWorldPosition(_ position: Vector3) -> Vector3 {
    commander.flightSimulation.pose.systemPoint(position)
  }

  @inline(never)
  private mutating func finishGameplayNPCBeam(_ emission: GameplayNPCBeamEmission) {
    let index = emission.preparation.index
    bodies[index].physical?.laserCooldown = emission.preparation.laser.firingInterval
    bodies[index].energy -= 1
    bodies[index].physical?.npc?.resources?.recordBeam(heat: 10)
    commander.crimeLedger.finishEmission(emission.origin.emissionID)
  }

  private mutating func collectOreForNPC(
    actor: ActorIdentity, payload: PayloadIdentity, context: EncounterContext
  ) {
    guard let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
      let npc = bodies[index].physical?.npc
    else { return }
    var cargo = Array(repeating: 0, count: CommodityIdentity.allCases.count)
    for amount in npc.ordinaryCargo {
      guard amount.valid, cargo[amount.commodity.rawValue] <= Int.max / 17 - amount.quantity else {
        return
      }
      cargo[amount.commodity.rawValue] += amount.quantity
    }
    let capacity =
      bodies[index].physical?.catalogueShipID.flatMap { ShipCatalogue.ship($0)?.game?.cargo }
      ?? ShipCatalogue.nativeShip(bodies[index].hull)?.game?.cargo ?? 20
    let used = CommodityIdentity.allCases.reduce(0) {
      $0 + ($1.unit == "t" ? cargo[$1.rawValue] : 0)
    }
    let receipt = collectOrdinaryPayload(
      payload: payload, into: &cargo, freeTonnes: max(0, capacity - used),
      hasScoops: npc.hasFuelScoops == true, approachAllowed: true, protection: context.protection)
    if case .collected = receipt {
      bodies[index].physical?.npc?.cargoProvenance = .recorded
      bodies[index].physical?.npc?.ordinaryCargo = CommodityIdentity.allCases.compactMap {
        cargo[$0.rawValue] > 0 ? .init(commodity: $0, quantity: cargo[$0.rawValue]) : nil
      }
      bodies.removeAll { $0.physical?.payload == payload }
    }
  }
}
