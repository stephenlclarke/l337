import Foundation

/// The single approved SH061 activation; other original hulls keep their own blockers.
enum OriginalSaigaActivation {
  static let id = "SH061"
  static let specificationSHA256 =
    "a5b9e65f897bebac9f94ab7ba88c5f38908bf13da7c85c5c3eff5b74ed96a4a4"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Saiga" && definition.family == "saiga"
      && definition.role == "trader" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.saiga.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 20,
      physical.model.coordinateUnits == nil
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
