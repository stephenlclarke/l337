import Foundation
import Testing

@testable import L337Core

private struct StationStateFixture {
  let world: UUID
  var owner: UUID { world }
  let system = OriginalStationSite.salamander.system

  init(world: UUID = UUID()) { self.world = world }

  func record(
    site: OriginalStationSite = .salamander,
    capabilities: [NativeStationCapability]? = nil
  ) throws -> NativeStationRecord {
    let current = try NativeStationWorld(owner: world)
    var record = try #require(current.ledger.records.first { $0.identity == site.identity(world: world) })
    if let capabilities {
      record = .init(
        identity: record.identity,
        descriptor: .init(
          definition: record.descriptor.definition, version: record.descriptor.version,
          boardOrigin: record.descriptor.boardOrigin, capabilities: capabilities),
        revision: record.revision, binding: record.binding, tombstone: record.tombstone,
        utility: record.utility, utilitySourceBirth: record.utilitySourceBirth)
    }
    return record
  }

  func budgetRecords(count: Int) throws -> [NativeStationRecord] {
    let limit = try stationRecordBudget()
    try #require((0...limit).contains(count))
    let records = Array(try NativeStationWorld(owner: world).ledger.records.prefix(count))
    try #require(records.count == count && records.allSatisfy { $0.valid })
    try #require(Set(records.map(\.identity.slot)).count == count)
    return records
  }

  func binding(
    system: SystemIdentity? = nil, visit: UInt64 = 1, entity: UInt64 = 9, body: Int = 9
  ) -> NativeStationBinding {
    .init(actor: .init(system: system ?? self.system, visit: visit, entity: entity), bodyID: body)
  }

  static func admittedRemoteWorld() throws -> NativeStationWorld {
    var game = Game(executive: false)
    game.commander.system = OriginalStationSite.remoteUtility.system.system
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.commander.valid)
    let world = try #require(game.commander.nativeStations)
    let identity = OriginalStationSite.remoteUtility.identity(world: world.ledger.world)
    let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
    try #require(game.nativeStationBodyIsCurrent(body))
    let record = try #require(world.ledger.records.first { $0.identity == identity })
    try #require(record.utilitySourceBirth != nil && record.binding != nil && record.valid)
    return world
  }

  // Model-only ledger exercise. This does not issue a Game's sealed entry or live service proof.
  func docked() throws -> NativeStationLedger {
    let record = try record()
    var ledger = try NativeStationLedger(world: world, records: [record])
    let binding = binding()
    try ledger.rebind(record.identity, to: binding)
    try ledger.recordDock(at: record.identity, binding: binding, commanderOwner: owner)
    return ledger
  }
}

private func stationRecordBudget() throws -> Int {
  let limit = NativeStationLedger.recordLimit
  try #require(limit > 0 && limit <= NativeStationLedger.maximumSourceRecords)
  try #require(limit == 4 && Set(OriginalStationSite.allCases).count == 4)
  // The absolute decoder budget remains separate from the closed four-site source domain.
  try #require(NativeStationLedger.maximumSourceRecords == 8 * (256 + 1))
  return limit
}

@Test func nativeStationLoadPreservesCustodyAndOnlyLiveContextUsesEpoch() throws {
  let fixture = StationStateFixture()
  let ledger = try fixture.docked()
  let epoch = UUID()
  let context = try #require(
    ledger.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: epoch))
  let bytes = try JSONEncoder().encode(ledger)
  let loaded = try JSONDecoder().decode(NativeStationLedger.self, from: bytes)
  #expect(loaded == ledger && loaded.currentDock?.sequence == 1 && loaded.nextDockSequence == 2)
  #expect(loaded.world == fixture.world)
  #expect(
    loaded.accepts(
      context, docked: true, system: fixture.system, commanderOwner: fixture.owner,
      runtimeEpoch: epoch))
  let newEpoch = UUID()
  #expect(
    !loaded.accepts(
      context, docked: true, system: fixture.system, commanderOwner: fixture.owner,
      runtimeEpoch: newEpoch))
  let fresh = try #require(
    loaded.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch))
  #expect(fresh.receipt == context.receipt && fresh.runtimeEpoch == newEpoch)
  #expect(loaded.currentDock == ledger.currentDock && loaded.nextDockSequence == 2)
  #expect(
    loaded.serviceContext(
      capability: .sealedDispatchBoard, docked: false, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: fixture.system,
      commanderOwner: UUID(), runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: fixture.system,
      commanderOwner: nil, runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: .init(galaxy: 0, system: 1),
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch) == nil)
}

@Test func nativeStationRebindingRetainsHistoricalDockAndDestructionCannotRevive() throws {
  let fixture = StationStateFixture()
  var ledger = try fixture.docked()
  let oldReceipt = try #require(ledger.currentDock)
  let newBinding = fixture.binding(visit: 2, entity: 12, body: 12)
  try ledger.rebind(oldReceipt.station, to: newBinding)
  #expect(ledger.valid && ledger.currentDock == oldReceipt && ledger.nextDockSequence == 2)
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.destroy(oldReceipt.station, binding: oldReceipt.dockingBinding)
  }
  #expect(ledger == before)
  ledger.depart()
  try ledger.recordDock(at: oldReceipt.station, binding: newBinding, commanderOwner: fixture.owner)
  #expect(ledger.currentDock?.sequence == 2 && ledger.nextDockSequence == 3)
  try ledger.destroy(oldReceipt.station, binding: newBinding)
  #expect(ledger.valid && ledger.currentDock == nil && ledger.records[0].revision == 2)
  #expect(ledger.records[0].binding == nil)
  #expect(ledger.records[0].tombstone?.destroyedBinding == newBinding)
  let destroyed = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(oldReceipt.station, to: fixture.binding(visit: 3))
  }
  #expect(throws: NativeStationStateError.self) {
    try ledger.recordDock(
      at: oldReceipt.station, binding: newBinding, commanderOwner: fixture.owner)
  }
  #expect(ledger == destroyed)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(ledger)) == ledger
  )
}

@Test func nativeStationRegistryRejectsDuplicateForeignAndUnboundedState() throws {
  let fixture = StationStateFixture()
  let record = try fixture.record()
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: [record, record])
  }
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: UUID(), records: [record])
  }
  let alias = NativeStationRecord(
    identity: .init(
      world: fixture.world, system: fixture.system, definition: record.identity.definition,
      version: record.identity.version, key: "alias"),
    descriptor: record.descriptor, revision: 1, binding: nil, tombstone: nil)
  #expect(!alias.valid)
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: [record, alias])
  }
  let changedVersion = NativeStationIdentity(
    world: fixture.world, system: fixture.system, definition: record.identity.definition,
    version: "foreign-current-revision", key: record.identity.key)
  #expect(!changedVersion.valid && changedVersion.slot == record.identity.slot)
  let limit = try stationRecordBudget()
  let records = try fixture.budgetRecords(count: limit)
  #expect(records.count == 4 && records.allSatisfy { $0.valid })
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: records + [record])
  }
  var ledger = try NativeStationLedger(
    world: fixture.world, records: [record, try fixture.record(site: .frog)])
  try ledger.rebind(record.identity, to: fixture.binding())
  let before = ledger
  let otherIdentity = ledger.records[1].identity
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(otherIdentity, to: fixture.binding())
  }
  #expect(ledger == before)
  let foreign = NativeStationBinding(
    actor: .init(system: .init(galaxy: 1, system: 237), visit: 1, entity: 9), bodyID: 9)
  #expect(throws: NativeStationStateError.self) { try ledger.rebind(record.identity, to: foreign) }
  #expect(ledger == before)
}

@Test func nativeStationDecodeRefusesMissingNamespaceOverflowAndInconsistentDock() throws {
  let fixture = StationStateFixture()
  let ledger = try fixture.docked()
  let bytes = try JSONEncoder().encode(ledger)
  let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  for field in ["world", "nextDockSequence", "records", "currentDock"] {
    var object = original
    if field == "world" { object.removeValue(forKey: field) }
    if field == "nextDockSequence" { object[field] = UInt64.max }
    if field == "records" { object[field] = [] }
    if field == "currentDock" {
      var receipt = try #require(object[field] as? [String: Any])
      receipt["lifecycleRevision"] = 2
      object[field] = receipt
    }
    let invalid = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(NativeStationLedger.self, from: invalid)
    }
  }
}

@Test func nativeStationEmptyCapabilitiesGrantNoService() throws {
  let fixture = StationStateFixture()
  let invalidAvenor = try fixture.record(capabilities: [])
  #expect(!invalidAvenor.valid)
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: [invalidAvenor])
  }
  let world = try StationStateFixture.admittedRemoteWorld()
  let identity = OriginalStationSite.remoteUtility.identity(world: world.ledger.world)
  let record = try #require(world.ledger.records.first { $0.identity == identity })
  let binding = try #require(record.binding)
  #expect(record.valid && record.utilitySourceBirth != nil && record.descriptor.capabilities.isEmpty)
  // Historical ledger data cannot grant a capability. Actual remote doorway entry is
  // covered by the native service tests, which own the real GameRuntime and writer.
  var ledger = world.ledger
  try ledger.recordDock(at: identity, binding: binding, commanderOwner: world.ledger.world)
  #expect(ledger.valid && ledger.currentDock?.station == identity)
  #expect(
    ledger.serviceContext(
      capability: .sealedDispatchBoard, docked: true, system: identity.system,
      commanderOwner: world.ledger.world, runtimeEpoch: UUID()) == nil)
}

@Test func nativeStationStructuralMetadataAndRevisionLimitsAreChecked() throws {
  let fixture = StationStateFixture()
  let record = try fixture.record()
  let maximum = try fixture.budgetRecords(count: stationRecordBudget())
  let admitted = try NativeStationLedger(world: fixture.world, records: maximum)
  #expect(admitted.valid)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(admitted))
      == admitted)
  var invalid = record
  invalid.revision = 0
  #expect(!invalid.valid)
  invalid.revision = UInt64.max
  #expect(!invalid.valid)
  invalid = record
  invalid.tombstone = .init(revision: 2, destroyedBinding: fixture.binding())
  #expect(!invalid.valid)
  let duplicateCapabilities = try fixture.record(capabilities: [.sealedDispatchBoard, .sealedDispatchBoard])
  #expect(!duplicateCapabilities.valid)
  let other = try fixture.record(site: .frog)
  #expect(other.descriptor.matches(other.identity))
  #expect(other.descriptor.boardOrigin == .authored)
  #expect(other.descriptor.sourceRoles == [other.identity.definition])
  #expect(!record.descriptor.matches(other.identity))
  var ledger = try NativeStationLedger(world: fixture.world, records: [record])
  try ledger.rebind(record.identity, to: fixture.binding())
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.recordDock(at: record.identity, binding: fixture.binding(), commanderOwner: nil)
  }
  #expect(ledger == before && ledger.nextDockSequence == 1 && ledger.currentDock == nil)
}

@Test func nativeStationReservedActorsAndHistoricalDockAliasesRefuse() throws {
  let fixture = StationStateFixture()
  let way = try fixture.record()
  let hq = try fixture.record(site: .frog)
  var ledger = try NativeStationLedger(world: fixture.world, records: [way, hq])
  for entity in [UInt64(0), UInt64(1)] {
    let before = ledger
    #expect(throws: NativeStationStateError.self) {
      try ledger.rebind(way.identity, to: fixture.binding(entity: entity))
    }
    #expect(ledger == before)
  }
  let old = fixture.binding()
  try ledger.rebind(way.identity, to: old)
  try ledger.recordDock(at: way.identity, binding: old, commanderOwner: fixture.owner)
  let receipt = ledger.currentDock
  try ledger.rebind(way.identity, to: fixture.binding(visit: 2, entity: 12, body: 12))
  let before = ledger
  for alias in [
    old, fixture.binding(entity: 20, body: old.bodyID),
    fixture.binding(entity: old.actor.entity, body: 20),
  ] {
    #expect(throws: NativeStationStateError.self) { try ledger.rebind(hq.identity, to: alias) }
    #expect(ledger == before && ledger.currentDock == receipt)
  }
  try ledger.rebind(hq.identity, to: fixture.binding(visit: 2, entity: 13, body: 13))
  #expect(ledger.valid && ledger.currentDock == receipt && ledger.nextDockSequence == 2)
}

@Test func nativeStationDecoderRejectsOversizedRecordArrayBeforeDecodingElements() throws {
  let fixture = StationStateFixture()
  let ledger = try NativeStationLedger(world: fixture.world, records: [])
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  let limit = try stationRecordBudget()
  // At the admitted count these malformed elements reach element decoding.
  object["records"] = Array(repeating: "not a station record", count: limit)
  let control = try JSONSerialization.data(withJSONObject: object)
  do {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: control)
    Issue.record("Malformed admitted-size records must reach element decoding")
  } catch DecodingError.typeMismatch(_, let context) {
    #expect(context.codingPath.first?.stringValue == "records")
    #expect(context.codingPath.last?.intValue == 0)
  }
  // One record over budget must refuse before decoding those same malformed elements.
  object["records"] = Array(repeating: "not a station record", count: limit + 1)
  let bytes = try JSONSerialization.data(withJSONObject: object)
  do {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: bytes)
    Issue.record("Oversized station registry must refuse before element decoding")
  } catch DecodingError.dataCorrupted(let context) {
    #expect(context.debugDescription == "Native station record limit exceeded.")
  }
}

@Test func nativeStationCurrentDockRequiresLatestSequenceButDepartureKeepsHistoryCounter() throws {
  let fixture = StationStateFixture()
  var ledger = try fixture.docked()
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  object["nextDockSequence"] = ledger.nextDockSequence + 1
  let invalid = try JSONSerialization.data(withJSONObject: object)
  #expect(throws: (any Error).self) {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: invalid)
  }
  ledger.depart()
  #expect(ledger.valid && ledger.currentDock == nil && ledger.nextDockSequence == 2)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(ledger)) == ledger
  )
}

@Test func nativeStationBodyBindingUniquenessIncludesSystemAndVisit() throws {
  // The different-system record comes from actual remote source admission and its birth event.
  let world = try StationStateFixture.admittedRemoteWorld()
  let fixture = StationStateFixture(world: world.ledger.world)
  let way = try fixture.record()
  let other = try fixture.record(site: .frog)
  let remoteID = OriginalStationSite.remoteUtility.identity(world: fixture.world)
  let remote = try #require(world.ledger.records.first { $0.identity == remoteID })
  try #require(remote.utilitySourceBirth != nil && remote.binding != nil && remote.valid)
  var ledger = try NativeStationLedger(world: fixture.world, records: [way, other, remote])
  try ledger.rebind(way.identity, to: fixture.binding(entity: 9, body: 9))
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(other.identity, to: fixture.binding(entity: 10, body: 9))
  }
  #expect(ledger == before)
  try ledger.rebind(other.identity, to: fixture.binding(visit: 2, entity: 10, body: 9))
  #expect(ledger.valid && ledger.records[0].binding?.bodyID == ledger.records[1].binding?.bodyID)
  let differentSystem = fixture.binding(system: remoteID.system, entity: 9, body: 9)
  try ledger.rebind(remote.identity, to: differentSystem)
  #expect(ledger.valid && ledger.records[2].binding == differentSystem)
  #expect(ledger.records.allSatisfy { $0.binding?.bodyID == 9 })
}
