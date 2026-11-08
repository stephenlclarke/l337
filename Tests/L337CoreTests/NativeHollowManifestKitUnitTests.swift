import Foundation
import Testing

@testable import L337Core

/// Real equipment transactions in a controlled non-C03 parent. This does not exercise or
/// authorize the actual laboratory contact, captain consent, inspection or mission return.
private func hollowKitTransactionFixture() throws -> (Game, ScriptInstance) {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  let parent = ScriptInstance(
    id: UUID(), definition: "fixture/hollow-kit-transaction", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  game.commander.scriptState.instances[parent.id] = parent
  return (game, parent)
}

struct NativeHollowManifestKitUnitTests {
  @Test func actualIssueAndOriginalReturnPreserveMoneyItemsAndOpaqueReceiptIdentity() throws {
    let fixture = try hollowKitTransactionFixture()
    let game = fixture.0
    var parent = fixture.1
    let before = game.commander
    let originalInventory = try #require(before.equipmentInventory)
    let command = UUID()
    var candidate = before
    let issued = try #require(game.issueScriptGearWithReceipt(
      NativeHollowManifestKitDefinition.gear, fields: ["fit": .bool(false)], command: command,
      state: &parent, candidate: &candidate))
    candidate.scriptState.instances[parent.id] = parent
    let serial = NativeHollowManifestKitDefinition.serial(mission: parent.id)
    let record = try #require(parent.gearIssues[NativeHollowManifestKitDefinition.resource])
    let obligation = try #require(record.obligation)
    let inventory = try #require(candidate.equipmentInventory)
    let item = try #require(inventory.items.first { $0.id == serial })
    #expect(issued.event.0 == "equipment.issued")
    #expect(issued.receipt.command == command && issued.receipt.source == obligation.source)
    #expect(issued.receipt.operation == .issued && issued.receipt.originalItems == [serial])
    #expect(issued.receipt.affectedItems == [serial] && issued.receipt.consumedItems.isEmpty)
    #expect(issued.receipt.displacements.isEmpty)
    #expect(inventory.revision == originalInventory.revision + 1)
    #expect(item.node == NativeHollowManifestKitDefinition.node)
    #expect(item.location == nil && item.component == nil)
    #expect(record.loan && !record.returnRemaining && record.consumed.isEmpty)
    #expect(candidate.cargoTonnes == before.cargoTonnes + 1)
    #expect(candidate.credits == before.credits && candidate.cargo == before.cargo)
    #expect(candidate.valid)
    #expect(throws: EquipmentIssueError.staleObligation) {
      _ = try NativeHollowManifestKitCustody.resolve(instance: parent, commander: candidate)
    }
    let issuedCommander = candidate
    let issuedParent = parent
    let duplicate = try game.issueScriptGearWithReceipt(
      NativeHollowManifestKitDefinition.gear, fields: ["fit": .bool(false)], command: UUID(),
      state: &parent, candidate: &candidate)
    #expect(duplicate?.receipt == nil)
    #expect(candidate == issuedCommander && parent == issuedParent)
    let returnCommand = UUID()
    let returned = try game.settleScriptGearWithReceipt(
      record, release: false, command: returnCommand, state: &parent, candidate: &candidate)
    candidate.scriptState.instances[parent.id] = parent
    #expect(returned.event.0 == "equipment.returned")
    #expect(returned.receipt.command == returnCommand)
    #expect(returned.receipt.source == issued.receipt.source)
    #expect(returned.receipt.operation == .returned)
    #expect(returned.receipt.originalItems == [serial] && returned.receipt.affectedItems == [serial])
    #expect(returned.receipt.consumedItems.isEmpty && returned.receipt.displacements.isEmpty)
    #expect(candidate.equipmentInventory?.items == originalInventory.items)
    #expect(candidate.equipmentInventory?.revision == originalInventory.revision + 2)
    #expect(candidate.cargoTonnes == before.cargoTonnes)
    #expect(candidate.credits == before.credits && candidate.cargo == before.cargo)
    #expect(parent.gearIssues[NativeHollowManifestKitDefinition.resource]?.status == .returned)
    #expect(candidate.valid)
    // The helpers return candidate transactions; they do not publish the Game themselves.
    #expect(game.commander == before)
  }

  @Test func fullPhysicalHoldRefusesWithoutCreatingAnItemObligationOrReceipt() throws {
    let (game, initialParent) = try hollowKitTransactionFixture()
    var parent = initialParent
    var candidate = game.commander
    candidate.cargo[0] = candidate.standardCargoCapacity
    let before = candidate
    #expect(throws: (any Error).self) {
      _ = try game.issueScriptGearWithReceipt(
        NativeHollowManifestKitDefinition.gear, fields: ["fit": .bool(false)], command: UUID(),
        state: &parent, candidate: &candidate)
    }
    #expect(candidate == before && parent == initialParent)
    #expect(NativeHollowManifestKitDefinition.occupiedTonnes(in: candidate.equipmentInventory) == 0)
  }

  @Test func kitHasNoShopOrFittingRouteAndGenericLuaCannotIssueIt() throws {
    let definition = NativeHollowManifestKitDefinition.gear
    #expect(definition.valid && definition.quantity == 1 && definition.loan)
    #expect(definition.returnPolicy == "all" && definition.mount == nil)
    #expect(NativeHollowManifestKitDefinition.purchaseNode.policy == .acquisitionOnly)
    #expect(EquipmentRuntimeCatalog.slot(for: NativeHollowManifestKitDefinition.node) == nil)
    #expect(!Equipment.all.contains { $0.name == definition.name })
    #expect(!Equipment.maximumHardware.contains(definition.name))
    let fixture = try GearScriptFixture(
      name: definition.name, accepted: "{op='gear.issue',id='forged-kit',gear='kit',fit=false}")
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    #expect(game.commander == before)
    #expect(NativeHollowManifestKitDefinition.issueLocation == .init(galaxy: 1, system: 27))
    #expect(NativeHollowManifestKitDefinition.returnLocation == .init(galaxy: 1, system: 120))
  }

  @Test func genericGearCommandsCannotReturnReleaseOrRefitAnActuallyIssuedKit() throws {
    let fixture = try GearScriptFixture(
      name: NativeHollowManifestKitDefinition.name, accepted: "")
    defer { fixture.clean() }
    let game = try fixture.game()
    var parent = try #require(game.commander.scriptState.instances.values.first)
    let definition = try #require(fixture.pack.manifest.equipment?.first)
    var candidate = game.commander
    _ = try #require(game.issueScriptGearWithReceipt(
      definition, fields: ["fit": .bool(false)], command: UUID(),
      state: &parent, candidate: &candidate))
    candidate.scriptState.instances[parent.id] = parent
    let before = candidate
    let beforeParent = parent
    for operation in ["gear.issue", "gear.return", "gear.release", "gear.store", "gear.refit"] {
      var fields: [String: ScriptValue] = [
        "op": .string(operation), "id": .string("attempt"), "gear": .string(definition.id),
      ]
      if operation == "gear.issue" { fields["fit"] = .bool(false) }
      if operation == "gear.store" || operation == "gear.refit" { fields["index"] = .integer(0) }
      // Controlled script input exercises the refusal boundary; it is not native contact proof.
      let event = ScriptEvent(
        sequence: 1, kind: "contact.requested", instance: parent.id, values: [:])
      do {
        _ = try game.applyScriptGearCommand(
          .object(fields), event: event, pack: fixture.pack, state: &parent, candidate: &candidate)
        Issue.record("Generic script unexpectedly accepted the laboratory kit command.")
      } catch let error as MissionPackError {
        #expect(error.reason == "Use the original Torenran laboratory issue and Narargan return.")
      }
      #expect(candidate == before && parent == beforeParent)
    }
  }
}
