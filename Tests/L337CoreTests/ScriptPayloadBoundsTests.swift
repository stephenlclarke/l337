import Foundation
import Testing

@testable import L337Core

struct ScriptPayloadBoundsTests {
  @Test func scriptPayloadBoundsAreCheckedBeforeAggregationAndCannotPartiallyLoad() {
    for quantity in [Int.max, -1, 1_000_001] {
      var commander = Commander()
      var instance = ScriptInstance(
        id: UUID(), definition: "fixture/payload", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      instance.payloads = ["first": quantity, "second": quantity]
      commander.scriptState.instances[instance.id] = instance
      #expect(commander.checkedCargoTonnes == nil && !commander.valid)
      var game = Game()
      let before = game
      let loaded = game.load(commander)
      #expect(!loaded && game.commander == before.commander && game.bodies == before.bodies)
      #expect(game.inventoryContextEpoch == before.inventoryContextEpoch)
    }
    var maximum = Commander()
    for index in 0..<128 {
      var instance = ScriptInstance(
        id: UUID(), definition: "fixture/payload-\(index)", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      instance.payloads = Dictionary(
        uniqueKeysWithValues: (0..<128).map { ("parcel-\($0)", 1_000_000) })
      maximum.scriptState.instances[instance.id] = instance
    }
    #expect(maximum.checkedCargoTonnes == 16_384_000_000)
  }
}
