import Foundation

// Retained audit/final DATA only. Native receiving, close verification and grants are separate owners.

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryArchiveCorrespondence: Codable, Sendable, Equatable {
  let challengeID: UUID
  let challengeOrdinal: Int
  let archive: NativeC01InquiryArchiveRef
  let modelInput: NativeC01InquiryModelInputRef
  let measurementOperation: UUID
  let referencePair: NativeC01InquiryReferencePair
  let benchTrialOperation: UUID
  let benchCycleOrdinal: Int
  let actualBenchCycle: NativeC01InquiryOutputCycle
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryAudit: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let sourceBirth: UUID
  let reviewer: NativeC01InquiryAssignmentUse
  let intakeOperation: UUID
  let measurements: NativeC01InquiryMeasurementRefs
  let benchTrialOperation: UUID
  let correspondences: [NativeC01InquiryArchiveCorrespondence]
  let originalObservationOperation: UUID
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryFinalReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let caseID: UUID
  let caseOrdinal: UInt64
  let caseRevision: UInt64
  let sourceBirth: UUID
  let sourcePins: NativeC01InquirySourcePins
  let profile: NativeC01InquiryProfileRef
  let registry: NativeC01InquiryRegistryRef
  let mandateOperation: UUID
  let measurements: NativeC01InquiryMeasurementRefs
  let benchTrialOperation: UUID
  let auditOperation: UUID
  let originalObservationOperation: UUID
  let verifierRevision: String
  let arrival: NativeMainStationDockReceipt
  let player: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let historicalEpoch: UUID
  let physicalTime: Double
}

extension NativeC01InquiryArchiveCorrespondence {
  var shapeValid: Bool {
    guard challengeOrdinal >= 0,
      archive.shapeValid,
      modelInput.shapeValid,
      referencePair.shapeValid,
      benchCycleOrdinal >= 0,
      actualBenchCycle.shapeValid
    else { return false }
    return (0..<3).contains(challengeOrdinal) && (0..<3).contains(benchCycleOrdinal)
  }
}

extension NativeC01InquiryAudit {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(caseRevision),
      reviewer.shapeValid,
      measurements.shapeValid,
      correspondences.count <= 16384,
      correspondences.allSatisfy({ $0.shapeValid })
    else { return false }
    return reviewer.operation == operation && reviewer.caseID == caseID
      && reviewer.caseRevision == caseRevision && reviewer.owner == owner
      && reviewer.sourceBirth == sourceBirth && reviewer.role == .independentReview
      && (2...3).contains(correspondences.count)
      && Set(correspondences.map(\.challengeID)).count == correspondences.count
      && Set(correspondences.map { $0.archive.originIdentity }).count == correspondences.count
      && Set(correspondences.map { $0.archive.originDomain }).count == correspondences.count
      && correspondences.allSatisfy({ $0.benchTrialOperation == benchTrialOperation })
  }
}

extension NativeC01InquiryFinalReceipt {
  var shapeValid: Bool {
    guard caseOrdinal < UInt64.max,
      NativeC01InquiryDataShape.revision(caseRevision),
      sourcePins.shapeValid,
      profile.shapeValid,
      registry.shapeValid,
      measurements.shapeValid,
      NativeC01InquiryDataShape.text(verifierRevision),
      arrival.valid,
      NativeC01InquiryDataShape.actor(player),
      NativeC01InquiryDataShape.inventoryRevision(inventoryRevision),
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return arrival.commanderOwner == owner && arrival.station.world == owner
      && player == ActorIdentity(system: arrival.actor.system, visit: arrival.actor.visit, entity: 0)
      && registry.corpusSHA256 == sourcePins.registrySHA256
  }
}

extension NativeC01InquiryArchiveCorrespondence {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["challengeID", "challengeOrdinal", "archive", "modelInput", "measurementOperation", "referencePair", "benchTrialOperation", "benchCycleOrdinal", "actualBenchCycle"])
    self.init(
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      archive: try c.decode(NativeC01InquiryArchiveRef.self, forKey: .init("archive")),
      modelInput: try c.decode(NativeC01InquiryModelInputRef.self, forKey: .init("modelInput")),
      measurementOperation: try c.decode(UUID.self, forKey: .init("measurementOperation")),
      referencePair: try c.decode(NativeC01InquiryReferencePair.self, forKey: .init("referencePair")),
      benchTrialOperation: try c.decode(UUID.self, forKey: .init("benchTrialOperation")),
      benchCycleOrdinal: try c.decode(Int.self, forKey: .init("benchCycleOrdinal")),
      actualBenchCycle: try c.decode(NativeC01InquiryOutputCycle.self, forKey: .init("actualBenchCycle")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(archive, forKey: .init("archive"))
    try c.encode(modelInput, forKey: .init("modelInput"))
    try c.encode(measurementOperation, forKey: .init("measurementOperation"))
    try c.encode(referencePair, forKey: .init("referencePair"))
    try c.encode(benchTrialOperation, forKey: .init("benchTrialOperation"))
    try c.encode(benchCycleOrdinal, forKey: .init("benchCycleOrdinal"))
    try c.encode(actualBenchCycle, forKey: .init("actualBenchCycle"))
  }
}

extension NativeC01InquiryAudit {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "owner", "caseID", "caseRevision", "sourceBirth", "reviewer", "intakeOperation", "measurements", "benchTrialOperation", "correspondences", "originalObservationOperation"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      reviewer: try c.decode(NativeC01InquiryAssignmentUse.self, forKey: .init("reviewer")),
      intakeOperation: try c.decode(UUID.self, forKey: .init("intakeOperation")),
      measurements: try c.decode(NativeC01InquiryMeasurementRefs.self, forKey: .init("measurements")),
      benchTrialOperation: try c.decode(UUID.self, forKey: .init("benchTrialOperation")),
      correspondences: try c.decode([NativeC01InquiryArchiveCorrespondence].self, forKey: .init("correspondences")),
      originalObservationOperation: try c.decode(UUID.self, forKey: .init("originalObservationOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(reviewer, forKey: .init("reviewer"))
    try c.encode(intakeOperation, forKey: .init("intakeOperation"))
    try c.encode(measurements, forKey: .init("measurements"))
    try c.encode(benchTrialOperation, forKey: .init("benchTrialOperation"))
    try c.encode(correspondences, forKey: .init("correspondences"))
    try c.encode(originalObservationOperation, forKey: .init("originalObservationOperation"))
  }
}

extension NativeC01InquiryFinalReceipt {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "owner", "caseID", "caseOrdinal", "caseRevision", "sourceBirth", "sourcePins", "profile", "registry", "mandateOperation", "measurements", "benchTrialOperation", "auditOperation", "originalObservationOperation", "verifierRevision", "arrival", "player", "carrier", "inventoryRevision", "historicalEpoch", "physicalTime"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseOrdinal: try c.decode(UInt64.self, forKey: .init("caseOrdinal")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      sourcePins: try c.decode(NativeC01InquirySourcePins.self, forKey: .init("sourcePins")),
      profile: try c.decode(NativeC01InquiryProfileRef.self, forKey: .init("profile")),
      registry: try c.decode(NativeC01InquiryRegistryRef.self, forKey: .init("registry")),
      mandateOperation: try c.decode(UUID.self, forKey: .init("mandateOperation")),
      measurements: try c.decode(NativeC01InquiryMeasurementRefs.self, forKey: .init("measurements")),
      benchTrialOperation: try c.decode(UUID.self, forKey: .init("benchTrialOperation")),
      auditOperation: try c.decode(UUID.self, forKey: .init("auditOperation")),
      originalObservationOperation: try c.decode(UUID.self, forKey: .init("originalObservationOperation")),
      verifierRevision: try c.decode(String.self, forKey: .init("verifierRevision")),
      arrival: try c.decode(NativeMainStationDockReceipt.self, forKey: .init("arrival")),
      player: try c.decode(ActorIdentity.self, forKey: .init("player")),
      carrier: try c.decode(UUID.self, forKey: .init("carrier")),
      inventoryRevision: try c.decode(UInt64.self, forKey: .init("inventoryRevision")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseOrdinal, forKey: .init("caseOrdinal"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(sourcePins, forKey: .init("sourcePins"))
    try c.encode(profile, forKey: .init("profile"))
    try c.encode(registry, forKey: .init("registry"))
    try c.encode(mandateOperation, forKey: .init("mandateOperation"))
    try c.encode(measurements, forKey: .init("measurements"))
    try c.encode(benchTrialOperation, forKey: .init("benchTrialOperation"))
    try c.encode(auditOperation, forKey: .init("auditOperation"))
    try c.encode(originalObservationOperation, forKey: .init("originalObservationOperation"))
    try c.encode(verifierRevision, forKey: .init("verifierRevision"))
    try c.encode(arrival, forKey: .init("arrival"))
    try c.encode(player, forKey: .init("player"))
    try c.encode(carrier, forKey: .init("carrier"))
    try c.encode(inventoryRevision, forKey: .init("inventoryRevision"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquiryAudit {
  // Necessary containing-case identity only, never an audit verifier or live receiving grant.
  func matchesContainingCase(owner: UUID, sourceBirth: UUID) -> Bool {
    self.owner == owner && self.sourceBirth == sourceBirth
  }
}
