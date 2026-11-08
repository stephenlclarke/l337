import Foundation
import Testing

@testable import L337Core

struct NativeC03PassiveEvidenceUnitTests {
  @Test func actualWakeClaimsRequireZeroNumericShotCount() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let actual = try #require(game.hollowManifestMission)
    try #require(NativeC03WakeTrail.actorClaimsMatch(actual))
    for mark in NativeC03WakeGeometry.Mark.allCases {
      try #require(actual.ownedEncounters[NativeC03WakeTrail.encounter]?
        .actors[mark.rawValue]?.body.scriptNPC?.shots == 0)
      var changed = actual
      // Negative-only corruption follows a genuine source/loan/native admission.
      changed.ownedEncounters[NativeC03WakeTrail.encounter]?
        .actors[mark.rawValue]?.body.scriptNPC?.shots = 1
      #expect(!NativeC03WakeTrail.actorClaimsMatch(changed))
    }
    #expect(game.hollowManifestMission == actual)
  }

  @Test func actualArchiveClaimsRequireZeroNumericShotCount() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let actual = try #require(game.hollowManifestMission)
    try #require(NativeC03RegisterState.actorClaimsMatch(actual))
    try #require(actual.ownedEncounters[NativeC03RegisterState.encounter]?
      .actors[NativeC03CustodyRegisterContent.target]?.body.scriptNPC?.shots == 0)
    var changed = actual
    changed.ownedEncounters[NativeC03RegisterState.encounter]?
      .actors[NativeC03CustodyRegisterContent.target]?.body.scriptNPC?.shots = 1
    #expect(!NativeC03RegisterState.actorClaimsMatch(changed))
    #expect(game.hollowManifestMission == actual)
  }

  @Test func actualThreeWakeSourcesClassifyWithoutChangingMissionOrCommander() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let before = game.commander
    let trail = try #require(game.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    for mark in NativeC03WakeGeometry.Mark.allCases {
      let admission = try #require(trail.latest(mark))
      let body = try #require(game.bodies.first { $0.physical?.identity == admission.actor })
      #expect(game.c03PassiveEvidenceKind(of: body) == .wakeMark(mark))
    }
    #expect(game.commander == before)
    let station = try #require(game.bodies.first { $0.id == 0 })
    #expect(game.c03PassiveEvidenceKind(of: station) == nil)
  }

  @Test func actualArchiveClassifiesButOriginalOnagerInspectionShipsDoNot() async throws {
    let freighters = try await actualHollowManifestFreighterRootFixture(targeting: .basic)
    defer { freighters.commission.clean() }
    for body in freighters.game.bodies where body.missionInstanceID != nil {
      #expect(freighters.game.c03PassiveEvidenceKind(of: body) == nil)
    }
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let record = try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let body = try #require(game.bodies.first { $0.physical?.identity == record.latest?.actor })
    #expect(game.c03PassiveEvidenceKind(of: body) == .custodyArchive)
    #expect(record.recovery == nil)
  }

  @Test func absentStaleMismatchedNativeAndGeometryClaimsRetainExistingBehavior() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let trail = try #require(game.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    let admission = try #require(trail.latest(.first))
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == admission.actor })
    let body = game.bodies[index]
    try #require(game.c03PassiveEvidenceKind(of: body) == .wakeMark(.first))
    for failure in 0..<6 {
      var changed = game
      var supplied = body
      switch failure {
      case 0:
        let id = try #require(game.hollowManifestMission?.id)
        changed.commander.scriptState.instances.removeValue(forKey: id)
      case 1:
        supplied.id += 1000
      case 2:
        changed.bodies[index].physical = nil
        supplied = changed.bodies[index]
      case 3:
        changed.commander.scriptState.geometry.removeValue(forKey: admission.geometry)
      case 4:
        changed.bodies[index].missionActorID = UUID()
        supplied = changed.bodies[index]
      default:
        changed.commander.system = NativeHollowManifestDefinition.freighterWorld.system
      }
      #expect(changed.c03PassiveEvidenceKind(of: supplied) == nil)
    }
  }

  @Test(arguments: NativeC03WakeGeometry.Mark.allCases)
  func genuinePlayerLaserDeathDoesNotAwardShipCreditBeforeNativeRemoval(
    mark: NativeC03WakeGeometry.Mark
  ) async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    var game = try await selectActualHollowWake(runtime, mark: mark)
    let target = try #require(game.weaponsTargetID)
    let body = try #require(game.bodies.first { $0.id == target })
    try #require(game.c03PassiveEvidenceKind(of: body) == .wakeMark(mark))
    try #require(game.commander.laser(on: .front) != nil)
    let before = game.commander.kills
    let recorded = game.commander.wantedCareers.playerRecordedKills
    let emission = game.commander.flightSimulation.nextEmission
    game.fireLaser()
    let dead = try #require(game.bodies.first { $0.id == target })
    // Require the real emitter, physical hit/death and native incident. A raw zero-HP body or
    // fabricated DeathSettlement would not exercise creditCombatDeath's actual call order.
    try #require(game.commander.flightSimulation.nextEmission == emission + 1)
    try #require(dead.energy == 0 && dead.physical?.deathIncidentID != nil)
    try #require(dead.physical?.deathOrigin?.owner == game.commander.flightSimulation.player)
    #expect(game.commander.kills == before)
    #expect(game.commander.wantedCareers.playerRecordedKills == recorded)
    #expect(game.c03PassiveEvidenceKind(of: dead) == .wakeMark(mark))
    game.resolveDestroyed()
    #expect(game.commander.kills == before)
    #expect(game.commander.wantedCareers.playerRecordedKills == recorded)
    #expect(!game.bodies.contains { $0.id == target })
  }

  @Test func genuineArchiveLaserDeathDoesNotAwardEitherShipCreditTotal() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    let target = try #require(selected.weaponsTargetID)
    let body = try #require(selected.bodies.first { $0.id == target })
    try #require(selected.c03PassiveEvidenceKind(of: body) == .custodyArchive)
    let previous = selected.commander.flightSimulation.pose
    // Aim at the real archive's side skin, away from its optical component. This controlled
    // viewpoint grants no damage/death receipt; the native laser must actually destroy it.
    let normal = body.modelVector(.init(1, 0, 0))
    var pose = ShipPose(position: previous.systemPoint((body.position + body.modelVector(.init(1, 0, 0))) + normal * 100))
    pose.orientation.z = previous.orientation.apply(normal * -1)
    pose.orientation.y = previous.orientation.apply(body.modelVector(.init(0, 1, 0)))
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    let targetPose = pose
    let kills = selected.commander.kills
    let recorded = selected.commander.wantedCareers.playerRecordedKills
    let emission = selected.commander.flightSimulation.nextEmission
    await runtime.nativeCommand { game in
      NativeStationTestFixture.reframe(&game, to: targetPose)
      game.rotateScriptNPCVelocities(from: previous, to: targetPose)
      game.screen = .front
      game.speed = 0
      game.cancelAutoTarget()
      game.weaponsTargetID = target
    }
    var result = await runtime.snapshot()
    for _ in 0..<4 {
      let live = try #require(result.bodies.first { $0.id == target })
      if live.energy == 0 { break }
      let previousEmission = result.commander.flightSimulation.nextEmission
      await runtime.nativeCommand { $0.fireLaser() }
      result = await runtime.snapshot()
      let hit = try #require(result.bodies.first { $0.id == target })
      try #require(result.commander.flightSimulation.nextEmission == previousEmission + 1)
      try #require(hit.energy < live.energy)
      if hit.energy == 0 { break }
      // A pulse laser deals 15 damage; the real 16-energy archive needs a second shot.
      // Advance the genuine cadence rather than changing HP, fitting or cooldown.
      let beforeCadence = result.commander.flightSimulation.physicalTime
      for _ in 0..<4 { _ = await runtime.advance(delta: 0.1) }
      result = await runtime.snapshot()
      try #require(result.commander.flightSimulation.physicalTime >= beforeCadence + 0.3)
    }
    let dead = try #require(result.bodies.first { $0.id == target })
    try #require(result.commander.flightSimulation.nextEmission > emission)
    try #require(dead.energy == 0 && dead.physical?.deathIncidentID != nil)
    try #require(dead.physical?.deathOrigin?.owner == result.commander.flightSimulation.player)
    #expect(result.c03PassiveEvidenceKind(of: dead) == .custodyArchive)
    #expect(result.commander.kills == kills)
    #expect(result.commander.wantedCareers.playerRecordedKills == recorded)
    result.resolveDestroyed()
    #expect(!result.bodies.contains { $0.id == target })
    #expect(result.commander.kills == kills)
    #expect(result.commander.wantedCareers.playerRecordedKills == recorded)
  }

  @Test func genuineOriginalOnagerDestructionRetainsOrdinaryShipCredit() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture(targeting: .basic)
    defer { actual.commission.clean() }
    let initial = try #require(actual.game.hollowManifestMission?.savedHollowManifest)
    let admission = try #require(initial.admissions.first { $0.reference.slot == .first })
    let runtime = GameRuntime(game: actual.game, saveURL: actual.commission.files.save)
    let kills = actual.game.commander.kills
    let recorded = actual.game.commander.wantedCareers.playerRecordedKills
    var actualDeath: ActorIdentity?
    for _ in 0..<128 {
      let scene = await runtime.snapshot()
      let body = try #require(scene.bodies.first { $0.missionActorID == admission.logicalActor })
      if body.energy == 0 { break }
      try #require(scene.c03PassiveEvidenceKind(of: body) == nil)
      let previous = scene.commander.flightSimulation.pose
      // Controlled viewpoint at unchanged skin outside the original seal. Damage, weapon
      // cadence, native emission/death and ship-credit accounting remain real producers.
      let point = (body.position + body.modelVector(.init(6.5, 1.5, 0)))
      let normal = body.modelVector(.init(1, 0, 0))
      var pose = ShipPose(position: previous.systemPoint(point + normal * 300))
      pose.orientation.z = previous.orientation.apply(normal * -1)
      pose.orientation.y = previous.orientation.apply(body.modelVector(.init(0, 1, 0)))
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      let targetPose = pose
      await runtime.nativeCommand { game in
        NativeStationTestFixture.reframe(&game, to: targetPose)
        game.rotateScriptNPCVelocities(from: previous, to: targetPose)
        game.screen = .front
        game.speed = 0
        game.cancelAutoTarget()
        game.weaponsTargetID = body.id
        game.fireLaser()
      }
      let fired = await runtime.snapshot()
      if let dead = fired.bodies.first(where: { $0.missionActorID == admission.logicalActor }),
        dead.energy == 0 {
        try #require(dead.physical?.deathIncidentID != nil)
        try #require(dead.physical?.deathOrigin?.owner == fired.commander.flightSimulation.player)
        actualDeath = dead.physical?.identity
        break
      }
      _ = await runtime.advance(delta: 0.1)
    }
    let result = await runtime.snapshot()
    try #require(actualDeath == admission.original.actor)
    #expect(result.commander.kills == ((kills &+ 1) & 0xffff))
    #expect(result.commander.wantedCareers.playerRecordedKills == recorded + 1)
  }
}
