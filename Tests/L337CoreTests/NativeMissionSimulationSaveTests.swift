import Foundation
import Testing

@testable import L337Core

struct NativeMissionSimulationSaveTests {
  @Test func presentNullAndWrongTypeECMTimeRefuseActualLoadWithoutPublishingLiveState() async throws
  {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    try game.commander.prepareEquipment(legacy: false)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let before = await runtime.snapshot()
    let originalPointer = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let world = directory.appendingPathComponent("world.json")
    let originalWorld = try Data(contentsOf: world)
    for malformed in [NSNull(), "wrong-type"] as [Any] {
      var object = try #require(JSONSerialization.jsonObject(with: originalWorld) as? [String: Any])
      var simulation = try #require(object["simulation"] as? [String: Any])
      simulation["ecmRemainingDuration"] = malformed
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          ScriptSimulationSave.self, from: JSONSerialization.data(withJSONObject: simulation))
      }
      object["simulation"] = simulation
      let bytes = try JSONSerialization.data(withJSONObject: object)
      try bytes.write(to: world)
      var published = try #require(
        JSONSerialization.jsonObject(with: originalPointer) as? [String: Any])
      var hashes = try #require(published["hashes"] as? [String: String])
      hashes["world.json"] = ScriptPackLibrary.hash(bytes)
      published["hashes"] = hashes
      let input = try JSONSerialization.data(withJSONObject: published)
      try input.write(to: url)
      var refused = false
      do { try await runtime.load(from: url, persistMigrations: false) } catch { refused = true }
      let after = await runtime.snapshot()
      #expect(refused && after.commander == before.commander && after.bodies == before.bodies)
      #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(after.ecmControl.epoch == before.ecmControl.epoch)
      #expect(try Data(contentsOf: url) == input)
      #expect(try Data(contentsOf: world) == bytes)
    }
  }

  private func decoded(
    _ state: ScriptSimulationSave, changing edit: (inout [String: Any]) -> Void
  ) throws -> ScriptSimulationSave {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    edit(&object)
    return try JSONDecoder().decode(
      ScriptSimulationSave.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func modernFractionalECMTimeRoundTripsExactlyAndClearsPreviousLiveOwnership() throws {
    var source = Game(executive: false)
    source.ecmControl.activateExternalField()
    source.ecmControl.advance(delta: 0.007)
    let state = source.scriptSimulationSave
    try #require(state.valid && state.spawnClock == nil)
    let bytes = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(ScriptSimulationSave.self, from: bytes)
    var loaded = Game(executive: false)
    loaded.ecmControl.activate(destroyed: 2)
    try #require(loaded.ecmControl.ownFieldActive)
    loaded.restoreScriptSimulation(decoded)
    #expect(loaded.ecmControl.remainingDuration == source.ecmControl.remainingDuration)
    #expect(loaded.ecmFrames == source.ecmFrames && !loaded.ecmControl.ownFieldActive)
    #expect(loaded.ecmControl.activation == 0 && loaded.ecmControl.events.isEmpty)
    #expect(loaded.scriptSimulationSave.spawnClock == nil && loaded.activeECMActivation == nil)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(object["spawnClock"] == nil)
  }

  @Test func presentInconsistentOrOutOfBoundsECMTimeCannotFallBackToLegacyFrames() throws {
    var game = Game(executive: false)
    game.ecmControl.activateExternalField()
    let state = game.scriptSimulationSave
    for duration in [0.0, -0.1, 1024.0 / ECMControl.referenceFramesPerSecond + 1] {
      let invalid = try decoded(state) { object in object["ecmRemainingDuration"] = duration }
      #expect(!invalid.valid)
    }
    let invalidLegacy = try decoded(state) { object in object["spawnClock"] = -1 }
    #expect(!invalidLegacy.valid)
  }
}
