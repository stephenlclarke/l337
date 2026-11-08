import Testing

@testable import L337Core

struct OriginalPeregrineR3UnitTests {
  @Test func starterSupportsPaidRecoveryToolsWithoutGrantingThem() throws {
    let ship = try #require(ShipCatalogue.ship("SH025"))
    let game = try #require(ship.game)
    #expect(game.recharge == 4.2 && game.price == 362000)
    #expect(game.workTools == [.salvageCutter])
    let places = try ShipAccommodationProfile(ship: ship)
    #expect(places.equipmentUnits == 24 && places.operatingCrew == 1)
    #expect(places.intrinsicCrewQuarters == 1 && places.initialCharterBerths == 0)
    let starter = Commander()
    #expect(starter.shipID == "SH025")
    #expect(starter.fittedEquipment(at: .utility(.salvageCutter)) == nil)
    #expect(starter.fleetBlueprintAcquisition(for: "SH025") == nil)
    #expect(starter.fleetBlueprintAcquisition(for: "SH005") == nil)
  }
}
