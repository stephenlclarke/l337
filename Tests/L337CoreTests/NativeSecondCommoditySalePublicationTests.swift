import Foundation
import Testing

@testable import L337Core

private extension GameRuntime {
  func chooseSecondSaleTestCommodity(_ index: Int) {
    game.screen = .buy
    game.selection = index
  }
}

private func secondSaleTestFiles(_ root: URL) throws -> [String: Data] {
  let files = try #require(FileManager.default.enumerator(at: root,
    includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL])
  var result: [String: Data] = [:]
  for file in files where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
    result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
  }
  return result
}

struct NativeSecondCommoditySalePublicationTests {
  @Test func secondActualSaleRollsBackWithTheMarketAndRetriesOnceAcrossColdContinue() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let directory = files.save.deletingLastPathComponent()
    let backup = files.root.appendingPathComponent("second-sale-backup")
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    let initial = await runtime.snapshot()
    let items = initial.market
    let credits = initial.commander.availableCredits
    let index = try #require(items.indices.first {
      Commodity.all[$0].unit == "t" && items[$0].quantity >= 2
        && items[$0].price > 0 && items[$0].price <= credits / 2
        && initial.commander.cargo[$0] == 0
    })
    await runtime.chooseSecondSaleTestCommodity(index)
    await runtime.key("right")
    await runtime.key("right")
    await runtime.key("left")
    let before = await runtime.snapshot()
    let first = try #require(before.commander.scriptState.firstNativeCommoditySale)
    let trade = try #require(before.commander.scriptState.firstNativeCommodityTrade)
    let beforeHistory = try NativeTitheCommissionHistory.current(in: before)
    try #require(before.commander.cargo[index] == 1 && beforeHistory.retainedOrdinarySaleCount == 1)
    var duplicateFirst = before
    duplicateFirst.retainNativeOrdinarySale(first)
    #expect(duplicateFirst.commander == before.commander)
    #expect(duplicateFirst.commander.scriptState.secondNativeCommoditySale == nil)
    let originalFiles = try secondSaleTestFiles(directory)
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked second-sale publication".utf8).write(to: directory)
    defer {
      if FileManager.default.fileExists(atPath: backup.path) {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.moveItem(at: backup, to: directory)
      }
    }

    await runtime.key("left")

    let refused = await runtime.snapshot()
    #expect(refused.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.bodies == before.bodies && refused.jumpCountdown == before.jumpCountdown)
    #expect(refused.commander.scriptState.secondNativeCommoditySale == nil)
    #expect(try secondSaleTestFiles(backup) == originalFiles)
    #expect(try Data(contentsOf: directory) == Data("blocked second-sale publication".utf8))
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    await runtime.key("left")
    let committed = await runtime.snapshot()
    let second = try #require(committed.commander.scriptState.secondNativeCommoditySale)
    let committedHistory = try NativeTitheCommissionHistory.current(in: committed)
    #expect(second.valid(after: first) && committedHistory.retainedOrdinarySaleCount == 2)
    #expect(committed.commander.scriptState.firstNativeCommoditySale === first)
    #expect(committed.commander.scriptState.firstNativeCommodityTrade === trade)
    #expect(committed.commander.cargo[index] == 0)
    #expect(committed.market[index].quantity == before.market[index].quantity + 1)
    #expect(committed.commander.credits == before.commander.credits + before.market[index].bidPrice)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: files.save))
    #expect(pointer.schemaVersion == NativeSecondCommoditySaleSave.version)
    let stored = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save).0
    #expect(stored == committed.commander && stored.scriptState.secondNativeCommoditySale == second)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.restoreStartup(from: files.save)
    await cold.key("return")
    let continued = await cold.snapshot()
    #expect(continued.commander.scriptState.secondNativeCommoditySale == second)
    #expect(try NativeTitheCommissionHistory.current(in: continued).retainedOrdinarySaleCount == 2)
    #expect(continued.commander.scriptState.instances.isEmpty && continued.commander.scriptState.savedClueJournal == nil)
    await cold.chooseSecondSaleTestCommodity(index)
    await cold.key("left")
    var replay = await cold.snapshot()
    replay.retainNativeOrdinarySale(second.sale)
    #expect(replay.commander.scriptState.secondNativeCommoditySale == second)
    #expect(replay.commander.scriptState.firstNativeCommoditySale == first)
  }

  @Test func currentSecondSaleArchiveClosesNamespaceAndRehashedClaimTampering() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    let initial = await runtime.snapshot()
    let index = try #require(initial.market.indices.first {
      Commodity.all[$0].unit == "t" && initial.market[$0].quantity >= 2
        && initial.market[$0].price > 0
        && initial.market[$0].price <= initial.commander.availableCredits / 2
    })
    await runtime.chooseSecondSaleTestCommodity(index)
    await runtime.key("right")
    await runtime.key("right")
    await runtime.key("left")
    await runtime.key("left")
    let before = await runtime.snapshot()
    let second = try #require(before.commander.scriptState.secondNativeCommoditySale)
    let leaf = try JSONEncoder().encode(second)
    let leafText = try #require(String(data: leaf, encoding: .utf8))
    let field = NativeSecondCommoditySaleSave.field
    let wrapper = Data(("{\"" + field + "\":" + leafText + "}").utf8)
    try NativeSecondCommoditySaleSave.validateFields(wrapper, location: .missions, schema: NativeSecondCommoditySaleSave.version)
    #expect(throws: SaveError.invalidCommander) {
      try NativeSecondCommoditySaleSave.validateFields(
        Data("{}".utf8), location: .missions, schema: NativeSecondCommoditySaleSave.version)
    }
    for location in [ScriptSaveJSONPreflight.InquiryArchiveLocation.pointer, .commander, .contracts, .world] {
      #expect(throws: SaveError.invalidCommander) {
        try NativeSecondCommoditySaleSave.validateFields(wrapper, location: location, schema: NativeSecondCommoditySaleSave.version)
      }
    }
    for invalid in [Data(("{\"" + field + "\":null}").utf8),
      Data(("{\"" + field + "\":" + leafText + ",\"" + field + "\":" + leafText + "}").utf8)]
    {
      #expect(throws: SaveError.invalidCommander) {
        try NativeSecondCommoditySaleSave.validateFields(invalid, location: .missions, schema: NativeSecondCommoditySaleSave.version)
      }
    }
    for schema in [Int?.none, .some(CurrentNewtKitSave.version), .some(CurrentNewtKitSave.alienVersion)] {
      #expect(throws: SaveError.invalidCommander) {
        try NativeSecondCommoditySaleSave.validateFields(wrapper, location: .missions, schema: schema)
      }
    }
    let numericCoercion = leafText.replacingOccurrences(of: "\"quantity\":1", with: "\"quantity\":1.0")
    try #require(numericCoercion != leafText)
    #expect(throws: SaveError.invalidCommander) {
      try NativeSecondCommoditySaleSave.validateFields(
        Data(("{\"" + field + "\":" + numericCoercion + "}").utf8), location: .missions, schema: NativeSecondCommoditySaleSave.version)
    }
    var unknownLeaf = try #require(JSONSerialization.jsonObject(with: leaf) as? [String: Any])
    unknownLeaf["earnedCommission"] = true
    let unknown = try JSONSerialization.data(withJSONObject: [field: unknownLeaf])
    #expect(throws: SaveError.invalidCommander) {
      try NativeSecondCommoditySaleSave.validateFields(unknown, location: .missions, schema: NativeSecondCommoditySaleSave.version)
    }
    let pointerBytes = try Data(contentsOf: files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: files.save)
    let missionsURL = generation.appendingPathComponent("missions.json")
    let missionsBytes = try Data(contentsOf: missionsURL)
    var missions = try #require(JSONSerialization.jsonObject(with: missionsBytes) as? [String: Any])
    var changed = try #require(missions[field] as? [String: Any])
    changed["firstOperation"] = UUID().uuidString
    missions[field] = changed
    let corrupt = try JSONSerialization.data(withJSONObject: missions)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(corrupt)
    let damaged = ScriptSavePointer(format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    try corrupt.write(to: missionsURL)
    try JSONEncoder().encode(damaged).write(to: files.save)
    let corruptFiles = try secondSaleTestFiles(files.save.deletingLastPathComponent())
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: files.save, persistMigrations: false)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    #expect(try secondSaleTestFiles(files.save.deletingLastPathComponent()) == corruptFiles)
    try missionsBytes.write(to: missionsURL)
    try pointerBytes.write(to: files.save)
    try await runtime.load(from: files.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander.scriptState.secondNativeCommoditySale == second)
  }
}

extension NativeSecondCommoditySalePublicationTests {
  /// Existing native fixtures issue the kit. Controlled observer setup preserves
  /// its real world state; only actual swept arrival can supply the market berth.
  @Test(arguments: [false, true])
  func actualIssuedNewtAndSecondSaleKeepCurrentSourceAndCustodyAcrossColdLoad(alien: Bool)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game: Game
    if alien {
      // This existing helper first earns the same ordinary SH029 birth, then
      // disables it, ejects its real crew and retains its actual native wreck.
      game = try NativePagedSalvageFixture.empGame(fullOrdinaryPools: false).0
    } else {
      game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    }
    let born = try #require(game.bodies.first { $0.physical?.currentNewtKitStock != nil })
    let issued = try #require(born.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.current)
    try #require(issued.issue.birthActor == born.physical?.identity)
    try #require(issued.issue.birthSpawn == born.physical?.spawnIdentity)
    try #require(source.matches(issued.issue))
    try #require(CurrentNewtKitSave.hasClaims(game.commander))
    try #require(game.commander.usesAlienStorageSaveVersion == alien)
    let originalLogical = game.commander.npcPersistence.logicalIdentity(for: issued.issue.birthActor)
    if alien {
      let original = try #require(game.commander.savedEMPState?.records[issued.issue.person.source])
      try #require(original.crewAboard == 0 && original.pods.count == original.crewTotal)
      let retained = try #require(
        game.commander.alienStorageState?.current.salvage.native.wrecks[original.wreck])
      try #require(retained.source == .emp(actor: original.source, sequence: original.sequence))
    } else {
      let logical = try #require(game.commander.npcPersistence.logicalIdentity(for: issued.issue.birthActor))
      let retained = try #require(game.commander.npcPersistence.snapshot(for: logical))
      try #require(retained.currentNewtKitStock == issued)
    }
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let previous = game.commander.flightSimulation.pose
    var approach = ShipPose()
    approach.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    approach.orientation.y = previous.orientation.apply(station.entranceUp)
    approach.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    approach.orientation.x = approach.orientation.y.cross(approach.orientation.z)
    NativeStationTestFixture.reframe(&game, to: approach)
    game.speed = 3
    game.screen = .front
    let runtime = GameRuntime(game: game)
    try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: storage.url)
    try await runtime.save(to: storage.url)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(CurrentNewtKitSave.hasClaims(arrived.commander))
    try #require(arrived.commander.usesAlienStorageSaveVersion == alien)
    try #require(arrived.commander.scriptState.firstNativeCommoditySale == nil)
    try #require(arrived.commander.scriptState.secondNativeCommoditySale == nil)
    let parkedStock: CurrentNewtKitStock
    if alien {
      parkedStock = try #require(arrived.commander.savedEMPState?.records[issued.issue.person.source]?
        .hull.body.physical?.currentNewtKitStock)
    } else {
      let logical = try #require(originalLogical)
      parkedStock = try #require(arrived.commander.npcPersistence.unboundSnapshots[logical]?
        .currentNewtKitStock)
    }
    try #require(parkedStock.issue == issued.issue)
    let custody = arrived.commander.savedEMPState
    let people = arrived.commander.nativePeople
    let npcPersistence = arrived.commander.npcPersistence
    let alienState = arrived.commander.alienStorageState?.current.snapshot
    let index = try #require(arrived.market.indices.first {
      Commodity.all[$0].unit == "t" && arrived.market[$0].quantity >= 2
        && arrived.market[$0].price > 0
        && arrived.market[$0].price <= arrived.commander.availableCredits / 2
        && arrived.commander.cargo[$0] == 0
    })
    await runtime.chooseSecondSaleTestCommodity(index)
    await runtime.key("right")
    await runtime.key("right")
    let bought = await runtime.snapshot()
    try #require(bought.commander.cargo[index] == 2)
    await runtime.key("left")
    let firstState = await runtime.snapshot()
    let first = try #require(firstState.commander.scriptState.firstNativeCommoditySale)
    try #require(first.before.cargo == 2 && first.after.cargo == 1)
    await runtime.key("left")
    await runtime.nativeCommand { $0.screen = .status }
    try await runtime.save(to: storage.url)
    let saved = await runtime.snapshot()
    let second = try #require(saved.commander.scriptState.secondNativeCommoditySale)
    #expect(second.valid(after: first) && second.sale.operation != first.operation)
    #expect(saved.commander.cargo[index] == 0)
    #expect(saved.market[index].quantity == bought.market[index].quantity + 2)
    #expect(saved.commander.credits == bought.commander.credits + 2 * bought.market[index].bidPrice)
    #expect(saved.commander.savedEMPState == custody && saved.commander.nativePeople == people)
    #expect(saved.commander.npcPersistence == npcPersistence)
    #expect(saved.commander.alienStorageState?.current.snapshot == alienState)
    #expect(CurrentNewtKitSave.hasClaims(saved.commander))
    #expect(NativeSecondCommoditySaleSave.validateClaims(saved.commander))
    let pointerBytes = try Data(contentsOf: storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    #expect(pointer.schemaVersion == (alien
      ? NativeSecondCommoditySaleSave.alienVersion : NativeSecondCommoditySaleSave.version))
    #expect(pointer.hashes.count == (alien ? 5 : 4))
    let (stored, world) = try ScriptSaveStore.read(pointerBytes, from: storage.url)
    #expect(stored == saved.commander && world == saved.scriptWorldSave)
    #expect(world.consistent(with: stored))
    #expect(stored.savedEMPState == custody && stored.nativePeople == people)
    #expect(stored.npcPersistence == npcPersistence)
    #expect(stored.scriptState.secondNativeCommoditySale == second)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander == saved.commander && loaded.scriptWorldSave == saved.scriptWorldSave)
    #expect(CurrentNewtKitSave.hasClaims(loaded.commander))
    #expect(loaded.commander.savedEMPState == custody && loaded.commander.nativePeople == people)
    #expect(loaded.commander.npcPersistence == npcPersistence)
    #expect(loaded.commander.alienStorageState?.current.snapshot == alienState)
    #expect(loaded.commander.scriptState.secondNativeCommoditySale == second)
    if alien {
      #expect(loaded.commander.savedEMPState?.records[issued.issue.person.source]?
        .hull.body.physical?.currentNewtKitStock == parkedStock)
    } else {
      let logical = try #require(originalLogical)
      #expect(loaded.commander.npcPersistence.unboundSnapshots[logical]?
        .currentNewtKitStock == parkedStock)
    }

    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: storage.url)
    let headerURL = directory.appendingPathComponent("commander.json")
    let originalHeader = try Data(contentsOf: headerURL)
    let header = try JSONSerialization.jsonObject(with: originalHeader)
    let control = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
    defer {
      try? originalHeader.write(to: headerURL, options: .atomic)
      try? pointerBytes.write(to: storage.url, options: .atomic)
    }
    func rehashHeader(_ data: Data) throws -> Data {
      var hashes = pointer.hashes
      hashes["commander.json"] = ScriptPackLibrary.hash(data)
      let changed = ScriptSavePointer(format: pointer.format, schemaVersion: pointer.schemaVersion,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      try data.write(to: headerURL, options: .atomic)
      let bytes = try JSONEncoder().encode(changed)
      try bytes.write(to: storage.url, options: .atomic)
      return bytes
    }
    // Re-encoding alone must still load. Only then corrupt a real retained kit's source pin.
    let controlBytes = try rehashHeader(control)
    let controlRead = try ScriptSaveStore.read(controlBytes, from: storage.url)
    #expect(controlRead.0 == saved.commander && controlRead.1 == world)
    var alteredCount = 0
    func corruptSource(_ value: Any) -> Any {
      if var object = value as? [String: Any] {
        if var stock = object["currentNewtKitStock"] as? [String: Any],
          var issue = stock["issue"] as? [String: Any],
          issue["kitID"] as? String == issued.issue.kitID.uuidString,
          alteredCount == 0
        {
          issue["sourceSHA256"] = String(repeating: "f", count: 64)
          stock["issue"] = issue
          object["currentNewtKitStock"] = stock
          alteredCount += 1
          return object
        }
        for key in object.keys.sorted() { object[key] = corruptSource(object[key]!) }
        return object
      }
      if let array = value as? [Any] { return array.map { corruptSource($0) } }
      return value
    }
    let corrupted = corruptSource(header)
    try #require(alteredCount == 1)
    let corruptHeader = try JSONSerialization.data(withJSONObject: corrupted, options: [.sortedKeys])
    try #require(corruptHeader != control)
    let corruptPointer = try rehashHeader(corruptHeader)
    let corruptFiles = try secondSaleTestFiles(storage.directory)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(corruptPointer, from: storage.url)
    }
    await #expect(throws: (any Error).self) {
      try await cold.load(from: storage.url, persistMigrations: false)
    }
    let refused = await cold.snapshot()
    #expect(refused.commander == loaded.commander && refused.scriptWorldSave == loaded.scriptWorldSave)
    #expect(refused.nativeStationRuntimeEpoch == loaded.nativeStationRuntimeEpoch)
    #expect(try secondSaleTestFiles(storage.directory) == corruptFiles)
    try originalHeader.write(to: headerURL, options: .atomic)
    try pointerBytes.write(to: storage.url, options: .atomic)
    let restored = try ScriptSaveStore.read(pointerBytes, from: storage.url)
    #expect(restored.0 == saved.commander && restored.1 == world)
  }
}


extension NativeSecondCommoditySalePublicationTests {
  /// Combine a genuinely issued SH029 kit with a logical SH005 reservation.
  /// The reservation API owns its actor once; no Bison body or stock is issued.
  @Test(arguments: [false, true])
  func secondSaleNewtAndUnobservedJournalSharePublicationRollbackAndColdChecks(alien: Bool)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game: Game
    if alien {
      game = try NativePagedSalvageFixture.empGame(fullOrdinaryPools: false).0
    } else {
      game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    }
    let born = try #require(game.bodies.first { $0.physical?.currentNewtKitStock != nil })
    let issued = try #require(born.physical?.currentNewtKitStock)
    let newt = try #require(CurrentNewtKitSource.current)
    try #require(newt.matches(issued.issue))
    try #require(issued.issue.birthActor == born.physical?.identity)
    try #require(issued.issue.birthSpawn == born.physical?.spawnIdentity)
    try #require(CurrentNewtKitSave.hasClaims(game.commander))
    try #require(game.commander.usesAlienStorageSaveVersion == alien)

    // Same definition-only request as the reviewed private-owner fixture, but
    // against this genuine Newt game's own context and actual allocator.
    let anchors = try #require(game.commander.flightSimulation.anchors)
    NativeStationTestFixture.reframe(&game, to: .init(
      position: (anchors.arrival + anchors.station.position) * 0.5,
      orientation: game.commander.flightSimulation.pose.orientation))
    let context = try #require(game.gameplayContext())
    try #require(EncounterGeography.region(at: context.player.position, anchors: context.anchors) == .tradeLane)
    let bison = try #require(CurrentNewtKitSource.bison)
    let parent = try #require(OriginalFleetRuntimeHullSource.source(for: "SH005"))
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
    npc.resources = NPCResources.stock(parent.performance)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    var request = SpawnRequest(identity: .init(system: context.system, visit: context.visit,
      sequence: sequence, member: 0, producer: .ambient), population: .civilian, hull: .cobra,
      position: anchors.arrival, orientation: .init(), velocity: .init(0, 0, 0), npc: npc,
      rock: nil, payload: nil, priority: .ordinary, catalogueShipID: "SH005")
    request.currentNewtKitConfiguration = bison.configuration
    try #require(bison.permitsBirthDefinition(request, context: context))
    let owner = try game.reserveBisonUnobservedUnits(request: request, context: context)
    let journal = try #require(game.commander.savedBisonUnitAllocations)
    try #require(journal.valid(in: game))
    try #require(owner.birthActor != issued.issue.birthActor && owner.birthSpawn != issued.issue.birthSpawn)
    try #require(!game.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(!bison.sourceQualifiedForBirth)
    #expect(owner.units.count == 13 && owner.units.allSatisfy {
      $0.electrical == .unobserved && $0.gas == .unobserved && $0.thermal == .unobserved
        && $0.mechanical == .unobserved && $0.operative == .unobserved && $0.physicalRoster == .unobserved
    })
    #expect(throws: BisonUnitRetentionError.missingPhysicalCommissioningInputs) {
      try game.requireBisonUnitCommissioning(owner)
    }
    #expect(game.commander.savedBisonUnitAllocations == journal)

    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let previous = game.commander.flightSimulation.pose
    var approach = ShipPose()
    approach.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    approach.orientation.y = previous.orientation.apply(station.entranceUp)
    approach.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    approach.orientation.x = approach.orientation.y.cross(approach.orientation.z)
    NativeStationTestFixture.reframe(&game, to: approach)
    game.speed = 3
    game.screen = .front
    let runtime = GameRuntime(game: game)
    try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: storage.url)
    try await runtime.save(to: storage.url)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(CurrentNewtKitSave.hasClaims(arrived.commander))
    try #require(arrived.commander.savedBisonUnitAllocations == journal)
    try #require(arrived.commander.scriptState.firstNativeCommoditySale == nil
      && arrived.commander.scriptState.secondNativeCommoditySale == nil)
    let custody = arrived.commander.savedEMPState
    let people = arrived.commander.nativePeople
    let npcPersistence = arrived.commander.npcPersistence
    let alienState = arrived.commander.alienStorageState?.current.snapshot
    let index = try #require(arrived.market.indices.first {
      Commodity.all[$0].unit == "t" && arrived.market[$0].quantity >= 2
        && arrived.market[$0].price > 0 && arrived.market[$0].price <= arrived.commander.availableCredits / 2
        && arrived.commander.cargo[$0] == 0
    })
    await runtime.chooseSecondSaleTestCommodity(index)
    await runtime.key("right")
    await runtime.key("right")
    await runtime.key("left")
    let beforeSale = await runtime.snapshot()
    let first = try #require(beforeSale.commander.scriptState.firstNativeCommoditySale)
    try #require(beforeSale.commander.cargo[index] == 1
      && beforeSale.commander.scriptState.secondNativeCommoditySale == nil)
    let backup = storage.directory.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    let originalFiles = try secondSaleTestFiles(storage.directory)
    try FileManager.default.moveItem(at: storage.directory, to: backup)
    try Data("blocked combined publication".utf8).write(to: storage.directory)
    defer {
      if FileManager.default.fileExists(atPath: backup.path) {
        try? FileManager.default.removeItem(at: storage.directory)
        try? FileManager.default.moveItem(at: backup, to: storage.directory)
      }
    }
    await runtime.key("left")
    let failed = await runtime.snapshot()
    #expect(failed.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    #expect(failed.commander == beforeSale.commander && failed.market == beforeSale.market)
    #expect(failed.scriptWorldSave == beforeSale.scriptWorldSave)
    #expect(failed.commander.savedBisonUnitAllocations == journal)
    #expect(try secondSaleTestFiles(backup) == originalFiles)
    #expect(try Data(contentsOf: storage.directory) == Data("blocked combined publication".utf8))
    try FileManager.default.removeItem(at: storage.directory)
    try FileManager.default.moveItem(at: backup, to: storage.directory)
    await runtime.key("left")
    await runtime.nativeCommand { $0.screen = .status }
    try await runtime.save(to: storage.url)
    let saved = await runtime.snapshot()
    let second = try #require(saved.commander.scriptState.secondNativeCommoditySale)
    #expect(second.valid(after: first) && second.sale.operation != first.operation)
    #expect(saved.commander.cargo[index] == 0)
    #expect(saved.market[index].quantity == beforeSale.market[index].quantity + 1)
    #expect(saved.commander.credits == beforeSale.commander.credits + beforeSale.market[index].bidPrice)
    #expect(saved.commander.savedBisonUnitAllocations == journal)
    #expect(saved.commander.savedEMPState == custody && saved.commander.nativePeople == people)
    #expect(saved.commander.npcPersistence == npcPersistence)
    #expect(saved.commander.alienStorageState?.current.snapshot == alienState)
    let pointerBytes = try Data(contentsOf: storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let checkpoint = try #require(pointer.bisonUnitJournalCheckpoint)
    #expect(pointer.schemaVersion == (alien
      ? NativeSecondCommoditySaleSave.alienVersion : NativeSecondCommoditySaleSave.version))
    #expect(pointer.hashes.count == (alien ? 5 : 4))
    let (stored, world) = try ScriptSaveStore.read(pointerBytes, from: storage.url)
    let expectedWorld = try BisonUnitJournalSave.preparedWorld(saved.scriptWorldSave, commander: saved.commander)
    #expect(stored == saved.commander && world == expectedWorld)
    #expect(world.bisonUnitJournalCheckpoint == checkpoint && world.consistent(with: stored))
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.commander == saved.commander && loaded.scriptWorldSave == saved.scriptWorldSave)
    let loadedJournal = try #require(loaded.commander.savedBisonUnitAllocations)
    let retained = try loadedJournal.owner(for: request, in: loaded)
    #expect(retained == owner && loadedJournal == journal)
    #expect(!loaded.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(loaded.commander.scriptState.secondNativeCommoditySale == second)
    #expect(loaded.commander.savedEMPState == custody && loaded.commander.npcPersistence == npcPersistence)
    #expect(loaded.commander.nativePeople == people && loaded.commander.alienStorageState?.current.snapshot == alienState)
    #expect(CurrentNewtKitSave.hasClaims(loaded.commander) && !bison.sourceQualifiedForBirth)

    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: storage.url)
    // Keep the other owner's markers and schema intact in each attack, so a
    // failure cannot be credited to accidentally stripping the unrelated join.
    for chunk in ["world.json", "missions.json"] {
      let url = generation.appendingPathComponent(chunk)
      let original = try Data(contentsOf: url)
      defer {
        try? original.write(to: url, options: .atomic)
        try? pointerBytes.write(to: storage.url, options: .atomic)
      }
      let decoded = try JSONSerialization.jsonObject(with: original)
      var object = try #require(decoded as? [String: Any])
      // Re-encoding alone must preserve the valid combined archive.
      func publish(_ data: Data) throws -> Data {
        var hashes = pointer.hashes
        hashes[chunk] = ScriptPackLibrary.hash(data)
        let changed = ScriptSavePointer(format: pointer.format, schemaVersion: pointer.schemaVersion,
          generation: pointer.generation, hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec,
          bisonUnitJournalCheckpoint: checkpoint)
        try data.write(to: url, options: .atomic)
        let bytes = try JSONEncoder().encode(changed)
        try bytes.write(to: storage.url, options: .atomic)
        return bytes
      }
      let control = try publish(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
      let controlRead = try ScriptSaveStore.read(control, from: storage.url)
      #expect(controlRead.0 == saved.commander && controlRead.1 == world)
      if chunk == "world.json" {
        let removed = object.removeValue(forKey: BisonUnitJournalSave.checkpointField)
        try #require(removed != nil)
      } else {
        var sale = try #require(object[NativeSecondCommoditySaleSave.field] as? [String: Any])
        sale["firstOperation"] = UUID().uuidString
        object[NativeSecondCommoditySaleSave.field] = sale
      }
      let corrupt = try publish(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
      let corruptFiles = try secondSaleTestFiles(storage.directory)
      #expect(throws: (any Error).self) { _ = try ScriptSaveStore.read(corrupt, from: storage.url) }
      var refused = false
      do { try await cold.load(from: storage.url, persistMigrations: false) } catch { refused = true }
      let after = await cold.snapshot()
      #expect(refused && after.commander == loaded.commander && after.scriptWorldSave == loaded.scriptWorldSave)
      #expect(after.nativeStationRuntimeEpoch == loaded.nativeStationRuntimeEpoch)
      #expect(try secondSaleTestFiles(storage.directory) == corruptFiles)
      try original.write(to: url, options: .atomic)
      try pointerBytes.write(to: storage.url, options: .atomic)
      let restored = try ScriptSaveStore.read(pointerBytes, from: storage.url)
      #expect(restored.0 == saved.commander && restored.1 == world)
    }
  }
}
