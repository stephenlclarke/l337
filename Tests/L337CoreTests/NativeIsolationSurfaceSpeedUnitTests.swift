import Testing

@testable import L337Core

struct NativeIsolationSurfaceSpeedUnitTests {
  @Test func stationaryCentresDoNotMakeAFastRotatingWorkSurfaceSafe() throws {
    let speed = try #require(NativeIsolationWorkEnvelope.surfaceSpeed(
      playerVelocity: .init(0, 0, 0), targetVelocity: .init(0, 0, 0),
      targetAngularVelocity: .init(0, 1, 0), worldSurfaceOffset: .init(3, 0, 0)))
    #expect(speed == 3)
    #expect(!NativeIsolationWorkEnvelope.qualifies(range: 100, speed: speed, aim: 0))
  }

  @Test func matchingTranslationAndAPointOnTheSpinAxisHaveNoRelativeSurfaceMotion() throws {
    let speed = try #require(NativeIsolationWorkEnvelope.surfaceSpeed(
      playerVelocity: .init(0, 0, 2), targetVelocity: .init(0, 0, 2),
      targetAngularVelocity: .init(0, 1, 0), worldSurfaceOffset: .init(0, 3, 0)))
    #expect(speed == 0)
    #expect(NativeIsolationWorkEnvelope.qualifies(range: 100, speed: speed, aim: 0))
  }

  @Test func nonfiniteSurfaceMotionCannotBecomeAWorkReading() {
    #expect(NativeIsolationWorkEnvelope.surfaceSpeed(
      playerVelocity: .init(0, 0, 0), targetVelocity: .init(0, 0, 0),
      targetAngularVelocity: .init(0, .infinity, 0), worldSurfaceOffset: .init(3, 0, 0)) == nil)
  }
}
