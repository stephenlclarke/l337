import Foundation

extension Game {
  var memoryAtlasPack: ScriptPack? {
    scriptPacks.first(where: NativeMemoryAtlasDefinition.matches)
  }

  var memoryAtlasMission: ScriptInstance? {
    commander.withReadOnlyScriptState {
      $0.instances.values.first(where: NativeMemoryAtlasDefinition.marked)
    }
  }

  /// The original service is declared by the closed native pack; no named person is spawned.
  func memoryAtlasUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeMemoryAtlasDefinition.matches(pack) else {
      return "Restore the original The Memory Atlas opening."
    }
    guard let instance = memoryAtlasMission else {
      return "Review Vale's original commission at Reris in Galaxy 1 after one ordinary trade."
    }
    guard NativeMemoryAtlasSave.prefixValid(instance) else {
      return "The original The Memory Atlas record cannot currently be verified."
    }
    return nil
  }

  /// The existing actor's bound scriptCommand/writer owns publication of this candidate.
  mutating func confirmMemoryAtlas(_ quote: NativeMemoryAtlasReview) throws {
    let current = memoryAtlasReview(quote.action)
    guard screen == .contracts, contractBoard.detail, contractBoard.action == .accept,
      contractBoard.selected?.memoryAtlas == quote.action,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.tradeOperation == current.tradeOperation, quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.source == current.source,
      quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Reris contact, trade, carrier or loan changed; review again.") }
    var candidate = self
    switch quote.action {
    case .accept:
      try candidate.acceptMemoryAtlas(at: arrival)
    case .collectReference:
      guard let watcher = quote.watcherSource else { throw EquipmentIssueError.staleObligation }
      try candidate.collectMemoryAtlasWatcherSource(watcher)
      candidate.notify("ORIGINAL MEMORY ATLAS REFERENCE COLLECTED - 1t - NEXT: THREE INDEPENDENT ORBITAL LANDMARKS AT NEDASEN")
    case .progress:
      throw MissionPackError("Follow the actual next The Memory Atlas objective; reading progress changes nothing.")
    }
    self = candidate
  }

  private mutating func acceptMemoryAtlas(at arrival: NativeMainStationArrivalContext) throws {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeMemoryAtlasDefinition.issuer,
      arrival.receipt.station.system == NativeMemoryAtlasDefinition.issuer,
      let pack = memoryAtlasPack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade, trade.owner == inventory.owner,
      trade.physicalTime <= commander.flightSimulation.physicalTime,
      memoryAtlasMission == nil, NativeMemoryAtlasSave.validateClaims(commander),
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander),
      let source = memoryAtlasWatcherSourceProjection, source.available,
      source.station == arrival.receipt.station,
      source.owner == inventory.owner,
      source.caseID == NativeMemoryAtlasDefinition.mission(owner: inventory.owner),
      commander.scriptState.instances.count < 128,
      commander.scriptState.pendingEvents.isEmpty,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use the actual original Reris service after one ordinary trade.") }
    let id = NativeMemoryAtlasDefinition.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeMemoryAtlasAcceptanceFacts(mission: id, owner: inventory.owner,
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      ordinaryTrade: trade.operation, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativeMemoryAtlasDefinition.stateID,
      version: NativeMemoryAtlasDefinition.version, digest: pack.digest)
    instance.savedMemoryAtlas = try .init(acceptance: facts)
    instance.receipts = [NativeMemoryAtlasDefinition.acceptReceipt]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.memoryAtlasMission,
      accepted.id == id, NativeMemoryAtlasSave.validateClaims(candidate.commander),
      NativeMemoryAtlasWatcherSourceSave.validateClaims(candidate.commander),
      candidate.memoryAtlasWatcherSourceProjection == source,
      accepted.journal == NativeMemoryAtlasDefinition.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("MEMORY ATLAS COMMISSION ACCEPTED - VALE RETAINS THE ORIGINAL UNTIL COLLECTION")
    self = candidate
  }
}
