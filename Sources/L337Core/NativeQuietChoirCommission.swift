import Foundation

extension Game {
  var quietChoirPack: ScriptPack? { scriptPacks.first(where: NativeQuietChoirDefinition.matches) }

  var quietChoirMission: ScriptInstance? {
    commander.withReadOnlyScriptState { $0.instances.values.first(where: NativeQuietChoirDefinition.marked) }
  }

  func quietChoirUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeQuietChoirDefinition.matches(pack) else { return "Restore the original Quiet Choir opening." }
    guard let instance = quietChoirMission else {
      return "Review Holt's signal investigation at Omdogan in Galaxy 4 after identifying a real Larvaal vessel and visiting four different systems."
    }
    guard NativeQuietChoirSave.prefixValid(instance) else { return "The original survey cannot currently be verified." }
    return nil
  }

  /// The actor's existing bound scriptCommand/writer publishes this candidate atomically.
  mutating func confirmQuietChoir(_ quote: NativeQuietChoirReview) throws {
    let current = quietChoirReview(quote.action)
    guard quote.action == .accept, screen == .contracts, contractBoard.detail,
      contractBoard.action == .accept, contractBoard.selected?.quietChoir == .accept,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.observations == current.observations, quote.identification == current.identification,
      quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, let observations = current.observations,
      let identification = current.identification,
      acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Omdogan service, visited history or carrier changed; review again.") }
    var candidate = self
    try candidate.acceptQuietChoir(at: arrival, observations: observations, identification: identification)
    self = candidate
  }

  private mutating func acceptQuietChoir(at arrival: NativeMainStationArrivalContext,
    observations: [NativeMainStationObservation], identification: FleetDiscoveryEvidence) throws
  {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeQuietChoirDefinition.issuer,
      arrival.receipt.station.system == NativeQuietChoirDefinition.issuer,
      let pack = quietChoirPack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      observations == (try? NativeQuietChoirTravelHistory.current(in: self, at: arrival)),
      identification == NativeQuietChoirTravelHistory.identification(in: self),
      quietChoirMission == nil, NativeQuietChoirSave.validateClaims(commander),
      commander.scriptState.instances.count < 128, commander.scriptState.pendingEvents.isEmpty,
      !scriptDispatching, !scriptEventsDeferred,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use Holt's actual Omdogan commission after four verified systems and real Larvaal identification.") }
    let id = NativeQuietChoirDefinition.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeQuietChoirAcceptanceFacts(mission: id, owner: inventory.owner,
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      visited: observations, identification: identification, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativeQuietChoirDefinition.stateID,
      version: NativeQuietChoirDefinition.version, digest: pack.digest)
    instance.savedQuietChoir = try .init(acceptance: facts)
    instance.receipts = [NativeQuietChoirDefinition.acceptReceipt]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.quietChoirMission, accepted.id == id,
      NativeQuietChoirSave.validateClaims(candidate.commander),
      accepted.journal == NativeQuietChoirDefinition.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("QUIET CHOIR ACCEPTED - CALIBRATE THE LOBAGOM REFERENCES")
    self = candidate
  }
}
