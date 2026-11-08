import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

/// Existing source routes with current specifications; these units do not prove paid acquisition.
struct OriginalBaselineR3ActivationUnitTests {
  @Test func baselineSourcesKeepTheirCurrentIdentityDetailedGeometryAndEmptyFitRequirements() throws {
    for id in OriginalPlayerHullActivation.resourceSHA256.keys.sorted() {
      let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
      let raw = try TOMLDecoder().decode(CatalogueShip.self, from: bytes)
      let ship = try #require(ShipCatalogue.ship(id))
      let current = try #require(OriginalFleetR3Data.contract(for: id))
      let definition = try #require(ship.originalDefinition)
      let physical = try #require(ship.physicalSourceContract)
      let fit = try #require(OriginalFleetR3Fitting.contract(for: ship))
      try OriginalPlayerHullActivation.authenticateBaseline(raw, bytes: bytes)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.authenticateBaseline(raw, bytes: bytes + Data("\n".utf8))
      }
      #expect(raw.name == current.name && ship.name == current.name)
      #expect(raw.game == current.performance && ship.game == current.performance)
      #expect(ship.design == raw.design && ship.nativeDesign == raw.nativeDesign)
      #expect(ship.nativeDesign == physical.model.nativeDesign)
      #expect(definition.sourceSHA256 == current.sourceSHA256)
      #expect(definition.purchasePolicy == current.purchasePolicy.rawValue)
      #expect(fit.accommodation?.initialPurchasedCabins == 0 && fit.fitting?.roleKitIncluded == false)
      #expect(!ship.profiles.contains { $0.group.hasPrefix("historical-") })
      #expect(ship.catalogue.aliases?.isEmpty == true)
      let accommodation = try ShipAccommodationProfile(ship: ship)
      #expect(accommodation.operatingCrew == current.accommodation?.operatingCrew)
      #expect(accommodation.equipmentUnits == current.fitting?.equipmentUnits)
      #expect(accommodation.maximumPhysicalCabinModules == current.accommodation?.maximumCabins)
      #expect(accommodation.initialCharterBerths == 0)
      var commander = Commander()
      commander.shipID = id  // Controlled empty-fit projection, not a purchase or title claim.
      #expect(commander.fittedEquipment(at: .utility(.salvageCutter)) == nil)
      #expect(commander.fittedEquipment(at: .utility(.miningLaser)) == nil)
      #expect(commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
      #expect(commander.assignedNativeCrew.isEmpty)
      #expect(commander.nativeCrewMissing == max(0, accommodation.operatingCrew - 1))
    }
  }

  @Test func currentVariantBudgetsDoNotRegressToTheFormerCommonFitOrSiblingValues() throws {
    for (id, name, cargo, speed, price, crew, units, cabins) in [
      ("SH002", "Gyrfalcon Assault", 14, 44.8, 366000, 1, 16, 2),
      ("SH003", "Gyrfalcon Command", 28, 39.0, 397000, 3, 24, 5),
      ("SH004", "Gyrfalcon Patrol", 20, 44.0, 345000, 2, 18, 4),
      ("SH018", "Onager", 58, 39.0, 281000, 1, 16, 11),
      ("SH029", "Okapi", 60, 37.8, 312000, 1, 20, 12),
      ("SH061", "Saiga", 84, 32.7, 315000, 2, 22, 16),
      ("SH103", "Redtail Mk III", 26, 51.4, 409000, 2, 24, 5),
      ("SH108", "Besra", 24, 47.8, 380000, 2, 22, 4),
    ] {
      let ship = try #require(ShipCatalogue.ship(id))
      let fit = try ShipAccommodationProfile(ship: ship)
      #expect(ship.name == name && ship.game?.cargo == cargo && ship.game?.speed == speed)
      #expect(ship.game?.price == price && fit.operatingCrew == crew && fit.equipmentUnits == units)
      #expect(fit.maximumPhysicalCabinModules == cabins && fit.crewStatus == "original-r3-current-fit")
    }
    for oldName in ["Donkey", "Burro", "Haflinger"] {
      #expect(!ShipCatalogue.all.contains { $0.name == oldName || ($0.catalogue.aliases ?? []).contains(oldName) })
    }
  }
}
