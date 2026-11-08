import Foundation

/// The existing unnamed source person, never a hiring or live inspection capability.
public struct NativeUtilityEngineerIdentity: Hashable, Codable, Sendable {
  let owner: UUID
  var key: String { "field-relief-engineer-v1:\(owner)" }
  var id: UUID { ScriptIdentity.uuid(key) }
  var station: NativeStationIdentity { OriginalStationSite.remoteUtility.identity(world: owner) }

  private enum CodingKeys: String, CodingKey { case owner }
  init(owner: UUID) { self.owner = owner }
  public init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["owner"])
    owner = try decoder.container(keyedBy: CodingKeys.self).decode(UUID.self, forKey: .owner)
  }
}

struct NativeUtilityEngineerRegistration: Codable, Equatable, Sendable {
  let operation: UUID
  let identity: NativeUtilityEngineerIdentity
  let station: NativeStationIdentity
  let sourceVersion: String
  let binding: NativeStationBinding
  let spawn: SpawnIdentity
  let physicalTime: Double
  let epoch: UUID
}

/// The same operation is the ordinary utility reception, not a second reward or debit.
struct NativeUtilityEngineerInspection: Codable, Equatable, Sendable {
  let operation: UUID
  let consignment: UUID
  let installation: NativeUtilityInstallation
  let dock: NativeStationDockReceipt
  let utilityRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
}

/// A lost station leaves this person's outcome unobserved. It proves no biological death.
struct NativeUtilityEngineerCasualty: Codable, Equatable, Sendable {
  let operation: UUID
  let binding: NativeStationBinding
  let priorLifecycleRevision: UInt64
  let tombstone: NativeStationTombstone
  let incident: UInt64
  let origin: AttackOrigin?
  let startTime: Double
  let usedDuration: Double
  let physicalTime: Double
  let preNextIncident: UInt64
  let postNextIncident: UInt64
  let epoch: UUID
}

enum NativeUtilityEngineerLocation: Equatable, Sendable {
  case residentAtSource(NativeStationIdentity)
  case unobservedAfterStationLoss(NativeStationIdentity)
}

/// Closed history in the existing custody owner. Decoding this value authorizes no action.
struct NativeUtilityEngineerState: Codable, Equatable, Sendable {
  let registration: NativeUtilityEngineerRegistration
  var inspections: [NativeUtilityEngineerInspection]
  var casualty: NativeUtilityEngineerCasualty?

  var recordedLocation: NativeUtilityEngineerLocation {
    casualty == nil ? .residentAtSource(registration.station)
      : .unobservedAfterStationLoss(registration.station)
  }

  init(registration: NativeUtilityEngineerRegistration,
    inspections: [NativeUtilityEngineerInspection] = [],
    casualty: NativeUtilityEngineerCasualty? = nil)
  {
    self.registration = registration
    self.inspections = inspections
    self.casualty = casualty
  }

  private enum CodingKeys: String, CodingKey { case registration, inspections, casualty }
  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["registration", "inspections"], optional: ["casualty"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    registration = try values.decode(NativeUtilityEngineerRegistration.self, forKey: .registration)
    inspections = try NativeUtilityCoding.array(
      NativeUtilityEngineerInspection.self, key: .inspections, container: values, limit: 2)
    casualty = try values.decodeIfPresent(NativeUtilityEngineerCasualty.self, forKey: .casualty)
    guard NativeUtilityEngineerSave.shapeValid(self) else { throw SaveError.invalidCommander }
  }
}

enum NativeUtilityEngineer {
  // A defensive current-leaf storage estimate, not a gameplay availability rule.
  static let maximumSourceBytes = 1_048_576

  static func birthOperation(owner: UUID) -> UUID {
    ScriptIdentity.uuid("field-relief-engineer-birth-v1:\(owner)")
  }

  static func casualtyOperation(
    owner: UUID, binding: NativeStationBinding, incident: UInt64
  ) -> UUID {
    ScriptIdentity.uuid(
      "field-relief-engineer-loss-v1:\(owner):\(binding.actor.visit):"
        + "\(binding.actor.entity):\(incident)")
  }
}
