import Foundation

extension BisonColdLoopCandidate {
  struct ConnectedAssembly: Decodable, Sendable {
    struct Interface: Decodable, Equatable, Sendable {
      let axis: Int
      let centreMetres: [Double]
      let sideMetres: Double
    }
    /// At the source's declared unit density, generic massKg encodes geometric
    /// volume and the inertia fields encode volume moments. Neither is stock.
    struct GeometricMoments: Decodable, Sendable {
      let id: String
      let centreMetres: [Double]
      let volumeCubicMetres: Double
      let volumeInertiaMetres5: [Double]
      private enum CodingKeys: String, CodingKey {
        case id, centreMetres
        case volumeCubicMetres = "massKg"
        case volumeInertiaMetres5 = "inertiaAboutCentreOfMassKgM2"
      }
    }
    let id: String
    let actualOpenStateObserved: Bool
    let centralCavityDimensionsMetres: [Double]
    let fluid: GeometricMoments
    let fluidBoxes: [BisonBedFeedCandidateV4.Results.Layout.Box]
    let fluidVolumeCubicMetres: Double
    let geometryMomentConvention: String
    let housing: BisonCommissioningCandidateV3.SourceMassState
    let housingEffectiveDensityKgPerCubicMetre: Double
    let housingSolidVolumeCubicMetres: Double
    let interfaces: [Interface]
    let oldFluid: GeometricMoments
    let outer: BisonBedFeedCandidateV4.Results.Layout.Box
    let pressureIntegrityQualified: Bool
    let pumpOrValveFunctionQualified: Bool
  }
  /// Signed physical moment correction from the frozen source. The minute
  /// floating residual is retained, never rounded into new fluid or a reset.
  struct FluidRedistribution: Decodable, Equatable, Sendable {
    let firstKgMetres: [Double]
    let massKg: Double
    let secondKgMetresSquared: [[Double]]
  }
  struct PassageInputs: Decodable, Sendable {
    let baselineFilesPinnedByRetainedManifest: Bool
    let baselineStageManifestSHA256: String
    let conductivityQualificationGranted: Bool
    let files: [BisonCommissioningCandidateV3.Header.Artifact]
    let firstCriteriaSHA256: String
    let physicalBase: String
  }
  struct PassageCriteria: Decodable, Sendable {
    let scope: String
    let sourceBase: String
    let physicalBase: String
    let success: [String]
    let unchanged: [String]
    let qualificationOpen: [String]
    let actualObservations: [String]
    let nativeCompilerRenderer: Bool
  }
  struct PassageExactDelta: Decodable, Sendable {
    struct Geometry: Decodable, Sendable {
      let id: String
      let centralCavityDimensionsMetres: [Double]
      let fluidVolumeCubicMetres: Double
      let housingEffectiveDensityKgPerCubicMetre: Double
      let paidFixedMassKg: Double
      let portInterfaces: [ConnectedAssembly.Interface]
    }
    struct Budgets: Decodable, Sendable {
      let carrier7Empty: Bool
      let carrierBodies: Int
      let clockSeconds: Double
      let cradleKg: Double
      let dewarKg: Double
      let dryKg: Double
      let electricWatts: Double
      let forceNewtons: Double
      let initialElectricalJoules: Double
      let maxOccupiedKg: Double
      let maximumQuietSeconds: Double
      let minimumBoundaryConductanceWattsPerKelvin: Double
      let movingMassKg: Double
      let nitrogenKg: Double
      let nominalOccupiedKg: Double
      let operatingRoles: Int
      let original7OnlyFrozenNewt: Bool
      let paidCaps: Int
      let passiveAnnuli: Int
      let propaneKg: Double
      let pumpFluidCubicMetres: Double
      let pumpKg: Double
      let startupElectricalJoules: Double
      let thermalCO2Kg: Double
      let valveFluidCubicMetres: Double
      let valveKg: Double
      let workJoules: Double
    }
    let acceptedPlayableIncrement: Int
    let actualObservations: [String]
    let authorParent: String
    let criteriaWaived: [String]
    let effectiveDensitiesAreNewUnqualifiedMaterialRequirements: Bool
    let firstCriteriaSHA256: String
    let geometry: [Geometry]
    let liquidRedistribution: FluidRedistribution
    let nativeCompilerRendererRun: Bool
    let newPortableStates: [BisonCommissioningCandidateV3.SourceMassState]
    let physicalBase: String
    let runtimeConsumerChanged: Bool
    let shippingResourceChanged: Bool
    let sourceSHA256: String
    let stillOpen: [String]
    let unchangedBudgets: Budgets
    let unchangedConditionalRequirements: [String]
    let unchangedSourceFields: [String]
  }
}
