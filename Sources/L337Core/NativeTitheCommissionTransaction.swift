import Foundation

enum NativeTitheCommissionDecision: Sendable {
  case confirmPermanentMark, decline
}

final class NativeTitheCommissionReview: Sendable {
  let contact: NativeTitheCommissionContact?
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let observations: [NativeMainStationObservation]?
  let firstSale: UUID?
  let secondSale: UUID?
  let epoch: UUID
  let warning: String
  let resources: CommanderSnapshot
  let issues: [String]
  var allowed: Bool { issues.isEmpty && contact != nil }

  fileprivate init(game: borrowing Game, contact: NativeTitheCommissionContact?,
    arrival: NativeMainStationArrivalContext?, observations: [NativeMainStationObservation]?,
    issues: [String])
  {
    self.contact = contact
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.observations = observations
    firstSale = game.commander.scriptState.firstNativeCommoditySale?.operation
    secondSale = game.commander.scriptState.secondNativeCommoditySale?.sale.operation
    epoch = game.nativeStationRuntimeEpoch
    warning = NativeTitheCommissionMark.warning
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var titheCommissionMission: ScriptInstance? {
    commander.withReadOnlyScriptState { $0.instances.values.first(where: NativeTitheCommissionDefinition.marked) }
  }

  /// Preview returns only a quote; it cannot grant a case or mark.
  func reviewTitheCommission() -> NativeTitheCommissionReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap {
      nativeMainStationArrivalContext(for: $0.station)
    }
    let observations = arrival.flatMap {
      try? NativeTitheCommissionHistory.acceptanceObservations(in: self, at: $0)
    }
    let contact = NativeTitheCommissionContactSource.current(in: self)
    var issues: [String] = []
    if paused || isMissionTrial || trialTitle != nil { issues.append("Use your unpaused actual commander outside a trial.") }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeTitheOriginalStage.accept.world || arrival == nil {
      issues.append("Use the actual living Rakenor main berth in Galaxy 7.")
    }
    if observations == nil { issues.append("Retain five distinct native system visits and two separate ordinary sales.") }
    if contact == nil { issues.append(NativeTitheCommissionContactSource.unavailable) }
    if titheCommissionPack == nil { issues.append("Restore the original fourteen-stage Tithe of Worlds definition.") }
    if !commander.equipmentStateValid || !NativeTitheCommissionSave.validateClaims(commander) {
      issues.append("The current owner, equipment or commission history cannot be verified.")
    }
    if titheCommissionMission != nil { issues.append("This commander already holds the permanent commission.") }
    if commander.scriptState.instances.count >= 128 || !commander.scriptState.pendingEvents.isEmpty
      || scriptDispatching || scriptEventsDeferred || commander.scriptState.nextEvent >= UInt64(Int64.max) - 1
    { issues.append("Finish the current command and retain space for its original mission record.") }
    return .init(game: self, contact: contact, arrival: arrival, observations: observations, issues: issues)
  }

  /// Only an explicit decision with the same sealed live desk and unchanged native quote
  /// reaches this transaction. The enclosing actor publishes the whole candidate once.
  mutating func confirmTitheCommission(_ quote: NativeTitheCommissionReview) throws {
    let fresh = reviewTitheCommission()
    guard quote.allowed, fresh.allowed, let contact = quote.contact,
      let actual = fresh.contact, contact.record == actual.record,
      contact.arrival == actual.arrival, contact.epoch == actual.epoch,
      quote.arrival == fresh.arrival, quote.owner == fresh.owner, quote.carrier == fresh.carrier,
      quote.inventoryRevision == fresh.inventoryRevision, quote.observations == fresh.observations,
      quote.firstSale == fresh.firstSale, quote.secondSale == fresh.secondSale,
      quote.epoch == nativeStationRuntimeEpoch, quote.epoch == fresh.epoch,
      quote.warning == NativeTitheCommissionMark.warning,
      quote.resources.value == commander.contractQuoteResources,
      let arrival = quote.arrival, acceptsNativeMainStationArrivalContext(arrival),
      contact.arrival == arrival, contact.record.station == arrival.receipt.station,
      NativeTitheCommissionContactSource.recognizesHistorical(contact.record, commander: commander),
      let owner = quote.owner, let carrier = quote.carrier, let fit = quote.inventoryRevision,
      let observations = quote.observations, let first = quote.firstSale, let second = quote.secondSale
    else { throw MissionPackError("The original Voss desk, history, carrier or warning is unavailable or changed. Review again.") }
    let id = NativeTitheCommissionDefinition.mission(owner: owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeTitheCommissionAcceptanceFacts(
      mission: id, owner: owner, carrier: carrier, inventoryRevision: fit, dock: arrival.receipt,
      desk: contact.record, visited: observations, firstSale: first, secondSale: second,
      sequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    let grant = try NativeTitheCommissionState(acceptance: facts)
    let instance = try grant.openingInstance()
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.commander.scriptState.nextEvent = facts.sequence
    guard NativeTitheCommissionSave.validateClaims(candidate.commander),
      candidate.commander.titheCommissionMarkEntitlement == grant.mark,
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("HEARTH COMPACT COMMISSION RECORDED - TRACE THE ZORDAIK ORDERS")
    self = candidate
  }
}

extension GameRuntime {
  func reviewTitheCommission() -> NativeTitheCommissionReview { game.reviewTitheCommission() }

  func decideTitheCommission(_ review: NativeTitheCommissionReview,
    decision: NativeTitheCommissionDecision) throws
  {
    switch decision {
    case .decline: return
    case .confirmPermanentMark: try scriptCommand { try $0.confirmTitheCommission(review) }
    }
  }
}
