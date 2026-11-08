import Foundation
import Testing

@testable import L337Core

struct NativeC03CatalogueReachabilityUnitTests {
  @Test func catalogueUsesTheOriginalCaseBeforeAndAfterRealCommission() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    let offered = await fixture.runtime.snapshot()
    let pack = try #require(offered.hollowManifestPack)
    let before = offered.commander
    let offeredEntries = offered.missionCatalogue.filter { $0.name == pack.manifest.mission.title }
    let entry = try #require(offeredEntries.first)
    #expect(offeredEntries.count == 1)
    #expect(entry.savedInstance == nil && entry.trialDigest == nil)
    #expect(entry.completed == 0 && entry.milestones.count == 10)
    #expect(entry.milestones.allSatisfy { $0.state == "Upcoming" })
    let offerUnchanged = offered.commander == before
    #expect(offerUnchanged && offered.hollowManifestMission == nil)

    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let mission = try #require(accepted.hollowManifestMission)
    let acceptedBefore = accepted.commander
    let current = try #require(accepted.missionCatalogue.first { $0.savedInstance == mission.id })
    #expect(current.trialDigest == nil && current.completed == 1)
    try #require(current.milestones.count == 10)
    #expect(current.milestones[0].state == "Complete")
    #expect(current.milestones[1].state == "Current")
    #expect(current.objective.contains("consent"))
    #expect(current.destination == "Garrivek / Galaxy 2")
    #expect(accepted.hollowManifestCurrentCaseLines().contains(current.objective))
    let acceptedUnchanged = accepted.commander == acceptedBefore
    #expect(acceptedUnchanged)
  }

  @Test func catalogueRefusesForgedTerminalProgressWithoutExposingAMilestoneOrTrial() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    var game = await fixture.runtime.snapshot()
    var mission = try #require(game.hollowManifestMission)
    // Corrupt a genuinely accepted case. No care, resolution, return or terminal is invented.
    mission.milestones = Set(0...9)
    mission.outcome = .complete
    game.commander.scriptState.instances[mission.id] = mission
    let before = game.commander
    let entry = try #require(game.missionCatalogue.first { $0.savedInstance == mission.id })
    #expect(entry.status == .locked && entry.completed == 0 && entry.trialDigest == nil)
    #expect(entry.milestones.count == 10)
    #expect(entry.milestones.allSatisfy { $0.state == "Unavailable" })
    #expect(entry.objective == "The original case record cannot currently be verified.")
    let unchanged = game.commander == before
    #expect(unchanged && mission.completionReceipt == nil)
  }
}
