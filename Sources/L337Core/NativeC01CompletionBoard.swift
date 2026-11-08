import Foundation

/// The same-file constructors below are the only issuers. Decoded receipts cannot
/// reconstruct these live native arrival/fitting/consent offers.
final class NativeC01CompletionReviewPin: Sendable {
  fileprivate let action: NativeGlassMeridianAction
  fileprivate let arrival: NativeMainStationArrivalContext
  fileprivate let source: NativeC01CompletionSource
  fileprivate let disposition: UUID?

  fileprivate init(action: NativeGlassMeridianAction, arrival: NativeMainStationArrivalContext,
    source: NativeC01CompletionSource, disposition: UUID?)
  {
    self.action = action
    self.arrival = arrival
    self.source = source
    self.disposition = disposition
  }
  fileprivate func matches(_ other: NativeC01CompletionReviewPin) -> Bool {
    action == other.action && arrival == other.arrival && source == other.source
      && disposition == other.disposition
  }
}

private final class NativeC01RecorderArchivePlan: Sendable {
  let pin: NativeC01CompletionReviewPin
  let archive: NativeC01RecorderArchive
  init(pin: NativeC01CompletionReviewPin, archive: NativeC01RecorderArchive) {
    self.pin = pin
    self.archive = archive
  }
}

extension NativeGlassMeridianAction {
  var c01EvidenceChoice: NativeC01EvidenceChoice? {
    switch self {
    case .publishFullSafetyReport: .publicReport
    case .submitCrewArbitration: .arbitration
    default: nil
    }
  }
  var isC01Completion: Bool { c01EvidenceChoice != nil || self == .archiveRecorder }
}

extension Game {
  /// Bound canonical JSON bytes BEFORE hashing. The frame is typed and domain-separated.
  private func c01CompletionFitPin(_ snapshot: EquipmentPurchaseSnapshot) throws -> String {
    guard snapshot.items.count <= OwnedEquipmentInventory.maximumCount + 1,
      Set(snapshot.items.map(\.id)).count == snapshot.items.count
    else { throw SaveError.invalidCommander }
    let ordered = EquipmentPurchaseSnapshot(owner: snapshot.owner, activeHull: snapshot.activeHull,
      revision: snapshot.revision, funds: snapshot.funds,
      items: snapshot.items.sorted { $0.id.uuidString < $1.id.uuidString })
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(ordered)
    guard bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
    return try NativeC01Completion.hash("elite.c01.completion.fit.v1", [
      "jsonSHA256": .string(ScriptPackLibrary.hash(bytes)), "jsonByteCount": .integer(Int64(bytes.count)),
      "itemCount": .integer(Int64(ordered.items.count)),
    ], limit: 4096)
  }

  private func c01CompletionHistoryPin() throws -> String {
    guard let history = commander.savedEquipmentPurchaseHistory else {
      return try NativeC01Completion.hash("elite.c01.completion.equipment-history.v1", [
        "present": .bool(false), "jsonSHA256": .null, "jsonByteCount": .integer(0),
        "paidCount": .integer(0), "legacyCount": .integer(0),
      ], limit: 4096)
    }
    guard history.owner == commander.equipmentOwnerID, history.revision < UInt64(Int64.max)
    else { throw SaveError.invalidCommander }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(history)
    guard bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
    return try NativeC01Completion.hash("elite.c01.completion.equipment-history.v1", [
      "present": .bool(true), "jsonSHA256": .string(ScriptPackLibrary.hash(bytes)),
      "jsonByteCount": .integer(Int64(bytes.count)), "paidCount": .integer(Int64(history.paid.count)),
      "legacyCount": .integer(Int64(history.legacy.count)),
    ], limit: 4096)
  }

  private func c01CompletionPin(_ action: NativeGlassMeridianAction) throws -> NativeC01CompletionReviewPin {
    guard action.isC01Completion, !paused, !isMissionTrial, trialTitle == nil,
      scriptDurabilityAvailable, glassMeridianPack != nil,
      contractStation == NativeGlassMeridian.source,
      let dock = commander.nativeStations?.currentMainDock,
      let arrival = nativeMainStationArrivalContext(for: dock.station), arrival.receipt == dock,
      acceptsNativeMainStationArrivalContext(arrival),
      let mission = glassMeridianMission, mission.outcome == .active, mission.suspension == nil,
      commander.valid, NativeGlassMeridianSave.validateClaims(commander),
      let opening = mission.savedGlassMeridian,
      let capture = opening.surveyor?.capture, opening.surveyor?.held == true,
      opening.surveyor?.loss == nil, opening.surveyor?.archive == nil,
      let recorderActor = capture.marker.body.physical?.identity,
      let installation = opening.laneRepair?.installation,
      opening.timingStandard?.used == installation, opening.timingStandard?.loss == nil,
      let clinic = opening.clinicEscort, let reception = clinic.arrival,
      NativeC01ClinicEscortSave.valid(clinic, mission: mission, commander: commander),
      let snapshot = try? commander.purchaseSnapshot(), snapshot.owner == opening.permission.owner,
      snapshot.activeHull == commander.hullInstanceID,
      snapshot.revision < UInt64(Int64.max),
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      commander.scriptState.pendingEvents.count < 4096, mission.receipts.count <= 4090,
      (0...4_294_967_295).contains(commander.credits)
    else { throw MissionPackError("Use Venn's living Avenor main berth with the same original recorder and genuine clinic reception.") }
    if action.c01EvidenceChoice != nil {
      guard opening.completion == nil, mission.milestones == Set(0...6), mission.journal.count < 512
      else { throw MissionPackError("The evidence choice is already recorded; review its history.") }
    } else {
      guard opening.completion?.terminal == nil, opening.completion != nil,
        mission.milestones == Set(0...7), commander.credits <= 4_294_967_295 - NativeC01Completion.payment
      else { throw MissionPackError("Select the evidence outcome first, and leave room for the full 4,800 CR fee.") }
      let maximum = NativeC01CompletionSave.hasRetainedSpare(opening, commander: commander) ? 511 : 512
      guard mission.journal.count < maximum else { throw MissionPackError("The case journal needs room for final receiving and retained clinic history.") }
    }
    let history = commander.savedEquipmentPurchaseHistory
    let source = NativeC01CompletionSource(mission: mission.id, owner: snapshot.owner,
      permission: opening.permission.operation, capture: capture.operation, marker: capture.marker.identity,
      recorderActor: recorderActor, installation: installation.operation,
      clinicArrival: reception.operation, clinicReception: reception.sourceReception,
      dock: dock, carrier: snapshot.activeHull, inventoryRevision: snapshot.revision,
      inventoryFingerprint: try c01CompletionFitPin(snapshot), historyPresent: history != nil,
      historyRevision: history?.revision ?? 0, historyFingerprint: try c01CompletionHistoryPin(),
      missionRevision: mission.revision, nextEvent: commander.scriptState.nextEvent,
      funds: commander.credits, physicalTime: commander.flightSimulation.physicalTime,
      epoch: nativeStationRuntimeEpoch)
    guard source.shapeValid else { throw SaveError.invalidCommander }
    return .init(action: action, arrival: arrival, source: source,
      disposition: opening.completion?.disposition.operation)
  }

  func c01CompletionReview(_ action: NativeGlassMeridianAction) -> NativeGlassMeridianReview {
    do {
      let pin = try c01CompletionPin(action)
      return .init(action: action, dock: pin.source.dock, carrier: pin.source.carrier,
        inventoryRevision: pin.source.inventoryRevision, epoch: pin.source.epoch,
        issues: [], completionPin: pin)
    } catch {
      return .init(action: action, dock: commander.nativeStations?.currentMainDock,
        carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
        epoch: nativeStationRuntimeEpoch, issues: [String(error.localizedDescription.prefix(512))])
    }
  }

  mutating func confirmC01Completion(_ review: NativeGlassMeridianReview) throws {
    guard review.action.isC01Completion, review.allowed, let pin = review.completionPin,
      pin.matches(try c01CompletionPin(review.action))
    else { throw MissionPackError("The source, choice, original custody or actual berth changed; review again.") }
    if let choice = review.action.c01EvidenceChoice {
      try commitC01Disposition(pin: pin, consent: review.reviewToken, choice: choice)
    } else {
      let plan = try prepareC01RecorderArchive(pin: pin, consent: review.reviewToken)
      try commitC01RecorderArchive(plan)
    }
  }

  private mutating func commitC01Disposition(
    pin: NativeC01CompletionReviewPin, consent: UUID, choice: NativeC01EvidenceChoice
  ) throws {
    guard pin.matches(try c01CompletionPin(pin.action)),
      var mission = glassMeridianMission, var opening = mission.savedGlassMeridian
    else { throw SaveError.invalidCommander }
    let cause = scriptEventContext(mission)
    let sequence = pin.source.nextEvent + 1
    mission.revision += 1
    mission.acknowledge(sequence)
    let receipt = ScriptChoiceReceipt(instance: mission.id, group: NativeC01Completion.group,
      choice: choice.rawValue, label: choice.label, dialogue: NativeC01Completion.dialogue,
      sequence: sequence, revision: mission.revision, cause: cause, committed: scriptEventContext(mission))
    let disposition = NativeC01DispositionReceipt(
      operation: try NativeC01Completion.dispositionOperation(source: pin.source, consent: consent,
        choice: choice, sequence: sequence, revision: mission.revision),
      source: pin.source, consent: consent, choice: receipt)
    opening.completion = .init(disposition: disposition)
    mission.savedGlassMeridian = opening
    mission.choiceReceipts = [NativeC01Completion.group: receipt]
    mission.milestones.insert(7)
    mission.receipts.formUnion([NativeC01Completion.choiceReceipt, NativeC01Completion.group])
    mission.journal.append(NativeC01Completion.selectedJournal(choice))
    var candidate = self
    candidate.commander.scriptState.nextEvent = sequence
    candidate.commander.scriptState.instances[mission.id] = mission
    guard NativeGlassMeridianSave.validateClaims(candidate.commander) else { throw SaveError.invalidCommander }
    candidate.notify("EVIDENCE OUTCOME RECORDED - SAME ORIGINAL RECORDER REQUIRED FOR FINAL RECEIVING")
    self = candidate
  }

  private func prepareC01RecorderArchive(
    pin: NativeC01CompletionReviewPin, consent: UUID
  ) throws -> NativeC01RecorderArchivePlan {
    guard pin.action == .archiveRecorder, pin.matches(try c01CompletionPin(.archiveRecorder)),
      let disposition = pin.disposition
    else { throw SaveError.invalidCommander }
    let sequence = pin.source.nextEvent + 1
    let revision = pin.source.missionRevision + 1
    let archive = NativeC01RecorderArchive(
      operation: try NativeC01Completion.archiveOperation(source: pin.source, consent: consent,
        disposition: disposition, sequence: sequence, revision: revision),
      source: pin.source, disposition: disposition, consent: consent, sequence: sequence, revision: revision)
    return .init(pin: pin, archive: archive)
  }

  private mutating func commitC01RecorderArchive(_ plan: NativeC01RecorderArchivePlan) throws {
    guard plan.pin.matches(try c01CompletionPin(.archiveRecorder)),
      let previous = glassMeridianMission, var opening = previous.savedGlassMeridian,
      var completion = opening.completion, let clinic = opening.clinicEscort,
      let people = commander.nativePeople?.clinicSource,
      let choice = NativeC01EvidenceChoice(rawValue: completion.disposition.choice.choice)
    else { throw SaveError.invalidCommander }
    var candidate = self
    var mission = previous
    let cause = scriptEventContext(previous)
    let archive = plan.archive
    let after = archive.source.funds + NativeC01Completion.payment
    let payment = NativeC01PaymentHistory(
      operation: try NativeC01Completion.paymentOperation(archive: archive.operation,
        before: archive.source.funds, after: after), archive: archive.operation,
      amount: NativeC01Completion.payment, creditsBefore: archive.source.funds, creditsAfter: after)
    mission.journal.append(NativeC01Completion.finalJournal(choice))
    let lossIDs = NativeC01Completion.losses(clinic).map(\.operation).sorted { $0.uuidString < $1.uuidString }
    let journal = try NativeC01Completion.journalHash(mission.journal)
    let terminal = NativeC01TerminalHistory(
      operation: try NativeC01Completion.terminalOperation(archive: archive.operation,
        payment: payment.operation, sequence: archive.sequence, revision: archive.revision,
        journalCount: mission.journal.count, journalFingerprint: journal,
        clinicLosses: lossIDs, clinicRevision: people.revision),
      archive: archive.operation, payment: payment, sequence: archive.sequence, revision: archive.revision,
      journalCount: mission.journal.count, journalFingerprint: journal, clinicLosses: lossIDs,
      clinicDispositionRevision: people.revision)
    opening.surveyor?.archive = archive
    completion.terminal = terminal
    opening.completion = completion
    mission.savedGlassMeridian = opening
    mission.outcome = .complete
    mission.revision = archive.revision
    mission.milestones.insert(8)
    mission.receipts.formUnion(NativeC01Completion.localReceipts)
    mission.acknowledge(archive.sequence)
    candidate.commander.credits = after
    candidate.commander.scriptState.nextEvent = archive.sequence
    mission.completionReceipt = .init(instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: .complete,
      sequence: archive.sequence, causeKind: "mission.receipted", cause: cause,
      committed: candidate.scriptEventContext(mission), revision: mission.revision,
      milestones: mission.milestones.sorted(),
      destroyedEncounters: mission.ownedEncounters.values.filter(\.destroyed).map(\.id).sorted(),
      deliveredParties: [], returnedEquipment: [], settlementAmount: nil, choices: mission.choiceReceipts)
    candidate.commander.scriptState.instances[mission.id] = mission
    try candidate.awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    guard NativeGlassMeridianSave.validateClaims(candidate.commander) else { throw SaveError.invalidCommander }
    candidate.notify("ORIGINAL RECORDER ARCHIVED - 4,800 CR AND THE MISSING INSTANT RECORDED")
    self = candidate
  }

  func c01CompletionDetail(_ action: NativeGlassMeridianAction) -> [String] {
    var lines = [
      "VENN: A public report warns every pilot immediately. A sealed arbitration submission protects the crews while their compensation is assessed. Both preserve the complete ledger.",
    ]
    if let choice = action.c01EvidenceChoice {
      lines += [choice.label, "Select Accept and confirm to record this branch. Back or Esc selects no branch.",
        "The same original 8kg recorder remains aboard. No payment or clue at this choice."]
    } else {
      lines += ["Archive the same original 8kg recorder at this actual Avenor main berth.",
        "Confirm receives the completed lane report, pays 4,800 CR once and records The missing instant.",
        "The timing standard remains installed. No equipment purchase or prize is required."]
    }
    return lines + (contractBoard.glassMeridianQuote ?? c01CompletionReview(action)).issues
  }

  func c01CompletionHistory(_ opening: NativeGlassMeridianState) -> [String] {
    guard let completion = opening.completion else { return [] }
    var lines = ["Evidence outcome: " + completion.disposition.choice.label]
    if completion.terminal != nil {
      lines += ["The same original 8kg recorder is archived with Captain Venn at Avenor.",
        "4,800 CR, the public lane-safety commendation and The missing instant are recorded."]
    } else if opening.surveyor?.loss != nil {
      lines.append("The selected evidence outcome remains recorded. The lost original recorder cannot be replaced; final archive, fee and clue are not granted.")
    } else {
      lines.append("Next: confirm final receiving with the same original 8kg recorder at Avenor.")
    }
    return lines
  }

  var c01RegionalOutcomeRumour: String? {
    guard !isMissionTrial, trialTitle == nil, docked, dockedAtMainStation,
      commander.galaxy == 0, [0, 7, 91, 162, 164, 185].contains(commander.system),
      let mission = glassMeridianMission
    else { return nil }
    return NativeC01CompletionSave.projectedOutcome(mission, commander: commander)
  }
}
