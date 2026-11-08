import Foundation

extension BisonCommissioningCandidateV3 {
  /// Base source declarations remain attributed to v2; they are not a v3
  /// operating-load adapter or actual body/profile/commodity instances.
  struct BaseDeclarations: Decodable, Sendable {
    struct Profile: Decodable, Sendable {
      let ordinal: Int
      let profileID: String
      let humanReview: String
      let identityRule: String
      let massKg: Double
      let dimensionsMetres: [Double]
      let centreMetres: [Double]
      let inertiaAboutCentreOfMassKgM2: [Double]
    }
    struct Inventory: Decodable, Sendable {
      struct Cargo: Decodable, Sendable {
        let cellCentresMetres: [[Double]]
        let cellPitchMetres: Double
        let cubeDensityKgM3: Double
        let maximumCellKg: Double
        let maximumTotalKilograms: Double
        let nativeUnitByCommodityIndex: [String]
        let unitKilograms: [String: Double]
        let placement: String
      }
      struct Fuel: Decodable, Sendable {
        let capacityTenthsLY: Int
        let kilogramsPerTenthLY: Double
        let includesActualScoopRemainder: Bool
        let centreMetres: [Double]
        let distributionDimensionsMetres: [Double]
      }
      struct Missiles: Decodable, Sendable {
        let maximum: Int
        let kilogramsEach: Double
        let dimensionsMetres: [Double]
        let centresMetres: [[Double]]
      }
      struct Equipment: Decodable, Sendable {
        let actualECMEnabledMustBeSealed: Bool
        let actualFuelScoopsMustBeFalse: Bool
        let coreECMIncludedInNewBareKg: Double
        let kitCount: Int
        let additionalModules: String
      }
      let id: String
      let catalogueShipID: String
      let r3SHA256: String
      let humanReview: String
      let cargo: Cargo
      let fuel: Fuel
      let missiles: Missiles
      let equipment: Equipment
    }
    let id: String
    let crewPhysicalProfiles: [Profile]
    let actualInventoryLoadModel: Inventory
  }

  struct UnitDefinition: Sendable {
    enum Location: Equatable, Sendable { case carrierCell(Int), portable }
    let location: Location
    /// A source proposal, not an observed person or empty-roster assertion.
    let proposedOriginalBodyOrdinal: Int?
    let proposedGasKelvin: Double
    let proposedBodyReferenceKelvin: Double?
  }

  var proposedUnitDefinitions: [UnitDefinition] {
    (0..<12).map { ordinal in
      UnitDefinition(location: .carrierCell(ordinal),
        proposedOriginalBodyOrdinal: ordinal == thermal.custody.carrierEmptyOrdinal ? nil : ordinal,
        proposedGasKelvin: thermal.carrier.gasKelvin,
        proposedBodyReferenceKelvin: ordinal == thermal.custody.carrierEmptyOrdinal ? nil : thermal.carrier.bodyReferenceKelvin)
    } + [UnitDefinition(location: .portable, proposedOriginalBodyOrdinal: thermal.custody.portableBodyOrdinal,
      proposedGasKelvin: thermal.portable.bodyAndGasKelvin,
      proposedBodyReferenceKelvin: thermal.portable.bodyAndGasKelvin)]
  }

  enum RuntimeDimension: String, CaseIterable, Equatable, Sendable {
    case actualIdentityAndCrewFitness, materialStrengthAndPhase, finitePreparationAndStockDebits
    case pressureSealSpeciesAndLeakage, absorberKineticsAndNearDepletion, thermalPathsAndSinkView
    case coldCircuitPhaseAndDeliveredFlow, carrierWarmDumpAndHeatPath
    case operatingVariableMassTensor, denseFourMaterialCurve, actualCommissioningAndClock
  }
  enum Refusal: Error, Equatable {
    case resourceSet, resourceIdentity(String), unavailableBase, incoherentDefinition
    case unsupportedRuntimeDimension(RuntimeDimension)
  }

  /// A declared budget, material allocation or two offline snapshots cannot
  /// supply any of these actual runtime owners. There is no constant fallback.
  func requireRuntimeSupport(_ dimension: RuntimeDimension) throws -> Never {
    throw Refusal.unsupportedRuntimeDimension(dimension)
  }
  /// The source energy ledger is corrected by exact8fba, not apparatus proof.
  /// Delivered phase/flow still needs its separate exact engineering child.
  var knownOpenSourceFindings: [RuntimeDimension] { [.coldCircuitPhaseAndDeliveredFlow] }
  var sourceQualifiedForBirth: Bool { false }
}
