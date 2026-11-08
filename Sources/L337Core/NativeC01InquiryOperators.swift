import Foundation

/// Component preparation only. The inquiry owner must publish the complete case
/// with this source in its existing protected writer; no method here writes a file.
enum NativeC01InquiryOperatorFailure: Error, Sendable {
  case unavailable, sourceMismatch, unfinishedCase, invalidHistory, revisionOverflow, staleContext
}

private struct NativeC01InquiryOperatorProjection {
  struct Subject {
    let key: String
    let ordinal: Int
  }
  struct Duty {
    let role: NativeC01InquiryDutyRole
    let subjectKey: String
  }
  let pins: NativeC01InquirySourcePins
  let registry: NativeC01InquiryRegistryRef
  let subjects: [Subject]
  let duties: [Duty]

  // Actual private-created owner outputs are required. There is no decoded
  // approval flag, caller-provided digest, or alternate pending-content loader.
  static func load() throws -> Self {
    let content = try NativeC01CharterArchiveApproval.load()
    let approved = try NativeCharterArchiveRegistryApproval.load()
    let sourceID = "l337.glass-meridian"
    guard content.archive.publication == .publishedSource,
      content.calibration.publication == .publishedSource,
      let group = content.archive.sourceGroups[sourceID],
      let source = approved.source(for: sourceID),
      source.clueID == "meridian-offset",
      source.receiptID == "l337.unwritten-route/clue/meridian-offset",
      source.archiveSHA256 == content.archiveSHA256,
      source.calibrationSHA256 == content.calibrationSHA256,
      group.sourceBinding.sourceID == sourceID,
      group.sourceBinding.clueID == source.clueID,
      group.sourceBinding.clueReceipt == source.receiptID,
      group.institutionalServiceSource.hostPolicy == "every-operational-main-station",
      group.institutionalServiceSource.subjectDefinitions.count == 2,
      group.institutionalServiceSource.initialDutyMapping.count == 2,
      group.challengeArchiveRoles.count == 3, source.observations.count == 3,
      approved.provenance.sourceSetCommit == group.sourceBinding.sourceSetBinding.commit,
      approved.provenance.sourceSetPath == group.sourceBinding.sourceSetBinding.path,
      approved.provenance.sourceSetSHA256 == group.sourceBinding.sourceSetBinding.sha256
    else { throw NativeC01InquiryOperatorFailure.sourceMismatch }
    for (index, role) in group.challengeArchiveRoles.enumerated() {
      let observed = source.observations[index]
      guard role.sourceID == sourceID, role.challengeOrdinal == index,
        role.recordID == observed.recordID, role.replicaID == observed.replicaID,
        role.origin.identity == observed.originIdentity, role.origin.domain == observed.originDomain,
        role.recordPayloadSHA256 == observed.payloadSHA256
      else { throw NativeC01InquiryOperatorFailure.sourceMismatch }
    }
    let service = group.institutionalServiceSource
    let staffing = group.serviceStaffingPolicy
    let pins = NativeC01InquirySourcePins(
      sourceID: sourceID, clueID: source.clueID, clueReceipt: source.receiptID,
      definition: .init(identity: service.definitionID, revision: service.definitionRevision,
        sha256: service.definitionSHA256),
      staffing: .init(identity: staffing.policyID, revision: staffing.policyRevision,
        sha256: staffing.policySHA256),
      archiveRoles: .init(identity: service.challengeArchiveRolesReference.identity,
        revision: service.challengeArchiveRolesReference.revision,
        sha256: service.challengeArchiveRolesReference.sha256),
      originalDefinitionSHA256: group.sourceBinding.originalDefinition.sha256,
      archiveContentSHA256: content.archiveSHA256,
      calibrationContentSHA256: content.calibrationSHA256,
      registrySHA256: approved.provenance.corpusSHA256)
    let registry = NativeC01InquiryRegistryRef(
      sourceSetCommit: approved.provenance.sourceSetCommit,
      sourceSetPath: approved.provenance.sourceSetPath,
      sourceSetSHA256: approved.provenance.sourceSetSHA256,
      corpusSchema: approved.provenance.corpusSchema,
      corpusRevision: approved.provenance.corpusRevision,
      corpusSHA256: approved.provenance.corpusSHA256)
    guard pins.shapeValid, registry.shapeValid else {
      throw NativeC01InquiryOperatorFailure.sourceMismatch
    }
    return .init(pins: pins, registry: registry,
      subjects: service.subjectDefinitions.map { .init(key: $0.definitionKey, ordinal: $0.ordinal) },
      duties: service.initialDutyMapping.map {
        let role: NativeC01InquiryDutyRole
        switch $0.roleKey { case .intake: role = .intake; case .independentReview: role = .independentReview }
        return .init(role: role, subjectKey: $0.subjectDefinitionKey)
      })
  }

  func matches(_ source: NativeC01InquiryInstitutionalSource) -> Bool {
    guard source.shapeValid, source.pins == pins else { return false }
    for expected in subjects {
      guard source.subjects.contains(where: {
        $0.ref.ordinal == expected.ordinal && $0.definitionKey == expected.key
      }) else { return false }
    }
    for expected in duties {
      guard let duty = source.duties.first(where: { $0.role == expected.role }),
        let subject = source.subjects.first(where: { $0.ref == duty.subject }),
        subject.definitionKey == expected.subjectKey, duty.policy == pins.staffing
      else { return false }
    }
    return true
  }
}

/// Immutable proposal, not a committed source, mandate or usable duty context.
/// Its first-case ID is a new request identity; it is never an approval credential.
final class NativeC01InquiryOperatorIntakePlan: Sendable {
  let beforeSource: NativeC01InquiryInstitutionalSource?
  let source: NativeC01InquiryInstitutionalSource
  let caseID: UUID
  let caseOrdinal: UInt64
  let intake: NativeC01InquiryAssignmentUse
  let registry: NativeC01InquiryRegistryRef
  fileprivate let beforeCaseID: UUID?
  fileprivate let beforeCaseRevision: UInt64?
  fileprivate let arrival: NativeMainStationArrivalContext
  fileprivate let epoch: UUID

  fileprivate init(
    beforeSource: NativeC01InquiryInstitutionalSource?, source: NativeC01InquiryInstitutionalSource,
    caseID: UUID, caseOrdinal: UInt64, intake: NativeC01InquiryAssignmentUse,
    registry: NativeC01InquiryRegistryRef, beforeCaseID: UUID?, beforeCaseRevision: UInt64?,
    arrival: NativeMainStationArrivalContext, epoch: UUID
  ) {
    self.beforeSource = beforeSource
    self.source = source
    self.caseID = caseID
    self.caseOrdinal = caseOrdinal
    self.intake = intake
    self.registry = registry
    self.beforeCaseID = beforeCaseID
    self.beforeCaseRevision = beforeCaseRevision
    self.arrival = arrival
    self.epoch = epoch
  }
}

/// Fresh source/duty context only. No audit, final verifier, measurement or arm is issued.
final class NativeC01InquiryOperatorReviewContext: Sendable {
  let source: NativeC01InquiryInstitutionalSource
  let duty: NativeC01InquiryStandingDuty
  let caseID: UUID
  let caseRevision: UInt64
  fileprivate let nextCaseRevision: UInt64
  fileprivate let arrival: NativeMainStationArrivalContext
  fileprivate let player: ActorIdentity
  fileprivate let carrier: UUID
  fileprivate let epoch: UUID
  fileprivate let operation: UUID

  fileprivate init(
    source: NativeC01InquiryInstitutionalSource, duty: NativeC01InquiryStandingDuty,
    caseID: UUID, caseRevision: UInt64, nextCaseRevision: UInt64,
    arrival: NativeMainStationArrivalContext, player: ActorIdentity, carrier: UUID,
    epoch: UUID, operation: UUID
  ) {
    self.source = source
    self.duty = duty
    self.caseID = caseID
    self.caseRevision = caseRevision
    self.nextCaseRevision = nextCaseRevision
    self.arrival = arrival
    self.player = player
    self.carrier = carrier
    self.epoch = epoch
    self.operation = operation
  }
}

/// A negative native observation, not inferred death or consent of an individual person.
final class NativeC01InquiryOperatorHostLossPlan: Sendable {
  let before: NativeC01InquiryInstitutionalSource
  let after: NativeC01InquiryInstitutionalSource
  fileprivate let epoch: UUID
  fileprivate init(
    before: NativeC01InquiryInstitutionalSource, after: NativeC01InquiryInstitutionalSource,
    epoch: UUID
  ) {
    self.before = before
    self.after = after
    self.epoch = epoch
  }
}

extension Game {
  /// Explicit first/successor request preparation. The complete mandate and ONE
  /// root still belong to the inquiry owner and must use the same protected writer.
  func prepareC01InquiryOperatorIntake() throws -> NativeC01InquiryOperatorIntakePlan {
    let before = commander.scriptState.savedC01Inquiry
    if let before, before.caseRecord.phase != .closeInquiry {
      throw NativeC01InquiryOperatorFailure.unfinishedCase
    }
    let projection = try NativeC01InquiryOperatorProjection.load()
    let arrival = try c01OperatorArrival()
    guard let owner = commander.equipmentOwnerID, let player = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID
    else { throw NativeC01InquiryOperatorFailure.unavailable }
    let operation = UUID()
    let source: NativeC01InquiryInstitutionalSource
    let ordinal: UInt64
    if let before {
      guard before.shapeValid, before.owner == owner,
        projection.matches(before.institutionalSource),
        before.caseRecord.mandate.registry == projection.registry,
        before.institutionalSource.host == arrival.receipt.station,
        before.nextCaseOrdinal < UInt64.max
      else { throw NativeC01InquiryOperatorFailure.invalidHistory }
      source = before.institutionalSource
      ordinal = before.nextCaseOrdinal
    } else {
      source = try c01CreateOperatorSource(
        projection, owner: owner, operation: operation, arrival: arrival)
      ordinal = 0
    }
    guard source.availability == .available,
      let (duty, _) = source.availableDuty(.intake)
    else { throw NativeC01InquiryOperatorFailure.unavailable }
    let caseID = UUID()
    let intake = try c01OperatorUse(source: source, duty: duty, operation: operation,
      caseID: caseID, caseRevision: 1, arrival: arrival, player: player, carrier: carrier)
    return .init(beforeSource: before?.institutionalSource, source: source,
      caseID: caseID, caseOrdinal: ordinal, intake: intake, registry: projection.registry,
      beforeCaseID: before?.caseRecord.id, beforeCaseRevision: before?.caseRecord.revision,
      arrival: arrival, epoch: nativeStationRuntimeEpoch)
  }

  func c01InquiryOperatorIntakeIsCurrent(_ plan: NativeC01InquiryOperatorIntakePlan) -> Bool {
    guard let projection = try? NativeC01InquiryOperatorProjection.load(),
      projection.matches(plan.source), projection.registry == plan.registry,
      plan.epoch == nativeStationRuntimeEpoch,
      acceptsNativeMainStationArrivalContext(plan.arrival),
      plan.source.host == plan.arrival.receipt.station,
      plan.source.owner == commander.equipmentOwnerID,
      plan.intake.carrier == commander.hullInstanceID,
      plan.intake.player == commander.flightSimulation.player,
      plan.intake.matches(plan.source), plan.intake.role == .intake
    else { return false }
    let actual = commander.scriptState.savedC01Inquiry
    if let beforeSource = plan.beforeSource {
      guard let actual, actual.shapeValid,
        actual.institutionalSource == beforeSource, plan.source == beforeSource,
        actual.caseRecord.id == plan.beforeCaseID,
        actual.caseRecord.revision == plan.beforeCaseRevision,
        actual.caseRecord.phase == .closeInquiry, actual.nextCaseOrdinal == plan.caseOrdinal
      else { return false }
      return true
    }
    return actual == nil && plan.caseOrdinal == 0
      && plan.source.birthOperation == plan.intake.operation
      && plan.source.activationArrival == plan.arrival.receipt
  }

  func prepareC01InquiryOperatorReview() throws -> NativeC01InquiryOperatorReviewContext {
    let projection = try NativeC01InquiryOperatorProjection.load()
    guard let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.owner == commander.equipmentOwnerID, projection.matches(root.institutionalSource),
      root.caseRecord.mandate.registry == projection.registry,
      root.caseRecord.phase == .testCorrectiveModel, root.caseRecord.audit == nil,
      root.institutionalSource.availability == .available,
      let (duty, _) = root.institutionalSource.availableDuty(.independentReview),
      let player = commander.flightSimulation.player, let carrier = commander.hullInstanceID
    else { throw NativeC01InquiryOperatorFailure.unavailable }
    let arrival = try c01OperatorArrival()
    guard arrival.receipt.station == root.institutionalSource.host else {
      throw NativeC01InquiryOperatorFailure.unavailable
    }
    return .init(source: root.institutionalSource, duty: duty,
      caseID: root.caseRecord.id, caseRevision: root.caseRecord.revision,
      nextCaseRevision: try c01OperatorNextRevision(root.caseRecord.revision),
      arrival: arrival, player: player, carrier: carrier, epoch: nativeStationRuntimeEpoch,
      operation: UUID())
  }

  func c01InquiryOperatorAssignment(
    _ context: NativeC01InquiryOperatorReviewContext
  ) throws -> NativeC01InquiryAssignmentUse {
    let projection = try NativeC01InquiryOperatorProjection.load()
    guard let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      projection.matches(root.institutionalSource),
      root.caseRecord.mandate.registry == projection.registry,
      root.institutionalSource == context.source, root.caseRecord.id == context.caseID,
      root.caseRecord.revision == context.caseRevision,
      root.caseRecord.phase == .testCorrectiveModel, root.caseRecord.audit == nil,
      context.epoch == nativeStationRuntimeEpoch,
      commander.equipmentOwnerID == context.source.owner,
      commander.hullInstanceID == context.carrier,
      commander.flightSimulation.player == context.player,
      acceptsNativeMainStationArrivalContext(context.arrival),
      context.source.availability == .available,
      let (duty, _) = context.source.availableDuty(.independentReview), duty == context.duty
    else { throw NativeC01InquiryOperatorFailure.staleContext }
    return try c01OperatorUse(source: context.source, duty: duty, operation: context.operation,
      caseID: context.caseID, caseRevision: context.nextCaseRevision,
      arrival: context.arrival, player: context.player, carrier: context.carrier)
  }

  /// Only an actual destroyed original host can make this negative proposal.
  /// Leaving the scene or losing a transient context never fabricates this fact.
  func prepareC01InquiryOperatorHostLoss() throws -> NativeC01InquiryOperatorHostLossPlan? {
    guard let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.owner == commander.equipmentOwnerID
    else { return nil }
    let before = root.institutionalSource
    guard before.availability == .available,
      case .destroyed(let host) = nativeOriginalMainStationDestination, host == before.host
    else { return nil }
    let operation = UUID()
    let revision = try c01OperatorNextRevision(before.revision)
    let subjects = try before.subjects.map {
      try NativeC01InquiryOperatorSubjectData.recordingHostLoss($0, operation: operation)
    }
    let after = NativeC01InquiryInstitutionalSource(owner: before.owner, host: before.host,
      pins: before.pins, birthOperation: before.birthOperation, revision: revision,
      activationArrival: before.activationArrival,
      activationPhysicalTime: before.activationPhysicalTime, subjects: subjects,
      duties: before.duties, availability: .unavailable, unavailabilityOperation: operation)
    guard after.shapeValid else { throw NativeC01InquiryOperatorFailure.invalidHistory }
    return .init(before: before, after: after, epoch: nativeStationRuntimeEpoch)
  }

  /// Stage only retained operator DATA against the latest attained game. The
  /// autonomous publication owner must not rewind physical loss on writer failure.
  mutating func stageC01InquiryOperatorHostLoss(_ plan: NativeC01InquiryOperatorHostLossPlan) throws {
    guard let root = commander.scriptState.savedC01Inquiry,
      root.owner == commander.equipmentOwnerID,
      case .destroyed(let host) = nativeOriginalMainStationDestination,
      host == plan.before.host, plan.epoch == nativeStationRuntimeEpoch
    else { throw NativeC01InquiryOperatorFailure.staleContext }
    if root.institutionalSource == plan.after { return }
    guard root.institutionalSource == plan.before, plan.after.shapeValid else {
      throw NativeC01InquiryOperatorFailure.staleContext
    }
    // Exactly the ONE root's source changes. Every current/prior case, assignment
    // and fixture-life record stays intact; historical duty matching ignores availability.
    commander.scriptState.savedC01Inquiry = .init(owner: root.owner,
      nextCaseOrdinal: root.nextCaseOrdinal, institutionalSource: plan.after,
      caseRecord: root.caseRecord, priorCases: root.priorCases, fixtureLifecycle: root.fixtureLifecycle)
  }

  private func c01OperatorArrival() throws -> NativeMainStationArrivalContext {
    guard case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity),
      acceptsNativeMainStationArrivalContext(arrival),
      arrival.receipt.commanderOwner == commander.equipmentOwnerID,
      commander.flightSimulation.physicalTime.isFinite,
      commander.flightSimulation.physicalTime >= 0,
      commander.flightSimulation.physicalTime <= 1e12
    else { throw NativeC01InquiryOperatorFailure.unavailable }
    return arrival
  }

  private func c01CreateOperatorSource(
    _ projection: NativeC01InquiryOperatorProjection, owner: UUID, operation: UUID,
    arrival: NativeMainStationArrivalContext
  ) throws -> NativeC01InquiryInstitutionalSource {
    let subjects = projection.subjects.map { definition in
      NativeC01InquiryInstitutionalSubject(
        ref: .init(owner: owner, sourceBirth: operation, ordinal: definition.ordinal),
        definitionKey: definition.key, birthOperation: operation, revision: 1,
        availability: .available, unavailabilityOperation: nil)
    }
    let duties = try projection.duties.map { mapping in
      guard let subject = subjects.first(where: { $0.definitionKey == mapping.subjectKey }) else {
        throw NativeC01InquiryOperatorFailure.sourceMismatch
      }
      return NativeC01InquiryStandingDuty(operation: UUID(), revision: 1,
        sourceBirth: operation, sourceRevision: 1, subject: subject.ref,
        role: mapping.role, policy: projection.pins.staffing)
    }
    let source = NativeC01InquiryInstitutionalSource(owner: owner, host: arrival.receipt.station,
      pins: projection.pins, birthOperation: operation, revision: 1, activationArrival: arrival.receipt,
      activationPhysicalTime: commander.flightSimulation.physicalTime,
      subjects: subjects, duties: duties, availability: .available, unavailabilityOperation: nil)
    guard projection.matches(source) else { throw NativeC01InquiryOperatorFailure.invalidHistory }
    return source
  }

  private func c01OperatorUse(
    source: NativeC01InquiryInstitutionalSource, duty: NativeC01InquiryStandingDuty,
    operation: UUID, caseID: UUID, caseRevision: UInt64, arrival: NativeMainStationArrivalContext,
    player: ActorIdentity, carrier: UUID
  ) throws -> NativeC01InquiryAssignmentUse {
    let value = NativeC01InquiryAssignmentUse(operation: operation, caseID: caseID,
      caseRevision: caseRevision, owner: source.owner, sourceBirth: source.birthOperation,
      sourceRevision: source.revision, subject: duty.subject, dutyOperation: duty.operation,
      dutyRevision: duty.revision, role: duty.role, policy: duty.policy, arrival: arrival.receipt,
      carrier: carrier, inventoryRevision: commander.equipmentInventory?.revision ?? 0,
      player: player, physicalTime: commander.flightSimulation.physicalTime,
      historicalEpoch: nativeStationRuntimeEpoch)
    guard value.matches(source) else { throw NativeC01InquiryOperatorFailure.invalidHistory }
    return value
  }

  private func c01OperatorNextRevision(_ previous: UInt64) throws -> UInt64 {
    try NativeC01InquiryOperatorSubjectData.nextRevision(previous)
  }
}

/// Negative DATA transform only. This never proves a host loss, issues a source,
/// or constructs a private proposal/context; the native caller owns those checks.
enum NativeC01InquiryOperatorSubjectData {
  static func recordingHostLoss(
    _ subject: NativeC01InquiryInstitutionalSubject, operation: UUID
  ) throws -> NativeC01InquiryInstitutionalSubject {
    guard subject.shapeValid else { throw NativeC01InquiryOperatorFailure.invalidHistory }
    guard subject.availability == .available else { return subject }
    return .init(ref: subject.ref, definitionKey: subject.definitionKey,
      birthOperation: subject.birthOperation, revision: try nextRevision(subject.revision),
      availability: .unobservedAfterLoss, unavailabilityOperation: operation)
  }

  static func nextRevision(_ previous: UInt64) throws -> UInt64 {
    let (next, overflow) = previous.addingReportingOverflow(1)
    guard !overflow, next > 0, next < UInt64(Int64.max) else {
      throw NativeC01InquiryOperatorFailure.revisionOverflow
    }
    return next
  }
}

/// DATA consistency only. Success is not approval or current operator eligibility.
enum NativeC01InquiryOperatorRetainedFacts {
  static func historyConsistent(
    source: NativeC01InquiryInstitutionalSource,
    assignments: [NativeC01InquiryAssignmentUse], registries: [NativeC01InquiryRegistryRef]
  ) -> Bool {
    guard source.shapeValid, !assignments.isEmpty, let registry = registries.first,
      registry.shapeValid, registry.corpusSHA256 == source.pins.registrySHA256
    else { return false }
    return assignments.allSatisfy { $0.matches(source) }
      && registries.allSatisfy { $0.shapeValid && $0 == registry }
  }
}

/// Read-only full static-source/history join for G1's outer save owner only.
/// This must never be called from shallow engine validity, and issues no live context.
enum NativeC01InquiryOperatorRetainedSource {
  static func validate(_ state: borrowing NativeC01InquiryState) throws -> Bool {
    guard state.shapeValid else { return false }
    let cases = state.priorCases + [state.caseRecord]
    let assignments = cases.flatMap { item in
      [item.mandate.intake] + (item.audit.map { [$0.reviewer] } ?? [])
    }
    guard NativeC01InquiryOperatorRetainedFacts.historyConsistent(
      source: state.institutionalSource, assignments: assignments,
      registries: cases.map { $0.mandate.registry })
    else { return false }
    // Only the actual private owner can supply published Content and the full
    // Registry. DATA equality alone cannot skip either pending approval gate.
    let actual = try NativeC01InquiryOperatorProjection.load()
    guard actual.matches(state.institutionalSource) else { return false }
    return cases.allSatisfy {
      $0.mandate.sourcePins == actual.pins && $0.mandate.registry == actual.registry
    }
  }
}

extension GameRuntime {
  /// Negative source publication after actual host destruction. Every attempt
  /// starts from the latest attained game; failed publication adopts nothing
  /// and cannot rewind the physical loss or issue a writer acknowledgment.
  func commitC01InquiryOperatorHostLoss() {
    guard game.commander.scriptState.savedC01Inquiry != nil else { return }
    do {
      guard let plan = try game.prepareC01InquiryOperatorHostLoss(),
        let publish = scriptPublisher()
      else { return }
      var candidate = game
      try candidate.stageC01InquiryOperatorHostLoss(plan)
      try publish(&candidate)
      game = candidate
    } catch {
      game.notify("INQUIRY HOST LOSS NOT SAVED - PHYSICAL LOSS RETAINED FOR RETRY")
    }
  }
}
