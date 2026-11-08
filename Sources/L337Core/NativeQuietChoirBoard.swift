import Foundation

enum NativeQuietChoirAction: String, Sendable {
  case accept, progress
  var key: String { NativeQuietChoirDefinition.stateID + "/" + rawValue }
}

/// The actual station investigation review; no field actor, observation or item permission.
final class NativeQuietChoirReview: Sendable {
  let action: NativeQuietChoirAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let observations: [NativeMainStationObservation]?
  let identification: FleetDiscoveryEvidence?
  let caseRevision: UInt64?
  let digest: String?
  let epoch: UUID
  let resources: CommanderSnapshot
  let issues: [String]
  var allowed: Bool { action == .accept && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativeQuietChoirAction,
    arrival: NativeMainStationArrivalContext?, observations: [NativeMainStationObservation]?,
    issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.observations = observations
    identification = NativeQuietChoirTravelHistory.identification(in: game)
    caseRevision = game.quietChoirMission?.revision
    digest = game.quietChoirPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var quietChoirRows: [ContractBoardRow] {
    guard quietChoirPack != nil else { return [] }
    if quietChoirMission != nil {
      return [.init(board: NativeQuietChoirAction.progress.key, offer: nil,
        title: "A Choir Beneath the Static / current investigation", reason: nil, quietChoir: .progress)]
    }
    guard systemIdentity == NativeQuietChoirDefinition.issuer else { return [] }
    return [.init(board: NativeQuietChoirAction.accept.key, offer: nil,
      title: "Holt / review A Choir Beneath the Static", reason: quietChoirReview(.accept).issues.first,
      quietChoir: .accept)]
  }

  func quietChoirReview(_ action: NativeQuietChoirAction) -> NativeQuietChoirReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let observations = arrival.flatMap { try? NativeQuietChoirTravelHistory.current(in: self, at: $0) }
    var issues: [String] = []
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        observations: observations, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeQuietChoirDefinition.issuer || arrival == nil {
      issues.append("Review Holt's investigation at the actual living Omdogan main berth in Galaxy 4.")
    }
    if quietChoirPack == nil { issues.append("Restore the original Quiet Choir commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeQuietChoirSave.validateClaims(commander) {
      issues.append("The original Quiet Choir commission cannot currently be verified.")
    }
    if NativeQuietChoirTravelHistory.identification(in: self) == nil {
      issues.append("Identify a real Larvaal vessel with Identification targeting before reviewing Holt's investigation.")
    }
    if observations == nil {
      issues.append("Four distinct visited systems cannot yet be verified from retained native history.")
    }
    if quietChoirMission != nil { issues.append("The original investigation is already commissioned.") }
    if commander.scriptState.instances.count >= 128 { issues.append("The mission record capacity is full.") }
    if commander.scriptState.pendingEvents.count >= 4096
      || commander.scriptState.nextEvent >= UInt64(Int64.max) - 2
      || scriptDispatching || scriptEventsDeferred || !commander.scriptState.pendingEvents.isEmpty
    {
      issues.append("Finish the current native command before confirming.")
    }
    return .init(game: self, action: action, arrival: arrival,
      observations: observations, issues: issues)
  }

  func quietChoirDetail() -> [String] {
    guard let action = contractBoard.selected?.quietChoir else { return [] }
    var lines = NativeQuietChoirDefinition.briefing
    lines.append("Identify a real Larvaal vessel and visit four distinct systems. No trade, combat score, Glass Meridian completion or other paid campaign is required.")
    lines.append("Acceptance requires no free hold or currently fitted scanner and issues no item. Prepare Identification targeting for later field observations; the phase collector and repair culture each require one tonne at their own actual transfer stage.")
    lines.append("Calibrate all three Lobagom references before recovering the original Lodogom collector. Mara Vale's analysis and culture issue, the real probe receiving and safe listening positions remain separate physical stages.")
    lines.append("Silence the actual counterfeit transmitter by the authored demand or component disablement; unrelated kills prove nothing. Both lawful rendezvous choices remain available. Settlement and the clue require the completed accord; optional filter fitting may wait.")
    if action == .progress {
      guard let instance = quietChoirMission, NativeQuietChoirSave.validateClaims(commander)
      else { return lines + ["The original investigation cannot currently be verified."] }
      return lines + instance.journal + ["Actual Lobagom reference emitters and calibrated receiver observations are not yet available; acceptance supplies no reading."]
    }
    return lines + (contractBoard.quietChoirQuote?.issues ?? ["Review the current berth, four verified visited systems and the real retained Larvaal identification."])
      + ["Confirm accepts only this investigation. Back changes nothing."]
  }
}
