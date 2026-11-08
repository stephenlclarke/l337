import Foundation
import Testing

@testable import L337Core

struct NativeC03CaseClosureUnitTests {
  @Test func actualCommissionCannotCollectPaymentWithoutReceivedEvidenceAndResolution() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0])
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: SaveError.invalidCommander) { try game.hollowManifestCaseClosureReview() }
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.scriptState.savedClueJournal == commander.scriptState.savedClueJournal)
  }

  @Test func invalidCreditMetadataRefusesBeforeAdditionOrReceiptEncoding() throws {
    for before in [Int.min, -1, 4_294_967_295 - NativeHollowManifestDefinition.terminalRewardTenths + 1, Int.max] {
      let facts = unissuedFacts(before: before, after: 0)
      #expect(throws: SaveError.invalidCommander) { try NativeC03CaseClosureReceipt.identity(facts) }
    }
    let changedPayment = unissuedFacts(before: 0, after: NativeHollowManifestDefinition.terminalRewardTenths + 1)
    #expect(throws: SaveError.invalidCommander) { try NativeC03CaseClosureReceipt.identity(changedPayment) }
  }

  @Test func genericCompletionMetadataDoesNotCompleteTheActualOpeningCase() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let mission = try #require(game.hollowManifestMission)
    let receipt = ScriptCompletionReceipt(instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: .complete,
      sequence: game.commander.scriptState.nextEvent, causeKind: "mission.receipted", cause: nil,
      committed: game.scriptEventContext(mission), revision: mission.revision,
      milestones: Array(0...9), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [NativeHollowManifestKitDefinition.resource], settlementAmount: nil, choices: nil)
    #expect(!NativeC03CaseClosureSave.validCompletion(receipt, state: mission, engine: game.commander.scriptState))
    #expect(mission.outcome == .active && mission.completionReceipt == nil)
  }

  @Test func exactProductionContentCannotTurnOpeningMetadataIntoACompletionOrClue() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let original = try #require(game.hollowManifestMission)
    var claimed = original
    claimed.outcome = .complete
    claimed.revision += 1
    claimed.milestones = Set(0...9)
    var engine = game.commander.scriptState
    engine.nextEvent += 1
    claimed.acknowledge(engine.nextEvent)
    // Deliberately forged generic completion metadata, not received evidence or resolution.
    // Its generic fields are consistent so the C03-specific validator must reject it.
    let receipt = ScriptCompletionReceipt(instance: claimed.id, definition: claimed.definition,
      version: claimed.version, digest: claimed.digest, outcome: .complete,
      sequence: engine.nextEvent, causeKind: "mission.receipted",
      cause: game.scriptEventContext(original), committed: game.scriptEventContext(claimed),
      revision: claimed.revision, milestones: claimed.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [], settlementAmount: nil, choices: nil)
    claimed.completionReceipt = receipt
    engine.instances[claimed.id] = claimed
    // A design-catalogue name is insufficient: integration must register this exact executable
    // pin together with the native completion predicate. Pin matching alone grants no award.
    let pin = try #require(ScriptClueTrustCatalog.production.pin(for: receipt))
    #expect(pin.sourceID == NativeHollowManifestDefinition.logicalSourceID)
    #expect(!NativeC03CaseClosureSave.validCompletion(receipt, state: claimed, engine: engine))
    #expect(!receipt.valid(for: claimed, engine: engine))
    var candidate = game
    candidate.commander.scriptState = engine
    let before = candidate.commander
    #expect(throws: SaveError.invalidCommander) {
      try candidate.awardScriptClue(previous: original, next: claimed, trust: .production)
    }
    #expect(candidate.commander == before)
    #expect(candidate.commander.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
    #expect(game.hollowManifestMission == original && original.outcome == .active)
  }

  // Invalid scalar metadata only; never an actual positive institution, source, arrival,
  // payment, receiving or completion receipt.
  private func unissuedFacts(before: Int, after: Int) -> NativeC03CaseClosureReceipt.Facts {
    let owner = UUID(), world = NativeHollowManifestDefinition.issuer
    let station = NativeMainStationIdentity(world: owner, system: world,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:1:120"))
    let dock = NativeMainStationDockReceipt(station: station,
      actor: .init(system: world, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    return .init(mission: UUID(), owner: owner, evidenceReturn: UUID(), remedy: UUID(), resolution: UUID(),
      originalCareTransfer: UUID(), dock: dock, creditsBefore: before, creditsAfter: after,
      beforeCaseRevision: 0, afterCaseRevision: 1, sourceSequence: 1, eventSequence: 1,
      physicalTime: 0, calendarSeconds: 0, epoch: UUID())
  }
}
