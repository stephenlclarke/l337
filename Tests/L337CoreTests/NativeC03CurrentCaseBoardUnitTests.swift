import Foundation
import Testing

@testable import L337Core

struct NativeC03CurrentCaseBoardUnitTests {
  @Test func actualBoardAndCatalogueShowTheSameOriginalConsentTask() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    var game = await fixture.runtime.snapshot()
    try openCurrentCase(&game)
    let before = game.commander
    let mission = try #require(game.hollowManifestMission)
    let catalogue = try #require(game.missionCatalogue.first { $0.savedInstance == mission.id })
    let rows = Display.contractDetailRows(game, width: 1200)
    let text = rows.joined(separator: " ")
    #expect(rows.contains("THE HOLLOW MANIFEST / CURRENT CASE"))
    #expect(rows.contains("Garrivek / Galaxy 2"))
    #expect(text.contains(catalogue.objective))
    #expect(catalogue.completed == 1 && catalogue.trialDigest == nil)
    let unchanged = game.commander == before
    #expect(unchanged)
  }

  @Test func missingOriginalCaseCannotFallThroughToTheAcceptanceBriefing() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    var game = await fixture.runtime.snapshot()
    var mission = try #require(game.hollowManifestMission)
    // Negative removal from a genuine commission; no positive replacement case is built.
    mission.savedHollowManifest = nil
    game.commander.scriptState.instances[mission.id] = mission
    try openCurrentCase(&game)
    let before = game.commander
    let rows = Display.contractDetailRows(game, width: 1200)
    let text = rows.joined(separator: " ")
    #expect(rows.contains("THE HOLLOW MANIFEST / CURRENT CASE"))
    #expect(text.contains("The original case record cannot currently be verified."))
    #expect(!text.contains("Confirm opens one audit"))
    #expect(!text.contains("Get each captain's explicit consent"))
    let unchanged = game.commander == before
    #expect(unchanged && mission.completionReceipt == nil)
  }

  private func openCurrentCase(_ game: inout Game) throws {
    game.openContractBoard()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.hollowManifest == .progress })
    game.contractBoard.selection = index
    game.contractBoardKey("return")
    try #require(game.contractBoard.detail && game.contractBoard.selected?.hollowManifest == .progress)
  }
}
