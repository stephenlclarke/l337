import Darwin
import Foundation
import Testing

@testable import L337Core

struct NativeStationIntegrationTests {
  @Test func physicalTestStorageSupportsNativePagesAndWriterRecovery() throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let snapshot = AlienStorageTestFixture().snapshot
    let reference = try AlienStoragePageStore.write(
      snapshot: snapshot, previous: nil, to: storage.directory)
    let root = try Data(contentsOf: storage.directory.appendingPathComponent("alien-root.json"))
    try storage.blockWriter()
    #expect(throws: (any Error).self) {
      try AlienStoragePageStore.read(
        reference: reference, expectedOwner: snapshot.owner, from: storage.directory)
    }
    #expect(try Data(contentsOf: storage.backup.appendingPathComponent("alien-root.json")) == root)
    try storage.restoreWriter()
    let restored = try AlienStoragePageStore.read(
      reference: reference, expectedOwner: snapshot.owner, from: storage.directory)
    #expect(restored == snapshot)
    let retry = try AlienStoragePageStore.write(
      snapshot: snapshot, previous: snapshot, to: storage.directory)
    #expect(retry == reference)
  }

  @Test func compiledOriginalStationBindingsMatchFourClosedSites() throws {
    let bindings = try NativeStationSource.requireBindings()
    let sites: [OriginalStationSite] = [.salamander, .frog, .dhole, .remoteUtility]
    #expect(bindings.count == 4 && Set(bindings.map(\.site)) == Set(sites))
    #expect(bindings.filter { $0.system == .init(galaxy: 0, system: 7) }.map(\.site) == [.salamander, .frog, .dhole])
    #expect(bindings.filter { $0.system == .init(galaxy: 0, system: 237) }.map(\.site) == [.remoteUtility])
    for source in bindings {
      #expect(source.descriptor.boardOrigin == .authored)
      #expect(source.rotationRate == 0 && source.recharge == 0)
      #expect(source.physical.dryMassKilograms == (source.site == .salamander ? 2_000_000 : 12_000_000))
      #expect(source.maximumEnergy == (source.site == .salamander ? 2000 : 5000))
      #expect(source.descriptor.capabilities == (source.site == .remoteUtility ? [] : [.sealedDispatchBoard]))
      #expect(source.catalogueShipID == source.site.catalogueID)
      #expect(source.key == source.site.key)
    }
    let dhole = try #require(bindings.first { $0.site == .dhole })
    let remote = try #require(bindings.first { $0.site == .remoteUtility })
    #expect(dhole.physical == remote.physical && dhole.geometry.mesh.vertices == remote.geometry.mesh.vertices)
    #expect(dhole.key != remote.key && dhole.system != remote.system)
    #expect(!bindings.contains { $0.system.system == Plugh.systemID })
  }

  @Test func nativeStationWorldRetainsChosenPosesWithoutMintingDockingAuthority() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    let expected = Set(OriginalStationSite.allCases.map { $0.identity(world: owner) })
    #expect(world.valid && world.ledger.world == owner && world.ledger.records.count == 4)
    #expect(Set(world.ledger.records.map(\.identity)) == expected && Set(world.poses.map(\.station)) == expected)
    #expect(world.ledger.currentDock == nil && world.ledger.nextDockSequence == 1)
    #expect(world.ledger.records.allSatisfy { $0.binding == nil && $0.tombstone == nil && $0.utilitySourceBirth == nil })
    let bytes = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    #expect(loaded == world)
    for site in OriginalStationSite.allCases {
      let pose = try #require(world.pose(for: site.identity(world: owner)))
      #expect(pose.orientation == loaded.pose(for: pose.station)?.orientation)
      #expect(pose.orientation == Basis3() && pose.orientation(at: 0) == pose.orientation(at: 12_345))
      #expect(pose.orientation(at: .nan) == nil)
    }
  }

  @Test func savedDescriptorsAndAlteredPosesCannotReplaceTheCompiledSourceBinding() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    let record = try #require(world.ledger.records.first)
    #expect(NativeStationSource.authentic(record, owner: owner))
    #expect(!NativeStationSource.authentic(record, owner: UUID()))
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    var poses = try #require(object["poses"] as? [[String: Any]])
    var position = try #require(poses[0]["position"] as? [String: Any])
    position["x"] = (try #require(position["x"] as? Double)) + 1
    poses[0]["position"] = position
    object["poses"] = poses
    let forged = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: forged)
    }
    object["poses"] = Array(repeating: poses[0], count: 5)
    let oversized = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: oversized)
    }
  }

  @Test func stationBoardHourUsesOnlyTheExplicitNativePersistentCalendar() {
    #expect(NativeStationSource.boardHour(calendarSeconds: 0) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3599.9) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3600) == 1)
    #expect(NativeStationSource.boardHour(calendarSeconds: 7201) == 2)
    #expect(NativeStationSource.boardHour(calendarSeconds: -1) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .infinity) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .nan) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .greatestFiniteMagnitude) == nil)
  }

  @Test func actualPopulationKeepsOriginalMainAndCompleteCurrentSiteCohort() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyNativePopulation(&game)
  }

  @Test func populationCapacityRefusalDoesNotAllocateOrPublishPartialStations() throws {
    var game = Game(executive: false)
    try verifyNativePopulationCapacity(&game)
  }

  @Test func actualWeaponRayIntersectsTheSourceStructureOutsideTheOriginalStationMesh() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyNativeStationWeaponMesh(&game)
  }

  @Test func originalMainStationRetainsItsNativeLaserImmunity() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyOriginalMainImmunity(&game)
  }

  @Test(arguments: OriginalStationSite.allCases)
  func actualXYZZYMissileVolleyDestroysOriginalSiteAndRetainsItsTombstoneAcrossLoad(site: OriginalStationSite)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.originalSiteAttack(site: site)
    try await verifyNativeOriginalDestruction(&game, site: site, storage: storage)
  }

  @Test(arguments: [false, true])
  func actualWeaponDamageNeverRechargesDuringManualAndGuidedPhysicalMovement(guided: Bool)
    throws
  {
    var game = try NativeStationTestFixture.originalSiteAttack(site: .dhole)
    try verifyNativeStationNoRecharge(&game, guided: guided)
  }

  @Test(arguments: OriginalStationSite.allCases)
  func actualNativeEntryCommitsSelectedStationAndLaunchesFromItsOwnExit(
    site: OriginalStationSite
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(site: site)
    try await verifyNativeEntryAndExit(&game, site: site, storage: storage)
  }

  @Test(arguments: ["speed", "facing", "aperture", "nonfinite", "stationPose"])
  func unsafeActualApproachCannotIssueADockingReceipt(reason: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(site: .dhole)
    try await verifyUnsafeNativeApproach(&game, reason: reason, storage: storage)
  }

  @Test func booleanDockAndPureLedgerReceiptCannotMintNativeServiceEvidence() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyUnprovedDocking(&game)
  }

  @Test(arguments: [0.1, 0.01, 0.001])
  func originalMainArrivalRequiresItsActualNativeDoorwayCrossing(delta: Double) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyOriginalMainArrival(&game, storage: storage, delta: delta)
  }
}

/// Shared fixture setup preserves every body's system position and model orientation.
/// Tests still cross the actual doorway through GameRuntime.advance; setup mints no receipt.
enum NativeStationTestFixture {
  static func launched(
    system: SystemIdentity = .init(galaxy: 0, system: 7), withDockingComputer: Bool = false
  ) throws -> Game {
    var game = Game(executive: false)
    game.commander.galaxy = system.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: system.galaxy)
    try game.commander.prepareEquipment(legacy: false)
    if withDockingComputer {
      let shop = try #require(game.systems.first { !$0.isPlugh && $0.technology >= TargetingTier.docking.technology })
      game.commander.system = shop.id
      game.commander.credits = 1_000_000
      game.screen = .equipment
      let originalLimits = game.workLimits
      let originalHull = game.commander.shipID
      let originalCargo = game.commander.cargo
      for tier in TargetingTier.allCases where tier <= .docking {
        let device = try #require(Equipment.all.first { $0.name == tier.equipmentName })
        let quote = try game.quoteEquipmentPurchase(device)
        let before = game.commander.credits
        let applied = try game.applyEquipmentPurchase(quote)
        try #require(applied)
        #expect(game.commander.credits == before - quote.purchase.requiredDebit)
        #expect(game.commander.targetingTier == tier)
      }
      try #require(game.commander.hasAutomaticDocking && game.commander.valid)
      #expect(game.workLimits == originalLimits && game.commander.shipID == originalHull)
      #expect(game.commander.cargo == originalCargo)
    }
    game.commander.system = system.system
    game.selectedSystem = system.system
    game.screen = .status
    game.launch()
    try #require(!game.docked, Comment(rawValue: game.message))
    try #require(game.commander.valid && game.commander.nativeStationStateValid)
    let owner = try #require(game.commander.equipmentOwnerID)
    let sites = OriginalStationSite.allCases.filter { $0.system == system }
    let expected = Set(sites.map { $0.identity(world: owner) })
    let sources = try NativeStationSource.requireBindings().filter { $0.system == system }
    try #require(Set(sources.map(\.site)) == Set(sites))
    let actual = game.bodies.filter { $0.nativeStationIdentity != nil }
    try #require(actual.count == expected.count && Set(actual.compactMap(\.nativeStationIdentity)) == expected)
    try #require(actual.allSatisfy { game.nativeStationBodyIsCurrent($0) })
    return game
  }

  static func approach(site: OriginalStationSite) throws -> Game {
    var game = try launched(system: site.system)
    let world = try #require(game.commander.nativeStations)
    let identity = site.identity(world: world.ledger.world)
    let source = try #require(NativeStationSource.binding(for: identity))
    let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
    try #require(game.nativeStationBodyIsCurrent(body) && source.geometry.docking.fits(game.commander.playerMesh))
    let time = game.commander.flightSimulation.physicalTime
    let position = try #require(world.currentPosition(for: .originalStation(identity), at: time))
    let orientation = try #require(world.currentOrientation(for: identity, at: time))
    let port = source.geometry.docking
    var pose = ShipPose()
    pose.position = position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    reframe(&game, to: pose)
    game.speed = 2
    return game
  }

  static func originalSiteAttack(site: OriginalStationSite) throws -> Game {
    var game = try launched(system: site.system)
    game.enableXYZzy()
    game.secretKey("b")
    game.secretKey("e")
    try #require(game.commander.xyzzyActive && game.commander.unlimitedMissiles)
    let world = try #require(game.commander.nativeStations)
    let identity = site.identity(world: world.ledger.world)
    let source = try #require(NativeStationSource.binding(for: identity))
    let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
    try #require(game.nativeStationBodyIsCurrent(body))
    let time = game.commander.flightSimulation.physicalTime
    let position = try #require(world.currentPosition(for: .originalStation(identity), at: time))
    let orientation = try #require(world.currentOrientation(for: identity, at: time))
    let anchors = try #require(game.commander.flightSimulation.anchors)
    let radial = (position - anchors.station.position).unit
    let surfaces = source.geometry.mesh.faces.compactMap { face -> (center: Vector3, normal: Vector3)? in
      guard face.count >= 3 else { return nil }
      let points = face.map { source.geometry.mesh.vertices[$0] }
      let center = points.reduce(Vector3(0, 0, 0), +) * (1 / Double(points.count))
      let normal = (points[1] - points[0]).cross(points[2] - points[0]).unit
      guard normal.finite, normal.length > 0, orientation.apply(normal).dot(radial) > 0 else { return nil }
      return (center, normal)
    }
    let surface = try #require(surfaces.max {
      orientation.apply($0.center).dot(radial) < orientation.apply($1.center).dot(radial)
    })
    let outward = orientation.apply(surface.normal)
    let radius = try #require(game.commander.playerMesh.vertices.map(\.length).max())
    let separation = 5000.0
    try #require(radius.isFinite && separation > radius)
    var pose = ShipPose()
    pose.position = position + orientation.apply(surface.center) + outward * separation
    pose.orientation.z = outward * -1
    let up = abs(pose.orientation.z.y) < 0.9 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    pose.orientation.y = (up - pose.orientation.z * up.dot(pose.orientation.z)).unit
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    try #require(pose.orientation.validRotation && pose.position.finite)
    // Original sites remain at their real locations. No security range or actor is changed.
    for other in game.bodies where other.energy > 0 {
      let otherRadius = try #require(game.gameplayMesh(for: other).vertices.map(\.length).max())
      let point = game.commander.flightSimulation.pose.systemPoint(other.position)
      try #require((pose.position - point).length > radius + otherRadius + 8)
    }
    for celestial in [anchors.planet, anchors.sun] {
      try #require((pose.position - celestial.position).length > radius + celestial.radius + 8)
    }
    reframe(&game, to: pose)
    game.speed = 0
    return game
  }

  static func reframe(_ game: inout Game, to pose: ShipPose) {
    let previous = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      let point = previous.systemPoint(game.bodies[index].position)
      let orientation = game.bodies[index].orientation.transformed(by: previous.orientation)
      game.bodies[index].position = pose.shipPoint(point)
      game.bodies[index].orientation = orientation.relative(to: pose.orientation)
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        previous.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
  }
}

struct NativeStationTestStorage {
  let root: URL
  var directory: URL { root.appendingPathComponent("save", isDirectory: true) }
  var url: URL { directory.appendingPathComponent("commander.json") }
  var backup: URL { root.appendingPathComponent("backup", isDirectory: true) }
  // The caller owns cleanup of this already isolated physical fixture directory.
  init(root: URL) { self.root = root }

  init() throws {
    // Page storage rejects linked ancestors, including the macOS /var temporary alias.
    let temporary = FileManager.default.temporaryDirectory.path
    let resolved = temporary.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    root = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent("native-station-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }
  func blockWriter() throws {
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked save directory".utf8).write(to: directory)
  }
  func restoreWriter() throws {
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

private func verifyNativePopulation(_ game: inout Game) throws {
  let world = try #require(game.commander.nativeStations)
  let main = try #require(game.bodies.first { $0.id == 0 })
  #expect(main.nativeStationIdentity == nil && main.hull == .station)
  #expect(main.physical?.identity == game.commander.flightSimulation.anchors?.station.identity)
  #expect(main.physical?.identity.entity == 1)
  let sites: [OriginalStationSite] = [.salamander, .frog, .dhole]
  let expected = Set(sites.map { $0.identity(world: world.ledger.world) })
  let stations = game.bodies.filter { $0.nativeStationIdentity != nil }
  #expect(stations.count == 3 && Set(stations.compactMap(\.nativeStationIdentity)) == expected)
  #expect(Set(stations.compactMap { $0.physical?.identity }).count == 3)
  for station in stations {
    let identity = try #require(station.nativeStationIdentity)
    let source = try #require(NativeStationSource.binding(for: identity))
    #expect(identity.world == game.commander.equipmentOwnerID)
    #expect(game.nativeStationBodyIsCurrent(station))
    #expect(station.energy == source.maximumEnergy && station.rotationRate == 0 && !station.ecmEnabled)
    #expect(station.physical?.catalogueShipID == source.catalogueShipID)
    #expect(game.gameplayMesh(for: station).vertices == source.geometry.mesh.vertices)
    let point = try #require(world.currentPosition(for: .originalStation(identity), at: game.commander.flightSimulation.physicalTime))
    #expect((game.commander.flightSimulation.pose.systemPoint(station.position) - point).length < 1e-8)
  }
  let commander = game.commander
  let bodies = game.bodies
  let nextBodyID = game.nextBodyID
  try game.populateNativeStations()
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == nextBodyID)
  #expect(world.ledger.currentDock == nil && world.currentMainDock == nil)
  #expect(world.ledger.records.count == 4 && world.mainStations.count == 1)
}

private func verifyNativePopulationCapacity(_ game: inout Game) throws {
  game.commander.system = 237
  try game.activateNativeStationWorld()
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  game.docked = false
  game.bodies = (0..<128).map {
    SpaceBody(id: $0 + 100, hull: .asteroid, position: .init(Double($0) * 1000, 100000, 100000))
  }
  game.nextBodyID = 228
  game.ensurePhysicalActors()
  #expect(game.bodies.allSatisfy { $0.physical != nil })
  let commander = game.commander
  let bodies = game.bodies
  let cursor = game.nextBodyID
  #expect(throws: NativeStationRuntimeError.capacity) { try game.populateNativeStations() }
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == cursor)
  #expect(game.commander.nativeStations?.ledger.records.allSatisfy { $0.binding == nil } == true)
}

private func verifyNativeStationWeaponMesh(_ game: inout Game) throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  let identity = OriginalStationSite.salamander.identity(world: owner)
  let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
  let source = try #require(NativeStationSource.binding(for: identity))
  let mesh = source.geometry.mesh
  let face = try #require(mesh.faces.first)
  let points = face.map { mesh.vertices[$0] }
  let center = points.reduce(Vector3(0, 0, 0), +) * (1 / Double(points.count))
  let outward = (points[1] - points[0]).cross(points[2] - points[0]).unit
  let main = try #require(game.bodies.first { $0.id == 0 })
  let mainRadius = try #require(game.gameplayMesh(for: main).vertices.map(\.length).max())
  #expect((body.position + body.modelVector(center) - main.position).length > mainRadius)
  try #require(outward.length > 0 && outward.finite)
  let origin = body.position + body.modelVector(center + outward * 1000)
  let direction = body.modelVector(outward * -1)
  let contact = try #require(
    try game.nearestMissionCollision(from: origin, direction: direction, range: 2000, radius: 0, includePlayer: false))
  #expect(contact.hit.target == .body(body.id))
  #expect(game.gameplayMeshOverrides[body.id]?.vertices == mesh.vertices)
  #expect(game.gameplayMesh(for: body).faces == mesh.faces)
}

private func verifyOriginalMainImmunity(_ game: inout Game) throws {
  game.enableXYZzy()
  var pose = ShipPose()
  pose.position = .init(0, 0, -1000)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 0
  let main = try #require(game.bodies.first { $0.id == 0 })
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      includePlayer: false))
  #expect(contact.hit.target == .body(main.id))
  game.fireLaser()
  #expect(game.laserFlash > 0 && game.bodies.first { $0.id == 0 }?.energy == main.energy)
  for _ in 0..<16 where game.weaponsTargetID != main.id { game.key("tab") }
  #expect(game.weaponsTargetID == main.id)
  game.key("q")
  game.key("t")
  let flight = game.commander.flightSimulation
  let fired = game.fireMissile()
  #expect(!fired)
  #expect(game.commander.flightSimulation == flight)
}

private func verifyNativeStationNoRecharge(_ game: inout Game, guided: Bool) throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  let identity = OriginalStationSite.dhole.identity(world: owner)
  let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
  let actor = try #require(body.physical?.identity)
  let source = try #require(NativeStationSource.binding(for: identity))
  try #require(source.recharge == 0 && source.rotationRate == 0)
  game.fireLaser()
  let damaged = try #require(game.bodies.first { $0.id == body.id })
  #expect(damaged.energy == body.energy - LaserKind.naval.damage)
  if guided {
    for _ in 0...game.bodies.count where game.autoPilot.targetActor != actor { game.key("tab") }
    try #require(game.commander.hasAutomaticDocking && game.dockingComputer)
    try #require(game.autoPilot.targetActor == actor && game.autoPilot.targetID == body.id)
  }
  let clock = game.commander.flightSimulation.physicalTime
  game.tick(delta: 0.1)
  #expect(game.commander.flightSimulation.physicalTime == clock + 0.1)
  #expect(game.bodies.first { $0.id == body.id }?.energy == damaged.energy)
  #expect(!game.docked && !game.paused)
  if guided { #expect(game.autoPilot.targetActor == actor && game.lastAppliedWorkMotion != nil) }
}

private func verifyNativeOriginalDestruction(
  _ game: inout Game, site: OriginalStationSite, storage: NativeStationTestStorage
) async throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  let expectedIdentity = site.identity(world: owner)
  let hq = try #require(game.bodies.first { $0.nativeStationIdentity == expectedIdentity })
  let identity = try #require(hq.nativeStationIdentity)
  let actor = try #require(hq.physical?.identity)
  let source = try #require(NativeStationSource.binding(for: identity))
  #expect(hq.energy == source.maximumEnergy && source.recharge == 0 && !hq.ecmEnabled)
  #expect(game.commander.credits == Commander.xyzzyStartingCredits && !game.commander.unlimitedCash)
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      includePlayer: false))
  #expect(contact.hit.target == .body(hq.id))
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0...game.bodies.count where game.weaponsTargetID != hq.id {
    await runtime.key("tab")
    game = await runtime.snapshot()
  }
  #expect(game.weaponsTargetID == hq.id)
  await runtime.key("q")
  var controls = Controls()
  controls.fire = true
  await runtime.setControls(controls)
  game = await runtime.advance(delta: 0.1)
  #expect(game.bodies.first { $0.id == hq.id }?.energy == hq.energy - LaserKind.naval.damage)
  await runtime.setControls(Controls())
  var launches = 0
  // Keep the original bounded horizon; real missiles and source damage determine destruction.
  let beforeMissiles = try #require(game.bodies.first { $0.id == hq.id })
  try #require(beforeMissiles.energy > 0)
  for frame in 0..<6269
  where game.bodies.contains(where: { $0.id == hq.id })
    && game.screen != .gameOver && !game.paused
  {
    if frame % 11 == 0 {
      let cursor = game.commander.flightSimulation.nextSpawn
      await runtime.key("t")
      await runtime.key("m")
      game = await runtime.snapshot()
      if game.commander.flightSimulation.nextSpawn > cursor { launches += 1 }
    }
    game = await runtime.advance(delta: 0.1)
  }
  #expect(launches > 0 && !game.paused && game.screen != .gameOver)
  #expect(
    !game.bodies.contains { $0.nativeStationIdentity == identity },
    "Original station energy after \(launches) launches: \(String(describing: game.bodies.first { $0.nativeStationIdentity == identity }?.energy))"
  )
  let world = try #require(game.commander.nativeStations)
  let record = try #require(world.ledger.records.first { $0.identity == identity })
  let tombstone = try #require(record.tombstone)
  #expect(tombstone.destroyedBinding == .init(actor: actor, bodyID: hq.id))
  #expect(record.binding == nil && record.revision == 2)
  #expect(world.pose(for: identity)?.energy == 0 && world.ledger.currentDock == nil)
  try await runtime.save(to: storage.url)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk.nativeStations?.ledger.records.first { $0.identity == identity } == record)
  try await runtime.load(from: storage.url, persistMigrations: false)
  game = await runtime.advance(delta: 0.01)
  #expect(game.commander.nativeStations?.ledger.records.first { $0.identity == identity } == record)
  #expect(!game.bodies.contains { $0.nativeStationIdentity == identity })
  #expect(game.commander.nativeStations?.poses == disk.nativeStations?.poses)
  #expect(game.commander.nativeStationStateValid)
}

private func verifyNativeEntryAndExit(
  _ game: inout Game, site: OriginalStationSite, storage: NativeStationTestStorage
) async throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  let expectedIdentity = site.identity(world: owner)
  let station = try #require(game.bodies.first { $0.nativeStationIdentity == expectedIdentity })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(game.docked && !game.dockedAtMainStation && !game.paused)
  let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
  #expect(receipt.station == identity)
  #expect(receipt.dockingBinding == .init(actor: actor, bodyID: station.id))
  #expect(receipt.sequence == 1 && receipt.commanderOwner == identity.world)
  #expect(game.nativeStationDockEvidenceIsCurrent)
  #expect((game.nativeStationBoardContext != nil) == (site != .remoteUtility))
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk.nativeStations?.ledger.currentDock == receipt)
  let calendar = game.commander.scriptState.calendarSeconds
  await runtime.key("0")
  game = await runtime.snapshot()
  #expect(!game.docked && !game.paused)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 2)
  #expect(game.commander.scriptState.calendarSeconds == calendar + 600)
  let source = try #require(NativeStationSource.binding(for: identity))
  let saved = try #require(game.commander.nativeStations?.pose(for: identity))
  let orientation = try #require(
    saved.orientation(at: game.commander.flightSimulation.physicalTime))
  let exit = try #require(source.geometry.exit(for: game.commander.playerMesh))
  #expect(
    (game.commander.flightSimulation.pose.position
      - (saved.position + orientation.apply(exit.center))).length < 1e-8)
  #expect(game.nativeStationBoardContext == nil)
  #expect(game.bodies.first { $0.id == 0 }?.nativeStationIdentity == nil)
}

private func verifyUnsafeNativeApproach(
  _ game: inout Game, reason: String, storage: NativeStationTestStorage
) async throws {
  switch reason {
  case "speed": game.speed = 8
  case "facing":
    var pose = game.commander.flightSimulation.pose
    pose.orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    NativeStationTestFixture.reframe(&game, to: pose)
  case "aperture":
    var pose = game.commander.flightSimulation.pose
    let owner = try #require(game.commander.equipmentOwnerID)
    let identity = OriginalStationSite.dhole.identity(world: owner)
    let source = try #require(NativeStationSource.binding(for: identity))
    let extent = try #require(source.geometry.docking.aperture.map { abs($0.x) }.max())
    let player = try #require(game.commander.playerMesh.vertices.map { abs($0.x) }.max())
    pose.position = pose.position + pose.orientation.x * (extent + player + 1)
    NativeStationTestFixture.reframe(&game, to: pose)
  case "nonfinite": game.commander.flightSimulation.pose.position.x = .nan
  case "stationPose":
    let owner = try #require(game.commander.equipmentOwnerID)
    let identity = OriginalStationSite.dhole.identity(world: owner)
    let index = try #require(game.bodies.firstIndex { $0.nativeStationIdentity == identity })
    game.bodies[index].position.x += 300
  default: throw NativeStationRuntimeError.invalidState
  }
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(!game.docked)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 1)
  #expect(game.nativeStationBoardContext == nil && !game.nativeStationDockEvidenceIsCurrent)
}

private func verifyUnprovedDocking(_ game: inout Game) throws {
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let owner = game.commander.equipmentOwnerID
  game.dock(atMainStation: false)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  try game.commander.nativeStations?.ledger.recordDock(
    at: identity, binding: .init(actor: actor, bodyID: station.id),
    commanderOwner: owner)
  game.scriptDurabilityAvailable = true
  #expect(game.commander.nativeStationStateValid)
  #expect(game.nativeStationBoardContext == nil && game.nativeStationEventFacts == nil)
  game.invalidateNativeStationAuthority()
  #expect(game.nativeStationBoardContext == nil && !game.nativeStationDockEvidenceIsCurrent)
  let commander = game.commander
  game.launch()
  #expect(game.docked && game.commander == commander)
}

private func verifyOriginalMainArrival(
  _ game: inout Game, storage: NativeStationTestStorage, delta: Double
) async throws {
  let station = try #require(game.bodies.first { $0.id == 0 })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 3
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: delta) }
  #expect(game.docked && game.dockedAtMainStation)
  let receipt = try #require(game.commander.nativeStations?.currentMainDock)
  #expect(receipt.station.system == game.systemIdentity && receipt.actor.entity == 1)
  #expect(
    receipt.station.resource == Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.records.count == 4)
  #expect(game.nativeMainStationDockEvidenceIsCurrent)
  let context = try #require(game.nativeMainStationArrivalContext(for: receipt.station))
  #expect(game.acceptsNativeMainStationArrivalContext(context))
  game.invalidateNativeStationAuthority()
  #expect(!game.acceptsNativeMainStationArrivalContext(context))
}
