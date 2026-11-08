import Foundation

extension BisonBedFeedCandidateV4 {
  /// Conditional source values only. None is an actual delivered flow, phase,
  /// heat, leakage or stock measurement and no integration occurs in this type.
  struct Results: Decodable, Sendable {
    struct OldChoke: Decodable, Sendable {
      let equilibriumGasConditionPass: Bool
      let equilibriumSublimationPascals: Double
      let sonicKelvin: Double
      let sonicPascals: Double
    }
    struct PhaseState: Decodable, Sendable {
      let CaCO3Kg: Double
      let CaORemainingKg: Double
      let bedSolidVolumeCubicMetres: Double
      let bedVoidGasCO2Kg: Double
      let bodyIndependentThermalCO2TotalKg: Double
      let capturedCO2Kg: Double
      let dewarHeadGasCO2Kg: Double
      let diffuserGasCO2Kg: Double
      let feedLineGasCO2Kg: Double
      let inletGasCO2Kg: Double
      let outletGasCO2Kg: Double
      let solidCO2Kg: Double
      let totalUnreactedGasCO2Kg: Double
    }
    struct Hydraulics: Decodable, Sendable {
      let bedOutletBeforeScreensPascals: Double
      let deliveredOutletLowerBoundPascals: Double
      let empiricalCorrelationQualificationRequired: Bool
      let flowBoundPass: Bool
      let inletPressurePascals: Double
      let meteringChokedCapacityKgPerSecond: Double
      let meteringIsChoked: Bool
      let meteringStagnationPressureLowerBoundPascals: Double
      let porosity: Double
      let pressureSquaredGradientK: Double
      let screenPressureDropPascals: Double
      let upstreamLinePressureDropPascals: Double
    }
    struct Layout: Decodable, Sendable {
      struct Box: Decodable, Sendable {
        let maximumMetres: [Double]
        let minimumMetres: [Double]
      }
      struct Divider: Decodable, Sendable {
        let apertureCentreMetres: [Double]
        let apertureDimensionsMetres: [Double]
        let centreMetres: [Double]
        let dimensionsMetres: [Double]
        let noUnmeteredBypassInGeometricConstruction: Bool
        let sealStrengthAndUniformDistributionQualified: Bool
      }
      struct Screen: Decodable, Sendable {
        let centreMetres: [Double]
        let holeCount: [Int]
        let holeDimensionsMetres: [Double]
        let massKg: Double
        let openAreaSquareMetres: Double
        let thicknessMetres: Double
        let webMetres: Double
      }
      let bedCentreMetres: [Double]
      let bedDimensionsMetres: [Double]
      let bedVolumeCubicMetres: Double
      let dewarInnerVolumeCubicMetres: Double
      let dewarPortCentreMetres: [Double]
      let dewarPortDimensionsMetres: [Double]
      let diffuserPlenumFreeVolumeCubicMetres: Double
      let feedBoreVolumeCubicMetres: Double
      let feedCentrelineLengthMetres: Double
      let feedDryWallMassKg: Double
      let feedOuterBoxes: [Box]
      let feedOuterVolumeCubicMetres: Double
      let freeRespiratoryGasVolumeCubicMetres: Double
      let inletPlenumFreeVolumeCubicMetres: Double
      let outletPlenumFreeVolumeCubicMetres: Double
      let interiorVolumePartitionResidualCubicMetres: Double
      let newBoxMinimumBoundaryClearanceMetres: [Double]
      let preheaterPlateMassKg: Double
      let reactorCentreMetres: [Double]
      let reactorHardwareEffectiveShellKg: Double
      let reactorPortCentreMetres: [Double]
      let reactorPortDimensionsMetres: [Double]
      let remainingHotHeatpathMassKg: Double
      let restrictorMassKg: Double
      let innerPressureDivider: Divider
      let screens: [Screen]
      // Reuse only the parent's source-value shape, which has no native conversion.
      let bedUnitComponent: BisonCommissioningCandidateV3.SourceMassState
      let diffuserGasUnitComponent: BisonCommissioningCandidateV3.SourceMassState
      let feedDryWallComponent: BisonCommissioningCandidateV3.SourceMassState
      let hardwareRawMoments: BisonCommissioningCandidateV3.SourceMassState
      let heaterComponent: BisonCommissioningCandidateV3.SourceMassState
      let inletGasUnitComponent: BisonCommissioningCandidateV3.SourceMassState
      let outletGasUnitComponent: BisonCommissioningCandidateV3.SourceMassState
      let reactorDryComponent: BisonCommissioningCandidateV3.SourceMassState
    }
    let actualObservations: [String]
    let status: String
    let allConditionalChecksPass: Bool
    let phaseValveTransientOrKineticsQualified: Bool
    let sourceDesignSHA256: String
    let generatorSHA256: String
    let checks: [String: Bool]
    let closedHotLedgerResidualJoules: Double
    let closedVolumeEnergyCorrectionUpperBoundJoules: Double
    let currentCarrierServiceHeatJoules: Double
    let fixed42ElectricalTotalWatts: Double
    let gasInventoryUpperComponentsKg: [String: Double]
    let totalGasInventoryUpperBoundKg: Double
    let independentReactionNodeNetWatts: Double
    let maximumAntiIceElectricalWatts: Double
    let maximumRecuperatedHeatWatts: Double
    let minimumDownstreamExpansionKelvin: Double
    let netSensibleEnthalpyIncreaseJoules: Double
    let nominalAntiIceElectricalWatts: Double
    let nominalCapturedCO2KgPerSecond: Double
    let nominalColdHeatFromElectricalAndParasiticWatts: Double
    let nominalGasSensibleFromElectricWatts: Double
    let nominalGrossHotWatts: Double
    let nominalLatentColdWatts: Double
    let nominalLineCO2KgPerSecond: Double
    let nominalOtherElectricalDrawWatts: Double
    let nominalRadiatorAfter13_2WFeedbackWatts: Double
    let nominalRecuperatedHotHeatWatts: Double
    let nominalSolidSublimationKgPerSecond: Double
    let paidChemicalReferenceJoules: Double
    let parasiticHeaterHeatReturnedToColdWatts: Double
    let oldSaturatedIdealChoke: OldChoke
    let hydraulics: Hydraulics
    /// Initial, nominal six-hour, then packing stress only. The12kg stress
    /// snapshot grants no operating capture above captured-plus-reserve limits.
    let phaseStates: [PhaseState]
    let layout: Layout
  }
}
