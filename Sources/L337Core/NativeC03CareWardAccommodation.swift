import Foundation

/// Root-adopted Haldator service fitting recipe only. A station address, this layout or its
/// working flags do not install hardware, register a service, supply power or accept people.
struct NativeC03CareWardAccommodation: Codable, Equatable, Sendable {
  enum Failure: Error, Equatable { case unsupportedStation }

  let station: NativeMainStationIdentity
  let service: UUID
  let cabins: [OwnedPassengerCabin]
  let berths: [PassengerBerth]
  let cargoAllocationTonnes: Int
  let equipmentCostUnits: Int

  static func candidate(station: NativeMainStationIdentity) throws -> Self {
    guard station.valid, station.system == NativeHollowManifestDefinition.carrierWorld,
      PassengerCabinGrade.standard.places == 4, PassengerCabinGrade.stateroomDouble.places == 2,
      PassengerCabinGrade.standard.supportsAwake, PassengerCabinGrade.stateroomDouble.supportsAwake
    else { throw Failure.unsupportedStation }
    let prefix = "c03-haldator-care-v1:\(station.world):\(station.resource)"
    let service = ScriptIdentity.uuid(prefix)
    let grades: [PassengerCabinGrade] = [.standard, .stateroomDouble]
    var cabins: [OwnedPassengerCabin] = []
    var berths: [PassengerBerth] = []
    for (module, grade) in grades.enumerated() {
      let cabin = OwnedPassengerCabin(id: ScriptIdentity.uuid("\(prefix):module:\(module)"),
        grade: grade, lifeSupportWorking: true, stasisWorking: true)
      cabins.append(cabin)
      for ordinal in 0..<grade.places {
        let place = berths.count
        berths.append(.init(id: ScriptIdentity.uuid("\(prefix):place:\(place)"), cabinID: cabin.id,
          cabinGrade: grade, ordinal: ordinal, mode: .awake, privateCabin: false,
          lifeSupportWorking: true, humanoidCompatible: true, use: .empty))
      }
    }
    return .init(station: station, service: service, cabins: cabins, berths: berths,
      cargoAllocationTonnes: grades.count * AccommodationFitting.tonnesPerCabin,
      equipmentCostUnits: grades.count * AccommodationFitting.equipmentUnitsPerCabin)
  }

  /// Proposed actual installation output, not an installation producer. No person is
  /// assigned and no NativeStationWorld is changed by reading this empty fitting recipe.
  var emptyHardware: ShipAccommodation {
    var hardware = ShipAccommodation()
    hardware.ownedCabins = cabins
    hardware.ownedBerths = berths
    hardware.fitted = Set(cabins.map(\.id))
    return hardware
  }

  func valid() -> Bool {
    guard cabins.count == 2, berths.count == 6,
      emptyHardware.valid, emptyHardware.people.isEmpty,
      emptyHardware.availablePlaces().count == 6,
      let expected = try? Self.candidate(station: station)
    else { return false }
    return self == expected
  }
}
