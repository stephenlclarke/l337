import Foundation

extension BisonBedFeedCandidateV4 {
  struct Header: Decodable, Sendable {
    let id: String
    let status: String
    let acceptedIncrement: Int
    let actualObservations: [String]
    let artifacts: [BisonCommissioningCandidateV3.Header.Artifact]
    let baseThermalSourceCommit: String
    let parentCommit: String
    let qualifiedBirth: Bool
  }
  struct Inputs: Decodable, Sendable {
    let baseCommit: String
    let implementationParentCommit: String
    let originalFreezeUnchanged: Bool
    let files: [BisonCommissioningCandidateV3.Inputs.File]
  }
  struct PrimaryNotes: Decodable, Sendable {
    struct Reference: Decodable, Sendable {
      let url: String
      let supports: String
      let doesNotSupport: String?
      let locator: String?
    }
    let actualObservations: [String]
    let newUnqualifiedInputs: [String]
    let primarySources: [Reference]
  }

  /// The source's "qualified" parameter ranges are required apparatus bounds,
  /// explicitly unobserved. They are not calibrated EOS/transport or valve state.
  struct Design: Decodable, Sendable {
    struct Feed: Decodable, Sendable {
      let antiIceMaximumElectricalWattsWithin42: Double
      let antiIceMaximumParasiticToColdWatts: Double
      let antiIceOutletKelvin: Double
      let bendZMetres: Double
      let gammaAssumption: Double
      let qualifiedGammaRange: [Double]
      let heaterCentreMetres: [Double]
      let heaterDimensionsMetres: [Double]
      let heaterMassKg: Double
      let innerSquareWidthMetres: Double
      let outerSquareWidthMetres: Double
      let mainYMetres: Double
      let maximumDesignMassFlowKgPerSecond: Double
      let maximumFittingLossCoefficient: Double
      let maximumFrictionDarcyFactor: Double
      let maximumHeaterCpJoulesPerKgKelvin: Double
      let minimumMeteringStagnationKelvin: Double
      let maximumMeteringStagnationKelvin: Double
      let minimumMeteringDischargeCoefficient: Double
      let minimumColdFeedKelvin: Double
      let minimumLinePressurePascals: Double
      let minimumRecuperatorConductanceWattsPerKelvin: Double
      let maximumRecuperatorPressureDropPascals: Double
      let metalDensityKgPerCubicMetre: Double
      let singlePhaseAndValveTransientsObserved: Bool
    }
    struct Phase: Decodable, Sendable {
      let Antoine: [Double]
      let CO2MolarMassKgPerMol: Double
      let CO2TripleKelvin: Double
      let CO2TriplePascals: Double
      let CaCO3DensityKgPerCubicMetre: Double
      let CaODensityKgPerCubicMetre: Double
      let CaOMolarMassKgPerMol: Double
      let actualPhaseOrFiniteStockObserved: Bool
      let compressibilityOrHeatCapacityObserved: Bool
      let coldCO2Kelvin: Double
      let coldCO2RangeKelvin: [Double]
      let gasConstantJoulesPerMolKelvin: Double
      let minimumLatentJoulesPerKg: Double
      let nominalCO2CpJoulesPerKgKelvin: Double
      let qualifiedCompressibilityFactorRange: [Double]
      let solidDensityKgPerCubicMetre: Double
      let totalThermalCO2StockKg: Double
    }
    struct Reactor: Decodable, Sendable {
      let ErgunMultiplierOrViscosityObserved: Bool
      let initialCaOKg: Double
      let innerDimensionsMetres: [Double]
      let maximumCapturedAndGasKg: Double
      let maximumDiffuserPressureDropPascals: Double
      let maximumGasInventoryKg: Double
      let maximumInletPressurePascals: Double
      let maximumQualifiedErgunMultiplier: Double
      let maximumTemperatureKelvin: Double
      let maximumViscosityPascalSeconds: Double
      let metalDensityKgPerCubicMetre: Double
      let minimumBedVoidFraction: Double
      let minimumEffectivePelletDiameterMetres: Double
      let minimumOutletPressurePascals: Double
      let minimumScreenDischargeCoefficient: Double
      let nominalDiffuserPressurePascals: Double
      let nominalMeanPressurePascals: Double
      let nominalTemperatureKelvin: Double
      let plenumDepthMetres: Double
      let preheaterPlateDimensionsMetres: [Double]
      let preheaterPlateOffsetMetres: [Double]
      let reactionKineticsQualified: Bool
      let reactorAssemblyDryKg: Double
      let restrictorApertureOffsetMetres: [Double]
      let restrictorBodyDimensionsMetres: [Double]
      let restrictorOffsetMetres: [Double]
      let restrictorThroatDimensionsMetres: [Double]
      let screenBorderAndWebMetres: Double
      let screenHoleCountX: Int
      let screenHoleCountY: Int
      let screenThicknessMetres: Double
    }
    struct Sourcing: Decodable, Sendable {
      let allNumericalExecutionHost: String
      let externalHardwareOrExtraEquipmentSlots: Int
      let extraPaidPairs: Int
      let feedDryMassDebitedFromExistingHeatpathKg: Double
      let nativeGeometryChanged: Bool
      let newPhysicalSourceUnobserved: Bool
    }
    let actualObservations: [String]
    let status: String
    let primaryReferences: [String]
    let feed: Feed
    let phase: Phase
    let reactor: Reactor
    let sourcing: Sourcing
  }
}
