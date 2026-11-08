import Foundation
import Testing

@testable import L337Core

struct CurrentNewtOrdnanceCurveQueryTests {
  @Test func actualSceneAndLaunchedPointSupplyOneReadonlyMovingFirstHit() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let targetCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate)
    let model = game.modelPose(of: target)
    let aim = Game.nativePlayerSurfaceAim(from: .init(0, 0, -1000), mesh: game.gameplayMesh(for: target))
    var observer = model
    observer.position = model.systemPoint(aim) - model.orientation.z * 60
    NativePagedSalvageFixture.moveObserver(&game, to: observer)
    let launched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
    let missileCandidate = game.bodies.first { $0.physical?.ordnance != nil }
    let missile = try #require(missileCandidate)
    let actor = try #require(missile.physical?.identity)
    let preparedPath = game.prepareCurrentNewtOuterMotion(delta: 0.1)
    let path = try #require(preparedPath)
    let ownedPreparationRequired1 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired1)
    let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
    let openingCandidate = game.beginCurrentNewtNativeSegment(interval,
      playerMotion: path.motion, playerEnd: try #require(path.state(at: path.endTime)))
    let opening = try #require(openingCandidate)
    let ownedPreparationRequired2 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired2)
    let ownedPreparationRequired3 = game.prepareCurrentNewtNativeQueryScene(
      opening: opening, mechanics: mechanics, ordnanceFrame: frame)
    let scene = try #require(ownedPreparationRequired3)
    let before = game
    let query = game.firstCurrentNewtOrdnanceContact(in: scene, actor: actor)
    guard case .contact(let contact, let cost) = query else {
      Issue.record("Actual moving target did not supply a qualified native first hit"); return
    }
    let expectedOpeningCandidate = frame.entries.first { $0.actor == actor }
    let expectedOpening = try #require(expectedOpeningCandidate)
    #expect(contact.scene === scene && contact.opening === expectedOpening)
    #expect(cost.candidatePairs > 0 && cost.distanceQueries > 0)
    #expect(contact.target.actor == target.physical?.identity && contact.native.matches(contact.target.hull))
    #expect(contact.lowerPhysicalTime >= interval.start && contact.upperPhysicalTime <= interval.end)
    #expect(contact.native.radius == 0)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.scriptWorldSave == before.scriptWorldSave && game.nextBodyID == before.nextBodyID)
    #expect(game.energy == before.energy)
  }

  @Test func changedActualSourceCannotSpendAnEarlierQualifiedScene() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let targetCandidate2 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate2)
    let launched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
    let indexCandidate = game.bodies.firstIndex { $0.physical?.ordnance != nil }
    let index = try #require(indexCandidate)
    let actor = try #require(game.bodies[index].physical?.identity)
    let preparedPath = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(preparedPath)
    let ownedPreparationRequired4 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired4)
    let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
    let openingCandidate2 = game.beginCurrentNewtNativeSegment(interval,
      playerMotion: path.motion, playerEnd: try #require(path.state(at: path.endTime)))
    let opening = try #require(openingCandidate2)
    let ownedPreparationRequired5 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired5)
    let ownedPreparationRequired6 = game.prepareCurrentNewtNativeQueryScene(
      opening: opening, mechanics: mechanics, ordnanceFrame: frame)
    let scene = try #require(ownedPreparationRequired6)
    game.bodies[index].physical?.attackOrigin = nil
    let before = game
    guard case .refused = game.firstCurrentNewtOrdnanceContact(in: scene, actor: actor) else {
      Issue.record("Changed real source reused a stale native scene"); return
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.scriptWorldSave == before.scriptWorldSave)
  }
}
