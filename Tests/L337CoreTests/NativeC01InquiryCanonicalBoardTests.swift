import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryCanonicalBoardTests {
  @Test func unavailableCanonicalRequestCannotStageOrChangeOriginalState() throws {
    var game = Game(executive: false)
    try #require(game.docked && !game.scriptDurabilityAvailable)
    let commander = game.commander
    let bodies = game.bodies
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    let rows = game.c01InquiryRequestRows
    try #require(rows.count == 1)
    #expect(rows[0].title == "Request continuity inquiry")
    #expect(rows[0].inquiry == .requestCase && rows[0].offer == nil)
    #expect(rows[0].key == NativeC01InquiryBoard.requestKey)
    let review = game.c01InquiryRequestReview()
    #expect(!review.allowed && review.caseID == nil && review.presentedIntake == nil)
    #expect(review.issues == ["Choose a commander save destination first."])
    #expect(rows[0].reason == review.issues.first)
    #expect(throws: (any Error).self) { try game.confirmC01InquiryRequest(review) }
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }

  @Test(arguments: ["escape", "back"])
  func existingBoardCancellationClearsOnlyThePendingRequestWithoutAStage(form: String) throws {
    var game = Game(executive: false)
    game.screen = .contracts
    game.contractBoard.rows = game.c01InquiryRequestRows
    try #require(game.contractBoard.rows.count == 1)
    game.contractBoard.selection = 0
    game.contractBoard.detail = true
    game.contractBoard.action = .back
    game.contractBoard.inquiryQuote = game.c01InquiryRequestReview()
    try #require(game.contractBoard.inquiryQuote?.allowed == false)
    let commander = game.commander
    let bodies = game.bodies
    game.contractBoardKey(form == "escape" ? "escape" : "return")
    #expect(!game.contractBoard.detail && game.contractBoard.inquiryQuote == nil)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }
}

/// Actual board navigation only: no selection/private-request injection.
private func c01OpenActualCanonicalRequestReview(_ runtime: GameRuntime) async throws -> Game {
  await runtime.key("contracts-open")
  let shown = await runtime.snapshot()
  try #require(shown.screen == .contracts && !shown.contractBoard.detail)
  let index = try #require(shown.contractBoard.rows.firstIndex { $0.inquiry == .requestCase })
  // Use the existing bounded row controls, not a new command key or stage loop.
  for _ in 0..<shown.contractBoard.rows.count { await runtime.key("up") }
  for _ in 0..<index { await runtime.key("down") }
  await runtime.key("return")
  let reviewed = await runtime.snapshot()
  try #require(reviewed.contractBoard.detail && reviewed.contractBoard.action == .back)
  try #require(reviewed.contractBoard.selected?.inquiry == .requestCase)
  return reviewed
}

/// NONREGISTERED oracle. G1 supplies an actual approved source/current-arrival
/// runtime and its real save fixture. No private request, approval, arrival,
/// source, receipt, completion or native physical evidence is constructed here.
func c01InquiryCanonicalBoardActualWriterRollbackOracle(
  runtime: GameRuntime, files: ScriptFreightFixture
) async throws {
  _ = try NativeC01CharterArchiveApproval.load()
  _ = try NativeCharterArchiveRegistryApproval.load()
  try #require(await runtime.scriptSaveURL == files.save)
  let first = try await c01OpenActualCanonicalRequestReview(runtime)
  let firstReview = try #require(first.contractBoard.inquiryQuote)
  try #require(firstReview.allowed && firstReview.presentedIntake?.role == .intake)
  let firstDisk = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
  await runtime.key("escape")
  let cancelled = await runtime.snapshot()
  #expect(!cancelled.contractBoard.detail && cancelled.contractBoard.inquiryQuote == nil)
  #expect(cancelled.commander == first.commander && cancelled.bodies == first.bodies)
  #expect(try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent()) == firstDisk)

  let shown = try await c01OpenActualCanonicalRequestReview(runtime)
  let review = try #require(shown.contractBoard.inquiryQuote)
  try #require(review.allowed && review.presentedIntake?.role == .intake)
  let caseID = try #require(review.caseID)
  await runtime.key("right")  // Existing Back -> Confirm action selection.
  let before = await runtime.snapshot()
  try #require(before.contractBoard.action == .accept)
  try #require(before.contractBoard.inquiryQuote?.caseID == caseID)
  let parent = files.save.deletingLastPathComponent()
  let disk = try ScriptFinanceTestFixture.files(parent)
  let preserved = try files.blockWrites("c01-canonical-request", destination: files.save)
  var restored = false
  defer {
    if !restored { try? files.restoreWrites(preserved, files: disk, destination: files.save) }
  }
  await runtime.key("return")
  let refused = await runtime.snapshot()
  #expect(refused.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
  #expect(refused.commander == before.commander && refused.bodies == before.bodies)
  #expect(refused.celestials == before.celestials)
  #expect(refused.gameplayRevision == before.gameplayRevision)
  #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
  #expect(refused.contractBoard.detail && refused.contractBoard.action == .accept)
  #expect(refused.contractBoard.inquiryQuote?.caseID == caseID)
  #expect(try ScriptFinanceTestFixture.files(preserved) == disk)
  try files.restoreWrites(preserved, files: disk, destination: files.save)
  restored = true
  await runtime.key("return")
  let committed = await runtime.snapshot()
  let root = try #require(committed.commander.scriptState.savedC01Inquiry)
  #expect(root.shapeValid && root.caseRecord.id == caseID)
  #expect(root.caseRecord.phase == .requestCase)
  #expect(!committed.contractBoard.detail && committed.contractBoard.inquiryQuote == nil)
  #expect(root.caseRecord.mandate.intake == review.presentedIntake)
  #expect(committed.commander.scriptState.instances == before.commander.scriptState.instances)
  #expect(committed.commander.credits == before.commander.credits)
  #expect(committed.commander.cargo == before.commander.cargo)
  #expect(committed.commander.kills == before.commander.kills)
  #expect(committed.commander.legal == before.commander.legal)
  #expect(committed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
  #expect(committed.bodies == before.bodies && committed.celestials == before.celestials)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
  #expect(cold.scriptState.savedC01Inquiry == root)

  // The canonical action now previews the actual unfinished case refusal.
  // It cannot silently start a second case or advance the new case by itself.
  let replayDisk = try ScriptFinanceTestFixture.files(parent)
  let current = try await c01OpenActualCanonicalRequestReview(runtime)
  #expect(current.contractBoard.inquiryQuote?.allowed == false)
  #expect(current.commander.scriptState.savedC01Inquiry == root)
  #expect(current.commander.credits == committed.commander.credits)
  #expect(try ScriptFinanceTestFixture.files(parent) == replayDisk)
}

/// NONREGISTERED no-destination check using G1's real approved/current-arrival
/// request review. A new ordinary runtime with saveURL:nil sets its own actual
/// durability flag false; no approval/request/arrival is constructed or repaired.
func c01InquiryCanonicalRequestNoDestinationOracle(runtime: GameRuntime) async throws {
  _ = try NativeC01CharterArchiveApproval.load()
  _ = try NativeCharterArchiveRegistryApproval.load()
  try #require(await runtime.hasCommanderSaveDestination())
  let actual = await runtime.snapshot()
  try #require(actual.scriptDurabilityAvailable && !actual.isMissionTrial)
  let realReview = actual.c01InquiryRequestReview()
  try #require(realReview.allowed && realReview.caseID != nil && realReview.presentedIntake != nil)
  let unbound = GameRuntime(game: actual, saveURL: nil)
  try #require(await unbound.hasCommanderSaveDestination() == false)
  let unavailable = await unbound.snapshot()
  try #require(!unavailable.scriptDurabilityAvailable)
  let refusedPreview = unavailable.c01InquiryRequestReview()
  #expect(!refusedPreview.allowed && refusedPreview.caseID == nil)
  #expect(refusedPreview.presentedIntake == nil)
  #expect(refusedPreview.issues == ["Choose a commander save destination first."])
  var candidate = unavailable
  var rejectedForNoDestination = false
  do { try candidate.confirmC01InquiryRequest(realReview) }
  catch NativeC01InquiryIntakeFailure.unavailable { rejectedForNoDestination = true }
  // Requiring the explicit unavailable error distinguishes this new leading
  // guard from later stale-arrival/stale-request refusal after runtime reset.
  #expect(rejectedForNoDestination)
  #expect(candidate.commander == unavailable.commander && candidate.bodies == unavailable.bodies)
  #expect(candidate.nativeStationRuntimeEpoch == unavailable.nativeStationRuntimeEpoch)
  #expect(candidate.gameplayRevision == unavailable.gameplayRevision)
  #expect(candidate.commander.scriptState.savedC01Inquiry == unavailable.commander.scriptState.savedC01Inquiry)
}
