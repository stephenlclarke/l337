import Foundation

extension BisonCommissioningCandidateV3 {
  struct Preparation: Decodable, Sendable {
    let plantDryHardwareKg: Double
    let plantOuterDimensionsMetres: [Double]
    let dryHardwareAllocationKg: [String: Double]
    let finiteElectricalEnergyJoules: Double
    let finiteOxygenStockKg: Double
    let finiteNitrogenStockKg: Double
    let finiteCO2StockKg: Double
    let finiteFreshCalciumOxideStockKg: Double
    let hotWaterBufferKg: Double
    let waterInitialKelvin: Double
    let waterMaximumKelvin: Double
    let waterCpJoulesPerKgKelvin: Double
    let maximumPreparationSeconds: Double
    let maximumCoolingElectricalWatts: Double
    let maximumWarmCarrierCoolingElectricalWatts: Double
    let maximumDirectElectricalWatts: Double
    let maximumTotalElectricalWatts: Double
    let minimumCoolingCOP: Double
    let minimumWarmCarrierCoolingCOP: Double
    let maximumGasSealPumpOperationsJoules: Double
    let packChargeEfficiencyMinimum: Double
    let bodyKg: Double
    let bodyKgIsConservativePreparationUpperBound: Bool
    let serviceBodyMassAtActualIssueKg: Double
    let bodyInitialKelvin: Double
    let bodyCpJoulesPerKgKelvin: Double
    let bodyPhaseChangeJoulesPerKg: Double
    let coldHardwareKg: Double
    let coldHardwareCpJoulesPerKgKelvin: Double
    let hotAssemblyKg: Double
    let hotBedCpJoulesPerKgKelvin: Double
    let extraHotForecapWallMassUpperBoundKg: Double
    let extraHotForecapCpJoulesPerKgKelvin: Double
    let CO2GasCpJoulesPerKgKelvin: Double
    let CO2PreparationLatentJoulesPerKg: Double
    let externalPreparationCO2AbsorbentDryKg: Double
    let externalPreparationCO2CapacityKg: Double
    let externalColdPlateSupportsPreparationWithoutConsumingPortableCO2OrCaO: Bool
    let preparationBreathingSupportSeparateFromServiceCartridges: Bool
    let CaOIsPaidMaterialStockNotRegeneratedByThisPlant: Bool
    let gasStockAlreadyIncludedInCarriedCharge: Bool
    let notCarriedOrInventedAtBirth: Bool
  }
  struct Thermochemistry: Decodable, Sendable {
    let sourceURLs: [String]
    let primarySourceCrossCheck: String
    let enthalpyBasis: String
    let carbonationEnthalpyAt298JoulesPerMol: Double
    let measuredEnthalpyUncertaintyJoulesPerMol: Double
    let newConstantCpApproximationJoulesPerKgKelvin: [String: Double]
    let CO2MolarMassKgPerMol: Double
    let CaOMolarMassKgPerMol: Double
    let antoineA: Double
    let antoineB: Double
    let antoineC: Double
  }
  /// G4's conditional source result, not a measured apparatus or native result.
  struct ThermalBudget: Decodable, Sendable {
    let status: String
    let actualObservations: [String]
    let allConditionalBudgetChecksPass: Bool
    let newAssumptionsRequireQualification: Bool
    let checks: [String: Bool]
    let portableWetMassKg: Double
    let carrierInitialPressurePascals: Double
    let carrierRejectedSixHourJoules: Double
    let carrierFixedElectricalSixHourJoules: Double
    let carrierElectricalStoredOrExportedJoules: Double
    let carrierResidualElectricalDumpWatts: Double
    let carrierResidualElectricalDestination: String
    let carrierEnvelopeTemperatureRiseKelvin: Double
    let carrierOccupiedElectricalWatts: Double
    let carrierEmptyElectricalWatts: Double
    let portablePressurePascals: Double
    let portableCO2ConsumedKg: Double
    let requiredCaOConversionFraction: Double
    let CO2RequiredFlowKgPerSecond: Double
    let portableHotRejectionDesignWatts: Double
    let portableHotRejectionWatts: Double
    let closedReferenceEnergyResidualJoules: Double
    let closedReferenceSensibleEnergyIncreaseJoules: Double
    let portableColdLoadWatts: Double
    let coldCO2RemainingKg: Double
    let calciumOxideRemainingKg: Double
    let carbonateFinalKg: Double
    let respiratoryBodyFinalKg: Double
    let packRemainingJoules: Double
    let preparationBaseColdJoules: Double
    let preparationElectricalJoules: Double
    let preparationUpperBoundRejectedJoules: Double
    let preparationBufferCapacityJoules: Double
    let preparationConservativeSeconds: Double
    let preparationMaximumNetBodyMaterialLossKg: Double
    let requiredPerBodyInitialMassFor24hAnd100kgIssue: Double
    let maximumServiceLeakKg: Double
  }
}
