import Foundation
import Testing

@testable import L337Core

/// Every positive comes from the actual existing seal/lab/wake/archive/recovery chain.
/// That fixture labels controlled travel and funding; no original or authority is injected.
func actualC03ArchiveReaderUIFixture() async throws -> (
  runtime: GameRuntime, commission: HollowManifestCommissionFixture, recovered: Game
) {
  let (runtime, commission) = try await actualHollowRegisterRuntime()
  do {
    let selected = try await selectActualHollowRegister(runtime)
    await runtime.missionUICommand(.init(action: .originalRegisterRecovery,
      game: selected, presentation: selected.scriptPagePresentation))
    let recovered = await runtime.snapshot()
    _ = try #require(recovered.hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery)
    _ = try recovered.hollowManifestHeldRegisterData()
    return (runtime, commission, recovered)
  } catch {
    commission.clean()
    throw error
  }
}

func openActualC03ArchiveReaderUI(_ runtime: GameRuntime) async throws -> Game {
  let before = await runtime.snapshot()
  let intent = MissionUIIntent(action: .reviewRecoveredRegister,
    game: before, presentation: before.scriptPagePresentation)
  try #require(intent.isCurrent(in: before))
  await runtime.missionUICommand(intent)
  let opened = await runtime.snapshot()
  try #require(opened.isC03ArchiveReaderVisible && opened.c03ArchiveReaderDisplay != nil)
  return opened
}

struct NativeC03ArchiveReaderUIUnitTests {
  @Test func actualMenuReadingShowsFiveOriginalPagesAndLeavesTheCaseUnadvanced() async throws {
    let fixture = try await actualC03ArchiveReaderUIFixture()
    defer { fixture.commission.clean() }
    let runtime = fixture.runtime
    await runtime.setViewport(width: 640, height: 480)
    var shown = try await openActualC03ArchiveReaderUI(runtime)
    let original = try fixture.recovered.hollowManifestHeldRegisterData()
    let caseBefore = fixture.recovered.hollowManifestMission
    let inventory = shown.commander.equipmentInventory
    let physicalTime = shown.commander.flightSimulation.physicalTime
    let credits = shown.commander.credits
    for section in NativeC03RecoveredArchiveReader.Section.allCases {
      let display = try #require(shown.c03ArchiveReaderDisplay)
      #expect(display.page.section == section && display.page.register == original.contents.serial)
      #expect(display.page.transfer == original.transfer)
      for width in [320.0, 640.0, 1280.0] {
        let frame = Display.referenceLibrary(shown, width: width, height: 480)
        #expect(frame.labels.contains { $0.text == "DOCUMENT / NOT PROOF" })
        #expect(frame.labels.contains { $0.text == "PREV" })
        #expect(frame.labels.contains { $0.text == "BACK" })
        #expect(frame.labels.contains { $0.text == "NEXT" })
        for label in frame.labels {
          #expect(label.bounds.x >= 0 && label.bounds.maxX <= width)
          #expect(label.bounds.y >= 0 && label.bounds.maxY <= 480)
        }
      }
      if section == .declarations {
        #expect(display.page.rows.prefix(2).map(\.basis) == [.documentClaim, .documentClaim])
        #expect(display.page.rows.prefix(2).map(\.value) == ["Sealed refinery waste", "Machinery"])
      }
      if section == .crewNotice {
        #expect(display.page.rows.last?.basis == .requirement)
        #expect(display.page.rows.last?.value.contains("unaltered log") == true)
      } else {
        await runtime.scriptPageKey("right", expected: shown.scriptPagePresentation)
        shown = await runtime.snapshot()
      }
    }
    let layout = NativeC03ArchiveReaderLayout(page: try #require(shown.c03ArchiveReaderDisplay).page,
      width: shown.viewportWidth, height: shown.viewportHeight, offset: 0)
    await runtime.scriptPageClick(x: layout.left + 1, y: layout.buttonsY,
      expected: shown.scriptPagePresentation)
    shown = await runtime.snapshot()
    #expect(shown.c03ArchiveReaderDisplay?.page.section == .wakeReferences)
    _ = await runtime.advance(delta: 0.05)
    shown = await runtime.snapshot()
    #expect(shown.commander.flightSimulation.physicalTime == physicalTime)
    #expect(shown.commander.equipmentInventory == inventory && shown.commander.credits == credits)
    #expect(shown.hollowManifestMission == caseBefore)
    #expect(shown.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(shown.hollowManifestMission?.savedHollowManifest?.caseFile == nil)
    #expect(shown.hollowManifestMission?.completionReceipt == nil)
    let files = try ScriptFinanceTestFixture.files(fixture.commission.files.save.deletingLastPathComponent())
    await runtime.scriptPageKey("escape", expected: shown.scriptPagePresentation)
    let closed = await runtime.snapshot()
    #expect(!closed.isC03ArchiveReaderVisible && closed.screen == fixture.recovered.screen)
    #expect(try ScriptFinanceTestFixture.files(fixture.commission.files.save.deletingLastPathComponent()) == files)
  }

  @Test func staleScrollPageSessionResizeAndUnprovedInputsCannotMoveTheReader() async throws {
    let fixture = try await actualC03ArchiveReaderUIFixture()
    defer { fixture.commission.clean() }
    let runtime = fixture.runtime
    await runtime.setViewport(width: 320, height: 320)
    let initial = try await openActualC03ArchiveReaderUI(runtime)
    await runtime.scriptPageKey("pagedown", expected: initial.scriptPagePresentation)
    let scrolled = await runtime.snapshot()
    try #require((scrolled.c03ArchiveReaderDisplay?.scroll ?? 0) > 0)
    #expect(initial.scriptPagePresentation != scrolled.scriptPagePresentation)
    await runtime.scriptPageKey("right", expected: initial.scriptPagePresentation)
    #expect(await runtime.snapshot().c03ArchiveReaderDisplay == scrolled.c03ArchiveReaderDisplay)
    for raw in ["left", "right", "up", "down", "pageup", "pagedown", "return", "tab", "escape", "k", "i"] {
      await runtime.key(raw)
    }
    let page = try #require(scrolled.c03ArchiveReaderDisplay).page
    let layout = NativeC03ArchiveReaderLayout(page: page, width: 320, height: 320, offset: 0)
    await runtime.libraryClick(x: layout.left + layout.width - 1, y: layout.buttonsY)
    #expect(await runtime.snapshot().c03ArchiveReaderDisplay == scrolled.c03ArchiveReaderDisplay)
    // Set actual actor viewport before reusing an old painted proof.
    await runtime.setViewport(width: 640, height: 480)
    await runtime.scriptPageKey("right", expected: scrolled.scriptPagePresentation)
    var current = await runtime.snapshot()
    #expect(current.c03ArchiveReaderDisplay?.page.section == .declarations)
    #expect(current.scriptPagePresentation != scrolled.scriptPagePresentation)
    await runtime.scriptPageKey("right", expected: current.scriptPagePresentation)
    let next = await runtime.snapshot()
    #expect(next.c03ArchiveReaderDisplay?.page.section == .firstSeal)
    await runtime.scriptPageClick(x: 639, y: 400, expected: current.scriptPagePresentation)
    #expect(await runtime.snapshot().c03ArchiveReaderDisplay == next.c03ArchiveReaderDisplay)
    current = await runtime.snapshot()
    await runtime.scriptPageKey("escape", expected: current.scriptPagePresentation)
    let reopened = try await openActualC03ArchiveReaderUI(runtime)
    #expect(reopened.scriptPagePresentation != initial.scriptPagePresentation)
    await runtime.scriptPageKey("right", expected: initial.scriptPagePresentation)
    #expect(await runtime.snapshot().c03ArchiveReaderDisplay == reopened.c03ArchiveReaderDisplay)
  }

  @Test func missingKitTrialCaseAndEpochChangesRefuseTheCapturedActualReader() async throws {
    let fixture = try await actualC03ArchiveReaderUIFixture()
    defer { fixture.commission.clean() }
    let recovered = fixture.recovered
    let intent = MissionUIIntent(action: .reviewRecoveredRegister,
      game: recovered, presentation: recovered.scriptPagePresentation)
    try #require(intent.isCurrent(in: recovered))
    let held = try recovered.hollowManifestHeldRegisterData()
    let reader = try recovered.hollowManifestRecoveredArchiveReader()
    // Negative value copies only. These are not real loss, transfer or trial producers.
    var missing = recovered
    let inventory = try #require(missing.commander.equipmentInventory)
    missing.commander.savedEquipmentInventory = try .init(owner: inventory.owner,
      activeHull: inventory.activeHull, revision: inventory.revision + 1,
      items: inventory.items.filter { $0.id != held.kit.serial })
    var trial = recovered
    trial.isMissionTrial = true
    var changed = recovered
    let mission = try #require(changed.hollowManifestMission?.id)
    changed.commander.scriptState.instances[mission]?.revision += 1
    var epoch = recovered
    epoch.nativeStationRuntimeEpoch = UUID()
    for invalid in [missing, trial, changed, epoch] {
      #expect(!intent.isCurrent(in: invalid))
      #expect(throws: (any Error).self) { try reader.page(in: invalid) }
    }
    // An epoch change rejects the captured session even though its saved original survives.
    _ = try await openActualC03ArchiveReaderUI(fixture.runtime)
    await fixture.runtime.nativeCommand { $0.nativeStationRuntimeEpoch = UUID() }
    let invalidated = await fixture.runtime.snapshot()
    #expect(!invalidated.isC03ArchiveReaderVisible)
    let stillHeld = try invalidated.hollowManifestHeldRegisterData()
    #expect(stillHeld.contents == held.contents && stillHeld.transfer == held.transfer)
    #expect(invalidated.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
  }

  @Test func failedLoadPreservesLiveViewWhileCurrentLoadResetsItAndHelpReturnsSafely() async throws {
    let fixture = try await actualC03ArchiveReaderUIFixture()
    defer { fixture.commission.clean() }
    let runtime = fixture.runtime
    var opened = try await openActualC03ArchiveReaderUI(runtime)
    let original = try opened.hollowManifestHeldRegisterData()
    var refused = false
    do { try await runtime.load(from: fixture.commission.files.root.appendingPathComponent("missing-save")) }
    catch { refused = true }
    #expect(refused)
    let retained = await runtime.snapshot()
    #expect(retained.c03ArchiveReaderDisplay == opened.c03ArchiveReaderDisplay)
    #expect(retained.scriptPagePresentation == opened.scriptPagePresentation)
    await runtime.scriptPageKey("k", expected: retained.scriptPagePresentation)
    let help = await runtime.snapshot()
    #expect(help.screen == .help && !help.isC03ArchiveReaderVisible)
    #expect(help.c03ArchiveReaderDisplay == nil && help.helpReturn == .library)
    await runtime.key("escape")
    opened = await runtime.snapshot()
    #expect(opened.isC03ArchiveReaderVisible)
    #expect(opened.scriptPagePresentation != retained.scriptPagePresentation)
    try await runtime.save(to: fixture.commission.files.save)
    try await runtime.load(from: fixture.commission.files.save, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(!loaded.isC03ArchiveReaderVisible && loaded.c03ArchiveReaderDisplay == nil)
    let current = try loaded.hollowManifestHeldRegisterData()
    #expect(current.contents == original.contents && current.transfer == original.transfer)
    let fresh = try await openActualC03ArchiveReaderUI(runtime)
    #expect(fresh.c03ArchiveReaderDisplay?.page.section == .declarations)
    #expect(fresh.scriptPagePresentation != opened.scriptPagePresentation)
    await runtime.scriptPageKey("escape", expected: fresh.scriptPagePresentation)
    let exited = await runtime.snapshot()
    if exited.screen != .library { await runtime.key("library-open") }
    let generic = await runtime.snapshot()
    try #require(generic.screen == .library && !generic.isC03ArchiveReaderVisible)
    let fromLibrary = try await openActualC03ArchiveReaderUI(runtime)
    await runtime.scriptPageKey("escape", expected: fromLibrary.scriptPagePresentation)
    let back = await runtime.snapshot()
    #expect(back.screen == .library && !back.isC03ArchiveReaderVisible)
    #expect(back.library == generic.library)
  }
}
