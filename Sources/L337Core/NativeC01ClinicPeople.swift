import Foundation

/// A distinct original person at the actual Lareria clinic facility, never an Avenor alias.
public struct NativeC01ClinicPilotIdentity: Hashable, Codable, Sendable {
  let owner: UUID
  let facility: UUID
  let ordinal: Int
  var key: String { "native-c01-clinic-pilot-v1:\(owner):\(facility):\(ordinal)" }
  var id: UUID { ScriptIdentity.uuid(key) }
  var valid: Bool {
    facility == NativeC01ClinicPeople.facility(owner: owner)
      && NativeC01ClinicPeople.definitions.indices.contains(ordinal) && id != owner
  }
}

struct NativeC01ClinicPilotDefinition: Sendable {
  let id: String
  let name: String
  let massKilograms: Double
}

enum NativeC01ClinicPeople {
  // New Root-adopted authored people and limited mass estimates; no universal person registry.
  static let definitions: [NativeC01ClinicPilotDefinition] = [
    .init(id: "clinic-pilot-0", name: "Iria Neth", massKilograms: 80),
    .init(id: "clinic-pilot-1", name: "Daven Roh", massKilograms: 80),
  ]
  static let maximumAssignments = 2
  static let maximumDispositions = 2

  static func facility(owner: UUID) -> UUID {
    let mission = ScriptIdentity.uuid("glass-meridian-commission-v1:\(owner)")
    return NativeC01ClinicEscort.cradle(mission: mission)
  }
  static func hull(owner: UUID, ordinal: Int) -> UUID {
    ScriptIdentity.uuid("native-c01-clinic-hull-v1:\(owner):\(facility(owner: owner)):\(ordinal)")
  }
  static func person(owner: UUID, ordinal: Int) -> NativeC01ClinicPilotIdentity {
    .init(owner: owner, facility: facility(owner: owner), ordinal: ordinal)
  }
}

/// Explicit local source fit. These are authored empty-mass terms, not a universal mass table.
struct NativeC01ClinicMassTerms: Codable, Sendable, Equatable {
  let dryHullKilograms: Double
  let pilotKilograms: Double
  let fuelKilograms: Double
  let cargoKilograms: Double
  let roleKitKilograms: Double
  let ammunitionKilograms: Double
  let otherPeopleKilograms: Double

  var valid: Bool {
    dryHullKilograms == 25545 && pilotKilograms == 80
      && [fuelKilograms, cargoKilograms, roleKitKilograms, ammunitionKilograms,
        otherPeopleKilograms].allSatisfy { $0.isFinite && $0 == 0 }
  }
  var loadedKilograms: Double {
    dryHullKilograms + pilotKilograms + fuelKilograms + cargoKilograms + roleKitKilograms
      + ammunitionKilograms + otherPeopleKilograms
  }
}

/// Two actual source people remain paired with their original registered hulls.
/// The native actor birth/retention owner supplies the observed bindings; this is not authority.
struct NativeC01ClinicRegisteredUnit: Codable, Sendable, Equatable {
  let ordinal: Int
  let registeredHull: UUID
  let pilot: NativeC01ClinicPilotIdentity
  let pilotName: String
  let adult: Bool
  let consentPolicy: String
  let intrinsicPlace: Int
  let mass: NativeC01ClinicMassTerms
  let actor: UUID
  let birthPhysical: ActorIdentity
  let berth: ShipPose
}

struct NativeC01ClinicSourceRegistration: Codable, Sendable, Equatable {
  let operation: UUID
  let source: NativeC01ClinicEscortSource
  let birth: NativeC01ClinicStockBirth
  let facility: UUID
  let cradle: ActorIdentity
  let cradlePose: ShipPose
  let cradleVelocity: Vector3
  let cradleAngularVelocity: Vector3
  let resourceSHA256: String
  let recipeSHA256: String
  let units: [NativeC01ClinicRegisteredUnit]
  let physicalTime: Double
  let epoch: UUID

  private enum CodingKeys: String, CodingKey {
    case operation, source, birth, facility, cradle, cradlePose, cradleVelocity, cradleAngularVelocity,
      resourceSHA256, recipeSHA256, units, physicalTime, epoch
  }
  init(
    operation: UUID, source: NativeC01ClinicEscortSource, birth: NativeC01ClinicStockBirth,
    facility: UUID, cradle: ActorIdentity,
    cradlePose: ShipPose, cradleVelocity: Vector3, cradleAngularVelocity: Vector3,
    resourceSHA256: String, recipeSHA256: String, units: [NativeC01ClinicRegisteredUnit],
    physicalTime: Double, epoch: UUID
  ) {
    self.operation = operation
    self.source = source
    self.birth = birth
    self.facility = facility
    self.cradle = cradle
    self.cradlePose = cradlePose
    self.cradleVelocity = cradleVelocity
    self.cradleAngularVelocity = cradleAngularVelocity
    self.resourceSHA256 = resourceSHA256
    self.recipeSHA256 = recipeSHA256
    self.units = units
    self.physicalTime = physicalTime
    self.epoch = epoch
  }
  private enum BirthKeys: String, CodingKey {
    case registration, units, cradle, reference, physicalTime
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let birthValues = try values.nestedContainer(keyedBy: BirthKeys.self, forKey: .birth)
    guard let stock = try NativePeopleDecoding.array(
      birthValues, key: .units, type: NativeC01ClinicStockUnit.self, maximum: 2), stock.count == 2,
      let units = try NativePeopleDecoding.array(
      values, key: .units, type: NativeC01ClinicRegisteredUnit.self, maximum: 2), units.count == 2
    else { throw SaveError.invalidCommander }
    self.init(
      operation: try values.decode(UUID.self, forKey: .operation),
      source: try values.decode(NativeC01ClinicEscortSource.self, forKey: .source),
      birth: .init(
        registration: try birthValues.decode(UUID.self, forKey: .registration), units: stock,
        cradle: try birthValues.decode(ShipPose.self, forKey: .cradle),
        reference: try birthValues.decode(ShipPose.self, forKey: .reference),
        physicalTime: try birthValues.decode(Double.self, forKey: .physicalTime)),
      facility: try values.decode(UUID.self, forKey: .facility),
      cradle: try values.decode(ActorIdentity.self, forKey: .cradle),
      cradlePose: try values.decode(ShipPose.self, forKey: .cradlePose),
      cradleVelocity: try values.decode(Vector3.self, forKey: .cradleVelocity),
      cradleAngularVelocity: try values.decode(Vector3.self, forKey: .cradleAngularVelocity),
      resourceSHA256: try values.decode(String.self, forKey: .resourceSHA256),
      recipeSHA256: try values.decode(String.self, forKey: .recipeSHA256), units: units,
      physicalTime: try values.decode(Double.self, forKey: .physicalTime),
      epoch: try values.decode(UUID.self, forKey: .epoch))
  }
}

/// Persisted exact accepted native terms. Only a current private source observation may issue them.
struct NativeC01ClinicPilotConsent: Codable, Sendable, Equatable {
  let pilot: NativeC01ClinicPilotIdentity
  let registeredHull: UUID
  let sourceRevision: UInt64
  let reservation: UUID
  let destination: NativeMainStationIdentity
  let actor: ActorIdentity
  let cradle: ActorIdentity
  let berth: ShipPose
  let reference: ShipPose
  let velocity: Vector3
  let angularVelocity: Vector3
  let cradlePose: ShipPose
  let cradleVelocity: Vector3
  let cradleAngularVelocity: Vector3
  let physicalTime: Double
  let epoch: UUID
}

struct NativeC01ClinicPeopleAssignment: Codable, Sendable, Equatable {
  let operation: UUID
  let revision: UInt64
  let launch: NativeC01ClinicLaunch
  let actor: UUID
  let physical: ActorIdentity
  let consent: NativeC01ClinicPilotConsent
  let observer: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let beforeCash: Int
  let afterCash: Int
}

/// A native fatality is retained without guessing whether an unobserved person survived.
struct NativeC01ClinicPilotCasualty: Codable, Sendable, Equatable {
  let actor: UUID
  let physical: ActorIdentity
  let incident: UInt64
  let origin: AttackOrigin?
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID
}

struct NativeC01ClinicPilotReception: Codable, Sendable, Equatable {
  let actor: UUID
  let physical: ActorIdentity
  let station: NativeMainStationIdentity
  let stationActor: ActorIdentity
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID
}

enum NativeC01ClinicDispositionKind: Codable, Sendable, Equatable {
  case casualty(NativeC01ClinicPilotCasualty)
  case reception(NativeC01ClinicPilotReception)

  var physicalTime: Double {
    switch self {
    case .casualty(let facts): facts.physicalTime
    case .reception(let facts): facts.physicalTime
    }
  }
  var actor: UUID {
    switch self {
    case .casualty(let facts): facts.actor
    case .reception(let facts): facts.actor
    }
  }
}

struct NativeC01ClinicPeopleDisposition: Codable, Sendable, Equatable {
  let operation: UUID
  let revision: UInt64
  let ordinal: Int
  let registeredHull: UUID
  let pilot: NativeC01ClinicPilotIdentity
  // A stored source hull can suffer an actual fatality before any leg assignment.
  let assignment: UUID?
  let kind: NativeC01ClinicDispositionKind
}

/// Only bounded original source facts and receipts. Current locations derive from this history.
struct NativeC01ClinicSourceState: Codable, Sendable, Equatable {
  let registration: NativeC01ClinicSourceRegistration
  var assignments: [NativeC01ClinicPeopleAssignment]
  var dispositions: [NativeC01ClinicPeopleDisposition]
  var owner: UUID { registration.source.owner }
  var revision: UInt64 { UInt64(assignments.count + dispositions.count) }

  init(registration: NativeC01ClinicSourceRegistration) {
    self.registration = registration
    assignments = []
    dispositions = []
  }
  private enum CodingKeys: String, CodingKey { case registration, assignments, dispositions }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard let assignments = try NativePeopleDecoding.array(
      values, key: .assignments, type: NativeC01ClinicPeopleAssignment.self,
      maximum: NativeC01ClinicPeople.maximumAssignments),
      let dispositions = try NativePeopleDecoding.array(
        values, key: .dispositions, type: NativeC01ClinicPeopleDisposition.self,
        maximum: NativeC01ClinicPeople.maximumDispositions)
    else { throw SaveError.invalidCommander }
    registration = try values.decode(NativeC01ClinicSourceRegistration.self, forKey: .registration)
    self.assignments = assignments
    self.dispositions = dispositions
  }

  func unit(_ ordinal: Int) -> NativeC01ClinicRegisteredUnit? {
    registration.units.first { $0.ordinal == ordinal }
  }
  func assignment(_ ordinal: Int) -> NativeC01ClinicPeopleAssignment? {
    assignments.first { $0.launch.ordinal == ordinal }
  }
  func disposition(_ ordinal: Int) -> NativeC01ClinicPeopleDisposition? {
    dispositions.first { $0.ordinal == ordinal }
  }
}

enum NativeC01ClinicPilotLocation: Sendable, Equatable {
  case aboardStored
  case aboardOperating(launch: UUID)
  case receiver(NativeMainStationIdentity)
  case casualtyWithDestroyedHull(incident: UInt64)
}

struct NativeC01ClinicPilotFacts: Sendable, Equatable {
  let pilot: NativePersonReference
  let registeredHull: UUID
  let actor: UUID
  let intrinsicPlace: Int
  let location: NativeC01ClinicPilotLocation
  let mass: NativeC01ClinicMassTerms
  var massKilograms: Double { mass.pilotKilograms }
  var loadedMassKilograms: Double { mass.loadedKilograms }
  var operating: Bool {
    if case .aboardOperating = location { return true }
    return false
  }
  var alive: Bool? {
    if case .casualtyWithDestroyedHull = location { return nil }
    return true
  }
}

extension Commander {
  func c01ClinicPilotFacts(for launch: NativeC01ClinicLaunch) -> NativeC01ClinicPilotFacts? {
    guard let source = nativePeople?.clinicSource, NativeC01ClinicPeopleSave.shapeValid(source),
      let unit = source.unit(launch.ordinal), unit.pilot.valid,
      launch.registeredHull == unit.registeredHull, launch.pilot == .clinicPilot(unit.pilot),
      let assignment = source.assignment(launch.ordinal),
      assignment.operation == launch.sourceReceipt, assignment.launch.operation == launch.operation
    else { return nil }
    return c01ClinicStockPilotFacts(ordinal: launch.ordinal)
  }

  func c01ClinicStockPilotFacts(ordinal: Int) -> NativeC01ClinicPilotFacts? {
    guard let source = nativePeople?.clinicSource, NativeC01ClinicPeopleSave.shapeValid(source),
      let unit = source.unit(ordinal)
    else { return nil }
    let location: NativeC01ClinicPilotLocation
    if let disposition = source.disposition(ordinal) {
      switch disposition.kind {
      case .casualty(let facts): location = .casualtyWithDestroyedHull(incident: facts.incident)
      case .reception(let facts): location = .receiver(facts.station)
      }
    } else if let assignment = source.assignment(ordinal) {
      location = .aboardOperating(launch: assignment.launch.operation)
    } else { location = .aboardStored }
    return .init(
      pilot: .clinicPilot(unit.pilot), registeredHull: unit.registeredHull, actor: unit.actor,
      intrinsicPlace: unit.intrinsicPlace, location: location, mass: unit.mass)
  }
}

extension NativeC01ClinicPeople {
  static let consentPolicy = "original-clinic-local-leg-no-fee-v1"
  static let maximumSourceBytes = 1_048_576

  static func registrationOperation(owner: UUID) -> UUID {
    ScriptIdentity.uuid("native-c01-clinic-registration-v1:\(owner):\(facility(owner: owner))")
  }
  static func reservationOperation(
    registration: NativeC01ClinicSourceRegistration, unit: NativeC01ClinicRegisteredUnit
  ) -> UUID {
    ScriptIdentity.uuid(
      "native-c01-clinic-reservation-v1:\(registration.operation):\(registration.source.permission):\(registration.source.installation):\(unit.registeredHull):\(unit.pilot.key)")
  }
  static func dispositionOperation(
    registration: NativeC01ClinicSourceRegistration, unit: NativeC01ClinicRegisteredUnit,
    assignment: UUID?, kind: NativeC01ClinicDispositionKind
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-c01-clinic-disposition-v1:\(registration.operation):\(unit.registeredHull):\(unit.pilot.key):\(assignment?.uuidString ?? "stored"):\(try NativeFlightReception.hash(kind))")
  }
}
