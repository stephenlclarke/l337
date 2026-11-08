import Foundation

/// Claims in the original launch's unaltered cargo log. Descriptive contents are not an
/// issued physical log, observation, custody transfer, living crew or rescue acceptance.
struct NativeC03OriginalCrewLogContent: Codable, Equatable, Sendable {
  static let schemaID = "c03-original-launch-cargo-log/1"

  let schema: String
  let serial: UUID
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let launch: UUID
  let master: UUID
  let seals: [NativeC03CustodyRegisterContent.SealEntry]
  let recordedCargo: NativeC03CustodyRegisterContent.Cargo
  let insuranceDeclaration: NativeC03CustodyRegisterContent.Cargo
  let crewWereToldContents: Bool
  let serviceCompartmentOverheatReported: Bool

  /// Candidate document only. The existing actual native paired-source issuer embeds it
  /// once in the original launch registration; generating these bytes issues nothing.
  static func candidate(
    state: borrowing NativeHollowManifestState, fit: NativeC03EvacuationAccommodation
  ) throws -> Self {
    guard state.birth.shapeValid,
      fit.valid(owner: state.birth.input.owner, mission: state.birth.input.mission),
      state.custodyRegister?.recovery != nil,
      state.inspections.count == 2, state.laboratory != nil
    else { throw SaveError.invalidCommander }
    return .init(schema: schemaID,
      serial: ScriptIdentity.uuid("c03-original-launch-cargo-log-v1:\(fit.source)"),
      mission: fit.mission, owner: fit.owner, carrier: fit.originalCarrier, launch: fit.originalLaunch,
      master: state.birth.master.id,
      seals: state.birth.originals.map {
        .init(source: $0.source, hull: $0.hull, seal: $0.seal, imprint: $0.imprint)
      },
      recordedCargo: .sealedRefineryWaste, insuranceDeclaration: .machinery,
      crewWereToldContents: false, serviceCompartmentOverheatReported: true)
  }

  func valid(
    in state: borrowing NativeHollowManifestState, fit: NativeC03EvacuationAccommodation
  ) -> Bool {
    guard shapeValid(fit: fit) else { return false }
    return self == (try? Self.candidate(state: state, fit: fit))
  }

  func shapeValid(fit: NativeC03EvacuationAccommodation) -> Bool {
    schema == Self.schemaID && mission == fit.mission && owner == fit.owner
      && serial == ScriptIdentity.uuid("c03-original-launch-cargo-log-v1:\(fit.source)")
      && carrier == fit.originalCarrier && launch == fit.originalLaunch
      && seals.count == 2 && Set(seals.map(\.seal)).count == 2
      && recordedCargo == .sealedRefineryWaste && insuranceDeclaration == .machinery
      && !crewWereToldContents && serviceCompartmentOverheatReported
  }
}
