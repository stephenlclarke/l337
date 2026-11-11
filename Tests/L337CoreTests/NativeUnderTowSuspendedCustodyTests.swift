import Foundation
import Testing

@testable import L337Core

struct NativeUnderTowSuspendedCustodyTests {
  @Test func borrowedOriginalSurvivesMissingContentSaveLoadAndExactPackResume() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    let (original, commander, loan) = try await borrowOriginal(fixture)
    let installed = fixture.files.root.appendingPathComponent("under-tow-library")
    let bytes = try await suspendAndSave(
      fixture, installed: installed, original: original, commander: commander, loan: loan)
    try await loadSuspended(
      fixture, original: original, commander: commander, loan: loan, bytes: bytes)
    try await restoreAndResume(
      fixture, installed: installed, original: original, commander: commander, loan: loan)
  }

  private func borrowOriginal(_ fixture: UnderTowOpeningFixture) async throws
    -> (ScriptInstance, Commander, NativeUnderTowReferenceBinding)
  {
    _ = try await fixture.confirm(.accept)
    let game = try await fixture.confirm(.collectReference)
    let instance = try #require(game.underTowMission)
    let loan = try NativeUnderTowCustody.resolve(instance: instance, commander: game.commander)
    return (instance, game.commander, loan)
  }

  private func suspendAndSave(
    _ fixture: UnderTowOpeningFixture, installed: URL, original: ScriptInstance,
    commander: Commander, loan: NativeUnderTowReferenceBinding
  ) async throws -> Data {
    await fixture.runtime.loadScriptPacks(directory: installed)
    let unavailable = await fixture.runtime.snapshot()
    let suspended = try #require(unavailable.underTowMission)
    try #require(suspended.suspension != nil && unavailable.underTowPack == nil)
    #expect(suspended.savedUnderTow == original.savedUnderTow)
    #expect(suspended.gearIssues == original.gearIssues)
    #expect(unavailable.commander.equipmentInventory == commander.equipmentInventory)
    #expect(
      unavailable.commander.credits == commander.credits
        && unavailable.commander.cargo == commander.cargo)
    #expect(unavailable.commander.checkedCargoTonnes == commander.checkedCargoTonnes)
    #expect(
      unavailable.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal)
    #expect(!unavailable.underTowReview(.collectReference).allowed)
    #expect(throws: EquipmentIssueError.staleObligation) {
      try NativeUnderTowCustody.resolve(instance: suspended, commander: unavailable.commander)
    }
    #expect(
      try NativeUnderTowCustody.heldReference(instance: suspended, commander: unavailable.commander)
        == loan)
    try #require(NativeUnderTowSave.validateClaims(unavailable.commander))
    try #require(unavailable.commander.valid)

    try await fixture.runtime.save(to: fixture.files.save)
    let bytes = try Data(contentsOf: fixture.files.save)
    let (saved, world) = try ScriptSaveStore.read(bytes, from: fixture.files.save)
    let cold = try #require(saved.scriptState.instances[original.id])
    #expect(world.consistent(with: saved) && cold.suspension == suspended.suspension)
    #expect(cold.savedUnderTow == original.savedUnderTow && cold.gearIssues == original.gearIssues)
    #expect(try NativeUnderTowCustody.heldReference(instance: cold, commander: saved) == loan)
    return bytes
  }

  private func loadSuspended(
    _ fixture: UnderTowOpeningFixture, original: ScriptInstance, commander: Commander,
    loan: NativeUnderTowReferenceBinding, bytes: Data
  ) async throws {
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    let retained = try #require(loaded.underTowMission)
    try #require(retained.suspension != nil)
    #expect(retained.savedUnderTow == original.savedUnderTow)
    #expect(loaded.commander.equipmentInventory == commander.equipmentInventory)
    #expect(
      try NativeUnderTowCustody.heldReference(instance: retained, commander: loaded.commander)
        == loan)
    #expect(throws: EquipmentIssueError.staleObligation) {
      try NativeUnderTowCustody.resolve(instance: retained, commander: loaded.commander)
    }
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    let missing = try #require(loaded.underTowMissingGalleryEntry(retained))
    #expect(missing.status == .locked && missing.savedInstance == original.id)
    await #expect(throws: MissionPackError.self) {
      try await fixture.runtime.resumeScriptMission(original.id)
    }
    #expect(await fixture.runtime.snapshot().commander == loaded.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
  }

  private func restoreAndResume(
    _ fixture: UnderTowOpeningFixture, installed: URL, original: ScriptInstance,
    commander: Commander, loan: NativeUnderTowReferenceBinding
  ) async throws {
    try await fixture.runtime.installScriptPack(
      from: ScriptPackLibrary.bundledUnderTowDirectory, destination: installed)
    try await fixture.runtime.resumeScriptMission(original.id)
    let resumed = await fixture.runtime.snapshot()
    let current = try #require(resumed.underTowMission)
    #expect(current.suspension == nil && current.savedUnderTow == original.savedUnderTow)
    #expect(resumed.underTowPack?.digest == NativeUnderTowDefinition.digest)
    #expect(
      try NativeUnderTowCustody.resolve(instance: current, commander: resumed.commander) == loan)
    #expect(current.gearIssues == original.gearIssues && current.milestones == [0, 1])
    #expect(current.outcome == .active && current.completionReceipt == nil)
    #expect(resumed.commander.equipmentInventory == commander.equipmentInventory)
    #expect(resumed.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
    #expect(
      resumed.commander.credits == commander.credits && resumed.commander.cargo == commander.cargo)
    #expect(resumed.commander.checkedCargoTonnes == commander.checkedCargoTonnes)
    #expect(
      resumed.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal)
    #expect(!resumed.underTowReview(.collectReference).allowed)
    let disk = try ScriptSaveStore.read(
      Data(contentsOf: fixture.files.save), from: fixture.files.save
    ).0
    let diskCase = try #require(disk.scriptState.instances[original.id])
    #expect(diskCase.suspension == nil && diskCase.savedUnderTow == original.savedUnderTow)
    #expect(try NativeUnderTowCustody.resolve(instance: diskCase, commander: disk) == loan)
  }
}
