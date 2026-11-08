import Foundation
import Testing

@testable import L337Core

struct EquipmentPreparationStackTests {
  @Test(arguments: [false, true])
  func currentPreparationKeepsTheWholeCommander(legacy: Bool) throws
  {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    try #require(commander.savedEquipmentVersion == 3 && commander.legacyOwnedEquipment == nil)
    let before = commander
    try commander.prepareEquipment(legacy: legacy)
    #expect(commander == before)
    try commander.prepareEquipment()
    #expect(commander == before)
  }

  @Test(arguments: [
    "missing-inventory", "missing-history", "foreign-history", "missing-drive",
    "missile-mirror", "runtime-statistics", "component-statistics", "unknown-held-node",
    "mixed-legacy",
  ])
  func currentVersionNeverBypassesMalformedStateOrRepairsItDuringPreparation(change: String) throws
  {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let inventory = try #require(commander.equipmentInventory)
    switch change {
    case "missing-inventory": commander.savedEquipmentInventory = nil
    case "missing-history": commander.savedEquipmentPurchaseHistory = nil
    case "foreign-history": commander.savedEquipmentPurchaseHistory = .init(owner: UUID())
    case "missing-drive":
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.location?.slot != .drive })
    case "missile-mirror": commander.missiles += 1
    case "runtime-statistics":
      let navigation = try #require(commander.fittedEquipment(at: .navigation))
      let original = try #require(navigation.component)
      var statistics = original.statistics
      statistics[.jumpFuelCost] = 1e16
      let component = ComponentInstance(
        id: original.id, origin: original.origin, statistics: statistics,
        grade: original.grade, features: original.features, receipts: original.receipts)
      let item = OwnedEquipmentItem(
        id: navigation.id, node: navigation.node, provenance: navigation.provenance,
        component: component, location: navigation.location, boundHull: navigation.boundHull,
        preferredSlot: navigation.preferredSlot, retainedLegacyState: navigation.retainedLegacyState
      )
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.map { $0.id == navigation.id ? item : $0 })
      try #require(commander.jumpFuelMultiplier == 1e16)
      // The finite loaded component is legal; only its effective Int fuel cost is unsafe.
      let changedInventory = try #require(commander.equipmentInventory)
      try changedInventory.validate(
        context: EquipmentRuntimeCatalog.context(
          owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance))
    case "component-statistics":
      let drive = try #require(commander.fittedEquipment(at: .drive))
      let original = try #require(drive.component)
      var statistics = original.statistics
      statistics[.jumpSpool] = .infinity
      let component = ComponentInstance(
        id: original.id, origin: original.origin,
        statistics: statistics, grade: original.grade, features: original.features,
        receipts: original.receipts)
      let item = OwnedEquipmentItem(
        id: drive.id, node: drive.node, provenance: drive.provenance,
        component: component, location: drive.location)
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.map { $0.id == drive.id ? item : $0 })
    case "unknown-held-node":
      let item = OwnedEquipmentItem(
        id: UUID(),
        node: .init(family: EquipmentRuntimeCatalog.laserFamily, key: "Unregistered laser"),
        provenance: .standard)
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items + [item])
    default: commander.legacyOwnedEquipment = .init()
    }
    try #require(commander.savedEquipmentVersion == 3)
    let before = commander
    #expect(throws: (any Error).self) { try commander.prepareEquipment() }
    #expect(commander == before)
    #expect(throws: (any Error).self) { try commander.prepareEquipment(legacy: false) }
    #expect(commander == before)
  }

  @Test func absentOwnershipRequiresAnExplicitFreshProducer() throws {
    var commander = Commander()
    let before = commander
    #expect(throws: CommanderEquipmentError.incompleteState) { try commander.prepareEquipment() }
    #expect(commander == before)
    try commander.prepareEquipment(legacy: false)
    let inventory = try #require(commander.equipmentInventory)
    #expect(commander.savedEquipmentVersion == 3 && commander.legacyOwnedEquipment == nil)
    #expect(commander.equipmentPurchaseHistory?.owner == inventory.owner)
    #expect(commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(commander.credits == before.credits && commander.cargo == before.cargo)
    #expect(commander.fuel == before.fuel && commander.missiles == before.missiles)
    #expect(commander.scriptState == before.scriptState && commander.contracts == before.contracts)
    #expect(commander.accommodation == before.accommodation)
    try commander.validateEquipmentState()
    let prepared = commander
    try commander.prepareEquipment()
    #expect(commander == prepared)
  }

  @Test(arguments: ["inventory", "history", "version", "old-version", "unknown-version", "old-bag"])
  func partialOrUnsupportedOwnershipCannotBecomeFreshOwnership(change: String) throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let inventory = commander.savedEquipmentInventory
    let history = commander.savedEquipmentPurchaseHistory
    commander.savedEquipmentInventory = nil
    commander.savedEquipmentPurchaseHistory = nil
    commander.savedEquipmentVersion = nil
    switch change {
    case "inventory": commander.savedEquipmentInventory = inventory
    case "history": commander.savedEquipmentPurchaseHistory = history
    case "version": commander.savedEquipmentVersion = 3
    case "old-version":
      commander.savedEquipmentInventory = inventory
      commander.savedEquipmentPurchaseHistory = history
      commander.savedEquipmentVersion = 2
    case "unknown-version": commander.savedEquipmentVersion = 4
    default: commander.legacyOwnedEquipment = .init()
    }
    let before = commander
    #expect(throws: CommanderEquipmentError.incompleteState) { try commander.prepareEquipment() }
    #expect(commander == before)
    #expect(throws: CommanderEquipmentError.incompleteState) {
      try commander.prepareEquipment(legacy: false)
    }
    #expect(commander == before)
  }

  @Test(arguments: [false, true])
  func writerRefusesUnownedOrUnsupportedEquipmentBeforePublishing(unsupported: Bool) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let retained = Data("keep the existing save".utf8)
    try retained.write(to: file)
    var candidate = Game(executive: false)
    if unsupported {
      try candidate.commander.prepareEquipment(legacy: false)
      candidate.commander.savedEquipmentVersion = 2
    }
    let before = candidate
    #expect(throws: CommanderEquipmentError.incompleteState) {
      try GameRuntime.writeCommander(&candidate, to: file)
    }
    #expect(candidate.commander == before.commander && candidate.bodies == before.bodies)
    #expect(candidate.time == before.time && candidate.gameplayRevision == before.gameplayRevision)
    #expect(try Data(contentsOf: file) == retained)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == [file.lastPathComponent])
  }

  @Test(arguments: ["absent", "unsupported"])
  func nativeEnvelopeCannotCreateOrUpgradeMissingCurrentOwnership(state: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var source = Game(executive: false)
    try source.commander.prepareEquipment(legacy: false)
    let writer = GameRuntime(game: source)
    try await writer.save(to: storage.url)
    let saved = await writer.snapshot().commander
    let pointerBytes = try Data(contentsOf: storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: storage.url)
    let commanderFile = generation.appendingPathComponent("commander.json")
    var object = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: commanderFile)) as? [String: Any])
    try #require(object["savedEquipmentVersion"] as? Int == 3)
    try #require(object["savedEquipmentInventory"] != nil)
    try #require(object["savedEquipmentPurchaseHistory"] != nil)
    if state == "absent" {
      for key in ["savedEquipmentInventory", "savedEquipmentPurchaseHistory", "savedEquipmentVersion"] {
        object.removeValue(forKey: key)
      }
    } else {
      var unsupported = saved
      let inventory = try #require(saved.equipmentInventory)
      unsupported.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.node.family != HyperspaceDriveDefinition.purchaseFamily })
      unsupported.savedEquipmentVersion = 2
      unsupported.mirrorFittedEquipment()
      object["savedEquipmentInventory"] = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(try #require(unsupported.equipmentInventory)))
      object["savedEquipmentVersion"] = 2
      object["equipment"] = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(unsupported.equipment))
    }
    let changed = try JSONSerialization.data(withJSONObject: object)
    try changed.write(to: commanderFile)
    var published = try #require(
      JSONSerialization.jsonObject(with: pointerBytes) as? [String: Any])
    var hashes = try #require(published["hashes"] as? [String: String])
    hashes["commander.json"] = ScriptPackLibrary.hash(changed)
    published["hashes"] = hashes
    let input = try JSONSerialization.data(withJSONObject: published)
    try input.write(to: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.root)
    var seed = Game(executive: false)
    try seed.commander.prepareEquipment(legacy: false)
    seed.commander.name = "KEEP OWNERSHIP"
    let receiver = GameRuntime(game: seed)
    let before = await receiver.snapshot()
    let saveURL = await receiver.scriptSaveURL
    await #expect(throws: (any Error).self) {
      try await receiver.load(from: storage.url, persistMigrations: false)
    }
    let after = await receiver.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.screen == before.screen && after.time == before.time)
    #expect(after.gameplayRevision == before.gameplayRevision)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(await receiver.scriptSaveURL == saveURL)
    #expect(try Data(contentsOf: storage.url) == input)
    #expect(try ScriptFinanceTestFixture.files(storage.root) == files)
  }

  @Test(arguments: ["absent", "current", "unsupported"])
  func suppliedRuntimeGameNeverInventsOrReplacesOwnership(state: String) async throws {
    var supplied = Game(executive: false)
    if state != "absent" {
      try supplied.commander.prepareEquipment(legacy: false)
      supplied.commander.mirrorFittedEquipment()
      if state == "unsupported" { supplied.commander.savedEquipmentVersion = 2 }
    }
    let before = supplied.commander
    let runtime = GameRuntime(game: supplied)
    let snapshot = await runtime.snapshot()
    #expect(snapshot.commander.equipmentInventory == before.equipmentInventory)
    #expect(snapshot.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(snapshot.commander.savedEquipmentVersion == before.savedEquipmentVersion)
    #expect(snapshot.commander.legacyOwnedEquipment == before.legacyOwnedEquipment)
    #expect(snapshot.commander.credits == before.credits && snapshot.commander.cargo == before.cargo)
    #expect(snapshot.commander.fuel == before.fuel && snapshot.commander.missiles == before.missiles)
  }
}
