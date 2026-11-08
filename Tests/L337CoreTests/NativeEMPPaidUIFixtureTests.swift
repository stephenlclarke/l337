import Foundation
import Testing

@testable import L337Core

enum NativeEMPPaidUIFixture {
  static let catalogueID = "SH029"
  static let initialScalarState: UInt64 = 0

  static func game(file: URL) async throws -> Game {
    let runtime = GameRuntime(game: try controlledApproach(), saveURL: file)
    try await ScriptFinanceTestFixture.enterMain(runtime)
    try await runtime.save(to: file)
    try await runtime.purchaseNativeEMPUIBase()
    try await runtime.upgradeNativeEMPUIWeapon()
    try await runtime.launchNativeEMPUIFlight()
    for _ in 0..<256 {
      if await runtime.snapshot().currentEMPPlayerModule()?.empBank?.remaining == 8 { break }
      let started = await runtime.snapshot().commander.flightSimulation.physicalTime
      let advanced = await runtime.advance(delta: 0.1)
      try #require(advanced.commander.flightSimulation.physicalTime > started)
      try #require(!advanced.docked && !advanced.paused && advanced.screen.isFlight)
    }
    let bank = try #require(await runtime.snapshot().currentEMPPlayerModule()?.empBank)
    try #require(bank.capacity == 8 && bank.remaining == 8 && bank.lastDischarge == nil)
    try await runtime.save(to: file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    try #require(saved.fittedEquipment(at: .utility(.empPirateBlaster))?.empBank == bank)

    var baseline = await runtime.snapshot()
    try insertEMPUnitTarget(&baseline, catalogue: catalogueID, hostile: true)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: catalogueID))
    let stock = try #require(NPCResources.stock(source.performance))
    try #require(source.ship.id == catalogueID && source.ship.catalogue.origin == .human)
    let target = try #require(baseline.bodies.first)
    try #require(target.physical?.catalogueShipID == catalogueID)
    try #require(target.physical?.npc?.resources == stock)
    try #require(stock.electricalRecharge == 3.5 && stock.shieldRecharge == 1.5)
    try #require(EMPState.declaredNativeCrewCount(source.ship) == 1)
    try #require(target.physical?.npc?.ordinaryCargo == [.init(commodity: .food, quantity: 2)])
    try #require(target.energy == 77 && target.missiles == 0 && !target.ecmEnabled)
    try #require(!target.navalTarget && baseline.commander.missionStage.rawValue == 0)
    try #require(
      baseline.scriptSimulationSave.randomState == initialScalarState,
      Comment(rawValue: "EMP UI initial scalar expected=\(initialScalarState)"
        + " actual=\(baseline.scriptSimulationSave.randomState)"
        + " time=\(baseline.commander.flightSimulation.physicalTime)"
        + " counter=\(baseline.missionLoopCounter)"))
    try #require(baseline.commander.flightSimulation.physicalTime > 0)
    try #require(baseline.missionLoopCounter > 0)
    return baseline
  }

  /// Funds, shop location and the near-port pose are controlled inputs to the native arrival.
  private static func controlledApproach() throws -> Game {
    var game = Game(executive: false)
    // Fresh deterministic input precedes every arrival, receipt and accepted frame.
    game.seedScriptTrial(initialScalarState)
    game.screen = .status
    game.commander.system = 69
    game.selectedSystem = 69
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 1_000_000
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    try #require(game.commander.shipID == "SH025" && game.currentSystem.technology == 16)
    try #require(!game.commander.unlimitedCash && !game.commander.unlimitedFuel)
    for (name, slot) in [
      ("Salvage Cutter", ComponentFittingSlot.utility(.salvageCutter)),
      ("Fuel Scoops", .utility(.fuelScoops)),
      ("Targeting: Salvage Module", .targetingSalvage),
      (TargetingTier.military.equipmentName, .targetingCore),
    ] {
      try game.commander.grantEquipment(name, at: slot, provenance: .grant("EMP regression"))
    }
    try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)) == nil)
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    game.launch()
    try #require(!game.docked && game.commander.valid)
    try ScriptFinanceTestFixture.approachMain(&game)
    return game
  }
}

private extension GameRuntime {
  func purchaseNativeEMPUIBase() throws {
    try #require(game.nativeMainStationDockEvidenceIsCurrent && game.stationAllowsEquipmentServices)
    key("3")
    try #require(game.screen == .equipment && !game.equipmentCrewSelected)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == Equipment.empPirateBlaster })
    let offer = Equipment.all[game.selection]
    try #require(game.equipmentAvailable(offer))
    let basePrice = game.shopPrice(offer)
    let funds = game.commander.credits
    let paidCount = try #require(game.commander.equipmentPurchaseHistory).paid.count
    let context = try #require(game.equipmentPurchaseContext)
    let purchased = equipmentTransaction(.purchase(context))
    try #require(purchased.applied)
    let base = try #require(game.currentEMPPlayerModule())
    let history = try #require(game.commander.equipmentPurchaseHistory)
    let payment = try #require(history.paid.last)
    let owner = try #require(game.commander.equipmentOwnerID)
    try #require(history.paid.count == paidCount + 1 && basePrice > 0)
    try #require(game.commander.credits == funds - basePrice && payment.price == basePrice)
    try #require(payment.owner == owner && payment.node == base.node)
    try #require(payment.binding.request.newItem == base.id)
    try #require(payment.binding.snapshot.funds == funds)
    try #require(base.provenance == .paid(owner: owner, transaction: payment.transaction))
    try #require(base.location?.slot == .utility(.empPirateBlaster))
    try #require(base.empGrades == .base && base.empBank?.remaining == 0)
    let originalPulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(originalPulse.power == 32 && originalPulse.warmup == 10)
    try #require(originalPulse.energyCost == 8)
    let baseSaved = try NativeSaveTestFixture.readVersionedCommander(
      from: try #require(scriptSaveURL))
    try #require(baseSaved.fittedEquipment(at: .utility(.empPirateBlaster)) == base)
    try #require(baseSaved.equipmentPurchaseHistory == history)
  }

  func upgradeNativeEMPUIWeapon() throws {
    let base = try #require(game.currentEMPPlayerModule())
    let history = try #require(game.commander.equipmentPurchaseHistory)
    let owner = try #require(game.commander.equipmentOwnerID)
    try #require(EMPModuleGrades.hasPaidBase(base, owner: owner, history: history))
    let upgradeFunds = game.commander.credits
    let upgrade = try game.empModulePurchaseContext(module: base.id, axis: .power)
    let receipt = try purchaseEMPModuleUpgrade(upgrade)
    let fitted = try #require(game.currentEMPPlayerModule())
    try #require(receipt.module == base.id && receipt.owner == owner)
    try #require(receipt.before == .base && receipt.after.power == 1)
    try #require(receipt.after.capacity == 0 && receipt.after.recharge == 0)
    try #require(
      receipt.paidPrice == 30_000 && game.commander.credits == upgradeFunds - receipt.paidPrice)
    try #require(fitted.id == base.id && fitted.provenance == base.provenance)
    try #require(fitted.location == base.location && fitted.empGrades?.paid == [receipt])
    try #require(fitted.empBank?.capacity == 8 && fitted.empBank?.remaining == 0)
    try #require(game.commander.equipmentPurchaseHistory == history)
    let upgradedPulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(upgradedPulse.power == 64 && upgradedPulse.warmup == 10)
    try #require(upgradedPulse.energyCost == 8)
    let upgradeSaved = try NativeSaveTestFixture.readVersionedCommander(
      from: try #require(scriptSaveURL))
    try #require(upgradeSaved.fittedEquipment(at: .utility(.empPirateBlaster)) == fitted)
    try #require(upgradeSaved.equipmentPurchaseHistory == history)
  }

  func launchNativeEMPUIFlight() throws {
    game.launch()
    try #require(!game.docked && game.commander.valid)
    try prepareEMPUnitScene(&game)
    setControls(Controls())
  }
}

struct NativeEMPPaidUIFixtureTests {
  @Test func paidUpgradeAndEarnedBankRetainExactOrdinaryUIActorAcrossCurrentSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let baseline = try await NativeEMPPaidUIFixture.game(file: storage.url)
    let tool = try #require(baseline.currentEMPPlayerModule())
    let payment = try #require(baseline.commander.equipmentPurchaseHistory?.paid.last)
    let upgrade = try #require(tool.empGrades?.paid.first)
    #expect(tool.provenance == .paid(owner: payment.owner, transaction: payment.transaction))
    #expect(payment.binding.request.newItem == tool.id && upgrade.module == tool.id)
    #expect(tool.empBank?.remaining == 8 && tool.empGrades?.power == 1)
    let target = try #require(baseline.bodies.first)
    let source = try #require(
      OriginalFleetRuntimeHullSource.source(for: NativeEMPPaidUIFixture.catalogueID))
    #expect(target.physical?.catalogueShipID == source.ship.id)
    #expect(EMPState.declaredNativeCrewCount(source.ship) == 1)
    let resources = try #require(target.physical?.npc?.resources)
    let pulse = try EMPPulseProfile.resolve(for: baseline.commander)
    #expect(
      1 + (resources.electricalRecharge + resources.shieldRecharge) * (pulse.warmup + 0.1)
        < pulse.power)
    #expect(baseline.commander.savedEMPState == nil && baseline.commander.savedEMPCharge == nil)
    let runtime = GameRuntime(game: baseline, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let ready = await runtime.snapshot()
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    var expectedDisk = ready.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: ready.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: ready.systemIdentity)
    #expect(saved == expectedDisk)
    let bytes = try Data(contentsOf: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.root)
    let expected = try expectedCurrentColdScene(ready)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.commander == expected.commander)
    #expect(restored.bodies == expected.bodies && restored.nextBodyID == expected.nextBodyID)
    #expect(restored.scriptSimulationSave == ready.scriptSimulationSave)
    #expect(try Data(contentsOf: storage.url) == bytes)
    #expect(try ScriptFinanceTestFixture.files(storage.root) == files)
    #expect(restored.commander.fittedEquipment(at: .utility(.empPirateBlaster)) == tool)
    #expect(
      restored.bodies.first { $0.id == target.id }?.physical?.identity == target.physical?.identity)
    #expect(
      restored.bodies.first { $0.id == target.id }?.physical?.catalogueShipID == source.ship.id)
  }
  /// Disk omits NPC bindings; current load restores those bindings and gives each
  /// retained source station fresh addresses. Predict only those exact changes
  /// from the post-writer live scene, then compare the complete state and bodies.
  private func expectedCurrentColdScene(_ ready: Game) throws
    -> (commander: Commander, bodies: [SpaceBody], nextBodyID: Int)
  {
    var commander = ready.commander
    var bodies = ready.bodies
    let indices = bodies.indices.filter { bodies[$0].nativeStationIdentity != nil }
    guard !indices.isEmpty else { return (commander, bodies, ready.nextBodyID) }
    let flight = ready.commander.flightSimulation
    let world = try #require(ready.commander.nativeStations)
    func object<T: Encodable>(_ value: T) throws -> [String: Any] {
      try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    var fields = try object(flight)
    fields["nextActor"] = flight.nextActor + UInt64(indices.count)
    fields["nextSpawn"] = flight.nextSpawn + 1
    commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: fields))
    var ledger = try object(world.ledger)
    var records = try #require(ledger["records"] as? [[String: Any]])
    for (member, index) in indices.enumerated() {
      let station = try #require(bodies[index].nativeStationIdentity)
      let record = try #require(world.ledger.records.firstIndex { $0.identity == station })
      let actor = ActorIdentity(
        system: ready.systemIdentity, visit: flight.visit,
        entity: flight.nextActor + UInt64(member))
      let spawn = SpawnIdentity(
        system: ready.systemIdentity, visit: flight.visit, sequence: flight.nextSpawn,
        member: UInt16(member), producer: .mission)
      var physical = try object(#require(bodies[index].physical))
      physical["identity"] = try object(actor)
      physical["spawnIdentity"] = try object(spawn)
      bodies[index].id = ready.nextBodyID + member
      bodies[index].physical = try JSONDecoder().decode(
        PhysicalActorState.self, from: JSONSerialization.data(withJSONObject: physical))
      records[record]["binding"] = try object(
        NativeStationBinding(actor: actor, bodyID: ready.nextBodyID + member))
    }
    ledger["records"] = records
    commander.nativeStations?.ledger = try JSONDecoder().decode(
      NativeStationLedger.self, from: JSONSerialization.data(withJSONObject: ledger))
    return (commander, bodies, ready.nextBodyID + indices.count)
  }

}
