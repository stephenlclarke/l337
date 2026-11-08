import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryLifecycleTests {
  @Test func rootAbsentLeavesOrdinaryDeadBodiesAndStateUnchanged() throws {
    var game = Game(executive: false)
    var body = SpaceBody(id: 900, hull: .sidewinder, position: .init(0, 0, 0))
    body.energy = 0
    game.bodies.append(body)
    let bodies = game.bodies
    let flight = game.commander.flightSimulation
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    #expect(game.prepareC01InquiryDestroyedRemoval().isEmpty)
    try game.captureC01InquiryCurrentLife()
    #expect(!game.c01InquiryRequiresNativeParking(beforeRemoving: body))
    #expect(game.bodies == bodies && game.commander.flightSimulation == flight)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }

  @Test(arguments: ["body", "actor", "spawn"])
  func bindingDataRequiresExactBodyActorAndSpawn(form: String) {
    let system = SystemIdentity(galaxy: 0, system: 0)
    let actor = ActorIdentity(system: system, visit: 1, entity: 2)
    let spawn = SpawnIdentity(system: system, visit: 1, sequence: 1, member: 0, producer: .ambient)
    let binding = NativeC01InquiryFixtureBinding(actor: actor, spawn: spawn,
      bodyID: 1, revision: 1, operation: UUID())
    #expect(!binding.shapeValid)  // Synthetic ambient DATA is not a native inquiry binding.
    #expect(NativeC01InquiryLifecycleFacts.matchesBinding(binding,
      bodyID: 1, actor: actor, spawn: spawn))
    #expect(!NativeC01InquiryLifecycleFacts.matchesBinding(binding,
      bodyID: form == "body" ? 2 : 1,
      actor: form == "actor" ? .init(system: system, visit: 1, entity: 3) : actor,
      spawn: form == "spawn"
        ? .init(system: system, visit: 1, sequence: 2, member: 0, producer: .ambient) : spawn))
  }

  @Test(arguments: ["missing-id", "wrong-id", "missing-origin", "wrong-origin", "hit"])
  func terminalStampDataRequiresFullOriginAndIncidentIdentity(form: String) {
    let system = SystemIdentity(galaxy: 0, system: 0)
    let player = ActorIdentity(system: system, visit: 1, entity: 0)
    let origin = AttackOrigin(emissionID: 1, owner: player, emittedAt: 0, ownerLegalAtEmission: .init())
    let other = AttackOrigin(emissionID: 2, owner: player, emittedAt: 0, ownerLegalAtEmission: .init())
    func incident(_ outcome: AttackOutcome) -> CombatIncident {
      .init(id: 1, physicalTime: 0, origin: origin,
        victim: .init(system: system, visit: 1, entity: 2), kind: .laser, outcome: outcome,
        position: .init(0, 0, 0), victimLegalBeforeAttack: nil, firstAggressor: nil,
        victimRole: nil, victimIsStation: false, laser: nil, mount: nil, victimPart: nil)
    }
    // Public incident DATA cannot construct the fileprivate accepted transport.
    #expect(NativeC01InquiryLifecycleFacts.terminalStampMatches(
      incident(.destruction), incidentID: 1, origin: origin))
    #expect(!NativeC01InquiryLifecycleFacts.terminalStampMatches(
      incident(form == "hit" ? .hit : .destruction),
      incidentID: form == "missing-id" ? nil : form == "wrong-id" ? 2 : 1,
      origin: form == "missing-origin" ? nil : form == "wrong-origin" ? other : origin))
  }
}

/// NONREGISTERED: G1 must supply the actual approved, born and currently installed
/// inquiry runtime. No root, birth receipt, model registration, actor, source or
/// positive physical fixture is manufactured. Only a copied retained timestamp
/// is corrupted to test refusal before the common writer can normalize it.
func c01InquiryActualCurrentLifeRejectsFutureRetainedTimeOracle(runtime: GameRuntime) async throws {
  _ = try NativeC01CharterArchiveApproval.load()
  _ = try NativeCharterArchiveRegistryApproval.load()
  let actual = await runtime.snapshot()
  let root = try #require(actual.commander.scriptState.savedC01Inquiry)
  try #require(root.shapeValid && root.owner == actual.commander.equipmentOwnerID)
  try #require(actual.c01InquiryStepRuntime.hasNativeModelRegistration)
  try #require(root.institutionalSource.availability == .available)
  try #require(NativeC01InquiryScene.currentLifeMatches(root,
    world: actual.scriptWorldSave, commander: actual.commander))
  let index = try #require(root.fixtureLifecycle.firstIndex {
    $0.caseID == root.caseRecord.id && $0.retirement == nil
  })
  let life = root.fixtureLifecycle[index]
  let parts = [life.support, life.head0, life.head1, life.head2]
  for part in parts {
    guard case .present = part.presence else {
      Issue.record("G1 must supply four genuine present parts for this capture oracle")
      return
    }
    try #require(part.physicalTime == actual.commander.flightSimulation.physicalTime)
  }
  let future = actual.commander.flightSimulation.physicalTime + 1
  try #require(future.isFinite && future <= 1e12)
  try #require(future > actual.commander.flightSimulation.physicalTime)
  // Each slot independently crosses the existing Scene check's future-time boundary.
  for slot in parts.indices {
    let original = parts[slot]
    var corruptedParts = parts
    corruptedParts[slot] = .init(binding: original.binding, pose: original.pose,
      velocity: original.velocity, angularVelocity: original.angularVelocity,
      energy: original.energy, physicalTime: future, presence: original.presence,
      bindingHistory: original.bindingHistory)
    var rows = root.fixtureLifecycle
    rows[index] = .init(caseID: life.caseID, fixture: life.fixture, revision: life.revision,
      support: corruptedParts[0], head0: corruptedParts[1], head1: corruptedParts[2],
      head2: corruptedParts[3], modelSnapshot: life.modelSnapshot, retirement: life.retirement)
    let corruptRoot = NativeC01InquiryState(owner: root.owner, nextCaseOrdinal: root.nextCaseOrdinal,
      institutionalSource: root.institutionalSource, caseRecord: root.caseRecord,
      priorCases: root.priorCases, fixtureLifecycle: rows)
    // The regression must reach capture's chronology check, not fail shallow DATA shape first.
    try #require(corruptRoot.shapeValid)
    var candidate = actual
    candidate.commander.scriptState.savedC01Inquiry = corruptRoot
    try #require(!NativeC01InquiryScene.currentLifeMatches(corruptRoot,
      world: candidate.scriptWorldSave, commander: candidate.commander))
    let before = candidate.commander
    var refusedForFutureTime = false
    do { try candidate.captureC01InquiryCurrentLife() }
    catch NativeC01InquiryLifecycleFailure.sourceMismatch { refusedForFutureTime = true }
    #expect(refusedForFutureTime)
    #expect(candidate.commander == before)
    #expect(candidate.commander.scriptState.savedC01Inquiry == corruptRoot)
    #expect(candidate.bodies == actual.bodies && candidate.celestials == actual.celestials)
    #expect(candidate.gameplayRevision == actual.gameplayRevision)
    #expect(candidate.nativeStationRuntimeEpoch == actual.nativeStationRuntimeEpoch)
    #expect(candidate.commander.flightSimulation == actual.commander.flightSimulation)
  }
  // The supplied genuine runtime was never changed by a corrupted comparison candidate.
  let retained = await runtime.snapshot()
  #expect(retained.commander == actual.commander && retained.bodies == actual.bodies)
}
