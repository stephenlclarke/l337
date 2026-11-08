import Foundation
import Testing

@testable import L337Core

struct OriginalImpalaCrewFitUnitTests {
  @Test func originalImpalaUsesExactNativeTwoCrewTwoPlacesAnd26BudgetWithoutFreeFit() throws {
    let ship = try #require(ShipCatalogue.ship("SH007"))
    let profile = try ShipAccommodationProfile(ship: ship)
    #expect(profile.operatingCrew == 2 && profile.intrinsicCrewQuarters == 2)
    #expect(profile.equipmentUnits == 26 && profile.initialCharterBerths == 0)
    #expect(profile.crewStatus == "authored-r3-native-adapter")
    #expect(ship.profiles.count == 1)
    #expect(ship.profiles.first?.id == "ORIGINAL-IMPALA-R3-SH007")
    #expect(ship.profiles.first?.group == "original-r3-source-stage")
    #expect(ship.catalogue.purchasePolicy == .pendingFabrication)
    // Controlled scalar inputs test fitting arithmetic, not an acquired or paid 26-unit outfit.
    let exact = AccommodationFitting.evaluate(profile: profile, holdTonnes: 60,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 26,
      cabins: [], berths: [])
    let overflow = AccommodationFitting.evaluate(profile: profile, holdTonnes: 60,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 27,
      cabins: [], berths: [])
    #expect(exact.allowed && exact.freeEquipmentUnits == 0)
    #expect(!overflow.allowed)
    // Complete controlled empty layouts isolate the source maximum of 12 physical modules.
    var layout = ShipAccommodation()
    for _ in 0..<12 { layout.addCabin(.stateroomSingle) }
    try #require(layout.layoutValid)
    let twelve = AccommodationFitting.evaluate(profile: profile, holdTonnes: 75,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
      cabins: layout.fittedCabins, berths: layout.fittedBerths)
    layout.addCabin(.stateroomSingle)
    try #require(layout.layoutValid)
    let thirteen = AccommodationFitting.evaluate(profile: profile, holdTonnes: 75,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
      cabins: layout.fittedCabins, berths: layout.fittedBerths)
    #expect(twelve.allowed && twelve.usableCargo == 15)
    #expect(!thirteen.allowed && thirteen.usableCargo == 10 && thirteen.freeEquipmentUnits == 13)
  }

  @Test func originalImpalaNeedsOneActualPaidCrewMemberAndRetainsCurrentColdLoad() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    // Controlled ownership/funds; this is no fabrication or ship acquisition receipt.
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, shipID: "SH007")
    let before = await runtime.snapshot()
    try #require(before.docked && before.commander.valid)
    #expect(before.commander.nativeCrewMissing == 1)
    #expect(before.commander.assignedNativeCrew.isEmpty)
    #expect(before.commander.accommodation.ownedCabins.isEmpty)
    var refused = before
    refused.launch()
    #expect(refused.docked && refused.commander == before.commander)
    #expect(refused.bodies == before.bodies)
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    let paid = await runtime.snapshot()
    #expect(paid.commander.credits == before.commander.credits - 2000)
    #expect(paid.commander.assignedNativeCrew.count == 1 && paid.commander.nativeCrewMissing == 0)
    let person = try #require(paid.commander.assignedNativeCrew.first)
    #expect(person.location.place == 1 && person.location.hull == paid.commander.hullInstanceID)
    #expect(person.contract != nil)
    #expect(paid.commander.accommodation == before.commander.accommodation)
    try await runtime.save(to: storage.url)
    let cold = GameRuntime()
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander.nativePeople?.crewService == paid.commander.nativePeople?.crewService)
    #expect(loaded.commander.assignedNativeCrew.first == person)
    #expect(loaded.commander.credits == paid.commander.credits && loaded.commander.valid)
    try #require(loaded.docked)
    await cold.key("escape")
    await cold.key("0")
    let launched = await cold.snapshot()
    #expect(!launched.docked && launched.commander.valid)
    #expect(launched.commander.nativeCrewMissing == 0)
    #expect(launched.commander.assignedNativeCrew.first == person)
    #expect(launched.commander.ship.catalogue.purchasePolicy == .pendingFabrication)
  }

  @Test func originalImpalaActualPaidFittingUsesNativeBudgetAndSurvivesCurrentSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, shipID: "SH007")
    var game = await runtime.snapshot()
    let before = game.commander
    let source = game.commander.nativePeople
    let item = try #require(Equipment.all.first { $0.name == "Fuel Scoops" })
    let quote = try game.quoteEquipmentPurchase(item)
    #expect(game.commander == before)
    let purchased = try game.applyEquipmentPurchase(quote)
    try #require(purchased)
    #expect(game.commander.credits == before.credits - quote.purchase.requiredDebit)
    #expect(game.commander.commonEquipmentUnits == before.commonEquipmentUnits + 1)
    #expect(game.commander.passengerFit?.allowed == true)
    #expect(game.commander.nativePeople == source && game.commander.assignedNativeCrew.isEmpty)
    #expect(game.commander.accommodation.ownedCabins.isEmpty && game.commander.fuel == before.fuel)
    #expect(game.commander.nativeCrewMissing == 1 && game.commander.valid)
    let inventory = game.commander.equipmentInventory
    let history = game.commander.equipmentPurchaseHistory
    let writer = GameRuntime(game: game, saveURL: storage.url)
    try await writer.save(to: storage.url)
    let cold = GameRuntime()
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander.equipmentInventory == inventory)
    #expect(loaded.commander.equipmentPurchaseHistory == history)
    #expect(loaded.commander.nativePeople == source)
    #expect(loaded.commander.credits == game.commander.credits)
    #expect(loaded.commander.nativeCrewMissing == 1 && loaded.commander.valid)
    #expect(try ShipAccommodationProfile(ship: loaded.commander.ship).equipmentUnits == 26)
  }
}
