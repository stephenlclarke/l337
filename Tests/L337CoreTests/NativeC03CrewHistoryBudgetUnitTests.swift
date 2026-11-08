import Foundation
import Testing

@testable import L337Core

/// Empty-container arithmetic and negative-only claim tests. No actual source/person,
/// player pickup, accepted transfer, death or additional terminal contribution is fabricated.
struct NativeC03CrewHistoryBudgetUnitTests {
  @Test func actualCurrentOwnerWithoutSourceRetainsEveryOrdinaryLimitAndNoExtraCredit() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let owner = try #require(game.commander.equipmentOwnerID)
    let custody = NativePeopleCustodyState(owner: owner)
    let before = game.commander
    let budget = try #require(NativeC03CrewHistoryBudget.current(custody: custody, commander: game.commander))
    #expect(budget.terminalContribution == 0)
    #expect(budget.maximumTransfers == 256 && budget.maximumRevision == 512)
    #expect(NativeC03CrewHistoryBudget.maximumRawTransfers == 257)
    #expect(budget.countsWithinLimits(custody))
    #expect(game.commander == before && game.commander.nativePeople?.hollowManifestCrew == nil)
    #expect(NativeC03CrewHistoryBudget.current(
      custody: .init(owner: UUID()), commander: game.commander) == nil)
  }

  @Test func sixFamilyTagsAndAnUnissuedReceiptCannotMintTheAdditionalBudget() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let owner = try #require(game.commander.equipmentOwnerID)
    var custody = NativePeopleCustodyState(owner: owner)
    try #require(NativeC03CrewHistoryBudget.current(custody: custody, commander: game.commander)?
      .terminalContribution == 0)
    let mission = NativeHollowManifestCommission.mission(owner: owner)
    let members: [NativePersonReference] = (0..<6).map {
      .hollowManifestCrew(.init(owner: owner, mission: mission, ordinal: $0))
    }
    // Deliberately unissued negative data: no original source, actual native launch death,
    // provider, player pickup or real accepted receipt exists behind these names/numbers.
    custody.transfers.append(.init(operation: UUID(), members: members, kind: .loss, dock: nil,
      collector: .init(system: NativeHollowManifestDefinition.carrierWorld, visit: 1, entity: 0),
      owner: owner, physicalTime: 0, calendarSeconds: 0,
      beforeCash: game.commander.credits, afterCash: game.commander.credits,
      beforeSlaves: 0, afterSlaves: 0, price: 0, epoch: UUID(), revision: 1))
    custody.revision = 1
    #expect(NativeC03CrewHistoryBudget.current(custody: custody, commander: game.commander) == nil)
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}
