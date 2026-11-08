import Foundation

/// The mission retains this reciprocal reference, never a second original-person roster.
struct NativeC03CrewSourceReference: Codable, Sendable, Equatable {
  let source: UUID
  let registration: UUID
  let sequence: UInt64

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    guard let recovery = state.custodyRegister?.recovery,
      source == ScriptIdentity.uuid(NativeC03CrewIdentity.sourceKey(
        owner: state.birth.input.owner, mission: state.birth.input.mission)),
      sequence > recovery.facts.sequence, sequence < state.nextSourceSequence
    else { return false }
    return true
  }
}

/// Retained facts for the dedicated source inside NativePeopleCustodyState. This is not a
/// second people ledger: original addresses come from the one source fit, current occupancy
/// from its real hardware/operating places, and terminal custody from common transfers.
/// None of these decoded facts is a birth, life, native-admission or provider permission.
struct NativeC03CrewSourceState: Codable, Sendable, Equatable {
  struct Unit: Codable, Sendable, Equatable {
    let originalHull: UUID
    let logicalActor: UUID
    let birthActor: ActorIdentity
    let birthSpawn: SpawnIdentity
    let rootGeometry: String
  }

  struct Registration: Codable, Sendable, Equatable {
    let operation: UUID
    let accommodation: NativeC03EvacuationAccommodation
    let caseSourceSequence: UInt64
    let custodyRevision: UInt64
    let registerTransfer: UUID
    let originalKit: UUID
    let crewLog: NativeC03OriginalCrewLogContent
    let carrier: Unit
    let launch: Unit
    let anchors: SystemAnchors
    let reference: ShipPose
    let physicalTime: Double
    let epoch: UUID
  }

  struct OperatingPlace: Codable, Sendable, Equatable {
    let index: Int
    let person: NativeC03CrewIdentity
  }

  /// Latest actual native admission per original hull. A selected cohort's slot is recorded
  /// by the issuer, never inferred from a permanent role or a small integer in a save.
  struct NativeBinding: Codable, Sendable, Equatable {
    let launch: Bool
    let generation: UInt64
    let actor: ActorIdentity
    let spawn: SpawnIdentity
    let selectedOrdinal: UInt16
    let cohortCount: UInt16
    let cohortFirstEntity: UInt64
    let physicalTime: Double
  }

  /// Only the actual native launch-death observer can publish this with a common loss
  /// transfer. A player's death/escape, cull, missing body or source document cannot do so.
  struct LaunchLoss: Codable, Sendable, Equatable {
    let transfer: UUID
    let actor: ActorIdentity
    let spawn: SpawnIdentity
    let incident: UInt64
    let origin: AttackOrigin?
    let physicalTime: Double
    let epoch: UUID
  }

  let registration: Registration
  var nativeBindings: [NativeBinding]
  var hardware: ShipAccommodation
  var operatingPlaces: [OperatingPlace]
  var crewLogHolder: NativeC03CrewLogHolder
  var crewLogAccess: NativeC03CrewLogAccessReceipt?
  var loss: LaunchLoss?

  var owner: UUID { registration.accommodation.owner }
  var mission: UUID { registration.accommodation.mission }
  var source: UUID { registration.accommodation.source }
  var missionReference: NativeC03CrewSourceReference {
    .init(source: source, registration: registration.operation,
      sequence: registration.caseSourceSequence)
  }
  var references: [NativePersonReference] {
    registration.accommodation.assignments.map { .hollowManifestCrew($0.person) }
  }

  static let encounter = "c03-original-evacuation-source"
  static let carrierTarget = "damaged-carrier"
  static let launchTarget = "evacuation-launch"

  static func logicalActor(mission: UUID, launch: Bool) -> UUID {
    let target = launch ? launchTarget : carrierTarget
    return ScriptIdentity.uuid(
      "script-actor-v2:\(mission):\(NativeHollowManifestCommission.digest):\(encounter):\(target)")
  }

  static func registrationOperation(
    source: UUID, carrier: ActorIdentity, launch: ActorIdentity, spawn: SpawnIdentity
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "c03-original-crew-birth-v1:\(source):\(try NativeFlightReception.hash(carrier)):\(try NativeFlightReception.hash(launch)):\(try NativeFlightReception.hash(spawn))")
  }

  /// Structural occupancy joins only. Actual retained source, current native hull/life and
  /// common transfer validation must separately authenticate every one of the six originals.
  var occupancyShapeValid: Bool {
    let fit = registration.accommodation
    guard fit.valid(owner: owner, mission: mission), hardware.valid,
      hardware.ownedCabins == [fit.cabin], hardware.fitted == [fit.cabin.id],
      hardware.people.isEmpty, hardware.ownedBerths.count == fit.berths.count
    else { return false }
    if loss != nil {
      return operatingPlaces.isEmpty && hardware.ownedBerths == fit.berths
    }
    guard operatingPlaces.count == NativeC03EvacuationAccommodation.operatingCount,
      operatingPlaces.map(\.index) == [0, 1],
      operatingPlaces.map(\.person) == Array(fit.assignments.prefix(2).map(\.person))
    else { return false }
    for (index, place) in hardware.ownedBerths.enumerated() {
      var expected = fit.berths[index]
      expected.use = .nativePerson(.hollowManifestCrew(fit.assignments[index + 2].person))
      guard place == expected else { return false }
    }
    return true
  }
}
