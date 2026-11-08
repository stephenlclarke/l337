import Foundation
import Testing

@testable import L337Core

struct OriginalBisonFittingUnitTests {
  @Test(arguments: ["SH005", "SH006"])
  func freshBisonSaveLoadsCurrentPaidFitWithoutFreeRoleKit(shipID: String) async throws {
    let expected = try OriginalBisonFixture.expected(shipID)
    var game = try OriginalBisonFixture.game(shipID: shipID)
    #expect(game.commander.accommodation.ownedCabins.isEmpty)
    #expect(game.commander.accommodation.people.isEmpty)
    #expect(game.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
    #expect(game.commander.fittedEquipment(at: .utility(.salvageCutter)) == nil)
    let bought = try OriginalBisonFixture.buy("Fuel Scoops", in: &game)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    try await runtime.save(to: file)
    let published = await runtime.snapshot().commander
    #expect(published.shipID == shipID && published.ship.name == expected.name)
    #expect(published.nativePerformance == expected.performance)
    #expect(
      published.equipmentInventory?.items.contains { $0.id == bought.request.newItem } == true)
    #expect(published.accommodation.ownedCabins.isEmpty && published.accommodation.people.isEmpty)
    #expect(published.fittedEquipment(at: .utility(.salvageCutter)) == nil)
    let cold = GameRuntime()
    try await cold.load(from: file, persistMigrations: false)
    #expect(await cold.snapshot().commander == published)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: file) == published)
  }

  @Test(arguments: ["SH005", "SH006"])
  func actualPaidScoopCutterAndTanksKeepNativeCostsAndNoFuelMint(shipID: String) throws {
    let expected = try OriginalBisonFixture.expected(shipID)
    var game = try OriginalBisonFixture.game(shipID: shipID)
    let initial = game.commander
    let initialInventory = try #require(initial.equipmentInventory)
    #expect(initial.commonEquipmentUnits == 0)
    let profile = try ShipAccommodationProfile(ship: initial.ship)
    #expect(profile.equipmentUnits == expected.units)
    let fuel = initial.fuel
    let cargo = initial.cargoTonnes
    var paid = 0
    for name in ["Fuel Scoops", "Salvage Cutter"] {
      let quote = try OriginalBisonFixture.buy(name, in: &game)
      paid += quote.purchase.requiredDebit
      let actual = try #require(game.commander.equipmentInventory?.items.first {
        $0.id == quote.request.newItem
      })
      #expect(Commander.commonEquipmentUnitCost(for: actual) == 1)
    }
    #expect(game.commander.performance.workTools?.contains(.salvageCutter) == true)
    #expect(game.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil)
    #expect(game.commander.commonEquipmentUnits == 2)
    let paidTools = [
      try #require(game.commander.fittedEquipment(at: .utility(.fuelScoops))),
      try #require(game.commander.fittedEquipment(at: .utility(.salvageCutter))),
    ]
    for count in 1...FuelStorage.maximumCount {
      if count == 3 {
        // Two paid tools and two tanks already occupy all four R3 utility mounts.
        let full = game.commander
        let epoch = game.inventoryContextEpoch
        let tank = try #require(Equipment.all.first { $0.name == FuelStorage.equipmentName })
        #expect(full.fuelStorageUnits == 2 && full.commonEquipmentUnits == 4)
        #expect(full.passengerFit?.freeEquipmentUnits == expected.units - 4)
        #expect(throws: EquipmentRuntimeError.incompatibleFit) {
          try game.quoteEquipmentPurchase(tank)
        }
        #expect(game.commander == full)
        game.selection = try #require(Equipment.all.firstIndex { $0.name == tank.name })
        let context = try #require(game.equipmentPurchaseContext)
        #expect(game.performEquipmentMutation(.purchase(context)) == .refused(.invalidState))
        #expect(game.commander == full && game.inventoryContextEpoch == epoch)

        // Hold the actual paid devices through guarded inventory commands, without replacing them.
        game.screen = .inventory
        for item in paidTools {
          let beforeStore = game.commander
          let command = try #require(game.inventoryActionPreview(for: .equipment(item)).command)
          let inventoryCommandApplied = game.performInventoryCommand(command)
          try #require(inventoryCommandApplied)
          let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == item.id })
          #expect(stored == item.moved(to: nil))
          #expect(game.commander.credits == beforeStore.credits)
          #expect(game.commander.equipmentPurchaseHistory == beforeStore.equipmentPurchaseHistory)
          #expect(game.commander.fuel == fuel && game.commander.cargoTonnes == cargo)
        }
        #expect(game.commander.commonEquipmentUnits == 2 && game.commander.fuelStorageUnits == 2)
        game.screen = .equipment
      }
      let quote = try OriginalBisonFixture.buy(FuelStorage.equipmentName, in: &game)
      paid += quote.purchase.requiredDebit
      #expect(game.commander.fuelStorageUnits == count)
      #expect(game.commander.fuelCapacity == expected.performance.fuel + count * 70)
      #expect(game.commander.fuel == fuel && game.commander.cargoTonnes == cargo)
      #expect(game.commander.commonEquipmentUnits == (count <= 2 ? 2 + count : count))
    }
    #expect(FuelStorage.maximumCount == 4)
    #expect(game.commander.credits == initial.credits - paid)
    #expect(
      game.commander.equipmentPurchaseHistory!.paid.count
        == initial.equipmentPurchaseHistory!.paid.count + 6)
    for item in initialInventory.items {
      #expect(game.commander.equipmentInventory?.items.first { $0.id == item.id } == item)
      #expect(Commander.commonEquipmentUnitCost(for: item) == 0)
    }
    for item in paidTools {
      #expect(game.commander.equipmentInventory?.items.first { $0.id == item.id } == item.moved(to: nil))
    }
    let full = game.commander
    let tank = try #require(Equipment.all.first { $0.name == FuelStorage.equipmentName })
    #expect(throws: (any Error).self) { try game.quoteEquipmentPurchase(tank) }
    #expect(game.commander == full)
  }

  @Test(arguments: ["SH005", "SH006"])
  func paidCabinBudgetOverflowUsesOneUnitFiveTonnesAndSeparateCrewPlaces(shipID: String) throws {
    let expected = try OriginalBisonFixture.expected(shipID)
    var game = try OriginalBisonFixture.game(shipID: shipID)
    let profile = try ShipAccommodationProfile(ship: game.commander.ship)
    #expect(
      profile.operatingCrew == expected.crew && profile.intrinsicCrewQuarters == expected.crew)
    #expect(profile.initialCharterBerths == 0 && profile.equipmentUnits == expected.units)
    #expect(game.commander.passengerFit?.freeEquipmentUnits == expected.units)
    let initial = game.commander
    let firstQuote = game.passengerCabinQuote(.economy)
    try #require(firstQuote.allowed)
    let firstID = try game.confirmPassengerBerth(firstQuote)
    #expect(game.commander.accommodation.fittedCabins.map(\.id) == [firstID])
    #expect(game.commander.accommodation.fittedBerths.count == PassengerCabinGrade.economy.places)
    #expect(game.commander.accommodation.people.isEmpty)
    #expect(game.commander.cargoTonnes == initial.cargoTonnes + 5)
    #expect(game.commander.passengerFit?.freeEquipmentUnits == expected.units - 1)
    var paid = firstQuote.price
    for _ in 1..<expected.units {
      let quote = game.passengerCabinQuote(.stateroomSingle)
      try #require(quote.allowed)
      _ = try game.confirmPassengerBerth(quote)
      paid += quote.price
    }
    let fit = try #require(game.commander.passengerFit)
    #expect(fit.freeEquipmentUnits == 0 && fit.usableCargo > 5)
    #expect(game.commander.accommodation.fittedCabins.count == expected.units)
    #expect(game.commander.cargoTonnes == expected.units * 5)
    #expect(game.commander.credits == initial.credits - paid)
    #expect(game.commander.commonEquipmentUnits == 0)
    let beforeRefusal = game.commander
    let refused = game.passengerCabinQuote(.stateroomSingle)
    #expect(!refused.allowed && refused.issues.contains { $0.contains("equipment unit") })
    #expect(throws: MissionPackError.self) { try game.confirmPassengerBerth(refused) }
    #expect(game.commander == beforeRefusal && game.commander.valid)
  }

}
