import Foundation
import Testing

@testable import L337Core

private func titheArchiveJoinFiles(_ root: URL) throws -> [String: Data] {
  let files = try #require(FileManager.default.enumerator(at: root,
    includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL])
  var result: [String: Data] = [:]
  for file in files where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
    result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
  }
  return result
}

struct NativeTitheCommissionArchiveJoinTests {
  @Test
  func unissuedCaseRollsBackWhileLegitimateJournalStillColdLoadsWithoutCommission() async throws {
    let (game, request, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: storage.url)
    try await runtime.save(to: storage.url)
    let before = await runtime.snapshot()
    let files = try titheArchiveJoinFiles(storage.directory)
    let candidate = ScriptInstance(id: UUID(), definition: NativeTitheCommissionDefinition.stateID,
      version: NativeTitheCommissionDefinition.version, digest: NativeTitheCommissionDefinition.digest)
    #expect(candidate.savedTitheCommission == nil && !NativeTitheCommissionSave.prefixValid(candidate))
    var refused = false
    do {
      try await runtime.scriptCommand { proposed in
        proposed.commander.scriptState.instances[candidate.id] = candidate
      }
    } catch { refused = true }
    let after = await runtime.snapshot()
    let refusedWithoutPublication = refused && after.commander == before.commander && after.scriptWorldSave == before.scriptWorldSave
    #expect(refusedWithoutPublication)
    let epochUnchanged = after.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch
    #expect(epochUnchanged)
    let afterFiles = try titheArchiveJoinFiles(storage.directory)
    #expect(afterFiles == files)
    let noIssuedContact = NativeTitheCommissionContactSource.current(in: after) == nil
    #expect(noIssuedContact)
    let noCommissionGranted = after.titheCommissionMission == nil && after.commander.titheCommissionMarkEntitlement == nil
    #expect(noCommissionGranted)
    let pointerBytes = try Data(contentsOf: storage.url)
    let (stored, world) = try ScriptSaveStore.read(pointerBytes, from: storage.url)
    let storedCommanderAndWorldConsistent = stored == before.commander && world.consistent(with: stored)
    #expect(storedCommanderAndWorldConsistent)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    let coldCommanderAndWorldRetained = loaded.commander == before.commander && loaded.scriptWorldSave == before.scriptWorldSave
    #expect(coldCommanderAndWorldRetained)
    let journalCandidate = loaded.commander.savedBisonUnitAllocations
    let journal = try #require(journalCandidate)
    let retained = try journal.owner(for: request, in: loaded)
    let ownerRetainedWithoutBirth = retained == owner && !loaded.bodies.contains { $0.physical?.identity == owner.birthActor }
    #expect(ownerRetainedWithoutBirth)
    let coldGrantsNoCommission = loaded.titheCommissionMission == nil && loaded.commander.titheCommissionMarkEntitlement == nil
    #expect(coldGrantsNoCommission)
    let coldFiles = try titheArchiveJoinFiles(storage.directory)
    #expect(coldFiles == files)
  }

  @Test(arguments: ["pointer", "commander.json", "missions.json", "world.json", "escaped-pointer"])
  func actualReaderRejectsDetachedCommissionClaimsWithoutStrippingJournalBindings(part: String) async throws {
    let (game, _, _, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: storage.url)
    try await runtime.save(to: storage.url)
    let before = await runtime.snapshot()
    let originalPointer = try Data(contentsOf: storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let checkpoint = try #require(pointer.bisonUnitJournalCheckpoint)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: storage.url)
    let originalRead = try ScriptSaveStore.read(originalPointer, from: storage.url)
    let originalCommanderRetained = originalRead.0 == before.commander
    #expect(originalCommanderRetained)
    let chunkURL = generation.appendingPathComponent(part)
    var originalChunk: Data?
    defer {
      if let originalChunk { try? originalChunk.write(to: chunkURL, options: .atomic) }
      try? originalPointer.write(to: storage.url, options: .atomic)
    }
    let input: Data
    if part == "escaped-pointer" {
      let text = try #require(String(data: originalPointer, encoding: .utf8))
      input = Data(("{\"savedTitheCommiss\\u0069on\":null," + text.dropFirst()).utf8)
    } else if part == "pointer" {
      let decoded = try JSONSerialization.jsonObject(with: originalPointer)
      var object = try #require(decoded as? [String: Any])
      object[NativeTitheCommissionSave.field] = NSNull()
      input = try JSONSerialization.data(withJSONObject: object)
    } else {
      let original = try Data(contentsOf: chunkURL)
      originalChunk = original
      let decoded = try JSONSerialization.jsonObject(with: original)
      var object = try #require(decoded as? [String: Any])
      func publish(_ bytes: Data) throws -> Data {
        var hashes = pointer.hashes
        hashes[part] = ScriptPackLibrary.hash(bytes)
        let changed = ScriptSavePointer(format: pointer.format, schemaVersion: pointer.schemaVersion,
          generation: pointer.generation, hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec,
          bisonUnitJournalCheckpoint: checkpoint)
        try bytes.write(to: chunkURL, options: .atomic)
        let published = try JSONEncoder().encode(changed)
        try published.write(to: storage.url, options: .atomic)
        return published
      }
      // Re-encoding and rehashing alone must not invalidate the original archive.
      let control = try publish(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
      let controlRead = try ScriptSaveStore.read(control, from: storage.url)
      #expect(controlRead.0 == originalRead.0 && controlRead.1 == originalRead.1)
      object[NativeTitheCommissionSave.field] = NSNull()
      input = try publish(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }
    try input.write(to: storage.url, options: .atomic)
    let corruptFiles = try titheArchiveJoinFiles(storage.directory)
    #expect(throws: (any Error).self) { _ = try ScriptSaveStore.read(input, from: storage.url) }
    var refused = false
    do { try await runtime.load(from: storage.url, persistMigrations: false) } catch { refused = true }
    let after = await runtime.snapshot()
    let refusedWithoutPublication = refused && after.commander == before.commander && after.scriptWorldSave == before.scriptWorldSave
    #expect(refusedWithoutPublication)
    let epochUnchanged = after.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch
    #expect(epochUnchanged)
    let afterFiles = try titheArchiveJoinFiles(storage.directory)
    #expect(afterFiles == corruptFiles)
    if let originalChunk { try originalChunk.write(to: chunkURL, options: .atomic) }
    try originalPointer.write(to: storage.url, options: .atomic)
    let restored = try ScriptSaveStore.read(originalPointer, from: storage.url)
    #expect(restored.0 == originalRead.0 && restored.1 == originalRead.1)
    #expect(restored.0.titheCommissionMarkEntitlement == nil)
  }
}
