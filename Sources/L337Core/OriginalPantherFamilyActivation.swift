import Foundation

/// These two approved variants have different roles; family membership grants no readiness.
enum OriginalPantherFamilyActivation {
  struct Registration: Sendable {
    let id: String
    let name: String
    let role: ShipCatalogueRole
    let specificationSHA256: String
    let modelSHA256: String
    var modelPath: String {
      "fleet-completion-20261019/batch-01-native-lod/" + id + "-design.toml"
    }
  }

  static func registration(for id: String) -> Registration? {
    switch id {
    case "SH032":
      return .init(
        id: id, name: "Panther Explorer", role: .leisure,
        specificationSHA256: "9bbbecb8af20c7c20d0d95e0a1d82aeb27950d4a6243329af3a0e6848ecd3a6f",
        modelSHA256: "d87094362d608526b5e257173478f305b0b2f786d573abdb51f7ef613a4bb131")
    case "SH033":
      return .init(
        id: id, name: "Panther Scout", role: .military,
        specificationSHA256: "f2e0376401c62989cac6f1faad27d484e53627008818dabe0e49ae2e3f194c76",
        modelSHA256: "2bdbe5b0f70a0d0316d8288d73457f96364fdad930fd7b746ce311437dacf435")
    default: return nil
    }
  }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    guard let approved = registration(for: definition.id) else { return false }
    return definition.name == approved.name && definition.family == "panther"
      && definition.role == approved.role.rawValue && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == approved.specificationSHA256
      && definition.approvedMeshAvailable && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard registration(for: retained.id) != nil else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: retained.id),
      supports(definition)
    else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    let physical: OriginalHullPhysicalContract
    switch retained.id {
    case "SH032": physical = try OriginalHullPhysicalContract.pantherExplorer.get()
    case "SH033": physical = try OriginalHullPhysicalContract.pantherScout.get()
    default: throw OriginalHullPhysicalContract.Failure.unsupportedSource
    }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
