import Foundation
import Testing

@testable import L337Core

private func legacyIntentGame() -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [
    SpaceBody(id: 10, hull: .sidewinder, position: .init(0, 0, 1000), hostile: true)
  ]
  game.bodies[0].energy = 100
  game.celestials = []
  game.energy = 100
  game.frontShield = 0
  game.rearShield = 0
  game.ensurePhysicalActors()
  // This controlled legacy-role actor needs an authenticated collider; the
  // retired sidewinder discriminator alone supplies no current native mesh.
  let source = OriginalFleetRuntimeHullSource.source(for: "SH029")
  #expect(source != nil)
  game.bodies[0].physical?.catalogueShipID = source?.ship.id
  return game
}

private enum LegacyInvalidIntent: CaseIterable, Equatable, Sendable {
  case missingIntent, dock, flee, nonplayer, staleTarget, missingNPC, missingPhysical
  case staleActorVisit, staleActorSystem, reservedActor, unallocatedActor, missingPlayer
  case wrongPlayerSystem
}

private func reframeLegacyIntentGame(_ game: inout Game, to pose: ShipPose) {
  let previous = game.commander.flightSimulation.pose
  for index in game.bodies.indices {
    let point = previous.systemPoint(game.bodies[index].position)
    let orientation = game.bodies[index].orientation.transformed(by: previous.orientation)
    game.bodies[index].position = pose.shipPoint(point)
    game.bodies[index].orientation = orientation.relative(to: pose.orientation)
  }
  for index in game.celestials.indices {
    game.celestials[index].position = pose.shipPoint(
      previous.systemPoint(game.celestials[index].position))
  }
  game.commander.flightSimulation.pose = pose
}

struct LegacyNPCIntentTests {
  @Test(arguments: LegacyInvalidIntent.allCases)
  fileprivate func staleHostilityDoesNotAuthorizePursuitOrEmission(_ invalid: LegacyInvalidIntent)
    throws
  {
    var game = legacyIntentGame()
    let player = try #require(game.commander.flightSimulation.player)
    let physical = try #require(game.bodies[0].physical)
    try #require(physical.npc?.intention == .engage(player))
    switch invalid {
    case .missingIntent: game.bodies[0].physical?.npc?.intention = nil
    case .dock:
      let station = try #require(game.commander.flightSimulation.anchors?.station.identity)
      game.bodies[0].physical?.npc?.intention = .dock(station)
    case .flee: game.bodies[0].physical?.npc?.intention = .flee(player)
    case .nonplayer:
      let allocated = game.commander.flightSimulation.allocateActor()
      let other = try #require(allocated)
      game.bodies[0].physical?.npc?.intention = .engage(other)
    case .staleTarget:
      let old = ActorIdentity(system: player.system, visit: player.visit - 1, entity: player.entity)
      game.bodies[0].physical?.npc?.intention = .engage(old)
    case .missingNPC: game.bodies[0].physical?.npc = nil
    case .missingPhysical: game.bodies[0].physical = nil
    case .staleActorVisit, .staleActorSystem, .reservedActor, .unallocatedActor:
      let old = physical.identity
      let identity = ActorIdentity(
        system: invalid == .staleActorSystem
          ? .init(galaxy: old.system.galaxy, system: old.system.system + 1) : old.system,
        visit: invalid == .staleActorVisit ? old.visit - 1 : old.visit,
        entity: invalid == .reservedActor
          ? 1
          : invalid == .unallocatedActor ? game.commander.flightSimulation.nextActor : old.entity)
      game.bodies[0].physical = .init(
        identity: identity, population: physical.population, npc: physical.npc)
    case .missingPlayer: game.commander.flightSimulation = .init()
    case .wrongPlayerSystem: game.commander.system += 1
    }
    let before = game.bodies
    let commander = game.commander
    #expect(
      game.prepareLegacyNPCFlightDecision(
        game.bodies[0],
        frame: game.commander.flightSimulation.pose, delta: 0.1) == nil)
    #expect(game.bodies == before && game.commander == commander)
    let effectPhase = game.applyLegacyNPCFlightEffects(index: 0, delta: 0.1)
    #expect(!effectPhase)
    #expect(game.bodies == before && game.commander == commander)
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies == before && game.commander == commander)
    #expect(game.energy == 100 && game.frontShield == 0 && game.rearShield == 0)
  }

  @Test func adoptedPlayerEngagementStillPursuesAndEmitsThroughRealCombat() throws {
    var game = legacyIntentGame()
    let player = try #require(game.commander.flightSimulation.player)
    let before = try #require(game.bodies.first)
    try #require(before.physical?.npc?.intention == .engage(player))
    let emission = game.commander.flightSimulation.nextEmission
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.z < before.position.z && game.energy < 100)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
    #expect((game.bodies[0].physical?.npc?.resources?.laserHeat ?? 0) > 0)
    #expect(game.commander.legal == 0 && game.commander.kills == 0)
  }

  @Test func actualNonplayerAssaultRetargetsAndStopsLegacyPlayerAttack() throws {
    var game = legacyIntentGame()
    game.bodies.append(.init(id: 11, hull: .cobra, position: .init(500, 0, 1000)))
    game.ensurePhysicalActors()
    let attacker = try #require(game.bodies[1].physical?.identity)
    let origin = game.makeAttackOrigin(owner: attacker)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 500, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    let incident = try #require(recorded)
    #expect(
      incident.origin.owner == attacker && incident.victim == game.bodies[0].physical?.identity)
    #expect(game.bodies[0].physical?.npc?.firstAggressor == attacker)
    #expect(game.bodies[0].physical?.npc?.intention == .engage(attacker))
    #expect(!game.bodies[0].hostile && game.bodies[0].energy == 99)
    let before = game.bodies
    let commander = game.commander
    #expect(
      game.prepareLegacyNPCFlightDecision(
        game.bodies[0],
        frame: game.commander.flightSimulation.pose, delta: 0.1) == nil)
    #expect(game.bodies == before && game.commander == commander)
    let effectPhase = game.applyLegacyNPCFlightEffects(index: 0, delta: 0.1)
    #expect(!effectPhase)
    #expect(game.bodies == before && game.commander == commander)
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies == before && game.commander == commander && game.energy == 100)
    #expect(game.commander.legal == 0 && game.commander.kills == 0)
  }

  @Test func actualPlayerAssaultStillEnablesOrdinaryRetaliation() throws {
    var game = legacyIntentGame()
    game.bodies[0].hostile = false
    game.bodies[0].physical?.npc?.intention = nil
    let player = try #require(game.commander.flightSimulation.player)
    let origin = game.makeAttackOrigin(owner: player)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 1000, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    try #require(recorded != nil)
    #expect(game.bodies[0].hostile && game.bodies[0].physical?.npc?.intention == .engage(player))
    let legal = game.commander.legal
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.energy < 100 && game.commander.legal == legal && legal > 0)
  }

  @Test func authenticatedLegacyBeamStillRespectsCelestialOcclusion() {
    var game = legacyIntentGame()
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 500), radius: 100)]
    let emission = game.commander.flightSimulation.nextEmission
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.z < 1000 && game.energy == 100)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
  }

  @Test func blackjackDriverRemainsEligibleWithoutOrdinaryPlayerIntent() throws {
    var game = legacyIntentGame()
    var encounter = BlackjackEncounter(role: .bolts, id: 10)
    encounter.body.position = .init(0, 0, 1000)
    let attackerBody = try exactCombatFixtureBody(
      &game, id: 11, position: .init(500, 0, 1000), hull: .sidewinder)
    game.bodies = [encounter.body, attackerBody]
    game.ensurePhysicalActors()
    let attacker = try #require(game.bodies[1].physical?.identity)
    let origin = game.makeAttackOrigin(owner: attacker)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 500, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    try #require(recorded != nil)
    #expect(game.bodies[0].hostile && game.bodies[0].physical?.npc?.intention == .engage(attacker))
    let before = game.bodies[0].position
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.length < before.length)
    #expect((game.bodies[0].blackjackLaserCooldown ?? 0) > 0)
  }
}

extension LegacyNPCIntentTests {
  @Test(arguments: [false, true])
  func pureLegacyPursuitMatchesUnchangedKernelWithoutFiringDuringPreparation(_ near: Bool) throws {
    let game = legacyIntentGame()
    var preparedGame = game
    preparedGame.bodies[0].position = near ? .init(0, 0, 1000) : .init(400, 200, 5000)
    let before = preparedGame
    let body = try #require(preparedGame.bodies.first)
    let ownedPreparationRequired1 = preparedGame.prepareLegacyNPCFlightDecision(
        body,
        frame: preparedGame.commander.flightSimulation.pose, delta: 0.1)
    let decision = try #require(ownedPreparationRequired1)
    #expect(decision.driver == .ordinaryPlayerEngagement && decision.bodyID == body.id)
    #expect(
      decision.actor == body.physical?.identity
        && decision.intention == body.physical?.npc?.intention)
    #expect(decision.epoch == before.nativeStationRuntimeEpoch)
    #expect(preparedGame.commander == before.commander && preparedGame.bodies == before.bodies)
    #expect(preparedGame.scriptWorldSave == before.scriptWorldSave)
    #expect(preparedGame.energy == before.energy && preparedGame.frontShield == before.frontShield)
    #expect(
      preparedGame.rearShield == before.rearShield && preparedGame.nextBodyID == before.nextBodyID)
    #expect(preparedGame.message == before.message && !preparedGame.workScenePlanned)
    #expect(preparedGame.plannedLegacyWorkMotion.isEmpty)
    var expectedRNG = before
    var actualRNG = preparedGame
    for _ in 0..<4 {
      let actualByte = actualRNG.randomByte()
      let expectedByte = expectedRNG.randomByte()
      #expect(actualByte == expectedByte)
    }
    let first = try #require(decision.worldPosition(at: decision.physicalTime + 0.025))
    let second = try #require(decision.worldPosition(at: decision.physicalTime + 0.075))
    let end = try #require(decision.worldPosition(at: decision.physicalTime + 0.1))
    #expect(decision.worldPosition(at: decision.physicalTime - 0.001) == nil)
    #expect(decision.worldPosition(at: decision.physicalTime + 0.101) == nil)
    // The original movement remains the control; only its effect clauses are extracted.
    var actual = preparedGame
    actual.enemyAction(index: 0, dt: 0.1)
    let actualStart = before.commander.flightSimulation.pose.systemPoint(before.bodies[0].position)
    let actualEnd = actual.commander.flightSimulation.pose.systemPoint(actual.bodies[0].position)
    let actualDisplacement = actualEnd - actualStart
    #expect((decision.worldStart - actualStart).length < 1e-8)
    #expect((first - (actualStart + actualDisplacement * 0.25)).length < 1e-8)
    #expect((second - (actualStart + actualDisplacement * 0.75)).length < 1e-8)
    #expect((end - actualEnd).length < 1e-8)
    #expect(actual.bodies[0].position == decision.end)
    #expect(actual.bodies[0].physical?.velocity == decision.worldVelocity)
    #expect(actual.bodies[0].orientation == before.bodies[0].orientation)
    #expect(actual.bodies[0].physical?.identity == decision.actor)
    if near {
      #expect(
        actual.commander.flightSimulation.nextEmission == before.commander.flightSimulation
          .nextEmission + 1)
      #expect(actual.energy < before.energy)
    } else {
      #expect(
        actual.commander.flightSimulation.nextEmission
          == before.commander.flightSimulation.nextEmission)
    }
  }

  @Test func pureFallbackKeepsTheOriginal300ThresholdWithoutRepeatingDampingPerCut() throws {
    // Scalar arithmetic only; this does not equip/admit a different hull or role.
    let position = Vector3(100, 200, 301)
    let end = LegacyNPCFlightDecision.ordinaryPosition(position, maximumSpeed: nil, delta: 0.1)
    #expect(end == .init(97.5, 195, 295))
    #expect(
      LegacyNPCFlightDecision.ordinaryPosition(
        .init(100, 200, 300),
        maximumSpeed: nil, delta: 0.1
      ).z == 300)
    #expect(
      LegacyNPCFlightDecision.ordinaryPosition(
        .init(0, 0, 0),
        maximumSpeed: 40, delta: 0.1) == .init(0, 0, 0))
    #expect(
      LegacyNPCFlightDecision.ordinaryPosition(
        .init(0, 0, 1),
        maximumSpeed: 40, delta: 0.1) == .init(0, 0, 0))
  }

  @Test func pureBlackjackExceptionKeepsMotionButDefersResourcesCooldownRandomnessAndFire() throws {
    var game = legacyIntentGame()
    var encounter = BlackjackEncounter(role: .bolts, id: 10)
    encounter.body.position = .init(0, 0, 1000)
    encounter.body.energy = 100
    let attackerBody = try exactCombatFixtureBody(
      &game, id: 11, position: .init(500, 0, 1000), hull: .sidewinder)
    game.bodies = [encounter.body, attackerBody]
    game.ensurePhysicalActors()
    let attacker = try #require(game.bodies[1].physical?.identity)
    let attackCandidate = game.makeAttackOrigin(owner: attacker)
    let attack = try #require(attackCandidate)
    let hit = GameplayHit(target: .body(10), distance: 500, point: game.bodies[0].position)
    let incident = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    try #require(incident != nil)
    try #require(game.bodies[0].physical?.npc?.intention == .engage(attacker))
    let before = game
    let ownedPreparationRequired2 = game.prepareLegacyNPCFlightDecision(
        game.bodies[0],
        frame: game.commander.flightSimulation.pose, delta: 0.1)
    let decision = try #require(ownedPreparationRequired2)
    #expect(decision.driver == .blackjack && decision.blackjackIdentity == encounter.identity)
    #expect(decision.intention == .engage(attacker))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.scriptWorldSave == before.scriptWorldSave && game.energy == before.energy)
    var expectedRNG = before
    var actualRNG = game
    for _ in 0..<4 {
      let actualByte = actualRNG.randomByte()
      let expectedByte = expectedRNG.randomByte()
      #expect(actualByte == expectedByte)
    }
    var actual = game
    actual.enemyAction(index: 0, dt: 0.1)
    #expect(actual.bodies[0].position == decision.end)
    #expect(
      (actual.commander.flightSimulation.pose.systemPoint(actual.bodies[0].position)
        - decision.worldEnd).length < 1e-8)
    #expect(
      abs(actual.bodies[0].energy - (before.bodies[0].energy + BlackjackTarget.recharge * 0.1))
        < 1e-8)
    #expect(actual.bodies[0].blackjackLaserCooldown == LaserKind.pulse.firingInterval)
    #expect(actual.bodies[0].physical?.velocity == before.bodies[0].physical?.velocity)
    #expect(abs((decision.end - decision.start).length - BlackjackTarget.speed * 0.1) < 1e-8)
  }

  @Test func pureBlackjackRangeCrossingDoesNotPrecreditTheOriginalPreMoveFireGate() throws {
    var game = legacyIntentGame()
    var encounter = BlackjackEncounter(role: .bolts, id: 10)
    encounter.body.position = .init(0, 0, 1501)
    game.bodies = [encounter.body]
    game.ensurePhysicalActors()
    let ownedPreparationRequired3 = game.prepareLegacyNPCFlightDecision(
        game.bodies[0],
        frame: game.commander.flightSimulation.pose, delta: 0.1)
    let decision = try #require(ownedPreparationRequired3)
    try #require(decision.start.length > 1500 && decision.end.length < 1500)
    let emission = game.commander.flightSimulation.nextEmission
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position == decision.end)
    #expect(game.commander.flightSimulation.nextEmission == emission)
    #expect(game.bodies[0].blackjackLaserCooldown == 0)
  }
}

extension LegacyNPCIntentTests {
  @Test func pureLegacyDecisionAcceptsSelectedCameraFrameWithoutAFutureGameOrClock() throws {
    var game = legacyIntentGame()
    game.bodies[0].position = .init(400, 200, 5000)
    let before = game
    let body = game.bodies[0]
    let opening = game.commander.flightSimulation.pose
    var frame = opening
    frame.position = frame.position + .init(100, 50, 200)
    frame.orientation.rotate(pitch: 0.1, roll: 0.05, yaw: 0.1)
    var projected = body
    projected.position = frame.shipPoint(opening.systemPoint(body.position))
    let ownedPreparationRequired4 = game.prepareLegacyNPCFlightDecision(projected, frame: frame, delta: 0.1)
    let decision = try #require(ownedPreparationRequired4)
    #expect((decision.worldStart - opening.systemPoint(body.position)).length < 1e-8)
    #expect(decision.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    var actual = game
    reframeLegacyIntentGame(&actual, to: frame)
    actual.enemyAction(index: 0, dt: 0.1)
    #expect(
      (actual.commander.flightSimulation.pose.systemPoint(actual.bodies[0].position)
        - decision.worldEnd).length < 1e-8)
    let velocity = try #require(actual.bodies[0].physical?.velocity)
    #expect((velocity - decision.worldVelocity).length < 1e-8)
    #expect(
      actual.commander.flightSimulation.physicalTime == game.commander.flightSimulation.physicalTime
    )
  }
}

/// Declared existing legacy unit scenes only; this supplies no original hull/mission role.
private func legacyFlightEffectGame(
  blackjack: Bool, range: Double = 1000,
  cooldown: Double? = nil
) -> Game {
  var game = legacyIntentGame()
  if blackjack {
    var encounter = BlackjackEncounter(role: .bolts, id: 10)
    encounter.body.position = .init(0, 0, range)
    encounter.body.energy = 100
    encounter.body.blackjackLaserCooldown = cooldown
    game.bodies = [encounter.body]
    game.ensurePhysicalActors()
  } else {
    game.bodies[0].position = .init(0, 0, range)
  }
  return game
}

extension LegacyNPCIntentTests {
  @Test(arguments: [false, true])
  func sharedActualEffectPhaseMatchesControllerAfterOnlyItsMotionIsRetained(_ blackjack: Bool)
    throws
  {
    let opening = legacyFlightEffectGame(blackjack: blackjack)
    let start = opening.bodies[0].position.length
    let emission = opening.commander.flightSimulation.nextEmission
    var whole = opening
    whole.enemyAction(index: 0, dt: 0.1)
    try #require(whole.commander.flightSimulation.nextEmission == emission + 1)
    var split = opening
    // Only the actual controller's kinematic output is used to isolate its effect phase.
    // No effect, resource, source, receipt or complete final Game is copied.
    split.bodies[0].position = whole.bodies[0].position
    let velocity = try #require(whole.bodies[0].physical?.velocity)
    split.bodies[0].physical?.velocity = velocity
    let retained = split.bodies[0]
    let ran = split.applyLegacyNPCFlightEffects(
      index: 0, delta: 0.1,
      blackjackStartingDistance: blackjack ? start : nil)
    try #require(ran)
    #expect(split.commander == whole.commander && split.bodies == whole.bodies)
    #expect(split.scriptWorldSave == whole.scriptWorldSave)
    #expect(split.energy == whole.energy && split.frontShield == whole.frontShield)
    #expect(split.rearShield == whole.rearShield && split.message == whole.message)
    #expect(
      split.bodies[0].position == retained.position
        && split.bodies[0].orientation == retained.orientation)
    #expect(split.bodies[0].physical?.velocity == retained.physical?.velocity)
    #expect(split.commander.flightSimulation.nextEmission == emission + 1)
    #expect(
      split.commander.flightSimulation.nextActor == whole.commander.flightSimulation.nextActor)
    #expect(
      split.commander.flightSimulation.nextSpawn == whole.commander.flightSimulation.nextSpawn)
    #expect(
      split.commander.credits == opening.commander.credits
        && split.commander.kills == opening.commander.kills)
    #expect(split.commander.legal == opening.commander.legal)
  }

  @Test(arguments: [false, true])
  func sharedEffectsRetainOrdinaryPostRangeAndBlackjackPreRangeAtCrossing(_ blackjack: Bool)
    throws
  {
    let opening = legacyFlightEffectGame(blackjack: blackjack, range: 1501)
    let emission = opening.commander.flightSimulation.nextEmission
    var whole = opening
    whole.enemyAction(index: 0, dt: 0.1)
    try #require(opening.bodies[0].position.length > 1500 && whole.bodies[0].position.length < 1500)
    var split = opening
    split.bodies[0].position = whole.bodies[0].position
    let velocity = try #require(whole.bodies[0].physical?.velocity)
    split.bodies[0].physical?.velocity = velocity
    let retainedPosition = split.bodies[0].position
    let ran = split.applyLegacyNPCFlightEffects(
      index: 0, delta: 0.1,
      blackjackStartingDistance: blackjack ? opening.bodies[0].position.length : nil)
    try #require(ran)
    #expect(split.commander == whole.commander && split.bodies == whole.bodies)
    #expect(split.energy == whole.energy && split.bodies[0].position == retainedPosition)
    #expect(split.commander.flightSimulation.nextEmission == emission + (blackjack ? 0 : 1))
    if blackjack {
      #expect(split.bodies[0].blackjackLaserCooldown == 0)
      #expect(split.energy == opening.energy)
    }
  }

  @Test func blackjackEffectEntryRequiresActualOpeningDistanceBeforeAnyResourceChange() {
    var game = legacyFlightEffectGame(blackjack: true)
    let before = game
    let ran = game.applyLegacyNPCFlightEffects(index: 0, delta: 0.1)
    #expect(!ran)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy && game.frontShield == before.frontShield)
    #expect(game.rearShield == before.rearShield && game.scriptWorldSave == before.scriptWorldSave)
  }

  @Test func blackjackEffectsRechargeAndCoolWithoutMovingOrPrematurelyAllocatingABeam() {
    var game = legacyFlightEffectGame(blackjack: true, cooldown: 0.2)
    let before = game
    let ran = game.applyLegacyNPCFlightEffects(
      index: 0, delta: 0.1,
      blackjackStartingDistance: before.bodies[0].position.length)
    #expect(ran)
    #expect(abs(game.bodies[0].energy - (before.bodies[0].energy + 0.4)) < 1e-10)
    #expect(abs((game.bodies[0].blackjackLaserCooldown ?? -1) - 0.1) < 1e-10)
    #expect(game.bodies[0].position == before.bodies[0].position)
    #expect(game.bodies[0].orientation == before.bodies[0].orientation)
    #expect(game.bodies[0].physical?.velocity == before.bodies[0].physical?.velocity)
    #expect(game.commander == before.commander && game.energy == before.energy)
  }
}

extension LegacyNPCIntentTests {
  @Test func attainedBlackjackEffectEntryCannotRechargeAnActorAlreadyKilledByContact() {
    var game = legacyFlightEffectGame(blackjack: true)
    game.bodies[0].energy = 0
    let before = game
    let ran = game.applyLegacyNPCFlightEffects(
      index: 0, delta: 0.1,
      blackjackStartingDistance: before.bodies[0].position.length)
    #expect(!ran)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy && game.scriptWorldSave == before.scriptWorldSave)
  }
}

extension LegacyNPCIntentTests {
  @Test func nativeLegacyFrameRetainsOnePathAndRunsOneOriginalEffectPhase() throws {
    var game = legacyIntentGame()
    let opening = game.commander.flightSimulation
    let body = game.bodies[0]
    let actor = try #require(body.physical?.identity)
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.1)
    let path = try #require(pathCandidate)
    let before = game
    let ownedPreparationRequired5 = game.prepareCurrentNewtNPCFrame(path)
    let frame = try #require(ownedPreparationRequired5)
    let entry = try #require(frame.entries[actor])
    let legacy = try #require(entry.legacy)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy)
    let middle = try #require(entry.state(at: path.startTime + 0.05))
    #expect(
      (middle.pose.position - (legacy.worldStart + legacy.worldVelocity * 0.05)).length < 1e-8)

    // Compare the actual old motion/effect owner at the same real clock and
    // selected model phase. Whole-tick player recharge is a separate phase.
    var original = before
    original.commander.flightSimulation.advancePhysicalTime(0.1)
    original.advanceBodyModelRotation(at: 0, delta: 0.1)
    original.enemyAction(index: 0, dt: 0.1)
    let interval = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame)
    let evidence = try #require(interval.evidence)
    #expect(
      evidence.verifiedFinalFlight(
        from: opening, usedD: 0.1,
        epoch: game.nativeStationRuntimeEpoch) == game.commander.flightSimulation)
    let endpoint = game.modelPose(of: game.bodies[0])
    #expect((endpoint.position - legacy.worldEnd).length < 1e-8)
    let decisionsCommitted = game.commitCurrentNewtNPCDecisions(frame, evidence: evidence)
    try #require(decisionsCommitted)
    #expect(game.modelPose(of: game.bodies[0]) == endpoint)
    #expect(game.bodies[0].position == original.bodies[0].position)
    let originalPose = original.modelPose(of: original.bodies[0])
    #expect((endpoint.orientation.x - originalPose.orientation.x).length < 1e-8)
    #expect((endpoint.orientation.y - originalPose.orientation.y).length < 1e-8)
    #expect((endpoint.orientation.z - originalPose.orientation.z).length < 1e-8)
    #expect(game.energy == original.energy && game.frontShield == original.frontShield)
    #expect(game.rearShield == original.rearShield)
    #expect(game.commander.crimeLedger == original.commander.crimeLedger)

    // A second real interval catches loss of the existing model phase. Euler
    // display rotation cannot be flattened and restarted at zero each tick.
    let secondPathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.1)
    let secondPath = try #require(secondPathCandidate)
    let ownedPreparationRequired6 = game.prepareCurrentNewtNPCFrame(secondPath)
    let secondFrame = try #require(ownedPreparationRequired6)
    original.commander.flightSimulation.advancePhysicalTime(0.1)
    original.advanceBodyModelRotation(at: 0, delta: 0.1)
    original.enemyAction(index: 0, dt: 0.1)
    let secondInterval = game.advanceCurrentNewtNativeInterval(secondPath, npcFrame: secondFrame)
    try #require(secondInterval.evidence != nil)
    let decisionsCommitted2 = game.commitCurrentNewtNPCDecisions(
      secondFrame,
      evidence: try #require(secondInterval.evidence))
    try #require(decisionsCommitted2)
    let nextPose = game.modelPose(of: game.bodies[0])
    let nextOriginal = original.modelPose(of: original.bodies[0])
    #expect((nextPose.position - nextOriginal.position).length < 1e-8)
    #expect((nextPose.orientation.x - nextOriginal.orientation.x).length < 1e-8)
    #expect((nextPose.orientation.y - nextOriginal.orientation.y).length < 1e-8)
    #expect((nextPose.orientation.z - nextOriginal.orientation.z).length < 1e-8)
    #expect(game.bodies[0].rotation == original.bodies[0].rotation)
    #expect(
      game.energy == original.energy && game.commander.crimeLedger == original.commander.crimeLedger
    )
  }

  @Test func nativeLegacyEffectRejectsAChangedRetainedIntentBeforeFiring() throws {
    var game = legacyIntentGame()
    let pathCandidate2 = game.prepareCurrentNewtOuterMotion(delta: 0.1)
    let path = try #require(pathCandidate2)
    let ownedPreparationRequired7 = game.prepareCurrentNewtNPCFrame(path)
    let frame = try #require(ownedPreparationRequired7)
    let interval = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame)
    try #require(interval.evidence != nil)
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[0].physical?.npc?.intention = .flee(player)
    let before = game
    #expect(!game.commitCurrentNewtNPCDecisions(frame, evidence: try #require(interval.evidence)))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy && game.frontShield == before.frontShield)
    #expect(game.rearShield == before.rearShield)
  }
}
