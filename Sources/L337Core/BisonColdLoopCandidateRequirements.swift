import Foundation

extension BisonColdLoopCandidate {
  struct Inputs: Decodable, Sendable {
    let baseCommit: String
    let files: [BisonCommissioningCandidateV3.Inputs.File]
  }
  struct Criteria: Decodable, Sendable {
    struct Acceptance: Decodable, Sendable {
      let minimumBoundaryConductanceWattsPerKelvin: Double
      let maximumOccupiedMassKg: Double
      let fixedElectricalWatts: Double
      let canonicalDryMassCOMFullInertiaAndLidStock: Bool
      let thermalCO2StockKg: Double
      let maximumQuietSeconds: Double
      let nativeOrOperatingAuthorityFromSource: Bool
    }
    let status: String
    let sourceBase: String
    let firstCriteria: String
    let unchangedAcceptance: Acceptance
    let finalConstruction: [String]
    let scopeLimits: [String]
    let actualObservations: [String]
    let criteriaWaived: [String]
  }
  /// Frozen source annotations. Later G4 validity work identifies 150..215 K
  /// zero-density support; neither it nor these notes qualify the actual
  /// finite-pressure/interface/pore domain or its required 0.007 W/m/K floor.
  struct PrimaryNotes: Decodable, Sendable {
    struct Reference: Decodable, Sendable {
      let url: String
      let role: String
      let limit: String
    }
    let status: String
    let sources: [Reference]
    let newBoundsNotPublishedGuarantees: [String]
    let actualObservations: [String]
  }
  struct Operation: Decodable, Sendable {
    struct BodyBoundary: Decodable, Sendable {
      let reference: String
      let coreSkinContactCryobiologyQualified: Bool
      let arbitraryLocalHeatFluxQualified: Bool
    }
    struct QuietTransition: Decodable, Sendable {
      let maximumSecondsUnchanged: Double
      let actualQuietOrSettledStateObserved: Bool
      let requirements: [String]
      let closedLoopIdentity: String
      let nominalReferenceOnly: String
    }
    struct Ownership: Decodable, Sendable {
      let physicalSourceAuthor: String
      let maintainedRuntimeSaveConsumers: String
      let nativeExecution: String
      let runtimeChangesInThisSlice: Bool
      let shippingResourceChangesInThisSlice: Bool
      let playableIncrement: Int
    }
    struct Custody: Decodable, Sendable {
      let originalOperatingRoles: Int
      let carrierBodies: Int
      let carrierCell7Empty: Bool
      let original7OnlyFrozenNewt: Bool
      let privateUnitsRemainUnobserved: Bool
      let identityConsentAwakeFitnessOrAuthorityGranted: Bool
    }
    let status: String
    let actualObservations: [String]
    let bodyBoundary: BodyBoundary
    let qualificationRequired: [String]
    let quietTransition: QuietTransition
    let ownership: Ownership
    let custody: Custody
  }
}
