import Foundation

enum NativeBorrowedVoiceAction: String, Sendable {
  case accept, progress
  var key: String { NativeBorrowedVoiceDefinition.stateID + "/" + rawValue }
}

/// The actual station rescue-service review, never a birth or permission for a named witness.
final class NativeBorrowedVoiceReview: Sendable {
  let action: NativeBorrowedVoiceAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let observations: [NativeMainStationObservation]?
  let caseRevision: UInt64?
  let digest: String?
  let epoch: UUID
  let resources: CommanderSnapshot
  let issues: [String]
  var allowed: Bool { action == .accept && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativeBorrowedVoiceAction,
    arrival: NativeMainStationArrivalContext?, observations: [NativeMainStationObservation]?,
    issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.observations = observations
    caseRevision = game.borrowedVoiceMission?.revision
    digest = game.borrowedVoicePack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var borrowedVoiceRows: [ContractBoardRow] {
    guard borrowedVoicePack != nil else { return [] }
    if borrowedVoiceMission != nil {
      return [.init(board: NativeBorrowedVoiceAction.progress.key, offer: nil,
        title: "The Borrowed Voice / current investigation", reason: nil, borrowedVoice: .progress)]
    }
    guard systemIdentity == NativeBorrowedVoiceDefinition.issuer else { return [] }
    return [.init(board: NativeBorrowedVoiceAction.accept.key, offer: nil,
      title: "Dain / review The Borrowed Voice", reason: borrowedVoiceReview(.accept).issues.first,
      borrowedVoice: .accept)]
  }

  func borrowedVoiceReview(_ action: NativeBorrowedVoiceAction) -> NativeBorrowedVoiceReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let observations = arrival.flatMap { try? NativeBorrowedVoiceTravelHistory.current(in: self, at: $0) }
    var issues: [String] = []
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        observations: observations, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeBorrowedVoiceDefinition.issuer || arrival == nil {
      issues.append("Review Dain's investigation at the actual living Taledea main berth in Galaxy 3.")
    }
    if borrowedVoicePack == nil { issues.append("Restore the original Borrowed Voice commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeBorrowedVoiceSave.validateClaims(commander) {
      issues.append("The original Borrowed Voice commission cannot currently be verified.")
    }
    if observations == nil {
      issues.append("Five distinct visited systems cannot yet be verified from retained native history.")
    }
    if borrowedVoiceMission != nil { issues.append("The original investigation is already commissioned.") }
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

  func borrowedVoiceDetail() -> [String] {
    guard let action = contractBoard.selected?.borrowedVoice else { return [] }
    var lines = NativeBorrowedVoiceDefinition.briefing
    lines.append("The original offer requires five different visited systems, not a trade, combat score, previous campaign or purchased scanner.")
    lines.append("Acceptance supplies no verifier and reserves no hold. Compare all three actual Ilasaeli beacons with their local casualty sensors first. Collect Renn's one-tonne original later at Noserin.")
    lines.append("Patient locations remain private. A witness statement, protected living reception and the chosen authenticated record are separate requirements; an accusation or destroyed observer proves none of them.")
    if action == .progress {
      guard let instance = borrowedVoiceMission, NativeBorrowedVoiceSave.validateClaims(commander)
      else { return lines + ["The original investigation cannot currently be verified."] }
      return lines + instance.journal + ["Actual beacon and independent casualty-sensor sources remain unavailable; the commission supplies no reading."]
    }
    return lines + (contractBoard.borrowedVoiceQuote?.issues ?? ["Review the current berth and five verified visited systems."])
      + ["Confirm accepts only this investigation. Back changes nothing."]
  }
}
