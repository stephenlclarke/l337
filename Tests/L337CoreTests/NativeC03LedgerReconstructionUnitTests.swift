import Foundation
import Testing

@testable import L337Core

struct NativeC03LedgerReconstructionUnitTests {
  @Test func realCommissionCannotSubstituteForReceivedOriginalDocumentsOrCompleteLedger() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let instance = try #require(game.hollowManifestMission)
    try #require(instance.milestones == [0])
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: SaveError.invalidCommander) { try game.hollowManifestLedgerReview() }
    #expect(instance.savedHollowManifest?.caseFile == nil)
    #expect(!instance.receipts.contains(NativeC03LedgerReconstructionReceipt.receipt))
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func malformedDocumentDigestsRefuseBeforeReceiptIdentityEncoding() throws {
    // Deliberately UNISSUED negative metadata. No positive case/receipt/native source,
    // provider, log, player arrival, received data or actual ledger is constructed here.
    let owner = UUID()
    let world = NativeHollowManifestDefinition.freighterWorld
    let station = NativeMainStationIdentity(world: owner, system: world,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:1:113"))
    let dock = NativeMainStationDockReceipt(station: station,
      actor: .init(system: world, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    for invalid in ["", String(repeating: "a", count: 1024), String(repeating: "F", count: 64)] {
      let ledger = NativeC03LedgerReconstructionReceipt.Facts(mission: UUID(), owner: owner,
        contact: UUID(), dock: dock, inspections: [UUID(), UUID()], master: UUID(),
        register: UUID(), registerHash: invalid, registerTransfer: UUID(),
        crewSourceRegistration: UUID(), crewLog: UUID(), crewLogHash: invalid,
        crewLogTransfer: UUID(), originalCareTransfer: UUID(), originalKit: UUID(),
        issueCommand: UUID(), carrier: UUID(), inventoryRevision: 0, sequence: 1,
        beforeCaseRevision: 0, afterCaseRevision: 1, physicalTime: 0, calendarSeconds: 0, epoch: UUID())
      #expect(throws: SaveError.invalidCommander) {
        try NativeC03LedgerReconstructionReceipt.identity(ledger)
      }
      let access = NativeC03CrewLogAccessReceipt.Facts(registration: UUID(), document: UUID(),
        documentHash: invalid, careTransfer: UUID(), service: UUID(), owner: owner, dock: dock,
        originalKit: UUID(), issueCommand: UUID(), carrier: UUID(), inventoryRevision: 0,
        beforeCaseRevision: 0, afterCaseRevision: 1, physicalTime: 0, calendarSeconds: 0, epoch: UUID())
      #expect(throws: SaveError.invalidCommander) { try NativeC03CrewLogAccessReceipt.identity(access) }
    }
  }
}
