import Foundation
import Testing

@testable import L337Core

struct OriginalFleetR3UtilitySourceValidationTests {
  @Test(arguments: ["SH029", "SH025"], [
    "missing-profile", "duplicate-profile", "missing-count", "duplicate-count", "wrong-count",
    "wrong-name", "wrong-family", "wrong-performance", "missing-performance",
  ])
  func malformedCurrentFitCannotSkipActualOwnedUtilityValidation(sourceID: String, condition: String) throws {
    // Existing unit setup uses an actual admitted original for its owned inventory; this
    // is not a purchase journey, a source alias or native permission for pending SH025.
    let admitted = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    var commander = Commander()
    commander.shipID = admitted.ship.id
    try commander.prepareEquipment(legacy: false)
    try #require(commander.shipID == "SH029" && commander.ship.name == "Okapi")
    let ownedShip = commander.ship
    let ship = try #require(ShipCatalogue.ship(sourceID))
    let inventory = try #require(commander.equipmentInventory)
    try #require(inventory.owner == commander.equipmentOwnerID)
    try #require(inventory.activeHull == commander.hullInstanceID)
    try #require(OriginalFleetR3Fitting.matchesCurrentMechanics(ship))
    try #require(OriginalFleetR3Fitting.contract(for: ship) != nil)
    try inventory.validate(context: EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance))
    try OriginalFleetR3Fitting.validateUtilities(inventory, ship: ownedShip)
    let source = try #require(OriginalFleetR3Fitting.contract(for: ship))
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.operatingCrew == source.accommodation?.operatingCrew)
    #expect(accommodation.intrinsicCrewQuarters == source.accommodation?.intrinsicCrewPlaces)
    if sourceID == "SH025" {
      // This exact current base has no pending-registration entry for SH025. Raw mesh
      // presence and runtime-source eligibility remain separate from that registry gate.
      try #require(OriginalDetailedHullStage.registration(for: sourceID) == nil)
      try #require(!OriginalDetailedHullStage.blocksRuntime(sourceID))
      try OriginalDetailedHullStage.requireRuntime(sourceID)
      #expect(ShipCatalogue.rawMesh(sourceID) != nil)
      #expect(OriginalFleetRuntimeHullSource.source(for: sourceID) == nil)
    } else {
      #expect(ship == ownedShip)
      try OriginalFleetR3Fitting.validateUtilities(inventory, ship: ship)
    }
    let before = commander

    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    var profiles = try #require(object["profiles"] as? [[String: Any]])
    let index = try #require(profiles.firstIndex { $0["group"] as? String == "project-refit-v1" })
    var fields = try #require(profiles[index]["fields"] as? [[String: Any]])
    let field = try #require(fields.firstIndex {
      $0["key"] as? String == "required_crew_including_commander"
    })
    switch condition {
    case "missing-profile": profiles.remove(at: index)
    case "duplicate-profile": profiles.append(profiles[index])
    case "missing-count":
      fields.remove(at: field)
      profiles[index]["fields"] = fields
    case "duplicate-count":
      fields.append(fields[field])
      profiles[index]["fields"] = fields
    case "wrong-count":
      fields[field]["number"] = -1
      profiles[index]["fields"] = fields
    case "wrong-name": object["name"] = ship.name + " altered source"
    case "wrong-family":
      var metadata = try #require(object["catalogue"] as? [String: Any])
      metadata["family"] = ship.catalogue.family + "-altered-source"
      object["catalogue"] = metadata
    case "wrong-performance":
      var game = try #require(object["game"] as? [String: Any])
      let performance = try #require(ship.game)
      try #require(performance.cargo < 100000)
      game["cargo"] = performance.cargo + 1
      object["game"] = game
    case "missing-performance": object.removeValue(forKey: "game")
    default:
      Issue.record("Unknown controlled fitting-source corruption")
      return
    }
    object["profiles"] = profiles
    let changed = try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
    try #require(changed.id == ship.id && OriginalFleetR3Data.contract(for: changed.id) != nil)
    let changedMechanics = ["wrong-name", "wrong-family", "wrong-performance", "missing-performance"]
      .contains(condition)
    #expect(OriginalFleetR3Fitting.matchesCurrentMechanics(changed) == !changedMechanics)
    try #require(OriginalFleetR3Fitting.contract(for: changed) == nil)
    #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics) {
      try OriginalFleetR3Fitting.validateUtilities(inventory, ship: changed)
    }
    #expect(throws: MissionPackError.self) { try ShipAccommodationProfile(ship: changed) }
    // The pending operand above is only a rejected source copy; it never claims this
    // inventory. The genuinely admitted owned original still validates unchanged.
    try OriginalFleetR3Fitting.validateUtilities(inventory, ship: ownedShip)
    let retainedAccommodation = try ShipAccommodationProfile(ship: ownedShip)
    let beforeAccommodation = try ShipAccommodationProfile(ship: before.ship)
    #expect(retainedAccommodation == beforeAccommodation)
    #expect(commander == before && commander.equipmentInventory == inventory)
  }
}
