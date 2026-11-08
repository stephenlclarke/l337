import Foundation

extension BisonColdLoopCandidate {
  /// Frozen model outputs and samples only. These rows are neither a continuous
  /// property guarantee nor an interpolator or actual delivered fluid state.
  struct Results: Decodable, Sendable {
    struct Derived: Decodable, Sendable {
      let CO2AvailableDomainCubicMetres: Double
      let CO2CollectorCubicMetres: Double
      let CO2CollectorPressureDropPascals: Double
      let CO2VentColumnVolumeCubicMetres: Double
      let CO2VentPressureDropPascals: Double
      let accumulatorHoopStressPascals: Double
      let accumulatorInnerVolumeCubicMetres: Double
      let accumulatorOuterVolumeCubicMetres: Double
      let accumulatorShellMassKg: Double
      let allocatedElectricalWatts: Double
      let bodyChannelDP: Double
      let bodyFluidConvectionConductance: Double
      let bodyHeaderDP: Double
      let bodyPanelInternalSpreadingConductance: Double
      let bodyPanelScreeningStressPascals: Double
      let bodyReynolds: Double
      let bodyUA: Double
      let bypassBranchDP: Double
      let coldChannelDP: Double
      let coldHeaderDP: Double
      let coldHeaderRibCount: Int
      let coldHeaderScreeningStressPascals: Double
      let coldPortDP: Double
      let coldReynolds: Double
      let coldUA: Double
      let effectiveBoundaryConductanceWattsPerKelvin: Double
      let fittingDP: Double
      let fixedCircuitFluidVolumeCubicMetres: Double
      let fullColdBranchCapacityWatts: Double
      let mainLineDP: Double
      let mainPipeScreeningStressPascals: Double
      let mainReynolds: Double
      let matrixAxialConductivity: Double
      let matrixConductionWattsPerKelvin: Double
      let matrixExposedAreaSquareMetres: Double
      let matrixGasConductanceWattsPerKelvin: Double
      let matrixMassKg: Double
      let matrixMetalVolumeCubicMetres: Double
      let maximumBoundaryHeatWatts: Double
      let minimumAccumulatorLiquidReserveCubicMetres: Double
      let occupiedMassKg: Double
      let otherRatedElectricalWatts: Double
      let padResistanceKelvinPerWatt: Double
      let pinScreeningStressPascals: Double
      let plateFluidVolumeCubicMetres: Double
      let plateMassKg: Double
      let plateOuterVolumeCubicMetres: Double
      let plateScreeningStressPascals: Double
      let plateTieColumnsPerPlate: Int
      let pumpTemperaturePenaltyFraction: Double
      let ratedPumpElectricalWatts: Double
      let referenceColdBranchFraction: Double
      let referenceControlledBoundaryWatts: Double
      let requiredHotBoundaryKelvin: Double
      let requiredPumpElectricalWatts: Double
      let residualColdDumpWatts: Double
      let totalPressureDropPascals: Double
      let worstHeatPlacementBoundaryKelvin: Double
      let zeroCoolingBranchCapacityWatts: Double
    }
    struct Primary: Decodable, Sendable {
      struct PressureSample: Decodable, Sendable {
        let kelvin: Double
        let maximumBladderPascals: Double
        let maximumSaturationPascals: Double
        let minimumBladderPascals: Double
      }
      let allColdRowsLiquid: Bool
      let maximumDensity: Double
      let maximumViscosityPascalSeconds: Double
      let maximumWarmBladderPascals: Double
      let minimumCpJoulesPerKgKelvin: Double
      let minimumDensity: Double
      let minimumThermalConductivity: Double
      let minimumVapourPressureMarginPascals: Double
      let sampledColdRows: Int
      let warmPressureStates: [PressureSample]
    }
    let actualObservations: [String]
    let allConditionalChecksPass: Bool
    let checks: [String: Bool]
    let coreBodyOrActualContactQualified: Bool
    let derived: Derived
    let generatorSHA256: String
    let porePopulationAndTransportQualified: Bool
    let primary: Primary
    let sourceDesignSHA256: String
    let status: String
  }
}
