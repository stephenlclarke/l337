import Foundation
import Testing

@testable import L337Core

struct CurrentNewtOuterMotionTests {
  @Test func manualSubrangesKeepTheSingleOriginalControlEndpointAndClock() throws {
    var game = Game(executive: false)
    game.docked = false
    game.screen = .front
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.speed = 3
    game.pitch = 0.7
    game.roll = -0.4
    game.yaw = 0.3
    game.autoPilot.setApproachVelocity(.init(2, -1, 4))
    let before = game.commander.flightSimulation
    var pilot = game.autoPilot
    pilot.rotateVelocity(pitch: game.pitch * 0.1, roll: game.roll * 0.1, yaw: game.yaw * 0.1)
    var originalEnd = before.pose
    originalEnd.advanceView(
      pitch: game.pitch * 0.1, roll: game.roll * 0.1, yaw: game.yaw * 0.1,
      translation: pilot.velocity * 0.1 + Vector3(0, 0, 3 * 0.1 * 18))
    let motionCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.1)
    let motion = try #require(motionCandidate)
    #expect(game.commander.flightSimulation == before)
    #expect(motion.motion.end == originalEnd)
    #expect(motion.rootMotion === motion)
    try checkSubranges(motion)
    #expect(game.commander.flightSimulation == before)
  }

  private func checkSubranges(_ motion: CurrentNewtOuterMotion) throws {
    let cuts = [motion.startTime, motion.startTime + 0.02, motion.startTime + 0.07, motion.endTime]
    for index in 1..<cuts.count {
      let interval = CurrentNewtMechanicalInterval(start: cuts[index - 1], end: cuts[index])
      let part = try #require(motion.subrange(interval))
      let endpoint = HullSweepSafety.shipPose(part, at: interval.end - interval.start)
      let expected = try #require(motion.state(at: interval.end))
      #expect((endpoint.position - expected.pose.position).length < 1e-10)
      #expect((endpoint.orientation.x - expected.pose.orientation.x).length < 1e-10)
      #expect((endpoint.orientation.y - expected.pose.orientation.y).length < 1e-10)
      #expect((endpoint.orientation.z - expected.pose.orientation.z).length < 1e-10)
    }
    #expect(motion.state(at: motion.startTime - 0.01) == nil)
    #expect(motion.state(at: motion.endTime + 0.01) == nil)
    #expect(motion.subrange(.init(start: motion.startTime, end: motion.startTime)) == nil)
  }
}
