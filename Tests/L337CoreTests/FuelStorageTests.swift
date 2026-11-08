import Foundation
import Testing

@testable import L337Core

@Test func fuelStorageUnitsAreCountedPricedAndNeverSupplyFreeFuel() throws {
  var game = Game(executive: false)
  let ship = try #require(ShipCatalogue.ship(game.commander.shipID))
  let stock = try #require(ship.game)
  let fitting = try #require(OriginalFleetR3Fitting.contract(for: ship)?.fitting)
  try #require(game.commander.shipID == NewCommanderDefaults.shipID && ship.id == "SH025")
  try #require(fitting.utilityMounts == 3 && FuelStorage.maximumCount == 4)
  let mountedCount = fitting.utilityMounts
  game.screen = .equipment
  game.commander.credits = 100_000
  game.commander.fuel = 35
  game.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  try game.commander.prepareEquipment(legacy: false)
  for count in 1...mountedCount {
    game.purchase()
    #expect(
      game.commander.fuelStorageUnits == count
        && game.commander.fuelCapacity == stock.fuel + count * 70)
    #expect(game.commander.fuel == 35 && game.commander.credits == 100_000 - count * 20_000)
    #expect(!game.commander.equipment.contains(FuelStorage.equipmentName) && game.commander.valid)
  }
  let mounted = game.commander
  let epoch = game.inventoryContextEpoch
  let storage = try #require(Equipment.all.first { $0.name == FuelStorage.equipmentName })
  #expect(throws: EquipmentRuntimeError.incompatibleFit) {
    try game.quoteEquipmentPurchase(storage)
  }
  let context = try #require(game.equipmentPurchaseContext)
  #expect(game.performEquipmentMutation(.purchase(context)) == .refused(.invalidState))
  #expect(game.commander == mounted && game.inventoryContextEpoch == epoch)
  #expect(game.commander.fuelStorageUnits == mountedCount)
  game.selection = 0
  game.purchase()
  let fullCapacity = stock.fuel + mountedCount * 70
  #expect(
    game.commander.fuel == fullCapacity
      && game.commander.credits == mounted.credits - (fullCapacity - 35) * 2)
  // A loaded physical tank cannot be stored while its capacity still contains fuel.
  let full = game.commander
  let tank = try #require(game.commander.fittedEquipment(at: .fuelStorage(mountedCount - 1)))
  let revision = try #require(game.commander.equipmentInventory?.revision)
  #expect(throws: EquipmentRuntimeError.incompatibleFit) {
    try game.storeEquipment(tank, expectedRevision: revision)
  }
  #expect(game.commander == full && game.commander.fuelStorageUnits == mountedCount)

  var poor = Game(executive: false)
  poor.commander.fuel = 35
  poor.commander.credits = 19_999
  poor.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  try poor.commander.prepareEquipment(legacy: false)
  let before = poor.commander
  poor.purchase()
  #expect(poor.commander.fuelStorageUnits == 0 && poor.message == "NOT ENOUGH CASH")
  #expect(poor.commander == before)
}

@Test func invalidLegacyFuelAndStorageCountsStillRefuseDecodingIntoAnActualRuntime() async throws {
  let runtime = GameRuntime(game: Game(executive: false))
  let ready = await runtime.snapshot()
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  for (units, fuel) in [(0, 350), (5, 70)] {
    var legacy = Commander()
    legacy.fuelStorageUnits = units
    legacy.fuel = fuel
    #expect(legacy.equipmentInventory == nil && !legacy.valid)
    let data = try JSONEncoder().encode(legacy)
    let decoded = try JSONDecoder().decode(Commander.self, from: data)
    #expect(decoded.equipmentInventory == nil && !decoded.valid)
    try data.write(to: url)
    await #expect(throws: SaveError.self) {
      try await runtime.load(from: url, persistMigrations: false)
    }
    let after = await runtime.snapshot()
    #expect(
      after.commander == ready.commander
        && after.inventoryContextEpoch == ready.inventoryContextEpoch)
  }
}

@Test func fuelStorageSaveCompatibilityAndFullAutoTradeRefuellingUseInstalledCapacity() async throws
{
  let original = try JSONEncoder().encode(Commander())
  var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
  object.removeValue(forKey: "storageUnitCount")
  let legacy = try JSONDecoder().decode(
    Commander.self, from: JSONSerialization.data(withJSONObject: object))
  let stock = try #require(ShipCatalogue.ship(legacy.shipID)?.game)
  #expect(legacy.fuelStorageUnits == 0 && legacy.fuelCapacity == stock.fuel && legacy.valid)
  var game = Game(executive: false)
  try #require(game.commander.shipID == legacy.shipID)
  let ship = try #require(ShipCatalogue.ship(game.commander.shipID))
  let fitting = try #require(OriginalFleetR3Fitting.contract(for: ship)?.fitting)
  try #require(ship.id == "SH025" && fitting.utilityMounts == 3)
  let mountedCount = fitting.utilityMounts
  game.screen = .equipment
  game.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  try game.commander.prepareEquipment(legacy: false)
  let originalFuel = game.commander.fuel
  let originalInventory = try #require(game.commander.equipmentInventory)
  let originalHistory = try #require(game.commander.equipmentPurchaseHistory)
  game.commander.credits = mountedCount * FuelStorage.price
  for count in 1...mountedCount {
    let context = try #require(game.equipmentPurchaseContext)
    let result = game.performEquipmentMutation(.purchase(context))
    let item = try #require(game.commander.fittedEquipment(at: .fuelStorage(count - 1)))
    #expect(result == .applied(.purchase(
      item: FuelStorage.equipmentName, physicalItem: item.id, fitted: true)))
    let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.first {
      $0.binding.request.newItem == item.id
    })
    #expect(
      item.provenance == .paid(owner: originalInventory.owner, transaction: receipt.transaction))
    #expect(receipt.owner == originalInventory.owner && receipt.node == item.node)
    #expect(receipt.price == FuelStorage.price)
    #expect(game.commander.equipmentInventory?.activeHull == originalInventory.activeHull)
    #expect(
      game.commander.equipmentPurchaseHistory!.paid.count == originalHistory.paid.count + count)
    #expect(game.commander.credits == (mountedCount - count) * FuelStorage.price)
    #expect(game.commander.fuel == originalFuel && game.commander.valid)
  }
  let paidInventory = try #require(game.commander.equipmentInventory)
  let paidHistory = try #require(game.commander.equipmentPurchaseHistory)
  let paidTanks = try (0..<mountedCount).map {
    try #require(game.commander.fittedEquipment(at: .fuelStorage($0)))
  }
  #expect(Set(paidTanks.map(\.id)).count == mountedCount)
  game.commander.fuel = 100
  let fullCapacity = stock.fuel + mountedCount * 70
  game.commander.credits = (fullCapacity - 100) * 2
  game.selectedSystem = game.commander.system
  for i in game.market.indices { game.market[i].quantity = 0 }
  game.autoTrade()
  #expect(game.commander.fuel == fullCapacity && game.commander.credits == 0)
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try await runtime.save(to: url)
  let saved = await runtime.snapshot().commander
  try await runtime.load(from: url)
  let cold = await runtime.snapshot().commander
  #expect(cold.fuelCapacity == fullCapacity && cold.fuelStorageUnits == mountedCount)
  #expect(cold.fuel == fullCapacity && cold.credits == 0 && cold.valid)
  #expect(cold == saved)
  #expect(cold.equipmentInventory == paidInventory && cold.equipmentPurchaseHistory == paidHistory)
  for (index, item) in paidTanks.enumerated() {
    #expect(cold.fittedEquipment(at: .fuelStorage(index)) == item)
  }
}

@Test func eachComputerStorageAndFuelCombinationControlsRingsSearchAndActualJump() throws {
  let stock = try #require(ShipCatalogue.ship(NewCommanderDefaults.shipID)?.game)
  for tier in NavigationTier.allCases {
    for units in 0...4 {
      for fuel in [0, 30, 70, stock.fuel + units * 70] {
        var game = Game(executive: false)
        try #require(game.commander.shipID == NewCommanderDefaults.shipID)
        game.commander.installNavigationComputer(tier)
        game.commander.fuelStorageUnits = units
        game.commander.fuel = fuel
        let capacity = Double(stock.fuel + units * 70) / 10
        let navigationCap = Double(tier.rawValue * 7)
        let jumpCap = max(stock.jump, navigationCap)
        #expect(tier.jumpCap == navigationCap)
        #expect(game.jumpReach.maximum == min(capacity, jumpCap))
        #expect(game.jumpReach.actual == min(Double(fuel) / 10, jumpCap))
        #expect(
          game.navigationPlanningRadius
            == (tier == .military ? nil : capacity + navigationCap))
        for system in game.knownSystems {
          game.selectedSystem = system.id
          #expect(
            game.targetReachable
              == (game.currentSystem.distance(to: system) <= game.jumpReach.actual))
        }
        game.screen = .shortChart
        for zoom in MapZoom.allCases {
          game.mapZoom = zoom
          let frame = Display.map(game, width: 512, height: 518)
          let styles = (frame.worldGraphics + frame.graphics).compactMap {
            graphic -> StrokePattern? in
            if case .ring(_, _, _, _, let style) = graphic { return style }
            return nil
          }
          #expect(styles.contains(.dotted) && styles.contains(.dashed))
          #expect(styles.contains(.solid) == (game.jumpReach.actual != game.jumpReach.maximum))
          for label in frame.labels {
            #expect(label.bounds.x >= 0 && label.bounds.maxX <= 512 && label.bounds.maxY <= 518)
          }
        }
      }
    }
  }
  var game = Game(executive: false)
  game.screen = .shortChart
  #expect(
    game.jumpReach.maximum == min(stock.jump, Double(stock.fuel) / 10)
      && game.jumpReach.search == nil)
  for zoom in MapZoom.allCases {
    #expect(game.mapZoom == zoom)
    game.key("z")
  }
  #expect(game.mapZoom == .jump)
}

@Test func routeFirstHopUsesCurrentFuelLaterHopsUseCapacityAndNavigationCap() throws {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.fuelStorageUnits = 4
  game.commander.fuel = 70
  let graph = NavigationGraph(game: game)
  let dest = try #require(
    game.systems.first {
      game.currentSystem.distance(to: $0) > 21
        && graph.path(from: game.commander.system, to: $0.id, fuel: 70, scoring: 0) != nil
    })
  let path = try #require(
    graph.path(from: game.commander.system, to: dest.id, fuel: 70, scoring: 0))
  #expect(game.systems[path[0]].distance(to: game.systems[path[1]]) <= 7)
  #expect(
    zip(path, path.dropFirst()).allSatisfy { game.systems[$0].distance(to: game.systems[$1]) <= 21 }
  )
  #expect(
    graph.edges[game.commander.system].contains {
      game.currentSystem.distance(to: game.systems[$0]) > 14
    })
  #expect(
    !graph.edges[game.commander.system].contains {
      game.currentSystem.distance(to: game.systems[$0]) > 21
    })
}
