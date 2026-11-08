import Foundation
import Testing

@testable import L337Core

private enum OriginalStationRecordFixture {
  static func withoutTable(_ name: String, in text: String) -> String {
    var removing = false
    return text.split(separator: "\n", omittingEmptySubsequences: false).filter { raw in
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.range(of: #"^\[\[?[A-Za-z_][A-Za-z0-9_.-]*\]\]?$"#,
        options: .regularExpression) != nil
      {
        let table = line.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        removing = table == name || table.hasPrefix(name + ".")
      }
      return !removing
    }.joined(separator: "\n")
  }

  static func replacing(_ key: String, with value: String, in text: String) throws -> String {
    var changed = text
    let range = try #require(changed.range(
      of: "(?m)^" + key + "[[:blank:]]*=.*$", options: .regularExpression))
    changed.replaceSubrange(range, with: key + " = " + value)
    return changed
  }

  static func mutated(_ condition: String, text: String) throws -> String {
    switch condition {
    case "missing-port": return withoutTable("nativeDocking", in: text)
    case "missing-native": return withoutTable("nativeDesign", in: text)
    case "zero-normal":
      return try replacing("outward", with: "{ x = 0.0, y = 0.0, z = 0.0 }", in: text)
    case "parallel-up":
      return try replacing("up", with: "{ x = 0.0, y = 0.0, z = 1.0 }", in: text)
    case "negative-depth": return try replacing("tunnelDepth", with: "-53.52", in: text)
    case "clockwise-aperture":
      return try replacing("aperture", with:
        "[{ x = -62.32, y = 50.8, z = 0.0 }, { x = 62.32, y = 50.8, z = 0.0 }, "
        + "{ x = 62.32, y = -50.8, z = 0.0 }, { x = -62.32, y = -50.8, z = 0.0 }]",
        in: text)
    case "wrong-name":
      return try replacing("name", with: "\"incomplete-original-record\"", in: text)
    case "wrong-family":
      return try replacing("family", with: "\"incomplete-original-record\"", in: text)
    case "wrong-hull":
      let other = try #require(Hull.allCases.first { $0 != .station })
      return try replacing("nativeHull", with: String(reflecting: other.rawValue), in: text)
    default: throw SaveError.invalidCommander
    }
  }
}

struct OriginalStationRecordUnitTests {
  @Test func originalStationRecordOwnsNativeMeshAndPort() throws {
    let ship = try #require(ShipCatalogue.ship("SH028"))
    let native = try #require(ship.nativeDesign)
    let port = try #require(ship.nativeDocking)
    #expect(ship.name == "Lion Citadel" && ship.catalogue.family == "lion-citadel")
    #expect(ship.nativeHull == .station && native.valid && port.valid)
    #expect(port.center == Vector3(0, 0, 136.32))
    #expect(port.outward == Vector3(0, 0, 1) && port.up == Vector3(0, 1, 0))
    #expect(port.tunnelDepth == 53.52)
    #expect(port.aperture == [
      Vector3(-62.32, -50.8, 0), .init(62.32, -50.8, 0),
      .init(62.32, 50.8, 0), .init(-62.32, 50.8, 0),
    ])
    #expect(MainStationGeometry.docking == port)
    #expect(MainStationGeometry.mesh.vertices == native.rawMesh.vertices)
    #expect(MainStationGeometry.mesh.faces == native.rawMesh.faces)
    #expect(native.rawMesh.vertices.count == 272 && native.rawMesh.faces.count == 488)
    let detailed = try #require(ship.previewMesh)
    #expect(detailed.vertices.count == 5888 && detailed.faces.count == 10056)
    #expect(detailed.vertices != native.rawMesh.vertices)
    var game = Game(executive: false)
    game.commander.shipID = "SH025"
    game.commander.fuel = 20
    game.commander.missiles = 1
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    try #require(game.commander.valid && game.commander.commonEquipmentUnits == 0)
    game.launch()
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let gameplay = game.gameplayMesh(for: station)
    #expect(gameplay.vertices == native.rawMesh.vertices && gameplay.faces == native.rawMesh.faces)
    // Aligned transverse containment is separate from attained approach and collision tests.
    #expect(port.fits(game.commander.playerMesh))
    #expect(!game.docked && !game.nativeMainStationDockEvidenceIsCurrent)
  }

  @Test(arguments: [
    "missing-port", "zero-normal", "parallel-up", "negative-depth", "clockwise-aperture",
    "wrong-name", "wrong-family", "wrong-hull", "missing-native",
  ])
  func standaloneOriginalStationLoaderRejectsPartialOrMalformedRecord(condition: String) throws {
    let source = ShipCatalogue.folder.appendingPathComponent("SH028.toml")
    let original = try Data(contentsOf: source)
    let text = try #require(String(data: original, encoding: .utf8))
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("SH028.toml")
    let before = ShipCatalogue.all
    try original.write(to: file)
    let loaded = try ShipCatalogue.load(from: folder)
    try #require(loaded.map(\.id) == ["SH028"])
    let positive = try #require(loaded.first)
    try #require(positive.nativeDocking?.valid == true && positive.nativeDesign?.valid == true)
    let changed = try OriginalStationRecordFixture.mutated(condition, text: text)
    try #require(changed != text)
    try Data(changed.utf8).write(to: file)
    #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
    #expect(ShipCatalogue.all == before)
    #expect(try Data(contentsOf: source) == original)
  }
}
