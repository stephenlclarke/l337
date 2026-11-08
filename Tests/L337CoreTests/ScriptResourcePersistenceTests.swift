import Foundation
import Testing

@testable import L337Core

private func currentMissionResourceGame() throws -> Game {
  var game = Game(executive: false)
  game.commander.name = "CURRENT RESOURCE OWNER"
  try game.commander.prepareEquipment(legacy: false)
  game.ensureScriptCalendar(origin: .newCommander)
  try NativeSaveTestFixture.prepareCurrentPolicy(&game)
  try #require(game.commander.valid && game.scriptWorldSave.valid)
  try #require(game.scriptWorldSave.consistent(with: game.commander))
  return game
}

struct ScriptResourcePersistenceTests {
  @Test func currentOwnedResourcesStartAMissionAndRoundTripThroughNativeEnvelope() async throws {
    let fixture = try GearScriptFixture(requiredReturn: false, accepted: "")
    defer { fixture.clean() }
    var current = try currentMissionResourceGame()
    current.scriptPacks = [fixture.pack]
    var seed = Game(executive: false)
    seed.scriptPacks = [fixture.pack]
    let file = fixture.root.appendingPathComponent("current-resources.json")
    try GameRuntime.writeCommander(&current, to: file)
    let before = current.commander
    let inventory = try #require(before.equipmentInventory)
    let bytes = try Data(contentsOf: file)
    let originalFiles = try ScriptFinanceTestFixture.files(fixture.root)
    try #require(seed.commander.name != before.name)
    let runtime = GameRuntime(game: seed)
    try await runtime.load(from: file, persistMigrations: false)
    var admitted = await runtime.snapshot()
    #expect(admitted.commander.equipmentInventory == inventory)
    #expect(admitted.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(admitted.commander.credits == before.credits && admitted.commander.cargo == before.cargo)
    #expect(admitted.commander.name == before.name && admitted.commander.shipID == before.shipID)
    #expect(admitted.commander.fuel == before.fuel && admitted.commander.missiles == before.missiles)
    #expect(admitted.energy == current.energy && admitted.frontShield == current.frontShield)
    #expect(admitted.rearShield == current.rearShield)
    #expect(try Data(contentsOf: file) == bytes)
    #expect(try ScriptFinanceTestFixture.files(fixture.root) == originalFiles)
    admitted.screen = .status
    let id = try admitted.acceptScriptMission(fixture.pack)
    try #require(admitted.commander.scriptState.instances[id]?.suspension == nil)
    try #require(admitted.commander.scriptState.instances[id]?.outcome == .active)
    #expect(admitted.commander.equipmentInventory == inventory)
    let save = fixture.root.appendingPathComponent("mission.json")
    try GameRuntime.writeCommander(&admitted, to: save)
    let saved = admitted
    let pointer = try Data(contentsOf: save)
    let envelope = try JSONDecoder().decode(ScriptSavePointer.self, from: pointer)
    #expect(envelope.schemaVersion == 26)
    let (header, world) = try ScriptSaveStore.read(pointer, from: save)
    #expect(header.valid && world.valid && world.consistent(with: header))
    #expect(header.equipmentInventory == inventory)
    #expect(world.energy == saved.energy && world.frontShield == saved.frontShield)
    #expect(world.rearShield == saved.rearShield)
    let files = try ScriptFinanceTestFixture.files(fixture.root)
    let cold = GameRuntime(game: seed)
    try await cold.load(from: save, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander.scriptState.instances[id] == saved.commander.scriptState.instances[id])
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == saved.commander.equipmentPurchaseHistory)
    #expect(loaded.energy == saved.energy && loaded.frontShield == saved.frontShield)
    #expect(loaded.rearShield == saved.rearShield)
    #expect(try Data(contentsOf: save) == pointer)
    #expect(try ScriptFinanceTestFixture.files(fixture.root) == files)
    try await cold.save(to: save)
    let (resaved, resavedWorld) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
    #expect(resaved.equipmentInventory == inventory && resavedWorld.energy == loaded.energy)
    #expect(resavedWorld.frontShield == loaded.frontShield && resavedWorld.rearShield == loaded.rearShield)
  }

  @Test(arguments: ["energy", "front", "rear"])
  func resourceJoinUsesActualCurrentCapacityAndRejectsExcessOrInvalidValues(field: String) throws {
    let game = try currentMissionResourceGame()
    let commander = game.commander
    var world = game.scriptWorldSave
    let capacity: Double
    switch field {
    case "energy": capacity = commander.performance.energy
    case "front": capacity = commander.shieldCapacity
    default: capacity = commander.rearShieldCapacity
    }
    func set(_ value: Double, in world: inout ScriptWorldSave) {
      switch field {
      case "energy": world.energy = value
      case "front": world.frontShield = value
      default: world.rearShield = value
      }
    }
    set(capacity, in: &world)
    #expect(world.valid && world.consistent(with: commander))
    set(capacity.nextUp, in: &world)
    #expect(world.valid && !world.consistent(with: commander))
    for invalid in [-1.0, Double.infinity, Double.nan] {
      set(invalid, in: &world)
      #expect(!world.valid)
    }
  }
}
