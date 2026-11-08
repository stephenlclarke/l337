import Foundation

/// One actual owner interval, copied with Game and never encoded or accepted from a save.
struct EMPPlayerElectricalInterval: Sendable {
  let nonce: UUID
  let player: ActorIdentity
  let owner: UUID
  let hull: UUID
  let epoch: UUID
  let start: Double
  let end: Double
  let acceptedDelta: Double
  let capacity: Double
  let recharge: Double
  let opening: ElectricalReserve?
  let module: OwnedEquipmentItem?
  let inventoryRevision: UInt64?
  let eligible: Bool
  private(set) var closing: ElectricalReserve?
  private(set) var generated = 0.0
  private(set) var discarded = 0.0
  private(set) var netCredited = 0.0
  private(set) var mandatoryDebited = 0.0

  fileprivate init(
    player: ActorIdentity, owner: UUID, hull: UUID, epoch: UUID,
    start: Double, end: Double, acceptedDelta: Double, capacity: Double, recharge: Double,
    opening: ElectricalReserve?, module: OwnedEquipmentItem?, inventoryRevision: UInt64?,
    eligible: Bool
  ) {
    nonce = UUID()
    self.player = player
    self.owner = owner
    self.hull = hull
    self.epoch = epoch
    self.start = start
    self.end = end
    self.acceptedDelta = acceptedDelta
    self.capacity = capacity
    self.recharge = recharge
    self.opening = opening
    self.module = module
    self.inventoryRevision = inventoryRevision
    self.eligible = eligible
  }

  /// A saved cursor behind this start is a skipped gap, never a generation entitlement.
  var earnsCurrentInterval: Bool {
    guard eligible else { return false }
    guard let opening else { return module != nil }
    guard opening.physicalTime == start, opening.capacity == capacity,
      opening.recharge == recharge
    else { return false }
    return true
  }

  fileprivate mutating func posted(_ reserve: ElectricalReserve) {
    closing = reserve
    let prior = opening?.remaining ?? 0
    let begin = max(start, opening?.recoveryAt ?? start)
    let duration = min(acceptedDelta, max(0, end - begin))
    // Gross offer from this accepted interval, before capacity and representation losses.
    generated = earnsCurrentInterval ? duration * recharge : 0
    netCredited = max(0, reserve.remaining - min(prior, capacity))
    // Uncredited offer includes both capacity clipping and representational roundoff.
    // These are floating observations, not an asserted exact conservation identity.
    discarded = max(0, prior - capacity) + max(0, generated - netCredited)
  }

  fileprivate mutating func recordDebit(
    before: ElectricalReserve, after: ElectricalReserve
  ) -> Bool {
    guard closing == before, before.physicalTime == end, after.physicalTime == end,
      after.valid, after.capacity == before.capacity, after.recharge == before.recharge,
      after.remaining <= before.remaining
    else { return false }
    mandatoryDebited += before.remaining - after.remaining
    closing = after
    return mandatoryDebited.isFinite
  }
}

extension Game {
  /// The only issuer runs before the actual clock advance; it never manufactures a player.
  mutating func beginEMPPlayerElectricalInterval(delta: Double) {
    empPulseBeforeResultStorage = nil
    empPlayerElectricalInterval = nil
    let start = commander.flightSimulation.physicalTime
    let end = start + delta
    let craft = commander.performance
    let rate = craft.recharge * commander.energyRechargeMultiplier
    guard delta.isFinite, delta > 0, delta <= 0.1,
      start.isFinite, start >= 0, end.isFinite, end > start,
      craft.energy.isFinite, craft.energy > 0, rate.isFinite, rate >= 0,
      let player = commander.flightSimulation.player, player.entity == 0, player.visit > 0,
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID
    else { return }
    let module = currentEMPPlayerModule()
    let opening = commander.savedPlayerElectrical
    guard opening != nil || module != nil else { return }
    guard opening.map({ $0.valid && $0.physicalTime <= start }) ?? true else { return }
    empPlayerElectricalInterval = .init(
      player: player, owner: owner, hull: hull, epoch: nativeStationRuntimeEpoch,
      start: start, end: end, acceptedDelta: delta, capacity: craft.energy, recharge: rate,
      opening: opening, module: module, inventoryRevision: commander.equipmentInventory?.revision,
      eligible: !paused && !docked && screen.isFlight && energy > 0)
  }

  func currentEMPPlayerModule() -> OwnedEquipmentItem? {
    guard let item = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      item.node == EMPModuleGradePolicy.node, item.empBankValid,
      let bank = item.empBank, bank.physicalTime <= commander.flightSimulation.physicalTime,
      let inventory = commander.equipmentInventory,
      let history = commander.equipmentPurchaseHistory
    else { return nil }
    do {
      try EMPModuleGrades.validate(
        inventory: inventory, history: history, at: commander.flightSimulation.physicalTime)
    } catch { return nil }
    return item
  }

  private func matchesEMPPlayerOwner(_ interval: EMPPlayerElectricalInterval) -> Bool {
    guard commander.flightSimulation.player == interval.player,
      commander.equipmentOwnerID == interval.owner, commander.hullInstanceID == interval.hull,
      nativeStationRuntimeEpoch == interval.epoch,
      commander.flightSimulation.physicalTime == interval.end,
      commander.performance.energy == interval.capacity,
      commander.performance.recharge * commander.energyRechargeMultiplier == interval.recharge
    else { return false }
    return true
  }

  /// The read path cannot initialize, recover or advance a reserve.
  func postedEMPPlayerElectrical() -> ElectricalReserve? {
    guard let interval = empPlayerElectricalInterval, interval.eligible,
      !paused, !docked, screen.isFlight, energy > 0, matchesEMPPlayerOwner(interval),
      let reserve = interval.closing, reserve.valid, reserve.physicalTime == interval.end,
      commander.savedPlayerElectrical == reserve
    else { return nil }
    return reserve
  }

  mutating func postEMPPlayerElectricalInterval() {
    guard var interval = empPlayerElectricalInterval, matchesEMPPlayerOwner(interval),
      interval.closing == nil, commander.savedPlayerElectrical == interval.opening,
      let reserve = ElectricalReserve(posting: interval)
    else { empPlayerElectricalInterval = nil; return }
    let wasDisabled = interval.opening?.disabledAt != nil
    interval.posted(reserve)
    commander.savedPlayerElectrical = reserve
    empPlayerElectricalInterval = interval
    if wasDisabled && reserve.disabledAt == nil { notify("ELECTRICAL POWER RECOVERED") }
  }

  /// Observation of an attained hit cannot reject that hit or restore its former balance.
  mutating func recordEMPPlayerElectricalDebit(
    before: ElectricalReserve, after: ElectricalReserve
  ) {
    guard var interval = empPlayerElectricalInterval,
      matchesEMPPlayerOwner(interval), interval.recordDebit(before: before, after: after)
    else { empPlayerElectricalInterval = nil; return }
    empPlayerElectricalInterval = interval
  }

  /// Invoked after every late callback. Every result consumes the actual interval.
  mutating func finishEMPPlayerElectricalInterval(publish: ScriptPublisher?) {
    guard let interval = empPlayerElectricalInterval else { return }
    empPlayerElectricalInterval = nil
    guard matchesEMPPlayerOwner(interval), let item = interval.module,
      currentEMPPlayerModule() == item,
      let originalBank = item.empBank, let grades = item.empGrades,
      var inventory = commander.equipmentInventory,
      inventory.revision == interval.inventoryRevision,
      let skippedBank = originalBank.skippingCharge(to: interval.end)
    else { return }
    let main = commander.savedPlayerElectrical
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance)
    // Advance only this owned cursor before optional publication. No credit or main debit.
    if skippedBank != originalBank {
      do {
        try inventory.replaceEMPBank(
          expected: item, with: skippedBank, expectedRevision: inventory.revision, context: context)
      } catch { return }
      commander.savedEquipmentInventory = inventory
    }
    guard interval.eligible, interval.earnsCurrentInterval,
      !paused, !docked, screen.isFlight, energy > 0,
      let main, main == interval.closing, main.valid, main.disabledAt == nil,
      main.physicalTime == interval.end, main.remaining.isFinite, main.remaining > 0,
      originalBank.physicalTime == interval.start, let publish
    else { return }
    let headroom = main.remaining.nextDown
    let wanted = EMPModuleGradePolicy.rechargeRates[grades.recharge] * interval.acceptedDelta
    var intervalDebit = wanted / EMPModuleGradePolicy.efficiency
    if intervalDebit * EMPModuleGradePolicy.efficiency > wanted {
      intervalDebit = intervalDebit.nextDown
    }
    let maximumDebit = min(headroom, intervalDebit)
    guard headroom.isFinite, headroom > 0, headroom < main.remaining,
      wanted.isFinite, intervalDebit.isFinite, maximumDebit > 0,
      let terms = grades.terms(maximumMainDebit: maximumDebit),
      case .success(let stage) = EMPBankTransfer.stage(
        bank: originalBank, module: item.id, main: main,
        start: interval.start, end: interval.end, paused: false, terms: terms),
      stage.mainDebited > 0, stage.bankGained > 0, stage.main.remaining > 0,
      let skippedItem = inventory.items.first(where: { $0.id == item.id }),
      skippedItem.empBank == skippedBank, skippedItem.empGrades == grades
    else { return }
    // The stage was calculated against the pre-skip bank, but replacement uses the actual
    // post-skip item and revision. No stage equality is mistaken for publication authority.
    var candidate = self
    do {
      try inventory.replaceEMPBank(
        expected: skippedItem, with: stage.bank,
        expectedRevision: inventory.revision, context: context)
      candidate.commander.savedEquipmentInventory = inventory
      candidate.commander.savedPlayerElectrical = stage.main
      try publish(&candidate)
    } catch { return }
    self = candidate
  }
}
