import Foundation
import Testing

@testable import L337Core

/// Raw-boundary refusal data only. Positive missions bytes come from the existing actual
/// ordinary trade, native commission/original loan and current writer. All methods UNRUN.
struct NativeAssemblySaveAbsenceUnitTests {
  private func missions(_ fixture: AssemblyOpeningFixture) throws -> Data {
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self,
      from: Data(contentsOf: fixture.files.save))
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    return try Data(contentsOf: generation.appendingPathComponent("missions.json"))
  }

  @Test func actualAbsentArchiveSkipsObjectDecodeAndKeepsOpaqueDataAndFamiliesSeparate() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    try #require(game.assemblyOfOrbitsMission == nil)
    try #require(game.commander.scriptState.firstNativeCommodityTrade != nil)
    let actual = try missions(fixture)
    #expect(try !ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(actual, part: .missions))
    try NativeAssemblyOfOrbitsSave.validateFields(actual, part: .missions)
    for part in [ScriptFreightVersionedSave.Part.commander, .missions, .contracts] {
      let absent = Data("{\"unrelated\":[{\"words\":[\"user text\"],\"offset\":\"label\"}]}".utf8)
      #expect(try !ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(absent, part: part))
      try NativeAssemblyOfOrbitsSave.validateFields(absent, part: part)
      let opaque = Data("{\"data\":{\"savedAssemblyOfOrbits\":\"user label\",\"savedC01Inquiry\":{\"phaseSeconds\":2.5}}}".utf8)
      #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(opaque, part: part))
      #expect(try !ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(opaque, part: part))
      try NativeAssemblyOfOrbitsSave.validateFields(opaque, part: part)
    }
    // This is malformed OTHER-family metadata, not an accepted Under Tow save or authority.
    let other = Data(("{\"instances\":{\"other\":{\"definition\":\""
      + NativeUnderTowDefinition.stateID + "\",\"digest\":\"" + NativeUnderTowDefinition.digest + "\"}}}").utf8)
    #expect(try !ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(other, part: .missions))
    #expect(try ScriptSaveJSONPreflight.underTowArchiveMayContainClaims(other, part: .missions))
    try NativeAssemblyOfOrbitsSave.validateFields(other, part: .missions)
    #expect(throws: (any Error).self) { try NativeUnderTowSave.validateFields(other, part: .missions) }
  }

  @Test func escapedMarkersCannotHideMissingLeavesAndActualEscapedLeafStillValidates() async throws {
    let definition = NativeAssemblyOfOrbitsDefinition.stateID.replacingOccurrences(of: "/", with: "\\/")
    let digest = NativeAssemblyOfOrbitsDefinition.digest
    try #require(digest.first == "0")
    let escapedDigest = "\\u0030" + String(digest.dropFirst())
    for suffix in ["", ",\"saved\\u0041ssemblyOfOrbits\":null"] {
      let raw = "{\"instances\":{\"case\":{\"defin\\u0069tion\":\"\(definition)\",\"digest\":\"\(escapedDigest)\"\(suffix)}}}"
      let data = Data(raw.utf8)
      #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(data, part: .missions))
      #expect(throws: (any Error).self) { try NativeAssemblyOfOrbitsSave.validateFields(data, part: .missions) }
    }
    for raw in ["{\"saved\\u0041ssemblyOfOrbits\":{}}", "{\"\\u0061ssemblyOfOrbits\":{}}"] {
      let data = Data(raw.utf8)
      #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(data, part: .contracts))
      #expect(throws: (any Error).self) { try NativeAssemblyOfOrbitsSave.validateFields(data, part: .contracts) }
    }
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let original = try missions(fixture)
    let text = try #require(String(data: original, encoding: .utf8))
    let escaped = Data(text.replacingOccurrences(of: "\"savedAssemblyOfOrbits\"",
      with: "\"saved\\u0041ssemblyOfOrbits\"").utf8)
    try #require(escaped != original)
    #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(escaped, part: .missions))
    try NativeAssemblyOfOrbitsSave.validateFields(escaped, part: .missions)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(collected.commander))
    #expect(try missions(fixture) == original)
  }

  @Test func absentFeatureStillEnforcesExistingObjectDuplicateAndCollectionBounds() throws {
    let dictionary = (0..<128).map { "\"case-\($0)\":{}" }.joined(separator: ",")
    let allowed = Data(("{\"instances\":{" + dictionary + "}}").utf8)
    #expect(try !ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(allowed, part: .missions))
    try NativeAssemblyOfOrbitsSave.validateFields(allowed, part: .missions)
    let pairs = (0..<128).map { "\"case-\($0)\",{}" }.joined(separator: ",")
    let allowedPairs = Data(("{\"instances\":[" + pairs + "]}").utf8)
    #expect(try !ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(allowedPairs, part: .missions))
    try NativeAssemblyOfOrbitsSave.validateFields(allowedPairs, part: .missions)
    for raw in [
      "{\"instances\":{" + dictionary + ",\"excess\":{}}}",
      "{\"instances\":[" + pairs + ",\"excess\",{}]}", "{\"instances\":[\"odd\"]}",
      "{\"instances\":null}", "{\"instances\":{\"case\":false}}",
      "{\"instances\":{},\"instan\\u0063es\":{}}", "[]", "{}{}",
    ] {
      #expect(throws: (any Error).self) {
        try NativeAssemblyOfOrbitsSave.validateFields(Data(raw.utf8), part: .missions)
      }
    }
  }

  @Test func realCurrentChunkKeepsPlacementAndIdentityRulesAndColdLoadsTheSameLoan() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let data = try missions(fixture)
    try NativeAssemblyOfOrbitsSave.validateFields(data, part: .missions)
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let embedded = try JSONSerialization.data(withJSONObject: ["savedScriptState": root])
    #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(embedded, part: .commander))
    #expect(throws: (any Error).self) { try NativeAssemblyOfOrbitsSave.validateFields(embedded, part: .commander) }
    let definition = NativeAssemblyOfOrbitsDefinition.stateID
    let digest = NativeAssemblyOfOrbitsDefinition.digest
    for fields in [
      "\"definition\":\"\(definition)\"", "\"digest\":\"\(digest)\"",
      "\"savedAssemblyOfOrbits\":{}", "\"assemblyOfOrbits\":{}",
      "\"definition\":\"\(definition)\",\"digest\":\"\(digest)\",\"savedAssemblyOfOrbits\":false",
      "\"definition\":\"\(definition)\",\"digest\":\"\(digest)\",\"savedAssemblyOfOrbits\":{\"unexpected\":true}",
      "\"definition\":\"\(definition)\",\"digest\":\"\(NativeUnderTowDefinition.digest)\",\"savedAssemblyOfOrbits\":{}",
      "\"definition\":\"\(NativeUnderTowDefinition.stateID)\",\"digest\":\"\(digest)\",\"savedAssemblyOfOrbits\":{}",
    ] {
      let malformed = Data("{\"instances\":{\"case\":{\(fields)}}}".utf8)
      #expect(try ScriptSaveJSONPreflight.assemblyOfOrbitsArchiveMayContainClaims(malformed, part: .missions))
      #expect(throws: (any Error).self) { try NativeAssemblyOfOrbitsSave.validateFields(malformed, part: .missions) }
    }
    let instance = try #require(collected.assemblyOfOrbitsMission)
    let original = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: collected.commander)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    let current = try #require(loaded.assemblyOfOrbitsMission)
    let retained = try NativeAssemblyOfOrbitsCustody.resolve(instance: current, commander: loaded.commander)
    #expect(retained.original == original.original && retained.issueCommand == original.issueCommand)
    #expect(current.savedAssemblyOfOrbits == instance.savedAssemblyOfOrbits && current.milestones == [0, 1])
    #expect(current.completionReceipt == nil)
    #expect(loaded.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
  }
}
