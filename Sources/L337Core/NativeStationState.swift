import Foundation

/// Exact original logical site, independent of a scene body or visit actor.
struct NativeStationIdentity: Hashable, Codable, Sendable {
  let world: UUID
  let system: SystemIdentity
  let definition: String
  let version: String
  let key: String
  init(world: UUID, system: SystemIdentity, definition: String, version: String, key: String) {
    self.world = world
    self.system = system
    self.definition = definition
    self.version = version
    self.key = key
  }
  var valid: Bool { OriginalStationSite.site(for: self, owner: world) != nil }
  var slot: NativeStationSlot { .init(world: world, system: system, key: key) }
  private enum CodingKeys: String, CodingKey { case world, system, definition, version, key }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["world", "system", "definition", "version", "key"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    world = try c.decode(UUID.self, forKey: .world)
    let systemDecoder = try c.superDecoder(forKey: .system)
    try NativeUtilityCoding.require(systemDecoder, ["galaxy", "system"])
    system = try SystemIdentity(from: systemDecoder)
    definition = try c.decode(String.self, forKey: .definition)
    version = try c.decode(String.self, forKey: .version)
    key = try c.decode(String.self, forKey: .key)
    guard valid else { throw SaveError.invalidCommander }
  }
}
struct NativeStationSlot: Hashable, Sendable {
  let world: UUID
  let system: SystemIdentity
  let key: String
}
enum NativeStationCapability: String, Hashable, Codable, Sendable { case sealedDispatchBoard }
enum NativeStationCapabilityOrigin: String, Codable, Sendable { case authored }

/// Descriptive data must exactly match the compiled original site policy.
struct NativeStationDescriptor: Equatable, Codable, Sendable {
  let definition: String
  let version: String
  let boardOrigin: NativeStationCapabilityOrigin
  let capabilities: [NativeStationCapability]
  init(definition: String, version: String, boardOrigin: NativeStationCapabilityOrigin,
    capabilities: [NativeStationCapability])
  {
    self.definition = definition
    self.version = version
    self.boardOrigin = boardOrigin
    self.capabilities = capabilities
  }
  var sourceRoles: [String] { [definition] }
  func matches(_ identity: NativeStationIdentity) -> Bool {
    guard let site = OriginalStationSite.site(for: identity, owner: identity.world) else { return false }
    return definition == identity.definition && version == OriginalStationSite.sourceVersion
      && boardOrigin == .authored
      && capabilities == (site.sealedDispatchDefinition == nil ? [] : [.sealedDispatchBoard])
  }
  private enum CodingKeys: String, CodingKey { case definition, version, boardOrigin, capabilities }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["definition", "version", "boardOrigin", "capabilities"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    definition = try c.decode(String.self, forKey: .definition)
    version = try c.decode(String.self, forKey: .version)
    boardOrigin = try c.decode(NativeStationCapabilityOrigin.self, forKey: .boardOrigin)
    capabilities = try NativeUtilityCoding.array(NativeStationCapability.self,
      key: .capabilities, container: c, limit: 1)
  }
}

struct NativeStationBinding: Equatable, Codable, Sendable {
  init(actor: ActorIdentity, bodyID: Int) {
    self.actor = actor
    self.bodyID = bodyID
  }
  private enum CodingKeys: String, CodingKey { case actor, bodyID }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["actor", "bodyID"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let actorDecoder = try c.superDecoder(forKey: .actor)
    try NativeUtilityCoding.require(actorDecoder, ["system", "visit", "entity"])
    let actorFields = try actorDecoder.container(keyedBy: NativeUtilityCoding.Key.self)
    let actorSystem = try actorFields.superDecoder(forKey: NativeUtilityCoding.Key(stringValue: "system")!)
    try NativeUtilityCoding.require(actorSystem, ["galaxy", "system"])
    actor = try ActorIdentity(from: actorDecoder)
    bodyID = try c.decode(Int.self, forKey: .bodyID)
  }

  let actor: ActorIdentity
  let bodyID: Int

  func valid(for identity: NativeStationIdentity) -> Bool {
    actor.system == identity.system && actor.visit > 0 && actor.visit <= UInt64(Int64.max)
      && actor.entity >= 2 && actor.entity <= UInt64(Int64.max) && bodyID > 0
  }
}

private struct NativeStationBodyBinding: Hashable {
  let system: SystemIdentity
  let visit: UInt64
  let bodyID: Int

  init(_ binding: NativeStationBinding) {
    system = binding.actor.system
    visit = binding.actor.visit
    bodyID = binding.bodyID
  }
}

struct NativeStationTombstone: Equatable, Codable, Sendable {
  init(revision: UInt64, destroyedBinding: NativeStationBinding) {
    self.revision = revision
    self.destroyedBinding = destroyedBinding
  }
  private enum CodingKeys: String, CodingKey { case revision, destroyedBinding }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["revision", "destroyedBinding"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    revision = try c.decode(UInt64.self, forKey: .revision)
    destroyedBinding = try c.decode(NativeStationBinding.self, forKey: .destroyedBinding)
  }

  let revision: UInt64
  let destroyedBinding: NativeStationBinding
}

struct NativeStationRecord: Equatable, Codable, Sendable {
  let identity: NativeStationIdentity
  let descriptor: NativeStationDescriptor
  var revision: UInt64
  var binding: NativeStationBinding?
  var tombstone: NativeStationTombstone?
  var utility: NativeUtilityState? = nil
  var utilitySourceBirth: NativeOriginalUtilityBirthReceipt? = nil

  private enum CodingKeys: String, CodingKey {
    case identity, descriptor, revision, binding, tombstone, utility, utilitySourceBirth
  }
  init(
    identity: NativeStationIdentity, descriptor: NativeStationDescriptor, revision: UInt64,
    binding: NativeStationBinding?, tombstone: NativeStationTombstone?,
    utility: NativeUtilityState? = nil, utilitySourceBirth: NativeOriginalUtilityBirthReceipt? = nil
  ) {
    self.identity = identity
    self.descriptor = descriptor
    self.revision = revision
    self.binding = binding
    self.tombstone = tombstone
    self.utility = utility
    self.utilitySourceBirth = utilitySourceBirth
  }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["identity", "descriptor", "revision"],
      optional: ["binding", "tombstone", "utility", "utilitySourceBirth"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    identity = try c.decode(NativeStationIdentity.self, forKey: .identity)
    descriptor = try c.decode(NativeStationDescriptor.self, forKey: .descriptor)
    revision = try c.decode(UInt64.self, forKey: .revision)
    binding = c.contains(.binding) ? try c.decode(NativeStationBinding.self, forKey: .binding) : nil
    tombstone = c.contains(.tombstone) ? try c.decode(NativeStationTombstone.self, forKey: .tombstone) : nil
    utility = c.contains(.utility) ? try c.decode(NativeUtilityState.self, forKey: .utility) : nil
    utilitySourceBirth = c.contains(.utilitySourceBirth)
      ? try c.decode(NativeOriginalUtilityBirthReceipt.self, forKey: .utilitySourceBirth) : nil
    guard NativeUtilityState.isTarget(identity) || (!c.contains(.utility) && !c.contains(.utilitySourceBirth)), valid else {
      throw SaveError.invalidCommander
    }
  }

  var valid: Bool {
    let utilityValid: Bool
    if NativeUtilityState.isTarget(identity) {
      utilityValid =
        utility?.owner == identity.world && utility?.valid == true
        && utility?.consignments.allSatisfy({
          ($0.installation?.contact.lifecycle ?? 1) <= revision
        }) == true
    } else {
      utilityValid = utility == nil && utilitySourceBirth == nil
    }
    let birthValid = utilitySourceBirth.map { $0.valid && $0.station == identity }
      ?? (!NativeUtilityState.isTarget(identity) || (binding == nil && tombstone == nil))
    return birthValid && utilityValid && identity.valid && descriptor.matches(identity) && revision > 0
      && revision < UInt64(Int64.max) && (binding?.valid(for: identity) ?? true)
      && (tombstone.map {
        $0.revision == revision && $0.destroyedBinding.valid(for: identity) && binding == nil
      } ?? true)
  }
}

/// Frozen evidence of actual docking, retained across load and subsequent visit rebinding.
struct NativeStationDockReceipt: Equatable, Codable, Sendable {
  init(station: NativeStationIdentity, lifecycleRevision: UInt64, dockingBinding: NativeStationBinding, sequence: UInt64, commanderOwner: UUID) {
    self.station = station
    self.lifecycleRevision = lifecycleRevision
    self.dockingBinding = dockingBinding
    self.sequence = sequence
    self.commanderOwner = commanderOwner
  }
  private enum CodingKeys: String, CodingKey { case station, lifecycleRevision, dockingBinding, sequence, commanderOwner }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["station", "lifecycleRevision", "dockingBinding", "sequence", "commanderOwner"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    station = try c.decode(NativeStationIdentity.self, forKey: .station)
    lifecycleRevision = try c.decode(UInt64.self, forKey: .lifecycleRevision)
    dockingBinding = try c.decode(NativeStationBinding.self, forKey: .dockingBinding)
    sequence = try c.decode(UInt64.self, forKey: .sequence)
    commanderOwner = try c.decode(UUID.self, forKey: .commanderOwner)
  }

  let station: NativeStationIdentity
  let lifecycleRevision: UInt64
  let dockingBinding: NativeStationBinding
  let sequence: UInt64
  let commanderOwner: UUID
}

/// Never decoded or saved. Only the trusted native boundary can request a fresh context.
struct NativeStationServiceContext: Equatable, Sendable {
  let receipt: NativeStationDockReceipt
  let capability: NativeStationCapability
  let runtimeEpoch: UUID

  fileprivate init(
    receipt: NativeStationDockReceipt, capability: NativeStationCapability, runtimeEpoch: UUID
  ) {
    self.receipt = receipt
    self.capability = capability
    self.runtimeEpoch = runtimeEpoch
  }
}

enum NativeStationStateError: Error { case invalidState, unavailable }

struct NativeStationLedger: Equatable, Codable, Sendable {
  /// Absolute decode budget; the exact current original source set is checked separately.
  static let maximumSourceRecords = 8 * (256 + 1)
  static var recordLimit: Int { OriginalStationSite.allCases.count }
  let world: UUID
  private(set) var records: [NativeStationRecord]
  private(set) var nextDockSequence: UInt64
  private(set) var currentDock: NativeStationDockReceipt?

  /// Explicit activation only; decoding never invents a namespace, record or arrival.
  init(world: UUID, records: [NativeStationRecord]) throws {
    self.world = world
    self.records = records
    nextDockSequence = 1
    currentDock = nil
    guard valid else { throw NativeStationStateError.invalidState }
  }

  var valid: Bool {
    guard Self.recordLimit <= Self.maximumSourceRecords,
      records.count <= Self.recordLimit, nextDockSequence > 0,
      nextDockSequence < UInt64(Int64.max),
      records.allSatisfy({ $0.valid && $0.identity.world == world }),
      Set(records.map(\.identity)).count == records.count,
      Set(records.map { $0.identity.slot }).count == records.count
    else { return false }
    let bindings = records.compactMap { $0.binding ?? $0.tombstone?.destroyedBinding }
    guard Set(bindings.map(\.actor)).count == bindings.count else { return false }
    // Body numbers are unique only within their system visit.
    guard Set(bindings.map(NativeStationBodyBinding.init)).count == bindings.count else {
      return false
    }
    guard let receipt = currentDock else { return true }
    guard
      !records.contains(where: { record in
        guard record.identity.slot != receipt.station.slot,
          let binding = record.binding ?? record.tombstone?.destroyedBinding
        else { return false }
        return binding.actor == receipt.dockingBinding.actor
          || (binding.actor.system == receipt.dockingBinding.actor.system
            && binding.actor.visit == receipt.dockingBinding.actor.visit
            && binding.bodyID == receipt.dockingBinding.bodyID)
      })
    else { return false }
    return receipt.sequence > 0 && receipt.sequence == nextDockSequence - 1
      && receipt.dockingBinding.valid(for: receipt.station)
      && records.contains {
        $0.identity == receipt.station && $0.tombstone == nil
          && $0.revision == receipt.lifecycleRevision
      }
  }

  /// Native preflight owns the physical proof. Rebinding cannot revive a destroyed station.
  mutating func rebind(_ identity: NativeStationIdentity, to binding: NativeStationBinding) throws {
    guard valid, let index = records.firstIndex(where: { $0.identity == identity }),
      records[index].tombstone == nil, binding.valid(for: identity)
    else { throw NativeStationStateError.unavailable }
    var candidate = self
    candidate.records[index].binding = binding
    guard candidate.valid else { throw NativeStationStateError.invalidState }
    self = candidate
  }

  /// Call only after actual native docking and persistence preflight have succeeded.
  mutating func recordDock(
    at identity: NativeStationIdentity, binding: NativeStationBinding, commanderOwner: UUID?
  ) throws {
    guard let commanderOwner, commanderOwner == world, valid, currentDock == nil, nextDockSequence < UInt64(Int64.max) - 1,
      let record = records.first(where: { $0.identity == identity }), record.tombstone == nil,
      record.binding == binding
    else { throw NativeStationStateError.unavailable }
    currentDock = .init(
      station: identity, lifecycleRevision: record.revision, dockingBinding: binding,
      sequence: nextDockSequence, commanderOwner: commanderOwner)
    nextDockSequence += 1
  }

  mutating func depart() { currentDock = nil }

  mutating func destroy(_ identity: NativeStationIdentity, binding: NativeStationBinding) throws {
    guard valid, let index = records.firstIndex(where: { $0.identity == identity }),
      records[index].tombstone == nil, records[index].binding == binding,
      records[index].revision < UInt64(Int64.max) - 1
    else { throw NativeStationStateError.unavailable }
    records[index].revision += 1
    records[index].tombstone = .init(revision: records[index].revision, destroyedBinding: binding)
    records[index].binding = nil
    if currentDock?.station == identity { currentDock = nil }
  }

  /// A utility operation never changes a station lifecycle or manufactures docking authority.
  /// Called only inside the sealed copied population plan before its native publication.
  mutating func recordUtilityBirth(_ receipt: NativeOriginalUtilityBirthReceipt) throws {
    guard receipt.valid, let index = records.firstIndex(where: { $0.identity == receipt.station }),
      NativeUtilityState.isTarget(receipt.station), records[index].binding == nil,
      records[index].tombstone == nil, records[index].utilitySourceBirth == nil
    else { throw NativeStationStateError.invalidState }
    records[index].utilitySourceBirth = receipt
  }

  mutating func replaceUtility(_ state: NativeUtilityState) throws {
    guard state.owner == world, state.valid,
      let index = records.firstIndex(where: { $0.identity == state.target }),
      let previous = records[index].utility, previous.revision < UInt64(Int64.max) - 1,
      state.revision == previous.revision + 1
    else { throw NativeStationStateError.invalidState }
    var candidate = self
    candidate.records[index].utility = state
    guard candidate.valid else { throw NativeStationStateError.invalidState }
    self = candidate
  }

  /// G1 supplies actual docked state/system/owner and the current transient runtime epoch.
  func serviceContext(
    capability: NativeStationCapability, docked: Bool, system: SystemIdentity,
    commanderOwner: UUID?, runtimeEpoch: UUID
  ) -> NativeStationServiceContext? {
    guard let commanderOwner, commanderOwner == world, valid, docked, let receipt = currentDock,
      receipt.station.system == system,
      receipt.commanderOwner == commanderOwner,
      records.first(where: { $0.identity == receipt.station })?.descriptor.capabilities.contains(
        capability)
        == true
    else { return nil }
    return .init(receipt: receipt, capability: capability, runtimeEpoch: runtimeEpoch)
  }

  func accepts(
    _ context: NativeStationServiceContext, docked: Bool, system: SystemIdentity,
    commanderOwner: UUID?, runtimeEpoch: UUID
  ) -> Bool {
    serviceContext(
      capability: context.capability, docked: docked, system: system,
      commanderOwner: commanderOwner, runtimeEpoch: runtimeEpoch) == context
  }

  private enum CodingKeys: String, CodingKey { case world, records, nextDockSequence, currentDock }

  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["world", "records", "nextDockSequence"], optional: ["currentDock"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    world = try values.decode(UUID.self, forKey: .world)
    var entries = try values.nestedUnkeyedContainer(forKey: .records)
    guard Self.recordLimit <= Self.maximumSourceRecords,
      entries.count.map({ $0 <= Self.recordLimit }) ?? true
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .records, in: values, debugDescription: "Native station record limit exceeded.")
    }
    var decoded: [NativeStationRecord] = []
    while !entries.isAtEnd {
      guard decoded.count < Self.recordLimit else {
        throw DecodingError.dataCorruptedError(
          forKey: .records, in: values, debugDescription: "Native station record limit exceeded.")
      }
      decoded.append(try entries.decode(NativeStationRecord.self))
    }
    records = decoded
    nextDockSequence = try values.decode(UInt64.self, forKey: .nextDockSequence)
    currentDock = values.contains(.currentDock)
      ? try values.decode(NativeStationDockReceipt.self, forKey: .currentDock) : nil
    guard valid else {
      throw DecodingError.dataCorruptedError(
        forKey: .records, in: values, debugDescription: "Invalid native station custody.")
    }
  }
}
