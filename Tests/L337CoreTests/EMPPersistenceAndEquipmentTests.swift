import Foundation
import Testing

@testable import L337Core

struct EMPPersistenceAndEquipmentTests {
  @Test func nativeSaveRestoresDisabledHullAndEveryOccupiedPodWithoutReissuingPeople() async throws
  {
    var game = try empFixture(catalogue: EMPUnitTargetCatalogue.twoPerson)
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let empResult = try releaseDamagedEMPBoundary(&game)
    try #require(empResult)
    let source = try #require(game.bodies[0].physical?.empSource)
    try ejectScheduledEMPCrewBoundary(&game, source: source)
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion >= 25)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.valid && saved.savedEMPState == game.commander.savedEMPState)
    let restored = GameRuntime()
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.savedEMPState == saved.savedEMPState)
    #expect(
      loaded.bodies.filter { $0.physical?.empCrewPod?.source == source }.count == record.crewTotal)
    let hull = try #require(loaded.bodies.first { $0.physical?.empSource == source })
    #expect(loaded.isEMPDisabled(hull) && hull.physical?.npc == nil)
    #expect(
      hull.physical?.identity
        == game.bodies.first { $0.physical?.empSource == source }?.physical?.identity)
    for _ in 0..<30 { _ = await restored.advance(delta: 0.1) }
    let after = await restored.snapshot()
    #expect(after.commander.savedEMPState?.records[source]?.pods.count == record.crewTotal)
    #expect(Set(after.bodies.compactMap { $0.physical?.empCrewPod }).count == record.crewTotal)
    var bad = after
    bad.commander.savedEMPState?.records[source]?.hull.body.physical?.empSource = .init(
      system: source.system, visit: source.visit, entity: source.entity + 1)
    #expect(!bad.commander.valid)
    let refused = GameRuntime(game: bad)
    let invalidFile = directory.appendingPathComponent("refused.json")
    await #expect(throws: (any Error).self) { try await refused.save(to: invalidFile) }
    #expect(!FileManager.default.fileExists(atPath: invalidFile.path))
  }

  @Test func currentSaveKeepsInnocentEMPWordsAndUnwrappedJSONCannotAcquireOwnership() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = Game(executive: false)
    game.screen = .status
    game.commander.name = "empPirateBlaster"
    try game.commander.prepareEquipment(legacy: false)
    var instance = ScriptInstance(
      id: UUID(), definition: "fixture/innocent-text", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.data = .object([
      "kind": .string("emp"), "producer": .string("emp"),
      "empSource": .string("dialogue only"), "name": .string(Equipment.empPirateBlaster),
    ])
    game.commander.scriptState.instances[instance.id] = instance
    let writer = GameRuntime(game: game)
    try await writer.save(to: storage.url)
    let bytes = try Data(contentsOf: storage.url)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: storage.url)
    #expect(saved.scriptState.instances[instance.id]?.data == instance.data)
    #expect(saved.savedEMPState == nil)
    let raw = storage.root.appendingPathComponent("unwrapped.json")
    try JSONEncoder().encode(saved).write(to: raw)
    let files = try ScriptFinanceTestFixture.files(storage.root)
    let reader = GameRuntime(game: Game(executive: false))
    let before = await reader.snapshot()
    await #expect(throws: SaveError.self) { try await reader.load(from: raw, persistMigrations: false) }
    let after = await reader.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.screen == before.screen && after.time == before.time)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(try Data(contentsOf: storage.url) == bytes)
    #expect(try ScriptFinanceTestFixture.files(storage.root) == files)
  }

  @Test func actualEMPContainerCannotBeDowngradedOrEraseItsTrafficTransfer() async throws {
    var game = try empFixture()
    let empResult = try releaseDamagedEMPBoundary(&game)
    try #require(empResult)
    let source = try #require(game.commander.savedEMPState?.records.keys.first)
    #expect(game.commander.npcPersistence.terminalReason(for: source) == .empTransferred)
    var erased = game.commander
    erased.savedEMPState = nil
    #expect(!erased.valid)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    try #require(pointer.schemaVersion == ScriptSaveStore.publicationSchema(
      saved, alien: saved.alienStorageState != nil))
    #expect(saved.savedEMPState == game.commander.savedEMPState)
    #expect(saved.npcPersistence.terminalReason(for: source) == .empTransferred)
    let malformed = ScriptSavePointer(
      format: pointer.format, schemaVersion: Int.max, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      _ = try ScriptSaveStore.read(ScriptValueStorage.encoder().encode(malformed), from: file)
    }
    let raw = directory.appendingPathComponent("raw.json")
    try JSONEncoder().encode(game.commander).write(to: raw)
    let restored = GameRuntime()
    await #expect(throws: (any Error).self) { try await restored.load(from: raw) }
  }

  @Test func realShopDebitsFiniteCashAndReloadKeepsOneSeparateFitting() async throws {
    var game = Game(executive: false)
    game.screen = .equipment
    try #require(game.commander.shipID == NewCommanderDefaults.shipID)
    try #require(game.commander.shipID == "SH025")
    try #require(!OriginalDetailedHullStage.blocksRuntime(game.commander.shipID))
    let fitting = try #require(OriginalFleetR3Fitting.contract(for: game.commander.ship)?.fitting)
    try #require(fitting.utilityMounts == 3)
    game.commander.fuel = game.commander.fuelCapacity
    game.commander.credits = 100_000
    game.commander.system = try #require(game.systems.first { $0.technology >= 9 }?.id)
    game.selectedSystem = game.commander.system
    game.market = MarketItem.at(game.currentSystem)
    try game.commander.prepareEquipment(legacy: false)
    game.selection = try #require(
      Equipment.all.firstIndex { $0.name == Equipment.empPirateBlaster })
    let item = Equipment.all[game.selection]
    #expect(item.price == 30_000 && item.technology == 8)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    #expect(result.applied)
    let after = await runtime.snapshot()
    #expect(after.commander.credits == before.commander.credits - before.shopPrice(item))
    #expect(
      after.commander.fittedEquipment(at: .utility(.empPirateBlaster))?.node.key
        == Equipment.empPirateBlaster)
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    let bytes = try Data(contentsOf: file)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: bytes).schemaVersion >= 22)
    let replay = await runtime.equipmentTransaction(.purchase(context))
    #expect(replay == .refused(.staleContext))
    #expect(try Data(contentsOf: file) == bytes)
    let restored = GameRuntime()
    try await restored.load(from: file)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.equipmentInventory == after.commander.equipmentInventory)
    #expect(
      loaded.commander.equipmentInventory?.items.filter {
        $0.node.key == Equipment.empPirateBlaster
      }.count == 1)
    #expect(loaded.commander.laserMounts == before.commander.laserMounts)
  }

  @Test func xyzzyGrantsOneBlasterAndRetainsFourNavalLasersAcrossRepeatedGrantAndLoad() async throws
  {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    for key in "xyzzy" { game.key(String(key)) }
    for _ in 0..<3 { game.key("2") }
    let tool = try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    #expect(tool.provenance == .xyzzy)
    #expect(
      game.commander.equipmentInventory?.items.filter { $0.node.key == Equipment.empPirateBlaster }
        .count == 1)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    game.key("return")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let restored = GameRuntime()
    try await restored.load(from: file)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.fittedEquipment(at: .utility(.empPirateBlaster))?.id == tool.id)
    #expect(
      loaded.commander.equipmentInventory?.items.filter {
        $0.node.key == Equipment.empPirateBlaster
      }.count == 1)
    #expect(LaserMount.allCases.allSatisfy { loaded.commander.laser(on: $0) == .naval })
  }
}
