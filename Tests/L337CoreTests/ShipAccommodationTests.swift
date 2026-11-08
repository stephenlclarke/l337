import Foundation
import Testing

@testable import L337Core

private func testAccommodationFit(
  profile: ShipAccommodationProfile, holdTonnes: Int, freightTonnes: Int,
  otherFittedCargoTonnes: Int, otherFittedEquipmentUnits: Int,
  berths: [PassengerBerth], requestedParty: Int = 0, humanoidParty: Bool = true
) -> AccommodationFit {
  let ids = Set(berths.map(\.cabinID))
  return AccommodationFitting.evaluate(
    profile: profile, holdTonnes: holdTonnes, freightTonnes: freightTonnes,
    otherFittedCargoTonnes: otherFittedCargoTonnes,
    otherFittedEquipmentUnits: otherFittedEquipmentUnits,
    cabins: ids.map { OwnedPassengerCabin(id: $0, grade: .stateroomSingle) },
    berths: berths, requestedParty: requestedParty, humanoidParty: humanoidParty)
}
private func currentAccommodationShips() throws -> [CatalogueShip] {
  // Current R3 contains six stations, one capsule, one platform and one probe.
  let nonships: Set<String> = [
    "SH028", "SH034", "SH040", "SH102", "SH141", "SH156", "SH161", "SH162", "SH164",
  ]
  let expected = Set((1...171).map { String(format: "SH%03d", $0) }).subtracting(nonships)
  let ships = ShipCatalogue.all.filter { $0.catalogue.objectKind == .ship }
  try #require(expected.count == 162 && ships.count == 162)
  try #require(Set(ships.map(\.id)) == expected)
  for ship in ships {
    let current = try #require(OriginalFleetR3Data.contract(for: ship.id))
    try #require(current.objectKind == .ship && current.accommodation != nil)
    if ship.id == OriginalImpalaVoyagerActivation.id {
      try #require(OriginalImpalaVoyagerActivation.authenticates(ship))
    }
  }
  return ships
}
private func cobraAccommodation() throws -> ShipAccommodationProfile {
  try ShipAccommodationProfile(ship: #require(ShipCatalogue.ship("SH023")))
}
@Test func commonCrewProfilesAreCompleteAndKeepOperatingQuartersOutsideCargo() throws {
  let ships = try currentAccommodationShips()
  for ship in ships {
    let profile = try ShipAccommodationProfile(ship: ship)
    #expect(profile.operatingCrew >= 1 && profile.intrinsicCrewQuarters >= profile.operatingCrew)
    let report = testAccommodationFit(
      profile: profile, holdTonnes: ship.game!.cargo,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [])
    #expect(report.allowed && report.usableCargo == ship.game!.cargo)
    #expect(report.freeCompatiblePlaces == 0)
    let current = try #require(OriginalFleetR3Data.contract(for: ship.id))
    #expect(current.accommodation?.initialPurchasedCabins == 0)
    #expect(profile.initialCharterBerths == 0)
  }
}
@Test func aPassengerPartyNeedsActuallyFittedSparePlacesAndBothFitBudgets() throws {
  let profile = try cobraAccommodation()
  try #require(profile.shipID == "SH023" && profile.equipmentUnits == 20)
  let hardwareAtBoundary = profile.equipmentUnits - AccommodationFitting.equipmentUnitsPerCabin
  let cabin = PassengerBerth(cabinID: UUID())
  let noCabin = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [], requestedParty: 1)
  #expect(!noCabin.allowed)
  let fits = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 15,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: hardwareAtBoundary, berths: [cabin], requestedParty: 1)
  #expect(fits.allowed && fits.usableCargo == 0 && fits.freeEquipmentUnits == 0)
  let holdFull = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 16,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: hardwareAtBoundary, berths: [cabin], requestedParty: 1)
  #expect(!holdFull.allowed && holdFull.issues.contains { $0.contains("1 more tonne") })
  let equipmentFull = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: profile.equipmentUnits, berths: [cabin], requestedParty: 1)
  #expect(
    !equipmentFull.allowed && equipmentFull.issues.contains { $0.contains("1 more equipment") })
}
@Test func occupiedReservedAndExtraCrewPlacesCannotBeReusedOrStoredAsEmpty() throws {
  let profile = try cobraAccommodation()
  let person = UUID()
  let mission = UUID()
  let occupied = PassengerBerth(cabinID: UUID(), use: .occupied(person: person))
  let reserved = PassengerBerth(cabinID: UUID(), use: .reserved(mission: mission, person: nil))
  let extra = PassengerBerth(cabinID: UUID(), use: .extraCrew(person: UUID()))
  let report = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [occupied, reserved, extra],
    requestedParty: 1)
  #expect(!report.allowed && report.freeCompatiblePlaces == 0 && report.cabinCargo == 15)
  let duplicate = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [
      occupied, PassengerBerth(cabinID: UUID(), use: .reserved(mission: mission, person: person)),
    ])
  #expect(!duplicate.allowed)
  let badLife = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [
      PassengerBerth(cabinID: UUID(), lifeSupportWorking: false, use: .occupied(person: person))
    ])
  #expect(!badLife.allowed)
}
@Test func zeroPhysicalHoldAndAlienCompatibilityDoNotGainFreeAccommodation() throws {
  let ship = try #require(ShipCatalogue.ship("SH040"))
  let cabin = PassengerBerth(cabinID: UUID())
  try #require(ship.catalogue.objectKind == .capsule)
  let capsulePerformance = try #require(ship.game)
  try #require(capsulePerformance.cargo == 0)
  #expect(throws: MissionPackError.self) { try ShipAccommodationProfile(ship: ship) }
  let profile = try cobraAccommodation()
  let zero = testAccommodationFit(
    profile: profile, holdTonnes: capsulePerformance.cargo, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1)
  #expect(!zero.allowed && zero.cabinCargo == 5)
  let alien = testAccommodationFit(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1,
    humanoidParty: false)
  #expect(!alien.allowed && alien.freeCompatiblePlaces == 0)
  let duplicate = testAccommodationFit(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin, cabin])
  #expect(!duplicate.allowed)
}

@Test func everyShipHasAnExplicitAccommodationSourceIncludingCurrentMedusa() throws {
  let ships = try currentAccommodationShips()
  for ship in ships { _ = try ShipAccommodationProfile(ship: ship) }
  let medusa = try #require(ShipCatalogue.ship("SH171"))
  let current = try #require(OriginalFleetR3Data.contract(for: medusa.id))
  let profile = try ShipAccommodationProfile(ship: medusa)
  #expect(profile.operatingCrew == current.accommodation?.operatingCrew)
  #expect(profile.intrinsicCrewQuarters == current.accommodation?.intrinsicCrewPlaces)
  #expect(profile.equipmentUnits == current.fitting?.equipmentUnits)
  #expect(profile.maximumPhysicalCabinModules == current.accommodation?.maximumCabins)
  #expect(profile.initialCharterBerths == 0 && profile.crewStatus == "original-r3-current-fit")
  #expect(profile.crewBasis.contains(current.sourceSHA256))
}

@Test func invalidCabinCustodyDoesNotInventShowroomAccommodationFacts() {
  var commander = Commander()
  commander.accommodation.fitted = [UUID()]
  #expect(!commander.accommodation.valid)
  #expect(
    commander.nativeAccommodationFields.allSatisfy {
      $0.number == nil && $0.text == "Unavailable" && $0.status == "unavailable"
    })
}

@Test(arguments: ["SH008", "SH009"])
func currentGoshawkAccommodationRequiresItsExplicitZeroPurchasedCabinCount(id: String) throws {
  let ship = try #require(ShipCatalogue.ship(id))
  let current = try #require(OriginalFleetR3Data.contract(for: id))
  try #require(ship.game == current.performance)
  let declaredTools: Set<ComponentUtility> = id == "SH008" ? [] : [.salvageCutter]
  try #require(ship.game?.workTools == declaredTools)
  let original = try ShipAccommodationProfile(ship: ship)
  #expect(original.initialCharterBerths == 0)
  let originalObject = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
  var object = originalObject
  var profiles = try #require(object["profiles"] as? [[String: Any]])
  let index = try #require(profiles.firstIndex { $0["group"] as? String == "project-refit-v1" })
  var fields = try #require(profiles[index]["fields"] as? [[String: Any]])
  let matching = fields.indices.filter { fields[$0]["key"] as? String == "initial_charter_passenger_berths" }
  try #require(matching.count == 1)
  try #require(fields[matching[0]]["number"] as? Double == 0)
  fields.remove(at: matching[0])
  profiles[index]["fields"] = fields
  object["profiles"] = profiles
  let missing = try JSONDecoder().decode(
    CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(OriginalFleetR3Fitting.contract(for: missing) == nil)
  #expect(throws: MissionPackError.self) { try ShipAccommodationProfile(ship: missing) }
  var missingToolsObject = originalObject
  var game = try #require(missingToolsObject["game"] as? [String: Any])
  let removedTools = game.removeValue(forKey: "workTools")
  try #require(removedTools != nil)
  missingToolsObject["game"] = game
  let missingTools = try JSONDecoder().decode(
    CatalogueShip.self, from: JSONSerialization.data(withJSONObject: missingToolsObject))
  #expect(missingTools.game?.workTools == nil)
  #expect(OriginalFleetR3Fitting.contract(for: missingTools) == nil)
  #expect(throws: MissionPackError.self) { try ShipAccommodationProfile(ship: missingTools) }
  #expect(try ShipAccommodationProfile(ship: ship) == original)
}
