import Foundation
import Testing

@testable import L337Core

struct EMPAutonomousEpisodeBoundaryTests {
  @Test func zeroNativeDeclarationDoesNotAdmitTheUnqualifiedDrone() throws {
    let ship = try #require(ShipCatalogue.ship("SH125"))
    let source = try #require(OriginalFleetR3Data.contract(for: ship.id))
    let crew = try #require(source.accommodation)
    #expect(crew.nativeAutonomous && crew.nativeCrew == 0 && crew.conversionCrew == 1)
    #expect(EMPState.declaredNativeCrewCount(ship) == 0)
    #expect(!EMPState.hasSupportedCrew(ship))
    #expect(OriginalDetailedHullStage.blocksRuntime(ship.id))
    #expect(throws: (any Error).self) { try OriginalDetailedHullStage.requireRuntime(ship.id) }
    #expect(OriginalFleetRuntimeHullSource.source(for: ship.id) == nil)
    #expect(SalvageCatalogue.empProfile(catalogueShipID: ship.id) == nil)
  }

  @Test func emptyEpisodeIsOnlyAZeroPersonBoundaryAndRetainsItsActualIncident() throws {
    // Use the existing controlled actual-zero pulse to obtain an incident and weapon.
    // The standalone episode below is a validator input, never a SH125 actor or custody record.
    let game = try NativePeopleTestFixture.disabled()
    let source = try NativePeopleTestFixture.source(game)
    let record = try #require(game.commander.nativeEMPCustodyRecord(for: source))
    let original = try #require(record.disableEpisodes.first)
    try #require(record.valid && record.crewTotal > 0 && !original.ejections.isEmpty)
    try #require(original.valid(source: source, crewTotal: record.crewTotal))
    let empty = EMPCrewDisableEpisode(
      incident: original.incident, weapon: original.weapon, weaponOwner: original.weaponOwner,
      ejections: [], actorBindings: original.actorBindings)
    #expect(empty.valid(source: source, crewTotal: 0))
    #expect(!original.valid(source: source, crewTotal: 0))
    for complement in [-1, 1, record.crewTotal, EMPState.maximumPeople + 1] {
      #expect(!empty.valid(source: source, crewTotal: complement))
    }
    let encoded = try JSONEncoder().encode(empty)
    let decoded = try JSONDecoder().decode(EMPCrewDisableEpisode.self, from: encoded)
    #expect(decoded == empty && decoded.ejections.isEmpty)
    #expect(decoded.incident == original.incident && decoded.weapon == original.weapon)
    #expect(game.commander.nativeEMPCustodyRecord(for: source) == record)
    #expect(record.crewTotal > 0 && record.disableEpisodes.first == original)
  }
}
