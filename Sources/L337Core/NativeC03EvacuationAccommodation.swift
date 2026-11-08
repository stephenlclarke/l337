import Foundation

/// A closed mission-source fitting recipe, not an R3 default, actual owned module, living
/// person, boarding receipt or native permission. The real source producer must issue it once.
struct NativeC03EvacuationAccommodation: Codable, Sendable, Equatable {
  enum Failure: Error { case unsupportedSource }
  static let crewCount = 6
  static let operatingCount = 2
  static let cabinGrade = PassengerCabinGrade.standard
  // New Root-adopted C03 estimate, including clothing; not a measured universal person mass.
  // Native loaded COM/tensor and actual source fitting still require separate qualification.
  static let personMassKilograms = 90.0

  enum Place: Codable, Sendable, Equatable {
    case intrinsic(Int)
    case cabin(UUID)
  }

  /// Stable original-person addresses are proposed here; addresses do not create people.
  struct Assignment: Codable, Sendable, Equatable {
    let ordinal: Int
    let person: NativeC03CrewIdentity
    let massKilograms: Double
    let place: Place
  }

  let owner: UUID
  let mission: UUID
  let source: UUID
  let originalCarrier: UUID
  let originalLaunch: UUID
  let shipID: String
  let specificationSHA256: String
  let referencedGeometrySHA256: String
  let cabin: OwnedPassengerCabin
  let berths: [PassengerBerth]
  let assignments: [Assignment]
  let cargoCostTonnes: Int
  let equipmentCostUnits: Int
  let remainingHoldTonnes: Int
  let remainingEquipmentUnits: Int

  /// New project-authored fitting: two actual operating places plus one four-place module.
  /// No caller-supplied count, capacity, grade, life flag or R3 role kit is treated as issuance.
  static func candidate(owner: UUID, mission: UUID) throws -> Self {
    let source = try NativeHollowManifestFleetSource.resolve(.evacuationLaunch)
    guard source.current.id == "SH061", source.current.objectKind == .ship,
      source.accommodation.operatingCrew == operatingCount,
      source.accommodation.intrinsicCrewPlaces == operatingCount,
      source.accommodation.initialPurchasedCabins == 0,
      source.accommodation.maximumCabins >= 1,
      source.accommodation.cabinMassTonnes == Double(AccommodationFitting.tonnesPerCabin),
      source.accommodation.cabinEquipmentUnits == AccommodationFitting.equipmentUnitsPerCabin,
      !source.fitting.roleKitIncluded, source.fitting.passengerCabinGrades.contains("standard"),
      cabinGrade.places == crewCount - operatingCount, cabinGrade.supportsAwake,
      source.performance.cargo >= AccommodationFitting.tonnesPerCabin,
      source.fitting.equipmentUnits >= AccommodationFitting.equipmentUnitsPerCabin
    else { throw Failure.unsupportedSource }
    let prefix = NativeC03CrewIdentity.sourceKey(owner: owner, mission: mission)
    let identity = ScriptIdentity.uuid(prefix)
    let cabinID = ScriptIdentity.uuid("\(prefix):launch:standard-cabin")
    let berths = (0..<cabinGrade.places).map {
      PassengerBerth(
        id: ScriptIdentity.uuid("\(prefix):launch:standard-cabin:place:\($0)"),
        cabinID: cabinID, cabinGrade: cabinGrade, ordinal: $0, mode: .awake,
        privateCabin: false, lifeSupportWorking: true, humanoidCompatible: true, use: .empty)
    }
    let assignments = (0..<crewCount).map {
      Assignment(
        ordinal: $0, person: .init(owner: owner, mission: mission, ordinal: $0),
        massKilograms: personMassKilograms,
        place: $0 < operatingCount ? .intrinsic($0) : .cabin(berths[$0 - operatingCount].id))
    }
    return .init(
      owner: owner, mission: mission, source: identity,
      originalCarrier: ScriptIdentity.uuid("\(prefix):carrier"),
      originalLaunch: ScriptIdentity.uuid("\(prefix):launch"),
      shipID: source.current.id, specificationSHA256: source.current.sourceSHA256,
      referencedGeometrySHA256: source.current.referencedGeometrySHA256,
      cabin: .init(id: cabinID, grade: cabinGrade, lifeSupportWorking: true, stasisWorking: true),
      berths: berths, assignments: assignments,
      cargoCostTonnes: AccommodationFitting.tonnesPerCabin,
      equipmentCostUnits: AccommodationFitting.equipmentUnitsPerCabin,
      remainingHoldTonnes: source.performance.cargo - AccommodationFitting.tonnesPerCabin,
      remainingEquipmentUnits: source.fitting.equipmentUnits - AccommodationFitting.equipmentUnitsPerCabin)
  }

  /// This is the empty module/layout the future real source must create and fit. It neither
  /// places any of the six people aboard nor creates charter passengers in another owner.
  var emptyHardware: ShipAccommodation {
    var hardware = ShipAccommodation()
    hardware.ownedCabins = [cabin]
    hardware.ownedBerths = berths
    hardware.fitted = [cabin.id]
    return hardware
  }

  func valid(owner: UUID, mission: UUID) -> Bool {
    guard assignments.count == Self.crewCount, berths.count == Self.cabinGrade.places,
      self.owner == owner, self.mission == mission,
      emptyHardware.valid, emptyHardware.people.isEmpty,
      emptyHardware.availablePlaces().count == Self.crewCount - Self.operatingCount,
      let expected = try? Self.candidate(owner: owner, mission: mission)
    else { return false }
    return self == expected
  }
}
