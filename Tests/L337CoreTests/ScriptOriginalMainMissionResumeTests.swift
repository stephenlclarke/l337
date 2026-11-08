import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct ScriptOriginalMainMissionResumeTests {
  @Test func mainDispatchMissingContentColdResumeKeepsOnePackageAndRequiresDurablePublication()
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    // The existing MAIN fixture uses actual swept entry and the retained starter.
    // This is independent of the earned Okapi/Salamander owning resume case.
    let runtime = try await fixture.runtime()
    let id = try await fixture.accept(runtime)
    let accepted = await runtime.snapshot()
    try #require(accepted.commander.shipID == "SH025")
    try #require(accepted.nativeMainStationDockEvidenceIsCurrent)
    let original = try #require(accepted.commander.scriptState.instances[id])
    let custody = try #require(original.courier)
    let job = try #require(original.contract)
    try #require(original.outcome == .active && original.suspension == nil)
    try #require(custody.terminal == nil && job.station.stationClass == "main-orbital")
    try #require(accepted.commander.scriptState.pendingEvents.isEmpty)
    let directory = fixture.save.deletingLastPathComponent()
    let missing = fixture.files.root.appendingPathComponent("missing-main-resume-library")
    let installed = fixture.files.root.appendingPathComponent("restored-main-resume-library")

    // Let the unavailable-content reader suspend the actual accepted package, then
    // save and discard this runtime. No test manufactures a suspension or custody.
    await runtime.loadScriptPacks(directory: missing)
    let unavailable = await runtime.snapshot()
    let suspended = try #require(unavailable.commander.scriptState.instances[id])
    try #require(suspended.suspension != nil && suspended.outcome == .active)
    #expect(suspended.courier == custody && suspended.contract == job)
    var suspendedCommander = accepted.commander
    suspendedCommander.scriptState.instances[id]?.suspension = suspended.suspension
    #expect(unavailable.commander == suspendedCommander)
    try await runtime.save(to: fixture.save)
    let savedSuspension = await runtime.snapshot()
    let unavailableFiles = try ScriptFinanceTestFixture.files(directory)

    let recovering = GameRuntime(game: Game(executive: false))
    await recovering.loadScriptPacks(directory: missing)
    try await recovering.load(from: fixture.save, persistMigrations: false)
    let coldMissing = await recovering.snapshot()
    let coldState = try #require(coldMissing.commander.scriptState.instances[id])
    try #require(coldMissing.scriptPack(for: coldState) == nil)
    try #require(coldMissing.scriptDurabilityAvailable && coldState.suspension != nil)
    #expect(coldMissing.commander == savedSuspension.commander)
    #expect(coldState.courier == custody && coldState.contract == job)
    #expect(try ScriptFinanceTestFixture.files(directory) == unavailableFiles)
    let missingEntryCandidate = coldMissing.scriptGallery.first { $0.savedInstance == id }
    let missingEntry = try #require(missingEntryCandidate)
    #expect(missingEntry.status == .locked)
    #expect(coldMissing.commander == savedSuspension.commander)
    await #expect(throws: MissionPackError.self) { try await recovering.resumeScriptMission(id) }
    let contentDenied = await recovering.snapshot()
    #expect(contentDenied.commander == coldMissing.commander)
    #expect(contentDenied.scriptWorldSave == coldMissing.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(directory) == unavailableFiles)

    // Exact pack installation restores content availability, not mission progress.
    try await recovering.installScriptPack(
      from: ScriptPackLibrary.bundledSealedDispatchDirectory, destination: installed)
    let contentRestored = await recovering.snapshot()
    let retained = try #require(contentRestored.commander.scriptState.instances[id])
    try #require(contentRestored.scriptPack(for: retained)?.digest == fixture.pack.digest)
    try #require(retained.suspension != nil)
    #expect(contentRestored.commander == contentDenied.commander)
    #expect(try ScriptFinanceTestFixture.files(directory) == unavailableFiles)

    // Reconstructing the genuine saved case without a bound writer must not clear
    // its suspension in memory, even though the exact pack is available again.
    let unbound = GameRuntime(game: contentRestored)
    let unboundBefore = await unbound.snapshot()
    try #require(!unboundBefore.scriptDurabilityAvailable && unboundBefore.requiresScriptDurability)
    await #expect(throws: MissionPackError.self) { try await unbound.resumeScriptMission(id) }
    let writerDenied = await unbound.snapshot()
    #expect(writerDenied.commander == unboundBefore.commander)
    #expect(writerDenied.scriptWorldSave == unboundBefore.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(directory) == unavailableFiles)

    // A real failed write preserves the suspended current save. Restore that same
    // directory and retry on the independently loaded actor, not the original one.
    let held = try fixture.files.blockWrites("original-main-resume")
    await #expect(throws: (any Error).self) { try await recovering.resumeScriptMission(id) }
    let refused = await recovering.snapshot()
    #expect(refused.commander == contentRestored.commander)
    #expect(refused.scriptWorldSave == contentRestored.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(held) == unavailableFiles)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(held, files: unavailableFiles)
    try await recovering.resumeScriptMission(id)
    let resumed = await recovering.snapshot()
    let active = try #require(resumed.commander.scriptState.instances[id])
    try #require(active.outcome == .active && active.suspension == nil)
    var expected = contentRestored.commander
    expected.scriptState.instances[id]?.suspension = nil
    #expect(resumed.commander == expected)
    #expect(active.courier == custody && active.contract == job)
    #expect(active.receipts == original.receipts && active.milestones == original.milestones)
    #expect(active.completionReceipt == nil && resumed.commander.scriptState.pendingEvents.isEmpty)
    #expect(OriginalServiceReservationPolicy.activeCount(resumed.commander.scriptState)
      == OriginalServiceReservationPolicy.activeCount(accepted.commander.scriptState))
    let resumedEntryCandidate = resumed.scriptGallery.first { $0.savedInstance == id }
    let resumedEntry = try #require(resumedEntryCandidate)
    #expect(resumedEntry.status == .active && resumedEntry.completed == original.milestones.count)
    #expect(resumed.commander == expected)

    let (persisted, world) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
    #expect(persisted == resumed.commander && world.consistent(with: persisted))
    let committedFiles = try ScriptFinanceTestFixture.files(directory)
    let cold = GameRuntime(game: Game(executive: false))
    await cold.loadScriptPacks(directory: installed)
    try await cold.load(from: fixture.save, persistMigrations: false)
    let reloaded = await cold.snapshot()
    #expect(reloaded.commander == resumed.commander)
    #expect(reloaded.scriptWorldSave == resumed.scriptWorldSave)
    try #require(reloaded.scriptDurabilityAvailable && reloaded.commander.valid)
    let reloadedState = try #require(reloaded.commander.scriptState.instances[id])
    #expect(reloadedState.courier == custody && reloadedState.contract == job)
    #expect(reloadedState.suspension == nil && reloadedState.outcome == .active)
    #expect(try ScriptFinanceTestFixture.files(directory) == committedFiles)
    try await cold.resumeScriptMission(id)
    let repeated = await cold.snapshot()
    #expect(repeated.commander == reloaded.commander)
    #expect(repeated.scriptWorldSave == reloaded.scriptWorldSave)
    // A successful resume republishes a fresh save generation even when its
    // mission state is unchanged. Read the current pointer after publication.
    let (republished, republishedWorld) = try ScriptSaveStore.read(
      Data(contentsOf: fixture.save), from: fixture.save)
    #expect(republished == repeated.commander)
    #expect(republishedWorld == repeated.scriptWorldSave)
    #expect(republishedWorld.consistent(with: republished))
  }
}
