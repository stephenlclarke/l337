import Foundation

/// Contents of the original in-story register. These document claims are not physical
/// shipment, person-life, archive issuance, custody, observation or recovery authority.
struct NativeC03CustodyRegisterContent: Codable, Equatable, Sendable {
  struct SealEntry: Codable, Equatable, Sendable {
    let source: UUID
    let hull: UUID
    let seal: UUID
    let imprint: UUID
  }

  enum Cargo: String, Codable, Sendable {
    case sealedRefineryWaste = "sealed-refinery-waste"
    case machinery
  }

  static let schemaID = "c03-original-custody-register/1"
  static let target = "custody-register"
  static let dialogue =
    "The register lists sealed refinery waste. The machinery manifests were insurance cover for its transport. The carrier's crew were not told what their holds contained."

  let schema: String
  let serial: UUID
  let mission: UUID
  let owner: UUID
  let master: UUID
  let seals: [SealEntry]
  let wakeObservations: [UUID]
  let recordedCargo: Cargo
  let insuranceDeclaration: Cargo
  let crewWereToldContents: Bool

  /// Candidate content for the future real archive producer. This issues no archive or data.
  static func candidate(state: borrowing NativeHollowManifestState) throws -> Self {
    guard state.birth.shapeValid, state.inspections.count == 2, state.laboratory != nil,
      let trail = state.wakeTrail, trail.observations.count == 3
    else {
      throw SaveError.invalidCommander
    }
    return .init(
      schema: schemaID,
      serial: ScriptIdentity.uuid("c03-original-custody-register-v1:\(state.birth.input.mission):\(trail.origin.source)"),
      mission: state.birth.input.mission, owner: state.birth.input.owner,
      master: state.birth.master.id,
      seals: state.birth.originals.map {
        .init(source: $0.source, hull: $0.hull, seal: $0.seal, imprint: $0.imprint)
      },
      wakeObservations: trail.observations.map(\.operation),
      recordedCargo: .sealedRefineryWaste, insuranceDeclaration: .machinery,
      crewWereToldContents: false)
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    guard seals.count == 2, wakeObservations.count == 3 else { return false }
    return self == (try? Self.candidate(state: state))
  }
}
