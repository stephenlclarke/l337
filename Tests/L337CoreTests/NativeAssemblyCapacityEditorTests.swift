import Foundation
import Testing

@testable import L337Core

struct NativeAssemblyCapacityEditorTests {
  private func open(_ runtime: GameRuntime) async throws -> Game {
    let before = await runtime.snapshot()
    try #require(MissionUIAction.assemblyCapacityConsole.isEnabled(in: before))
    await runtime.missionUICommand(.init(action: .assemblyCapacityConsole, game: before,
      presentation: before.scriptPagePresentation))
    let opened = await runtime.snapshot()
    try #require(opened.screen == .inventory && opened.nativeAssemblyCapacityEditorDisplay != nil)
    guard case .assemblyCapacity? = opened.scriptPagePresentation.page else {
      throw MissionPackError("The actual editor must expose a typed native page.")
    }
    return opened
  }

  @discardableResult
  private func press(_ runtime: GameRuntime, _ key: String) async -> Game {
    let painted = await runtime.snapshot()
    await runtime.scriptPageKey(key, expected: painted.scriptPagePresentation)
    return await runtime.snapshot()
  }

  private func fillWaitingAndConfirm(_ runtime: GameRuntime) async throws {
    for _ in 0..<5 {
      await press(runtime, "down")
      await press(runtime, "right")
    }
    await press(runtime, "down")
    let review = await press(runtime, "return")
    try #require(review.nativeAssemblyCapacityEditorDisplay?.confirmation != nil)
    try #require(review.nativeAssemblyCapacityEditorDisplay?.confirms == false)
    await press(runtime, "right")
  }

  @Test func typedEditorInputWriterRollbackRetryAndBothSidesColdRecallPreserveOriginalMission()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let original = try #require(collected.assemblyOfOrbitsMission)
    _ = try await open(fixture.runtime)
    try await fillWaitingAndConfirm(fixture.runtime)
    let ready = await fixture.runtime.snapshot()
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let held = try fixture.files.blockWrites("assembly-editor-save")
    let refused = await press(fixture.runtime, "return")
    #expect(refused.commander == ready.commander && refused.bodies == ready.bodies)
    #expect(refused.nativeAssemblyCapacityEditorDisplay?.confirmation != nil)
    #expect(refused.nativeAssemblyCapacityEditorDisplay?.confirms == true)
    #expect(refused.nativeAssemblyCapacityEditorDisplay?.dirty == true)
    #expect(refused.nativeAssemblyCapacityEditorDisplay?.message.contains("Save failed") == true)
    #expect(try ScriptFinanceTestFixture.files(held) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(held, files: files)
    let saved = await press(fixture.runtime, "return")
    let port = try #require(saved.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts?["port"])
    #expect(port.choices.count == 5 && port.choices.allSatisfy { $0.allocation == .waiting })
    #expect(saved.nativeAssemblyCapacityEditorDisplay?.dirty == false)
    for _ in 0..<6 { await press(fixture.runtime, "up") }
    let other = await press(fixture.runtime, "right")
    #expect(other.nativeAssemblyCapacityEditorDisplay?.side == "STARBOARD")
    try await fillWaitingAndConfirm(fixture.runtime)
    let both = await press(fixture.runtime, "return")
    let starboard = try #require(both.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts?["starboard"])
    #expect(starboard.choices.count == 5 && starboard.side == .starboard)
    #expect(both.commander.credits == collected.commander.credits && both.commander.cargo == collected.commander.cargo)
    #expect(both.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(both.commander.nativePeople == collected.commander.nativePeople)
    #expect(both.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(both.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(both.assemblyOfOrbitsMission?.gearIssues == original.gearIssues)
    #expect(both.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
    let oldPage = both.scriptPagePresentation
    var coldGame = Game(executive: false)
    coldGame.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledAssemblyOfOrbitsDirectory)]
    let cold = GameRuntime(game: coldGame)
    try await cold.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.nativeAssemblyCapacityEditorDisplay == nil)
    #expect(loaded.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts == ["port": port, "starboard": starboard])
    await cold.scriptPageKey("return", expected: oldPage)
    let unchanged = await cold.snapshot()
    #expect(unchanged.commander == loaded.commander)
    let recalled = try await open(cold)
    #expect(recalled.nativeAssemblyCapacityEditorDisplay?.rows[1].contains("Waiting") == true)
    // Clear only port through the same actual confirmation and writer route.
    for _ in 0..<7 { await press(cold, "down") }
    await press(cold, "return")
    await press(cold, "right")
    let beforeClear = await cold.snapshot()
    let clearFiles = try ScriptFinanceTestFixture.files(directory)
    let clearHeld = try fixture.files.blockWrites("assembly-editor-clear")
    let clearRefused = await press(cold, "return")
    #expect(clearRefused.commander == beforeClear.commander)
    #expect(try ScriptFinanceTestFixture.files(clearHeld) == clearFiles)
    try fixture.files.restoreWrites(clearHeld, files: clearFiles)
    let cleared = await press(cold, "return")
    #expect(cleared.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts == ["starboard": starboard])
    #expect(cleared.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(cleared.commander.equipmentInventory == collected.commander.equipmentInventory)
  }

  @Test func backAndDefaultConfirmationDiscardUnsavedEditsWhileBothNativeRenderPathsExposePlanning()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    let unaccepted = await fixture.runtime.snapshot()
    #expect(!MissionUIAction.assemblyCapacityConsole.isEnabled(in: unaccepted))
    let accepted = try await fixture.confirm(.accept)
    #expect(!MissionUIAction.assemblyCapacityConsole.isEnabled(in: accepted))
    let collected = try await fixture.confirm(.collectReference)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let opened = try await open(fixture.runtime)
    let compact = Display.render(opened, rasterizeGraphics: false)
    let responsive = Display.presentation(opened, width: 512, height: 518)
    #expect(compact.labels.contains { $0.text.uppercased().contains("ASSEMBLY PLANNING") })
    #expect(responsive.labels.contains { $0.text.uppercased().contains("NO CREWS DISPATCHED") })
    #expect(responsive.inventoryInteraction == nil)
    #expect(responsive.labels.allSatisfy { $0.bounds.x >= 0 && $0.bounds.y >= 0
      && $0.bounds.maxX <= 512 && $0.bounds.maxY <= 518 })
    await press(fixture.runtime, "down")
    await press(fixture.runtime, "right")
    for _ in 0..<5 { await press(fixture.runtime, "down") }
    let confirm = await press(fixture.runtime, "return")
    #expect(confirm.nativeAssemblyCapacityEditorDisplay?.confirms == false)
    let back = await press(fixture.runtime, "return")
    #expect(back.nativeAssemblyCapacityEditorDisplay?.confirmation == nil)
    #expect(back.commander == collected.commander)
    let closed = await press(fixture.runtime, "escape")
    #expect(closed.nativeAssemblyCapacityEditorDisplay == nil && closed.screen == collected.screen)
    #expect(closed.commander == collected.commander)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
    let reopened = try await open(fixture.runtime)
    #expect(reopened.nativeAssemblyCapacityEditorDisplay?.rows[1].contains("Unsubmitted") == true)
  }

  @Test func oldPaintedKeysAndActualConcurrentCasePublicationCannotRefreshAwayCapturedContext()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    _ = try await fixture.confirm(.collectReference)
    let opened = try await open(fixture.runtime)
    let moved = await press(fixture.runtime, "down")
    await fixture.runtime.scriptPageKey("right", expected: opened.scriptPagePresentation)
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == moved.commander)
    #expect(refused.nativeAssemblyCapacityEditorDisplay?.rows == moved.nativeAssemblyCapacityEditorDisplay?.rows)
    let context = try await fixture.runtime.assemblyCapacityContext()
    let other = try NativeAssemblyCapacityEditorSession.emptyModel(mission: context.mission, side: .starboard)
    _ = try await fixture.runtime.saveAssemblyCapacityDraft(other, context: context)
    let published = await fixture.runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let stale = await press(fixture.runtime, "right")
    #expect(stale.nativeAssemblyCapacityEditorDisplay?.message.contains("console changed") == true)
    #expect(stale.commander == published.commander)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
    await press(fixture.runtime, "escape")
    let fresh = try await open(fixture.runtime)
    #expect(fresh.nativeAssemblyCapacityEditorDisplay?.side == "PORT")
    let recalled = await press(fixture.runtime, "right")
    #expect(recalled.nativeAssemblyCapacityEditorDisplay?.side == "STARBOARD")
    #expect(recalled.commander == published.commander)
  }
}
