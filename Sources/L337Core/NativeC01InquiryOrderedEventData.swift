import Foundation

/// Consistency of retained/candidate DATA only. No function here constructs a
/// native accepted step, private pulse, R2 ACK, live arm or earned observation.
enum NativeC01InquiryOrderedEventData {
  enum Failure: Error, Sendable {
    case invalidContextData, invalidEventData, outOfOrder, duplicateOscillator
  }

  struct Group: Sendable, Equatable {
    let step: NativeC01InquiryStepData
    let fixture: NativeC01InquiryFixtureRef
    let offset: NativeC01InquiryExactDyadic
    let events: [NativeC01InquiryPulseEvent]
  }

  /// A caller's order value is DATA, never the private native ordering seal.
  struct OrderedBatchData: Sendable, Equatable {
    let group: Group
    let nativeOrder: UInt64
  }

  // Existing three heads, two independent oscillators, at most one crossing
  // each in a native usedD <= 0.1 under the adopted four-second source law.
  private static let maximumEventsPerStep = 6

  static func grouped(_ events: [NativeC01InquiryPulseEvent], step: NativeC01InquiryStepData,
    fixture: NativeC01InquiryFixtureRef, challengeIDs: [UUID], appliedControlRevisions: [UInt64]
  ) throws -> [Group] {
    guard step.shapeValid, fixture.shapeValid,
      step.fixtureID == fixture.fixtureID, step.generation == fixture.generation,
      challengeIDs.count == 3, Set(challengeIDs).count == 3,
      appliedControlRevisions.count == 3,
      appliedControlRevisions.allSatisfy({ $0 > 0 && $0 < UInt64(Int64.max) }),
      events.count <= maximumEventsPerStep
    else { throw Failure.invalidContextData }
    var slots: Set<Int> = []
    var groups: [Group] = []
    for event in events {
      guard event.shapeValid, event.step == step, event.fixture == fixture,
        event.pulseSequence > 0, event.cycle > 0,
        event.challengeID == challengeIDs[event.challengeOrdinal],
        event.appliedControlRevision == appliedControlRevisions[event.challengeOrdinal]
      else { throw Failure.invalidEventData }
      guard slots.insert(slot(event)).inserted else { throw Failure.duplicateOscillator }
      if let last = groups.last {
        guard event.offset >= last.offset else { throw Failure.outOfOrder }
        if event.offset == last.offset {
          groups[groups.count - 1] = .init(step: step, fixture: fixture, offset: last.offset,
            events: last.events + [event])
          continue
        }
      }
      groups.append(.init(step: step, fixture: fixture, offset: event.offset, events: [event]))
    }
    return groups
  }

  /// Checks only the represented old-batch/reference/latch order. Genuine ACK,
  /// native operation order, command eligibility and actual phase application
  /// must still come from their private runtime owners.
  static func latchMatchesReferenceBatchData(
    _ application: NativeC01InquiryControlApplication, batch: OrderedBatchData
  ) -> Bool {
    let group = batch.group
    guard application.shapeValid, batch.nativeOrder < UInt64.max,
      case .withinStep(let boundary) = application.boundary,
      boundary.step == group.step, boundary.offset == group.offset,
      boundary.nativeOrder > batch.nativeOrder,
      application.caseID == group.step.caseID, application.fixture == group.fixture,
      groupDataIsConsistent(group)
    else { return false }
    let channel = group.events.filter { $0.challengeOrdinal == application.challengeOrdinal }
    let references = channel.filter { $0.oscillator == .reference }
    guard references.count == 1,
      references[0].challengeID == application.challengeID,
      channel.allSatisfy({
        $0.challengeID == application.challengeID
          && $0.appliedControlRevision == application.before.revision
      })
    else { return false }
    return true
  }

  /// Adjacent reference counters and matching DATA do not prove a continuous
  /// native step chain or compute a measured period from rounded clock labels.
  static func adjacentReferenceData(
    _ first: NativeC01InquiryPulseEvent, _ second: NativeC01InquiryPulseEvent
  ) -> Bool {
    guard first.shapeValid, second.shapeValid,
      first.oscillator == .reference, second.oscillator == .reference,
      first.pulseSequence > 0, second.pulseSequence > 0, first.cycle > 0, second.cycle > 0,
      first.fixture == second.fixture, first.challengeID == second.challengeID,
      first.challengeOrdinal == second.challengeOrdinal,
      first.appliedControlRevision == second.appliedControlRevision,
      first.step.ownerSession == second.step.ownerSession,
      first.step.sceneEpoch == second.step.sceneEpoch, first.step.player == second.step.player,
      first.step.caseID == second.step.caseID,
      first.step.sequence < second.step.sequence
    else { return false }
    let pulse = first.pulseSequence.addingReportingOverflow(1)
    let cycle = first.cycle.addingReportingOverflow(1)
    return !pulse.overflow && !cycle.overflow
      && pulse.partialValue < UInt64.max && cycle.partialValue < UInt64.max
      && second.pulseSequence == pulse.partialValue && second.cycle == cycle.partialValue
  }

  private static func groupDataIsConsistent(_ group: Group) -> Bool {
    guard !group.events.isEmpty, group.events.count <= maximumEventsPerStep,
      group.events.allSatisfy({
        $0.shapeValid && $0.step == group.step && $0.fixture == group.fixture
          && $0.offset == group.offset && $0.pulseSequence > 0 && $0.cycle > 0
      })
    else { return false }
    return Set(group.events.map(slot)).count == group.events.count
  }

  private static func slot(_ event: NativeC01InquiryPulseEvent) -> Int {
    event.challengeOrdinal * 2 + (event.oscillator == .reference ? 0 : 1)
  }
}

extension NativeC01InquiryOrderedEventData {
  /// FIFO DATA chain at one represented reference boundary. This never proves
  /// actual ACK custody, source activity, native order or instrument eligibility.
  static func latchSequenceMatchesReferenceBatchData(
    _ applications: [NativeC01InquiryControlApplication], batch: OrderedBatchData,
    commands: [NativeC01InquiryCommand]
  ) -> Bool {
    guard !applications.isEmpty, applications.count <= 16_384, commands.count <= 16_384,
      groupDataIsConsistent(batch.group), batch.nativeOrder < UInt64.max,
      commands.allSatisfy({ $0.shapeValid }),
      Set(commands.map(\.id)).count == commands.count,
      Set(applications.map(\.operation)).count == applications.count,
      Set(applications.map(\.commandID)).count == applications.count
    else { return false }
    var requests: [UUID: NativeC01InquiryCommand] = [:]
    for command in commands { requests[command.id] = command }
    var previousByChannel: [Int: NativeC01InquiryControlApplication] = [:]
    var priorApplicationOrder = batch.nativeOrder
    var priorRequestOrder: UInt64?
    var priorCommandSequence: UInt64?
    for application in applications {
      guard application.shapeValid,
        case .withinStep(let boundary) = application.boundary,
        boundary.step == batch.group.step, boundary.offset == batch.group.offset,
        boundary.nativeOrder > priorApplicationOrder,
        application.caseID == batch.group.step.caseID,
        application.fixture == batch.group.fixture,
        let command = requests[application.commandID], command.kind == .setDetent,
        command.ownerSession == batch.group.step.ownerSession,
        command.nativeOrder > 0, command.nativeOrder < batch.nativeOrder,
        priorRequestOrder.map({ command.nativeOrder > $0 }) ?? true,
        priorCommandSequence.map({ command.sequence > $0 }) ?? true,
        application.commandSequence == command.sequence,
        application.owner == command.owner, application.caseID == command.caseID,
        application.sourceBirth == command.sourceBirth,
        application.challengeID == command.challengeID,
        application.challengeOrdinal == command.challengeOrdinal,
        application.fixture == command.fixture, application.instrument == command.instrument,
        application.after == command.requested.setting(application.challengeOrdinal)
      else { return false }
      if let previous = previousByChannel[application.challengeOrdinal] {
        guard application.before == previous.after,
          application.owner == previous.owner, application.sourceBirth == previous.sourceBirth,
          application.caseID == previous.caseID, application.fixture == previous.fixture,
          application.challengeID == previous.challengeID
        else { return false }
      } else {
        guard latchMatchesReferenceBatchData(application, batch: batch),
          application.before == command.appliedBefore.setting(application.challengeOrdinal)
        else { return false }
      }
      previousByChannel[application.challengeOrdinal] = application
      priorApplicationOrder = boundary.nativeOrder
      priorRequestOrder = command.nativeOrder
      priorCommandSequence = command.sequence
    }
    return true
  }
}
