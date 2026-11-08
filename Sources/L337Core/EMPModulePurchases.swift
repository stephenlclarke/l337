import Foundation

enum EMPModulePurchaseError: Error, Equatable {
  case unavailable, invalidState, missingPaidBase, loan, insufficientFunds, staleContext
}

/// Painted facts allocate no transaction. The actor rechecks the complete source before payment.
public final class EMPModulePurchaseContext: Sendable {
  fileprivate let commander: Commander
  fileprivate let epoch: InventoryContextEpoch
  fileprivate let selection: Int
  fileprivate let mount: LaserMount
  fileprivate let workTool: Bool
  let item: OwnedEquipmentItem
  public let axis: EMPModuleAxis
  public let next: Int
  let shop: String
  let cataloguePrice: Int
  public let price: Int

  fileprivate init(
    game: borrowing Game, item: OwnedEquipmentItem, axis: EMPModuleAxis, next: Int,
    shop: String, offer: Equipment
  ) {
    commander = game.commander
    epoch = game.inventoryContextEpoch
    selection = game.selection
    mount = game.equipmentMount
    workTool = game.equipmentWorkTool
    self.item = item
    self.axis = axis
    self.next = next
    self.shop = shop
    cataloguePrice = offer.price
    price = game.shopPrice(offer)
  }

  public var moduleID: UUID { item.id }

  /// A paint-cache check only. The actor still resolves eligibility and payment again.
  public func isCurrent(in game: Game) -> Bool {
    guard game.commander == commander, game.inventoryContextEpoch == epoch,
      game.selection == selection, game.equipmentMount == mount, game.equipmentWorkTool == workTool,
      game.stationAllowsEquipmentServices, game.docked, game.screen == .equipment, !game.paused,
      !game.equipmentCrewSelected,
      let offer = EMPModuleGradePolicy.offer(axis: axis, next: next)
    else { return false }
    return game.equipmentAvailable(offer) && game.shopPrice(offer) == price
      && EMPModuleGradePolicy.shop(galaxy: game.commander.galaxy, system: game.commander.system) == shop
  }

}

extension Game {
  public func empModulePurchaseContext(module: UUID, axis: EMPModuleAxis) throws -> EMPModulePurchaseContext {
    guard stationAllowsEquipmentServices, docked, screen == .equipment, !paused,
      !equipmentCrewSelected, !commander.unlimitedCash, commander.valid,
      let inventory = commander.equipmentInventory, let history = commander.equipmentPurchaseHistory,
      let item = inventory.items.first(where: { $0.id == module }),
      item.node == EMPModuleGradePolicy.node, let grades = item.empGrades, item.empBankValid,
      let after = grades.indices.advancing(axis),
      let offer = EMPModuleGradePolicy.offer(axis: axis, next: after.value(for: axis)),
      equipmentAvailable(offer),
      let shop = EMPModuleGradePolicy.shop(galaxy: commander.galaxy, system: commander.system)
    else { throw EMPModulePurchaseError.unavailable }
    let obligations = try commander.equipmentIssueObligations()
    guard EquipmentIssueTransactions.activeLoan(for: item, obligations: obligations) == nil else {
      throw EMPModulePurchaseError.loan
    }
    guard EMPModuleGrades.hasPaidBase(item, owner: inventory.owner, history: history) else {
      throw EMPModulePurchaseError.missingPaidBase
    }
    let context = EMPModulePurchaseContext(
      game: self, item: item, axis: axis, next: after.value(for: axis), shop: shop, offer: offer)
    guard context.price > 0, commander.availableCredits >= context.price else {
      throw EMPModulePurchaseError.insufficientFunds
    }
    return context
  }

  fileprivate mutating func applyEMPModulePurchase(_ context: EMPModulePurchaseContext) throws
    -> EMPModulePaidUpgradeReceipt
  {
    guard commander == context.commander, inventoryContextEpoch == context.epoch,
      selection == context.selection, equipmentMount == context.mount,
      equipmentWorkTool == context.workTool
    else { throw EMPModulePurchaseError.staleContext }
    let fresh = try empModulePurchaseContext(module: context.item.id, axis: context.axis)
    guard fresh.item == context.item, fresh.next == context.next, fresh.shop == context.shop,
      fresh.cataloguePrice == context.cataloguePrice, fresh.price == context.price,
      let inventory = commander.equipmentInventory, inventory.revision < UInt64.max,
      let grades = context.item.empGrades, let bank = context.item.empBank,
      let indices = grades.indices.advancing(context.axis)
    else { throw EMPModulePurchaseError.staleContext }
    let time = commander.flightSimulation.physicalTime
    let nextBank: EMPBankState?
    if context.axis == .capacity {
      nextBank = bank.changingCapacity(
        to: EMPModuleGradePolicy.capacities[indices.capacity], at: time)?.bank
    } else {
      nextBank = bank.skippingCharge(to: time)
    }
    guard let nextBank, nextBank.remaining == bank.remaining,
      nextBank.lastDischarge == bank.lastDischarge
    else { throw EMPModulePurchaseError.invalidState }
    let receipt = EMPModulePaidUpgradeReceipt(
      operation: UUID(), owner: inventory.owner, module: context.item.id, axis: context.axis,
      before: grades.indices, after: indices, sourceInventoryRevision: inventory.revision,
      resultingRevision: inventory.revision + 1, physicalTime: time, shop: context.shop,
      cataloguePrice: context.cataloguePrice, paidPrice: context.price)
    let nextGrades = EMPModuleGrades(
      power: indices.power, capacity: indices.capacity, recharge: indices.recharge,
      paid: grades.paid + [receipt])
    let item = context.item
    let replacement = OwnedEquipmentItem(
      id: item.id, node: item.node, provenance: item.provenance, component: item.component,
      location: item.location, boundHull: item.boundHull, preferredSlot: item.preferredSlot,
      retainedLegacyState: item.retainedLegacyState,
      nativeRepairLoopCondition: item.nativeRepairLoopCondition,
      empBank: nextBank, empGrades: nextGrades)
    var candidate = commander
    candidate.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == item.id ? replacement : $0 },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance))
    candidate.credits -= context.price
    guard candidate.valid else { throw EMPModulePurchaseError.invalidState }
    commander = candidate
    inventoryContextEpoch = .init()
    return receipt
  }

  /// Prepare only the unpublished Gallery candidate; its owner publishes the final isolated trial.
  mutating func purchaseNativePeopleTrialEMPSetup() throws {
    guard isMissionTrial, trialDigest == NativePeopleGallery.digest, trialSeed != nil,
      scriptDurabilityAvailable, docked, dockedAtMainStation, !paused,
      screen == .status, stationAllowsEquipmentServices,
      commander.shipID == NewCommanderDefaults.shipID, commander.shipID == "SH025",
      commander.flightSimulation.physicalTime == 0, commander.flightSimulation.player == nil,
      commander.encounterDirector == nil, commander.savedEMPState == nil,
      commander.savedEMPCharge == nil, commander.valid, !commander.unlimitedCash,
      commander.credits == 100_000,
      let inventory = commander.equipmentInventory,
      let history = commander.equipmentPurchaseHistory,
      !inventory.items.contains(where: { $0.node == EMPModuleGradePolicy.node }),
      let offerIndex = Equipment.all.firstIndex(where: { $0.name == Equipment.empPirateBlaster })
    else { throw EMPModulePurchaseError.unavailable }
    var candidate = self
    candidate.screen = .equipment
    candidate.selection = offerIndex
    let quote = try candidate.quoteEquipmentPurchase(Equipment.all[offerIndex])
    guard quote.purchase.requiredDebit > 0,
      try candidate.applyEquipmentPurchase(quote),
      let module = candidate.currentEMPPlayerModule(),
      let paidHistory = candidate.commander.equipmentPurchaseHistory,
      EMPModuleGrades.hasPaidBase(module, owner: inventory.owner, history: paidHistory),
      paidHistory.paid.count == history.paid.count + 1,
      candidate.commander.credits == commander.credits - quote.purchase.requiredDebit
    else { throw EMPModulePurchaseError.invalidState }
    for axis in [EMPModuleAxis.power, .recharge] {
      let beforeCredits = candidate.commander.credits
      let context = try candidate.empModulePurchaseContext(module: module.id, axis: axis)
      guard context.next == 1 else { throw EMPModulePurchaseError.invalidState }
      let receipt = try candidate.applyEMPModulePurchase(context)
      guard receipt.owner == inventory.owner, receipt.module == module.id, receipt.axis == axis,
        receipt.after.value(for: axis) == 1, receipt.paidPrice > 0,
        candidate.commander.credits == beforeCredits - receipt.paidPrice
      else { throw EMPModulePurchaseError.invalidState }
    }
    guard let upgraded = candidate.currentEMPPlayerModule(), upgraded.id == module.id,
      let grades = upgraded.empGrades,
      grades.power == 1, grades.capacity == 0, grades.recharge == 1, grades.paid.count == 2,
      candidate.commander.equipmentInventory?.owner == inventory.owner,
      candidate.commander.equipmentInventory?.activeHull == inventory.activeHull,
      candidate.commander.shipID == commander.shipID, candidate.commander.valid
    else { throw EMPModulePurchaseError.invalidState }
    candidate.screen = screen
    candidate.selection = selection
    self = candidate
  }
}

extension GameRuntime {
  /// Same current writer barrier as equipmentTransaction; no suspension separates checks and save.
  func purchaseEMPModuleUpgrade(_ context: EMPModulePurchaseContext) throws
    -> EMPModulePaidUpgradeReceipt
  {
    let before = game
    do {
      guard scriptSaveURL != nil else { throw SaveError.invalidCommander }
      let receipt = try game.applyEMPModulePurchase(context)
      try commitScriptCommand(from: before)
      return receipt
    } catch {
      game = before
      throw error
    }
  }

  /// Public UI boundary: no receipt or mutable bank escapes the existing atomic transaction.
  public func confirmEMPModuleUpgrade(_ context: EMPModulePurchaseContext) throws {
    _ = try purchaseEMPModuleUpgrade(context)
  }

}
