import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct NativeHollowManifestCurrentPackUnitTests {
  @Test func currentTOMLActuallyDecodesTheClosedAuthoredDeclaration() throws {
    let url = ScriptPackLibrary.bundledHollowManifestDirectory.appendingPathComponent("manifest.toml")
    let bytes = try Data(contentsOf: url)
    let manifest = try TOMLDecoder().decode(ScriptManifest.self, from: bytes)
    let declaration = try #require(manifest.hollowManifest)
    #expect(declaration.sourceID == NativeHollowManifestDefinition.logicalSourceID)
    #expect(declaration.schema == NativeHollowManifestDefinition.authoredSchema)
    #expect(declaration.version == NativeHollowManifestDefinition.authoredVersion)
    try NativeHollowManifestCommission.validateDeclaration(manifest)
  }

  @Test func actualCurrentReaderVerifiesExactOriginalPackBytes() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledHollowManifestDirectory)
    #expect(NativeHollowManifestCommission.matches(pack))
    #expect(pack.manifest.hollowManifest?.valid == true)
    #expect(pack.digest == NativeHollowManifestCommission.digest)
    #expect(ScriptPackLibrary.hash(pack.manifestBytes) == NativeHollowManifestCommission.manifestSHA256)
    #expect(ScriptPackLibrary.hash(pack.source) == NativeHollowManifestCommission.moduleSHA256)
    #expect(pack.manifest.stateID == "l337.contract/hollow-manifest")
    #expect(pack.manifest.hollowManifest?.sourceID == "l337.hollow-manifest")
    #expect(pack.models.isEmpty && pack.manifest.trial == nil && pack.manifest.board == nil)
    #expect(pack.manifest.mission.milestones.count == 10)
  }

  @Test(arguments: ["missing", "foreign", "executable-alias", "unknown-field"])
  func absentOrAlteredAuthoredDeclarationCannotBecomeANativeMission(_ mutation: String) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: ScriptPackLibrary.bundledHollowManifestDirectory, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    switch mutation {
    case "missing":
      let start = try #require(text.range(of: "[hollowManifest]\n"))
      let end = try #require(text.range(of: "[[handlers]]", range: start.upperBound..<text.endIndex))
      text.removeSubrange(start.lowerBound..<end.lowerBound)
    case "foreign":
      text = text.replacingOccurrences(of: "sourceID = \"l337.hollow-manifest\"", with: "sourceID = \"l337.borrowed-dawn\"")
    case "executable-alias":
      text = text.replacingOccurrences(of: "sourceID = \"l337.hollow-manifest\"", with: "sourceID = \"l337.contract/hollow-manifest\"")
    default:
      text = text.replacingOccurrences(of: "[hollowManifest]\n", with: "[hollowManifest]\nconsent = true\n")
    }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { _ = try ScriptPackLibrary.read(directory) }
  }
}
