import Foundation
import Testing

@testable import L337Core

struct NativeC03RemedyChoiceUnitTests {
  @Test func onlyTheTwoOriginalRemediesAreOfferedWithExactAuthoredTitles() throws {
    #expect(NativeC03RemedyChoice.allCases.map(\.title) == [
      "Publish the complete custody ledger",
      "Submit the case to the restitution tribunal",
    ])
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(NativeC03RemedyChoice.self, from: Data("\"abandon-evidence\"".utf8))
    }
  }

  @Test func actualCommissionCannotChooseAnOutcomeOrCreateInstitutionalAcceptance() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0])
    let commander = game.commander
    let bodies = game.bodies
    for choice in NativeC03RemedyChoice.allCases {
      #expect(throws: SaveError.invalidCommander) { try game.hollowManifestRemedyReview(choice) }
    }
    #expect(game.hollowManifestMission?.savedHollowManifest?.caseFile == nil)
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func unissuedMalformedSubmissionDigestRefusesBeforeIdentityEncoding() throws {
    // Negative metadata only: no actual filing, publication, office, care, ledger,
    // physical provider, arrival or valid receipt is fabricated.
    let owner = UUID(), world = NativeHollowManifestDefinition.laboratoryWorld
    let station = NativeMainStationIdentity(world: owner, system: world,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:1:27"))
    let dock = NativeMainStationDockReceipt(station: station,
      actor: .init(system: world, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    for invalid in ["", String(repeating: "a", count: 1024), String(repeating: "F", count: 64)] {
      let facts = NativeC03RemedyReceipt.Facts(mission: UUID(), owner: owner, ledger: UUID(),
        ledgerHash: invalid, choice: .publicDisclosure, recipient: UUID(), recipientOperation: UUID(),
        dock: dock, originalKit: UUID(), issueCommand: UUID(), carrier: UUID(), inventoryRevision: 0,
        sequence: 1, beforeCaseRevision: 0, afterCaseRevision: 1,
        physicalTime: 0, calendarSeconds: 0, epoch: UUID())
      #expect(throws: SaveError.invalidCommander) { try NativeC03RemedyReceipt.identity(facts) }
    }
  }
}
