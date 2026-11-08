import Foundation
import Testing

@testable import L337Core

struct CurrentNewtNativeQuerySceneTests {
  @Test func actualMissileOpeningAndKitUseOneQualifiedReadOnlyScene() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let targetCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate)
    let missileLaunched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(missileLaunched)
    let missileCandidate = game.bodies.first { $0.physical?.ordnance != nil }
    let missile = try #require(missileCandidate)
    let actor = try #require(missile.physical?.identity)
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate)
    let ownedPreparationRequired1 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired1)
    let entryCandidate = frame.entries.first { $0.actor == actor }
    let entry = try #require(entryCandidate)
    let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
    let openingCandidate = game.beginCurrentNewtNativeSegment(
      interval,
      playerMotion: path.motion, playerEnd: try #require(path.state(at: path.endTime)))
    let opening = try #require(openingCandidate)
    let ownedPreparationRequired2 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired2)
    let before = game
    // The unchanged default solid route cannot silently drop an active missile.
    #expect(game.prepareCurrentNewtNativeContact(opening: opening, mechanics: mechanics) == nil)
    let ownedPreparationRequired3 = game.prepareCurrentNewtNativeQueryScene(
        opening: opening, mechanics: mechanics, ordnanceFrame: frame)
    let scene = try #require(ownedPreparationRequired3)
    let colliderCandidate = scene.colliders.first { $0.actor == actor }
    let collider = try #require(colliderCandidate)
    #expect(collider.component == "ordnance")
    let native = game.gameplayMesh(for: missile)
    #expect(collider.mesh.vertices == native.vertices && collider.mesh.faces == native.faces)
    for elapsed in [0.0, 0.025, 0.05] {
      let actual = try #require(collider.poseAt(elapsed))
      let expected = try #require(entry.state(at: interval.start + elapsed))
      #expect((actual.position - expected.position).length < 1e-7)
    }
    let containsMatch = scene.colliders.contains { $0.actor == target.physical?.identity && $0.newt }
    #expect(containsMatch)
    let bound = try #require(collider.pointSpeedRelativeTo(entry.state.velocity))
    #expect(bound.isFinite && bound >= 0)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy && game.nextBodyID == before.nextBodyID)
  }

  @Test func staleActualProjectileOriginCannotSupplyAQueryTarget() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let targetCandidate2 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate2)
    let missileLaunched2 = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(missileLaunched2)
    let pathCandidate2 = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate2)
    let ownedPreparationRequired4 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired4)
    let indexCandidate = game.bodies.firstIndex { $0.physical?.ordnance != nil }
    let index = try #require(indexCandidate)
    game.bodies[index].physical?.attackOrigin = nil  // Negative source corruption only.
    let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
    let openingCandidate2 = game.beginCurrentNewtNativeSegment(
      interval,
      playerMotion: path.motion, playerEnd: try #require(path.state(at: path.endTime)))
    let opening = try #require(openingCandidate2)
    let ownedPreparationRequired5 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired5)
    let before = game
    #expect(
      game.prepareCurrentNewtNativeQueryScene(
        opening: opening, mechanics: mechanics,
        ordnanceFrame: frame) == nil)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
  }
}
