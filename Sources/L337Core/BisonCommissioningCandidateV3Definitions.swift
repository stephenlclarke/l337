import Foundation

extension BisonCommissioningCandidateV3 {
  struct Header: Decodable, Sendable {
    struct Artifact: Decodable, Sendable {
      let path: String
      let bytes: Int
      let sha256: String
    }
    let id: String
    let status: String
    let baseBisonSourceSHA256: String
    let baseCommissioningSHA256: String
    let acceptedIncrement: Int
    let actualObservations: [String]
    let qualifiedBirth: Bool
    let sharedRuntimeOrShippingResourceChanges: Bool
    let supersedesAuthoredCommissioningInputsNotRecoveredHumanRequirements: Bool
    let artifacts: [Artifact]
    let reviewCorrection: String
    let unaffectedBaseProofCommit: String
  }
  struct Inputs: Decodable, Sendable {
    struct File: Decodable, Sendable {
      let path: String
      let bytes: Int
      let sha256: String
      let source: String
    }
    let files: [File]
    let newSourceIsNotObservedCommissioning: Bool
    let scope: String
  }
  struct CarrierReviewInputs: Decodable, Sendable {
    let baseCommit: String
    let files: [Inputs.File]
    let scope: String
  }
  struct Envelope: Decodable, Sendable {
    let id: String
    let massKg: Double
    let centreMetres: [Double]
    let dimensionsMetres: [Double]
  }
  struct Material: Decodable, Sendable {
    struct Certificate: Decodable, Sendable {
      let component: String
      let minimumCornerDistanceMetres: Double
      let noBoundaryCrossing: Bool
    }
    let status: String
    let compiler: Bool
    let native: Bool
    let actualSealOrCommissioningObserved: Bool
    let newAssumptions: Bool
    let canonicalDryMassAndMomentsMatched: Bool
    let exactInnerFreeSpaceIsOuterMinusCertifiedDisjointBoxes: Bool
    let unchangedOuterVertices: Bool
    let unchangedCollisionFaces: Bool
    let outerSourceSHA256: String
    let connectedFreeGasVolumeCubicMetres: Double
    let innerHomothety: Double
    let innerVolume: Double
    let outerVolume: Double
    let pressureWallVolume: Double
    let innerVerticesMetres: [[Double]]
    let innerFaces: [[Int]]
    let finiteHardware: [Envelope]
    let additionalTankEnvelope: Envelope
    let existingIsolatorEnvelope: Envelope
    let body: Envelope
    let disjointInsideCertificates: [Certificate]
  }
  struct MomentFit: Decodable, Sendable {
    let status: String
    let actualMaterialQualificationObserved: Bool
    let canonicalStockFacetDensitiesPreserved: Bool
    let wallMaterialDistributionIsNewAssumption: Bool
    let dryMassKg: Double
    let unchangedDryCentreMetres: [Double]
    let unchangedDryInertiaAboutCentreKgM2: [Double]
    let wallCellDensityKgPerCubicMetre: [Double]
    let wallCellMassKg: [Double]
    let finiteHardwareMoments: [Double]
    let finiteWallMoments: [Double]
    let minimumDensityKgPerCubicMetre: Double
    let maximumDensityKgPerCubicMetre: Double
    let residualMassFirstInertia: [Double]
  }
  /// Authored offline source state. Deliberately has no runtime Mass conversion.
  struct SourceMassState: Decodable, Sendable {
    let id: String
    let massKg: Double
    let centreMetres: [Double]
    let inertiaAboutCentreOfMassKgM2: [Double]
  }
  struct PhysicalDelta: Decodable, Sendable {
    let status: String
    let actualObservations: [String]
    let canonicalDryAggregatePreserved: Bool
    let canonicalOuterGeometryPreserved: Bool
    let canonicalWallFacetDensityDistributionPreserved: Bool
    let newFiniteGasMassDistribution: Bool
    let variableInternalMassStateNotProvedByInstantaneousContactCases: Bool
    let freeGasVolumeCubicMetres: Double
    let coldCircuitPhaseAndFlowDetails: String
    let portableStates: [SourceMassState]
  }
  struct Radiator: Decodable, Sendable {
    struct Patch: Decodable, Sendable {
      let sourceFaceIndex: Int
      let materialOwner: String
      let unchangedSourceFaceVertices: [Int]
      let verticesMetres: [[Double]]
      let areaSquareMetres: Double
    }
    let status: String
    let requestedSquareMetres: Double
    let availableForecapSquareMetres: Double
    let matchingFiniteWallPatchMassKg: Double
    let patches: [Patch]
    let rendererAndCollisionUnchanged: Bool
    let thermalMaterialOrViewQualified: Bool
  }
  struct ContactReference: Decodable, Sendable {
    struct Case: Decodable, Sendable {
      let state: String
      let q: Double
      let rotation: [[Double]]
      let lambdaNewtons: [Double]
      let rank: Int
    }
    let scope: String
    let actualObservations: [String]
    let paidGrossForceNewtons: Double
    let paidWorkJoules: Double
    let cases: [Case]
  }
  struct FiniteOperations: Decodable, Sendable {
    struct Requirement: Decodable, Sendable {
      let operation: String
      let inputs: String
      let actualRequirement: String
    }
    let status: String
    let owner: String
    let acceptedIncrement: Int
    let actualOperationsPerformed: [String]
    let sharedRuntimeHunksChanged: Bool
    let preparationElectricalOrigin: String
    let requiredOperations: [Requirement]
  }
  struct AdoptedCriteria: Decodable, Sendable {
    let actualObservations: [String]
    let canonicalSourceFrozen: Bool
    let carrierTemperatureIsNewAssumption: String
    let portableTemperatureIsNewAssumption: String
    let newMaterialAndPhysiologicalQualification: String
    let hotDesignAllowanceWatts: Double
    let maximumOperationalCO2CaptureKg: Double
    let minimumCaOConversionFraction: Double
    let minimumNearDepletionUptakeKgPerSecond: Double
    let minimumSixHourCO2UptakeKg: Double
    let portableMassMaximumKg: Double
    let portableNoVentOrAddedPaidPairs: Bool
    let pressureRangePascals: [Double]
    let carrierFixedElectricalServiceHeatJoules: Double
    let carrierResidualDumpRequiredRatingWattsPerCell: Double
    let carrierResidualUsefulElectricalDifferenceDestination: String
    let carrierTotalServiceHullHeatJoules: Double
  }
}
