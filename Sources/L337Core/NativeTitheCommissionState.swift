import Foundation

/// Current native case identity, pinned to the installed original fourteen-stage pack.
/// Content identity cannot supply Voss's desk or permission to create a commission.
enum NativeTitheCommissionDefinition {
  static let stateID = NativeTitheOriginalReward.source + "/tithe-of-worlds"
  static let version = "1.0.0"
  static let digest = "78b469d0b368de7ab71a5bcd25926472a15a266766046cd5559ccd1743456a37"
  static let acceptReceipt = "tithe-commission-accept"
  static let briefing = [NativeTitheCommissionMark.warning, NativeTitheOriginalStage.accept.dialogue]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("tithe-original-commission-v1:\(owner)")
  }
  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == stateID { return true }
    if instance.digest == digest { return true }
    return instance.savedTitheCommission != nil
  }
}

/// Archive DATA only. A syntactically valid record never constructs a live desk contact.
struct NativeTitheCommissionDeskRecord: Codable, Sendable, Equatable {
  let source: UUID
  let operation: UUID
  let owner: UUID
  let station: NativeMainStationIdentity
  let role: String

  var shapeValid: Bool {
    station.valid && station.world == owner
      && station.system == NativeTitheOriginalStage.accept.world
      && role == "VOSS / HEARTH COMPACT COMMISSION"
  }
}

struct NativeTitheCommissionAcceptanceFacts: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let desk: NativeTitheCommissionDeskRecord
  let visited: [NativeMainStationObservation]
  let firstSale: UUID
  let secondSale: UUID
  let sequence: UInt64
  let physicalTime: Double
  let calendarSeconds: Double

  var shapeValid: Bool {
    mission == NativeTitheCommissionDefinition.mission(owner: owner)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativeTitheOriginalStage.accept.world
      && desk.shapeValid && desk.owner == owner && desk.station == dock.station
      && firstSale != secondSale
      && visited.count == NativeTitheCommissionHistory.requiredDistinctSystems
      && Set(visited.map { $0.station.system }).count == visited.count
      && Set(visited.map { $0.actor.visit }).count == visited.count
      && visited.allSatisfy({ $0.valid && $0.station.world == owner
        && $0.actor.visit <= dock.actor.visit && $0.calendarSeconds <= calendarSeconds })
      && visited.contains(where: { $0.station == dock.station && $0.actor == dock.actor })
      && sequence > 0 && sequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && (dock.calendarSeconds...1e12).contains(calendarSeconds)
  }
}

/// This immutable commander entitlement belongs to its one explicit acceptance operation.
/// It grants no combat benefit and carries no claim that livery has been rendered.
struct NativeTitheCommissionMarkEntitlement: Codable, Sendable, Equatable {
  let owner: UUID
  let mission: UUID
  let acceptance: UUID
  let id: String
  let receipt: String
  let permanent: Bool

  fileprivate init(facts: NativeTitheCommissionAcceptanceFacts, acceptance: UUID) {
    owner = facts.owner
    mission = facts.mission
    self.acceptance = acceptance
    id = NativeTitheCommissionMark.id
    receipt = NativeTitheCommissionMark.receipt
    permanent = true
  }
  func valid(facts: NativeTitheCommissionAcceptanceFacts, operation: UUID) -> Bool {
    owner == facts.owner && mission == facts.mission && acceptance == operation
      && id == NativeTitheCommissionMark.id && receipt == NativeTitheCommissionMark.receipt
      && permanent
  }
}

/// Case and mark are one immutable leaf: neither can be published independently.
final class NativeTitheCommissionState: Codable, Sendable, Equatable {
  let acceptance: NativeTitheCommissionAcceptanceFacts
  let operation: UUID
  let mark: NativeTitheCommissionMarkEntitlement

  init(acceptance: NativeTitheCommissionAcceptanceFacts) throws {
    guard acceptance.shapeValid else { throw SaveError.invalidCommander }
    self.acceptance = acceptance
    operation = try Self.identity(acceptance)
    mark = .init(facts: acceptance, acceptance: operation)
  }
  static func identity(_ facts: NativeTitheCommissionAcceptanceFacts) throws -> UUID {
    ScriptIdentity.uuid("tithe-explicit-permanent-commission-v1:\(try NativeFlightReception.hash(facts))")
  }
  var shapeValid: Bool {
    acceptance.shapeValid && operation == (try? Self.identity(acceptance))
      && mark.valid(facts: acceptance, operation: operation)
  }
  static func == (lhs: NativeTitheCommissionState, rhs: NativeTitheCommissionState) -> Bool {
    lhs.acceptance == rhs.acceptance && lhs.operation == rhs.operation && lhs.mark == rhs.mark
  }
}

extension NativeTitheCommissionState {
  /// Pure candidate assembly. The native desk and commander validator still own issuance.
  func openingInstance() throws -> ScriptInstance {
    guard shapeValid else { throw SaveError.invalidCommander }
    var instance = ScriptInstance(id: acceptance.mission,
      definition: NativeTitheCommissionDefinition.stateID,
      version: NativeTitheCommissionDefinition.version, digest: NativeTitheCommissionDefinition.digest)
    instance.savedTitheCommission = self
    instance.receipts = [NativeTitheCommissionDefinition.acceptReceipt]
    instance.milestones = [0]
    instance.journal = NativeTitheCommissionDefinition.briefing
    instance.revision = 1
    instance.acknowledge(acceptance.sequence)
    return instance
  }
}
