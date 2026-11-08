import Foundation
import Testing

@testable import L337Core

struct EMPCrewSourceClassificationTests {
  @Test(arguments: ["SH025", "SH031", "SH124", "SH125", "SH162", "SH028"])
  func nativeCrewClassesUseCurrentDeclarationsWithoutIssuingPeople(id: String) throws {
    let source = try #require(OriginalFleetR3Data.contract(for: id))
    let ship = try #require(ShipCatalogue.ship(id))
    try #require(source.name == ship.name && source.family == ship.catalogue.family)
    let expected = ["SH025", "SH031", "SH124"].contains(id)
    #expect(EMPState.hasSupportedCrew(ship) == expected)
    #expect(EMPState.declaredNativeCrewCount(ship) == source.accommodation?.nativeCrew)
    if id == "SH125" {
      let crew = try #require(source.accommodation)
      #expect(crew.nativeAutonomous && crew.nativeCrew == 0 && crew.conversionCrew > 0)
    }
    if id == "SH162" {
      #expect(source.objectKind != .ship && source.accommodation == nil)
    }
    // This checks metadata classification, not actor, people, EMP or geometry readiness.
  }

  @Test(arguments: ["renamed-drone", "unknown-id"])
  func descriptorNamesCannotCreateACurrentNativeCrewClass(condition: String) throws {
    let id = condition == "renamed-drone" ? "SH125" : "SH025"
    let ship = try #require(ShipCatalogue.ship(id))
    if condition == "unknown-id" { try #require(EMPState.hasSupportedCrew(ship)) }
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    if condition == "renamed-drone" {
      object["name"] = "Uncrewed Utility Craft"
    } else {
      object["id"] = "UNKNOWN-CURRENT-SOURCE"
    }
    let changed = try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!EMPState.hasSupportedCrew(changed))
    #expect(EMPState.declaredNativeCrewCount(changed) == nil)
  }
}
