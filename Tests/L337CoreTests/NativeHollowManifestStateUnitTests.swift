import Foundation
import Testing

@testable import L337Core

/// Controlled structural records only. No real command, native effect, life or motion is issued.
struct NativeHollowManifestStateUnitTests {
  private typealias State = NativeHollowManifestState

  private func fixture() throws -> State {
    let owner = UUID()
    let system = NativeHollowManifestDefinition.issuer
    let dock = NativeMainStationDockReceipt(
      station: .init(
        world: owner, system: system,
        resource: Game.worldResourceIdentity("main-station-v1:main-orbital:1:120")),
      actor: .init(system: system, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 10)
    let price = try #require(
      OriginalLiveMarkets.initialQuote(galaxy: 1, system: 120, commodity: 13)
    ).bidPrice
    let sale = NativeFirstCommoditySale(
      operation: UUID(), owner: owner, commodity: 13, dock: dock, physicalTime: 10,
      calendarOperation: 0, unitPrice: price, quantity: 1,
      before: .init(stock: 20, cargo: 1, credits: 100),
      after: .init(stock: 21, cargo: 0, credits: 100 + price))
    let birth = try NativeHollowManifestSourceBirth.preparing(
      .init(
        mission: UUID(), owner: owner, commission: UUID(), carrier: UUID(), inventoryRevision: 1,
        dock: dock, sale: sale, physicalTime: 20, firstSourceSequence: 50))
    let geometry = NativeHollowManifestSealGeometryReference(
      rootGeometryHash: ScriptPackLibrary.hash(
        try ScriptPackLibrary.canonicalGeometry(birth.rootDesign)),
      sealGeometryHash: ScriptPackLibrary.hash(
        try ScriptPackLibrary.canonicalGeometry(birth.master.template)),
      revision: 1,
      componentPose: .init(
        position: NativeC03SealGeometry.componentPosition,
        orientation: NativeC03SealGeometry.componentOrientation), rootScale: 1, componentScale: 1)
    let admissions: [State.Admission] = birth.originals.enumerated().map { index, source in
      .init(
        reference: .init(slot: source.slot, revision: 1),
        original: .init(
          slot: source.slot, mission: birth.input.mission, owner: owner, source: source.source,
          hull: source.hull, captain: source.captain, seal: source.seal, master: source.master,
          imprint: source.imprint,
          actor: .init(
            system: NativeHollowManifestDefinition.freighterWorld, visit: 1,
            entity: UInt64(10 + index)),
          component: UUID(), sourceRevision: 1, issuedSequence: UInt64(57 + index), issuedTime: 30),
        logicalActor: UUID(),
        spawn: .init(
          system: NativeHollowManifestDefinition.freighterWorld, visit: 1, sequence: 1,
          member: UInt16(index), producer: .mission), geometry: geometry)
    }
    var flight = FlightSimulationState()
    flight.enter(NativeHollowManifestDefinition.freighterWorld, arriving: true)
    let layout = try NativeC03FreighterRoute.candidateLayout(anchors: flight.anchors)
    var basis = Basis3()
    basis.x = layout.u
    basis.y = layout.v
    basis.z = layout.normal
    return .init(
      birth: birth, phase: .admitted, nextSourceSequence: 1000,
      admissions: admissions, firstAdmissions: admissions.map(\.reference),
      latestAdmissions: admissions.map(\.reference), terminals: [], consents: [],
      firstCompromises: [], latestSealDamage: nil, damageRevision: 0, withdrawals: [],
      routeAnchors: flight.anchors,
      sourceFrame: .init(
        position: (layout.firstCentre + layout.secondCentre) * 0.5, orientation: basis),
      ownedEncounterID: "controlled-originals",
      routes: [
        .init(
          admission: admissions[0].reference, first: layout.first.first,
          second: layout.first.second, target: .second, revision: 1),
        .init(
          admission: admissions[1].reference, first: layout.second.first,
          second: layout.second.second, target: .first, revision: 1),
      ], inspections: [], laboratory: nil, wakeTrail: nil, custodyRegister: nil,
      crewSource: nil, crewLogAccess: nil, caseFile: nil)
  }
  private func object<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
  }
  private func changed<T: Codable>(_ value: T, _ field: String, _ replacement: Any) throws -> T {
    var raw = try #require(object(value) as? [String: Any])
    raw[field] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: raw))
  }
  private func effect(_ state: State, damage: Double = 220, after: Double = 0) -> State.RootEffect {
    let witness = state.admissions[0]
    let origin = AttackOrigin(
      emissionID: 1, owner: .init(system: witness.original.actor.system, visit: 1, entity: 0),
      emittedAt: 30, ownerLegalAtEmission: .init())
    let hit = CombatIncident(
      id: 10, physicalTime: 40, origin: origin, victim: witness.original.actor,
      kind: .bomb, outcome: .hit, position: .init(1, 2, 3), victimLegalBeforeAttack: nil,
      firstAggressor: nil, victimRole: .mission, victimIsStation: false,
      laser: nil, mount: nil, victimPart: nil)
    return .init(
      admission: witness.reference,
      incident: .init(
        path: .ordinaryCombat, id: hit.id, physicalTime: hit.physicalTime,
        victim: witness.original.actor, kind: hit.kind, outcome: hit.outcome,
        position: hit.position, origin: origin, attribution: .currentVisit,
        terminalShot: nil, victimPart: nil, component: nil, lawIncident: hit),
      requestedDamage: damage, hullAppliedDamage: damage, beforeHull: 220, afterHull: after,
      contactPhysicalTime: nil,
      damageAdmitted: true, hullDestroyed: after == 0, destructionIncident: nil)
  }

  @Test func coldLeafRoundTripKeepsTheOriginalStateWithoutInventingLaterProgress() throws {
    let state = try fixture()
    let decoded = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(state))
    #expect(decoded == state && decoded.shapeValid)
    #expect(decoded.birth == state.birth && decoded.nextSourceSequence == state.nextSourceSequence)
    #expect(decoded.crewSource == nil && decoded.crewLogAccess == nil && decoded.caseFile == nil)
    #expect(decoded.preservesHistory(of: state) && state.preservesHistory(of: decoded))
  }

  @Test func decodedCrewReferenceIsRetainedAsDataButCannotGrantMissingOriginalCrew() throws {
    let state = try fixture()
    // Unissued decoder input: no carrier, launch, living crew, ward or transfer is created.
    let unissued = NativeC03CrewSourceReference(
      source: UUID(), registration: UUID(), sequence: state.nextSourceSequence + 1)
    let injected = try changed(state, "crewSource", object(unissued))
    let cold = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(injected))
    #expect(cold.crewSource == unissued && cold == injected)
    #expect(!cold.shapeValid && !cold.preservesHistory(of: state))
    #expect(throws: State.Failure.invalidState) { try cold.retainingCrewSource(unissued) }
    #expect(state.crewSource == nil && state.caseFile == nil)
  }

  @Test func decodedCaseDataCannotBecomeReceivedEvidenceOrDisappearDuringColdRoundTrip() throws {
    let state = try fixture()
    // Deliberately false raw save data. Receipt equality/decoding conveys no acceptance.
    let facts = NativeC03LedgerReconstructionReceipt.Facts(
      mission: UUID(), owner: UUID(), contact: UUID(), dock: state.birth.input.dock,
      inspections: [], master: UUID(), register: UUID(), registerHash: "invalid",
      registerTransfer: UUID(), crewSourceRegistration: UUID(), crewLog: UUID(),
      crewLogHash: "invalid", crewLogTransfer: UUID(), originalCareTransfer: UUID(),
      originalKit: UUID(), issueCommand: UUID(), carrier: UUID(), inventoryRevision: 0,
      sequence: state.nextSourceSequence + 1, beforeCaseRevision: 0, afterCaseRevision: 1,
      physicalTime: 0, calendarSeconds: 0, epoch: UUID())
    let bytes = try JSONSerialization.data(withJSONObject: [
      "ledger": ["operation": UUID().uuidString, "facts": try object(facts)],
    ])
    let unissued = try JSONDecoder().decode(NativeC03CaseFile.self, from: bytes)
    let injected = try changed(state, "caseFile", object(unissued))
    let cold = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(injected))
    #expect(cold.caseFile == unissued && cold == injected)
    #expect(!unissued.valid(in: cold) && !cold.shapeValid)
    #expect(!cold.preservesHistory(of: state))
    #expect(throws: State.Failure.invalidState) { try cold.retainingCaseFile(unissued) }
    #expect(throws: State.Failure.invalidState) { try state.retainingReconstruction(unissued.ledger) }
    let opening = try State.unadmitted(state.birth)
    #expect(!(try changed(opening, "caseFile", object(unissued))).shapeValid)
    #expect(state.caseFile == nil && state.crewSource == nil)
  }

  @Test func unadmittedStateCannotContainActorsProgressOrImplicitReadmissionMotion() throws {
    let initial = try State.unadmitted(fixture().birth)
    #expect(initial.shapeValid && initial.admissions.isEmpty && initial.routes.isEmpty)
    #expect(throws: State.Failure.missingActualRetainedMotion) {
      try initial.requireReadmissionMotion()
    }
    let admitted = try fixture()
    #expect(admitted.shapeValid)
    #expect(throws: State.Failure.missingActualRetainedMotion) {
      try admitted.requireReadmissionMotion()
    }
    #expect(!(try changed(admitted, "phase", "unadmitted")).shapeValid)
  }

  @Test func lethalArithmeticUsesActualHullAppliedDamageAndRejectsFalse220OneZero() throws {
    let state = try fixture()
    let lethal = effect(state)
    #expect(
      lethal.shapeValid && lethal.incident.outcome == .hit && lethal.destructionIncident == nil)
    let impossible = effect(state, damage: 1, after: 0)
    #expect(!impossible.shapeValid)
    let small = effect(state, damage: 1, after: 219)
    let laserLaw = try changed(try #require(small.incident.lawIncident), "kind", "laser")
    var laser = try changed(small.incident, "kind", "laser")
    laser = try changed(laser, "lawIncident", object(laserLaw))
    let afterAbsorption = try changed(small, "incident", object(laser))
    let absorbed = try changed(afterAbsorption, "requestedDamage", 100)
    #expect(absorbed.shapeValid && !absorbed.hullDestroyed)
    #expect(!(try changed(small, "requestedDamage", 100)).shapeValid)
    #expect(!(try changed(absorbed, "afterHull", 130)).shapeValid)
    #expect(!(try changed(lethal, "damageAdmitted", false)).shapeValid)
    #expect(!(try changed(lethal, "hullAppliedDamage", 231)).shapeValid)
    let supersededHull = try changed(lethal, "beforeHull", 230)
    let supersededDamage = try changed(supersededHull, "hullAppliedDamage", 230)
    let internallyBalancedOldFit = try changed(supersededDamage, "requestedDamage", 230)
    #expect(!internallyBalancedOldFit.shapeValid)
    let component = try changed(lethal.incident, "component", UUID().uuidString)
    #expect(!(try changed(lethal, "incident", object(component))).shapeValid)
    let part = try changed(lethal.incident, "victimPart", "freighter-seal-a")
    #expect(!(try changed(lethal, "incident", object(part))).shapeValid)
    let componentOutcome = try changed(lethal.incident, "outcome", "componentDestruction")
    #expect(!(try changed(lethal, "incident", object(componentOutcome))).shapeValid)
  }

  @Test func causativeHitPhysicalLossAndOptionalRealDeathIncidentKeepDistinctIdentities() throws {
    let state = try fixture()
    let lethal = effect(state)
    let hit = try #require(lethal.incident.lawIncident)
    var death = try changed(hit, "id", 11)
    death = try changed(death, "outcome", "destruction")
    let witnessed = try changed(lethal, "destructionIncident", object(death))
    #expect(witnessed.shapeValid && witnessed.incident.id == 10)
    #expect(witnessed.incident.outcome == .hit && witnessed.destructionIncident?.id == 11)
    let sameID = try changed(death, "id", 10)
    #expect(!(try changed(lethal, "destructionIncident", object(sameID))).shapeValid)
    let relabelled = try changed(lethal.incident, "outcome", "destruction")
    #expect(!(try changed(lethal, "incident", object(relabelled))).shapeValid)
    let collisionHit = try changed(hit, "kind", "collision")
    var collision = try changed(lethal.incident, "kind", "collision")
    collision = try changed(collision, "lawIncident", object(collisionHit))
    #expect((try changed(lethal, "incident", object(collision))).shapeValid)
    let substep = try changed(lethal, "contactPhysicalTime", 39)
    #expect(substep.shapeValid && substep.incident.physicalTime == 40)
    #expect(!(try changed(lethal, "contactPhysicalTime", 41)).shapeValid)
    // Nil optional death receipt is an API constraint, not a demonstrated live exhaustion case.
  }

  @Test func realUnknownPlasmaOriginMayBeAbsentWithoutInventingAttributionOrComponentCause() throws
  {
    let state = try fixture()
    let old = effect(state)
    let native = State.RootIncident(
      path: .nativeMission, id: 10, physicalTime: 40, victim: old.incident.victim,
      kind: .plasma, outcome: .destruction, position: old.incident.position,
      origin: nil, attribution: .unknown, terminalShot: UUID(),
      victimPart: nil, component: nil, lawIncident: nil)
    let unknown = try changed(old, "incident", object(native))
    #expect(unknown.shapeValid && unknown.incident.origin == nil)
    #expect(!(try changed(unknown.incident, "kind", "bomb")).shapeValid)
    #expect(!(try changed(unknown.incident, "attribution", "currentVisit")).shapeValid)
    #expect(!(try changed(unknown.incident, "terminalShot", NSNull())).shapeValid)
  }

  @Test func witnessRolesAndSourcePhaseRejectUnreferencedDuplicatesAndOriginalSubstitution() throws
  {
    let state = try fixture()
    #expect(state.shapeValid)
    #expect(
      !(try changed(state, "admissions", object(state.admissions + [state.admissions[0]])))
        .shapeValid)
    let tooMany = Array(repeating: state.admissions[0], count: 19)
    #expect(!(try changed(state, "admissions", object(tooMany))).shapeValid)
    let wrong = try changed(state.admissions[0].original, "captain", UUID().uuidString)
    let wrongWitness = try changed(state.admissions[0], "original", object(wrong))
    #expect(
      !(try changed(state, "admissions", object([wrongWitness, state.admissions[1]]))).shapeValid)
    let wrongReferences = [State.Reference(slot: .first, revision: 2), state.latestAdmissions[1]]
    #expect(!(try changed(state, "latestAdmissions", object(wrongReferences))).shapeValid)
  }

  @Test func terminalIsImmutableOriginalLossAndCannotBeReplacedByLaterActorOrDuplicateCause() throws
  {
    let state = try fixture()
    let original = state.birth.originals[0]
    let terminal = State.Terminal(
      captain: original.captain, hull: original.hull, sourceSequence: 80, effect: effect(state))
    var lost = try changed(state, "phase", "originalLossRetained")
    lost = try changed(lost, "terminals", object([terminal]))
    #expect(lost.shapeValid && lost.terminals[0].effect.incident.outcome == .hit)
    #expect(lost.preservesHistory(of: state) && lost.preservesHistory(of: lost))
    #expect(!(try changed(lost, "phase", "admitted")).shapeValid)
    #expect(!(try changed(lost, "terminals", object([terminal, terminal]))).shapeValid)
    let substitute = try changed(terminal, "captain", UUID().uuidString)
    #expect(!(try changed(lost, "terminals", object([substitute]))).shapeValid)
    let falseEffect = effect(state, damage: 1, after: 0)
    let falseDeath = try changed(terminal, "effect", object(falseEffect))
    #expect(!(try changed(lost, "terminals", object([falseDeath]))).shapeValid)
    let nonlethal = try changed(terminal, "effect", object(effect(state, damage: 1, after: 219)))
    #expect(!(try changed(lost, "terminals", object([nonlethal]))).shapeValid)
    let differentEvent = try changed(terminal.effect.incident, "id", 12)
    let changedLaw = try changed(try #require(differentEvent.lawIncident), "id", 12)
    let otherCause = try changed(differentEvent, "lawIncident", object(changedLaw))
    let otherEffect = try changed(terminal.effect, "incident", object(otherCause))
    let otherTerminal = try changed(terminal, "effect", object(otherEffect))
    let rewritten = try changed(lost, "terminals", object([otherTerminal]))
    #expect(rewritten.shapeValid && !rewritten.preservesHistory(of: lost))
  }

  @Test func nativeWithdrawalKeepsPhysicalLawWitnessWithoutSpeechOrPersonalDeath() throws {
    let state = try fixture()
    let physical = effect(state, damage: 1, after: 219)
    let withdrawal = State.Withdrawal(
      owner: state.birth.input.owner, source: state.birth.originals[0].source,
      sourceSequence: 80, player: try #require(physical.incident.origin).owner, effect: physical)
    let withdrawn = try changed(state, "withdrawals", object([withdrawal]))
    #expect(withdrawn.shapeValid && withdrawn.terminals.isEmpty && withdrawn.consents.isEmpty)
    let foreign = try changed(withdrawal, "owner", UUID().uuidString)
    #expect(!(try changed(state, "withdrawals", object([foreign]))).shapeValid)
    let missingLaw = try changed(physical.incident, "lawIncident", NSNull())
    let noEvent = try changed(physical, "incident", object(missingLaw))
    let flagOnly = try changed(withdrawal, "effect", object(noEvent))
    #expect(!(try changed(state, "withdrawals", object([flagOnly]))).shapeValid)
  }

  @Test func historicalGrantAndFirstCompromiseKeepOldActorWhenLatestNativeBindingChanges() throws {
    let state = try fixture()
    let old = state.admissions[0]
    let actor = ActorIdentity(system: old.original.actor.system, visit: 2, entity: 20)
    var binding = try changed(old.original, "actor", object(actor))
    binding = try changed(binding, "sourceRevision", 2)
    binding = try changed(binding, "issuedSequence", 70)
    binding = try changed(binding, "issuedTime", 50)
    let newer = State.Admission(
      reference: .init(slot: .first, revision: 2), original: binding,
      logicalActor: old.logicalActor,
      spawn: .init(system: actor.system, visit: 2, sequence: 2, member: 0, producer: .mission),
      geometry: old.geometry)
    var rebound = try changed(state, "admissions", object(state.admissions + [newer]))
    rebound = try changed(
      rebound, "latestAdmissions", object([newer.reference, state.latestAdmissions[1]]))
    let route = try changed(state.routes[0], "admission", object(newer.reference))
    rebound = try changed(rebound, "routes", object([route, state.routes[1]]))
    let request = NativeHollowManifestSealConsentRequest(
      operation: UUID(), binding: old.original, purpose: .observeOriginalCargoSeal,
      player: .init(system: old.original.actor.system, visit: 1, entity: 0),
      playerHull: state.birth.input.carrier, targetingEquipment: UUID(), inventoryRevision: 1,
      sequence: 60, physicalTime: 31)
    let reply = NativeHollowManifestSealConsentReply(
      operation: UUID(), request: request.operation, originalSource: old.original.source,
      captain: old.original.captain, seal: old.original.seal, decision: .granted,
      revision: 1, previousReply: nil, sequence: 61, physicalTime: 32)
    let consent = State.Consent(
      request: request, requestAdmission: old.reference, reply: reply,
      replyAdmission: old.reference,
      revocation: nil, revocationAdmission: nil)
    rebound = try changed(rebound, "consents", object([consent]))
    func hit(
      _ witness: State.Admission, sequence: UInt64, incident: UInt64,
      time: Double, before: Double
    ) -> State.SealEffect {
      .init(
        admission: witness.reference, sourceSequence: sequence,
        facts: .init(
          original: witness.original, geometry: witness.geometry,
          component: witness.original.component,
          cause: .init(
            id: incident, physicalTime: time, mission: state.birth.input.mission,
            victim: witness.original.actor, victimPart: witness.original.slot.rawValue,
            component: witness.original.component, kind: .laser, outcome: .hit,
            position: .init(0, 0, 0), attribution: .currentVisit,
            origin: .init(
              emissionID: incident + 100,
              owner: .init(
                system: witness.original.actor.system, visit: witness.original.actor.visit,
                entity: 0),
              emittedAt: witness.original.issuedTime, ownerLegalAtEmission: .init()),
            terminalShot: nil),
          admittedDamage: 1, beforeEnergy: before, afterEnergy: before - 1))
    }
    let first = hit(old, sequence: 65, incident: 1, time: 40, before: 16)
    let latest = hit(newer, sequence: 71, incident: 2, time: 51, before: 15)
    rebound = try changed(rebound, "firstCompromises", object([first]))
    rebound = try changed(rebound, "latestSealDamage", object(latest))
    rebound = try changed(rebound, "damageRevision", 2)
    #expect(rebound.shapeValid)
    #expect(rebound.preservesHistory(of: state))
    #expect(rebound.consents[0].request.binding.actor == old.original.actor)
    #expect(rebound.firstCompromises[0].facts.cause.victim == old.original.actor)
    #expect(rebound.latestSealDamage?.facts.cause.victim == actor)
    #expect(!(try changed(rebound, "consents", object([consent, consent]))).shapeValid)
    let relabelledFacts = try changed(first.facts, "original", object(newer.original))
    let relabelled = try changed(first, "facts", object(relabelledFacts))
    #expect(!(try changed(rebound, "firstCompromises", object([relabelled]))).shapeValid)
    #expect(throws: State.Failure.missingActualRetainedMotion) {
      try rebound.requireReadmissionMotion()
    }
  }

  @Test func fixedRouteAndHistoricalStateRoundTripNeverSupplyCurrentMotionOrProgress() throws {
    let state = try fixture()
    let decoded = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(state))
    #expect(decoded == state && decoded.shapeValid)
    let moved = try changed(state.routes[0], "first", object(Vector3(0, 0, 0)))
    #expect(!(try changed(state, "routes", object([moved, state.routes[1]]))).shapeValid)
    #expect(throws: State.Failure.missingActualRetainedMotion) {
      try decoded.requireReadmissionMotion()
    }
    // No save namespace, native body, completion evidence or runtime publisher is exercised.
  }

  @Test func oneNativeEventCannotNameTwoVictimsOrCollideWithAnActualOptionalDeathID() throws {
    let state = try fixture()
    let first = effect(state)
    let other = state.admissions[1]
    let otherLaw = try changed(
      try #require(first.incident.lawIncident), "victim", object(other.original.actor))
    var otherIncident = try changed(first.incident, "victim", object(other.original.actor))
    otherIncident = try changed(otherIncident, "lawIncident", object(otherLaw))
    var second = try changed(first, "admission", object(other.reference))
    second = try changed(second, "incident", object(otherIncident))
    #expect(first.shapeValid && second.shapeValid)
    func lost(_ effects: [State.RootEffect]) throws -> State {
      let terminals = effects.enumerated().map { index, effect in
        State.Terminal(
          captain: state.birth.originals[index].captain, hull: state.birth.originals[index].hull,
          sourceSequence: UInt64(80 + index), effect: effect)
      }
      let value = try changed(state, "phase", "originalLossRetained")
      return try changed(value, "terminals", object(terminals))
    }
    #expect(!(try lost([first, second])).shapeValid)
    let separateLaw = try changed(otherLaw, "id", 12)
    var separate = try changed(otherIncident, "id", 12)
    separate = try changed(separate, "lawIncident", object(separateLaw))
    let distinctSecond = try changed(second, "incident", object(separate))
    #expect((try lost([first, distinctSecond])).shapeValid)
    var death = try changed(try #require(first.incident.lawIncident), "id", 11)
    death = try changed(death, "outcome", "destruction")
    let withDeath = try changed(first, "destructionIncident", object(death))
    let reusedLaw = try changed(otherLaw, "id", 11)
    var reused = try changed(otherIncident, "id", 11)
    reused = try changed(reused, "lawIncident", object(reusedLaw))
    let deathCollision = try changed(second, "incident", object(reused))
    #expect(withDeath.shapeValid && deathCollision.shapeValid)
    #expect(!(try lost([withDeath, deathCollision])).shapeValid)
    #expect((try lost([withDeath, distinctSecond])).shapeValid)
  }

  @Test func unchangedNativeEventCanSupportMultipleFactsButConflictingMetadataOrPartsCannot() throws
  {
    let state = try fixture()
    let physical = effect(state)
    let terminal = State.Terminal(
      captain: state.birth.originals[0].captain, hull: state.birth.originals[0].hull,
      sourceSequence: 80, effect: physical)
    let withdrawal = State.Withdrawal(
      owner: state.birth.input.owner, source: state.birth.originals[0].source,
      sourceSequence: 81, player: try #require(physical.incident.origin).owner, effect: physical)
    var shared = try changed(state, "phase", "originalLossRetained")
    shared = try changed(shared, "terminals", object([terminal]))
    shared = try changed(shared, "withdrawals", object([withdrawal]))
    #expect(shared.shapeValid)
    let changedPhysical = try changed(physical, "beforeHull", 219)
    #expect(changedPhysical.shapeValid)
    let differentEffect = try changed(withdrawal, "effect", object(changedPhysical))
    #expect(!(try changed(shared, "withdrawals", object([differentEffect]))).shapeValid)
    let witness = state.admissions[0]
    let seal = State.SealEffect(
      admission: witness.reference, sourceSequence: 79,
      facts: .init(
        original: witness.original, geometry: witness.geometry,
        component: witness.original.component,
        cause: .init(
          id: physical.incident.id, physicalTime: physical.incident.physicalTime,
          mission: state.birth.input.mission, victim: witness.original.actor,
          victimPart: witness.original.slot.rawValue, component: witness.original.component,
          kind: physical.incident.kind, outcome: .hit, position: physical.incident.position,
          attribution: .currentVisit, origin: physical.incident.origin, terminalShot: nil),
        admittedDamage: 1, beforeEnergy: 16, afterEnergy: 15))
    var sameSeal = try changed(state, "firstCompromises", object([seal]))
    sameSeal = try changed(sameSeal, "latestSealDamage", object(seal))
    sameSeal = try changed(sameSeal, "damageRevision", 1)
    #expect(sameSeal.shapeValid)
    let partsConflict = try changed(sameSeal, "phase", "originalLossRetained")
    #expect(!(try changed(partsConflict, "terminals", object([terminal]))).shapeValid)
  }

  @Test func rootReducerKeepsActualAbsorbedHullAmountAndFirstPlayerWithdrawalOnly() throws {
    let state = try fixture()
    let small = effect(state, damage: 1, after: 219)
    let law = try changed(try #require(small.incident.lawIncident), "kind", "laser")
    var incident = try changed(small.incident, "kind", "laser")
    incident = try changed(incident, "lawIncident", object(law))
    let laser = try changed(
      try changed(small, "incident", object(incident)), "requestedDamage", 100)
    let player = try #require(laser.incident.origin).owner
    let result = try state.retainingRootEffect(effect: laser, actualPlayer: player)
    #expect(result.shapeValid && result.preservesHistory(of: state))
    #expect(result.withdrawals.count == 1 && result.terminals.isEmpty)
    #expect(result.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(result.withdrawals[0].effect == laser)
    #expect(result.withdrawals[0].effect.requestedDamage == 100)
    #expect(result.withdrawals[0].effect.hullAppliedDamage == 1)
    #expect(result.withdrawals[0].effect.afterHull == 219)
    #expect(result.birth == state.birth && result.admissions == state.admissions)
    #expect(result.routes == state.routes && result.sourceFrame == state.sourceFrame)
    #expect(try result.retainingRootEffect(effect: laser, actualPlayer: player) == result)
    #expect(try result.retainingRootEffect(effect: laser, actualPlayer: nil) == result)
  }

  @Test(arguments: [false, true])
  func rootReducerFatalOrdinaryHitPreservesOptionalSeparateActualDeath(hasDeath: Bool) throws {
    let state = try fixture()
    var physical = effect(state)
    if hasDeath {
      let hit = try #require(physical.incident.lawIncident)
      let death = try changed(try changed(hit, "id", 11), "outcome", "destruction")
      physical = try changed(physical, "destructionIncident", object(death))
    }
    let player = try #require(physical.incident.origin).owner
    let result = try state.retainingRootEffect(effect: physical, actualPlayer: player)
    #expect(result.shapeValid && result.preservesHistory(of: state))
    #expect(result.phase == .originalLossRetained)
    #expect(result.terminals.count == 1 && result.withdrawals.count == 1)
    #expect(result.nextSourceSequence == state.nextSourceSequence + 2)
    #expect(result.withdrawals[0].sourceSequence == state.nextSourceSequence)
    #expect(result.terminals[0].sourceSequence == state.nextSourceSequence + 1)
    #expect(result.terminals[0].captain == state.birth.originals[0].captain)
    #expect(result.terminals[0].hull == state.birth.originals[0].hull)
    #expect(result.terminals[0].effect == physical)
    #expect(result.terminals[0].effect.incident.outcome == .hit)
    #expect(result.terminals[0].effect.incident.id == 10)
    #expect(result.terminals[0].effect.destructionIncident?.id == (hasDeath ? 11 : nil))
    #expect(try result.retainingRootEffect(effect: physical, actualPlayer: nil) == result)
    #expect(throws: State.Failure.missingActualRetainedMotion) {
      try result.requireReadmissionMotion()
    }
  }

  @Test func rootReducerUnknownRetainedPlasmaKeepsNilOriginAndActualOverkill() throws {
    let state = try fixture()
    let witness = state.admissions[0]
    let shot = UUID()
    let physical = State.RootEffect(
      admission: witness.reference,
      incident: .init(
        path: .nativeMission, id: 20, physicalTime: 50, victim: witness.original.actor,
        kind: .plasma, outcome: .destruction, position: .init(4, 5, 6), origin: nil,
        attribution: .unknown, terminalShot: shot, victimPart: nil, component: nil, lawIncident: nil
      ),
      requestedDamage: 500, hullAppliedDamage: 300, beforeHull: 220, afterHull: 0,
      contactPhysicalTime: nil, damageAdmitted: true, hullDestroyed: true, destructionIncident: nil)
    let result = try state.retainingRootEffect(effect: physical, actualPlayer: nil)
    #expect(result.terminals.count == 1 && result.withdrawals.isEmpty)
    #expect(result.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(result.terminals[0].effect == physical)
    #expect(result.terminals[0].effect.hullAppliedDamage == 300)
    #expect(result.terminals[0].effect.incident.origin == nil)
    #expect(result.terminals[0].effect.incident.terminalShot == shot)
    #expect(result.terminals[0].effect.incident.lawIncident == nil)
    // Native event20 and source sequence1000 are separate domains, not a shared allocator.
    #expect(result.terminals[0].sourceSequence == 1000)
  }

  @Test func rootReducerDoesNotInventHostilityWithoutActualPlayerAndLaw() throws {
    let state = try fixture()
    let physical = effect(state, damage: 1, after: 219)
    #expect(try state.retainingRootEffect(effect: physical, actualPlayer: nil) == state)
    let player = try #require(physical.incident.origin).owner
    let native = State.RootEffect(
      admission: physical.admission,
      incident: .init(
        path: .nativeMission, id: 20, physicalTime: 50,
        victim: physical.incident.victim, kind: .laser, outcome: .hit,
        position: physical.incident.position, origin: physical.incident.origin,
        attribution: .currentVisit, terminalShot: nil, victimPart: nil, component: nil,
        lawIncident: nil),
      requestedDamage: 10, hullAppliedDamage: 1, beforeHull: 220, afterHull: 219,
      contactPhysicalTime: nil, damageAdmitted: true, hullDestroyed: false, destructionIncident: nil
    )
    #expect(try state.retainingRootEffect(effect: native, actualPlayer: player) == state)
    let foreign = ActorIdentity(system: player.system, visit: player.visit, entity: 3)
    #expect(throws: (any Error).self) {
      _ = try state.retainingRootEffect(effect: physical, actualPlayer: foreign)
    }
  }

  @Test func rootReducerRefusesConflictingReusedNativeIDsAndOptionalDeathCollisions() throws {
    let state = try fixture()
    let first = effect(state, damage: 1, after: 219)
    let player = try #require(first.incident.origin).owner
    let retained = try state.retainingRootEffect(effect: first, actualPlayer: player)
    #expect(throws: (any Error).self) {
      _ = try retained.retainingRootEffect(
        effect: effect(state, damage: 2, after: 228), actualPlayer: player)
    }
    let lethal = effect(state)
    let death = try changed(
      try changed(try #require(lethal.incident.lawIncident), "id", 11), "outcome", "destruction")
    let withDeath = try changed(lethal, "destructionIncident", object(death))
    let lost = try state.retainingRootEffect(effect: withDeath, actualPlayer: player)
    let other = state.admissions[1]
    var law = try changed(try #require(first.incident.lawIncident), "id", 11)
    law = try changed(law, "victim", object(other.original.actor))
    var conflict = try changed(first.incident, "id", 11)
    conflict = try changed(conflict, "victim", object(other.original.actor))
    conflict = try changed(conflict, "lawIncident", object(law))
    var effectConflict = try changed(first, "incident", object(conflict))
    effectConflict = try changed(effectConflict, "admission", object(other.reference))
    #expect(effectConflict.shapeValid)
    // Other original, no terminal and no player fact: only the actual death-ID conflict refuses.
    #expect(throws: (any Error).self) {
      _ = try lost.retainingRootEffect(effect: effectConflict, actualPlayer: nil)
    }
  }

  @Test func rootReducerReservesOnlyNewBoundedFactsBeforeAnyCommitAndNeverResurrects() throws {
    let state = try fixture()
    let high = try changed(state, "nextSourceSequence", UInt64(Int64.max) - 2)
    try #require(high.shapeValid)
    let lethal = effect(high)
    let player = try #require(lethal.incident.origin).owner
    #expect(throws: (any Error).self) {
      _ = try high.retainingRootEffect(effect: lethal, actualPlayer: player)
    }
    let nonlethal = effect(high, damage: 1, after: 219)
    let oneFact = try high.retainingRootEffect(effect: nonlethal, actualPlayer: player)
    #expect(oneFact.nextSourceSequence == UInt64(Int64.max) - 1)
    #expect(try oneFact.retainingRootEffect(effect: nonlethal, actualPlayer: player) == oneFact)
    let lost = try state.retainingRootEffect(effect: effect(state), actualPlayer: nil)
    let laterLaw = try changed(try #require(nonlethal.incident.lawIncident), "id", 21)
    var laterIncident = try changed(nonlethal.incident, "id", 21)
    laterIncident = try changed(laterIncident, "lawIncident", object(laterLaw))
    let later = try changed(nonlethal, "incident", object(laterIncident))
    #expect(throws: (any Error).self) {
      _ = try lost.retainingRootEffect(effect: later, actualPlayer: player)
    }
  }

  @Test func rootReducerRejectsComponentFalseLethalZeroAppliedAndUnadmittedInputs() throws {
    let state = try fixture()
    let lethal = effect(state)
    let part = try changed(lethal.incident, "victimPart", "freighter-seal-a")
    let component = try changed(lethal, "incident", object(part))
    let zero = try changed(lethal, "hullAppliedDamage", 0)
    let falseLethal = effect(state, damage: 1, after: 0)
    for invalid in [component, zero, falseLethal] {
      #expect(throws: (any Error).self) {
        _ = try state.retainingRootEffect(effect: invalid, actualPlayer: nil)
      }
    }
    let unadmitted = try State.unadmitted(state.birth)
    #expect(throws: (any Error).self) {
      _ = try unadmitted.retainingRootEffect(effect: lethal, actualPlayer: nil)
    }
  }

  @Test func rootReducerPreservesConsentRevocationSealCompromiseAndRejectsCrossPartEventReuse()
    throws
  {
    let state = try fixture()
    let witness = state.admissions[0]
    let player = try #require(effect(state).incident.origin).owner
    let request = NativeHollowManifestSealConsentRequest(
      operation: UUID(), binding: witness.original, purpose: .observeOriginalCargoSeal,
      player: player, playerHull: state.birth.input.carrier, targetingEquipment: UUID(),
      inventoryRevision: 1, sequence: 60, physicalTime: 31)
    let reply = NativeHollowManifestSealConsentReply(
      operation: UUID(), request: request.operation,
      originalSource: witness.original.source, captain: witness.original.captain,
      seal: witness.original.seal, decision: .granted, revision: 1, previousReply: nil,
      sequence: 61, physicalTime: 32)
    let revoked = NativeHollowManifestSealConsentReply(
      operation: UUID(), request: request.operation,
      originalSource: witness.original.source, captain: witness.original.captain,
      seal: witness.original.seal, decision: .revoked, revision: 2, previousReply: reply.operation,
      sequence: 62, physicalTime: 33)
    let consent = State.Consent(
      request: request, requestAdmission: witness.reference,
      reply: reply, replyAdmission: witness.reference, revocation: revoked,
      revocationAdmission: witness.reference)
    let seal = State.SealEffect(
      admission: witness.reference, sourceSequence: 65,
      facts: .init(
        original: witness.original, geometry: witness.geometry,
        component: witness.original.component,
        cause: .init(
          id: 2, physicalTime: 34, mission: state.birth.input.mission,
          victim: witness.original.actor, victimPart: witness.original.slot.rawValue,
          component: witness.original.component, kind: .laser, outcome: .hit,
          position: .init(0, 0, 0), attribution: .currentVisit,
          origin: .init(emissionID: 2, owner: player, emittedAt: 30, ownerLegalAtEmission: .init()),
          terminalShot: nil), admittedDamage: 1, beforeEnergy: 16, afterEnergy: 15))
    var historical = try changed(state, "consents", object([consent]))
    historical = try changed(historical, "firstCompromises", object([seal]))
    historical = try changed(historical, "latestSealDamage", object(seal))
    historical = try changed(historical, "damageRevision", 1)
    try #require(historical.shapeValid)
    let result = try historical.retainingRootEffect(
      effect: effect(historical), actualPlayer: player)
    #expect(result.preservesHistory(of: historical))
    #expect(result.consents == historical.consents && result.consents[0].revocation == revoked)
    #expect(result.firstCompromises == historical.firstCompromises)
    #expect(result.latestSealDamage == historical.latestSealDamage && result.damageRevision == 1)
    #expect(result.admissions == historical.admissions && result.routes == historical.routes)
    #expect(result.birth == historical.birth && result.sourceFrame == historical.sourceFrame)
    let small = effect(historical, damage: 1, after: 219)
    let law = try changed(try #require(small.incident.lawIncident), "id", 2)
    var incident = try changed(small.incident, "id", 2)
    incident = try changed(incident, "lawIncident", object(law))
    let reuse = try changed(small, "incident", object(incident))
    #expect(reuse.shapeValid)
    // Even with no new player/terminal fact to retain, a component event cannot become a root hit.
    #expect(throws: (any Error).self) {
      _ = try historical.retainingRootEffect(effect: reuse, actualPlayer: nil)
    }
  }

  private func consentRequest(_ state: State, slot: Int = 0, time: Double = 31)
    -> NativeHollowManifestSealConsentRequest
  {
    let original = state.admissions[slot].original
    return .init(
      operation: UUID(), binding: original, purpose: .observeOriginalCargoSeal,
      player: .init(system: original.actor.system, visit: original.actor.visit, entity: 0),
      playerHull: state.birth.input.carrier, targetingEquipment: UUID(), inventoryRevision: 1,
      sequence: state.nextSourceSequence, physicalTime: time)
  }

  private func consentReply(
    _ state: State,
    decision: NativeHollowManifestSealConsentReply.Decision = .granted, time: Double = 32
  )
    throws -> NativeHollowManifestSealConsentReply
  {
    let consent = try #require(state.consents.first)
    return .init(
      operation: UUID(), request: consent.request.operation,
      originalSource: consent.request.binding.source, captain: consent.request.binding.captain,
      seal: consent.request.binding.seal, decision: decision,
      revision: decision == .revoked ? 2 : 1,
      previousReply: decision == .revoked ? consent.reply?.operation : nil,
      sequence: state.nextSourceSequence, physicalTime: time)
  }

  @Test func consentRequestConsumesOneSourceFactAndExactReplayDoesNotReplaceItsFit() throws {
    let state = try fixture()
    let request = consentRequest(state)
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(request: request, admission: reference)
    #expect(requested.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(requested.consents.count == 1 && requested.consents[0].reply == nil)
    #expect(requested.preservesHistory(of: state))
    #expect(requested.routes == state.routes && requested.admissions == state.admissions)
    #expect(
      try requested.retainingConsentRequest(request: request, admission: reference) == requested)
    let refitted = try changed(request, "targetingEquipment", UUID().uuidString)
    #expect(throws: State.Failure.invalidState) {
      _ = try requested.retainingConsentRequest(request: refitted, admission: reference)
    }
  }

  @Test(arguments: ["sequence", "player", "binding", "time", "capacity", "unadmitted"])
  func consentRequestRefusesStaleOrUnboundedCandidates(change: String) throws {
    var state = try fixture()
    var request = consentRequest(state)
    let reference = state.admissions[0].reference
    switch change {
    case "sequence": request = try changed(request, "sequence", state.nextSourceSequence + 1)
    case "player":
      request = try changed(request, "player", object(state.admissions[0].original.actor))
    case "binding": request = try changed(request, "binding", object(state.admissions[1].original))
    case "time": request = try changed(request, "physicalTime", 29)
    case "capacity":
      state = try changed(state, "nextSourceSequence", UInt64(Int64.max) - 1)
      request = try changed(request, "sequence", state.nextSourceSequence)
    case "unadmitted": state = try State.unadmitted(state.birth)
    default:
      Issue.record("Unknown consent candidate")
      return
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try state.retainingConsentRequest(request: request, admission: reference)
    }
  }

  @Test func consentReplyRequiresStrictlyLaterTimeAndCannotBeReplaced() throws {
    let state = try fixture()
    let request = consentRequest(state)
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(request: request, admission: reference)
    let simultaneous = try consentReply(requested, time: request.physicalTime)
    #expect(throws: State.Failure.invalidState) {
      _ = try requested.retainingConsentReply(reply: simultaneous, admission: reference)
    }
    let reply = try consentReply(requested)
    let granted = try requested.retainingConsentReply(reply: reply, admission: reference)
    #expect(granted.nextSourceSequence == requested.nextSourceSequence + 1)
    #expect(granted.preservesHistory(of: requested) && granted.consents[0].reply == reply)
    #expect(try granted.retainingConsentReply(reply: reply, admission: reference) == granted)
    let replacement = try changed(reply, "decision", "declined")
    #expect(throws: State.Failure.invalidState) {
      _ = try granted.retainingConsentReply(reply: replacement, admission: reference)
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try granted.retainingConsentRequest(
        request: consentRequest(granted), admission: reference)
    }
  }

  @Test func consentDeclineIsAnIrreversibleRecordedDecisionWithoutARegrantOrRevocation() throws {
    let state = try fixture()
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: reference)
    let reply = try consentReply(requested, decision: .declined)
    let declined = try requested.retainingConsentReply(reply: reply, admission: reference)
    #expect(declined.consents[0].reply?.decision == .declined)
    #expect(throws: State.Failure.invalidState) {
      _ = try declined.retainingConsentRevocation(
        revocation: consentReply(declined, decision: .revoked, time: 33), admission: reference)
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try declined.retainingConsentReply(reply: consentReply(declined), admission: reference)
    }
  }

  @Test func consentRevocationRequiresRetainedCauseAndKeepsGrantAndNativeWithdrawal() throws {
    let state = try fixture()
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: reference)
    let reply = try consentReply(requested)
    let granted = try requested.retainingConsentReply(reply: reply, admission: reference)
    #expect(throws: State.Failure.invalidState) {
      _ = try granted.retainingConsentRevocation(
        revocation: consentReply(granted, decision: .revoked, time: 41), admission: reference)
    }
    let hit = effect(granted, damage: 1, after: 219)
    let withdrawn = try granted.retainingRootEffect(
      effect: hit, actualPlayer: try #require(hit.incident.origin).owner)
    let revocation = try consentReply(withdrawn, decision: .revoked, time: 41)
    let revoked = try withdrawn.retainingConsentRevocation(
      revocation: revocation, admission: reference)
    #expect(revoked.consents[0].request == requested.consents[0].request)
    #expect(revoked.consents[0].reply == reply && revoked.consents[0].revocation == revocation)
    #expect(revoked.withdrawals == withdrawn.withdrawals && revoked.terminals.isEmpty)
    #expect(revoked.preservesHistory(of: withdrawn))
    #expect(
      try revoked.retainingConsentRevocation(revocation: revocation, admission: reference)
        == revoked)
    let backdated = try changed(revocation, "physicalTime", 39)
    #expect(throws: State.Failure.invalidState) {
      _ = try withdrawn.retainingConsentRevocation(revocation: backdated, admission: reference)
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try withdrawn.retainingConsentRequest(
        request: consentRequest(withdrawn), admission: reference)
    }
  }

  @Test func consentGrantCannotFollowWithdrawalOrTerminalButPendingHistorySurvives() throws {
    let state = try fixture()
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: reference)
    for lethal in [false, true] {
      let hit = effect(requested, damage: lethal ? 220 : 1, after: lethal ? 0 : 219)
      let blocked = try requested.retainingRootEffect(
        effect: hit, actualPlayer: try #require(hit.incident.origin).owner)
      #expect(blocked.consents == requested.consents)
      #expect(throws: State.Failure.invalidState) {
        _ = try blocked.retainingConsentReply(
          reply: consentReply(blocked, time: 41), admission: reference)
      }
      #expect(
        try blocked.retainingConsentRequest(
          request: requested.consents[0].request, admission: reference) == blocked)
    }
  }

  @Test func consentOperationsCannotCollideAcrossOriginalsOrConsumeScriptOrNativeCounters() throws {
    let state = try fixture()
    let request = consentRequest(state)
    let requested = try state.retainingConsentRequest(
      request: request, admission: state.admissions[0].reference)
    let second = consentRequest(requested, slot: 1, time: 32)
    let collision = try changed(second, "operation", request.operation.uuidString)
    #expect(throws: State.Failure.invalidState) {
      _ = try requested.retainingConsentRequest(
        request: collision, admission: state.admissions[1].reference)
    }
    let both = try requested.retainingConsentRequest(
      request: second, admission: state.admissions[1].reference)
    #expect(both.consents.count == 2 && both.nextSourceSequence == state.nextSourceSequence + 2)
    #expect(both.birth == state.birth && both.damageRevision == state.damageRevision)
    let wrongSequence = try changed(try consentReply(both, time: 33), "sequence", 10)
    #expect(throws: State.Failure.invalidState) {
      _ = try both.retainingConsentReply(
        reply: wrongSequence, admission: state.admissions[0].reference)
    }
  }

  @Test func consentReplyUsesCurrentAdmissionButRetainsOriginalRequestAcrossVisits() throws {
    let state = try fixture()
    let old = state.admissions[0]
    let request = consentRequest(state)
    let requested = try state.retainingConsentRequest(request: request, admission: old.reference)
    let actor = ActorIdentity(system: old.original.actor.system, visit: 2, entity: 20)
    var binding = try changed(old.original, "actor", object(actor))
    binding = try changed(binding, "sourceRevision", 2)
    binding = try changed(binding, "issuedSequence", requested.nextSourceSequence)
    binding = try changed(binding, "issuedTime", 50)
    let newer = State.Admission(
      reference: .init(slot: old.reference.slot, revision: 2),
      original: binding, logicalActor: old.logicalActor,
      spawn: .init(system: actor.system, visit: 2, sequence: 2, member: 0, producer: .mission),
      geometry: old.geometry)
    var rebound = try changed(requested, "admissions", object(requested.admissions + [newer]))
    rebound = try changed(
      rebound, "latestAdmissions", object([newer.reference, state.latestAdmissions[1]]))
    rebound = try changed(rebound, "nextSourceSequence", requested.nextSourceSequence + 1)
    rebound = try changed(
      rebound, "routes",
      object([
        changed(state.routes[0], "admission", object(newer.reference)), state.routes[1],
      ]))
    try #require(rebound.shapeValid && rebound.preservesHistory(of: requested))
    #expect(
      try rebound.retainingConsentRequest(request: request, admission: old.reference) == rebound)
    #expect(throws: State.Failure.invalidState) {
      _ = try rebound.retainingConsentRequest(request: request, admission: newer.reference)
    }
    let reply = try consentReply(rebound, time: 51)
    #expect(throws: State.Failure.invalidState) {
      _ = try rebound.retainingConsentReply(reply: reply, admission: old.reference)
    }
    let granted = try rebound.retainingConsentReply(reply: reply, admission: newer.reference)
    #expect(granted.consents[0].request == request)
    #expect(granted.consents[0].requestAdmission == old.reference)
    #expect(granted.consents[0].replyAdmission == newer.reference)
    #expect(granted.consents[0].request.binding.actor.visit == 1)
    #expect(granted.preservesHistory(of: requested))
  }

  @Test func consentCompromiseCauseAllowsRevocationWithoutInventingWithdrawal() throws {
    let state = try fixture()
    let witness = state.admissions[0]
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: witness.reference)
    let granted = try requested.retainingConsentReply(
      reply: consentReply(requested), admission: witness.reference)
    let seal = State.SealEffect(
      admission: witness.reference,
      sourceSequence: granted.nextSourceSequence,
      facts: .init(
        original: witness.original, geometry: witness.geometry,
        component: witness.original.component,
        cause: .init(
          id: 2, physicalTime: 40, mission: witness.original.mission,
          victim: witness.original.actor,
          victimPart: witness.original.slot.rawValue, component: witness.original.component,
          kind: .laser, outcome: .hit, position: .init(0, 0, 0), attribution: .currentVisit,
          origin: .init(
            emissionID: 2, owner: requested.consents[0].request.player,
            emittedAt: 30, ownerLegalAtEmission: .init()), terminalShot: nil),
        admittedDamage: 1, beforeEnergy: 16, afterEnergy: 15))
    var compromised = try changed(granted, "firstCompromises", object([seal]))
    compromised = try changed(compromised, "latestSealDamage", object(seal))
    compromised = try changed(compromised, "damageRevision", 1)
    compromised = try changed(compromised, "nextSourceSequence", granted.nextSourceSequence + 1)
    try #require(compromised.shapeValid)
    let revoked = try compromised.retainingConsentRevocation(
      revocation: consentReply(compromised, decision: .revoked, time: 41),
      admission: witness.reference)
    #expect(revoked.withdrawals.isEmpty && revoked.firstCompromises == [seal])
    #expect(revoked.latestSealDamage == seal && revoked.damageRevision == 1)
    #expect(revoked.consents[0].reply == granted.consents[0].reply)
    #expect(revoked.preservesHistory(of: compromised))
  }

  @Test(arguments: ["sequence", "captain", "request", "admission", "operation", "backdated"])
  func consentReplyRejectsWrongJoinsAndConflictingOperationIDs(change: String) throws {
    let state = try fixture()
    let reference = state.admissions[0].reference
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: reference)
    var reply = try consentReply(requested)
    var suppliedReference = reference
    switch change {
    case "sequence": reply = try changed(reply, "sequence", requested.nextSourceSequence + 1)
    case "captain": reply = try changed(reply, "captain", UUID().uuidString)
    case "request": reply = try changed(reply, "request", UUID().uuidString)
    case "admission": suppliedReference = state.admissions[1].reference
    case "operation":
      reply = try changed(reply, "operation", requested.consents[0].request.operation.uuidString)
    case "backdated": reply = try changed(reply, "physicalTime", 30)
    default:
      Issue.record("Unknown reply candidate")
      return
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try requested.retainingConsentReply(reply: reply, admission: suppliedReference)
    }
  }

  private func sealFacts(
    _ state: State, slot: Int = 0, incident: UInt64 = 20,
    time: Double = 40, before: Double = 16, damage: Double = 1
  )
    throws -> NativeHollowManifestSealDamageFacts
  {
    let selected = state.birth.originals[slot].slot
    let reference = try #require(state.latestAdmissions.first { $0.slot == selected })
    let witness = try #require(state.admissions.first { $0.reference == reference })
    let actor = witness.original.actor
    return .init(
      original: witness.original, geometry: witness.geometry,
      component: witness.original.component,
      cause: .init(
        id: incident, physicalTime: time, mission: witness.original.mission,
        victim: actor, victimPart: selected.rawValue, component: witness.original.component,
        kind: .laser, outcome: before - damage <= 0 ? .componentDestruction : .hit,
        position: .init(1, 2, 3), attribution: .currentVisit,
        origin: .init(
          emissionID: incident,
          owner: .init(system: actor.system, visit: actor.visit, entity: 0),
          emittedAt: 30, ownerLegalAtEmission: .init()), terminalShot: nil),
      admittedDamage: damage, beforeEnergy: before, afterEnergy: max(0, before - damage))
  }

  private func reboundSealState(_ state: State, time: Double) throws -> State {
    let reference = try #require(state.latestAdmissions.first { $0.slot == .first })
    let old = try #require(state.admissions.first { $0.reference == reference })
    let actor = ActorIdentity(
      system: old.original.actor.system,
      visit: old.original.actor.visit + 1, entity: old.original.actor.entity + 20)
    var binding = try changed(old.original, "actor", object(actor))
    binding = try changed(binding, "sourceRevision", old.reference.revision + 1)
    binding = try changed(binding, "issuedSequence", state.nextSourceSequence)
    binding = try changed(binding, "issuedTime", time)
    let newer = State.Admission(
      reference: .init(slot: .first, revision: old.reference.revision + 1),
      original: binding, logicalActor: old.logicalActor,
      spawn: .init(
        system: actor.system, visit: actor.visit, sequence: old.spawn.sequence + 1,
        member: 0, producer: .mission), geometry: old.geometry)
    var rebound = try changed(state, "admissions", object(state.admissions + [newer]))
    rebound = try changed(
      rebound, "latestAdmissions", object([newer.reference, state.latestAdmissions[1]]))
    rebound = try changed(rebound, "nextSourceSequence", state.nextSourceSequence + 1)
    let route = try changed(state.routes[0], "admission", object(newer.reference))
    rebound = try changed(rebound, "routes", object([route, state.routes[1]]))
    try #require(rebound.shapeValid && rebound.preservesHistory(of: state))
    return rebound
  }

  @Test func sealDamageRetainsExactFirstCauseAndLatestWithoutIssuingRootLossOrWithdrawal() throws {
    let state = try fixture()
    let facts = try sealFacts(state)
    let reference = state.latestAdmissions[0]
    let result = try state.retainingSealDamage(facts: facts, admission: reference)
    let first = try #require(result.firstCompromises.first)
    #expect(first.facts == facts && first.admission == reference)
    #expect(first.sourceSequence == state.nextSourceSequence && facts.cause.id == 20)
    #expect(result.latestSealDamage == first && result.damageRevision == 1)
    #expect(result.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(result.terminals.isEmpty && result.withdrawals.isEmpty && result.consents.isEmpty)
    #expect(result.preservesHistory(of: state) && result.routes == state.routes)
    #expect(try result.retainingSealDamage(facts: facts, admission: reference) == result)
    let altered = try changed(facts, "admittedDamage", 2)
    #expect(throws: State.Failure.invalidState) {
      _ = try result.retainingSealDamage(facts: altered, admission: reference)
    }
  }

  @Test func sealDamageKeepsTwoFirstsAndRejectsKnownEnergyHealingOrDuplicateNativeCause() throws {
    let state = try fixture()
    let first = try state.retainingSealDamage(
      facts: sealFacts(state), admission: state.latestAdmissions[0])
    let second = try first.retainingSealDamage(
      facts: sealFacts(first, slot: 1, incident: 21, time: 41), admission: first.latestAdmissions[1]
    )
    #expect(second.firstCompromises.count == 2 && second.damageRevision == 2)
    let thirdFacts = try sealFacts(second, incident: 22, time: 42, before: 15)
    let third = try second.retainingSealDamage(
      facts: thirdFacts, admission: second.latestAdmissions[0])
    #expect(third.firstCompromises == second.firstCompromises)
    #expect(third.latestSealDamage?.facts == thirdFacts && third.damageRevision == 3)
    #expect(third.preservesHistory(of: first))
    #expect(throws: State.Failure.invalidState) {
      _ = try third.retainingSealDamage(
        facts: sealFacts(third, incident: 23, time: 43, before: 15),
        admission: third.latestAdmissions[0])
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try third.retainingSealDamage(
        facts: sealFacts(third, slot: 1, incident: 22, time: 42, before: 15),
        admission: third.latestAdmissions[1])
    }
  }

  @Test(arguments: [
    "component", "original", "geometry", "spent-first", "arithmetic", "time", "zero", "unadmitted",
  ])
  func sealDamageRejectsMalformedCandidatesWithoutCreatingCompromise(change: String) throws {
    var state = try fixture()
    var facts = try sealFacts(state)
    let reference = state.latestAdmissions[0]
    switch change {
    case "component": facts = try changed(facts, "component", UUID().uuidString)
    case "original": facts = try changed(facts, "original", object(state.admissions[1].original))
    case "geometry":
      let geometry = try changed(
        facts.geometry, "sealGeometryHash", String(repeating: "0", count: 64))
      facts = try changed(facts, "geometry", object(geometry))
    case "spent-first": facts = try sealFacts(state, before: 15)
    case "arithmetic": facts = try changed(facts, "afterEnergy", 0)
    case "time": facts = try sealFacts(state, time: 29)
    case "zero": facts = try sealFacts(state, damage: 0)
    case "unadmitted": state = try State.unadmitted(state.birth)
    default:
      Issue.record("Unknown seal candidate")
      return
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try state.retainingSealDamage(facts: facts, admission: reference)
    }
    #expect(state.firstCompromises.isEmpty && state.latestSealDamage == nil)
  }

  @Test(arguments: ["source", "revision"])
  func sealDamageRefusesExhaustedCounterButExactRetainedReplayNeedsNoCapacity(counter: String)
    throws
  {
    let state = try fixture()
    let facts = try sealFacts(state)
    let damaged = try state.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0])
    let field = counter == "source" ? "nextSourceSequence" : "damageRevision"
    let exhausted = try changed(damaged, field, UInt64(Int64.max) - 1)
    try #require(exhausted.shapeValid)
    #expect(
      try exhausted.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0])
        == exhausted)
    #expect(throws: State.Failure.invalidState) {
      _ = try exhausted.retainingSealDamage(
        facts: sealFacts(exhausted, incident: 21, time: 41, before: 15),
        admission: exhausted.latestAdmissions[0])
    }
  }

  @Test func sealDamageCannotReuseActualRootHitOrOptionalDeathIdentity() throws {
    let state = try fixture()
    let hit = effect(state, damage: 1, after: 219)
    let withdrawn = try state.retainingRootEffect(
      effect: hit, actualPlayer: try #require(hit.incident.origin).owner)
    #expect(throws: State.Failure.invalidState) {
      _ = try withdrawn.retainingSealDamage(
        facts: sealFacts(withdrawn, incident: hit.incident.id, time: 41),
        admission: withdrawn.latestAdmissions[0])
    }
    let lethal = effect(state)
    var death = try changed(try #require(lethal.incident.lawIncident), "id", 11)
    death = try changed(death, "outcome", "destruction")
    let witnessed = try changed(lethal, "destructionIncident", object(death))
    let lost = try state.retainingRootEffect(effect: witnessed, actualPlayer: nil)
    #expect(throws: State.Failure.invalidState) {
      _ = try lost.retainingSealDamage(
        facts: sealFacts(lost, slot: 1, incident: 11, time: 41), admission: lost.latestAdmissions[1]
      )
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try lost.retainingSealDamage(
        facts: sealFacts(lost, time: 41), admission: lost.latestAdmissions[0])
    }
  }

  @Test func sealDamageUnknownRetainedPlasmaPreservesNilOriginAndComponentDestruction() throws {
    let state = try fixture()
    var facts = try sealFacts(state, damage: 20)
    var cause = try changed(facts.cause, "kind", "plasma")
    cause = try changed(cause, "attribution", "unknown")
    cause = try changed(cause, "origin", NSNull())
    cause = try changed(cause, "terminalShot", UUID().uuidString)
    facts = try changed(facts, "cause", object(cause))
    let result = try state.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0])
    #expect(result.latestSealDamage?.facts == facts)
    #expect(facts.afterEnergy == 0 && facts.admittedDamage == 20)
    #expect(result.latestSealDamage?.facts.cause.origin == nil)
    #expect(result.latestSealDamage?.facts.cause.outcome == .componentDestruction)
    #expect(result.terminals.isEmpty)
    #expect(throws: State.Failure.invalidState) {
      _ = try result.retainingSealDamage(
        facts: sealFacts(result, incident: 21, time: 41, before: 1),
        admission: result.latestAdmissions[0])
    }
  }

  @Test func sealDamagePrunesOnlyReleasedLatestWitnessAndNeverRelabelsFirstReplay() throws {
    let state = try fixture()
    let facts = try sealFacts(state)
    let first = try state.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0])
    let secondVisit = try reboundSealState(first, time: 50)
    let secondFacts = try sealFacts(secondVisit, incident: 21, time: 51, before: 15)
    let second = try secondVisit.retainingSealDamage(
      facts: secondFacts, admission: secondVisit.latestAdmissions[0])
    let released = second.latestAdmissions[0]
    let thirdVisit = try reboundSealState(second, time: 60)
    #expect(thirdVisit.admissions.contains { $0.reference == released })
    let third = try thirdVisit.retainingSealDamage(
      facts: sealFacts(thirdVisit, incident: 22, time: 61, before: 14),
      admission: thirdVisit.latestAdmissions[0])
    #expect(!third.admissions.contains { $0.reference == released })
    #expect(third.admissions.count == 3 && third.firstCompromises == first.firstCompromises)
    #expect(third.preservesHistory(of: second))
    #expect(
      try third.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0]) == third)
    #expect(throws: State.Failure.invalidState) {
      _ = try third.retainingSealDamage(facts: facts, admission: third.latestAdmissions[0])
    }
    #expect(throws: State.Failure.invalidState) {
      _ = try third.retainingSealDamage(facts: secondFacts, admission: released)
    }
  }

  @Test func sealDamageInvalidatesNewGrantAndSuppliesRetainedCauseForLaterRevocation() throws {
    let state = try fixture()
    let reference = state.latestAdmissions[0]
    let requested = try state.retainingConsentRequest(
      request: consentRequest(state), admission: reference)
    let granted = try requested.retainingConsentReply(
      reply: consentReply(requested), admission: reference)
    let compromised = try granted.retainingSealDamage(
      facts: sealFacts(granted), admission: reference)
    #expect(compromised.consents == granted.consents && compromised.withdrawals.isEmpty)
    let revoked = try compromised.retainingConsentRevocation(
      revocation: consentReply(compromised, decision: .revoked, time: 41), admission: reference)
    #expect(revoked.firstCompromises == compromised.firstCompromises)
    #expect(revoked.consents[0].reply == granted.consents[0].reply)
    #expect(revoked.consents[0].revocation?.decision == .revoked)
    let pendingDamaged = try requested.retainingSealDamage(
      facts: sealFacts(requested), admission: reference)
    #expect(throws: State.Failure.invalidState) {
      _ = try pendingDamaged.retainingConsentReply(
        reply: consentReply(pendingDamaged, time: 41), admission: reference)
    }
  }

  @Test(arguments: ["incident", "clock", "discontinuous-energy"])
  func sealDamageRejectsStaleWatermarksAndKnownEnergyDiscontinuity(change: String) throws {
    let state = try fixture()
    let damaged = try state.retainingSealDamage(
      facts: sealFacts(state), admission: state.latestAdmissions[0])
    let facts = try sealFacts(
      damaged, incident: change == "incident" ? 19 : 21,
      time: change == "clock" ? 39 : 41, before: change == "discontinuous-energy" ? 14 : 15)
    #expect(throws: State.Failure.invalidState) {
      _ = try damaged.retainingSealDamage(facts: facts, admission: damaged.latestAdmissions[0])
    }
  }

}

extension NativeHollowManifestStateUnitTests {
  /// Unauthenticated historical fixtures only. These never mint a live sample or scan permission.
  private func inspectionFixture() throws -> (State, NativeHollowManifestSealInspection) {
    let initial = try fixture()
    let reference = initial.admissions[0].reference
    let requested = try initial.retainingConsentRequest(
      request: consentRequest(initial), admission: reference)
    let state = try requested.retainingConsentReply(
      reply: consentReply(requested), admission: reference)
    let original = state.admissions[0].original
    let consent = try #require(state.consents.first)
    let reply = try #require(consent.reply)
    let node = try #require(EquipmentRuntimeCatalog.node(for: TargetingTier.basic.equipmentName))
    let carrier = state.birth.input.carrier
    let instrument = OwnedEquipmentItem(
      id: UUID(), node: node,
      provenance: .paid(owner: state.birth.input.owner, transaction: UUID()),
      location: .init(hullInstanceID: carrier, slot: .targetingCore))
    let slot = try #require(NativeC03SealGeometry.Slot(rawValue: original.slot.rawValue))
    func reading(_ time: Double) -> NativeC03SealProbe.Reading {
      .init(
        actor: original.actor, component: original.component, slot: slot,
        physicalTime: time, rootPose: .init(),
        reliefHeights: NativeC03SealGeometry.reliefs.map { $0.size.z },
        surfaceRanges: Array(repeating: 300, count: 12), maximumProbeAngle: 0.000002)
    }
    let facts = NativeHollowManifestSealInspection.Facts(
      evidence: .nativeSnapshotPair, admission: reference, original: original,
      request: consent.request.operation, reply: reply.operation,
      player: consent.request.player, carrier: carrier, inventoryRevision: 1,
      instrument: instrument, epoch: UUID(), sequence: state.nextSourceSequence,
      firstFrame: 17, lastFrame: 18, first: reading(40), last: reading(40.05))
    let receipt = NativeHollowManifestSealInspection(
      operation: try NativeHollowManifestSealInspection.identity(facts), facts: facts)
    return (state, receipt)
  }

  @Test func currentInspectionHistoryKeepsOriginalConsentInstrumentAndImmutableEvidence() throws {
    let (state, receipt) = try inspectionFixture()
    let recorded = try state.retainingInspection(receipt)
    #expect(recorded.shapeValid && recorded.inspections == [receipt])
    #expect(recorded.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(recorded.preservesHistory(of: state))
    #expect(receipt.valid(in: recorded))
    let encoded = try NativeHollowManifestSave.encode(recorded)
    let restored = try NativeHollowManifestSave.decode(
      encoded, owner: recorded.birth.input.owner, mission: recorded.birth.input.mission,
      existing: state)
    #expect(restored == recorded && restored.inspections == [receipt])
    #expect(throws: State.Failure.invalidState) { _ = try recorded.retainingInspection(receipt) }
    #expect(throws: (any Error).self) {
      _ = try NativeHollowManifestSave.decode(
        NativeHollowManifestSave.encode(state), owner: state.birth.input.owner,
        mission: state.birth.input.mission, existing: recorded)
    }
  }

  @Test(arguments: ["reply", "original", "component", "one-snapshot", "frame", "range", "height", "instrument", "source-counter"])
  func malformedInspectionHistoryRejectsChangedSourceConsentAndMeasurementFacts(_ mutation: String) throws {
    let (state, receipt) = try inspectionFixture()
    var facts = receipt.facts
    switch mutation {
    case "reply": facts = try changed(facts, "reply", UUID().uuidString)
    case "original": facts = try changed(facts, "original", object(state.admissions[1].original))
    case "component":
      let last = try changed(facts.last, "component", UUID().uuidString)
      facts = try changed(facts, "last", object(last))
    case "one-snapshot": facts = try changed(facts, "last", object(facts.first))
    case "frame": facts = try changed(facts, "lastFrame", facts.firstFrame)
    case "range":
      let last = try changed(facts.last, "surfaceRanges", Array(repeating: 1501, count: 12))
      facts = try changed(facts, "last", object(last))
    case "height":
      let last = try changed(facts.last, "reliefHeights", [0, 0, 0])
      facts = try changed(facts, "last", object(last))
    case "instrument":
      let item = OwnedEquipmentItem(
        id: facts.instrument.id,
        node: .init(family: .init("foreign-family"), key: facts.instrument.node.key),
        provenance: facts.instrument.provenance, location: facts.instrument.location)
      facts = try changed(facts, "instrument", object(item))
    default: facts = try changed(facts, "sequence", try #require(state.consents.first?.reply?.sequence))
    }
    // Rehash the altered facts so this checks the actual joins, not merely a stale digest.
    let forged = NativeHollowManifestSealInspection(
      operation: try NativeHollowManifestSealInspection.identity(facts), facts: facts)
    #expect(throws: State.Failure.invalidState) { _ = try state.retainingInspection(forged) }
    #expect(state.inspections.isEmpty)
  }

  @Test func laterStructuralDamageKeepsEarlierObservationButCannotBeBackdatedAcrossIt() throws {
    let (state, receipt) = try inspectionFixture()
    let recorded = try state.retainingInspection(receipt)
    let later = try recorded.retainingSealDamage(
      facts: sealFacts(recorded, time: 41), admission: receipt.facts.admission)
    #expect(later.shapeValid && later.inspections == [receipt])
    #expect(later.firstCompromises.count == 1 && later.preservesHistory(of: recorded))
    #expect(throws: State.Failure.invalidState) {
      _ = try recorded.retainingSealDamage(
        facts: sealFacts(recorded, time: 39), admission: receipt.facts.admission)
    }
  }

  @Test func currentLeafDoesNotAcceptErasedInspectionArrayOrUnknownPermissionFlag() throws {
    let (state, _) = try inspectionFixture()
    let bytes = try NativeHollowManifestSave.encode(state)
    var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    raw.removeValue(forKey: "inspections")
    #expect(throws: (any Error).self) {
      _ = try NativeHollowManifestSave.decode(
        JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys, .withoutEscapingSlashes]),
        owner: state.birth.input.owner, mission: state.birth.input.mission)
    }
    raw["inspections"] = []
    raw["scanPermission"] = true
    #expect(throws: (any Error).self) {
      _ = try NativeHollowManifestSave.decode(
        JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys, .withoutEscapingSlashes]),
        owner: state.birth.input.owner, mission: state.birth.input.mission)
    }
  }

  @Test func decodedLogAccessCannotCreateAnOriginalCrewRescueOrEnterTheStrictCodec() throws {
    let state = try fixture()
    let facts = NativeC03CrewLogAccessReceipt.Facts(registration: UUID(), document: UUID(),
      documentHash: String(repeating: "a", count: 64), careTransfer: UUID(), service: UUID(),
      owner: state.birth.input.owner, dock: state.birth.input.dock,
      originalKit: UUID(), issueCommand: UUID(), carrier: UUID(), inventoryRevision: 1,
      beforeCaseRevision: 1, afterCaseRevision: 2, physicalTime: 30,
      calendarSeconds: 30, epoch: UUID())
    // Decoder data only: neither private ward witness nor physical care is issued here.
    let bytes = try JSONSerialization.data(withJSONObject: [
      "operation": UUID().uuidString, "facts": try object(facts),
    ])
    let access = try JSONDecoder().decode(NativeC03CrewLogAccessReceipt.self, from: bytes)
    let injected = try changed(state, "crewLogAccess", object(access))
    let cold = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(injected))
    #expect(cold.crewLogAccess == access && cold == injected)
    #expect(!access.valid(in: cold) && !cold.shapeValid)
    #expect(!cold.preservesHistory(of: state))
    #expect(throws: NativeHollowManifestSave.Failure.invalidLeaf) {
      try NativeHollowManifestSave.encode(cold)
    }
    #expect(throws: State.Failure.invalidState) { try state.retainingCrewLogAccess(access) }
    #expect(state.crewLogAccess == nil && state.crewSource == nil && state.caseFile == nil)
  }

}

extension NativeHollowManifestStateUnitTests {
  @Test(arguments: [
    "admission", "request", "reply", "revocation", "withdrawal", "terminal",
    "first-seal", "latest-seal",
  ])
  func everyRetainedTimeFamilyRejectsBackdatedFactsAndAcceptsItsExactWatermark(family: String)
    throws
  {
    let (state, watermark) = try retainedTimeHistory(family)
    try #require(state.shapeValid)
    let before = state
    let reference = state.latestAdmissions[1]
    let stale = consentRequest(state, slot: 1, time: watermark - 1)
    #expect(throws: State.Failure.invalidState) {
      _ = try state.retainingConsentRequest(request: stale, admission: reference)
    }
    #expect(state == before)
    let boundary = consentRequest(state, slot: 1, time: watermark)
    let accepted = try state.retainingConsentRequest(request: boundary, admission: reference)
    #expect(accepted.shapeValid && accepted.preservesHistory(of: before))
    #expect(accepted.consents.last?.request == boundary)
    #expect(accepted.nextSourceSequence == state.nextSourceSequence + 1)
    #expect(accepted.admissions == state.admissions && accepted.terminals == state.terminals)
    #expect(accepted.withdrawals == state.withdrawals)
    #expect(accepted.firstCompromises == state.firstCompromises)
    #expect(accepted.latestSealDamage == state.latestSealDamage)
  }

  private func retainedTimeHistory(_ family: String) throws -> (State, Double) {
    var state = try fixture()
    switch family {
    case "admission":
      return (try reboundSealState(state, time: 50), 50)
    case "request":
      let request = consentRequest(state, time: 50)
      return (try state.retainingConsentRequest(request: request, admission: state.latestAdmissions[0]), 50)
    case "reply", "revocation":
      let request = consentRequest(state)
      state = try state.retainingConsentRequest(request: request, admission: state.latestAdmissions[0])
      let reply = try consentReply(state, time: family == "reply" ? 50 : 32)
      state = try state.retainingConsentReply(reply: reply, admission: state.latestAdmissions[0])
      if family == "reply" { return (state, 50) }
      let hit = effect(state, damage: 1, after: 219)
      let player = try #require(hit.incident.origin).owner
      state = try state.retainingRootEffect(effect: hit, actualPlayer: player)
      let revocation = try consentReply(state, decision: .revoked, time: 50)
      return (try state.retainingConsentRevocation(
        revocation: revocation, admission: state.latestAdmissions[0]), 50)
    case "withdrawal", "terminal":
      let hit = family == "withdrawal" ? effect(state, damage: 1, after: 219) : effect(state)
      let player = family == "withdrawal" ? hit.incident.origin?.owner : nil
      return (try state.retainingRootEffect(effect: hit, actualPlayer: player), 40)
    case "first-seal", "latest-seal":
      let facts = try sealFacts(state, time: family == "first-seal" ? 50 : 40)
      state = try state.retainingSealDamage(facts: facts, admission: state.latestAdmissions[0])
      if family == "first-seal" { return (state, 50) }
      let latest = try sealFacts(state, incident: 21, time: 50, before: 15)
      return (try state.retainingSealDamage(facts: latest, admission: state.latestAdmissions[0]), 50)
    default:
      throw State.Failure.invalidState
    }
  }
}
