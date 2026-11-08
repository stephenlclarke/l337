import Foundation
import Testing

@testable import L337Core

/// Controlled fitting units, independent of native acquisition or travel acceptance.
struct OriginalFleetR3FittingUnitTests {
  @Test func deliveredFitsUseCurrentPerHullBudgetsAndPhysicalCabinCeilings() throws {
    for (id, units, cabins, mounts) in [
      ("SH025", 24, 18, 3), ("SH005", 48, 221, 4), ("SH006", 54, 244, 4),
      ("SH013", 30, 79, 3), ("SH014", 34, 92, 3), ("SH026", 14, 3, 2),
    ] {
      let ship = try #require(ShipCatalogue.ship(id))
      let source = try #require(OriginalFleetR3Fitting.contract(for: ship))
      let profile = try ShipAccommodationProfile(ship: ship)
      #expect(profile.equipmentUnits == units && profile.maximumPhysicalCabinModules == cabins)
      #expect(source.fitting?.utilityMounts == mounts)
      #expect(profile.initialCharterBerths == 0)
      #expect(profile.crewStatus == "original-r3-current-fit")
    }
  }

  @Test func explicitNativeReservationsPreserveCurrentCostsWithoutCreatingEquipmentOrPeople() throws {
    for (id, planning, native, crew) in [
      ("SH013", 34, 30, 6), ("SH014", 38, 34, 7), ("SH026", 18, 14, 1),
    ] {
      let ship = try #require(ShipCatalogue.ship(id))
      let current = try #require(OriginalFleetR3Fitting.contract(for: ship))
      #expect(current.fitting?.equipmentUnits == planning)
      #expect(OriginalFleetR3Fitting.nativeEquipmentUnits(for: ship, contract: current) == native)
      let profile = try #require(NativeCrewService.adoptedAccommodation(id))
      #expect(profile.equipmentUnits == native && profile.operatingCrew == crew)
      var commander = Commander()
      commander.shipID = id  // Controlled empty fitting projection, not a purchase.
      try commander.prepareEquipment(legacy: false)
      #expect(commander.assignedNativeCrew.isEmpty && commander.nativeCrewMissing == crew - 1)
      #expect(commander.fittedEquipment(at: .utility(.salvageCutter)) == nil)
      #expect(commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
      var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
      var profiles = try #require(object["profiles"] as? [[String: Any]])
      let index = try #require(profiles.firstIndex { $0["group"] as? String == "project-refit-v1" })
      var fields = try #require(profiles[index]["fields"] as? [[String: Any]])
      let declaration = try #require(fields.firstIndex {
        $0["key"] as? String == "fleet_r3_planning_budget_including_structural_reservation"
      })
      fields[declaration]["number"] = planning + 1
      profiles[index]["fields"] = fields
      object["profiles"] = profiles
      let changed = try JSONDecoder().decode(
        CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(OriginalFleetR3Fitting.contract(for: changed) == nil)
      #expect(throws: (any Error).self) { try ShipAccommodationProfile(ship: changed) }
    }
  }

  @Test func paidFourthUtilityRefusesUntilAnExistingDeviceIsActuallyHeld() throws {
    var game = Game(executive: false)
    game.commander.system = 69
    game.selectedSystem = 69
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 1_000_000
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.shipID == "SH025" && !game.commander.unlimitedCash)
    for name in [Equipment.empPirateBlaster, "Salvage Cutter", "Fuel Scoops"] {
      let item = try #require(Equipment.all.first { $0.name == name })
      let before = game.commander
      let quote = try game.quoteEquipmentPurchase(item)
      let equipmentPurchased = try game.applyEquipmentPurchase(quote)
      try #require(equipmentPurchased)
      #expect(game.commander.credits == before.credits - quote.purchase.requiredDebit)
    }
    let fourth = try #require(Equipment.all.first { $0.name == "E.C.M. System" })
    let before = game.commander
    #expect(throws: EquipmentRuntimeError.incompatibleFit) {
      try game.quoteEquipmentPurchase(fourth)
    }
    #expect(game.commander == before)
    // Move the already paid cutter to held custody in this controlled fit projection.
    let inventory = try #require(before.equipmentInventory)
    let cutter = try #require(before.fittedEquipment(at: .utility(.salvageCutter)))
    var held = before
    held.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == cutter.id ? $0.moved(to: nil) : $0 },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: before.performance))
    held.mirrorFittedEquipment()
    try #require(held.valid)
    #expect(held.equipmentInventory?.items.first { $0.id == cutter.id }?.provenance == cutter.provenance)
    game.commander = held
    let quote = try game.quoteEquipmentPurchase(fourth)
    let equipmentPurchased = try game.applyEquipmentPurchase(quote)
    try #require(equipmentPurchased)
    #expect(game.commander.fittedEquipment(at: .utility(.ecm)) != nil)
    #expect(game.commander.fittedEquipment(at: .utility(.salvageCutter)) == nil)
    #expect(game.commander.valid)
  }

  @Test(arguments: ["SH008", "SH009"])
  func pendingHullRejectsEquipmentPreparationBeforeAnyPerformanceRead(_ id: String) {
    var commander = Commander()
    commander.shipID = id
    let before = commander
    #expect(throws: (any Error).self) { try commander.validateEquipmentState() }
    #expect(throws: (any Error).self) { try commander.prepareEquipment() }
    #expect(commander == before)
  }
}
