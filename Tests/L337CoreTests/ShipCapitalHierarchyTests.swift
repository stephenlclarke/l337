import Foundation
import Testing

@testable import L337Core

struct ShipCapitalHierarchyTests {
  @Test func stationsAreCapitalChildrenWithoutBecomingDestructionTargets() throws {
    let stationIDs = Set(["SH028", "SH034", "SH102", "SH141", "SH161", "SH164"])
    let expectedDamagePolicies: [String: ShipCatalogueDamagePolicy] = [
      "SH028": .activeStationIndestructible,
      "SH034": .destructible,
      "SH102": .destructible,
      "SH141": .destructible,
      "SH161": .destructible,
      "SH164": .destructible,
    ]
    let capitals = ShipCatalogue.all.filter { $0.catalogue.isCapital }
    #expect(capitals.count == 10)
    #expect(
      Set(capitals.filter { $0.catalogue.capitalSubtype == .station }.map(\.id)) == stationIDs)
    #expect(
      Set(capitals.filter { $0.catalogue.capitalSubtype == .vessel }.map(\.id))
        == Set(["SH043", "SH081", "SH123"]))
    for id in stationIDs {
      let ship = try #require(ShipCatalogue.ship(id))
      let metadata = ship.catalogue
      #expect(metadata.isCapital && metadata.capitalSubtype == .station)
      #expect(metadata.objectKind == .station || metadata.objectKind == .platform)
      // Damage policy is per source; station collection still requires docking.
      let expectedDamagePolicy = try #require(expectedDamagePolicies[id])
      #expect(metadata.collectionMilestone == .docking)
      #expect(metadata.damagePolicy == expectedDamagePolicy)
      #expect(metadata.purchasePolicy == .never && metadata.minimumBuildTechLevel == nil)
      #expect(metadata.valid(shipID: id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
    let platform = try #require(ShipCatalogue.ship("SH156"))
    #expect(platform.catalogue.objectKind == .platform)
    #expect(platform.catalogue.isCapital && platform.catalogue.capitalSubtype == .platform)
    #expect(platform.catalogue.collectionMilestone == .none && !platform.catalogue.discoveryEligible)
    #expect(platform.catalogue.purchasePolicy == .never && !platform.catalogue.playerFlyable)
    #expect(OriginalDetailedHullStage.blocksRuntime(platform.id))
    #expect(ShipCatalogue.ship("SH161")?.catalogue.objectKind == .station)
  }

  @Test func hierarchyDoesNotAddDuplicateCollectionEntriesOrAnotherDisplayedType() throws {
    let ships = ShipCatalogue.all
    #expect(ships.count == 171 && Set(ships.map(\.id)).count == ships.count)
    let eligible = ships.filter { $0.catalogue.discoveryEligible }
    #expect(eligible.count == 167 && Set(eligible.map(\.id)).count == eligible.count)
    #expect(ShipCatalogueType.allCases.count == 8 && ShipCatalogueRole.allCases.count == 7)
    for ship in ships where !ship.catalogue.isCapital {
      #expect(ship.catalogue.capitalSubtype == nil)
    }
    for id in ["SH005", "SH006"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(!metadata.isCapital && metadata.purchasePolicy == .blueprintFabrication)
      #expect(metadata.normalPurchaseEligible && metadata.mechanicsStatus == .ready)
    }
    for id in ["SH013", "SH014"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(!metadata.isCapital && metadata.purchasePolicy == .pendingFabrication)
      #expect(!metadata.normalPurchaseEligible)
    }
    for id in ["SH078", "SH079", "SH155"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(!metadata.isCapital && metadata.purchasePolicy == .pendingFabrication)
    }
    let medusa = try #require(ShipCatalogue.ship("SH171"))
    #expect(!medusa.catalogue.isCapital && medusa.catalogue.capitalSubtype == nil)
    #expect(
      medusa.catalogue.primaryType == .alien && medusa.catalogue.purchasePolicy == .never)
  }

  @Test func parentCapitalNeverOverridesTheStationMilestone() throws {
    for (id, key, value) in [
      ("SH028", "isCapital", false as Any),
      ("SH028", "capitalSubtype", "vessel" as Any),
      ("SH043", "capitalSubtype", "station" as Any),
      ("SH028", "collectionMilestone", "destruction" as Any),
      ("SH028", "damagePolicy", "destructible" as Any),
    ] {
      let ship = try #require(ShipCatalogue.ship(id))
      let data = try JSONEncoder().encode(ship.catalogue)
      var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      object[key] = value
      let changed = try JSONDecoder().decode(
        ShipCatalogueMetadata.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!changed.valid(shipID: id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
  }
}
