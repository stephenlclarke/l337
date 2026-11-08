import Foundation

enum NativeC01InquiryFixtureAdmissionFailure: Error, Sendable {
  case unavailable, sourceMismatch, alreadyBorn, stalePlan, capacity, invalidPhysicalInput
}

/// Authenticated source intent only, not a birth or a placement permission.
final class NativeC01InquiryFixtureBirthIntent: Sendable {
  fileprivate let root: NativeC01InquiryState
  fileprivate let context: EncounterContext
  fileprivate let host: NativeMainStationDestinationContext
  fileprivate let epoch: UUID
  fileprivate let geometry: NativeC01InquiryFixtureGeometryPins
  fileprivate let beforeFlight: FlightSimulationState
  fileprivate let beforeBodies: [SpaceBody]
  fileprivate let beforeBodyID: Int
  fileprivate init(root: NativeC01InquiryState, context: EncounterContext,
    host: NativeMainStationDestinationContext, epoch: UUID,
    geometry: NativeC01InquiryFixtureGeometryPins, beforeFlight: FlightSimulationState,
    beforeBodies: [SpaceBody], beforeBodyID: Int)
  {
    self.root = root; self.context = context; self.host = host
    self.epoch = epoch; self.geometry = geometry
    self.beforeFlight = beforeFlight; self.beforeBodies = beforeBodies; self.beforeBodyID = beforeBodyID
  }
}

/// Nonobservational model candidate from the actual current birth intent.
/// Its decoder-free constructor cannot accept caller phases or pulse history.
final class NativeC01InquiryInitialModelPreparation: Sendable {
  fileprivate let source: NativeC01InquiryFixtureBirthIntent
  let ownerSession: UUID
  let snapshot: NativeC01InquiryModelSnapshot
  var sourceRoot: NativeC01InquiryState { source.root }
  var nativeEpoch: UUID { source.epoch }

  fileprivate init(source: NativeC01InquiryFixtureBirthIntent, ownerSession: UUID) {
    self.source = source; self.ownerSession = ownerSession
    let zero = NativeC01InquiryOscillatorData(phase: .zero, cycle: 0, pulseSequence: 0)
    let head = NativeC01InquiryHeadModelData(reference: zero, output: zero,
      appliedDetent: .zero, appliedControlRevision: 1)
    snapshot = .init(physicalTime: source.context.physicalTime, lastStep: nil,
      head0: head, head1: head, head2: head)
  }
}

/// No physical-input factory is issued. Native placement, closed-joint and
/// same-mesh/mass receipts remain prerequisites alongside the sealed model candidate.
/// DATA, a hull enum, and a caller Bool cannot obtain it.
final class NativeC01InquiryFixturePhysicalAdmission: Sendable {
  struct Part: Sendable {
    let kind: NativeC01InquiryFixtureGeometry.Part
    let hull: Hull
    let pose: ShipPose
    let mesh: Mesh
    let velocity: Vector3
    let angularVelocity: Vector3
    let massKilograms: Double
    let maximumEnergy: Double
  }
  fileprivate let source: NativeC01InquiryFixtureBirthIntent
  fileprivate let parts: [Part]
  fileprivate let frame: ShipPose
  fileprivate let placementCandidate: UInt64
  fileprivate let population: PopulationClass
  fileprivate let initialModel: NativeC01InquiryInitialModelPreparation
  fileprivate var model: NativeC01InquiryModelSnapshot { initialModel.snapshot }
  fileprivate init(source: NativeC01InquiryFixtureBirthIntent, parts: [Part], frame: ShipPose,
    placementCandidate: UInt64, population: PopulationClass,
    initialModel: NativeC01InquiryInitialModelPreparation)
  {
    self.source = source; self.parts = parts; self.frame = frame
    self.placementCandidate = placementCandidate; self.population = population
    self.initialModel = initialModel
  }
}

/// Native staging and the selected retention candidate precede physical commit.
final class NativeC01InquiryFixtureAdmissionPlan: Sendable {
  fileprivate let source: NativeC01InquiryFixtureBirthIntent
  fileprivate let beforeFlight: FlightSimulationState
  fileprivate let beforeBodies: [SpaceBody]
  fileprivate let beforeBodyID: Int
  fileprivate let flight: FlightSimulationState
  fileprivate let bodies: [SpaceBody]
  fileprivate let root: NativeC01InquiryState
  fileprivate let fixture: NativeC01InquiryFixtureRef
  fileprivate let bindings: [NativeC01InquiryFixtureBinding]
  fileprivate let modelInstallation: NativeC01InquiryInitialModelInstallation
  fileprivate init(source: NativeC01InquiryFixtureBirthIntent, beforeFlight: FlightSimulationState,
    beforeBodies: [SpaceBody], beforeBodyID: Int, flight: FlightSimulationState,
    bodies: [SpaceBody], root: NativeC01InquiryState, fixture: NativeC01InquiryFixtureRef,
    bindings: [NativeC01InquiryFixtureBinding],
    modelInstallation: NativeC01InquiryInitialModelInstallation)
  {
    self.source = source; self.beforeFlight = beforeFlight; self.beforeBodies = beforeBodies
    self.beforeBodyID = beforeBodyID; self.flight = flight; self.bodies = bodies
    self.root = root; self.fixture = fixture; self.bindings = bindings
    self.modelInstallation = modelInstallation
  }
}

/// Source recipe proposal only. It grants no native placement, body/mass
/// installation, world clearance, admission or activity receipt.
final class NativeC01InquiryFixtureStageProposal: Sendable {
  fileprivate let source: NativeC01InquiryFixtureBirthIntent
  fileprivate let parts: [NativeC01InquiryFixturePhysicalAdmission.Part]
  fileprivate let frame: ShipPose
  fileprivate let placementCandidate: UInt64
  fileprivate let population: PopulationClass
  fileprivate let initialModel: NativeC01InquiryInitialModelPreparation
  fileprivate var model: NativeC01InquiryModelSnapshot { initialModel.snapshot }
  fileprivate init(source: NativeC01InquiryFixtureBirthIntent,
    parts: [NativeC01InquiryFixturePhysicalAdmission.Part], frame: ShipPose,
    placementCandidate: UInt64, population: PopulationClass,
    initialModel: NativeC01InquiryInitialModelPreparation)
  {
    self.source = source; self.parts = parts; self.frame = frame
    self.placementCandidate = placementCandidate; self.population = population
    self.initialModel = initialModel
  }
}

/// Genuine SOURCE staging, never native admission. Only this source file can
/// construct the token; copied geometry/body facts cannot recreate it. No Game
/// mutation or receipt occurs until a separately genuine G1 permit is joined.
final class NativeC01InquiryFixtureStagedCohort: Sendable {
  fileprivate let proposal: NativeC01InquiryFixtureStageProposal
  fileprivate let plan: NativeC01InquiryFixtureAdmissionPlan
  let afterBodies: [SpaceBody]
  let afterBodyID: Int

  var sourceIntent: NativeC01InquiryFixtureBirthIntent { proposal.source }
  var context: EncounterContext { proposal.source.context }
  var nativeEpoch: UUID { proposal.source.epoch }
  var ownerSession: UUID { proposal.initialModel.ownerSession }
  var fixture: NativeC01InquiryFixtureRef { plan.fixture }
  var bindings: [NativeC01InquiryFixtureBinding] { plan.bindings }
  var stagedBodies: [SpaceBody] { plan.bodies }
  var stagedFlight: FlightSimulationState { plan.flight }
  var beforeFlight: FlightSimulationState { plan.beforeFlight }
  var beforeBodies: [SpaceBody] { plan.beforeBodies }
  var beforeBodyID: Int { plan.beforeBodyID }
  var proposedRoot: NativeC01InquiryState { plan.root }
  var sourceFrame: ShipPose { proposal.frame }
  var partRecipes: [NativeC01InquiryFixturePhysicalAdmission.Part] { proposal.parts }
  var population: PopulationClass { proposal.population }
  var initialModelSnapshot: NativeC01InquiryModelSnapshot { proposal.model }

  fileprivate init(proposal: NativeC01InquiryFixtureStageProposal,
    plan: NativeC01InquiryFixtureAdmissionPlan, afterBodies: [SpaceBody], afterBodyID: Int)
  {
    self.proposal = proposal; self.plan = plan; self.afterBodies = afterBodies
    self.afterBodyID = afterBodyID
  }
}

/// Only the successful native commit constructs this receipt. No decoder or
/// retained fixture row can issue it; it is not the protected writer's ACK.
struct NativeC01InquiryFixtureBirthReceipt: Sendable {
  let fixture: NativeC01InquiryFixtureRef
  let bindings: [NativeC01InquiryFixtureBinding]
  let modelInstallation: NativeC01InquiryInitialModelInstallation
  fileprivate init(_ plan: NativeC01InquiryFixtureAdmissionPlan) {
    fixture = plan.fixture; bindings = plan.bindings; modelInstallation = plan.modelInstallation
  }
}

/// Source geometry consistency only. A true result grants no placement, scene,
/// joint, model, mass installation or private physical-admission authority.
enum NativeC01InquiryFixtureAdmissionData {
  static func partsMatchAdoptedGeometry(
    _ parts: [NativeC01InquiryFixturePhysicalAdmission.Part], frame: ShipPose
  ) -> Bool {
    guard parts.count == 4, parts.map(\.kind) == [.support, .head0, .head1, .head2],
      frame.position.finite, frame.orientation.validRotation
    else { return false }
    for part in parts {
      let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: part.kind)
      let budget = NativeC01InquiryFixtureGeometry.physicalBudget(for: part.kind)
      guard part.mesh.vertices == descriptor.mesh.vertices, part.mesh.faces == descriptor.mesh.faces,
        part.massKilograms == budget.massKilograms, part.maximumEnergy == budget.energy,
        part.pose.position == frame.systemPoint(descriptor.centreNative),
        part.pose.orientation == frame.orientation,
        part.velocity.finite, part.angularVelocity.finite
      else { return false }
    }
    return true
  }
}

extension Game {
  func prepareC01InquiryFixtureBirthIntent() throws -> NativeC01InquiryFixtureBirthIntent {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      let root = commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.owner == commander.equipmentOwnerID,
      root.caseRecord.phase == .requestCase, root.caseRecord.measurements.isEmpty,
      root.caseRecord.bench.commands.isEmpty, root.caseRecord.bench.applications.isEmpty,
      root.caseRecord.bench.trials.isEmpty, root.caseRecord.audit == nil,
      root.caseRecord.finalReceipt == nil, root.institutionalSource.availability == .available,
      root.institutionalSource.availableDuty(.intake) != nil,
      let context = gameplayContext(), case .living(let host) = nativeOriginalMainStationDestination,
      host.identity == root.institutionalSource.host, acceptsNativeMainStationDestination(host),
      context.player.identity == commander.flightSimulation.player
    else { throw NativeC01InquiryFixtureAdmissionFailure.unavailable }
    guard root.caseRecord.fixtureGenerations.isEmpty,
      !root.fixtureLifecycle.contains(where: { $0.caseID == root.caseRecord.id })
    else { throw NativeC01InquiryFixtureAdmissionFailure.alreadyBorn }
    guard try NativeC01InquiryOperatorRetainedSource.validate(root) else {
      throw NativeC01InquiryFixtureAdmissionFailure.sourceMismatch
    }
    try c01FixtureChallengeSourceMatches(root.caseRecord)
    return .init(root: root, context: context, host: host, epoch: nativeStationRuntimeEpoch,
      geometry: try NativeC01InquiryFixtureGeometry.expectedGeometryPins(),
      beforeFlight: commander.flightSimulation, beforeBodies: bodies, beforeBodyID: nextBodyID)
  }

  func prepareC01InquiryInitialModel(_ source: NativeC01InquiryFixtureBirthIntent) throws
    -> NativeC01InquiryInitialModelPreparation
  {
    guard c01FixtureIntentIsCurrent(source) else {
      throw NativeC01InquiryFixtureAdmissionFailure.stalePlan
    }
    return .init(source: source, ownerSession: c01InquiryStepRuntime.ownerSession)
  }

  /// This entry is unreachable until the actual private physical-input factory
  /// exists. No allocation precedes its authentic source and policy currentness.
  /// Legacy typed entry remains unissued: no StageProposal or StagedCohort
  /// exposes a PhysicalAdmission/AdmissionPlan constructor or getter.
  func prepareC01InquiryFixtureAdmission(_ physical: NativeC01InquiryFixturePhysicalAdmission) throws
    -> NativeC01InquiryFixtureAdmissionPlan
  {
    let source = physical.source
    guard c01FixtureIntentIsCurrent(source), physical.initialModel.source === source,
      physical.initialModel.ownerSession == c01InquiryStepRuntime.ownerSession,
      NativeC01InquiryFixtureAdmissionData.partsMatchAdoptedGeometry(physical.parts, frame: physical.frame),
      physical.placementCandidate < UInt64.max, physical.model.shapeValid,
      physical.model.physicalTime == source.context.physicalTime, physical.model.lastStep == nil
    else { throw NativeC01InquiryFixtureAdmissionFailure.invalidPhysicalInput }
    let proposal = NativeC01InquiryFixtureStageProposal(source: physical.source,
      parts: physical.parts, frame: physical.frame, placementCandidate: physical.placementCandidate,
      population: physical.population, initialModel: physical.initialModel)
    return try c01PrepareSourceFixtureCohort(proposal)
  }

  func prepareC01InquiryFixtureStageProposal(_ placement: NativeC01InquiryFixturePlacementCandidate,
    initialModel: NativeC01InquiryInitialModelPreparation,
    parts: [NativeC01InquiryFixturePhysicalAdmission.Part], population: PopulationClass
  ) throws -> NativeC01InquiryFixtureStageProposal
  {
    let source = placement.source
    guard c01FixtureIntentIsCurrent(source), initialModel.source === source,
      initialModel.ownerSession == c01InquiryStepRuntime.ownerSession,
      placement.index < UInt64(NativeC01InquiryFixturePlacementData.maximumCandidates),
      NativeC01InquiryFixtureAdmissionData.partsMatchAdoptedGeometry(parts, frame: placement.frame)
    else { throw NativeC01InquiryFixtureAdmissionFailure.invalidPhysicalInput }
    return .init(source: source, parts: parts, frame: placement.frame, placementCandidate: placement.index,
      population: population, initialModel: initialModel)
  }

  /// Real copy allocation and Root/model preflight, without a native permission.
  /// Actual registry/geometry/world proof must consume THIS token by identity.
  func prepareC01InquiryFixtureStagedCohort(_ proposal: NativeC01InquiryFixtureStageProposal) throws
    -> NativeC01InquiryFixtureStagedCohort
  {
    let plan = try c01PrepareSourceFixtureCohort(proposal)
    let afterBodies = plan.beforeBodies + plan.bodies
    let afterBodyID = plan.beforeBodyID.addingReportingOverflow(plan.bodies.count)
    guard !afterBodyID.overflow, afterBodyID.partialValue < 1_000_000_000
    else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
    return .init(proposal: proposal, plan: plan, afterBodies: afterBodies, afterBodyID: afterBodyID.partialValue)
  }

  /// Source/currentness preflight only. A true result cannot construct a native
  /// permit, registry, geometry proof, physical receipt or model activity.
  func c01InquiryStagedCohortIsCurrentForNativeOwner(_ staged: NativeC01InquiryFixtureStagedCohort) -> Bool {
    let plan = staged.plan
    return plan.source === staged.proposal.source && c01FixtureIntentIsCurrent(plan.source)
      && staged.proposal.initialModel.source === plan.source
      && staged.ownerSession == c01InquiryStepRuntime.ownerSession
      && nativeStationRuntimeEpoch == staged.nativeEpoch
      && commander.flightSimulation == plan.beforeFlight
      && bodies == plan.beforeBodies && nextBodyID == plan.beforeBodyID
      && c01InquiryStepRuntime.canInstallInitialModel(plan.modelInstallation)
  }

  private func c01PrepareSourceFixtureCohort(_ physical: NativeC01InquiryFixtureStageProposal) throws
    -> NativeC01InquiryFixtureAdmissionPlan
  {
    let source = physical.source
    guard c01FixtureIntentIsCurrent(source), physical.initialModel.source === source,
      physical.initialModel.ownerSession == c01InquiryStepRuntime.ownerSession,
      NativeC01InquiryFixtureAdmissionData.partsMatchAdoptedGeometry(physical.parts, frame: physical.frame),
      physical.placementCandidate < UInt64.max, physical.model.shapeValid,
      physical.model.physicalTime == source.context.physicalTime, physical.model.lastStep == nil
    else { throw NativeC01InquiryFixtureAdmissionFailure.invalidPhysicalInput }
    let before = commander.flightSimulation
    // These existing native capacity bounds remain in addition to the full
    // source-specific policy proof required by the opaque physical input.
    guard source.context.budget.maximum >= physical.parts.count,
      source.context.budget.total <= source.context.budget.maximum - physical.parts.count,
      source.context.budget.active[physical.population, default: 0]
        <= physical.population.maximum - physical.parts.count
    else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
    guard bodies.reduce(0, { $0 + $1.scriptNativeUnits }) <= 1024 - physical.parts.count,
      physical.parts.count <= 999_999_999 - nextBodyID,
      UInt64(physical.parts.count) < UInt64.max - before.nextActor,
      before.nextSpawn < UInt64.max - 1
    else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
    var staged = before
    guard let sequence = staged.allocateSpawn() else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
    let operation = UUID()
    let fixtureID = UUID()
    var admitted: [SpaceBody] = []
    var states: [NativeC01InquiryFixturePartState] = []
    var lives: [NativeC01InquiryPartLife] = []
    var bindings: [NativeC01InquiryFixtureBinding] = []
    for (slot, part) in physical.parts.enumerated() {
      guard let actor = staged.allocateActor() else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
      let spawn = SpawnIdentity(system: source.context.system, visit: source.context.visit,
        sequence: sequence, member: UInt16(slot), producer: .c01Inquiry)
      let bodyID = nextBodyID + slot
      let binding = NativeC01InquiryFixtureBinding(actor: actor, spawn: spawn,
        bodyID: bodyID, revision: 1, operation: operation)
      var body = SpaceBody(id: bodyID, hull: part.hull, position: staged.pose.shipPoint(part.pose.position))
      body.orientation = part.pose.orientation.relative(to: staged.pose.orientation)
      body.energy = part.maximumEnergy; body.missiles = 0; body.ecmEnabled = false; body.rotationRate = 0
      body.physical = .init(identity: actor, population: physical.population, npc: nil,
        velocity: part.velocity, spawnIdentity: spawn, angularVelocity: part.angularVelocity)
      body.physical?.canonicalSpin = true
      admitted.append(body); bindings.append(binding)
      states.append(.init(part: part.kind, birthBinding: binding, binding: binding,
        birthPose: part.pose, pose: part.pose, velocity: part.velocity,
        angularVelocity: part.angularVelocity, energy: body.energy,
        physicalTime: source.context.physicalTime, presence: .present))
      lives.append(.init(binding: binding, pose: part.pose, velocity: part.velocity,
        angularVelocity: part.angularVelocity, energy: body.energy,
        physicalTime: source.context.physicalTime, presence: .present, bindingHistory: []))
    }
    let current = source.root.caseRecord
    let fixture = NativeC01InquiryFixtureRef(fixtureID: fixtureID, generation: 1,
      admissionOperation: operation, geometryRevision: NativeC01InquiryFixtureGeometry.revision,
      geometryPins: source.geometry, metricRevision: NativeC01InquiryFixtureGeometry.metricRevision,
      lawRevision: NativeC01InquiryHeadModelData.lawRevision)
    let generation = NativeC01InquiryFixtureGeneration(owner: source.root.owner, caseID: current.id,
      caseOrdinal: current.ordinal, sourceBirth: source.root.institutionalSource.birthOperation,
      sourceRevision: source.root.institutionalSource.revision, fixtureID: fixtureID,
      generation: 1, revision: 1, admissionOperation: operation,
      admissionArrival: current.mandate.intake.arrival, admissionPhysicalTime: source.context.physicalTime,
      inertialFrame: physical.frame, placementCandidate: physical.placementCandidate,
      geometryRevision: fixture.geometryRevision, geometryPins: fixture.geometryPins,
      metricRevision: fixture.metricRevision, metresPerWorldUnit: NativeC01InquiryFixtureGeometry.metresPerWorldUnit,
      lawRevision: fixture.lawRevision, support: states[0], head0: states[1], head1: states[2], head2: states[3],
      retirement: nil, modelSnapshot: physical.model)
    let life = NativeC01InquiryFixtureLife(caseID: current.id, fixture: fixture, revision: 1,
      support: lives[0], head0: lives[1], head1: lives[2], head2: lives[3],
      modelSnapshot: physical.model, retirement: nil)
    let revision = current.revision.addingReportingOverflow(1)
    guard !revision.overflow, revision.partialValue < UInt64(Int64.max) else {
      throw NativeC01InquiryFixtureAdmissionFailure.capacity
    }
    let selected = NativeC01InquiryCase(id: current.id, ordinal: current.ordinal,
      revision: revision.partialValue, phase: current.phase, mandate: current.mandate,
      fixtureGenerations: [generation], measurements: current.measurements, bench: current.bench,
      audit: current.audit, finalReceipt: current.finalReceipt,
      originalOutcomeReferences: current.originalOutcomeReferences)
    let retained = NativeC01InquiryState(owner: source.root.owner, nextCaseOrdinal: source.root.nextCaseOrdinal,
      institutionalSource: source.root.institutionalSource, caseRecord: selected,
      priorCases: source.root.priorCases, fixtureLifecycle: source.root.fixtureLifecycle + [life])
    guard staged.valid, retained.shapeValid,
      try JSONEncoder().encode(retained).count <= 33_554_432
    else { throw NativeC01InquiryFixtureAdmissionFailure.capacity }
    let modelInstallation = try prepareC01InquiryInitialModelInstallation(
      physical.initialModel, selectedRoot: retained, fixture: fixture, bindings: bindings)
    return .init(source: source, beforeFlight: before, beforeBodies: bodies, beforeBodyID: nextBodyID,
      flight: staged, bodies: admitted, root: retained, fixture: fixture, bindings: bindings,
      modelInstallation: modelInstallation)
  }

  /// Native permission comes ONLY from the real G1 owner. This private Game
  /// is application storage, not evidence of geometry, source life or authority.
  mutating func commitC01InquiryFixtureAdmission(_ staged: NativeC01InquiryFixtureStagedCohort,
    permit: NativeC01InquiryNativeAdmissionPermit,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> NativeC01InquiryFixtureBirthReceipt {
    let installation = permit.registryInstallation
    guard c01InquiryStagedCohortIsCurrentForNativeOwner(staged),
      permit.matches(staged, current: self),
      canInstallC01InquiryNativeRegistry(installation, for: staged)
    else { throw NativeC01InquiryFixtureAdmissionFailure.stalePlan }
    let plan = staged.plan
    // Preallocate receipt/value ownership before application. It cannot escape
    // on failure and is returned only after complete live adoption.
    let receipt = NativeC01InquiryFixtureBirthReceipt(plan)
    var candidate = self
    candidate.commander.flightSimulation = plan.flight
    candidate.bodies = staged.afterBodies
    candidate.nextBodyID = staged.afterBodyID
    candidate.commander.scriptState.savedC01Inquiry = plan.root
    candidate.commitValidatedC01InquiryNativeRegistry(installation)
    candidate.commitValidatedC01InquiryInitialModel(plan.modelInstallation)
    try GameRuntime.validateC01InquiryPrivateBirthCandidate(candidate, navigationBinding: navigationBinding)
    // No await or publisher/callback can interleave. Recheck the actual BASE,
    // never use private candidate existence or its values as native permission.
    guard c01InquiryStagedCohortIsCurrentForNativeOwner(staged),
      permit.matches(staged, current: self),
      canInstallC01InquiryNativeRegistry(installation, for: staged)
    else { throw NativeC01InquiryFixtureAdmissionFailure.stalePlan }
    self = candidate
    return receipt
  }

  /// Source currentness only; native physical qualification remains mandatory.
  func c01InquiryFixtureBirthIntentIsCurrentForNativeOwner(
    _ intent: NativeC01InquiryFixtureBirthIntent
  ) -> Bool {
    c01FixtureIntentIsCurrent(intent)
  }

  private func c01FixtureIntentIsCurrent(_ intent: NativeC01InquiryFixtureBirthIntent) -> Bool {
    !docked && !paused && screen.isFlight && energy.isFinite && energy > 0
      && nativeStationRuntimeEpoch == intent.epoch
      && commander.scriptState.savedC01Inquiry == intent.root
      && commander.flightSimulation == intent.beforeFlight
      && bodies == intent.beforeBodies && nextBodyID == intent.beforeBodyID
      && gameplayContext() == intent.context && acceptsNativeMainStationDestination(intent.host)
  }

  private func c01FixtureChallengeSourceMatches(_ current: NativeC01InquiryCase) throws {
    let content = try NativeC01CharterArchiveApproval.load()
    let registry = try NativeCharterArchiveRegistryApproval.load()
    let mandate = current.mandate
    guard let group = content.archive.sourceGroups[mandate.sourcePins.sourceID],
      let source = registry.source(for: mandate.sourcePins.sourceID),
      group.challengeArchiveRoles.count == 3, source.observations.count == 3,
      mandate.profile.selector == group.sourceBinding.recoveryProfileSelector.jsonPointer,
      mandate.profile.commit == group.sourceBinding.recoveryProfileSelector.commit,
      mandate.profile.path == group.sourceBinding.recoveryProfileSelector.path,
      mandate.profile.sha256 == group.sourceBinding.recoveryProfileSelector.sha256,
      mandate.profile.schema == content.calibration.schema
    else { throw NativeC01InquiryFixtureAdmissionFailure.sourceMismatch }
    for ordinal in 0..<3 {
      guard let challenge = mandate.challenge(ordinal) else { throw NativeC01InquiryFixtureAdmissionFailure.sourceMismatch }
      let role = group.challengeArchiveRoles[ordinal]
      let observed = source.observations[ordinal]
      guard challenge.caseID == current.id, challenge.sourceID == role.sourceID,
        challenge.ordinal == role.challengeOrdinal, challenge.contentRevision == role.contentRevision,
        challenge.archive == .init(recordID: observed.recordID, replicaID: observed.replicaID,
          originIdentity: observed.originIdentity, originDomain: observed.originDomain,
          payloadSHA256: observed.payloadSHA256),
        challenge.modelInput == .init(resourcePath: role.modelInput.resourcePath,
          resourceSHA256: role.modelInput.resourceSHA256, profileSchema: role.modelInput.profileSchema,
          jsonPointer: role.modelInput.jsonPointer, offsetDegrees: role.modelInput.offsetDegrees)
      else { throw NativeC01InquiryFixtureAdmissionFailure.sourceMismatch }
    }
  }
}

/// Screened position proposal only. This is not full-solid/joint approval,
/// protected-corridor permission, an installed physical mesh/mass or a model.
final class NativeC01InquiryFixturePlacementCandidate: Sendable {
  fileprivate let source: NativeC01InquiryFixtureBirthIntent
  let frame: ShipPose
  let index: UInt64
  let envelopeRadius: Double
  fileprivate init(source: NativeC01InquiryFixtureBirthIntent, frame: ShipPose,
    index: UInt64, envelopeRadius: Double)
  {
    self.source = source; self.frame = frame
    self.index = index; self.envelopeRadius = envelopeRadius
  }
}

enum NativeC01InquiryFixturePlacementFailure: Error, Sendable {
  case staleSource, invalidStationFrame, invalidGeometry, noCandidateFits
}

/// Deterministic source recipe DATA. Constructing a frame grants no admission.
enum NativeC01InquiryFixturePlacementData {
  static let maximumCandidates = 64

  static func frame(index: Int, station: ShipPose, outward: Vector3) -> ShipPose? {
    guard (0..<maximumCandidates).contains(index), station.position.finite,
      station.orientation.validRotation, outward.finite,
      outward.length.isFinite, outward.length > 0
    else { return nil }
    let metric = NativeC01InquiryFixtureGeometry.metresPerWorldUnit
    guard metric.isFinite, metric > 0 else { return nil }
    let offset = 5_000.0 + Double(index) * 5_000.0
    let position = station.position + outward * (20_000.0 / metric)
      + station.orientation.x * (offset / metric)
    guard position.finite, position.length.isFinite else { return nil }
    return .init(position: position, orientation: station.orientation)
  }

  static func envelopeRadius(orientation: Basis3) -> Double? {
    let metric = NativeC01InquiryFixtureGeometry.metresPerWorldUnit
    guard metric.isFinite, metric > 0, orientation.validRotation else { return nil }
    var radius = 0.0
    for kind in NativeC01InquiryFixtureGeometry.Part.allCases {
      let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: kind)
      guard !descriptor.mesh.vertices.isEmpty else { return nil }
      for vertex in descriptor.mesh.vertices {
        let point = orientation.apply(descriptor.centreNative + vertex)
        guard point.finite else { return nil }
        // An outward-rounded L1 bound encloses the represented source vertex.
        let xy = (abs(point.x) + abs(point.y)).nextUp
        let bound = (xy + abs(point.z)).nextUp
        guard bound.isFinite else { return nil }
        radius = max(radius, bound)
      }
    }
    let envelope = (radius + (2_000.0 / metric).nextUp).nextUp
    guard envelope.isFinite, envelope > 0 else { return nil }
    return envelope
  }
}

extension Game {
  /// A real retained-source intent is mandatory before the bounded search. The
  /// native wrapper is read-only and may conservatively reject a valid position.
  /// Its candidate never bypasses the remaining physical-input prerequisites.
  func prepareC01InquiryFixturePlacementCandidate(_ source: NativeC01InquiryFixtureBirthIntent) throws
    -> NativeC01InquiryFixturePlacementCandidate
  {
    guard c01FixtureIntentIsCurrent(source) else {
      throw NativeC01InquiryFixturePlacementFailure.staleSource
    }
    let stations = bodies.filter {
      $0.id == 0 && $0.hull == .station && $0.energy > 0
        && $0.physical?.identity == source.host.observation.actor
    }
    guard stations.count == 1 else {
      throw NativeC01InquiryFixturePlacementFailure.invalidStationFrame
    }
    let station = stations[0]
    let stationFrame = modelPose(of: station)
    let outward = source.beforeFlight.pose.orientation.apply(station.entranceNormal)
    guard let radius = NativeC01InquiryFixturePlacementData.envelopeRadius(orientation: stationFrame.orientation) else {
      throw NativeC01InquiryFixturePlacementFailure.invalidGeometry
    }
    for index in 0..<NativeC01InquiryFixturePlacementData.maximumCandidates {
      guard c01FixtureIntentIsCurrent(source) else {
        throw NativeC01InquiryFixturePlacementFailure.staleSource
      }
      guard let frame = NativeC01InquiryFixturePlacementData.frame(
        index: index, station: stationFrame, outward: outward)
      else { throw NativeC01InquiryFixturePlacementFailure.invalidStationFrame }
      let refusal = c01InquiryPlacementEnvelopeRefusal(
        center: frame.position, radius: radius, context: source.context)
      guard c01FixtureIntentIsCurrent(source), refusal != .staleContext else {
        throw NativeC01InquiryFixturePlacementFailure.staleSource
      }
      if refusal == nil {
        return .init(source: source, frame: frame, index: UInt64(index), envelopeRadius: radius)
      }
    }
    throw NativeC01InquiryFixturePlacementFailure.noCandidateFits
  }
}
