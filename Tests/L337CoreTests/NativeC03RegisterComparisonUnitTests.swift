import Foundation
import Testing

@testable import L337Core

/// Every positive record comes from the actual existing native archive journey. Its
/// controlled remote scene and older fixture test budget are not earned travel or wealth.
/// No register, observation, laboratory, kit or recovery receipt is injected. UNRUN.
struct NativeC03RegisterComparisonUnitTests {
  private func recover(_ runtime: GameRuntime) async throws -> Game {
    let selected = try await selectActualHollowRegister(runtime)
    try #require(selected.hollowManifestRegisterTarget != nil)
    await runtime.missionUICommand(.init(action: .originalRegisterRecovery,
      game: selected, presentation: selected.scriptPagePresentation))
    let result = await runtime.snapshot()
    _ = try #require(result.hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery)
    return result
  }

  @Test func actualRecoveryRetainsTheComparisonAndCurrentColdLoadNeedsNoSecondSource() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let before = await runtime.snapshot()
    #expect(before.hollowManifestRegisterComparisonLines().isEmpty)
    let recovered = try await recover(runtime)
    let instance = try #require(recovered.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let record = try #require(state.custodyRegister)
    let transfer = try #require(record.recovery)
    let lab = try #require(state.laboratory)
    let trail = try #require(state.wakeTrail)
    let held = try recovered.hollowManifestHeldRegisterData()
    let comparison = held.comparison
    #expect(comparison == transfer.facts.comparison && comparison.shapeValid)
    #expect(comparison.valid(in: state, contents: record.origin.contents))
    #expect(comparison.facts.mission == instance.id && comparison.facts.owner == held.kit.owner)
    #expect(comparison.facts.register == held.contents.serial)
    #expect(comparison.facts.contentsHash == (try NativeFlightReception.hash(held.contents)))
    #expect(comparison.facts.laboratory == lab.operation)
    #expect(comparison.facts.sealAnalysis == lab.facts.analysis.operation)
    #expect(comparison.facts.inspections == lab.facts.analysis.facts.observations.map(\.inspection))
    #expect(comparison.facts.wakeObservations == trail.observations.map(\.operation))
    #expect(comparison.facts.finding == .conflictingCargoDeclarations)
    #expect(recovered.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(recovered.commander.cargo == before.commander.cargo && recovered.commander.credits == before.commander.credits)
    #expect(recovered.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(instance.milestones == [0, 1, 2, 3, 4] && instance.outcome == .active)
    #expect(state.caseFile == nil && instance.completionReceipt == nil)
    let lines = recovered.hollowManifestCurrentCaseLines()
    #expect(lines.contains { $0.contains("REGISTER COMPARISON") })
    #expect(lines.contains { $0.contains("not proof of actual cargo") })
    #expect(lines.contains { $0.contains("unaltered log") })

    let files = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
    var missingKit = recovered
    let inventory = try #require(missingKit.commander.equipmentInventory)
    missingKit.commander.equipmentInventory = try .init(owner: inventory.owner,
      activeHull: inventory.activeHull, revision: inventory.revision + 1,
      items: inventory.items.filter { $0.id != held.kit.serial })
    #expect(throws: (any Error).self) { try missingKit.hollowManifestHeldRegisterData() }
    #expect(missingKit.hollowManifestRegisterComparisonLines().contains {
      $0.contains("comparison is unavailable")
    })
    #expect(!missingKit.hollowManifestRegisterComparisonLines().contains {
      $0.contains("REGISTER CLAIM")
    })
    #expect(try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent()) == files)
    var shell = Game(executive: false)
    shell.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledHollowManifestDirectory)]
    let cold = GameRuntime(game: shell, saveURL: commission.files.save)
    try await cold.load(from: commission.files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    let retained = try loaded.hollowManifestHeldRegisterData()
    #expect(retained.transfer == held.transfer && retained.comparison == comparison)
    #expect(retained.contents == held.contents && retained.kit.serial == held.kit.serial)
    #expect(loaded.hollowManifestRegisterComparisonLines() == recovered.hollowManifestRegisterComparisonLines())
    let committed = loaded.commander
    await cold.key("original-register-recover")
    #expect(await cold.snapshot().commander == committed)
  }

  @Test func correctlyRehashedForeignBindingsCannotReplaceTheActualComparison() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recover(runtime)
    let instance = try #require(recovered.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let record = try #require(state.custodyRegister)
    let transfer = try #require(record.recovery)
    let lab = try #require(state.laboratory)
    let comparison = transfer.facts.comparison
    for failure in ["laboratory", "wake-order", "contents"] {
      var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(comparison)) as? [String: Any])
      var facts = try #require(object["facts"] as? [String: Any])
      switch failure {
      case "laboratory": facts["laboratory"] = lab.facts.analysis.operation.uuidString
      case "wake-order": facts["wakeObservations"] = Array(comparison.facts.wakeObservations.reversed()).map(\.uuidString)
      default: facts["contentsHash"] = try NativeFlightReception.hash(lab.facts.analysis)
      }
      object["facts"] = facts
      let first = try JSONDecoder().decode(NativeC03RegisterComparison.self,
        from: JSONSerialization.data(withJSONObject: object))
      object["operation"] = try NativeC03RegisterComparison.identity(first.facts).uuidString
      let wrong = try JSONDecoder().decode(NativeC03RegisterComparison.self,
        from: JSONSerialization.data(withJSONObject: object))
      try #require(wrong.shapeValid)
      #expect(!wrong.valid(in: state, contents: record.origin.contents))

      var outer = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(transfer.facts)) as? [String: Any])
      outer["comparison"] = object
      let changedFacts = try JSONDecoder().decode(NativeC03RegisterState.Recovery.Facts.self,
        from: JSONSerialization.data(withJSONObject: outer))
      let changedTransfer = NativeC03RegisterState.Recovery(
        operation: try NativeC03RegisterState.Recovery.identity(changedFacts), facts: changedFacts)
      let changedRecord = NativeC03RegisterState(origin: record.origin, admissions: record.admissions,
        recovery: changedTransfer)
      #expect(!changedRecord.valid(in: state))
      var saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
      saved["custodyRegister"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(changedRecord))
      let wrongState = try JSONDecoder().decode(NativeHollowManifestState.self,
        from: JSONSerialization.data(withJSONObject: saved))
      var invalid = recovered
      invalid.commander.scriptState.instances[instance.id]?.savedHollowManifest = wrongState
      #expect(!NativeHollowManifestSave.validateClaims(invalid.commander))
      let files = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
      #expect(throws: (any Error).self) {
        try GameRuntime.writeCommander(&invalid, to: commission.files.save)
      }
      #expect(try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent()) == files)
      #expect(recovered.hollowManifestMission?.savedHollowManifest == state)
    }
  }

  @Test func malformedComparisonBoundsRefuseBeforeIdentityHashing() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    for failure in ["empty-inspections", "duplicate-inspection", "excess-wakes", "long-hash"] {
      var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(held.comparison)) as? [String: Any])
      var facts = try #require(object["facts"] as? [String: Any])
      switch failure {
      case "empty-inspections": facts["inspections"] = [String]()
      case "duplicate-inspection": facts["inspections"] = Array(repeating: held.comparison.facts.inspections[0].uuidString, count: 2)
      case "excess-wakes": facts["wakeObservations"] = Array(repeating: held.comparison.facts.wakeObservations[0].uuidString, count: 96)
      default: facts["contentsHash"] = String(repeating: "a", count: 65)
      }
      object["facts"] = facts
      let wrong = try JSONDecoder().decode(NativeC03RegisterComparison.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!wrong.bounded && !wrong.shapeValid)
      #expect(throws: SaveError.self) { try NativeC03RegisterComparison.identity(wrong.facts) }
    }
  }

  @Test func actualWriterFailureRollsBackDataAndComparisonTogetherThenRetriesOnce() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    let state = try #require(selected.hollowManifestMission?.savedHollowManifest)
    let record = try #require(state.custodyRegister)
    let expected = try NativeC03RegisterComparison.examining(state, contents: record.origin.contents)
    let files = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
    let backup = try commission.files.blockWrites("c03-register-comparison")
    await #expect(throws: (any Error).self) {
      try await runtime.scriptCommand { candidate in
        do { try candidate.recoverHollowManifestRegister() }
        catch { Issue.record(error); throw error }
      }
    }
    let refused = await runtime.snapshot()
    #expect(refused.commander == selected.commander)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.custodyRegister == record)
    #expect(record.recovery == nil && record.sourceContents == record.origin.contents)
    #expect(refused.hollowManifestRegisterComparisonLines().isEmpty)
    #expect(try ScriptFinanceTestFixture.files(backup) == files)
    try commission.files.restoreWrites(backup, files: files)
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    #expect(held.comparison == expected)
    #expect(recovered.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(recovered.commander.credits == selected.commander.credits)
    #expect(recovered.commander.scriptState.savedClueJournal == selected.commander.scriptState.savedClueJournal)
    let committed = recovered.commander
    let stored = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
    await runtime.key("original-register-recover")
    #expect(await runtime.snapshot().commander == committed)
    #expect(try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent()) == stored)
  }

}
