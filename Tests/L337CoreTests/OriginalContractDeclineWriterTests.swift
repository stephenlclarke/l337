import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalContractDeclineWriterTests {
  @Test func originalMainBoardDeclineRequiresWriterAndSurvivesRollbackRetryAndColdRead() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    // Reuse the existing actual main berth. No secondary-source hull acquisition or new role.
    let runtime = try await fixture.runtime()
    let (key, offer) = try await fixture.offer(runtime)
    let generated = await runtime.snapshot()
    try #require(generated.docked && generated.dockedAtMainStation)
    try #require(generated.nativeMainStationDockEvidenceIsCurrent)
    let board = try #require(generated.commander.contracts.boards[key])
    try #require(board.valid && board.station.stationClass == "main-orbital")
    try #require(board.offers.first?.id == offer.id && offer.status == .available)
    try #require(generated.commander.scriptState.instances.isEmpty)
    let directory = fixture.save.deletingLastPathComponent()
    let originalFiles = try ScriptFinanceTestFixture.files(directory)

    // Actual actor construction removes live dock authority and the save binding. Retained
    // main-board value-model eligibility alone must not silently commit an in-memory decline.
    let unbound = GameRuntime(game: generated)
    let unboundBefore = await unbound.snapshot()
    try #require(unboundBefore.requiresScriptDurability && !unboundBefore.scriptDurabilityAvailable)
    try #require(unboundBefore.commander.contracts.boards[key] == board)
    var control = unboundBefore
    try control.declineContract(board: key, offer: offer.id)
    try #require(control.commander.contracts.boards[key]?.offers.first?.status == .declined)
    await #expect(throws: MissionPackError.self) {
      try await unbound.declineContract(board: key, offer: offer.id)
    }
    let denied = await unbound.snapshot()
    #expect(denied.commander == unboundBefore.commander)
    #expect(denied.scriptWorldSave == unboundBefore.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(directory) == originalFiles)

    // An actual writer failure must roll back the same native offer and preserve every file.
    let before = await runtime.snapshot()
    let held = try fixture.files.blockWrites("contract-decline")
    await #expect(throws: (any Error).self) {
      try await runtime.declineContract(board: key, offer: offer.id)
    }
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.scriptWorldSave == before.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(held) == originalFiles)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(held, files: originalFiles)
    try await runtime.declineContract(board: key, offer: offer.id)
    let declined = await runtime.snapshot()
    var expected = before.commander
    expected.contracts.boards[key]?.offers[0].status = .declined
    #expect(declined.commander == expected)
    #expect(declined.nativeMainStationDockEvidenceIsCurrent)
    #expect(declined.commander.scriptState.instances.isEmpty)
    let committedFiles = try ScriptFinanceTestFixture.files(directory)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: fixture.save)
    #expect(persisted.contracts == expected.contracts)
    #expect(persisted.credits == before.commander.credits && persisted.cargo == before.commander.cargo)
    #expect(persisted.equipmentInventory == before.commander.equipmentInventory)
    #expect(persisted.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(persisted.nativePeople == before.commander.nativePeople)
    #expect(persisted.scriptState == before.commander.scriptState)

    // The current reader keeps the actual declined identity/status and rebinds its own writer.
    var loading = Game(executive: false)
    loading.scriptPacks = [fixture.pack]
    let cold = GameRuntime(game: loading)
    try await cold.load(from: fixture.save, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.commander.contracts == persisted.contracts)
    #expect(restored.commander.credits == persisted.credits && restored.commander.cargo == persisted.cargo)
    #expect(restored.commander.equipmentInventory == persisted.equipmentInventory)
    #expect(restored.commander.equipmentPurchaseHistory == persisted.equipmentPurchaseHistory)
    #expect(restored.commander.nativePeople == persisted.nativePeople)
    #expect(restored.commander.scriptState == persisted.scriptState)
    #expect(restored.commander.valid && restored.scriptDurabilityAvailable)
    #expect(try ScriptFinanceTestFixture.files(directory) == committedFiles)
    await #expect(throws: MissionPackError.self) {
      try await cold.declineContract(board: key, offer: offer.id)
    }
    let repeated = await cold.snapshot()
    #expect(repeated.commander == restored.commander && repeated.scriptWorldSave == restored.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(directory) == committedFiles)
  }
}
