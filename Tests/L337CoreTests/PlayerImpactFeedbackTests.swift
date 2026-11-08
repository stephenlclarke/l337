import Foundation
import Testing

@testable import L337Core

struct PlayerImpactFeedbackTests {
  private var directory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/readme-capture")
  }

  private func scene() async throws -> Game {
    try await ReadmeMedia.dockingUnderAttackScene(sourceDirectory: directory)
  }

  private func contact(_ game: borrowing Game) throws
    -> (body: SpaceBody, muzzle: Vector3, hit: GameplayHit)
  {
    let body = try #require(game.bodies.first { $0.scriptNPC != nil })
    let npc = try #require(body.scriptNPC)
    let weapon = try #require(npc.fit.definition.lasers?.first)
    let gun = try #require(npc.guns[weapon.id])
    let muzzle = body.position + body.orientation.apply(weapon.muzzle)
    let direction = body.orientation.apply(gun.aim ?? weapon.direction).unit
    let actual = try game.nearestMissionCollision(
      from: muzzle, direction: direction, range: weapon.range, radius: 0,
      excludingBodyIDs: [body.id], includePlayer: true)
    let collision = try #require(actual)
    try #require(collision.hit.target == .player)
    return (body, muzzle, collision.hit)
  }

  @Test func missionHitFeedbackIsMintedByActualDamageAndAppearsInTheNormalFrame() async throws {
    let game = try await scene()
    let feedback = try #require(game.visiblePlayerImpactFeedback)
    #expect(feedback.player == game.commander.flightSimulation.player)
    #expect(feedback.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(feedback.event > 0 && feedback.event < game.commander.flightSimulation.nextIncident)
    #expect(game.frontShield < game.commander.shieldCapacity && feedback.shielded)
    let frame = Display.presentation(game, width: 1024, height: 768)
    #expect(frame.labels.contains { $0.text == "FORE SHIELD HIT" })
    #expect(game.laserFlash == 0)
  }

  @Test func acceptedCommonHitUpdatesTheSameFeedbackWithoutChangingDamageSemantics() async throws {
    var game = try await scene()
    let shot = try contact(game)
    let owner = try #require(shot.body.physical?.identity)
    let attackOrigin = game.makeAttackOrigin(owner: owner)
    let origin = try #require(attackOrigin)
    let previous = try #require(game.visiblePlayerImpactFeedback)
    let shield = game.frontShield
    let energy = game.energy
    let recordedHit = game.applyCombatHit(
      shot.hit, origin: origin, kind: .laser, damage: 3,
      emissionPosition: game.commander.flightSimulation.pose.systemPoint(shot.muzzle))
    let incident = try #require(recordedHit)
    #expect(game.frontShield == max(0, shield - 3))
    #expect(game.energy == energy - max(0, 3 - shield))
    let feedback = try #require(game.visiblePlayerImpactFeedback)
    #expect(feedback.event == incident.id && feedback.event > previous.event)
    #expect(feedback.contact == shot.hit.point)
  }

  @Test func zeroAndNonfiniteDamageNeverCreateNewFeedbackOrChangeThePreviousHit() async throws {
    for damage in [0.0, -1, .nan, .infinity] {
      var game = try await scene()
      let shot = try contact(game)
      let owner = try #require(shot.body.physical?.identity)
      let attackOrigin = game.makeAttackOrigin(owner: owner)
      let origin = try #require(attackOrigin)
      let previous = game.playerImpactFeedback
      let shields = [game.frontShield, game.rearShield, game.energy]
      _ = game.applyCombatHit(shot.hit, origin: origin, kind: .laser, damage: damage)
      #expect(game.playerImpactFeedback == previous)
      #expect([game.frontShield, game.rearShield, game.energy] == shields)
    }
  }

  @Test func realCooldownRefusalCannotRenewTheHitOrSpendAnotherShot() async throws {
    var game = try await scene()
    let shot = try contact(game)
    let before = try #require(game.bodies.first { $0.id == shot.body.id })
    let feedback = game.playerImpactFeedback
    let emission = game.commander.flightSimulation.nextEmission
    let result = try game.fireMissionNativeLaser(
      bodyID: before.id, weaponID: "forward", componentID: nil)
    #expect(result == nil)
    #expect(game.playerImpactFeedback == feedback)
    #expect(game.commander.flightSimulation.nextEmission == emission)
    #expect(game.bodies.first { $0.id == before.id }?.scriptNPC == before.scriptNPC)
  }

  @Test func realMissAndEnvironmentalDamageDoNotMasqueradeAsIncomingHits() async throws {
    var game = try await scene()
    let shot = try contact(game)
    var missedDirection: Vector3?
    for direction in [Vector3(0, 1, 0), .init(0, -1, 0), .init(1, 0, 0), .init(-1, 0, 0)] {
      if try game.nearestMissionCollision(
        from: shot.muzzle, direction: direction, range: 6000, radius: 0,
        excludingBodyIDs: [shot.body.id], includePlayer: true) == nil
      {
        missedDirection = direction
        break
      }
    }
    let direction = try #require(missedDirection)
    let owner = try #require(shot.body.physical?.identity)
    let attackOrigin = game.makeAttackOrigin(owner: owner)
    let origin = try #require(attackOrigin)
    let previous = game.playerImpactFeedback
    let miss = game.recordCombat(
      origin: origin, kind: .laser, outcome: .discharge, target: nil,
      worldPosition: game.commander.flightSimulation.pose.systemPoint(
        shot.muzzle + direction * 6000))
    #expect(miss != nil && game.playerImpactFeedback == previous)
    let shield = game.frontShield
    game.applyDamage(2, front: true)
    #expect(game.frontShield == max(0, shield - 2))
    #expect(game.playerImpactFeedback == previous)
  }

  @Test func physicalExpiryAndSnapshotsKeepIndependentValuesWhilePauseDoesNotAgeAHit() async throws
  {
    let original = try await scene()
    var expired = original
    expired.commander.flightSimulation.advancePhysicalTime(PlayerImpactFeedback.duration)
    #expect(expired.visiblePlayerImpactFeedback == nil)
    #expect(original.visiblePlayerImpactFeedback != nil)
    var paused = original
    paused.paused = true
    let before = paused.commander.flightSimulation.physicalTime
    paused.tick(delta: 0.1)
    #expect(paused.commander.flightSimulation.physicalTime == before)
    #expect(paused.visiblePlayerImpactFeedback == original.visiblePlayerImpactFeedback)
    paused.commander.flightSimulation.enter(paused.systemIdentity, arriving: false)
    #expect(paused.visiblePlayerImpactFeedback == nil)
  }

  @Test func foreignRuntimeCannotDisplayAnOldCapturedFeedbackValue() async throws {
    let original = try await scene()
    let old = try #require(original.visiblePlayerImpactFeedback)
    let runtime = GameRuntime()
    try await runtime.startNewCommander()
    var fresh = await runtime.snapshot()
    fresh.launch()
    fresh.screen = .front
    fresh.playerImpactFeedback = old
    #expect(fresh.visiblePlayerImpactFeedback == nil)
  }

  @Test func acceptedGlowStaysInsideNativeFlightClipsAtCompactAndWideSizes() async throws {
    let captured = try await scene()
    for (width, height) in [(512.0, 518.0), (768, 768), (1512, 982), (3584, 2160)] {
      for screen in [Screen.front, .rear] {
        var game = captured
        game.screen = screen
        let layout = CockpitLayout(game: game, width: width, height: height)
        var feedback = Frame()
        feedback.canvas = .init(x: 0, y: 0, width: width, height: height)
        feedback.flightClip = layout.flightClip
        feedback.rasterizeGraphics = false
        Display.drawPlayerImpactFeedback(game, into: &feedback)
        #expect(feedback.graphics.count == 3 && feedback.labels.count == 1)
        for graphic in feedback.graphics {
          guard case .point(let center, let radius, let opacity, _) = graphic else {
            Issue.record("An impact HUD indicator must not invent a beam or ship panel")
            continue
          }
          #expect(center.x - radius >= layout.flightClip.x - 1e-9)
          #expect(center.x + radius <= layout.flightClip.maxX + 1e-9)
          #expect(center.y - radius >= layout.flightClip.y - 1e-9)
          #expect(center.y + radius <= layout.flightClip.maxY + 1e-9)
          #expect(opacity > 0 && opacity <= 1)
        }
        let actual = Display.presentation(game, width: width, height: height)
        #expect(actual.labels.contains { $0.text == "FORE SHIELD HIT" })
      }
    }
  }

  @Test func freshCurrentSaveLoadDoesNotPersistOrReplayAHitIndicator() async throws {
    let game = try await scene()
    try #require(game.visiblePlayerImpactFeedback != nil)
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let runtime = GameRuntime(game: game)
    let url = temporary.appendingPathComponent("commander.json")
    try await runtime.save(to: url)
    try await runtime.load(from: url)
    let loaded = await runtime.snapshot()
    #expect(loaded.playerImpactFeedback == nil)
    #expect(loaded.commander.shipID == game.commander.shipID)
    #expect(loaded.commander.name == game.commander.name)
  }
}
