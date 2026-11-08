import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct NavalPlansOwnedRewardJourneyTests {
  @Test func actualPlansDeliveryStoresPaidEnergyUnitAndAwardsItsOwnRewardOnceAcrossColdLoad()
    async throws
  {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let starter = GameRuntime(game: Game(executive: false))
    try await starter.startNewCommander()
    _ = try await starter.registerNewCommanderDestination(at: files.save)
    var approach = await starter.snapshot()
    // Prior orders, finite initial funding and remote approach positions are explicit
    // controlled inputs. Both mission handoffs and the hardware purchase must be real.
    approach.commander.missionStage = .reportToCeerdi
    approach.commander.kills = 1280
    approach.commander.credits = 30_000_000
    try prepareApproach(&approach, system: 83)
    let collection = GameRuntime(game: approach, saveURL: files.save)
    let collected = try await awaitMainBerth(collection, system: 83)
    try #require(collected.commander.missionStage == .carryingPlans)
    try #require(collected.missionNotice?.message == .plansCollection)
    try await closeNavalMessage(collection)
    let purchased = try await collection.scriptCommand { game -> OwnedEquipmentItem in
      try #require(game.nativeMainStationDockEvidenceIsCurrent && game.currentSystem.technology == 13)
      let equipment = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
      try #require(game.equipmentAvailable(equipment))
      let quote = try game.quoteEquipmentPurchase(equipment)
      try #require(quote.purchase.requiredDebit > 0)
      let balance = game.commander.credits
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought && game.commander.credits == balance - quote.purchase.requiredDebit)
      let item = try #require(game.commander.fittedEquipment(at: .energy))
      try #require(item.id == quote.request.newItem && item.node.key == "Extra Energy Unit")
      let inventory = try #require(game.commander.equipmentInventory)
      try #require(item.provenance == .paid(
        owner: inventory.owner, transaction: quote.request.transaction))
      return item
    }
    let carrying = await collection.snapshot()
    let owner = try #require(carrying.commander.equipmentOwnerID)
    let history = try #require(carrying.commander.equipmentPurchaseHistory)
    let originalInventory = try #require(carrying.commander.equipmentInventory)
    let originalReceipt = try #require(history.paid.first {
      $0.binding.request.newItem == purchased.id
    })
    try #require(originalReceipt.owner == owner && originalReceipt.price > 0)
    let entry = try #require(carrying.missionPacks.entries.first { $0.pack.id == "xyzzy.plans" })
    let nativeReward = try #require(EquipmentRuntimeCatalog.node(for: Equipment.navalEnergyUnit))
    #expect(carrying.commander.equipmentInventory?.items.contains { $0.node == nativeReward } == false)
    try await collection.save(to: files.save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: files.save, persistMigrations: false)
    var continued = await cold.snapshot()
    try #require(continued.commander.missionStage == .carryingPlans && continued.packMatchesSave(entry))
    #expect(continued.commander.fittedEquipment(at: .energy) == purchased)
    try prepareApproach(&continued, system: 36)
    let delivery = GameRuntime(game: continued, saveURL: files.save)
    let delivered = try await awaitMainBerth(delivery, system: 36)
    try #require(delivered.commander.missionStage == .plansDelivered)
    try #require(delivered.missionNotice?.message == .plansDebriefing)
    let currentInventory = try #require(delivered.commander.equipmentInventory)
    let retained = try #require(currentInventory.items.first { $0.id == purchased.id })
    #expect(retained == purchased.moved(to: nil))
    for item in originalInventory.items {
      let after = try #require(currentInventory.items.first { $0.id == item.id })
      #expect(after == (item.id == purchased.id ? item.moved(to: nil) : item))
    }
    let reward = try #require(currentInventory.items.first { $0.node == nativeReward })
    #expect(currentInventory.items.filter { $0.node == nativeReward }.count == 1)
    #expect(reward.provenance == .grant("mission-pack:" + entry.digest))
    #expect(delivered.commander.fittedEquipment(at: .energy)?.id == reward.id)
    #expect(delivered.commander.energyRechargeMultiplier == 3)
    #expect(delivered.commander.equipmentPurchaseHistory == history)
    #expect(delivered.commander.credits == carrying.commander.credits)
    #expect(delivered.commander.kills == 1536)
    #expect(delivered.commander.cargo == carrying.commander.cargo)
    #expect(delivered.commander.valid)
    let progress = try #require(delivered.commander.missionProgress[entry.pack.stateID])
    #expect(progress.receipts.contains("transition.delivery"))
    try await closeNavalMessage(delivery)
    try await delivery.save(to: files.save)
    let terminal = await delivery.snapshot().commander
    let restored = GameRuntime(game: Game(executive: false))
    try await restored.load(from: files.save, persistMigrations: false)
    let reloaded = await restored.snapshot()
    #expect(reloaded.commander == terminal)
    #expect(reloaded.commander.equipmentInventory?.items.first { $0.id == purchased.id } == retained)
    #expect(reloaded.commander.equipmentPurchaseHistory?.paid.contains(originalReceipt) == true)
    // Reconsider the actual already attained berth. Its receipted delivery cannot
    // grant another module, delete the spare or add another 256 points.
    await restored.nativeCommand { $0.progressNavalMissions() }
    #expect(await restored.snapshot().commander == terminal)
    #expect(await restored.snapshot().missionNotice == nil)
  }

  private func prepareApproach(_ game: inout Game, system: Int) throws {
    game.screen = .status
    game.launch()
    try #require(!game.docked)
    try game.departOrdinarySimulation()
    game.commander.galaxy = 2
    game.commander.system = system
    game.selectedSystem = system
    game.systems = Universe.systemsIncludingPlugh(number: 2)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let began = game.beginGameplayVisit(arriving: true)
    try #require(began)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
  }

  private func awaitMainBerth(_ runtime: GameRuntime, system: Int) async throws -> Game {
    for _ in 0..<100 {
      let current = await runtime.snapshot()
      if current.docked {
        try #require(current.nativeMainStationDockEvidenceIsCurrent)
        try #require(current.systemIdentity == SystemIdentity(galaxy: 2, system: system))
        return current
      }
      #expect(current.bodies.allSatisfy { $0.hull != .thargoid && $0.hull != .thargon })
      _ = await runtime.advance(delta: 0.05)
    }
    throw SaveError.invalidCommander
  }

  private func closeNavalMessage(_ runtime: GameRuntime) async throws {
    for _ in 0..<48 { _ = await runtime.advance(delta: 0.05) }
    await runtime.key("escape")
    try #require(await runtime.snapshot().screen == .status)
  }
}
