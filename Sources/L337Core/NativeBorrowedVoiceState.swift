import Foundation

/// Saved historical values only. Decoding these cannot authorize a contact or item issue.
struct NativeBorrowedVoiceAcceptanceFacts: Codable, Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let visited: [NativeMainStationObservation]
  let eventSequence: UInt64
  let physicalTime: Double
  let calendarSeconds: Double

  var shapeValid: Bool {
    mission == NativeBorrowedVoiceDefinition.mission(owner: owner)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativeBorrowedVoiceDefinition.issuer
      && visited.count == NativeBorrowedVoiceTravelHistory.minimumDistinctSystems
      && Set(visited.map { $0.station.system }).count == visited.count
      && Set(visited.map { $0.actor.visit }).count == visited.count
      && visited.allSatisfy({ $0.valid && $0.station.world == owner
        && $0.actor.visit <= dock.actor.visit && $0.calendarSeconds <= calendarSeconds })
      && visited.contains(where: { $0.station == dock.station && $0.actor == dock.actor })
      && eventSequence > 0 && eventSequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && calendarSeconds >= dock.calendarSeconds
      && calendarSeconds <= 1e12
  }
}

struct NativeBorrowedVoiceState: Codable, Equatable, Sendable {
  let acceptance: NativeBorrowedVoiceAcceptanceFacts
  let acceptanceOperation: UUID

  init(acceptance: NativeBorrowedVoiceAcceptanceFacts) throws {
    guard acceptance.shapeValid else { throw SaveError.invalidCommander }
    self.acceptance = acceptance
    acceptanceOperation = try Self.identity(acceptance)
  }

  static func identity(_ facts: NativeBorrowedVoiceAcceptanceFacts) throws -> UUID {
    ScriptIdentity.uuid("borrowed-voice-acceptance-v1:\(try NativeFlightReception.hash(facts))")
  }

  var shapeValid: Bool {
    acceptance.shapeValid && acceptanceOperation == (try? Self.identity(acceptance))
  }
}
