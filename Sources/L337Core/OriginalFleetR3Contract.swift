import Foundation

/// Current per-ID engineering requirements. A contract is not native geometry or activation.
struct OriginalFleetR3Contract: Sendable {
  enum Origin: String, Sendable {
    case human, larvaal

    var catalogueOrigin: ShipCatalogueOrigin {
      switch self {
      case .human: .human
      case .larvaal: .alien
      }
    }
  }

  enum PurchasePolicy: String, Sendable {
    case blueprintFabrication, plughQuestFabrication, never
  }

  /// An authored environment purpose does not install a provider, port or native population.
  struct Environment: Sendable {
    enum PhysicalService: String, Sendable {
      case stationServices = "station-services"
      case weaponsPlatform = "weapons-platform"
      case missionProbe = "mission-probe"
    }

    let playerCrewRequired: Bool
    let purchasePolicy: PurchasePolicy
    let physicalService: PhysicalService
  }

  struct Accommodation: Sendable {
    let operatingCrew: Int
    let intrinsicCrewPlaces: Int
    let nativeAutonomous: Bool
    let nativeCrew: Int
    let conversionCrew: Int
    let initialPurchasedCabins: Int
    let cabinMassTonnes: Double
    let cabinEquipmentUnits: Int
    let maximumCabins: Int
  }

  struct Fitting: Sendable {
    let equipmentUnits: Int
    let utilityMounts: Int
    let compatibleUtilities: [String]
    let recommendedRoleKit: [String]
    let roleKitIncluded: Bool
    let passengerCabinGrades: [String]
    let externalMissilePylons: Bool
  }

  struct Acquisition: Sendable {
    let method: String
    let receivedSampleMassKg: Double
    let destructionGrantsBlueprint: Bool
    let disableAloneGrantsBlueprint: Bool

    var requiresPhysicalIntake: Bool {
      method == "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop"
        && !destructionGrantsBlueprint && !disableAloneGrantsBlueprint
        && receivedSampleMassKg.isFinite && receivedSampleMassKg > 0
    }
  }

  let id: String
  let name: String
  let family: String
  let classification: String
  let objectKind: ShipCatalogueObjectKind
  let origin: Origin
  let environment: Environment?
  let playerFlyable: Bool
  let purchasePolicy: PurchasePolicy
  let sourceSHA256: String
  /// R3 references only; later verified per-ID physical geometry remains independently owned.
  let referencedGeometrySHA256: String
  let performance: ShipPerformance?
  let accommodation: Accommodation?
  let fitting: Fitting?
  let acquisition: Acquisition?
}
