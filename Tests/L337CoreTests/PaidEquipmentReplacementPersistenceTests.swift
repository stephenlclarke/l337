import Foundation
import Testing

@testable import L337Core

struct PaidEquipmentReplacementPersistenceTests {
  @Test func failedOccupiedLaserPurchaseRetriesSameContextOnceAndRetainsBothLaserItems()
    async throws
  {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    try #require(source.ship.id == "SH031" && source.ship.catalogue.playerFlyable)
    try #require(source.ship.nativeHull == .viper && source.ship.game == source.performance)
    let fitting = try #require(source.contract.fitting)
    try #require(!fitting.roleKitIncluded)
    let beam = try #require(Equipment.all.first { $0.name == "Beam Laser" })

    // The inert ctor reads SH025 metadata; bind the controlled owner before physical initialization.
    var game = Game(executive: false)
    try #require(
      game.commander.equipmentInventory == nil && game.commander.equipmentPurchaseHistory == nil)
    var owner = Commander()
    owner.shipID = source.ship.id
    owner.credits = 1_000_000
    owner.fuel = 0
    owner.missiles = 0
    try #require(
      owner.equipment == [LaserKind.pulse.equipmentName]
        && owner.laserMounts == LaserMounts(front: .pulse))
    try #require(owner.equipmentInventory == nil && owner.equipmentPurchaseHistory == nil)
    owner.system = try #require(
      game.systems.first { !$0.isPlugh && $0.technology >= beam.requiredTechnologyLevel }?.id)
    // Controlled STANDARD foundations, not earned hull acquisition, crew or a free role kit.
    try owner.prepareEquipment(legacy: false)
    try #require(owner.shipID == source.ship.id && owner.nativePerformance == source.performance)
    try #require(owner.valid && !owner.unlimitedCash)
    let foundations = try #require(owner.equipmentInventory)
    try #require(foundations.items.count == 5 && owner.equipmentPurchaseHistory?.paid.isEmpty == true)
    try #require(
      foundations.items.allSatisfy {
        $0.provenance == .standard && $0.location?.hullInstanceID == foundations.activeHull
      })
    for slot in [ComponentFittingSlot.shield, .energy, .navigation, .drive] {
      let item = try #require(owner.fittedEquipment(at: slot))
      try #require(item.component?.id == item.id)
    }
    try #require(owner.fuel == 0 && owner.missiles == 0 && owner.equipmentOwnerID == foundations.owner)
    try #require(owner.hullInstanceID == foundations.activeHull)

    game.commander = owner
    game.energy = owner.performance.energy
    game.frontShield = owner.shieldCapacity
    game.rearShield = owner.rearShieldCapacity
    game.selectedSystem = owner.system
    game.market = MarketItem.at(game.currentSystem)
    game.screen = .equipment
    game.equipmentMount = .front
    game.equipmentWorkTool = false
    game.selection = try #require(Equipment.all.firstIndex { $0.name == beam.name })
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    try #require(game.commander.valid && game.requiresScriptDurability && !game.atPlugh)
    try #require(game.equipmentAvailable(beam))

    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let before = await runtime.snapshot()
    let inventory = try #require(before.commander.equipmentInventory)
    let history = try #require(before.commander.equipmentPurchaseHistory)
    let pulse = try #require(before.commander.fittedEquipment(at: .laser(.front)))
    let components = inventory.items.compactMap(\.component)
    try #require(before.commander.shipID == source.ship.id && before.commander.valid)
    try #require(before.commander.laser(on: .front) == .pulse && pulse.provenance == .standard)
    try #require(pulse.node.key == LaserKind.pulse.equipmentName && pulse.component == nil)
    try #require(components.count == 4 && pulse.location?.hullInstanceID == inventory.activeHull)
    try #require(history.paid.isEmpty && before.commander.fuel == 0 && before.commander.missiles == 0)
    let context = try #require(before.equipmentPurchaseContext)
    let price = before.shopPrice(beam)
    try #require(price > 0 && price <= before.commander.credits)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try #require(
      try NativeSaveTestFixture.readVersionedCommander(from: storage.url) == before.commander)

    try storage.blockWriter()
    let failed = await runtime.equipmentTransaction(.purchase(context))
    #expect(failed == .refused(.invalidState))
    let rolledBack = await runtime.snapshot()
    #expect(rolledBack.commander == before.commander && rolledBack.bodies == before.bodies)
    #expect(rolledBack.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(rolledBack.equipmentPurchaseContext == context)
    #expect(rolledBack.energy == before.energy && rolledBack.frontShield == before.frontShield)
    #expect(rolledBack.rearShield == before.rearShield)
    #expect(rolledBack.commander.fittedEquipment(at: .laser(.front)) == pulse)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    #expect(try Data(contentsOf: storage.directory) == Data("blocked save directory".utf8))
    try storage.restoreWriter()
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)

    // Context has no transaction UUID: the successful actor commit supplies the real new item.
    let retried = await runtime.equipmentTransaction(.purchase(context))
    try #require(retried.applied)
    let after = await runtime.snapshot()
    let placed = try #require(after.commander.fittedEquipment(at: .laser(.front)))
    let nextInventory = try #require(after.commander.equipmentInventory)
    let nextHistory = try #require(after.commander.equipmentPurchaseHistory)
    let paid = try #require(nextHistory.paid.first { $0.binding.request.newItem == placed.id })
    #expect(retried == .applied(.purchase(item: beam.name, physicalItem: placed.id, fitted: true)))
    #expect(after.commander.valid && after.commander.shipID == source.ship.id)
    #expect(after.commander.credits == before.commander.credits - price)
    #expect(after.commander.laser(on: .front) == .beam && placed.id != pulse.id)
    // Lasers are physical items without ComponentInstance payloads; preserve all four real modules.
    #expect(placed.node.family == pulse.node.family && placed.node.key == beam.name)
    #expect(placed.component == nil && placed.location?.hullInstanceID == inventory.activeHull)
    #expect(placed.location?.slot == .laser(.front))
    #expect(placed.provenance == .paid(owner: inventory.owner, transaction: paid.transaction))
    #expect(paid.owner == inventory.owner && paid.node == placed.node && paid.price == price)
    #expect(paid.binding.request.location == EquipmentRuntimeCatalog.purchaseLocation(placed.location))
    #expect(nextHistory.paid.count == history.paid.count + 1 && nextHistory.legacy == history.legacy)
    #expect(nextHistory.owner == history.owner && nextHistory.revision == history.revision + 1)
    #expect(nextHistory.paid.filter { $0.transaction != paid.transaction } == history.paid)
    #expect(nextInventory.owner == inventory.owner && nextInventory.activeHull == inventory.activeHull)
    #expect(nextInventory.revision == inventory.revision + 1)
    #expect(nextInventory.items.count == inventory.items.count + 1)
    #expect(Set(nextInventory.items.map(\.id)) == Set(inventory.items.map(\.id)).union([placed.id]))
    #expect(nextInventory.items.first { $0.id == pulse.id } == pulse.moved(to: nil))
    #expect(nextInventory.items.compactMap(\.component) == components)
    #expect(
      nextInventory.items.filter { $0.id != pulse.id && $0.id != placed.id }
        == inventory.items.filter { $0.id != pulse.id })
    #expect(
      after.commander.fuel == before.commander.fuel && after.commander.cargo == before.commander.cargo)
    #expect(after.commander.missiles == before.commander.missiles)
    #expect(after.commander.accommodation == before.commander.accommodation)
    #expect(after.energy == before.energy && after.frontShield == before.frontShield)
    #expect(after.rearShield == before.rearShield)
    #expect(after.inventoryContextEpoch != before.inventoryContextEpoch)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: storage.url) == after.commander)

    let committedFiles = try ScriptFinanceTestFixture.files(storage.directory)
    let replay = await runtime.equipmentTransaction(.purchase(context))
    #expect(replay == .refused(.staleContext))
    let replayed = await runtime.snapshot()
    #expect(replayed.commander == after.commander)
    #expect(replayed.inventoryContextEpoch == after.inventoryContextEpoch)
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == committedFiles)
    let cold = GameRuntime(game: game)
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander == after.commander && loaded.commander.valid)
    #expect(loaded.commander.fittedEquipment(at: .laser(.front)) == placed)
    #expect(
      loaded.commander.equipmentInventory?.items.first { $0.id == pulse.id } == pulse.moved(to: nil))
    #expect(loaded.commander.equipmentPurchaseHistory == nextHistory)
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == committedFiles)
  }
}
