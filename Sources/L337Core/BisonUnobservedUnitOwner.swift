import Foundation

/// Retained native-constructor state, explicitly without physical observations.
/// Reserving identities supplies no new stock, pressure, temperature, seal,
/// operative state, commissioned receipt or permission for a first snapshot.
struct BisonUnobservedUnitOwner: Equatable, Sendable {
  enum Unobserved: String, Codable, Sendable { case unobserved }

  struct Unit: Equatable, Codable, Sendable {
    let id: UUID
    let sourceComponentID: String
    /// nil denotes the separate portable unit, not an unassigned carrier cell.
    let carrierOrdinal: Int?
    let gas: Unobserved
    let thermal: Unobserved
    let electrical: Unobserved
    let mechanical: Unobserved
    let operative: Unobserved
    let physicalRoster: Unobserved

    fileprivate init(id: UUID, sourceComponentID: String, carrierOrdinal: Int?) {
      self.id = id
      self.sourceComponentID = sourceComponentID
      self.carrierOrdinal = carrierOrdinal
      gas = .unobserved
      thermal = .unobserved
      electrical = .unobserved
      mechanical = .unobserved
      operative = .unobserved
      physicalRoster = .unobserved
    }

    private enum CodingKeys: String, CodingKey {
      case id, sourceComponentID, carrierOrdinal, gas, thermal, electrical, mechanical, operative, physicalRoster
    }
    func encode(to encoder: any Encoder) throws {
      var v = encoder.container(keyedBy: CodingKeys.self)
      try v.encode(id, forKey: .id)
      try v.encode(sourceComponentID, forKey: .sourceComponentID)
      if let carrierOrdinal { try v.encode(carrierOrdinal, forKey: .carrierOrdinal) }
      else { try v.encodeNil(forKey: .carrierOrdinal) }
      try v.encode(gas, forKey: .gas)
      try v.encode(thermal, forKey: .thermal)
      try v.encode(electrical, forKey: .electrical)
      try v.encode(mechanical, forKey: .mechanical)
      try v.encode(operative, forKey: .operative)
      try v.encode(physicalRoster, forKey: .physicalRoster)
    }

    init(from decoder: any Decoder) throws {
      try validateCabinRecordKeys(decoder, ["id", "sourceComponentID", "carrierOrdinal", "gas", "thermal",
        "electrical", "mechanical", "operative", "physicalRoster"])
      let v = try decoder.container(keyedBy: CodingKeys.self)
      id = try v.decode(UUID.self, forKey: .id)
      sourceComponentID = try v.decode(String.self, forKey: .sourceComponentID)
      carrierOrdinal = try v.decodeIfPresent(Int.self, forKey: .carrierOrdinal)
      gas = try v.decode(Unobserved.self, forKey: .gas)
      thermal = try v.decode(Unobserved.self, forKey: .thermal)
      electrical = try v.decode(Unobserved.self, forKey: .electrical)
      mechanical = try v.decode(Unobserved.self, forKey: .mechanical)
      operative = try v.decode(Unobserved.self, forKey: .operative)
      physicalRoster = try v.decode(Unobserved.self, forKey: .physicalRoster)
    }
  }

  let id: UUID
  let allocationJournalID: UUID
  let birthRequest: SpawnRequest
  let birthActor: ActorIdentity
  let birthSpawn: SpawnIdentity
  let allocatedAt: Double
  private(set) var retainedAt: Double
  let units: [Unit]

  fileprivate init(actor: ActorIdentity, spawn: SpawnIdentity, time: Double,
    journalID: UUID, request: SpawnRequest, definition: CurrentBisonWideShoeCommissioning) {
    id = UUID()
    allocationJournalID = journalID
    birthRequest = request
    birthActor = actor
    birthSpawn = spawn
    allocatedAt = time
    retainedAt = time
    units = definition.carrierCells.sorted { $0.originalCellOrdinal < $1.originalCellOrdinal }.map {
      Unit(id: UUID(), sourceComponentID: $0.sourceComponentID, carrierOrdinal: $0.originalCellOrdinal)
    } + [Unit(id: UUID(), sourceComponentID: definition.portablePod.sourceComponentID, carrierOrdinal: nil)]
  }

  /// Cold reconciliation preserves every original identity; it cannot allocate.
  fileprivate init(id: UUID, journalID: UUID, request: SpawnRequest, actor: ActorIdentity, spawn: SpawnIdentity,
    allocatedAt: Double, retainedAt: Double, units: [Unit]) {
    self.id = id
    allocationJournalID = journalID
    birthRequest = request
    birthActor = actor
    birthSpawn = spawn
    self.allocatedAt = allocatedAt
    self.retainedAt = retainedAt
    self.units = units
  }

  fileprivate func valid(definition: CurrentBisonWideShoeCommissioning, at time: Double) -> Bool {
    let cells = definition.carrierCells.sorted { $0.originalCellOrdinal < $1.originalCellOrdinal }
    guard time.isFinite, allocatedAt.isFinite, allocatedAt >= 0, retainedAt.isFinite,
      retainedAt >= allocatedAt, retainedAt <= time,
      birthRequest.identity == birthSpawn,
      birthRequest.currentNewtKitConfiguration == CurrentBisonWideShoePhysicalSource.configurationID,
      birthActor.entity > 1, birthActor.entity < UInt64.max,
      birthSpawn.producer == .ambient, birthSpawn.member == 0, birthSpawn.sequence > 0,
      birthSpawn.system == birthActor.system, birthSpawn.visit == birthActor.visit,
      units.count == 13, cells.count == 12,
      Set(units.map(\.id)).count == 13, !units.contains(where: { $0.id == id }) else { return false }
    for index in cells.indices {
      guard units[index].carrierOrdinal == cells[index].originalCellOrdinal,
        units[index].sourceComponentID == cells[index].sourceComponentID else { return false }
    }
    return units[12].carrierOrdinal == nil && units[12].sourceComponentID == definition.portablePod.sourceComponentID
  }

  fileprivate mutating func retain(at time: Double) throws {
    guard time.isFinite, time >= retainedAt else { throw BisonUnitRetentionError.staleClock }
    retainedAt = time
  }
}

enum BisonUnitRetentionError: Error, Equatable {
  case unavailableDefinition, invalidBirthCandidate, foreignAllocation, invalidCurrentWire, staleClock
  case unobservedElectricalStore, unboundCompleteIssueClock, missingPhysicalCommissioningInputs
}

extension Game {
  /// Insert only in the actual constructor after actor allocation and before
  /// its first body snapshot. Only the journal may create this new candidate;
  /// reentry returns the retained journal entry instead of calling this helper.
  /// This value alone must not pass the source's qualified-birth predicate.
  fileprivate func prepareBisonUnobservedUnits(request: SpawnRequest,
    actor: ActorIdentity, context: EncounterContext, journalID: UUID) throws -> BisonUnobservedUnitOwner {
    guard let source = CurrentNewtKitSource.bison, let definition = source.bisonCommissioning else {
      throw BisonUnitRetentionError.unavailableDefinition
    }
    guard gameplayContext() == context, source.permitsBirthDefinition(request, context: context),
      actor.system == context.system, actor.visit == context.visit,
      actor.entity > 1, actor.entity < UInt64.max,
      actor.entity + 1 == commander.flightSimulation.nextActor,
      !bodies.contains(where: { $0.physical?.identity == actor || $0.physical?.spawnIdentity == request.identity })
    else { throw BisonUnitRetentionError.invalidBirthCandidate }
    let result = BisonUnobservedUnitOwner(actor: actor, spawn: request.identity,
      time: context.physicalTime, journalID: journalID, request: request, definition: definition)
    guard result.valid(definition: definition, at: context.physicalTime) else {
      throw BisonUnitRetentionError.invalidBirthCandidate
    }
    return result
  }

  mutating func retainBisonUnobservedUnits(_ owner: inout BisonUnobservedUnitOwner) throws {
    let definition = try currentBisonUnitDefinition(for: owner)
    guard var journal = commander.savedBisonUnitAllocations else {
      throw BisonUnitRetentionError.foreignAllocation
    }
    var retained = owner
    try retained.retain(at: commander.flightSimulation.physicalTime)
    guard retained.valid(definition: definition, at: commander.flightSimulation.physicalTime) else {
      throw BisonUnitRetentionError.staleClock
    }
    var candidate = self
    try journal.retain(retained, request: owner.birthRequest, in: candidate)
    candidate.commander.savedBisonUnitAllocations = journal
    self = candidate
    owner = retained
  }

  /// Source startup budget is not an observed battery. Refusal is atomic.
  func startBisonUnitService(_ owner: inout BisonUnobservedUnitOwner) throws {
    _ = try currentBisonUnitDefinition(for: owner)
    throw BisonUnitRetentionError.unobservedElectricalStore
  }

  /// The source clock begins at an actual COMPLETE birth issue, not provisional
  /// unit allocation. No elapsed-time debit, recharge or support is manufactured.
  func advanceBisonUnitService(_ owner: inout BisonUnobservedUnitOwner) throws {
    _ = try currentBisonUnitDefinition(for: owner)
    throw BisonUnitRetentionError.unboundCompleteIssueClock
  }

  func requireBisonUnitCommissioning(_ owner: BisonUnobservedUnitOwner) throws {
    _ = try currentBisonUnitDefinition(for: owner)
    throw BisonUnitRetentionError.missingPhysicalCommissioningInputs
  }

  fileprivate func currentBisonUnitDefinition(for owner: BisonUnobservedUnitOwner) throws
    -> CurrentBisonWideShoeCommissioning {
    guard let definition = CurrentNewtKitSource.bison?.bisonCommissioning else {
      throw BisonUnitRetentionError.unavailableDefinition
    }
    let flight = commander.flightSimulation
    guard owner.birthActor.system == systemIdentity, owner.birthActor.visit == flight.visit,
      owner.birthActor.entity < flight.nextActor,
      owner.valid(definition: definition, at: flight.physicalTime),
      let journal = commander.savedBisonUnitAllocations, journal.containsCurrent(owner, in: self) else {
      throw BisonUnitRetentionError.foreignAllocation
    }
    return definition
  }
}

extension BisonUnobservedUnitOwner {
  /// Current wire only. A candidate remains untrusted until the actual retained
  /// allocation matches; decoding cannot mint or replace private unit identities.
  fileprivate struct CurrentWire: Equatable, Codable, Sendable {
    let version: Int
    let configuration: String
    let sourceSHA256: String
    let commissioningSHA256: String
    let id: UUID
    let allocationJournalID: UUID
    let birthRequest: SpawnRequest
    let birthActor: ActorIdentity
    let birthSpawn: SpawnIdentity
    let allocatedAt: Double
    let retainedAt: Double
    let units: [Unit]

    init(_ owner: BisonUnobservedUnitOwner) {
      version = 2
      configuration = CurrentBisonWideShoePhysicalSource.configurationID
      sourceSHA256 = CurrentBisonWideShoePhysicalSource.sourceSHA256
      commissioningSHA256 = CurrentBisonWideShoePhysicalSource.commissioningSHA256
      id = owner.id
      allocationJournalID = owner.allocationJournalID
      birthRequest = owner.birthRequest
      birthActor = owner.birthActor
      birthSpawn = owner.birthSpawn
      allocatedAt = owner.allocatedAt
      retainedAt = owner.retainedAt
      units = owner.units
    }

    private enum CodingKeys: String, CodingKey {
      case version, configuration, sourceSHA256, commissioningSHA256, id, allocationJournalID, birthRequest, birthActor,
        birthSpawn, allocatedAt, retainedAt, units
    }
    init(from decoder: any Decoder) throws {
      try validateCabinRecordKeys(decoder, ["version", "configuration", "sourceSHA256", "commissioningSHA256",
        "id", "allocationJournalID", "birthRequest", "birthActor", "birthSpawn", "allocatedAt", "retainedAt", "units"])
      let v = try decoder.container(keyedBy: CodingKeys.self)
      version = try v.decode(Int.self, forKey: .version)
      configuration = try v.decode(String.self, forKey: .configuration)
      sourceSHA256 = try v.decode(String.self, forKey: .sourceSHA256)
      commissioningSHA256 = try v.decode(String.self, forKey: .commissioningSHA256)
      id = try v.decode(UUID.self, forKey: .id)
      allocationJournalID = try v.decode(UUID.self, forKey: .allocationJournalID)
      birthRequest = try v.decode(SpawnRequest.self, forKey: .birthRequest)
      birthActor = try v.decode(ActorIdentity.self, forKey: .birthActor)
      birthSpawn = try v.decode(SpawnIdentity.self, forKey: .birthSpawn)
      allocatedAt = try v.decode(Double.self, forKey: .allocatedAt)
      retainedAt = try v.decode(Double.self, forKey: .retainedAt)
      var list = try v.nestedUnkeyedContainer(forKey: .units)
      guard list.count == 13 else { throw BisonUnitRetentionError.invalidCurrentWire }
      var decoded: [Unit] = []
      while !list.isAtEnd {
        guard decoded.count < 13 else { throw BisonUnitRetentionError.invalidCurrentWire }
        decoded.append(try list.decode(Unit.self))
      }
      units = decoded
    }

    func matches(_ owner: BisonUnobservedUnitOwner) -> Bool {
      version == 2 && configuration == CurrentBisonWideShoePhysicalSource.configurationID
        && sourceSHA256 == CurrentBisonWideShoePhysicalSource.sourceSHA256
        && commissioningSHA256 == CurrentBisonWideShoePhysicalSource.commissioningSHA256
        && id == owner.id && allocationJournalID == owner.allocationJournalID && birthRequest == owner.birthRequest
        && birthActor == owner.birthActor && birthSpawn == owner.birthSpawn
        && allocatedAt == owner.allocatedAt && retainedAt >= owner.retainedAt
        && units == owner.units
    }
  }
}

extension Game {
  func encodeBisonUnobservedUnits(_ owner: BisonUnobservedUnitOwner) throws -> Data {
    _ = try currentBisonUnitDefinition(for: owner)
    return try JSONEncoder().encode(BisonUnobservedUnitOwner.CurrentWire(owner))
  }

  /// G1's later current-cold caller must join the real allocation first. No
  /// standalone JSON decode returns a new owner, commissioning or native stock.
  func restoreBisonUnobservedUnits(_ data: Data, matching owner: BisonUnobservedUnitOwner) throws
    -> BisonUnobservedUnitOwner {
    let definition = try currentBisonUnitDefinition(for: owner)
    let wire = try JSONDecoder().decode(BisonUnobservedUnitOwner.CurrentWire.self, from: data)
    guard wire.matches(owner), wire.retainedAt == owner.retainedAt else { throw BisonUnitRetentionError.invalidCurrentWire }
    let result = BisonUnobservedUnitOwner(id: owner.id, journalID: owner.allocationJournalID, request: owner.birthRequest,
      actor: owner.birthActor, spawn: owner.birthSpawn,
      allocatedAt: owner.allocatedAt, retainedAt: wire.retainedAt, units: owner.units)
    guard result.valid(definition: definition, at: commander.flightSimulation.physicalTime) else {
      throw BisonUnitRetentionError.invalidCurrentWire
    }
    return result
  }
}


/// Private allocation journal, not physical stock. Codable creates an untrusted
/// candidate; all access rechecks the actual Commander allocator/owner and scene.
struct BisonUnitAllocationJournal: Equatable, Codable, Sendable {
  private struct Allocation: Equatable, Codable, Sendable {
    let request: SpawnRequest
    var wire: BisonUnobservedUnitOwner.CurrentWire

    init(request: SpawnRequest, owner: BisonUnobservedUnitOwner) {
      self.request = request
      wire = .init(owner)
    }
    private enum CodingKeys: String, CodingKey { case request, wire }
    init(from decoder: any Decoder) throws {
      try validateCabinRecordKeys(decoder, ["request", "wire"])
      let v = try decoder.container(keyedBy: CodingKeys.self)
      request = try v.decode(SpawnRequest.self, forKey: .request)
      wire = try v.decode(BisonUnobservedUnitOwner.CurrentWire.self, forKey: .wire)
    }
  }

  private let version: Int
  fileprivate let id: UUID
  private let commanderID: UUID
  private var actorCeiling: UInt64
  private var retainedAt: Double
  private var allocations: [Allocation]

  fileprivate init(commander: Commander) throws {
    guard let owner = commander.equipmentOwnerID, commander.equipmentStateValid else {
      throw BisonUnitJournalError.missingCommanderOwner
    }
    version = 2
    id = UUID()
    commanderID = owner
    actorCeiling = commander.flightSimulation.nextActor
    retainedAt = commander.flightSimulation.physicalTime
    allocations = []
  }

  private enum CodingKeys: String, CodingKey {
    case version, id, commanderID, actorCeiling, retainedAt, allocations
  }
  init(from decoder: any Decoder) throws {
    try validateCabinRecordKeys(decoder, ["version", "id", "commanderID", "actorCeiling", "retainedAt", "allocations"])
    let v = try decoder.container(keyedBy: CodingKeys.self)
    version = try v.decode(Int.self, forKey: .version)
    id = try v.decode(UUID.self, forKey: .id)
    commanderID = try v.decode(UUID.self, forKey: .commanderID)
    actorCeiling = try v.decode(UInt64.self, forKey: .actorCeiling)
    retainedAt = try v.decode(Double.self, forKey: .retainedAt)
    guard version == 2, actorCeiling > 2, actorCeiling < UInt64.max,
      retainedAt.isFinite, retainedAt >= 0 else { throw BisonUnitJournalError.invalidJournal }
    var list = try v.nestedUnkeyedContainer(forKey: .allocations)
    // This is the persisted allocator's declared bound, never admission credit.
    // The actual root must independently dominate it before any entry is used.
    guard let count = list.count, count > 0, UInt64(count) <= actorCeiling - 2 else {
      throw BisonUnitJournalError.invalidJournal
    }
    var values: [Allocation] = []
    while !list.isAtEnd {
      guard UInt64(values.count) < actorCeiling - 2 else { throw BisonUnitJournalError.invalidJournal }
      values.append(try list.decode(Allocation.self))
    }
    allocations = values
  }

  /// Exact current-source/identity invariants against the actual decoded root.
  /// No body/operative state, service issue or observation follows from validity.
  func valid(in commander: Commander) -> Bool {
    let flight = commander.flightSimulation
    guard version == 2, let owner = commander.equipmentOwnerID, owner == commanderID,
      commander.equipmentStateValid, flight.valid,
      actorCeiling > 2, actorCeiling <= flight.nextActor,
      retainedAt.isFinite, retainedAt >= 0, retainedAt <= flight.physicalTime,
      !allocations.isEmpty, UInt64(allocations.count) <= actorCeiling - 2,
      let definition = CurrentNewtKitSource.bison?.bisonCommissioning else { return false }
    var actors = Set<UInt64>()
    var spawns = Set<SpawnIdentity>()
    var identities: Set<UUID> = [id]
    for entry in allocations {
      let w = entry.wire
      let unit = w.untrustedRetainedOwner
      guard w.allocationJournalID == id, w.birthRequest == entry.request,
        w.matches(unit), unit.valid(definition: definition, at: retainedAt),
        w.birthActor.entity < actorCeiling, w.birthActor.visit > 0, w.birthActor.visit <= flight.visit,
        (0..<8).contains(w.birthActor.system.galaxy), (0...256).contains(w.birthActor.system.system),
        w.birthSpawn.sequence < flight.nextSpawn,
        entry.request.identity == w.birthSpawn,
        entry.request.currentNewtKitConfiguration == CurrentBisonWideShoePhysicalSource.configurationID,
        entry.request.catalogueShipID == "SH005", entry.request.hull == .cobra,
        entry.request.population == .civilian, entry.request.priority == .ordinary,
        entry.request.energy == nil, entry.request.rock == nil, entry.request.payload == nil,
        entry.request.salvage == nil, entry.request.position.finite, entry.request.velocity.finite,
        entry.request.orientation.x.finite, entry.request.orientation.y.finite, entry.request.orientation.z.finite,
        entry.request.angularVelocity.finite, let npc = entry.request.npc, npc.role == .trader,
        npc.legalProvenance == .generated, npc.cargoProvenance == .generated, npc.routeProvenance == .generated,
        let parent = OriginalFleetRuntimeHullSource.source(for: "SH005"),
        npc.resources == NPCResources.stock(parent.performance),
        actors.insert(w.birthActor.entity).inserted, spawns.insert(w.birthSpawn).inserted,
        identities.insert(w.id).inserted else { return false }
      for value in w.units {
        guard identities.insert(value.id).inserted else { return false }
      }
    }
    return true
  }

  func valid(in game: Game) -> Bool {
    guard valid(in: game.commander) else { return false }
    let actors = Set(allocations.map { $0.wire.birthActor })
    let spawns = Set(allocations.map { $0.wire.birthSpawn })
    // This version is exclusively unpublished UNOBSERVED reservations. A live
    // body with either identity is a collision, never a claimed completed birth.
    return !game.bodies.contains { body in
      guard let physical = body.physical else { return false }
      return actors.contains(physical.identity) || physical.spawnIdentity.map(spawns.contains) == true
    }
  }

  /// A held value is usable only while its exact origin, request, identities
  /// and retention checkpoint remain in the current canonical journal.
  fileprivate func containsCurrent(_ owner: BisonUnobservedUnitOwner, in game: Game) -> Bool {
    guard self == game.commander.savedBisonUnitAllocations, valid(in: game),
      owner.allocationJournalID == id,
      let entry = allocations.first(where: { $0.request.identity == owner.birthSpawn }) else { return false }
    return entry.request == owner.birthRequest && entry.wire == .init(owner)
  }

  func owner(for request: SpawnRequest, in game: Game) throws -> BisonUnobservedUnitOwner? {
    guard valid(in: game), self == game.commander.savedBisonUnitAllocations else {
      throw BisonUnitJournalError.invalidJournal
    }
    guard let entry = allocations.first(where: { $0.request.identity == request.identity }) else { return nil }
    guard entry.request == request else { throw BisonUnitJournalError.conflictingReentry }
    return entry.wire.untrustedRetainedOwner
  }

  fileprivate mutating func retain(_ owner: BisonUnobservedUnitOwner, request: SpawnRequest,
    in game: Game) throws {
    if let index = allocations.firstIndex(where: { $0.request.identity == request.identity }) {
      let previous = allocations[index]
      guard previous.request == request, owner.birthRequest == request, owner.allocationJournalID == id,
        owner.id == previous.wire.id,
        previous.wire.units == owner.units, previous.wire.birthActor == owner.birthActor,
        previous.wire.allocatedAt == owner.allocatedAt, owner.retainedAt >= previous.wire.retainedAt else {
        throw BisonUnitJournalError.conflictingReentry
      }
      allocations[index].wire = .init(owner)
    } else {
      allocations.append(.init(request: request, owner: owner))
    }
    actorCeiling = game.commander.flightSimulation.nextActor
    retainedAt = game.commander.flightSimulation.physicalTime
    guard valid(in: game) else { throw BisonUnitJournalError.invalidJournal }
  }

  fileprivate func preserves(_ previous: Self) -> Bool {
    guard id == previous.id, commanderID == previous.commanderID,
      actorCeiling == previous.actorCeiling, retainedAt >= previous.retainedAt,
      allocations.count == previous.allocations.count else { return false }
    for before in previous.allocations {
      guard let after = allocations.first(where: { $0.request.identity == before.request.identity }),
        after.request == before.request, after.wire.matches(before.wire.untrustedRetainedOwner) else { return false }
    }
    return true
  }
}

enum BisonUnitJournalError: Error, Equatable {
  case missingCommanderOwner, invalidJournal, conflictingReentry, staleContext, unavailableActor
}

extension BisonUnobservedUnitOwner.CurrentWire {
  /// Private candidate only. No caller may expose this without actual root and
  /// allocator checks, and it contains no physical observations or stores.
  fileprivate var untrustedRetainedOwner: BisonUnobservedUnitOwner {
    .init(id: id, journalID: allocationJournalID, request: birthRequest, actor: birthActor,
      spawn: birthSpawn, allocatedAt: allocatedAt,
      retainedAt: retainedAt, units: units)
  }
}

extension Game {
  /// The journal owns native actor allocation once per exact source request.
  /// Both allocator and journal commit together only after complete validation.
  /// A later physical refusal keeps this logical reservation and no body effects.
  mutating func reserveBisonUnobservedUnits(request: SpawnRequest, context: EncounterContext) throws -> BisonUnobservedUnitOwner {
    guard gameplayContext() == context, let source = CurrentNewtKitSource.bison,
      source.permitsBirthDefinition(request, context: context),
      request.identity.sequence < commander.flightSimulation.nextSpawn,
      request.position.finite, request.velocity.finite, request.angularVelocity.finite,
      request.orientation.x.finite, request.orientation.y.finite, request.orientation.z.finite else {
      throw BisonUnitJournalError.staleContext
    }
    var candidate = self
    var retained: BisonUnitAllocationJournal
    if let previous = commander.savedBisonUnitAllocations {
      guard previous.valid(in: self) else { throw BisonUnitJournalError.invalidJournal }
      retained = previous
      if var owner = try retained.owner(for: request, in: self) {
        try candidate.retainBisonUnobservedUnits(&owner)
        self = candidate
        return owner
      }
    } else {
      retained = try .init(commander: candidate.commander)
    }
    guard let actor = candidate.commander.flightSimulation.allocateActor() else {
      throw BisonUnitJournalError.unavailableActor
    }
    let owner = try candidate.prepareBisonUnobservedUnits(request: request, actor: actor, context: context, journalID: retained.id)
    try retained.retain(owner, request: request, in: candidate)
    candidate.commander.savedBisonUnitAllocations = retained
    self = candidate
    return owner
  }

  func encodeBisonUnitJournal(_ journal: BisonUnitAllocationJournal) throws -> Data {
    guard journal.valid(in: self), journal == commander.savedBisonUnitAllocations else {
      throw BisonUnitJournalError.invalidJournal
    }
    return try JSONEncoder().encode(journal)
  }

  /// Standalone wire reconciliation requires the actual retained journal. Fresh
  /// root decode/binding belongs to the real Commander/save owner, not this API.
  func restoreBisonUnitJournal(_ data: Data, matching journal: BisonUnitAllocationJournal) throws
    -> BisonUnitAllocationJournal {
    guard journal.valid(in: self), journal == commander.savedBisonUnitAllocations else {
      throw BisonUnitJournalError.invalidJournal
    }
    let candidate = try JSONDecoder().decode(BisonUnitAllocationJournal.self, from: data)
    guard candidate.valid(in: self), candidate.preserves(journal) else { throw BisonUnitJournalError.invalidJournal }
    return candidate
  }
}


extension BisonUnitAllocationJournal {
  /// Pending reservations own no live body, persistence snapshot, EMP custody
  /// or captured person. Inspect the actual retained owners, including archives.
  func unpublishedSceneIsConsistent(_ bodies: [SpaceBody], commander: Commander) -> Bool {
    guard valid(in: commander) else { return false }
    let actors = Set(allocations.map { $0.wire.birthActor })
    let spawns = Set(allocations.map { $0.wire.birthSpawn })
    func conflicts(_ body: borrowing SpaceBody) -> Bool {
      let physical = (copy body).physical
      return physical.map { actors.contains($0.identity)
        || $0.spawnIdentity.map(spawns.contains) == true
        || $0.empSource.map(actors.contains) == true
        || $0.empCrewPod.map({ actors.contains($0.source) }) == true } == true
    }
    guard !bodies.contains(where: { conflicts($0) }),
      !commander.npcPersistence.conflictsWithUnpublishedBison(actors: actors, spawns: spawns) else { return false }
    if let emp = commander.savedEMPState {
      for (key, record) in emp.records {
        guard !actors.contains(key), !actors.contains(record.source),
          record.originalSpawn.map(spawns.contains) != true,
          !conflicts(record.hull.body), !conflicts(record.custody.original.body),
          !record.pods.contains(where: { conflicts($0.body) }),
          record.savedCurrentTrafficTransfer.map({ actors.contains($0.actor) }) != true,
          record.custody.traffic.map({ actors.contains($0.actor) }) != true else { return false }
      }
    }
    guard commander.nativePeople?.admissions.contains(where: { value in
      value.person.emp.map { actors.contains($0.source) } == true
        || actors.contains(value.actor)
    }) != true else { return false }
    for request in commander.encounterDirector?.pendingRequests ?? [] where spawns.contains(request.identity) {
      guard allocations.contains(where: { $0.request == request }) else { return false }
    }
    return true
  }
}
