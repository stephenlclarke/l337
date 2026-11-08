import Foundation
import Testing

@testable import L337Core

struct CurrentNewtReservationTests {
  @Test(arguments: ["actual", "missing-total", "missing-cargo", "foreign-parent"])
  func releaseCanOnlyProjectItsOwnAlreadyCountedSlot(condition: String) throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bodyCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate)
    let physical = try #require(body.physical)
    let stock = try #require(physical.currentNewtKitStock)
    let ownedPreparationRequired1 = game.gameplayContext()
    let current = try #require(ownedPreparationRequired1)
    let before = game
    var budget = current.budget
    if condition == "missing-total" { budget.total -= 1 }
    if condition == "missing-cargo" { budget.active[.cargo, default: 0] -= 1 }
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
    object["budget"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(budget))
    // Negative proposals alter only observed budget counters; real birth/stock/time stay intact.
    let observed = try JSONDecoder().decode(
      EncounterContext.self, from: JSONSerialization.data(withJSONObject: object))
    let subject = condition == "foreign-parent" ? current.player.identity : physical.identity
    let projected = game.currentNewtReleaseBudget(stock: stock, parent: subject, context: observed)
    if condition == "actual" {
      let result = try #require(projected)
      #expect(result.total == current.budget.total - 1)
      #expect(result.active[.cargo, default: 0] == current.budget.active[.cargo, default: 0] - 1)
      #expect(result.maximum == current.budget.maximum)
      #expect(result.policeReserve == current.budget.policeReserve)
      #expect(result.missionReserve == current.budget.missionReserve)
    } else {
      #expect(projected == nil)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID && game.gameplayRevision == before.gameplayRevision)
    #expect(game.time == before.time)
  }
}
