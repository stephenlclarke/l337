import Foundation

/// C01 phase/intermediate/within-step DATA only, in units of 2^-1074 seconds.
/// This bounded value is not a dwell accumulator or a native step/event seal.
struct NativeC01InquiryExactDyadic: Sendable, Equatable, Comparable, Codable {
  enum Failure: Error, Sendable {
    case invalidWordCount, unusedBits, outOfRange, invalidBinary64
    case overflow, negativeDifference
  }

  private let words: [UInt64]
  static let wordCount = 17
  static let zero = Self(canonical: Array(repeating: 0, count: wordCount))
  static let period: Self = {
    var words = Array(repeating: UInt64(0), count: wordCount)
    words[16] = 0x0010_0000_0000_0000
    return Self(canonical: words)
  }()
  static let maximumStep: Self = {
    // Exact binary64 0.1: significand 0x1999999999999a, shift 1018.
    let significand: UInt64 = 0x0019_9999_9999_999a
    var words = Array(repeating: UInt64(0), count: wordCount)
    words[15] = significand << 58
    words[16] = significand >> 6
    return Self(canonical: words)
  }()
  private static let exclusiveLimit: [UInt64] = {
    var words = maximumStep.words
    // Period bit 1076 and every step bit are disjoint; no addition is rounded.
    words[16] |= period.words[16]
    return words
  }()

  private init(canonical words: [UInt64]) { self.words = words }

  init(littleEndianWords words: [UInt64]) throws {
    guard words.count == Self.wordCount else { throw Failure.invalidWordCount }
    guard words[16] & 0xffe0_0000_0000_0000 == 0 else { throw Failure.unusedBits }
    guard Self.less(words, Self.exclusiveLimit) else { throw Failure.outOfRange }
    self.words = words
  }

  /// Exact import of the represented binary64 value, including subnormals.
  /// Negative zero is rejected; no floating arithmetic constructs these words.
  init(binary64 value: Double) throws {
    let bits = value.bitPattern
    let exponent = Int((bits >> 52) & 0x7ff)
    guard bits >> 63 == 0, exponent != 0x7ff else { throw Failure.invalidBinary64 }
    let fraction = bits & 0x000f_ffff_ffff_ffff
    let significand = exponent == 0 ? fraction : fraction | (UInt64(1) << 52)
    let shift = exponent == 0 ? 0 : exponent - 1
    let index = shift / 64
    let remainder = shift % 64
    guard index < Self.wordCount else { throw Failure.outOfRange }
    var result = Array(repeating: UInt64(0), count: Self.wordCount)
    result[index] = significand << remainder
    if remainder != 0 {
      let spill = significand >> (64 - remainder)
      if index + 1 < Self.wordCount {
        result[index + 1] = spill
      } else if spill != 0 {
        throw Failure.outOfRange
      }
    }
    try self.init(littleEndianWords: result)
  }

  var littleEndianWords: [UInt64] { words }
  var isZero: Bool { words.allSatisfy { $0 == 0 } }
  var shapeValid: Bool {
    words.count == Self.wordCount && words[16] & 0xffe0_0000_0000_0000 == 0
      && Self.less(words, Self.exclusiveLimit)
  }

  static func < (lhs: Self, rhs: Self) -> Bool { less(lhs.words, rhs.words) }

  private static func less(_ lhs: [UInt64], _ rhs: [UInt64]) -> Bool {
    for index in (0..<wordCount).reversed() where lhs[index] != rhs[index] {
      return lhs[index] < rhs[index]
    }
    return false
  }

  func adding(_ other: Self) throws -> Self {
    var result = Array(repeating: UInt64(0), count: Self.wordCount)
    var carry = false
    for index in 0..<Self.wordCount {
      let sum = words[index].addingReportingOverflow(other.words[index])
      let carried = sum.partialValue.addingReportingOverflow(carry ? 1 : 0)
      result[index] = carried.partialValue
      carry = sum.overflow || carried.overflow
    }
    guard !carry else { throw Failure.overflow }
    return try Self(littleEndianWords: result)
  }

  func subtracting(_ other: Self) throws -> Self {
    guard self >= other else { throw Failure.negativeDifference }
    var result = Array(repeating: UInt64(0), count: Self.wordCount)
    var borrow = false
    for index in 0..<Self.wordCount {
      let difference = words[index].subtractingReportingOverflow(other.words[index])
      let borrowed = difference.partialValue.subtractingReportingOverflow(borrow ? 1 : 0)
      result[index] = borrowed.partialValue
      borrow = difference.overflow || borrowed.overflow
    }
    guard !borrow else { throw Failure.negativeDifference }
    return try Self(littleEndianWords: result)
  }

  func split(at prefix: Self) throws -> (prefix: Self, suffix: Self) {
    (prefix, try subtracting(prefix))
  }

  private struct Key: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: Key.self)
    guard Set(container.allKeys.map(\.stringValue)) == Set(["words"]) else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Invalid C01 dyadic keys"))
    }
    var encoded = try container.nestedUnkeyedContainer(forKey: Key("words"))
    var words: [UInt64] = []
    words.reserveCapacity(Self.wordCount)
    for _ in 0..<Self.wordCount {
      let text = try encoded.decode(String.self)
      guard text.utf8.count == 16,
        text.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
        let word = UInt64(text, radix: 16)
      else {
        throw DecodingError.dataCorrupted(.init(
          codingPath: decoder.codingPath, debugDescription: "Invalid C01 dyadic word"))
      }
      words.append(word)
    }
    guard encoded.isAtEnd else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Invalid C01 dyadic word count"))
    }
    try self.init(littleEndianWords: words)
  }

  func encode(to encoder: any Encoder) throws {
    guard shapeValid else {
      throw EncodingError.invalidValue(self, .init(
        codingPath: encoder.codingPath, debugDescription: "Invalid C01 exact dyadic"))
    }
    var container = encoder.container(keyedBy: Key.self)
    var encoded = container.nestedUnkeyedContainer(forKey: Key("words"))
    for value in words {
      let text = String(value, radix: 16)
      try encoded.encode(String(repeating: "0", count: 16 - text.utf8.count) + text)
    }
  }
}

/// Pure source-specific numeric proposals. These functions cannot issue a live
/// accepted step, pulse, actuator application, private model or birth receipt.
enum NativeC01InquiryExactModelArithmetic {
  enum Failure: Error, Sendable { case invalidPhase, invalidStep, counterOverflow }

  struct Advance: Sendable, Equatable {
    let phase: NativeC01InquiryExactDyadic
    let cycle: UInt64
    let pulseSequence: UInt64
    let crossingOffset: NativeC01InquiryExactDyadic?
  }

  static func advance(phase: NativeC01InquiryExactDyadic, cycle: UInt64,
    pulseSequence: UInt64, usedD: NativeC01InquiryExactDyadic) throws -> Advance
  {
    guard phase < .period else { throw Failure.invalidPhase }
    guard !usedD.isZero, usedD <= .maximumStep else { throw Failure.invalidStep }
    guard cycle < UInt64.max, pulseSequence < UInt64.max else { throw Failure.counterOverflow }
    let boundary = try NativeC01InquiryExactDyadic.period.subtracting(phase)
    if usedD < boundary {
      return .init(phase: try phase.adding(usedD), cycle: cycle,
        pulseSequence: pulseSequence, crossingOffset: nil)
    }
    // Exact root ownership is certified before returning crossing DATA.
    guard !boundary.isZero, boundary <= usedD else { throw Failure.invalidPhase }
    let nextCycle = cycle.addingReportingOverflow(1)
    let nextPulse = pulseSequence.addingReportingOverflow(1)
    guard !nextCycle.overflow, !nextPulse.overflow,
      nextCycle.partialValue < UInt64.max, nextPulse.partialValue < UInt64.max
    else { throw Failure.counterOverflow }
    return .init(phase: try usedD.subtracting(boundary), cycle: nextCycle.partialValue,
      pulseSequence: nextPulse.partialValue, crossingOffset: boundary)
  }

  static func latchedPhaseData(_ detent: NativeC01InquiryManualDetent) throws
    -> NativeC01InquiryExactDyadic
  {
    if detent == .zero { return .zero }
    return try NativeC01InquiryExactDyadic.period.subtracting(
      NativeC01InquiryExactDyadic(binary64: detent.lagSeconds))
  }
}


extension NativeC01InquiryExactDyadic {
  enum ClockProjectionFailure: Error, Sendable { case invalidStart, invalidOffset, overflow }

  /// Nearest-even binary64 projection of this bounded numeric DATA value.
  /// This is useful for zero-start diagnostic fixtures, not elapsed-time proof.
  var roundedBinary64: Double { Self.roundClockWords(words) }

  /// Correctly rounded fl(start + exactOffset), without first rounding offset.
  /// The stored17-word/model bound is unchanged; one transient extra limb
  /// accommodates the existing <=1e12 clock domain. No clock/event is issued.
  func roundedClockLabel(after start: Double) throws -> Double {
    guard start.isFinite, start >= 0, start <= 1e12, start.sign != .minus else {
      throw ClockProjectionFailure.invalidStart
    }
    guard shapeValid else { throw ClockProjectionFailure.invalidOffset }
    let bits = start.bitPattern
    let exponent = Int((bits >> 52) & 0x7ff)
    let fraction = bits & 0x000f_ffff_ffff_ffff
    let significand = exponent == 0 ? fraction : fraction | (UInt64(1) << 52)
    let shift = exponent == 0 ? 0 : exponent - 1
    let index = shift / 64, remainder = shift % 64
    var sum = Array(repeating: UInt64(0), count: Self.wordCount + 1)
    guard index < sum.count else { throw ClockProjectionFailure.overflow }
    sum[index] = significand << remainder
    if remainder != 0 {
      let spill = significand >> (64 - remainder)
      if index + 1 < sum.count { sum[index + 1] = spill }
      else if spill != 0 { throw ClockProjectionFailure.overflow }
    }
    var carry = false
    for position in sum.indices {
      let offsetWord = position < Self.wordCount ? words[position] : 0
      let added = sum[position].addingReportingOverflow(offsetWord)
      let carried = added.partialValue.addingReportingOverflow(carry ? 1 : 0)
      sum[position] = carried.partialValue
      carry = added.overflow || carried.overflow
    }
    guard !carry else { throw ClockProjectionFailure.overflow }
    return Self.roundClockWords(sum)
  }

  /// Inputs are only this type's17 words or the checked18-word clock scratch.
  /// Their maximum bit is below1152, so rounded finite binary64 cannot overflow.
  private static func roundClockWords(_ value: [UInt64]) -> Double {
    var highest = -1
    for index in value.indices.reversed() where value[index] != 0 {
      highest = index * 64 + 63 - value[index].leadingZeroBitCount
      break
    }
    guard highest >= 0 else { return 0 }
    if highest < 52 { return Double(bitPattern: value[0]) }
    let dropped = highest - 52
    let index = dropped / 64, remainder = dropped % 64
    var significand = value[index] >> remainder
    if remainder != 0 && index + 1 < value.count {
      significand |= value[index + 1] << (64 - remainder)
    }
    significand &= 0x001f_ffff_ffff_ffff
    if dropped > 0 && clockBit(value, at: dropped - 1)
      && (clockBitsBelow(value, count: dropped - 1) || significand & 1 != 0) {
      significand += 1
    }
    if significand == 0x0020_0000_0000_0000 {
      significand >>= 1
      highest += 1
    }
    let exponent = UInt64(highest - 51)
    return Double(bitPattern: (exponent << 52) | (significand & 0x000f_ffff_ffff_ffff))
  }

  private static func clockBit(_ value: [UInt64], at bit: Int) -> Bool {
    guard bit >= 0, bit / 64 < value.count else { return false }
    return value[bit / 64] & (UInt64(1) << (bit % 64)) != 0
  }

  private static func clockBitsBelow(_ value: [UInt64], count: Int) -> Bool {
    guard count > 0 else { return false }
    let fullWords = count / 64
    for index in 0..<fullWords where value[index] != 0 { return true }
    let remaining = count % 64
    guard remaining > 0 else { return false }
    let mask = (UInt64(1) << remaining) - 1
    return value[fullWords] & mask != 0
  }
}
