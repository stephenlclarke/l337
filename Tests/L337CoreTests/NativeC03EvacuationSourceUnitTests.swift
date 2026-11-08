import Foundation
import Testing

@testable import L337Core

/// All preceding mission/kit/data producers are genuine. The return scene is controlled,
/// not earned travel. No crew source, person, native admission or accepted receipt is injected.
private func actualHollowEvacuationContextGame() async throws -> (
  game: Game, commission: HollowManifestCommissionFixture
) {
  let (runtime, commission) = try await actualHollowRegisterRuntime()
  do {
    let selected = try await selectActualHollowRegister(runtime)
    await runtime.missionUICommand(.init(action: .originalRegisterRecovery,
      game: selected, presentation: selected.scriptPagePresentation))
    var game = await runtime.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    _ = try game.hollowManifestHeldRegisterData()
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    let world = NativeHollowManifestDefinition.carrierWorld
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.speed = 0
    game.screen = .front
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    return (game, commission)
  } catch {
    commission.clean()
    throw error
  }
}

struct NativeC03EvacuationSourceUnitTests {
  @Test func realCaseAndOriginalKitDataProposeButDoNotIssueAnyPeopleOrNativeActors() async throws {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    let game = actual.game
    let commander = game.commander
    let bodies = game.bodies
    let nextBody = game.nextBodyID
    // Keep this positive physical-source assertion. Current Saiga1720>512, loaded inertia
    // and unapproved fit are real qualification blockers, never replaced by a fake hull.
    let context = try #require(try game.hollowManifestEvacuationAdmissionContext())
    #expect(context.initial && context.originalSource == nil)
    #expect(context.accommodation.assignments.count == 6)
    #expect(context.retention.actors.count == 2 && !context.retention.admitted)
    #expect(context.retention.actors.values.allSatisfy {
      $0.presence == .prepared && $0.body.physical == nil
    })
    let data = try game.hollowManifestHeldRegisterData()
    #expect(context.heldRegister?.kit == data.kit && context.heldRegister?.transfer == data.transfer)
    #expect(game.acceptsHollowManifestEvacuationAdmissionContext(context))
    #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == nextBody)
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }

  @Test func staleClockGeometryOrPausedFirstSourceCannotReuseActualContext() async throws {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    let game = actual.game
    let context = try #require(try game.hollowManifestEvacuationAdmissionContext())
    try #require(game.acceptsHollowManifestEvacuationAdmissionContext(context))
    var changed = game
    changed.commander.flightSimulation.physicalTime += 0.1
    #expect(!changed.acceptsHollowManifestEvacuationAdmissionContext(context))
    changed = game
    changed.paused = true
    #expect(!changed.acceptsHollowManifestEvacuationAdmissionContext(context))
    changed = game
    let geometry = try #require(context.previousGeometry.keys.sorted().first)
    changed.commander.scriptState.geometry.removeValue(forKey: geometry)
    #expect(!changed.acceptsHollowManifestEvacuationAdmissionContext(context))
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}
