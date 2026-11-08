import Foundation
import Testing

@testable import L337Core

private struct EMPIssueOwner {
  let script: GearScriptFixture
  let writer: EMPUnitWriter
  let runtime: GameRuntime
  let instance: UUID
  func clean() { script.clean(); writer.clean() }
}

private func actualEMPIssueOwner(fit: Bool = true, full: Bool = false, topEnergy: Bool = false) async throws -> EMPIssueOwner {
  let script = try GearScriptFixture(name: Equipment.empPirateBlaster,
    accepted: "{op='gear.issue',id='issue',gear='kit',fit=\(fit ? "true" : "false")}",
    contact: "{op='gear.refit',id='refit',gear='kit',index=0}")
  let writer = try EMPUnitWriter()
  do {
    var game = try missionGearGame(missiles: 1)
    if topEnergy {
      try game.commander.grantEquipment(Equipment.eliteEnergyUnit, at: .energy,
        provenance: .grant("current issue profile control"))
    }
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    let runtime = GameRuntime(game: game, saveURL: writer.file)
    try await runtime.save(to: writer.file)
    await runtime.key("0")
    await runtime.setControls(Controls())
    for _ in 0..<3 { _ = await runtime.advance(delta: 0.0625) }
    // A controlled unit station boundary, not an arrival or native journey proof.
    let instance = try await runtime.scriptCommand { scene in
      try #require(scene.commander.flightSimulation.physicalTime > 0)
      scene.dock()
      try #require(scene.docked && scene.dockedAtMainStation)
      scene.screen = .status
      scene.scriptPacks = [script.pack]
      if full { scene.commander.cargo[0] = scene.commander.standardCargoCapacity }
      return try scene.acceptScriptMission(script.pack)
    }
    return .init(script: script, writer: writer, runtime: runtime, instance: instance)
  } catch { script.clean(); writer.clean(); throw error }
}

struct EMPMissionIssueSourceTests {
  @Test func actualIssueSameEmpty000ProjectedAndFinal() async throws {
    let fixture = try await actualEMPIssueOwner()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    let state = try #require(game.commander.scriptState.instances[fixture.instance])
    let issue = try #require(state.gearIssues["kit"])
    let id = try #require(issue.items.first)
    let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    #expect(id == OwnedGear.issuedIdentity(mission: fixture.instance, resource: "kit", index: 0))
    #expect(issue.items.count == 1 && issue.loan && issue.status == .issued)
    #expect(issue.source?.mission == fixture.instance && issue.source?.resource == "kit")
    #expect(issue.source?.packDigest == fixture.script.pack.digest)
    #expect(item.provenance == .missionIssue(mission: fixture.instance, resource: "kit", index: 0, packDigest: fixture.script.pack.digest))
    #expect(item.node == EMPModuleGradePolicy.node && item.location?.slot == .utility(.empPirateBlaster))
    #expect(item.empGrades == .base && item.empBank?.capacity == 8 && item.empBank?.remaining == 0)
    #expect(item.empBank?.module == id && item.empBank?.lastDischarge == nil)
    #expect(item.empBank?.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(game.commander.valid && state.suspension == nil)
    let pointer = try Data(contentsOf: fixture.writer.file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: fixture.writer.file)
    #expect(saved.equipmentInventory == game.commander.equipmentInventory)
    #expect(saved.scriptState.instances[fixture.instance]?.gearIssues == state.gearIssues)
    let cold = GameRuntime()
    try await cold.load(from: fixture.writer.file, persistMigrations: false)
    #expect(await cold.snapshot().commander.equipmentInventory == game.commander.equipmentInventory)
    #expect(try Data(contentsOf: fixture.writer.file) == pointer)
    // Successful real issue validates its projected fit and final physical item; the opaque seed is never exposed.
  }

  @Test func actualIssueReplayAndPublicMissingSeedRequestsFailWithoutAuthority() async throws {
    let fixture = try await actualEMPIssueOwner()
    defer { fixture.clean() }
    let before = await fixture.runtime.snapshot()
    let original = try #require(before.commander.equipmentInventory)
    try await fixture.runtime.scriptCommand { game in game.emitScriptEvent("mission.accepted") }
    let repeated = await fixture.runtime.snapshot()
    #expect(repeated.commander.equipmentInventory == original)
    #expect(repeated.commander.scriptState.instances[fixture.instance]?.gearIssues == before.commander.scriptState.instances[fixture.instance]?.gearIssues)
    let context = EquipmentRuntimeCatalog.context(owner: original.owner, hull: original.activeHull, performance: before.commander.nativePerformance)
    let source = EquipmentIssueSource(mission: UUID(), resource: "public-EMP", packDigest: fixture.script.pack.digest)
    let empty = try OwnedEquipmentInventory(owner: original.owner, activeHull: original.activeHull)
    let budget = try before.commander.equipmentFitBudget(projectedItems: [])
    for index in [0, 1] {
      let request = EquipmentIssueRequest(command: UUID(), source: source,
        devices: [.init(id: OwnedGear.issuedIdentity(mission: source.mission, resource: source.resource, index: index),
          node: EMPModuleGradePolicy.node, index: index, preferredSlot: .utility(.empPirateBlaster))], fitting: .held)
      #expect(throws: (any Error).self) {
        _ = try EquipmentIssueTransactions.quoteAdmission(request: request, inventory: empty,
          context: context, obligations: [], budget: budget)
      }
      #expect(empty.items.isEmpty && empty.revision == 0)
    }
    // These public requests lack the private seed; they do not isolate inaccessible seed predicates.
    #expect(await fixture.runtime.snapshot().commander.equipmentInventory == original)
  }

  @Test func heldFitMassBudgetAndNoFree333() async throws {
    let fixture = try await actualEMPIssueOwner(fit: false, topEnergy: true)
    defer { fixture.clean() }
    let before = await fixture.runtime.snapshot()
    let state = try #require(before.commander.scriptState.instances[fixture.instance])
    let id = try #require(state.gearIssues["kit"]?.items.first)
    let held = try #require(before.commander.equipmentInventory?.items.first { $0.id == id })
    #expect(held.location == nil && held.empBank?.remaining == 0 && held.empGrades == .base)
    #expect(held.empGrades?.paid.isEmpty == true && before.commander.checkedCargoTonnes == 1)
    try await fixture.runtime.scriptCommand { game in game.emitScriptEvent("contact.requested") }
    let after = await fixture.runtime.snapshot()
    let fitted = try #require(after.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    #expect(fitted.id == id && fitted.provenance == held.provenance)
    #expect(fitted.empBank == held.empBank && fitted.empGrades == .base)
    #expect(after.commander.checkedCargoTonnes == before.commander.checkedCargoTonnes)
    #expect(after.commander.scriptState.instances[fixture.instance]?.gearIssues["kit"]?.loan == true)
    #expect(after.commander.valid && after.commander.scriptState.instances[fixture.instance]?.suspension == nil)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: fixture.writer.file)
    #expect(saved.equipmentInventory == after.commander.equipmentInventory)
    #expect(saved.scriptState.instances[fixture.instance]?.gearIssues == after.commander.scriptState.instances[fixture.instance]?.gearIssues)
    let full = try await actualEMPIssueOwner(fit: false, full: true)
    defer { full.clean() }
    let refused = await full.runtime.snapshot()
    #expect(refused.commander.scriptState.instances[full.instance]?.gearIssues["kit"] == nil)
    #expect(refused.commander.scriptState.instances[full.instance]?.suspension != nil)
    #expect(refused.commander.equipmentInventory?.items.contains { $0.node == EMPModuleGradePolicy.node } == false)
    #expect(refused.commander.cargo[0] == refused.commander.standardCargoCapacity)
    #expect(refused.commander.valid)
  }
}
