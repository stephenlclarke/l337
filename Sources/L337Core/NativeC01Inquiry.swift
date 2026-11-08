import Foundation

// Retained source data only. The ONE inquiry root, closed raw codec and full
// world/content joins belong to the current-save owner. None of these values is live authority.
enum NativeC01InquiryDutyRole: String, Codable, Sendable, Hashable, CaseIterable {
  case intake
  case independentReview = "independent-review"
}

struct NativeC01InquiryPolicyRef: Codable, Sendable, Equatable {
  let identity: String
  let revision: String
  let sha256: String
  var shapeValid: Bool {
    !identity.isEmpty && identity.utf8.count <= 256
      && !revision.isEmpty && revision.utf8.count <= 256
      && ScriptCompletionReceipt.validDigest(sha256)
  }
}

struct NativeC01InquirySourcePins: Codable, Sendable, Equatable {
  let sourceID: String
  let clueID: String
  let clueReceipt: String
  let definition: NativeC01InquiryPolicyRef
  let staffing: NativeC01InquiryPolicyRef
  let archiveRoles: NativeC01InquiryPolicyRef
  let originalDefinitionSHA256: String
  let archiveContentSHA256: String
  let calibrationContentSHA256: String
  let registrySHA256: String

  var shapeValid: Bool {
    sourceID == "l337.glass-meridian" && clueID == "meridian-offset"
      && clueReceipt == "l337.unwritten-route/clue/meridian-offset"
      && definition.shapeValid && staffing.shapeValid && archiveRoles.shapeValid
      && [originalDefinitionSHA256, archiveContentSHA256, calibrationContentSHA256, registrySHA256]
        .allSatisfy(ScriptCompletionReceipt.validDigest)
  }
}

/// A source subject stays the same through duty, case, visit and runtime-epoch changes.
struct NativeC01InquirySubjectRef: Codable, Sendable, Equatable, Hashable {
  let owner: UUID
  let sourceBirth: UUID
  let ordinal: Int
  var shapeValid: Bool { (0..<2).contains(ordinal) }
}

enum NativeC01InquiryAvailability: String, Codable, Sendable, Equatable {
  case available, unavailable, unobservedAfterLoss
}

struct NativeC01InquiryInstitutionalSubject: Codable, Sendable, Equatable {
  let ref: NativeC01InquirySubjectRef
  let definitionKey: String
  let birthOperation: UUID
  let revision: UInt64
  let availability: NativeC01InquiryAvailability
  let unavailabilityOperation: UUID?

  var shapeValid: Bool {
    ref.shapeValid && birthOperation == ref.sourceBirth
      && !definitionKey.isEmpty && definitionKey.utf8.count <= 256
      && revision > 0 && revision < UInt64(Int64.max)
      && ((availability == .available) == (unavailabilityOperation == nil))
  }
}

struct NativeC01InquiryStandingDuty: Codable, Sendable, Equatable {
  let operation: UUID
  let revision: UInt64
  let sourceBirth: UUID
  let sourceRevision: UInt64
  let subject: NativeC01InquirySubjectRef
  let role: NativeC01InquiryDutyRole
  let policy: NativeC01InquiryPolicyRef

  var shapeValid: Bool {
    revision > 0 && revision < UInt64(Int64.max)
      && sourceRevision > 0 && sourceRevision < UInt64(Int64.max)
      && subject.shapeValid && subject.sourceBirth == sourceBirth && policy.shapeValid
  }
}

/// Exactly one bounded main-host source record inside the proposed ONE inquiry root.
/// Missing or decoded records never cause source activation.
struct NativeC01InquiryInstitutionalSource: Codable, Sendable, Equatable {
  let owner: UUID
  let host: NativeMainStationIdentity
  let pins: NativeC01InquirySourcePins
  let birthOperation: UUID
  let revision: UInt64
  let activationArrival: NativeMainStationDockReceipt
  let activationPhysicalTime: Double
  let subjects: [NativeC01InquiryInstitutionalSubject]
  let duties: [NativeC01InquiryStandingDuty]
  let availability: NativeC01InquiryAvailability
  let unavailabilityOperation: UUID?

  var shapeValid: Bool {
    guard host.valid, host.world == owner, pins.shapeValid,
      revision > 0, revision < UInt64(Int64.max), activationArrival.valid,
      activationArrival.station == host, activationArrival.commanderOwner == owner,
      activationPhysicalTime.isFinite, (0...1e12).contains(activationPhysicalTime),
      subjects.count == 2, duties.count == 2,
      Set(subjects.map(\.ref.ordinal)) == Set(0..<2),
      Set(subjects.map(\.definitionKey)).count == 2,
      Set(duties.map(\.role)) == Set(NativeC01InquiryDutyRole.allCases),
      Set(duties.map(\.subject)).count == 2,
      ((availability == .available) == (unavailabilityOperation == nil))
    else { return false }
    return subjects.allSatisfy {
      $0.shapeValid && $0.ref.owner == owner && $0.ref.sourceBirth == birthOperation
    } && duties.allSatisfy { duty in
      duty.shapeValid && duty.sourceBirth == birthOperation && duty.sourceRevision <= revision
        && duty.policy == pins.staffing && subjects.contains { $0.ref == duty.subject }
    }
  }

  func availableDuty(_ role: NativeC01InquiryDutyRole)
    -> (NativeC01InquiryStandingDuty, NativeC01InquiryInstitutionalSubject)?
  {
    guard shapeValid, availability == .available,
      let duty = duties.first(where: { $0.role == role }),
      let subject = subjects.first(where: { $0.ref == duty.subject }),
      subject.availability == .available
    else { return nil }
    // A data lookup only. The current native source/content/assignment factory must still agree.
    return (duty, subject)
  }
}

/// The existing planned mandate/audit retain this use; there is no second assignment journal.
struct NativeC01InquiryAssignmentUse: Codable, Sendable, Equatable {
  let operation: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let owner: UUID
  let sourceBirth: UUID
  let sourceRevision: UInt64
  let subject: NativeC01InquirySubjectRef
  let dutyOperation: UUID
  let dutyRevision: UInt64
  let role: NativeC01InquiryDutyRole
  let policy: NativeC01InquiryPolicyRef
  let arrival: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let player: ActorIdentity
  let physicalTime: Double
  let historicalEpoch: UUID

  var shapeValid: Bool {
    caseRevision > 0 && caseRevision < UInt64(Int64.max)
      && sourceRevision > 0 && sourceRevision < UInt64(Int64.max)
      && dutyRevision > 0 && dutyRevision < UInt64(Int64.max)
      && inventoryRevision < UInt64(Int64.max) && subject.shapeValid
      && subject.owner == owner && subject.sourceBirth == sourceBirth && policy.shapeValid
      && arrival.valid && arrival.commanderOwner == owner && arrival.station.world == owner
      && player.system == arrival.station.system && player.entity == 0
      && player.visit == arrival.actor.visit
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }

  func matches(_ source: NativeC01InquiryInstitutionalSource) -> Bool {
    guard shapeValid, source.shapeValid, source.owner == owner,
      source.birthOperation == sourceBirth, source.revision >= sourceRevision,
      source.host == arrival.station, policy == source.pins.staffing,
      let duty = source.duties.first(where: { $0.operation == dutyOperation })
    else { return false }
    // Retained history may outlive availability; it never resolves a current desk.
    return duty.subject == subject && duty.role == role && duty.revision >= dutyRevision
  }
}

enum NativeC01InquiryPhase: String, Codable, Sendable, Equatable {
  case requestCase = "request-case"
  case measureSourceTrace = "measure-source-trace"
  case testCorrectiveModel = "test-corrective-model"
  case independentAudit = "independent-audit"
  case closeInquiry = "close-inquiry"
}

enum NativeC01InquiryOriginalBasis: Codable, Sendable, Equatable {
  case notCreated
  case retained(NativeC01InquiryOriginalHeaderRef)
}

enum NativeC01InquiryOriginalLossRef: Codable, Sendable, Equatable {
  case clockMarker(NativeC01InquiryMarkerLossRef)
  case surveyor(NativeC01InquirySurveyorLossRef)
  case timingStandard(NativeC01InquiryTimingStandardLossRef)
  case clinicHull(NativeC01InquiryClinicHullLossRef)
  case originalActor(NativeC01InquiryDestroyedActorRef)
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryState: Codable, Sendable, Equatable {
  let owner: UUID
  let nextCaseOrdinal: UInt64
  let institutionalSource: NativeC01InquiryInstitutionalSource
  let caseRecord: NativeC01InquiryCase
  let priorCases: [NativeC01InquiryCase]
  let fixtureLifecycle: [NativeC01InquiryFixtureLife]
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryCase: Codable, Sendable, Equatable {
  let id: UUID
  let ordinal: UInt64
  let revision: UInt64
  let phase: NativeC01InquiryPhase
  let mandate: NativeC01InquiryMandate
  let fixtureGenerations: [NativeC01InquiryFixtureGeneration]
  let measurements: [NativeC01InquiryMeasurement]
  let bench: NativeC01InquiryBench
  let audit: NativeC01InquiryAudit?
  let finalReceipt: NativeC01InquiryFinalReceipt?
  let originalOutcomeReferences: NativeC01InquiryOriginalOutcomeReferences
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryRegistryRef: Codable, Sendable, Equatable {
  let sourceSetCommit: String
  let sourceSetPath: String
  let sourceSetSHA256: String
  let corpusSchema: String
  let corpusRevision: String
  let corpusSHA256: String
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryProfileRef: Codable, Sendable, Equatable {
  let selector: String
  let schema: String
  let commit: String
  let path: String
  let sha256: String
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryModelInputRef: Codable, Sendable, Equatable {
  let resourcePath: String
  let resourceSHA256: String
  let profileSchema: String
  let jsonPointer: String
  let offsetDegrees: Int
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryArchiveRef: Codable, Sendable, Equatable {
  let recordID: String
  let replicaID: String
  let originIdentity: String
  let originDomain: String
  let payloadSHA256: String
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryChallenge: Codable, Sendable, Equatable {
  let id: UUID
  let caseID: UUID
  let sourceID: String
  let ordinal: Int
  let contentRevision: String
  let archive: NativeC01InquiryArchiveRef
  let modelInput: NativeC01InquiryModelInputRef
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryMandate: Codable, Sendable, Equatable {
  let operation: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let sourcePins: NativeC01InquirySourcePins
  let profile: NativeC01InquiryProfileRef
  let registry: NativeC01InquiryRegistryRef
  let intake: NativeC01InquiryAssignmentUse
  let challenge0: NativeC01InquiryChallenge
  let challenge1: NativeC01InquiryChallenge
  let challenge2: NativeC01InquiryChallenge
  let originalObservationOperation: UUID
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOriginalHeaderRef: Codable, Sendable, Equatable {
  let instanceID: UUID
  let definition: String
  let version: String
  let digest: String
  let revision: UInt64
  let outcome: ScriptOutcome
  let permissionOperation: UUID?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryMarkerLossRef: Codable, Sendable, Equatable {
  let ordinal: Int
  let generation: Int
  let markerActor: UUID
  let physicalTime: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquirySurveyorLossRef: Codable, Sendable, Equatable {
  let kind: NativeC01SurveyorLoss.Kind
  let collector: ActorIdentity
  let carrier: UUID
  let markerActor: UUID?
  let physicalTime: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryTimingStandardLossRef: Codable, Sendable, Equatable {
  let kind: NativeC01TimingStandardLoss.Kind
  let collector: ActorIdentity
  let carrier: UUID
  let actor: UUID?
  let physicalTime: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryClinicHullLossRef: Codable, Sendable, Equatable {
  let ordinal: Int
  let launch: UUID?
  let operation: UUID
  let sourceDisposition: UUID
  let actor: UUID
  let physicalTime: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryDestroyedActorRef: Codable, Sendable, Equatable {
  let encounterID: String
  let actor: UUID
  let presence: ScriptActorPresence
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOriginalObservation: Codable, Sendable, Equatable {
  let operation: UUID
  let physicalTime: Double
  let basis: NativeC01InquiryOriginalBasis
  let losses: [NativeC01InquiryOriginalLossRef]
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOriginalOutcomeReferences: Codable, Sendable, Equatable {
  let request: NativeC01InquiryOriginalObservation
  let audit: NativeC01InquiryOriginalObservation?
  let close: NativeC01InquiryOriginalObservation?
}

// The raw envelope owner rejects duplicate keys, lexical primitive aliases and
// global byte/depth limits before Decoder loses that information.
enum NativeC01InquiryDataCodec {
  struct Key: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }
  static func object(
    _ decoder: any Decoder, required: Set<String>, optional: Set<String> = []
  ) throws -> KeyedDecodingContainer<Key> {
    let c = try decoder.container(keyedBy: Key.self)
    let keys = Set(c.allKeys.map(\.stringValue))
    guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Invalid inquiry object keys"))
    }
    for key in c.allKeys {
      if try c.decodeNil(forKey: key) {
        throw DecodingError.valueNotFound(String.self, .init(
          codingPath: c.codingPath + [key], debugDescription: "Null inquiry field"))
      }
    }
    return c
  }
  static func requireShape(_ valid: Bool, decoder: any Decoder) throws {
    guard valid else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Invalid inquiry DATA shape"))
    }
  }
  static func requireShape<T>(_ value: T, valid: Bool, encoder: any Encoder) throws {
    guard valid else {
      throw EncodingError.invalidValue(value, .init(
        codingPath: encoder.codingPath, debugDescription: "Invalid inquiry DATA shape"))
    }
  }
}

enum NativeC01InquiryDataShape {
  static func text(_ value: String) -> Bool { !value.isEmpty && value.utf8.count <= 256 }
  static func revision(_ value: UInt64) -> Bool { value > 0 && value < UInt64(Int64.max) }
  static func inventoryRevision(_ value: UInt64) -> Bool { value < UInt64(Int64.max) }
  static func time(_ value: Double) -> Bool {
    value.isFinite && value.sign != .minus && value <= 1e12
  }
  static func pose(_ value: ShipPose) -> Bool {
    value.position.finite && value.orientation.validRotation
  }
  static func actor(_ value: ActorIdentity) -> Bool {
    value.system.galaxy >= 0 && value.system.galaxy < 8
      && value.system.system >= 0 && value.system.system <= 256
      && value.visit > 0 && value.visit < UInt64.max && value.entity < UInt64.max
  }
  static func incident(_ value: CombatIncident) -> Bool {
    value.id > 0 && value.id < UInt64.max && time(value.physicalTime)
      && value.position.finite && actor(value.origin.owner)
      && time(value.origin.emittedAt) && value.origin.emittedAt <= value.physicalTime
      && (value.victim.map(actor) ?? true)
  }
  static func adjacent(_ first: UInt64, _ second: UInt64) -> Bool {
    first < UInt64.max && second < UInt64.max && first + 1 == second
  }
  static func fixedChannels(_ ordinals: [Int]) -> Bool { ordinals == [0, 1, 2] }
}

extension NativeC01InquiryState {
  var shapeValid: Bool {
    guard nextCaseOrdinal < UInt64.max,
      institutionalSource.shapeValid,
      caseRecord.shapeValid,
      priorCases.count <= 16384,
      priorCases.allSatisfy({ $0.shapeValid }),
      fixtureLifecycle.count <= 16384,
      fixtureLifecycle.allSatisfy({ $0.shapeValid })
    else { return false }
    guard institutionalSource.owner == owner, priorCases.count <= 16384,
      caseRecord.ordinal == UInt64(priorCases.count),
      NativeC01InquiryDataShape.adjacent(caseRecord.ordinal, nextCaseOrdinal)
    else { return false }
    let cases = priorCases + [caseRecord]
    guard Set(cases.map(\.id)).count == cases.count else { return false }
    for (index, item) in cases.enumerated() {
      guard item.ordinal == UInt64(index), item.mandate.intake.owner == owner,
        item.mandate.intake.matches(institutionalSource),
        item.mandate.sourcePins == institutionalSource.pins,
        index == priorCases.count || item.phase == .closeInquiry
      else { return false }
      if let audit = item.audit {
        guard audit.reviewer.matches(institutionalSource) else { return false }
      }
    }
    var generations: [NativeC01InquiryLifeKey: NativeC01InquiryFixtureGeneration] = [:]
    for item in cases {
      for generation in item.fixtureGenerations {
        let key = NativeC01InquiryLifeKey(caseID: item.id, fixture: generation.fixtureID,
          generation: generation.generation)
        guard generations.updateValue(generation, forKey: key) == nil else { return false }
      }
    }
    guard fixtureLifecycle.count == generations.count else { return false }
    var seen = Set<NativeC01InquiryLifeKey>()
    for life in fixtureLifecycle {
      let key = NativeC01InquiryLifeKey(caseID: life.caseID, fixture: life.fixture.fixtureID,
        generation: life.fixture.generation)
      guard seen.insert(key).inserted, let birth = generations[key],
        life.fixture.matches(birth), life.revision >= birth.revision,
        life.matchesBirthChains(birth)
      else { return false }
    }
    return true
  }
}

extension NativeC01InquiryCase {
  var shapeValid: Bool {
    guard ordinal < UInt64.max,
      NativeC01InquiryDataShape.revision(revision),
      mandate.shapeValid,
      fixtureGenerations.count <= 16384,
      fixtureGenerations.allSatisfy({ $0.shapeValid }),
      measurements.count <= 16384,
      measurements.allSatisfy({ $0.shapeValid }),
      bench.shapeValid,
      (audit.map { $0.shapeValid } ?? true),
      (finalReceipt.map { $0.shapeValid } ?? true),
      originalOutcomeReferences.shapeValid
    else { return false }
    guard mandate.caseID == id, mandate.caseRevision <= revision,
      measurements.count <= 3,
      measurements.map(\.challengeOrdinal) == Array(0..<measurements.count),
      Set(measurements.map(\.operation)).count == measurements.count,
      Set(fixtureGenerations.map(\.admissionOperation)).count == fixtureGenerations.count,
      fixtureGenerations.filter({ $0.retirement == nil }).count <= 1,
      originalOutcomeReferences.request.operation == mandate.originalObservationOperation,
      (audit != nil) == (originalOutcomeReferences.audit != nil),
      (finalReceipt != nil) == (originalOutcomeReferences.close != nil)
    else { return false }
    guard bench.matchesContainingCase(
      owner: mandate.intake.owner, caseID: id, sourceBirth: mandate.intake.sourceBirth,
      maximumRevision: revision, measurements: measurementRefs)
    else { return false }
    var keys = Set<NativeC01InquiryFixtureKey>()
    for generation in fixtureGenerations {
      guard generation.caseID == id, generation.caseOrdinal == ordinal,
        generation.owner == mandate.intake.owner,
        generation.sourceBirth == mandate.intake.sourceBirth,
        keys.insert(.init(fixture: generation.fixtureID, generation: generation.generation)).inserted
      else { return false }
    }
    for measurement in measurements {
      guard measurement.caseID == id, measurement.caseRevision <= revision,
        measurement.owner == mandate.intake.owner,
        measurement.sourceBirth == mandate.intake.sourceBirth,
        measurement.mandateOperation == mandate.operation,
        let challenge = mandate.challenge(measurement.challengeOrdinal),
        measurement.challengeID == challenge.id,
        fixtureGenerations.contains(where: { measurement.fixture.matches($0) })
      else { return false }
    }
    if let audit {
      guard audit.matchesContainingCase(
        owner: mandate.intake.owner, sourceBirth: mandate.intake.sourceBirth),
        audit.caseID == id, audit.caseRevision <= revision,
        audit.intakeOperation == mandate.intake.operation,
        audit.reviewer.subject != mandate.intake.subject,
        audit.measurements == measurementRefs,
        audit.benchTrialOperation == bench.passingTrialOperation,
        audit.originalObservationOperation == originalOutcomeReferences.audit?.operation
      else { return false }
    }
    if let finalReceipt {
      guard finalReceipt.caseID == id, finalReceipt.caseOrdinal == ordinal,
        finalReceipt.caseRevision == revision, finalReceipt.owner == mandate.intake.owner,
        finalReceipt.sourceBirth == mandate.intake.sourceBirth,
        finalReceipt.sourcePins == mandate.sourcePins, finalReceipt.profile == mandate.profile,
        finalReceipt.registry == mandate.registry, finalReceipt.mandateOperation == mandate.operation,
        finalReceipt.measurements == measurementRefs,
        finalReceipt.benchTrialOperation == bench.passingTrialOperation,
        finalReceipt.auditOperation == audit?.operation,
        finalReceipt.originalObservationOperation == originalOutcomeReferences.close?.operation
      else { return false }
    }
    switch phase {
    case .requestCase:
      return measurements.count < 3 && bench.passingTrialOperation == nil && audit == nil && finalReceipt == nil
    case .measureSourceTrace:
      return measurements.count == 3 && bench.passingTrialOperation == nil && audit == nil && finalReceipt == nil
    case .testCorrectiveModel:
      return measurements.count == 3 && bench.passingTrialOperation != nil && audit == nil && finalReceipt == nil
    case .independentAudit:
      return measurements.count == 3 && bench.passingTrialOperation != nil && audit != nil && finalReceipt == nil
    case .closeInquiry:
      return measurements.count == 3 && bench.passingTrialOperation != nil && audit != nil && finalReceipt != nil
    }
  }
}

extension NativeC01InquiryRegistryRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(sourceSetCommit),
      NativeC01InquiryDataShape.text(sourceSetPath),
      ScriptCompletionReceipt.validDigest(sourceSetSHA256),
      NativeC01InquiryDataShape.text(corpusSchema),
      NativeC01InquiryDataShape.text(corpusRevision),
      ScriptCompletionReceipt.validDigest(corpusSHA256)
    else { return false }
    return sourceSetCommit.utf8.count == 40
      && sourceSetCommit.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
  }
}

extension NativeC01InquiryProfileRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(selector),
      NativeC01InquiryDataShape.text(schema),
      NativeC01InquiryDataShape.text(commit),
      NativeC01InquiryDataShape.text(path),
      ScriptCompletionReceipt.validDigest(sha256)
    else { return false }
    return commit.utf8.count == 40
      && commit.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
  }
}

extension NativeC01InquiryModelInputRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(resourcePath),
      ScriptCompletionReceipt.validDigest(resourceSHA256),
      NativeC01InquiryDataShape.text(profileSchema),
      NativeC01InquiryDataShape.text(jsonPointer),
      offsetDegrees >= 0
    else { return false }
    return [0, 45, 90].contains(offsetDegrees)
  }
}

extension NativeC01InquiryArchiveRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(recordID),
      NativeC01InquiryDataShape.text(replicaID),
      NativeC01InquiryDataShape.text(originIdentity),
      NativeC01InquiryDataShape.text(originDomain),
      ScriptCompletionReceipt.validDigest(payloadSHA256)
    else { return false }
    return true
  }
}

extension NativeC01InquiryChallenge {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(sourceID),
      ordinal >= 0,
      NativeC01InquiryDataShape.text(contentRevision),
      archive.shapeValid,
      modelInput.shapeValid
    else { return false }
    return (0..<3).contains(ordinal) && modelInput.offsetDegrees == ordinal * 45
  }
}

extension NativeC01InquiryMandate {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(caseRevision),
      sourcePins.shapeValid,
      profile.shapeValid,
      registry.shapeValid,
      intake.shapeValid,
      challenge0.shapeValid,
      challenge1.shapeValid,
      challenge2.shapeValid
    else { return false }
    return operation == intake.operation && caseID == intake.caseID
      && caseRevision == intake.caseRevision && intake.role == .intake
      && registry.corpusSHA256 == sourcePins.registrySHA256
      && [challenge0, challenge1, challenge2].map(\.ordinal) == [0, 1, 2]
      && [challenge0, challenge1, challenge2].allSatisfy { $0.caseID == caseID && $0.sourceID == sourcePins.sourceID }
      && Set([challenge0.id, challenge1.id, challenge2.id]).count == 3
      && Set([challenge0.archive.recordID, challenge1.archive.recordID, challenge2.archive.recordID]).count == 3
      && Set([challenge0.archive.replicaID, challenge1.archive.replicaID, challenge2.archive.replicaID]).count == 3
  }
}

extension NativeC01InquiryOriginalHeaderRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(definition),
      NativeC01InquiryDataShape.text(version),
      ScriptCompletionReceipt.validDigest(digest),
      revision < UInt64(Int64.max)
    else { return false }
    return true
  }
}

extension NativeC01InquiryMarkerLossRef {
  var shapeValid: Bool {
    guard ordinal >= 0,
      generation >= 0,
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return (0..<3).contains(ordinal) && generation >= 0
  }
}

extension NativeC01InquirySurveyorLossRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.actor(collector),
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return true
  }
}

extension NativeC01InquiryTimingStandardLossRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.actor(collector),
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return true
  }
}

extension NativeC01InquiryClinicHullLossRef {
  var shapeValid: Bool {
    guard ordinal >= 0,
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return ordinal >= 0
  }
}

extension NativeC01InquiryDestroyedActorRef {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.text(encounterID)
    else { return false }
    return presence == .destroyed
  }
}

extension NativeC01InquiryOriginalObservation {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.time(physicalTime),
      basis.shapeValid,
      losses.count <= 16384,
      losses.allSatisfy({ $0.shapeValid })
    else { return false }
    switch basis {
    case .notCreated: return losses.isEmpty
    case .retained: return true
    }
  }
}

extension NativeC01InquiryOriginalOutcomeReferences {
  var shapeValid: Bool {
    guard request.shapeValid,
      (audit.map { $0.shapeValid } ?? true),
      (close.map { $0.shapeValid } ?? true)
    else { return false }
    return (audit.map { $0.physicalTime >= request.physicalTime } ?? true)
      && (close.map { $0.physicalTime >= (audit?.physicalTime ?? request.physicalTime) } ?? true)
  }
}

extension NativeC01InquiryOriginalBasis {
  var shapeValid: Bool {
    switch self {
    case .notCreated: return true
    case .retained(let value): return value.shapeValid
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "not-created":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind"])
      _ = c
      self = .notCreated
    case "retained":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryOriginalHeaderRef.self, forKey: .init("payload"))
      self = .retained(value)
    default:
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Unknown inquiry variant"))
    }
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    switch self {
    case .notCreated:
      try c.encode("not-created", forKey: .init("kind"))
    case .retained(let value):
      try c.encode("retained", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    }
  }
}

extension NativeC01InquiryOriginalLossRef {
  var shapeValid: Bool {
    switch self {
    case .clockMarker(let value): return value.shapeValid
    case .surveyor(let value): return value.shapeValid
    case .timingStandard(let value): return value.shapeValid
    case .clinicHull(let value): return value.shapeValid
    case .originalActor(let value): return value.shapeValid
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "clock-marker":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryMarkerLossRef.self, forKey: .init("payload"))
      self = .clockMarker(value)
    case "surveyor":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquirySurveyorLossRef.self, forKey: .init("payload"))
      self = .surveyor(value)
    case "timing-standard":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryTimingStandardLossRef.self, forKey: .init("payload"))
      self = .timingStandard(value)
    case "clinic-hull":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryClinicHullLossRef.self, forKey: .init("payload"))
      self = .clinicHull(value)
    case "original-actor":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryDestroyedActorRef.self, forKey: .init("payload"))
      self = .originalActor(value)
    default:
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Unknown inquiry variant"))
    }
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    switch self {
    case .clockMarker(let value):
      try c.encode("clock-marker", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .surveyor(let value):
      try c.encode("surveyor", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .timingStandard(let value):
      try c.encode("timing-standard", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .clinicHull(let value):
      try c.encode("clinic-hull", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .originalActor(let value):
      try c.encode("original-actor", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    }
  }
}

extension NativeC01InquiryPolicyRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["identity", "revision", "sha256"])
    self.init(
      identity: try c.decode(String.self, forKey: .init("identity")),
      revision: try c.decode(String.self, forKey: .init("revision")),
      sha256: try c.decode(String.self, forKey: .init("sha256")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(identity, forKey: .init("identity"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(sha256, forKey: .init("sha256"))
  }
}

extension NativeC01InquirySourcePins {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["sourceID", "clueID", "clueReceipt", "definition", "staffing", "archiveRoles", "originalDefinitionSHA256", "archiveContentSHA256", "calibrationContentSHA256", "registrySHA256"])
    self.init(
      sourceID: try c.decode(String.self, forKey: .init("sourceID")),
      clueID: try c.decode(String.self, forKey: .init("clueID")),
      clueReceipt: try c.decode(String.self, forKey: .init("clueReceipt")),
      definition: try c.decode(NativeC01InquiryPolicyRef.self, forKey: .init("definition")),
      staffing: try c.decode(NativeC01InquiryPolicyRef.self, forKey: .init("staffing")),
      archiveRoles: try c.decode(NativeC01InquiryPolicyRef.self, forKey: .init("archiveRoles")),
      originalDefinitionSHA256: try c.decode(String.self, forKey: .init("originalDefinitionSHA256")),
      archiveContentSHA256: try c.decode(String.self, forKey: .init("archiveContentSHA256")),
      calibrationContentSHA256: try c.decode(String.self, forKey: .init("calibrationContentSHA256")),
      registrySHA256: try c.decode(String.self, forKey: .init("registrySHA256")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(sourceID, forKey: .init("sourceID"))
    try c.encode(clueID, forKey: .init("clueID"))
    try c.encode(clueReceipt, forKey: .init("clueReceipt"))
    try c.encode(definition, forKey: .init("definition"))
    try c.encode(staffing, forKey: .init("staffing"))
    try c.encode(archiveRoles, forKey: .init("archiveRoles"))
    try c.encode(originalDefinitionSHA256, forKey: .init("originalDefinitionSHA256"))
    try c.encode(archiveContentSHA256, forKey: .init("archiveContentSHA256"))
    try c.encode(calibrationContentSHA256, forKey: .init("calibrationContentSHA256"))
    try c.encode(registrySHA256, forKey: .init("registrySHA256"))
  }
}

extension NativeC01InquirySubjectRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["owner", "sourceBirth", "ordinal"])
    self.init(
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      ordinal: try c.decode(Int.self, forKey: .init("ordinal")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(ordinal, forKey: .init("ordinal"))
  }
}

extension NativeC01InquiryInstitutionalSubject {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["ref", "definitionKey", "birthOperation", "revision", "availability"],
      optional: ["unavailabilityOperation"])
    self.init(
      ref: try c.decode(NativeC01InquirySubjectRef.self, forKey: .init("ref")),
      definitionKey: try c.decode(String.self, forKey: .init("definitionKey")),
      birthOperation: try c.decode(UUID.self, forKey: .init("birthOperation")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      availability: try c.decode(NativeC01InquiryAvailability.self, forKey: .init("availability")),
      unavailabilityOperation: try c.decodeIfPresent(UUID.self, forKey: .init("unavailabilityOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(ref, forKey: .init("ref"))
    try c.encode(definitionKey, forKey: .init("definitionKey"))
    try c.encode(birthOperation, forKey: .init("birthOperation"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(availability, forKey: .init("availability"))
    try c.encodeIfPresent(unavailabilityOperation, forKey: .init("unavailabilityOperation"))
  }
}

extension NativeC01InquiryStandingDuty {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "revision", "sourceBirth", "sourceRevision", "subject", "role", "policy"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      sourceRevision: try c.decode(UInt64.self, forKey: .init("sourceRevision")),
      subject: try c.decode(NativeC01InquirySubjectRef.self, forKey: .init("subject")),
      role: try c.decode(NativeC01InquiryDutyRole.self, forKey: .init("role")),
      policy: try c.decode(NativeC01InquiryPolicyRef.self, forKey: .init("policy")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(sourceRevision, forKey: .init("sourceRevision"))
    try c.encode(subject, forKey: .init("subject"))
    try c.encode(role, forKey: .init("role"))
    try c.encode(policy, forKey: .init("policy"))
  }
}

extension NativeC01InquiryInstitutionalSource {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["owner", "host", "pins", "birthOperation", "revision", "activationArrival", "activationPhysicalTime", "subjects", "duties", "availability"],
      optional: ["unavailabilityOperation"])
    self.init(
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      host: try c.decode(NativeMainStationIdentity.self, forKey: .init("host")),
      pins: try c.decode(NativeC01InquirySourcePins.self, forKey: .init("pins")),
      birthOperation: try c.decode(UUID.self, forKey: .init("birthOperation")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      activationArrival: try c.decode(NativeMainStationDockReceipt.self, forKey: .init("activationArrival")),
      activationPhysicalTime: try c.decode(Double.self, forKey: .init("activationPhysicalTime")),
      subjects: try c.decode([NativeC01InquiryInstitutionalSubject].self, forKey: .init("subjects")),
      duties: try c.decode([NativeC01InquiryStandingDuty].self, forKey: .init("duties")),
      availability: try c.decode(NativeC01InquiryAvailability.self, forKey: .init("availability")),
      unavailabilityOperation: try c.decodeIfPresent(UUID.self, forKey: .init("unavailabilityOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(host, forKey: .init("host"))
    try c.encode(pins, forKey: .init("pins"))
    try c.encode(birthOperation, forKey: .init("birthOperation"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(activationArrival, forKey: .init("activationArrival"))
    try c.encode(activationPhysicalTime, forKey: .init("activationPhysicalTime"))
    try c.encode(subjects, forKey: .init("subjects"))
    try c.encode(duties, forKey: .init("duties"))
    try c.encode(availability, forKey: .init("availability"))
    try c.encodeIfPresent(unavailabilityOperation, forKey: .init("unavailabilityOperation"))
  }
}

extension NativeC01InquiryAssignmentUse {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "caseID", "caseRevision", "owner", "sourceBirth", "sourceRevision", "subject", "dutyOperation", "dutyRevision", "role", "policy", "arrival", "carrier", "inventoryRevision", "player", "physicalTime", "historicalEpoch"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      sourceRevision: try c.decode(UInt64.self, forKey: .init("sourceRevision")),
      subject: try c.decode(NativeC01InquirySubjectRef.self, forKey: .init("subject")),
      dutyOperation: try c.decode(UUID.self, forKey: .init("dutyOperation")),
      dutyRevision: try c.decode(UInt64.self, forKey: .init("dutyRevision")),
      role: try c.decode(NativeC01InquiryDutyRole.self, forKey: .init("role")),
      policy: try c.decode(NativeC01InquiryPolicyRef.self, forKey: .init("policy")),
      arrival: try c.decode(NativeMainStationDockReceipt.self, forKey: .init("arrival")),
      carrier: try c.decode(UUID.self, forKey: .init("carrier")),
      inventoryRevision: try c.decode(UInt64.self, forKey: .init("inventoryRevision")),
      player: try c.decode(ActorIdentity.self, forKey: .init("player")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(sourceRevision, forKey: .init("sourceRevision"))
    try c.encode(subject, forKey: .init("subject"))
    try c.encode(dutyOperation, forKey: .init("dutyOperation"))
    try c.encode(dutyRevision, forKey: .init("dutyRevision"))
    try c.encode(role, forKey: .init("role"))
    try c.encode(policy, forKey: .init("policy"))
    try c.encode(arrival, forKey: .init("arrival"))
    try c.encode(carrier, forKey: .init("carrier"))
    try c.encode(inventoryRevision, forKey: .init("inventoryRevision"))
    try c.encode(player, forKey: .init("player"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
  }
}

extension NativeC01InquiryOscillatorData {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["phase", "cycle", "pulseSequence"])
    self.init(
      phase: try c.decode(NativeC01InquiryExactDyadic.self, forKey: .init("phase")),
      cycle: try c.decode(UInt64.self, forKey: .init("cycle")),
      pulseSequence: try c.decode(UInt64.self, forKey: .init("pulseSequence")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(phase, forKey: .init("phase"))
    try c.encode(cycle, forKey: .init("cycle"))
    try c.encode(pulseSequence, forKey: .init("pulseSequence"))
  }
}

extension NativeC01InquiryHeadModelData {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["reference", "output", "appliedDetent", "appliedControlRevision"])
    self.init(
      reference: try c.decode(NativeC01InquiryOscillatorData.self, forKey: .init("reference")),
      output: try c.decode(NativeC01InquiryOscillatorData.self, forKey: .init("output")),
      appliedDetent: try c.decode(NativeC01InquiryManualDetent.self, forKey: .init("appliedDetent")),
      appliedControlRevision: try c.decode(UInt64.self, forKey: .init("appliedControlRevision")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(reference, forKey: .init("reference"))
    try c.encode(output, forKey: .init("output"))
    try c.encode(appliedDetent, forKey: .init("appliedDetent"))
    try c.encode(appliedControlRevision, forKey: .init("appliedControlRevision"))
  }
}

extension NativeC01InquiryState {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["owner", "nextCaseOrdinal", "institutionalSource", "caseRecord", "priorCases", "fixtureLifecycle"])
    self.init(
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      nextCaseOrdinal: try c.decode(UInt64.self, forKey: .init("nextCaseOrdinal")),
      institutionalSource: try c.decode(NativeC01InquiryInstitutionalSource.self, forKey: .init("institutionalSource")),
      caseRecord: try c.decode(NativeC01InquiryCase.self, forKey: .init("caseRecord")),
      priorCases: try c.decode([NativeC01InquiryCase].self, forKey: .init("priorCases")),
      fixtureLifecycle: try c.decode([NativeC01InquiryFixtureLife].self, forKey: .init("fixtureLifecycle")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(nextCaseOrdinal, forKey: .init("nextCaseOrdinal"))
    try c.encode(institutionalSource, forKey: .init("institutionalSource"))
    try c.encode(caseRecord, forKey: .init("caseRecord"))
    try c.encode(priorCases, forKey: .init("priorCases"))
    try c.encode(fixtureLifecycle, forKey: .init("fixtureLifecycle"))
  }
}

extension NativeC01InquiryCase {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["id", "ordinal", "revision", "phase", "mandate", "fixtureGenerations", "measurements", "bench", "originalOutcomeReferences"],
      optional: ["audit", "finalReceipt"])
    self.init(
      id: try c.decode(UUID.self, forKey: .init("id")),
      ordinal: try c.decode(UInt64.self, forKey: .init("ordinal")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      phase: try c.decode(NativeC01InquiryPhase.self, forKey: .init("phase")),
      mandate: try c.decode(NativeC01InquiryMandate.self, forKey: .init("mandate")),
      fixtureGenerations: try c.decode([NativeC01InquiryFixtureGeneration].self, forKey: .init("fixtureGenerations")),
      measurements: try c.decode([NativeC01InquiryMeasurement].self, forKey: .init("measurements")),
      bench: try c.decode(NativeC01InquiryBench.self, forKey: .init("bench")),
      audit: try c.decodeIfPresent(NativeC01InquiryAudit.self, forKey: .init("audit")),
      finalReceipt: try c.decodeIfPresent(NativeC01InquiryFinalReceipt.self, forKey: .init("finalReceipt")),
      originalOutcomeReferences: try c.decode(NativeC01InquiryOriginalOutcomeReferences.self, forKey: .init("originalOutcomeReferences")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(id, forKey: .init("id"))
    try c.encode(ordinal, forKey: .init("ordinal"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(phase, forKey: .init("phase"))
    try c.encode(mandate, forKey: .init("mandate"))
    try c.encode(fixtureGenerations, forKey: .init("fixtureGenerations"))
    try c.encode(measurements, forKey: .init("measurements"))
    try c.encode(bench, forKey: .init("bench"))
    try c.encodeIfPresent(audit, forKey: .init("audit"))
    try c.encodeIfPresent(finalReceipt, forKey: .init("finalReceipt"))
    try c.encode(originalOutcomeReferences, forKey: .init("originalOutcomeReferences"))
  }
}

extension NativeC01InquiryRegistryRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["sourceSetCommit", "sourceSetPath", "sourceSetSHA256", "corpusSchema", "corpusRevision", "corpusSHA256"])
    self.init(
      sourceSetCommit: try c.decode(String.self, forKey: .init("sourceSetCommit")),
      sourceSetPath: try c.decode(String.self, forKey: .init("sourceSetPath")),
      sourceSetSHA256: try c.decode(String.self, forKey: .init("sourceSetSHA256")),
      corpusSchema: try c.decode(String.self, forKey: .init("corpusSchema")),
      corpusRevision: try c.decode(String.self, forKey: .init("corpusRevision")),
      corpusSHA256: try c.decode(String.self, forKey: .init("corpusSHA256")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(sourceSetCommit, forKey: .init("sourceSetCommit"))
    try c.encode(sourceSetPath, forKey: .init("sourceSetPath"))
    try c.encode(sourceSetSHA256, forKey: .init("sourceSetSHA256"))
    try c.encode(corpusSchema, forKey: .init("corpusSchema"))
    try c.encode(corpusRevision, forKey: .init("corpusRevision"))
    try c.encode(corpusSHA256, forKey: .init("corpusSHA256"))
  }
}

extension NativeC01InquiryProfileRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["selector", "schema", "commit", "path", "sha256"])
    self.init(
      selector: try c.decode(String.self, forKey: .init("selector")),
      schema: try c.decode(String.self, forKey: .init("schema")),
      commit: try c.decode(String.self, forKey: .init("commit")),
      path: try c.decode(String.self, forKey: .init("path")),
      sha256: try c.decode(String.self, forKey: .init("sha256")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(selector, forKey: .init("selector"))
    try c.encode(schema, forKey: .init("schema"))
    try c.encode(commit, forKey: .init("commit"))
    try c.encode(path, forKey: .init("path"))
    try c.encode(sha256, forKey: .init("sha256"))
  }
}

extension NativeC01InquiryModelInputRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["resourcePath", "resourceSHA256", "profileSchema", "jsonPointer", "offsetDegrees"])
    self.init(
      resourcePath: try c.decode(String.self, forKey: .init("resourcePath")),
      resourceSHA256: try c.decode(String.self, forKey: .init("resourceSHA256")),
      profileSchema: try c.decode(String.self, forKey: .init("profileSchema")),
      jsonPointer: try c.decode(String.self, forKey: .init("jsonPointer")),
      offsetDegrees: try c.decode(Int.self, forKey: .init("offsetDegrees")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(resourcePath, forKey: .init("resourcePath"))
    try c.encode(resourceSHA256, forKey: .init("resourceSHA256"))
    try c.encode(profileSchema, forKey: .init("profileSchema"))
    try c.encode(jsonPointer, forKey: .init("jsonPointer"))
    try c.encode(offsetDegrees, forKey: .init("offsetDegrees"))
  }
}

extension NativeC01InquiryArchiveRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["recordID", "replicaID", "originIdentity", "originDomain", "payloadSHA256"])
    self.init(
      recordID: try c.decode(String.self, forKey: .init("recordID")),
      replicaID: try c.decode(String.self, forKey: .init("replicaID")),
      originIdentity: try c.decode(String.self, forKey: .init("originIdentity")),
      originDomain: try c.decode(String.self, forKey: .init("originDomain")),
      payloadSHA256: try c.decode(String.self, forKey: .init("payloadSHA256")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(recordID, forKey: .init("recordID"))
    try c.encode(replicaID, forKey: .init("replicaID"))
    try c.encode(originIdentity, forKey: .init("originIdentity"))
    try c.encode(originDomain, forKey: .init("originDomain"))
    try c.encode(payloadSHA256, forKey: .init("payloadSHA256"))
  }
}

extension NativeC01InquiryChallenge {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["id", "caseID", "sourceID", "ordinal", "contentRevision", "archive", "modelInput"])
    self.init(
      id: try c.decode(UUID.self, forKey: .init("id")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      sourceID: try c.decode(String.self, forKey: .init("sourceID")),
      ordinal: try c.decode(Int.self, forKey: .init("ordinal")),
      contentRevision: try c.decode(String.self, forKey: .init("contentRevision")),
      archive: try c.decode(NativeC01InquiryArchiveRef.self, forKey: .init("archive")),
      modelInput: try c.decode(NativeC01InquiryModelInputRef.self, forKey: .init("modelInput")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(id, forKey: .init("id"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(sourceID, forKey: .init("sourceID"))
    try c.encode(ordinal, forKey: .init("ordinal"))
    try c.encode(contentRevision, forKey: .init("contentRevision"))
    try c.encode(archive, forKey: .init("archive"))
    try c.encode(modelInput, forKey: .init("modelInput"))
  }
}

extension NativeC01InquiryMandate {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "caseID", "caseRevision", "sourcePins", "profile", "registry", "intake", "challenge0", "challenge1", "challenge2", "originalObservationOperation"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourcePins: try c.decode(NativeC01InquirySourcePins.self, forKey: .init("sourcePins")),
      profile: try c.decode(NativeC01InquiryProfileRef.self, forKey: .init("profile")),
      registry: try c.decode(NativeC01InquiryRegistryRef.self, forKey: .init("registry")),
      intake: try c.decode(NativeC01InquiryAssignmentUse.self, forKey: .init("intake")),
      challenge0: try c.decode(NativeC01InquiryChallenge.self, forKey: .init("challenge0")),
      challenge1: try c.decode(NativeC01InquiryChallenge.self, forKey: .init("challenge1")),
      challenge2: try c.decode(NativeC01InquiryChallenge.self, forKey: .init("challenge2")),
      originalObservationOperation: try c.decode(UUID.self, forKey: .init("originalObservationOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(sourcePins, forKey: .init("sourcePins"))
    try c.encode(profile, forKey: .init("profile"))
    try c.encode(registry, forKey: .init("registry"))
    try c.encode(intake, forKey: .init("intake"))
    try c.encode(challenge0, forKey: .init("challenge0"))
    try c.encode(challenge1, forKey: .init("challenge1"))
    try c.encode(challenge2, forKey: .init("challenge2"))
    try c.encode(originalObservationOperation, forKey: .init("originalObservationOperation"))
  }
}

extension NativeC01InquiryOriginalHeaderRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["instanceID", "definition", "version", "digest", "revision", "outcome"],
      optional: ["permissionOperation"])
    self.init(
      instanceID: try c.decode(UUID.self, forKey: .init("instanceID")),
      definition: try c.decode(String.self, forKey: .init("definition")),
      version: try c.decode(String.self, forKey: .init("version")),
      digest: try c.decode(String.self, forKey: .init("digest")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      outcome: try c.decode(ScriptOutcome.self, forKey: .init("outcome")),
      permissionOperation: try c.decodeIfPresent(UUID.self, forKey: .init("permissionOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(instanceID, forKey: .init("instanceID"))
    try c.encode(definition, forKey: .init("definition"))
    try c.encode(version, forKey: .init("version"))
    try c.encode(digest, forKey: .init("digest"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(outcome, forKey: .init("outcome"))
    try c.encodeIfPresent(permissionOperation, forKey: .init("permissionOperation"))
  }
}

extension NativeC01InquiryMarkerLossRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["ordinal", "generation", "markerActor", "physicalTime"])
    self.init(
      ordinal: try c.decode(Int.self, forKey: .init("ordinal")),
      generation: try c.decode(Int.self, forKey: .init("generation")),
      markerActor: try c.decode(UUID.self, forKey: .init("markerActor")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(ordinal, forKey: .init("ordinal"))
    try c.encode(generation, forKey: .init("generation"))
    try c.encode(markerActor, forKey: .init("markerActor"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquirySurveyorLossRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["kind", "collector", "carrier", "physicalTime"],
      optional: ["markerActor"])
    self.init(
      kind: try c.decode(NativeC01SurveyorLoss.Kind.self, forKey: .init("kind")),
      collector: try c.decode(ActorIdentity.self, forKey: .init("collector")),
      carrier: try c.decode(UUID.self, forKey: .init("carrier")),
      markerActor: try c.decodeIfPresent(UUID.self, forKey: .init("markerActor")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(kind, forKey: .init("kind"))
    try c.encode(collector, forKey: .init("collector"))
    try c.encode(carrier, forKey: .init("carrier"))
    try c.encodeIfPresent(markerActor, forKey: .init("markerActor"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquiryTimingStandardLossRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["kind", "collector", "carrier", "physicalTime"],
      optional: ["actor"])
    self.init(
      kind: try c.decode(NativeC01TimingStandardLoss.Kind.self, forKey: .init("kind")),
      collector: try c.decode(ActorIdentity.self, forKey: .init("collector")),
      carrier: try c.decode(UUID.self, forKey: .init("carrier")),
      actor: try c.decodeIfPresent(UUID.self, forKey: .init("actor")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(kind, forKey: .init("kind"))
    try c.encode(collector, forKey: .init("collector"))
    try c.encode(carrier, forKey: .init("carrier"))
    try c.encodeIfPresent(actor, forKey: .init("actor"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquiryClinicHullLossRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["ordinal", "operation", "sourceDisposition", "actor", "physicalTime"],
      optional: ["launch"])
    self.init(
      ordinal: try c.decode(Int.self, forKey: .init("ordinal")),
      launch: try c.decodeIfPresent(UUID.self, forKey: .init("launch")),
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      sourceDisposition: try c.decode(UUID.self, forKey: .init("sourceDisposition")),
      actor: try c.decode(UUID.self, forKey: .init("actor")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(ordinal, forKey: .init("ordinal"))
    try c.encodeIfPresent(launch, forKey: .init("launch"))
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(sourceDisposition, forKey: .init("sourceDisposition"))
    try c.encode(actor, forKey: .init("actor"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquiryDestroyedActorRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["encounterID", "actor", "presence"])
    self.init(
      encounterID: try c.decode(String.self, forKey: .init("encounterID")),
      actor: try c.decode(UUID.self, forKey: .init("actor")),
      presence: try c.decode(ScriptActorPresence.self, forKey: .init("presence")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(encounterID, forKey: .init("encounterID"))
    try c.encode(actor, forKey: .init("actor"))
    try c.encode(presence, forKey: .init("presence"))
  }
}

extension NativeC01InquiryOriginalObservation {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "physicalTime", "basis", "losses"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      basis: try c.decode(NativeC01InquiryOriginalBasis.self, forKey: .init("basis")),
      losses: try c.decode([NativeC01InquiryOriginalLossRef].self, forKey: .init("losses")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(basis, forKey: .init("basis"))
    try c.encode(losses, forKey: .init("losses"))
  }
}

extension NativeC01InquiryOriginalOutcomeReferences {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["request"],
      optional: ["audit", "close"])
    self.init(
      request: try c.decode(NativeC01InquiryOriginalObservation.self, forKey: .init("request")),
      audit: try c.decodeIfPresent(NativeC01InquiryOriginalObservation.self, forKey: .init("audit")),
      close: try c.decodeIfPresent(NativeC01InquiryOriginalObservation.self, forKey: .init("close")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(request, forKey: .init("request"))
    try c.encodeIfPresent(audit, forKey: .init("audit"))
    try c.encodeIfPresent(close, forKey: .init("close"))
  }
}

private struct NativeC01InquiryLifeKey: Hashable {
  let caseID: UUID
  let fixture: UUID
  let generation: UInt64
}
private struct NativeC01InquiryFixtureKey: Hashable {
  let fixture: UUID
  let generation: UInt64
}
extension NativeC01InquiryMandate {
  func challenge(_ ordinal: Int) -> NativeC01InquiryChallenge? {
    switch ordinal { case 0: challenge0; case 1: challenge1; case 2: challenge2; default: nil }
  }
}
extension NativeC01InquiryCase {
  var measurementRefs: NativeC01InquiryMeasurementRefs? {
    guard measurements.count == 3 else { return nil }
    return .init(channel0: measurements[0].operation,
      channel1: measurements[1].operation, channel2: measurements[2].operation)
  }
}
