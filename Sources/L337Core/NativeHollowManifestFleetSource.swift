import Foundation

/// Current engineering sources only. This grants no owned fitting, crew, accommodation,
/// acquisition right, native actor or mission receipt.
enum NativeHollowManifestFleetSource {
  enum Role: CaseIterable, Sendable {
    case inspectionFreighter, custodyCarrier, evacuationLaunch

    var id: String {
      switch self {
      case .inspectionFreighter: "SH018"
      case .custodyCarrier: "SH029"
      case .evacuationLaunch: "SH061"
      }
    }
  }

  struct Profile: Sendable {
    let current: OriginalFleetR3Contract
    let performance: ShipPerformance
    let accommodation: OriginalFleetR3Contract.Accommodation
    let fitting: OriginalFleetR3Contract.Fitting
    let physical: OriginalHullPhysicalContract
  }

  static func resolve(_ role: Role) throws -> Profile {
    switch role {
    case .inspectionFreighter: try inspectionFreighter.get()
    case .custodyCarrier: try custodyCarrier.get()
    case .evacuationLaunch: try evacuationLaunch.get()
    }
  }

  private static let inspectionFreighter = Result { try prepare(.inspectionFreighter) }
  private static let custodyCarrier = Result { try prepare(.custodyCarrier) }
  private static let evacuationLaunch = Result { try prepare(.evacuationLaunch) }

  private static func prepare(_ role: Role) throws -> Profile {
    let physical: OriginalHullPhysicalContract
    switch role {
    case .inspectionFreighter: physical = try OriginalHullPhysicalContract.onager.get()
    case .custodyCarrier: physical = try OriginalHullPhysicalContract.okapi.get()
    case .evacuationLaunch: physical = try OriginalHullPhysicalContract.saiga.get()
    }
    guard let current = OriginalFleetR3Data.contract(for: role.id),
      let definition = OriginalFleetDefinitionData.definition(for: role.id),
      let performance = current.performance, performance.valid,
      let accommodation = current.accommodation, let fitting = current.fitting,
      definition.id == current.id, physical.id == current.id,
      definition.name == current.name, physical.name == current.name,
      definition.family == current.family, definition.role == current.classification,
      definition.sourceSHA256 == current.sourceSHA256,
      physical.specificationSHA256 == current.sourceSHA256,
      physical.model.sourceSHA256 == current.referencedGeometrySHA256,
      definition.nativePerformance == performance, definition.approvedMeshAvailable,
      definition.playerFlyable == current.playerFlyable,
      definition.purchasePolicy == current.purchasePolicy.rawValue,
      accommodation.operatingCrew > 0,
      accommodation.intrinsicCrewPlaces >= accommodation.operatingCrew,
      accommodation.initialPurchasedCabins == 0, !fitting.roleKitIncluded
    else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    return .init(
      current: current, performance: performance, accommodation: accommodation,
      fitting: fitting, physical: physical)
  }
}
