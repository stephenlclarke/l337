import Foundation
import TOMLDecoder

/// Exact original SH007 source projection. Pending acquisition and fitting are not
/// made ready by decoding geometry or an authored performance profile.
enum OriginalImpalaVoyagerActivation {
  static let id = "SH007"
  static let specificationSHA256 =
    "362f40c5d357d80c6559090d528a09f71858e09155b162996902c10aa4c7ff63"
  static let resourceSHA256 =
    "ff6069c1f22ffb1873d42de721f8a6c6bfb7c214d2043d7e291440a69b850490"
  static let minimumBuildTechLevel = 14

  enum Failure: Error { case unsupportedDefinition }

  private static let originalResource: Result<CatalogueShip, any Error> = Result {
    let data = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
    guard ScriptPackLibrary.hash(data) == resourceSHA256 else {
      throw Failure.unsupportedDefinition
    }
    let ship = try TOMLDecoder().decode(CatalogueShip.self, from: data)
    guard ship.id == id, ship.name == "Impala Voyager", ship.catalogue.family == "impala",
      ship.catalogue.purchasePolicy == .pendingFabrication,
      ship.catalogue.minimumBuildTechLevel == minimumBuildTechLevel,
      ship.catalogue.mechanicsStatus == .pending, !ship.catalogue.normalPurchaseEligible,
      ship.nativeHull == nil, ship.nativeDesign?.valid == true, ship.game?.valid == true
    else { throw Failure.unsupportedDefinition }
    return ship
  }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    guard let original = try? originalResource.get() else { return false }
    return definition.id == id && definition.name == "Impala Voyager"
      && definition.family == "impala" && definition.role == "leisure"
      && definition.playerFlyable && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance == original.game
  }

  static func authenticates(_ ship: CatalogueShip) -> Bool {
    guard ship.id == id, let original = try? originalResource.get() else { return false }
    return ship == original
  }

  /// Bare original hold declaration only. Actual purchased expansion and cabins
  /// are owned fitting state and remain subject to their separate current consumer.
  static func validEffectiveCargo(_ ship: CatalogueShip) -> Bool {
    guard authenticates(ship), let performance = ship.game,
      ship.profiles.count == 1, let profile = ship.profiles.first,
      profile.id == "ORIGINAL-IMPALA-R3-SH007", profile.group == "original-r3-source-stage",
      Set(profile.fields.map(\.key)).count == profile.fields.count
    else { return false }
    func integer(_ key: String, unit: String) -> Double? {
      let fields = profile.fields.filter { $0.key == key }
      guard fields.count == 1, let field = fields.first, field.unit == unit,
        let value = field.number, value.isFinite, value >= 0, value.rounded() == value
      else { return nil }
      return value
    }
    return integer("original.r3.performance.cargoTonnes", unit: "source r3 units")
        == Double(performance.cargo)
      && integer("original.r3.performance.cargoExpansionTonnes", unit: "source r3 units")
        == Double(performance.cargoExpansion)
      && integer("original.r3.accommodation.initialPurchasedCabins",
        unit: "source r3 places/modules") == 0
      && performance.cargo == 60 && performance.cargoExpansion == 15
      && performance.cargo >= ship.catalogue.minimumStandardCargoTonnes
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id), supports(definition),
      authenticates(retained)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.impalaVoyager.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1, physical.model.coordinateUnits == "metres",
      retained.nativeDesign == physical.model.nativeDesign
    else { throw Failure.unsupportedDefinition }
    // Keep the complete own resource/profile. The shared older fit projection would
    // restore superseded values and mark unfinished mechanics ready.
    return retained
  }
}
