import Foundation
import Testing

@testable import L337Core

/// Actual opening commands and writer round trips; later-stage negative inputs are
/// deliberately unissued data. No test claims a successful physical care or intake.
struct NativeC03WholeFamilyProgressUnitTests {
  @Test func actualOpeningRoundTripKeepsAllLaterStagesUnavailable() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let mission = try #require(game.hollowManifestMission)
    let state = try #require(mission.savedHollowManifest)
    let written = try Data(contentsOf: fixture.files.save)
    let restored = try ScriptSaveStore.read(written, from: fixture.files.save).0
    let coldMission = try #require(restored.scriptState.instances[mission.id])
    let cold = try #require(coldMission.savedHollowManifest)
    #expect(cold == state && cold.crewLogAccess == nil && cold.caseFile == nil)
    #expect(NativeHollowManifestCommission.prefixValid(coldMission))
    #expect(NativeHollowManifestSave.validateClaims(restored))
    #expect(NativeHollowManifestCommission.expectedMilestones(cold) == [0])
    #expect(NativeHollowManifestCommission.expectedReceipts(cold) == [NativeHollowManifestCommission.receipt])
    #expect(NativeHollowManifestCommission.expectedJournal(cold) == NativeHollowManifestCommission.briefing)
    #expect(coldMission.completionReceipt == nil && coldMission.gearIssues.isEmpty)
    #expect(try Data(contentsOf: fixture.files.save) == written)
  }

  @Test func milestoneCountsCannotBypassAnyOfTheNineOriginalObjectives() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let original = try #require(game.hollowManifestMission)
    let bytes = try Data(contentsOf: fixture.files.save)
    for last in 1...9 {
      var claimed = original
      claimed.milestones = Set(0...last)
      var candidate = game.commander
      candidate.scriptState.instances[claimed.id] = claimed
      #expect(!NativeHollowManifestCommission.prefixValid(claimed))
      #expect(!NativeHollowManifestSave.validateClaims(candidate))
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.write(commander: candidate, world: game.scriptWorldSave, to: fixture.files.save)
      }
      #expect(game.hollowManifestMission == original)
    }
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
  }

  @Test func terminalFlagsCannotReplaceOriginalResolutionOrChangeTheSavedOpening() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let original = try #require(game.hollowManifestMission)
    let state = try #require(original.savedHollowManifest)
    let bytes = try Data(contentsOf: fixture.files.save)
    for outcome in [ScriptOutcome.complete, .failed, .abandoned] {
      var claimed = original
      claimed.outcome = outcome
      #expect(!NativeC03CaseClosureSave.terminalClaimsMatch(claimed, state: state))
      #expect(!NativeHollowManifestCommission.prefixValid(claimed))
      var candidate = game.commander
      candidate.scriptState.instances[claimed.id] = claimed
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.write(commander: candidate, world: game.scriptWorldSave, to: fixture.files.save)
      }
    }
    #expect(game.hollowManifestMission == original)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
  }

}
