import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryExactDyadicTests {
  private typealias Exact = NativeC01InquiryExactDyadic

  @Test func binary64ImportPreservesSubnormalNormalAndSourceConstants() throws {
    let tiny = try Exact(binary64: .leastNonzeroMagnitude)
    var expected = Array(repeating: UInt64(0), count: 17)
    expected[0] = 1
    #expect(tiny.littleEndianWords == expected)
    expected[0] = UInt64(1) << 52
    #expect(try Exact(binary64: .leastNormalMagnitude).littleEndianWords == expected)
    #expect(try Exact(binary64: 0) == .zero)
    #expect(try Exact(binary64: 4) == .period)
    #expect(try Exact(binary64: 0.1) == .maximumStep)
  }

  @Test func binary64ImportRejectsSignsNonfiniteAndOutOfDomainValues() {
    let values: [Double] = [-0.0, -.leastNonzeroMagnitude, -1, .nan, .infinity, -.infinity, 5]
    for value in values {
      #expect(throws: (any Error).self) { try Exact(binary64: value) }
    }
  }

  @Test func exactTailsRemainDistinctWhenNoBinary64ValueCanHoldTheSum() throws {
    let one = try Exact(binary64: 1)
    let tiny = try Exact(binary64: .leastNonzeroMagnitude)
    let exact = try one.adding(tiny)
    #expect(exact > one && exact != one)
    #expect(try exact.subtracting(one) == tiny)
    #expect(try exact.subtracting(tiny) == one)
  }

  @Test func carryAndBorrowPropagateAcrossAllSixteenLowerWords() throws {
    var lower = Array(repeating: UInt64.max, count: 17)
    lower[16] = 0
    let before = try Exact(littleEndianWords: lower)
    let tiny = try Exact(binary64: .leastNonzeroMagnitude)
    let carried = try before.adding(tiny)
    var expected = Array(repeating: UInt64(0), count: 17)
    expected[16] = 1
    #expect(carried.littleEndianWords == expected)
    #expect(try carried.subtracting(tiny) == before)
    #expect(try before.subtracting(before) == .zero)
    #expect(throws: (any Error).self) { try tiny.subtracting(carried) }
  }

  @Test func containerRejectsWrongCountsUnusedBitsAndExclusiveUpperBound() {
    #expect(throws: (any Error).self) { try Exact(littleEndianWords: []) }
    #expect(throws: (any Error).self) {
      try Exact(littleEndianWords: Array(repeating: 0, count: 18))
    }
    var unused = Array(repeating: UInt64(0), count: 17)
    unused[16] = UInt64(1) << 53
    #expect(throws: (any Error).self) { try Exact(littleEndianWords: unused) }
    var limit = Exact.maximumStep.littleEndianWords
    limit[16] |= Exact.period.littleEndianWords[16]
    #expect(throws: (any Error).self) { try Exact(littleEndianWords: limit) }
    #expect(throws: (any Error).self) { try Exact.period.adding(.maximumStep) }
  }

  @Test func canonicalCodecRoundTripsTheExactTailWithoutDoubleProjection() throws {
    let value = try Exact(binary64: 1).adding(Exact(binary64: .leastNonzeroMagnitude))
    let data = try JSONEncoder().encode(value)
    #expect(try JSONDecoder().decode(Exact.self, from: data) == value)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(object.keys) == Set(["words"]))
    let words = try #require(object["words"] as? [String])
    #expect(words.count == 17 && words.allSatisfy { $0.utf8.count == 16 })
    #expect(words[0] == "0000000000000001")
    #expect(words.allSatisfy { $0 == $0.lowercased() })
  }

  @Test(arguments: ["missing", "unknown", "null", "short", "long", "uppercase", "nonhex", "shortword", "unused", "upperbound", "scale"])
  func codecRejectsNoncanonicalRepresentations(form: String) throws {
    var words = Array(repeating: "0000000000000000", count: 17)
    if form == "short" { words.removeLast() }
    if form == "long" { words.append(words[0]) }
    if form == "uppercase" { words[0] = "000000000000000A" }
    if form == "nonhex" { words[0] = "000000000000000g" }
    if form == "shortword" { words[0] = "0" }
    if form == "unused" { words[16] = "0020000000000000" }
    if form == "upperbound" {
      var limit = Exact.maximumStep.littleEndianWords
      limit[16] |= Exact.period.littleEndianWords[16]
      words = limit.map {
        let text = String($0, radix: 16)
        return String(repeating: "0", count: 16 - text.utf8.count) + text
      }
    }
    var object: [String: Any] = ["words": words]
    if form == "missing" { object.removeValue(forKey: "words") }
    if form == "unknown" { object["phaseSeconds"] = 0 }
    if form == "scale" { object["exponent"] = -1074 }
    if form == "null" { object["words"] = NSNull() }
    let data = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(Exact.self, from: data) }
  }

  @Test func nonobservationalInitialZeroDoesNotProduceNumericCrossing() throws {
    let result = try NativeC01InquiryExactModelArithmetic.advance(
      phase: .zero, cycle: 0, pulseSequence: 0, usedD: .maximumStep)
    #expect(result.phase == .maximumStep && result.cycle == 0 && result.pulseSequence == 0)
    #expect(result.crossingOffset == nil)
  }

  @Test func exactRootWithSubnormalTailIsOwnedOnceAtItsTrueOffset() throws {
    let tiny = try Exact(binary64: .leastNonzeroMagnitude)
    let phase = try Exact.period.subtracting(.maximumStep).adding(tiny)
    let result = try NativeC01InquiryExactModelArithmetic.advance(
      phase: phase, cycle: 9, pulseSequence: 11, usedD: .maximumStep)
    let root = try #require(result.crossingOffset)
    #expect(root > .zero && root < .maximumStep)
    #expect(try root.adding(tiny) == .maximumStep)
    #expect(result.phase == tiny && result.cycle == 10 && result.pulseSequence == 12)
    let next = try NativeC01InquiryExactModelArithmetic.advance(
      phase: result.phase, cycle: result.cycle, pulseSequence: result.pulseSequence, usedD: tiny)
    #expect(next.crossingOffset == nil)
  }

  @Test func endpointRootBelongsToEndingStepAndDoesNotRepeatAtZero() throws {
    let phase = try Exact.period.subtracting(.maximumStep)
    let result = try NativeC01InquiryExactModelArithmetic.advance(
      phase: phase, cycle: 0, pulseSequence: 0, usedD: .maximumStep)
    #expect(result.crossingOffset == Exact.maximumStep && result.phase == .zero)
    let next = try NativeC01InquiryExactModelArithmetic.advance(
      phase: result.phase, cycle: result.cycle, pulseSequence: result.pulseSequence,
      usedD: .maximumStep)
    #expect(next.crossingOffset == nil && next.cycle == 1 && next.pulseSequence == 1)
  }

  @Test func phaseStepAndCounterBoundariesRefuseWithoutWrapping() throws {
    #expect(throws: (any Error).self) {
      try NativeC01InquiryExactModelArithmetic.advance(
        phase: .period, cycle: 0, pulseSequence: 0, usedD: .maximumStep)
    }
    for d in [Exact.zero, Exact.period] {
      #expect(throws: (any Error).self) {
        try NativeC01InquiryExactModelArithmetic.advance(
          phase: .zero, cycle: 0, pulseSequence: 0, usedD: d)
      }
    }
    let phase = try Exact.period.subtracting(.maximumStep)
    let countsToReject: [(UInt64, UInt64)] = [
      (UInt64.max, 0), (0, UInt64.max), (UInt64.max - 1, 0), (0, UInt64.max - 1),
    ]
    for counts in countsToReject {
      #expect(throws: (any Error).self) {
        try NativeC01InquiryExactModelArithmetic.advance(
          phase: phase, cycle: counts.0, pulseSequence: counts.1, usedD: .maximumStep)
      }
    }
  }

  @Test func exactSplitPreservesTheWholeIntervalAndRefusesNegativeRemainder() throws {
    let tiny = try Exact(binary64: .leastNonzeroMagnitude)
    let split = try Exact.maximumStep.split(at: tiny)
    #expect(split.prefix == tiny)
    #expect(try split.prefix.adding(split.suffix) == .maximumStep)
    #expect(try Exact.maximumStep.split(at: .zero).suffix == .maximumStep)
    #expect(try Exact.maximumStep.split(at: .maximumStep).suffix == .zero)
    #expect(throws: (any Error).self) { try Exact.maximumStep.split(at: .period) }
  }

  @Test func detentLatchProducesOnlyExactPhaseDataAndNoPulseObject() throws {
    for detent in NativeC01InquiryManualDetent.allCases {
      let phase = try NativeC01InquiryExactModelArithmetic.latchedPhaseData(detent)
      #expect(phase < .period)
      if detent == .zero {
        #expect(phase == .zero)
      } else {
        #expect(try phase.adding(Exact(binary64: detent.lagSeconds)) == .period)
      }
    }
  }
}

// Closed retained DATA checks only; no approved source or native transport.
extension NativeC01InquiryExactDyadicTests {
  @Test func oscillatorCodecRequiresExactPhaseAndRejectsTheOldDoubleKey() throws {
    let value = NativeC01InquiryOscillatorData(phase: .zero, cycle: 0, pulseSequence: 0)
    #expect(value.shapeValid)
    let data = try JSONEncoder().encode(value)
    #expect(try JSONDecoder().decode(NativeC01InquiryOscillatorData.self, from: data) == value)
    let old = Data(#"{"phaseSeconds":0,"cycle":0,"pulseSequence":0}"#.utf8)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01InquiryOscillatorData.self, from: old)
    }
    let invalid = NativeC01InquiryOscillatorData(phase: .period, cycle: 0, pulseSequence: 0)
    #expect(!invalid.shapeValid)
    #expect(throws: (any Error).self) { try JSONEncoder().encode(invalid) }
  }

  @Test func withinStepDataAllowsZeroButRejectsOffsetsPastActualUsedD() throws {
    let step = exactDataStep()
    let zero = NativeC01InquiryWithinStepBoundary(step: step, offset: .zero, nativeOrder: 0)
    let end = NativeC01InquiryWithinStepBoundary(step: step, offset: .maximumStep, nativeOrder: 1)
    let invalid = NativeC01InquiryWithinStepBoundary(step: step, offset: .period, nativeOrder: 1)
    #expect(zero.shapeValid && end.shapeValid && !invalid.shapeValid)
    let data = try JSONEncoder().encode(end)
    #expect(try JSONDecoder().decode(NativeC01InquiryWithinStepBoundary.self, from: data) == end)
  }

  @Test func pulseDataRejectsZeroAndPreservesAnExactNonbinary64Root() throws {
    let step = exactDataStep()
    // Syntactic fixture DATA, expressly not a source-approved/admitted fixture.
    let digest = String(repeating: "a", count: 64)
    let fixture = NativeC01InquiryFixtureRef(fixtureID: step.fixtureID, generation: 1,
      admissionOperation: UUID(), geometryRevision: NativeC01InquiryFixtureGeometry.revision,
      geometryPins: .init(support: digest, head0: digest, head1: digest, head2: digest),
      metricRevision: NativeC01InquiryFixtureGeometry.metricRevision,
      lawRevision: NativeC01InquiryHeadModelData.lawRevision)
    func event(_ offset: NativeC01InquiryExactDyadic) -> NativeC01InquiryPulseEvent {
      .init(step: step, fixture: fixture, challengeID: UUID(), challengeOrdinal: 0,
        oscillator: .reference, appliedControlRevision: 1, pulseSequence: 1,
        cycle: 1, offset: offset, clockLabel: step.clockEnd)
    }
    #expect(!event(.zero).shapeValid && !event(.period).shapeValid)
    let tiny = try NativeC01InquiryExactDyadic(binary64: .leastNonzeroMagnitude)
    let value = event(try NativeC01InquiryExactDyadic.maximumStep.subtracting(tiny))
    #expect(value.shapeValid)
    let data = try JSONEncoder().encode(value)
    #expect(try JSONDecoder().decode(NativeC01InquiryPulseEvent.self, from: data) == value)
  }

  private func exactDataStep() -> NativeC01InquiryStepData {
    .init(ownerSession: UUID(), sequence: 1, sceneEpoch: UUID(),
      player: .init(system: .init(galaxy: 0, system: 0), visit: 1, entity: 0),
      caseID: UUID(), caseRevision: 1, fixtureID: UUID(), generation: 1,
      clockStart: 0, clockEnd: 0.1, usedD: 0.1)
  }
}
