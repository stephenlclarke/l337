import Testing

@testable import L337Core

struct CurrentNavalHullSourceUnitTests {
  @Test func producerRequiresAnActualCurrentNativeBindingBeforeChangingBodiesOrIDs() throws {
    let native = try #require(ShipCatalogue.nativeShip(.viper))
    let current = try #require(OriginalFleetRuntimeHullSource.source(for: native.id))
    try #require(current.ship.nativeHull == .viper)
    var game = Game(executive: false)
    let count = game.bodies.count
    let next = game.nextBodyID
    let nativeAdded = game.addNavalShip(.viper, position: .init(0, 0, 6400))
    try #require(nativeAdded)
    try #require(game.bodies.count == count + 1 && game.nextBodyID == next + 1)
    let body = try #require(game.bodies.last)
    #expect(body.id == next && body.hull == .viper && body.hostile)
    #expect(body.position == .init(0, 0, 6400) && !body.navalTarget)

    // Real missing bindings from the current imported fleet cannot fall through
    // to Mesh.hull's missing-native precondition or claim a substitute original.
    for hull in [Hull.cobra, .sidewinder, .constrictor, .thargoid, .thargon] {
      try #require(ShipCatalogue.nativeShip(hull) == nil)
      let commander = game.commander
      let bodies = game.bodies
      let next = game.nextBodyID
      let time = game.time
      let missingAdded = game.addNavalShip(hull, position: .init(6400, 6400, 6400))
      #expect(!missingAdded)
      #expect(game.commander == commander && game.bodies == bodies)
      #expect(game.nextBodyID == next && game.time == time)
    }
  }
}
