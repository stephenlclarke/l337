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

extension NativeC03PublicationPreflightTests {
  private func confirmedRoot() async throws -> HollowManifestCommissionFixture {
    let fixture = try await HollowManifestCommissionFixture()
    do {
      _ = try await fixture.review()
      await fixture.selectConfirm()
      await fixture.runtime.key("return")
      let accepted = await fixture.runtime.snapshot()
      try #require(accepted.hollowManifestMission?.savedHollowManifest != nil)
      try #require(accepted.commander.nativePeople == nil)
      return fixture
    } catch { fixture.clean(); throw error }
  }

  private func addingCustody(_ custody: Data, to header: Data) throws -> Data {
    try #require(header.last == 125)
    try #require(header.range(of: Data("\"savedNativePeopleCustody\":".utf8)) == nil)
    var bytes = Data(header.dropLast())
    bytes.append(Data(",\"savedNativePeopleCustody\":".utf8))
    bytes.append(custody)
    bytes.append(125)
    return bytes
  }

  private func custody(_ companion: Data, owner: UUID, extra: String = "") -> Data {
    var bytes = Data("{\"owner\":\"\(owner.uuidString)\",\"revision\":0,\"admissions\":[],\"transfers\":[],\"hollowManifestCrew\":".utf8)
    bytes.append(companion)
    bytes.append(Data((extra + "}").utf8))
    return bytes
  }

  /// Exercise the real current reader, including its pointer/hash/namespace and
  /// enclosing Commander decode. Mutate exact bytes; never normalize the leaf.
  private func readingHeader(
    _ header: Data, pointer: ScriptSavePointer, from url: URL, schema: Int? = nil
  ) throws -> (Commander, ScriptWorldSave) {
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let file = directory.appendingPathComponent("commander.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file, options: .atomic) }
    try header.write(to: file, options: .atomic)
    var hashes = pointer.hashes
    hashes["commander.json"] = ScriptPackLibrary.hash(header)
    let rebound = ScriptSavePointer(
      format: pointer.format, schemaVersion: schema ?? pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec, bisonUnitJournalCheckpoint: pointer.bisonUnitJournalCheckpoint)
    return try ScriptSaveStore.read(ScriptValueStorage.encoder().encode(rebound), from: url)
  }

  @Test func actualRootMissingAndNullCrewCompanionsKeepTheOriginalMissionAndNoSource() async throws {
    let fixture = try await confirmedRoot()
    defer { fixture.clean() }
    let pointerBytes = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    try #require(NativeC03PublicationNamespace.contains(pointer.schemaVersion))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let header = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
    let (original, world) = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save)
    let owner = try #require(original.equipmentOwnerID)
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)
    let rootNull = try addingCustody(Data("null".utf8), to: header)
    let (unchanged, unchangedWorld) = try readingHeader(rootNull, pointer: pointer, from: fixture.files.save)
    #expect(unchanged == original && unchangedWorld == world)
    let nestedNull = try addingCustody(custody(Data("null".utf8), owner: owner), to: header)
    let (empty, emptyWorld) = try readingHeader(nestedNull, pointer: pointer, from: fixture.files.save)
    #expect(empty.nativePeople?.hollowManifestCrew == nil)
    #expect(empty.nativePeople?.owner == owner && empty.nativePeople?.admissions.isEmpty == true)
    #expect(empty.scriptState == original.scriptState && emptyWorld == world)
    #expect(NativeC03PublicationPreflight.validateClaims(empty))
    // A descriptive NativePersonReference tag shares this spelling. Its valid
    // wrapper must not be mistaken for a misplaced companion or issue a person.
    let mission = try #require(original.scriptState.instances.values.first {
      $0.definition == NativeHollowManifestCommission.stateID
    }?.id)
    let address = NativePersonReference.hollowManifestCrew(.init(owner: owner, mission: mission, ordinal: 0))
    let reference = try ScriptValueStorage.encoder().encode(address)
    var referencedCustody = Data(custody(Data("null".utf8), owner: owner).dropLast())
    referencedCustody.append(Data(",\"referenceProbe\":".utf8))
    referencedCustody.append(reference)
    referencedCustody.append(125)
    let withReference = try addingCustody(referencedCustody, to: header)
    let (unissued, _) = try readingHeader(withReference, pointer: pointer, from: fixture.files.save)
    #expect(unissued == empty && unissued.nativePeople?.hollowManifestCrew == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
  }

  @Test func actualRootRejectsUnknownMalformedDuplicateAndMisplacedCrewBytesBeforeTypedDecode()
    async throws
  {
    let fixture = try await confirmedRoot()
    defer { fixture.clean() }
    let pointerBytes = try Data(contentsOf: fixture.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let (original, world) = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save)
    let owner = try #require(original.equipmentOwnerID)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.files.save)
    let header = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
    let files = try ScriptFinanceTestFixture.files(fixture.files.root)
    let cases: [(Data, NativeC03PublicationPreflight.Failure)] = [
      (custody(Data("{}".utf8), owner: owner), .invalidCrewCompanion),
      (custody(Data("[]".utf8), owner: owner), .invalidCrewCompanion),
      (custody(Data("false".utf8), owner: owner), .invalidCrewCompanion),
      (custody(Data(#"{"registration":{},"unknownCompanionField":true}"#.utf8), owner: owner),
        .invalidCrewCompanion),
      (custody(Data("null".utf8), owner: owner,
        extra: #", "hollowManifestCrewExtra":{"ignoredAuthority":true}"#), .unknownField),
      (custody(Data("null".utf8), owner: owner,
        extra: #", "hollowManifestCr\u0065w":null"#), .duplicateField),
      // Foundation could erase this purported source by taking the later nil.
      // The complete raw duplicate scan must win before either value is decoded.
      (custody(Data(#"{"registration":{},"unknownCompanionField":true}"#.utf8), owner: owner,
        extra: #", "hollowManifestCr\u0065w":null"#), .duplicateField),
      (custody(Data("null".utf8), owner: owner,
        extra: #", "nested":{"hollowManifestCrew":{"registration":{}}}"#), .misplacedClaim),
      (custody(Data(#"{"x":1,"\u0078":2}"#.utf8), owner: owner), .duplicateField),
      (custody(Data(#"{"x":[,]}"#.utf8), owner: owner), .invalidJSON),
      (custody(Data([123, 34, 120, 34, 58, 34, 0xC0, 0xAF, 34, 125]), owner: owner), .invalidJSON),
      (custody(Data(("{" + String(repeating: " ", count: NativeC03CrewSourceSave.maximumBytes)
        + "}").utf8), owner: owner), .resourceLimit),
    ]
    for (rawCustody, failure) in cases {
      let altered = try addingCustody(rawCustody, to: header)
      // Distinct raw failures prove this reached preflight, rather than merely
      // failing much later on this deliberately unissued typed source/history.
      #expect(throws: failure) { try readingHeader(altered, pointer: pointer, from: fixture.files.save) }
    }
    let claimed = try addingCustody(custody(Data("{}".utf8), owner: owner), to: header)
    #expect(throws: NativeC03PublicationPreflight.Failure.wrongSchema) {
      try readingHeader(claimed, pointer: pointer, from: fixture.files.save,
        schema: pointer.schemaVersion == NativeC03PublicationNamespace.alienVersion
          ? NativeSecondCommoditySaleSave.alienVersion : NativeSecondCommoditySaleSave.version)
    }
    let (after, afterWorld) = try ScriptSaveStore.read(pointerBytes, from: fixture.files.save)
    #expect(after == original && afterWorld == world)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
  }

  /// A positive companion comes only from actual paired native issuance. This
  /// retains the real source qualification/admission prerequisite; an unwired or
  /// unsupported source must fail here, never be replaced by invented save DATA.
  @Test func genuineIssuedCrewCompanionKeepsExactRootBytesAndRejectsAnUnknownNestedField()
    async throws
  {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    var game = actual.game
    try game.restoreScriptActors()
    let source = try #require(game.commander.nativePeople?.hollowManifestCrew)
    let people = try #require(game.commander.nativePeople)
    try #require(NativeC03CrewSourceSave.validSource(source, custody: people, commander: game.commander))
    let runtime = GameRuntime(game: game, saveURL: actual.commission.files.save)
    try await runtime.save(to: actual.commission.files.save)
    let pointerBytes = try Data(contentsOf: actual.commission.files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: actual.commission.files.save)
    let header = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
    let owner = try #require(game.commander.equipmentOwnerID)
    let leaf = try ScriptValueStorage.encoder().encode(source)
    let checked = try NativeC03PublicationPreflight.validateChunk(
      header, part: .commander, schema: pointer.schemaVersion,
      currentSchema: pointer.schemaVersion == NativeC03PublicationNamespace.alienVersion
        ? NativeC03PublicationNamespace.alienVersion : NativeC03PublicationNamespace.version,
      owner: owner)
    #expect(checked.crew?.bytes == leaf && checked.crew?.state == source)
    let (original, world) = try ScriptSaveStore.read(pointerBytes, from: actual.commission.files.save)
    #expect(original.nativePeople?.hollowManifestCrew == source)
    let spaced = try replacing(leaf, Data("{".utf8), with: Data("{ \n".utf8))
    let spacedHeader = try replacing(header, leaf, with: spaced)
    let spacedCheck = try NativeC03PublicationPreflight.validateChunk(
      spacedHeader, part: .commander, schema: pointer.schemaVersion,
      currentSchema: pointer.schemaVersion, owner: owner)
    #expect(spacedCheck.crew?.bytes == spaced)
    let (restored, restoredWorld) = try readingHeader(
      spacedHeader, pointer: pointer, from: actual.commission.files.save)
    #expect(restored == original && restoredWorld == world)
    let escapedHeader = try replacing(spacedHeader, Data("\"hollowManifestCrew\":".utf8),
      with: Data("\"hollowManifestCr\\u0065w\":".utf8))
    let (escaped, escapedWorld) = try readingHeader(
      escapedHeader, pointer: pointer, from: actual.commission.files.save)
    #expect(escaped == original && escapedWorld == world)
    var framed = Data([0])
    framed.append(escapedHeader)
    let sliced = framed[(framed.startIndex + 1)..<framed.endIndex]
    let slicedCheck = try NativeC03PublicationPreflight.validateChunk(
      sliced, part: .commander, schema: pointer.schemaVersion,
      currentSchema: pointer.schemaVersion, owner: owner)
    #expect(slicedCheck.crew?.bytes == spaced && slicedCheck.crew?.state == source)
    let unknown = try replacing(leaf, Data("\"registration\":{".utf8),
      with: Data("\"registration\":{\"unknownCompanionField\":true,".utf8))
    let unknownHeader = try replacing(header, leaf, with: unknown)
    #expect(throws: NativeC03PublicationPreflight.Failure.invalidCrewCompanion) {
      try readingHeader(unknownHeader, pointer: pointer, from: actual.commission.files.save)
    }
    let missing = try replacing(header, leaf, with: Data("null".utf8))
    #expect(throws: (any Error).self) {
      try readingHeader(missing, pointer: pointer, from: actual.commission.files.save)
    }
    let (after, afterWorld) = try ScriptSaveStore.read(pointerBytes, from: actual.commission.files.save)
    #expect(after == original && afterWorld == world)
  }
}
