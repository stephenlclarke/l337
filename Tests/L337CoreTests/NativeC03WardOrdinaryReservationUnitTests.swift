import Foundation
import Testing

@testable import L337Core

/// Actual fresh owner and negative-only claims. No positive ward/provider/arrival/care,
/// person, admission, death or released obligation is invented for these tests.
struct NativeC03WardOrdinaryReservationUnitTests {
  @Test func actualFreshOwnerHasNoPostCareEncumbranceAndProjectionPinsCurrentState() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let commander = game.commander
    let projection = try #require(NativeC03WardOrdinaryReservation.currentPostCare(in: game))
    #expect(projection.reservedAdmissions == 0 && projection.reservedTransfers == 0)
    #expect(projection.reservedRevisions == 0 && projection.countsWithinLimits())
    #expect(projection.isCurrent(in: game))
    var changed = game
    changed.commander.credits += 1
    #expect(!projection.isCurrent(in: changed))
    changed = game
    changed.nativeStationRuntimeEpoch = UUID()
    #expect(!projection.isCurrent(in: changed))
    #expect(game.commander == commander)
  }

  @Test func sixUnissuedFamilyTagsAndDecodedCareCannotCreateReservationOrReleasedCapacity() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let owner = try #require(game.commander.equipmentOwnerID)
    let mission = NativeHollowManifestCommission.mission(owner: owner)
    var custody = NativePeopleCustodyState(owner: owner)
    // Deliberately unissued negative data, with no native birth, physical ward or care.
    let members: [NativePersonReference] = (0..<6).map {
      .hollowManifestCrew(.init(owner: owner, mission: mission, ordinal: $0))
    }
    custody.transfers = [.init(operation: UUID(), members: members, kind: .care, dock: nil,
      collector: .init(system: NativeHollowManifestDefinition.carrierWorld, visit: 1, entity: 0),
      owner: owner, physicalTime: 0, calendarSeconds: 0, beforeCash: game.commander.credits,
      afterCash: game.commander.credits, beforeSlaves: 0, afterSlaves: 0, price: 0,
      epoch: game.nativeStationRuntimeEpoch, revision: 1)]
    custody.revision = 1
    game.commander.savedNativePeopleCustody = custody
    let before = game.commander
    #expect(NativeC03WardOrdinaryReservation.currentPostCare(in: game) == nil)
    #expect(game.commander == before && game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}
