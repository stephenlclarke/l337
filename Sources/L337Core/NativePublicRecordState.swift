import Foundation

/// Saved historical values only. Decoding these cannot authorize a contact or item issue.
struct NativePublicRecordAcceptanceFacts: Codable, Equatable, Sendable {
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
    mission == NativePublicRecordDefinition.mission(owner: owner)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativePublicRecordDefinition.issuer
      && eventSequence > 0 && eventSequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && calendarSeconds >= dock.calendarSeconds
      && calendarSeconds <= 1e12
  }
}

struct NativePublicRecordState: Codable, Equatable, Sendable {
  let acceptance: NativePublicRecordAcceptanceFacts
  let acceptanceOperation: UUID

  init(acceptance: NativePublicRecordAcceptanceFacts) throws {
    guard acceptance.shapeValid else { throw SaveError.invalidCommander }
    self.acceptance = acceptance
    acceptanceOperation = try Self.identity(acceptance)
  }

  static func identity(_ facts: NativePublicRecordAcceptanceFacts) throws -> UUID {
    ScriptIdentity.uuid("public-record-acceptance-v1:\(try NativeFlightReception.hash(facts))")
  }

  var shapeValid: Bool {
    acceptance.shapeValid && acceptanceOperation == (try? Self.identity(acceptance))
  }
}
