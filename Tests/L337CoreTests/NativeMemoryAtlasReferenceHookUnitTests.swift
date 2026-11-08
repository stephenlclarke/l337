import Foundation
import Testing

@testable import L337Core

struct NativeMemoryAtlasReferenceHookUnitTests {
  @Test func actualGraphResolvesTheWatcherButRefusesShopAndFittingRoutes() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    let game = await runtime.snapshot()
    let name = NativeMemoryAtlasReferenceDefinition.name
    let kind = OwnedGearKind.module(name)
    let node = try #require(EquipmentRuntimeCatalog.node(for: name))
    #expect(kind.valid && kind.canonicalNode == node)
    #expect(!OwnedGearKind.module(name.lowercased()).valid)
    #expect(EquipmentRuntimeCatalog.node(for: NativeMemoryAtlasReferenceDefinition.logicalResource) == nil)
    #expect(EquipmentRuntimeCatalog.slot(for: node) == nil)
    #expect(EquipmentRuntimeCatalog.definition(for: node.family) == nil)
    #expect(!Equipment.all.contains { $0.name == name })
    let snapshot = try game.commander.purchaseSnapshot()
    let history = try #require(game.commander.equipmentPurchaseHistory)
    // Negative attempted offer, never actual reference stock or a measurement source.
    let offer = EquipmentPurchaseOffer(node: node, price: 1,
      shop: "Negative Memory Atlas reference shop request", revision: 0)
    #expect(throws: EquipmentPurchaseError.notForSale(node)) {
      try EquipmentPurchaseProgression.validateEligibility(offer: offer,
        snapshot: snapshot, history: history, graph: EquipmentRuntimeCatalog.graph)
    }
    let unchanged = try game.commander.purchaseSnapshot() == snapshot
    #expect(unchanged)
  }

  @Test func genericGearCommandsRefuseBeforeAnyReferenceLoanMutation() async throws {
    let fixture = try GearScriptFixture(name: NativeMemoryAtlasReferenceDefinition.name,
      requiredReturn: false, accepted: "")
    defer { fixture.clean() }
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    game.scriptPacks = [fixture.pack]
    _ = try game.acceptScriptMission(fixture.pack)
    var state = try #require(game.commander.scriptState.instances.values.first {
      $0.definition == fixture.pack.manifest.stateID
    })
    var candidate = game.commander
    let before = candidate
    let beforeState = state
    let beforeTonnes = try #require(candidate.checkedCargoTonnes)
    for operation in ["gear.issue", "gear.return", "gear.release", "gear.store", "gear.refit"] {
      var fields: [String: ScriptValue] = [
        "op": .string(operation), "id": .string("negative-atlas-transfer"), "gear": .string("kit"),
      ]
      if operation == "gear.issue" { fields["fit"] = .bool(false) }
      if operation == "gear.store" || operation == "gear.refit" { fields["index"] = .integer(0) }
      // Controlled generic request, not the C25 case, original stock, consent or receiver.
      let event = ScriptEvent(sequence: 1, kind: "contact.requested",
        instance: state.id, values: [:])
      do {
        _ = try game.applyScriptGearCommand(.object(fields), event: event,
          pack: fixture.pack, state: &state, candidate: &candidate)
        Issue.record("A generic command accepted the native-only atlas watcher.")
      } catch let error as MissionPackError {
        #expect(error.reason == "Use the actual Reris atlas reference loan and same-original return.")
      }
      let unchanged = candidate == before && state == beforeState
      let tonnes = try #require(candidate.checkedCargoTonnes)
      #expect(unchanged && tonnes == beforeTonnes)
    }
  }
}
