import AppKit
import Testing

@testable import L337Core
@testable import L337Mac

extension NativeViewTests {
  @MainActor @Test func actualPaintedInventorySubpageReturnReachesEditorAndWritesPlayerPlan()
    async throws
  {
    _ = NSApplication.shared
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let runtime = fixture.runtime
    let view = GameView(frame: .init(x: 0, y: 0, width: 840, height: 640))
    view.game = await runtime.snapshot()
    var intents: [MissionUIIntent] = []
    let target = NativeMissionMenu(snapshot: { view.game },
      paintedPresentation: { view.paintedMissionMenuPresentation }, enqueue: { intents.append($0) })
    let menu = NSMenu(title: "Missions")
    target.install(in: menu)
    let item = try #require(menu.items.first { $0.representedObject as? String == "assembly-capacity-open" })
    #expect(item.title == "Assembly Planning Console" && target.validateMenuItem(item))
    let chosen = target.choose(.assemblyCapacityConsole)
    try #require(chosen && intents.count == 1)
    await runtime.missionUICommand(intents[0])
    let delegate = AppDelegate(restoreOnLaunch: false, runtime: runtime)
    func press(_ key: String) async throws {
      view.game = await runtime.snapshot()
      try paintCampaignGalleryView(view)
      let page = try #require(view.paintedMissionMenuPresentation)
      guard case .assemblyCapacity? = page.page else {
        Issue.record("The native editor must paint its exact typed page before input")
        return
      }
      let character: String
      let code: UInt16
      switch key {
      case "return": character = "\r"; code = 36
      case "down": character = "\u{F701}"; code = 125
      case "right": character = "\u{F703}"; code = 124
      default: throw MissionPackError("Unsupported native editor fixture key")
      }
      let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
      view.keyDown(with: event)
      try verifyNativePaintedKey(view, key: key, painted: page)
      #expect(!view.pending.contains("inventory-command"))
      await delegate.processPendingCommands(in: view)
      try #require(view.pending.isEmpty)
    }
    // Return on Inventory previously went only to equipment fitting. Here it must reach
    // the actual typed planning page, then the same real durable input path below.
    try await press("return")
    let otherSide = await runtime.snapshot()
    #expect(otherSide.nativeAssemblyCapacityEditorDisplay?.side == "STARBOARD")
    for _ in 0..<5 {
      try await press("down")
      try await press("right")
    }
    try await press("down")
    try await press("return")
    let review = await runtime.snapshot()
    #expect(review.nativeAssemblyCapacityEditorDisplay?.confirms == false)
    #expect(review.commander == collected.commander)
    try await press("right")
    try await press("return")
    let saved = await runtime.snapshot()
    let plan = try #require(saved.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts?["starboard"])
    #expect(plan.choices.count == 5 && plan.choices.allSatisfy { $0.allocation == .waiting })
    #expect(saved.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(saved.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(saved.commander.credits == collected.commander.credits && saved.commander.cargo == collected.commander.cargo)
    let stored = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(stored.scriptState.instances[plan.register.mission]?.savedAssemblyOfOrbits?.capacityDrafts?["starboard"] == plan)
  }
}
