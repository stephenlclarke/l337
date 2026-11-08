import Foundation
import Testing

@testable import L337Core

private enum CurrentHullFitFixture {
  static let utilities = ["Fuel Scoops", "E.C.M. System", "Escape Pod"]
  static let cabinCount = 18

  /// Use the active original hull and current equipment, before the first calendar/save.
  static func game() throws -> Game {
    var game = Game(executive: false)
    game.commander.shipID = "SH025"
    game.commander.system = try #require(game.systems.filter { !$0.isPlugh }.max {
      $0.technology < $1.technology
    }?.id)
    game.commander.credits = 30_000_000
    game.commander.fuel = 20
    game.commander.missiles = 1
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.selectedSystem = game.commander.system
    game.market = MarketItem.at(game.currentSystem)
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    game.screen = .equipment
    let profile = try ShipAccommodationProfile(ship: game.commander.ship)
    let fitting = try #require(OriginalFleetR3Fitting.contract(for: game.commander.ship)?.fitting)
    try #require(game.commander.ship.name == "Peregrine Mk V" && profile.equipmentUnits == 24)
    try #require(fitting.utilityMounts == 3 && profile.maximumPhysicalCabinModules == cabinCount)
    try #require(game.commander.standardCargoCapacity == 92)
    try #require(game.commander.accommodation.ownedCabins.isEmpty)
    try #require(game.commander.scriptState.calendarLedger == nil)
    try #require(!game.commander.xyzzyActive && !game.commander.requiresContractFit)
    try #require(game.commander.accommodation.fitted.isEmpty)
    try #require(game.commander.commonEquipmentUnits == 0 && game.commander.valid)
    return game
  }

  static func item(_ name: String) throws -> Equipment {
    try #require(Equipment.all.first { $0.name == name })
  }

  @discardableResult
  static func buy(_ name: String, in game: inout Game) throws -> EquipmentRuntimePurchaseQuote {
    let item = try item(name)
    try #require(game.equipmentAvailable(item))
    let before = game.commander
    let quote = try game.quoteEquipmentPurchase(item)
    try #require(quote.purchase.requiredDebit > 0 && quote.purchase.requiredDebit == game.shopPrice(item))
    try #require(game.commander == before)
    let purchased = try game.applyEquipmentPurchase(quote)
    try #require(purchased)
    try #require(game.commander.credits == before.credits - quote.purchase.requiredDebit)
    try #require(game.commander.equipmentPurchaseHistory!.paid.count
      == before.equipmentPurchaseHistory!.paid.count + 1)
    let inventory = try #require(game.commander.equipmentInventory)
    let actual = try #require(inventory.items.first { $0.id == quote.request.newItem })
    try #require(actual.provenance == .paid(owner: inventory.owner, transaction: quote.request.transaction))
    try #require(actual.location == quote.location)
    let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.first {
      $0.transaction == quote.request.transaction
    })
    try #require(receipt.owner == inventory.owner && receipt.node == actual.node)
    try #require(receipt.price == quote.purchase.requiredDebit && receipt.binding.request == quote.request)
    return quote
  }

  static func outfit(atBudget: Bool) throws -> Game {
    var game = try game()
    let initial = game.commander
    var paid = 0
    for name in utilities {
      paid += try buy(name, in: &game).purchase.requiredDebit
    }
    // Basic navigation is intrinsic and costs zero units; buy its actual successor.
    paid += try buy("Navigation: Advanced", in: &game).purchase.requiredDebit
    try #require(game.commander.commonEquipmentUnits == 4)
    for count in 1...cabinCount {
      let before = game.commander
      let quote = game.passengerCabinQuote(.economy)
      try #require(quote.allowed && quote.price > 0)
      try #require(game.commander == before)
      let id = try game.confirmPassengerBerth(quote)
      paid += quote.price
      try #require(game.commander.credits == before.credits - quote.price)
      try #require(game.commander.accommodation.fittedCabins.count == count)
      try #require(game.commander.accommodation.fittedCabins.contains {
        $0.id == id && $0.grade == .economy
      })
      try #require(game.commander.cargoTonnes == count * AccommodationFitting.tonnesPerCabin)
      try #require(game.commander.equipmentInventory == before.equipmentInventory)
      try #require(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
      try #require(game.commander.scriptState.calendarLedger == nil && game.commander.valid)
    }
    if atBudget {
      paid += try buy("Pulse Shield Booster", in: &game).purchase.requiredDebit
    }
    try #require(game.commander.commonEquipmentUnits == (atBudget ? 6 : 4))
    try #require(game.commander.passengerFit?.freeEquipmentUnits == (atBudget ? 0 : 2))
    try #require(game.commander.passengerFit?.allowed == true && game.commander.valid)
    try #require(game.commander.credits == initial.credits - paid)
    try #require(game.commander.equipmentPurchaseHistory!.paid.count
      == initial.equipmentPurchaseHistory!.paid.count + (atBudget ? 5 : 4))
    try #require(game.commander.fuel == initial.fuel)
    try #require(game.commander.scriptState.calendarLedger == nil)
    return game
  }
}

struct CurrentHullFitPurchaseUnitTests {
  @Test func freshUnsavedPaidOutfitStopsAtActualHullBudget() throws {
    var game = try CurrentHullFitFixture.outfit(atBudget: true)
    let before = game.commander
    let next = try CurrentHullFitFixture.item("Extra Energy Unit")
    let node = try #require(EquipmentRuntimeCatalog.node(for: next.name))
    #expect(Commander.commonEquipmentUnitCost(for: node) == 2)
    #expect(before.commonEquipmentUnits == 6 && before.passengerFit?.freeEquipmentUnits == 0)
    #expect(before.fuel == 20 && before.accommodation.fittedCabins.count == CurrentHullFitFixture.cabinCount)
    #expect(throws: EquipmentRuntimeError.incompatibleFit) {
      try game.quoteEquipmentPurchase(next)
    }
    #expect(game.equipmentPurchaseRequirement(next) == "Cannot fit selected equipment")
    #expect(game.commander == before)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == next.name })
    let context = try #require(game.equipmentPurchaseContext)
    #expect(game.performEquipmentMutation(.purchase(context)) == .refused(.invalidState))
    #expect(game.commander == before)
    #expect(game.commander.scriptState.calendarLedger == nil)
    // Fuel remains on its separate paid transaction even when hardware units are full.
    let fuel = try CurrentHullFitFixture.item("Fuel")
    #expect(EquipmentRuntimeCatalog.node(for: fuel.name) == nil)
    #expect(game.equipmentPurchaseRequirement(fuel) == nil)
    let fuelPrice = game.shopPrice(fuel)
    try #require(fuelPrice > 0)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == fuel.name })
    let fuelContext = try #require(game.equipmentPurchaseContext)
    #expect(game.performEquipmentMutation(.purchase(fuelContext)).applied)
    #expect(game.commander.fuel == before.fuelCapacity)
    #expect(game.commander.credits == before.credits - fuelPrice)
    #expect(game.commander.equipmentInventory == before.equipmentInventory)
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(game.commander.commonEquipmentUnits == 6 && game.commander.valid)
  }

  @Test func quotedFitRechecksChangedCommanderBeforeCommit() throws {
    var game = try CurrentHullFitFixture.outfit(atBudget: false)
    let before = game.commander
    let next = try CurrentHullFitFixture.item("Extra Energy Unit")
    let quote = try game.quoteEquipmentPurchase(next)
    #expect(game.commander == before)
    #expect(game.equipmentPurchaseRequirement(next) == nil)
    #expect(game.commander == before)
    var changed = game
    changed.commander.credits -= 1
    let changedBefore = changed.commander
    #expect(throws: EquipmentRuntimeError.staleCommander) {
      try changed.applyEquipmentPurchase(quote)
    }
    #expect(changed.commander == changedBefore)
    let purchaseApplied = try game.applyEquipmentPurchase(quote)
    #expect(purchaseApplied)
    let after = game.commander
    #expect(after.commonEquipmentUnits == 6 && after.passengerFit?.allowed == true)
    #expect(after.credits == before.credits - quote.purchase.requiredDebit)
    #expect(after.equipmentPurchaseHistory!.paid.count
      == before.equipmentPurchaseHistory!.paid.count + 1)
    #expect(after.fittedEquipment(at: .energy)?.id == quote.request.newItem)
    #expect(after.fuel == before.fuel && after.scriptState.calendarLedger == nil)
    #expect(throws: EquipmentRuntimeError.staleCommander) {
      try game.applyEquipmentPurchase(quote)
    }
    #expect(game.commander == after)
  }

  @Test func currentPaidBoundaryFitSurvivesRealSaveAndLoad() async throws {
    let game = try CurrentHullFitFixture.outfit(atBudget: true)
    let before = game.commander
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    try await runtime.save(to: file)
    let published = await runtime.snapshot().commander
    #expect(published.scriptState.calendarLedger != nil)
    #expect(published.shipID == "SH025" && published.commonEquipmentUnits == 6)
    #expect(published.passengerFit?.allowed == true && published.valid)
    #expect(published.equipmentInventory == before.equipmentInventory)
    #expect(published.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(published.credits == before.credits && published.fuel == before.fuel)
    #expect(published.accommodation == before.accommodation)
    let cold = GameRuntime()
    try await cold.load(from: file, persistMigrations: false)
    #expect(await cold.snapshot().commander == published)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: file) == published)
  }

  @Test func overBudgetCurrentOutfitHasNoFreshCalendarExemption() throws {
    var game = try CurrentHullFitFixture.outfit(atBudget: true)
    let scoop = try #require(game.commander.fittedEquipment(at: .utility(.fuelScoops)))
    let location = try #require(scoop.location)
    try game.storeEquipment(scoop, expectedRevision: game.commander.equipmentInventory!.revision)
    try CurrentHullFitFixture.buy("Targeting: Basic", in: &game)
    let current = game.commander
    try #require(current.commonEquipmentUnits == 6 && current.valid)
    try #require(current.scriptState.calendarLedger == nil
      && current.accommodation.fittedCabins.count == CurrentHullFitFixture.cabinCount)
    let inventory = try #require(current.equipmentInventory)
    let held = try #require(inventory.items.first { $0.id == scoop.id })
    try #require(held.location == nil)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: current.performance)
    // Hostile current input refits an actual paid held item without the guarded game transaction.
    // This supplies no acquisition evidence; both items already came from real paid purchases.
    var hostile = current
    hostile.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == held.id ? $0.moved(to: location) : $0 },
      expectedRevision: inventory.revision, context: context)
    hostile.mirrorFittedEquipment()
    #expect(hostile.equipmentPurchaseHistory == current.equipmentPurchaseHistory)
    #expect(hostile.credits == current.credits && hostile.scriptState.calendarLedger == nil)
    #expect(hostile.equipmentStateValid)
    #expect(hostile.commonEquipmentUnits == 7 && hostile.passengerFit?.allowed == false)
    #expect(hostile.commonEquipmentUnits + hostile.accommodation.fittedCabins.count == 25)
    #expect(hostile.passengerFit?.usableCargo == 2)
    #expect(hostile.passengerFit?.issues.contains { $0.contains("equipment units") } == true)
    #expect(!hostile.accommodationValid && !hostile.valid)
    let before = game.commander
    #expect(throws: EquipmentRuntimeError.incompatibleFit) {
      try game.fitEquipment(held, at: .utility(.fuelScoops), expectedRevision: inventory.revision)
    }
    #expect(game.commander == before)
  }
}
