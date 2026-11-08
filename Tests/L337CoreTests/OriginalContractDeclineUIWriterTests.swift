import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalContractDeclineUIWriterTests {
  private static func review(
    _ runtime: GameRuntime, board: String, offer: UUID
  ) async throws -> Game {
    await runtime.key("contracts-open")
    let listed = await runtime.snapshot()
    try #require(listed.screen == .contracts)
    let index = try #require(listed.contractBoard.rows.firstIndex {
      $0.board == board && $0.offer?.id == offer
    })
    for _ in 0..<abs(index - listed.contractBoard.selection) {
      await runtime.key(index < listed.contractBoard.selection ? "up" : "down")
    }
    await runtime.key("return")
    await runtime.key("right")
    await runtime.key("right")
    let ready = await runtime.snapshot()
    try #require(ready.contractBoard.detail && ready.contractBoard.action == .decline)
    try #require(ready.contractBoard.selected?.board == board)
    try #require(ready.contractBoard.selected?.offer?.id == offer)
    try #require(ready.contractBoard.quote?.offer == offer)
    try #require(ready.scriptPagePresentation.valid)
    return ready
  }

  private static func confirm(
    _ runtime: GameRuntime, review: Game, click: Bool
  ) async throws {
    let page = review.scriptPagePresentation
    try #require(page.valid && review.screen == .contracts && review.contractBoard.detail)
    if click {
      let button = try #require(ContractBoardLayout(
        width: review.viewportWidth, height: review.viewportHeight).actions.first { $0.0 == .decline }?.1)
      await runtime.scriptPageClick(x: button.x + 4, y: button.y + 4, expected: page)
    } else {
      await runtime.scriptPageKey("return", expected: page)
    }
  }

  @Test(arguments: [false, true])
  func reviewedOriginalDeclineRequiresWriterThroughKeyboardAndClickAndSurvivesColdRead(click: Bool)
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (key, offer) = try await fixture.offer(runtime)
    let reviewed = try await Self.review(runtime, board: key, offer: offer.id)
    try #require(reviewed.nativeMainStationDockEvidenceIsCurrent)
    try #require(reviewed.commander.contracts.boards[key]?.offers.first?.status == .available)
    try #require(reviewed.commander.scriptState.instances.isEmpty)
    let directory = fixture.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)

    // Keep the genuine reviewed row, but use actual unbound actor construction: no flag grant.
    let unbound = GameRuntime(game: reviewed)
    let unboundBefore = await unbound.snapshot()
    try #require(!unboundBefore.scriptDurabilityAvailable && unboundBefore.requiresScriptDurability)
    try #require(unboundBefore.contractBoard.detail && unboundBefore.contractBoard.action == .decline)
    var control = unboundBefore
    try control.declineContract(board: key, offer: offer.id)
    try #require(control.commander.contracts.boards[key]?.offers.first?.status == .declined)
    try #require(await unbound.snapshot().commander == unboundBefore.commander)
    // The existing refusal behavior reopens the list. Capture that UI-only expected world
    // without discarding any saved field or allowing a business-state difference.
    var reviewOnly = unboundBefore
    reviewOnly.openContractBoard()
    try #require(reviewOnly.commander == unboundBefore.commander)
    try await Self.confirm(unbound, review: unboundBefore, click: click)
    let denied = await unbound.snapshot()
    #expect(denied.commander == unboundBefore.commander)
    #expect(denied.scriptWorldSave == reviewOnly.scriptWorldSave)
    #expect(denied.screen == .contracts && !denied.contractBoard.detail && denied.contractBoard.quote == nil)
    #expect(denied.message.contains("writable commander save"))
    #expect(try ScriptFinanceTestFixture.files(directory) == files)

    // Real bound input reaches its writer. Failure restores the exact review and all property.
    let before = await runtime.snapshot()
    let held = try fixture.files.blockWrites("ui-decline")
    try await Self.confirm(runtime, review: before, click: click)
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.scriptWorldSave == before.scriptWorldSave)
    #expect(failed.contractBoard.detail && failed.contractBoard.action == .decline)
    #expect(failed.message.contains("MISSION SAVE FAILED"))
    #expect(try ScriptFinanceTestFixture.files(held) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try fixture.files.restoreWrites(held, files: files)
    let retry = await runtime.snapshot()
    try await Self.confirm(runtime, review: retry, click: click)
    let declined = await runtime.snapshot()
    var expected = before.commander
    expected.contracts.boards[key]?.offers[0].status = .declined
    #expect(declined.commander == expected)
    #expect(declined.nativeMainStationDockEvidenceIsCurrent)
    #expect(declined.screen == .contracts && !declined.contractBoard.detail && declined.contractBoard.quote == nil)
    #expect(declined.message == "OFFER DECLINED")
    #expect(!declined.contractBoard.rows.contains { $0.board == key && $0.offer?.id == offer.id })
    let committedFiles = try ScriptFinanceTestFixture.files(directory)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: fixture.save)
    #expect(persisted.contracts == expected.contracts)
    #expect(persisted.credits == before.commander.credits && persisted.cargo == before.commander.cargo)
    #expect(persisted.equipmentInventory == before.commander.equipmentInventory)
    #expect(persisted.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(persisted.nativePeople == before.commander.nativePeople)
    #expect(persisted.scriptState == before.commander.scriptState)

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
    #expect(!restored.contractBoard.rows.contains { $0.board == key && $0.offer?.id == offer.id })
    #expect(try ScriptFinanceTestFixture.files(directory) == committedFiles)
    // A stale callback for the declined original cannot act on another offer after cold load.
    try await Self.confirm(cold, review: reviewed, click: click)
    let stale = await cold.snapshot()
    #expect(stale.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(stale.commander == restored.commander && stale.scriptWorldSave == restored.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(directory) == committedFiles)
  }
}
