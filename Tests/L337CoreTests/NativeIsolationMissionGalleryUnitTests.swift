import Foundation
import Testing

@testable import L337Core

struct NativeIsolationMissionGalleryUnitTests {
  @Test func actualOriginalAcceptanceAppearsAsTheParentJobWithoutGrantingWork() async throws {
    let fixture = try await IsolationWorkFixture()
    let game = fixture.game
    let pack = try #require(game.scriptPacks.first(where: NativeIsolationWorkParent.matches))
    let childPack = try #require(game.scriptPacks.first(where: NativeIsolationWorkPack.matches))
    let parent = try #require(game.isolationWorkParentMission)
    let before = game.commander
    let native = try #require(game.isolationParentGalleryEntry(pack))
    let catalogue = try #require(game.missionCatalogue.first { $0.savedInstance == parent.id })
    #expect(native.status == .active && native.completed == 1 && native.trialDigest == nil)
    #expect(native.destination == "Renas / Galaxy 1")
    #expect(native.objective == "Isolate and verify both original Renas feeders with the original programmer.")
    #expect(native.milestones.first { $0.state == "Current" }?.title == "Verify both original isolations")
    #expect(catalogue.objective == native.objective && catalogue.destination == native.destination)
    #expect(game.isolationParentGalleryEntry(childPack) == nil)
    #expect((try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: game.commander)) != nil)
    #expect(game.isolationWorkChild?.savedIsolationWork?.modules.allSatisfy { $0.verification == nil } == true)
    let unchanged = game.commander == before
    #expect(unchanged)
  }

  @Test func actualUnpaidReturnAndColdHistoryDoNotRequireTheOriginalStillHeld() async throws {
    let fixture = try await IsolationWorkFixture()
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    let initial = await runtime.snapshot()
    try await runtime.save(to: files.save)
    try await NativeIsolationPublicationAssertions.reject(.missingChild, runtime: runtime, at: files.save)
    try await NativeIsolationLoadAssertions.reject(.missingChild, runtime: runtime, at: files.save)
    try await runtime.scriptCommand { try $0.abandonIsolationWork() }
    let owed = await runtime.snapshot()
    let pack = try #require(owed.scriptPacks.first(where: NativeIsolationWorkParent.matches))
    let owedParent = try #require(owed.isolationWorkParentMission)
    let terminal = try #require(owedParent.savedIsolationWorkParent?.terminal)
    let stillOwed = try #require(owed.isolationParentGalleryEntry(pack))
    #expect(stillOwed.status == .failed && stillOwed.objective.contains("still owed"))
    #expect(stillOwed.destination == "Return original / Avenor / Galaxy 1")
    try await runtime.scriptCommand { candidate in
      try candidate.confirmIsolationWorkParent(candidate.isolationWorkParentReview(.returnUnpaid))
    }
    let ended = await runtime.snapshot()
    try await NativeIsolationPublicationAssertions.reject(.orphanedSource, runtime: runtime, at: files.save)
    try await NativeIsolationLoadAssertions.reject(.orphanedSource, runtime: runtime, at: files.save)
    try await NativeIsolationPublicationAssertions.reject(.lateReturn, runtime: runtime, at: files.save)
    try await NativeIsolationLoadAssertions.reject(.lateReturn, runtime: runtime, at: files.save)
    let parent = try #require(ended.isolationWorkParentMission)
    let beforeRead = ended.commander
    let returned = try #require(ended.isolationParentGalleryEntry(pack))
    #expect(returned.status == .failed && returned.completed == 1 && returned.trialDigest == nil)
    #expect(returned.objective.contains("has been returned"))
    #expect(returned.reward == "No reward or clue awarded for this ending.")
    #expect(parent.savedIsolationWorkParent?.terminal == terminal)
    #expect(parent.contract?.settlementAmount == 0 && ended.commander.credits == initial.commander.credits)
    #expect(ended.commander.scriptState.savedClueJournal == nil)
    #expect(ended.isolationWorkChild?.savedIsolationWork == initial.isolationWorkChild?.savedIsolationWork)
    #expect((try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: ended.commander)) == nil)
    let unchanged = ended.commander == beforeRead
    #expect(unchanged)
    let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
    var coldGame = ended
    coldGame.commander = cold
    let coldEntry = try #require(coldGame.isolationParentGalleryEntry(pack))
    #expect(coldEntry.status == returned.status && coldEntry.objective == returned.objective)
    #expect(coldEntry.completed == 1 && coldEntry.reward == returned.reward)
    coldGame.openContractBoard()
    let progress = try #require(coldGame.contractBoard.rows.firstIndex { $0.isolationWorkParent == .progress })
    coldGame.contractBoard.selection = progress
    coldGame.contractBoardKey("return")
    let board = Display.contractDetailRows(coldGame, width: 1200).joined(separator: " ")
    #expect(board.contains(coldEntry.objective))
    #expect(board.contains("No reward or clue awarded for this ending."))
    let coldUnchanged = coldGame.commander == cold
    #expect(coldUnchanged)
    coldGame.commander.scriptState.instances.removeValue(forKey: parent.id)
    #expect(!NativeIsolationWorkSave.validateClaims(coldGame.commander))
    let orphaned = try #require(coldGame.isolationParentGalleryEntry(pack))
    #expect(orphaned.status == .locked && orphaned.completed == 0 && orphaned.trialDigest == nil)
    #expect(orphaned.objective == "The original isolation job record cannot currently be verified.")
  }

  @Test func unsupportedSuccessfulClaimsCannotBecomePaidParentGalleryProgress() async throws {
    let fixture = try await IsolationWorkFixture()
    var game = fixture.game
    let pack = try #require(game.scriptPacks.first(where: NativeIsolationWorkParent.matches))
    var parent = try #require(game.isolationWorkParentMission)
    // Corrupt a real accepted job. No terminal, physical verification or receiver is supplied.
    parent.outcome = .complete
    parent.milestones = [0, 1, 2]
    game.commander.scriptState.instances[parent.id] = parent
    let before = game.commander
    let native = try #require(game.isolationParentGalleryEntry(pack))
    let catalogue = try #require(game.missionCatalogue.first { $0.savedInstance == parent.id })
    #expect(native.status == .locked && native.completed == 0 && native.trialDigest == nil)
    #expect(native.milestones.allSatisfy { $0.state == "Unavailable" })
    #expect(native.reward == "No settlement available.")
    #expect(catalogue.status == .locked && catalogue.completed == 0)
    game.openContractBoard()
    let progress = try #require(game.contractBoard.rows.firstIndex { $0.isolationWorkParent == .progress })
    game.contractBoard.selection = progress
    game.contractBoardKey("return")
    let board = Display.contractDetailRows(game, width: 1200).joined(separator: " ")
    #expect(board.contains("The original isolation job record cannot currently be verified."))
    #expect(!board.contains("JOB COMPLETE"))
    game.scriptPacks.removeAll()
    let missingContent = Display.contractDetailRows(game, width: 1200).joined(separator: " ")
    #expect(missingContent.contains("The original isolation job or its content is unavailable."))
    #expect(!missingContent.contains("JOB COMPLETE"))
    let unchanged = game.commander == before
    #expect(unchanged && parent.completionReceipt == nil)
    game.scriptPacks = fixture.game.scriptPacks
    game.commander.scriptState.instances.removeValue(forKey: parent.id)
    let missingParent = Display.contractDetailRows(game, width: 1200).joined(separator: " ")
    #expect(missingParent.contains("The original isolation job or its content is unavailable."))
    #expect(!missingParent.contains("Review the original programmer loan"))
  }
}
