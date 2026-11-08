import Foundation

extension Game {
  var publicRecordPack: ScriptPack? { scriptPacks.first(where: NativePublicRecordDefinition.matches) }

  var publicRecordMission: ScriptInstance? {
    commander.withReadOnlyScriptState { $0.instances.values.first(where: NativePublicRecordDefinition.marked) }
  }

  func publicRecordUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativePublicRecordDefinition.matches(pack) else { return "Restore the original Public Record opening." }
    guard let instance = publicRecordMission else {
      return "Review Sol's commission at Fenias in Galaxy 5 after one ordinary trade."
    }
    guard NativePublicRecordSave.prefixValid(instance) else { return "The original commission cannot currently be verified." }
    return nil
  }

  /// The actor's existing bound scriptCommand/writer publishes this candidate atomically.
  mutating func confirmPublicRecord(_ quote: NativePublicRecordReview) throws {
    let current = publicRecordReview(quote.action)
    guard quote.action == .accept, screen == .contracts, contractBoard.detail,
      contractBoard.action == .accept, contractBoard.selected?.publicRecord == .accept,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.tradeOperation == current.tradeOperation, quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Fenias service, trade or carrier changed; review again.") }
    var candidate = self
    try candidate.acceptPublicRecord(at: arrival)
    self = candidate
  }

  private mutating func acceptPublicRecord(at arrival: NativeMainStationArrivalContext) throws {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativePublicRecordDefinition.issuer,
      arrival.receipt.station.system == NativePublicRecordDefinition.issuer,
      let pack = publicRecordPack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade, trade.owner == inventory.owner,
      trade.physicalTime <= commander.flightSimulation.physicalTime,
      publicRecordMission == nil, NativePublicRecordSave.validateClaims(commander),
      commander.scriptState.instances.count < 128, commander.scriptState.pendingEvents.isEmpty,
      !scriptDispatching, !scriptEventsDeferred,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use the actual Fenias commission service after one ordinary trade.") }
    let id = NativePublicRecordDefinition.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativePublicRecordAcceptanceFacts(mission: id, owner: inventory.owner,
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      ordinaryTrade: trade.operation, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativePublicRecordDefinition.stateID,
      version: NativePublicRecordDefinition.version, digest: pack.digest)
    instance.savedPublicRecord = try .init(acceptance: facts)
    instance.receipts = [NativePublicRecordDefinition.acceptReceipt]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.publicRecordMission, accepted.id == id,
      NativePublicRecordSave.validateClaims(candidate.commander),
      accepted.journal == NativePublicRecordDefinition.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("PUBLIC RECORD COMMISSION ACCEPTED - COLLECT THE ORIGINAL REFERENCE AT FENIAS")
    self = candidate
  }
}
