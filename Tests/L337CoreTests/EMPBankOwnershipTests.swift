import Foundation
import Testing

@testable import L337Core

/// Controlled bank values exercise ownership; they do not supply a real flight release witness.
enum EMPBankOwnershipFixture {
  static func node() throws -> EquipmentNodeID {
    try #require(EquipmentRuntimeCatalog.node(for: Equipment.empPirateBlaster))
  }

  static func context(_ commander: Commander) throws -> OwnedEquipmentContext {
    let inventory = try #require(commander.equipmentInventory)
    return EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance)
  }

  static func item(_ commander: Commander) throws -> OwnedEquipmentItem {
    let node = try node()
    return try #require(commander.equipmentInventory?.items.first { $0.node == node })
  }

  static func replace(_ bank: EMPBankState, in commander: inout Commander) throws {
    var inventory = try #require(commander.equipmentInventory)
    try inventory.replaceEMPBank(
      expected: item(commander), with: bank, expectedRevision: inventory.revision,
      context: context(commander))
    commander.savedEquipmentInventory = inventory
  }

  /// Actual initial owned game only; controlled EMP grants remain in game(initialBalance:).
  static func ownedStarterGame() throws -> Game {
    try #require(!OriginalDetailedHullStage.blocksRuntime(NewCommanderDefaults.shipID))
    var game = Game(executive: false)
    let initial = (
      shipID: game.commander.shipID, credits: game.commander.credits,
      fuel: game.commander.fuel, missiles: game.commander.missiles,
      energy: game.energy, frontShield: game.frontShield, rearShield: game.rearShield)
    try #require(initial.shipID == NewCommanderDefaults.shipID)
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    game.screen = .inventory
    try #require(game.commander.shipID == initial.shipID && game.commander.credits == initial.credits)
    try #require(game.commander.fuel == initial.fuel && game.commander.missiles == initial.missiles)
    try #require(game.energy == initial.energy && game.frontShield == initial.frontShield
      && game.rearShield == initial.rearShield)
    let inventory = try #require(game.commander.equipmentInventory)
    let rounds = inventory.items.filter { $0.node == EquipmentRuntimeCatalog.standardMissile }
    try #require(rounds.count == initial.missiles)
    try #require(rounds.allSatisfy {
      guard let location = $0.location, case .missilePylon(_) = location.slot else { return false }
      return location.hullInstanceID == inventory.activeHull
    })
    try #require(!inventory.items.contains { $0.node == EMPModuleGradePolicy.node })
    try #require(game.commander.valid)
    return game
  }

  static func game(initialBalance: Double?, useOwnedStarter: Bool = false) throws -> Game {
    var game: Game
    if useOwnedStarter {
      game = try ownedStarterGame()
    } else {
      game = try missionGearGame(missiles: 1)
    }
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
      provenance: .grant("explicit bank ownership fixture"))
    if let initialBalance {
      let module = try item(game.commander)
      let bank = try #require(
        EMPBankState(
          module: module.id, capacity: 8, remaining: initialBalance,
          at: game.commander.flightSimulation.physicalTime))
      if module.empBank != bank {
        try replace(bank, in: &game.commander)
      }
      let actual = try item(game.commander)
      try #require(actual.empBank == bank)
    }
    try #require(game.commander.valid)
    return game
  }

  static func historyGame(useOwnedStarter: Bool = false) throws -> Game {
    var game = try self.game(initialBalance: 6, useOwnedStarter: useOwnedStarter)
    game.ensurePhysicalActors()
    let module = try item(game.commander)
    let bank = try #require(module.empBank)
    let flight = game.commander.flightSimulation
    let system = try #require(flight.system)
    // Modeled historical value, not an actual runtime firing/emission receipt.
    var charge = EMPChargeState(
      player: .init(system: system, visit: flight.visit, entity: 0),
      target: .init(system: system, visit: flight.visit, entity: 2),
      owner: try #require(game.commander.equipmentOwnerID),
      hull: try #require(game.commander.hullInstanceID), weapon: module.id, startedAt: 0)
    charge.phase = .released
    charge.endedAt = 10
    let discharged = try #require(bank.stagingDischarge(charge, cost: 2)).bank
    game.commander.flightSimulation.advancePhysicalTime(10)
    game.time = 10
    try replace(discharged, in: &game.commander)
    try #require(game.commander.valid)
    return game
  }
}

struct EMPBankOwnershipTests {
  @Test func currentEMPRequiresBankAndGradesWhileUnrelatedCurrentItemsKeepEveryField() throws {
    let game = try EMPBankOwnershipFixture.game(initialBalance: nil, useOwnedStarter: true)
    let emp = try EMPBankOwnershipFixture.item(game.commander)
    #expect(emp.empBank?.remaining == 0 && emp.empGrades == .base)
    let id = UUID()
    let shield = OwnedEquipmentItem(
      id: id, node: .init(family: EquipmentPurchaseCatalog.shields, key: "Basic Shields"),
      provenance: .paid(owner: UUID(), transaction: UUID()),
      component: .init(id: id, origin: EquipmentModuleTemplates.shield.grades[0]),
      location: .init(hullInstanceID: UUID(), slot: .shield), boundHull: UUID(),
      preferredSlot: .shield,
      retainedLegacyState: .init(conditionBasisPoints: 10000, modifications: [:]))
    let repair = OwnedEquipmentItem(
      id: UUID(), node: try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops")),
      provenance: .grant("current repair field"),
      nativeRepairLoopCondition: .failed(sourceUnit: UUID()))
    var keys: Set<String> = []
    for original in [shield, repair] {
      let bytes = try JSONEncoder().encode(original)
      let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      keys.formUnion(object.keys)
      #expect(object["empBank"] == nil && object["empGrades"] == nil)
      #expect(try JSONDecoder().decode(OwnedEquipmentItem.self, from: bytes) == original)
    }
    #expect(keys == [
      "id", "node", "provenance", "component", "location", "boundHull", "preferredSlot",
      "retainedLegacyState", "nativeRepairLoopCondition",
    ])
    let bytes = try JSONEncoder().encode(emp)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(try JSONDecoder().decode(OwnedEquipmentItem.self, from: bytes) == emp)
    for key in ["empBank", "empGrades"] {
      for null in [false, true] {
        var malformed = object
        if null { malformed[key] = NSNull() } else { malformed.removeValue(forKey: key) }
        #expect(throws: DecodingError.self) {
          _ = try JSONDecoder().decode(
            OwnedEquipmentItem.self, from: JSONSerialization.data(withJSONObject: malformed))
        }
      }
    }
  }

  @Test func foreignModuleWrongNodeAndMalformedBankRefuseItemAndInventoryDecode() throws {
    let game = try EMPBankOwnershipFixture.game(initialBalance: 0, useOwnedStarter: true)
    let item = try EMPBankOwnershipFixture.item(game.commander)
    let bytes = try JSONEncoder().encode(item)
    let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for kind in ["null", "module", "balance", "node", "missingHistory"] {
      var object = original
      var bank = try #require(object["empBank"] as? [String: Any])
      switch kind {
      case "null": object["empBank"] = NSNull()
      case "module": bank["module"] = UUID().uuidString; object["empBank"] = bank
      case "balance": bank["remaining"] = 9; object["empBank"] = bank
      case "node":
        object["node"] = try JSONSerialization.jsonObject(
          with: JSONEncoder().encode(try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))))
      default: bank.removeValue(forKey: "lastDischarge"); object["empBank"] = bank
      }
      let bad = try JSONSerialization.data(withJSONObject: object)
      #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(OwnedEquipmentItem.self, from: bad)
      }
      let ownedInventory = try #require(game.commander.equipmentInventory)
      var inventory = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(
          ownedInventory)) as? [String: Any])
      inventory["items"] = [object]
      let invalidInventory = try JSONSerialization.data(withJSONObject: inventory)
      #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(OwnedEquipmentInventory.self, from: invalidInventory)
      }
    }
    #expect(try JSONDecoder().decode(OwnedEquipmentItem.self, from: bytes) == item)
  }

  @Test func fitStoreAndOccupiedReplacementRetainExactModuleBankAndOriginalProperty() throws {
    let game = try EMPBankOwnershipFixture.historyGame(useOwnedStarter: true)
    var inventory = try #require(game.commander.equipmentInventory)
    let original = try EMPBankOwnershipFixture.item(game.commander)
    let context = try EMPBankOwnershipFixture.context(game.commander)
    let slot = try #require(original.location)
    try inventory.store(expected: original, expectedRevision: inventory.revision, context: context)
    let stored = try #require(inventory.items.first { $0.id == original.id })
    #expect(stored == original.moved(to: nil) && stored.empBank == original.empBank)
    let spareID = UUID()
    let spareBank = try #require(EMPBankState(module: spareID, capacity: 8, remaining: 0, at: 10))
    let spare = OwnedEquipmentItem(
      id: spareID, node: original.node, provenance: .grant("explicit spare"),
      empBank: spareBank, empGrades: .base)
    try inventory.admit(spare, expectedRevision: inventory.revision, context: context)
    try inventory.fit(expected: stored, at: slot, expectedRevision: inventory.revision, context: context)
    let fitted = try #require(inventory.items.first { $0.id == original.id })
    try inventory.fit(
      expected: spare, at: slot, replacing: fitted,
      expectedRevision: inventory.revision, context: context)
    #expect(inventory.items.first { $0.id == original.id } == stored)
    #expect(inventory.items.first { $0.id == spareID }?.empBank == spareBank)
    #expect(original.empBank?.remaining == 4 && spareBank.remaining == 0)
  }

  @Test func bankReplacementUsesActualExpectedItemRevisionAndContextWithoutOtherPropertyChanges()
    throws
  {
    let game = try EMPBankOwnershipFixture.game(initialBalance: 3, useOwnedStarter: true)
    var inventory = try #require(game.commander.equipmentInventory)
    let item = try EMPBankOwnershipFixture.item(game.commander)
    let before = inventory
    let bank = try #require(item.empBank)
    let next = try #require(bank.skippingCharge(to: 1))
    try inventory.replaceEMPBank(
      expected: item, with: next, expectedRevision: inventory.revision,
      context: EMPBankOwnershipFixture.context(game.commander))
    let updated = try #require(inventory.items.first { $0.id == item.id })
    #expect(updated.empBank == next && updated.empBank?.remaining == bank.remaining)
    #expect(updated.id == item.id && updated.node == item.node && updated.provenance == item.provenance)
    #expect(updated.location == item.location && updated.boundHull == item.boundHull)
    #expect(updated.component == item.component && updated.preferredSlot == item.preferredSlot)
    #expect(updated.retainedLegacyState == item.retainedLegacyState)
    #expect(updated.nativeRepairLoopCondition == item.nativeRepairLoopCondition)
    #expect(inventory.revision == before.revision + 1)
    #expect(inventory.items.filter { $0.id != item.id } == before.items.filter { $0.id != item.id })
  }

  @Test func staleForeignBackwardAndNoChangeBankReplacementsLeaveInventoryUntouched() throws {
    let game = try EMPBankOwnershipFixture.historyGame(useOwnedStarter: true)
    var inventory = try #require(game.commander.equipmentInventory)
    let item = try EMPBankOwnershipFixture.item(game.commander)
    let bank = try #require(item.empBank)
    let context = try EMPBankOwnershipFixture.context(game.commander)
    let before = inventory
    let next = try #require(bank.skippingCharge(to: 11))
    #expect(throws: OwnedEquipmentError.staleRevision) {
      try inventory.replaceEMPBank(
        expected: item, with: next, expectedRevision: inventory.revision + 1, context: context)
    }
    let foreign = try #require(EMPBankState(module: UUID(), capacity: 8, remaining: 4, at: 11))
    let backward = try #require(EMPBankState(module: item.id, capacity: 8, remaining: 4, at: 9))
    for invalid in [foreign, backward] {
      #expect(throws: OwnedEquipmentError.invalidStructure) {
        try inventory.replaceEMPBank(
          expected: item, with: invalid, expectedRevision: inventory.revision, context: context)
      }
    }
    #expect(throws: OwnedEquipmentError.noChange) {
      try inventory.replaceEMPBank(
        expected: item, with: bank, expectedRevision: inventory.revision, context: context)
    }
    #expect(inventory == before)
    try inventory.replaceEMPBank(
      expected: item, with: next, expectedRevision: inventory.revision, context: context)
    let after = inventory
    #expect(throws: OwnedEquipmentError.staleItem) {
      try inventory.replaceEMPBank(
        expected: item, with: try #require(next.skippingCharge(to: 12)),
        expectedRevision: inventory.revision, context: context)
    }
    #expect(inventory == after)
  }

  @Test func actualPortableHullTransferPreservesBankIdentityBalanceTimeAndReleaseHistory() throws {
    let game = try EMPBankOwnershipFixture.historyGame()
    var commander = game.commander
    // Supply the same resource prerequisite the actual hull-trade caller settles separately.
    commander.fuel = 0
    let original = commander
    let item = try EMPBankOwnershipFixture.item(commander)
    let hull = UUID()
    try commander.transferEquipment(to: "SH001", hullID: hull)
    let after = try EMPBankOwnershipFixture.item(commander)
    #expect(after.moved(to: nil) == item.moved(to: nil))
    #expect(after.empBank == item.empBank && after.empBank?.lastDischarge != nil)
    #expect(commander.hullInstanceID == hull && commander.equipmentOwnerID == original.equipmentOwnerID)
    #expect(commander.equipmentInventory?.revision == original.equipmentInventory!.revision + 1)
    #expect(commander.equipmentPurchaseHistory == original.equipmentPurchaseHistory)
    #expect(commander.credits == original.credits && commander.valid)
    #expect(commander.flightSimulation.physicalTime == original.flightSimulation.physicalTime)
  }

  @Test func unrelatedPaidComponentUpgradeDoesNotAlterStoredEMPBank() throws {
    let game = try EMPBankOwnershipFixture.game(initialBalance: 2, useOwnedStarter: true)
    var inventory = try #require(game.commander.equipmentInventory)
    let emp = try EMPBankOwnershipFixture.item(game.commander)
    let shield = try #require(
      inventory.items.first { $0.component?.family == EquipmentModuleTemplates.shieldFamily })
    let component = try #require(shield.component)
    let definition = try #require(
      EquipmentRuntimeCatalog.definition(for: shield.node.family))
    let effect = ComponentUpgrade(
      identity: .service(UUID()), boundComponent: component.id, origin: component.origin.identity,
      basisPoints: [.frontShieldCapacity: 1500])
    let quote = try ComponentProgression.quote(
      component: component, item: effect, definition: definition, inventoryRevision: 77)
    let application = try ComponentProgression.apply(
      quote, component: component, item: effect, definition: definition, inventoryRevision: 77)
    try inventory.replaceGradedInstance(
      expected: shield, application: application, expectedRevision: inventory.revision,
      sourceInventoryRevision: 77, context: EMPBankOwnershipFixture.context(game.commander))
    #expect(inventory.items.first { $0.id == emp.id } == emp)
    #expect(inventory.items.first { $0.id == shield.id }?.component == application.component)
    #expect(emp.empBank?.remaining == 2)
  }

  @Test func actualPaidEMPQuoteAttachesOnlyExplicitMatchingBankAndRefusesStaleOrForeignInputs()
    throws
  {
    var game = try EMPBankOwnershipFixture.ownedStarterGame()
    game.screen = .equipment
    game.commander.credits = 100_000
    let equipment = try #require(Equipment.all.first { $0.name == Equipment.empPirateBlaster })
    game.commander.system = try #require(game.systems.first {
      !$0.isPlugh && $0.technology >= equipment.requiredTechnologyLevel
    }?.id)
    let quote = try game.quoteEquipmentPurchase(equipment)
    let original = quote.prepared
    var commander = original
    let bank = try #require(
      EMPBankState(
        module: quote.request.newItem, capacity: 8, remaining: 0,
        at: commander.flightSimulation.physicalTime))
    let foreign = try #require(
      EMPBankState(module: UUID(), capacity: 8, remaining: 0, at: bank.physicalTime))
    let future = try #require(bank.skippingCharge(to: bank.physicalTime + 1))
    for invalid in [foreign, future] {
      #expect(throws: EquipmentRuntimeError.incompatibleFit) {
        _ = try commander.acceptEquipmentPurchase(quote, initialEMPBank: invalid, initialEMPGrades: .base)
      }
      #expect(commander == original)
    }
    let fitted = try commander.acceptEquipmentPurchase(quote, initialEMPBank: bank, initialEMPGrades: .base)
    #expect(fitted && commander.valid)
    let item = try EMPBankOwnershipFixture.item(commander)
    #expect(item.id == quote.request.newItem && item.empBank == bank && item.empBank?.remaining == 0)
    #expect(commander.credits == original.credits - quote.purchase.requiredDebit)
    #expect(
      commander.equipmentPurchaseHistory?.paid.count
        == original.equipmentPurchaseHistory!.paid.count + 1)
    let paid = commander
    #expect(throws: EquipmentRuntimeError.staleCommander) {
      _ = try commander.acceptEquipmentPurchase(quote, initialEMPBank: bank, initialEMPGrades: .base)
    }
    #expect(commander == paid)
    var oldEntry = original
    _ = try oldEntry.acceptEquipmentPurchase(quote)
    #expect(try EMPBankOwnershipFixture.item(oldEntry).empBank == bank)
    #expect(try EMPBankOwnershipFixture.item(oldEntry).empGrades == .base)
    #expect(oldEntry.credits == commander.credits)
    #expect(oldEntry.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
  }
}
