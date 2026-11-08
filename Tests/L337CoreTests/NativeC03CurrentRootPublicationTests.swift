import Foundation
import Testing

@testable import L337Core

/// The positive root is issued only by the actual bootstrap, swept berth, sale,
/// review and Confirm fixture. Changed bytes below are rejecting inputs only.
struct NativeC03CurrentRootPublicationTests {
  @Test(arguments: ["foreign-owner", "older-root"])
  func currentReaderBindsTheOriginalLeafToItsActualHeaderAndNamespace(change: String)
    async throws
  {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let owner = try #require(accepted.commander.equipmentOwnerID)
    let originalPointer = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let alien = pointer.schemaVersion == NativeC03PublicationNamespace.alienVersion
    #expect(pointer.schemaVersion == (alien
      ? NativeC03PublicationNamespace.alienVersion : NativeC03PublicationNamespace.version))
    let restored = try ScriptSaveStore.read(originalPointer, from: fixture.files.save).0
    #expect(restored.scriptState.instances[instance.id]?.savedHollowManifest == state)
    #expect(restored.scriptState.firstNativeCommoditySale
      == accepted.commander.scriptState.firstNativeCommoditySale)
    #expect(NativeC03PublicationPreflight.validateClaims(restored))
    #expect(state.admissions.isEmpty && state.crewSource == nil && state.caseFile == nil)

    let sourceDirectory = fixture.files.save.deletingLastPathComponent()
    let changedDirectory = fixture.files.root.appendingPathComponent("changed-root-" + change)
    try FileManager.default.copyItem(at: sourceDirectory, to: changedDirectory)
    let changedSave = changedDirectory.appendingPathComponent(fixture.files.save.lastPathComponent)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: changedSave)
    let originalMissions = try Data(contentsOf: generation.appendingPathComponent("missions.json"))
    var hashes = pointer.hashes
    var schema = pointer.schemaVersion
    if change == "foreign-owner" {
      let headerURL = generation.appendingPathComponent("commander.json")
      var header = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: headerURL))
        as? [String: Any])
      var inventory = try #require(header["savedEquipmentInventory"] as? [String: Any])
      #expect(inventory["owner"] as? String == owner.uuidString)
      inventory["owner"] = UUID().uuidString
      header["savedEquipmentInventory"] = inventory
      let changedHeader = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
      try changedHeader.write(to: headerURL)
      hashes["commander.json"] = ScriptPackLibrary.hash(changedHeader)
    } else {
      schema = alien ? NativeSecondCommoditySaleSave.alienVersion
        : NativeSecondCommoditySaleSave.version
    }
    let changedPointer = ScriptSavePointer(
      format: pointer.format, schemaVersion: schema, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec,
      bisonUnitJournalCheckpoint: pointer.bisonUnitJournalCheckpoint)
    let rejectingBytes = try JSONEncoder().encode(changedPointer)
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(rejectingBytes, from: changedSave)
    }
    #expect(try Data(contentsOf: generation.appendingPathComponent("missions.json"))
      == originalMissions)
    #expect(try Data(contentsOf: fixture.files.save) == originalPointer)
    let unchanged = await fixture.runtime.snapshot()
    #expect(unchanged.commander == accepted.commander && unchanged.bodies == accepted.bodies)
  }

  @Test func actualCommandCannotDropAnAlreadyPublishedCaseOrReplaceItsSave() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let before = await fixture.runtime.snapshot()
    let instance = try #require(before.hollowManifestMission)
    let mission = instance.id
    let state = try #require(instance.savedHollowManifest)
    let pointerBytes = try Data(contentsOf: fixture.files.save)
    let filesBefore = try ScriptFinanceTestFixture.files(fixture.files.root)

    // This is a deliberately invalid command proposal, never accepted history.
    await fixture.runtime.nativeCommand { game in
      game.commander.scriptState.instances.removeValue(forKey: mission)
    }
    let after = await fixture.runtime.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.hollowManifestMission?.savedHollowManifest == state)
    #expect(try Data(contentsOf: fixture.files.save) == pointerBytes)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == filesBefore)
    let restored = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save).0
    #expect(restored.scriptState.instances[mission]?.savedHollowManifest == state)
    #expect(NativeC03PublicationPreflight.validateClaims(restored))
  }
}
