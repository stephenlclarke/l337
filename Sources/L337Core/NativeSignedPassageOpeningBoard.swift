import Foundation

enum NativeSignedPassageOpeningAction: String, Sendable {
  case accept, progress
  var key: String { NativeSignedPassageOpening.stateID + "/" + rawValue }
}

/// Review of the original case service. Neither saved facts nor its name creates a person.
final class NativeSignedPassageOpeningReview: Sendable {
  let action: NativeSignedPassageOpeningAction
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

  fileprivate init(game: borrowing Game, action: NativeSignedPassageOpeningAction,
    arrival: NativeMainStationArrivalContext?, tradeOperation: UUID?, issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.tradeOperation = tradeOperation
    caseRevision = game.signedPassageOpeningMission?.revision
    digest = game.signedPassageOpeningPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var signedPassageOpeningRows: [ContractBoardRow] {
    guard signedPassageOpeningPack != nil else { return [] }
    if signedPassageOpeningMission != nil {
      return [.init(board: NativeSignedPassageOpeningAction.progress.key, offer: nil,
        title: "Signed Passage / current case", reason: nil, signedPassageOpening: .progress)]
    }
    guard systemIdentity == NativeSignedPassageOpening.issuer else { return [] }
    return [.init(board: NativeSignedPassageOpeningAction.accept.key, offer: nil,
      title: "Senn / review Signed Passage", reason: signedPassageOpeningReview(.accept).issues.first,
      signedPassageOpening: .accept)]
  }

  func signedPassageOpeningReview(_ action: NativeSignedPassageOpeningAction) -> NativeSignedPassageOpeningReview {
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
    if systemIdentity != NativeSignedPassageOpening.issuer || arrival == nil {
      issues.append("Review Senn's case at the actual living Neron main berth in Galaxy 1.")
    }
    if signedPassageOpeningPack == nil { issues.append("Restore the original Signed Passage commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeSignedPassageOpeningSave.validateClaims(commander) {
      issues.append("The original Signed Passage commission cannot currently be verified.")
    }
    if trade == nil { issues.append("Complete one actual ordinary purchase or sale first.") }
    if signedPassageOpeningMission != nil { issues.append("The original case is already commissioned.") }
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

  func signedPassageOpeningDetail() -> [String] {
    guard let action = contractBoard.selected?.signedPassageOpening else { return [] }
    var lines = NativeSignedPassageOpening.briefing
    lines.append("Acceptance issues no original reference, serial or collection and reserves no cargo space. Collect Senn's identified one-tonne reference here at Neron before departure; its later genuine pickup needs one free tonne.")
    lines.append("Observe three actual receiving cradles and compare allocation with receipt-signing time. Move the same source-owned test crate through two real carrier handoffs under the onboard reference; the test crate is separate from the carried loan.")
    lines.append("Prepare real receiver capacity and permission while the sender remains sole custodian. Commit sender removal and receiver acquisition atomically with one receipt: one crate and one holder. Acknowledgement is not concurrent custody, and a receipt cannot arrive before its cradle exists.")
    lines.append("The independent receiving witness and living tender crew must actually reach the Aetaria archive berth. Arrived authorised delegates choose independent receiving locks or a shared bounded custody register. Both same-consignment locks/early-receipt rejection or duplicate-claim rejection/actual handoff receiving proofs, plus original reference return/audit, precede the 4,300 CR fee and source clue.")
    if action == .progress {
      guard let instance = signedPassageOpeningMission, NativeSignedPassageOpeningSave.validateClaims(commander)
      else { return lines + ["The original case record cannot currently be verified."] }
      return lines + instance.journal + ["Senn's actual finite original reference source at Neron remains unavailable. Acceptance supplies no original reference, serial, collection, test crate, cradle measurement, carrier permission/capacity/atomic handoff, witness reception or settlement proof."]
    }
    return lines + (contractBoard.signedPassageOpeningQuote?.issues ?? ["Review the current berth and ordinary trade."])
      + ["Confirm accepts only the stated case commission. Back changes nothing."]
  }
}

extension Game {
  var signedPassageOpeningPack: ScriptPack? { scriptPacks.first(where: NativeSignedPassageOpening.matches) }

  var signedPassageOpeningMission: ScriptInstance? {
    commander.withReadOnlyScriptState { $0.instances.values.first(where: NativeSignedPassageOpening.marked) }
  }

  func signedPassageOpeningUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeSignedPassageOpening.matches(pack) else { return "Restore the original Signed Passage opening." }
    guard let instance = signedPassageOpeningMission else {
      return "Review Senn's commission at Neron in Galaxy 1 after one ordinary trade."
    }
    guard NativeSignedPassageOpening.prefixValid(instance) else { return "The original commission cannot currently be verified." }
    return nil
  }

  /// The actor's existing bound scriptCommand/writer publishes this candidate atomically.
  mutating func confirmSignedPassageOpening(_ quote: NativeSignedPassageOpeningReview) throws {
    let current = signedPassageOpeningReview(quote.action)
    guard quote.action == .accept, screen == .contracts, contractBoard.detail,
      contractBoard.action == .accept, contractBoard.selected?.signedPassageOpening == .accept,
      quote.allowed, current.allowed, quote.action == current.action,
      quote.arrival == current.arrival, quote.owner == current.owner,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.tradeOperation == current.tradeOperation, quote.caseRevision == current.caseRevision,
      quote.digest == current.digest, quote.epoch == nativeStationRuntimeEpoch,
      quote.epoch == current.epoch, quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, acceptsNativeMainStationArrivalContext(arrival)
    else { throw MissionPackError("The actual Neron service, trade or carrier changed; review again.") }
    var candidate = self
    try candidate.acceptSignedPassageOpening(at: arrival)
    self = candidate
  }

  private mutating func acceptSignedPassageOpening(at arrival: NativeMainStationArrivalContext) throws {
    guard acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, systemIdentity == NativeSignedPassageOpening.issuer,
      arrival.receipt.station.system == NativeSignedPassageOpening.issuer,
      let pack = signedPassageOpeningPack, let inventory = commander.equipmentInventory,
      inventory.owner == commander.equipmentOwnerID, inventory.activeHull == commander.hullInstanceID,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade, trade.owner == inventory.owner,
      trade.physicalTime <= commander.flightSimulation.physicalTime,
      signedPassageOpeningMission == nil, NativeSignedPassageOpeningSave.validateClaims(commander),
      commander.scriptState.instances.count < 128, commander.scriptState.pendingEvents.isEmpty,
      !scriptDispatching, !scriptEventsDeferred,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw MissionPackError("Use the actual Neron commission service after one ordinary trade.") }
    let id = NativeSignedPassageOpening.mission(owner: inventory.owner)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let facts = NativeSignedPassageOpeningRecord(mission: id, owner: inventory.owner,
      acceptance: NativeSignedPassageOpening.operation(mission: id, dock: arrival.receipt),
      carrier: inventory.activeHull, inventoryRevision: inventory.revision, dock: arrival.receipt,
      trade: trade.operation, eventSequence: commander.scriptState.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds)
    var instance = ScriptInstance(id: id, definition: NativeSignedPassageOpening.stateID,
      version: NativeSignedPassageOpening.version, digest: pack.digest)
    instance.savedNativeSignedPassageOpening = try .init(opening: facts)
    instance.receipts = [NativeSignedPassageOpening.acceptance]
    instance.milestones = [0]
    var candidate = self
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.signedPassageOpeningMission, accepted.id == id,
      NativeSignedPassageOpeningSave.validateClaims(candidate.commander),
      accepted.journal == NativeSignedPassageOpening.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.credits == commander.credits, candidate.commander.cargo == commander.cargo,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.flightSimulation == commander.flightSimulation,
      candidate.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw SaveError.invalidCommander }
    candidate.notify("SIGNED PASSAGE COMMISSION ACCEPTED - COLLECT THE ORIGINAL REFERENCE AT NERON")
    self = candidate
  }
}

extension Game {
  /// Original commissioning history and future requirements; reading creates no field evidence.
  func signedPassageOpeningGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeSignedPassageOpening.applies(pack) else { return nil }
    guard NativeSignedPassageOpening.matches(pack), signedPassageOpeningPack != nil,
      NativeSignedPassageOpeningSave.validateClaims(commander)
    else { return signedPassageOpeningUnavailableGallery(reason: "The original Signed Passage content or case cannot currently be verified.") }
    let titles = NativeSignedPassageOpening.Stage.allCases.map(\.objective)
    guard let instance = signedPassageOpeningMission else {
      let quote = signedPassageOpeningReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Senn's case at Neron in Galaxy 1.",
        briefing: pack.manifest.mission.briefing, destination: "Neron / Galaxy 1",
        reward: pack.manifest.mission.reward, prerequisites: quote.issues, completed: 0,
        milestones: signedPassageOpeningMilestones(titles, accepted: false), trialDigest: nil, savedInstance: nil)
    }
    let reason = instance.suspension == nil
      ? "Senn's actual finite original reference source at Neron is not currently available."
      : "Review the suspended original Signed Passage case before continuing."
    return .init(name: pack.manifest.mission.title, status: .locked, objective: reason,
      briefing: pack.manifest.mission.briefing + "\n\n" + instance.journal.joined(separator: "\n")
        + "\n\nCommission accepted. No original reference/serial/collection, actual crate/cradle observation/carrier handoff, living receiving witness/delegate reception, independent receiving locks/shared-register proof, fee or clue has been obtained.",
      destination: "Neron / Galaxy 1", reward: pack.manifest.mission.reward,
      prerequisites: [reason], completed: 1, milestones: signedPassageOpeningMilestones(titles, accepted: true),
      trialDigest: nil, savedInstance: instance.id)
  }

  func signedPassageOpeningMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeSignedPassageOpening.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return signedPassageOpeningUnavailableGallery(reason: "Restore the original Signed Passage content. Its current saved commission remains recorded.")
  }

  private func signedPassageOpeningMilestones(_ titles: [String], accepted: Bool) -> [MissionMilestone] {
    titles.enumerated().map { index, title in
      .init(title: title, state: index == 0 ? (accepted ? "Complete" : "Current") : "Unavailable")
    }
  }

  private func signedPassageOpeningUnavailableGallery(reason: String) -> GalleryMission {
    let accepted = signedPassageOpeningMission != nil && NativeSignedPassageOpeningSave.validateClaims(commander)
    return .init(name: "Signed Passage", status: .locked, objective: reason,
      briefing: "Review the original case commission and its current saved history.",
      destination: "Neron / Galaxy 1", reward: "No settlement available.", prerequisites: [reason],
      completed: accepted ? 1 : 0,
      milestones: accepted ? signedPassageOpeningMilestones(NativeSignedPassageOpening.Stage.allCases.map(\.objective), accepted: true) : [],
      trialDigest: nil, savedInstance: signedPassageOpeningMission?.id)
  }
}
