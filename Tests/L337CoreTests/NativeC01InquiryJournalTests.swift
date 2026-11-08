import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryJournalTests {
  @Test func freshJournalShowsActualEmptyProgressAndCanonicalRequestWithoutAwardingAnything() throws {
    var game = Game(executive: false)
    game.screen = .status
    let commander = game.commander
    let bodies = game.bodies
    game.openC01InquiryJournal()
    #expect(game.screen == .journal)
    let progress = try #require(game.c01InquiryJournalProgress)
    #expect(progress.collectedClueIDs.isEmpty)
    #expect(Set(progress.missingClueIDs) == ScriptBaseClueCatalog.requiredClueIDs)
    let rows = game.c01InquiryJournalRows
    try #require(rows.count == 1)
    #expect(rows[0].title == "Request continuity inquiry")
    #expect(rows[0].key == NativeC01InquiryBoard.requestKey)
    #expect(game.scriptC01InquiryJournalPageIdentity.valid)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.scriptState.savedClueJournal == nil)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }

  @Test func invalidRetainedJournalStaysUnavailableWithoutCreatingOrErasingAwards() {
    var game = Game(executive: false)
    game.screen = .status
    // Intentionally invalid public DATA: empty awards and a foreign owner.
    // No completion, clue award, approval or positive source is constructed.
    game.commander.scriptState.savedClueJournal = .init(owner: UUID())
    let commander = game.commander
    game.openC01InquiryJournal()
    #expect(game.c01InquiryJournalProgress == nil)
    #expect(game.c01InquiryJournalSummary.contains("The retained clue journal is unavailable."))
    #expect(game.c01InquiryJournalRows.count == 1)
    #expect(game.commander == commander)
  }

  @Test func unavailableRequestAndBackUseTheActualFactoryWithoutMutatingTheCommander() throws {
    var game = Game(executive: false)
    game.screen = .status
    try #require(!game.scriptDurabilityAvailable)
    let commander = game.commander
    let bodies = game.bodies
    game.openC01InquiryJournal()
    let list = game.scriptC01InquiryJournalPageIdentity
    game.c01InquiryJournalKey("return")
    #expect(game.c01InquiryJournal.detail && game.c01InquiryJournal.action == .back)
    #expect(game.c01InquiryJournal.review?.allowed == false)
    #expect(game.c01InquiryJournal.review?.presentedIntake == nil)
    #expect(game.scriptC01InquiryJournalPageIdentity != list)
    game.c01InquiryJournalKey("left")
    #expect(game.c01InquiryJournal.action == .back && !game.c01InquiryJournalCanConfirm)
    game.c01InquiryJournalKey("return")
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    #expect(!game.c01InquiryJournal.detail && game.c01InquiryJournal.review == nil)
    game.c01InquiryJournalKey("escape")
    #expect(game.screen == .status && game.commander == commander)
  }
}

/// NONREGISTERED genuine-fixture integration oracle. Uses actual typed menu,
/// existing page-key/current-presentation checks and actual durable writer.
/// Model snapshots supply API proof DATA here; no AppKit painting/render pass
/// or native physical observation is claimed by this test source.
func c01InquiryJournalActualWriterRollbackOracle(
  runtime: GameRuntime, files: ScriptFreightFixture
) async throws {
  _ = try NativeC01CharterArchiveApproval.load()
  _ = try NativeCharterArchiveRegistryApproval.load()
  try #require(await runtime.hasCommanderSaveDestination())
  try #require(await runtime.scriptSaveURL == files.save)
  let start = await runtime.snapshot()
  try #require(start.c01InquiryRequestReview().allowed)
  let intent = MissionUIIntent(action: .journal, game: start, presentation: start.scriptPagePresentation)
  await runtime.missionUICommand(intent)
  let list = await runtime.snapshot()
  try #require(list.screen == .journal && !list.c01InquiryJournal.detail)
  await runtime.scriptPageKey("return", expected: list.scriptPagePresentation)
  let detail = await runtime.snapshot()
  let review = try #require(detail.c01InquiryJournal.review)
  try #require(review.allowed && detail.c01InquiryJournal.action == .back)
  // Old list-page input cannot choose a button on the newly opened detail.
  await runtime.scriptPageKey("left", expected: list.scriptPagePresentation)
  #expect(await runtime.snapshot().c01InquiryJournal.action == .back)
  await runtime.scriptPageKey("left", expected: detail.scriptPagePresentation)
  let before = await runtime.snapshot()
  let caseID = try #require(before.c01InquiryJournal.review?.caseID)
  try #require(before.c01InquiryJournal.action == .accept)
  let parent = files.save.deletingLastPathComponent()
  let disk = try ScriptFinanceTestFixture.files(parent)
  let preserved = try files.blockWrites("c01-journal-request", destination: files.save)
  var restored = false
  defer { if !restored { try? files.restoreWrites(preserved, files: disk, destination: files.save) } }
  await runtime.scriptPageKey("return", expected: before.scriptPagePresentation)
  let refused = await runtime.snapshot()
  #expect(refused.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
  #expect(refused.commander == before.commander && refused.bodies == before.bodies)
  #expect(refused.c01InquiryJournal.detail && refused.c01InquiryJournal.review?.caseID == caseID)
  #expect(try ScriptFinanceTestFixture.files(preserved) == disk)
  try files.restoreWrites(preserved, files: disk, destination: files.save)
  restored = true
  await runtime.scriptPageKey("return", expected: refused.scriptPagePresentation)
  let published = await runtime.snapshot()
  let root = try #require(published.commander.scriptState.savedC01Inquiry)
  #expect(root.caseRecord.id == caseID && root.caseRecord.phase == .requestCase)
  #expect(!published.c01InquiryJournal.detail && published.c01InquiryJournal.review == nil)
  #expect(published.commander.scriptState.instances == before.commander.scriptState.instances)
  #expect(published.commander.credits == before.commander.credits)
  #expect(published.commander.cargo == before.commander.cargo)
  #expect(published.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
  #expect(cold.scriptState.savedC01Inquiry == root)
}
