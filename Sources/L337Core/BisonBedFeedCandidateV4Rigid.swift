import Foundation

extension BisonBedFeedCandidateV4 {
  struct Rigid: Decodable, Sendable {
    struct Wall: Decodable, Sendable {
      let materialQualificationObserved: Bool
      let rawResidual: [Double]
      let retainedLidMassKg: Double
      let wallCellEffectiveDensityKgPerCubicMetre: [Double]
      let wallCellMassKg: [Double]
    }
    let actualObservations: [String]
    let status: String
    let canonicalDryAggregatePreserved: Bool
    let canonicalOuterGeometryUnchanged: Bool
    let bodyRespirationAndSorbentPreserved: Bool
    let finitePhaseStateRepresentation: String
    let massRelevantInputSHA256: String
    let freeRespiratoryGasVolumeCubicMetres: Double
    let unchangedRadiatorPatchNewWallMassKg: Double
    let baseDry: BisonCommissioningCandidateV3.SourceMassState
    let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
    let wall: Wall
  }
  struct Delta: Decodable, Sendable {
    let acceptedIncrement: Int
    let actualObservations: [String]
    let id: String
    let baseCommit: String
    let status: String
    let allGasBoundKg: Double
    let currentCarrierServiceHeatJoules: Double
    let newRespiratoryFreeGasCubicMetres: Double
    let oldFrozenSourcesUnchanged: Bool
    let qualifiedBirth: Bool
    let shippingOrRuntimeFilesChanged: Bool
    let sourceChanges: [String]
    let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
  }
  struct Criteria: Decodable, Sendable {
    struct Limits: Decodable, Sendable {
      let CO2ThermalStockKg: Double
      let chargedAdditionalKg: Double
      let dryKg: Double
      let electricalWattsPerUnit: Double
      let loadedMaximumKg: Double
      let loopDryKg: Double
      let movingDriveMassKg: Double
      let paidForceNewtons: Double
      let paidPairs: Int
      let paidWorkJoules: Double
      let passivePairs: Int
    }
    let actualObservations: [String]
    let parentCommit: String
    let thermalBaseCommit: String
    let scope: String
    let allGasReserveKg: Double
    let maximumBedInletPressurePascals: Double
    let maximumCapturedPlusReservedGasKg: Double
    let minimumBedVoidAt12kgCapture: Double
    let minimumDesignMassFlowKgPerSecond: Double
    let minimumGasExpansionKelvin: Double
    let minimumOutletPressurePascals: Double
    let newFlowAssemblyQualificationKgPerSecond: Double
    let retainedMinimumCaOConversionFraction: Double
    let retainedNearDepletionUptakeKgPerSecond: Double
    let unchangedLimits: Limits
  }
  struct Contacts: Decodable, Sendable {
    struct Case: Decodable, Sendable {
      let state: String
      let q: Double
      let rotation: [[Double]]
      let lambdaNewtons: [Double]
    }
    let cases: [Case]
    let paidForceNewtons: Double
    let paidWorkJoules: Double
    let scope: String
  }

  /// Only the added feed apparatus introduces new refusal categories. The
  /// parent's eleven reviewed runtime owners continue through parent directly.
  enum FeedRuntimeDimension: String, CaseIterable, Equatable, Sendable {
    case dividerSealsAndScreens, preheatAntiIceAndRecuperation, gasEOSAndTransportBounds
  }
  enum Refusal: Error, Equatable {
    case resourceSet, resourceIdentity(String), parentRevision, incoherentDefinition
    case unsupportedFeedRuntimeDimension(FeedRuntimeDimension)
  }
  func requireFeedRuntimeSupport(_ dimension: FeedRuntimeDimension) throws -> Never {
    throw Refusal.unsupportedFeedRuntimeDimension(dimension)
  }
  var sourceQualifiedForBirth: Bool { parent.sourceQualifiedForBirth }
  /// Distinct scopes: all-circuit gas includes headspace within the same stock.
  /// The older in-flight value is retained, not refuted as an external-gas bound.
  var priorOutsideTankInFlightSourceBoundKg: Double { parent.thermal.finiteGasOperations.maximumColdCircuitInFlightCO2Kg }
  var allCircuitGasSourceReserveKg: Double { design.reactor.maximumGasInventoryKg }
  var totalThermalCO2SourceStockKg: Double { design.phase.totalThermalCO2StockKg }
}
