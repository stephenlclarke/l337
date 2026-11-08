import Foundation
import Testing

@testable import L337Core

/// Current-writer fixtures only. No production reader, codec or positive native fact is replaced.
enum NativeIsolationLoadAssertions {
  private struct Entry: Equatable {
    let type: String
    let link: String?
    let bytes: Data?
  }

  static func reject(
    _ corruption: NativeIsolationPublicationAssertions.Corruption,
    runtime: GameRuntime, at save: URL
  ) async throws {
    let caller = await runtime.snapshot()
    let callerWorld = caller.scriptWorldSave
    let directory = save.deletingLastPathComponent()
    let goodTree = try tree(directory)
    let goodPointer = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: goodPointer)
    try #require(pointer.valueCodec == ScriptValueStorage.codec)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
    let missions = generation.appendingPathComponent("missions.json")
    let goodMissions = try Data(contentsOf: missions)
    try #require(pointer.hashes["missions.json"] == ScriptPackLibrary.hash(goodMissions))
    let (original, _) = try ScriptSaveStore.read(goodPointer, from: save)
    try requireClaims(original)
    let decoded = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptEngineState.self, from: goodMissions)
    let actualEngineMatches = decoded == original.scriptState
    try #require(actualEngineMatches)

    // A reader runtime wraps the attained state; the original physical-flow actor stays untouched.
    let reader = GameRuntime(game: caller, saveURL: save)
    try await reader.load(from: save, persistMigrations: false)
    try requireClaims(await reader.snapshot().commander)
    try #require(try tree(directory) == goodTree)

    var actual = original
    actual.scriptState = decoded
    let invalid = try NativeIsolationPublicationAssertions.candidate(corruption, from: actual)
    let missionDataChanged = invalid.scriptState != decoded
    try #require(missionDataChanged)
    var nonMissionFields = invalid
    nonMissionFields.scriptState = actual.scriptState
    let onlyMissionsChanged = nonMissionFields == actual
    try #require(onlyMissionsChanged)
    let invalidMissions = try ScriptValueStorage.encoder().encode(invalid.scriptState)
    try ScriptSaveJSONPreflight.validate(invalidMissions)
    try NativeIsolationWorkParentSave.validateFields(invalidMissions, part: .missions)
    try NativeIsolationWorkSave.validateFields(invalidMissions, part: .missions)
    let roundTrip = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptEngineState.self, from: invalidMissions)
    let roundTripMatches = roundTrip == invalid.scriptState
    try #require(roundTripMatches)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(invalidMissions)
    let invalidPointer = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    let invalidPointerBytes = try JSONEncoder().encode(invalidPointer)
    try requireOnlyMissionsHashChanged(goodPointer, invalidPointerBytes)

    do {
      try invalidMissions.write(to: missions, options: .atomic)
      try invalidPointerBytes.write(to: save, options: .atomic)
      try requireOnlyTwoFilesChanged(goodTree, tree(directory), save: save, missions: missions)
      let beforeDirect = await reader.snapshot()
      let directWorld = beforeDirect.scriptWorldSave
      let directInput = try tree(directory)
      #expect(throws: SaveError.self) {
        _ = try ScriptSaveStore.read(invalidPointerBytes, from: save)
      }
      try await requireUnchanged(reader, commander: beforeDirect.commander, world: directWorld)
      try #require(try tree(directory) == directInput)

      let beforeLoad = await reader.snapshot()
      let loadWorld = beforeLoad.scriptWorldSave
      let loadInput = try tree(directory)
      await #expect(throws: SaveError.self) {
        try await reader.load(from: save, persistMigrations: false)
      }
      try await requireUnchanged(reader, commander: beforeLoad.commander, world: loadWorld)
      try #require(try tree(directory) == loadInput)
    } catch let failure {
      do {
        try restore(missions: missions, missionBytes: goodMissions, pointer: save, pointerBytes: goodPointer)
      } catch let restorationFailure {
        Issue.record(restorationFailure)
      }
      throw failure
    }
    // Restoration is test-owned and follows both failed-call conservation checks.
    try restore(missions: missions, missionBytes: goodMissions, pointer: save, pointerBytes: goodPointer)
    try #require(try tree(directory) == goodTree)
    let (restored, _) = try ScriptSaveStore.read(goodPointer, from: save)
    try requireClaims(restored)
    try await reader.load(from: save, persistMigrations: false)
    try requireClaims(await reader.snapshot().commander)
    try #require(try tree(directory) == goodTree)
    try await requireUnchanged(runtime, commander: caller.commander, world: callerWorld)
  }

  static func rejectWrongLossCause(_ game: Game) async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    try await reject(.wrongLossCause, runtime: runtime, at: files.save)
  }

  private static func requireClaims(_ commander: borrowing Commander) throws {
    let generic = commander.valid
    let parent = NativeIsolationWorkParentSave.validateClaims(commander)
    let work = NativeIsolationWorkSave.validateClaims(commander)
    let contract = NativeIsolationContractSave.validateClaims(commander)
    try #require(generic)
    try #require(parent && work && contract)
  }

  private static func requireUnchanged(
    _ runtime: GameRuntime, commander: Commander, world: ScriptWorldSave
  ) async throws {
    let actual = await runtime.snapshot()
    let unchanged = actual.commander == commander
    try #require(unchanged)
    try #require(actual.scriptWorldSave == world)
  }

  private static func restore(missions: URL, missionBytes: Data, pointer: URL, pointerBytes: Data) throws {
    try missionBytes.write(to: missions, options: .atomic)
    try pointerBytes.write(to: pointer, options: .atomic)
  }

  private static func requireOnlyMissionsHashChanged(_ original: Data, _ altered: Data) throws {
    let good = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    var bad = try #require(JSONSerialization.jsonObject(with: altered) as? [String: Any])
    let before = try #require(good["hashes"] as? [String: String])
    let after = try #require(bad["hashes"] as? [String: String])
    try #require(Set(before.keys) == Set(after.keys))
    for (key, value) in before where key != "missions.json" {
      try #require(after[key] == value)
    }
    bad["hashes"] = good["hashes"]
    try #require((good as NSDictionary).isEqual(to: bad))
  }

  private static func requireOnlyTwoFilesChanged(
    _ original: [String: Entry], _ altered: [String: Entry], save: URL, missions: URL
  ) throws {
    let prefix = save.deletingLastPathComponent().path + "/"
    try #require(missions.path.hasPrefix(prefix))
    let allowed = Set([save.lastPathComponent, String(missions.path.dropFirst(prefix.count))])
    try #require(Set(original.keys) == Set(altered.keys))
    for (path, entry) in original {
      let actual = try #require(altered[path])
      try #require(actual.type == entry.type && actual.link == entry.link)
      if !allowed.contains(path) { try #require(actual == entry) }
    }
  }

  private static func tree(_ directory: URL) throws -> [String: Entry] {
    let enumeration = try #require(FileManager.default.enumerator(atPath: directory.path))
    var result: [String: Entry] = [:]
    for case let path as String in enumeration {
      let file = directory.appendingPathComponent(path)
      let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
      let type = try #require(attributes[.type] as? FileAttributeType)
      switch type {
      case .typeRegular:
        result[path] = .init(type: type.rawValue, link: nil, bytes: try Data(contentsOf: file))
      case .typeDirectory:
        result[path] = .init(type: type.rawValue, link: nil, bytes: nil)
      case .typeSymbolicLink:
        result[path] = .init(type: type.rawValue,
          link: try FileManager.default.destinationOfSymbolicLink(atPath: file.path), bytes: nil)
      default:
        throw SaveError.invalidCommander
      }
    }
    return result
  }
}
