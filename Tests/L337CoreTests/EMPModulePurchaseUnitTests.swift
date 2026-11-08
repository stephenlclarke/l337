import Foundation
import Testing

@testable import L337Core

struct EMPModulePurchaseFixture: Sendable {
  let folder: URL
  let file: URL
  let runtime: GameRuntime

  init(plugh: Bool = false, useOwnedStarter: Bool = false) async throws {
    folder = try missionGearFolder()
    file = folder.appendingPathComponent("save/commander.json")
    var game: Game
    if useOwnedStarter {
      game = Game(executive: false)
      do {
        try #require(game.commander.shipID == NewCommanderDefaults.shipID)
        try #require(game.commander.shipID == "SH025")
        try #require(!OriginalDetailedHullStage.blocksRuntime(game.commander.shipID))
        let fitting = try #require(OriginalFleetR3Fitting.contract(for: game.commander.ship)?.fitting)
        try #require(fitting.utilityMounts == 3)
        try game.commander.prepareEquipment(legacy: false)
        game.commander.mirrorFittedEquipment()
        try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
        game.screen = .inventory
        let original = try #require(game.commander.equipmentInventory)
        let originalIDs = Set(original.items.map(\.id))
        let rounds = original.items.filter { item in
          guard let location = item.location, location.hullInstanceID == original.activeHull,
            item.node == EquipmentRuntimeCatalog.standardMissile
          else { return false }
          if case .missilePylon = location.slot { return true }
          return false
        }
        try #require(game.commander.missiles == 3 && rounds.count == 3)
        let roundIDs = Set(rounds.map(\.id))
        let funds = game.commander.credits
        let history = game.commander.equipmentPurchaseHistory
        let shipID = game.commander.shipID
        let capacity = game.commander.capacity
        let fuel = game.commander.fuel
        for _ in 0..<2 {
          let before = try #require(game.commander.equipmentInventory)
          let round = try #require(missionHighestRound(game.commander))
          try #require(rounds.contains(round))
          let source = game.commander.salvageLedger
          let eventSequence = game.commander.scriptState.nextEvent
          let command = try #require(game.inventoryActionPreview(for: .equipment(round)).command)
          try #require(command.owner == original.owner && command.hull == original.activeHull)
          try #require(command.shipID == shipID && command.context == game.inventoryContextEpoch)
          try #require(command.ownedRevision == before.revision && command.sourceRevision == nil)
          if case .store(let selected) = command.action {
            try #require(selected == round)
          } else { throw SaveError.invalidCommander }
          try #require(before.revision < UInt64.max)
          let result = game.performEquipmentMutation(.inventory(command))
          let after = try #require(game.commander.equipmentInventory)
          try #require(result == .applied(.inventory(
            ownedRevision: after.revision, sourceRevision: game.commander.salvageLedger.revision)))
          try #require(after.revision == before.revision + 1)
          try #require(after.owner == original.owner && after.activeHull == original.activeHull)
          try #require(Set(after.items.map(\.id)) == originalIDs)
          try #require(after.items == before.items.map {
            $0.id == round.id ? $0.moved(to: nil) : $0
          })
          try #require(game.commander.shipID == shipID && game.commander.salvageLedger == source)
          try #require(game.commander.credits == funds && game.commander.equipmentPurchaseHistory == history)
          try #require(game.commander.capacity == capacity && game.commander.fuel == fuel)
          let occupied = try #require(game.commander.checkedCargoTonnes)
          try #require(occupied <= capacity && game.commander.valid)
          // Keep the normal Store event emission and dispatch; do not reset its state.
          try #require(game.commander.scriptState.nextEvent >= eventSequence)
        }
        let held = try #require(game.commander.equipmentInventory).items.filter {
          roundIDs.contains($0.id) && $0.location == nil
        }
        try #require(game.commander.missiles == 1 && held.count == 2)
        try #require(held.allSatisfy { item in
          rounds.contains { item == $0.moved(to: nil) }
        })
      } catch {
        try? FileManager.default.removeItem(at: folder)
        throw error
      }
    } else {
      game = try missionGearGame(missiles: 1)
    }
    game.screen = .equipment
    game.commander.credits = 1_000_000
    game.commander.system = plugh ? Plugh.systemID : try #require(game.systems.first {
      !$0.isPlugh && $0.technology >= 14
    }?.id)
    if plugh { game.commander.discoverPlugh(in: game.commander.galaxy) }
    game.selection = try #require(Equipment.all.firstIndex { $0.name == Equipment.empPirateBlaster })
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    runtime = GameRuntime(game: game, saveURL: file)
    do {
      try await runtime.save(to: file)
      let context = try #require(await runtime.snapshot().equipmentPurchaseContext)
      try #require(await runtime.equipmentTransaction(.purchase(context)).applied)
      try #require(await runtime.snapshot().commander.valid)
    } catch {
      try? FileManager.default.removeItem(at: folder)
      throw error
    }
  }

  func clean() { try? FileManager.default.removeItem(at: folder) }

  func context(_ axis: EMPModuleAxis, runtime current: GameRuntime? = nil) async throws
    -> EMPModulePurchaseContext
  {
    let game = await (current ?? runtime).snapshot()
    let item = try EMPBankOwnershipFixture.item(game.commander)
    return try game.empModulePurchaseContext(module: item.id, axis: axis)
  }

  static func files(_ folder: URL) throws -> [String: Data] {
    let enumerator = try #require(FileManager.default.enumerator(atPath: folder.path))
    var files: [String: Data] = [:]
    for case let relative as String in enumerator {
      let file = folder.appendingPathComponent(relative)
      guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
      files[relative] = try Data(contentsOf: file)
    }
    return files
  }
}

struct EMPModulePurchaseUnitTests {
  @Test func actualPaidAxesChangeOnlyTheirOwnGradeAndNeverRefillTheEmptyBase() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let initial = await f.runtime.snapshot()
    let original = try EMPBankOwnershipFixture.item(initial.commander)
    #expect(original.empGrades == .base && original.empBank?.remaining == 0)
    let initialHistory = initial.commander.equipmentPurchaseHistory
    for axis in EMPModuleAxis.allCases {
      let before = await f.runtime.snapshot()
      let old = try EMPBankOwnershipFixture.item(before.commander)
      let grades = try #require(old.empGrades)
      let context = try await f.context(axis)
      let expectedDebit = axis == .power ? 30000 : 15000
      #expect(context.price == expectedDebit)
      let receipt = try await f.runtime.purchaseEMPModuleUpgrade(context)
      let after = await f.runtime.snapshot()
      let actual = try EMPBankOwnershipFixture.item(after.commander)
      #expect(receipt.paidPrice == expectedDebit && receipt.module == original.id)
      #expect(actual.empGrades?.indices == grades.indices.advancing(axis))
      #expect(actual.empBank?.remaining == 0 && actual.empBank?.lastDischarge == old.empBank?.lastDischarge)
      #expect(actual.id == old.id && actual.provenance == old.provenance && actual.location == old.location)
      #expect(actual.component == old.component && actual.nativeRepairLoopCondition == old.nativeRepairLoopCondition)
      #expect(after.commander.credits == before.commander.credits - expectedDebit)
      #expect(after.commander.equipmentPurchaseHistory == initialHistory)
      #expect(after.commander.equipmentInventory?.items.filter { $0.id != old.id }
        == before.commander.equipmentInventory?.items.filter { $0.id != old.id })
      #expect(after.energy == before.energy && after.frontShield == before.frontShield
        && after.rearShield == before.rearShield)
      #expect(try NativeSaveTestFixture.readVersionedCommander(from: f.file) == after.commander)
      await #expect(throws: EMPModulePurchaseError.staleContext) {
        _ = try await f.runtime.purchaseEMPModuleUpgrade(context)
      }
      #expect(await f.runtime.snapshot().commander == after.commander)
    }
    let cold = GameRuntime()
    try await cold.load(from: f.file, persistMigrations: false)
    let loaded = await cold.snapshot()
    let final = await f.runtime.snapshot()
    #expect(loaded.commander == final.commander)
    #expect(try EMPBankOwnershipFixture.item(loaded.commander).empGrades?.paid.count == 3)
  }

  @Test func actualPlughPricePolicyAndSameModulePredecessorsApplyAtEveryStep() async throws {
    let f = try await EMPModulePurchaseFixture(plugh: true, useOwnedStarter: true)
    defer { f.clean() }
    let first = await f.runtime.snapshot()
    let base = try EMPBankOwnershipFixture.item(first.commander)
    #expect(first.commander.equipmentPurchaseHistory?.paid.last?.price == 22500)
    var total = 0
    for expected in [22500, 45000, 90000] {
      let before = await f.runtime.snapshot()
      let context = try await f.context(.power)
      #expect(context.price == expected)
      let receipt = try await f.runtime.purchaseEMPModuleUpgrade(context)
      total += expected
      #expect(receipt.module == base.id && receipt.shop == "galaxy:0/system:256")
      #expect(await f.runtime.snapshot().commander.credits == before.commander.credits - expected)
    }
    let after = await f.runtime.snapshot()
    let module = try EMPBankOwnershipFixture.item(after.commander)
    #expect(module.empGrades?.power == 3 && module.empGrades?.capacity == 0 && module.empGrades?.recharge == 0)
    #expect(module.empGrades?.paid.count == 3 && module.empBank?.capacity == 8 && module.empBank?.remaining == 0)
    #expect(after.commander.credits == first.commander.credits - total)
    #expect(throws: EMPModulePurchaseError.unavailable) {
      _ = try after.empModulePurchaseContext(module: module.id, axis: .power)
    }
  }

  @Test func failedActualGradeWriterKeepsAllPropertyThenFreshRetryAndColdLoadCommitOnce()
    async throws
  {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let context = try await f.context(.capacity)
    let before = await f.runtime.snapshot()
    let directory = f.file.deletingLastPathComponent()
    let property = try EMPModulePurchaseFixture.files(directory)
    let backup = f.folder.appendingPathComponent("backup")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked".utf8).write(to: directory)
    await #expect(throws: (any Error).self) { _ = try await f.runtime.purchaseEMPModuleUpgrade(context) }
    let refused = await f.runtime.snapshot()
    #expect(refused.commander == before.commander && refused.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(try EMPModulePurchaseFixture.files(backup) == property)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    let fresh = try await f.context(.capacity)
    _ = try await f.runtime.purchaseEMPModuleUpgrade(fresh)
    let after = await f.runtime.snapshot()
    let module = try EMPBankOwnershipFixture.item(after.commander)
    #expect(module.empGrades?.capacity == 1 && module.empGrades?.paid.count == 1)
    #expect(module.empBank?.capacity == 16 && module.empBank?.remaining == 0)
    #expect(after.commander.credits == before.commander.credits - 15000)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: f.file) == after.commander)
    let cold = GameRuntime()
    try await cold.load(from: f.file, persistMigrations: false)
    #expect(await cold.snapshot().commander == after.commander)
  }

  @Test func capacityGrowthKeepsControlledNonzeroChargeAndStoredModuleIdentity() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    var controlled = await f.runtime.snapshot()
    let original = try EMPBankOwnershipFixture.item(controlled.commander)
    let bank = try #require(EMPBankState(
      module: original.id, capacity: 8, remaining: 3,
      at: controlled.commander.flightSimulation.physicalTime))
    try EMPBankOwnershipFixture.replace(bank, in: &controlled.commander)
    let stored = try EMPBankOwnershipFixture.item(controlled.commander)
    let revision = try #require(controlled.commander.equipmentInventory?.revision)
    try controlled.commander.storeEquipment(stored, expectedRevision: revision)
    // Controlled unit charge is not an assertion that flight recharge has been integrated.
    let runtime = GameRuntime(game: controlled, saveURL: f.file)
    try await runtime.save(to: f.file)
    let context = try await f.context(.capacity, runtime: runtime)
    _ = try await runtime.purchaseEMPModuleUpgrade(context)
    let after = await runtime.snapshot()
    let item = try EMPBankOwnershipFixture.item(after.commander)
    #expect(item.id == original.id && item.location == nil && item.empBank?.remaining == 3)
    #expect(item.empBank?.capacity == 16 && item.empGrades?.indices == .init(power: 0, capacity: 1, recharge: 0))
    #expect(item.empBank?.lastDischarge == bank.lastDischarge && item.provenance == original.provenance)
  }

  @Test func grantForeignModuleFundsAndUnboundWriterCannotCreatePaidGrades() async throws {
    var grant = try EMPBankOwnershipFixture.game(initialBalance: 0)
    grant.screen = .equipment
    grant.commander.system = Plugh.systemID
    grant.commander.discoverPlugh(in: grant.commander.galaxy)
    grant.commander.credits = 1_000_000
    let item = try EMPBankOwnershipFixture.item(grant.commander)
    #expect(throws: EMPModulePurchaseError.missingPaidBase) {
      _ = try grant.empModulePurchaseContext(module: item.id, axis: .power)
    }
    let f = try await EMPModulePurchaseFixture()
    defer { f.clean() }
    var snapshot = await f.runtime.snapshot()
    let paid = try EMPBankOwnershipFixture.item(snapshot.commander)
    #expect(throws: EMPModulePurchaseError.unavailable) {
      _ = try snapshot.empModulePurchaseContext(module: UUID(), axis: .power)
    }
    snapshot.commander.credits = 0
    #expect(throws: EMPModulePurchaseError.insufficientFunds) {
      _ = try snapshot.empModulePurchaseContext(module: paid.id, axis: .power)
    }
    let unbound = GameRuntime(game: await f.runtime.snapshot())
    let context = try await f.context(.power, runtime: unbound)
    let before = await unbound.snapshot()
    await #expect(throws: SaveError.invalidCommander) {
      _ = try await unbound.purchaseEMPModuleUpgrade(context)
    }
    #expect(await unbound.snapshot().commander == before.commander)
  }

  @Test func carriedEMPCountsOneHundredKilogramsOnceBeforeRoundingAndRejectsFullHold() throws {
    var game = try EMPBankOwnershipFixture.ownedStarterGame()
    #expect(game.commander.checkedCargoTonnes == 0)
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster, at: .utility(.empPirateBlaster), provenance: .grant("mass fixture"))
    #expect(game.commander.checkedCargoTonnes == 1)
    var inventory = try #require(game.commander.equipmentInventory)
    let context = try EMPBankOwnershipFixture.context(game.commander)
    for _ in 0..<9 {
      let id = UUID()
      let bank = try #require(EMPBankState(module: id, capacity: 8, remaining: 0, at: 0))
      try inventory.admit(
        .init(id: id, node: EMPModuleGradePolicy.node, provenance: .grant("carried unit"),
          empBank: bank, empGrades: .base), expectedRevision: inventory.revision, context: context)
    }
    game.commander.savedEquipmentInventory = inventory
    #expect(game.commander.checkedCargoTonnes == 1 && game.commander.valid)
    var full = try EMPBankOwnershipFixture.ownedStarterGame()
    full.commander.cargo[0] = full.commander.standardCargoCapacity
    let before = full.commander
    #expect(before.valid)
    #expect(throws: (any Error).self) {
      try full.commander.grantEquipment(
        Equipment.empPirateBlaster, at: .utility(.empPirateBlaster), provenance: .grant("full hold"))
    }
    #expect(full.commander == before)
  }

  @Test func foreignOwnerPredatingBaseAndFutureGradeReceiptsCannotPublishCurrentProperty()
    async throws
  {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    _ = try await f.runtime.purchaseEMPModuleUpgrade(try await f.context(.power))
    let before = await f.runtime.snapshot()
    let property = try EMPModulePurchaseFixture.files(f.file.deletingLastPathComponent())
    let original = try #require(JSONSerialization.jsonObject(
      with: JSONEncoder().encode(before.commander)) as? [String: Any])
    for kind in ["owner", "beforeBase", "future"] {
      var object = original
      var inventory = try #require(object["savedEquipmentInventory"] as? [String: Any])
      var items = try #require(inventory["items"] as? [[String: Any]])
      let index = try #require(items.firstIndex { $0["empGrades"] != nil })
      var grades = try #require(items[index]["empGrades"] as? [String: Any])
      var paid = try #require(grades["paid"] as? [[String: Any]])
      switch kind {
      case "owner": paid[0]["owner"] = UUID().uuidString
      case "beforeBase":
        paid[0]["sourceInventoryRevision"] = 0
        paid[0]["resultingRevision"] = 1
      default: paid[0]["physicalTime"] = before.commander.flightSimulation.physicalTime + 1
      }
      grades["paid"] = paid
      items[index]["empGrades"] = grades
      inventory["items"] = items
      object["savedEquipmentInventory"] = inventory
      let invalid = try JSONDecoder().decode(
        Commander.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(!invalid.valid)
      await f.runtime.nativeCommand { $0.commander = invalid }
      #expect(await f.runtime.snapshot().commander == before.commander)
      #expect(try EMPModulePurchaseFixture.files(f.file.deletingLastPathComponent()) == property)
    }
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: f.file) == before.commander)
  }
}
