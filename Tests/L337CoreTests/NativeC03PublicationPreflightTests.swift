import Foundation
import Testing

@testable import L337Core

struct NativeC03PublicationPreflightTests {
  private func replacing(_ data: Data, _ old: Data, with new: Data) throws -> Data {
    let range = try #require(data.range(of: old))
    var result = data
    result.replaceSubrange(range, with: new)
    return result
  }

  /// These envelopes are raw gate inputs, never a complete root or a publication
  /// receipt. Positive leaf bytes below come only from the actual Confirm flow.
  private func envelope(_ instance: Data, key: UUID, object: Bool = false) -> Data {
    var data = Data((object
      ? "{\"instances\":{\"\(key.uuidString)\":"
      : "{\"instances\":[\"\(key.uuidString)\",").utf8)
    data.append(instance)
    data.append(Data((object ? "}}" : "]}").utf8))
    return data
  }

  @Test func actualCommissionLeafKeepsExactWriterBytesAndCannotChangeItsRootBindings()
    async throws
  {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let owner = try #require(accepted.commander.equipmentOwnerID)
    try #require(state.phase == .unadmitted && state.admissions.isEmpty)
    try #require(state.crewSource == nil && state.crewLogAccess == nil && state.caseFile == nil)
    let expectedSchema = ScriptSaveStore.publicationSchema(
      accepted.commander, alien: accepted.commander.alienStorageState != nil)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.files.save))
    try #require(pointer.schemaVersion == expectedSchema)
    let writer = ScriptValueStorage.encoder()
    let chunk = try writer.encode(accepted.commander.scriptState)
    let instanceBytes = try writer.encode(instance)
    let leaf = try writer.encode(state)
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)

    let publications = try NativeC03PublicationPreflight.validate(
      chunk, part: .missions, schema: pointer.schemaVersion,
      currentSchema: expectedSchema, owner: owner)
    try #require(publications.count == 1)
    #expect(publications[0].mission == instance.id)
    #expect(publications[0].bytes == leaf && publications[0].state == state)
    #expect(NativeC03PublicationPreflight.validateClaims(accepted.commander))
    #expect(publications[0].state.crewSource == nil)
    #expect(publications[0].state.crewLogAccess == nil && publications[0].state.caseFile == nil)
    var framed = Data([0])
    framed.append(chunk)
    let sliced = framed[(framed.startIndex + 1)..<framed.endIndex]
    let slicedPublications = try NativeC03PublicationPreflight.validate(
      sliced, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
    #expect(slicedPublications.first?.bytes == leaf && slicedPublications.first?.state == state)

    // An escaped enclosing FIELD NAME is decoded for placement, but the nested
    // publication's escaped slashes/numbers/strings must never be reserialized.
    let escaped = try replacing(
      chunk, Data("\"savedHollowManifest\":".utf8),
      with: Data("\"savedHollow\\u004Danifest\":".utf8))
    let escapedPublications = try NativeC03PublicationPreflight.validate(
      escaped, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
    #expect(escapedPublications.first?.bytes == leaf)
    #expect(escapedPublications.first?.state == state)

    // Both supported current instance representations bind the collection key,
    // embedded instance ID, actual root owner and unchanged publication decoder.
    for object in [false, true] {
      let bytes = envelope(instanceBytes, key: instance.id, object: object)
      let decoded = try NativeC03PublicationPreflight.validate(
        bytes, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
      #expect(decoded.first?.bytes == leaf && decoded.first?.state == state)
      #expect(throws: (any Error).self) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: UUID())
      }
      #expect(throws: NativeC03PublicationPreflight.Failure.missingOwner) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: nil)
      }
      for part in [ScriptFreightVersionedSave.Part.commander, .contracts] {
        #expect(throws: NativeC03PublicationPreflight.Failure.misplacedClaim) {
          try NativeC03PublicationPreflight.validate(
            bytes, part: part, schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
        }
      }
      for schema in [nil, Optional(expectedSchema + 1)] {
        #expect(throws: NativeC03PublicationPreflight.Failure.wrongSchema) {
          try NativeC03PublicationPreflight.validate(
            bytes, part: .missions, schema: schema, currentSchema: expectedSchema, owner: owner)
        }
      }
      #expect(throws: NativeC03PublicationPreflight.Failure.wrongSchema) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .missions, schema: expectedSchema, currentSchema: nil, owner: owner)
      }
      #expect(throws: NativeC03PublicationPreflight.Failure.invalidInstance) {
        try NativeC03PublicationPreflight.validate(
          envelope(instanceBytes, key: UUID(), object: object), part: .missions,
          schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
      }
      // Change BOTH outer IDs, retaining the actual original birth. The decoder
      // must receive that outer mission, not the birth's self-asserted mission.
      let foreign = UUID()
      let changedID = try replacing(
        instanceBytes, Data("\"id\":\"\(instance.id.uuidString)\"".utf8),
        with: Data("\"id\":\"\(foreign.uuidString)\"".utf8))
      #expect(throws: (any Error).self) {
        try NativeC03PublicationPreflight.validate(
          envelope(changedID, key: foreign, object: object), part: .missions,
          schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
      }
    }

    // Unknown nested fields and purported private receipts enter only the
    // unchanged bounded strict decoder; none may become an accepted state.
    let alteredLeaves = [
      // A dictionary round-trip would erase this noncanonical representation.
      try replacing(leaf, Data("{".utf8), with: Data("{ ".utf8)),
      try replacing(leaf, Data("\"input\":{".utf8),
        with: Data("\"input\":{\"inventedSourceAuthority\":true,".utf8)),
      try replacing(leaf, Data("{".utf8),
        with: Data("{\"crewLogAccess\":{\"inventedWardWitness\":true},".utf8)),
      try replacing(leaf, Data("{".utf8),
        with: Data("{\"caseFile\":{\"inventedResolution\":true},".utf8)),
    ]
    for changed in alteredLeaves {
      let bytes = try replacing(chunk, leaf, with: changed)
      #expect(throws: (any Error).self) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .missions, schema: expectedSchema, currentSchema: expectedSchema, owner: owner)
      }
    }
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
    let after = await fixture.runtime.snapshot()
    #expect(after.commander == accepted.commander && after.bodies == accepted.bodies)
    #expect(after.hollowManifestMission?.savedHollowManifest == state)
  }

  @Test func malformedDuplicateUnknownAndOversizedLeavesRefuseBeforeAnyDecoder() throws {
    let id = UUID()
    // Deliberately incomplete negative DATA. Every listed raw error must win
    // BEFORE missing root policy/owner or any attempt to decode this fake birth.
    func instance(_ leaf: String) -> Data {
      Data(("""
        {"id":"\(id.uuidString)","definition":"\(NativeHollowManifestCommission.stateID)",
        "version":"\(NativeHollowManifestCommission.version)",
        "digest":"\(NativeHollowManifestCommission.digest)","savedHollowManifest":\(leaf)}
        """).utf8)
    }
    let cases: [(String, NativeC03PublicationPreflight.Failure)] = [
      (#"{"birth":{},"birth":{}}"#, .duplicateField),
      (#"{"birth":{"x":1,"\u0078":2}}"#, .duplicateField),
      (#"{"birth":{},"inventedWardAuthority":true}"#, .unknownField),
      (#"{"birth":{},"phase":"unadmitted","pha\u0073e":"admitted"}"#, .duplicateField),
      (#"{"birth":[]}"#, .invalidJSON),
      (#"{"birth":{},"admissions":{}}"#, .invalidJSON),
      (#"{"birth":{},"caseFile":null}"#, .invalidJSON),
      (#"{"birth":{"x":[,]}}"#, .invalidJSON),
      ("{\"birth\":{},\"admissions\":[" + Array(repeating: "{}", count: 21).joined(separator: ",")
        + "]}", .resourceLimit),
      ("{\"birth\":{\"x\":" + String(repeating: "[", count: 17) + "0"
        + String(repeating: "]", count: 17) + "}}", .resourceLimit),
      ("{\"birth\":{\"x\":\"" + String(repeating: "a", count: 4097) + "\"}}", .resourceLimit),
      ("{" + String(repeating: " ", count: NativeHollowManifestSave.maximumBytes)
        + "\"birth\":{}}", .resourceLimit),
    ]
    for (leaf, failure) in cases {
      #expect(throws: failure) {
        try NativeC03PublicationPreflight.validate(
          envelope(instance(leaf), key: id), part: .missions,
          schema: nil, currentSchema: nil, owner: nil)
      }
    }
    let first = instance(#"{"birth":{}}"#)
    var duplicated = Data("{\"instances\":[\"\(id.uuidString)\",".utf8)
    duplicated.append(first)
    duplicated.append(Data(",\"\(id.uuidString.lowercased())\",".utf8))
    duplicated.append(first)
    duplicated.append(Data("]}".utf8))
    #expect(throws: NativeC03PublicationPreflight.Failure.invalidInstance) {
      try NativeC03PublicationPreflight.validate(
        duplicated, part: .missions, schema: nil, currentSchema: nil, owner: nil)
    }
  }

  @Test func unclaimedChunksStayUnclaimedAndMisplacedOrMalformedJSONNeverHidesALeaf() throws {
    for part in [ScriptFreightVersionedSave.Part.commander, .missions, .contracts] {
      let bytes = Data(#"{"instances":[],"text":"savedHollowManifest","unicode":"🐦 \uD83D\uDC26 \u0000","other":{"x":[true,null,-1.25e+2]}}"#.utf8)
      #expect(try NativeC03PublicationPreflight.validate(
        bytes, part: part, schema: nil, currentSchema: nil, owner: nil).isEmpty)
    }
    for bytes in [
      Data(#"{"savedHollowManifest":{}}"#.utf8),
      Data(#"{"savedScriptState":{"instances":[{"savedHollow\u004Danifest":{}}]}}"#.utf8),
      Data(#"{"payload":{"savedHollowManifest":{}}}"#.utf8),
    ] {
      #expect(throws: NativeC03PublicationPreflight.Failure.misplacedClaim) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .commander, schema: nil, currentSchema: nil, owner: nil)
      }
    }
    #expect(throws: NativeC03PublicationPreflight.Failure.unknownField) {
      try NativeC03PublicationPreflight.validate(
        Data(#"{"hollowManifest":{"claimedAuthority":true}}"#.utf8),
        part: .commander, schema: nil, currentSchema: nil, owner: nil)
    }
    let malformed = [
      Data(#"{"instances":[],"inst\u0061nces":[]}"#.utf8),
      Data(#"{"instances":[],}"#.utf8),
      Data(#"{"instances":[]}false"#.utf8),
      Data(#"{"x":"\uD800"}"#.utf8),
      Data(#"{"x":01}"#.utf8),
      Data(#"{"x":1.}"#.utf8),
      Data(#"{"x":[}"#.utf8),
      Data([123, 34, 120, 34, 58, 34, 0xC0, 0xAF, 34, 125]),
    ]
    for bytes in malformed {
      #expect(throws: (any Error).self) {
        try NativeC03PublicationPreflight.validate(
          bytes, part: .contracts, schema: nil, currentSchema: nil, owner: nil)
      }
    }
  }
}
