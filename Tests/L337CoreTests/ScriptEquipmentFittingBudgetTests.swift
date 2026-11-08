import Foundation
import Testing

@testable import L337Core

struct ScriptEquipmentFittingBudgetTests {
  @Test func declaredCurrentDockingModuleKeepsItsOneUnitFittingCost() throws {
    let name = TargetingTier.docking.equipmentName
    let fixture = try GearScriptFixture(name: name)
    defer { fixture.clean() }
    let game = try fixture.game()
    let state = try #require(game.commander.scriptState.instances.values.first)
    let record = try #require(state.gearIssues["kit"])
    let item = try #require(
      game.commander.equipmentInventory?.items.first { $0.id == record.items[0] })
    #expect(game.commander.valid && record.kind.name == name)
    #expect(item.node == EquipmentRuntimeCatalog.node(for: name))
    #expect(Commander.commonEquipmentUnitCost(for: item) == 1)
    let budget = try game.commander.equipmentFitBudget(
      projectedItems: try #require(game.commander.equipmentInventory).items)
    #expect(budget.nodeEquipmentUnits[item.node] == 1)
    #expect(game.commander.ownedGearCounts(fitted: true)[name] == .integer(1))
  }
}
