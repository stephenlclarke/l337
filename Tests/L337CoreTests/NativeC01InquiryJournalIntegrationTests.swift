import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryJournalIntegrationTests {
  @Test func menuUsesVisibleJournalActionAndRefusesTextAndUnavailableScreens() {
    var game = Game(executive: false)
    game.screen = .status
    #expect(MissionUIAction(rawValue: "journal-open") == .journal)
    #expect(MissionUIAction.journal.title == "Journal")
    #expect(MissionUIAction.journal.isEnabled(in: game))
    for screen in [Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff] {
      game.screen = screen
      game.key("journal-open")
      #expect(game.screen == screen)
    }
    game.screen = .chart
    game.mapSearch.active = true
    #expect(!MissionUIAction.journal.isEnabled(in: game))
    game.key("journal-open")
    #expect(game.screen == .chart)
  }

  @Test func normalNavigationAndPausedReaderKeepActualCommanderAndClockUnchanged() {
    var game = Game(executive: false)
    game.screen = .status
    game.paused = true
    let commander = game.commander
    let bodies = game.bodies
    let time = game.time
    game.key("journal-open")
    #expect(game.screen == .journal && game.paused && !game.calendarActive)
    game.tick(delta: 0.1)
    #expect(game.commander == commander && game.bodies == bodies && game.time == time)
    game.key("return")
    #expect(game.c01InquiryJournal.detail && game.c01InquiryJournal.action == .back)
    #expect(!game.c01InquiryJournalCanConfirm)
    game.key("escape")
    #expect(game.screen == .journal && !game.c01InquiryJournal.detail && game.paused)
    game.key("escape")
    #expect(game.screen == .status && game.paused)
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func actualTypedPageRejectsStaleInputUnsupportedClicksAndDisallowedKeys() async throws {
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let list = await runtime.snapshot()
    guard case .journal(let identity)? = list.scriptPagePresentation.page else {
      Issue.record("Journal must use its typed page identity")
      return
    }
    #expect(identity.valid)
    await runtime.scriptPageClick(x: 120, y: 150, expected: list.scriptPagePresentation)
    let unclicked = await runtime.snapshot()
    #expect(unclicked.scriptPagePresentation == list.scriptPagePresentation)
    #expect(unclicked.commander == list.commander && unclicked.bodies == list.bodies)
    #expect(identity.allowedKeys.contains("k"))
    await runtime.scriptPageKey("k", expected: list.scriptPagePresentation)
    let help = await runtime.snapshot()
    try #require(help.screen == .help && help.helpReturn == .journal)
    #expect(help.commander == list.commander && help.bodies == list.bodies)
    // The old Journal proof cannot close Help; return uses Help's current proof.
    await runtime.scriptPageKey("escape", expected: list.scriptPagePresentation)
    #expect(await runtime.snapshot().screen == .help)
    await runtime.scriptPageKey("escape", expected: help.scriptPagePresentation)
    let returned = await runtime.snapshot()
    try #require(returned.screen == .journal)
    #expect(returned.scriptC01InquiryJournalPageIdentity == identity)
    #expect(returned.commander == list.commander && returned.bodies == list.bodies)
    await runtime.scriptPageKey("return", expected: returned.scriptPagePresentation)
    let detail = await runtime.snapshot()
    try #require(detail.c01InquiryJournal.detail)
    await runtime.scriptPageKey("escape", expected: list.scriptPagePresentation)
    let stale = await runtime.snapshot()
    #expect(stale.c01InquiryJournal.detail)
    #expect(stale.scriptPagePresentation == detail.scriptPagePresentation)
    await runtime.scriptPageKey("contracts-open", expected: stale.scriptPagePresentation)
    #expect(await runtime.snapshot().screen == .journal)
    await runtime.scriptPageKey("escape", expected: stale.scriptPagePresentation)
    #expect(await runtime.snapshot().c01InquiryJournal.detail == false)
    #expect(await runtime.snapshot().commander == start.commander)
  }

  @Test func detailScrollIsBoundAndRefusedConfirmReturnsToBackWithoutSaving() throws {
    var game = Game(executive: false)
    game.screen = .status
    game.viewportWidth = 320
    game.viewportHeight = 320
    game.key("journal-open")
    game.key("return")
    try #require(game.c01InquiryJournal.review?.allowed == false)
    let beforeScroll = game.scriptPagePresentation
    game.key("pagedown")
    #expect(game.c01InquiryJournal.scroll > 0)
    #expect(game.scriptPagePresentation != beforeScroll)
    let commander = game.commander
    let bodies = game.bodies
    // A stale transient button choice is UI DATA, never a prepared case or permission.
    game.c01InquiryJournal.action = .accept
    game.key("return")
    #expect(game.c01InquiryJournal.detail)
    #expect(game.c01InquiryJournal.action == .back && game.c01InquiryJournal.scroll == 0)
    #expect(game.c01InquiryJournal.review?.allowed == false)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    game.key("return")
    #expect(!game.c01InquiryJournal.detail)
  }

  @Test func actorReaderDoesNotAdvancePhysicalOrCalendarTimeAndClearsHeldControls() async {
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    var held = Controls()
    held.fire = true
    held.pitch = 1
    await runtime.setControls(held)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let opened = await runtime.snapshot()
    #expect(await runtime.controls.fire == false)
    #expect(await runtime.controls.pitch == 0)
    let after = await runtime.advance(delta: 0.1)
    #expect(after.screen == .journal && !after.calendarActive)
    #expect(after.time == opened.time)
    #expect(after.commander.flightSimulation.physicalTime == opened.commander.flightSimulation.physicalTime)
    #expect(after.commander.scriptState.calendarSeconds == opened.commander.scriptState.calendarSeconds)
    #expect(after.bodies == opened.bodies)
  }

  @Test(arguments: ["width", "height"])
  func actualFractionalViewportChangeRejectsOldProofAndSameSizeKeepsCurrentProof(form: String)
    async throws
  {
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let width = 840.25, height = 640.5
    await runtime.setViewport(width: width, height: height)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let shown = await runtime.snapshot()
    try #require(shown.screen == .journal && !shown.c01InquiryJournal.detail)
    let identity = shown.scriptC01InquiryJournalPageIdentity
    try #require(identity.valid)
    #expect(identity.viewportWidth == width && identity.viewportHeight == height)
    let encoded = try JSONEncoder().encode(shown.scriptPagePresentation)
    #expect(encoded.count <= 1024)  // Existing native painted-key token bound.
    #expect(try JSONDecoder().decode(ScriptPagePresentation.self, from: encoded)
      == shown.scriptPagePresentation)
    await runtime.setViewport(width: width, height: height)
    let same = await runtime.snapshot()
    #expect(same.scriptPagePresentation == shown.scriptPagePresentation)
    #expect(same.scriptC01InquiryJournalPageIdentity.recordsSHA256 == identity.recordsSHA256)
    #expect(same.c01InquiryJournal.generation == shown.c01InquiryJournal.generation)

    // A real representable fractional change must not disappear through integer rounding.
    let nextWidth = form == "width" ? width.nextUp : width
    let nextHeight = form == "height" ? height.nextUp : height
    await runtime.setViewport(width: nextWidth, height: nextHeight)
    let changed = await runtime.snapshot()
    let current = changed.scriptC01InquiryJournalPageIdentity
    try #require(current.valid)
    #expect(current.viewportWidth == nextWidth && current.viewportHeight == nextHeight)
    #expect(current != identity && current.recordsSHA256 != identity.recordsSHA256)
    #expect(current.generation == identity.generation)
    await runtime.scriptPageKey("return", expected: shown.scriptPagePresentation)
    let refused = await runtime.snapshot()
    #expect(refused.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(refused.screen == .journal && !refused.c01InquiryJournal.detail)
    #expect(refused.scriptPagePresentation == changed.scriptPagePresentation)
    #expect(refused.commander == shown.commander && refused.bodies == shown.bodies)
    #expect(refused.commander.scriptState.savedC01Inquiry == nil)
    await runtime.setViewport(width: nextWidth, height: nextHeight)
    let unchangedSize = await runtime.snapshot()
    #expect(unchangedSize.scriptPagePresentation == changed.scriptPagePresentation)
    await runtime.scriptPageKey("return", expected: unchangedSize.scriptPagePresentation)
    let opened = await runtime.snapshot()
    #expect(opened.screen == .journal && opened.c01InquiryJournal.detail)
    #expect(opened.scriptC01InquiryJournalPageIdentity.valid)
    #expect(opened.commander == shown.commander && opened.bodies == shown.bodies)
  }

  @Test(arguments: [
    "zero-width", "negative-width", "nan-width", "positive-infinity-width", "negative-infinity-width",
    "zero-height", "negative-height", "nan-height", "positive-infinity-height", "negative-infinity-height",
  ])
  func invalidViewportProofRefusesWithoutNormalizingActualRuntimeDimensions(form: String)
    async throws
  {
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    let shown = await runtime.snapshot()
    try #require(shown.screen == .journal && shown.scriptPagePresentation.valid)
    let invalid: Double
    if form.hasPrefix("zero-") { invalid = 0 }
    else if form.hasPrefix("negative-infinity-") { invalid = -.infinity }
    else if form.hasPrefix("positive-infinity-") { invalid = .infinity }
    else if form.hasPrefix("nan-") { invalid = .nan }
    else { invalid = -1 }
    // Malformed proof DATA only. The actual runtime keeps its genuine current
    // viewport; this does not require its setter to accept invalid dimensions.
    var malformedProjection = shown
    if form.hasSuffix("width") { malformedProjection.viewportWidth = invalid }
    else { malformedProjection.viewportHeight = invalid }
    let invalidIdentity = malformedProjection.scriptC01InquiryJournalPageIdentity
    #expect(invalidIdentity.viewportWidth.bitPattern == malformedProjection.viewportWidth.bitPattern)
    #expect(invalidIdentity.viewportHeight.bitPattern == malformedProjection.viewportHeight.bitPattern)
    #expect(invalidIdentity.generation == shown.c01InquiryJournal.generation)
    #expect(!invalidIdentity.valid && !malformedProjection.scriptPagePresentation.valid)
    await runtime.scriptPageKey("return", expected: malformedProjection.scriptPagePresentation)
    let refused = await runtime.snapshot()
    #expect(refused.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(refused.screen == .journal && !refused.c01InquiryJournal.detail)
    #expect(refused.viewportWidth == shown.viewportWidth && refused.viewportHeight == shown.viewportHeight)
    #expect(refused.scriptPagePresentation == shown.scriptPagePresentation)
    #expect(refused.commander == shown.commander && refused.bodies == shown.bodies)
    #expect(refused.commander.scriptState.savedC01Inquiry == nil)
    await runtime.scriptPageKey("return", expected: refused.scriptPagePresentation)
    #expect(await runtime.snapshot().c01InquiryJournal.detail == true)
  }
}
