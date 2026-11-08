import Foundation
import Testing

@testable import L337Core

struct OriginalEnvironmentSourceTests {
  @Test(arguments: ["SH156", "SH161", "SH162", "SH164"])
  func originalNonshipResourcesRetainTheirPurposeWithoutIssuingRuntimeServices(id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let source = try #require(OriginalFleetR3Data.contract(for: id))
    let environment = try #require(source.environment)
    let entry = try #require(OriginalDetailedHullStage.registration(for: id))
    let native = try #require(ship.nativeDesign)
    #expect(ship.name == source.name && ship.catalogue.family == source.family)
    #expect(ship.catalogue.objectKind == source.objectKind)
    #expect(ship.catalogue.origin == source.origin.catalogueOrigin)
    #expect(ship.game == nil && source.performance == nil)
    #expect(source.accommodation == nil && source.fitting == nil && source.acquisition == nil)
    #expect(!environment.playerCrewRequired && environment.purchasePolicy == .never)
    #expect(ship.catalogue.purchasePolicy == .never && !ship.catalogue.normalPurchaseEligible)
    #expect(!ship.catalogue.playerFlyable && !ship.catalogue.readyForNaturalEncounters)
    #expect(ship.catalogue.mechanicsStatus == .pending && ship.catalogue.placementStatus == .pending)
    #expect(ship.catalogue.roleWeights.isEmpty && ship.catalogue.galaxies.isEmpty)
    #expect(ship.catalogue.regions.isEmpty && ship.catalogue.aliases?.isEmpty == true)
    #expect(ship.nativeHull == nil && ship.nativeCombat == nil && ship.nativeDocking == nil)
    #expect(ship.profiles.count == 1 && ship.profiles[0].group == "original-r3-source-stage")
    #expect(ship.design.vertices.count == entry.detailedVertices)
    #expect(ship.design.faces.count == entry.detailedFaces)
    #expect(native.faces.count == entry.sourceNativeFaces && native.faces.count > 512)
    #expect(ship.design.materials?.isEmpty == false && native.materials?.isEmpty == false)
    #expect(ship.catalogue.valid(shipID: id, performance: nil, nativeCombat: nil))
    #expect(try OriginalDetailedHullStage.resolvePending(ship).id == id)
    #expect(OriginalFleetR3Fitting.contract(for: ship) == nil)
    #expect(throws: (any Error).self) { try ShipAccommodationProfile(ship: ship) }
    #expect(!EMPState.hasSupportedCrew(ship))
    #expect(!OriginalStationSite.allCases.contains { $0.catalogueID == id })
    #expect(ShipCatalogue.rawMesh(id) == nil)
    #expect(SalvageCatalogue.profile(catalogueShipID: id) == nil)
    #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
    #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .unsupportedHull)
    if id == "SH156" {
      #expect(ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .platform)
      #expect(ship.catalogue.capitalSubtype != .station)
      #expect(ship.catalogue.collectionMilestone == .none && !ship.catalogue.discoveryEligible)
      #expect(environment.physicalService == .weaponsPlatform)
    } else if id == "SH162" {
      #expect(!ship.catalogue.isCapital && ship.catalogue.capitalSubtype == nil)
      #expect(ship.catalogue.collectionMilestone == .none && !ship.catalogue.discoveryEligible)
      #expect(environment.physicalService == .missionProbe)
    } else {
      #expect(ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .station)
      #expect(ship.catalogue.collectionMilestone == .docking && ship.catalogue.discoveryEligible)
      #expect(ship.catalogue.damagePolicy == .destructible)
      #expect(environment.physicalService == .stationServices)
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: id, actualSourceFaces: entry.sourceNativeFaces, maximum: 512))
    { try OriginalDetailedHullStage.requireRuntime(id) }
    let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
    try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
    var changed = bytes
    changed.append(0)
    #expect(throws: (any Error).self) {
      try OriginalDetailedHullStage.authenticate(ship, bytes: changed)
    }
    // No actual provider, port, population census, power or occupied body is created here.
    #expect(OriginalFleetPendingSourceRegistrations.records.count == 49)
  }

  @Test(
    arguments: ["SH156", "SH161", "SH162", "SH164"],
    ["foreign-origin", "ordinary-ship", "fake-performance", "wrong-purpose", "missing-native"])
  func pendingEnvironmentCannotBecomeAShipOrBorrowAnotherPurpose(id: String, condition: String)
    throws
  {
    let ship = try #require(ShipCatalogue.ship(id))
    _ = try OriginalDetailedHullStage.resolvePending(ship)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    switch condition {
    case "foreign-origin":
      var metadata = try #require(object["catalogue"] as? [String: Any])
      metadata["origin"] = ship.catalogue.origin == .human ? "alien" : "human"
      object["catalogue"] = metadata
    case "ordinary-ship":
      var metadata = try #require(object["catalogue"] as? [String: Any])
      metadata["objectKind"] = "ship"
      object["catalogue"] = metadata
    case "fake-performance":
      let ordinary = try #require(OriginalFleetR3Data.contract(for: "SH025")?.performance)
      object["game"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ordinary))
    case "wrong-purpose":
      var profiles = try #require(object["profiles"] as? [[String: Any]])
      var fields = try #require(profiles[0]["fields"] as? [[String: Any]])
      let index = try #require(fields.firstIndex { $0["key"] as? String == "original.environment.physicalService" })
      fields[index]["text"] = "unissued-other-service"
      profiles[0]["fields"] = fields
      object["profiles"] = profiles
    case "missing-native": object.removeValue(forKey: "nativeDesign")
    default:
      Issue.record("Unknown controlled pending environment source condition")
      return
    }
    let changed = try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(throws: (any Error).self) { try OriginalDetailedHullStage.resolvePending(changed) }
    #expect(try OriginalDetailedHullStage.resolvePending(ship).id == id)
    #expect(ship.game == nil && ship.nativeDocking == nil)
  }
}
