import Foundation
import Testing

@testable import L337Core

struct NativeC03MissionGalleryUnitTests {
  @Test func readingUnacceptedCatalogueDoesNotAcceptOrPayTheMission() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    let game = await fixture.runtime.snapshot()
    let before = game.commander
    let pack = try #require(game.hollowManifestPack)
    let entry = try #require(game.hollowManifestGalleryEntry(pack))
    #expect(entry.completed == 0 && entry.milestones.count == 10)
    #expect(entry.milestones.allSatisfy { $0.state == "Upcoming" })
    #expect(entry.savedInstance == nil && entry.trialDigest == nil)
    #expect(game.hollowManifestMission == nil && game.commander == before)
  }

  @Test func actualCommissionShowsOriginalNextStepWithoutGrantingTrialOrProgress() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let before = game.commander
    let pack = try #require(game.hollowManifestPack)
    let mission = try #require(game.hollowManifestMission)
    let presentation = game.hollowManifestCasePresentation()
    let entry = try #require(game.hollowManifestGalleryEntry(pack))
    #expect(presentation.completed == 1 && presentation.milestones.count == 10)
    #expect(presentation.milestones[0].state == "Complete" && presentation.milestones[1].state == "Current")
    #expect(presentation.objective.contains("consent") && presentation.destination == "Garrivek / Galaxy 2")
    #expect(entry.savedInstance == mission.id && entry.trialDigest == nil)
    #expect(entry.completed == presentation.completed && entry.objective == presentation.objective)
    #expect(game.hollowManifestCurrentCaseLines().contains(presentation.objective))
    #expect(game.commander == before)
  }

  @Test func forgedCompleteMilestonesCannotProducePaidGalleryStatus() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    var game = await fixture.runtime.snapshot()
    var mission = try #require(game.hollowManifestMission)
    let cash = game.commander.credits
    // Negative corruption of a genuine original commission, never a fabricated positive
    // care, provider, arrival, return, payment, clue or case-closure fixture.
    mission.milestones = Set(0...9)
    mission.outcome = .complete
    game.commander.scriptState.instances[mission.id] = mission
    let presentation = game.hollowManifestCasePresentation()
    #expect(presentation.status == .locked && presentation.completed == 0)
    #expect(presentation.milestones.allSatisfy { $0.state == "Unavailable" })
    #expect(game.commander.credits == cash && mission.completionReceipt == nil)
  }
}
