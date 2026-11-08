import Foundation
import Testing
import L337Core

/// Ordinary public client; existing controlled fixtures supply state, never new payment authority.
struct EMPModulePublicPresentationTests {
  private func panel(_ game: Game, selected: UUID? = nil, page: Int = 0,
    width: Double = 1000, height: Double = 720) -> EMPModuleUpgradePresentation
  {
    game.empModuleUpgradePresentation(selected: selected, page: page, width: width, height: height)
  }

  private func intents(_ presentation: EMPModuleUpgradePresentation) -> [EMPModulePurchaseContext] {
    presentation.controls.compactMap {
      if case .purchase(let context) = $0.action { return context }
      return nil
    }
  }

  private func selectedEMP(_ game: inout Game) throws {
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == Equipment.empPirateBlaster })
  }

  /// Controlled second grant, encoded with the current codec. This is not a native acquisition proof.
  private func addingStoredGrant(to game: Game) throws -> Game {
    let grant = try EMPBankOwnershipFixture.game(initialBalance: 0, useOwnedStarter: true)
    let item = try EMPBankOwnershipFixture.item(grant.commander)
    var spare = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
    let id = UUID()
    spare["id"] = id.uuidString
    spare["location"] = NSNull()
    var bank = try #require(spare["empBank"] as? [String: Any])
    bank["module"] = id.uuidString
    spare["empBank"] = bank
    var commander = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander)) as? [String: Any])
    var inventory = try #require(commander["savedEquipmentInventory"] as? [String: Any])
    var items = try #require(inventory["items"] as? [[String: Any]])
    items.append(spare)
    inventory["items"] = items
    inventory["revision"] = try #require(inventory["revision"] as? Int) + 1
    commander["savedEquipmentInventory"] = inventory
    var result = game
    result.commander = try JSONDecoder().decode(Commander.self,
      from: JSONSerialization.data(withJSONObject: commander))
    try #require(result.commander.valid)
    return result
  }

  @Test func publicPresentationShowsActualBankAndDisabledQuoteWithoutMutation() async throws {
    func expectRefusal(_ snapshot: Game, reason: String) throws {
      let before = snapshot.commander
      let epoch = snapshot.inventoryContextEpoch
      let presentation = panel(snapshot)
      let reasons = presentation.controls.compactMap { control -> String? in
        if case .disabled(let reason) = control.action { return reason }
        return nil
      }
      #expect(intents(presentation).isEmpty)
      #expect(reasons == Array(repeating: reason, count: 3))
      #expect(presentation.frame.labels.filter { $0.text == reason }.count == 3)
      #expect(snapshot.commander == before && snapshot.inventoryContextEpoch == epoch)
      #expect(presentation.isCurrent(in: snapshot))
    }
    var game = try EMPBankOwnershipFixture.game(initialBalance: 3, useOwnedStarter: true)
    try selectedEMP(&game)
    game.commander.system = Plugh.systemID
    game.commander.plughDiscoveryMask |= 1 << game.commander.galaxy
    game.commander.credits = 1_000_000
    try #require(game.commander.valid)
    let before = game.commander
    let presentation = panel(game)
    let readout = try #require(presentation.bank)
    #expect(readout.remaining == 3 && readout.capacity == 8 && readout.storedShots == 0)
    #expect(readout.powerGrade == 0 && readout.capacityGrade == 0 && readout.rechargeGrade == 0)
    #expect(intents(presentation).isEmpty)
    let disabled = presentation.controls.filter { if case .disabled = $0.action { true } else { false } }
    #expect(disabled.count == 3)
    #expect(game.commander == before && presentation.isCurrent(in: game))
    game.commander.credits -= 1
    #expect(!presentation.isCurrent(in: game))
    try expectRefusal(game, reason: "PAID OWNED MODULE REQUIRED")

    // Every maximum grade comes from the real paid base and the public actor writer.
    let paid = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { paid.clean() }
    let initial = await paid.runtime.snapshot()
    let module = try #require(initial.empModuleBankReadouts.first?.moduleID)
    var cashless = initial
    cashless.commander.credits = 0
    try #require(cashless.commander.valid)
    let fundsRuntime = GameRuntime(game: cashless)
    let fundsBefore = await fundsRuntime.snapshot()
    let originalFiles = try EMPModulePurchaseFixture.files(paid.folder)
    try expectRefusal(fundsBefore, reason: "INSUFFICIENT CREDITS")
    let fundsAfter = await fundsRuntime.snapshot()
    #expect(fundsAfter.commander == fundsBefore.commander
      && fundsAfter.inventoryContextEpoch == fundsBefore.inventoryContextEpoch)
    #expect(try EMPModulePurchaseFixture.files(paid.folder) == originalFiles)

    for axis in EMPModuleAxis.allCases {
      for next in 1...3 {
        let source = await paid.runtime.snapshot()
        let context = try #require(intents(panel(source)).first { $0.axis == axis })
        #expect(context.moduleID == module && context.next == next && context.price > 0)
        try await paid.runtime.confirmEMPModuleUpgrade(context)
        let committed = await paid.runtime.snapshot()
        #expect(committed.commander.credits == source.commander.credits - context.price)
        #expect(committed.empModuleBankReadouts.first?.moduleID == module)
      }
    }
    let maximum = await paid.runtime.snapshot()
    let bank = try #require(maximum.empModuleBankReadouts.first)
    #expect(bank.moduleID == module && bank.powerGrade == 3
      && bank.capacityGrade == 3 && bank.rechargeGrade == 3 && bank.remaining == 0)
    let maximumFiles = try EMPModulePurchaseFixture.files(paid.folder)
    try expectRefusal(maximum, reason: "MAXIMUM GRADE")
    let maximumAfter = await paid.runtime.snapshot()
    #expect(maximumAfter.commander == maximum.commander
      && maximumAfter.inventoryContextEpoch == maximum.inventoryContextEpoch)
    #expect(try EMPModulePurchaseFixture.files(paid.folder) == maximumFiles)

    // The existing acceptance/gear.issue path owns this loan and its obligation.
    // G1 composes the reserved paired EMP issuance producer before executing this test.
    let loanFixture = try GearScriptFixture(name: Equipment.empPirateBlaster, loan: true)
    defer { loanFixture.clean() }
    var loanGame = try loanFixture.game()
    try selectedEMP(&loanGame)
    loanGame.commander.system = Plugh.systemID
    loanGame.commander.plughDiscoveryMask |= 1 << loanGame.commander.galaxy
    loanGame.commander.credits = 1_000_000
    let issue = try #require(loanGame.commander.scriptState.instances.values.first?.gearIssues["kit"])
    try #require(issue.loan && issue.status == .issued && issue.items.count == 1)
    let loanModule = try #require(loanGame.empModuleBankReadouts.first?.moduleID)
    #expect(issue.items == [loanModule])
    try #require(loanGame.commander.valid)
    let loanFile = loanFixture.root.appendingPathComponent("save/commander.json")
    let loanRuntime = GameRuntime(game: loanGame, saveURL: loanFile)
    try await loanRuntime.save(to: loanFile)
    let loanBefore = await loanRuntime.snapshot()
    let loanFiles = try EMPModulePurchaseFixture.files(loanFixture.root)
    try expectRefusal(loanBefore, reason: "LOAN: UPGRADES UNAVAILABLE")
    let loanAfter = await loanRuntime.snapshot()
    #expect(loanAfter.commander == loanBefore.commander
      && loanAfter.inventoryContextEpoch == loanBefore.inventoryContextEpoch)
    #expect(try EMPModulePurchaseFixture.files(loanFixture.root) == loanFiles)
  }

  @Test func multipleModuleChoiceRequiresVisibleExactUUIDBeforeIntents() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let game = try addingStoredGrant(to: await f.runtime.snapshot())
    let first = panel(game)
    #expect(first.selectedModule == nil && first.bank == nil && intents(first).isEmpty)
    let paid = try #require((await f.runtime.snapshot()).empModuleBankReadouts.first?.moduleID)
    let ordered = game.empModuleBankReadouts.sorted { $0.moduleID.uuidString < $1.moduleID.uuidString }
    let page = try #require(ordered.firstIndex { $0.moduleID == paid })
    let chosen = panel(game, selected: paid, page: page)
    #expect(chosen.visibleModule == paid && chosen.selectedModule == paid && chosen.bank?.moduleID == paid)
    #expect(intents(chosen).count == 3 && intents(chosen).allSatisfy { $0.moduleID == paid })
    let hidden = panel(game, selected: paid, page: 1 - page)
    #expect(hidden.selectedModule == nil && hidden.bank == nil && intents(hidden).isEmpty)
    let chooseControl = try #require(chosen.controls.first)
    if case .choose(let actual)? = chosen.action(at: .init(chooseControl.bounds.x + 1, chooseControl.bounds.y + 1)) {
      #expect(actual == paid)
    } else { Issue.record("Visible module control must select its exact UUID") }
  }

  @Test func publicIntentUsesCurrentShopPriceAndCommitsSameModuleOnly() async throws {
    let f = try await EMPModulePurchaseFixture(plugh: true, useOwnedStarter: true)
    defer { f.clean() }
    let before = await f.runtime.snapshot()
    let context = try #require(intents(panel(before)).first { $0.axis == .power })
    #expect(context.price == 22500 && context.next == 1)
    let original = try #require(before.commander.equipmentInventory?.items.first { $0.id == context.moduleID })
    try await f.runtime.confirmEMPModuleUpgrade(context)
    let after = await f.runtime.snapshot()
    let bank = try #require(after.empModuleBankReadouts.first { $0.moduleID == context.moduleID })
    let item = try #require(after.commander.equipmentInventory?.items.first { $0.id == original.id })
    #expect(after.commander.credits == before.commander.credits - context.price)
    #expect(bank.powerGrade == 1 && bank.capacityGrade == 0 && bank.rechargeGrade == 0)
    #expect(bank.capacity == 8 && bank.remaining == 0)
    #expect(item.id == original.id && item.provenance == original.provenance && item.location == original.location)
    #expect(after.commander.equipmentInventory?.items.filter { $0.id != item.id }
      == before.commander.equipmentInventory?.items.filter { $0.id != item.id })
    #expect(after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(!context.isCurrent(in: after))
    let cold = GameRuntime()
    try await cold.load(from: f.file, persistMigrations: false)
    #expect(await cold.snapshot().commander == after.commander)
  }

  @Test func publicIntentRefusesStaleSourceAndFailedWriterWithoutPublication() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let first = await f.runtime.snapshot()
    let stale = try #require(intents(panel(first)).first { $0.axis == .power })
    await f.runtime.key("down")
    let moved = await f.runtime.snapshot()
    #expect(!stale.isCurrent(in: moved))
    let bytes = try EMPModulePurchaseFixture.files(f.folder)
    await #expect(throws: (any Error).self) { try await f.runtime.confirmEMPModuleUpgrade(stale) }
    #expect(await f.runtime.snapshot().commander == moved.commander)
    #expect(try EMPModulePurchaseFixture.files(f.folder) == bytes)
    await f.runtime.key("up")
    let before = await f.runtime.snapshot()
    let context = try #require(intents(panel(before)).first { $0.axis == .capacity })
    let directory = f.file.deletingLastPathComponent()
    let property = try EMPModulePurchaseFixture.files(directory)
    let backup = f.folder.appendingPathComponent("public-client-backup")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked".utf8).write(to: directory)
    await #expect(throws: (any Error).self) { try await f.runtime.confirmEMPModuleUpgrade(context) }
    let refused = await f.runtime.snapshot()
    #expect(refused.commander == before.commander && refused.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(try EMPModulePurchaseFixture.files(backup) == property)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    let fresh = try #require(intents(panel(await f.runtime.snapshot())).first { $0.axis == .capacity })
    try await f.runtime.confirmEMPModuleUpgrade(fresh)
    let committed = await f.runtime.snapshot()
    #expect(committed.commander.credits == before.commander.credits - fresh.price)
    #expect(committed.empModuleBankReadouts.first?.capacity == 16)
    let cold = GameRuntime()
    try await cold.load(from: f.file, persistMigrations: false)
    #expect(await cold.snapshot().commander == committed.commander)
  }

  @Test func managedPresentationKeepsControlsInsideVisibleViewport() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let game = await f.runtime.snapshot()
    for (width, height) in [(320.0, 256.0), (640, 480), (1440, 900)] {
      let presentation = panel(game, width: width, height: height)
      #expect(intents(presentation).count == 3)
      #expect(presentation.controls.count == 5)
      for control in presentation.controls {
        let b = control.bounds
        #expect(b.x >= 0 && b.y >= 0 && b.maxX <= width && b.maxY <= height)
        #expect(presentation.action(at: .init(b.x + 1, b.y + 1)) != nil)
      }
      for (index, control) in presentation.controls.enumerated() {
        for other in presentation.controls.dropFirst(index + 1) {
          #expect(control.bounds.maxY <= other.bounds.y || other.bounds.maxY <= control.bounds.y)
        }
      }
      #expect(presentation.action(at: .init(-1, -1)) == nil)
    }
    let compact = panel(game, width: 200, height: 120)
    #expect(intents(compact).isEmpty)
    #expect(compact.controls.count == 1)
    if case .back? = compact.controls.first?.action {} else { Issue.record("Small view requires Back") }
  }

  @Test func realBankHUDShowsStoredShotsAndRatedRechargeWithoutReadyOrETA() throws {
    var full = try EMPBankOwnershipFixture.game(initialBalance: 8, useOwnedStarter: true)
    full.screen = .front
    full.docked = false
    let actual = try #require(full.empModuleBankReadouts.first { $0.fitted })
    #expect(actual.remaining == 8 && actual.capacity == 8 && actual.storedShots == 1)
    #expect(actual.ratedRecharge == 0.4)
    let frame = Display.presentation(full, width: 1200, height: 900)
    let labels = frame.labels.map(\.text).joined(separator: " ").uppercased()
    #expect(labels.contains("EMP STORED:") && labels.contains("1 SHOTS"))
    #expect(labels.contains("EMP RATED RECHARGE:"))
    #expect(!labels.contains("EMP READY") && !labels.contains("EMP ETA"))
    let empty = try EMPBankOwnershipFixture.game(initialBalance: 0, useOwnedStarter: true)
    #expect(empty.empModuleBankReadouts.first?.storedShots == 0)
    #expect(empty.empModuleBankReadouts.first?.remaining == 0)
  }

  @Test func managementEntryPreservesBasePurchaseWithoutPaidOwnedModule() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let paid = await f.runtime.snapshot()
    #expect(paid.empModuleManagementAvailable && paid.empModuleReturnOpensManagement)
    #expect(paid.empModuleManagementBounds(width: 1200, height: 900) != nil)
    var grant = try EMPBankOwnershipFixture.game(initialBalance: 0, useOwnedStarter: true)
    try selectedEMP(&grant)
    #expect(grant.empModuleManagementAvailable && !grant.empModuleReturnOpensManagement)
    let original = grant.equipmentPurchaseContext
    _ = panel(grant)
    #expect(grant.equipmentPurchaseContext == original)
    var noModule = try EMPBankOwnershipFixture.ownedStarterGame()
    try selectedEMP(&noModule)
    #expect(!noModule.empModuleManagementAvailable && !noModule.empModuleReturnOpensManagement)
    #expect(noModule.empModuleManagementBounds(width: 1200, height: 900) == nil)
  }

  @Test func selectionBackAndDisabledActionsCannotBecomePurchases() async throws {
    let f = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { f.clean() }
    let game = await f.runtime.snapshot()
    let before = game.commander
    let bytes = try EMPModulePurchaseFixture.files(f.folder)
    let ordinary = panel(game)
    let choose = try #require(ordinary.controls.first)
    if case .choose(let id)? = ordinary.action(at: .init(choose.bounds.x + 1, choose.bounds.y + 1)) {
      #expect(id == ordinary.visibleModule)
    } else { Issue.record("Return on module choice must only select") }
    let back = try #require(ordinary.controls.last)
    if case .back? = ordinary.action(at: .init(back.bounds.x + 1, back.bounds.y + 1)) {}
    else { Issue.record("Back must not carry a purchase") }
    let busy = game.empModuleUpgradePresentation(selected: ordinary.selectedModule, busy: true,
      width: 1000, height: 720)
    #expect(intents(busy).isEmpty)
    #expect(busy.controls.filter { if case .disabled = $0.action { true } else { false } }.count == 3)
    #expect(await f.runtime.snapshot().commander == before)
    #expect(try EMPModulePurchaseFixture.files(f.folder) == bytes)
  }
}
