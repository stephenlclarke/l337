import Foundation
import Testing

@testable import L337Core

struct EquipmentGrantPreparationTests {
  @Test(arguments: [false, true])
  func matchingStockGrantRefusesAbsentOwnershipWithoutPublishing(navigation: Bool) throws {
    var commander = grantPreparationCommander()
    try #require(commander.valid && commander.equipmentInventory == nil)
    let before = commander
    let name = navigation ? NavigationTier.basic.equipmentName : LaserKind.pulse.equipmentName
    let slot: ComponentFittingSlot = navigation ? .navigation : .laser(.front)
    #expect(throws: CommanderEquipmentError.incompleteState) {
      try commander.grantEquipment(name, at: slot, provenance: .grant("stock-preparation-test"))
    }
    #expect(commander == before)
  }

  @Test(arguments: [false, true])
  func alreadyCanonicalMatchingStockGrantIsAWholeCommanderNoOp(navigation: Bool) throws {
    var commander = grantPreparationCommander()
    try commander.prepareEquipment(legacy: false)
    try #require(commander.valid && commander.equipmentInventory != nil)
    let name = navigation ? NavigationTier.basic.equipmentName : LaserKind.pulse.equipmentName
    let slot: ComponentFittingSlot = navigation ? .navigation : .laser(.front)
    let fitted = try #require(commander.fittedEquipment(at: slot))
    let before = commander
    try commander.grantEquipment(name, at: slot, provenance: .grant("canonical-no-op-test"))
    #expect(commander == before && commander.fittedEquipment(at: slot) == fitted)
  }

  @Test(arguments: [false, true])
  func invalidGrantPublishesNeitherPreparationNorPartialNewEquipment(prepared: Bool) throws {
    var commander = grantPreparationCommander()
    if prepared { try commander.prepareEquipment(legacy: false) }
    let before = commander
    if prepared {
      #expect(throws: EquipmentRuntimeError.unavailable) {
        try commander.grantEquipment(
          "Unknown equipment", at: .navigation, provenance: .grant("invalid"))
      }
    } else {
      #expect(throws: CommanderEquipmentError.incompleteState) {
        try commander.grantEquipment(
          "Unknown equipment", at: .navigation, provenance: .grant("invalid"))
      }
    }
    #expect(commander == before)
    #expect(throws: (any Error).self) {
      try commander.grantEquipment(
        TargetingTier.basic.equipmentName, at: .laser(.rear),
        provenance: .grant("wrong-slot"))
    }
    #expect(commander == before)
  }

  @Test func matchingStockGrantCannotPublishAnInvalidPreparedCommander() throws {
    var commander = grantPreparationCommander()
    try commander.prepareEquipment(legacy: false)
    commander.credits = -1
    let before = commander
    #expect(throws: EquipmentRuntimeError.incompatibleFit) {
      try commander.grantEquipment(
        NavigationTier.basic.equipmentName, at: .navigation,
        provenance: .grant("invalid-commander"))
    }
    #expect(commander == before)
  }
}

private func grantPreparationCommander() -> Commander {
  var commander = Commander()
  commander.credits = 2710
  commander.fuel = 43
  commander.cargo[0] = 3
  let id = UUID()
  var mission = ScriptInstance(
    id: id, definition: "test.grant-preparation/mission", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  mission.data = .object(["retained": .string("equipment preparation must preserve this mission")])
  mission.journal = ["Keep the original assignment."]
  commander.scriptState.instances[id] = mission
  return commander
}
