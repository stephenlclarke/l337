import Foundation
import Testing

@testable import L337Core

/// Real commissioned originals and the actual native preparation/retention/clock owners.
/// Calling an interval directly is not a normal Game tick or mission-frame acceptance.
private func prepareActualC03NativeInterval(_ game: inout Game) throws
  -> (path: CurrentNewtOuterMotion, frame: CurrentNewtNPCFrame)
{
  game.beginC03AttainedMotionStep()
  try #require(game.nativeC03MotionPending != nil)
  let steering = game.prepareC03FreighterRoutePass(delta: 0.1)
  try #require(steering.refusedBodyIDs.isEmpty && !steering.recognizedBodyIDs.isEmpty)
  let path = try #require(game.prepareCurrentNewtOuterMotion(delta: 0.1))
  let frame = try #require(game.prepareCurrentNewtNPCFrame(path))
  return (path, frame)
}

struct NativeC03NewtAppliedMotionUnitTests {
  @Test func preparationDoesNotCreateAnAppliedNativeCaptureOrMissionFrame() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    let prepared = try prepareActualC03NativeInterval(&game)
    let before = game.commander
    let bodies = game.bodies
    let ordnance = try #require(game.prepareGameplayOrdnanceFrame(until: prepared.path.endTime))
    var budget = CurrentNewtNativeQueryBudget()
    let step = try #require(game.prepareCurrentNewtNativeStep(original: prepared.path,
      trajectory: prepared.path, npcFrame: prepared.frame, ordnanceFrame: ordnance, budget: &budget))
    _ = try #require(step.physics)
    #expect(game.c03NativeAppliedSegments.isEmpty)
    #expect(game.commander == before && game.bodies == bodies)
    game.finishC03AttainedMotionStep()
    guard case .refused(.missingPhase)? = game.nativeC03AttainedMotion else {
      Issue.record("A predicted scene must not become an applied motion phase")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func actualNativeRetentionAndClockBindChronologyWithoutInventingTheOuterFrame() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    let prepared = try prepareActualC03NativeInterval(&game)
    let openingFrame = game.gameplayRevision
    let result = game.advanceCurrentNewtNativeInterval(prepared.path, npcFrame: prepared.frame)
    let evidence = try #require(result.evidence)
    try #require(result.fullMotionAttained && evidence.completedOuterInterval)
    let segments = game.c03NativeAppliedSegments
    try #require(!segments.isEmpty)
    #expect(game.c03NativeAppliedChainMatches(evidence))
    var cursor = prepared.path.startTime
    for segment in segments {
      #expect(segment.opening.interval.start == cursor)
      #expect(segment.opening.interval.end > cursor)
      #expect(segment.beforeBodies == segment.opening.before.bodies)
      #expect(segment.afterFlight.physicalTime == segment.opening.interval.end)
      cursor = segment.opening.interval.end
      let opaque: Any = segment
      #expect(!(opaque is any Encodable))
    }
    #expect(cursor == prepared.path.endTime)
    #expect(game.gameplayRevision == openingFrame)
    let before = game.commander
    let bodies = game.bodies
    // No counter is manually incremented. Real native time is insufficient to forge the
    // missing Game-owned outer frame, even though every actual segment matches its clock.
    game.finishC03AttainedMotionStep(native: evidence)
    guard case .refused(.changedEffect)? = game.nativeC03AttainedMotion else {
      Issue.record("An interval without its actual outer Game frame must stay refused")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.hollowManifestMission?.milestones == [0])
  }

  @Test func acceptedSegmentsCannotBeOmittedReplayedOrJoinedToAnotherRealClock() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    var other = actual.game
    let first = try prepareActualC03NativeInterval(&game)
    let second = try prepareActualC03NativeInterval(&other)
    let result = game.advanceCurrentNewtNativeInterval(first.path, npcFrame: first.frame)
    let alternate = other.advanceCurrentNewtNativeInterval(second.path, npcFrame: second.frame)
    let clock = try #require(result.evidence)
    let otherClock = try #require(alternate.evidence)
    try #require(result.fullMotionAttained && alternate.fullMotionAttained)
    let segments = game.c03NativeAppliedSegments
    let start = try #require(segments.first)
    try #require(game.c03NativeAppliedChainMatches(clock))
    #expect(!game.c03NativeAppliedChainMatches(otherClock))
    #expect(!clock.validatesC03AppliedSegments([], opening: first.frame.opening,
      bodies: start.beforeBodies, current: game))
    #expect(!clock.validatesC03AppliedSegments(segments + segments, opening: first.frame.opening,
      bodies: start.beforeBodies, current: game))
    #expect(!clock.validatesC03AppliedSegments(other.c03NativeAppliedSegments,
      opening: first.frame.opening, bodies: start.beforeBodies, current: game))
    let before = game.commander
    let bodies = game.bodies
    game.finishC03AttainedMotionStep(native: otherClock)
    guard case .refused(.missingPhase)? = game.nativeC03AttainedMotion else {
      Issue.record("Another genuine clock with matching numeric endpoints is not this capture's clock")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func realNativeMutationWithoutAcceptedClockCannotFallBackToLegacyEvidence() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    let prepared = try prepareActualC03NativeInterval(&game)
    let result = game.advanceCurrentNewtNativeInterval(prepared.path, npcFrame: prepared.frame)
    try #require(result.fullMotionAttained && result.evidence != nil)
    try #require(!game.c03NativeAppliedSegments.isEmpty)
    let before = game.commander
    let bodies = game.bodies
    game.finishC03AttainedMotionStep()
    guard case .refused(.missingPhase)? = game.nativeC03AttainedMotion else {
      Issue.record("Applied native data alone must not fall back to a legacy powered witness")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func anUninstalledSourceRouteRefusesNativePlanningBeforeMotionOrArrival() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    let prepared = try prepareActualC03NativeInterval(&game)
    let index = try #require(game.bodies.firstIndex { $0.scriptNPC != nil && $0.id != 0 })
    let intent = try #require(game.bodies[index].scriptNPC?.intent)
    // Invalidated caller input only, never a new source, arrival or applied-path witness.
    var altered = ScriptNPCIntent(request: intent.request, mode: intent.mode, target: intent.target,
      player: intent.player, offset: intent.offset + Vector3(1, 0, 0),
      speed: intent.speed, tolerance: intent.tolerance)
    altered.status = intent.status
    game.bodies[index].scriptNPC?.intent = altered
    let before = game.commander
    let bodies = game.bodies
    #expect(!game.c03NativeRouteIntentIsCurrent(game.bodies[index], delta: prepared.path.motion.duration))
    #expect(game.prepareCurrentNewtNPCFrame(prepared.path) == nil)
    #expect(game.c03NativeAppliedSegments.isEmpty)
    #expect(game.commander == before && game.bodies == bodies)
  }
}
