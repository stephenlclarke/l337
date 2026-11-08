import Foundation
import Testing

@testable import L337Core

/// Controlled current-source unit boundaries; actual native flight acceptance remains separate.
private func currentCatalogueGame() throws -> Game {
  var game = try empFixture(catalogue: "SH025")
  try fitEliteEMPTestEnergy(&game)
  let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
  let resources = try #require(game.bodies[0].physical?.npc?.resources)
  let stock = try #require(NPCResources.stock(source.performance))
  try #require(resources == stock && resources.electrical == nil)
  try #require(game.bodies[0].physical?.catalogueShipID == source.ship.id)
  try #require(game.empPulseEligible(game.bodies[0]) && game.commander.valid)
  return game
}

private func prepareCurrentCatalogueCharge(
  _ game: inout Game, publish: ScriptPublisher?, file: URL
) throws -> EMPChargeState {
  try earnEMPUnitBank(&game, publish: publish, file: file)
  try openEMPUnitHeader(&game, publish: publish)
  let fired = game.fireEMPPirateBlaster()
  try #require(fired)
  let charge = try #require(game.commander.savedEMPCharge)
  for _ in 0..<99 {
    try empUnitFrame(&game, controls: empUnitAim(game, actor: charge.target, fire: true),
      publish: publish)
  }
  try #require(game.commander.savedEMPCharge?.phase == .charging)
  return charge
}

private func currentCataloguePublisher(
  _ publish: @escaping ScriptPublisher, attempts: URL, successes: URL
) -> ScriptPublisher {
  return { candidate in
    let charge = candidate.commander.savedEMPCharge
    let pulse = charge?.phase == .released
      && candidate.currentEMPPlayerModule()?.empBank?.lastDischarge == charge
    if pulse {
      var bytes = (try? Data(contentsOf: attempts)) ?? Data()
      bytes.append(1)
      try bytes.write(to: attempts)
    }
    try publish(&candidate)
    if pulse {
      var bytes = (try? Data(contentsOf: successes)) ?? Data()
      bytes.append(1)
      try bytes.write(to: successes)
    }
  }
}

/// A nil-publisher copy supplies normal-frame motion only; the tested branch must really publish.
private func publishCurrentCatalogueFinalFrame(
  _ game: inout Game, charge: EMPChargeState, publish: ScriptPublisher?, file: URL
) throws -> Game {
  let publish = try #require(publish)
  let attempts = file.appendingPathExtension("pulse-attempts")
  let successes = file.appendingPathExtension("pulse-successes")
  let tracked = currentCataloguePublisher(publish, attempts: attempts, successes: successes)
  var reference = game
  try empUnitFrame(&reference,
    controls: empUnitAim(reference, actor: charge.target, fire: true), publish: nil, finish: false)
  let audio = game.dischargeAudio.events.count
  let module = try #require(game.currentEMPPlayerModule())
  let inventory = try #require(game.commander.equipmentInventory)
  let history = game.commander.equipmentPurchaseHistory
  let profile = try EMPPulseProfile.resolve(for: game.commander)
  try empUnitFrame(&game, controls: empUnitAim(game, actor: charge.target, fire: true),
    publish: tracked, finish: false)
  try #require(try Data(contentsOf: attempts).count == 1)
  try #require(try Data(contentsOf: successes).count == 1)
  let result = try #require(game.currentEMPPulseBeforeResult())
  try #require(result.charge.phase == .released && result.charge.target == charge.target)
  let target = try #require(game.bodies.first { $0.physical?.identity == charge.target })
  try expectEMPPrimaryLaw(result, body: target)
  let actual = try #require(target.physical?.npc?.resources?.electrical)
  let front = result.primary.contactOffset.dot(result.primary.modelForward) >= 0
  let oldShield = front ? result.primary.frontShield : result.primary.rearShield
  let newShield = front
    ? target.physical?.npc?.resources?.frontShield : target.physical?.npc?.resources?.rearShield
  try #require(actual.remaining < result.primary.electrical.remaining || newShield != oldShield)
  let afterModule = try #require(game.currentEMPPlayerModule())
  #expect(afterModule.empBank?.remaining == (module.empBank?.remaining ?? 0) - profile.energyCost)
  #expect(afterModule.empBank?.lastDischarge == result.charge)
  try expectEMPModuleProperty(module, afterModule)
  #expect(game.commander.equipmentInventory?.items.filter { $0.id != module.id }
    == inventory.items.filter { $0.id != module.id })
  #expect(game.commander.equipmentPurchaseHistory == history)
  #expect(game.dischargeAudio.events.count == audio + 1)
  let stored = try NativeSaveTestFixture.readVersionedCommander(from: file)
  #expect(stored.fittedEquipment(at: .utility(.empPirateBlaster)) == afterModule)
  #expect(stored.savedEMPState == game.commander.savedEMPState)
  return reference
}

@discardableResult
private func releaseCurrentCataloguePulse(_ game: inout Game) throws -> Game {
  try withEMPUnitWriter(&game) { scene, publish, file in
    let charge = try prepareCurrentCatalogueCharge(&scene, publish: publish, file: file)
    return try publishCurrentCatalogueFinalFrame(&scene, charge: charge, publish: publish, file: file)
  }
}

private func expectCurrentCatalogueRefusal(
  _ game: inout Game, arrange: ((inout Game) throws -> Void)? = nil,
  corrupt: (inout Game) throws -> Void
) throws {
  try withEMPUnitWriter(&game) { scene, publish, file in
    let publish = try #require(publish)
    let charge = try prepareCurrentCatalogueCharge(&scene, publish: publish, file: file)
    try arrange?(&scene)
    // Establish that this exact prepared target can publish before the selected corruption.
    var positive = scene
    try withEMPUnitWriter(&positive) { control, writer, destination in
      _ = try publishCurrentCatalogueFinalFrame(
        &control, charge: charge, publish: writer, file: destination)
    }
    try corrupt(&scene)
    var reference = scene
    try empUnitFrame(&reference,
      controls: empUnitAim(reference, actor: charge.target, fire: true), publish: nil, finish: false)
    let bytes = try Data(contentsOf: file)
    let files = try ScriptFinanceTestFixture.files(file.deletingLastPathComponent())
    let attempts = file.appendingPathExtension("pulse-attempts")
    let successes = file.appendingPathExtension("pulse-successes")
    let tracked = currentCataloguePublisher(publish, attempts: attempts, successes: successes)
    try empUnitFrame(&scene, controls: empUnitAim(scene, actor: charge.target, fire: true),
      publish: tracked, finish: false)
    #expect(!FileManager.default.fileExists(atPath: attempts.path))
    #expect(!FileManager.default.fileExists(atPath: successes.path))
    #expect(scene.commander == reference.commander && scene.bodies == reference.bodies)
    #expect(scene.time == reference.time && scene.gameplayRevision == reference.gameplayRevision)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    #expect(try encoder.encode(scene.scriptSimulationSave) == encoder.encode(reference.scriptSimulationSave))
    #expect(scene.dischargeAudio.epoch == reference.dischargeAudio.epoch
      && scene.dischargeAudio.events == reference.dischargeAudio.events)
    #expect(scene.energy == reference.energy && scene.laserHeat == reference.laserHeat)
    #expect(scene.commander.savedEMPState == nil && scene.currentEMPPulseBeforeResult() == nil)
    #expect(scene.commander.savedEMPCharge?.phase == .released)
    #expect(scene.message == "EMP RELEASE REFUSED - TARGET OR EQUIPMENT CHANGED")
    #expect(try Data(contentsOf: file) == bytes)
    #expect(try ScriptFinanceTestFixture.files(file.deletingLastPathComponent()) == files)
  }
}

struct EMPCurrentCatalogueReleaseTests {
  @Test func currentSourceKeepsItsPartialMeshAndExplicitIdentityThroughActualZero() throws {
    var game = try currentCatalogueGame()
    let actor = try #require(game.bodies[0].physical?.identity)
    let originalMesh = game.gameplayMesh(for: game.bodies[0])
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let crew = try ShipAccommodationProfile(ship: source.ship).operatingCrew
    let reference = try releaseCurrentCataloguePulse(&game)
    let original = try #require(reference.bodies.first { $0.physical?.identity == actor })
    let partial = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(partial.physical?.identity == actor && partial.hull == original.hull)
    #expect(partial.energy == original.energy && partial.physical?.catalogueShipID == source.ship.id)
    #expect(partial.position == original.position && partial.orientation == original.orientation)
    #expect(partial.rotation == original.rotation && partial.rotationRate == original.rotationRate)
    #expect(partial.physical?.velocity == original.physical?.velocity)
    #expect(partial.physical?.angularVelocity == original.physical?.angularVelocity)
    let partialMesh = game.gameplayMesh(for: partial)
    #expect(partialMesh.vertices == originalMesh.vertices && partialMesh.faces == originalMesh.faces)
    #expect(partialMesh.details.map { [$0.start, $0.end, $0.face] }
      == originalMesh.details.map { [$0.start, $0.end, $0.face] })
    #expect(partialMesh.materials.map(\.name) == originalMesh.materials.map(\.name))
    #expect(partialMesh.materials.map(\.colour) == originalMesh.materials.map(\.colour))
    #expect(partialMesh.materials.map(\.emissive) == originalMesh.materials.map(\.emissive))
    #expect(partialMesh.faceMaterials == originalMesh.faceMaterials)
    try #require((partial.physical?.npc?.resources?.electrical?.remaining ?? 0) > 0)
    #expect(partial.physical?.npc?.ordinaryCargo == original.physical?.npc?.ordinaryCargo)
    #expect(game.commander.savedEMPState == nil)
    game.advanceEMPCharge(triggerHeld: false)
    try withEMPUnitWriter(&game) { scene, publish, file in
      let publish = try #require(publish)
      scene.finishEMPPlayerElectricalInterval(publish: publish)
      try earnEMPUnitBank(&scene, publish: publish, file: file)
      scene.finishEMPPlayerElectricalInterval(publish: publish)
      for _ in 0..<256 {
        if scene.fireCooldown <= 0 { break }
        try empUnitFrame(&scene, controls: empUnitAim(scene, actor: actor), publish: publish)
      }
      try #require(scene.fireCooldown <= 0)
      let profile = try EMPPulseProfile.resolve(for: scene.commander)
      try #require((scene.currentEMPPlayerModule()?.empBank?.remaining ?? 0) >= profile.energyCost)
    }
    try #require(try releaseDamagedEMPBoundary(&game))
    let disabled = try #require(game.bodies.first { $0.physical?.identity == actor })
    let key = try #require(disabled.physical?.empSource)
    let record = try #require(game.commander.savedEMPState?.records[key])
    #expect(key == actor && record.originalBodyID == original.id)
    #expect(record.custody.original.body.physical?.catalogueShipID == source.ship.id)
    #expect(record.custody.traffic?.catalogueShipID == source.ship.id)
    #expect(record.custody.valid && record.valid && game.commander.valid)
    #expect(record.hull.body.energy == record.custody.original.body.energy)
    #expect(record.cargo == record.custody.original.body.physical?.npc?.ordinaryCargo)
    #expect(record.legal == record.custody.original.body.physical?.npc?.legal)
    #expect(record.crewTotal == crew && record.crewAboard == crew)
    #expect(record.hull.body.physical?.npc?.resources?.electrical?.remaining == 0)
    #expect(record.disableIncident.physicalTime == game.commander.flightSimulation.physicalTime)
  }

  @Test func currentSpentReserveSurvivesStrictSaveAndCanReachActualZero() async throws {
    var game = try currentCatalogueGame()
    let actor = try #require(game.bodies[0].physical?.identity)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let crew = try ShipAccommodationProfile(ship: source.ship).operatingCrew
    let profile = try EMPPulseProfile.resolve(for: game.commander)
    let coldSeed = game
    var resources = try #require(game.bodies[0].physical?.npc?.resources)
    var reserve = try #require(ElectricalReserve(capacity: resources.energyCapacity,
      recharge: resources.energyRecharge, at: game.commander.flightSimulation.physicalTime))
    let spent = profile.power / 4
    try #require(spent > 0 && spent < resources.energyCapacity)
    let drained = reserve.drain(resources.energyCapacity - spent, at: reserve.physicalTime)
    try #require(drained)
    resources.electrical = reserve
    resources.frontShield = 0
    resources.rearShield = 0
    game.bodies[0].physical?.npc?.resources = resources
    try #require(game.persistNPCStates().isEmpty && game.commander.valid)
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    try GameRuntime.writeCommander(&game, to: storage.url)
    let bytes = try Data(contentsOf: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.url.deletingLastPathComponent())
    let (stored, world) = try ScriptSaveStore.read(bytes, from: storage.url)
    #expect(stored.npcPersistence.snapshot(for: actor)?.catalogueShipID == source.ship.id)
    #expect(stored.npcPersistence.snapshot(for: actor)?.npc.resources?.electrical == reserve)
    #expect(world.bodies.first { $0.physical?.identity == actor }?.physical?.catalogueShipID == source.ship.id)
    try #require(coldSeed.bodies[0].physical?.npc?.resources != resources)
    let runtime = GameRuntime(game: coldSeed)
    try await runtime.load(from: storage.url, persistMigrations: false)
    var loaded = await runtime.snapshot()
    let retained = try #require(loaded.bodies.first { $0.physical?.identity == actor })
    try #require(retained.physical?.npc?.resources == resources)
    let reference = try releaseCurrentCataloguePulse(&loaded)
    let normal = try #require(reference.bodies.first { $0.physical?.identity == actor })
    let key = try #require(loaded.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let record = try #require(loaded.commander.savedEMPState?.records[key])
    #expect(key == actor && record.valid && record.custody.valid && loaded.commander.valid)
    #expect(record.custody.original.body.physical?.catalogueShipID == source.ship.id)
    #expect(record.custody.traffic?.catalogueShipID == source.ship.id)
    #expect(record.hull.body.energy == normal.energy && record.cargo == normal.physical?.npc?.ordinaryCargo)
    #expect(record.crewTotal == crew && record.crewAboard == crew)
    #expect(try Data(contentsOf: storage.url) == bytes)
    #expect(try ScriptFinanceTestFixture.files(storage.url.deletingLastPathComponent()) == files)
  }

  @Test(arguments: [false, true])
  func unknownCatalogueOrChangedProfileCannotPublishIdentityOrPulse(invalidProfile: Bool) throws {
    var game = try currentCatalogueGame()
    try expectCurrentCatalogueRefusal(&game) { scene in
      if invalidProfile {
        let capacity = try #require(scene.bodies[0].physical?.npc?.resources?.energyCapacity)
        scene.bodies[0].physical?.npc?.resources = try #require(
          NPCResources.legacyEnergyOnly(maximumEnergy: capacity))
      } else {
        scene.bodies[0].physical?.catalogueShipID = "UNKNOWN-EMP-CATALOGUE"
      }
    }
    #expect(game.bodies[0].physical?.catalogueShipID
      == (invalidProfile ? "SH025" : "UNKNOWN-EMP-CATALOGUE"))
  }

  @Test func lateUnrelatedCaptureRefusalRollsBackWholeCurrentPulse() throws {
    var game = try currentCatalogueGame()
    let actor = try #require(game.bodies[0].physical?.identity)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    try expectCurrentCatalogueRefusal(&game, arrange: { scene in
      var resources = try #require(scene.bodies[0].physical?.npc?.resources)
      let now = scene.commander.flightSimulation.physicalTime
      var reserve = try #require(ElectricalReserve(capacity: resources.energyCapacity,
        recharge: resources.energyRecharge, at: now))
      let drained = reserve.drain(resources.energyCapacity - 5, at: now)
      try #require(drained)
      resources.frontShield = 0
      resources.rearShield = 0
      resources.electrical = reserve
      scene.bodies[0].physical?.npc?.resources = resources
    }) { scene in
      scene.bodies.append(.init(id: 99, hull: .cobra, position: .init(4000, 1000, 9000)))
      scene.nextBodyID = 100
      scene.ensurePhysicalActors()
      let bad = try #require(scene.bodies.firstIndex { $0.id == 99 })
      scene.bodies[bad].physical?.catalogueShipID = source.ship.id
      scene.bodies[bad].physical?.npc?.resources = try #require(NPCResources.stock(source.performance))
      scene.bodies[bad].energy = source.performance.energy * 2
    }
    #expect(game.bodies[0].physical?.catalogueShipID == source.ship.id)
    game.bodies.removeAll { $0.id == 99 }
    game.advanceEMPCharge(triggerHeld: false)
    _ = try releaseCurrentCataloguePulse(&game)
    let target = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(target.physical?.empSource != nil)
    #expect(target.physical?.catalogueShipID == source.ship.id)
    let discharges = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }
    #expect(discharges.count == 1 && discharges.first?.id == 1)
  }
}
