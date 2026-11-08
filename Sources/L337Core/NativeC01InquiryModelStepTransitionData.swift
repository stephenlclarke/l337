import Foundation

/// Pure transition planning. Drafts are not native pulses, ACKs, qualified
/// observations or publication payloads. No function mutates attained state.
enum NativeC01InquiryModelStepTransitionData {
  enum Failure: Error, Sendable {
    case invalidInput, invalidCursor, invalidPending, revisionOverflow, invalidTimeline
  }

  struct PendingControl: Sendable, Equatable {
    let commandID: UUID
    let challengeID: UUID
    let challengeOrdinal: Int
    let acknowledgedOrder: UInt64
    let requested: NativeC01InquiryControlSetting
  }

  struct PulseDraft: Sendable, Equatable {
    let challengeID: UUID
    let challengeOrdinal: Int
    let oscillator: NativeC01InquiryOscillator
    let offset: NativeC01InquiryExactDyadic
    let appliedControlRevision: UInt64
    let pulseSequence: UInt64
    let cycle: UInt64
  }

  struct LatchDraft: Sendable, Equatable {
    let request: PendingControl
    let offset: NativeC01InquiryExactDyadic
    let before: NativeC01InquiryControlSetting
    let after: NativeC01InquiryControlSetting
  }

  /// All pulses at this exact offset precede every latch at this offset.
  /// FIFO request order governs latches, not their array/channel creation order.
  struct Point: Sendable, Equatable {
    let offset: NativeC01InquiryExactDyadic
    /// Rounded diagnostic DATA only; ordering and grouping use exact offset.
    let clockLabel: Double
    let pulses: [PulseDraft]
    let latches: [LatchDraft]
  }

  struct Transition: Sendable, Equatable {
    let step: NativeC01InquiryStepData
    let fixture: NativeC01InquiryFixtureRef
    let before: NativeC01InquiryModelSnapshot
    let after: NativeC01InquiryModelSnapshot
    let points: [Point]
    let unapplied: [PendingControl]

    var nativeOperationCount: Int {
      points.count + points.reduce(0) { $0 + $1.latches.count }
    }
  }

  // The existing per-case command/application bound; not a new attempt limit.
  private static let maximumRequests = 16_384

  static func prepare(before: NativeC01InquiryModelSnapshot, step: NativeC01InquiryStepData,
    fixture: NativeC01InquiryFixtureRef, challengeIDs: [UUID], pending: [PendingControl]
  ) throws -> Transition {
    guard before.shapeValid, step.shapeValid, fixture.shapeValid,
      fixture.fixtureID == step.fixtureID, fixture.generation == step.generation,
      challengeIDs.count == 3, Set(challengeIDs).count == 3,
      pending.count <= maximumRequests
    else { throw Failure.invalidInput }
    guard before.physicalTime == step.clockStart else { throw Failure.invalidCursor }
    if let previous = before.lastStep {
      let sequence = previous.sequence.addingReportingOverflow(1)
      guard !sequence.overflow, sequence.partialValue == step.sequence,
        previous.ownerSession == step.ownerSession, previous.sceneEpoch == step.sceneEpoch,
        previous.player == step.player, previous.caseID == step.caseID,
        previous.fixtureID == step.fixtureID, previous.generation == step.generation,
        previous.clockEnd == step.clockStart
      else { throw Failure.invalidCursor }
    }
    guard Set(pending.map(\.commandID)).count == pending.count,
      Set(pending.map(\.acknowledgedOrder)).count == pending.count,
      pending.allSatisfy({
        (0..<3).contains($0.challengeOrdinal) && $0.acknowledgedOrder > 0
          && $0.acknowledgedOrder < UInt64.max && $0.requested.shapeValid
      })
    else { throw Failure.invalidPending }
    for request in pending {
      guard request.challengeID == challengeIDs[request.challengeOrdinal] else {
        throw Failure.invalidPending
      }
    }
    let ordered = pending.sorted { $0.acknowledgedOrder < $1.acknowledgedOrder }
    let heads = [before.head0, before.head1, before.head2]
    let requests = (0..<3).map { ordinal in ordered.filter { $0.challengeOrdinal == ordinal } }
    for ordinal in 0..<3 {
      try validateSettingChain(requests[ordinal], initial: .init(
        detent: heads[ordinal].appliedDetent, revision: heads[ordinal].appliedControlRevision))
    }
    let usedD = try NativeC01InquiryExactDyadic(binary64: step.usedD)
    var afterHeads: [NativeC01InquiryHeadModelData] = []
    var pulses: [PulseDraft] = []
    var latches: [LatchDraft] = []
    var unapplied: [PendingControl] = []
    for ordinal in 0..<3 {
      let result = try advanceHead(heads[ordinal], ordinal: ordinal,
        challengeID: challengeIDs[ordinal], usedD: usedD, requests: requests[ordinal])
      afterHeads.append(result.head)
      pulses += result.pulses
      latches += result.latches
      unapplied += result.unapplied
    }
    guard pulses.count <= 6, latches.count <= maximumRequests else {
      throw Failure.invalidTimeline
    }
    let after = NativeC01InquiryModelSnapshot(physicalTime: step.clockEnd, lastStep: step,
      head0: afterHeads[0], head1: afterHeads[1], head2: afterHeads[2])
    guard after.shapeValid else { throw Failure.invalidInput }
    return .init(step: step, fixture: fixture, before: before, after: after,
      points: try timeline(pulses, latches: latches, clockStart: step.clockStart),
      unapplied: unapplied.sorted { $0.acknowledgedOrder < $1.acknowledgedOrder })
  }

  private struct HeadResult {
    let head: NativeC01InquiryHeadModelData
    let pulses: [PulseDraft]
    let latches: [LatchDraft]
    let unapplied: [PendingControl]
  }

  private static func validateSettingChain(_ requests: [PendingControl],
    initial: NativeC01InquiryControlSetting) throws
  {
    var current = initial
    for request in requests {
      let next = current.revision.addingReportingOverflow(1)
      guard !next.overflow, next.partialValue < UInt64(Int64.max) else {
        throw Failure.revisionOverflow
      }
      guard request.requested.revision == next.partialValue,
        request.requested.detent != current.detent
      else { throw Failure.invalidPending }
      current = request.requested
    }
  }

  private static func advanceHead(_ before: NativeC01InquiryHeadModelData,
    ordinal: Int, challengeID: UUID, usedD: NativeC01InquiryExactDyadic,
    requests: [PendingControl]) throws -> HeadResult
  {
    let reference = try advance(before.reference, usedD: usedD)
    var pulses: [PulseDraft] = []
    if let offset = reference.crossingOffset {
      pulses.append(draft(reference, offset: offset, oscillator: .reference,
        ordinal: ordinal, challengeID: challengeID, revision: before.appliedControlRevision))
    }
    guard let boundary = reference.crossingOffset, !requests.isEmpty else {
      let output = try advance(before.output, usedD: usedD)
      if let offset = output.crossingOffset {
        pulses.append(draft(output, offset: offset, oscillator: .output,
          ordinal: ordinal, challengeID: challengeID, revision: before.appliedControlRevision))
      }
      return .init(head: .init(reference: data(reference), output: data(output),
        appliedDetent: before.appliedDetent, appliedControlRevision: before.appliedControlRevision),
        pulses: pulses, latches: [], unapplied: requests)
    }
    // Only the prefix is evaluated under the old output state. Its old future
    // crossing after the latch must never escape into the returned timeline.
    let prefix = try advance(before.output, usedD: boundary)
    if let offset = prefix.crossingOffset {
      pulses.append(draft(prefix, offset: offset, oscillator: .output,
        ordinal: ordinal, challengeID: challengeID, revision: before.appliedControlRevision))
    }
    var setting = NativeC01InquiryControlSetting(
      detent: before.appliedDetent, revision: before.appliedControlRevision)
    var latches: [LatchDraft] = []
    for request in requests {
      latches.append(.init(request: request, offset: boundary, before: setting, after: request.requested))
      setting = request.requested
    }
    // Intermediate FIFO settings consume no time and emit no edge. Only the
    // last setting owns the remaining source interval, with old counters retained.
    let phase = try NativeC01InquiryExactModelArithmetic.latchedPhaseData(setting.detent)
    var output = NativeC01InquiryOscillatorData(
      phase: phase, cycle: prefix.cycle, pulseSequence: prefix.pulseSequence)
    let suffix = try usedD.subtracting(boundary)
    if !suffix.isZero {
      let advanced = try advance(output, usedD: suffix)
      // Every nonzero detent lag is >=0.5s, and zero waits the existing 4s period.
      // Thus no freshly reset output can cross in the remaining <=0.1s.
      guard advanced.crossingOffset == nil else { throw Failure.invalidTimeline }
      output = data(advanced)
    }
    return .init(head: .init(reference: data(reference), output: output,
      appliedDetent: setting.detent, appliedControlRevision: setting.revision),
      pulses: pulses, latches: latches, unapplied: [])
  }

  private static func advance(_ value: NativeC01InquiryOscillatorData,
    usedD: NativeC01InquiryExactDyadic) throws -> NativeC01InquiryExactModelArithmetic.Advance
  {
    try NativeC01InquiryExactModelArithmetic.advance(phase: value.phase, cycle: value.cycle,
      pulseSequence: value.pulseSequence, usedD: usedD)
  }

  private static func data(_ value: NativeC01InquiryExactModelArithmetic.Advance)
    -> NativeC01InquiryOscillatorData
  {
    .init(phase: value.phase, cycle: value.cycle, pulseSequence: value.pulseSequence)
  }

  private static func draft(_ value: NativeC01InquiryExactModelArithmetic.Advance,
    offset: NativeC01InquiryExactDyadic, oscillator: NativeC01InquiryOscillator,
    ordinal: Int, challengeID: UUID, revision: UInt64) -> PulseDraft
  {
    .init(challengeID: challengeID, challengeOrdinal: ordinal, oscillator: oscillator,
      offset: offset, appliedControlRevision: revision,
      pulseSequence: value.pulseSequence, cycle: value.cycle)
  }

  private static func timeline(_ pulses: [PulseDraft], latches: [LatchDraft],
    clockStart: Double
  ) throws -> [Point] {
    let sortedPulses = pulses.sorted {
      if $0.offset != $1.offset { return $0.offset < $1.offset }
      if $0.challengeOrdinal != $1.challengeOrdinal { return $0.challengeOrdinal < $1.challengeOrdinal }
      return $0.oscillator == .reference && $1.oscillator == .output
    }
    var points: [Point] = []
    for pulse in sortedPulses {
      if let last = points.last, last.offset == pulse.offset {
        points[points.count - 1] = .init(offset: last.offset, clockLabel: last.clockLabel,
          pulses: last.pulses + [pulse], latches: [])
      } else {
        points.append(.init(offset: pulse.offset,
          clockLabel: try pulse.offset.roundedClockLabel(after: clockStart),
          pulses: [pulse], latches: []))
      }
    }
    let sortedLatches = latches.sorted {
      if $0.offset != $1.offset { return $0.offset < $1.offset }
      return $0.request.acknowledgedOrder < $1.request.acknowledgedOrder
    }
    var cursor = 0
    for index in points.indices {
      var atBoundary: [LatchDraft] = []
      while cursor < sortedLatches.count, sortedLatches[cursor].offset == points[index].offset {
        atBoundary.append(sortedLatches[cursor]); cursor += 1
      }
      points[index] = .init(offset: points[index].offset, clockLabel: points[index].clockLabel,
        pulses: points[index].pulses,
        latches: atBoundary)
    }
    guard cursor == sortedLatches.count, points.count <= 6 else { throw Failure.invalidTimeline }
    return points
  }
}
