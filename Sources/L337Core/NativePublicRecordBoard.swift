import Foundation

enum NativePublicRecordAction: String, Sendable {
  case accept, progress
  var key: String { NativePublicRecordDefinition.stateID + "/" + rawValue }
}

/// Review of the original case service. Neither saved facts nor its name creates a person.
final class NativePublicRecordReview: Sendable {
  let action: NativePublicRecordAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let tradeOperation: UUID?
  let caseRevision: UInt64?
  let digest: String?
  let epoch: UUID
  let resources: CommanderSnapshot
  let issues: [String]
  var allowed: Bool { action == .accept && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativePublicRecordAction,
    arrival: NativeMainStationArrivalContext?, tradeOperation: UUID?, issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.tradeOperation = tradeOperation
    caseRevision = game.publicRecordMission?.revision
    digest = game.publicRecordPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var publicRecordRows: [ContractBoardRow] {
    guard publicRecordPack != nil else { return [] }
    if publicRecordMission != nil {
      return [.init(board: NativePublicRecordAction.progress.key, offer: nil,
        title: "Public Record / current case", reason: nil, publicRecord: .progress)]
    }
    guard systemIdentity == NativePublicRecordDefinition.issuer else { return [] }
    return [.init(board: NativePublicRecordAction.accept.key, offer: nil,
      title: "Sol / review Public Record", reason: publicRecordReview(.accept).issues.first,
      publicRecord: .accept)]
  }

  func publicRecordReview(_ action: NativePublicRecordAction) -> NativePublicRecordReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let trade = NativeFirstCommodityTradeSave.validateClaims(commander)
      ? commander.scriptState.firstNativeCommodityTrade : nil
    var issues: [String] = []
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        tradeOperation: trade?.operation, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativePublicRecordDefinition.issuer || arrival == nil {
      issues.append("Review Sol's case at the actual living Fenias main berth in Galaxy 5.")
    }
    if publicRecordPack == nil { issues.append("Restore the original Public Record commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativePublicRecordSave.validateClaims(commander) {
      issues.append("The original Public Record commission cannot currently be verified.")
    }
    if trade == nil { issues.append("Complete one actual ordinary purchase or sale first.") }
    if publicRecordMission != nil { issues.append("The original case is already commissioned.") }
    if commander.scriptState.instances.count >= 128 { issues.append("The mission record capacity is full.") }
    if commander.scriptState.pendingEvents.count >= 4096
      || commander.scriptState.nextEvent >= UInt64(Int64.max) - 2
      || scriptDispatching || scriptEventsDeferred || !commander.scriptState.pendingEvents.isEmpty
    {
      issues.append("Finish the current native command before confirming.")
    }
    return .init(game: self, action: action, arrival: arrival,
      tradeOperation: trade?.operation, issues: issues)
  }

  func publicRecordDetail() -> [String] {
    guard let action = contractBoard.selected?.publicRecord else { return [] }
    var lines = NativePublicRecordDefinition.briefing
    lines.append("Acceptance issues no reference, observer permission or reply period and reserves no cargo space. Collect Sol's identified one-tonne reference here at Fenias before departure; that later pickup needs one free tonne.")
    lines.append("Observe three actual cargo-routing decisions with the source observers permission. Compare both external controllers using the original public recorder and freeze the independent evidence version, retaining each original measurement and hash.")
    lines.append("Keep the sponsor record alongside the independent one. Disagreement is evidence, not a verdict. A reply may challenge the claim but cannot alter or erase the preserved measurements. The technical witness chooses what to disclose and must actually reach safe newsroom reception at Voron.")
    lines.append("Arrived authorised delegates choose an anonymised evidence release or a witnessed right-of-reply hearing. Public release needs actual archive receiving and a zero-private-identity-field audit. The hearing reply period starts only after explicit receiver confirmation, lasts 120 seconds and permits publication on expiry; it is not a mission deadline or automatic award. Both selected independent proofs and original reference return/audit precede the 6,300 CR fee and source clue.")
    if action == .progress {
      guard let instance = publicRecordMission, NativePublicRecordSave.validateClaims(commander)
      else { return lines + ["The original case record cannot currently be verified."] }
      return lines + instance.journal + ["Sol's actual finite original reference source at Fenias remains unavailable. Acceptance supplies no instrument, observer permission, cargo-routing observation, independent recording/version/hash, qualified-work credit, technical witness reception, privacy audit, reply lease or settlement proof."]
    }
    return lines + (contractBoard.publicRecordQuote?.issues ?? ["Review the current berth and ordinary trade."])
      + ["Confirm accepts only the stated case commission. Back changes nothing."]
  }
}
