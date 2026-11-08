import Foundation
import Testing

@testable import L337Core

/// Address/layout tests only. The constructed station address is not an actual loaded
/// station, physical ward installation, occupied person, provider or accepting receipt.
struct NativeC03CareWardAccommodationUnitTests {
  private func address(owner: UUID, system: SystemIdentity) -> NativeMainStationIdentity {
    let key = "main-orbital:\(system.galaxy):\(system.system)"
    return .init(world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:\(key)"))
  }

  @Test func exactHaldatorRecipeHasSixDistinctEmptyPlacesInTwoExistingModules() throws {
    let station = address(owner: UUID(), system: NativeHollowManifestDefinition.carrierWorld)
    let fit = try NativeC03CareWardAccommodation.candidate(station: station)
    #expect(fit.valid() && fit.station == station)
    #expect(fit.cabins.map(\.grade) == [.standard, .stateroomDouble])
    #expect(fit.berths.map(\.ordinal) == [0, 1, 2, 3, 0, 1])
    #expect(fit.berths.allSatisfy { $0.use == .empty && $0.mode == .awake })
    #expect(fit.cargoAllocationTonnes == 10 && fit.equipmentCostUnits == 2)
    #expect(Set(fit.cabins.map(\.id) + fit.berths.map(\.id) + [fit.service]).count == 9)
    #expect(fit.emptyHardware.availablePlaces().count == 6 && fit.emptyHardware.people.isEmpty)
    #expect(try NativeC03CareWardAccommodation.candidate(station: station) == fit)
    let other = try NativeC03CareWardAccommodation.candidate(station:
      address(owner: UUID(), system: NativeHollowManifestDefinition.carrierWorld))
    #expect(Set(fit.berths.map(\.id)).isDisjoint(with: Set(other.berths.map(\.id))))
  }

  @Test func wrongStationResourceOrChangedCurrentFittingCannotQualifyTheRecipe() throws {
    let world = NativeHollowManifestDefinition.carrierWorld
    let station = address(owner: UUID(), system: world)
    #expect(throws: NativeC03CareWardAccommodation.Failure.unsupportedStation) {
      try NativeC03CareWardAccommodation.candidate(station: address(owner: station.world,
        system: NativeHollowManifestDefinition.freighterWorld))
    }
    #expect(throws: NativeC03CareWardAccommodation.Failure.unsupportedStation) {
      try NativeC03CareWardAccommodation.candidate(station:
        .init(world: station.world, system: world, resource: UUID()))
    }
    let fit = try NativeC03CareWardAccommodation.candidate(station: station)
    let raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fit)) as? [String: Any])
    var changed = raw
    changed["equipmentCostUnits"] = 0
    let decoded = try JSONDecoder().decode(NativeC03CareWardAccommodation.self,
      from: JSONSerialization.data(withJSONObject: changed))
    #expect(!decoded.valid())
  }
}
