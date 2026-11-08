import Foundation

extension BisonColdLoopCandidate {
  /// Proposed quiescent references only; no operating tensor or state adapter.
  struct Delta: Decodable, Sendable {
    let actualOpenStateObserved: Bool
    let baselineSourceSHA256: String
    let conductivityFloorQualified: Bool
    let criteriaWaived: [String]
    let fluidRedistributionRawMoments: FluidRedistribution
    let pressureIntegrityQualified: Bool
    let pumpOrValveFunctionQualified: Bool
    let quietTransitionObserved: Bool
    let actualDiaphragmOrFlowStateQualified: Bool
    let actualObservations: [String]
    let additionalPreparationElectricalJoules: Double
    let additionalPreparationHeatJoules: Double
    let additionalPreparationRejectJoules: Double
    let baseDry: BisonCommissioningCandidateV3.SourceMassState
    let bodyCoreOrContactQualified: Bool
    let dewar: BisonCommissioningCandidateV3.SourceMassState
    let extraWorkingFluid: BisonCommissioningCandidateV3.SourceMassState
    let freeRespiratoryGasCubicMetres: Double
    let generatorSHA256: String
    let hardware: BisonCommissioningCandidateV3.SourceMassState
    let baselineLayoutSHA256: String
    let macroCertificates: [PassageDelta.Certificate]
    let microcellPopulationQualified: Bool
    let newMeteringCapacityKgPerSecond: Double
    let nominalAccumulatorLiquidCubicMetres: Double
    let nominalDiaphragmLocalZMetres: Double
    let nominalLiquidDensityKgPerCubicMetre: Double
    let phaseStates: [BisonBedFeedCandidateV4.Results.PhaseState]
    let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
    let preparation: PassageDelta.Preparation
    let radiatorPatchWallMassKg: Double
    let rigidRuntimeConsumerUpdated: Bool
    let solidPoreDomainCubicMetres: Double
    let sourceDesignSHA256: String
    let status: String
    let wall: BisonBedFeedCandidateV4.Rigid.Wall

    let actualMotionObserved: Bool
    let baselineConnectedFluidRedistributionRawMoments: FluidRedistribution
    let baselineConnectedSourceSHA256: String
    let configurationReferences: [MechanismConfiguration]
    let geometryIsProposed: Bool
    let geometryMomentConvention: String
    let mechanismMaterialOrClearanceQualified: Bool
    let newInternalVoidContentsObserved: Bool
    let nominalJointClearances: [MechanismClearance]
    let proposalLimits: [String]
    let proposedAssemblies: [MechanismAssembly]
    let proposedFluidRedistributionRawMoments: FluidRedistribution
    let referenceGateAngleRadians: Double
    let referencePumpAngleRadians: Double
    let torqueFlowOrActuatorPerformanceQualified: Bool
  }
}
