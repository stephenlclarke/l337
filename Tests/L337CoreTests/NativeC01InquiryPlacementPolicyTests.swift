import Testing

@testable import L337Core

struct NativeC01InquiryPlacementPolicyTests {
  @Test func nonfiniteOrNonpositiveEnvelopeRefusesWithoutStateChanges() throws {
    let game = nativePolicyScene()
    let context = try #require(game.gameplayContext())
    let radii: [Double] = [0, -1, .nan, .infinity]
    for radius in radii {
      expectReadOnlyRefusal(game, context: context, center: .init(0, 0, 0),
        radius: radius, expected: .staleContext)
    }
    for center in [Vector3(.nan, 0, 0), .init(0, .infinity, 0)] {
      expectReadOnlyRefusal(game, context: context, center: center, radius: 1,
        expected: .staleContext)
    }
  }

  @Test func changedRevisionRefusesTheOldActualContextWithoutRewindingIt() throws {
    var game = nativePolicyScene()
    let context = try #require(game.gameplayContext())
    game.gameplayRevision += 1
    expectReadOnlyRefusal(game, context: context, center: .init(50_000, 0, 0),
      radius: 1, expected: .staleContext)
    #expect(game.gameplayRevision != context.revision)
  }

  @Test func duplicatedAttainedBodyRefusesThePriorSceneWithoutAllocation() throws {
    var game = nativePolicyScene()
    let context = try #require(game.gameplayContext())
    let existing = try #require(game.bodies.first)
    game.bodies.append(existing)
    expectReadOnlyRefusal(game, context: context, center: .init(50_000, 0, 0),
      radius: 1, expected: .staleContext)
    #expect(game.bodies.filter { $0.id == existing.id }.count == 2)
  }

  @Test func actualPlanetAndSunOverlapUseNativeRefusalWithoutAllocation() throws {
    let game = nativePolicyScene()
    let context = try #require(game.gameplayContext())
    // Genuine projected current scene, not a caller-built accepted context.
    try #require(Set(game.bodies.compactMap { $0.physical?.identity }).count == game.bodies.count)
    try #require(Set(context.actors.map(\.identity)) == Set(game.bodies.compactMap { $0.physical?.identity }))
    for center in [context.anchors.planet.position, context.anchors.sun.position] {
      expectReadOnlyRefusal(game, context: context, center: center, radius: 1,
        expected: .unsafePosition)
    }
  }

  private func nativePolicyScene() -> Game {
    var game = Game(executive: false)
    game.launch()
    game.ensurePhysicalActors()
    return game
  }

  private func expectReadOnlyRefusal(_ game: Game, context: EncounterContext,
    center: Vector3, radius: Double, expected: AdmissionRefusal)
  {
    let commander = game.commander
    let bodies = game.bodies
    let bodyID = game.nextBodyID
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    #expect(game.c01InquiryPlacementEnvelopeRefusal(center: center, radius: radius,
      context: context) == expected)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.nextBodyID == bodyID && game.gameplayRevision == revision)
    #expect(game.nativeStationRuntimeEpoch == epoch)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }
}
