import Foundation

/// Fixed original C01 structural source. The native port is an empty exit, never a work face.
enum NativeC01ClinicCradle {
  struct Docking: Codable, Sendable, Equatable {
    let center: Vector3
    let outward: Vector3
    let up: Vector3
    let tunnelDepth: Double
    let aperture: [Vector3]
    let meaning: String

    var port: NativeStationGeometry.Port {
      .init(center: center, outward: outward, up: up,
        tunnelDepth: tunnelDepth, aperture: aperture)
    }
  }
  struct Record: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let id: String
    let sourcePath: String
    let sourceSHA256: String
    let metresPerSourceUnit: Double
    let massKilograms: Double
    let design: ShipDesign
    let nativeDesign: ShipDesign
    let nativeDocking: Docking
    let structuralPolicy: NativeC01Props.StructuralPolicy
  }

  static let resourceSHA256 =
    "a6437839508054cbe79ad3dc15ffa5e0dac95e17cd60926a35dff8ed30b62654"
  static let recipeSHA256 =
    "25dc873550c7178652037fd5d72e17e7d8dad770eb781617de1416a6e9cb6fc5"
  static let original: Result<Record, any Error> = Result {
    let url = ScriptPackLibrary.bundledGlassMeridianDirectory
      .appendingPathComponent("native-props/maintenance-cradle.json")
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? NSNumber, size.intValue == 97343 else {
      throw SaveError.invalidCommander
    }
    let bytes = try Data(contentsOf: url)
    guard bytes.count == size.intValue, ScriptPackLibrary.hash(bytes) == resourceSHA256 else {
      throw SaveError.invalidCommander
    }
    return try decode(bytes)
  }
  static let modelHash: Result<String, any Error> = Result {
    ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(original.get().nativeDesign))
  }

  static func decode(_ bytes: Data) throws -> Record {
    guard !bytes.isEmpty, bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(bytes)
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      Set(root.keys) == Set([
        "schemaVersion", "id", "sourcePath", "sourceSHA256", "metresPerSourceUnit", "massKilograms",
        "design", "nativeDesign", "nativeDocking", "structuralPolicy",
      ]), let docking = root["nativeDocking"] as? [String: Any],
      Set(docking.keys) == Set(["center", "outward", "up", "tunnelDepth", "aperture", "meaning"]),
      let policy = root["structuralPolicy"] as? [String: Any],
      Set(policy.keys) == Set([
        "energy", "recharge", "shields", "fuel", "missiles", "ecm", "weapons", "drive", "crew",
      ])
    else { throw SaveError.invalidCommander }
    let record = try JSONDecoder().decode(Record.self, from: bytes)
    let port = record.nativeDocking.port
    let power = record.structuralPolicy
    guard record.schemaVersion == 1, record.id == "c01-maintenance-cradle",
      record.sourcePath == "g4-original-c01/maintenance-cradle.toml",
      record.sourceSHA256 == recipeSHA256, record.metresPerSourceUnit == 1,
      record.massKilograms == 315120,
      record.design == record.nativeDesign, record.nativeDesign.valid,
      record.nativeDesign.license == "MIT", record.nativeDesign.vertices.count == 64,
      record.nativeDesign.faces.count == 144,
      record.nativeDesign.faces.allSatisfy({ $0.count == 3 }),
      port.valid, port.center == .init(0, 0, 40), port.outward == .init(0, 0, 1),
      port.up == .init(0, 1, 0), port.tunnelDepth == 80,
      port.aperture == [.init(-32, -22, 0), .init(32, -22, 0),
                       .init(32, 22, 0), .init(-32, 22, 0)],
      !record.nativeDocking.meaning.isEmpty, record.nativeDocking.meaning.utf8.count <= 512,
      power.energy == 100, power.recharge == 0, power.shields == 0, power.fuel == 0,
      power.missiles == 0, !power.ecm, !power.weapons, !power.drive, power.crew == 0,
      try PreparedHull(mesh: record.nativeDesign.rawMesh).isClosed
    else { throw SaveError.invalidCommander }
    return record
  }
}
