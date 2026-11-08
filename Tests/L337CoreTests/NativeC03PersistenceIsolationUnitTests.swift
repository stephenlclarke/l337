import Foundation
import Testing

@testable import L337Core

struct NativeC03PersistenceIsolationUnitTests {
  @Test func originalDeathGuardDoesNotCaptureAnUnrelatedLiveMissionEarlier() throws {
    var (game, instanceID, index) = try actualMissionBridgeGame()
    let before = try #require(game.commander.scriptState.instances[instanceID])
    try #require(game.currentMissionActorDescriptor(bodyID: game.bodies[index].id) != nil)
    try #require(game.hollowManifestMission == nil && game.bodies.allSatisfy { $0.energy > 0 })
    // Controlled pose change makes an unintended generic capture observable. It is not a
    // native motion proof or mission progress. The generic admission above is genuine.
    game.bodies[index].position.x += 123
    let observed = game.bodies[index]
    game.resolveDestroyed()
    #expect(game.commander.scriptState.instances[instanceID] == before)
    #expect(game.bodies.contains(observed))
    // The original explicit full-persistence site must still capture that same generic actor.
    _ = game.persistScriptActors()
    let captured = try #require(game.commander.scriptState.instances[instanceID])
    #expect(captured != before)
    #expect(captured.ownedEncounters["opponents"]?.actors["lead"]?.identity
      == before.ownedEncounters["opponents"]?.actors["lead"]?.identity)
  }
}
