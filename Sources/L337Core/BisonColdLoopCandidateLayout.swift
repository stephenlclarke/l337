import Foundation

extension BisonColdLoopCandidate {
  /// Immutable 8bf layout context. Current pump/valve distributions are supplied only by
  /// delta.proposedAssemblies, never these old whole-box pieces.
  struct Layout: Decodable, Sendable {
    struct Geometry: Decodable, Sendable {
      struct CentreBox: Decodable, Sendable {
        let centreMetres: [Double]
        let dimensionsMetres: [Double]
      }
      struct MatrixCell: Decodable, Sendable {
        let cellVolumeCubicMetres: Double
        let gapLayerCounts: [Int]
        let pitchMetres: Double
        let strutMetres: Double
      }
      let accumulatorBranch: [[Double]]
      let adapters: [BisonBedFeedCandidateV4.Results.Layout.Box]
      let bodyChannels: [CentreBox]
      let bodyHeaderBottomPorts: [BisonBedFeedCandidateV4.Results.Layout.Box]
      let bodyHeaders: [BisonBedFeedCandidateV4.Results.Layout.Box]
      let bodyPanel: CentreBox
      let bodyVerticalPorts: [BisonBedFeedCandidateV4.Results.Layout.Box]
      let bypass: [[Double]]
      let coldGasCollector: CentreBox
      let coldSlots: [BisonBedFeedCandidateV4.Results.Layout.Box]
      let mainReturn: [[Double]]
      let mainSupply: [[Double]]
      let matrixCell: MatrixCell
      let plateCentresZMetres: [Double]
      let tieColumnsPerPlate: Int
      let ventColumns: [BisonBedFeedCandidateV4.Results.Layout.Box]
    }
    struct Piece: Decodable, Sendable {
      let allocation: String
      let centreMetres: [Double]
      let id: String
      let inertiaAboutCentreOfMassKgM2: [Double]
      let massKg: Double
    }
    let actualObservations: [String]
    let cradleUsedKg: Double
    let dewarUsedKg: Double
    let generatorSHA256: String
    let geometry: Geometry
    let mainCentrelineMetres: Double
    let pieces: [Piece]
    let sourceDesignSHA256: String
    let status: String
  }

  /// Nominal quiescent reference records. The shared source-only mass shape
  /// exposes no native tensor, flowing-liquid model or physical state adapter.
  struct PassageDelta: Decodable, Sendable {
    struct Certificate: Decodable, Sendable {
      let index: Int
      let minimumCornerClearanceMetres: Double
      let noBoundaryCrossing: Bool
    }
    struct Preparation: Decodable, Sendable {
      let actualPreparationObserved: Bool
      let addedHeatJoules: Double
      let totalConservativeSeconds: Double
      let totalElectricalJoules: Double
      let totalNitrogenStockRequiredKg: Double
      let totalRejectedJoules: Double
    }
    let actualOpenStateObserved: Bool
    let baselineSourceSHA256: String
    let connectedFixedAssemblies: [ConnectedAssembly]
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
    let layoutSHA256: String
    let macroCertificates: [Certificate]
    let microcellPopulationQualified: Bool
    let newMeteringCapacityKgPerSecond: Double
    let nominalAccumulatorLiquidCubicMetres: Double
    let nominalDiaphragmLocalZMetres: Double
    let nominalLiquidDensityKgPerCubicMetre: Double
    let phaseStates: [BisonBedFeedCandidateV4.Results.PhaseState]
    let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
    let preparation: Preparation
    let radiatorPatchWallMassKg: Double
    let rigidRuntimeConsumerUpdated: Bool
    let solidPoreDomainCubicMetres: Double
    let sourceDesignSHA256: String
    let status: String
    let wall: BisonBedFeedCandidateV4.Rigid.Wall

    private enum CodingKeys: String, CodingKey {
      case actualOpenStateObserved
      case baselineSourceSHA256
      case connectedFixedAssemblies
      case conductivityFloorQualified
      case criteriaWaived
      case fluidRedistributionRawMoments
      case pressureIntegrityQualified
      case pumpOrValveFunctionQualified
      case quietTransitionObserved
      case actualDiaphragmOrFlowStateQualified
      case actualObservations
      case additionalPreparationElectricalJoules
      case additionalPreparationHeatJoules
      case additionalPreparationRejectJoules
      case baseDry
      case bodyCoreOrContactQualified
      case dewar
      case extraWorkingFluid
      case freeRespiratoryGasCubicMetres
      case generatorSHA256
      case hardware
      case layoutSHA256 = "baselineLayoutSHA256"
      case macroCertificates
      case microcellPopulationQualified
      case newMeteringCapacityKgPerSecond
      case nominalAccumulatorLiquidCubicMetres
      case nominalDiaphragmLocalZMetres
      case nominalLiquidDensityKgPerCubicMetre
      case phaseStates
      case portableStates
      case preparation
      case radiatorPatchWallMassKg
      case rigidRuntimeConsumerUpdated
      case solidPoreDomainCubicMetres
      case sourceDesignSHA256
      case status
      case wall
    }
  }
}
