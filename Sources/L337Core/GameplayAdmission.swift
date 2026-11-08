import Foundation

extension Game {
  /// One runtime allocator admits complete batches against the current scene,
  /// including reserves. Proposals never allocate identities themselves.
  @inline(never)
  mutating func admitEncounterPlan(_ plan: EncounterPlan) -> [SpawnReceipt] {
    // Empty plans have no admission effects. The frame adopts existing actors
    // once; every real request still performs the complete native preflight.
    guard plan.batches.contains(where: { !$0.requests.isEmpty }) else { return [] }
    return admitNonemptyEncounterPlan(plan)
  }

  @inline(never)
  private mutating func admitNonemptyEncounterPlan(_ plan: EncounterPlan) -> [SpawnReceipt] {
    ensurePhysicalActors()
    guard let context = gameplayContext(), plan.system == context.system,
      plan.visit == context.visit, plan.revision == context.revision
    else {
      return plan.batches.flatMap(\.requests).map {
        .init(request: $0.identity, actor: nil, refusal: .staleContext)
      }
    }
    return admitCurrentEncounterPlan(plan, context: context)
  }

  @inline(never)
  private mutating func admitCurrentEncounterPlan(
    _ plan: EncounterPlan, context: EncounterContext
  ) -> [SpawnReceipt] {
    var receipts: [SpawnReceipt] = []
    for batch in plan.batches {
      if batch.atomic, let refusal = batchRefusal(batch.requests) {
        receipts += batch.requests.map { .init(request: $0.identity, actor: nil, refusal: refusal) }
        continue
      }
      for request in batch.requests {
        if let id = request.catalogueShipID, OriginalDetailedHullStage.blocksRuntime(id) {
          receipts.append(.init(request: request.identity, actor: nil, refusal: .unqualifiedOriginalHull))
          continue
        }
        if let existing = bodies.first(where: { $0.physical?.spawnIdentity == request.identity }) {
          if request.currentNewtKitConfiguration == CurrentBisonWideShoePhysicalSource.configurationID {
            // This journal version cannot own a published/commissioned actor.
            receipts.append(.init(request: request.identity, actor: nil, refusal: .unqualifiedOriginalHull))
            continue
          }
          receipts.append(
            .init(request: request.identity, actor: existing.physical?.identity, refusal: nil))
          continue
        }
        if let refusal = batchRefusal([request]) {
          receipts.append(.init(request: request.identity, actor: nil, refusal: refusal))
          continue
        }
        if request.currentNewtKitConfiguration == CurrentBisonWideShoePhysicalSource.configurationID {
          receipts.append(constructReservedBisonBody(request, context: context))
          continue
        }
        guard let actor = commander.flightSimulation.allocateActor() else {
          receipts.append(.init(request: request.identity, actor: nil, refusal: .reservedCapacity))
          continue
        }
        receipts.append(constructAdmittedEncounterBody(request, actor: actor, context: context))
      }
    }
    return receipts
  }

  /// Qualified preflight above is unchanged. Only the real journal reserves
  /// the actor. Physical refusal retains that unobserved reservation; complete
  /// body construction/publication remains barred until an actual completed
  /// state owner and its reviewed journal version exist.
  @inline(never)
  private mutating func constructReservedBisonBody(
    _ request: SpawnRequest, context: EncounterContext
  ) -> SpawnReceipt {
    do {
      let owner = try reserveBisonUnobservedUnits(request: request, context: context)
      try requireBisonUnitCommissioning(owner)
      // Journal v2 carries no completed-state authority, even if a future
      // commissioning operation returns. Do not publish an UNOBSERVED owner.
      return .init(request: request.identity, actor: nil, refusal: .unqualifiedOriginalHull)
    } catch {
      return .init(request: request.identity, actor: nil, refusal: .staleContext)
    }
  }

  @inline(never)
  private mutating func constructAdmittedEncounterBody(
    _ request: SpawnRequest, actor: ActorIdentity, context: EncounterContext
  ) -> SpawnReceipt {
    let pose = commander.flightSimulation.pose
    let nativeOreMotion: Bool
    if request.identity.producer == .mining, request.population == .cargo,
      request.hull == .cargo, request.npc == nil, request.rock == nil,
      request.catalogueShipID == nil, case .ore? = request.payload
    {
      nativeOreMotion = true
    } else {
      nativeOreMotion = false
    }
    var body = SpaceBody(
      id: nextBodyID, hull: request.hull, position: pose.shipPoint(request.position))
    nextBodyID += 1
    body.orientation.x = pose.shipVector(request.orientation.x)
    body.orientation.y = pose.shipVector(request.orientation.y)
    body.orientation.z = pose.shipVector(request.orientation.z)
    body.rotationRate = request.npc == nil ? 0.5 : 0
    // Native ore declares physical angular motion; do not add legacy display spin.
    if nativeOreMotion { body.rotationRate = 0 }
    if request.identity.producer == .derelicts {
      body.rotationRate = 0
      body.missiles = 0
      body.ecmEnabled = false
    }
    body.hostile = request.npc?.intention == .engage(context.player.identity)
    if let rock = miningFields.flatMap(\.rocks).first(where: { $0.identity == request.rock }) {
      body.energy = commander.miningLedger.remainingEnergy(for: rock)
    }
    var npc = request.npc
    if npc != nil, npc?.resources == nil, request.priority != .mission,
      let performance = request.catalogueShipID.flatMap({ ShipCatalogue.ship($0)?.game })
        ?? ShipCatalogue.nativeShip(request.hull)?.game
    {
      npc?.resources = NPCResources.stock(performance)
    }
    if let resources = npc?.resources {
      body.energy = request.energy ?? resources.energyCapacity
    } else if let energy = request.energy {
      body.energy = energy
    }
    body.physical = .init(
      identity: actor, population: request.population, npc: npc,
      velocity: request.velocity, rock: request.rock, payload: request.payload,
      spawnIdentity: request.identity, catalogueShipID: request.catalogueShipID,
      angularVelocity: request.angularVelocity, salvage: request.salvage)
    if request.identity.producer == .derelicts || nativeOreMotion {
      body.physical?.canonicalSpin = true
    }
    if request.currentNewtKitConfiguration != nil {
      guard let stock = issueCurrentNewtKit(request: request, body: body, actor: actor, context: context) else {
        return .init(request: request.identity, actor: nil, refusal: .staleContext)
      }
      body.physical?.currentNewtKitStock = stock
      body.physical?.canonicalSpin = true
      body.rotationRate = 0
    } else if let retained = retainedCurrentNewtKitStock(for: request) {
      // Restoration copies the existing issue/depletion; it never calls the birth issuer.
      guard let observed = retained.observedForRestoration(at: context.physicalTime) else {
        return .init(request: request.identity, actor: nil, refusal: .staleContext)
      }
      body.physical?.currentNewtKitStock = observed
      body.physical?.canonicalSpin = true
      body.rotationRate = 0
    }
    if request.identity.producer != .persistence && request.identity.producer != .emp,
      let snapshot = NPCPersistenceSnapshot.capture(
        body: body, pose: pose, physicalTime: context.physicalTime,
        protection: context.protection),
      case .refused = commander.npcPersistence.capture(snapshot, protection: context.protection)
    {
      return .init(request: request.identity, actor: nil, refusal: .reservedCapacity)
    }
    bodies.append(body)
    return .init(request: request.identity, actor: actor, refusal: nil)
  }

  /// A single currently installed kit supplies the physical proposal. The actual
  /// producer commits its stock debit/person receipt in the same candidate turn.
  @inline(never)
  mutating func admitCurrentOccupiedNewtPod(
    _ release: CurrentNewtPodReleaseRequest
  ) -> SpawnReceipt {
    let ordinal = release.issue.person.ordinal
    let member: UInt16 = (0..<EMPState.maximumPeople).contains(ordinal) ? UInt16(ordinal) + 1 : 0
    let spawn = SpawnIdentity(
      system: release.system, visit: release.visit, sequence: release.actuation.sequence,
      member: member, producer: .emp)
    guard let context = gameplayContext(),
      release.system == context.system, release.visit == context.visit,
      release.revision == context.revision, release.physicalTime == context.physicalTime,
      release.issue.structurallyValid,
      release.issue.person.ordinal >= 0, release.issue.person.ordinal < EMPState.maximumPeople,
      let state = commander.savedEMPState, state.valid,
      let record = state.records[release.issue.person.source],
      record.valid, !record.terminal, !record.isRecovered, record.crewAboard > 0,
      record.source == release.actuation.source,
      record.sequence == release.actuation.sequence,
      record.hull.binding == release.actuation.parent,
      record.nextDueCrew(at: context.physicalTime) == release.issue.person.ordinal,
      context.physicalTime < (record.crewDeadline ?? -1),
      let parentIndex = bodies.firstIndex(where: {
        $0.physical?.identity == release.actuation.parent
      }),
      bodies.filter({ $0.physical?.identity == release.actuation.parent }).count == 1,
      isEMPDisabled(bodies[parentIndex]),
      let parent = bodies[parentIndex].physical,
      parent.catalogueShipID == release.issue.birthLoad.catalogueShipID,
      parent.empSource == record.source,
      let stock = parent.currentNewtKitStock,
      stock == record.hull.body.physical?.currentNewtKitStock,
      stock.issue == record.custody.original.body.physical?.currentNewtKitStock?.issue,
      CurrentOccupiedNewtValidation.releaseRequest(release, matches: stock),
      CurrentOccupiedNewtValidation.currentLoad(
        release.loadAtRelease, body: bodies[parentIndex], record: record),
      let source = CurrentNewtKitSource.current, source.matches(release.issue),
      source.matches(stock, at: context.physicalTime)
    else { return .init(request: spawn, actor: nil, refusal: .staleContext) }
    let liveParent = CurrentNewtKitReceipt.BodyState(
      pose: modelPose(of: bodies[parentIndex]), velocity: parent.velocity,
      angularVelocity: parent.angularVelocity)
    // The current source must prove actual timed travel, work, full mass/tensor,
    // live pre-release motion and the installed bay corridor before parent exclusion.
    guard source.matches(release, liveParent: liveParent),
      let capsule = ShipCatalogue.ship("SH040"),
      capsule.catalogue.objectKind == .capsule,
      let performance = OriginalFleetR3Data.contract(for: capsule.id)?.performance,
      capsule.game == performance, performance.energy.isFinite, performance.energy > 0,
      let geometry = Self.currentNewtPodCollisionMesh(source: source),
      let radius = geometry.vertices.map(\.length).max(),
      radius.isFinite, radius > 0,
      !bodies.contains(where: { $0.physical?.spawnIdentity == spawn }),
      !state.records.values.contains(where: { other in
        other.pods.contains { $0.body.physical?.currentNewtKitReceipt?.issue.kitID == release.issue.kitID }
      })
    else { return .init(request: spawn, actor: nil, refusal: .unqualifiedOriginalHull) }
    let request = SpawnRequest(
      identity: spawn, population: .cargo, hull: .cargo,
      position: release.pod.pose.position, orientation: release.pod.pose.orientation,
      velocity: release.pod.velocity, npc: nil, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: capsule.id, energy: performance.energy,
      angularVelocity: release.pod.angularVelocity,
      salvage: .init(
        category: .occupiedPod, ownership: .occupied, claimant: record.source,
        wreck: nil, section: nil, lot: nil,
        bounds: .init(center: .init(0, 0, 0), radius: radius), workSurfaces: []))
    guard let releaseBudget = currentNewtReleaseBudget(
      stock: stock, parent: release.actuation.parent, context: context)
    else { return .init(request: spawn, actor: nil, refusal: .reservedCapacity) }
    if let refusal = admissionCapacityRefusal(request, context: context, budget: releaseBudget) {
      return .init(request: spawn, actor: nil, refusal: refusal)
    }
    guard spawnParametersSafe(
      request, context: context, measuredRadius: radius,
      measuredMaximumEnergy: performance.energy),
      spawnSeparationIsSafe(
        position: request.position, radius: radius, context: context,
        excludedActor: release.actuation.parent, fragmentRequest: request)
    else { return .init(request: spawn, actor: nil, refusal: .unsafePosition) }
    var candidate = self
    guard candidate.nextBodyID < Int.max,
      let actor = candidate.commander.flightSimulation.allocateActor()
    else { return .init(request: spawn, actor: nil, refusal: .reservedCapacity) }
    let receipt = candidate.constructAdmittedEncounterBody(request, actor: actor, context: context)
    guard receipt.actor == actor, receipt.refusal == nil,
      let podIndex = candidate.bodies.firstIndex(where: { $0.physical?.identity == actor })
    else { return receipt }
    let delivery = CurrentNewtKitReceipt(
      issue: release.issue, actuation: release.actuation,
      podActor: actor, podSpawn: spawn, releasedAt: release.physicalTime,
      loadAtRelease: release.loadAtRelease,
      parent: release.parent, pod: release.pod,
      parentMass: release.parentMass, podMass: release.podMass,
      energyJoules: release.energyJoules, remainingCharges: release.remainingCharges)
    guard delivery.structurallyValid,
      source.matches(delivery, observedAt: release.physicalTime)
    else {
      return .init(request: spawn, actor: nil, refusal: .unqualifiedOriginalHull)
    }
    candidate.bodies[podIndex].physical?.empCrewPod = release.issue.person
    candidate.bodies[podIndex].physical?.currentNewtKitReceipt = delivery
    candidate.bodies[podIndex].physical?.canonicalSpin = true
    candidate.bodies[podIndex].rotationRate = 0
    self = candidate
    return receipt
  }

  /// Only the actual installed subject can consume its already counted pod slot.
  /// Reconcile the complete live budget so a foreign cargo count cannot stand in for it.
  @inline(never)
  func currentNewtReleaseBudget(
    stock: CurrentNewtKitStock, parent: ActorIdentity, context: EncounterContext
  ) -> AdmissionBudget? {
    let reserved = bodies.compactMap { body -> (ActorIdentity, CurrentNewtKitStock)? in
      guard let physical = body.physical, let installed = physical.currentNewtKitStock,
        installed.phase != .released
      else { return nil }
      return (physical.identity, installed)
    }
    guard reserved.allSatisfy({ $0.1.structurallyValid }),
      Set(reserved.map({ $0.1.issue.kitID })).count == reserved.count,
      reserved.filter({ $0.0 == parent && $0.1 == stock }).count == 1,
      reserved.filter({ $0.1.issue.kitID == stock.issue.kitID }).count == 1,
      bodies.count <= Int.max - reserved.count
    else { return nil }
    var expected: [PopulationClass: Int] = [:]
    for body in bodies where body.id != 0 {
      if let population = body.physical?.population { expected[population, default: 0] += 1 }
    }
    expected[.cargo, default: 0] += reserved.count
    guard context.budget.total == bodies.count + reserved.count,
      context.budget.active.values.allSatisfy({ $0 >= 0 }),
      context.budget.active.filter({ $0.value > 0 }) == expected.filter({ $0.value > 0 }),
      context.budget.maximum == AdmissionBudget().maximum,
      context.budget.policeReserve == AdmissionBudget().policeReserve,
      context.budget.missionReserve == AdmissionBudget().missionReserve,
      context.budget.active[.cargo, default: 0] > 0, context.budget.total > 0
    else { return nil }
    var budget = context.budget
    budget.total -= 1
    budget.active[.cargo, default: 0] -= 1
    return budget
  }

  /// Practice uses the native reserve and measured geometry policy for the whole volume.
  /// No existing actor is moved, replaced or relabelled during this read-only preflight.
  func gameplayPracticeAdmissionRefusal(
    _ practice: NativePracticeState, prepared: [SpaceBody], context: EncounterContext
  ) -> AdmissionRefusal? {
    let flight = commander.flightSimulation
    guard practice.valid, practice.endedAt == nil,
      context.system == systemIdentity, context.visit == flight.visit,
      context.revision == gameplayRevision, context.physicalTime == flight.physicalTime,
      prepared.allSatisfy({ practice.beacon(for: $0, pose: flight.pose) != nil }),
      Set(prepared.compactMap { $0.physical?.identity }).count == prepared.count
    else { return .staleContext }
    guard bodies.reduce(0, { $0 + $1.scriptNativeUnits }) + prepared.count <= 1024 else {
      return .reservedCapacity
    }
    var meshes: [Int: Mesh] = [:]
    for body in bodies where body.energy > 0 {
      if body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil {
        guard let envelope = currentNewtBroadPhaseEnvelope(for: body) else { return .unsafePosition }
        meshes[body.id] = envelope
      } else { meshes[body.id] = scriptNPCMesh(body) ?? gameplayMesh(for: body) }
    }
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 80
    guard
      NativePracticeAdmission.volumeClear(
        practice, context: context, bodies: bodies, meshes: meshes, pose: flight.pose,
        playerRadius: playerRadius)
    else { return .unsafePosition }
    let registeredStations = Set(
      commander.nativeStations?.ledger.records.compactMap { record in
        record.identity.system == context.system ? record.binding?.bodyID : nil
      } ?? [])
    var budget = context.budget
    for body in prepared {
      guard let spawn = body.physical?.spawnIdentity else { return .staleContext }
      var request = SpawnRequest(
        identity: spawn, population: .mission, hull: .cargo,
        position: flight.pose.systemPoint(body.position),
        orientation: practice.permission.frame.orientation, velocity: .init(0, 0, 0),
        npc: nil, rock: nil, payload: nil, priority: .mission)
      request.energy = NativePracticeSource.energy
      if let refusal = admissionCapacityRefusal(request, context: context, budget: budget) {
        return refusal
      }
      guard
        spawnParametersSafe(
          request, context: context, measuredRadius: NativePracticeSource.radius,
          measuredMaximumEnergy: NativePracticeSource.energy)
      else { return .unsafePosition }
      if let refusal = Self.gameplayMissionActorSceneClearanceRefusal(
        original: self, center: request.position, radius: NativePracticeSource.radius,
        context: context, registeredStationBodies: registeredStations)
      {
        return refusal
      }
      budget.total += 1
      budget.active[.mission, default: 0] += 1
    }
    return nil
  }

  @inline(never)
  private mutating func batchRefusal(_ requests: [SpawnRequest]) -> AdmissionRefusal? {
    guard let context = gameplayContext() else { return .staleContext }
    return preparedBatchRefusal(requests, context: context)
  }

  @inline(never)
  private mutating func preparedBatchRefusal(
    _ requests: [SpawnRequest], context: EncounterContext
  ) -> AdmissionRefusal? {
    if requests.contains(where: { request in
      if request.currentNewtKitConfiguration != nil,
        CurrentNewtKitSource.birthSource(for: request, context: context) == nil
      { return true }
      if let id = request.catalogueShipID { return OriginalDetailedHullStage.blocksRuntime(id) }
      return request.hull.isTargetShip && ShipCatalogue.nativeShip(request.hull) == nil
    }) { return .unqualifiedOriginalHull }
    let fresh = requests.filter { request in
      !bodies.contains { $0.physical?.spawnIdentity == request.identity }
    }
    guard Set(fresh.map(\.identity)).count == fresh.count else { return .staleContext }
    guard UInt64(fresh.count) <= UInt64.max - storedFlightSimulation().nextActor,
      fresh.count <= Int.max - nextBodyID
    else { return .reservedCapacity }
    let newNPCs = fresh.filter {
      $0.npc != nil && $0.npc?.role != .mission && $0.identity.producer != .persistence
        && $0.identity.producer != .emp
    }.count
    guard newNPCs <= NPCPersistenceLedger.maximumEntries - storedNPCPersistenceCount() else {
      return .reservedCapacity
    }
    var budget = context.budget
    var recoveredSecuritySources = Set<ActorIdentity>()
    for request in fresh {
      guard OriginalBisonActivation.matchesRequest(request, context: context) else {
        return .staleContext
      }
      guard OriginalFleetRuntimeHullSource.matchesAmbientTrader(request, context: context) else {
        return .staleContext
      }
      guard OriginalFleetRuntimeHullSource.matchesAmbientNonTrader(request, context: context) else {
        return .staleContext
      }
      guard securitySpawnSourceIsValid(request, context: context) else { return .staleContext }
      if let source = request.recoveredSecuritySource,
        !recoveredSecuritySources.insert(source).inserted
      { return .staleContext }
      let kitReserve = request.currentNewtKitConfiguration != nil
        || retainedCurrentNewtKitStock(for: request)?.remaining == 1
      if kitReserve {
        guard budget.ordinaryRemaining >= 2,
          budget.active[.cargo, default: 0] < PopulationClass.cargo.maximum
        else { return .reservedCapacity }
      }
      if let refusal = admissionCapacityRefusal(request, context: context, budget: budget) {
        return refusal
      }
      guard safeSpawn(request, context: context) else { return .unsafePosition }
      budget.total += kitReserve ? 2 : 1
      budget.active[request.population, default: 0] += 1
      if kitReserve { budget.active[.cargo, default: 0] += 1 }
    }
    for (index, request) in fresh.enumerated() {
      for other in fresh.dropFirst(index + 1) {
        if (request.position - other.position).length < spawnRadius(request) + spawnRadius(other)
          + 8
        {
          return .unsafePosition
        }
      }
    }
    return nil
  }

  /// A pure emission path shares the native population/reserve and celestial policy without
  /// entering unrelated salvage geometry caches or adopting actors.
  func gameplayProjectileAdmissionRefusal(_ request: SpawnRequest, context: EncounterContext)
    -> AdmissionRefusal?
  {
    guard request.population == .projectile, request.hull == .missile, request.npc == nil,
      request.rock == nil, request.payload == nil, request.salvage == nil,
      !bodies.contains(where: { $0.physical?.spawnIdentity == request.identity })
    else { return .staleContext }
    if let refusal = admissionCapacityRefusal(request, context: context, budget: context.budget) {
      return refusal
    }
    return spawnParametersSafe(request, context: context) ? nil : .unsafePosition
  }

  /// Uses sealed measured hull/component geometry and the ordinary native reserve policy.
  /// Requests must correspond in order to the selected sealed cohort; no identities are allocated.
  @inline(never)
  func gameplayMissionActorAdmissionRefusal(
    _ requests: [SpawnRequest], templates: [MissionActorAdmissionTemplate],
    context: EncounterContext
  ) -> AdmissionRefusal? {
    guard requests.count == templates.count,
      Set(requests.map(\.identity)).count == requests.count
    else { return .staleContext }
    let (registeredStationBodies, playerRadius) = withReadOnlyCommander { commander in
      let registeredStationBodies = Set(
        commander.nativeStations?.ledger.records.compactMap { record in
          record.identity.system == context.system ? record.binding?.bodyID : nil
        } ?? [])
      let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 80
      return (registeredStationBodies, playerRadius)
    }
    return Self.gameplayMissionActorAdmissionRefusal(
      original: self, requests, templates: templates, context: context,
      registeredStationBodies: registeredStationBodies, playerRadius: playerRadius)
  }

  /// Read actual Commander facts before reserving the per-request geometry-validation frame.
  @inline(never)
  private static func gameplayMissionActorAdmissionRefusal(
    original: borrowing Game, _ requests: [SpawnRequest],
    templates: [MissionActorAdmissionTemplate], context: EncounterContext,
    registeredStationBodies: Set<Int>, playerRadius: Double
  ) -> AdmissionRefusal? {
    var budget = context.budget
    for index in requests.indices {
      if let refusal = Self.gameplayMissionActorRequestRefusal(
        original: original, request: requests[index], template: templates[index],
        context: context, budget: budget, playerRadius: playerRadius)
      {
        return refusal
      }
      if let refusal = Self.gameplayMissionActorSceneClearanceRefusal(
        original: original, request: requests[index], template: templates[index],
        context: context, registeredStationBodies: registeredStationBodies)
      {
        return refusal
      }
      budget.total += 1
      budget.active[requests[index].population, default: 0] += 1
    }
    for index in requests.indices {
      for other in requests.indices where other > index {
        if (requests[index].position - requests[other].position).length
          < templates[index].radius + templates[other].radius + 64,
          !original.c01SurveyorPairSeparated(
            requests[index], templates[index], requests[other], templates[other])
        {
          return .unsafePosition
        }
      }
    }
    return nil
  }

  /// Keep one request's condition and capacity temporaries out of cohort iteration.
  @inline(never)
  private static func gameplayMissionActorRequestRefusal(
    original: borrowing Game, request: SpawnRequest,
    template: borrowing MissionActorAdmissionTemplate, context: EncounterContext,
    budget: AdmissionBudget, playerRadius: Double
  ) -> AdmissionRefusal? {
    let maximumHullEnergy = template.maximumHullEnergy
    let resourceCapacityMatches: Bool
    if let resources = request.npc?.resources {
      resourceCapacityMatches = resources.energyCapacity == maximumHullEnergy
    } else {
      resourceCapacityMatches =
        template.canonicalBody.scriptNPC != nil
        && maximumHullEnergy > 100000
    }
    guard request.priority == .mission, request.identity.producer == .mission,
      request.population == .mission,
      request.hull == template.canonicalBody.hull,
      request.energy == template.canonicalBody.energy,
      resourceCapacityMatches
    else { return .staleContext }
    for index in original.bodies.indices {
      if original.bodies[index].physical?.spawnIdentity == request.identity {
        return .staleContext
      }
    }
    if let refusal = original.admissionCapacityRefusal(request, context: context, budget: budget) {
      return refusal
    }
    let radius = template.radius
    guard
      original.spawnParametersSafe(
        request, context: context, measuredRadius: radius,
        measuredMaximumEnergy: maximumHullEnergy),
      (request.position - context.player.position).length > radius + playerRadius + 64
    else { return .unsafePosition }
    return nil
  }

  /// Scene-body and measured-radius storage is needed only after request preflight returns.
  @inline(never)
  private static func gameplayMissionActorSceneClearanceRefusal(
    original: borrowing Game, request: SpawnRequest, template: MissionActorAdmissionTemplate,
    context: EncounterContext, registeredStationBodies: Set<Int>
  ) -> AdmissionRefusal? {
    let center = request.position
    let radius = template.radius
    for actorIndex in context.actors.indices where context.actors[actorIndex].energy > 0 {
      var matchingBodyIndex: Int?
      for bodyIndex in original.bodies.indices {
        if original.bodies[bodyIndex].physical?.identity == context.actors[actorIndex].identity {
          matchingBodyIndex = bodyIndex
          break
        }
      }
      guard let bodyIndex = matchingBodyIndex else { return .staleContext }
      if original.c01SurveyorRetainedPairSeparated(request, template, original.bodies[bodyIndex]) {
        continue
      }
      if let refusal = Self.gameplayMissionActorSceneBodyRefusal(
        original: original, center: center, radius: radius,
        actor: context.actors[actorIndex], body: original.bodies[bodyIndex],
        registeredStationBodies: registeredStationBodies)
      {
        return refusal
      }
    }
    return nil
  }

  /// Practice checks every live scene actor through the strict ordinary body/station rules.
  @inline(never)
  private static func gameplayMissionActorSceneClearanceRefusal(
    original: borrowing Game, center: Vector3, radius: Double, context: EncounterContext,
    registeredStationBodies: Set<Int>
  ) -> AdmissionRefusal? {
    for actorIndex in context.actors.indices where context.actors[actorIndex].energy > 0 {
      var matchingBodyIndex: Int?
      for bodyIndex in original.bodies.indices {
        if original.bodies[bodyIndex].physical?.identity == context.actors[actorIndex].identity {
          matchingBodyIndex = bodyIndex
          break
        }
      }
      guard let bodyIndex = matchingBodyIndex else { return .staleContext }
      if let refusal = Self.gameplayMissionActorSceneBodyRefusal(
        original: original, center: center, radius: radius,
        actor: context.actors[actorIndex], body: original.bodies[bodyIndex],
        registeredStationBodies: registeredStationBodies)
      {
        return refusal
      }
    }
    return nil
  }

  /// Borrow selected scene records and explicitly copy owned component values.
  @inline(never)
  private static func gameplayMissionActorSceneBodyRefusal(
    original: borrowing Game, center: Vector3, radius: Double,
    actor: borrowing ActorSnapshot, body: borrowing SpaceBody,
    registeredStationBodies: Set<Int>
  ) -> AdmissionRefusal? {
    let bodyID = body.id
    if body.nativeStationIdentity != nil || registeredStationBodies.contains(bodyID) {
      return original.missionActorClearsNativeStation(
        center: center, radius: radius, body: body) ? nil : .unsafePosition
    }
    let rockIdentity = actor.rock
    let physical = (copy body).physical
    let otherRadius: Double
    if physical?.currentNewtKitStock != nil || physical?.currentNewtKitReceipt != nil {
      guard let envelope = original.currentNewtBroadPhaseEnvelope(for: copy body),
        let radius = envelope.vertices.map(\.length).max()
      else { return .unsafePosition }
      otherRadius = radius
    } else if let bounds = actor.salvage?.bounds {
      otherRadius = bounds.radius + bounds.center.length
    } else if body.scriptNPC != nil {
      otherRadius = original.scriptNPCRadius(copy body)
    } else if let rock = original.miningFields.flatMap(\.rocks).first(where: {
      $0.identity == rockIdentity
    }) {
      otherRadius = rock.radius
    } else {
      guard let sourceRadius = original.gameplayMesh(for: copy body).vertices.map(\.length).max()
      else { return .unsafePosition }
      otherRadius = sourceRadius
    }
    guard otherRadius.isFinite, otherRadius > 0,
      (center - actor.position).length >= radius + otherRadius + 64
    else { return .unsafePosition }
    return nil
  }

  /// Static admission only: transform every source-box corner with the actual accepted
  /// model basis. The resulting world box encloses the full station even for tolerated scale.
  @inline(never)
  func missionActorClearsNativeStation(
    center: Vector3, radius: Double, body: borrowing SpaceBody
  ) -> Bool {
    guard center.finite, center.length.isFinite, radius.isFinite, radius > 0,
      let identity = body.nativeStationIdentity, nativeStationBodyIsCurrent(copy body)
    else { return false }
    guard
      let bounds = Self.validatedMissionActorStationBounds(
        original: self, identity: identity, body: copy body)
    else { return false }
    let pose = modelPose(of: copy body)
    return Self.missionActorClearsStationBounds(
      center: center, radius: radius, minimum: bounds.minimum, maximum: bounds.maximum, pose: pose)
  }

  /// Current station authority finishes before model-pose and bounds construction starts.
  @inline(never)
  private static func validatedMissionActorStationBounds(
    original: borrowing Game, identity: NativeStationIdentity, body: SpaceBody
  ) -> (minimum: Vector3, maximum: Vector3)? {
    original.withReadOnlyCommander { commander in
      Self.validatedMissionActorStationBounds(commander: commander, identity: identity, body: body)
    }
  }

  private static func validatedMissionActorStationBounds(
    commander: borrowing Commander, identity: NativeStationIdentity, body: borrowing SpaceBody
  ) -> (minimum: Vector3, maximum: Vector3)? {
    guard let world = commander.nativeStations, let saved = world.pose(for: identity),
      let source = NativeStationSource.binding(for: identity), body.energy == saved.energy,
      world.bodyRigidPoseIsConsistent(body, flight: commander.flightSimulation)
    else { return nil }
    let bounds = source.geometry.bounds
    return (bounds.minimum, bounds.maximum)
  }

  /// Pure geometry receives only the measured bounds and the actual model pose.
  @inline(never)
  private static func missionActorClearsStationBounds(
    center: Vector3, radius: Double, minimum: Vector3, maximum: Vector3, pose: ShipPose
  ) -> Bool {
    guard minimum.finite, maximum.finite,
      minimum.x < maximum.x, minimum.y < maximum.y, minimum.z < maximum.z,
      pose.position.finite, pose.orientation.validRotation
    else { return false }
    var worldMinimum = pose.systemPoint(minimum)
    var worldMaximum = worldMinimum
    for x in [minimum.x, maximum.x] {
      for y in [minimum.y, maximum.y] {
        for z in [minimum.z, maximum.z] {
          let point = pose.systemPoint(.init(x, y, z))
          guard point.finite, point.length.isFinite else { return false }
          worldMinimum = .init(
            min(worldMinimum.x, point.x), min(worldMinimum.y, point.y), min(worldMinimum.z, point.z)
          )
          worldMaximum = .init(
            max(worldMaximum.x, point.x), max(worldMaximum.y, point.y), max(worldMaximum.z, point.z)
          )
        }
      }
    }
    let closest = Vector3(
      max(worldMinimum.x, min(worldMaximum.x, center.x)),
      max(worldMinimum.y, min(worldMaximum.y, center.y)),
      max(worldMinimum.z, min(worldMaximum.z, center.z)))
    let clearance = (center - closest).length - radius
    let numerical =
      1e-8 * max(1, radius + center.length + worldMinimum.length + worldMaximum.length)
    return clearance.isFinite && numerical.isFinite && clearance - 64 > numerical
  }

  private func admissionCapacityRefusal(
    _ request: SpawnRequest, context: EncounterContext, budget: AdmissionBudget
  ) -> AdmissionRefusal? {
    guard request.identity.system == context.system, request.identity.visit == context.visit
    else {
      return .staleContext
    }
    if let emp = withReadOnlyCommander({ $0.savedEMPState }), request.identity.producer != .emp,
      emp.records.values.contains(where: { record in
        guard let original = record.originalSpawn else { return false }
        return original.system == request.identity.system
          && original.visit == request.identity.visit
          && original.producer == request.identity.producer
          && original.sequence == request.identity.sequence
          && original.member == request.identity.member
      })
    {
      return .staleContext
    }
    if context.protection.suppressAmbientShips,
      [.civilian, .pirate].contains(request.population), request.priority == .ordinary
    {
      return .missionSuppression
    }
    guard budget.active[request.population, default: 0] < request.population.maximum else {
      return .populationLimit
    }
    let reserve: Int
    switch request.priority {
    case .mission: reserve = 0
    case .police: reserve = max(0, budget.missionReserve - budget.active[.mission, default: 0])
    case .ordinary:
      reserve =
        max(0, budget.policeReserve - budget.active[.police, default: 0])
        + max(0, budget.missionReserve - budget.active[.mission, default: 0])
    }
    guard budget.total < budget.maximum - reserve else { return .reservedCapacity }
    return nil
  }

  private func spawnParametersSafe(
    _ request: SpawnRequest, context: EncounterContext, measuredRadius: Double? = nil,
    measuredMaximumEnergy: Double? = nil
  ) -> Bool {
    guard request.position.finite, request.velocity.finite,
      request.orientation.x.finite, request.orientation.y.finite, request.orientation.z.finite,
      request.angularVelocity.finite
    else {
      recordNativeSalvageAdmissionRefusal(request: request, stage: "spawn.finite", reason: "false")
      return false
    }
    let radius = measuredRadius ?? spawnRadius(request)
    let maximumEnergy = measuredMaximumEnergy ?? request.npc?.resources?.energyCapacity ?? 100000
    guard request.npc?.resources?.valid ?? true,
      maximumEnergy.isFinite, maximumEnergy > 0,
      request.energy.map({ $0.isFinite && $0 >= 0 && $0 <= maximumEnergy }) ?? true
    else {
      recordNativeSalvageAdmissionRefusal(request: request, stage: "spawn.resources", reason: "false")
      return false
    }
    guard Self.nativeAdmissionCelestialEnvelopeSafe(
      center: request.position, radius: radius, projectile: request.population == .projectile,
      context: context)
    else {
      recordNativeSalvageAdmissionRefusal(request: request, stage: "spawn.celestial", reason: "false")
      return false
    }
    return true
  }

  private mutating func safeSpawn(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard spawnParametersSafe(request, context: context) else {
      recordNativeSalvageAdmissionRefusal(request: request, stage: "spawn.parametersOrCelestial",
        reason: "false")
      return false
    }
    let radius = spawnRadius(request)
    // An emitted projectile starts at its owner's muzzle; its collision resolver excludes it.
    if request.population == .projectile { return true }
    return spawnSeparationIsSafe(
      position: request.position, radius: radius, context: context,
      excludedActor: nil, fragmentRequest: request)
  }

  /// The native cohort already owns an actor; no fabricated SpawnIdentity is used for clearance.
  mutating func nativeLaunchGeometryIsSafe(
    source: OriginalFleetRuntimeHullSource.Source, actor: ActorIdentity,
    position: Vector3, context: EncounterContext
  ) -> Bool {
    let radius = source.envelope.clearanceRadius
    guard position.finite, radius.isFinite, radius > 0,
      (position - context.anchors.planet.position).length > context.anchors.planet.radius + radius,
      (position - context.anchors.sun.position).length > context.anchors.sun.radius * 4 + radius
    else { return false }
    return spawnSeparationIsSafe(
      position: position, radius: radius, context: context,
      excludedActor: actor, fragmentRequest: nil)
  }

  private mutating func spawnSeparationIsSafe(
    position: Vector3, radius: Double, context: EncounterContext,
    excludedActor: ActorIdentity?, fragmentRequest: SpawnRequest?
  ) -> Bool {
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 80
    guard (position - context.player.position).length > radius + playerRadius + 8 else {
      recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.player",
        reason: "distance=\((position - context.player.position).length) required=\(radius + playerRadius + 8)")
      return false
    }
    for actor in context.actors where actor.identity != excludedActor && actor.energy > 0 {
      let otherRadius: Double
      if let salvage = actor.salvage {
        otherRadius = salvage.bounds.radius + salvage.bounds.center.length
      } else if let id = actor.catalogueShipID, OriginalBisonActivation.contains(id) {
        guard let radius = OriginalBisonActivation.collisionRadius(for: id) else {
          recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.geometry",
            reason: "missing Bison collider entity=\(actor.identity.entity)")
          return false
        }
        otherRadius = radius
      } else if let id = actor.catalogueShipID, actor.hull != .station,
        OriginalFleetR3Data.contract(for: id)?.objectKind == .ship
      {
        guard let source = OriginalFleetRuntimeHullSource.source(for: id) else {
          recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.geometry",
            reason: "missing fleet collider entity=\(actor.identity.entity)")
          return false
        }
        otherRadius = source.envelope.clearanceRadius
      } else if actor.hull == .cobra {
        guard let body = bodies.first(where: { $0.physical?.identity == actor.identity }) else {
          recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.geometry",
            reason: "missing body entity=\(actor.identity.entity)")
          return false
        }
        if body.scriptNPC != nil {
          otherRadius = scriptNPCRadius(body)
        } else {
          guard !OriginalDetailedHullStage.blocksRuntime(body) else {
            recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.geometry",
              reason: "blocked runtime hull entity=\(actor.identity.entity)")
            return false
          }
          // A source-less marker has no collider. Restored markers are removed before adoption.
          guard let radius = gameplayMesh(for: body).vertices.map(\.length).max() else { continue }
          otherRadius = radius
        }
        guard otherRadius.isFinite, otherRadius > 0 else {
          recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.geometry",
            reason: "invalid radius entity=\(actor.identity.entity)")
          return false
        }
      } else {
        otherRadius = Mesh.hull(actor.hull).vertices.map(\.length).max() ?? 80
      }
      if (position - actor.position).length < radius + otherRadius + 8,
        !(fragmentRequest.map { releasedFragmentClearsParent($0, parent: actor, context: context) }
          ?? false)
      {
        recordNativeSalvageAdmissionRefusal(request: fragmentRequest, stage: "separation.actor",
          reason: "entity=\(actor.identity.entity) distance=\((position - actor.position).length) required=\(radius + otherRadius + 8)")
        return false
      }
    }
    return true
  }

  private func spawnRadius(_ request: SpawnRequest) -> Double {
    if let bounds = request.salvage?.bounds { return bounds.radius + bounds.center.length }
    if let rock = miningFields.flatMap(\.rocks).first(where: { $0.identity == request.rock }) {
      return rock.radius
    }
    if let id = request.catalogueShipID, OriginalBisonActivation.contains(id) {
      return OriginalBisonActivation.collisionRadius(for: id) ?? .nan
    }
    if let id = request.catalogueShipID, request.hull != .station,
      OriginalFleetR3Data.contract(for: id)?.objectKind == .ship
    {
      return OriginalFleetRuntimeHullSource.source(for: id)?.envelope.clearanceRadius ?? .nan
    }
    guard request.hull != .cobra else { return .nan }
    return Mesh.hull(request.hull).vertices.map(\.length).max() ?? 80
  }
}

extension Game {
  // Same celestial inequalities used by ordinary native spawn policy.
  private static func nativeAdmissionCelestialEnvelopeSafe(
    center: Vector3, radius: Double, projectile: Bool, context: EncounterContext
  ) -> Bool {
    radius.isFinite && radius > 0
      && (center - context.anchors.planet.position).length > context.anchors.planet.radius + radius
      && (center - context.anchors.sun.position).length > context.anchors.sun.radius
        * (projectile ? 1 : 4) + radius
  }

  /// Read-only conservative C01 envelope screening; no full-solid/joint,
  /// protected-corridor, mass installation, model or allocation permission.
  func c01InquiryPlacementEnvelopeRefusal(
    center: Vector3, radius: Double, context: EncounterContext
  ) -> AdmissionRefusal? {
    guard center.finite, center.length.isFinite, radius.isFinite, radius > 0,
      gameplayContext() == context, context.system == systemIdentity,
      context.visit == commander.flightSimulation.visit,
      context.physicalTime == commander.flightSimulation.physicalTime,
      Set(bodies.map(\.id)).count == bodies.count,
      Set(bodies.compactMap { $0.physical?.identity }).count == bodies.count,
      bodies.allSatisfy({ $0.energy.isFinite }),
      Set(context.actors.map(\.identity)) == Set(bodies.compactMap { $0.physical?.identity })
    else { return .staleContext }
    guard Self.nativeAdmissionCelestialEnvelopeSafe(
      center: center, radius: radius, projectile: false, context: context)
    else { return .unsafePosition }
    let playerVertices = commander.playerMesh.vertices
    guard !playerVertices.isEmpty, playerVertices.allSatisfy({ $0.finite }),
      let playerRadius = playerVertices.map(\.length).max(),
      playerRadius.isFinite, playerRadius > 0,
      (center - context.player.position).length > radius + playerRadius + 64
    else { return .unsafePosition }
    let stations = Set(commander.nativeStations?.ledger.records.compactMap {
      $0.identity.system == context.system ? $0.binding?.bodyID : nil
    } ?? [])
    return Self.gameplayMissionActorSceneClearanceRefusal(
      original: self, center: center, radius: radius, context: context,
      registeredStationBodies: stations)
  }
}

extension Game {
  /// Only the existing atomic EMP archive producer calls this admission seam.
  /// It binds an already owned object; no release, person or kit is reissued.
  mutating func admitCurrentOccupiedNewtPodReadmission(
    _ object: EMPStoredObject, source logical: ActorIdentity, sequence: UInt64, member: UInt16
  ) -> SpawnReceipt {
    let spawn = SpawnIdentity(system: systemIdentity, visit: commander.flightSimulation.visit,
      sequence: sequence, member: member, producer: .emp)
    guard member > 0, let context = gameplayContext(),
      context.system == logical.system, context.visit >= logical.visit,
      context.revision == gameplayRevision, object.binding == nil,
      object.physicalTime == context.physicalTime,
      let state = commander.savedEMPState, state.valid,
      let record = state.records[logical], record.valid, record.sequence == sequence,
      let saved = object.body.physical, let person = saved.empCrewPod,
      person.source == logical, person.ordinal == Int(member) - 1,
      let index = record.podIndex(for: person.ordinal), record.pods[index] == object,
      object.validCurrentOccupiedNewt(in: record), commander.worldOwnedPod(person),
      commander.currentNewtCapturedServiceCustodyValid,
      let receipt = saved.currentNewtKitReceipt,
      let stock = record.hull.body.physical?.currentNewtKitStock,
      stock.receipt == receipt, stock.serviceCapturedAt == nil,
      receipt.issue == stock.issue, receipt.issue.person == person,
      record.custody.original.body.physical?.currentNewtKitStock?.issue == stock.issue,
      !bodies.contains(where: {
        $0.physical?.empCrewPod == person
          || $0.physical?.currentNewtKitReceipt?.issue.kitID == receipt.issue.kitID
          || $0.physical?.spawnIdentity == spawn
      }),
      let physical = CurrentNewtKitSource.current,
      physical.matches(receipt, observedAt: context.physicalTime),
      let geometry = Self.currentNewtPodCollisionMesh(source: physical),
      let radius = geometry.vertices.map(\.length).max(), radius.isFinite, radius > 0,
      let performance = OriginalFleetR3Data.contract(for: "SH040")?.performance,
      object.body.energy > 0, object.body.energy <= performance.energy
    else { return .init(request: spawn, actor: nil, refusal: .staleContext) }
    let request = SpawnRequest(identity: spawn, population: .cargo, hull: .cargo,
      position: object.body.position, orientation: object.body.orientation, velocity: saved.velocity,
      npc: nil, rock: nil, payload: nil, priority: .ordinary, catalogueShipID: "SH040",
      energy: object.body.energy, angularVelocity: saved.angularVelocity, salvage: saved.salvage)
    if let refusal = admissionCapacityRefusal(request, context: context, budget: context.budget) {
      return .init(request: spawn, actor: nil, refusal: refusal)
    }
    guard spawnParametersSafe(request, context: context, measuredRadius: radius,
      measuredMaximumEnergy: performance.energy),
      spawnSeparationIsSafe(position: request.position, radius: radius, context: context,
        excludedActor: nil, fragmentRequest: request),
      (request.position - context.player.position).length <= context.perceptionRadius
    else { return .init(request: spawn, actor: nil, refusal: .unsafePosition) }
    var candidate = self
    guard candidate.nextBodyID < Int.max, let actor = candidate.commander.flightSimulation.allocateActor()
    else { return .init(request: spawn, actor: nil, refusal: .reservedCapacity) }
    let admitted = candidate.constructAdmittedEncounterBody(request, actor: actor, context: context)
    guard admitted.actor == actor, admitted.refusal == nil,
      let body = candidate.bodies.firstIndex(where: { $0.physical?.identity == actor })
    else { return admitted }
    candidate.bodies[body].physical?.empCrewPod = person
    candidate.bodies[body].physical?.currentNewtKitReceipt = receipt
    candidate.bodies[body].physical?.canonicalSpin = saved.canonicalSpin
    candidate.bodies[body].rotationRate = object.body.rotationRate
    // The outer existing producer restores the remaining physical/archive and
    // legal bindings in its same private candidate before publication.
    self = candidate
    return admitted
  }
}
