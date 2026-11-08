import Foundation
import Testing

@testable import L337Core

/// Raw-boundary regression cases, not positive authority fixtures. The positive archive
/// below comes from the existing actual purchase/commission/loan/current writer. UNRUN.
struct NativeUnderTowSaveAbsenceUnitTests {
  private func missions(_ fixture: UnderTowOpeningFixture) throws -> Data {
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self,
      from: Data(contentsOf: fixture.files.save))
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    return try Data(contentsOf: generation.appendingPathComponent("missions.json"))
  }

  @Test func genuineFeatureAbsenceReturnsBeforeObjectDecodeAndKeepsOpaqueUserData() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    try #require(game.underTowMission == nil)
    try #require(game.commander.scriptState.firstNativeCommodityTrade != nil)
    let data = try missions(fixture)
    #expect(try !ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(data, part: .missions))
    try NativeUnderTowSave.validateFields(data, part: .missions)
    for part in [ScriptFreightVersionedSave.Part.commander, .missions, .contracts] {
      let absent = Data("{\"unrelated\":[{\"words\":[\"user text\"],\"offset\":\"label\"}]}".utf8)
      #expect(try !ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(absent, part: part))
      try NativeUnderTowSave.validateFields(absent, part: part)
      // A conservative marker may require the old decoder. User data is still not schema.
      let opaque = Data("{\"data\":{\"savedUnderTow\":\"user label\",\"savedC01Inquiry\":{\"phaseSeconds\":2.5}}}".utf8)
      #expect(try ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(opaque, part: part))
      try NativeUnderTowSave.validateFields(opaque, part: part)
    }
  }

  @Test func escapedMetadataCannotHideAMissingLeafAndRealEscapedLeafStillValidates() async throws {
    let escapedDefinition = NativeUnderTowDefinition.stateID.replacingOccurrences(of: "/", with: "\\/")
    let digest = NativeUnderTowDefinition.digest
    try #require(digest.first == "a")
    let escapedDigest = "\\u0061" + String(digest.dropFirst())
    for suffix in ["", ",\"savedUnder\\u0054ow\":null"] {
      let raw = "{\"instances\":{\"case\":{\"defin\\u0069tion\":\"\(escapedDefinition)\",\"digest\":\"\(escapedDigest)\"\(suffix)}}}"
      let data = Data(raw.utf8)
      #expect(try ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(data, part: .missions))
      #expect(throws: (any Error).self) { try NativeUnderTowSave.validateFields(data, part: .missions) }
    }
    for raw in ["{\"savedUnder\\u0054ow\":{}}", "{\"under\\u0054ow\":{}}"] {
      let data = Data(raw.utf8)
      #expect(try ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(data, part: .contracts))
      #expect(throws: (any Error).self) { try NativeUnderTowSave.validateFields(data, part: .contracts) }
    }
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let original = try missions(fixture)
    let text = try #require(String(data: original, encoding: .utf8))
    let escaped = Data(text.replacingOccurrences(of: "\"savedUnderTow\"",
      with: "\"savedUnder\\u0054ow\"").utf8)
    try #require(escaped != original)
    #expect(try ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(escaped, part: .missions))
    try NativeUnderTowSave.validateFields(escaped, part: .missions)
    #expect(NativeUnderTowSave.validateClaims(collected.commander))
    #expect(try missions(fixture) == original)
  }

  @Test func absentFeatureStillChecksObjectShapeDuplicatesAndInstanceCollectionBounds() throws {
    let dictionary = (0..<128).map { "\"case-\($0)\":{}" }.joined(separator: ",")
    let allowed = Data(("{\"instances\":{" + dictionary + "}}").utf8)
    #expect(try !ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(allowed, part: .missions))
    try NativeUnderTowSave.validateFields(allowed, part: .missions)
    let pairs = (0..<128).map { "\"case-\($0)\",{}" }.joined(separator: ",")
    let allowedPairs = Data(("{\"instances\":[" + pairs + "]}").utf8)
    #expect(try !ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(allowedPairs, part: .missions))
    try NativeUnderTowSave.validateFields(allowedPairs, part: .missions)
    let malformed = [
      "{\"instances\":{" + dictionary + ",\"excess\":{}}}",
      "{\"instances\":[" + pairs + ",\"excess\",{}]}",
      "{\"instances\":[\"odd\"]}",
      "{\"instances\":null}", "{\"instances\":{\"case\":false}}",
      "{\"instances\":{},\"instan\\u0063es\":{}}", "[]", "{}{}",
    ]
    for raw in malformed {
      #expect(throws: (any Error).self) {
        try NativeUnderTowSave.validateFields(Data(raw.utf8), part: .missions)
      }
    }
  }
}
