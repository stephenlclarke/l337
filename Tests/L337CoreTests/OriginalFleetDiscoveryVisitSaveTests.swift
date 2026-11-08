import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalFleetDiscoveryVisitSaveTests {
  @Test func currentVisitRejectsMovedSystemsWhileRealTravelPreservesHistoricalSighting() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched(withDockingComputer: true)
    let owner = try #require(game.commander.equipmentOwnerID)
    let identity = OriginalStationSite.frog.identity(world: owner)
    let initial = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
    try #require(game.nativeStationBodyIsCurrent(initial))
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(initial.position + initial.entranceNormal * 2000)
    pose.orientation.y = previous.orientation.apply(initial.entranceUp)
    pose.orientation.z = previous.orientation.apply(initial.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    let station = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
    game.autoPilot.cycle(
      [station], frontIDs: [station.id], signature: "actual-frog-discovery-save",
      origin: game.commander.flightSimulation.player)
    game.screen = .front
    game.observeSelectedFleetDiscovery()
    let history = try #require(game.commander.scriptState.savedFleetDiscovery)
    let entry = try #require(history.entries["SH034"])
    try #require(history.valid && entry.valid && entry.encounter.kind == .encounter)
    try #require(entry.identification == nil && entry.milestone == nil)
    #expect(entry.encounter.actor == station.physical?.identity)
    #expect(entry.encounter.player == game.commander.flightSimulation.player)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let pointerBytes = try Data(contentsOf: storage.url)
    let (pristine, world) = try ScriptSaveStore.read(pointerBytes, from: storage.url)
    try #require(pristine.valid && world.consistent(with: pristine))
    try #require(NativeFleetDiscoverySave.validateClaims(pristine))
    try #require(pristine.scriptState.savedFleetDiscovery == history)
    try #require(entry.encounter.actor.visit == pristine.flightSimulation.visit)
    try #require(entry.encounter.actor.system == pristine.flightSimulation.system)
    try #require(entry.encounter.actor.entity < pristine.flightSimulation.nextActor)
    try #require(entry.encounter.physicalTime <= pristine.flightSimulation.physicalTime)

    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    #expect(NativeFleetDiscoverySave.contains(pointer.schemaVersion))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: storage.url)
    let missions = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: missions)
    defer { try? original.write(to: missions) }
    let decodedMissions = try JSONSerialization.jsonObject(with: original)
    var object = try #require(decodedMissions as? [String: Any])
    var discovery = try #require(object["savedFleetDiscovery"] as? [String: Any])
    var entries = try #require(discovery["entries"] as? [String: Any])
    var recorded = try #require(entries["SH034"] as? [String: Any])
    var encounter = try #require(recorded["encounter"] as? [String: Any])
    let foreignSystem = SystemIdentity(galaxy: 0, system: 185)
    for key in ["actor", "player"] {
      var actor = try #require(encounter[key] as? [String: Any])
      actor["system"] = ["galaxy": foreignSystem.galaxy, "system": foreignSystem.system]
      encounter[key] = actor
    }
    recorded["encounter"] = encounter
    entries["SH034"] = recorded
    discovery["entries"] = entries
    object["savedFleetDiscovery"] = discovery
    let moved = try JSONDecoder().decode(
      NativeFleetDiscovery.self, from: JSONSerialization.data(withJSONObject: discovery))
    try #require(moved.valid)
    let altered = try #require(moved.entries["SH034"]?.encounter)
    #expect(altered.actor.system == foreignSystem && altered.player.system == foreignSystem)
    #expect(altered.actor.visit == entry.encounter.actor.visit && altered.player.visit == entry.encounter.player.visit)
    #expect(altered.actor.entity == entry.encounter.actor.entity && altered.player.entity == entry.encounter.player.entity)
    #expect(altered.owner == entry.encounter.owner && altered.physicalTime == entry.encounter.physicalTime)
    var invalid = pristine
    invalid.scriptState.savedFleetDiscovery = moved
    #expect(!NativeFleetDiscoverySave.validateClaims(invalid) && !invalid.valid)
    let refusedURL = storage.root.appendingPathComponent("foreign-claim/commander.json")
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveStore.write(commander: invalid, world: world, to: refusedURL)
    }
    #expect(!FileManager.default.fileExists(atPath: refusedURL.path))
    let changedBytes = try JSONSerialization.data(withJSONObject: object)
    try changedBytes.write(to: missions)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(changedBytes)
    let changedPointer = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveStore.read(JSONEncoder().encode(changedPointer), from: storage.url)
    }
    try original.write(to: missions)
    let restoredCurrent = try ScriptSaveStore.read(pointerBytes, from: storage.url).0
    #expect(restoredCurrent == pristine)
    let unchangedPointerBytes = try Data(contentsOf: storage.url)
    #expect(unchangedPointerBytes == pointerBytes)

    // Existing native controls produce the next visit; no synthetic enter-system shortcut.
    try await ScriptProcurementFixture.dock(runtime)
    try await ScriptProcurementFixture.travel(runtime, path: [7, 185], verifyDeparture: true)
    let travelled = await runtime.snapshot()
    try #require(travelled.commander.flightSimulation.system == foreignSystem)
    try #require(travelled.commander.flightSimulation.visit > entry.encounter.actor.visit)
    try #require(travelled.commander.scriptState.savedFleetDiscovery?.entries["SH034"] == entry)
    #expect(entry.encounter.actor.system != travelled.commander.flightSimulation.system)
    #expect(NativeFleetDiscoverySave.validateClaims(travelled.commander))
    try await runtime.save(to: storage.url)
    let historical = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    #expect(historical.valid && NativeFleetDiscoverySave.validateClaims(historical))
    #expect(historical.scriptState.savedFleetDiscovery?.entries["SH034"] == entry)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot().commander
    #expect(loaded == historical && loaded.scriptState.savedFleetDiscovery?.entries["SH034"] == entry)
  }
}
