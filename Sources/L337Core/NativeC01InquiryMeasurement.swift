import Foundation

/// Retained numeric data only. Decoding or comparing this value certifies no
/// native step, observation, continuity, source, or live instrument authority.
struct NativeC01InquiryDurationBounds: Codable, Sendable, Equatable {
  enum Failure: Error, Sendable {
    case invalidBounds
    case nonfiniteArithmetic
  }

  let lower: Double
  let upper: Double

  static let zero = Self(zero: ())

  private init(zero: Void) {
    lower = 0
    upper = 0
  }

  private init(lower: Double, upper: Double) throws {
    guard Self.validEndpoint(lower), Self.validEndpoint(upper), lower <= upper else {
      throw Failure.invalidBounds
    }
    self.lower = lower
    self.upper = upper
  }

  /// A numeric classification, never a completed-measurement predicate.
  var lowerAtLeastTwelve: Bool { lower >= 12 }

  func adding(_ other: Self) throws -> Self {
    if self == .zero { return other }
    if other == .zero { return self }
    let low = lower + other.lower
    let high = upper + other.upper
    guard low.isFinite, high.isFinite else { throw Failure.nonfiniteArithmetic }
    let outwardHigh = high.nextUp
    guard outwardHigh.isFinite else { throw Failure.nonfiniteArithmetic }
    return try Self(lower: max(0, low.nextDown), upper: outwardHigh)
  }

  /// Numeric DATA only: enclose the exact difference of bounded model values.
  /// No rounded absolute-clock subtraction, sealed elapsed interval, continuous
  /// source history, measured period or earned observation is issued here.
  static func enclosingExactDifferenceData(high: NativeC01InquiryExactDyadic,
    low: NativeC01InquiryExactDyadic
  ) throws -> Self {
    guard high.shapeValid, low.shapeValid, low <= high else { throw Failure.invalidBounds }
    let difference = try high.subtracting(low)
    if difference.isZero { return .zero }
    let nearest = difference.roundedBinary64
    if let represented = try? NativeC01InquiryExactDyadic(binary64: nearest), represented == difference {
      return try Self(lower: nearest, upper: nearest)
    }
    // The exact type is bounded below5s, so both adjacent endpoints are finite.
    // If projection rounds to the exclusive model bound, re-import may refuse;
    // the same outward enclosure remains valid without widening that model.
    return try Self(lower: max(0, nearest.nextDown), upper: nearest.nextUp)
  }

  // Only a future actual sealed-step adapter in this file may call these raw
  // numeric helpers. They return data, not a seal; neither currently has callers.
  fileprivate static func singleton(_ value: Double) throws -> Self {
    try Self(lower: value, upper: value)
  }

  fileprivate static func nonnegativeDifference(high: Double, low: Double) throws -> Self {
    guard validEndpoint(high), validEndpoint(low), high >= low else {
      throw Failure.invalidBounds
    }
    if high == low { return .zero }
    let difference = high - low
    guard difference.isFinite, difference.nextUp.isFinite else {
      throw Failure.nonfiniteArithmetic
    }
    return try Self(lower: max(0, difference.nextDown), upper: difference.nextUp)
  }

  private static func validEndpoint(_ value: Double) -> Bool {
    value.isFinite && value >= 0 && value.sign != .minus
  }

  private struct RawKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: RawKey.self)
    guard Set(container.allKeys.map(\.stringValue)) == Set(["lowerBits", "upperBits"]) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid duration keys"))
    }
    func endpoint(_ name: String) throws -> Double {
      let key = RawKey(name)
      let word = try container.decode(String.self, forKey: key)
      guard word.utf8.count == 16,
        word.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
        let bits = UInt64(word, radix: 16)
      else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Invalid duration bit word")
      }
      let value = Double(bitPattern: bits)
      guard Self.validEndpoint(value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Invalid duration endpoint")
      }
      return value
    }
    let decodedLower = try endpoint("lowerBits")
    let decodedUpper = try endpoint("upperBits")
    guard decodedLower <= decodedUpper else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Reversed duration endpoints"))
    }
    lower = decodedLower
    upper = decodedUpper
  }

  func encode(to encoder: any Encoder) throws {
    func word(_ value: Double) -> String {
      let digits = String(value.bitPattern, radix: 16)
      return String(repeating: "0", count: 16 - digits.utf8.count) + digits
    }
    var container = encoder.container(keyedBy: RawKey.self)
    try container.encode(word(lower), forKey: RawKey("lowerBits"))
    try container.encode(word(upper), forKey: RawKey("upperBits"))
  }
}

enum NativeC01InquiryOscillator: String, Codable, Sendable, Equatable {
  case reference
  case output
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryFixtureRef: Codable, Sendable, Equatable {
  let fixtureID: UUID
  let generation: UInt64
  let admissionOperation: UUID
  let geometryRevision: String
  let geometryPins: NativeC01InquiryFixtureGeometryPins
  let metricRevision: String
  let lawRevision: String
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryInstrumentBinding: Codable, Sendable, Equatable {
  let owner: UUID
  let player: ActorIdentity
  let carrier: UUID
  let hullID: String
  let hullGeometrySHA256: String
  let sourceBirth: UUID
  let caseID: UUID
  let fixture: NativeC01InquiryFixtureRef
  let instrumentRevision: String
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryStepData: Codable, Sendable, Equatable {
  let ownerSession: UUID
  let sequence: UInt64
  let sceneEpoch: UUID
  let player: ActorIdentity
  let caseID: UUID
  let caseRevision: UInt64
  let fixtureID: UUID
  let generation: UInt64
  let clockStart: Double
  let clockEnd: Double
  let usedD: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryPulseEvent: Codable, Sendable, Equatable {
  let step: NativeC01InquiryStepData
  let fixture: NativeC01InquiryFixtureRef
  let challengeID: UUID
  let challengeOrdinal: Int
  let oscillator: NativeC01InquiryOscillator
  let appliedControlRevision: UInt64
  let pulseSequence: UInt64
  let cycle: UInt64
  let offset: NativeC01InquiryExactDyadic
  let clockLabel: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryObservationEndpoint: Codable, Sendable, Equatable {
  let step: NativeC01InquiryStepData
  let playerPose: ShipPose
  let receiverBinding: NativeC01InquiryFixtureBinding
  let surfaceRangeNative: Double
  let aimDegrees: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryQualifiedRun: Codable, Sendable, Equatable {
  let first: NativeC01InquiryObservationEndpoint
  let last: NativeC01InquiryObservationEndpoint
  let qualifiedStepCount: UInt64
  let qualifiedDuration: NativeC01InquiryDurationBounds
  let minSurfaceRangeNative: Double
  let maxSurfaceRangeNative: Double
  let maxAimDegrees: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryReferencePair: Codable, Sendable, Equatable {
  let first: NativeC01InquiryPulseEvent
  let second: NativeC01InquiryPulseEvent
  let observedPeriod: NativeC01InquiryDurationBounds
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryMeasurement: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let sourceBirth: UUID
  let mandateOperation: UUID
  let challengeID: UUID
  let challengeOrdinal: Int
  let fixture: NativeC01InquiryFixtureRef
  let instrument: NativeC01InquiryInstrumentBinding
  let inventoryRevision: UInt64
  let historicalEpoch: UUID
  let run: NativeC01InquiryQualifiedRun
  let referencePair: NativeC01InquiryReferencePair
}

extension NativeC01InquiryFixtureRef {
  var shapeValid: Bool {
    guard generation < UInt64.max,
      NativeC01InquiryDataShape.text(geometryRevision),
      geometryPins.shapeValid,
      NativeC01InquiryDataShape.text(metricRevision),
      NativeC01InquiryDataShape.text(lawRevision)
    else { return false }
    return generation > 0 && geometryRevision == NativeC01InquiryFixtureGeometry.revision
      && metricRevision == NativeC01InquiryFixtureGeometry.metricRevision
      && lawRevision == NativeC01InquiryHeadModelData.lawRevision
  }
}

extension NativeC01InquiryInstrumentBinding {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.actor(player),
      NativeC01InquiryDataShape.text(hullID),
      ScriptCompletionReceipt.validDigest(hullGeometrySHA256),
      fixture.shapeValid,
      NativeC01InquiryDataShape.text(instrumentRevision)
    else { return false }
    return player.entity == 0 && fixture.shapeValid
  }
}

extension NativeC01InquiryStepData {
  var shapeValid: Bool {
    guard sequence < UInt64.max,
      NativeC01InquiryDataShape.actor(player),
      NativeC01InquiryDataShape.revision(caseRevision),
      generation < UInt64.max,
      NativeC01InquiryDataShape.time(clockStart),
      NativeC01InquiryDataShape.time(clockEnd),
      usedD.isFinite && usedD >= 0 && usedD.sign != .minus
    else { return false }
    return player.entity == 0 && generation > 0 && usedD > 0 && usedD <= 0.1
      && clockEnd == clockStart + usedD && clockEnd > clockStart
  }
}

extension NativeC01InquiryPulseEvent {
  var shapeValid: Bool {
    guard step.shapeValid,
      fixture.shapeValid,
      challengeOrdinal >= 0,
      NativeC01InquiryDataShape.revision(appliedControlRevision),
      pulseSequence > 0 && pulseSequence < UInt64.max,
      cycle > 0 && cycle < UInt64.max,
      offset.shapeValid,
      clockLabel.isFinite && clockLabel >= 0 && clockLabel.sign != .minus
    else { return false }
    guard let usedD = try? NativeC01InquiryExactDyadic(binary64: step.usedD),
      let projectedLabel = try? offset.roundedClockLabel(after: step.clockStart) else { return false }
    return (0..<3).contains(challengeOrdinal) && step.fixtureID == fixture.fixtureID
      && step.generation == fixture.generation && !offset.isZero && offset <= usedD
      && clockLabel >= step.clockStart && clockLabel <= step.clockEnd
      && clockLabel.bitPattern == projectedLabel.bitPattern
  }
}

extension NativeC01InquiryObservationEndpoint {
  var shapeValid: Bool {
    guard step.shapeValid,
      NativeC01InquiryDataShape.pose(playerPose),
      receiverBinding.shapeValid,
      surfaceRangeNative.isFinite && surfaceRangeNative >= 0 && surfaceRangeNative.sign != .minus,
      aimDegrees.isFinite && aimDegrees >= 0 && aimDegrees.sign != .minus
    else { return false }
    return (250...1500).contains(surfaceRangeNative) && aimDegrees <= 2
      && receiverBinding.actor.system == step.player.system
      && receiverBinding.actor.visit == step.player.visit
  }
}

extension NativeC01InquiryQualifiedRun {
  var shapeValid: Bool {
    guard first.shapeValid,
      last.shapeValid,
      qualifiedStepCount < UInt64.max,
      qualifiedDuration.shapeValid,
      minSurfaceRangeNative.isFinite && minSurfaceRangeNative >= 0 && minSurfaceRangeNative.sign != .minus,
      maxSurfaceRangeNative.isFinite && maxSurfaceRangeNative >= 0 && maxSurfaceRangeNative.sign != .minus,
      maxAimDegrees.isFinite && maxAimDegrees >= 0 && maxAimDegrees.sign != .minus
    else { return false }
    guard qualifiedStepCount > 0, minSurfaceRangeNative >= 250,
      maxSurfaceRangeNative <= 1500, minSurfaceRangeNative <= maxSurfaceRangeNative,
      maxAimDegrees <= 2, first.step.ownerSession == last.step.ownerSession,
      first.step.sceneEpoch == last.step.sceneEpoch, first.step.player == last.step.player,
      first.step.caseID == last.step.caseID, first.step.fixtureID == last.step.fixtureID,
      first.step.generation == last.step.generation, first.receiverBinding == last.receiverBinding,
      last.step.sequence >= first.step.sequence,
      last.step.sequence - first.step.sequence == qualifiedStepCount - 1,
      last.step.clockEnd >= first.step.clockEnd
    else { return false }
    guard minSurfaceRangeNative <= first.surfaceRangeNative,
      first.surfaceRangeNative <= maxSurfaceRangeNative,
      minSurfaceRangeNative <= last.surfaceRangeNative,
      last.surfaceRangeNative <= maxSurfaceRangeNative,
      first.aimDegrees <= maxAimDegrees, last.aimDegrees <= maxAimDegrees
    else { return false }
    // Repeated step counters must describe the same retained native step DATA.
    // Otherwise ordered endpoints cannot reverse or overlap their step times.
    // These necessary joins do not prove the missing intervening observations.
    if first.step.sequence == last.step.sequence { return first.step == last.step }
    return last.step.clockStart >= first.step.clockEnd
  }
}

extension NativeC01InquiryReferencePair {
  var shapeValid: Bool {
    guard first.shapeValid,
      second.shapeValid,
      observedPeriod.shapeValid
    else { return false }
    return first.oscillator == .reference && second.oscillator == .reference
      && first.fixture == second.fixture && first.challengeID == second.challengeID
      && first.challengeOrdinal == second.challengeOrdinal
      && first.appliedControlRevision == second.appliedControlRevision
      && first.step.ownerSession == second.step.ownerSession
      && first.step.sceneEpoch == second.step.sceneEpoch && first.step.player == second.step.player
      && first.step.caseID == second.step.caseID
      && NativeC01InquiryDataShape.adjacent(first.pulseSequence, second.pulseSequence)
      && NativeC01InquiryDataShape.adjacent(first.cycle, second.cycle)
      && second.step.sequence > first.step.sequence
      && second.step.clockStart >= first.step.clockEnd && observedPeriod.lower > 0
  }
}

extension NativeC01InquiryMeasurement {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(caseRevision),
      challengeOrdinal >= 0,
      fixture.shapeValid,
      instrument.shapeValid,
      NativeC01InquiryDataShape.inventoryRevision(inventoryRevision),
      run.shapeValid,
      referencePair.shapeValid
    else { return false }
    return (0..<3).contains(challengeOrdinal) && run.qualifiedDuration.lowerAtLeastTwelve
      && instrument.owner == owner && instrument.caseID == caseID && instrument.fixture == fixture
      && instrument.sourceBirth == sourceBirth && referencePair.first.fixture == fixture
      && run.first.step.caseID == caseID && run.first.step.player == instrument.player
      && referencePair.first.challengeID == challengeID
      && referencePair.first.challengeOrdinal == challengeOrdinal
      && run.contains(referencePair.first) && run.contains(referencePair.second)
  }
}

extension NativeC01InquiryFixtureRef {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["fixtureID", "generation", "admissionOperation", "geometryRevision", "geometryPins", "metricRevision", "lawRevision"])
    self.init(
      fixtureID: try c.decode(UUID.self, forKey: .init("fixtureID")),
      generation: try c.decode(UInt64.self, forKey: .init("generation")),
      admissionOperation: try c.decode(UUID.self, forKey: .init("admissionOperation")),
      geometryRevision: try c.decode(String.self, forKey: .init("geometryRevision")),
      geometryPins: try c.decode(NativeC01InquiryFixtureGeometryPins.self, forKey: .init("geometryPins")),
      metricRevision: try c.decode(String.self, forKey: .init("metricRevision")),
      lawRevision: try c.decode(String.self, forKey: .init("lawRevision")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(fixtureID, forKey: .init("fixtureID"))
    try c.encode(generation, forKey: .init("generation"))
    try c.encode(admissionOperation, forKey: .init("admissionOperation"))
    try c.encode(geometryRevision, forKey: .init("geometryRevision"))
    try c.encode(geometryPins, forKey: .init("geometryPins"))
    try c.encode(metricRevision, forKey: .init("metricRevision"))
    try c.encode(lawRevision, forKey: .init("lawRevision"))
  }
}

extension NativeC01InquiryInstrumentBinding {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["owner", "player", "carrier", "hullID", "hullGeometrySHA256", "sourceBirth", "caseID", "fixture", "instrumentRevision"])
    self.init(
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      player: try c.decode(ActorIdentity.self, forKey: .init("player")),
      carrier: try c.decode(UUID.self, forKey: .init("carrier")),
      hullID: try c.decode(String.self, forKey: .init("hullID")),
      hullGeometrySHA256: try c.decode(String.self, forKey: .init("hullGeometrySHA256")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      instrumentRevision: try c.decode(String.self, forKey: .init("instrumentRevision")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(player, forKey: .init("player"))
    try c.encode(carrier, forKey: .init("carrier"))
    try c.encode(hullID, forKey: .init("hullID"))
    try c.encode(hullGeometrySHA256, forKey: .init("hullGeometrySHA256"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(instrumentRevision, forKey: .init("instrumentRevision"))
  }
}

extension NativeC01InquiryStepData {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["ownerSession", "sequence", "sceneEpoch", "player", "caseID", "caseRevision", "fixtureID", "generation", "clockStart", "clockEnd", "usedD"])
    self.init(
      ownerSession: try c.decode(UUID.self, forKey: .init("ownerSession")),
      sequence: try c.decode(UInt64.self, forKey: .init("sequence")),
      sceneEpoch: try c.decode(UUID.self, forKey: .init("sceneEpoch")),
      player: try c.decode(ActorIdentity.self, forKey: .init("player")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      fixtureID: try c.decode(UUID.self, forKey: .init("fixtureID")),
      generation: try c.decode(UInt64.self, forKey: .init("generation")),
      clockStart: try c.decode(Double.self, forKey: .init("clockStart")),
      clockEnd: try c.decode(Double.self, forKey: .init("clockEnd")),
      usedD: try c.decode(Double.self, forKey: .init("usedD")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(ownerSession, forKey: .init("ownerSession"))
    try c.encode(sequence, forKey: .init("sequence"))
    try c.encode(sceneEpoch, forKey: .init("sceneEpoch"))
    try c.encode(player, forKey: .init("player"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(fixtureID, forKey: .init("fixtureID"))
    try c.encode(generation, forKey: .init("generation"))
    try c.encode(clockStart, forKey: .init("clockStart"))
    try c.encode(clockEnd, forKey: .init("clockEnd"))
    try c.encode(usedD, forKey: .init("usedD"))
  }
}

extension NativeC01InquiryPulseEvent {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["step", "fixture", "challengeID", "challengeOrdinal", "oscillator", "appliedControlRevision", "pulseSequence", "cycle", "offset", "clockLabel"])
    self.init(
      step: try c.decode(NativeC01InquiryStepData.self, forKey: .init("step")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      oscillator: try c.decode(NativeC01InquiryOscillator.self, forKey: .init("oscillator")),
      appliedControlRevision: try c.decode(UInt64.self, forKey: .init("appliedControlRevision")),
      pulseSequence: try c.decode(UInt64.self, forKey: .init("pulseSequence")),
      cycle: try c.decode(UInt64.self, forKey: .init("cycle")),
      offset: try c.decode(NativeC01InquiryExactDyadic.self, forKey: .init("offset")),
      clockLabel: try c.decode(Double.self, forKey: .init("clockLabel")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(step, forKey: .init("step"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(oscillator, forKey: .init("oscillator"))
    try c.encode(appliedControlRevision, forKey: .init("appliedControlRevision"))
    try c.encode(pulseSequence, forKey: .init("pulseSequence"))
    try c.encode(cycle, forKey: .init("cycle"))
    try c.encode(offset, forKey: .init("offset"))
    try c.encode(clockLabel, forKey: .init("clockLabel"))
  }
}

extension NativeC01InquiryObservationEndpoint {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["step", "playerPose", "receiverBinding", "surfaceRangeNative", "aimDegrees"])
    self.init(
      step: try c.decode(NativeC01InquiryStepData.self, forKey: .init("step")),
      playerPose: try c.decode(ShipPose.self, forKey: .init("playerPose")),
      receiverBinding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("receiverBinding")),
      surfaceRangeNative: try c.decode(Double.self, forKey: .init("surfaceRangeNative")),
      aimDegrees: try c.decode(Double.self, forKey: .init("aimDegrees")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(step, forKey: .init("step"))
    try c.encode(playerPose, forKey: .init("playerPose"))
    try c.encode(receiverBinding, forKey: .init("receiverBinding"))
    try c.encode(surfaceRangeNative, forKey: .init("surfaceRangeNative"))
    try c.encode(aimDegrees, forKey: .init("aimDegrees"))
  }
}

extension NativeC01InquiryQualifiedRun {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["first", "last", "qualifiedStepCount", "qualifiedDuration", "minSurfaceRangeNative", "maxSurfaceRangeNative", "maxAimDegrees"])
    self.init(
      first: try c.decode(NativeC01InquiryObservationEndpoint.self, forKey: .init("first")),
      last: try c.decode(NativeC01InquiryObservationEndpoint.self, forKey: .init("last")),
      qualifiedStepCount: try c.decode(UInt64.self, forKey: .init("qualifiedStepCount")),
      qualifiedDuration: try c.decode(NativeC01InquiryDurationBounds.self, forKey: .init("qualifiedDuration")),
      minSurfaceRangeNative: try c.decode(Double.self, forKey: .init("minSurfaceRangeNative")),
      maxSurfaceRangeNative: try c.decode(Double.self, forKey: .init("maxSurfaceRangeNative")),
      maxAimDegrees: try c.decode(Double.self, forKey: .init("maxAimDegrees")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(first, forKey: .init("first"))
    try c.encode(last, forKey: .init("last"))
    try c.encode(qualifiedStepCount, forKey: .init("qualifiedStepCount"))
    try c.encode(qualifiedDuration, forKey: .init("qualifiedDuration"))
    try c.encode(minSurfaceRangeNative, forKey: .init("minSurfaceRangeNative"))
    try c.encode(maxSurfaceRangeNative, forKey: .init("maxSurfaceRangeNative"))
    try c.encode(maxAimDegrees, forKey: .init("maxAimDegrees"))
  }
}

extension NativeC01InquiryReferencePair {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["first", "second", "observedPeriod"])
    self.init(
      first: try c.decode(NativeC01InquiryPulseEvent.self, forKey: .init("first")),
      second: try c.decode(NativeC01InquiryPulseEvent.self, forKey: .init("second")),
      observedPeriod: try c.decode(NativeC01InquiryDurationBounds.self, forKey: .init("observedPeriod")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(first, forKey: .init("first"))
    try c.encode(second, forKey: .init("second"))
    try c.encode(observedPeriod, forKey: .init("observedPeriod"))
  }
}

extension NativeC01InquiryMeasurement {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "owner", "caseID", "caseRevision", "sourceBirth", "mandateOperation", "challengeID", "challengeOrdinal", "fixture", "instrument", "inventoryRevision", "historicalEpoch", "run", "referencePair"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      mandateOperation: try c.decode(UUID.self, forKey: .init("mandateOperation")),
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      instrument: try c.decode(NativeC01InquiryInstrumentBinding.self, forKey: .init("instrument")),
      inventoryRevision: try c.decode(UInt64.self, forKey: .init("inventoryRevision")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")),
      run: try c.decode(NativeC01InquiryQualifiedRun.self, forKey: .init("run")),
      referencePair: try c.decode(NativeC01InquiryReferencePair.self, forKey: .init("referencePair")))
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
    try c.encode(mandateOperation, forKey: .init("mandateOperation"))
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(instrument, forKey: .init("instrument"))
    try c.encode(inventoryRevision, forKey: .init("inventoryRevision"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
    try c.encode(run, forKey: .init("run"))
    try c.encode(referencePair, forKey: .init("referencePair"))
  }
}

extension NativeC01InquiryFixtureRef {
  func matches(_ generation: NativeC01InquiryFixtureGeneration) -> Bool {
    fixtureID == generation.fixtureID && self.generation == generation.generation
      && admissionOperation == generation.admissionOperation
      && geometryRevision == generation.geometryRevision && geometryPins == generation.geometryPins
      && metricRevision == generation.metricRevision && lawRevision == generation.lawRevision
  }
}
extension NativeC01InquiryQualifiedRun {
  func contains(_ event: NativeC01InquiryPulseEvent) -> Bool {
    guard shapeValid, event.shapeValid,
      event.step.ownerSession == first.step.ownerSession
        && event.step.sceneEpoch == first.step.sceneEpoch && event.step.player == first.step.player
        && event.step.caseID == first.step.caseID && event.step.fixtureID == first.step.fixtureID
        && event.step.generation == first.step.generation
        && event.step.sequence >= first.step.sequence && event.step.sequence <= last.step.sequence,
      event.step.clockStart >= first.step.clockStart, event.step.clockEnd <= last.step.clockEnd
    else { return false }
    // A matching retained counter cannot stand for conflicting endpoint data.
    // Window membership alone still proves no missing intermediate observation.
    if event.step.sequence == first.step.sequence && event.step != first.step { return false }
    if event.step.sequence == last.step.sequence && event.step != last.step { return false }
    return true
  }
}

extension NativeC01InquiryDurationBounds {
  var shapeValid: Bool {
    lower.isFinite && upper.isFinite && lower.sign != .minus && upper.sign != .minus
      && lower >= 0 && lower <= upper
  }
}
