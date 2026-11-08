import Foundation

extension Game {
  var underTowPack: ScriptPack? {
    scriptPacks.first(where: NativeUnderTowDefinition.matches)
  }

  var underTowMission: ScriptInstance? {
    commander.withReadOnlyScriptState {
      $0.instances.values.first(where: NativeUnderTowDefinition.marked)
    }
  }

  /// The original service is declared by the closed native pack; no named person is spawned.
  func underTowUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeUnderTowDefinition.matches(pack) else {
      return "Restore the original Under Tow opening."
    }
    guard let instance = underTowMission else {
      return "Review Penn's original commission at Luera in Galaxy 8 after one ordinary trade."
    }
    guard NativeUnderTowSave.prefixValid(instance) else {
      return "The original Under Tow record cannot currently be verified."
    }
    return nil
  }

  /// The existing actor's bound scriptCommand/writer owns publication of this candidate.
  mutating func confirmUnderTow(_ quote: NativeUnderTowReview) throws {
    let current = underTowReview(quote.action)
    guard screen == .contracts, contractBoard.detail, contractBoard.action == .accept,
      contractBoard.selected?.underTow == quote.action,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.tradeOperation == current.tradeOperation, quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Luera contact, trade, carrier or loan changed; review again.") }
    var candidate = self
    switch quote.action {
    case .accept:
      try candidate.acceptUnderTow(at: arrival)
    case .collectReference:
      try candidate.collectUnderTowReference(at: arrival)
    case .progress:
      throw MissionPackError("Follow the actual next Under Tow objective; reading progress changes nothing.")
    }
    self = candidate
  }

  private mutating func acceptUnderTow(at arrival: NativeMainStationArrivalContext) throws {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeUnderTowDefinition.issuer,
      arrival.receipt.station.system == NativeUnderTowDefinition.issuer,
      let pack = underTowPack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade, trade.owner == inventory.owner,
      trade.physicalTime <= commander.flightSimulation.physicalTime,
      underTowMission == nil, NativeUnderTowSave.validateClaims(commander),
      commander.scriptState.instances.count < 128,
      commander.scriptState.pendingEvents.isEmpty,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use the actual original Luera service after one ordinary trade.") }
    let id = NativeUnderTowDefinition.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeUnderTowAcceptanceFacts(mission: id, owner: inventory.owner,
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      ordinaryTrade: trade.operation, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativeUnderTowDefinition.stateID,
      version: NativeUnderTowDefinition.version, digest: pack.digest)
    instance.savedUnderTow = try .init(acceptance: facts)
    instance.receipts = [NativeUnderTowDefinition.acceptReceipt]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.underTowMission,
      accepted.id == id, NativeUnderTowSave.validateClaims(candidate.commander),
      accepted.journal == NativeUnderTowDefinition.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("UNDER TOW COMMISSION ACCEPTED - PENN RETAINS THE ORIGINAL UNTIL COLLECTION")
    self = candidate
  }

  private mutating func collectUnderTowReference(at arrival: NativeMainStationArrivalContext) throws {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeUnderTowDefinition.issuer,
      underTowPack != nil, var selected = underTowMission,
      selected.outcome == .active, selected.suspension == nil,
      var state = selected.savedUnderTow, state.collection == nil,
      selected.gearIssues.isEmpty, NativeUnderTowSave.validateClaims(commander),
      arrival.receipt.station == state.acceptance.dock.station,
      let before = commander.equipmentInventory,
      before.owner == state.acceptance.owner, before.activeHull == commander.hullInstanceID,
      before.revision < UInt64(Int64.max) - 1, selected.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let used = commander.checkedCargoTonnes, used >= 0,
      used < commander.standardCargoCapacity
    else { throw EquipmentIssueError.staleObligation }
    let added = used.addingReportingOverflow(NativeUnderTowReferenceDefinition.cargoTonnes)
    guard !added.overflow else { throw EquipmentIssueError.invalidBudget }
    var staged = commander
    let actual = try issueScriptGearWithReceipt(NativeUnderTowReferenceDefinition.gear,
      fields: ["fit": .bool(false)], command: UUID(), state: &selected, candidate: &staged)
    guard let actual, let inventory = staged.equipmentInventory,
      let original = inventory.items.first(where: {
        $0.id == NativeUnderTowReferenceDefinition.serial(mission: selected.id)
      }), inventory.owner == before.owner, inventory.activeHull == before.activeHull,
      inventory.revision == before.revision + 1,
      inventory.items == before.items + [original], original.node == NativeUnderTowReferenceDefinition.node,
      original.location == nil, original.component == nil, original.preferredSlot == nil,
      original.boundHull == nil, original.retainedLegacyState == nil,
      original.nativeRepairLoopCondition == nil,
      staged.credits == commander.credits, staged.cargo == commander.cargo,
      staged.checkedCargoTonnes == added.partialValue,
      staged.standardCargoCapacity == commander.standardCargoCapacity
    else { throw EquipmentIssueError.identityMismatch }
    let sequence = staged.scriptState.nextEvent + 1
    let facts = NativeUnderTowReferenceCollection.Facts(issueCommand: actual.receipt.command,
      source: actual.receipt.source, issuer: NativeUnderTowReferenceDefinition.issuer(owner: before.owner),
      original: original.id, carrier: before.activeHull, dock: arrival.receipt,
      beforeInventoryRevision: before.revision, afterInventoryRevision: inventory.revision,
      beforeCaseRevision: selected.revision, afterCaseRevision: selected.revision + 1,
      eventSequence: sequence, beforeCargoTonnes: used, afterCargoTonnes: added.partialValue,
      capacityTonnes: commander.standardCargoCapacity,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    state.collection = try .init(actual: actual.receipt, facts: facts, acceptance: state.acceptance)
    selected.savedUnderTow = state
    selected.receipts.insert(NativeUnderTowDefinition.collectReceipt)
    selected.milestones.insert(1)
    selected.journal.append(NativeUnderTowDefinition.collectionDialogue)
    selected.revision = facts.afterCaseRevision
    selected.acknowledge(sequence)
    staged.scriptState.nextEvent = sequence
    staged.scriptState.instances[selected.id] = selected
    let budget = try staged.equipmentFitBudget(projectedItems: inventory.items)
    guard budget.valid, budget.accommodationAllowed,
      budget.occupiedCargoTonnes == added.partialValue,
      budget.projectedCargoCapacity == commander.standardCargoCapacity,
      budget.occupiedCargoTonnes <= budget.projectedCargoCapacity,
      (try? NativeUnderTowCustody.resolve(instance: selected, commander: staged)) != nil,
      NativeUnderTowSave.validateClaims(staged), staged.equipmentStateValid,
      staged.credits == commander.credits, staged.cargo == commander.cargo,
      staged.nativePeople == commander.nativePeople, staged.nativeStations == commander.nativeStations,
      staged.flightSimulation == commander.flightSimulation,
      staged.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw EquipmentIssueError.invalidBudget }
    commander = staged
    notify("ORIGINAL UNDER TOW REFERENCE COLLECTED - 1t - NEXT: THREE ORIGINAL COLLARS AT ALLION")
  }
}
