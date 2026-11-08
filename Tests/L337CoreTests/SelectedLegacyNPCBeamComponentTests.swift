import Foundation
import Testing

@testable import L337Core

struct SelectedLegacyNPCBeamComponentTests {
  @Test
  func selectedBeamDamagesTheActuallyIssuedTurretAndRequeriesItsCurrentHealth() throws {
    let prepared = try prepareBeam()
    var game = prepared.opening
    let interval = game.advanceCurrentNewtNativeInterval(prepared.path, npcFrame: prepared.frame)
    let evidence = try #require(interval.evidence)
    try #require(evidence.completedOuterInterval)
    expectRetainedEvidenceKeepsFullClockAndCensus(game, prepared: prepared, evidence: evidence)
    try verifyRetainedBeam(&game, prepared: prepared, evidence: evidence)
  }
  private struct PreparedBeam {
    let opening: Game
    let instance: UUID
    let targetID: Int
    let owner: ActorIdentity
    let victim: ActorIdentity
    let path: CurrentNewtOuterMotion
    let frame: CurrentNewtNPCFrame
    let geometry: MissionCollisionQueryGeometry
    let plan: SelectedNPCBeamPlan
  }


  @inline(never)
  private func prepareBeam() throws -> PreparedBeam {
    var (game, instance, index) = try actualMissionBridgeGame()
    var target = game.bodies[index]
    let npc = try #require(target.scriptNPC)
    let turretCandidate = npc.fit.definition.components?.first { $0.id == "turret" }
    let turret = try #require(turretCandidate)
    let issued = try #require(npc.components[turret.id])
    try #require(turret.solid && issued.energy > 2)
    let emitterStart = Vector3(0, 0, 1200)
    let emitter = try selectedLegacyBeamEmitter(id: 91_004, position: emitterStart)
    let emitterEnd = LegacyNPCFlightDecision.ordinaryPosition(
      emitterStart, maximumSpeed: emitter.nativeNavalCombat?.speed, delta: 0.05)
    let aim = Game.nativePlayerSurfaceAim(from: emitterEnd, mesh: game.nativeGuidanceStoredPlayerMesh())
    // Reposition the actual issued actor, preserving its installed fit and UUID.
    // The beam passes through the turret above the hull, as in the existing
    // actualPlayerLaserUsesAuthoredComponentGeometryAndSharedDamage regression.
    target.position = emitterEnd + (aim - emitterEnd) * 0.6
      - turret.position * npc.fit.definition.scale
    target.orientation = .init()
    target.rotation = 0
    target.rotationRate = 0
    game.bodies = [target, emitter]
    game.celestials = []
    game.speed = 0
    game.ensurePhysicalActors()
    let ownedBeamRequired1 = game.bodies.first { $0.id == 91_004 }?.physical?.identity
    let owner = try #require(ownedBeamRequired1)
    let ownedBeamRequired2 = game.bodies.first { $0.id == target.id }?.physical?.identity
    let victim = try #require(ownedBeamRequired2)
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate)
    var frameRefusal: CurrentNewtPreparationRefusal? = nil
    let frameCandidate = game.prepareCurrentNewtNPCFrame(path, report: {
      if frameRefusal == nil { frameRefusal = $0 }
    })
    let frameReason = frameRefusal?.summary ?? "NPC frame refusal checkpoint missing (instrumentation incomplete)"
    let frame = try #require(frameCandidate, Comment(rawValue: frameReason))
    let geometry = try game.prepareSelectedNPCBeamGeometry(for: path)
    let planCandidate = game.prepareSelectedLegacyNPCBeam(
      entry: try #require(frame.entries[owner]), geometry: geometry)
    let plan = try #require(planCandidate)
    expectCompleteCommanderEquality(game, delta: path.endTime - path.startTime)
    return .init(
      opening: game, instance: instance, targetID: target.id, owner: owner, victim: victim,
      path: path, frame: frame, geometry: geometry, plan: plan)
  }

  private final class RetainedBeamSource {
    let target: SpaceBody
    let npc: ScriptNPCState
    let turret: ScriptNPCComponent
    let issued: ScriptNPCComponentState
    init(target: SpaceBody, npc: ScriptNPCState, turret: ScriptNPCComponent, issued: ScriptNPCComponentState) {
      self.target = target; self.npc = npc; self.turret = turret; self.issued = issued
    }
  }

  private final class CheckedBeamContact {
    let contact: MissionCollisionContact
    let part: String
    let componentID: UUID
    let live: SpaceBody
    let component: ScriptNPCComponentState
    init(contact: MissionCollisionContact, part: String, componentID: UUID,
      live: SpaceBody, component: ScriptNPCComponentState) {
      self.contact = contact; self.part = part; self.componentID = componentID
      self.live = live; self.component = component
    }
  }

  private final class RefreshedBeam {
    let contact: MissionCollisionContact
    let afterHit: FlightSimulationState
    init(_ contact: MissionCollisionContact, afterHit: FlightSimulationState) {
      self.contact = contact; self.afterHit = afterHit
    }
  }

  @inline(never)
  private func verifyRetainedBeam(
    _ game: inout Game, prepared: PreparedBeam, evidence: CurrentNewtNativeClockEvidence
  ) throws {
    let source = try retainedBeamSource(prepared)
    let ownedBeamRequired3 = game.querySelectedLegacyNPCBeam(prepared.plan, evidence: evidence)
    let query = try #require(ownedBeamRequired3)
    let checked = try verifyInitialBeamContact(game, prepared: prepared, source: source, query: query)
    try preflightRetainedBeam(&game, prepared: prepared, checked: checked, evidence: evidence)
    let origin = try retainedBeamOrigin(&game, prepared: prepared)
    let result = try applyRetainedBeam(&game, prepared: prepared, checked: checked, query: query,
      origin: origin, evidence: evidence)
    try verifyAppliedBeam(game, prepared: prepared, source: source, checked: checked, result: result)
    let refreshed = try requeryRetainedBeam(game, prepared: prepared, evidence: evidence)
    verifyRefreshedBeam(game, checked: checked, refreshed: refreshed)
  }

  @inline(never)
  private func retainedBeamSource(_ prepared: PreparedBeam) throws -> RetainedBeamSource {
    // Read the exact saved source only after the real retention returns. These
    // are the original issued UUID/fit facts, never a reconstructed target.
    let targetCandidate = prepared.opening.bodies.first { $0.id == prepared.targetID }
    let target = try #require(targetCandidate)
    let npc = try #require(target.scriptNPC)
    let turretCandidate = npc.fit.definition.components?.first { $0.id == "turret" }
    let turret = try #require(turretCandidate)
    let issued = try #require(npc.components[turret.id])
    return .init(target: target, npc: npc, turret: turret, issued: issued)
  }

  @inline(never)
  private func verifyInitialBeamContact(_ game: Game, prepared: PreparedBeam,
    source: RetainedBeamSource, query: SelectedNPCBeamQuery) throws -> CheckedBeamContact {
    let instance = prepared.instance
    let target = source.target
    let npc = source.npc
    let turret = source.turret
    let issued = source.issued
    let contact = try #require(query.contact)
    let part = try #require(contact.victimPart)
    let componentID = try #require(contact.componentUUID)
    try #require(part == turret.id && componentID == issued.identity)
    try #require(contact.hit.target == .body(target.id))
    let liveCandidate = game.bodies.first { $0.id == target.id }
    let live = try #require(liveCandidate)
    let component = try #require(live.scriptNPC?.components[part])
    try #require(component.identity == componentID && component.energy > 2)
    #expect(live.scriptNPC?.fit == npc.fit)
    #expect(live.missionInstanceID == instance)
    return .init(contact: contact, part: part, componentID: componentID, live: live, component: component)
  }

  @inline(never)
  private func preflightRetainedBeam(_ game: inout Game, prepared: PreparedBeam,
    checked: CheckedBeamContact, evidence: CurrentNewtNativeClockEvidence) throws {
    let contact = checked.contact
    let owner = prepared.owner
    let before = game.storedFlightSimulation()
    _ = try game.preflightSelectedNativeMissionContact(
      contact, owner: owner, damage: 1, evidence: evidence)
    let ownedBeamExpected4 = game.storedFlightSimulation() == before
    #expect(ownedBeamExpected4)
  }

  @inline(never)
  private func retainedBeamOrigin(_ game: inout Game, prepared: PreparedBeam) throws -> AttackOrigin {
    let owner = prepared.owner
    let originCandidate = game.makeAttackOrigin(owner: owner)
    let origin = try #require(originCandidate)
    return origin
  }

  @inline(never)
  private func applyRetainedBeam(_ game: inout Game, prepared: PreparedBeam,
    checked: CheckedBeamContact, query: SelectedNPCBeamQuery, origin: AttackOrigin,
    evidence: CurrentNewtNativeClockEvidence)
    throws -> (receipt: NativeMissionImpactReceipt, clockEffect: NativeMissionBeamClockEffect) {
    let contact = checked.contact
    let afterEmission = game.storedFlightSimulation()
    let result = try game.applySelectedNativeMissionContact(
      contact, origin: origin, damage: 1, emissionPosition: query.launch, evidence: evidence)
    let ownedBeamExpected5 = result.clockEffect.applying(to: afterEmission) == game.storedFlightSimulation()
    #expect(ownedBeamExpected5)
    return result
  }

  @inline(never)
  private func verifyAppliedBeam(_ game: Game, prepared: PreparedBeam, source: RetainedBeamSource,
    checked: CheckedBeamContact, result: (receipt: NativeMissionImpactReceipt, clockEffect: NativeMissionBeamClockEffect)) throws {
    let instance = prepared.instance
    let owner = prepared.owner
    let victim = prepared.victim
    let path = prepared.path
    let geometry = prepared.geometry
    let target = source.target
    let npc = source.npc
    let part = checked.part
    let componentID = checked.componentID
    let live = checked.live
    let component = checked.component
    let contact = checked.contact
    #expect(result.receipt.damageAdmitted && result.receipt.target == .body(target.id))
    #expect(result.receipt.victimPart == part && result.receipt.victimComponentID == componentID)
    let actualCandidate = game.bodies.first { $0.id == target.id }
    let actual = try #require(actualCandidate)
    #expect(actual.energy == live.energy)
    #expect(actual.scriptNPC?.fit == npc.fit && actual.missionInstanceID == instance)
    #expect(actual.scriptNPC?.components[part]?.identity == componentID)
    #expect(actual.scriptNPC?.components[part]?.energy == component.energy - 1)
    let incident = result.clockEffect.incident
    #expect(incident.victim == victim && incident.origin.owner == owner)
    #expect(incident.physicalTime == path.endTime && incident.origin.emittedAt == path.endTime)
    #expect(incident.position == geometry.selectedFrame.systemPoint(contact.hit.point))
  }

  @inline(never)
  private func requeryRetainedBeam(_ game: Game, prepared: PreparedBeam,
    evidence: CurrentNewtNativeClockEvidence) throws -> RefreshedBeam {
    let plan = prepared.plan
    let afterHit = game.storedFlightSimulation()
    let ownedBeamRequired6 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)?.contact
    let refreshed = try #require(ownedBeamRequired6)
    return .init(refreshed, afterHit: afterHit)
  }

  @inline(never)
  private func verifyRefreshedBeam(_ game: Game, checked: CheckedBeamContact, refreshed current: RefreshedBeam) {
    let refreshed = current.contact
    let afterHit = current.afterHit
    let part = checked.part
    let componentID = checked.componentID
    let component = checked.component
    #expect(refreshed.victimPart == part && refreshed.componentUUID == componentID)
    #expect(refreshed.selectedTargetBody?.scriptNPC?.components[part]?.energy == component.energy - 1)
    let ownedBeamExpected7 = game.storedFlightSimulation() == afterHit
    #expect(ownedBeamExpected7)
  }

  // Positive proof and stale-clock/census cases use isolated copies of the same
  // actual retained scene; none can grant a clock, source, body or contact.
  @inline(never)
  private func expectRetainedEvidenceKeepsFullClockAndCensus(
    _ game: Game, prepared: PreparedBeam, evidence: CurrentNewtNativeClockEvidence
  ) {
    let opening = prepared.opening.storedFlightSimulation()
    let closing = game.storedFlightSimulation()
    let verified = evidence.verifiedFinalFlight(
      from: opening, usedD: prepared.path.motion.duration, epoch: game.nativeStationRuntimeEpoch)
    let clockMatches = verified == closing
    #expect(clockMatches)
    let actualMatches = evidence.validatesSelectedBeamGeometry(prepared.geometry, closing: game)
    #expect(actualMatches)
    var wrongClock = game
    wrongClock.commander.flightSimulation.advancePhysicalTime(0.01)
    let staleClockMatches = evidence.validatesSelectedBeamGeometry(prepared.geometry, closing: wrongClock)
    #expect(!staleClockMatches)
    var missingBody = game
    missingBody.bodies.removeAll { $0.id == prepared.targetID }
    let missingBodyMatches = evidence.validatesSelectedBeamGeometry(prepared.geometry, closing: missingBody)
    #expect(!missingBodyMatches)
    let originalUnchanged = evidence.validatesSelectedBeamGeometry(prepared.geometry, closing: game)
    #expect(originalUnchanged)
  }

  // Exercise early scalar, late stored optional and the actual advanced-clock
  // full comparison before entering the native retention call stack.
  @inline(never)
  private func expectCompleteCommanderEquality(_ opening: Game, delta: Double) {
    let same = opening
    let publicSame = opening.commander == same.commander
    let storedSame = opening.currentNewtNativeCommanderMatches(same)
    #expect(publicSame && storedSame)
    var credits = opening
    credits.commander.credits += 1
    let creditsEqual = opening.currentNewtNativeCommanderMatches(credits)
    let publicCreditsEqual = opening.commander == credits.commander
    #expect(!creditsEqual && !publicCreditsEqual)
    var blackjack = opening
    blackjack.commander.blackjack.pendingGold.toggle()
    let blackjackEqual = opening.currentNewtNativeCommanderMatches(blackjack)
    let publicBlackjackEqual = opening.commander == blackjack.commander
    #expect(!blackjackEqual && !publicBlackjackEqual)
    // Stored optional absence is part of full equality even when the public
    // default view is the same. Never normalize nil into a default mission.
    let absent = Game(executive: false)
    var present = absent
    present.commander.blackjack = BlackjackMission()
    let publicAbsenceEqual = absent.commander == present.commander
    let storedAbsenceEqual = absent.currentNewtNativeCommanderMatches(present)
    #expect(!publicAbsenceEqual && !storedAbsenceEqual)
    var advanced = opening
    advanced.commander.flightSimulation.advancePhysicalTime(delta)
    let advancedMatches = advanced.currentNewtNativeCommanderMatches(opening, advancingClockBy: delta)
    let unadvancedMatches = opening.currentNewtNativeCommanderMatches(opening, advancingClockBy: delta)
    #expect(advancedMatches && !unadvancedMatches)
    advanced.commander.blackjack.pendingGold.toggle()
    let unrelatedMatches = advanced.currentNewtNativeCommanderMatches(opening, advancingClockBy: delta)
    #expect(!unrelatedMatches)
  }
}
