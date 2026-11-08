import Foundation
import Testing

@testable import L337Core

struct OriginalFleetR3ObjectDomainUnitTests {
  @Test func environmentPurposesDoNotBecomeShipPerformanceCrewOrPurchaseRights() throws {
    let stations = ["SH028", "SH034", "SH102", "SH141", "SH161", "SH164"]
    for id in stations + ["SH156", "SH162"] {
      let object = try #require(OriginalFleetR3Data.contract(for: id))
      let environment = try #require(object.environment)
      #expect(!environment.playerCrewRequired && environment.purchasePolicy == .never)
      #expect(object.purchasePolicy == .never && !object.playerFlyable)
      #expect(object.performance == nil && object.accommodation == nil && object.fitting == nil)
      #expect(object.acquisition == nil)
      if stations.contains(id) {
        #expect(object.objectKind == .station && environment.physicalService == .stationServices)
      } else if id == "SH156" {
        #expect(object.objectKind == .platform && environment.physicalService == .weaponsPlatform)
      } else {
        #expect(object.objectKind == .other && environment.physicalService == .missionProbe)
      }
    }
    // Missing accommodation means unissued native population; it is not a zero-person census.
    // These declarations contain no actual station provider, port, pose or receiving authority.
    #expect(OriginalFleetR3Data.ids.compactMap {
      OriginalFleetR3Data.contract(for: $0)?.environment
    }.count == 8)
  }

  @Test func autonomousNativeDroneAndPlayerConversionHaveSeparateExplicitStaffing() throws {
    let drone = try #require(OriginalFleetR3Data.contract(for: "SH125"))
    let crew = try #require(drone.accommodation)
    #expect(drone.origin == .larvaal && drone.origin.catalogueOrigin == .alien)
    #expect(crew.nativeAutonomous && crew.nativeCrew == 0)
    #expect(crew.conversionCrew == 1 && crew.intrinsicCrewPlaces == 1)
    #expect(crew.initialPurchasedCabins == 0 && drone.fitting?.roleKitIncluded == false)
    let human = try #require(OriginalFleetR3Data.contract(for: "SH025"))
    #expect(human.origin == .human && human.origin.catalogueOrigin == .human)
    #expect(human.accommodation?.nativeAutonomous == false)
  }

  @Test func capsuleZeroJumpAndWeaponCapabilitiesRemainAnExplicitCapsuleContract() throws {
    let capsule = try #require(OriginalFleetR3Data.contract(for: "SH040"))
    let performance = try #require(capsule.performance)
    #expect(capsule.objectKind == .capsule && capsule.origin == .human)
    #expect(capsule.playerFlyable && capsule.purchasePolicy == .never && capsule.acquisition == nil)
    #expect(performance.cargo == 0 && performance.fuel == 0 && performance.jump == 0)
    #expect(performance.spool == 0 && performance.missiles == 0 && performance.facings == 0)
    #expect(capsule.accommodation?.nativeCrew == 1 && capsule.accommodation?.maximumCabins == 0)
    #expect(capsule.fitting?.equipmentUnits == 0 && capsule.fitting?.utilityMounts == 0)
    #expect(!performance.valid)  // The ordinary ship fitting/drive path cannot admit a capsule.
  }

  @Test func anUntrustedOriginCannotReuseAnOtherwiseMatchingCurrentShipFit() throws {
    let ship = try #require(ShipCatalogue.ship("SH005"))
    #expect(OriginalFleetR3Fitting.contract(for: ship)?.origin == .human)
    let data = try JSONEncoder().encode(ship)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var catalogue = try #require(object["catalogue"] as? [String: Any])
    catalogue["origin"] = "alien"
    object["catalogue"] = catalogue
    let changed = try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(OriginalFleetR3Fitting.contract(for: changed) == nil)
    #expect(throws: (any Error).self) { try ShipAccommodationProfile(ship: changed) }
  }

  @Test func untrustedQuoteValuesCannotReplaceCanonicalPricesFittingsOrPendingPolicy() throws {
    var game = Game(executive: false)
    game.commander.credits = 10_000_000
    let before = game.commander
    for id in ["SH018", "SH007"] {
      let ship = try #require(ShipCatalogue.ship(id))
      let expected = try #require(game.shipTradeQuote(for: ship))
      var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
      var performance = try #require(object["game"] as? [String: Any])
      performance["price"] = 1
      performance["cargo"] = 100_000
      object["game"] = performance
      var catalogue = try #require(object["catalogue"] as? [String: Any])
      catalogue["purchasePolicy"] = "xyzzyOnly"
      catalogue["mechanicsStatus"] = "ready"
      object["catalogue"] = catalogue
      let requested = try JSONDecoder().decode(
        CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
      let quote = try #require(game.shipTradeQuote(for: requested))
      #expect(quote.selected == expected.selected && quote.selected == ship)
      #expect(quote.purchase == expected.purchase && quote.net == expected.net)
      #expect(quote.balance == expected.balance && quote.issues == expected.issues)
      #expect(!quote.allowed && game.commander == before)
      if id == "SH007" { #expect(quote.selected.catalogue.purchasePolicy == .pendingFabrication) }
      object["id"] = "SH999"
      let unknown = try JSONDecoder().decode(
        CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(game.shipTradeQuote(for: unknown) == nil && game.commander == before)
    }
  }
}
