import Foundation
import Testing

@testable import L337Core

struct NativeC02HistoryPrerequisitesUnitTests {
  @Test func actualFreshCommanderCannotMeetTravelAndLarvaalRequirementsFromItsBirthBerth() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    let game = await runtime.snapshot()
    let before = game.commander
    let review = try game.quietChoirHistoryReview()
    #expect(!review.historyRequirementsMet && review.distinctSystems < 4)
    #expect(review.identification == nil && review.issues.count == 2)
    #expect(review.isCurrent(in: game))
    #expect(game.commander == before)
  }

  @Test func travelReviewCannotRemainCurrentAfterCommanderChanges() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    let review = try game.quietChoirHistoryReview()
    game.commander.credits += 1
    #expect(!review.isCurrent(in: game))
    #expect(!review.historyRequirementsMet)
  }

  @Test func trialCannotSupplyActualCommanderTravelEligibility() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    let review = try game.quietChoirHistoryReview()
    game.trialTitle = "Negative isolated context"
    #expect(!review.isCurrent(in: game))
    #expect(throws: SaveError.invalidCommander) { try game.quietChoirHistoryReview() }
  }
}
