import Foundation

/// Saved historical values only. Decoding these cannot authorize a contact or item issue.
struct NativeQuietChoirAcceptanceFacts: Codable, Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let visited: [NativeMainStationObservation]
  let identification: FleetDiscoveryEvidence
  let eventSequence: UInt64
  let physicalTime: Double
  let calendarSeconds: Double

  var shapeValid: Bool {
    mission == NativeQuietChoirDefinition.mission(owner: owner)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativeQuietChoirDefinition.issuer
      && visited.count == NativeQuietChoirTravelHistory.minimumDistinctSystems
      && Set(visited.map { $0.station.system }).count == visited.count
      && Set(visited.map { $0.actor.visit }).count == visited.count
      && visited.allSatisfy({ $0.valid && $0.station.world == owner
        && $0.actor.visit <= dock.actor.visit && $0.calendarSeconds <= calendarSeconds })
      && visited.contains(where: { $0.station == dock.station && $0.actor == dock.actor })
      && NativeQuietChoirTravelHistory.qualifies(identification, owner: owner)
      && identification.physicalTime <= physicalTime
      && identification.actor.visit <= dock.actor.visit
      && eventSequence > 0 && eventSequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && calendarSeconds >= dock.calendarSeconds
      && calendarSeconds <= 1e12
  }
}

struct NativeQuietChoirState: Codable, Equatable, Sendable {
  let acceptance: NativeQuietChoirAcceptanceFacts
  let acceptanceOperation: UUID

  init(acceptance: NativeQuietChoirAcceptanceFacts) throws {
    guard acceptance.shapeValid else { throw SaveError.invalidCommander }
    self.acceptance = acceptance
    acceptanceOperation = try Self.identity(acceptance)
  }

  static func identity(_ facts: NativeQuietChoirAcceptanceFacts) throws -> UUID {
    ScriptIdentity.uuid("quiet-choir-acceptance-v1:\(try NativeFlightReception.hash(facts))")
  }

  var shapeValid: Bool {
    acceptance.shapeValid && acceptanceOperation == (try? Self.identity(acceptance))
  }
}
