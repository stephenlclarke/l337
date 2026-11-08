import Foundation

/// The adopted original C25 station-service source; never a person or a general stock provider.
enum NativeMemoryAtlasWatcherSource {
  static let adoptionRevision: UInt64 = 1
  static let world = SystemIdentity(galaxy: 0, system: 80)
  static let resource = "memory-atlas-reference"
  static let name = "Atlas Reference Watcher"
  static let node = EquipmentNodeID(family: .init(resource), key: name)
  static let cargoTonnes = 1
  static let version = "1.0.0"
  static let digest = "ee7da4c00fded8856bf7407f29864e93ce30f65adf96c03ee0c2eb0280d4dbe6"
  static let purchaseNode = EquipmentPurchaseNode(id: node, displayName: name, policy: .acquisitionOnly)
  static let gear = ScriptGearDefinition(
    id: resource, name: name, quantity: 1, loan: true, mount: nil, returnPolicy: "all")

  static func caseID(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c25-memory-atlas-commission-v1:\(owner)")
  }
  static func issuer(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c25-reris-vale-watcher-owner-v1:\(owner)")
  }
  static func original(owner: UUID) -> UUID {
    OwnedGear.issuedIdentity(mission: caseID(owner: owner), resource: resource, index: 0)
  }
  static var canonicalNodeInstalled: Bool {
    EquipmentRuntimeCatalog.graph.nodes.contains { $0 == purchaseNode }
      && EquipmentRuntimeCatalog.node(for: name) == node && OwnedGearKind.module(name).valid
  }
}

/// History is decoded as facts, never as a live quote or an authority to create stock.
struct NativeMemoryAtlasWatcherSourceRecord: Codable, Equatable, Sendable {
  enum Custody: String, Codable, Sendable { case available, onLoan }
  struct Initialization: Codable, Equatable, Sendable {
    let dock: NativeMainStationDockReceipt
    let eventSequence: UInt64
    let physicalTime: Double
    let calendarSeconds: Double
  }
  struct Transfer: Codable, Equatable, Sendable {
    let beforeSourceRevision: UInt64
    let afterSourceRevision: UInt64
    let collection: NativeMemoryAtlasReferenceCollection
  }

  let adoptionRevision: UInt64
  let sourceRevision: UInt64
  let owner: UUID
  let issuer: UUID
  let caseID: UUID
  let original: UUID
  let station: NativeMainStationIdentity
  let resource: String
  let name: String
  let node: EquipmentNodeID
  let quantity: Int
  let cargoTonnes: Int
  let heldOnly: Bool
  let loan: Bool
  let returnPolicy: String
  let packVersion: String
  let packDigest: String
  let initialization: Initialization
  let custody: Custody
  let transfer: Transfer?

  fileprivate init(owner: UUID, initialization: Initialization) {
    adoptionRevision = NativeMemoryAtlasWatcherSource.adoptionRevision
    sourceRevision = 1
    self.owner = owner
    issuer = NativeMemoryAtlasWatcherSource.issuer(owner: owner)
    caseID = NativeMemoryAtlasWatcherSource.caseID(owner: owner)
    original = NativeMemoryAtlasWatcherSource.original(owner: owner)
    station = initialization.dock.station
    resource = NativeMemoryAtlasWatcherSource.resource
    name = NativeMemoryAtlasWatcherSource.name
    node = NativeMemoryAtlasWatcherSource.node
    quantity = 1
    cargoTonnes = NativeMemoryAtlasWatcherSource.cargoTonnes
    heldOnly = true
    loan = true
    returnPolicy = "all"
    packVersion = NativeMemoryAtlasWatcherSource.version
    packDigest = NativeMemoryAtlasWatcherSource.digest
    self.initialization = initialization
    custody = .available
    transfer = nil
  }

  private init(original source: Self, transfer: Transfer) {
    adoptionRevision = source.adoptionRevision
    sourceRevision = transfer.afterSourceRevision
    owner = source.owner
    issuer = source.issuer
    caseID = source.caseID
    original = source.original
    station = source.station
    resource = source.resource
    name = source.name
    node = source.node
    quantity = source.quantity
    cargoTonnes = source.cargoTonnes
    heldOnly = source.heldOnly
    loan = source.loan
    returnPolicy = source.returnPolicy
    packVersion = source.packVersion
    packDigest = source.packDigest
    initialization = source.initialization
    custody = .onLoan
    self.transfer = transfer
  }

  var shapeValid: Bool {
    guard adoptionRevision == NativeMemoryAtlasWatcherSource.adoptionRevision,
      issuer == NativeMemoryAtlasWatcherSource.issuer(owner: owner),
      caseID == NativeMemoryAtlasWatcherSource.caseID(owner: owner),
      original == NativeMemoryAtlasWatcherSource.original(owner: owner),
      station.valid, station.world == owner, station.system == NativeMemoryAtlasWatcherSource.world,
      resource == NativeMemoryAtlasWatcherSource.resource, name == NativeMemoryAtlasWatcherSource.name,
      node == NativeMemoryAtlasWatcherSource.node, quantity == 1,
      cargoTonnes == NativeMemoryAtlasWatcherSource.cargoTonnes, heldOnly, loan, returnPolicy == "all",
      packVersion == NativeMemoryAtlasWatcherSource.version, packDigest == NativeMemoryAtlasWatcherSource.digest,
      initialization.dock.valid, initialization.dock.station == station,
      initialization.dock.commanderOwner == owner,
      initialization.eventSequence > 0, initialization.eventSequence < UInt64(Int64.max),
      initialization.physicalTime.isFinite, (0...1e12).contains(initialization.physicalTime),
      initialization.calendarSeconds.isFinite,
      initialization.calendarSeconds >= initialization.dock.calendarSeconds,
      initialization.calendarSeconds <= 1e12
    else { return false }
    switch custody {
    case .available: return sourceRevision == 1 && transfer == nil
    case .onLoan:
      guard sourceRevision == 2, let transfer,
        transfer.beforeSourceRevision == 1, transfer.afterSourceRevision == 2
      else { return false }
      let facts = transfer.collection.facts
      return facts.source == EquipmentIssueSource(mission: caseID, resource: resource, packDigest: packDigest)
        && facts.issuer == issuer && facts.original == original && facts.dock.station == station
        && facts.dock.sequence >= initialization.dock.sequence
        && facts.eventSequence > initialization.eventSequence
        && facts.physicalTime >= initialization.physicalTime
        && facts.calendarSeconds >= initialization.calendarSeconds
    }
  }

  /// Only the live source transaction can construct this non-Codable transition proof.
  func recording(_ verified: NativeMemoryAtlasWatcherSourceTransfer) throws -> Self {
    guard self == verified.before, shapeValid, custody == .available, sourceRevision == 1 else {
      throw EquipmentIssueError.staleObligation
    }
    let result = Self(original: self, transfer: verified.transfer)
    guard result.shapeValid else { throw EquipmentIssueError.identityMismatch }
    return result
  }

  /// Matching a kernel return is necessary, but does not supply the future final-audit authority.
  func matchesOriginalReturn(_ receipt: EquipmentIssueReceipt) -> Bool {
    custody == .onLoan && receipt.operation == .returned
      && receipt.source == EquipmentIssueSource(mission: caseID, resource: resource, packDigest: packDigest)
      && receipt.originalItems == [original] && receipt.affectedItems == [original]
      && receipt.consumedItems.isEmpty && receipt.displacements.isEmpty
  }
}

struct NativeMemoryAtlasWatcherSourceProjection: Equatable, Sendable {
  let source: NativeMemoryAtlasWatcherSourceRecord
  var owner: UUID { source.owner }
  var issuer: UUID { source.issuer }
  var caseID: UUID { source.caseID }
  var original: UUID { source.original }
  var station: NativeMainStationIdentity { source.station }
  var sourceRevision: UInt64 { source.sourceRevision }
  var custody: NativeMemoryAtlasWatcherSourceRecord.Custody { source.custody }
  var available: Bool { source.custody == .available }
  var owed: Bool { source.custody == .onLoan }
  var initialization: NativeMemoryAtlasWatcherSourceRecord.Initialization { source.initialization }
  var transfer: NativeMemoryAtlasWatcherSourceRecord.Transfer? { source.transfer }
}

extension Game {
  var memoryAtlasWatcherSourceProjection: NativeMemoryAtlasWatcherSourceProjection? {
    guard let source = commander.savedMemoryAtlasWatcherSource,
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander)
    else { return nil }
    return .init(source: source)
  }

  /// Sole production caller: G1's genuine native main-arrival writer candidate, after receipt sealing.
  /// The shared slot, protected node and publisher hooks are reserved but unintegrated in this child.
  mutating func initializeMemoryAtlasWatcherSourceForCurrentNativeArrival() throws {
    guard NativeMemoryAtlasWatcherSourceSave.validateClaims(commander) else {
      throw SaveError.invalidCommander
    }
    if commander.savedMemoryAtlasWatcherSource != nil { return }
    guard systemIdentity == NativeMemoryAtlasWatcherSource.world else { return }
    guard !paused, !isMissionTrial, trialTitle == nil, scriptDurabilityAvailable,
      docked, dockedAtMainStation, currentSystem.name == "Reris",
      NativeMemoryAtlasWatcherSource.canonicalNodeInstalled,
      let owner = commander.equipmentOwnerID, let inventory = commander.equipmentInventory,
      inventory.owner == owner, inventory.activeHull == commander.hullInstanceID,
      let receipt = commander.nativeStations?.currentMainDock,
      let arrival = nativeMainStationArrivalContext(for: receipt.station),
      acceptsNativeMainStationArrivalContext(arrival), arrival.receipt == receipt,
      receipt.commanderOwner == owner, receipt.station.world == owner,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw EquipmentIssueError.staleObligation }
    var candidate = commander
    candidate.scriptState.nextEvent += 1
    candidate.savedMemoryAtlasWatcherSource = .init(owner: owner, initialization: .init(
      dock: receipt, eventSequence: candidate.scriptState.nextEvent,
      physicalTime: candidate.flightSimulation.physicalTime,
      calendarSeconds: candidate.scriptState.calendarSeconds))
    guard NativeMemoryAtlasWatcherSourceSave.validateClaims(candidate) else {
      throw SaveError.invalidCommander
    }
    commander = candidate
  }
}
