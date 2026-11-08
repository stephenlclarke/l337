import Foundation

extension Game {
  var borrowedVoicePack: ScriptPack? { scriptPacks.first(where: NativeBorrowedVoiceDefinition.matches) }

  var borrowedVoiceMission: ScriptInstance? {
    commander.withReadOnlyScriptState { $0.instances.values.first(where: NativeBorrowedVoiceDefinition.marked) }
  }

  func borrowedVoiceUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeBorrowedVoiceDefinition.matches(pack) else { return "Restore the original Borrowed Voice opening." }
    guard let instance = borrowedVoiceMission else {
      return "Review Dain's rescue-channel investigation at Taledea in Galaxy 3 after visiting five different systems."
    }
    guard NativeBorrowedVoiceSave.prefixValid(instance) else { return "The original survey cannot currently be verified." }
    return nil
  }

  /// The actor's existing bound scriptCommand/writer publishes this candidate atomically.
  mutating func confirmBorrowedVoice(_ quote: NativeBorrowedVoiceReview) throws {
    let current = borrowedVoiceReview(quote.action)
    guard quote.action == .accept, screen == .contracts, contractBoard.detail,
      contractBoard.action == .accept, contractBoard.selected?.borrowedVoice == .accept,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.observations == current.observations, quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, let observations = current.observations,
      acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Taledea service, visited history or carrier changed; review again.") }
    var candidate = self
    try candidate.acceptBorrowedVoice(at: arrival, observations: observations)
    self = candidate
  }

  private mutating func acceptBorrowedVoice(at arrival: NativeMainStationArrivalContext,
    observations: [NativeMainStationObservation]) throws
  {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeBorrowedVoiceDefinition.issuer,
      arrival.receipt.station.system == NativeBorrowedVoiceDefinition.issuer,
      let pack = borrowedVoicePack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      observations == (try? NativeBorrowedVoiceTravelHistory.current(in: self, at: arrival)),
      borrowedVoiceMission == nil, NativeBorrowedVoiceSave.validateClaims(commander),
      commander.scriptState.instances.count < 128, commander.scriptState.pendingEvents.isEmpty,
      !scriptDispatching, !scriptEventsDeferred,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use the actual Taledea rescue service after five verified visited systems.") }
    let id = NativeBorrowedVoiceDefinition.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeBorrowedVoiceAcceptanceFacts(mission: id, owner: inventory.owner,
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      visited: observations, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativeBorrowedVoiceDefinition.stateID,
      version: NativeBorrowedVoiceDefinition.version, digest: pack.digest)
    instance.savedBorrowedVoice = try .init(acceptance: facts)
    instance.receipts = [NativeBorrowedVoiceDefinition.acceptReceipt]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.borrowedVoiceMission, accepted.id == id,
      NativeBorrowedVoiceSave.validateClaims(candidate.commander),
      accepted.journal == NativeBorrowedVoiceDefinition.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("BORROWED VOICE ACCEPTED - COMPARE THE ORIGINAL DISTRESS BEACONS")
    self = candidate
  }
}
