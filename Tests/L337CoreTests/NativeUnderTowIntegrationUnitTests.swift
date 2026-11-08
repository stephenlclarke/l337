import Foundation
import Testing

@testable import L337Core

/// Uses the original opening fixture's real bootstrap, swept berth, purchase and loan.
/// Its remote scene is controlled test setup, not evidence of a flown route. UNRUN.
struct NativeUnderTowIntegrationUnitTests {
  @Test func currentTypedLeafCopyDetachesWithoutChangingTheOriginalLoan() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let original = try #require(collected.underTowMission)
    let originalState = try #require(original.savedUnderTow)
    let originalCustody = try NativeUnderTowCustody.resolve(instance: original, commander: collected.commander)
    var detached = original
    detached.savedUnderTow?.collection = nil
    #expect(detached != original)
    #expect(original.savedUnderTow == originalState)
    #expect(collected.underTowMission?.savedUnderTow == originalState)
    #expect(NativeUnderTowSave.validateClaims(collected.commander))
    #expect(try NativeUnderTowCustody.resolve(instance: original, commander: collected.commander) == originalCustody)

    var invalid = collected
    invalid.commander.scriptState.instances[original.id] = detached
    #expect(invalid.commander != collected.commander)
    #expect(!NativeUnderTowSave.validateClaims(invalid.commander))
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    #expect(throws: (any Error).self) {
      try GameRuntime.writeCommander(&invalid, to: fixture.files.save)
    }
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    let stored = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(stored.scriptState.instances[original.id]?.savedUnderTow == originalState)
    #expect(stored.equipmentInventory == collected.commander.equipmentInventory)
  }

  @Test func malformedActualCurrentLeafRefusesReaderAndActorLoadWithoutChangingCustody() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    try await fixture.runtime.save(to: fixture.files.save)
    let instance = try #require(collected.underTowMission)
    let originalCustody = try NativeUnderTowCustody.resolve(instance: instance, commander: collected.commander)
    let pointerBytes = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    try #require(pointer.schemaVersion == NativeFirstCommodityTradeSave.version)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let missionsURL = generation.appendingPathComponent("missions.json")
    let missionsBytes = try Data(contentsOf: missionsURL)
    let originalRoot = try #require(JSONSerialization.jsonObject(with: missionsBytes) as? [String: Any])
    let originalPointer = try #require(JSONSerialization.jsonObject(with: pointerBytes) as? [String: Any])
    for corruption in ["missing", "null", "unknown"] {
      let changed = try changedOriginalInstance(originalRoot) { saved in
        switch corruption {
        case "missing": saved.removeValue(forKey: NativeUnderTowSave.field)
        case "null": saved[NativeUnderTowSave.field] = NSNull()
        default:
          var leaf = try #require(saved[NativeUnderTowSave.field] as? [String: Any])
          leaf["unrecognisedCustodyPermission"] = true
          saved[NativeUnderTowSave.field] = leaf
        }
      }
      let damaged = try JSONSerialization.data(withJSONObject: changed)
      var updatedPointer = originalPointer
      var hashes = try #require(updatedPointer["hashes"] as? [String: String])
      hashes["missions.json"] = ScriptPackLibrary.hash(damaged)
      updatedPointer["hashes"] = hashes
      // Change the real current chunk and its hash: a hash mismatch cannot satisfy this test.
      try damaged.write(to: missionsURL)
      try JSONSerialization.data(withJSONObject: updatedPointer).write(to: fixture.files.save)
      let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
      let before = await fixture.runtime.snapshot()
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save)
      }
      await #expect(throws: (any Error).self) {
        try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
      }
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == before.commander && refused.bodies == before.bodies)
      #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
      let retained = try #require(refused.underTowMission)
      #expect(try NativeUnderTowCustody.resolve(instance: retained, commander: refused.commander) == originalCustody)
      try missionsBytes.write(to: missionsURL)
      try pointerBytes.write(to: fixture.files.save)
    }
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let restored = await fixture.runtime.snapshot()
    let retained = try #require(restored.underTowMission)
    #expect(retained.savedUnderTow == instance.savedUnderTow)
    #expect(restored.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try NativeUnderTowCustody.resolve(instance: retained, commander: restored.commander) == originalCustody)
  }

  @Test func productionLibraryAndProgressRoutesNeverOfferGenericCompletionOrAnotherLoan() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    let emptyDirectory = fixture.files.root.appendingPathComponent("empty-user-packs")
    try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
    let library = ScriptPackLibrary.defaultLibrary(directory: emptyDirectory)
    let bundled = library.packs.filter(NativeUnderTowDefinition.applies)
    try #require(bundled.count == 1)
    #expect(NativeUnderTowDefinition.matches(bundled[0]))
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let inventory = collected.commander.equipmentInventory
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let progress = try await fixture.review(.progress)
    let quote = try #require(progress.contractBoard.underTowQuote)
    #expect(!quote.allowed && quote.action == .progress)
    #expect(progress.contractBoard.quote == nil && progress.contractBoard.inquiryQuote == nil)
    #expect(Display.contractDetailRows(progress, width: progress.viewportWidth).contains {
      $0.contains("Original reference held")
    })
    await fixture.runtime.key("return")
    let back = await fixture.runtime.snapshot()
    #expect(!back.contractBoard.detail && back.contractBoard.underTowQuote == nil)
    for key in ["right", "left"] {
      _ = try await fixture.review(.progress)
      await fixture.runtime.key(key)
      await fixture.runtime.key("return")
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == collected.commander)
      #expect(refused.commander.equipmentInventory == inventory)
      #expect(refused.underTowMission?.milestones == [0, 1])
      #expect(refused.underTowRows.allSatisfy { $0.underTow == .progress })
    }
    let trialCandidate = collected
    #expect(throws: MissionPackError.self) {
      _ = try trialCandidate.constructScriptTrial(packDigest: bundled[0].digest, seed: 1)
    }
    #expect(trialCandidate.commander == collected.commander)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
  }

  /// Negative edits of the one ACTUALLY accepted instance; never a positive receipt fixture.
  private func changedOriginalInstance(_ original: [String: Any],
    change: (inout [String: Any]) throws -> Void) throws -> [String: Any]
  {
    var root = original
    var count = 0
    if var instances = root["instances"] as? [String: Any] {
      for key in Array(instances.keys) {
        guard var instance = instances[key] as? [String: Any],
          instance["definition"] as? String == NativeUnderTowDefinition.stateID else { continue }
        try change(&instance)
        instances[key] = instance
        count += 1
      }
      root["instances"] = instances
    } else {
      var pairs = try #require(root["instances"] as? [Any])
      try #require(pairs.count.isMultiple(of: 2))
      for index in stride(from: 1, to: pairs.count, by: 2) {
        guard var instance = pairs[index] as? [String: Any],
          instance["definition"] as? String == NativeUnderTowDefinition.stateID else { continue }
        try change(&instance)
        pairs[index] = instance
        count += 1
      }
      root["instances"] = pairs
    }
    try #require(count == 1)
    return root
  }
}
