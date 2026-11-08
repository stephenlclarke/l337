import Foundation

struct NativeC01ClinicEscortSource: Codable, Sendable, Equatable {
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let installation: UUID
  let recorder: UUID
  let station: NativeMainStationIdentity
  let anchors: SystemAnchors
  let reference: ShipPose
  let visit: UInt64
  let physicalTime: Double

  var position: Vector3 { anchors.station.position + .init(0, -5000, 20000) }
  var valid: Bool {
    var native = FlightSimulationState()
    native.enter(NativeC01ClinicEscort.location, arriving: true)
    guard let expected = native.anchors else { return false }
    return station.valid && station.world == owner && station.system == NativeC01ClinicEscort.location
      && anchors.system == station.system && anchors.station.position == expected.station.position
      && anchors.planet == expected.planet && anchors.sun == expected.sun
      && reference.position.finite && reference.orientation.validRotation
      && visit > 0 && visit < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }
}

/// Immutable references supplied by the native source owner, never minted by the runtime.
struct NativeC01ClinicStockUnit: Codable, Sendable, Equatable {
  let ordinal: Int
  let registeredHull: UUID
  let pilot: NativePersonReference
}

struct NativeC01ClinicStockBirth: Codable, Sendable, Equatable {
  let registration: UUID
  let units: [NativeC01ClinicStockUnit]
  let cradle: ShipPose
  let reference: ShipPose
  let physicalTime: Double

  func unit(_ ordinal: Int) -> NativeC01ClinicStockUnit? {
    units.first { $0.ordinal == ordinal }
  }
}

/// Immutable mission references to the actual finite source owner's reserved hull/person.
/// This contains no population producer, mutable person state or invented availability.
struct NativeC01ClinicLaunch: Codable, Sendable, Equatable {
  let operation: UUID
  let sourceReceipt: UUID
  let registeredHull: UUID
  let pilot: NativePersonReference
  let ordinal: Int
  let nativeActor: ActorIdentity
  let berth: ShipPose
  let reference: ShipPose
  let physicalTime: Double
  var loss: NativeC01ClinicHullLoss?
}

struct NativeC01ClinicHullLoss: Codable, Sendable, Equatable {
  let ordinal: Int
  let launch: UUID?
  let operation: UUID
  let sourceDisposition: UUID
  let actor: ScriptOwnedActor
  let physicalTime: Double
}

/// Persisted receiving facts; only an actual private live witness can publish this receipt.
struct NativeC01ClinicArrival: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let launch: UUID
  let registeredHull: UUID
  let pilot: NativePersonReference
  let sourceReception: UUID
  let actor: ActorIdentity
  let station: NativeMainStationIdentity
  let stationActor: ActorIdentity
  let from: ShipPose
  let to: ShipPose
  let stationFrom: ShipPose
  let stationTo: ShipPose
  let startTime: Double
  let physicalTime: Double
}

struct NativeC01ClinicEscortState: Codable, Sendable, Equatable {
  let source: NativeC01ClinicEscortSource
  let birth: NativeC01ClinicStockBirth
  var parkedLosses: [NativeC01ClinicHullLoss] = []
  var launches: [NativeC01ClinicLaunch] = []
  var arrival: NativeC01ClinicArrival?
  var current: NativeC01ClinicLaunch? { launches.last }

  func loss(for ordinal: Int) -> NativeC01ClinicHullLoss? {
    if let parked = parkedLosses.first(where: { $0.ordinal == ordinal }) { return parked }
    return launches.first(where: { $0.ordinal == ordinal })?.loss
  }

  func launch(for ordinal: Int) -> NativeC01ClinicLaunch? {
    launches.first { $0.ordinal == ordinal }
  }
}

enum NativeC01ClinicEscort {
  static let location = SystemIdentity(galaxy: 0, system: 91)
  static let receipt = "c01-escort-clinic"
  static let target = "clinic-tender"
  static let cradleTarget = "maintenance-cradle"
  static let sourceEncounter = "meridian-clinic-source"
  static let cradleModel = "asset:c01-original-maintenance-cradle"
  static let tenderModel = "asset:c01-original-clinic-sh026"
  static let stayNearMetres = 1500.0
  static let pilotMassKilograms = 80.0
  static let maximumLaunches = 2

  static func stockTarget(_ ordinal: Int) -> String {
    ordinal == 0 ? "clinic-tender-front" : "clinic-tender-reserve"
  }
  static func stockOrdinal(alias: String) -> Int? {
    if alias == stockTarget(0) { return 0 }
    if alias == stockTarget(1) { return 1 }
    return nil
  }
  static func actor(mission: UUID, ordinal: Int) -> UUID {
    ScriptIdentity.uuid(
      "script-actor-v2:\(mission):\(NativeGlassMeridian.digest):\(sourceEncounter):\(stockTarget(ordinal))")
  }
  static func cradle(mission: UUID) -> UUID {
    ScriptIdentity.uuid(
      "script-actor-v2:\(mission):\(NativeGlassMeridian.digest):\(sourceEncounter):\(cradleTarget)")
  }
  static func parkedPose(cradle: ShipPose, ordinal: Int) -> ShipPose {
    .init(position: cradle.systemPoint(.init(0, 0, ordinal == 0 ? 18 : -18)),
      orientation: cradle.orientation)
  }
  static func launchOperation(
    source: NativeC01ClinicEscortSource, reservation: UUID, hull: UUID, pilot: NativePersonReference,
    ordinal: Int, berth: ShipPose, reference: ShipPose
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "c01-clinic-launch-v1:\(source.mission):\(source.permission):\(source.installation):\(reservation):\(hull):\(pilot.key):\(ordinal):\(try NativeFlightReception.hash([berth, reference]))")
  }

  static func profile(cradle: Bool) throws -> ScriptNPCDefinition {
    if cradle {
      let record = try NativeC01ClinicCradle.original.get()
      return .init(
        id: "c01-maintenance-cradle", name: "Lareria clinic maintenance cradle",
        source: record.sourcePath + "; SHA256 " + record.sourceSHA256,
        basis: "Original open64x44m exit;100structural energy, no shield/fuel/weapons/drive/crew.",
        model: cradleModel, scale: 1, energy: 100, recharge: 0,
        speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0,
        missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
    }
    let original = try NativeC01SurveyorGeometry.harrier.get()
    let p = original.performance
    return .init(
      id: "c01-clinic-tender", name: "Registered Lareria clinic tender / Harrier",
      source: "Original SH026 native resource and finite Lareria clinic source",
      basis: "Healthy powered local Harrier; existing flight conversion x18. One actual80kg pilot; empty tank, no cargo/role kit/ammunition/ECM/jump drive. Two fixed source hulls and their actual pilots are admitted together before any launch.",
      model: tenderModel, scale: 1, energy: p.energy, recharge: p.recharge,
      speed: p.speed * 18, acceleration: p.acceleration * 18,
      pitch: p.pitch, yaw: p.yaw, roll: p.roll,
      missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
  }

  private static let tenderModelHash: Result<String, any Error> = Result {
    ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(NativeC01SurveyorGeometry.harrier.get().design))
  }
  static func modelHash(cradle: Bool) throws -> String {
    if cradle { return try NativeC01ClinicCradle.modelHash.get() }
    return try tenderModelHash.get()
  }
}
