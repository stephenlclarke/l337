import AppKit
import Foundation
import Testing

@testable import L337Core
@testable import L337Mac

private func registrationDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

@Suite(.serialized)
struct StartupSaveRegistrationTests {
  @MainActor @Test func freshNativeLaunchPublishesAndAcknowledgesItsDefaultDestination()
    async throws
  {
    _ = NSApplication.shared
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = registrationDirectory()
    defer {
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let url = directory.appendingPathComponent("commander.json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    let before = await delegate.runtime.snapshot()
    try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: false)
    let registered = await delegate.runtime.snapshot()
    #expect(registered.commander.name == before.commander.name)
    #expect(registered.commander.shipID == before.commander.shipID)
    #expect(registered.commander.credits == before.commander.credits)
    #expect(registered.commander.fuel == before.commander.fuel)
    #expect(registered.commander.cargo == before.commander.cargo)
    #expect(registered.commander.equipmentOwnerID != before.commander.equipmentOwnerID)
    #expect(registered.commander.valid && registered.scriptDurabilityAvailable)
    #expect(registered.nativeMainStationDockEvidenceIsCurrent)
    #expect(
      registered.commander.nativeStations?.currentMainDock?.station.system
        == .init(galaxy: 0, system: 7))
    #expect(saves.activeURL == url && saves.startupURL == nil)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(preferences.persistentDomain(forName: identifier) == nil)
    // Let the actual introductory sequence reach the title before using the native command batch.
    for _ in 0..<121 { _ = await delegate.runtime.advance(delta: 0.1) }
    let title = await delegate.runtime.snapshot()
    try #require(title.screen == .title)
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    view.pending = [" ", "0"]
    await delegate.processPendingCommands(in: view)
    let flying = await delegate.runtime.snapshot()
    #expect(!flying.docked && flying.commander.nativeStations != nil)
    #expect(flying.requiresScriptDurability && flying.scriptDurabilityAvailable)
    #expect(flying.commander.scriptState.calendarSeconds == 600)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
    let (saved, _) = try ScriptSaveStore.read(bytes, from: url)
    #expect(saved.valid && saved.nativeStations == flying.commander.nativeStations)
    #expect(saved.scriptState == flying.commander.scriptState)
    #expect(saved.equipmentInventory == flying.commander.equipmentInventory)
    #expect(CommanderSaveSession(preferences: preferences, defaultURL: url).startupURL == url)
    #expect(preferences.string(forKey: "lastCommanderSavePath") == url.path)
    let acknowledgedReceipt = await delegate.runtime.takeNewCommanderSaveReceipt()
    #expect(acknowledgedReceipt == nil)
  }

  @MainActor @Test(arguments: [false, true])
  func failedOrMissingSelectedSaveUsesANewDestinationWithoutOverwriting(missing: Bool) async throws
  {
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let selected = directory.appendingPathComponent("previous.json")
    let original = Data("invalid previous commander".utf8)
    if !missing { try original.write(to: selected) }
    let defaultURL = directory.appendingPathComponent("commander.json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: defaultURL)
    saves.didSave(to: selected)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    let initial = await delegate.runtime.snapshot()
    await #expect(throws: (any Error).self) {
      try await delegate.runtime.restoreStartup(from: selected)
    }
    // This is also the safe fallback after Choose Save is cancelled or its load fails.
    try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: true)
    let registered = await delegate.runtime.snapshot()
    #expect(registered.commander.name == initial.commander.name)
    #expect(registered.commander.shipID == initial.commander.shipID)
    #expect(registered.commander.credits == initial.commander.credits)
    #expect(registered.commander.fuel == initial.commander.fuel)
    #expect(registered.commander.cargo == initial.commander.cargo)
    #expect(registered.commander.equipmentOwnerID != initial.commander.equipmentOwnerID)
    #expect(registered.commander.valid && registered.nativeMainStationDockEvidenceIsCurrent)
    #expect(
      registered.commander.nativeStations?.currentMainDock?.station.system
        == .init(galaxy: 0, system: 7))
    #expect(saves.activeURL != selected && saves.activeURL != defaultURL)
    #expect(preferences.string(forKey: "lastCommanderSavePath") == selected.path)
    #expect(!FileManager.default.fileExists(atPath: saves.activeURL.path))
    try await delegate.runtime.save(to: saves.activeURL)
    await delegate.acknowledgeNewCommanderSave()
    #expect(preferences.string(forKey: "lastCommanderSavePath") == saves.activeURL.path)
    #expect(
      CommanderSaveSession(preferences: preferences, defaultURL: defaultURL).startupURL
        == saves.activeURL)
    if missing {
      #expect(!FileManager.default.fileExists(atPath: selected.path))
    } else {
      #expect(try Data(contentsOf: selected) == original)
    }
  }

  @Test func registeredNativeFlightSupportsTheActualRecoveredEquipmentWriter() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: try recoveredEquipmentGame("energy-technology"))
    _ = try await runtime.registerNewCommanderDestination(at: url)
    await runtime.key("0")
    await runtime.key("9")
    let before = await runtime.snapshot()
    try #require(!before.docked && before.scriptDurabilityAvailable && before.screen == .inventory)
    let lot = try #require(before.commander.salvageLedger.inventory.first)
    let command = try #require(before.inventoryActionPreview(for: .recovered(lot)).command)
    let result = await runtime.equipmentTransaction(.inventory(command))
    #expect(result.applied)
    let committed = await runtime.snapshot()
    #expect(committed.commander.salvageLedger.inventory.isEmpty)
    #expect(
      committed.commander.fittedComponent(at: .energy)?.receipts.first?.item
        == .salvage(lot.identity))
    #expect(committed.commander.credits == before.commander.credits)
    #expect(
      committed.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    #expect(saved.valid && saved.salvageLedger == committed.commander.salvageLedger)
    #expect(saved.equipmentInventory == committed.commander.equipmentInventory)
  }

  @Test func collisionAtFirstPublicationPreservesTheExistingPointerAndGeneration() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    try await runtime.startNewCommander()
    await runtime.key(" ")
    _ = try await runtime.registerNewCommanderDestination(at: url)
    // Another valid native save arrives after registration, before this commander's first write.
    var other = Game(executive: false)
    other.screen = .status
    other.commander.name = "EXISTING"
    try other.commander.prepareEquipment(legacy: false)
    let otherRuntime = GameRuntime(game: other, saveURL: url)
    await otherRuntime.key("0")
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let chunks = try pointer.hashes.keys.reduce(into: [String: Data]()) {
      $0[$1] = try Data(contentsOf: generation.appendingPathComponent($1))
    }
    let before = await runtime.snapshot()
    await runtime.key("0")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.docked == before.docked)
    #expect(refused.pendingNewSaveDestination == url)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: url) == bytes)
    for (name, data) in chunks {
      #expect(try Data(contentsOf: generation.appendingPathComponent(name)) == data)
    }
    let entries = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    #expect(!entries.contains { $0.lastPathComponent.hasSuffix(".pending") })
    let alternative = directory.appendingPathComponent("safe-new.json")
    try await runtime.save(to: alternative)
    #expect(try Data(contentsOf: url) == bytes)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
  }

  @Test func failedFirstWriteHasNoReceiptAndPreservesTheRegisteredCommander() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appendingPathComponent("parent")
    let url = blocker.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    try await runtime.startNewCommander()
    await runtime.key(" ")
    _ = try await runtime.registerNewCommanderDestination(at: url)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = Data("blocks the writer".utf8)
    try original.write(to: blocker)
    let before = await runtime.snapshot()
    await runtime.key("0")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.docked)
    #expect(refused.pendingNewSaveDestination == url)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: blocker) == original)
  }

  @Test(arguments: [false, true])
  func successfulOpenOrSaveAsCannotAcknowledgeAnOlderDestination(open: Bool) async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let a = directory.appendingPathComponent("A.json")
    let b = directory.appendingPathComponent("B.json")
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    await runtime.key(" ")
    _ = try await runtime.registerNewCommanderDestination(at: a)
    try await runtime.save(to: a)
    let original = try Data(contentsOf: a)
    if open {
      let writer = GameRuntime(game: Game(executive: false))
      try await writer.startNewCommander()
      try await writer.save(to: b)
      try await runtime.load(from: b, persistMigrations: false)
    } else {
      try await runtime.save(to: b)
    }
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: a) == original)
    #expect(await runtime.hasCommanderSaveDestination())
  }

  @Test func registrationRejectsExistingFilesDanglingLinksAndTrialWriters() async throws {
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("existing.json")
    let link = directory.appendingPathComponent("dangling.json")
    let bytes = Data("existing".utf8)
    try bytes.write(to: file)
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: directory.appendingPathComponent("missing.json"))
    let runtime = GameRuntime(game: Game(executive: false))
    for url in [file, link] {
      await #expect(throws: (any Error).self) {
        _ = try await runtime.registerNewCommanderDestination(at: url)
      }
    }
    #expect(!(await runtime.hasCommanderSaveDestination()))
    #expect(try Data(contentsOf: file) == bytes)
    var trial = Game(executive: false)
    trial.isMissionTrial = true
    let trialRuntime = GameRuntime(game: trial)
    await #expect(throws: (any Error).self) {
      _ = try await trialRuntime.registerNewCommanderDestination(
        at: directory.appendingPathComponent("trial.json"))
    }
    #expect(await trialRuntime.takeNewCommanderSaveReceipt() == nil)
  }

  @Test(arguments: [false, true])
  func actorRestartRetainsUnpublishedDestinationOrUnacknowledgedSuccess(published: Bool)
    async throws
  {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .gameOver
    try game.commander.prepareEquipment(legacy: false)
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: url)
    if published { try await runtime.save(to: url) }
    let before = await runtime.snapshot()
    if !published {
      // Authentic restart now publishes immediately. A competing first file must refuse first.
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let collision = Data("arrived before restart".utf8)
      try collision.write(to: url)
      await runtime.key("return")
      let refused = await runtime.snapshot()
      #expect(refused.screen == .gameOver && refused.commander == before.commander)
      #expect(refused.commander.equipmentOwnerID == before.commander.equipmentOwnerID)
      #expect(refused.pendingNewSaveDestination == url)
      #expect(try Data(contentsOf: url) == collision)
      #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
      try FileManager.default.removeItem(at: url)
    }
    await runtime.key("return")
    let restarted = await runtime.snapshot()
    #expect(restarted.screen == .status && restarted.scriptDurabilityAvailable)
    #expect(restarted.commander.valid && restarted.nativeMainStationDockEvidenceIsCurrent)
    #expect(restarted.commander.equipmentOwnerID != before.commander.equipmentOwnerID)
    #expect(restarted.pendingNewSaveDestination == nil)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    #expect(saved.equipmentOwnerID == restarted.commander.equipmentOwnerID)
    #expect(saved.nativeStations == restarted.commander.nativeStations)
    let receipt = await runtime.takeNewCommanderSaveReceipt()
    #expect(receipt?.url == url && receipt?.isTrial == false)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
  }

  @MainActor @Test(arguments: [false, true])
  func startupRegistrationFailureStillProcessesExplicitFileRecoveryAndFlight(open: Bool)
    async throws
  {
    _ = NSApplication.shared
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let blocker = directory.appendingPathComponent("blocked")
    let original = Data("not a writable save directory".utf8)
    try original.write(to: blocker)
    let saves = CommanderSaveSession(
      preferences: preferences, defaultURL: blocker.appendingPathComponent("commander.json"))
    var errors: [any Error] = []
    let delegate = AppDelegate(
      restoreOnLaunch: false, saves: saves, commanderFileFailure: { errors.append($0) })
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    delegate.window = window
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
      window.orderOut(nil)
      window.delegate = nil
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    await delegate.prepareNewCommanderSaveIfNeeded(afterFailedRestore: false)
    #expect(errors.count == 1)
    #expect(!(await delegate.runtime.hasCommanderSaveDestination()))
    #expect(preferences.persistentDomain(forName: identifier) == nil)
    #expect(try Data(contentsOf: blocker) == original)
    let recovery = directory.appendingPathComponent("recovered.json")
    if open {
      let writer = GameRuntime(game: Game(executive: false))
      try await writer.startNewCommander()
      try await writer.save(to: recovery)
      delegate.queueCommanderFile(.open(recovery))
    } else {
      delegate.queueCommanderFile(.saveAs(recovery))
    }
    await delegate.processPendingCommands(in: view)
    #expect(errors.count == 1 && view.pending.isEmpty)
    #expect(await delegate.runtime.hasCommanderSaveDestination())
    #expect(saves.activeURL == recovery)
    if !open {
      for _ in 0..<121 { _ = await delegate.runtime.advance(delta: 0.1) }
      view.pending.append(" ")
    }
    view.pending.append("0")
    await delegate.processPendingCommands(in: view)
    func pitchEvent(_ type: NSEvent.EventType) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: window.windowNumber, context: nil, characters: "",
          charactersIgnoringModifiers: "", isARepeat: false, keyCode: 126))
    }
    view.keyDown(with: try pitchEvent(.keyDown))
    try #require(view.held.contains("up") && view.controls.pitch != 0)
    await delegate.processFrame(in: view, delta: { 0.1 })
    view.keyUp(with: try pitchEvent(.keyUp))
    let flying = await delegate.runtime.snapshot()
    #expect(!flying.docked && flying.scriptDurabilityAvailable && flying.requiresScriptDurability)
    #expect(flying.commander.flightSimulation.physicalTime > 0 && flying.pitch != 0)
    #expect(view.game.commander == flying.commander && view.pending.isEmpty)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: recovery), from: recovery)
    #expect(saved.valid && saved.nativeStations != nil)
    #expect(saved.equipmentInventory == flying.commander.equipmentInventory)
    #expect(try Data(contentsOf: blocker) == original)
  }

}

@Suite struct IsolatedApplicationDataTests {
  private func makeRoot() throws -> URL {
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    return directory.deletingLastPathComponent().resolvingSymlinksInPath()
      .appendingPathComponent(directory.lastPathComponent, isDirectory: true)
  }

  @Test func explicitRootRejectsLivePathsAliasesAndSaveSidecars() throws {
    let root = try makeRoot()
    let live = try makeRoot()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: live)
    }
    #expect(try IsolatedApplicationData.parse([], liveDirectory: live) == nil)
    for arguments in [
      ["--data-directory"], ["--data-directory", "relative"], ["--data-directory=" + root.path],
      ["--data-directory", root.path, "--data-directory", root.path],
      ["--data-directory", live.path], ["--data-directory", live.deletingLastPathComponent().path],
    ] {
      #expect(throws: (any Error).self) {
        _ = try IsolatedApplicationData.parse(arguments, liveDirectory: live)
      }
    }
    let packAlias = root.appendingPathComponent("script-packs")
    try FileManager.default.createSymbolicLink(at: packAlias, withDestinationURL: live)
    #expect(throws: (any Error).self) {
      _ = try IsolatedApplicationData.parse(
        ["--data-directory", packAlias.path], liveDirectory: live)
    }
    let parsed = try IsolatedApplicationData.parse(
      ["--data-directory", root.path], liveDirectory: live)
    let data = try #require(parsed)
    #expect(throws: (any Error).self) { _ = try data.packDirectories() }
    #expect(throws: (any Error).self) {
      _ = try data.checkedSave(live.appendingPathComponent("commander.json"))
    }
    let sidecar = data.defaultSave.appendingPathExtension("missions")
    try FileManager.default.createSymbolicLink(at: sidecar, withDestinationURL: live)
    #expect(throws: (any Error).self) { _ = try data.checkedSave(data.defaultSave) }
    try Data("../commander.json".utf8).write(to: root.appendingPathComponent(".last-commander"))
    #expect(throws: (any Error).self) { _ = try data.rememberedSave() }
  }

  @MainActor @Test func ordinaryRuntimeRestoresTheSamePrivateFallbackSave() async throws {
    let root = try makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let live = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    let parsed = try IsolatedApplicationData.parse(
      ["--data-directory", root.path], liveDirectory: live)
    let data = try #require(parsed)
    let directories = try data.packDirectories()
    #expect(directories.legacy.deletingLastPathComponent().path == root.path)
    #expect(directories.script.deletingLastPathComponent().path == root.path)
    let saves = try CommanderSaveSession(isolatedData: data)
    #expect(saves.startupURL == nil)
    let failed = Data("damaged save".utf8)
    try failed.write(to: saves.defaultURL)
    let delegate = AppDelegate(saves: saves)
    await #expect(throws: (any Error).self) {
      try await delegate.runtime.restoreStartup(from: saves.checkedSave(saves.defaultURL))
    }
    try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: true)
    let destination = try saves.checkedSave(saves.activeURL)
    #expect(destination != saves.defaultURL)
    try await delegate.runtime.save(to: destination)
    await delegate.acknowledgeNewCommanderSave()
    #expect(try Data(contentsOf: saves.defaultURL) == failed)
    let reopened = try CommanderSaveSession(isolatedData: data)
    let startup = try #require(reopened.startupURL)
    #expect(startup.path == destination.path)
    let restored = AppDelegate(saves: reopened)
    try await restored.runtime.restoreStartup(from: reopened.checkedSave(startup))
    let before = await delegate.runtime.snapshot()
    let after = await restored.runtime.snapshot()
    #expect(after.commander.name == before.commander.name)
    #expect(after.commander.equipmentOwnerID == before.commander.equipmentOwnerID)
  }

  @MainActor @Test
  func controlledBisonManifestRequiresAFullSecondBudgetAcrossSaveQuitAndContinue() async throws {
    _ = NSApplication.shared
    let directory = try NativePagedSalvageFixture.folder()
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    defer {
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let file = directory.appendingPathComponent("commander.json")
    let (runtime, source) = try await NativeSecondBudgetFixture.runtime(file: file)
    let initial = await runtime.secondBudgetSnapshot()
    let owner = try #require(initial.game.commander.equipmentOwnerID)
    let hull = try #require(initial.game.commander.hullInstanceID)
    let parent = try #require(initial.game.bodies.first { $0.physical?.identity == source.parent })
    let originalPose = initial.game.modelPose(of: parent)
    let originalCargo = initial.game.commander.cargo
    let originalItems = initial.game.commander.equipmentInventory?.items.map(\.id)
    let originalPurchases = initial.game.commander.equipmentPurchaseHistory
    let originalCredits = initial.game.commander.credits
    try #require(try NativeSecondBudgetFixture.pending(initial.game, source: source).isEmpty)
    var first = initial
    for _ in 0..<2500 {
      first = try await runtime.secondBudgetAdvanceHeldWork(delta: 0.02)
      if NativeSecondBudgetFixture.hasInspection(first.game, source: source),
        try NativeSecondBudgetFixture.observation(first.game, source: source).cycle.releases > 0
      { break }
    }
    let firstWork = try NativeSecondBudgetFixture.observation(first.game, source: source)
    try #require(firstWork.cycle.releases == 1 && firstWork.cycle.progress.nextLot == 8)
    try #require(firstWork.cycle.currentWorkSeconds == 0 && !firstWork.cycle.depleted)
    try #require(firstWork.cycle.lastRelease?.creditedWorkSeconds == source.section.workSeconds)
    try #require(firstWork.inspection.plan.originalManifest == NativeSecondBudgetFixture.manifest)
    let firstLots = try NativeSecondBudgetFixture.pending(first.game, source: source)
    try #require(firstLots.count == 8)
    try NativeSecondBudgetFixture.requirePhysicalCustody(first.game, source: source)
    let firstParent = try #require(first.game.bodies.first { $0.physical?.identity == source.parent })
    #expect(first.game.modelPose(of: firstParent) != originalPose)
    // Enter the second budget with actual cutter input. No work/ledger import,
    // source rebinding or synthetic currentWorkSeconds is used at either boundary.
    var partial = first
    for _ in 0..<2500 {
      partial = try await runtime.secondBudgetAdvanceHeldWork(delta: 0.02)
      let observed = try NativeSecondBudgetFixture.observation(partial.game, source: source)
      try #require(observed.cycle.releases == 1 && observed.cycle.progress == firstWork.cycle.progress)
      if observed.cycle.currentWorkSeconds > 0 { break }
    }
    let partialWork = try NativeSecondBudgetFixture.observation(partial.game, source: source)
    try #require(partialWork.cycle.currentWorkSeconds > 0)
    try #require(partialWork.cycle.currentWorkSeconds < source.section.workSeconds)
    try #require(partialWork.inspection == firstWork.inspection)
    #expect(try NativeSecondBudgetFixture.pending(partial.game, source: source) == firstLots)
    await runtime.setControls(Controls())

    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    var failures: [any Error] = []
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves, runtime: runtime,
      commanderFileFailure: { failures.append($0) })
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    delegate.window = window
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
      window.orderOut(nil)
      window.delegate = nil
      delegate.window = nil
    }
    view.game = partial.game
    delegate.queueCommanderFile(.saveActive)
    try #require(view.pendingCommanderFiles.count == 1 && view.pending.contains("commander-file"))
    await delegate.processPendingCommands(in: view)
    try #require(failures.isEmpty && view.pending.isEmpty && view.pendingCommanderFiles.isEmpty)
    let saved = await runtime.secondBudgetSnapshot()
    let savedWork = try NativeSecondBudgetFixture.observation(saved.game, source: source)
    try #require(saved.game.nativeSalvageWork == nil)
    #expect(savedWork.inspection == firstWork.inspection)
    #expect(savedWork.cycle.progress == partialWork.cycle.progress)
    #expect(savedWork.cycle.currentWorkSeconds == partialWork.cycle.currentWorkSeconds)
    #expect(savedWork.cycle.lastRelease == partialWork.cycle.lastRelease)
    let savedParent = try #require(saved.game.bodies.first { $0.physical?.identity == source.parent })
    let savedPose = saved.game.modelPose(of: savedParent)
    let bytes = try Data(contentsOf: file)
    // This is the production Quit callback, not a claim of OS process relaunch.
    // Quit itself cancels the loop and must not save, tick or credit cutter work.
    delegate.applicationWillTerminate(
      Notification(name: NSApplication.willTerminateNotification, object: NSApplication.shared))
    #expect(delegate.loop == nil)
    let terminated = await runtime.secondBudgetSnapshot()
    #expect(terminated.game.commander == saved.game.commander && terminated.game.bodies == saved.game.bodies)
    #expect(terminated.game.time == saved.game.time)
    #expect(try Data(contentsOf: file) == bytes)

    let reopened = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let startup = try #require(reopened.startupURL)
    try #require(startup == file)
    let fresh = GameRuntime()
    let resumedDelegate = AppDelegate(saves: reopened, runtime: fresh,
      commanderFileFailure: { failures.append($0) })
    try await fresh.restoreStartup(from: reopened.checkedSave(startup))
    let title = await fresh.secondBudgetSnapshot()
    try #require(title.game.screen == .title)
    let titleWork = try NativeSecondBudgetFixture.observation(title.game, source: source)
    #expect(titleWork.inspection == savedWork.inspection && titleWork.cycle == savedWork.cycle)
    #expect(title.game.commander.flightSimulation.physicalTime == saved.game.commander.flightSimulation.physicalTime)
    for _ in 0..<10 { _ = await fresh.secondBudgetAdvance(delta: 0.1) }
    let waiting = await fresh.secondBudgetSnapshot()
    let waitingWork = try NativeSecondBudgetFixture.observation(waiting.game, source: source)
    #expect(waitingWork.inspection == titleWork.inspection && waitingWork.cycle == titleWork.cycle)
    #expect(waiting.game.commander.flightSimulation.physicalTime == title.game.commander.flightSimulation.physicalTime)
    #expect(waiting.game.bodies == title.game.bodies)
    #expect(try Data(contentsOf: file) == bytes)
    let resumedView = GameView(frame: view.frame)
    resumedView.game = waiting.game
    resumedView.pending = ["return"]
    await resumedDelegate.processPendingCommands(in: resumedView)
    let continued = await fresh.secondBudgetSnapshot()
    try #require(continued.game.screen != .title && continued.game.screen != .gameOver && !continued.game.docked)
    let continuedWork = try NativeSecondBudgetFixture.observation(continued.game, source: source)
    #expect(continuedWork.inspection == savedWork.inspection && continuedWork.cycle == savedWork.cycle)
    #expect(continued.game.commander.equipmentOwnerID == owner && continued.game.commander.hullInstanceID == hull)
    let restoredParent = try #require(continued.game.bodies.first { $0.physical?.identity == source.parent })
    #expect(continued.game.modelPose(of: restoredParent) == savedPose)
    #expect(restoredParent.physical == savedParent.physical)
    #expect(continued.game.commander.savedEMPState == saved.game.commander.savedEMPState)
    #expect(try NativeSecondBudgetFixture.pending(continued.game, source: source) == firstLots)
    #expect(try Data(contentsOf: file) == bytes)
    // Continue opens the normal status page; use the native front-view key
    // before resuming flight input, without advancing or inventing work time.
    resumedView.game = continued.game
    resumedView.pending = ["1"]
    await resumedDelegate.processPendingCommands(in: resumedView)
    let front = await fresh.secondBudgetSnapshot()
    try #require(front.game.screen.isFlight)
    #expect(try NativeSecondBudgetFixture.observation(front.game, source: source).cycle == savedWork.cycle)
    try await fresh.secondBudgetAimCargo(source)
    var second = await fresh.secondBudgetSnapshot()
    var previous = try NativeSecondBudgetFixture.observation(second.game, source: source)
    var advancedSeconds = 0.0
    for _ in 0..<2500 {
      second = try await fresh.secondBudgetAdvanceHeldWork(delta: 0.02)
      advancedSeconds += 0.02
      let observed = try NativeSecondBudgetFixture.observation(second.game, source: source)
      try #require(observed.inspection == savedWork.inspection)
      if observed.cycle.releases > 1 {
        // The release frame can contribute at most its actual 0.02s of work.
        #expect(previous.cycle.currentWorkSeconds + 0.02 + 1e-9 >= source.section.workSeconds)
        break
      }
      try #require(observed.cycle.releases == 1 && observed.cycle.progress == savedWork.cycle.progress)
      #expect(observed.cycle.currentWorkSeconds >= previous.cycle.currentWorkSeconds)
      #expect(observed.cycle.currentWorkSeconds <= previous.cycle.currentWorkSeconds + 0.02 + 1e-9)
      #expect(try NativeSecondBudgetFixture.pending(second.game, source: source) == firstLots)
      previous = observed
    }
    let completed = try NativeSecondBudgetFixture.observation(second.game, source: source)
    try #require(completed.cycle.releases == 2 && completed.cycle.progress.nextLot == 16)
    #expect(completed.cycle.id == savedWork.cycle.id && completed.cycle.owner == owner)
    #expect(completed.cycle.currentWorkSeconds == 0 && !completed.cycle.damagedTechnology && !completed.cycle.depleted)
    #expect(completed.cycle.lastRelease?.creditedWorkSeconds == source.section.workSeconds)
    #expect(advancedSeconds + savedWork.cycle.currentWorkSeconds + 1e-9 >= source.section.workSeconds)
    #expect(completed.cycle.lastRelease?.operation != savedWork.cycle.lastRelease?.operation)
    let secondLots = try NativeSecondBudgetFixture.pending(second.game, source: source)
    #expect(secondLots.count == 16 && firstLots.isSubset(of: secondLots))
    try NativeSecondBudgetFixture.requirePhysicalCustody(second.game, source: source)
    #expect(Set(secondLots.subtracting(firstLots).map(\.lot)) == Set(UInt16(8)..<UInt16(16)))
    #expect(second.game.commander.cargo == originalCargo)
    // Bank recharge is real elapsed physics; identity and paid provenance stay fixed.
    #expect(second.game.commander.equipmentInventory?.items.map(\.id) == originalItems)
    #expect(second.game.commander.equipmentPurchaseHistory == originalPurchases)
    #expect(second.game.commander.credits == originalCredits && failures.isEmpty)
  }
}
