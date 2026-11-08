import Foundation

/// Immutable current birth fact. It is retained independently of the people leaf so
/// removing that leaf cannot turn a born original source into unused stock.
struct NativeOriginalUtilityBirthReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let station: NativeStationIdentity
  let binding: NativeStationBinding
  let spawn: SpawnIdentity
  let physicalTime: Double

  fileprivate init(operation: UUID, station: NativeStationIdentity,
    binding: NativeStationBinding, spawn: SpawnIdentity, physicalTime: Double)
  {
    self.operation = operation
    self.station = station
    self.binding = binding
    self.spawn = spawn
    self.physicalTime = physicalTime
  }

  var valid: Bool {
    station == OriginalStationSite.remoteUtility.identity(world: station.world)
      && binding.valid(for: station) && spawn.system == station.system
      && spawn.visit == binding.actor.visit && spawn.sequence > 0
      && spawn.sequence < UInt64(Int64.max) && spawn.producer == .mission
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }

  private enum CodingKeys: String, CodingKey {
    case operation, station, binding, spawn, physicalTime
  }

  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(decoder,
      ["operation", "station", "binding", "spawn", "physicalTime"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    operation = try values.decode(UUID.self, forKey: .operation)
    station = try values.decode(NativeStationIdentity.self, forKey: .station)
    binding = try values.decode(NativeStationBinding.self, forKey: .binding)
    spawn = try values.decode(SpawnIdentity.self, forKey: .spawn)
    physicalTime = try values.decode(Double.self, forKey: .physicalTime)
    guard valid else { throw SaveError.invalidCommander }
  }
}

/// A sealed proposal from the real native cohort and allocator snapshot. Retained
/// saved facts cannot construct this capability or replace its before-state checks.
final class NativeOriginalStationPopulationPlan: Sendable {
  fileprivate let worldBefore: NativeStationWorld
  fileprivate let flightBefore: FlightSimulationState
  fileprivate let bodiesBefore: [SpaceBody]
  fileprivate let nextBodyBefore: Int
  fileprivate let epoch: UUID
  fileprivate let admitted: [SpaceBody]
  let flightAfter: FlightSimulationState
  let worldAfter: NativeStationWorld
  fileprivate let firstUtility: Int?

  fileprivate init(worldBefore: NativeStationWorld, flightBefore: FlightSimulationState,
    bodiesBefore: [SpaceBody], nextBodyBefore: Int, epoch: UUID,
    admitted: [SpaceBody], flightAfter: FlightSimulationState,
    worldAfter: NativeStationWorld, firstUtility: Int?)
  {
    self.worldBefore = worldBefore
    self.flightBefore = flightBefore
    self.bodiesBefore = bodiesBefore
    self.nextBodyBefore = nextBodyBefore
    self.epoch = epoch
    self.admitted = admitted
    self.flightAfter = flightAfter
    self.worldAfter = worldAfter
    self.firstUtility = firstUtility
  }

  fileprivate func matches(_ game: borrowing Game) -> Bool {
    game.nativeOriginalStationPopulationPlan === self
      && game.nativeStationRuntimeEpoch == epoch
      && game.commander.nativeStations == worldBefore
      && game.commander.flightSimulation == flightBefore
      && game.nextBodyID == nextBodyBefore && game.bodies == bodiesBefore
      && !game.docked && game.pendingNativeStationDock == nil
  }

  fileprivate var birthWitness: NativeOriginalUtilityBirthWitness? {
    guard let firstUtility else { return nil }
    return .init(plan: self, actor: admitted[firstUtility])
  }
}

final class NativeOriginalUtilityBirthWitness: Sendable {
  let station: NativeStationIdentity
  let sourceVersion: String
  let binding: NativeStationBinding
  let actor: SpaceBody
  let spawn: SpawnIdentity
  let physicalTime: Double
  let epoch: UUID
  let priorVisit: UInt64
  let priorNextActor: UInt64
  let priorNextSpawn: UInt64
  fileprivate let plan: NativeOriginalStationPopulationPlan

  fileprivate init(plan: NativeOriginalStationPopulationPlan, actor: SpaceBody) {
    self.plan = plan
    // The private producer below has checked both fields before sealing this plan.
    station = actor.nativeStationIdentity!
    sourceVersion = OriginalStationSite.sourceVersion
    binding = .init(actor: actor.physical!.identity, bodyID: actor.id)
    self.actor = actor
    spawn = actor.physical!.spawnIdentity!
    physicalTime = plan.flightAfter.physicalTime
    epoch = plan.epoch
    priorVisit = plan.flightBefore.visit
    priorNextActor = plan.flightBefore.nextActor
    priorNextSpawn = plan.flightBefore.nextSpawn
  }
}

extension Game {
  @inline(never)
  func acceptsNativeOriginalUtilityBirthWitness(_ witness: NativeOriginalUtilityBirthWitness)
    -> Bool
  {
    let plan = witness.plan
    guard plan.matches(self), let member = plan.firstUtility,
      plan.admitted[member] == witness.actor,
      witness.station == OriginalStationSite.remoteUtility.identity(world: plan.worldBefore.ledger.world),
      let before = plan.worldBefore.ledger.records.first(where: { $0.identity == witness.station }),
      before.binding == nil, before.tombstone == nil, before.utilitySourceBirth == nil,
      let after = plan.worldAfter.ledger.records.first(where: { $0.identity == witness.station }),
      after.binding == witness.binding, let birth = after.utilitySourceBirth
    else { return false }
    return birth.station == witness.station && birth.binding == witness.binding
      && birth.spawn == witness.spawn && birth.physicalTime == witness.physicalTime
      && birth.operation == NativeUtilityEngineer.birthOperation(owner: witness.station.world)
  }

  /// The caller has completed the existing whole-scene placement pass. Verify its
  /// exact current cohort again before allocating into private copied state.
  @inline(never)
  func prepareNativeOriginalStationPopulation(
    world: NativeStationWorld, flightBefore: FlightSimulationState,
    selected: [(NativeStationRecord, NativeStationSavedPose, NativeStationSourceBinding)]
  ) throws -> NativeOriginalStationPopulationPlan {
    guard nativeOriginalStationPopulationPlan == nil, !docked,
      pendingNativeStationDock == nil, world.valid,
      commander.nativeStations == world, commander.flightSimulation == flightBefore,
      flightBefore.system == systemIdentity, let anchors = flightBefore.anchors,
      !selected.isEmpty, nextBodyID > 0, nextBodyID < 1_000_000_000 - selected.count,
      bodies.filter({ $0.energy > 0 }).count + selected.count <= 128
    else { throw NativeStationRuntimeError.invalidState }
    _ = try NativeStationSource.requireBindings()
    let absent = world.ledger.records.filter { record in
      record.identity.system == systemIdentity && record.tombstone == nil
        && !bodies.contains { $0.nativeStationIdentity == record.identity }
    }
    guard Set(selected.map { $0.0.identity }) == Set(absent.map(\.identity)),
      selected.count == absent.count
    else { throw NativeStationRuntimeError.invalidState }
    var flight = flightBefore
    guard let sequence = flight.allocateSpawn(), sequence < UInt64(Int64.max) else {
      throw NativeStationRuntimeError.capacity
    }
    var stagedWorld = world
    var admitted: [SpaceBody] = []
    var firstUtility: Int?
    for (member, entry) in selected.enumerated() {
      let (record, saved, source) = entry
      guard member <= Int(UInt16.max), absent.contains(record),
        world.pose(for: record.identity) == saved,
        NativeStationSource.binding(for: record.identity) == source,
        source.geometry.position(in: anchors) == saved.position,
        let currentPosition = world.currentPosition(
          for: .originalStation(record.identity), at: flightBefore.physicalTime),
        let orientation = world.currentOrientation(for: saved.station, at: flightBefore.physicalTime),
        let actor = flight.allocateActor(), actor.entity < UInt64(Int64.max)
      else { throw NativeStationRuntimeError.invalidSource }
      let radius = source.geometry.mesh.vertices.map(\.length).max() ?? .infinity
      guard radius.isFinite, radius > 0 else { throw NativeStationRuntimeError.invalidSource }
      for celestial in [anchors.planet, anchors.sun] {
        guard (currentPosition - celestial.position).length > radius + celestial.radius + 8 else {
          throw NativeStationRuntimeError.unsafePlacement
        }
      }
      for body in bodies where body.energy > 0 {
        let otherRadius = gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity
        guard (currentPosition - flightBefore.pose.systemPoint(body.position)).length
          > radius + otherRadius + 8
        else { throw NativeStationRuntimeError.unsafePlacement }
      }
      for other in admitted {
        guard let otherIdentity = other.nativeStationIdentity,
          let otherSource = NativeStationSource.binding(for: otherIdentity),
          let otherRadius = otherSource.geometry.mesh.vertices.map(\.length).max(),
          (currentPosition - flightBefore.pose.systemPoint(other.position)).length
            > radius + otherRadius + 8
        else { throw NativeStationRuntimeError.unsafePlacement }
      }
      let spawn = SpawnIdentity(system: systemIdentity, visit: flight.visit,
        sequence: sequence, member: UInt16(member), producer: .mission)
      let id = nextBodyID + member
      var body = SpaceBody(id: id, hull: .station, position: flight.pose.shipPoint(currentPosition))
      body.nativeStationIdentity = record.identity
      body.orientation = orientation.relative(to: flight.pose.orientation)
      body.rotation = 0  // The current original source sites have identity orientation and zero spin.
      body.rotationRate = source.rotationRate
      body.energy = saved.energy
      body.missiles = 0
      body.ecmEnabled = false
      body.physical = nativePhysicalActorState(for: body, identity: actor, spawnIdentity: spawn,
        velocity: world.inertia(for: .originalStation(record.identity))?.velocity ?? .init(0, 0, 0))
      body.physical?.catalogueShipID = source.catalogueShipID
      guard source.rotationRate == 0, body.energy > 0,
        let physical = body.physical, physical.population == .mission, physical.npc == nil,
        physical.identity == actor, physical.spawnIdentity == spawn,
        !bodies.contains(where: { $0.id == id || $0.physical?.identity == actor })
      else { throw NativeStationRuntimeError.invalidState }
      let binding = NativeStationBinding(actor: actor, bodyID: id)
      if NativeUtilityState.isTarget(record.identity), record.utilitySourceBirth == nil {
        guard record.binding == nil, record.tombstone == nil, firstUtility == nil,
          commander.nativePeople?.utilityEngineer == nil,
          stagedWorld.ledger.records.contains(where: { $0.identity == record.identity })
        else { throw NativeStationRuntimeError.invalidState }
        try stagedWorld.ledger.recordUtilityBirth(.init(
          operation: NativeUtilityEngineer.birthOperation(owner: record.identity.world),
          station: record.identity, binding: binding, spawn: spawn,
          physicalTime: flight.physicalTime))
        firstUtility = member
      }
      try stagedWorld.ledger.rebind(record.identity, to: binding)
      admitted.append(body)
    }
    guard stagedWorld.valid, flight.valid,
      flight.visit == flightBefore.visit, flight.physicalTime == flightBefore.physicalTime,
      flight.nextActor == flightBefore.nextActor + UInt64(admitted.count),
      flight.nextSpawn == flightBefore.nextSpawn + 1,
      flight.nextIncident == flightBefore.nextIncident,
      flight.nextEmission == flightBefore.nextEmission
    else { throw NativeStationRuntimeError.invalidState }
    return .init(worldBefore: world, flightBefore: flightBefore, bodiesBefore: bodies,
      nextBodyBefore: nextBodyID, epoch: nativeStationRuntimeEpoch, admitted: admitted,
      flightAfter: flight, worldAfter: stagedWorld, firstUtility: firstUtility)
  }

  @inline(never)
  mutating func publishNativeOriginalStationPopulation(_ plan: NativeOriginalStationPopulationPlan)
    throws
  {
    guard nativeOriginalStationPopulationPlan == nil else {
      throw NativeStationRuntimeError.invalidState
    }
    nativeOriginalStationPopulationPlan = plan
    defer { nativeOriginalStationPopulationPlan = nil }
    guard plan.matches(self) else { throw NativeStationRuntimeError.invalidState }
    if let witness = plan.birthWitness {
      // MC1 owns these contracted adapters. They must prepare and validate the whole
      // people/source operation before their first assignment; no adapter is fabricated here.
      let people = try prepareNativeUtilityEngineerBirth(witness)
      guard people.operation == plan.worldAfter.ledger.records.first(where: {
        $0.identity == witness.station
      })?.utilitySourceBirth?.operation, plan.matches(self),
        acceptsNativeOriginalUtilityBirthWitness(witness)
      else { throw NativeStationRuntimeError.invalidState }
      try commitNativeUtilityEngineerMutation(people)
    }
    // All throwing validation has completed. Publish the same prepared body/source/
    // allocator values next to the prepared people assignment without another fallible step.
    commander.nativeStations = plan.worldAfter
    commander.flightSimulation = plan.flightAfter
    nextBodyID = plan.nextBodyBefore + plan.admitted.count
    bodies = plan.bodiesBefore + plan.admitted
  }
}

final class NativeOriginalUtilityDockWitness: Sendable {
  let receipt: NativeStationDockReceipt
  let runtimeEpoch: UUID
  let physicalTime: Double
  let utilityRevision: UInt64
  let owner: UUID
  let stationRevision: UInt64
  fileprivate init(receipt: NativeStationDockReceipt, epoch: UUID, time: Double,
    utility: NativeUtilityState, revision: UInt64)
  {
    self.receipt = receipt
    runtimeEpoch = epoch
    physicalTime = time
    utilityRevision = utility.revision
    owner = utility.owner
    stationRevision = revision
  }
}

/// A live native start observation; never decoded or created from a dead saved source.
final class NativeOriginalUtilityFatalStart: Sendable {
  fileprivate let station: NativeStationIdentity
  fileprivate let binding: NativeStationBinding
  fileprivate let actor: SpaceBody
  fileprivate let revision: UInt64
  fileprivate let player: ActorIdentity
  fileprivate let time: Double
  fileprivate let duration: Double
  fileprivate let nextIncident: UInt64
  fileprivate let epoch: UUID
  fileprivate init?(game: borrowing Game, duration: Double) {
    let start = game.commander.flightSimulation.physicalTime
    let end = start + duration
    guard duration.isFinite, duration > 0, duration <= 0.1,
      start.isFinite, (0...1e12).contains(start), end.isFinite, end > start, end <= 1e12,
      !game.docked, !game.paused,
      let owner = game.commander.equipmentOwnerID,
      let world = game.commander.nativeStations, world.valid, world.ledger.world == owner,
      let record = world.ledger.records.first(where: { NativeUtilityState.isTarget($0.identity) }),
      record.tombstone == nil, record.utilitySourceBirth != nil,
      let binding = record.binding, record.identity.system == game.systemIdentity,
      let actor = game.bodies.first(where: { $0.id == binding.bodyID }), actor.energy > 0,
      actor.physical?.identity == binding.actor, game.nativeStationBodyIsCurrent(actor),
      let player = game.commander.flightSimulation.player,
      game.commander.nativePeople?.utilityEngineer?.casualty == nil,
      game.commander.nativePeople?.utilityEngineer != nil
    else { return nil }
    station = record.identity
    self.binding = binding
    self.actor = actor
    revision = record.revision
    self.player = player
    time = game.commander.flightSimulation.physicalTime
    self.duration = duration
    nextIncident = game.commander.flightSimulation.nextIncident
    epoch = game.nativeStationRuntimeEpoch
  }
}

final class NativeOriginalUtilityFatalTransition: Sendable {
  let station: NativeStationIdentity
  let binding: NativeStationBinding
  let actor: SpaceBody
  let priorLifecycleRevision: UInt64
  let tombstone: NativeStationTombstone
  let startTime: Double
  let usedDuration: Double
  let physicalTime: Double
  let preNextIncident: UInt64
  let postNextIncident: UInt64
  let epoch: UUID
  fileprivate let before: NativeStationWorld
  fileprivate let after: NativeStationWorld
  fileprivate init?(game: borrowing Game, source: NativeOriginalUtilityFatalStart,
    actor: SpaceBody, after: NativeStationWorld)
  {
    let now = game.commander.flightSimulation.physicalTime
    let bodyID = actor.id
    let matching = game.bodies.filter { $0.id == bodyID }
    guard matching.count == 1, let actual = matching.first, actual == actor,
      source.epoch == game.nativeStationRuntimeEpoch,
      source.player == game.commander.flightSimulation.player,
      source.duration.isFinite, source.duration > 0, source.duration <= 0.1,
      source.time.isFinite, (0...1e12).contains(source.time),
      now.isFinite, now <= 1e12, now == source.time + source.duration, now > source.time,
      source.station.system == game.systemIdentity, actor.energy.isFinite, actor.energy <= 0,
      actor.id == source.binding.bodyID, actor.nativeStationIdentity == source.station,
      let physical = actor.physical, physical.identity == source.binding.actor,
      physical.spawnIdentity == source.actor.physical?.spawnIdentity,
      let incident = physical.deathIncidentID, incident >= source.nextIncident,
      incident < game.commander.flightSimulation.nextIncident,
      let origin = physical.deathOrigin,
      origin.emissionID > 0, origin.emissionID < game.commander.flightSimulation.nextEmission,
      origin.emittedAt.isFinite, origin.emittedAt >= 0, origin.emittedAt <= now,
      let before = game.commander.nativeStations, before.valid,
      let record = before.ledger.records.first(where: { $0.identity == source.station }),
      record.revision == source.revision, record.binding == source.binding,
      record.tombstone == nil, record.utilitySourceBirth != nil,
      let final = after.ledger.records.first(where: { $0.identity == source.station }),
      let tombstone = final.tombstone, source.revision < UInt64(Int64.max) - 1,
      tombstone.revision == source.revision + 1, tombstone.destroyedBinding == source.binding,
      final.binding == nil, after.valid, after.pose(for: source.station)?.energy == 0
    else { return nil }
    station = source.station
    binding = source.binding
    self.actor = actor
    priorLifecycleRevision = source.revision
    self.tombstone = tombstone
    startTime = source.time
    usedDuration = source.duration
    physicalTime = now
    preNextIncident = source.nextIncident
    postNextIncident = game.commander.flightSimulation.nextIncident
    epoch = source.epoch
    self.before = before
    self.after = after
  }
}

extension Game {
  func nativeOriginalUtilityDockWitness() -> NativeOriginalUtilityDockWitness? {
    guard docked, !dockedAtMainStation, !paused, scriptDurabilityAvailable,
      nativeStationDockEvidenceIsCurrent, pendingNativeStationDock == nil,
      commander.nativeStationStateValid, let owner = commander.equipmentOwnerID,
      let world = commander.nativeStations, world.ledger.world == owner,
      let receipt = world.ledger.currentDock, receipt.commanderOwner == owner,
      receipt.station == OriginalStationSite.remoteUtility.identity(world: owner),
      let record = world.ledger.records.first(where: { $0.identity == receipt.station }),
      NativeStationSource.authentic(record, owner: owner), record.tombstone == nil,
      record.binding == receipt.dockingBinding, record.revision == receipt.lifecycleRevision,
      record.utilitySourceBirth != nil,
      let pose = world.pose(for: record.identity), pose.energy > 0,
      let utility = record.utility, utility.valid
    else { return nil }
    return .init(receipt: receipt, epoch: nativeStationRuntimeEpoch,
      time: commander.flightSimulation.physicalTime, utility: utility, revision: record.revision)
  }
  func acceptsNativeOriginalUtilityDockWitness(_ witness: NativeOriginalUtilityDockWitness) -> Bool {
    guard let actual = nativeOriginalUtilityDockWitness() else { return false }
    return actual.receipt == witness.receipt && actual.runtimeEpoch == witness.runtimeEpoch
      && actual.physicalTime == witness.physicalTime && actual.owner == witness.owner
      && actual.utilityRevision == witness.utilityRevision && actual.stationRevision == witness.stationRevision
  }
  mutating func beginNativeOriginalUtilityFatalInterval(delta: Double) {
    nativeOriginalUtilityFatalStart = NativeOriginalUtilityFatalStart(game: self, duration: delta)
  }
  func nativeOriginalUtilityFatalIntervalMatches(
    station: NativeStationIdentity, binding: NativeStationBinding
  ) -> Bool {
    guard let start = nativeOriginalUtilityFatalStart else { return false }
    return start.station == station && start.binding == binding && start.epoch == nativeStationRuntimeEpoch
      && start.player == commander.flightSimulation.player
      && commander.flightSimulation.physicalTime == start.time + start.duration
      && commander.flightSimulation.physicalTime > start.time
  }
  mutating func prepareNativeOriginalUtilityFatalTransition(
    actor: SpaceBody, world: NativeStationWorld
  ) throws -> NativeOriginalUtilityFatalTransition {
    if let retained = nativeOriginalUtilityFatalTransition,
      acceptsNativeOriginalUtilityFatalTransition(retained)
    { return retained }
    guard let start = nativeOriginalUtilityFatalStart,
      let transition = NativeOriginalUtilityFatalTransition(game: self, source: start, actor: actor, after: world)
    else { throw NativeStationRuntimeError.invalidState }
    nativeOriginalUtilityFatalTransition = transition
    return transition
  }
  func acceptsNativeOriginalUtilityFatalTransition(_ value: NativeOriginalUtilityFatalTransition) -> Bool {
    guard nativeOriginalUtilityFatalTransition === value,
      value.epoch == nativeStationRuntimeEpoch, value.station.system == systemIdentity,
      value.binding.actor.visit == commander.flightSimulation.visit,
      value.physicalTime <= commander.flightSimulation.physicalTime,
      value.postNextIncident <= commander.flightSimulation.nextIncident,
      let world = commander.nativeStations
    else { return false }
    guard world.ledger.world == value.before.ledger.world,
      world.adapterRevision == value.before.adapterRevision,
      world.geometryRevision == value.before.geometryRevision,
      let current = world.ledger.records.first(where: { $0.identity == value.station }),
      let original = value.before.ledger.records.first(where: { $0.identity == value.station }),
      let terminal = value.after.ledger.records.first(where: { $0.identity == value.station }),
      let condition = world.pose(for: value.station)
    else { return false }
    let bodyID = value.binding.bodyID
    let actor = value.binding.actor
    let station = value.station
    let spawn = value.actor.physical?.spawnIdentity
    let matching = bodies.filter { $0.id == bodyID }
    if let actual = matching.first {
      guard matching.count == 1,
        actual.physical?.identity == actor, actual.energy <= 0,
        actual.nativeStationIdentity == station, actual.physical?.spawnIdentity == spawn,
        actual.physical?.deathIncidentID == value.actor.physical?.deathIncidentID,
        actual.physical?.deathOrigin == value.actor.physical?.deathOrigin
      else { return false }
      return (current == original && condition == value.before.pose(for: value.station))
        || (current == terminal && condition.energy == 0)
    }
    // Ordinary dead-body cleanup can remove the actor only after the native
    // tombstone and first engineer casualty have been committed. Absence alone
    // never establishes that transition, and a contradictory claim is refused.
    guard current == terminal, current.binding == nil, current.tombstone == value.tombstone,
      condition.energy == 0,
      !bodies.contains(where: { body in
        if body.id == bodyID || body.physical?.identity == actor
          || body.nativeStationIdentity == station
        { return true }
        if let spawn { return body.physical?.spawnIdentity == spawn }
        return false
      })
    else { return false }
    return nativeOriginalUtilityFatalCasualtyMatches(value)
  }
  private func nativeOriginalUtilityFatalCasualtyMatches(
    _ value: NativeOriginalUtilityFatalTransition
  ) -> Bool {
    guard commander.nativePeopleStateValid, let custody = commander.nativePeople,
      custody.owner == commander.equipmentOwnerID, custody.owner == value.station.world,
      let engineer = custody.utilityEngineer,
      engineer.registration.station == value.station,
      engineer.registration.identity.owner == custody.owner,
      let casualty = engineer.casualty, let physical = value.actor.physical,
      let incident = physical.deathIncidentID, let origin = physical.deathOrigin
    else { return false }
    return casualty.operation == NativeUtilityEngineer.casualtyOperation(
      owner: custody.owner, binding: value.binding, incident: incident)
      && casualty.binding == value.binding
      && casualty.priorLifecycleRevision == value.priorLifecycleRevision
      && casualty.tombstone == value.tombstone && casualty.incident == incident
      && casualty.origin == origin && casualty.startTime == value.startTime
      && casualty.usedDuration == value.usedDuration && casualty.physicalTime == value.physicalTime
      && casualty.preNextIncident == value.preNextIncident
      && casualty.postNextIncident == value.postNextIncident && casualty.epoch == value.epoch
  }
  func nativeOriginalUtilityFatalProspectiveWorld(
    _ value: NativeOriginalUtilityFatalTransition
  ) -> NativeStationWorld? {
    guard acceptsNativeOriginalUtilityFatalTransition(value), var world = commander.nativeStations,
      let index = world.poses.firstIndex(where: { $0.station == value.station }),
      let record = world.ledger.records.first(where: { $0.identity == value.station })
    else { return nil }
    if record.tombstone == nil {
      do { try world.ledger.destroy(value.station, binding: value.binding) } catch { return nil }
    } else if record.tombstone != value.tombstone { return nil }
    world.poses[index].energy = 0
    return world.valid ? world : nil
  }
}
