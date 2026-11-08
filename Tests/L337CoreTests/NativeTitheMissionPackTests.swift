import Foundation
import Testing

@testable import L337Core

struct NativeTitheMissionPackTests {
  @Test func actualBundledTitheIdentityRetainsAllFourteenObjectivesAndHasNoCommandOrHullAuthority()
    throws
  {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledTitheOfWorldsDirectory)
    #expect(pack.manifest.id == "l337.tithe-of-worlds")
    #expect(pack.manifest.mission.id == "tithe-of-worlds")
    #expect(pack.manifest.stateID == NativeTitheCommissionDefinition.stateID)
    #expect(pack.digest == NativeTitheCommissionDefinition.digest)
    #expect(NativeTitheCommissionDefinition.matches(pack))
    #expect(pack.manifest.capabilities.contains(NativeTitheCommissionDefinition.nativeCapability))
    #expect(ScriptCapabilities.implemented.contains(NativeTitheCommissionDefinition.nativeCapability))
    #expect(pack.manifest.mission.milestones == NativeTitheOriginalStage.allCases.map(\.objective))
    #expect(pack.manifest.mission.milestones.count == 14)
    #expect(pack.manifest.mission.briefing.contains(NativeTitheCommissionMark.warning))
    #expect(pack.models.isEmpty && pack.resourceBytes.isEmpty)
    #expect(pack.manifest.npcs == nil && pack.manifest.encounters == nil && pack.manifest.equipment == nil)
    #expect(pack.manifest.trial == nil && pack.manifest.board == nil)
    let result = try ScriptEvaluator.evaluate(source: pack.source, handler: "accepted",
      event: .object(["kind": .string("mission.accepted")]), snapshot: .object([:]), state: .object([:]))
    #expect(result.commands.isEmpty && result.data == .object([:]))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tithe-library-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let library = ScriptPackLibrary.defaultLibrary(directory: directory)
    #expect(library.errors.isEmpty)
    #expect(library.packs.filter { NativeTitheCommissionDefinition.applies($0) }.count == 1)
    #expect(library.packs.contains { NativeTitheCommissionDefinition.matches($0) })
  }

  @Test func actualInstallationAndColdGalleryExposeOriginalStagesWithoutAcceptingOrGrantingAnything()
    async throws
  {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    let before = await runtime.snapshot()
    let original = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
    let installed = files.root.appendingPathComponent("installed")
    try await runtime.installScriptPack(from: ScriptPackLibrary.bundledTitheOfWorldsDirectory,
      destination: installed)
    let game = await runtime.snapshot()
    let installationPreservesCommanderAndBodies = game.commander == before.commander && game.bodies == before.bodies
    #expect(installationPreservesCommanderAndBodies)
    let installationGrantsNoCommission = game.commander.titheCommissionMarkEntitlement == nil && game.titheCommissionMission == nil
    #expect(installationGrantsNoCommission)
    let entryCandidate = game.missionCatalogue.first { $0.name == "The Tithe of Worlds" }
    let entry = try #require(entryCandidate)
    let exactlyOneEntry = game.missionCatalogue.filter { $0.name == entry.name }.count == 1
    #expect(exactlyOneEntry)
    #expect(entry.status == .locked && entry.completed == 0 && entry.savedInstance == nil)
    #expect(entry.trialDigest == nil && entry.milestones.count == 14)
    #expect(entry.milestones.map(\.title) == NativeTitheOriginalStage.allCases.map(\.objective))
    #expect(entry.prerequisites.contains(NativeTitheCommissionContactSource.unavailable))
    #expect(entry.briefing.contains(NativeTitheCommissionMark.warning))
    let installedFiles = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
    #expect(installedFiles == original)
    let packCandidate = game.titheCommissionPack
    let pack = try #require(packCandidate)
    var coldGame = Game(executive: false)
    coldGame.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledTitheOfWorldsDirectory)]
    let cold = GameRuntime(game: coldGame)
    try await cold.load(from: files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    let coldEntryCandidate = loaded.missionCatalogue.first { $0.name == entry.name }
    let coldEntry = try #require(coldEntryCandidate)
    #expect(coldEntry.status == .locked && coldEntry.completed == 0 && coldEntry.milestones.count == 14)
    #expect(coldEntry.briefing == entry.briefing)
    let coldCommanderUnchanged = loaded.commander == before.commander
    #expect(coldCommanderUnchanged)
    let coldWorldUnchanged = loaded.scriptWorldSave == before.scriptWorldSave
    #expect(coldWorldUnchanged)
    let coldDockIsCurrent = loaded.nativeMainStationDockEvidenceIsCurrent
    #expect(coldDockIsCurrent)
    let creditsAndCargoRetained = loaded.commander.credits == before.commander.credits && loaded.commander.cargo == before.commander.cargo
    #expect(creditsAndCargoRetained)
    let equipmentRetained = loaded.commander.equipmentInventory == before.commander.equipmentInventory
    #expect(equipmentRetained)
    let instancesRetained = loaded.commander.scriptState.instances == before.commander.scriptState.instances
    #expect(instancesRetained)
    let cluesRetained = loaded.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal
    #expect(cluesRetained)
    let contentRetained = loaded.titheCommissionPack?.digest == pack.digest
    #expect(contentRetained)
    let coldGrantsNoCommission = loaded.commander.titheCommissionMarkEntitlement == nil && loaded.titheCommissionMission == nil
    #expect(coldGrantsNoCommission)
    let coldFiles = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
    #expect(coldFiles == original)
  }

  @Test func exactReaderRefusesChangedOriginalObjectivesAndExecutableRewardCommands() throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let original = ScriptPackLibrary.bundledTitheOfWorldsDirectory
    let manifest = try String(contentsOf: original.appendingPathComponent("manifest.toml"), encoding: .utf8)
    let module = try String(contentsOf: original.appendingPathComponent("scripts/main.lua"), encoding: .utf8)
    let mutations = [
      ("manifest.toml", manifest.replacingOccurrences(of: "title = \"The Tithe of Worlds\"", with: "title = \"Changed Tithe\"")),
      ("manifest.toml", manifest.replacingOccurrences(of: "id = \"l337.tithe-of-worlds\"", with: "id = \"l337.false-tithe\"")),
      ("manifest.toml", manifest.replacingOccurrences(of: "Accept the resource-seizure investigation at Rakenor.", with: "Skip the original investigation.")),
      ("scripts/main.lua", module.replacingOccurrences(of: "commands = {}", with: "commands = {{op = \"credits\", id = \"unearned-fee\", amount = 96000}}")),
    ]
    for (index, mutation) in mutations.enumerated() {
      let destination = files.root.appendingPathComponent("changed-tithe-\(index)")
      try FileManager.default.copyItem(at: original, to: destination)
      try #require(mutation.1 != (mutation.0 == "manifest.toml" ? manifest : module))
      try mutation.1.write(to: destination.appendingPathComponent(mutation.0), atomically: true, encoding: .utf8)
      #expect(throws: MissionPackError.self) { _ = try ScriptPackLibrary.read(destination) }
    }
    let unchanged = try ScriptPackLibrary.read(original)
    #expect(NativeTitheCommissionDefinition.matches(unchanged))
  }

  @Test func installedDefinitionCannotUseGenericAcceptanceOrGalleryTrialToIssueThePrivateCommission()
    async throws
  {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    try await runtime.installScriptPack(from: ScriptPackLibrary.bundledTitheOfWorldsDirectory,
      destination: files.root.appendingPathComponent("installed"))
    let before = await runtime.snapshot()
    let packCandidate = before.titheCommissionPack
    let pack = try #require(packCandidate)
    let saved = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
    var direct = before
    var acceptanceRefused = false
    do {
      _ = try direct.acceptScriptMission(pack)
    } catch is MissionPackError { acceptanceRefused = true }
    #expect(acceptanceRefused)
    let refusedAcceptancePreservesCommander = direct.commander == before.commander
    #expect(refusedAcceptancePreservesCommander)
    var trialRefused = false
    do {
      _ = try await runtime.scriptGalleryTrial(packDigest: pack.digest)
    } catch is MissionPackError { trialRefused = true }
    #expect(trialRefused)
    let after = await runtime.snapshot()
    let refusedTrialPreservesCommanderAndBodies = after.commander == before.commander && after.bodies == before.bodies
    #expect(refusedTrialPreservesCommanderAndBodies)
    let refusedTrialGrantsNoCommission = after.titheCommissionMission == nil && after.commander.titheCommissionMarkEntitlement == nil
    #expect(refusedTrialGrantsNoCommission)
    let noIssuedContact = NativeTitheCommissionContactSource.current(in: after) == nil
    #expect(noIssuedContact)
    let afterFiles = try ScriptFinanceTestFixture.files(files.save.deletingLastPathComponent())
    #expect(afterFiles == saved)
  }
}
