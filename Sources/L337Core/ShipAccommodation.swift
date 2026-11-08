import Foundation

/// Common project fitting, kept separate from native edition-specific cabin/crew rules.
public struct ShipAccommodationProfile: Sendable, Equatable {
  public let shipID: String
  public let operatingCrew: Int
  public let intrinsicCrewQuarters: Int
  public let equipmentUnits: Int
  public let initialCharterBerths: Int
  public let crewBasis: String
  public let crewStatus: String
  public let maximumPhysicalCabinModules: Int?
  public init(ship: CatalogueShip) throws {
    if let source = OriginalFleetR3Fitting.contract(for: ship),
      let crew = source.accommodation,
      let nativeUnits = OriginalFleetR3Fitting.nativeEquipmentUnits(for: ship, contract: source)
    {
      shipID = source.id
      operatingCrew = crew.operatingCrew
      intrinsicCrewQuarters = crew.intrinsicCrewPlaces
      equipmentUnits = nativeUnits
      initialCharterBerths = crew.initialPurchasedCabins
      maximumPhysicalCabinModules = crew.maximumCabins
      crewBasis = "Current original R3 contract " + source.sourceSHA256
      crewStatus = "original-r3-current-fit"
      return
    }
    if ship.id == OriginalImpalaVoyagerActivation.id {
      guard OriginalImpalaVoyagerActivation.authenticates(ship),
        ship.profiles.count == 1, let profile = ship.profiles.first,
        profile.id == "ORIGINAL-IMPALA-R3-SH007", profile.group == "original-r3-source-stage",
        Set(profile.fields.map(\.key)).count == profile.fields.count
      else { throw MissionPackError("The original Impala source profile is unavailable.") }
      func nativeField(_ key: String, unit: String) throws -> ShipSpec {
        guard let field = profile.fields.first(where: { $0.key == key }), field.unit == unit,
          field.status == "declared-original-r3-planning"
        else { throw MissionPackError("The original Impala accommodation source is incomplete.") }
        return field
      }
      func nativeCount(_ key: String, unit: String) throws -> Int {
        guard let value = try nativeField(key, unit: unit).number,
          value.isFinite, (0...100000).contains(value), value.rounded() == value
        else { throw MissionPackError("Original Impala counts must be finite source integers.") }
        return Int(value)
      }
      let placesUnit = "source r3 places/modules"
      let crewKey = "original.r3.accommodation.minimumOperatingCrewIncludingCommander"
      let required = try nativeCount(crewKey, unit: placesUnit)
      let places = try nativeCount("original.r3.accommodation.intrinsicCrewPlaces", unit: placesUnit)
      let initial = try nativeCount("original.r3.accommodation.initialPurchasedCabins", unit: placesUnit)
      let maximum = try nativeCount(
        "original.r3.accommodation.maximumPhysicalCabinModules", unit: placesUnit)
      let budget = try nativeCount(
        "original.r3.fitting.equipmentBudgetUnits", unit: "source r3 planning units")
      guard required == 2, places == 2, initial == 0, maximum == 12, budget == 26 else {
        throw MissionPackError("The original Impala source counts do not match its adopted layout.")
      }
      shipID = ship.id
      operatingCrew = required
      intrinsicCrewQuarters = places
      equipmentUnits = budget
      initialCharterBerths = initial
      maximumPhysicalCabinModules = maximum
      crewBasis = try nativeField(crewKey, unit: placesUnit).basis
      crewStatus = "authored-r3-native-adapter"
      return
    }
    guard OriginalFleetR3Data.contract(for: ship.id) == nil else {
      throw MissionPackError("The current original hull requires its exact native fitting adapter.")
    }
    maximumPhysicalCabinModules = nil
    guard ship.game != nil,
      let profile = ship.profiles.first(where: { $0.group == "project-refit-v1" })
    else {
      throw MissionPackError("This hull has no selected common accommodation profile.")
    }
    func field(_ name: String) throws -> ShipSpec {
      guard let value = profile.fields.first(where: { $0.key == name }) else {
        throw MissionPackError("The selected accommodation profile is incomplete.")
      }
      return value
    }
    func integer(_ name: String) throws -> Int {
      guard let value = try field(name).number, value.isFinite, (0...100000).contains(value),
        value.rounded() == value
      else {
        throw MissionPackError("Accommodation counts must be finite nonnegative integers.")
      }
      return Int(value)
    }
    shipID = ship.id
    operatingCrew = try integer("required_crew_including_commander")
    intrinsicCrewQuarters = try integer("reserved_crew_accommodation")
    equipmentUnits = try integer("equipment_capacity_units")
    initialCharterBerths = try integer("initial_charter_passenger_berths")
    crewBasis = try field("required_crew_including_commander").basis
    crewStatus = try field("required_crew_including_commander").status
    guard operatingCrew >= 1, intrinsicCrewQuarters >= operatingCrew else {
      throw MissionPackError("The required operating complement needs its intrinsic quarters.")
    }
  }
}
public enum PassengerPlaceUse: Sendable, Equatable, Codable {
  case empty
  case occupied(person: UUID)
  case nativePerson(NativePersonReference)
  case reserved(mission: UUID, person: UUID?)
  case extraCrew(person: UUID)
  var personID: UUID? {
    switch self {
    case .empty: nil
    case .nativePerson(let person): person.nativeID
    case .occupied(let id), .extraCrew(let id): id
    case .reserved(_, let id): id
    }
  }
  var used: Bool { self != .empty }
}
public struct PassengerBerth: Sendable, Equatable, Codable, Identifiable {
  public let id: UUID
  public let cabinID: UUID
  public let cabinGrade: PassengerCabinGrade
  public let ordinal: Int
  public var mode: PassengerTransportMode
  public var privateCabin: Bool
  public var lifeSupportWorking: Bool
  public var humanoidCompatible: Bool
  public var use: PassengerPlaceUse
  private enum CodingKeys: String, CodingKey {
    case id, cabinID, cabinGrade, ordinal, mode, privateCabin, lifeSupportWorking,
      humanoidCompatible, use
  }
  public init(from decoder: any Decoder) throws {
    try validateCabinRecordKeys(
      decoder,
      [
        "id", "cabinID", "cabinGrade", "ordinal", "mode", "privateCabin", "lifeSupportWorking",
        "humanoidCompatible", "use",
      ])
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    id = try fields.decode(UUID.self, forKey: .id)
    cabinID = try fields.decode(UUID.self, forKey: .cabinID)
    cabinGrade = try fields.decode(PassengerCabinGrade.self, forKey: .cabinGrade)
    ordinal = try fields.decode(Int.self, forKey: .ordinal)
    mode = try fields.decode(PassengerTransportMode.self, forKey: .mode)
    privateCabin = try fields.decode(Bool.self, forKey: .privateCabin)
    lifeSupportWorking = try fields.decode(Bool.self, forKey: .lifeSupportWorking)
    humanoidCompatible = try fields.decode(Bool.self, forKey: .humanoidCompatible)
    use = try fields.decode(PassengerPlaceUse.self, forKey: .use)
  }
  public init(
    id: UUID = UUID(), cabinID: UUID, cabinGrade: PassengerCabinGrade = .stateroomSingle,
    ordinal: Int = 0,
    mode: PassengerTransportMode = .awake, privateCabin: Bool = false,
    lifeSupportWorking: Bool = true, humanoidCompatible: Bool = true,
    use: PassengerPlaceUse = .empty
  ) {
    self.id = id
    self.cabinID = cabinID
    self.cabinGrade = cabinGrade
    self.ordinal = ordinal
    self.mode = mode
    self.privateCabin = privateCabin
    self.lifeSupportWorking = lifeSupportWorking
    self.humanoidCompatible = humanoidCompatible
    self.use = use
  }
}
public struct AccommodationFit: Sendable, Equatable {
  public let usableCargo: Int
  public let freeEquipmentUnits: Int
  public let freeCompatiblePlaces: Int
  public let cabinCargo: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
}
public enum AccommodationFitting {
  public static let tonnesPerCabin = 5
  public static let equipmentUnitsPerCabin = 1

  /// Callers supply actual fitted equipment costs; theoretical expansion/storage are excluded.
  public static func evaluate(
    profile: ShipAccommodationProfile, holdTonnes: Int,
    freightTonnes: Int, otherFittedCargoTonnes: Int, otherFittedEquipmentUnits: Int,
    cabins: [OwnedPassengerCabin], berths: [PassengerBerth], requestedParty: Int = 0,
    humanoidParty: Bool = true
  ) -> AccommodationFit {
    let quantities = [
      holdTonnes, freightTonnes, otherFittedCargoTonnes, otherFittedEquipmentUnits, requestedParty,
    ]
    guard quantities.allSatisfy({ (0...100000).contains($0) }), berths.count <= 10000,
      cabins.count <= 10000
    else {
      return .init(
        usableCargo: 0, freeEquipmentUnits: 0, freeCompatiblePlaces: 0, cabinCargo: 0,
        issues: ["Invalid accommodation quantities."])
    }
    let cabinCargo = cabins.count * tonnesPerCabin
    let usable = holdTonnes - freightTonnes - otherFittedCargoTonnes - cabinCargo
    let equipment =
      profile.equipmentUnits - otherFittedEquipmentUnits - cabins.count
      * equipmentUnitsPerCabin
    var issues: [String] = []
    if let maximum = profile.maximumPhysicalCabinModules, cabins.count > maximum {
      issues.append("This original hull supports at most \(maximum) physical cabin modules.")
    }
    if Set(berths.map(\.id)).count != berths.count {
      issues.append("A berth module cannot be fitted more than once.")
    }
    let people = berths.compactMap { $0.use.personID }
    if Set(people).count != people.count {
      issues.append("A person cannot occupy or reserve multiple places.")
    }
    if usable < 0 {
      issues.append(
        "Accommodation needs \(-usable) more tonne\(-usable == 1 ? "" : "s") of physical hold.")
    }
    if equipment < 0 { issues.append("Accommodation needs \(-equipment) more equipment units.") }
    if berths.contains(where: { $0.use.used && (!$0.lifeSupportWorking || !$0.humanoidCompatible) })
    {
      issues.append("Occupied or reserved accommodation needs compatible working life support.")
    }
    var accommodation = ShipAccommodation()
    accommodation.ownedCabins = cabins
    accommodation.ownedBerths = berths
    accommodation.fitted = Set(cabins.map(\.id))
    if !accommodation.layoutValid {
      issues.append("Cabin layouts and place identities must match owned physical modules.")
    }
    let hardware = Dictionary(cabins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    if berths.contains(where: { place in
      guard place.use.used else { return false }
      guard let cabin = hardware[place.cabinID], cabin.lifeSupportWorking else { return true }
      return place.mode == .stasis ? !cabin.stasisWorking : !cabin.grade.supportsAwake
    }) {
      issues.append("Occupied or reserved places need working, compatible transport hardware.")
    }
    let free = humanoidParty ? accommodation.availablePlaces().count : 0
    if requestedParty > 0 && !humanoidParty {
      issues.append("This party needs a separately supported environmental accommodation adapter.")
    }
    if requestedParty > free {
      issues.append("The party needs \(requestedParty-free) more compatible fitted berths.")
    }
    // Operating crew already has intrinsic quarters; it is not subtracted from hold or charter berths again.
    return .init(
      usableCargo: max(0, usable), freeEquipmentUnits: max(0, equipment),
      freeCompatiblePlaces: free, cabinCargo: cabinCargo, issues: issues)
  }
}
