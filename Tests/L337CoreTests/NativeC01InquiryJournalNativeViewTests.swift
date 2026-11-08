import AppKit
import Testing

@testable import L337Core
@testable import L337Mac

extension NativeViewTests {
  @MainActor @Test func journalNativeMenuOpensPausedReaderWithoutChangingAttainedState() async throws {
    _ = NSApplication.shared
    var game = Game(executive: false)
    game.screen = .status
    game.paused = true
    let runtime = GameRuntime(game: game)
    let view = GameView(frame: .init(x: 0, y: 0, width: 840, height: 640))
    view.game = await runtime.snapshot()
    let before = view.game
    var intents: [MissionUIIntent] = []
    let target = NativeMissionMenu(snapshot: { view.game },
      paintedPresentation: { view.paintedMissionMenuPresentation }, enqueue: { intents.append($0) })
    let menu = NSMenu(title: "Missions")
    target.install(in: menu)
    let item = try #require(menu.items.first { ($0.representedObject as? String) == "journal-open" })
    #expect(item.title == "Journal" && item.keyEquivalent.isEmpty)
    #expect(target.validateMenuItem(item) && target.choose(.journal))
    try #require(intents.count == 1)
    #expect(intents[0].action == .journal)
    await runtime.missionUICommand(intents[0])
    let opened = await runtime.snapshot()
    #expect(opened.screen == .journal && opened.paused && !opened.calendarActive)
    #expect(opened.commander == before.commander && opened.bodies == before.bodies)
    #expect(opened.time == before.time)
    #expect(opened.commander.scriptState.savedC01Inquiry == nil)
  }

  @MainActor @Test func journalPaintResizeAndWheelKeepActualSignedPageAndRejectUnpaintedBounds()
    throws
  {
    _ = NSApplication.shared
    let view = GameView(frame: .init(x: 0, y: 0, width: 840, height: 640))
    view.game.screen = .status
    view.game.key("journal-open")
    try #require(view.game.screen == .journal)
    let commander = view.game.commander
    let bodies = view.game.bodies
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    guard case .journal? = painted.page else {
      Issue.record("Native Journal paint must capture the typed Journal page")
      return
    }
    let enter = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
      modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
      characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
    view.keyDown(with: enter)
    try verifyNativePaintedKey(view, key: "return", painted: painted)
    view.pending.removeAll()
    view.setFrameSize(.init(width: 940, height: 720))
    #expect(view.paintedMissionMenuPresentation == nil)
    view.keyDown(with: enter)
    #expect(view.pending.isEmpty)
    try paintCampaignGalleryView(view)
    let resized = try #require(view.paintedMissionMenuPresentation)
    #expect(resized != painted)
    let wheel = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line,
      wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
    let scroll = try #require(NSEvent(cgEvent: wheel))
    try #require(scroll.scrollingDeltaY > 0)
    view.scrollWheel(with: scroll)
    try verifyNativePaintedKey(view, key: "up", painted: resized)
    view.pending.removeAll()
    let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown,
      location: .init(x: 120, y: 150), modifierFlags: [], timestamp: 0, windowNumber: 0,
      context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    view.mouseDown(with: click)
    #expect(view.pending.isEmpty)
    #expect(view.game.commander == commander && view.game.bodies == bodies)
    #expect(view.game.commander.scriptState.savedC01Inquiry == nil)
  }
  @MainActor @Test func journalQueuedProofUsesCurrentBoundsBeforeActualNativeDispatch() async throws {
    _ = NSApplication.shared
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let start = await runtime.snapshot()
    await runtime.missionUICommand(.init(action: .journal, game: start,
      presentation: start.scriptPagePresentation))
    await runtime.setViewport(width: 840, height: 640)
    let delegate = AppDelegate(restoreOnLaunch: false, runtime: runtime)
    let view = GameView(frame: .init(x: 0, y: 0, width: 840, height: 640))
    view.game = await runtime.snapshot()
    let commander = view.game.commander
    let bodies = view.game.bodies
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    #expect(painted == (await runtime.snapshot()).scriptPagePresentation)
    let enter = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
      modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
      characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
    view.keyDown(with: enter)
    try verifyNativePaintedKey(view, key: "return", painted: painted)
    // The event was genuinely painted and queued before this resize.
    view.setFrameSize(.init(width: 940, height: 720))
    await delegate.processPendingCommands(in: view)
    let refused = await runtime.snapshot()
    #expect(view.pending.isEmpty)
    #expect(refused.viewportWidth == 940 && refused.viewportHeight == 720)
    #expect(refused.screen == .journal && !refused.c01InquiryJournal.detail)
    #expect(refused.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
    #expect(refused.commander == commander && refused.bodies == bodies)
    view.game = refused
    try paintCampaignGalleryView(view)
    let current = try #require(view.paintedMissionMenuPresentation)
    #expect(current == refused.scriptPagePresentation && current != painted)
    view.keyDown(with: enter)
    await delegate.processPendingCommands(in: view)
    let opened = await runtime.snapshot()
    #expect(opened.screen == .journal && opened.c01InquiryJournal.detail)
    #expect(opened.commander == commander && opened.bodies == bodies)
    view.game = opened
    try paintCampaignGalleryView(view)
    let wheelProof = try #require(view.paintedMissionMenuPresentation)
    let wheel = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line,
      wheelCount: 1, wheel1: -1, wheel2: 0, wheel3: 0))
    let scroll = try #require(NSEvent(cgEvent: wheel))
    try #require(scroll.scrollingDeltaY < 0)
    view.scrollWheel(with: scroll)
    try verifyNativePaintedKey(view, key: "down", painted: wheelProof)
    await delegate.processPendingCommands(in: view)
    let scrolled = await runtime.snapshot()
    #expect(view.pending.isEmpty)
    #expect(scrolled.screen == .journal && scrolled.c01InquiryJournal.detail)
    #expect(scrolled.c01InquiryJournal.generation != opened.c01InquiryJournal.generation)
    #expect(scrolled.commander == commander && scrolled.bodies == bodies)
    #expect(scrolled.commander.scriptState.savedC01Inquiry == nil)
  }

  @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
  func invalidRuntimeViewportPreservesTheCurrentValidDimensions(value: Double) async {
    let runtime = GameRuntime(game: Game(executive: false))
    await runtime.setViewport(width: 840.25, height: 640.5)
    let before = await runtime.snapshot()
    await runtime.setViewport(width: value, height: 720)
    let widthRefused = await runtime.snapshot()
    #expect(widthRefused.viewportWidth == before.viewportWidth)
    #expect(widthRefused.viewportHeight == before.viewportHeight)
    await runtime.setViewport(width: 940, height: value)
    let heightRefused = await runtime.snapshot()
    #expect(heightRefused.viewportWidth == before.viewportWidth)
    #expect(heightRefused.viewportHeight == before.viewportHeight)
    #expect(heightRefused.commander == before.commander && heightRefused.bodies == before.bodies)
  }
}
