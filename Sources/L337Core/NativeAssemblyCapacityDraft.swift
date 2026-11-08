import Foundation

/// Original physical-v2 design values, labelled project estimates. These are planning
/// limits, not calibrated hardware, occupied slots, consenting crews or dispatch authority.
enum NativeAssemblyCapacityRules {
  static let proposals = 5
  static let slots = 4
  static let crews = 3
  static let protectedFreeSlots = 1
}

/// Untrusted proposed register. IDs must later join the real surveyed requests and crews.
/// Constructing or decoding this value does not create any of those sources or people.
struct NativeAssemblyCapacityRegisterCandidate: Codable, Equatable, Sendable {
  let mission: UUID
  let proposals: [UUID]
  let crews: [UUID]
  /// Model slot index only; physical corridor geometry is not supplied by this register.
  let protectedSlot: Int

  var shapeValid: Bool {
    proposals.count == NativeAssemblyCapacityRules.proposals
      && crews.count == NativeAssemblyCapacityRules.crews
      && (0..<NativeAssemblyCapacityRules.slots).contains(protectedSlot)
      && Set(proposals).count == proposals.count && Set(crews).count == crews.count
  }
}

struct NativeAssemblyCapacityChoice: Codable, Equatable, Sendable {
  enum Allocation: Codable, Equatable, Sendable {
    /// Submitted but not given working capacity; no real queue, departure or promise.
    case waiting
    case working(slot: Int, crew: UUID)
  }
  let proposal: UUID
  let allocation: Allocation
}

/// Editable PLAYER candidate state. Its saved case field and Codable round trips remain
/// untrusted model input, never native work receipts. Both sides have distinct identities.
struct NativeAssemblyCapacityDraft: Codable, Equatable, Sendable {
  enum Side: String, Codable, Equatable, Sendable, CaseIterable {
    case port, starboard
    var target: String { "assembly-of-orbits-work-" + rawValue }
  }
  enum Failure: Error { case invalidDraft, unknownProposal, unknownAllocation, revisionExhausted }

  let register: NativeAssemblyCapacityRegisterCandidate
  let side: Side
  private(set) var revision: UInt64
  private(set) var choices: [NativeAssemblyCapacityChoice]

  init(register: NativeAssemblyCapacityRegisterCandidate, side: Side) throws {
    guard register.shapeValid else { throw Failure.invalidDraft }
    self.register = register
    self.side = side
    revision = 0
    choices = []
  }

  var shapeValid: Bool {
    guard register.shapeValid, choices.count <= NativeAssemblyCapacityRules.proposals,
      revision < UInt64(Int64.max), Set(choices.map(\.proposal)).count == choices.count
    else { return false }
    return choices.allSatisfy { choice in
      register.proposals.contains(choice.proposal) && allocationKnown(choice.allocation)
    }
  }

  private func allocationKnown(_ allocation: NativeAssemblyCapacityChoice.Allocation) -> Bool {
    switch allocation {
    case .waiting: true
    case .working(let slot, let crew):
      (0..<NativeAssemblyCapacityRules.slots).contains(slot) && register.crews.contains(crew)
    }
  }

  /// Invalid/conflicting capacity choices stay editable and receive measured-model
  /// feedback. Foreign IDs and malformed state refuse without changing this value.
  func setting(_ choice: NativeAssemblyCapacityChoice) throws -> Self {
    guard shapeValid else { throw Failure.invalidDraft }
    guard register.proposals.contains(choice.proposal) else { throw Failure.unknownProposal }
    guard allocationKnown(choice.allocation) else { throw Failure.unknownAllocation }
    if choices.contains(choice) { return self }
    guard revision < UInt64(Int64.max) - 1 else { throw Failure.revisionExhausted }
    var next = self
    let indexed = Dictionary(uniqueKeysWithValues: choices.map { ($0.proposal, $0) })
      .merging([choice.proposal: choice], uniquingKeysWith: { _, replacement in replacement })
    next.choices = register.proposals.compactMap { indexed[$0] }
    next.revision += 1
    return next
  }

  func removing(_ proposal: UUID) throws -> Self {
    guard shapeValid else { throw Failure.invalidDraft }
    guard register.proposals.contains(proposal) else { throw Failure.unknownProposal }
    guard choices.contains(where: { $0.proposal == proposal }) else { return self }
    guard revision < UInt64(Int64.max) - 1 else { throw Failure.revisionExhausted }
    var next = self
    next.choices.removeAll { $0.proposal == proposal }
    next.revision += 1
    return next
  }

  func assess() throws -> NativeAssemblyCapacityAssessment {
    guard shapeValid else { throw Failure.invalidDraft }
    var issues: [NativeAssemblyCapacityAssessment.Issue] = []
    for proposal in register.proposals where !choices.contains(where: { $0.proposal == proposal }) {
      issues.append(.unsubmitted(proposal))
    }
    let working = choices.compactMap { choice -> (proposal: UUID, slot: Int, crew: UUID)? in
      guard case .working(let slot, let crew) = choice.allocation else { return nil }
      return (choice.proposal, slot, crew)
    }
    if working.count > NativeAssemblyCapacityRules.crews {
      issues.append(.workingCapacityExceeded)
    }
    for choice in working where choice.slot == register.protectedSlot {
      issues.append(.protectedSlotClaimed(choice.proposal))
    }
    for slot in 0..<NativeAssemblyCapacityRules.slots {
      let proposals = working.filter { $0.slot == slot }.map { $0.proposal }
      if proposals.count > 1 { issues.append(.slotConflict(slot, proposals)) }
    }
    for crew in register.crews {
      let proposals = working.filter { $0.crew == crew }.map { $0.proposal }
      if proposals.count > 1 { issues.append(.crewConflict(crew, proposals)) }
    }
    return .init(target: side.target, revision: revision, submitted: choices.count,
      working: working.count, waiting: choices.count - working.count,
      freeModelSlots: NativeAssemblyCapacityRules.slots - Set(working.map { $0.slot }).count,
      protectedSlotFree: !working.contains(where: { $0.slot == register.protectedSlot }), issues: issues)
  }
}

/// Model feedback only. No physical test, work, dispatch, branch or milestone receipt.
struct NativeAssemblyCapacityAssessment: Equatable, Sendable {
  enum Issue: Equatable, Sendable {
    case unsubmitted(UUID), protectedSlotClaimed(UUID), workingCapacityExceeded
    case slotConflict(Int, [UUID]), crewConflict(UUID, [UUID])
  }
  let target: String
  let revision: UInt64
  let submitted: Int
  let working: Int
  let waiting: Int
  let freeModelSlots: Int
  let protectedSlotFree: Bool
  let issues: [Issue]
  var candidateWithinLimits: Bool { issues.isEmpty }

  var feedback: [String] {
    var lines: [String] = []
    for issue in issues {
      let line: String
      switch issue {
      case .unsubmitted: line = "Record a decision for every proposal."
      case .protectedSlotClaimed: line = "Keep the protected corridor slot free."
      case .workingCapacityExceeded: line = "At most three proposals can hold working capacity."
      case .slotConflict: line = "Two working proposals claim the same corridor slot."
      case .crewConflict: line = "A working crew cannot serve two simultaneous allocations."
      }
      if !lines.contains(line) { lines.append(line) }
    }
    if lines.isEmpty { lines.append("All five decisions are recorded within the candidate capacity limits.") }
    lines.append("Planning does not dispatch crews or complete either physical capacity test.")
    return lines
  }
}
