import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryJournalRestoreTests {
  @Test func realWriterFailureAndFailedLoadPreserveJournalButColdLoadRejectsOldSignedPage()
    async throws
  {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    var game = try files.policyGame()
    game.scriptPacks = []
    let runtime = GameRuntime(game: game, saveURL: files.save)
    try await runtime.save(to: files.save)
    let start = await runtime.snapshot()
    try #require(start.commander.scriptState.savedC01Inquiry == nil)
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let list = await runtime.snapshot()
    try #require(list.screen == .journal)
    await runtime.scriptPageKey("return", expected: list.scriptPagePresentation)
    let reviewed = await runtime.snapshot()
    try #require(reviewed.c01InquiryJournal.detail && reviewed.c01InquiryJournal.action == .back)
    // This is an ordinary root-absent runtime. No approved intake, case or birth is invented.
    try #require(reviewed.c01InquiryJournal.review?.allowed == false)
    try #require(reviewed.c01InquiryJournal.review?.caseID == nil)
    let parent = files.save.deletingLastPathComponent()
    let disk = try ScriptFinanceTestFixture.files(parent)
    let preserved = try files.blockWrites("journal-ordinary-save", destination: files.save)
    var restored = false
    defer {
      if !restored { try? files.restoreWrites(preserved, files: disk, destination: files.save) }
    }
    var writeRefused = false
    do { try await runtime.save(to: files.save) }
    catch { writeRefused = true }
    #expect(writeRefused)
    let refused = await runtime.snapshot()
    #expect(refused.commander == reviewed.commander && refused.bodies == reviewed.bodies)
    #expect(refused.celestials == reviewed.celestials)
    #expect(refused.scriptPagePresentation == reviewed.scriptPagePresentation)
    #expect(refused.c01InquiryJournal.detail && refused.c01InquiryJournal.action == .back)
    #expect(refused.c01InquiryJournal.review?.caseID == nil)
    #expect(refused.nativeStationRuntimeEpoch == reviewed.nativeStationRuntimeEpoch)
    #expect(refused.gameplayRevision == reviewed.gameplayRevision)
    #expect(await runtime.scriptSaveURL == files.save)
    #expect(try ScriptFinanceTestFixture.files(preserved) == disk)
    try files.restoreWrites(preserved, files: disk, destination: files.save)
    restored = true
    try await runtime.save(to: files.save)
    let retried = await runtime.snapshot()
    #expect(retried.scriptPagePresentation == reviewed.scriptPagePresentation)
    #expect(retried.c01InquiryJournal.detail && retried.commander.scriptState.savedC01Inquiry == nil)
    let savedDisk = try ScriptFinanceTestFixture.files(parent)

    let malformed = files.root.appendingPathComponent("malformed-journal-restore.json")
    try Data("{".utf8).write(to: malformed)
    var loadRefused = false
    do { try await runtime.load(from: malformed, persistMigrations: false) }
    catch { loadRefused = true }
    #expect(loadRefused)
    let failedLoad = await runtime.snapshot()
    #expect(failedLoad.commander == retried.commander && failedLoad.bodies == retried.bodies)
    #expect(failedLoad.scriptPagePresentation == retried.scriptPagePresentation)
    #expect(failedLoad.nativeStationRuntimeEpoch == retried.nativeStationRuntimeEpoch)
    #expect(await runtime.scriptSaveURL == files.save)
    #expect(try ScriptFinanceTestFixture.files(parent) == savedDisk)
    // A failed load must not consume the current Journal proof or reset its transient panel.
    await runtime.scriptPageKey("escape", expected: failedLoad.scriptPagePresentation)
    let currentList = await runtime.snapshot()
    try #require(currentList.screen == .journal && !currentList.c01InquiryJournal.detail)
    await runtime.scriptPageKey("return", expected: currentList.scriptPagePresentation)
    let old = await runtime.snapshot()
    try #require(old.c01InquiryJournal.detail)
    let oldIntent = MissionUIIntent(action: .journal, game: old,
      presentation: old.scriptPagePresentation)

    try await runtime.load(from: files.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    try #require(cold.screen == .status && cold.commander.scriptState.savedC01Inquiry == nil)
    #expect(cold.c01InquiryJournal.review == nil && !cold.c01InquiryJournal.detail)
    #expect(cold.nativeStationRuntimeEpoch != old.nativeStationRuntimeEpoch)
    // Captured pre-load menu intent cannot reopen Journal in the replacement runtime state.
    await runtime.missionUICommand(oldIntent)
    #expect(await runtime.snapshot().screen == .status)
    await runtime.missionUICommand(.init(action: .journal, game: cold,
      presentation: cold.scriptPagePresentation))
    let reopened = await runtime.snapshot()
    await runtime.scriptPageKey("return", expected: reopened.scriptPagePresentation)
    let detail = await runtime.snapshot()
    try #require(detail.screen == .journal && detail.c01InquiryJournal.detail)
    try #require(detail.scriptPagePresentation != old.scriptPagePresentation)
    await runtime.scriptPageKey("escape", expected: old.scriptPagePresentation)
    let stale = await runtime.snapshot()
    #expect(stale.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(stale.c01InquiryJournal.detail)
    #expect(stale.scriptPagePresentation == detail.scriptPagePresentation)
    #expect(stale.commander == detail.commander && stale.bodies == detail.bodies)
    #expect(stale.commander.scriptState.savedC01Inquiry == nil)
    #expect(try ScriptFinanceTestFixture.files(parent) == savedDisk)
    await runtime.scriptPageKey("escape", expected: stale.scriptPagePresentation)
    #expect(await runtime.snapshot().c01InquiryJournal.detail == false)
  }

  @Test func canonicalBoardAndJournalRefuseEachOthersPreviouslySignedPageWithoutAWrite()
    async throws
  {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    var game = try files.policyGame()
    game.scriptPacks = []
    let runtime = GameRuntime(game: game, saveURL: files.save)
    try await runtime.save(to: files.save)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let journal = await runtime.snapshot()
    try #require(journal.screen == .journal && !journal.c01InquiryJournal.detail)
    await runtime.scriptPageKey("escape", expected: journal.scriptPagePresentation)
    let station = await runtime.snapshot()
    try #require(station.screen == .status)
    await runtime.missionUICommand(.init(action: .contracts, game: station,
      presentation: station.scriptPagePresentation))
    let board = await runtime.snapshot()
    try #require(board.screen == .contracts && !board.contractBoard.detail)
    let requestIndex = try #require(board.contractBoard.rows.firstIndex { $0.inquiry == .requestCase })
    // Actual signed row navigation only. No row, quote or private request is injected.
    for _ in 0..<board.contractBoard.rows.count {
      let current = await runtime.snapshot()
      await runtime.scriptPageKey("up", expected: current.scriptPagePresentation)
    }
    for _ in 0..<requestIndex {
      let current = await runtime.snapshot()
      await runtime.scriptPageKey("down", expected: current.scriptPagePresentation)
    }
    let selected = await runtime.snapshot()
    try #require(selected.contractBoard.selected?.inquiry == .requestCase)
    try #require(!selected.contractBoard.detail)
    let parent = files.save.deletingLastPathComponent()
    let boardDisk = try ScriptFinanceTestFixture.files(parent)
    await runtime.scriptPageKey("return", expected: journal.scriptPagePresentation)
    let refusedOnBoard = await runtime.snapshot()
    #expect(refusedOnBoard.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(refusedOnBoard.screen == .contracts && !refusedOnBoard.contractBoard.detail)
    #expect(refusedOnBoard.scriptPagePresentation == selected.scriptPagePresentation)
    #expect(refusedOnBoard.contractBoard.inquiryQuote == nil)
    #expect(refusedOnBoard.commander == selected.commander && refusedOnBoard.bodies == selected.bodies)
    #expect(try ScriptFinanceTestFixture.files(parent) == boardDisk)

    await runtime.missionUICommand(.init(action: .journal, game: refusedOnBoard,
      presentation: refusedOnBoard.scriptPagePresentation))
    let currentJournal = await runtime.snapshot()
    try #require(currentJournal.screen == .journal && !currentJournal.c01InquiryJournal.detail)
    let journalDisk = try ScriptFinanceTestFixture.files(parent)
    await runtime.scriptPageKey("return", expected: selected.scriptPagePresentation)
    let refusedOnJournal = await runtime.snapshot()
    #expect(refusedOnJournal.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(refusedOnJournal.screen == .journal && !refusedOnJournal.c01InquiryJournal.detail)
    #expect(refusedOnJournal.scriptPagePresentation == currentJournal.scriptPagePresentation)
    #expect(refusedOnJournal.c01InquiryJournal.review == nil)
    #expect(refusedOnJournal.commander == currentJournal.commander)
    #expect(refusedOnJournal.bodies == currentJournal.bodies)
    #expect(refusedOnJournal.commander.scriptState.savedC01Inquiry == nil)
    #expect(try ScriptFinanceTestFixture.files(parent) == journalDisk)
    // The actual current proof still opens the real unavailable review, defaulting to Back.
    await runtime.scriptPageKey("return", expected: refusedOnJournal.scriptPagePresentation)
    let actual = await runtime.snapshot()
    #expect(actual.c01InquiryJournal.detail && actual.c01InquiryJournal.action == .back)
    #expect(actual.c01InquiryJournal.review?.allowed == false)
    #expect(actual.c01InquiryJournal.review?.caseID == nil)
    #expect(actual.commander == currentJournal.commander)
    #expect(actual.commander.scriptState.savedC01Inquiry == nil)
  }
}
