import Foundation

/// Manual input values, never a measured output or an active actuator grant.
enum NativeC01InquiryManualDetent: UInt8, Codable, Sendable, CaseIterable {
  case zero = 0, one, two, three, four, five, six, seven

  enum Direction: Sendable { case increase, decrease }

  var lagDegrees: Double { Double(rawValue) * 45 }
  var lagSeconds: Double { Double(rawValue) * 0.5 }

  func stepped(_ direction: Direction) -> Self {
    switch direction {
    case .increase:
      switch self {
      case .zero: .one
      case .one: .two
      case .two: .three
      case .three: .four
      case .four: .five
      case .five: .six
      case .six: .seven
      case .seven: .zero
      }
    case .decrease:
      switch self {
      case .zero: .seven
      case .one: .zero
      case .two: .one
      case .three: .two
      case .four: .three
      case .five: .four
      case .six: .five
      case .seven: .six
      }
    }
  }
}

/// Model data only. No decoder or memberwise initializer emits a pulse or
/// certifies an accepted native step, root, observed period or current phase.
struct NativeC01InquiryOscillatorData: Codable, Sendable, Equatable {
  let phase: NativeC01InquiryExactDyadic
  let cycle: UInt64
  let pulseSequence: UInt64

  var shapeValid: Bool {
    phase.shapeValid && phase < .period
      && cycle < UInt64.max && pulseSequence < UInt64.max
  }
}

struct NativeC01InquiryHeadModelData: Codable, Sendable, Equatable {
  static let lawRevision = "c01-inquiry-apparatus-law-v1"
  static let periodSeconds = 4.0

  // Independently retained physical model states. A control request cannot
  // replace either state with the source challenge's expected reading.
  let reference: NativeC01InquiryOscillatorData
  let output: NativeC01InquiryOscillatorData
  let appliedDetent: NativeC01InquiryManualDetent
  let appliedControlRevision: UInt64

  var shapeValid: Bool {
    reference.shapeValid && output.shapeValid
      && appliedControlRevision > 0 && appliedControlRevision < UInt64.max
  }
}

// Actual application/latching and event integration require the private
// accepted-step/model transport and R2 postwriter ACK. No live raw-dt step issuer,
// expected-output adapter, target button or decoded live arm exists here.

// e50/a7f: no oscillator integrator, latch or event producer is part of this DATA candidate.

enum NativeC01InquiryCommandKind: String, Codable, Sendable, Equatable {
  case setDetent = "set-detent"
  case requestTrial = "request-trial"
}

enum NativeC01InquiryTrialFailureReason: String, Codable, Sendable, Equatable {
  case unqualifiedInterval = "unqualified-interval"
  case unprovenEvent = "unproven-event"
  case unprovenPhase = "unproven-phase"
  case outputCount = "output-count"
  case angularError = "angular-error"
  case configurationChanged = "configuration-changed"
  case sourceUnavailable = "source-unavailable"
  case fixtureUnavailable = "fixture-unavailable"
  case interrupted
  case workBudgetExhausted = "work-budget-exhausted"
  case publicationContextChanged = "publication-context-changed"
}

enum NativeC01InquiryTrialResult: Codable, Sendable, Equatable {
  case failed(NativeC01InquiryTrialFailure)
  case passed
}

enum NativeC01InquiryControlBoundary: Codable, Sendable, Equatable {
  case betweenSteps(NativeC01InquiryBetweenStepBoundary)
  case withinStep(NativeC01InquiryWithinStepBoundary)
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryControlSetting: Codable, Sendable, Equatable {
  let detent: NativeC01InquiryManualDetent
  let revision: UInt64
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryControlConfiguration: Codable, Sendable, Equatable {
  let revision: UInt64
  let head0: NativeC01InquiryControlSetting
  let head1: NativeC01InquiryControlSetting
  let head2: NativeC01InquiryControlSetting
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryCommand: Codable, Sendable, Equatable {
  let id: UUID
  let sequence: UInt64
  let kind: NativeC01InquiryCommandKind
  let owner: UUID
  let ownerSession: UUID
  let caseID: UUID
  let priorCaseRevision: UInt64
  let caseRevision: UInt64
  let sourceBirth: UUID
  let challengeID: UUID
  let challengeOrdinal: Int
  let trialID: UUID
  let fixture: NativeC01InquiryFixtureRef
  let instrument: NativeC01InquiryInstrumentBinding
  let historicalReviewNonce: UUID
  let historicalEpoch: UUID
  let requested: NativeC01InquiryControlConfiguration
  let appliedBefore: NativeC01InquiryControlConfiguration
  let nativeOrder: UInt64
  let physicalTime: Double
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryMeasurementRefs: Codable, Sendable, Equatable {
  let channel0: UUID
  let channel1: UUID
  let channel2: UUID
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOutputCycle: Codable, Sendable, Equatable {
  let referenceStartSequence: UInt64
  let referenceEndSequence: UInt64
  let outputCount: UInt64
  let firstOutput: NativeC01InquiryPulseEvent?
  let lastOutput: NativeC01InquiryPulseEvent?
  let observedReferencePeriod: NativeC01InquiryDurationBounds
  let lagSeconds: NativeC01InquiryDurationBounds?
  let absoluteCircularErrorDegrees: NativeC01InquiryDurationBounds?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryChannelTrace: Codable, Sendable, Equatable {
  let challengeID: UUID
  let challengeOrdinal: Int
  let fixture: NativeC01InquiryFixtureRef
  let applied: NativeC01InquiryControlSetting
  let run: NativeC01InquiryQualifiedRun?
  let referenceEvents: [NativeC01InquiryPulseEvent]
  let cycles: [NativeC01InquiryOutputCycle]
  let openOutputWindow: NativeC01InquiryOpenOutputWindow?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryTrialFailure: Codable, Sendable, Equatable {
  let reason: NativeC01InquiryTrialFailureReason
  let physicalTime: Double
  let nativeOrder: UInt64
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryTrial: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let sourceBirth: UUID
  let trialID: UUID
  let armCommandID: UUID
  let measurements: NativeC01InquiryMeasurementRefs
  let requested: NativeC01InquiryControlConfiguration
  let instrument: NativeC01InquiryInstrumentBinding
  let historicalEpoch: UUID
  let channel0: NativeC01InquiryChannelTrace
  let channel1: NativeC01InquiryChannelTrace
  let channel2: NativeC01InquiryChannelTrace
  let result: NativeC01InquiryTrialResult
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryBench: Codable, Sendable, Equatable {
  let commands: [NativeC01InquiryCommand]
  let applications: [NativeC01InquiryControlApplication]
  let trials: [NativeC01InquiryTrial]
  let passingTrialOperation: UUID?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOpenOutputWindow: Codable, Sendable, Equatable {
  let referenceStartSequence: UInt64
  let outputCount: UInt64
  let firstOutput: NativeC01InquiryPulseEvent?
  let lastOutput: NativeC01InquiryPulseEvent?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryBetweenStepBoundary: Codable, Sendable, Equatable {
  let ownerSession: UUID
  let historicalEpoch: UUID
  let physicalTime: Double
  let nativeOrder: UInt64
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryWithinStepBoundary: Codable, Sendable, Equatable {
  let step: NativeC01InquiryStepData
  let offset: NativeC01InquiryExactDyadic
  let nativeOrder: UInt64
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryControlApplication: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let caseID: UUID
  let caseRevision: UInt64
  let sourceBirth: UUID
  let commandID: UUID
  let commandSequence: UInt64
  let challengeID: UUID
  let challengeOrdinal: Int
  let fixture: NativeC01InquiryFixtureRef
  let instrument: NativeC01InquiryInstrumentBinding
  let boundary: NativeC01InquiryControlBoundary
  let before: NativeC01InquiryControlSetting
  let after: NativeC01InquiryControlSetting
}

extension NativeC01InquiryControlSetting {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(revision)
    else { return false }
    return true
  }
}

extension NativeC01InquiryControlConfiguration {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(revision),
      head0.shapeValid,
      head1.shapeValid,
      head2.shapeValid
    else { return false }
    return true
  }
}

extension NativeC01InquiryCommand {
  var shapeValid: Bool {
    guard sequence < UInt64.max,
      NativeC01InquiryDataShape.revision(priorCaseRevision),
      NativeC01InquiryDataShape.revision(caseRevision),
      challengeOrdinal >= 0,
      fixture.shapeValid,
      instrument.shapeValid,
      requested.shapeValid,
      appliedBefore.shapeValid,
      nativeOrder < UInt64.max,
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return (0..<3).contains(challengeOrdinal)
      && NativeC01InquiryDataShape.adjacent(priorCaseRevision, caseRevision)
      && instrument.owner == owner && instrument.caseID == caseID
      && instrument.sourceBirth == sourceBirth && instrument.fixture == fixture
      && (kind != .setDetent || requested != appliedBefore)
  }
}

extension NativeC01InquiryMeasurementRefs {
  var shapeValid: Bool {
    return Set([channel0, channel1, channel2]).count == 3
  }
}

extension NativeC01InquiryOutputCycle {
  var shapeValid: Bool {
    guard referenceStartSequence < UInt64.max,
      referenceEndSequence < UInt64.max,
      outputCount < UInt64.max,
      (firstOutput.map { $0.shapeValid } ?? true),
      (lastOutput.map { $0.shapeValid } ?? true),
      observedReferencePeriod.shapeValid,
      (lagSeconds.map { $0.shapeValid } ?? true),
      (absoluteCircularErrorDegrees.map { $0.shapeValid } ?? true)
    else { return false }
    guard NativeC01InquiryDataShape.adjacent(referenceStartSequence, referenceEndSequence),
      observedReferencePeriod.lower > 0,
      (lagSeconds == nil) == (absoluteCircularErrorDegrees == nil)
    else { return false }
    if outputCount == 0 {
      return firstOutput == nil && lastOutput == nil && lagSeconds == nil
    }
    guard let firstOutput, let lastOutput, firstOutput.oscillator == .output,
      lastOutput.oscillator == .output, firstOutput.fixture == lastOutput.fixture,
      firstOutput.challengeID == lastOutput.challengeID
    else { return false }
    if outputCount == 1 { return firstOutput == lastOutput }
    return firstOutput.pulseSequence < lastOutput.pulseSequence
      && lastOutput.pulseSequence - firstOutput.pulseSequence == outputCount - 1
      && lagSeconds == nil
  }
}

extension NativeC01InquiryChannelTrace {
  var shapeValid: Bool {
    guard challengeOrdinal >= 0,
      fixture.shapeValid,
      applied.shapeValid,
      (run.map { $0.shapeValid } ?? true),
      referenceEvents.count <= 16384,
      referenceEvents.allSatisfy({ $0.shapeValid }),
      cycles.count <= 16384,
      cycles.allSatisfy({ $0.shapeValid }),
      (openOutputWindow.map { $0.shapeValid } ?? true)
    else { return false }
    guard (0..<3).contains(challengeOrdinal), referenceEvents.count <= 4,
      cycles.count <= 3, cycles.count <= max(0, referenceEvents.count - 1),
      run != nil || (referenceEvents.isEmpty && cycles.isEmpty && openOutputWindow == nil)
    else { return false }
    if let run {
      guard run.first.step.fixtureID == fixture.fixtureID,
        run.first.step.generation == fixture.generation
      else { return false }
    }
    for (index, event) in referenceEvents.enumerated() {
      guard event.oscillator == .reference && event.fixture == fixture,
        event.challengeID == challengeID && event.challengeOrdinal == challengeOrdinal,
        event.appliedControlRevision == applied.revision,
        run?.contains(event) == true
      else { return false }
      if index > 0 {
        guard NativeC01InquiryDataShape.adjacent(referenceEvents[index - 1].pulseSequence, event.pulseSequence),
          NativeC01InquiryDataShape.adjacent(referenceEvents[index - 1].cycle, event.cycle),
          referenceEvents[index - 1].step.sequence < event.step.sequence,
          referenceEvents[index - 1].step.clockEnd <= event.step.clockStart
        else { return false }
      }
    }
    for (index, cycle) in cycles.enumerated() {
      guard cycle.referenceStartSequence == referenceEvents[index].pulseSequence,
        cycle.referenceEndSequence == referenceEvents[index + 1].pulseSequence
      else { return false }
      for output in [cycle.firstOutput, cycle.lastOutput].compactMap({ $0 }) {
        guard output.fixture == fixture && output.challengeID == challengeID,
          output.challengeOrdinal == challengeOrdinal,
          output.appliedControlRevision == applied.revision, run?.contains(output) == true,
          Self.eventPrecedesData(referenceEvents[index], output, includingEqual: true),
          Self.eventPrecedesData(output, referenceEvents[index + 1], includingEqual: false)
        else { return false }
      }
    }
    if let openOutputWindow {
      guard openOutputWindow.referenceStartSequence == referenceEvents.last?.pulseSequence else { return false }
      for output in [openOutputWindow.firstOutput, openOutputWindow.lastOutput].compactMap({ $0 }) {
        guard output.fixture == fixture && output.challengeID == challengeID,
          output.challengeOrdinal == challengeOrdinal,
          output.appliedControlRevision == applied.revision, run?.contains(output) == true,
          let reference = referenceEvents.last,
          Self.eventPrecedesData(reference, output, includingEqual: true)
        else { return false }
      }
    }
    return true
  }

  /// Necessary retained event order only, not an accepted continuous step chain.
  /// Exact offsets own a shared boundary; rounded display labels cannot decide it.
  private static func eventPrecedesData(_ first: NativeC01InquiryPulseEvent,
    _ second: NativeC01InquiryPulseEvent, includingEqual: Bool) -> Bool
  {
    if first.step == second.step {
      return includingEqual ? first.offset <= second.offset : first.offset < second.offset
    }
    return first.step.sequence < second.step.sequence
      && first.step.clockEnd <= second.step.clockStart
  }
}

extension NativeC01InquiryTrialFailure {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.time(physicalTime),
      nativeOrder < UInt64.max
    else { return false }
    return true
  }
}

extension NativeC01InquiryTrial {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(caseRevision),
      measurements.shapeValid,
      requested.shapeValid,
      instrument.shapeValid,
      channel0.shapeValid,
      channel1.shapeValid,
      channel2.shapeValid,
      result.shapeValid
    else { return false }
    guard [channel0, channel1, channel2].map(\.challengeOrdinal) == [0, 1, 2],
      Set([channel0.challengeID, channel1.challengeID, channel2.challengeID]).count == 3,
      instrument.owner == owner, instrument.caseID == caseID, instrument.sourceBirth == sourceBirth,
      [channel0, channel1, channel2].allSatisfy({ $0.fixture == instrument.fixture }),
      [channel0, channel1, channel2].allSatisfy({ channel in
        guard let run = channel.run else { return true }
        return run.first.step.caseID == caseID && run.first.step.player == instrument.player
      })
    else { return false }
    switch result {
    case .failed: return true
    case .passed: return channel0.passingShape && channel1.passingShape && channel2.passingShape
    }
  }
}

extension NativeC01InquiryBench {
  var shapeValid: Bool {
    guard commands.count <= 16384,
      commands.allSatisfy({ $0.shapeValid }),
      applications.count <= 16384,
      applications.allSatisfy({ $0.shapeValid }),
      trials.count <= 16384,
      trials.allSatisfy({ $0.shapeValid })
    else { return false }
    guard Set(commands.map(\.id)).count == commands.count,
      Set(commands.map(\.historicalReviewNonce)).count == commands.count,
      Set(applications.map(\.operation)).count == applications.count,
      Set(applications.map(\.commandID)).count == applications.count,
      Set(trials.map(\.operation)).count == trials.count,
      Set(trials.map(\.trialID)).count == trials.count
    else { return false }
    var requests: [UUID: NativeC01InquiryCommand] = [:]
    for (index, command) in commands.enumerated() {
      guard command.sequence == UInt64(index) else { return false }
      requests[command.id] = command
    }
    for application in applications {
      guard let command = requests[application.commandID], command.kind == .setDetent,
        application.commandSequence == command.sequence, application.caseID == command.caseID,
        application.owner == command.owner, application.sourceBirth == command.sourceBirth,
        application.challengeID == command.challengeID,
        application.challengeOrdinal == command.challengeOrdinal, application.fixture == command.fixture,
        application.instrument == command.instrument,
        application.after == command.requested.setting(application.challengeOrdinal)
      else { return false }
      switch application.boundary {
      case .betweenSteps(let boundary):
        guard boundary.ownerSession == command.ownerSession else { return false }
      case .withinStep(let boundary):
        guard boundary.step.ownerSession == command.ownerSession else { return false }
      }
    }
    for trial in trials {
      guard let command = requests[trial.armCommandID], command.kind == .requestTrial,
        command.trialID == trial.trialID, command.caseID == trial.caseID,
        command.owner == trial.owner, command.sourceBirth == trial.sourceBirth,
        command.instrument == trial.instrument, command.requested == trial.requested
      else { return false }
    }
    let firstPass = trials.first { if case .passed = $0.result { return true }; return false }
    return passingTrialOperation == firstPass?.operation
  }
}

extension NativeC01InquiryOpenOutputWindow {
  var shapeValid: Bool {
    guard referenceStartSequence < UInt64.max,
      outputCount < UInt64.max,
      (firstOutput.map { $0.shapeValid } ?? true),
      (lastOutput.map { $0.shapeValid } ?? true)
    else { return false }
    if outputCount == 0 { return firstOutput == nil && lastOutput == nil }
    guard let firstOutput, let lastOutput, firstOutput.oscillator == .output,
      lastOutput.oscillator == .output, firstOutput.fixture == lastOutput.fixture,
      firstOutput.challengeID == lastOutput.challengeID
    else { return false }
    if outputCount == 1 { return firstOutput == lastOutput }
    return firstOutput.pulseSequence < lastOutput.pulseSequence
      && lastOutput.pulseSequence - firstOutput.pulseSequence == outputCount - 1
  }
}

extension NativeC01InquiryBetweenStepBoundary {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.time(physicalTime),
      nativeOrder < UInt64.max
    else { return false }
    return true
  }
}

extension NativeC01InquiryWithinStepBoundary {
  var shapeValid: Bool {
    guard step.shapeValid,
      offset.shapeValid,
      nativeOrder < UInt64.max
    else { return false }
    guard let usedD = try? NativeC01InquiryExactDyadic(binary64: step.usedD) else { return false }
    return offset <= usedD
  }
}

extension NativeC01InquiryControlApplication {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(caseRevision),
      commandSequence < UInt64.max,
      challengeOrdinal >= 0,
      fixture.shapeValid,
      instrument.shapeValid,
      boundary.shapeValid,
      before.shapeValid,
      after.shapeValid
    else { return false }
    guard (0..<3).contains(challengeOrdinal)
      && NativeC01InquiryDataShape.adjacent(before.revision, after.revision)
      && before.detent != after.detent && instrument.owner == owner
      && instrument.caseID == caseID && instrument.sourceBirth == sourceBirth
      && instrument.fixture == fixture
    else { return false }
    switch boundary {
    case .betweenSteps: return true
    case .withinStep(let boundary):
      return boundary.step.caseID == caseID && boundary.step.player == instrument.player
        && boundary.step.fixtureID == fixture.fixtureID && boundary.step.generation == fixture.generation
    }
  }
}

extension NativeC01InquiryTrialResult {
  var shapeValid: Bool {
    switch self {
    case .failed(let value): return value.shapeValid
    case .passed: return true
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "failed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryTrialFailure.self, forKey: .init("payload"))
      self = .failed(value)
    case "passed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind"])
      _ = c
      self = .passed
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
    case .failed(let value):
      try c.encode("failed", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .passed:
      try c.encode("passed", forKey: .init("kind"))
    }
  }
}

extension NativeC01InquiryControlBoundary {
  var shapeValid: Bool {
    switch self {
    case .betweenSteps(let value): return value.shapeValid
    case .withinStep(let value): return value.shapeValid
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "between-steps":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryBetweenStepBoundary.self, forKey: .init("payload"))
      self = .betweenSteps(value)
    case "within-step":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryWithinStepBoundary.self, forKey: .init("payload"))
      self = .withinStep(value)
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
    case .betweenSteps(let value):
      try c.encode("between-steps", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .withinStep(let value):
      try c.encode("within-step", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    }
  }
}

extension NativeC01InquiryControlSetting {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["detent", "revision"])
    self.init(
      detent: try c.decode(NativeC01InquiryManualDetent.self, forKey: .init("detent")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(detent, forKey: .init("detent"))
    try c.encode(revision, forKey: .init("revision"))
  }
}

extension NativeC01InquiryControlConfiguration {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["revision", "head0", "head1", "head2"])
    self.init(
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      head0: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("head0")),
      head1: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("head1")),
      head2: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("head2")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(head0, forKey: .init("head0"))
    try c.encode(head1, forKey: .init("head1"))
    try c.encode(head2, forKey: .init("head2"))
  }
}

extension NativeC01InquiryCommand {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["id", "sequence", "kind", "owner", "ownerSession", "caseID", "priorCaseRevision", "caseRevision", "sourceBirth", "challengeID", "challengeOrdinal", "trialID", "fixture", "instrument", "historicalReviewNonce", "historicalEpoch", "requested", "appliedBefore", "nativeOrder", "physicalTime"])
    self.init(
      id: try c.decode(UUID.self, forKey: .init("id")),
      sequence: try c.decode(UInt64.self, forKey: .init("sequence")),
      kind: try c.decode(NativeC01InquiryCommandKind.self, forKey: .init("kind")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      ownerSession: try c.decode(UUID.self, forKey: .init("ownerSession")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      priorCaseRevision: try c.decode(UInt64.self, forKey: .init("priorCaseRevision")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      trialID: try c.decode(UUID.self, forKey: .init("trialID")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      instrument: try c.decode(NativeC01InquiryInstrumentBinding.self, forKey: .init("instrument")),
      historicalReviewNonce: try c.decode(UUID.self, forKey: .init("historicalReviewNonce")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")),
      requested: try c.decode(NativeC01InquiryControlConfiguration.self, forKey: .init("requested")),
      appliedBefore: try c.decode(NativeC01InquiryControlConfiguration.self, forKey: .init("appliedBefore")),
      nativeOrder: try c.decode(UInt64.self, forKey: .init("nativeOrder")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(id, forKey: .init("id"))
    try c.encode(sequence, forKey: .init("sequence"))
    try c.encode(kind, forKey: .init("kind"))
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(ownerSession, forKey: .init("ownerSession"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(priorCaseRevision, forKey: .init("priorCaseRevision"))
    try c.encode(caseRevision, forKey: .init("caseRevision"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(trialID, forKey: .init("trialID"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(instrument, forKey: .init("instrument"))
    try c.encode(historicalReviewNonce, forKey: .init("historicalReviewNonce"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
    try c.encode(requested, forKey: .init("requested"))
    try c.encode(appliedBefore, forKey: .init("appliedBefore"))
    try c.encode(nativeOrder, forKey: .init("nativeOrder"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
  }
}

extension NativeC01InquiryMeasurementRefs {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["channel0", "channel1", "channel2"])
    self.init(
      channel0: try c.decode(UUID.self, forKey: .init("channel0")),
      channel1: try c.decode(UUID.self, forKey: .init("channel1")),
      channel2: try c.decode(UUID.self, forKey: .init("channel2")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(channel0, forKey: .init("channel0"))
    try c.encode(channel1, forKey: .init("channel1"))
    try c.encode(channel2, forKey: .init("channel2"))
  }
}

extension NativeC01InquiryOutputCycle {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["referenceStartSequence", "referenceEndSequence", "outputCount", "observedReferencePeriod"],
      optional: ["firstOutput", "lastOutput", "lagSeconds", "absoluteCircularErrorDegrees"])
    self.init(
      referenceStartSequence: try c.decode(UInt64.self, forKey: .init("referenceStartSequence")),
      referenceEndSequence: try c.decode(UInt64.self, forKey: .init("referenceEndSequence")),
      outputCount: try c.decode(UInt64.self, forKey: .init("outputCount")),
      firstOutput: try c.decodeIfPresent(NativeC01InquiryPulseEvent.self, forKey: .init("firstOutput")),
      lastOutput: try c.decodeIfPresent(NativeC01InquiryPulseEvent.self, forKey: .init("lastOutput")),
      observedReferencePeriod: try c.decode(NativeC01InquiryDurationBounds.self, forKey: .init("observedReferencePeriod")),
      lagSeconds: try c.decodeIfPresent(NativeC01InquiryDurationBounds.self, forKey: .init("lagSeconds")),
      absoluteCircularErrorDegrees: try c.decodeIfPresent(NativeC01InquiryDurationBounds.self, forKey: .init("absoluteCircularErrorDegrees")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(referenceStartSequence, forKey: .init("referenceStartSequence"))
    try c.encode(referenceEndSequence, forKey: .init("referenceEndSequence"))
    try c.encode(outputCount, forKey: .init("outputCount"))
    try c.encodeIfPresent(firstOutput, forKey: .init("firstOutput"))
    try c.encodeIfPresent(lastOutput, forKey: .init("lastOutput"))
    try c.encode(observedReferencePeriod, forKey: .init("observedReferencePeriod"))
    try c.encodeIfPresent(lagSeconds, forKey: .init("lagSeconds"))
    try c.encodeIfPresent(absoluteCircularErrorDegrees, forKey: .init("absoluteCircularErrorDegrees"))
  }
}

extension NativeC01InquiryChannelTrace {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["challengeID", "challengeOrdinal", "fixture", "applied", "referenceEvents", "cycles"],
      optional: ["run", "openOutputWindow"])
    self.init(
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      applied: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("applied")),
      run: try c.decodeIfPresent(NativeC01InquiryQualifiedRun.self, forKey: .init("run")),
      referenceEvents: try c.decode([NativeC01InquiryPulseEvent].self, forKey: .init("referenceEvents")),
      cycles: try c.decode([NativeC01InquiryOutputCycle].self, forKey: .init("cycles")),
      openOutputWindow: try c.decodeIfPresent(NativeC01InquiryOpenOutputWindow.self, forKey: .init("openOutputWindow")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(applied, forKey: .init("applied"))
    try c.encodeIfPresent(run, forKey: .init("run"))
    try c.encode(referenceEvents, forKey: .init("referenceEvents"))
    try c.encode(cycles, forKey: .init("cycles"))
    try c.encodeIfPresent(openOutputWindow, forKey: .init("openOutputWindow"))
  }
}

extension NativeC01InquiryTrialFailure {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["reason", "physicalTime", "nativeOrder"])
    self.init(
      reason: try c.decode(NativeC01InquiryTrialFailureReason.self, forKey: .init("reason")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      nativeOrder: try c.decode(UInt64.self, forKey: .init("nativeOrder")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(reason, forKey: .init("reason"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(nativeOrder, forKey: .init("nativeOrder"))
  }
}

extension NativeC01InquiryTrial {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "owner", "caseID", "caseRevision", "sourceBirth", "trialID", "armCommandID", "measurements", "requested", "instrument", "historicalEpoch", "channel0", "channel1", "channel2", "result"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      trialID: try c.decode(UUID.self, forKey: .init("trialID")),
      armCommandID: try c.decode(UUID.self, forKey: .init("armCommandID")),
      measurements: try c.decode(NativeC01InquiryMeasurementRefs.self, forKey: .init("measurements")),
      requested: try c.decode(NativeC01InquiryControlConfiguration.self, forKey: .init("requested")),
      instrument: try c.decode(NativeC01InquiryInstrumentBinding.self, forKey: .init("instrument")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")),
      channel0: try c.decode(NativeC01InquiryChannelTrace.self, forKey: .init("channel0")),
      channel1: try c.decode(NativeC01InquiryChannelTrace.self, forKey: .init("channel1")),
      channel2: try c.decode(NativeC01InquiryChannelTrace.self, forKey: .init("channel2")),
      result: try c.decode(NativeC01InquiryTrialResult.self, forKey: .init("result")))
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
    try c.encode(trialID, forKey: .init("trialID"))
    try c.encode(armCommandID, forKey: .init("armCommandID"))
    try c.encode(measurements, forKey: .init("measurements"))
    try c.encode(requested, forKey: .init("requested"))
    try c.encode(instrument, forKey: .init("instrument"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
    try c.encode(channel0, forKey: .init("channel0"))
    try c.encode(channel1, forKey: .init("channel1"))
    try c.encode(channel2, forKey: .init("channel2"))
    try c.encode(result, forKey: .init("result"))
  }
}

extension NativeC01InquiryBench {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["commands", "applications", "trials"],
      optional: ["passingTrialOperation"])
    self.init(
      commands: try c.decode([NativeC01InquiryCommand].self, forKey: .init("commands")),
      applications: try c.decode([NativeC01InquiryControlApplication].self, forKey: .init("applications")),
      trials: try c.decode([NativeC01InquiryTrial].self, forKey: .init("trials")),
      passingTrialOperation: try c.decodeIfPresent(UUID.self, forKey: .init("passingTrialOperation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(commands, forKey: .init("commands"))
    try c.encode(applications, forKey: .init("applications"))
    try c.encode(trials, forKey: .init("trials"))
    try c.encodeIfPresent(passingTrialOperation, forKey: .init("passingTrialOperation"))
  }
}

extension NativeC01InquiryOpenOutputWindow {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["referenceStartSequence", "outputCount"],
      optional: ["firstOutput", "lastOutput"])
    self.init(
      referenceStartSequence: try c.decode(UInt64.self, forKey: .init("referenceStartSequence")),
      outputCount: try c.decode(UInt64.self, forKey: .init("outputCount")),
      firstOutput: try c.decodeIfPresent(NativeC01InquiryPulseEvent.self, forKey: .init("firstOutput")),
      lastOutput: try c.decodeIfPresent(NativeC01InquiryPulseEvent.self, forKey: .init("lastOutput")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(referenceStartSequence, forKey: .init("referenceStartSequence"))
    try c.encode(outputCount, forKey: .init("outputCount"))
    try c.encodeIfPresent(firstOutput, forKey: .init("firstOutput"))
    try c.encodeIfPresent(lastOutput, forKey: .init("lastOutput"))
  }
}

extension NativeC01InquiryBetweenStepBoundary {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["ownerSession", "historicalEpoch", "physicalTime", "nativeOrder"])
    self.init(
      ownerSession: try c.decode(UUID.self, forKey: .init("ownerSession")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      nativeOrder: try c.decode(UInt64.self, forKey: .init("nativeOrder")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(ownerSession, forKey: .init("ownerSession"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(nativeOrder, forKey: .init("nativeOrder"))
  }
}

extension NativeC01InquiryWithinStepBoundary {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["step", "offset", "nativeOrder"])
    self.init(
      step: try c.decode(NativeC01InquiryStepData.self, forKey: .init("step")),
      offset: try c.decode(NativeC01InquiryExactDyadic.self, forKey: .init("offset")),
      nativeOrder: try c.decode(UInt64.self, forKey: .init("nativeOrder")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(step, forKey: .init("step"))
    try c.encode(offset, forKey: .init("offset"))
    try c.encode(nativeOrder, forKey: .init("nativeOrder"))
  }
}

extension NativeC01InquiryControlApplication {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "owner", "caseID", "caseRevision", "sourceBirth", "commandID", "commandSequence", "challengeID", "challengeOrdinal", "fixture", "instrument", "boundary", "before", "after"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseRevision: try c.decode(UInt64.self, forKey: .init("caseRevision")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      commandID: try c.decode(UUID.self, forKey: .init("commandID")),
      commandSequence: try c.decode(UInt64.self, forKey: .init("commandSequence")),
      challengeID: try c.decode(UUID.self, forKey: .init("challengeID")),
      challengeOrdinal: try c.decode(Int.self, forKey: .init("challengeOrdinal")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      instrument: try c.decode(NativeC01InquiryInstrumentBinding.self, forKey: .init("instrument")),
      boundary: try c.decode(NativeC01InquiryControlBoundary.self, forKey: .init("boundary")),
      before: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("before")),
      after: try c.decode(NativeC01InquiryControlSetting.self, forKey: .init("after")))
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
    try c.encode(commandID, forKey: .init("commandID"))
    try c.encode(commandSequence, forKey: .init("commandSequence"))
    try c.encode(challengeID, forKey: .init("challengeID"))
    try c.encode(challengeOrdinal, forKey: .init("challengeOrdinal"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(instrument, forKey: .init("instrument"))
    try c.encode(boundary, forKey: .init("boundary"))
    try c.encode(before, forKey: .init("before"))
    try c.encode(after, forKey: .init("after"))
  }
}

extension NativeC01InquiryControlConfiguration {
  func setting(_ ordinal: Int) -> NativeC01InquiryControlSetting? {
    switch ordinal { case 0: head0; case 1: head1; case 2: head2; default: nil }
  }
}
extension NativeC01InquiryChannelTrace {
  // Necessary DATA conditions only; this never certifies actual observation or model arithmetic.
  var passingShape: Bool {
    shapeValid && run?.qualifiedDuration.lowerAtLeastTwelve == true
      && referenceEvents.count == 4 && cycles.count == 3 && openOutputWindow == nil
      && cycles.allSatisfy {
        $0.outputCount == 1 && $0.lagSeconds != nil
          && ($0.absoluteCircularErrorDegrees.map { $0.upper <= 2 } ?? false)
      }
  }
}

extension NativeC01InquiryBench {
  // This direct containing-case join follows shallow internal validation. It
  // compares historical revisions to a bound; unrelated writes do not stale history.
  func matchesContainingCase(
    owner: UUID, caseID: UUID, sourceBirth: UUID, maximumRevision: UInt64,
    measurements: NativeC01InquiryMeasurementRefs?
  ) -> Bool {
    commands.allSatisfy {
      $0.owner == owner && $0.caseID == caseID && $0.sourceBirth == sourceBirth
        && $0.caseRevision <= maximumRevision
    } && applications.allSatisfy {
      $0.owner == owner && $0.caseID == caseID && $0.sourceBirth == sourceBirth
        && $0.caseRevision <= maximumRevision
    } && trials.allSatisfy {
      $0.owner == owner && $0.caseID == caseID && $0.sourceBirth == sourceBirth
        && $0.caseRevision <= maximumRevision && $0.measurements == measurements
    }
  }
}
