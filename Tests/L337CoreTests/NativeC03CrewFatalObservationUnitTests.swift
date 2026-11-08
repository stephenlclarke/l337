import Foundation
import Testing

@testable import L337Core

/// No admitted original source or actual fatal hit is fabricated. Positive native death,
/// cull/retry and writer journeys require G1's real, qualified source admission first.
struct NativeC03CrewFatalObservationUnitTests {
  @Test func actualFreshGameCannotCreateCrewOrWitnessThroughObservationOrCapture() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let commander = game.commander
    let bodies = game.bodies
    let epoch = game.nativeStationRuntimeEpoch
    #expect(game.c03CrewFatalBeforeObservation() == nil)
    game.beginC03CrewFatalObservation()
    game.retainC03CrewFatalObservation()
    try game.captureC03EvacuationActors()
    try game.captureC03EvacuationActors(unloading: true)
    game.endC03CrewFatalObservation()
    game.acknowledgeC03CrewDeathPersistence()
    #expect(game.c03CrewRuntime.before == nil && game.c03CrewRuntime.pendingDeath == nil)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.nativeStationRuntimeEpoch == epoch)
    #expect(game.c03EvacuationRecognizedBodyIDs().isEmpty)
  }

  @Test func detachedDeadBodyCannotBecomeAnObservedRemovalOrNativeLoss() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let commander = game.commander
    let bodies = game.bodies
    // Negative-only caller data: this body was never admitted or damaged by the native core.
    var absent = SpaceBody(id: Int.max, hull: .cobra, position: .init(0, 0, 0))
    absent.energy = 0
    #expect(throws: SaveError.invalidCommander) {
      try game.recordC03EvacuationRemoval(absent, destroyed: true)
    }
    #expect(!game.isC03EvacuationBody(absent))
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.c03CrewRuntime.before == nil && game.c03CrewRuntime.pendingDeath == nil)
  }

  @Test func captureEventBoundsPreserveTheExistingEmitterLimitsWithoutOverflow() {
    let limit = UInt64(Int64.max) - 1
    #expect(NativeC03CrewCaptureEventCapacity.permits(next: limit, pending: 4096, demand: 0))
    #expect(NativeC03CrewCaptureEventCapacity.permits(next: limit - 2, pending: 4094, demand: 2))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: limit - 1, pending: 4094, demand: 2))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: 1, pending: 4095, demand: 2))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: UInt64.max, pending: 0, demand: 0))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: 1, pending: Int.max, demand: 1))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: 1, pending: -1, demand: 0))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: 1, pending: 0, demand: -1))
    #expect(!NativeC03CrewCaptureEventCapacity.permits(next: 1, pending: 0, demand: Int.max))
  }
}
