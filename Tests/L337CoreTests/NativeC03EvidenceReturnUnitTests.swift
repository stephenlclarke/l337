import Foundation
import Testing

@testable import L337Core

struct NativeC03EvidenceReturnUnitTests {
  @Test func actualCommissionCannotRemoveKitOrReturnUnreceivedOriginalEvidence() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0])
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: SaveError.invalidCommander) { try game.hollowManifestEvidenceReturnReview() }
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.hollowManifestMission?.savedHollowManifest?.caseFile == nil)
  }

  @Test func unissuedReturnHashesRefuseBeforeIdentityEncoding() throws {
    for invalid in ["", String(repeating: "a", count: 1024), String(repeating: "F", count: 64)] {
      for index in 0..<3 {
        var hashes = Array(repeating: String(repeating: "a", count: 64), count: 3)
        hashes[index] = invalid
        let facts = unissuedFacts(hashes: hashes)
        #expect(throws: SaveError.invalidCommander) { try NativeC03EvidenceReturnReceipt.identity(facts) }
      }
    }
  }

  @Test func unissuedReturnSourceRefusesUnboundedOrUnrelatedEquipmentClaims() throws {
    let mission = UUID()
    for source in [
      EquipmentIssueSource(mission: UUID(), resource: NativeHollowManifestKitDefinition.resource,
        packDigest: NativeHollowManifestCommission.digest),
      EquipmentIssueSource(mission: mission, resource: String(repeating: "x", count: 1024),
        packDigest: NativeHollowManifestCommission.digest),
      EquipmentIssueSource(mission: mission, resource: NativeHollowManifestKitDefinition.resource,
        packDigest: String(repeating: "a", count: 1024)),
    ] {
      let facts = unissuedFacts(mission: mission, source: source)
      #expect(throws: SaveError.invalidCommander) { try NativeC03EvidenceReturnReceipt.identity(facts) }
    }
  }

  // Negative metadata only. No positive receiving receipt, equipment receipt, real kit,
  // provider, source, care, data transfer or actual arrival is fabricated by this helper.
  private func unissuedFacts(mission: UUID = UUID(), source: EquipmentIssueSource? = nil,
    hashes: [String] = Array(repeating: String(repeating: "a", count: 64), count: 3))
    -> NativeC03EvidenceReturnReceipt.Facts
  {
    let owner = UUID(), world = NativeHollowManifestKitDefinition.returnLocation
    let station = NativeMainStationIdentity(world: owner, system: world,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:120"))
    let dock = NativeMainStationDockReceipt(station: station,
      actor: .init(system: world, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    return .init(mission: mission, owner: owner, remedy: UUID(), recipient: UUID(),
      receivingOperation: UUID(), dock: dock, register: UUID(), registerHash: hashes[0],
      registerTransfer: UUID(), crewLog: UUID(), crewLogHash: hashes[1], crewLogTransfer: UUID(),
      originalKit: UUID(), itemHash: hashes[2], issueCommand: UUID(), equipmentCommand: UUID(),
      equipmentSource: source ?? EquipmentIssueSource(mission: mission,
        resource: NativeHollowManifestKitDefinition.resource, packDigest: NativeHollowManifestCommission.digest),
      carrier: UUID(), beforeInventoryRevision: 0, afterInventoryRevision: 1,
      beforeCaseRevision: 0, afterCaseRevision: 1, sequence: 1,
      physicalTime: 0, calendarSeconds: 0, epoch: UUID())
  }
}
