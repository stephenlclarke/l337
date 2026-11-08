import Foundation

extension BisonColdLoopCandidate {
  /// Authored bounds and finite dimensions, never actual material/flow/stock.
  struct Design: Decodable, Sendable {
    struct Accumulator: Decodable, Sendable {
      let actualBladderOrPressureObserved: Bool
      let centreMetres: [Double]
      let gasCompressibilityRange: [Double]
      let innerRadiusMetres: Double
      let maximumWorkingPressurePascals: Double
      let metalDensityKgPerCubicMetre: Double
      let minimumLiquidReserveCubicMetres: Double
      let minimumMetalAllowableStressPascals: Double
      let mountAndValveMassKg: Double
      let nitrogenMassKg: Double
      let nitrogenSpecificGasConstant: Double
      let outerRadiusMetres: Double
      let shape: String
      let straightLengthMetres: Double
    }
    struct Allocation: Decodable, Sendable {
      let baseOccupiedMassKg: Double
      let bodyPanelPadPumpAccumulatorPipesFromCradleKg: Double
      let coldPlatesMatrixAndHeadersFromDewarKg: Double
      let maximumOccupiedMassKgUnchanged: Double
      let newPaidNitrogenStockKg: Double
      let newPaidPropaneStockKg: Double
      let sourceActualStocksObserved: Bool
    }
    struct BodyPanel: Decodable, Sendable {
      let actualBodyContactOrCoreThermalTransportObserved: Bool
      let centreMetres: [Double]
      let channelCount: Int
      let channelHeightMetres: Double
      let channelLengthMetres: Double
      let channelWidthMetres: Double
      let headerInnerSquareMetres: Double
      let headerLengthMetres: Double
      let headerOuterSquareMetres: Double
      let headersCount: Int
      let metalDensityKgPerCubicMetre: Double
      let minimumMetalAllowableStressPascals: Double
      let minimumMetalConductivityWattsPerMetreKelvin: Double
      let outerDimensionsMetres: [Double]
      let padBondMinimumConductivity: Double
      let padCoreMinimumConductivity: Double
      let padCoreThicknessMetres: Double
      let padDensityKgPerCubicMetre: Double
      let padThicknessMetres: Double
    }
    struct ColdExchanger: Decodable, Sendable {
      let actualPoreCoverageOrTransportQualified: Bool
      let gapCellCounts: [Int]
      let gasCollectorDepthMetres: Double
      let headerCrossDimensionsMetres: [Double]
      let headerLengthMetres: Double
      let headerRibPitchMetres: Double
      let headerRibThicknessMetres: Double
      let headersCount: Int
      let innerDimensionsMetres: [Double]
      let matrixMetalDensityKgPerCubicMetre: Double
      let matrixPitchMetres: Double
      let matrixStrutWidthMetres: Double
      let maximumCollectorFittingK: Double
      let maximumCollectorFrictionDarcyFactor: Double
      let maximumCollectorPathMetres: Double
      let maximumGasPathLengthCells: Double
      let maximumPinnedPressureLossMultiplier: Double
      let minimumActivePoreFraction: Double
      let minimumCO2GasConductivity: Double
      let minimumCollectorOutletEffectivePerimeterMetres: Double
      let minimumFluidOpenWidthFraction: Double
      let minimumGasPathShapeFactor: Double
      let minimumHeaderOuterWallMetres: Double
      let minimumMatrixJointFactor: Double
      let minimumMatrixMetalConductivity: Double
      let minimumMatrixPlateContactConductanceWattsPerKelvin: Double
      let minimumPlateAllowableStressPascals: Double
      let minimumPlateMetalConductivity: Double
      let pinPitchMetres: Double
      let pinRadiusMetres: Double
      let plateCount: Int
      let plateFluidGapMetres: Double
      let plateMetalDensityKgPerCubicMetre: Double
      let plateSideBorderMetres: Double
      let plateTotalThicknessMetres: Double
      let portLengthMetres: Double
      let ventCentresXMetres: [Double]
      let ventCentresYMetres: [Double]
      let ventSealBorderMetres: Double
      let ventSideMetres: Double
    }
    struct Coolant: Decodable, Sendable {
      let actualPureChargeOrPhaseObserved: Bool
      let chargedMassKg: Double
      let coldOperationKelvin: [Double]
      let massFlowKgPerSecond: Double
      let maximumColdDensityKgPerCubicMetre: Double
      let maximumPrepCpJoulesPerKgKelvin: Double
      let maximumViscosityPascalSeconds: Double
      let maximumWarmStorageKelvin: Double
      let minimumColdNusselt: Double
      let minimumCpJoulesPerKgKelvin: Double
      let minimumDensityKgPerCubicMetre: Double
      let minimumThermalConductivityWattsPerMetreKelvin: Double
      let species: String
    }
    struct MainCircuit: Decodable, Sendable {
      let actualPumpFlowOrEfficiencyObserved: Bool
      let branchInnerSquareMetres: Double
      let branchLengthMetres: Double
      let branchOuterSquareMetres: Double
      let innerSquareMetres: Double
      let maximumAdapterExtraFluidVolumeCubicMetres: Double
      let maximumCentrelineLengthMetres: Double
      let maximumFittingLossCoefficient: Double
      let maximumFrictionDarcyFactor: Double
      let maximumPumpHeadPascals: Double
      let metalDensityKgPerCubicMetre: Double
      let minimumFixedCircuitFluidVolumeCubicMetres: Double
      let minimumMetalAllowableStressPascals: Double
      let minimumPumpOverallEfficiency: Double
      let outerSquareMetres: Double
      let pumpCentreMetres: [Double]
      let pumpDisplacedLineLengthMetres: Double
      let pumpDryMassKg: Double
      let pumpExternalDimensionsMetres: [Double]
      let pumpFluidVolumeCubicMetres: Double
    }
    struct Power: Decodable, Sendable {
      let allResidualHeatDestination: String
      let beaconWatts: Double
      let blowerWatts: Double
      let controlWatts: Double
      let maximumAntiIceWatts: Double
      let unchangedTotalWatts: Double
    }
    struct Regulator: Decodable, Sendable {
      let actualMixingFractionOrControlObserved: Bool
      let bypassInnerSquareMetres: Double
      let bypassLengthMetres: Double
      let bypassOuterSquareMetres: Double
      let maximumBypassValveLossCoefficient: Double
      let valveCentreMetres: [Double]
      let valveDryMassKg: Double
      let valveFluidVolumeCubicMetres: Double
      let valveOuterDimensionsMetres: [Double]
    }
    struct Target: Decodable, Sendable {
      let biologicalCoreOrActualBodyContactQualified: Bool
      let maximumCO2SinkKelvin: Double
      let maximumColdHeatWatts: Double
      let maximumQuietSeconds: Double
      let minimumBoundaryConductanceWattsPerKelvin: Double
      let minimumHotBoundaryKelvin: Double
      let nominalColdHeatWatts: Double
    }
    let accumulator: Accumulator
    let actualObservations: [String]
    let allocation: Allocation
    let bodyPanel: BodyPanel
    let coldExchanger: ColdExchanger
    let coolant: Coolant
    let mainCircuit: MainCircuit
    let power: Power
    let regulator: Regulator
    let status: String
    let target: Target
  }
}
