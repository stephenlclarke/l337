import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryDataCodecTests {
  // Synthetic DATA fixtures exercise codecs and links. None is native evidence or approval.
  private let owner = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let operation = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private let nextOperation = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
  private let parkingOperation = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
  private let system = SystemIdentity(galaxy: 0, system: 0)
  private let digest = String(repeating: "1", count: 64)

  @Test func policyLeafRoundTripsData() throws {
    let data = try json(policyObject())
    let value = try JSONDecoder().decode(NativeC01InquiryPolicyRef.self, from: data)
    #expect(value.shapeValid)
    #expect(try JSONDecoder().decode(
      NativeC01InquiryPolicyRef.self, from: JSONEncoder().encode(value)) == value)
  }

  @Test(arguments: ["unknown", "missing", "null", "overlong", "digest", "primitive"])
  func policyLeafRejectsUnknownMissingNullAndInvalidShape(form: String) throws {
    var object = policyObject()
    switch form {
    case "unknown": object["approved"] = true
    case "missing": object.removeValue(forKey: "revision")
    case "null": object["revision"] = NSNull()
    case "overlong": object["identity"] = String(repeating: "x", count: 257)
    case "digest": object["sha256"] = "not-a-digest"
    default: object["identity"] = 1
    }
    let data = try json(object)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01InquiryPolicyRef.self, from: data)
    }
  }

  @Test(arguments: [
    "unknown-kind", "missing-payload", "null-payload", "mixed-payload", "outer-key",
    "nested-key", "nested-null",
  ])
  func taggedResultRejectsUnknownMissingNullMixedAndNestedKeys(form: String) throws {
    let failure: [String: Any] = ["reason": "interrupted", "physicalTime": 0, "nativeOrder": 0]
    let baseline: [String: Any] = ["kind": "failed", "payload": failure]
    // A valid failed DATA result gives every mutation a decodable baseline.
    let retained = try JSONDecoder().decode(NativeC01InquiryTrialResult.self, from: json(baseline))
    if case .failed(let value) = retained { #expect(value.reason == .interrupted) }
    else { Issue.record("Expected failed DATA variant") }
    var object = baseline
    switch form {
    case "unknown-kind": object["kind"] = "ready"
    case "missing-payload": object.removeValue(forKey: "payload")
    case "null-payload": object["payload"] = NSNull()
    case "mixed-payload": object["kind"] = "passed"
    case "outer-key": object["approved"] = true
    case "nested-key":
      var payload = failure
      payload["approved"] = true
      object["payload"] = payload
    default:
      var payload = failure
      payload["reason"] = NSNull()
      object["payload"] = payload
    }
    let data = try json(object)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01InquiryTrialResult.self, from: data)
    }
  }

  @Test func optionalHeaderNullIsNotAbsence() throws {
    var object: [String: Any] = [
      "instanceID": owner.uuidString, "definition": "data-only", "version": "data-v1",
      "digest": digest, "revision": 1, "outcome": "active",
    ]
    let absent = try JSONDecoder().decode(NativeC01InquiryOriginalHeaderRef.self, from: json(object))
    #expect(absent.permissionOperation == nil)
    object["permissionOperation"] = NSNull()
    let data = try json(object)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01InquiryOriginalHeaderRef.self, from: data)
    }
  }

  @Test(arguments: ["missing-life", "extra-ledger"])
  func sameRootLifecycleFieldIsRequiredAndClosed(form: String) throws {
    // Sentinel leaves are intentionally invalid. This check must stop at the root key gate.
    var object: [String: Any] = [
      "owner": owner.uuidString, "nextCaseOrdinal": 1, "institutionalSource": [:] as [String: Any],
      "caseRecord": [:] as [String: Any], "priorCases": [], "fixtureLifecycle": [],
    ]
    if form == "missing-life" { object.removeValue(forKey: "fixtureLifecycle") }
    else { object["worldLedger"] = [] as [Any] }
    let data = try json(object)
    var rejectedAtKeys = false
    do {
      _ = try JSONDecoder().decode(NativeC01InquiryState.self, from: data)
    } catch DecodingError.dataCorrupted(let context) {
      rejectedAtKeys = context.debugDescription == "Invalid inquiry object keys"
    } catch {
      Issue.record("Root key mutation reached a leaf decoder")
    }
    #expect(rejectedAtKeys)
    // These mutations pass lexical validation and reach the closed DTO key check.
    try ScriptSaveJSONPreflight.validateInquiryData(data)
    #expect(throws: SaveError.invalidCommander) {
      try NativeC01InquirySave.decodeData(data)
    }
    let missions = try json(["savedC01Inquiry": object])
    for schema in [NativeC01InquirySave.version, NativeC01InquirySave.alienVersion] {
      #expect(throws: SaveError.invalidCommander) {
        try NativeC01InquirySave.validateFields(missions, location: .missions, schema: schema)
      }
    }
    // Mixed trade and watcher envelopes extract inquiry DATA before the same admission boundary.
    let inquiryData = try ScriptSaveJSONPreflight.extractInquiryData(
      missions, location: .missions, permitsRoot: true)
    let extracted = try #require(inquiryData)
    #expect(extracted == data)
    #expect(throws: SaveError.invalidCommander) {
      try NativeC01InquirySave.decodeData(extracted)
    }
  }

  @Test func acceptedStepDataRejectsInconsistentClockLabels() throws {
    let data = step(end: 0.1, usedD: 0.1)
    #expect(data.shapeValid)  // DATA relation only; no sealed accepted step is issued.
    #expect(!step(end: 0.2, usedD: 0.1).shapeValid)
    #expect(!step(end: 0.1, usedD: 0).shapeValid)
    #expect(!step(end: 0.2, usedD: 0.2).shapeValid)
    #expect(throws: (any Error).self) {
      try JSONEncoder().encode(step(end: 0.2, usedD: 0.1))
    }
  }

  @Test func uncreatedOriginalCannotCarryLossAndCapacityIsBounded() {
    let loss = NativeC01InquiryOriginalLossRef.clockMarker(.init(
      ordinal: 0, generation: 0, markerActor: owner, physicalTime: 0))
    let empty = NativeC01InquiryOriginalObservation(
      operation: operation, physicalTime: 0, basis: .notCreated, losses: [])
    #expect(empty.shapeValid)
    #expect(!NativeC01InquiryOriginalObservation(
      operation: operation, physicalTime: 0, basis: .notCreated, losses: [loss]).shapeValid)
    let header = NativeC01InquiryOriginalHeaderRef(instanceID: owner,
      definition: "data-only", version: "data-v1", digest: digest, revision: 1,
      outcome: .active, permissionOperation: nil)
    #expect(NativeC01InquiryOriginalObservation(
      operation: operation, physicalTime: 0, basis: .retained(header), losses: [loss]).shapeValid)
    #expect(!NativeC01InquiryOriginalObservation(
      operation: operation, physicalTime: 0, basis: .retained(header),
      losses: Array(repeating: loss, count: 16385)).shapeValid)
  }

  @Test func historicalPoseDoesNotNeedToEqualCurrentLifePose() {
    let snapshot = generation()
    let retained = snapshot
    let current = life(snapshot: snapshot, rebind: false, keepHistory: true, retired: false)
    #expect(!snapshot.shapeValid)  // Ambient source and unproven dock resource cannot admit a fixture.
    #expect(current.fixture.matches(snapshot))
    #expect(current.support.pose != snapshot.support.pose)
    #expect(current.support.energy != snapshot.support.energy)
    #expect(current.matchesBirthChains(snapshot))
    #expect(snapshot == retained)
    #expect(snapshot.retirement == nil && current.retirement == nil)
  }

  @Test func rebindChainsAndRetirementDataRemainDistinct() {
    let snapshot = generation()
    let retained = snapshot
    let rebound = life(snapshot: snapshot, rebind: true, keepHistory: true, retired: true)
    let missingHistory = life(snapshot: snapshot, rebind: true, keepHistory: false, retired: true)
    #expect(!snapshot.shapeValid)
    #expect(rebound.matchesBirthChains(snapshot))  // Necessary DATA chain relation, no native grant.
    #expect(!missingHistory.matchesBirthChains(snapshot))
    #expect(rebound.support.binding != snapshot.support.binding)
    #expect(rebound.support.bindingHistory.first?.departure.binding == snapshot.support.birthBinding)
    #expect(snapshot == retained && snapshot.retirement == nil)
    let retirement = rebound.retirement
    if let retirement, case .caseClosed(let closedOperation) = retirement.cause {
      #expect(closedOperation == nextOperation)
    } else { Issue.record("Expected separate case-close DATA retirement") }
    let wrongRef = NativeC01InquiryFixtureRef(
      fixtureID: snapshot.fixtureID, generation: 2, admissionOperation: snapshot.admissionOperation,
      geometryRevision: snapshot.geometryRevision, geometryPins: snapshot.geometryPins,
      metricRevision: snapshot.metricRevision, lawRevision: snapshot.lawRevision)
    #expect(!wrongRef.matches(snapshot))
  }

  private func policyObject() -> [String: Any] {
    ["identity": "data-only", "revision": "data-v1", "sha256": digest]
  }

  private func json(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  }

  private func step(end: Double, usedD: Double) -> NativeC01InquiryStepData {
    .init(ownerSession: owner, sequence: 0, sceneEpoch: operation,
      player: .init(system: system, visit: 1, entity: 0), caseID: owner, caseRevision: 1,
      fixtureID: operation, generation: 1, clockStart: 0, clockEnd: end, usedD: usedD)
  }

  // Deliberately incomplete DTOs: no catalogue, content, geometry digest, native body or source factory.
  private func binding(_ member: UInt16, rebound: Bool) -> NativeC01InquiryFixtureBinding {
    .init(actor: .init(system: system, visit: rebound ? 2 : 1, entity: UInt64(member) + 2),
      spawn: .init(system: system, visit: rebound ? 2 : 1, sequence: rebound ? 2 : 1,
        member: member, producer: .ambient), bodyID: Int(member) + (rebound ? 5 : 1),
      revision: rebound ? 2 : 1, operation: rebound ? nextOperation : operation)
  }

  private func model() -> NativeC01InquiryModelSnapshot {
    let oscillator = NativeC01InquiryOscillatorData(phase: .zero, cycle: 0, pulseSequence: 0)
    let head = NativeC01InquiryHeadModelData(
      reference: oscillator, output: oscillator, appliedDetent: .zero, appliedControlRevision: 1)
    return .init(physicalTime: 0, lastStep: nil, head0: head, head1: head, head2: head)
  }

  private func generation() -> NativeC01InquiryFixtureGeneration {
    func part(_ kind: NativeC01InquiryFixtureGeometry.Part, member: UInt16)
      -> NativeC01InquiryFixturePartState
    {
      let id = binding(member, rebound: false)
      let pose = ShipPose(position: .init(0, 0, 0), orientation: .init())
      return .init(part: kind, birthBinding: id, binding: id, birthPose: pose, pose: pose,
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 1,
        physicalTime: 0, presence: .present)
    }
    let station = NativeMainStationIdentity(world: owner, system: system, resource: owner)
    return .init(owner: owner, caseID: owner, caseOrdinal: 0, sourceBirth: owner, sourceRevision: 1,
      fixtureID: operation, generation: 1, revision: 1, admissionOperation: operation,
      admissionArrival: .init(station: station,
        actor: .init(system: system, visit: 1, entity: 1), commanderOwner: owner,
        sequence: 1, calendarSeconds: 0), admissionPhysicalTime: 0,
      inertialFrame: .init(position: .init(0, 0, 0), orientation: .init()), placementCandidate: 0,
      geometryRevision: NativeC01InquiryFixtureGeometry.revision,
      geometryPins: .init(support: digest, head0: digest, head1: digest, head2: digest),
      metricRevision: NativeC01InquiryFixtureGeometry.metricRevision, metresPerWorldUnit: 1,
      lawRevision: NativeC01InquiryHeadModelData.lawRevision,
      support: part(.support, member: 0), head0: part(.head0, member: 1),
      head1: part(.head1, member: 2), head2: part(.head2, member: 3), retirement: nil,
      modelSnapshot: model())
  }

  private func life(
    snapshot: NativeC01InquiryFixtureGeneration, rebind: Bool, keepHistory: Bool, retired: Bool
  ) -> NativeC01InquiryFixtureLife {
    func part(_ historical: NativeC01InquiryFixturePartState) -> NativeC01InquiryPartLife {
      let current = binding(historical.binding.spawn.member, rebound: rebind)
      let departure = NativeC01InquiryFixtureTransition(
        operation: parkingOperation, binding: historical.binding, physicalTime: 0,
        historicalEpoch: owner)
      let history: [NativeC01InquiryRebinding] = rebind && keepHistory ? [
        .init(operation: nextOperation, departure: departure, binding: current,
          physicalTime: 0, historicalEpoch: nextOperation)
      ] : []
      return .init(binding: current, pose: .init(position: .init(1, 0, 0), orientation: .init()),
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 0.5,
        physicalTime: 0, presence: .present, bindingHistory: history)
    }
    let ref = NativeC01InquiryFixtureRef(fixtureID: snapshot.fixtureID,
      generation: snapshot.generation, admissionOperation: snapshot.admissionOperation,
      geometryRevision: snapshot.geometryRevision, geometryPins: snapshot.geometryPins,
      metricRevision: snapshot.metricRevision, lawRevision: snapshot.lawRevision)
    return .init(caseID: snapshot.caseID, fixture: ref, revision: rebind ? 2 : 1,
      support: part(snapshot.support), head0: part(snapshot.head0), head1: part(snapshot.head1),
      head2: part(snapshot.head2), modelSnapshot: model(),
      retirement: retired ? .init(operation: nextOperation, revision: 2, physicalTime: 0,
        cause: .caseClosed(operation: nextOperation)) : nil)
  }
}

extension NativeC01InquiryDataCodecTests {
  @Test func inventoryRevisionUsesZeroBasedHistoricalRange() {
    // This factor is used by both measurement and final DATA, never a native issuer.
    #expect(NativeC01InquiryDataShape.inventoryRevision(0))
    #expect(NativeC01InquiryDataShape.inventoryRevision(UInt64(Int64.max) - 1))
    #expect(!NativeC01InquiryDataShape.inventoryRevision(UInt64(Int64.max)))
    #expect(!NativeC01InquiryDataShape.inventoryRevision(UInt64.max))
  }
}

extension NativeC01InquiryDataCodecTests {
  @Test(arguments: [
    "owner", "case", "source", "future-command", "future-application", "future-trial", "measurements",
  ])
  func benchHistoryMustJoinContainingCase(form: String) {
    let baseline = benchData(form: "baseline", record: 0)
    #expect(baseline.shapeValid)  // Internal DATA links only; synthetic generation is not admitted.
    #expect(!generation().shapeValid)
    #expect(baseline.matchesContainingCase(owner: owner, caseID: owner, sourceBirth: owner,
      maximumRevision: 3, measurements: measurementRefs()))
    if ["owner", "case", "source"].contains(form) {
      // An internally coherent bench still cannot be attached to a foreign containing case.
      #expect(!baseline.matchesContainingCase(
        owner: form == "owner" ? parkingOperation : owner,
        caseID: form == "case" ? parkingOperation : owner,
        sourceBirth: form == "source" ? parkingOperation : owner,
        maximumRevision: 3, measurements: measurementRefs()))
    }
    let indices = ["owner", "case", "source"].contains(form) ? [0, 1, 2] : [0]
    for record in indices {
      let foreign = benchData(form: form, record: record)
      #expect(!foreign.matchesContainingCase(owner: owner, caseID: owner, sourceBirth: owner,
        maximumRevision: 3, measurements: measurementRefs()))
    }
  }

  private func measurementRefs() -> NativeC01InquiryMeasurementRefs {
    .init(channel0: owner, channel1: operation, channel2: nextOperation)
  }

  private func benchData(form: String, record: Int) -> NativeC01InquiryBench {
    let snapshot = generation()
    let ref = NativeC01InquiryFixtureRef(fixtureID: snapshot.fixtureID,
      generation: snapshot.generation, admissionOperation: snapshot.admissionOperation,
      geometryRevision: snapshot.geometryRevision, geometryPins: snapshot.geometryPins,
      metricRevision: snapshot.metricRevision, lawRevision: snapshot.lawRevision)
    let instrument = NativeC01InquiryInstrumentBinding(owner: owner,
      player: .init(system: system, visit: 1, entity: 0), carrier: owner,
      hullID: "data-only", hullGeometrySHA256: digest, sourceBirth: owner, caseID: owner,
      fixture: ref, instrumentRevision: "data-only")
    let zero = NativeC01InquiryControlSetting(detent: .zero, revision: 1)
    let one = NativeC01InquiryControlSetting(detent: .one, revision: 2)
    let before = NativeC01InquiryControlConfiguration(revision: 1, head0: zero, head1: zero, head2: zero)
    let requested = NativeC01InquiryControlConfiguration(revision: 2, head0: one, head1: zero, head2: zero)
    func identity(_ field: String, record index: Int) -> UUID {
      form == field && record == index ? parkingOperation : owner
    }
    let commandRevision: UInt64 = form == "future-command" ? 4 : 2
    let applicationRevision: UInt64 = form == "future-application" ? 4 : 2
    let trialRevision: UInt64 = form == "future-trial" ? 4 : 2
    let set = NativeC01InquiryCommand(id: operation, sequence: 0, kind: .setDetent,
      owner: identity("owner", record: 0), ownerSession: owner,
      caseID: identity("case", record: 0), priorCaseRevision: commandRevision - 1,
      caseRevision: commandRevision, sourceBirth: identity("source", record: 0),
      challengeID: owner, challengeOrdinal: 0, trialID: owner, fixture: ref, instrument: instrument,
      historicalReviewNonce: operation, historicalEpoch: owner, requested: requested,
      appliedBefore: before, nativeOrder: 0, physicalTime: 0)
    let arm = NativeC01InquiryCommand(id: nextOperation, sequence: 1, kind: .requestTrial,
      owner: owner, ownerSession: owner, caseID: owner, priorCaseRevision: 1, caseRevision: 2,
      sourceBirth: owner, challengeID: owner, challengeOrdinal: 0, trialID: owner,
      fixture: ref, instrument: instrument, historicalReviewNonce: nextOperation,
      historicalEpoch: owner, requested: requested, appliedBefore: requested,
      nativeOrder: 1, physicalTime: 0)
    let application = NativeC01InquiryControlApplication(operation: nextOperation,
      owner: identity("owner", record: 1), caseID: identity("case", record: 1),
      caseRevision: applicationRevision, sourceBirth: identity("source", record: 1),
      commandID: operation, commandSequence: 0, challengeID: owner, challengeOrdinal: 0,
      fixture: ref, instrument: instrument,
      boundary: .betweenSteps(.init(ownerSession: owner, historicalEpoch: owner,
        physicalTime: 0, nativeOrder: 1)), before: zero, after: one)
    func channel(_ ordinal: Int, challenge: UUID) -> NativeC01InquiryChannelTrace {
      .init(challengeID: challenge, challengeOrdinal: ordinal, fixture: ref,
        applied: ordinal == 0 ? one : zero, run: nil, referenceEvents: [], cycles: [],
        openOutputWindow: nil)
    }
    let refs = form == "measurements"
      ? NativeC01InquiryMeasurementRefs(channel0: operation, channel1: owner, channel2: nextOperation)
      : measurementRefs()
    let trial = NativeC01InquiryTrial(operation: parkingOperation,
      owner: identity("owner", record: 2), caseID: identity("case", record: 2),
      caseRevision: trialRevision, sourceBirth: identity("source", record: 2), trialID: owner,
      armCommandID: nextOperation, measurements: refs, requested: requested,
      instrument: instrument, historicalEpoch: owner,
      channel0: channel(0, challenge: owner), channel1: channel(1, challenge: operation),
      channel2: channel(2, challenge: nextOperation),
      result: .failed(.init(reason: .interrupted, physicalTime: 0, nativeOrder: 2)))
    return .init(commands: [set, arm], applications: [application], trials: [trial],
      passingTrialOperation: nil)
  }
}

extension NativeC01InquiryDataCodecTests {
  @Test(arguments: ["owner", "source"])
  func auditOwnerAndSourceMustJoinContainingCase(form: String) {
    let source = historicalInstitutionalSource()
    let reviewer = historicalReviewer(source: source, form: "baseline")
    func audit(_ auditOwner: UUID, sourceBirth: UUID) -> NativeC01InquiryAudit {
      .init(operation: nextOperation, owner: auditOwner, caseID: owner, caseRevision: 1,
        sourceBirth: sourceBirth, reviewer: reviewer, intakeOperation: owner,
        measurements: measurementRefs(), benchTrialOperation: parkingOperation,
        correspondences: [], originalObservationOperation: nextOperation)
    }
    let baseline = audit(owner, sourceBirth: operation)
    #expect(!baseline.shapeValid)  // No correspondences, approved audit or receiving factory.
    #expect(baseline.matchesContainingCase(owner: owner, sourceBirth: operation))
    let foreign = audit(form == "owner" ? parkingOperation : owner,
      sourceBirth: form == "source" ? parkingOperation : operation)
    #expect(!foreign.matchesContainingCase(owner: owner, sourceBirth: operation))
  }

  @Test(arguments: ["duty", "subject", "policy", "role"])
  func auditReviewerRequiresHistoricalDutyButNotCurrentAvailability(form: String) {
    let source = historicalInstitutionalSource()
    let baseline = historicalReviewer(source: source, form: "baseline")
    #expect(source.shapeValid && baseline.shapeValid)
    #expect(source.availability == .unavailable)
    #expect(source.subjects.allSatisfy { $0.availability == .unavailable })
    #expect(baseline.sourceRevision < source.revision)
    #expect(baseline.dutyRevision < source.duties[1].revision)
    #expect(baseline.matches(source))  // Historical DATA correspondence, never current desk authority.
    let foreign = historicalReviewer(source: source, form: form)
    #expect(foreign.shapeValid)
    #expect(!foreign.matches(source))
  }

  private func historicalInstitutionalSource() -> NativeC01InquiryInstitutionalSource {
    let policy = NativeC01InquiryPolicyRef(identity: "data-only-policy", revision: "data-v1", sha256: digest)
    let host = NativeMainStationIdentity(world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:0"))
    let arrival = NativeMainStationDockReceipt(station: host,
      actor: .init(system: system, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    let pins = NativeC01InquirySourcePins(sourceID: "l337.glass-meridian", clueID: "meridian-offset",
      clueReceipt: "l337.unwritten-route/clue/meridian-offset", definition: policy,
      staffing: policy, archiveRoles: policy, originalDefinitionSHA256: digest,
      archiveContentSHA256: digest, calibrationContentSHA256: digest, registrySHA256: digest)
    let intake = NativeC01InquirySubjectRef(owner: owner, sourceBirth: operation, ordinal: 0)
    let reviewer = NativeC01InquirySubjectRef(owner: owner, sourceBirth: operation, ordinal: 1)
    // Synthetic DATA and an unavailable source; no private Content or Registry output is created.
    return .init(owner: owner, host: host, pins: pins, birthOperation: operation, revision: 3,
      activationArrival: arrival, activationPhysicalTime: 0,
      subjects: [
        .init(ref: intake, definitionKey: "data-intake", birthOperation: operation,
          revision: 2, availability: .unavailable, unavailabilityOperation: parkingOperation),
        .init(ref: reviewer, definitionKey: "data-reviewer", birthOperation: operation,
          revision: 2, availability: .unavailable, unavailabilityOperation: parkingOperation),
      ], duties: [
        .init(operation: owner, revision: 2, sourceBirth: operation, sourceRevision: 1,
          subject: intake, role: .intake, policy: policy),
        .init(operation: nextOperation, revision: 2, sourceBirth: operation, sourceRevision: 1,
          subject: reviewer, role: .independentReview, policy: policy),
      ], availability: .unavailable, unavailabilityOperation: parkingOperation)
  }

  private func historicalReviewer(
    source: NativeC01InquiryInstitutionalSource, form: String
  ) -> NativeC01InquiryAssignmentUse {
    .init(operation: nextOperation, caseID: owner, caseRevision: 1, owner: owner,
      sourceBirth: operation, sourceRevision: 1,
      subject: .init(owner: owner, sourceBirth: operation, ordinal: form == "subject" ? 0 : 1),
      dutyOperation: form == "duty" ? parkingOperation : nextOperation, dutyRevision: 1,
      role: form == "role" ? .intake : .independentReview,
      policy: form == "policy"
        ? .init(identity: "foreign-data-policy", revision: "data-v1", sha256: digest)
        : source.pins.staffing,
      arrival: source.activationArrival, carrier: owner, inventoryRevision: 0,
      player: .init(system: system, visit: 1, entity: 0), physicalTime: 0, historicalEpoch: owner)
  }
}
