import Foundation

enum NativeC01InquiryIntakeFailure: Error, Sendable {
  case unavailable, sourceMismatch, staleRequest, invalidOriginalHistory, capacity, missingRetirement
}

/// A prepared explicit request, never a decoded mandate, writer receipt or live arm.
final class NativeC01InquiryCaseRequest: Sendable {
  let caseRecord: NativeC01InquiryCase
  fileprivate let intake: NativeC01InquiryOperatorIntakePlan
  fileprivate init(caseRecord: NativeC01InquiryCase, intake: NativeC01InquiryOperatorIntakePlan) {
    self.caseRecord = caseRecord
    self.intake = intake
  }
}

extension GameRuntime {
  /// The protected inquiry command owner must confirm/stage this exact request.
  /// Preparing it does not publish its source, subjects, case, or any clue.
  func prepareC01InquiryCaseRequest() throws -> NativeC01InquiryCaseRequest {
    let intake = try game.prepareC01InquiryOperatorIntake()
    return try game.c01PreparedCaseRequest(intake)
  }
}

extension Game {
  /// Invoke inside G1's existing protected whole-candidate command publication.
  /// A successful staging return is not publication success or an acknowledgment.
  mutating func stageC01InquiryCaseRequest(_ request: NativeC01InquiryCaseRequest) throws {
    guard c01InquiryOperatorIntakeIsCurrent(request.intake),
      request.caseRecord.shapeValid,
      request.caseRecord.id == request.intake.caseID,
      request.caseRecord.ordinal == request.intake.caseOrdinal,
      request.caseRecord.mandate.intake == request.intake.intake,
      request.caseRecord.originalOutcomeReferences.request
        == (try c01OriginalObservation(operation: request.intake.intake.operation))
    else { throw NativeC01InquiryIntakeFailure.staleRequest }
    let next = request.caseRecord.ordinal.addingReportingOverflow(1)
    guard !next.overflow, next.partialValue < UInt64.max else {
      throw NativeC01InquiryIntakeFailure.capacity
    }
    let candidate: NativeC01InquiryState
    if let before = commander.scriptState.savedC01Inquiry {
      guard before.shapeValid, before.caseRecord.phase == .closeInquiry,
        let final = before.caseRecord.finalReceipt,
        before.nextCaseOrdinal == request.caseRecord.ordinal,
        before.institutionalSource == request.intake.source
      else { throw NativeC01InquiryIntakeFailure.staleRequest }
      // Closing owns logical retirement. Starting a case never removes, repairs,
      // retires or recreates a physical fixture on behalf of a missing issuer.
      for life in before.fixtureLifecycle where life.caseID == before.caseRecord.id {
        guard let retirement = life.retirement else {
          throw NativeC01InquiryIntakeFailure.missingRetirement
        }
        if case .caseClosed(let operation) = retirement.cause,
          operation != final.operation
        { throw NativeC01InquiryIntakeFailure.missingRetirement }
      }
      guard before.priorCases.count < 16384 else { throw NativeC01InquiryIntakeFailure.capacity }
      candidate = .init(owner: before.owner, nextCaseOrdinal: next.partialValue,
        institutionalSource: before.institutionalSource, caseRecord: request.caseRecord,
        priorCases: before.priorCases + [before.caseRecord], fixtureLifecycle: before.fixtureLifecycle)
    } else {
      guard request.caseRecord.ordinal == 0, request.intake.beforeSource == nil,
        !bodies.contains(where: { $0.physical?.spawnIdentity?.producer.rawValue == "c01Inquiry" })
      else { throw NativeC01InquiryIntakeFailure.staleRequest }
      candidate = .init(owner: request.intake.source.owner, nextCaseOrdinal: next.partialValue,
        institutionalSource: request.intake.source, caseRecord: request.caseRecord,
        priorCases: [], fixtureLifecycle: [])
    }
    guard candidate.shapeValid else { throw NativeC01InquiryIntakeFailure.sourceMismatch }
    // Only the ONE inquiry root changes. Original missions, clues, money,
    // property, standing subjects and existing world bodies are not settled here.
    commander.scriptState.savedC01Inquiry = candidate
  }

  fileprivate func c01PreparedCaseRequest(
    _ intake: NativeC01InquiryOperatorIntakePlan
  ) throws -> NativeC01InquiryCaseRequest {
    guard c01InquiryOperatorIntakeIsCurrent(intake) else {
      throw NativeC01InquiryIntakeFailure.staleRequest
    }
    let content = try NativeC01CharterArchiveApproval.load()
    let registry = try NativeCharterArchiveRegistryApproval.load()
    let sourceID = intake.source.pins.sourceID
    guard content.archive.publication == .publishedSource,
      content.calibration.publication == .publishedSource,
      let group = content.archive.sourceGroups[sourceID],
      let calibration = content.calibration.profiles[sourceID],
      let source = registry.source(for: sourceID),
      source.clueID == intake.source.pins.clueID, source.receiptID == intake.source.pins.clueReceipt,
      source.archiveSHA256 == content.archiveSHA256,
      source.calibrationSHA256 == content.calibrationSHA256,
      source.archiveSHA256 == intake.source.pins.archiveContentSHA256,
      source.calibrationSHA256 == intake.source.pins.calibrationContentSHA256,
      registry.provenance.corpusSHA256 == intake.source.pins.registrySHA256,
      group.sourceBinding.recoveryProfileSelector.jsonPointer == "/profiles/" + sourceID,
      group.challengeArchiveRoles.count == 3, source.observations.count == 3,
      calibration.continuityCalibration.parameters.phaseOffsetsDegrees.count == 3
    else { throw NativeC01InquiryIntakeFailure.sourceMismatch }
    let provenance = registry.provenance
    let registryRef = NativeC01InquiryRegistryRef(sourceSetCommit: provenance.sourceSetCommit,
      sourceSetPath: provenance.sourceSetPath, sourceSetSHA256: provenance.sourceSetSHA256,
      corpusSchema: provenance.corpusSchema, corpusRevision: provenance.corpusRevision,
      corpusSHA256: provenance.corpusSHA256)
    guard registryRef == intake.registry else { throw NativeC01InquiryIntakeFailure.sourceMismatch }
    let recovery = group.sourceBinding.recoveryProfileSelector
    let profile = NativeC01InquiryProfileRef(selector: recovery.jsonPointer,
      schema: content.calibration.schema, commit: recovery.commit,
      path: recovery.path, sha256: recovery.sha256)
    var challenges: [NativeC01InquiryChallenge] = []
    for (ordinal, role) in group.challengeArchiveRoles.enumerated() {
      let observation = source.observations[ordinal]
      guard role.sourceID == sourceID, role.challengeOrdinal == ordinal,
        role.recordID == observation.recordID, role.replicaID == observation.replicaID,
        role.origin.identity == observation.originIdentity,
        role.origin.domain == observation.originDomain,
        role.recordPayloadSHA256 == observation.payloadSHA256,
        role.modelInput.resourceSHA256 == content.calibrationSHA256,
        role.modelInput.profileSchema == content.calibration.schema,
        role.modelInput.offsetDegrees
          == calibration.continuityCalibration.parameters.phaseOffsetsDegrees[ordinal]
      else { throw NativeC01InquiryIntakeFailure.sourceMismatch }
      challenges.append(.init(id: UUID(), caseID: intake.caseID, sourceID: sourceID,
        ordinal: ordinal, contentRevision: role.contentRevision,
        archive: .init(recordID: role.recordID, replicaID: role.replicaID,
          originIdentity: role.origin.identity, originDomain: role.origin.domain,
          payloadSHA256: role.recordPayloadSHA256),
        modelInput: .init(resourcePath: role.modelInput.resourcePath,
          resourceSHA256: role.modelInput.resourceSHA256,
          profileSchema: role.modelInput.profileSchema, jsonPointer: role.modelInput.jsonPointer,
          offsetDegrees: role.modelInput.offsetDegrees)))
    }
    let original = try c01OriginalObservation(operation: intake.intake.operation)
    let mandate = NativeC01InquiryMandate(operation: intake.intake.operation,
      caseID: intake.caseID, caseRevision: 1, sourcePins: intake.source.pins,
      profile: profile, registry: registryRef, intake: intake.intake,
      challenge0: challenges[0], challenge1: challenges[1], challenge2: challenges[2],
      originalObservationOperation: original.operation)
    let record = NativeC01InquiryCase(id: intake.caseID, ordinal: intake.caseOrdinal,
      revision: 1, phase: .requestCase, mandate: mandate, fixtureGenerations: [], measurements: [],
      bench: .init(commands: [], applications: [], trials: [], passingTrialOperation: nil),
      audit: nil, finalReceipt: nil,
      originalOutcomeReferences: .init(request: original, audit: nil, close: nil))
    guard record.shapeValid else { throw NativeC01InquiryIntakeFailure.sourceMismatch }
    return .init(caseRecord: record, intake: intake)
  }

  /// Actual original-owner references at this request boundary. This neither
  /// requires original success nor changes the original mission or its rewards.
  private func c01OriginalObservation(operation: UUID) throws -> NativeC01InquiryOriginalObservation {
    let time = commander.flightSimulation.physicalTime
    guard time.isFinite, time >= 0, time <= 1e12,
      NativeGlassMeridianSave.validateClaims(commander)
    else { throw NativeC01InquiryIntakeFailure.invalidOriginalHistory }
    let originals = commander.scriptState.instances.values.filter {
      $0.definition == NativeGlassMeridian.stateID || $0.digest == NativeGlassMeridian.digest
        || $0.savedGlassMeridian != nil
    }
    guard originals.count <= 1 else { throw NativeC01InquiryIntakeFailure.invalidOriginalHistory }
    guard let mission = originals.first else {
      return .init(operation: operation, physicalTime: time, basis: .notCreated, losses: [])
    }
    guard mission.definition == NativeGlassMeridian.stateID,
      mission.version == NativeGlassMeridian.version, mission.digest == NativeGlassMeridian.digest,
      let state = mission.savedGlassMeridian
    else { throw NativeC01InquiryIntakeFailure.invalidOriginalHistory }
    let header = NativeC01InquiryOriginalHeaderRef(instanceID: mission.id,
      definition: mission.definition, version: mission.version, digest: mission.digest,
      revision: mission.revision, outcome: mission.outcome,
      permissionOperation: state.permission.operation)
    var losses: [NativeC01InquiryOriginalLossRef] = []
    var seen = Set<String>()
    func append(_ loss: NativeC01InquiryOriginalLossRef, key: String, at lossTime: Double? = nil) throws {
      guard loss.shapeValid, seen.insert(key).inserted,
        lossTime.map({ $0.isFinite && $0 >= 0 && $0 <= time }) ?? true
      else { throw NativeC01InquiryIntakeFailure.invalidOriginalHistory }
      losses.append(loss)
    }
    for loss in state.losses {
      try append(.clockMarker(.init(ordinal: loss.ordinal, generation: loss.generation,
        markerActor: loss.marker.identity, physicalTime: loss.physicalTime)),
        key: "marker:" + loss.marker.identity.uuidString, at: loss.physicalTime)
    }
    if let loss = state.surveyor?.loss {
      try append(.surveyor(.init(kind: loss.kind, collector: loss.collector, carrier: loss.carrier,
        markerActor: loss.marker?.identity, physicalTime: loss.physicalTime)),
        key: "surveyor", at: loss.physicalTime)
    }
    if let loss = state.timingStandard?.loss {
      try append(.timingStandard(.init(kind: loss.kind, collector: loss.collector, carrier: loss.carrier,
        actor: loss.actor?.identity, physicalTime: loss.physicalTime)),
        key: "timing-standard", at: loss.physicalTime)
    }
    if let clinic = state.clinicEscort {
      let retained = clinic.parkedLosses + clinic.launches.compactMap(\.loss)
      for loss in retained.sorted(by: { $0.operation.uuidString < $1.operation.uuidString }) {
        try append(.clinicHull(.init(ordinal: loss.ordinal, launch: loss.launch,
          operation: loss.operation, sourceDisposition: loss.sourceDisposition,
          actor: loss.actor.identity, physicalTime: loss.physicalTime)),
          key: "clinic:" + loss.operation.uuidString, at: loss.physicalTime)
      }
    }
    for key in mission.ownedEncounters.keys.sorted() {
      guard let encounter = mission.ownedEncounters[key] else {
        throw NativeC01InquiryIntakeFailure.invalidOriginalHistory
      }
      for actor in encounter.actors.values.sorted(by: { $0.identity.uuidString < $1.identity.uuidString })
      where actor.presence == .destroyed {
        try append(.originalActor(.init(encounterID: key, actor: actor.identity, presence: .destroyed)),
          key: "actor:" + actor.identity.uuidString)
      }
    }
    let observed = NativeC01InquiryOriginalObservation(
      operation: operation, physicalTime: time, basis: .retained(header), losses: losses)
    guard observed.shapeValid else { throw NativeC01InquiryIntakeFailure.invalidOriginalHistory }
    return observed
  }
}

/// Presented request data, not a native grant or writer receipt. Only this file
/// can pair a review with the existing factory's immutable private request.
struct NativeC01InquiryRequestReview: Sendable {
  fileprivate let request: NativeC01InquiryCaseRequest?
  let issues: [String]
  var allowed: Bool { request != nil && issues.isEmpty }
  var caseID: UUID? { request?.caseRecord.id }
  var presentedIntake: NativeC01InquiryAssignmentUse? { request?.caseRecord.mandate.intake }
}

extension Game {
  func c01InquiryRequestReview() -> NativeC01InquiryRequestReview {
    guard scriptDurabilityAvailable else {
      return .init(request: nil, issues: ["Choose a commander save destination first."])
    }
    do {
      let intake = try prepareC01InquiryOperatorIntake()
      let request = try c01PreparedCaseRequest(intake)
      return .init(request: request, issues: [])
    } catch NativeC01InquiryOperatorFailure.unfinishedCase {
      return .init(request: nil,
        issues: ["Continue the current inquiry before requesting another case."])
    } catch {
      return .init(request: nil, issues: ["The charter evidence desk is unavailable here."])
    }
  }

  /// Called only by the existing board's Confirm branch. The command owner
  /// publishes or rolls back the whole candidate, as for its other native rows.
  mutating func confirmC01InquiryRequest(_ review: NativeC01InquiryRequestReview) throws {
    guard scriptDurabilityAvailable, review.allowed, let request = review.request else {
      throw NativeC01InquiryIntakeFailure.unavailable
    }
    // Recheck actual source/arrival, case/revision, original observation and
    // retained history through the original stage function, not UI allowed.
    try stageC01InquiryCaseRequest(request)
  }
}
