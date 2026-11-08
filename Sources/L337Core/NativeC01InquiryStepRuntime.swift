import Foundation

enum NativeC01InquiryStepFailure: Error, Sendable {
  case sourceUnavailable, invalidFixture, staleOpening, invalidNativeClock
  case counterExhausted, duplicateStep, interruptedStepChain, sourceChanged
  case missingNativeSceneModelSeal, unavailableR2Publication
  case invalidInitialModelPreparation, conflictingModelRegistration, missingNativeModelRegistration
  case invalidModelStepInput
}

/// A source-current opening is not elapsed-time authority. Only the real
/// Game clock call site can wrap it in the file-private clock witness.
final class NativeC01InquiryClockOpening: Sendable {
  fileprivate let session: UUID
  fileprivate let sequence: UInt64
  fileprivate let nativeOrder: UInt64
  fileprivate let root: NativeC01InquiryState
  fileprivate let fixture: NativeC01InquiryFixtureRef
  fileprivate let context: EncounterContext
  fileprivate let epoch: UUID
  fileprivate let beforeFlight: FlightSimulationState
  fileprivate let usedD: Double

  fileprivate init(session: UUID, sequence: UInt64, nativeOrder: UInt64,
    root: NativeC01InquiryState, fixture: NativeC01InquiryFixtureRef,
    context: EncounterContext, epoch: UUID, beforeFlight: FlightSimulationState, usedD: Double)
  {
    self.session = session; self.sequence = sequence; self.nativeOrder = nativeOrder
    self.root = root; self.fixture = fixture; self.context = context; self.epoch = epoch
    self.beforeFlight = beforeFlight; self.usedD = usedD
  }
}

/// An actual native clock seal, not a motion, model, instrument or pulse seal.
/// Its only constructor is reached through the Game-file clock witness.
final class NativeC01InquiryAcceptedClockStep: Sendable {
  fileprivate let data: NativeC01InquiryStepData
  fileprivate let nativeOrder: UInt64
  fileprivate let root: NativeC01InquiryState
  fileprivate let fixture: NativeC01InquiryFixtureRef

  fileprivate init(data: NativeC01InquiryStepData, nativeOrder: UInt64,
    root: NativeC01InquiryState, fixture: NativeC01InquiryFixtureRef)
  {
    self.data = data; self.nativeOrder = nativeOrder; self.root = root; self.fixture = fixture
  }
}

/// No factory is issued until a genuine native observer can seal completion.
/// Retained DTOs alone cannot populate the pending publication slot.
final class NativeC01InquirySealedPendingEvidence: Sendable {
  enum Payload: Sendable {
    case measurement(NativeC01InquiryMeasurement)
    case trial(NativeC01InquiryTrial)
  }
  let ownerSession: UUID
  let operation: UUID
  let payload: Payload
  private init(ownerSession: UUID, operation: UUID, payload: Payload) {
    self.ownerSession = ownerSession; self.operation = operation; self.payload = payload
  }
}

/// Prepared source registration is inert until its exact physical receipt installs it.
fileprivate final class NativeC01InquiryModelRegistration: Sendable {
  let ownerSession: UUID
  let owner: UUID
  let caseID: UUID
  let sourceBirth: UUID
  let fixture: NativeC01InquiryFixtureRef
  let bindings: [NativeC01InquiryFixtureBinding]
  let birthSnapshot: NativeC01InquiryModelSnapshot

  fileprivate init(preparation: NativeC01InquiryInitialModelPreparation,
    fixture: NativeC01InquiryFixtureRef, bindings: [NativeC01InquiryFixtureBinding])
  {
    ownerSession = preparation.ownerSession; owner = preparation.sourceRoot.owner
    caseID = preparation.sourceRoot.caseRecord.id
    sourceBirth = preparation.sourceRoot.institutionalSource.birthOperation
    self.fixture = fixture; self.bindings = bindings; birthSnapshot = preparation.snapshot
  }
}

/// Prevalidated installation, not an activation or a caller's saved-model approval.
final class NativeC01InquiryInitialModelInstallation: Sendable {
  var ownerSession: UUID { registration.ownerSession }
  fileprivate let registration: NativeC01InquiryModelRegistration
  fileprivate let expectedPrevious: NativeC01InquiryModelRegistration?
  fileprivate init(registration: NativeC01InquiryModelRegistration,
    expectedPrevious: NativeC01InquiryModelRegistration?)
  {
    self.registration = registration; self.expectedPrevious = expectedPrevious
  }
}

/// Runtime-only, copied with attained Game. This type is deliberately not Codable.
struct NativeC01InquiryStepRuntimeState: Sendable {
  let ownerSession: UUID
  fileprivate(set) var nextStepSequence: UInt64 = 1
  fileprivate(set) var nextNativeOrder: UInt64 = 1
  fileprivate(set) var consumedThroughStep: UInt64?
  fileprivate(set) var integratedThroughStep: UInt64?
  fileprivate(set) var lastFailure: NativeC01InquiryStepFailure?
  fileprivate(set) var chainInterrupted = false
  fileprivate var currentClock: NativeC01InquiryAcceptedClockStep?
  fileprivate var consumedClock: NativeC01InquiryAcceptedClockStep?
  fileprivate var pendingEvidence: NativeC01InquirySealedPendingEvidence?
  fileprivate var registeredModel: NativeC01InquiryModelRegistration?
  fileprivate var liveModelSnapshot: NativeC01InquiryModelSnapshot?

  init() { ownerSession = UUID() }

  /// These are read-only DTO/status projections, never accepted-step factories.
  var lastAcceptedStepData: NativeC01InquiryStepData? { currentClock?.data }
  var lastConsumedStepData: NativeC01InquiryStepData? { consumedClock?.data }
  var hasCompletedPendingEvidence: Bool { pendingEvidence != nil }
  var hasNativeModelRegistration: Bool { registeredModel != nil }
  var liveModelSnapshotData: NativeC01InquiryModelSnapshot? { liveModelSnapshot }

  func canInstallInitialModel(_ installation: NativeC01InquiryInitialModelInstallation) -> Bool {
    ownerSession == installation.ownerSession
      && Self.sameRegistration(registeredModel, installation.expectedPrevious)
  }

  fileprivate static func sameRegistration(_ lhs: NativeC01InquiryModelRegistration?,
    _ rhs: NativeC01InquiryModelRegistration?) -> Bool
  {
    switch (lhs, rhs) {
    case (nil, nil): return true
    case (.some(let first), .some(let second)): return first === second
    default: return false
    }
  }

  mutating func invalidateScene() {
    currentClock = nil
    consumedClock = nil
    chainInterrupted = true
    // Session, monotonic cursors and completed immutable pending survive hot changes.
    // Only a real cold owner reset creates a fresh state and drops runtime queues.
  }

  fileprivate mutating func beginClockAttempt() {
    if currentClock != nil {
      chainInterrupted = true
      lastFailure = .interruptedStepChain
    }
    currentClock = nil
    consumedClock = nil
  }
}

/// Deliberately unissued until the actual instrument/model command producer
/// exists. A caller's retained command row cannot create publication intent.
final class NativeC01InquiryR2PublicationIntent: Sendable {
  fileprivate let session: UUID
  fileprivate let nativeOrder: UInt64
  fileprivate let selectedRoot: NativeC01InquiryState
  fileprivate let command: NativeC01InquiryCommand
  private init(session: UUID, nativeOrder: UInt64, selectedRoot: NativeC01InquiryState,
    command: NativeC01InquiryCommand)
  {
    self.session = session; self.nativeOrder = nativeOrder
    self.selectedRoot = selectedRoot; self.command = command
  }
}

extension Game {
  func prepareC01InquiryInitialModelInstallation(
    _ preparation: NativeC01InquiryInitialModelPreparation, selectedRoot: NativeC01InquiryState,
    fixture: NativeC01InquiryFixtureRef, bindings: [NativeC01InquiryFixtureBinding]
  ) throws -> NativeC01InquiryInitialModelInstallation {
    let before = preparation.sourceRoot
    guard commander.scriptState.savedC01Inquiry == before,
      preparation.ownerSession == c01InquiryStepRuntime.ownerSession,
      preparation.nativeEpoch == nativeStationRuntimeEpoch,
      preparation.snapshot.physicalTime == commander.flightSimulation.physicalTime,
      preparation.snapshot.lastStep == nil, preparation.snapshot.shapeValid,
      before.caseRecord.fixtureGenerations.isEmpty,
      selectedRoot.shapeValid, selectedRoot.owner == before.owner,
      selectedRoot.institutionalSource == before.institutionalSource,
      selectedRoot.caseRecord.id == before.caseRecord.id,
      selectedRoot.caseRecord.fixtureGenerations.count == 1,
      let generation = selectedRoot.caseRecord.fixtureGenerations.last,
      fixture.matches(generation), generation.modelSnapshot == preparation.snapshot,
      let life = selectedRoot.fixtureLifecycle.last,
      life.caseID == before.caseRecord.id, life.fixture == fixture, life.retirement == nil,
      life.modelSnapshot == preparation.snapshot,
      bindings.count == 4,
      [life.support, life.head0, life.head1, life.head2].map(\.binding) == bindings
    else { throw NativeC01InquiryStepFailure.invalidInitialModelPreparation }
    if let prior = c01InquiryStepRuntime.registeredModel {
      guard prior.ownerSession == preparation.ownerSession,
        before.priorCases.contains(where: { $0.id == prior.caseID && $0.finalReceipt != nil }),
        before.fixtureLifecycle.contains(where: {
          $0.caseID == prior.caseID && $0.fixture == prior.fixture && $0.retirement != nil
        })
      else { throw NativeC01InquiryStepFailure.conflictingModelRegistration }
    }
    let registration = NativeC01InquiryModelRegistration(preparation: preparation,
      fixture: fixture, bindings: bindings)
    return .init(registration: registration, expectedPrevious: c01InquiryStepRuntime.registeredModel)
  }

  /// Called only with the actual cohort receipt after its prevalidated Root install.
  /// Normal installation performs no lookup, allocation, throw or suspension.
  mutating func installC01InquiryInitialModel(_ receipt: NativeC01InquiryFixtureBirthReceipt) {
    let installation = receipt.modelInstallation
    guard installation.ownerSession == c01InquiryStepRuntime.ownerSession else {
      c01InquiryStepRuntime.lastFailure = .conflictingModelRegistration
      return
    }
    if c01InquiryStepRuntime.registeredModel === installation.registration { return }
    guard c01InquiryStepRuntime.canInstallInitialModel(installation) else {
      c01InquiryStepRuntime.lastFailure = .conflictingModelRegistration
      return
    }
    commitValidatedC01InquiryInitialModel(installation)
  }

  /// Assignment-only FRESH installation after genuine native permit/source/
  /// model/registry preflight. This is not a model or physical permission issuer.
  /// Existing receipt replay returns above BEFORE this seam, preserving progress.
  mutating func commitValidatedC01InquiryInitialModel(_ installation: NativeC01InquiryInitialModelInstallation) {
    c01InquiryStepRuntime.registeredModel = installation.registration
    c01InquiryStepRuntime.liveModelSnapshot = installation.registration.birthSnapshot
  }

  mutating func prepareC01InquiryClockOpening(usedD: Double) -> NativeC01InquiryClockOpening? {
    c01InquiryStepRuntime.beginClockAttempt()
    guard let root = commander.scriptState.savedC01Inquiry else { return nil }
    guard !docked, !paused, energy.isFinite, energy > 0,
      usedD.isFinite, usedD > 0, usedD <= 0.1, root.shapeValid,
      root.owner == commander.equipmentOwnerID, root.caseRecord.finalReceipt == nil,
      root.institutionalSource.availability == .available,
      root.institutionalSource.availableDuty(.intake) != nil,
      case .living(let host) = nativeOriginalMainStationDestination,
      host.identity == root.institutionalSource.host, acceptsNativeMainStationDestination(host),
      let context = gameplayContext(), context.player.identity == commander.flightSimulation.player
    else {
      c01InquiryStepRuntime.lastFailure = .sourceUnavailable
      return nil
    }
    do {
      guard try NativeC01InquiryOperatorRetainedSource.validate(root) else {
        c01InquiryStepRuntime.lastFailure = .sourceUnavailable
        return nil
      }
    } catch {
      c01InquiryStepRuntime.lastFailure = .sourceUnavailable
      return nil
    }
    guard let generation = root.caseRecord.fixtureGenerations.last,
      generation.retirement == nil,
      let fixture = c01ClockCurrentFixture(root, generation: generation, context: context)
    else {
      c01InquiryStepRuntime.lastFailure = .invalidFixture
      return nil
    }
    let flight = commander.flightSimulation
    let end = flight.physicalTime + usedD
    guard flight.physicalTime.isFinite, flight.physicalTime >= 0,
      end.isFinite, end > flight.physicalTime,
      context.physicalTime == flight.physicalTime
    else {
      c01InquiryStepRuntime.lastFailure = .invalidNativeClock
      return nil
    }
    guard c01InquiryStepRuntime.nextStepSequence < UInt64.max - 1,
      c01InquiryStepRuntime.nextNativeOrder < UInt64.max - 1
    else {
      c01InquiryStepRuntime.lastFailure = .counterExhausted
      return nil
    }
    return .init(session: c01InquiryStepRuntime.ownerSession,
      sequence: c01InquiryStepRuntime.nextStepSequence,
      nativeOrder: c01InquiryStepRuntime.nextNativeOrder, root: root, fixture: fixture,
      context: context, epoch: nativeStationRuntimeEpoch, beforeFlight: flight, usedD: usedD)
  }

  mutating func acceptC01InquiryClockWitness(_ witness: NativeC01InquiryClockWitness) {
    let opening = witness.opening
    let flight = commander.flightSimulation
    let expectedFlight: FlightSimulationState
    if let motion = witness.nativeMotion {
      guard let attained = motion.verifiedFinalFlight(
        from: opening.beforeFlight, usedD: opening.usedD, epoch: opening.epoch)
      else {
        c01InquiryStepRuntime.lastFailure = .staleOpening
        return
      }
      expectedFlight = attained
    } else {
      expectedFlight = opening.beforeFlight
    }
    guard c01InquiryStepRuntime.ownerSession == opening.session,
      c01InquiryStepRuntime.nextStepSequence == opening.sequence,
      c01InquiryStepRuntime.nextNativeOrder == opening.nativeOrder,
      nativeStationRuntimeEpoch == opening.epoch,
      commander.scriptState.savedC01Inquiry == opening.root,
      flight.player == opening.beforeFlight.player, flight.visit == opening.beforeFlight.visit,
      flight.system == opening.beforeFlight.system,
      flight.pose == expectedFlight.pose, flight.anchors == expectedFlight.anchors,
      flight.nextActor == expectedFlight.nextActor,
      flight.nextSpawn == expectedFlight.nextSpawn,
      flight.nextEmission == expectedFlight.nextEmission,
      flight.nextIncident == expectedFlight.nextIncident
    else {
      c01InquiryStepRuntime.lastFailure = .staleOpening
      return
    }
    let end = opening.beforeFlight.physicalTime + opening.usedD
    guard opening.usedD.isFinite, opening.usedD > 0, opening.usedD <= 0.1,
      end.isFinite, end > opening.beforeFlight.physicalTime,
      witness.observedEnd == end, flight.physicalTime == end
    else {
      c01InquiryStepRuntime.lastFailure = .invalidNativeClock
      return
    }
    let sequence = opening.sequence.addingReportingOverflow(1)
    let order = opening.nativeOrder.addingReportingOverflow(1)
    guard !sequence.overflow, !order.overflow,
      sequence.partialValue < UInt64.max, order.partialValue < UInt64.max
    else {
      c01InquiryStepRuntime.lastFailure = .counterExhausted
      return
    }
    let data = NativeC01InquiryStepData(ownerSession: opening.session, sequence: opening.sequence,
      sceneEpoch: opening.epoch, player: opening.context.player.identity,
      caseID: opening.root.caseRecord.id, caseRevision: opening.root.caseRecord.revision,
      fixtureID: opening.fixture.fixtureID, generation: opening.fixture.generation,
      clockStart: opening.beforeFlight.physicalTime, clockEnd: end, usedD: opening.usedD)
    guard data.shapeValid else {
      c01InquiryStepRuntime.lastFailure = .invalidNativeClock
      return
    }
    c01InquiryStepRuntime.nextStepSequence = sequence.partialValue
    c01InquiryStepRuntime.nextNativeOrder = order.partialValue
    c01InquiryStepRuntime.currentClock = .init(data: data, nativeOrder: opening.nativeOrder,
      root: opening.root, fixture: opening.fixture)
    c01InquiryStepRuntime.lastFailure = nil
  }

  /// Derive a shorter opening only from the genuine current attempt. This is
  /// still not elapsed-time authority; the Game owner must seal its actual legs.
  func attainedC01InquiryClockOpening(
    _ opening: NativeC01InquiryClockOpening, usedD: Double
  ) -> NativeC01InquiryClockOpening? {
    guard usedD.isFinite, usedD > 0, usedD <= opening.usedD,
      opening.beforeFlight.physicalTime + usedD == commander.flightSimulation.physicalTime,
      c01InquiryStepRuntime.ownerSession == opening.session,
      c01InquiryStepRuntime.nextStepSequence == opening.sequence,
      c01InquiryStepRuntime.nextNativeOrder == opening.nativeOrder,
      nativeStationRuntimeEpoch == opening.epoch,
      commander.scriptState.savedC01Inquiry == opening.root
    else { return nil }
    return .init(session: opening.session, sequence: opening.sequence,
      nativeOrder: opening.nativeOrder, root: opening.root, fixture: opening.fixture,
      context: opening.context, epoch: opening.epoch, beforeFlight: opening.beforeFlight,
      usedD: usedD)
  }

  /// Attained cursor changes happen before any post-tick publication candidate.
  /// A failed writer cannot make this native step available for observation again.
  mutating func consumeC01InquiryAttainedClockStep() {
    c01InquiryStepRuntime.consumedClock = nil
    guard let clock = c01InquiryStepRuntime.currentClock else { return }
    c01InquiryStepRuntime.currentClock = nil
    let data = clock.data
    guard data.ownerSession == c01InquiryStepRuntime.ownerSession,
      c01InquiryStepRuntime.consumedThroughStep.map({ data.sequence > $0 }) ?? true
    else {
      c01InquiryStepRuntime.lastFailure = .duplicateStep
      return
    }
    if let prior = c01InquiryStepRuntime.consumedThroughStep {
      let next = prior.addingReportingOverflow(1)
      if next.overflow || next.partialValue != data.sequence {
        c01InquiryStepRuntime.chainInterrupted = true
      }
    } else if data.sequence != 1 {
      c01InquiryStepRuntime.chainInterrupted = true
    }
    c01InquiryStepRuntime.consumedThroughStep = data.sequence
    c01InquiryStepRuntime.consumedClock = clock
  }

  fileprivate mutating func finishC01InquiryClockFrameWithoutSceneModelSeal() {
    guard let clock = c01InquiryStepRuntime.consumedClock else { return }
    guard clock.data.ownerSession == c01InquiryStepRuntime.ownerSession,
      nativeStationRuntimeEpoch == clock.data.sceneEpoch,
      commander.flightSimulation.player == clock.data.player,
      commander.scriptState.savedC01Inquiry?.caseRecord.id == clock.data.caseID
    else {
      c01InquiryStepRuntime.lastFailure = .sourceChanged
      return
    }
    guard let model = c01InquiryStepRuntime.registeredModel else {
      c01InquiryStepRuntime.lastFailure = .missingNativeModelRegistration
      return
    }
    guard let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.institutionalSource.availability == .available,
      model.ownerSession == clock.data.ownerSession, model.owner == root.owner,
      model.caseID == clock.data.caseID, model.fixture == clock.fixture,
      model.sourceBirth == root.institutionalSource.birthOperation,
      let life = root.fixtureLifecycle.first(where: {
        $0.caseID == model.caseID && $0.fixture == model.fixture
      }), life.retirement == nil,
      [life.support, life.head0, life.head1, life.head2].map(\.binding) == model.bindings
    else {
      c01InquiryStepRuntime.lastFailure = .sourceChanged
      return
    }
    // Registration is real only after the physical receipt. It still does not
    // supply G1's whole-scene motion seal or authorize integration/observation.
    c01InquiryStepRuntime.lastFailure = .missingNativeSceneModelSeal
  }

  func c01InquiryR2PublicationMatches(_ intent: NativeC01InquiryR2PublicationIntent) -> Bool {
    guard let root = commander.scriptState.savedC01Inquiry, root == intent.selectedRoot,
      root.shapeValid, root.owner == commander.equipmentOwnerID,
      intent.session == c01InquiryStepRuntime.ownerSession,
      intent.nativeOrder < c01InquiryStepRuntime.nextNativeOrder,
      intent.command.nativeOrder == intent.nativeOrder,
      root.caseRecord.phase == .testCorrectiveModel,
      root.caseRecord.bench.commands.last == intent.command,
      intent.command.owner == root.owner, intent.command.caseID == root.caseRecord.id,
      intent.command.caseRevision == root.caseRecord.revision,
      intent.command.sourceBirth == root.institutionalSource.birthOperation
    else { return false }
    do { return try NativeC01InquiryOperatorRetainedSource.validate(root) }
    catch { return false }
  }

  /// Native source/identity checks for a clock's target, not a mesh/pose freeze
  /// or a substitute for G1's actual physical and motion resolvers.
  private func c01ClockCurrentFixture(_ root: NativeC01InquiryState,
    generation: NativeC01InquiryFixtureGeneration, context: EncounterContext
  ) -> NativeC01InquiryFixtureRef? {
    let matching = root.fixtureLifecycle.filter {
      $0.caseID == root.caseRecord.id && $0.fixture.fixtureID == generation.fixtureID
        && $0.fixture.generation == generation.generation
    }
    guard matching.count == 1, matching[0].retirement == nil else { return nil }
    let life = matching[0]
    guard life.fixture.matches(generation) else { return nil }
    let parts = [life.support, life.head0, life.head1, life.head2]
    for (index, part) in parts.enumerated() {
      guard case .present = part.presence, part.binding.actor.system == context.system,
        part.binding.actor.visit == context.visit,
        part.binding.spawn.member == UInt16(index)
      else { return nil }
      let current = bodies.filter { $0.id == part.binding.bodyID }
      guard current.count == 1 else { return nil }
      let body = current[0]
      let budget = NativeC01InquiryFixtureGeometry.physicalBudget(
        for: generation.parts[index].part)
      guard let physical = body.physical, physical.identity == part.binding.actor,
        physical.spawnIdentity == part.binding.spawn, physical.canonicalSpin == true,
        physical.npc == nil, physical.velocity.finite, physical.angularVelocity.finite,
        body.energy.isFinite, body.energy > 0, body.energy <= budget.energy,
        body.rotation == 0, body.rotationRate == 0,
        body.position.finite, body.orientation.validRotation,
        bodies.filter({ $0.physical?.identity == part.binding.actor }).count == 1,
        bodies.filter({ $0.physical?.spawnIdentity == part.binding.spawn }).count == 1
      else { return nil }
    }
    return life.fixture
  }
}

extension GameRuntime {
  /// Called at the reserved real frame boundary after mandatory P5 effects.
  func finishC01InquiryAttainedFrame() {
    game.finishC01InquiryClockFrameWithoutSceneModelSeal()
  }
}

/// Explicit required native input, deliberately UNISSUED. There is no factory.
/// Before any future constructor call is added, G1's genuine model-activity/
/// lifetime/correspondence receipt must be bound here. Clock + registration,
/// saved flags and mathematical classifier output cannot create this input.
final class NativeC01InquiryModelStepInput: Sendable {
  fileprivate let clock: NativeC01InquiryAcceptedClockStep
  fileprivate let registration: NativeC01InquiryModelRegistration
  fileprivate let before: NativeC01InquiryModelSnapshot
  fileprivate let acknowledged: [NativeC01InquiryR2WriterACK]
  private init(clock: NativeC01InquiryAcceptedClockStep,
    registration: NativeC01InquiryModelRegistration, before: NativeC01InquiryModelSnapshot,
    acknowledged: [NativeC01InquiryR2WriterACK])
  {
    self.clock = clock; self.registration = registration
    self.before = before; self.acknowledged = acknowledged
  }
}

/// Prepared DATA behind an unissued native input, never a native event seal.
/// No commit/phase mutation or successful live caller exists in this component.
final class NativeC01InquiryModelTransitionPlan: Sendable {
  let data: NativeC01InquiryModelStepTransitionData.Transition
  let firstNativeOrder: UInt64
  let nextNativeOrder: UInt64
  fileprivate let input: NativeC01InquiryModelStepInput
  fileprivate init(input: NativeC01InquiryModelStepInput,
    data: NativeC01InquiryModelStepTransitionData.Transition,
    firstNativeOrder: UInt64, nextNativeOrder: UInt64)
  {
    self.input = input; self.data = data
    self.firstNativeOrder = firstNativeOrder; self.nextNativeOrder = nextNativeOrder
  }
}

extension Game {
  func prepareC01InquiryModelTransition(_ input: NativeC01InquiryModelStepInput) throws
    -> NativeC01InquiryModelTransitionPlan
  {
    let clock = input.clock
    let model = input.registration
    guard c01InquiryStepRuntime.registeredModel === model,
      c01InquiryStepRuntime.consumedClock === clock,
      c01InquiryStepRuntime.liveModelSnapshot == input.before,
      c01InquiryStepRuntime.ownerSession == clock.data.ownerSession,
      model.ownerSession == clock.data.ownerSession,
      c01InquiryStepRuntime.consumedThroughStep == clock.data.sequence,
      c01InquiryStepRuntime.integratedThroughStep.map({ $0 < clock.data.sequence }) ?? true,
      let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.owner == model.owner, root.caseRecord.id == model.caseID,
      root.institutionalSource.birthOperation == model.sourceBirth,
      root.institutionalSource.availability == .available,
      model.fixture == clock.fixture,
      input.acknowledged.count <= 16_384
    else { throw NativeC01InquiryStepFailure.invalidModelStepInput }
    if let previous = input.before.lastStep {
      guard c01InquiryStepRuntime.integratedThroughStep == previous.sequence,
        previous.ownerSession == clock.data.ownerSession
      else { throw NativeC01InquiryStepFailure.invalidModelStepInput }
    } else {
      guard input.before == model.birthSnapshot else {
        throw NativeC01InquiryStepFailure.invalidModelStepInput
      }
    }
    guard try NativeC01InquiryOperatorRetainedSource.validate(root) else {
      throw NativeC01InquiryStepFailure.sourceUnavailable
    }
    var challenges: [UUID] = []
    for ordinal in 0..<3 {
      guard let challenge = root.caseRecord.mandate.challenge(ordinal) else {
        throw NativeC01InquiryStepFailure.invalidModelStepInput
      }
      challenges.append(challenge.id)
    }
    var pending: [NativeC01InquiryModelStepTransitionData.PendingControl] = []
    for acknowledgement in input.acknowledged {
      let intent = acknowledgement.intent
      let command = intent.command
      guard intent.session == model.ownerSession, intent.nativeOrder > 0,
        intent.nativeOrder < clock.nativeOrder, command.nativeOrder == intent.nativeOrder,
        command.ownerSession == model.ownerSession, command.kind == .setDetent,
        command.owner == model.owner, command.caseID == model.caseID,
        command.sourceBirth == model.sourceBirth, command.fixture == model.fixture,
        root.caseRecord.bench.commands.contains(command),
        let requested = command.requested.setting(command.challengeOrdinal)
      else { throw NativeC01InquiryStepFailure.invalidModelStepInput }
      pending.append(.init(commandID: command.id, challengeID: command.challengeID,
        challengeOrdinal: command.challengeOrdinal, acknowledgedOrder: intent.nativeOrder,
        requested: requested))
    }
    let transition = try NativeC01InquiryModelStepTransitionData.prepare(before: input.before,
      step: clock.data, fixture: model.fixture, challengeIDs: challenges, pending: pending)
    let applicationCount = transition.points.reduce(0) { $0 + $1.latches.count }
    guard root.caseRecord.bench.applications.count <= 16_384 - applicationCount else {
      throw NativeC01InquiryStepFailure.invalidModelStepInput
    }
    let next = c01InquiryStepRuntime.nextNativeOrder.addingReportingOverflow(
      UInt64(transition.nativeOperationCount))
    guard !next.overflow, next.partialValue < UInt64.max else {
      throw NativeC01InquiryStepFailure.counterExhausted
    }
    // Only a prepared range is returned. Neither native orders nor the actual
    // model/ACK/step cursors are consumed until a genuine future atomic commit.
    return .init(input: input, data: transition,
      firstNativeOrder: c01InquiryStepRuntime.nextNativeOrder, nextNativeOrder: next.partialValue)
  }
}
