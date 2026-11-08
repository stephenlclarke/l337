import Foundation

/// Saved historical values only. Decoding these cannot authorize a contact or item issue.
struct NativeMemoryAtlasAcceptanceFacts: Codable, Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let ordinaryTrade: UUID
  let eventSequence: UInt64
  let physicalTime: Double
  let calendarSeconds: Double

  var shapeValid: Bool {
    mission == NativeMemoryAtlasDefinition.mission(owner: owner)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativeMemoryAtlasDefinition.issuer
      && eventSequence > 0 && eventSequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && calendarSeconds >= dock.calendarSeconds
      && calendarSeconds <= 1e12
  }
}

struct NativeMemoryAtlasReferenceCollection: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let issueCommand: UUID
    let source: EquipmentIssueSource
    let issuer: UUID
    let original: UUID
    let carrier: UUID
    let dock: NativeMainStationDockReceipt
    let beforeInventoryRevision: UInt64
    let afterInventoryRevision: UInt64
    let beforeCaseRevision: UInt64
    let afterCaseRevision: UInt64
    let eventSequence: UInt64
    let beforeCargoTonnes: Int
    let afterCargoTonnes: Int
    let capacityTonnes: Int
    let physicalTime: Double
    let calendarSeconds: Double

    func shapeValid(acceptance: NativeMemoryAtlasAcceptanceFacts) -> Bool {
      acceptance.shapeValid
        && source == EquipmentIssueSource(
          mission: acceptance.mission, resource: NativeMemoryAtlasReferenceDefinition.logicalResource,
          packDigest: NativeMemoryAtlasDefinition.digest)
        && issuer == NativeMemoryAtlasDefinition.referenceIssuer(owner: acceptance.owner)
        && original == NativeMemoryAtlasDefinition.referenceSerial(mission: acceptance.mission)
        && dock.valid && dock.commanderOwner == acceptance.owner
        && dock.station == acceptance.dock.station && dock.sequence >= acceptance.dock.sequence
        && beforeInventoryRevision >= acceptance.inventoryRevision
        && beforeInventoryRevision < UInt64(Int64.max) - 1
        && afterInventoryRevision == beforeInventoryRevision + 1
        && beforeCaseRevision < UInt64(Int64.max) - 1
        && afterCaseRevision == beforeCaseRevision + 1
        && eventSequence > acceptance.eventSequence && eventSequence < UInt64(Int64.max)
        && (0...Int.max / 17).contains(beforeCargoTonnes)
        && afterCargoTonnes == beforeCargoTonnes + NativeMemoryAtlasReferenceDefinition.cargoTonnes
        && capacityTonnes >= afterCargoTonnes && capacityTonnes <= Int.max / 17
        && physicalTime.isFinite && physicalTime >= acceptance.physicalTime && physicalTime <= 1e12
        && calendarSeconds.isFinite && calendarSeconds >= acceptance.calendarSeconds
        && calendarSeconds >= dock.calendarSeconds && calendarSeconds <= 1e12
    }
  }

  let operation: UUID
  let facts: Facts

  init(actual: EquipmentIssueReceipt, facts: Facts, acceptance: NativeMemoryAtlasAcceptanceFacts) throws {
    guard facts.shapeValid(acceptance: acceptance), actual.operation == .issued,
      actual.command == facts.issueCommand, actual.source == facts.source,
      actual.originalItems == [facts.original], actual.affectedItems == [facts.original],
      actual.consumedItems.isEmpty, actual.displacements.isEmpty
    else { throw EquipmentIssueError.identityMismatch }
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func identity(_ facts: Facts) throws -> UUID {
    ScriptIdentity.uuid("c25-original-reference-collection-v1:\(try NativeFlightReception.hash(facts))")
  }

  func shapeValid(acceptance: NativeMemoryAtlasAcceptanceFacts) -> Bool {
    facts.shapeValid(acceptance: acceptance) && operation == (try? Self.identity(facts))
  }
}

struct NativeMemoryAtlasState: Codable, Equatable, Sendable {
  let acceptance: NativeMemoryAtlasAcceptanceFacts
  let acceptanceOperation: UUID
  var collection: NativeMemoryAtlasReferenceCollection?

  init(acceptance: NativeMemoryAtlasAcceptanceFacts) throws {
    guard acceptance.shapeValid else { throw SaveError.invalidCommander }
    self.acceptance = acceptance
    acceptanceOperation = try Self.identity(acceptance)
  }

  static func identity(_ facts: NativeMemoryAtlasAcceptanceFacts) throws -> UUID {
    ScriptIdentity.uuid("c25-original-memory-atlas-accept-v1:\(try NativeFlightReception.hash(facts))")
  }

  var shapeValid: Bool {
    acceptance.shapeValid && acceptanceOperation == (try? Self.identity(acceptance))
      && (collection?.shapeValid(acceptance: acceptance) ?? true)
  }
}
