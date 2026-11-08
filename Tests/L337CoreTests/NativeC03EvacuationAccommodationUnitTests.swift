import Foundation
import Testing

@testable import L337Core

/// Pure source-recipe checks, not actual people/module/native admission or rescue acceptance.
struct NativeC03EvacuationAccommodationUnitTests {
  @Test func sixPlannedOriginalAddressesNeedOneExplicitPhysicalCabin() throws {
    let owner = UUID(), mission = UUID()
    let recipe = try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: mission)
    let source = try NativeHollowManifestFleetSource.resolve(.evacuationLaunch)
    #expect(recipe.valid(owner: owner, mission: mission))
    #expect(source.accommodation.intrinsicCrewPlaces == 2)
    #expect(source.accommodation.initialPurchasedCabins == 0)
    #expect(source.fitting.roleKitIncluded == false)
    #expect(recipe.assignments.count == 6)
    #expect(Set(recipe.assignments.map(\.person.id)).count == 6)
    #expect(recipe.assignments.allSatisfy { $0.massKilograms == 90 })
    #expect(recipe.assignments.reduce(0) { $0 + $1.massKilograms } == 540)
    #expect(recipe.assignments.allSatisfy {
      $0.person.belongsTo(owner: owner, mission: mission, source: recipe.source)
        && $0.person.ordinal == $0.ordinal
    })
    #expect(recipe.assignments.prefix(2).map(\.place) == [.intrinsic(0), .intrinsic(1)])
    #expect(recipe.assignments.dropFirst(2).map(\.place) == recipe.berths.map { .cabin($0.id) })
    #expect(recipe.cabin.grade == .standard && recipe.berths.count == 4)
    #expect(recipe.cargoCostTonnes == 5 && recipe.remainingHoldTonnes == 79)
    #expect(recipe.equipmentCostUnits == 1 && recipe.remainingEquipmentUnits == 21)
    #expect(recipe.specificationSHA256 == source.physical.specificationSHA256)
    #expect(recipe.referencedGeometrySHA256 == source.physical.model.sourceSHA256)
    #expect(recipe.emptyHardware.valid && recipe.emptyHardware.people.isEmpty)
    #expect(recipe.emptyHardware.availablePlaces().count == 4)
    #expect(recipe.berths.allSatisfy { $0.use == .empty })
  }

  @Test func originalAddressesStayStableAndSeparateFromOtherCasesAndOwners() throws {
    let owner = UUID(), mission = UUID()
    let first = try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: mission)
    #expect(try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: mission) == first)
    let ownIDs = ids(first)
    #expect(ownIDs.count == 14)
    let otherCase = try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: UUID())
    let otherOwner = try NativeC03EvacuationAccommodation.candidate(owner: UUID(), mission: mission)
    #expect(ownIDs.isDisjoint(with: ids(otherCase)))
    #expect(ownIDs.isDisjoint(with: ids(otherOwner)))
    #expect(!first.valid(owner: UUID(), mission: mission))
    #expect(!first.valid(owner: owner, mission: UUID()))
  }

  @Test func unfittedBrokenOrStoredHardwareCannotSupplyPassengerPlaces() throws {
    let recipe = try NativeC03EvacuationAccommodation.candidate(owner: UUID(), mission: UUID())
    var hardware = recipe.emptyHardware
    hardware.fitted = []
    #expect(hardware.availablePlaces().isEmpty)
    hardware = recipe.emptyHardware
    hardware.ownedCabins[0].lifeSupportWorking = false
    #expect(hardware.availablePlaces().isEmpty)
    hardware = recipe.emptyHardware
    hardware.ownedBerths[0].lifeSupportWorking = false
    #expect(hardware.availablePlaces().count == 3)
    hardware = recipe.emptyHardware
    hardware.ownedBerths[0].humanoidCompatible = false
    #expect(hardware.availablePlaces().count == 3)
    hardware = recipe.emptyHardware
    hardware.ownedBerths.removeLast()
    #expect(!hardware.valid)
  }

  @Test func currentRecipeRoundTripsAndRejectsChangedSourceCostsOrAssignments() throws {
    let owner = UUID(), mission = UUID()
    let recipe = try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: mission)
    let data = try JSONEncoder().encode(recipe)
    #expect(try JSONDecoder().decode(NativeC03EvacuationAccommodation.self, from: data) == recipe)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for key in ["shipID", "specificationSHA256", "referencedGeometrySHA256", "assignments",
      "remainingHoldTonnes", "remainingEquipmentUnits"] {
      var changed = object
      if key == "assignments" { changed[key] = [] as [Any] }
      else if key.hasPrefix("remaining") { changed[key] = 100_000 }
      else { changed[key] = "changed" }
      let bytes = try JSONSerialization.data(withJSONObject: changed)
      let decoded = try JSONDecoder().decode(NativeC03EvacuationAccommodation.self, from: bytes)
      #expect(!decoded.valid(owner: owner, mission: mission))
    }
    var changed = object
    var assignments = try #require(changed["assignments"] as? [[String: Any]])
    assignments[0]["massKilograms"] = 91
    changed["assignments"] = assignments
    let differentMass = try JSONDecoder().decode(NativeC03EvacuationAccommodation.self,
      from: JSONSerialization.data(withJSONObject: changed))
    #expect(!differentMass.valid(owner: owner, mission: mission))
    assignments[0].removeValue(forKey: "massKilograms")
    changed["assignments"] = assignments
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(NativeC03EvacuationAccommodation.self,
        from: JSONSerialization.data(withJSONObject: changed))
    }
  }

  private func ids(_ recipe: NativeC03EvacuationAccommodation) -> Set<UUID> {
    Set([recipe.source, recipe.originalCarrier, recipe.originalLaunch, recipe.cabin.id]
      + recipe.berths.map(\.id) + recipe.assignments.map(\.person.id))
  }
}
