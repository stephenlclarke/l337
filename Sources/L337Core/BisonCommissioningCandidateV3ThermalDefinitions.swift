import Foundation

extension BisonCommissioningCandidateV3 {
  /// Authored apparatus/budget assumptions. No member is an observed reading,
  /// finite stock receipt, actuator permission or successful preparation.
  struct Thermal: Decodable, Sendable {
    struct Custody: Decodable, Sendable {
      let originalRoles: Int
      let carrierEmptyOrdinal: Int
      let carrierOccupiedOrdinals: [Int]
      let portableBodyOrdinal: Int
      let actualIdentitiesOrAwakeStatesGranted: Bool
    }
    struct Carrier: Decodable, Sendable {
      let gasKelvin: Double
      let bodyReferenceKelvin: Double
      let dryHardwareKgUnchanged: Double
      let existingGasKg: Double
      let existingNitrogenKg: Double
      let existingOxygenKg: Double
      let operativeBodyReferenceRangeKelvin: [Double]
      let operativeGasTemperatureRangeKelvin: [Double]
      let maximumPressurePascals: Double
      let minimumBodyToGasConductanceWattsPerKelvin: Double
      let minimumCoolingCOP: Double
      let heatSinkKelvin: Double
      let auxiliaryElectricalWatts: Double
      let maximumEnvironmentalHeatLeakWatts: Double
      let existingHullInitialKelvin: Double
      let existingHullMaximumKelvin: Double
      let existingHullThermalCapacityMinimumJoulesPerKelvin: Double
      let minimumEnvelopeSpecificHeatJoulesPerKgKelvin: Double
      let minimumSharedSinkConductanceWattsPerKelvin: Double
      let thermalCapacityMaterialID: String
      let newMaterialPerformanceAssumptionsRequireQualification: Bool
    }
    struct Portable: Decodable, Sendable {
      let bodyAndGasKelvin: Double
      let coldCO2Kelvin: Double
      let hotBedKelvin: Double
      let radiatorKelvin: Double
      let heatSinkKelvin: Double
      let operativeBodyGasTemperatureRangeKelvin: [Double]
      let coldCO2RangeKelvin: [Double]
      let hotBedRangeKelvin: [Double]
      let radiatorRangeKelvin: [Double]
      let chargedSolidCO2Kg: Double
      let calciumOxideKgWithinExisting32: Double
      let remainingHardwareKgWithinExisting32: Double
      let existingCryothermalDryKg: Double
      let absorberHousingAndHeatpathDryKgUnchanged: Double
      let additionalDewarDryKg: Double
      let dewarInteriorDimensionsMetres: [Double]
      let absorberInteriorDimensionsMetres: [Double]
      let assumedCaODensityKgPerCubicMetre: Double
      let assumedCarbonateDensityKgPerCubicMetre: Double
      let assumedSolidCO2DensityKgPerCubicMetre: Double
      let finiteCryothermalHardwareAllocationKg: [String: Double]
      let minimumPackedBedVoidFraction: Double
      let minimumCO2UptakeKgPerKgCaO: Double
      let minimumLatentJoulesPerKg: Double
      let minimumColdPathConductanceWattsPerKelvin: Double
      let minimumHotRadiatorConductanceWattsPerKelvin: Double
      let maximumHotToColdConductanceWattsPerKelvin: Double
      let maximumEnvironmentalIngressWatts: Double
      let maximumOperationalCapturedCO2Kg: Double
      let maximumHotRejectionDesignWatts: Double
      let maximumClosedVolumeEnergyCorrectionJoules: Double
      let maximumBodyGasDeviationKelvin: Double
      let radiatorAreaSquareMetres: Double
      let minimumRadiatorEmissivity: Double
      let minimumRadiatorViewFactor: Double
      let fixedElectricalWattsAllCountedAsColdHeat: Double
      let ratedOccupiedMassLimitKgUnchanged: Double
      let newReactionAndPackingPerformanceRequireQualification: Bool
      let ventedMassKg: Double
      let valveQuietMaximumSeconds: Double
      let extraPaidMechanicalPairs: Int
      let heatpath: String
      let heatLocations: HeatLocations
      struct HeatLocations: Decodable, Sendable {
        let allMassRetainedInClosedThermalCircuit: Bool
        let reactionHeatIsPositiveAtHotNode: Bool
        let hotLeakReturnsToColdNodeAndIsIncludedInCoolingLoad: Bool
        let coldNode: String
        let hotNode: String
        let rejection: String
        let view: String
      }
    }
    struct GasOperations: Decodable, Sendable {
      let qualifiedActualPressureSealOrStockObserved: Bool
      let vacuumTargetPascals: Double
      let closedSealTestSeconds: Double
      let maximumMassLeakKgPerSecond: Double
      let measurementTolerancePascals: Double
      let operativePressureRangePascals: [Double]
      let maximumBedPressurePascals: Double
      let maximumColdCircuitInFlightCO2Kg: Double
      let maximumFlowOrificeDiameterMetres: Double
      let minimumDischargeCoefficient: Double
      let CO2GammaAssumption: Double
      let coldCircuitSeparateFromRespiratoryGas: Bool
      let equalisationOrServiceToResetPackOrClock: Bool
    }
    struct PerUnitElectrical: Decodable, Sendable {
      let initialJoules: Double
      let startupJoules: Double
      let continuousWatts: Double
      let ratedSeconds: Double
    }
    struct LifeSupport: Decodable, Sendable {
      let oxygenKgPerMinute: Double
      let co2KgPerMinute: Double
      let sorbentCapacityKg: Double
    }
    let status: String
    let actualObservations: [String]
    let nativeTestsRun: Bool
    let biologicalCryostasisAndOperatingCrewFitnessQualified: Bool
    let sourceCorrection: String
    let custody: Custody
    let carrier: Carrier
    let portable: Portable
    let finiteGasOperations: GasOperations
    let unchangedPerUnitElectrical: PerUnitElectrical
    let unchangedLifeSupport: LifeSupport
    let preparationPlant: Preparation
    let externalThermochemistry: Thermochemistry
  }
}
