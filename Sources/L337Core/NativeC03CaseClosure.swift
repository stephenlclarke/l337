import Foundation

enum NativeC03CaseClosure {
  static let receipt = "hollow-manifest-case-closed"
  static let authoredReceipt = "l337.hollow-manifest/close-case"
  static let journal = [
    "TOREN: The false claims have stopped. The completed rescue and its later custody history remain on record. Your audit fee is 5,600 CR. Your own offences, if any, remain your responsibility.",
    "TOREN: The master seal carried an older imprint beneath its serial number. It was never part of the freight register. Keep the image; the loops seem to point towards something missing from the middle.",
  ]
}

final class NativeC03CaseClosureReview: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let arrival: NativeMainStationArrivalContext
  let returned: NativeC03EvidenceReturnReceipt
  let credits: Int
  let nextEvent: UInt64
  fileprivate init(pin: NativeHollowManifestInstalledCase, arrival: NativeMainStationArrivalContext,
    returned: NativeC03EvidenceReturnReceipt, credits: Int, nextEvent: UInt64)
  {
    self.pin = pin
    self.arrival = arrival
    self.returned = returned
    self.credits = credits
    self.nextEvent = nextEvent
  }
}

/// The real institutional source must confirm resolution of the duplicate claims, the
/// preserved original evidence and the actual original receiving record. A filing alone
/// is not resolution. NO factory exists while that source/record is unimplemented.
final class NativeC03CaseResolutionWitness: Sendable {
  let operation: UUID
  let returned: UUID
  let remedy: UUID
  private let snapshot: CommanderSnapshot
  private let bodies: [SpaceBody]
  private let epoch: UUID

  private init(game: borrowing Game, operation: UUID, returned: UUID, remedy: UUID) {
    self.operation = operation
    self.returned = returned
    self.remedy = remedy
    snapshot = CommanderSnapshot(game.commander)
    bodies = game.bodies
    epoch = game.nativeStationRuntimeEpoch
  }

  fileprivate func isCurrent(in game: borrowing Game) -> Bool {
    guard epoch == game.nativeStationRuntimeEpoch else { return false }
    guard bodies == game.bodies else { return false }
    return snapshot.value == game.commander
  }
}

struct NativeC03CaseClosureReceipt: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let evidenceReturn: UUID
    let remedy: UUID
    let resolution: UUID
    let originalCareTransfer: UUID
    let dock: NativeMainStationDockReceipt
    let creditsBefore: Int
    let creditsAfter: Int
    let beforeCaseRevision: UInt64
    let afterCaseRevision: UInt64
    let sourceSequence: UInt64
    let eventSequence: UInt64
    let physicalTime: Double
    let calendarSeconds: Double
    let epoch: UUID
  }
  let operation: UUID
  let facts: Facts

  fileprivate init(actual: NativeC03CaseResolutionWitness, facts: Facts) throws {
    guard actual.operation == facts.resolution, actual.returned == facts.evidenceReturn,
      actual.remedy == facts.remedy else { throw SaveError.invalidCommander }
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func identity(_ facts: Facts) throws -> UUID {
    // Every field is a fixed scalar/identity. Validate addition bounds before arithmetic.
    guard (0...4_294_967_295 - NativeHollowManifestDefinition.terminalRewardTenths)
      .contains(facts.creditsBefore),
      facts.creditsAfter == facts.creditsBefore + NativeHollowManifestDefinition.terminalRewardTenths
    else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-original-case-payment-v1:\(try NativeFlightReception.hash(facts))")
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    let f = facts
    guard let file = state.caseFile, let returned = file.evidenceReturn,
      returned.valid(in: state), operation == (try? Self.identity(f)),
      f.mission == state.birth.input.mission, f.owner == state.birth.input.owner,
      f.evidenceReturn == returned.operation, f.remedy == file.remedy?.operation,
      f.originalCareTransfer == file.ledger.facts.originalCareTransfer,
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestDefinition.issuer,
      f.beforeCaseRevision >= returned.facts.afterCaseRevision,
      f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1,
      f.sourceSequence > returned.facts.sequence, f.sourceSequence < state.nextSourceSequence,
      f.eventSequence > 0, f.eventSequence < UInt64(Int64.max),
      f.physicalTime.isFinite, f.physicalTime >= returned.facts.physicalTime,
      f.physicalTime <= 1e12, f.calendarSeconds.isFinite,
      f.calendarSeconds >= returned.facts.calendarSeconds,
      f.calendarSeconds >= f.dock.calendarSeconds, f.calendarSeconds <= 1e12
    else { return false }
    return true
  }

  /// Historical credit values may differ from later spendable funds. Genuine receiving and
  /// claim-resolution source records must additionally reciprocate in G1's full save graph.
  func valid(commander: borrowing Commander) -> Bool {
    let f = facts
    guard let mission = commander.scriptState.instances[f.mission],
      let state = mission.savedHollowManifest, valid(in: state),
      let returned = state.caseFile?.evidenceReturn, returned.valid(commander: commander),
      let completion = mission.completionReceipt,
      NativeC03CaseClosureSave.validCompletion(completion, state: mission, engine: commander.scriptState),
      let world = commander.nativeStations, world.mainStations.contains(f.dock.station),
      f.dock.sequence < world.nextMainDockSequence,
      f.dock.actor.visit <= commander.flightSimulation.visit,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: f.calendarSeconds,
        current: commander.scriptState.calendarSeconds)
    else { return false }
    return true
  }
}

/// Acyclic leaf used by both the generic completion validator and native save graph.
/// It never calls receipt.valid, the clue journal, full Commander validity or provider code.
enum NativeC03CaseClosureSave {
  static func terminalClaimsMatch(_ mission: borrowing ScriptInstance,
    state: borrowing NativeHollowManifestState) -> Bool
  {
    guard let closed = state.caseFile?.closure else {
      guard mission.outcome == .active else { return false }
      return mission.completionReceipt == nil
    }
    guard closed.valid(in: state), mission.outcome == .complete,
      mission.revision == closed.facts.afterCaseRevision, let receipt = mission.completionReceipt,
      receipt.instance == mission.id, receipt.definition == mission.definition,
      receipt.version == mission.version, receipt.digest == mission.digest,
      receipt.outcome == .complete, receipt.sequence == closed.facts.eventSequence,
      receipt.revision == mission.revision else { return false }
    return true
  }

  static func validCompletion(_ receipt: ScriptCompletionReceipt, state mission: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState) -> Bool
  {
    guard mission.definition == NativeHollowManifestCommission.stateID,
      mission.digest == NativeHollowManifestCommission.digest,
      mission.version == NativeHollowManifestCommission.version,
      let state = mission.savedHollowManifest, let closed = state.caseFile?.closure,
      terminalClaimsMatch(mission, state: state),
      mission.completionReceipt == receipt, receipt.causeKind == "mission.receipted",
      receipt.sequence <= engine.nextEvent, mission.hasAcknowledged(receipt.sequence),
      let cause = receipt.cause, cause.valid, receipt.committed.valid,
      cause.revision == closed.facts.beforeCaseRevision,
      cause.nativeMainDock == closed.facts.dock,
      receipt.committed.nativeMainDock == closed.facts.dock,
      receipt.committed.revision == closed.facts.afterCaseRevision,
      cause.calendarSeconds == closed.facts.calendarSeconds,
      receipt.committed.calendarSeconds == closed.facts.calendarSeconds,
      cause.localSeconds == receipt.committed.localSeconds,
      cause.flightSeconds == receipt.committed.flightSeconds,
      cause.transitSeconds == receipt.committed.transitSeconds,
      receipt.committed.localSeconds <= engine.localSeconds,
      receipt.committed.flightSeconds <= engine.flightSeconds,
      receipt.committed.calendarSeconds <= engine.calendarSeconds,
      receipt.committed.transitSeconds <= engine.transitSeconds,
      mission.milestones == Set(0...9), receipt.milestones == Array(0...9),
      receipt.returnedEquipment == [NativeHollowManifestKitDefinition.resource],
      receipt.deliveredParties.isEmpty, receipt.settlementAmount == nil,
      receipt.choices == nil, mission.choiceReceipts.isEmpty, mission.contract == nil,
      receipt.destroyedEncounters == mission.ownedEncounters.values.filter(\.destroyed).map(\.id).sorted()
    else { return false }
    return true
  }
}

extension Game {
  func hollowManifestCaseClosureReview() throws -> NativeC03CaseClosureReview {
    guard !isMissionTrial, trialTitle == nil, screen == .contracts,
      systemIdentity == NativeHollowManifestDefinition.issuer,
      let mission = hollowManifestMission, mission.outcome == .active, mission.suspension == nil,
      mission.milestones == Set(0...8), mission.revision < UInt64(Int64.max) - 1,
      let file = mission.savedHollowManifest?.caseFile,
      let returned = file.evidenceReturn, file.closure == nil, file.valid(commander: commander),
      (0...4_294_967_295 - NativeHollowManifestDefinition.terminalRewardTenths).contains(commander.credits),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity)
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    guard acceptsHollowManifestInstalledCase(pin), acceptsNativeMainStationArrivalContext(arrival)
    else { throw SaveError.invalidCommander }
    return .init(pin: pin, arrival: arrival, returned: returned, credits: commander.credits,
      nextEvent: commander.scriptState.nextEvent)
  }

  @inline(never)
  mutating func closeHollowManifestCase(_ review: NativeC03CaseClosureReview,
    resolution: NativeC03CaseResolutionWitness) throws
  {
    let current = try hollowManifestCaseClosureReview()
    guard acceptsHollowManifestInstalledCase(review.pin), resolution.isCurrent(in: self),
      review.arrival == current.arrival, review.returned == current.returned,
      review.credits == current.credits, review.nextEvent == current.nextEvent,
      resolution.returned == current.returned.operation,
      let previous = hollowManifestMission, let state = previous.savedHollowManifest,
      let file = state.caseFile, let remedy = file.remedy,
      resolution.remedy == remedy.operation, state.nextSourceSequence < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let facts = NativeC03CaseClosureReceipt.Facts(mission: previous.id, owner: current.pin.owner,
      evidenceReturn: current.returned.operation, remedy: remedy.operation, resolution: resolution.operation,
      originalCareTransfer: file.ledger.facts.originalCareTransfer, dock: current.arrival.receipt,
      creditsBefore: current.credits,
      creditsAfter: current.credits + NativeHollowManifestDefinition.terminalRewardTenths,
      beforeCaseRevision: previous.revision, afterCaseRevision: previous.revision + 1,
      sourceSequence: state.nextSourceSequence, eventSequence: current.nextEvent + 1,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch)
    let closed = try NativeC03CaseClosureReceipt(actual: resolution, facts: facts)
    var mission = previous
    let cause = scriptEventContext(previous)
    mission.savedHollowManifest = try state.retainingCaseFile(file.closing(closed))
    mission.outcome = .complete
    mission.revision = facts.afterCaseRevision
    mission.receipts.formUnion([NativeC03CaseClosure.receipt, NativeHollowManifestDefinition.terminalRewardReceipt])
    mission.milestones.insert(9)
    mission.journal += NativeC03CaseClosure.journal
    mission.acknowledge(facts.eventSequence)
    var candidate = self
    candidate.commander.credits = facts.creditsAfter
    candidate.commander.scriptState.nextEvent = facts.eventSequence
    mission.completionReceipt = .init(instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: .complete,
      sequence: facts.eventSequence, causeKind: "mission.receipted", cause: cause,
      committed: candidate.scriptEventContext(mission), revision: mission.revision,
      milestones: mission.milestones.sorted(),
      destroyedEncounters: mission.ownedEncounters.values.filter(\.destroyed).map(\.id).sorted(),
      deliveredParties: [], returnedEquipment: [NativeHollowManifestKitDefinition.resource],
      settlementAmount: nil, choices: nil)
    candidate.commander.scriptState.instances[mission.id] = mission
    try candidate.awardScriptClue(previous: previous, next: mission, trust: .production)
    guard let completion = mission.completionReceipt,
      let award = candidate.commander.scriptState.savedClueJournal?.awards[NativeHollowManifestDefinition.logicalSourceID],
      award.clueID == NativeHollowManifestDefinition.completionClueID,
      award.receiptID == NativeHollowManifestDefinition.completionClueReceipt,
      award.completion == completion else { throw SaveError.invalidCommander }
    try candidate.enqueueScriptCompletion(completion)
    guard closed.valid(commander: candidate.commander),
      NativeHollowManifestSave.validateClaims(candidate.commander),
      candidate.commander.equipmentInventory == commander.equipmentInventory,
      candidate.commander.nativePeople == commander.nativePeople,
      candidate.commander.nativeStations == commander.nativeStations,
      candidate.commander.cargo == commander.cargo,
      candidate.commander.flightSimulation == commander.flightSimulation,
      acceptsHollowManifestInstalledCase(review.pin)
    else { throw SaveError.invalidCommander }
    self = candidate
  }
}
