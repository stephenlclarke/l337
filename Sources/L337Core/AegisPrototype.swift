import CryptoKit
import Foundation

/// The saved Constrictor discriminator now represents this mission-only source.
/// It does not identify a fleet catalogue entry or grant generic hull admission.
enum AegisPrototype {
  struct Source: Decodable, Sendable {
    let schemaVersion: Int
    let id: String
    let name: String
    let role: String
    let units: String
    let forwardAxis: String
    let upAxis: String
    let combat: NativeCombat
    let collision: String
    let muzzle: [Double]
    let nativeDesign: ShipDesign
  }

  static let source: Source? = {
    let resources = Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
    } ?? Bundle.module
    guard let url = resources.url(
      forResource: "NavalAegis", withExtension: "json", subdirectory: "MissionPacks"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return decode(data)
  }()

  static let mesh = source?.nativeDesign.rawMesh
  static let muzzle = source.map { Vector3($0.muzzle[0], $0.muzzle[1], $0.muzzle[2]) }

  static func presentation(_ text: String) -> String {
    text.replacingOccurrences(of: "CONSTRICTOR", with: "AEGIS PROTOTYPE")
      .replacingOccurrences(of: "Constrictor", with: "Aegis Prototype")
  }

  static func decode(_ bytes: Data) -> Source? {
    guard bytes.count == 30_118,
      SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined()
        == "85ec1a7ce589824a6b6f9c75957613d43157065ca266b243a9cb0bda4546bca0",
      let record = try? JSONDecoder().decode(Source.self, from: bytes),
      record.schemaVersion == 1, record.id == "naval.aegis-prototype",
      record.name == "Aegis Prototype", record.role == "naval.experimental-warship-target",
      record.units == "metres", record.forwardAxis == "+Z", record.upAxis == "+Y",
      record.collision == "nativeDesign", record.muzzle.count == 3,
      record.muzzle.allSatisfy(\.isFinite), record.combat.valid, record.nativeDesign.valid,
      record.nativeDesign.vertices.count == 160, record.nativeDesign.faces.count == 288,
      record.nativeDesign.faces.allSatisfy({ $0.count == 3 })
    else { return nil }
    return record
  }
}
