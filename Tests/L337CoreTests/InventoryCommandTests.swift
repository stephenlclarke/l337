import Foundation
import Testing

@testable import L337Core

private func inventoryCommandGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .inventory
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore, provenance: .grant("fixture"))
  try game.commander.grantEquipment(
    TargetingTier.basic.equipmentName, at: .targetingCore, provenance: .grant("fixture"))
  return game
}

struct InventoryCommandTests {
  @Test func backendAlsoRefusesARequiredSystemRemovalFromAMalformedControl() throws {
    var game = try inventoryCommandGame()
    let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let allowed = try #require(game.inventoryActionPreview(for: .equipment(pulse)).command)
    let shield = try #require(game.commander.fittedEquipment(at: .shield))
    let malformed = InventoryCommand(
      owner: allowed.owner, hull: allowed.hull, context: allowed.context, shipID: allowed.shipID,
      ownedRevision: allowed.ownedRevision, sourceRevision: nil, action: .store(shield))
    let before = game.commander
    let removed = game.performInventoryCommand(malformed)
    #expect(!removed && game.commander == before && game.commander.valid)
  }

  @Test func actualTypedRowsRemainPureAndNeverOfferRemovingRequiredShipSystems() throws {
    let game = try inventoryCommandGame()
    let before = game.commander
    let rows = game.inventoryInformationRows(width: 512)
    #expect(rows == game.inventoryInformationRows(width: 512))
    for slot in [ComponentFittingSlot.shield, .energy, .navigation] {
      let item = try #require(game.commander.fittedEquipment(at: slot))
      let preview = game.inventoryActionPreview(for: .equipment(item))
      #expect(preview.command == nil && preview.detail.contains("Required ship system"))
    }
    #expect(!rows.contains { $0.text.contains(game.commander.equipmentOwnerID!.uuidString) })
    #expect(
      game.commander == before && game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func anActualHeldDeviceCanFitAndStoreOnceWithoutCreatingPaidHistoryOrNewIdentities() throws
  {
    var game = try inventoryCommandGame()
    let held = try #require(
      game.commander.equipmentInventory?.items.first {
        $0.node.key == TargetingTier.basic.equipmentName && $0.location == nil
      })
    let ids = Set(game.commander.equipmentInventory!.items.map(\.id))
    let fit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
    let fitted = game.performInventoryCommand(fit)
    #expect(fitted && game.commander.fittedEquipment(at: .targetingCore)?.id == held.id)
    let beforeReplay = game.commander
    let repeated = game.performInventoryCommand(fit)
    #expect(!repeated && game.commander == beforeReplay)
    let installed = try #require(game.commander.fittedEquipment(at: .targetingCore))
    let store = try #require(game.inventoryActionPreview(for: .equipment(installed)).command)
    let stored = game.performInventoryCommand(store)
    #expect(stored && game.commander.targetingTier == nil)
    #expect(Set(game.commander.equipmentInventory!.items.map(\.id)) == ids)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func recoveredActionUsesItsDisplayedStatisticsAndConsumesTheExactSource() throws {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let preview = game.inventoryActionPreview(for: .recovered(lot))
    let command = try #require(preview.command)
    #expect(preview.detail.contains("255") && preview.detail.contains("units"))
    #expect(preview.extraDetails.contains { $0.hasPrefix("Resulting grade:") })
    #expect(!preview.detail.contains("frontShieldCapacity"))
    game.frontShield = game.commander.shieldCapacity / 2
    let accepted = game.performInventoryCommand(command)
    #expect(accepted && game.commander.salvageLedger.inventory.isEmpty)
    #expect(abs(game.frontShield / game.commander.shieldCapacity - 0.5) < 1e-10)
    let after = game.commander
    let second = game.performInventoryCommand(command)
    #expect(!second && game.commander == after)
  }

  @Test func loadAndScreenReturnRejectOldCommandsEvenWhenPersistentIdentitiesAndRevisionsMatch()
    async throws
  {
    var game = try inventoryCommandGame()
    let scoop = try #require(Equipment.all.first { $0.name == "Fuel Scoops" })
    game.commander.system = try #require(game.systems.first {
      $0.technology >= scoop.technology && !$0.isPlugh
    }?.id)
    game.selectedSystem = game.commander.system
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 1_000_000
    game.screen = .equipment
    try #require(game.commander.shipID == "SH025" && !game.commander.unlimitedCash)
    try #require(game.equipmentAvailable(scoop))
    let purchaseBefore = game.commander
    let purchase = try game.quoteEquipmentPurchase(scoop)
    try #require(game.commander == purchaseBefore && purchase.purchase.requiredDebit > 0)
    try #require(purchase.purchase.requiredDebit == game.shopPrice(scoop))
    let purchaseApplied = try game.applyEquipmentPurchase(purchase)
    try #require(purchaseApplied)
    let paidInventory = try #require(game.commander.equipmentInventory)
    let paidItem = try #require(paidInventory.items.first { $0.id == purchase.request.newItem })
    try #require(paidItem.location?.slot == .utility(.fuelScoops))
    try #require(paidItem.provenance == .paid(
      owner: paidInventory.owner, transaction: purchase.request.transaction))
    try #require(game.commander.credits == purchaseBefore.credits - purchase.purchase.requiredDebit)
    try #require(game.commander.equipmentPurchaseHistory!.paid.count
      == purchaseBefore.equipmentPurchaseHistory!.paid.count + 1)
    let paidReceipt = try #require(game.commander.equipmentPurchaseHistory?.paid.first {
      $0.transaction == purchase.request.transaction
    })
    try #require(paidReceipt.owner == paidInventory.owner && paidReceipt.node == paidItem.node)
    try #require(paidReceipt.price == purchase.purchase.requiredDebit)
    try #require(paidReceipt.binding.request == purchase.request)
    game.screen = .inventory
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let url = storage.url
    let runtime = GameRuntime(game: game, saveURL: url)
    let shown = await runtime.snapshot()
    let item = try #require(shown.commander.equipmentInventory?.items.first { $0.id == paidItem.id })
    let command = try #require(shown.inventoryActionPreview(for: .equipment(item)).command)
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    await runtime.key("9")
    let restored = await runtime.snapshot()
    #expect(restored.commander.equipmentOwnerID == command.owner)
    #expect(restored.commander.hullInstanceID == command.hull)
    #expect(restored.commander.equipmentInventory?.revision == command.ownedRevision)
    #expect(restored.inventoryContextEpoch != command.context)
    let accepted = await runtime.inventoryCommand(command)
    #expect(!accepted)
    #expect(await runtime.snapshot().commander == restored.commander)
    let current = try #require(restored.inventoryActionPreview(for: .equipment(item)).command)
    await runtime.key("8")
    await runtime.key("9")
    let returned = await runtime.snapshot()
    let staleReturn = await runtime.inventoryCommand(current)
    #expect(!staleReturn && returned.inventoryContextEpoch != current.context)
    #expect(await runtime.snapshot().commander == returned.commander)

    // Both directions keep the same paid source; a failed writer preserves the command for retry.
    for storing in [true, false] {
      let before = await runtime.snapshot()
      let currentItem = try #require(before.commander.equipmentInventory?.items.first {
        $0.id == paidItem.id
      })
      let currentCommand = try #require(before.inventoryActionPreview(for: .equipment(currentItem)).command)
      try #require((currentItem.location != nil) == storing)
      let files = try ScriptFinanceTestFixture.files(storage.directory)
      if !storing {
        // Refreshing the header cannot make the original installed payload current after Store.
        let oldPayload = InventoryCommand(
          owner: currentCommand.owner, hull: currentCommand.hull, context: currentCommand.context,
          shipID: currentCommand.shipID, ownedRevision: currentCommand.ownedRevision,
          sourceRevision: currentCommand.sourceRevision, action: .fit(item, .utility(.fuelScoops)))
        let refused = await runtime.equipmentTransaction(.inventory(oldPayload))
        #expect(!refused.applied)
        let unchanged = await runtime.snapshot()
        #expect(unchanged.commander == before.commander)
        #expect(unchanged.inventoryContextEpoch == before.inventoryContextEpoch)
        #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
      }
      try storage.blockWriter()
      let failed = await runtime.equipmentTransaction(.inventory(currentCommand))
      #expect(failed == .refused(.invalidState))
      let rolledBack = await runtime.snapshot()
      #expect(rolledBack.commander == before.commander && rolledBack.bodies == before.bodies)
      #expect(rolledBack.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(rolledBack.energy == before.energy && rolledBack.frontShield == before.frontShield)
      #expect(rolledBack.rearShield == before.rearShield)
      #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
      #expect(try Data(contentsOf: storage.directory) == Data("blocked save directory".utf8))
      try storage.restoreWriter()
      #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
      let retried = await runtime.equipmentTransaction(.inventory(currentCommand))
      try #require(retried.applied)
      let after = await runtime.snapshot()
      let inventory = try #require(after.commander.equipmentInventory)
      let actual = try #require(inventory.items.first { $0.id == paidItem.id })
      #expect(actual == paidItem.moved(to: storing ? nil : paidItem.location))
      #expect(inventory.owner == paidInventory.owner && inventory.activeHull == paidInventory.activeHull)
      #expect(Set(inventory.items.map(\.id)) == Set(paidInventory.items.map(\.id)))
      #expect(inventory.items.filter { $0.id != paidItem.id }
        == paidInventory.items.filter { $0.id != paidItem.id })
      #expect(inventory.revision == currentCommand.ownedRevision + 1)
      #expect(after.inventoryContextEpoch != currentCommand.context)
      #expect(after.commander.equipmentPurchaseHistory == shown.commander.equipmentPurchaseHistory)
      #expect(after.commander.credits == shown.commander.credits)
      #expect(after.commander.fuel == shown.commander.fuel && after.commander.cargo == shown.commander.cargo)
      #expect(try NativeSaveTestFixture.readVersionedCommander(from: url) == after.commander)
      let committedFiles = try ScriptFinanceTestFixture.files(storage.directory)
      let replay = await runtime.equipmentTransaction(.inventory(currentCommand))
      #expect(replay == .refused(.staleContext))
      let afterReplay = await runtime.snapshot()
      #expect(afterReplay.commander == after.commander)
      #expect(afterReplay.inventoryContextEpoch == after.inventoryContextEpoch)
      #expect(try ScriptFinanceTestFixture.files(storage.directory) == committedFiles)
    }
    let final = await runtime.snapshot()
    let cold = GameRuntime()
    try await cold.load(from: url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander == final.commander)
    #expect(loaded.commander.equipmentInventory?.items.first { $0.id == paidItem.id } == paidItem)
    #expect(loaded.commander.equipmentPurchaseHistory == shown.commander.equipmentPurchaseHistory)
  }

  @Test func aDifferentActorCannotUseTheSameCommandersOldInteractionContext() async throws {
    let game = try inventoryCommandGame()
    let first = GameRuntime(game: game)
    let second = GameRuntime(game: game)
    let shown = await first.snapshot()
    let item = try #require(shown.commander.fittedEquipment(at: .targetingCore))
    let command = try #require(shown.inventoryActionPreview(for: .equipment(item)).command)
    let before = await second.snapshot()
    #expect(before.commander.equipmentInventory == shown.commander.equipmentInventory)
    let accepted = await second.inventoryCommand(command)
    #expect(!accepted && before.inventoryContextEpoch != shown.inventoryContextEpoch)
    #expect(await second.snapshot().commander == before.commander)
  }
}
