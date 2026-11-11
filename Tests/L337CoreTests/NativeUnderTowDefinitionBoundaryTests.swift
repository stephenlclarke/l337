import Foundation
import Testing

@testable import L337Core

struct NativeUnderTowDefinitionBoundaryTests {
  @Test func originalPackStillChecksBytesEntryIdentityAndDecodedDeclaration() throws {
    let original = try ScriptPackLibrary.read(ScriptPackLibrary.bundledUnderTowDirectory)
    try #require(NativeUnderTowDefinition.matches(original))
    let appended = Data("\n".utf8)
    let differentBytes = [
      ScriptPack(
        manifest: original.manifest, source: original.source,
        manifestBytes: original.manifestBytes + appended, digest: original.digest,
        entryBytes: original.entryBytes),
      ScriptPack(
        manifest: original.manifest, source: original.source + appended,
        manifestBytes: original.manifestBytes, digest: original.digest,
        entryBytes: original.source + appended),
      ScriptPack(
        manifest: original.manifest, source: original.source,
        manifestBytes: original.manifestBytes, digest: original.digest,
        entryBytes: original.source + appended),
      ScriptPack(
        manifest: original.manifest, source: original.source,
        manifestBytes: original.manifestBytes, digest: String(repeating: "0", count: 64),
        entryBytes: original.entryBytes),
    ]
    for candidate in differentBytes {
      #expect(!NativeUnderTowDefinition.matches(candidate))
    }

    let encoded = try JSONEncoder().encode(original.manifest)
    let declaration = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    for field in ["id", "version", "handlers", "capabilities"] {
      var changed = declaration
      switch field {
      case "id", "version": changed[field] = "different-original"
      case "handlers": changed[field] = [["event": "station.docked", "function": "accepted"]]
      default: changed[field] = ["script-lua-v1", "story-v2"]
      }
      let manifest = try JSONDecoder().decode(
        ScriptManifest.self, from: JSONSerialization.data(withJSONObject: changed))
      // Keep all pinned raw bytes so the decoded identity and declaration checks are exercised.
      let candidate = ScriptPack(
        manifest: manifest, source: original.source,
        manifestBytes: original.manifestBytes, digest: original.digest,
        entryBytes: original.entryBytes)
      #expect(!NativeUnderTowDefinition.matches(candidate))
    }
    #expect(NativeUnderTowDefinition.matches(original))
  }
}
