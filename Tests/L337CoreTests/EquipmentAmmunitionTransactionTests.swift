import Foundation
import Testing

@testable import L337Core

struct EquipmentAmmunitionTransactionTests {
  @Test func actualShopPurchaseCreatesOnePaidFiniteRoundAtOneNewRevision() throws {
    var game = Game()
    game.commander.missiles = 0
    game.commander.credits = 100000
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
    try game.commander.prepareEquipment(legacy: false)
    let before = try #require(game.commander.equipmentInventory)
    let result = game.purchaseImmediately()
    guard case .applied(.purchase(let name, let identity, let fitted)) = result else {
      Issue.record("Expected a physical missile purchase, got \(result)")
      return
    }
    let id = try #require(identity)
    let next = try #require(game.commander.equipmentInventory)
    let round = try #require(next.items.first { $0.id == id })
    #expect(name == "Missile" && fitted && game.commander.missiles == 1)
    #expect(
      round.node == EquipmentRuntimeCatalog.standardMissile
        && round.location?.slot == .missilePylon(0))
    #expect(next.revision == before.revision + 1 && game.commander.valid)
    #expect(game.commander.equipmentPurchaseHistory?.paid.last?.binding.request.newItem == id)
  }

  @Test func changingUnlimitedSupplyDoesNotRefillOrConsumeFiniteRounds() throws {
    var game = Game()
    game.commander.missiles = 0
    try game.commander.prepareEquipment(legacy: false)
    game.commander.xyzzyActive = true
    game.screen = .secret
    let inventory = game.commander.equipmentInventory
    game.secretKey("3")
    #expect(game.commander.unlimitedMissiles && game.commander.missiles == 0)
    #expect(game.commander.equipmentInventory == inventory)
    game.secretKey("3")
    #expect(!game.commander.unlimitedMissiles && game.commander.equipmentInventory == inventory)
  }
}
