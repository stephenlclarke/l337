import Foundation

extension BisonColdLoopCandidate {
  struct MechanismInputs: Decodable, Sendable {
    let actualObservations: [String]
    let baselineCommit: String
    let baselineStageManifestSHA256: String
    let captureCommit: String
    let designNotesAreCommentaryNotParsedParameterFallback: Bool
    let designNotesSHA256: String
    let files: [BisonCommissioningCandidateV3.Header.Artifact]
    let firstCriteriaSHA256: String
  }
  struct MechanismCriteria: Decodable, Sendable {
    let actualObservations: [String]
    let captureBase: String
    let designChoices: [String]
    let nativeCompilerRenderer: Bool
    let physicalBase: String
    let qualificationOpen: [String]
    let scope: String
    let sourceBase: String
    let success: [String]
    let unchanged: [String]
  }
  struct MechanismExactDelta: Decodable, Sendable {
    let acceptedPlayableIncrement: Int
    let actualObservations: [String]
    let apparatusMaterialTorqueFlowPressureThermalQuietQualified: Bool
    let baselineConnectedSourceSHA256: String
    let canonicalDryCentreDeltaMetres: [Double]
    let canonicalDryInertiaMaximumAbsoluteDeltaKgM2: Double
    let canonicalDryMassKg: Double
    let cavityLengthsMetres: [Double]
    let changedQuiescentFourMaterialReferences: Int
    let finiteMaterialPiecesIncludingResidualHousings: Int
    let firstCriteriaSHA256: String
    let gasOrVacuumContentsObserved: Bool
    let generatorSHA256: String
    let hotRadiatorPatchMassKg: Double
    let liquidPhysicalMomentDelta: FluidRedistribution
    let mechanismSourceSHA256: String
    let nominalClearances: [MechanismClearance]
    let nominalWetMassKg: [Double]
    let originalInterfaces: [Interfaces]
    let outerEnvelopesExact: Bool
    let paidAssemblyMassKg: [Double]
    let paidFluidVolumeCubicMetres: [Double]
    let positiveWallDensityRangeKgPerCubicMetre: [Double]
    let proposedResidualHousingDensitiesKgPerCubicMetre: [Double]
    let retainedFields: [String]
    let runtimeShippingNativeCompilerRendererUpdated: Bool
    let sealedDryActuatorVoidCubicMetres: Double

    struct Interfaces: Decodable, Sendable {
      let id: String
      let interfaces: [ConnectedAssembly.Interface]
    }
  }
}
