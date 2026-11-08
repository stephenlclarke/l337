import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

/// Controlled source/target scene initialization, not evidence of flying the quoted route.
/// Every successful service still crosses an actual main/original native docking boundary.
struct NativeUtilityRuntimeFixture {
  let flight: OriginalSealedDispatchFixture
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws { flight = try OriginalSealedDispatchFixture() }
  func source(escapeReady: Bool = false, combatReady: Bool = false) async throws -> GameRuntime {
    if !combatReady { return try await flight.runtime(escapeReady: escapeReady, defaults: true) }
    // A finite initial test reserve pays for the actual fitted weapon before the first launch.
    try #require(!escapeReady)
    let weapon = try #require(Equipment.all.first { $0.name == "Military Laser" })
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    try #require(weapon.price == 164000 && weapon.requiredTechnologyLevel == 14)
    game.commander.credits += weapon.price
    // Controlled initial Verasel shop. The subsequent trip to Avenor uses real native travel.
    game.commander.system = 69
    game.selectedSystem = 69
    game.market = MarketItem.at(game.currentSystem)
    try game.prepareG03FlightEquipment()
    let before = game.commander
    let history = try #require(before.equipmentPurchaseHistory)
    try #require(game.currentSystem.name == "Verasel" && game.currentSystem.technology == 16)
    try #require(game.equipmentAvailable(weapon) && !before.unlimitedCash && !before.unlimitedFuel)
    let quote = try game.quoteEquipmentPurchase(weapon)
    try #require(quote.purchase.requiredDebit == 164000 && quote.mount == .front)
    let fitted = try game.applyEquipmentPurchase(quote)
    let paid = try #require(game.commander.equipmentPurchaseHistory)
    try #require(fitted && game.commander.laser(on: .front) == .military)
    try #require(game.commander.fittedEquipment(at: .laser(.front))?.id == quote.request.newItem)
    try #require(paid.paid.count == history.paid.count + 1)
    try #require(paid.paid.last?.node == quote.request.offer.node)
    try #require(paid.paid.last?.binding.request == quote.request)
    try #require(game.commander.credits == before.credits - quote.purchase.requiredDebit)
    try #require(game.commander.credits == 14000 && game.commander.valid)
    game.scriptPacks = []
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    let errors = await runtime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    await runtime.key("0")
    try await flight.dock(runtime)
    let path = [69, 0, 185, 7]
    let reach = await runtime.snapshot().commander
    try #require(game.systems[69].distance(to: game.systems[0]) <= reach.maximumJumpDistance)
    for (a, b) in zip(path, path.dropFirst()) {
      try #require(game.systems[a].distance(to: game.systems[b]) <= reach.fullTankJumpDistance)
    }
    try await flight.travel(runtime, path: path)
    await runtime.procurementRefuel()
    let arrived = await runtime.snapshot()
    try #require(arrived.commander.system == 7 && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.commander.laser(on: .front) == .military && arrived.commander.valid)
    return runtime
  }
  private func launched(from before: consuming Game, system: Int) throws -> Game {
    var game = before
    if game.commander.system != system { try game.departOrdinarySimulation() }
    game.commander.nativeStations?.ledger.depart()
    game.commander.nativeStations?.currentMainDock = nil
    game.invalidateNativeStationAuthority()
    game.commander.system = system
    game.selectedSystem = system
    game.screen = .status
    game.docked = true
    game.dockedAtMainStation = true
    game.commander.fuel = game.commander.fuelCapacity
    game.launch()
    try #require(!game.docked && game.commander.valid)
    return game
  }
  func target(from runtime: GameRuntime) async throws -> GameRuntime {
    let site = OriginalStationSite.remoteUtility
    var game = try launched(from: await runtime.snapshot(), system: site.system.system)
    let utility = try #require(game.commander.nativeUtility)
    let owner = try #require(game.commander.equipmentOwnerID)
    try #require(utility.target == site.identity(world: owner))
    let world = try #require(game.commander.nativeStations)
    let record = try #require(world.ledger.records.first { $0.identity == utility.target })
    let birth = try #require(record.utilitySourceBirth)
    let engineer = try #require(game.commander.nativePeople?.utilityEngineer)
    try #require(engineer.registration.operation == birth.operation)
    try #require(engineer.registration.station == utility.target && engineer.casualty == nil)
    try #require(engineer.registration.binding == birth.binding && engineer.registration.spawn == birth.spawn)
    try #require(engineer.registration.physicalTime == birth.physicalTime)
    let source = try #require(NativeStationSource.binding(for: utility.target))
    try #require(source.site == site && NativeStationSource.authentic(record, owner: owner))
    let time = game.commander.flightSimulation.physicalTime
    let position = try #require(world.currentPosition(for: .originalStation(utility.target), at: time))
    let orientation = try #require(world.currentOrientation(for: utility.target, at: time))
    let body = try #require(game.bodies.first { $0.nativeStationIdentity == utility.target })
    try #require(body.energy > 0 && game.nativeStationBodyIsCurrent(body))
    let port = source.geometry.docking
    var pose = ShipPose()
    pose.position = position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 2
    let target = GameRuntime(game: game, saveURL: save)
    let arrived = await target.advance(delta: 0.1)
    try #require(arrived.docked && !arrived.dockedAtMainStation)
    try #require(arrived.nativeStationDockEvidenceIsCurrent && arrived.commander.valid)
    try #require(arrived.nativeUtilityServiceContext != nil)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: save)
    #expect(persisted.nativePeople?.utilityEngineer == arrived.commander.nativePeople?.utilityEngineer)
    let persistedBirth = persisted.nativeStations?.ledger.records.first {
      $0.identity == utility.target
    }?.utilitySourceBirth
    #expect(persistedBirth == birth)
    return target
  }
  func source(from runtime: GameRuntime) async throws -> GameRuntime {
    let game = try launched(from: await runtime.snapshot(), system: 7)
    let source = GameRuntime(game: game, saveURL: save)
    try await flight.dock(source)
    try #require(await source.snapshot().nativeMainStationDockEvidenceIsCurrent)
    return source
  }
  func reloaded(_ runtime: GameRuntime) async throws -> GameRuntime {
    let before = await runtime.snapshot().commander
    try await runtime.save(to: save)
    let saved = await runtime.snapshot()
    var expected = saved.commander
    #expect(expected.nativeUtility == before.nativeUtility)
    // Predict only documented live original scene-address replacement, before reading the save.
    // All logical property, original material, receipt and ordinary actor state stays exact.
    let stations = saved.bodies.indices.filter { saved.bodies[$0].nativeStationIdentity != nil }
    var expectedBodies = saved.bodies
    if !stations.isEmpty {
      var flight = expected.flightSimulation
      var world = try #require(expected.nativeStations)
      let allocatedSpawn = flight.allocateSpawn()
      let sequence = try #require(allocatedSpawn)
      for (member, index) in stations.enumerated() {
        var body = saved.bodies[index]
        let station = try #require(body.nativeStationIdentity)
        let physical = try #require(body.physical)
        let allocatedActor = flight.allocateActor()
        let actor = try #require(allocatedActor)
        body.id = saved.nextBodyID + member
        body.physical = .init(
          identity: actor, population: physical.population, npc: physical.npc,
          velocity: physical.velocity, laserCooldown: physical.laserCooldown,
          rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
          emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
          deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
          spawnIdentity: .init(
            system: saved.systemIdentity, visit: flight.visit,
            sequence: sequence, member: UInt16(member), producer: .mission),
          blocksNavalEncounter: physical.blocksNavalEncounter,
          catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
          empSource: physical.empSource, empCrewPod: physical.empCrewPod,
          suspendedNPCIntention: physical.suspendedNPCIntention)
        expectedBodies[index] = body
        try world.ledger.rebind(station, to: .init(actor: actor, bodyID: body.id))
      }
      expected.flightSimulation = flight
      expected.nativeStations = world
    }
    let loaded = GameRuntime()
    let errors = await loaded.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    try await loaded.load(from: save, persistMigrations: false)
    let restored = await loaded.snapshot()
    #expect(restored.commander == expected)
    #expect(restored.commander.nativePeople?.utilityEngineer == saved.commander.nativePeople?.utilityEngineer)
    let target = try #require(saved.commander.nativeUtility?.target)
    let birth = saved.commander.nativeStations?.ledger.records.first { $0.identity == target }?.utilitySourceBirth
    let restoredBirth = restored.commander.nativeStations?.ledger.records.first {
      $0.identity == target
    }?.utilitySourceBirth
    #expect(restoredBirth == birth)
    if !stations.isEmpty {
      #expect(restored.bodies == expectedBodies)
      #expect(restored.nextBodyID == saved.nextBodyID + stations.count)
    }
    return loaded
  }
  func recharge(
    _ input: consuming Game, expected: Double, site: OriginalStationSite = .remoteUtility
  ) throws {
    var game = input
    game.launch()
    game.selectFlightTool(.combatLaser)
    let (_, id) = try utilityBeamApproach(&game, site: site)
    let index = try #require(game.bodies.firstIndex { $0.id == id })
    let identity = try #require(game.bodies[index].nativeStationIdentity)
    let source = try #require(NativeStationSource.binding(for: identity))
    try #require(source.recharge == 0 && game.bodies[index].energy == source.maximumEnergy)
    game.advanceNativeStationRecharge(delta: 0.1)
    #expect(game.bodies[index].energy == source.maximumEnergy)
    try #require(game.commander.laser(on: .front) == .pulse)
    var firing = Controls()
    firing.fire = true
    game.tick(delta: 0.1, controls: firing)
    let wounded = try #require(game.bodies.firstIndex { $0.id == id })
    try #require(game.bodies[wounded].energy > 0 && game.bodies[wounded].energy < source.maximumEnergy)
    try #require(game.nativeStationBodyIsCurrent(game.bodies[wounded]))
    let before = game.bodies[wounded].energy
    let materials = game.commander.nativeUtility
    let engineer = game.commander.nativePeople?.utilityEngineer
    for delta in [0.0, -0.1, Double.nan, Double.infinity, 0.100001] {
      var refused = game
      refused.advanceNativeStationRecharge(delta: delta)
      #expect(refused.bodies == game.bodies && refused.commander == game.commander)
    }
    var foreign = game
    foreign.bodies[wounded].nativeStationIdentity = site.identity(world: UUID())
    #expect(!foreign.nativeStationBodyIsCurrent(foreign.bodies[wounded]))
    foreign.advanceNativeStationRecharge(delta: 0.1)
    #expect(foreign.bodies[wounded].energy == before)
    var wrongBinding = game
    wrongBinding.bodies[wounded].id = game.nextBodyID
    #expect(!wrongBinding.nativeStationBodyIsCurrent(wrongBinding.bodies[wounded]))
    wrongBinding.advanceNativeStationRecharge(delta: 0.1)
    #expect(wrongBinding.bodies[wounded].energy == before)
    if site == .remoteUtility {
      var missingCustody = game
      missingCustody.commander.savedNativePeopleCustody = nil
      #expect(!missingCustody.commander.nativePeopleStateValid)
      missingCustody.advanceNativeStationRecharge(delta: 0.1)
      #expect(missingCustody.bodies[wounded].energy == before)
    }
    game.tick(delta: 0.1, controls: Controls())
    let after = try #require(game.bodies.first { $0.id == id })
    #expect(abs(after.energy - before - expected / 10) < 0.00001)
    let retained = game.bodies
    game.advanceNativeStationRecharge(delta: 0)
    #expect(game.bodies == retained)
    #expect(game.commander.nativeUtility == materials && game.commander.nativePeople?.utilityEngineer == engineer)
    #expect(game.commander.valid)
  }
  func refusedWrite(_ runtime: GameRuntime, quote: NativeUtilityQuote, label: String) async throws {
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    let blocked = try files.blockWrites(label)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(quote) }
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.nativeUtilityServiceContext == before.nativeUtilityServiceContext)
    try files.restoreWrites(blocked, files: disk)
  }
}

struct NativeUtilityRuntimeTests {

  /// Controlled native geometry/physics coverage; this is not the current combat journey.
  @Test func manualPairNativeAdmissionPredictsBothModesAndRefusesAnAddedObstacle() async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let source = try await f.source()
    let quote = try await source.nativeUtilityQuote(.collect)
    try await source.confirmNativeUtility(quote)
    let target = try await f.target(from: source)
    var scene = await target.snapshot()
    scene.launch()
    // Controlled initial scene: retain every real station, with no ambient actors/providers.
    scene.bodies.removeAll { $0.hull != .station }
    scene.commander.npcPersistence = .init()
    scene.commander.encounterDirector = nil
    scene.commander.stationSecurity = .init()
    scene.commander.cargoDebrisLedger = .init()
    scene.miningFields.removeAll()
    scene.salvageSites.removeAll()
    scene.commander.savedEMPState = nil
    scene.commander.savedEMPCharge = nil
    scene.scriptReferenceFrame = nil
    let (identity, bodyID) = try utilityBeamApproach(&scene, minimumHullClearance: true)
    var outward = scene.commander.flightSimulation.pose
    outward.orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    NativeStationTestFixture.reframe(&scene, to: outward)
    scene.cancelAutoTarget()
    scene.screen = .front
    scene.speed = 0
    scene.autoPilot.setApproachVelocity(.init(0, 0, 0))
    let body = try #require(scene.bodies.first { $0.id == bodyID })
    let actor = try #require(body.physical?.identity)
    let flight = scene.commander.flightSimulation
    let world = try #require(scene.commander.nativeStations)
    let sourcePoint = try #require(world.currentPosition(
      for: .originalStation(identity), at: flight.physicalTime))
    let sourceBasis = try #require(world.currentOrientation(for: identity, at: flight.physicalTime))
    let nativeSource = ShipPose(position: sourcePoint, orientation: sourceBasis)
    let normal = sourceBasis.transposed.apply(flight.pose.orientation.z)
    let floor = normal.dot(sourceBasis.transposed.apply(flight.pose.position - sourcePoint))
    try #require(scene.commander.valid)
    for mode in [false, true] {
      var game = scene
      game.manualResidualFlight = mode
      let before = game.commander.flightSimulation
      let admitted = game.admitManualControlPair(
        source: identity, actor: actor, bodyID: bodyID,
        exteriorNormal: normal, exteriorFloor: floor, delta: 0.1)
      try #require(admitted)
      #expect(game.commander.flightSimulation == before)
      var pulse = Controls()
      pulse.throttle = 1
      game.tick(delta: 0.1, controls: pulse)
      let moved = game.commander.flightSimulation
      #expect(moved.physicalTime > before.physicalTime && moved.pose.position != before.pose.position)
      try #require(!game.paused && !game.docked && game.energy > 0)
      var brake = Controls()
      brake.throttle = -1
      game.tick(delta: 0.1, controls: brake)
      #expect(game.speed == 0 && game.autoPilot.velocity == .init(0, 0, 0))
      #expect(!game.manualResidualFlight && game.commander.flightSimulation.pose == moved.pose)
      #expect(game.commander.flightSimulation.physicalTime > moved.physicalTime)
      let after = try #require(game.bodies.first { $0.id == bodyID })
      let afterFrame = try UtilityCombatFrame(body: after)
      #expect(normal.dot(afterFrame.player) - floor >= 0)
      let afterFlight = game.commander.flightSimulation
      let afterWorld = try #require(game.commander.nativeStations)
      let afterPoint = try #require(afterWorld.currentPosition(
        for: .originalStation(identity), at: afterFlight.physicalTime))
      let afterBasis = try #require(afterWorld.currentOrientation(
        for: identity, at: afterFlight.physicalTime))
      #expect(normal.dot(afterBasis.transposed.apply(afterFlight.pose.position - afterPoint)) - floor >= 0)
      #expect(game.nativeStationBodyIsCurrent(after) && game.commander.valid)
    }
    var blocked = scene
    let allocatedObstruction = blocked.commander.flightSimulation.allocateActor()
    let obstruction = try #require(allocatedObstruction)
    var cargo = SpaceBody(id: blocked.nextBodyID, hull: .cargo, position: .init(0, 0, 0))
    cargo.physical = .init(identity: obstruction, population: .cargo, npc: nil)
    blocked.bodies.append(cargo)
    blocked.nextBodyID += 1
    let before = blocked.commander
    let bodies = blocked.bodies
    let blockedAdmission = blocked.admitManualControlPair(
      source: identity, actor: actor, bodyID: bodyID,
      exteriorNormal: normal, exteriorFloor: floor, delta: 0.1)
    #expect(!blockedAdmission)
    #expect(blocked.commander == before && blocked.bodies == bodies)

    // An unsupported ordinary body must be refused before an unavailable hull can trap.
    let unavailableSources: [(Hull, String?)] = [
      (.constrictor, nil), (.cargo, "missing-manual-pair-native-source")
    ]
    for (hull, catalogueID) in unavailableSources {
      var unavailable = scene
      let allocatedUnavailableActor = unavailable.commander.flightSimulation.allocateActor()
      let unavailableActor = try #require(allocatedUnavailableActor)
      var body = SpaceBody(id: unavailable.nextBodyID, hull: hull, position: .init(10000, 0, 0))
      body.physical = .init(identity: unavailableActor, population: .mission, npc: nil)
      body.physical?.catalogueShipID = catalogueID
      unavailable.bodies.append(body)
      unavailable.nextBodyID += 1
      let commander = unavailable.commander
      let retained = unavailable.bodies
      let unavailableAdmission = unavailable.admitManualControlPair(
        source: identity, actor: actor, bodyID: bodyID,
        exteriorNormal: normal, exteriorFloor: floor, delta: 0.1)
      #expect(!unavailableAdmission)
      #expect(unavailable.commander == commander && unavailable.bodies == retained)
    }

    // Keep the real native source and actual ticks; choose one fixed near-tangent heading.
    let planeNormal = Vector3(0, 0, 1)
    var near = scene
    var tangent = flight.pose
    let z = Vector3(1, 0, 1e-12).unit
    let y = Vector3(0, 1, 0)
    tangent.orientation.x = sourceBasis.apply(y.cross(z))
    tangent.orientation.y = sourceBasis.apply(y)
    tangent.orientation.z = sourceBasis.apply(z)
    try #require(tangent.orientation.validRotation)
    NativeStationTestFixture.reframe(&near, to: tangent)
    let nativeLocal = sourceBasis.transposed.apply(tangent.position - sourcePoint)
    let nativeFloor = planeNormal.dot(nativeLocal)
    try #require(ManualFlightThrottleKernel.outwardComponentsAgree(
      normal: planeNormal, direction: sourceBasis.transposed.apply(tangent.orientation.z)))
    let nearCommander = near.commander
    let nearBodies = near.bodies
    let nearAdmission = near.admitManualControlPair(
      source: identity, actor: actor, bodyID: bodyID,
      exteriorNormal: planeNormal, exteriorFloor: nativeFloor, delta: 0.1)
    #expect(!nearAdmission)
    #expect(near.commander == nearCommander && near.bodies == nearBodies)
    var actual = near
    var pulse = Controls()
    pulse.throttle = 1
    actual.tick(delta: 0.1, controls: pulse)
    let afterPulse = actual.commander.flightSimulation.pose
    var brake = Controls()
    brake.throttle = -1
    actual.tick(delta: 0.1, controls: brake)
    let afterBrake = actual.commander.flightSimulation.pose
    try #require(afterPulse.position != tangent.position && afterBrake == afterPulse)
    #expect(!ManualControlPairEnvelope.nativeExteriorPair(
      normal: planeNormal, floor: nativeFloor, source: nativeSource,
      start: tangent, afterPulse: afterPulse, afterBrake: afterBrake))

    // A single tolerated rendered displacement can put that locked floor beyond the
    // native player. Hull inflation cannot discharge the validator's signed plane.
    let index = try #require(near.bodies.firstIndex { $0.id == bodyID })
    let nearFrame = try UtilityCombatFrame(body: near.bodies[index])
    near.bodies[index].position = near.bodies[index].position
      - nearFrame.model.apply(planeNormal) * 1e-6
    let shifted = near.bodies[index]
    try #require(world.bodyRigidPoseIsConsistent(shifted, flight: near.commander.flightSimulation))
    let rendered = try UtilityCombatFrame(body: shifted)
    let lockedFloor = planeNormal.dot(rendered.player)
    try #require(ManualFlightThrottleKernel.outwardComponentsAgree(
      normal: planeNormal, direction: rendered.model.transposed.apply(.init(0, 0, 1))))
    #expect(planeNormal.dot(rendered.player) - lockedFloor == 0)
    try #require(planeNormal.dot(nativeLocal) - lockedFloor < 0)
    let retainedCommander = near.commander
    let retainedBodies = near.bodies
    let shiftedAdmission = near.admitManualControlPair(
      source: identity, actor: actor, bodyID: bodyID,
      exteriorNormal: planeNormal, exteriorFloor: lockedFloor, delta: 0.1)
    #expect(!shiftedAdmission)
    #expect(near.commander == retainedCommander && near.bodies == retainedBodies)
  }

  @Test func manualPairCargoEnvelopeIncludesADeathSourceBehindTheFullPendingQueue() throws {
    let system = SystemIdentity(galaxy: 0, system: 0)
    var flight = FlightSimulationState()
    flight.enter(system, arriving: false)
    let allocatedFirst = flight.allocateActor()
    let first = try #require(allocatedFirst)
    let allocatedSecond = flight.allocateActor()
    let second = try #require(allocatedSecond)
    let commodity = try #require(CommodityIdentity.allCases.first { $0.unit != "kg" && $0.unit != "g" })
    func dead(_ actor: ActorIdentity, position: Vector3) -> ActorSnapshot {
      .init(identity: actor, hull: .cobra, position: position, orientation: .init(),
        velocity: .init(0, 0, 0), energy: 0, maximumEnergy: 100,
        maximumSpeedUnitsPerSecond: 100, legal: .init(),
        npc: .init(role: .trader, origin: system, destination: system), rock: nil, payload: nil)
    }
    var ledger = CargoDebrisLedger()
    #expect(ledger.registerDeath(
      actor: dead(first, position: .init(0, 0, 0)),
      manifest: [.init(commodity: commodity, quantity: 5 * CargoDebrisLedger.maximumPending)],
      settlementID: 1, physicalTime: 0, protection: .init())
      == .registered(lots: CargoDebrisLedger.maximumPending))
    let remote = Vector3(10000, 20000, 30000)
    #expect(ledger.registerDeath(actor: dead(second, position: remote),
      manifest: [.init(commodity: commodity, quantity: 1)], settlementID: 2,
      physicalTime: 0, protection: .init()) == .registered(lots: 1))
    try #require(ledger.pendingPayloads.count == CargoDebrisLedger.maximumPending)
    let before = ledger
    let volumes = try #require(ledger.manualControlPairEnvelopes(from: 0, through: 0.2, horizon: 0.2))
    #expect(ledger == before)
    let unissued = CargoDebrisBirthDescription(sourcePosition: remote,
      sourceOrientation: .init(), sourceVelocity: .init(0, 0, 0),
      sourceTime: 0, physicalTime: 0.2, slot: 0)
    #expect(volumes.contains { (unissued.position - $0.position).length <= $0.radius })
    for lot in ledger.pendingPayloads {
      let end = lot.position + lot.velocity * 0.2
      #expect(volumes.contains { (end - $0.position).length <= $0.radius })
    }
  }

  @Test func manualPairSecurityEnvelopeRetainsHistoricalQueuedLaunchPositions() throws {
    let system = SystemIdentity(galaxy: 0, system: 0)
    var flight = FlightSimulationState()
    flight.enter(system, arriving: false)
    let anchors = try #require(flight.anchors)
    let player = ActorSnapshot(identity: try #require(flight.player), hull: .cobra,
      position: flight.pose.position, orientation: .init(), velocity: .init(0, 0, 0),
      energy: 100, maximumEnergy: 100, maximumSpeedUnitsPerSecond: 100,
      legal: .init(), npc: nil, rock: nil, payload: nil)
    let context = EncounterContext(system: system, seed: 0, government: 7, visit: flight.visit,
      revision: 0, physicalTime: 0, anchors: anchors, player: player, actors: [],
      protection: .init(), budget: .init(), perceptionRadius: 6000)
    var security = StationSecurity()
    let queued = security.advance(context: context).encounters.batches.flatMap(\.requests)
    try #require(!queued.isEmpty)
    let moved = StationAnchor(identity: anchors.station.identity, position: .init(100000, 0, 0),
      orientation: .init(), exitPosition: .init(100000, 0, -500), exitDirection: .init(0, 0, -1))
    let before = security
    let volumes = try #require(security.manualControlPairLaunchEnvelopes(station: moved, rotation: 0))
    #expect(security == before)
    for request in queued {
      #expect(volumes.contains { (request.position - $0.volume.position).length <= $0.volume.radius })
    }
  }

  @Test func manualThrottleKernelPreservesCapsExactBrakeAndOverspeedRefusal() throws {
    #expect(ManualFlightThrottleKernel.cruise(
      speed: 1, throttle: 1, delta: 0.1, acceleration: 10, maximum: 2) == 2)
    #expect(ManualFlightThrottleKernel.cruise(
      speed: 1, throttle: -1, delta: 0.1, acceleration: 10, maximum: 2) == 0)
    let pulse = try #require(ManualFlightThrottleKernel.residual(
      velocity: .init(0, 0, 0), magnitude: 0, acceleration: 10, maximum: 2,
      throttle: 1, delta: 0.1))
    #expect(pulse == .init(0, 0, 1))
    let stopped = try #require(ManualFlightThrottleKernel.residual(
      velocity: pulse, magnitude: pulse.length, acceleration: 10, maximum: 2,
      throttle: -1, delta: 0.1))
    #expect(stopped == .init(0, 0, 0))
    let overspeed = Vector3(0, 0, 5)
    #expect(ManualFlightThrottleKernel.residual(
      velocity: overspeed, magnitude: overspeed.length, acceleration: 10, maximum: 2,
      throttle: 1, delta: 0.1) == overspeed)
    #expect(ManualFlightThrottleKernel.residual(
      velocity: overspeed, magnitude: .nan, acceleration: 10, maximum: 2,
      throttle: -1, delta: 0.1) == nil)
    #expect(ManualFlightThrottleKernel.residual(
      velocity: overspeed, magnitude: overspeed.length, acceleration: 0, maximum: 2,
      throttle: -1, delta: 0.1) == nil)
  }

  // Policy/ledger values below are not a native hit, movement or corridor witness.
  @Test func outwardHoldPulseUsesOneFundedBrakeBeforeTheOriginalReturn() throws {
    #expect(UtilityCombatController.outwardComponentsAgree(
      normal: .init(0, 0, -1), direction: .init(0, 0, -1)))
    #expect(!UtilityCombatController.outwardComponentsAgree(
      normal: .init(0, 0, -1), direction: .init(0, 0, 1)))
    #expect(!UtilityCombatController.outwardComponentsAgree(
      normal: .init(0.8, 0.6, 0), direction: .init(0.8, -0.6, 0)))
    #expect(!UtilityCombatController.outwardComponentsAgree(
      normal: .init(0, 0, 0), direction: .init(0, 0, -1)))
    #expect(!UtilityCombatController.outwardComponentsAgree(
      normal: .init(Double.leastNonzeroMagnitude, 0, 1),
      direction: .init(-Double.leastNonzeroMagnitude, 0, 1)))

    var ledger = try UtilityCombatLedger(maximumShots: 1)
    try ledger.chargeFire()
    try ledger.earnQualifiedHit()
    var stage = UtilityCombatPause.Stage.hold
    let pulse = try stage.holdOrBrake(outward: true, returnReserve: 6, ledger: ledger)
    #expect(pulse.throttle == 1 && !pulse.fire)
    #expect(pulse.pitch == 0 && pulse.yaw == 0 && pulse.roll == 0)
    #expect(stage == .brake && ledger.released == 0 && ledger.calls == 1 && ledger.credit == 8)
    try ledger.chargeRelease()
    #expect(ledger.released == 1 && ledger.calls == 2 && ledger.credit == 7)

    let brake = try stage.holdOrBrake(outward: false, returnReserve: 6, ledger: ledger)
    #expect(brake.throttle == -1 && !brake.fire)
    #expect(brake.pitch == 0 && brake.yaw == 0 && brake.roll == 0)
    #expect(stage == .yawSource)
    try ledger.chargeRelease()
    #expect(ledger.released == 2 && ledger.calls == 3 && ledger.credit == 6)
    #expect(ledger.maximumCalls - ledger.calls == 6)
    #expect(ledger.invoked == 1 && ledger.qualified == 1)
    #expect(throws: (any Error).self) {
      _ = try stage.holdOrBrake(outward: true, returnReserve: 6, ledger: ledger)
    }
    #expect(ledger.released == 2 && ledger.calls == 3 && ledger.credit == 6)
  }

  @Test func insufficientTwoReleaseReserveRetainsTheOriginalStationaryHold() throws {
    var ledger = try UtilityCombatLedger(maximumShots: 1)
    try ledger.chargeFire()
    try ledger.earnQualifiedHit()
    var inwardStage = UtilityCombatPause.Stage.hold
    let inward = try inwardStage.holdOrBrake(outward: false, returnReserve: 6, ledger: ledger)
    #expect(inward.throttle == -1 && inwardStage == .hold)
    #expect(ledger.released == 0 && ledger.calls == 1 && ledger.credit == 8)

    var stage = UtilityCombatPause.Stage.hold
    let hold = try stage.holdOrBrake(outward: true, returnReserve: 7, ledger: ledger)
    #expect(hold.throttle == -1 && !hold.fire)
    #expect(hold.pitch == 0 && hold.yaw == 0 && hold.roll == 0)
    #expect(stage == .hold && ledger.released == 0 && ledger.calls == 1 && ledger.credit == 8)
    try ledger.chargeRelease()
    #expect(ledger.released == 1 && ledger.calls == 2 && ledger.credit == 7)
    #expect(ledger.maximumCalls - ledger.calls == 7)
  }

  @Test func nativeBoardReviewDefaultsBackAndRequiresSeparateConfirmedCollection() async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source()
    await runtime.key("contracts-open")
    let board = await runtime.snapshot()
    try #require(board.screen == .contracts)
    let index = try #require(board.contractBoard.rows.firstIndex { $0.utility == .collect })
    for _ in 0..<index { await runtime.key("down") }
    await runtime.key("return")
    let review = await runtime.snapshot()
    #expect(review.contractBoard.detail && review.contractBoard.action == .back)
    #expect(
      Display.contractDetailRows(review, width: 1000).joined(separator: " ").lowercased().contains(
        "frozen payment"))
    let before = review.commander
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().contractBoard.utilityQuote?.quote == nil)
    await runtime.key("return")
    await runtime.key("right")
    await runtime.key("return")
    let collected = await runtime.snapshot()
    #expect(collected.commander.nativeUtility?.heldTonnes == 4)
    #expect(collected.commander.credits == before.credits && collected.commander.valid)
  }

  @Test func actualSourceInstallationCrewReceiptAndTwoNativeRechargeSocketsSurviveColdLoad()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    let original = await runtime.snapshot()
    let stock = try #require(original.commander.nativeUtility)
    #expect(stock.materials.count == 8 && stock.consignments.isEmpty)
    #expect(original.commander.nativePeople?.utilityEngineer == nil)
    #expect(original.commander.nativeStations?.ledger.records.first {
      NativeUtilityState.isTarget($0.identity)
    }?.utilitySourceBirth == nil)
    #expect(
      original.commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      }?.binding == nil)
    for socket in 0..<2 {
      let before = await runtime.snapshot()
      let collect = try await runtime.nativeUtilityQuote(.collect)
      #expect(collect.rewardTenths == 6100 + 1100 * (collect.route.count - 1))
      try await runtime.confirmNativeUtility(collect)
      let held = await runtime.snapshot()
      #expect(held.commander.cargoTonnes == before.commander.cargoTonnes + 4)
      #expect(held.commander.nativeUtility?.active?.originalUnits == stock.units(socket))
      runtime = try await f.reloaded(runtime)
      runtime = try await f.target(from: runtime)
      try f.recharge(await runtime.snapshot(), expected: Double(10 * socket))
      let install = try await runtime.nativeUtilityQuote(.install)
      let dock = await runtime.snapshot().commander.nativeStations?.ledger.currentDock
      try await runtime.confirmNativeUtility(install)
      let installed = await runtime.snapshot()
      #expect(installed.commander.nativeUtility?.heldTonnes == 0)
      #expect(installed.commander.nativeUtility?.active?.installation?.socket == socket)
      #expect(installed.commander.nativeStations?.ledger.currentDock == dock)
      try f.recharge(installed, expected: Double(10 * (socket + 1)))
      runtime = try await f.reloaded(runtime)
      let receive = try await runtime.nativeUtilityQuote(.receive)
      let resident = try #require(await runtime.snapshot().commander.nativePeople?.utilityEngineer)
      #expect(resident.casualty == nil && resident.inspections.count == socket)
      try await runtime.confirmNativeUtility(receive)
      let received = await runtime.snapshot()
      let job = try #require(received.commander.nativeUtility?.consignments.last)
      #expect(job.phase == .received && job.reception?.installation == job.installation?.operation)
      #expect(job.originalUnits == stock.units(socket))
      let engineer = try #require(received.commander.nativePeople?.utilityEngineer)
      #expect(engineer.registration == resident.registration && engineer.inspections.count == socket + 1)
      #expect(engineer.inspections.last?.operation == job.reception?.operation)
      #expect(engineer.inspections.last?.installation == job.installation)
      #expect(engineer.inspections.last?.consignment == job.id && engineer.casualty == nil)
      #expect(received.commander.credits == before.commander.credits + collect.rewardTenths)
      let missionID = WayfarerFieldRelief.instance(job.id)
      let mission = try #require(received.commander.scriptState.instances[missionID])
      #expect(mission.outcome == .complete && mission.savedFieldRelief?.job == job)
      #expect(mission.contract?.settlementAmount == collect.rewardTenths)
      #expect(mission.completionReceipt?.cause?.nativeStation?.receipt == receive.target?.receipt)
      let award = try #require(
        received.commander.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID])
      if let prior = before.commander.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID] {
        #expect(award == prior)
      } else {
        #expect(award.completion == mission.completionReceipt)
      }
      #expect(received.commander.valid)
      await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(receive) }
      runtime = try await f.reloaded(runtime)
      if socket == 0 { runtime = try await f.source(from: runtime) }
    }
    runtime = try await f.source(from: runtime)
    try f.recharge(await runtime.snapshot(), expected: 0, site: .dhole)
    let final = await runtime.snapshot().commander
    #expect(
      final.nativeUtility?.consignments.count == 2 && final.nativeUtility?.rechargeBonus == 20)
  }

  @Test func collectInstallReceiveWriterRefusalsAndColdStaleQuotesPreserveOriginalProperty()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await f.refusedWrite(runtime, quote: collect, label: "utility-collect")
    try await runtime.confirmNativeUtility(collect)
    runtime = try await f.target(from: runtime)
    var install = try await runtime.nativeUtilityQuote(.install)
    try await f.refusedWrite(runtime, quote: install, label: "utility-install")
    runtime = try await f.reloaded(runtime)
    let before = await runtime.snapshot().commander
    let frozenReward = try #require(before.nativeUtility?.active?.rewardTenths)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(install) }
    #expect(await runtime.snapshot().commander == before)
    install = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(install)
    let receive = try await runtime.nativeUtilityQuote(.receive)
    try await f.refusedWrite(runtime, quote: receive, label: "utility-receive")
    try await runtime.confirmNativeUtility(receive)
    #expect(await runtime.snapshot().commander.credits == before.credits + frozenReward)
  }

  @Test func wrongDockPausedChangedInventoryAndSubstituteCommodityCannotAuthorizeInstallation()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let source = try await f.source()
    await #expect(throws: (any Error).self) { _ = try await source.nativeUtilityQuote(.install) }
    let collect = try await source.nativeUtilityQuote(.collect)
    try await source.confirmNativeUtility(collect)
    let runtime = try await f.target(from: source)
    let quote = try await runtime.nativeUtilityQuote(.install)
    var paused = await runtime.snapshot()
    paused.paused = true
    #expect(throws: (any Error).self) { try paused.confirmNativeUtility(quote) }
    var changed = await runtime.snapshot()
    let inventory = try #require(changed.commander.equipmentInventory)
    changed.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
      owner: inventory.owner,
      activeHull: inventory.activeHull, revision: inventory.revision + 1, items: inventory.items)
    try #require(changed.commander.valid)
    #expect(throws: (any Error).self) { try changed.confirmNativeUtility(quote) }
    changed.commander.cargo[9] = 4
    // Commodity stock does not replace an allocated original unit; strict state validation proves this.
    let state = try #require(changed.commander.nativeUtility)
    var substitute = state
    substitute.consignments[0] = NativeUtilityConsignment(
      id: state.consignments[0].id,
      originalUnits: [UUID(), UUID(), UUID(), UUID()], hull: state.consignments[0].hull,
      source: state.consignments[0].source, route: state.consignments[0].route,
      firstLegReach: state.consignments[0].firstLegReach,
      fullTankReach: state.consignments[0].fullTankReach,
      rewardTenths: state.consignments[0].rewardTenths)
    #expect(!substitute.valid)
    var wrong = await runtime.snapshot()
    wrong.invalidateNativeStationAuthority()
    #expect(throws: (any Error).self) { try wrong.confirmNativeUtility(quote) }
  }

  @Test func exactSourceReturnsRetireStockAndRetryUsesTheOtherOriginalFour() async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source()
    let original = await runtime.snapshot().commander
    let first = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(first)
    let held = try #require(await runtime.snapshot().commander.nativeUtility?.active)
    let returningFirst = try await runtime.nativeUtilityQuote(.returnMaterials)
    try await runtime.confirmNativeUtility(returningFirst)
    let returned = await runtime.snapshot().commander
    #expect(returned.cargoTonnes == original.cargoTonnes)
    #expect(returned.nativeUtility?.consignments[0].phase == .returned)
    let second = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(second)
    let active = try #require(await runtime.snapshot().commander.nativeUtility?.active)
    #expect(active.id != held.id && Set(active.originalUnits).isDisjoint(with: held.originalUnits))
    let returningSecond = try await runtime.nativeUtilityQuote(.returnMaterials)
    try await runtime.confirmNativeUtility(returningSecond)
    await #expect(throws: (any Error).self) { _ = try await runtime.nativeUtilityQuote(.collect) }
    #expect(await runtime.snapshot().commander.credits == original.credits)
    _ = try await f.reloaded(runtime)
  }

  @Test
  func xyzzyActualHeldMaterialsConstrainMarketThenInstallationRestoresExistingUnlimitedPolicy()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: true, fill: false)
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: false, fill: true)
    let full = await runtime.snapshot()
    try #require(full.commander.xyzzyActive && full.commander.unlimitedCargo)
    try #require(full.commander.accommodation.fitted.isEmpty)
    try #require(full.commander.nativeUtility?.heldTonnes == 4)
    #expect(full.commander.tradeCargoCapacity == full.commander.standardCargoCapacity)
    #expect(full.marketAvailability(0) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == full.commander && refused.market == full.market)
    #expect(refused.commander.valid)
    runtime = try await f.target(from: runtime)
    let install = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(install)
    let installed = await runtime.snapshot().commander
    #expect(installed.nativeUtility?.heldTonnes == 0)
    #expect(
      installed.tradeCargoCapacity == installed.capacity
        && installed.capacity > installed.standardCargoCapacity)
    runtime = try await f.source(from: runtime)
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: false, fill: true)
    let available = await runtime.snapshot()
    try #require(available.commander.cargoTonnes == available.commander.standardCargoCapacity)
    #expect(available.marketAvailability(0) == "BUY")
    await runtime.key("return")
    let bought = await runtime.snapshot()
    #expect(bought.commander.cargo[0] == available.commander.cargo[0] + 1)
    #expect(bought.commander.valid)
  }

  @Test(arguments: [false, true])
  func destroyedActualTargetNeverRestoresHeldOrInstalledMaterials(installed: Bool) async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let source = try await f.source(combatReady: true)
    let collect = try await source.nativeUtilityQuote(.collect)
    try await source.confirmNativeUtility(collect)
    let runtime = try await f.target(from: source)
    if installed {
      let quote = try await runtime.nativeUtilityQuote(.install)
      try await runtime.confirmNativeUtility(quote)
    }
    let before = try #require(await runtime.snapshot().commander.nativeUtility)
    let beforePeople = try #require(await runtime.snapshot().commander.nativePeople?.utilityEngineer)
    await runtime.key("0")
    try await runtime.utilityPrepareTargetAttack()
    let live = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("utility-target-death")
    await #expect(throws: (any Error).self) { try await runtime.utilityActualTargetDeath() }
    let refused = await runtime.snapshot()
    let retained = try #require(refused.commander.nativePeople?.utilityEngineer?.casualty)
    #expect(refused.commander.nativeUtility == live.commander.nativeUtility)
    #expect(refused.commander.credits == live.commander.credits)
    #expect(refused.commander.scriptState.savedClueJournal == live.commander.scriptState.savedClueJournal)
    #expect(refused.commander.nativePeople?.utilityEngineer?.registration == beforePeople.registration)
    #expect(refused.commander.nativePeople?.utilityEngineer?.inspections == beforePeople.inspections)
    #expect(refused.commander.nativeStations?.ledger.records.first {
      NativeUtilityState.isTarget($0.identity)
    }?.tombstone == retained.tombstone)
    #expect(refused.bodies.filter { $0.nativeStationIdentity == before.target }.allSatisfy { $0.energy <= 0 })
    #expect(try ScriptFinanceTestFixture.files(blocked) == disk)
    try f.files.restoreWrites(blocked, files: disk)
    try await runtime.utilityActualTargetDeath()
    let dead = await runtime.snapshot()
    let record = try #require(
      dead.commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      })
    #expect(record.tombstone != nil && record.binding == nil)
    let engineer = try #require(dead.commander.nativePeople?.utilityEngineer)
    let casualty = try #require(engineer.casualty)
    #expect(casualty == retained)
    #expect(dead.commander.flightSimulation.physicalTime == refused.commander.flightSimulation.physicalTime)
    #expect(dead.commander.credits == live.commander.credits)
    #expect(dead.commander.scriptState.savedClueJournal == live.commander.scriptState.savedClueJournal)
    #expect(engineer.registration == beforePeople.registration && engineer.inspections == beforePeople.inspections)
    #expect(casualty.tombstone == record.tombstone && casualty.binding == record.tombstone?.destroyedBinding)
    #expect(casualty.usedDuration == 0.1 && casualty.physicalTime == casualty.startTime + casualty.usedDuration)
    #expect(casualty.incident >= casualty.preNextIncident && casualty.incident < casualty.postNextIncident)
    #expect(casualty.origin != nil && engineer.recordedLocation == .unobservedAfterStationLoss(record.identity))
    #expect(record.utilitySourceBirth?.operation == engineer.registration.operation)
    var noRevival = dead
    noRevival.advanceNativeStationRecharge(delta: 0.1)
    #expect(noRevival.bodies == dead.bodies && noRevival.commander == dead.commander)
    #expect(dead.commander.nativeUtility == before && dead.commander.valid)
    #expect(dead.commander.nativeUtility?.heldTonnes == (installed ? 0 : 4))
    await #expect(throws: (any Error).self) {
      _ = try await runtime.nativeUtilityQuote(installed ? .receive : .install)
    }
    let cold = try await f.reloaded(runtime)
    #expect(await cold.snapshot().commander.nativeUtility == before)
    #expect(await cold.snapshot().commander.nativePeople?.utilityEngineer == engineer)
    #expect(
      await cold.snapshot().commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      }?.tombstone != nil)
  }

  @Test(arguments: [NativeUtilityLossCause.escape, .shipDestroyed])
  func physicalLossWriterFailureThenRetryRetainsActualOriginalLoss(cause: NativeUtilityLossCause)
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source(escapeReady: true)
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    await runtime.key("0")
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("utility-loss")
    if cause == .escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.utilityActualFatalHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let refused = await runtime.snapshot()
    #expect(refused.commander.nativeUtility == before.commander.nativeUtility)
    if cause == .escape { #expect(refused.commander == before.commander) }
    try f.files.restoreWrites(blocked, files: disk)
    if cause == .escape {
      await runtime.key("escape-pod")
    } else {
      _ = await runtime.advance(delta: 0.1)
    }
    let lost = await runtime.snapshot()
    let job = try #require(lost.commander.nativeUtility?.consignments[0])
    #expect(job.phase == .lost && job.loss?.cause == cause)
    #expect(job.originalUnits == before.commander.nativeUtility?.active?.originalUnits)
    #expect(lost.commander.nativeUtility?.heldTonnes == 0)
    #expect(lost.commander.credits == before.commander.credits)
    #expect(
      lost.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(lost.commander.valid)
    _ = try await f.reloaded(runtime)
  }

}

// A controlled aiming frame supplies no shot, birth, fatal interval or service authority.
private func utilityBeamApproach(
  _ game: inout Game, site: OriginalStationSite = .remoteUtility,
  minimumHullClearance: Bool = false
) throws -> (NativeStationIdentity, Int) {
  try #require(!game.docked && !game.paused && game.screen.isFlight && game.commander.valid)
  let owner = try #require(game.commander.equipmentOwnerID)
  let identity = site.identity(world: owner)
  let source = try #require(NativeStationSource.binding(for: identity))
  let world = try #require(game.commander.nativeStations)
  let record = try #require(world.ledger.records.first { $0.identity == identity })
  let body = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
  try #require(record.tombstone == nil && NativeStationSource.authentic(record, owner: owner))
  try #require(body.energy > 0 && game.nativeStationBodyIsCurrent(body))
  try #require(record.binding?.actor == body.physical?.identity && record.binding?.bodyID == body.id)
  if site == .remoteUtility {
    let birth = try #require(record.utilitySourceBirth)
    let engineer = try #require(game.commander.nativePeople?.utilityEngineer)
    try #require(engineer.registration.operation == birth.operation && engineer.casualty == nil)
    try #require(engineer.registration.binding == birth.binding && engineer.registration.spawn == birth.spawn)
  }
  let time = game.commander.flightSimulation.physicalTime
  let position = try #require(world.currentPosition(for: .originalStation(identity), at: time))
  let orientation = try #require(world.currentOrientation(for: identity, at: time))
  let geometry = source.geometry
  let main = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station && $0.energy > 0 })
  let away = (position - game.commander.flightSimulation.pose.systemPoint(main.position)).unit
  let faces = geometry.mesh.faces.filter { $0.count == 3 }.map { indices in
    indices.map { geometry.mesh.vertices[$0] }
  }
  let face = try #require(faces.max { lhs, rhs in
    let a = orientation.apply((lhs[1] - lhs[0]).cross(lhs[2] - lhs[0]).unit)
    let b = orientation.apply((rhs[1] - rhs[0]).cross(rhs[2] - rhs[0]).unit)
    return a.dot(away) < b.dot(away)
  })
  let center = face.reduce(Vector3(0, 0, 0), +) * (1 / Double(face.count))
  let outward = (face[1] - face[0]).cross(face[2] - face[0]).unit
  let radius = try #require(game.commander.playerMesh.vertices.map(\.length).max())
  // Attack setup may use hull clearance; recharge retains the laser-range stand-off.
  let gap = minimumHullClearance ? radius + 8 : max(radius + 8, 6000 * 0.75)
  let separation = geometry.bounds.support(outward) - center.dot(outward) + gap
  var pose = ShipPose()
  pose.position = position + orientation.apply(center + outward * separation)
  pose.orientation.z = orientation.apply(outward) * -1
  let up = abs(pose.orientation.z.y) < 0.9 ? Vector3(0, 1, 0) : .init(1, 0, 0)
  pose.orientation.y = (up - pose.orientation.z * up.dot(pose.orientation.z)).unit
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 0
  let contact = try game.nearestMissionCollision(
    from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0, includePlayer: false)
  let hit = try #require(contact?.hit)
  try #require(hit.target == .body(body.id))
  return (identity, body.id)
}

// A perishable test projection; it supplies no hit, elapsed time or fatal authority.
private func utilityCurrentTargetContact(
  _ game: borrowing Game, utility: NativeUtilityState, binding: NativeStationSourceBinding
) throws -> (source: NativeStationSourceBinding, body: SpaceBody, contact: MissionCollisionContact?) {
  let screen = game.screen
  let docked = game.docked
  let paused = game.paused
  let commanderIsValid = game.commander.valid
  let flightIsCurrent = screen.isFlight && !docked && !paused && commanderIsValid
  try #require(flightIsCurrent)
  let target = utility.target
  let owner = utility.owner
  let sourceBinding = NativeStationSource.binding(for: target)
  let currentSource = try #require(sourceBinding)
  let sourceIsCurrent = currentSource.identity(world: owner) == target
    && currentSource.site == binding.site && currentSource.physical == binding.physical
  try #require(sourceIsCurrent)
  let bodies = game.bodies
  let targetBody = bodies.first { $0.nativeStationIdentity == target }
  let currentBody = try #require(targetBody)
  let nativeBodyIsCurrent = game.nativeStationBodyIsCurrent(currentBody)
  let bodyIsCurrent = currentBody.energy > 0 && nativeBodyIsCurrent
    && utilityCombatOrdinarySource(currentBody)
  try #require(bodyIsCurrent)
  let currentContact = try game.nearestMissionCollision(
    from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
    includePlayer: false)
  return (source: currentSource, body: currentBody, contact: currentContact)
}

/// A caught helper refusal must remain a failed test rather than the writer-refusal oracle.
private func utilityTargetDeathUnexpectedError(_ error: any Error) -> String {
  let detail = String(describing: error)
  let marker = " [truncated]"
  var message = "utilityActualTargetDeath unexpected failure outside final save: "
  var scanned = 0
  for scalar in detail.unicodeScalars {
    if scanned == 512 { return message + marker }
    scanned += 1
    let value = scalar.value
    let chunk: String
    if value == 0x22 {
      chunk = "\\\""
    } else if value == 0x5C {
      chunk = "\\\\"
    } else if value < 0x20 || (0x7F...0x9F).contains(value)
      || value == 0x061C || value == 0x200E || value == 0x200F
      || value == 0x2028 || value == 0x2029 || (0x202A...0x202E).contains(value)
      || (0x2066...0x2069).contains(value)
    {
      chunk = String(format: "\\u{%X}", value)
    } else {
      chunk = String(scalar)
    }
    guard message.utf8.count + chunk.utf8.count + marker.utf8.count <= 512 else {
      return message + marker
    }
    message += chunk
  }
  return message
}

private enum UtilityCombatFailure: Error {
  case refused(String)
}

private func utilityCombatInteger(_ value: Double) throws -> Int {
  guard value.isFinite, value >= 0, let result = Int(exactly: value) else {
    throw UtilityCombatFailure.refused("unrepresentable combat count")
  }
  return result
}

private func utilityCombatSum(_ values: Int...) throws -> Int {
  var result = 0
  for value in values {
    let next = result.addingReportingOverflow(value)
    guard value >= 0, !next.overflow else {
      throw UtilityCombatFailure.refused("combat count overflow")
    }
    result = next.partialValue
  }
  return result
}

private struct UtilityCombatLedger {
  let maximumShots: Int
  let maximumCalls: Int
  let maximumCredit: Int
  private(set) var invoked = 0
  private(set) var qualified = 0
  private(set) var released = 0
  private(set) var calls = 0
  private(set) var credit = 0

  init(maximumShots: Int) throws {
    let callLimit = maximumShots.multipliedReportingOverflow(by: 9)
    let creditLimit = maximumShots.multipliedReportingOverflow(by: 8)
    guard maximumShots > 0, !callLimit.overflow, !creditLimit.overflow else {
      throw UtilityCombatFailure.refused("combat ceiling overflow")
    }
    self.maximumShots = maximumShots
    maximumCalls = callLimit.partialValue
    maximumCredit = creditLimit.partialValue
  }

  mutating func chargeFire() throws {
    guard invoked < maximumShots, calls < maximumCalls else {
      throw UtilityCombatFailure.refused("fire ceiling exhausted")
    }
    invoked = try utilityCombatSum(invoked, 1)
    calls = try utilityCombatSum(calls, 1)
  }

  mutating func chargeRelease() throws {
    guard credit > 0, calls < maximumCalls else {
      throw UtilityCombatFailure.refused("earned release credit exhausted")
    }
    let nextReleased = try utilityCombatSum(released, 1)
    let nextCalls = try utilityCombatSum(calls, 1)
    credit -= 1
    released = nextReleased
    calls = nextCalls
  }

  mutating func earnQualifiedHit() throws {
    let nextQualified = try utilityCombatSum(qualified, 1)
    let nextCredit = try utilityCombatSum(credit, 8)
    guard nextQualified <= invoked, nextCredit <= maximumCredit else {
      throw UtilityCombatFailure.refused("duplicate combat credit")
    }
    qualified = nextQualified
    credit = nextCredit
  }
}

/// Reject alternate health/routing profiles using the already-owned source body.
private func utilityCombatOrdinarySource(_ body: SpaceBody) -> Bool {
  guard body.hull == .station, body.scriptNPC == nil, body.scriptShot == nil,
    body.missionActorID == nil, body.missionInstanceID == nil,
    let physical = body.physical, physical.npc == nil, physical.empCrewPod == nil,
    physical.rock == nil, physical.payload == nil, physical.ordnance == nil,
    physical.velocity == .init(0, 0, 0), physical.angularVelocity == .init(0, 0, 0),
    physical.canonicalSpin != true, body.rotationRate == 0
  else { return false }
  return body.energy.isFinite && body.energy > 0 && body.position.finite
}

/// Created only at the refused bearing, before the public error wrapper loses these values.
private struct UtilityCombatBearingRefusal: Error {
  let original: UtilityCombatFailure
  let phase: String
  let aiming: Bool
  let selectedGuide: Vector3
  let direction: Vector3
  let directionIsFinite: Bool
  let directionLength: Double?
  let sourcePlayer: Vector3
  let sourceModel: Basis3
  let anchor: Vector3
  let origin: Vector3
  let normal: Vector3
  let tangent: Vector3
  let floor: Double
  let width: Double
  let side: Double
  let reachedShoulder: Bool
  let axisRemaining: Int

  var diagnostic: String {
    " controllerBearing=[phase=\(phase) aiming=\(aiming)"
      + " direction=\(utilityCombatVectorText(direction)) finite=\(directionIsFinite)"
      + " length=\(directionLength.map { String($0) } ?? "NE")"
      + " selectedGuide=\(utilityCombatVectorText(selectedGuide))"
      + " sourcePlayer=\(utilityCombatVectorText(sourcePlayer))"
      + " sourceModelX=\(utilityCombatVectorText(sourceModel.x))"
      + " sourceModelY=\(utilityCombatVectorText(sourceModel.y))"
      + " sourceModelZ=\(utilityCombatVectorText(sourceModel.z))"
      + " anchor=\(utilityCombatVectorText(anchor)) origin=\(utilityCombatVectorText(origin))"
      + " normal=\(utilityCombatVectorText(normal)) tangent=\(utilityCombatVectorText(tangent))"
      + " floor=\(floor) width=\(width) side=\(side)"
      + " reachedShoulder=\(reachedShoulder) axisRemaining=\(axisRemaining)]"
  }
}

private struct UtilityCombatOwn {
  let motion: Vector3
  let craft: ShipPerformance
  let weaponReady: Bool
  var stopped: Bool { motion == .init(0, 0, 0) }
}

private struct UtilityCombatFrame {
  let player: Vector3
  let model: Basis3

  init(body: SpaceBody) throws {
    var model = Basis3()
    model.x = body.modelVector(.init(1, 0, 0))
    model.y = body.modelVector(.init(0, 1, 0))
    model.z = body.modelVector(.init(0, 0, 1))
    guard utilityCombatOrdinarySource(body), model.validRotation else {
      throw UtilityCombatFailure.refused("unsupported source motion or damage profile")
    }
    self.model = model
    player = model.transposed.apply(body.position * -1)
    guard player.finite else {
      throw UtilityCombatFailure.refused("invalid source-relative player position")
    }
  }
}

/// Pure values only: runtime owns every observation, control update and native call.
private struct UtilityCombatController {
  private enum Phase: Equatable {
    case ready, brake, yawGoal, pitchGoal, travel, brakeReturn, yawAim, pitchAim
  }
  private var phase = Phase.ready
  private var axisRemaining = 0
  private var previousTurn: UtilityCombatTurnObservation?
  private var latestTurn: UtilityCombatTurnObservation?
  private var side = 1.0
  private var reachedShoulder = false
  private var travelDirection = Vector3(0, 0, 0)
  private var brakeRemaining = 0
  private var yawBudget = 0
  private var pitchBudget = 0
  private var recoveryReserve = 0
  private let anchor: Vector3
  private let normal: Vector3
  private let tangent: Vector3
  private let origin: Vector3
  private let floor: Double
  private let width: Double
  let player: ActorIdentity
  let source: ActorIdentity
  let sourceBodyID: Int
  let owner: UUID
  let carrier: UUID
  let stationEpoch: UUID
  let commandEpoch: UUID
  let step: Double
  var active: Bool { phase != .ready }
  func exteriorContains(_ player: Vector3) -> Bool {
    let margin = normal.dot(player) - floor
    return player.finite && margin.isFinite && margin >= 0
  }
  func sourceAnchorDirection(in frame: UtilityCombatFrame) -> Vector3 {
    frame.model.apply(anchor - frame.player)
  }
  // New policy: each cached source-plane component must progress outward.
  func admitsOutwardPulse(in frame: UtilityCombatFrame) -> Bool {
    let direction = frame.model.transposed.apply(.init(0, 0, 1))
    return exteriorContains(frame.player) && direction.finite
      && Self.outwardComponentsAgree(normal: normal, direction: direction)
  }

  static func outwardComponentsAgree(normal: Vector3, direction: Vector3) -> Bool {
    ManualFlightThrottleKernel.outwardComponentsAgree(normal: normal, direction: direction)
  }
  var manualPairExterior: (normal: Vector3, floor: Double) { (normal, floor) }
  var diagnosticPhase: String {
    switch phase {
    case .ready: return "ready"
    case .brake: return "brake"
    case .yawGoal: return "yawGoal"
    case .pitchGoal: return "pitchGoal"
    case .travel: return "travel"
    case .brakeReturn: return "brakeReturn"
    case .yawAim: return "yawAim"
    case .pitchAim: return "pitchAim"
    }
  }

  var diagnosticTurns: String {
    "axisRemaining=\(axisRemaining) previousTurn=[\(previousTurn?.diagnostic ?? "nil")]"
      + " latestTurn=[\(latestTurn?.diagnostic ?? "nil")]"
  }

  init(body: SpaceBody, hit: Vector3, binding: NativeStationSourceBinding,
    player: ActorIdentity, owner: UUID, carrier: UUID,
    stationEpoch: UUID, commandEpoch: UUID, step: Double
  ) throws {
    let frame = try UtilityCombatFrame(body: body)
    guard let actor = body.physical?.identity, binding.rotationRate == 0,
      step.isFinite, step > 0, step <= 0.1, hit.finite
    else { throw UtilityCombatFailure.refused("unsupported initial combat frame") }
    let localAnchor = frame.model.transposed.apply(hit - body.position)
    let localNormal = frame.model.transposed.apply(.init(0, 0, -1))
    let localTangent = frame.model.transposed.apply(.init(1, 0, 0))
    let localFloor = localNormal.dot(frame.player)
    // Cached native bounds: no vertex traversal, new face choice or native query.
    let localWidth = binding.geometry.bounds.support(localTangent)
      + binding.geometry.bounds.support(localTangent * -1)
    guard localAnchor.finite, localNormal.finite, localTangent.finite, localFloor.isFinite,
      localWidth.isFinite, localWidth > 0
    else { throw UtilityCombatFailure.refused("invalid cached source guide") }
    anchor = localAnchor
    normal = localNormal
    tangent = localTangent
    origin = frame.player
    floor = localFloor
    width = localWidth
    self.player = player
    source = actor
    sourceBodyID = body.id
    self.owner = owner
    self.carrier = carrier
    self.stationEpoch = stationEpoch
    self.commandEpoch = commandEpoch
    self.step = step
  }

  private func deadline(_ amount: Double) throws -> Int {
    let rounded = try utilityCombatInteger(ceil(amount))
    return try utilityCombatSum(rounded, 1)
  }

  private func budgets(_ own: UtilityCombatOwn) throws -> (yaw: Int, pitch: Int, brake: Int) {
    let craft = own.craft
    let acceleration = craft.acceleration * 18
    let maximum = craft.speed * 18
    guard own.motion.finite, own.motion.length.isFinite,
      acceleration.isFinite, acceleration > 0, maximum.isFinite, maximum > 0,
      own.motion.length <= maximum, craft.yaw.isFinite, craft.yaw > 0,
      craft.pitch.isFinite, craft.pitch > 0
    else { throw UtilityCombatFailure.refused("invalid fitted combat limits or overspeed") }
    return (try deadline(.pi / (craft.yaw * step)),
      try deadline(.pi / (craft.pitch * step)), try deadline(maximum / (acceleration * step)))
  }

  func startReserve(_ own: UtilityCombatOwn) throws -> Int {
    let budget = try budgets(own)
    let stop = try deadline(own.motion.length / (own.craft.acceleration * 18 * step))
    return try utilityCombatSum(stop, budget.yaw, budget.pitch, 1,
      budget.brake, budget.yaw, budget.pitch)
  }

  func requiresRelease(_ own: UtilityCombatOwn, credit: Int, mayStart: Bool) throws -> Bool {
    if active || !own.stopped || !own.weaponReady { return true }
    let reserve = try startReserve(own)
    return mayStart && credit >= reserve
  }

  private var goal: Vector3 { origin + normal * width + tangent * (side * width) }

  private func normalized(_ value: Double) throws -> Double {
    guard value.isFinite else { throw UtilityCombatFailure.refused("nonfinite combat input") }
    return max(-1, min(1, value))
  }

  mutating func controls(_ own: UtilityCombatOwn, frame: UtilityCombatFrame,
    credit: Int, mayStart: Bool
  ) throws -> Controls {
    let budget = try budgets(own)
    var result = Controls()
    if phase == .ready {
      if !own.stopped { result.throttle = -1; return result }
      let reserve = try startReserve(own)
      guard mayStart, credit >= reserve else {
        if !own.weaponReady { return result }
        throw UtilityCombatFailure.refused("unfunded outbound maneuver")
      }
      yawBudget = budget.yaw
      pitchBudget = budget.pitch
      recoveryReserve = try utilityCombatSum(budget.brake, budget.yaw, budget.pitch)
      brakeRemaining = try deadline(own.motion.length / (own.craft.acceleration * 18 * step))
      reachedShoulder = false
      phase = .brake
    }
    // Every zero-step transition increases this rank; repeated phases return a real paid R.
    for _ in 0..<7 {
      switch phase {
      case .ready:
        throw UtilityCombatFailure.refused("combat phase completed without a command")
      case .brake, .brakeReturn:
        if !own.stopped {
          guard brakeRemaining > 0 else { throw UtilityCombatFailure.refused("actual stop deadline") }
          brakeRemaining -= 1
          result.throttle = -1
          return result
        }
        if phase == .brake {
          phase = .yawGoal
          axisRemaining = yawBudget
        } else {
          phase = .yawAim
          axisRemaining = yawBudget
        }
      case .yawGoal, .pitchGoal, .yawAim, .pitchAim:
        guard own.stopped, axisRemaining > 0 else {
          throw UtilityCombatFailure.refused("turn requires actual stop and paid deadline")
        }
        let aiming = phase == .yawAim || phase == .pitchAim
        let selectedGuide = aiming ? anchor : goal
        // An already attained shoulder has no outbound bearing; complete it before turning.
        if !aiming && frame.player == selectedGuide {
          guard exteriorContains(frame.player) else {
            throw UtilityCombatFailure.refused("invalid exterior stopping frame")
          }
          reachedShoulder = true
          phase = .brakeReturn
          continue
        }
        let direction = frame.model.apply(selectedGuide - frame.player)
        let directionIsFinite = direction.finite
        // Retain the norm only when the original short-circuit reached its evaluation.
        let directionLength = directionIsFinite ? direction.length : nil
        guard directionIsFinite, let directionLength,
          directionLength.isFinite, directionLength > 0
        else {
          throw UtilityCombatBearingRefusal(
            original: .refused("degenerate combat bearing"), phase: diagnosticPhase,
            aiming: aiming, selectedGuide: selectedGuide, direction: direction,
            directionIsFinite: directionIsFinite, directionLength: directionLength,
            sourcePlayer: frame.player, sourceModel: frame.model,
            anchor: anchor, origin: origin, normal: normal, tangent: tangent,
            floor: floor, width: width, side: side,
            reachedShoulder: reachedShoulder, axisRemaining: axisRemaining)
        }
        let yaw = phase == .yawGoal || phase == .yawAim
        if yaw && direction.x == 0 && direction.z < 0 {
          throw UtilityCombatFailure.refused("ambiguous antiparallel combat bearing")
        }
        let angle = yaw ? atan2(direction.x, direction.z) : atan2(direction.y, hypot(direction.x, direction.z))
        let limit = (yaw ? own.craft.yaw : own.craft.pitch) * step
        let input = try normalized(angle / limit)
        axisRemaining -= 1
        // Cache only the bearing already calculated for this actual command.
        previousTurn = latestTurn
        latestTurn = .init(phase: diagnosticPhase, angle: angle, remaining: axisRemaining)
        result.throttle = -1
        if yaw { result.yaw = input } else { result.pitch = input }
        if abs(angle) <= limit {
          switch phase {
          case .yawGoal: phase = .pitchGoal; axisRemaining = pitchBudget
          case .pitchGoal:
            phase = .travel
            let travel = goal - frame.player
            guard travel.length.isFinite, travel.length > 0 else {
              throw UtilityCombatFailure.refused("degenerate shoulder guide")
            }
            travelDirection = travel * (1 / travel.length)
          case .yawAim: phase = .pitchAim; axisRemaining = pitchBudget
          case .pitchAim:
            phase = .ready
            if reachedShoulder { side = -side }
          default: throw UtilityCombatFailure.refused("invalid turn phase")
          }
        }
        return result
      case .travel:
        let motion = own.motion.length
        let acceleration = own.craft.acceleration * 18
        let distance = (goal - frame.player).length
        let margin = normal.dot(frame.player) - floor
        let direction = frame.model.transposed.apply(.init(0, 0, 1))
        let velocity = frame.model.transposed.apply(own.motion)
        let stopping = motion * motion / (2 * acceleration) + motion * step
        guard distance.isFinite, margin.isFinite, margin >= 0, stopping.isFinite else {
          throw UtilityCombatFailure.refused("invalid exterior stopping frame")
        }
        reachedShoulder = reachedShoulder || (frame.player - goal).dot(travelDirection) >= 0
        if reachedShoulder || distance <= stopping || credit <= recoveryReserve {
          phase = .brakeReturn
          brakeRemaining = try deadline(motion / (acceleration * step))
          continue
        }
        guard credit > recoveryReserve else {
          throw UtilityCombatFailure.refused("outbound recovery reserve")
        }
        let inward = direction.dot(normal) < 0 || velocity.dot(normal) < 0
        guard !inward || margin >= stopping else {
          throw UtilityCombatFailure.refused("inward exterior stopping margin")
        }
        let available = inward ? min(distance, margin) : distance
        let root = step * step + 2 * available / acceleration
        guard root.isFinite, root >= 0 else { throw UtilityCombatFailure.refused("invalid speed goal") }
        let speed = min(own.craft.speed * 18, max(0, acceleration * (sqrt(root) - step)))
        result.throttle = try normalized((speed - motion) / (acceleration * step))
        return result
      }
    }
    throw UtilityCombatFailure.refused("combat phase rank exhausted")
  }
}

private enum UtilityCombatObservationSite: String, Sendable {
  case decision, blocked, preF, postF
}

/// Ordered value checks preserve the original guard's lazy refusal boundary.
private func utilityCombatAuthority(
  _ condition: Bool, at site: UtilityCombatObservationSite, field: String
) throws {
  guard condition else {
    throw UtilityCombatFailure.refused(
      "unsupported actual combat authority or resources "
        + "[\(site.rawValue):\(field)=false; laterChecks=not-evaluated]")
  }
}

private func utilityCombatActorText(_ actor: ActorIdentity?) -> String {
  guard let actor else { return "nil" }
  return "\(actor.system.galaxy)/\(actor.system.system)/\(actor.visit)/\(actor.entity)"
}

private func utilityCombatVectorText(_ vector: Vector3) -> String {
  "\(vector.x),\(vector.y),\(vector.z)"
}

private func utilityCombatPoseText(_ pose: ShipPose) -> String {
  "p=\(utilityCombatVectorText(pose.position)) x=\(utilityCombatVectorText(pose.orientation.x))"
    + " y=\(utilityCombatVectorText(pose.orientation.y)) z=\(utilityCombatVectorText(pose.orientation.z))"
}

/// Non-numeric source labels are explicitly a sanitized ASCII prefix, never arbitrary log text.
private func utilityCombatLabelPrefix(_ value: String?) -> String {
  guard let value else { return "nil" }
  let peek = Array(value.utf8.prefix(33))
  let bytes = peek.prefix(32).map { byte -> UInt8 in
    if (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
      || [45, 46, 47, 58, 95].contains(byte) { return byte }
    return 63
  }
  return String(decoding: bytes, as: UTF8.self) + (peek.count > 32 ? "~truncated" : "")
}

private func utilityCombatBoundedText(_ value: String, limit: Int, marker: String) -> String {
  if value.utf8.prefix(limit + 1).count <= limit { return value }
  var bytes = Array(value.utf8.prefix(limit - marker.utf8.count))
  while !bytes.isEmpty && String(bytes: bytes, encoding: .utf8) == nil { bytes.removeLast() }
  return (String(bytes: bytes, encoding: .utf8) ?? "") + marker
}

private func utilityCombatIncidentText(_ incident: CombatIncident) -> String {
  let origin = incident.origin
  let text = "id=\(incident.id) t=\(incident.physicalTime) e=\(origin.emissionID) et=\(origin.emittedAt)"
    + " o=\(utilityCombatActorText(origin.owner)) v=\(utilityCombatActorText(incident.victim))"
    + " ord=\(utilityCombatActorText(origin.ordnance)) k=\(incident.kind.rawValue)"
    + " out=\(incident.outcome.rawValue) laser=\(incident.laser?.rawValue ?? "nil")"
    + " mount=\(incident.mount?.rawValue ?? "nil") impact=\(utilityCombatVectorText(incident.position))"
    + " oLegal=\(origin.ownerLegalAtEmission.value),\(origin.ownerLegalAtEmission.bountyTenths)"
    + " vLegal=\(incident.victimLegalBeforeAttack.map { String($0.value) } ?? "nil")"
    + " first=\(utilityCombatActorText(incident.firstAggressor))"
    + " victimRole=\(incident.victimRole?.rawValue ?? "nil") station=\(incident.victimIsStation)"
    + " partPrefix32=\(utilityCombatLabelPrefix(origin.sourcePart))"
  return utilityCombatBoundedText(text, limit: 1024, marker: " [trace-row-truncated]")
}

private func utilityCombatIntentText(_ action: NPCAction?) -> String {
  guard let action else { return "nil" }
  switch action {
  case .engage(let actor): return "engage:" + utilityCombatActorText(actor)
  case .flee(let actor): return "flee:" + utilityCombatActorText(actor)
  case .dock(let actor): return "dock:" + utilityCombatActorText(actor)
  case .navigate(let position, let speed):
    return "navigate:p=" + utilityCombatVectorText(position) + " speed=\(speed)"
  case .mine: return "mine"
  case .scoop: return "scoop"
  }
}

/// Raw current body leaves only. Neither this formatter nor a match count grants authority.
private func utilityCombatBodyText(_ body: SpaceBody?) -> String {
  guard let body else { return "not-observed-within-prefix" }
  var text = "id=\(body.id) actor=\(utilityCombatActorText(body.physical?.identity))"
    + " roleAtObservation=\(body.physical?.npc?.role.rawValue ?? "nil")"
    + " producerAtObservation=\(body.physical?.spawnIdentity?.producer.rawValue ?? "nil")"
    + " cataloguePrefix32=\(utilityCombatLabelPrefix(body.physical?.catalogueShipID))"
    + " hullPrefix32=\(utilityCombatLabelPrefix(body.hull.modelName))"
    + " E=\(body.energy) cameraP=\(utilityCombatVectorText(body.position))"
    + " cameraX=\(utilityCombatVectorText(body.orientation.x))"
    + " cameraY=\(utilityCombatVectorText(body.orientation.y))"
    + " cameraZ=\(utilityCombatVectorText(body.orientation.z)) rotation=\(body.rotation) rate=\(body.rotationRate)"
    + " hostile=\(body.hostile) missiles=\(body.missiles) scriptNPC=\(body.scriptNPC != nil)"
    + " scriptShot=\(body.scriptShot != nil) mission=\(body.missionInstanceID != nil)"
    + " missionActor=\(body.missionActorID != nil) nativeStation=\(body.nativeStationIdentity != nil)"
  if let physical = body.physical {
    text += " actor=\(utilityCombatActorText(physical.identity)) population=\(physical.population.rawValue)"
      + " cataloguePrefix32=\(utilityCombatLabelPrefix(physical.catalogueShipID))"
      + " physicalV=\(utilityCombatVectorText(physical.velocity))"
      + " physicalAngular=\(utilityCombatVectorText(physical.angularVelocity))"
      + " canonicalSpin=\(physical.canonicalSpin.map { String($0) } ?? "nil")"
      + " laserCooldown=\(physical.laserCooldown) ordnance=\(physical.ordnance != nil)"
      + " empSource=\(physical.empSource != nil) empPod=\(physical.empCrewPod != nil)"
    if let spawn = physical.spawnIdentity {
      text += " spawn=\(spawn.system.galaxy)/\(spawn.system.system)/\(spawn.visit)"
        + "/\(spawn.sequence)/\(spawn.member) producer=\(spawn.producer.rawValue)"
    } else { text += " spawn=nil producer=nil" }
    if let npc = physical.npc {
      text += " role=\(npc.role.rawValue) legal=\(npc.legal.value),\(npc.legal.bountyTenths)"
        + " provenance=\(npc.legalProvenance?.rawValue ?? "nil")"
        + ",\(npc.cargoProvenance?.rawValue ?? "nil"),\(npc.routeProvenance?.rawValue ?? "nil")"
        + " first=\(utilityCombatActorText(npc.firstAggressor)) intent=\(utilityCombatIntentText(npc.intention))"
        + " route=\(npc.origin.galaxy)/\(npc.origin.system)->\(npc.destination.galaxy)/\(npc.destination.system)"
      if let resources = npc.resources {
        text += " resources=\(resources.profile.rawValue) energyCap=\(resources.energyCapacity)"
          + " recharge=\(resources.energyRecharge) shields=\(resources.frontShield),\(resources.rearShield)"
          + " shieldCaps=\(resources.frontCapacity),\(resources.rearCapacity) shieldRecharge=\(resources.shieldRecharge)"
          + " heat=\(resources.laserHeat)/\(resources.heatCapacity) cooling=\(resources.heatCooling)"
          + " fuel=\(resources.fuel.map { String($0) } ?? "nil")"
          + "/\(resources.fuelCapacity.map { String($0) } ?? "nil") electrical=\(resources.electrical != nil)"
      } else { text += " resources=nil" }
    } else { text += " role=nil npc=nil" }
  } else { text += " physical=nil" }
  return utilityCombatBoundedText(text, limit: 4096, marker: " [body-truncated]")
}

/// Fixed-size test observations; neither drives controls nor establishes current source health.
private struct UtilityCombatTurnObservation {
  let phase: String
  let angle: Double
  let remaining: Int
  var diagnostic: String { "ph=\(phase) angle=\(angle) left=\(remaining)" }
}

private struct UtilityCombatCommandObservation {
  let kind: String
  let time: Double
  let energy: Double
  let frontShield: Double
  let rearShield: Double
  let revision: UInt64
  let impactRevision: UInt64?
  let sourceEnergy: Double
  let input: Controls
  let pose: ShipPose
  let motion: Vector3
  let legal: Int
  var postSourceEnergy: Double?
  var beforeTraceEpoch: UUID?
  var maneuverF: Bool?
  var woundDecreasedPassed = false
  var currentWound: Bool?
  var terminalSeen = false
  var validationEntered = false
  var validationReturned = false
  var woundGuardPassed = false
  var authenticatedHit = false
  var awardCommitted = false
  var diagnostic: String {
    "kind=\(kind) t=\(time) E=\(energy) shields=\(frontShield),\(rearShield)"
      + " rev=\(revision) impact=\(impactRevision.map { String($0) } ?? "nil")"
      + " sourceE=\(sourceEnergy) input=\(input.fire),\(input.pitch),\(input.yaw),\(input.roll),\(input.throttle)"
      + " beforePose=[\(utilityCombatPoseText(pose))] motion=\(utilityCombatVectorText(motion)) legal=\(legal)"
      + " postSourceE=\(postSourceEnergy.map { String($0) } ?? "not-observed")"
      + " beforeTraceEpoch=\(beforeTraceEpoch?.uuidString ?? "not-recorded")"
      + " maneuverF=\(maneuverF.map { String($0) } ?? "NE")"
      + " stages=woundDecreased:\(woundDecreasedPassed),currentWound:\(currentWound.map { String($0) } ?? "NE")"
      + ",terminal:\(terminalSeen),validationEntered:\(validationEntered),validationReturned:\(validationReturned)"
      + ",woundGuardPassed:\(woundGuardPassed),authenticatedHit:\(authenticatedHit),awardCommitted:\(awardCommitted)"
  }
}

/// The existing failure-only exact-player trace consumer, shared by mutually exclusive throw paths.
private func utilityCombatPlayerIncidents(_ trace: GameplayCombatTrace?, player: ActorIdentity?)
  -> (hit: CombatIncident?, destruction: CombatIncident?, scanned: Int, history: String)
{
  var lastPlayerHit: CombatIncident? = nil
  var lastPlayerDestruction: CombatIncident? = nil
  var traceScanned = 0
  var history = ""
  if let trace {
    for incident in trace.incidents.suffix(128).reversed() {
      traceScanned += 1
      history += utilityCombatIncidentText(incident) + "\n"
      guard let player, let victim = incident.victim, victim == player else { continue }
      if lastPlayerHit == nil && incident.outcome == .hit { lastPlayerHit = incident }
      if lastPlayerDestruction == nil && incident.outcome == .destruction {
        lastPlayerDestruction = incident
      }
    }
  }
  return (lastPlayerHit, lastPlayerDestruction, traceScanned, history)
}

// Attempt-local owners keep combat planning and validation outside the native-step activation.
private typealias UtilityCombatTargetContact = (
  source: NativeStationSourceBinding, body: SpaceBody, contact: MissionCollisionContact?
)

private final class UtilityCombatAttempt {
  enum State { case unprepared, active(UtilityCombatWork) }
  let destination: URL
  let utility: NativeUtilityState
  let initial: NativeStationRecord
  let before: NativeUtilityEngineerCasualty?
  var state = State.unprepared

  init(
    destination: URL, utility: NativeUtilityState, initial: NativeStationRecord,
    before: NativeUtilityEngineerCasualty?
  ) {
    self.destination = destination
    self.utility = utility
    self.initial = initial
    self.before = before
  }
}

private final class UtilityCombatWork {
  enum Phase {
    case beginAttempt, recovery, afterRecovery, rearShield(UtilityCombatPause)
    case contact(UtilityCombatTargetContact), blocked(remaining: Int)
    case afterBlocked, fire(UtilityCombatTargetContact), finished
  }
  let binding: NativeStationSourceBinding
  let maximumShots: Int
  let sourceBinding: NativeStationBinding
  let playerMesh: Mesh
  let combatShipID: String
  let playerRadius: Double
  let sourceRadius: Double
  let sourceSavedPose: NativeStationSavedPose
  var ledger: UtilityCombatLedger
  var controller: UtilityCombatController
  var attackRecord: NativeStationRecord
  var lastCommand: UtilityCombatCommandObservation?
  // One perishable checkpoint in this existing test consumer, never a history or authority.
  var manualPairHoldDecisionObserved = false
  var manualPairAdmissionObserved = false
  var firstEligibleManualPair: String?
  var usedRearShieldPause: Bool
  var firing: Controls
  var attemptIndex = 0
  var maneuveredForPendingFire = false
  var maneuverFire = false
  var maneuverContact: UtilityCombatTargetContact?
  var phase = Phase.beginAttempt

  init(
    binding: NativeStationSourceBinding, maximumShots: Int, sourceBinding: NativeStationBinding,
    playerMesh: Mesh, combatShipID: String, playerRadius: Double, sourceRadius: Double,
    sourceSavedPose: NativeStationSavedPose, ledger: UtilityCombatLedger,
    controller: UtilityCombatController, attackRecord: NativeStationRecord,
    lastCommand: UtilityCombatCommandObservation?, usedRearShieldPause: Bool, firing: Controls
  ) {
    self.binding = binding
    self.maximumShots = maximumShots
    self.sourceBinding = sourceBinding
    self.playerMesh = playerMesh
    self.combatShipID = combatShipID
    self.playerRadius = playerRadius
    self.sourceRadius = sourceRadius
    self.sourceSavedPose = sourceSavedPose
    self.ledger = ledger
    self.controller = controller
    self.attackRecord = attackRecord
    self.lastCommand = lastCommand
    self.usedRearShieldPause = usedRearShieldPause
    self.firing = firing
  }
}

private final class UtilityCombatPause {
  enum Stage: Equatable {
    case yawAway, pitchAway, hold, brake, yawSource, pitchSource, returned

    // Pure command policy; the original driver charges every emitted release once.
    mutating func holdOrBrake(
      outward: Bool, returnReserve: Int, ledger: UtilityCombatLedger
    ) throws -> Controls {
      var command = Controls()
      command.throttle = -1
      switch self {
      case .hold:
        if outward {
          let pulseReserve = try utilityCombatSum(returnReserve, 2)
          if ledger.credit >= pulseReserve,
            ledger.maximumCalls - ledger.calls >= pulseReserve
          {
            command.throttle = 1
            self = .brake
          }
        }
      case .brake:
        self = .yawSource
      default:
        throw UtilityCombatFailure.refused("hold or paired brake required")
      }
      return command
    }
  }
  let controller: UtilityCombatController
  let own: UtilityCombatOwn
  let hit: CombatIncident
  let attacker: SpaceBody
  let physical: PhysicalActorState
  let spawn: SpawnIdentity
  let resources: NPCResources
  let yawBudget: Int
  let pitchBudget: Int
  let returnReserve: Int
  let away: Vector3
  var stage = Stage.yawAway
  var remaining: Int

  init(
    controller: UtilityCombatController, own: UtilityCombatOwn, hit: CombatIncident,
    attacker: SpaceBody, physical: PhysicalActorState, spawn: SpawnIdentity,
    resources: NPCResources, yawBudget: Int, pitchBudget: Int, returnReserve: Int, away: Vector3
  ) {
    self.controller = controller
    self.own = own
    self.hit = hit
    self.attacker = attacker
    self.physical = physical
    self.spawn = spawn
    self.resources = resources
    self.yawBudget = yawBudget
    self.pitchBudget = pitchBudget
    self.returnReserve = returnReserve
    self.away = away
    remaining = yawBudget
  }
}

private final class UtilityCombatStep {
  enum Continuation {
    case rearShield(UtilityCombatPause, pose: ShipPose, time: Double, impact: UInt64?)
    case release(time: Double)
    case blocked(time: Double, remaining: Int)
    case fire(
      pose: ShipPose, time: Double, impact: UInt64?, energy: Double,
      incident: UInt64, emission: UInt64, traceEpoch: UUID)
  }
  let work: UtilityCombatWork
  let command: Controls
  let epoch: UUID
  let delta: Double
  let stopsControls: Bool
  let continuation: Continuation

  init(
    work: UtilityCombatWork, command: Controls, epoch: UUID, delta: Double,
    stopsControls: Bool, continuation: Continuation
  ) {
    self.work = work
    self.command = command
    self.epoch = epoch
    self.delta = delta
    self.stopsControls = stopsControls
    self.continuation = continuation
  }
}

extension GameRuntime {
  private func utilityCombatValidateStep(
    _ controller: UtilityCombatController, utility: NativeUtilityState,
    binding: NativeStationSourceBinding, saved: NativeStationSavedPose,
    player: Mesh, shipID: String, playerRadius: Double, sourceRadius: Double,
    from before: ShipPose, time beforeTime: Double, impact beforeImpact: UInt64?
  ) throws {
    let flight = game.commander.flightSimulation
    let afterTime = flight.physicalTime
    guard before.position.finite, before.orientation.validRotation,
      flight.pose.position.finite, flight.pose.orientation.validRotation,
      beforeTime.isFinite, afterTime.isFinite, afterTime > beforeTime,
      afterTime == beforeTime + controller.step,
      flight.player == controller.player, game.commander.shipID == shipID,
      game.commander.equipmentOwnerID == controller.owner,
      game.commander.hullInstanceID == controller.carrier,
      game.nativeStationRuntimeEpoch == controller.stationEpoch,
      game.ecmControl.epoch == controller.commandEpoch,
      game.screen == .front, !game.docked, !game.paused, game.energy.isFinite, game.energy > 0,
      game.pendingNativeStationDock == nil, game.stationImpactRevision == beforeImpact,
      let world = game.commander.nativeStations, world.ledger.world == controller.owner,
      saved.station == utility.target, let currentSaved = world.pose(for: utility.target),
      currentSaved.valid, currentSaved.station == saved.station,
      currentSaved.position == saved.position, currentSaved.orientation == saved.orientation,
      let fromPosition = world.currentPosition(
        for: .originalStation(utility.target), at: beforeTime),
      let toPosition = world.currentPosition(
        for: .originalStation(utility.target), at: afterTime),
      let fromOrientation = world.currentOrientation(for: utility.target, at: beforeTime),
      let toOrientation = world.currentOrientation(for: utility.target, at: afterTime)
    else { throw UtilityCombatFailure.refused("actual moving F interval or source frame changed") }
    // This is the real retained source frame, including on a terminal native step.
    let localPlayer = toOrientation.transposed.apply(flight.pose.position - toPosition)
    let translationMargin = world.stationSweepMargin(
      .originalStation(utility.target), from: beforeTime, to: afterTime)
    let displacement = (flight.pose.position - before.position).length
      + (toPosition - fromPosition).length + translationMargin
    let angle = (abs(game.pitch) + abs(game.roll) + abs(game.yaw) + binding.rotationRate)
      * controller.step
    let margin = (sourceRadius + playerRadius + displacement) * angle + translationMargin
    guard controller.exteriorContains(localPlayer),
      fromPosition.finite, toPosition.finite,
      fromOrientation.validRotation, toOrientation.validRotation,
      playerRadius.isFinite, playerRadius > 0, sourceRadius.isFinite, sourceRadius > 0,
      translationMargin.isFinite, translationMargin >= 0,
      displacement.isFinite, displacement >= 0, angle.isFinite, angle >= 0,
      margin.isFinite, margin >= 0,
      game.nativeStationHullSweepClear(
        player, from: before, to: flight.pose, saved: currentSaved,
        fromOrientation: fromOrientation, toOrientation: toOrientation,
        margin: margin, mesh: binding.geometry.mesh,
        fromPosition: fromPosition, toPosition: toPosition)
    else { throw UtilityCombatFailure.refused("actual moving F exterior or native hull sweep refused") }
  }

  /// Spend one existing R bank on the stronger rear shield, then regain the source bearing.
  private func utilityCombatPrepareRearShieldPause(
    _ work: UtilityCombatWork, own: UtilityCombatOwn, utility: NativeUtilityState
  ) throws -> UtilityCombatPause? {
    let controller = work.controller
    guard !controller.active, own.stopped,
      game.frontShield.isFinite, game.rearShield.isFinite,
      game.frontShield >= 0, game.frontShield < game.rearShield,
      game.rearShield > 0, own.craft.yaw.isFinite, own.craft.yaw > 0,
      own.craft.pitch.isFinite, own.craft.pitch > 0,
      let hit = game.gameplayCombatTrace?.incidents.suffix(128).reversed().first(where: {
        $0.victim == controller.player && $0.origin.owner != controller.player
          && $0.outcome == .hit && $0.kind == .laser && $0.laser == .pulse
          && $0.mount == .front && $0.origin.ordnance == nil
      }),
      hit.origin.owner.system == controller.player.system,
      hit.origin.owner.visit == controller.player.visit
    else { return nil }
    let matches = game.bodies.filter { $0.physical?.identity == hit.origin.owner }
    guard matches.count == 1, let attacker = matches.first,
      attacker.energy.isFinite, attacker.energy > 1, attacker.position.finite,
      attacker.position.length.isFinite, attacker.position.length > 0,
      attacker.hull.isTargetShip, attacker.scriptNPC == nil, attacker.scriptShot == nil,
      attacker.missionInstanceID == nil, attacker.missionActorID == nil,
      attacker.nativeStationIdentity == nil, !game.isEMPDisabled(attacker),
      let physical = attacker.physical, physical.population == .civilian,
      physical.empSource == nil, physical.empCrewPod == nil, physical.ordnance == nil,
      physical.payload == nil, let spawn = physical.spawnIdentity,
      spawn.system == controller.player.system, spawn.visit == controller.player.visit,
      let npc = physical.npc, npc.intention == .engage(controller.player),
      let resources = npc.resources, resources.valid, resources.profile == .legacyEnergyOnly,
      resources.energyRecharge == 0, resources.frontCapacity == 0, resources.rearCapacity == 0
    else { return nil }
    let yawBudget = try utilityCombatSum(
      utilityCombatInteger(ceil(.pi / (own.craft.yaw * controller.step))), 1)
    let pitchBudget = try utilityCombatSum(
      utilityCombatInteger(ceil(.pi / (own.craft.pitch * controller.step))), 1)
    let returnReserve = try utilityCombatSum(yawBudget, pitchBudget)
    let admissionReserve = try utilityCombatSum(returnReserve, returnReserve, 1)
    guard work.ledger.credit >= admissionReserve,
      work.ledger.maximumCalls - work.ledger.calls >= admissionReserve
    else { return nil }
    // This is an observed direction, not a prediction of the emitter's later pose.
    let away = game.commander.flightSimulation.pose.orientation.apply(attacker.position * -1)
    guard away.finite, away.length.isFinite, away.length > 0 else { return nil }
    return .init(
      controller: controller, own: own, hit: hit, attacker: attacker, physical: physical,
      spawn: spawn, resources: resources, yawBudget: yawBudget, pitchBudget: pitchBudget,
      returnReserve: returnReserve, away: away)
  }

  private func utilityCombatPlanRearShieldPause(
    _ pause: UtilityCombatPause, work: UtilityCombatWork, utility: NativeUtilityState
  ) throws -> UtilityCombatStep? {
    let controller = pause.controller
    let own = pause.own
    let hit = pause.hit
    let attacker = pause.attacker
    let physical = pause.physical
    let spawn = pause.spawn
    let resources = pause.resources
    let yawBudget = pause.yawBudget
    let pitchBudget = pause.pitchBudget
    let returnReserve = pause.returnReserve
    let away = pause.away
    while true {
      if pause.stage == .hold { work.manualPairHoldDecisionObserved = true }
      let current = try utilityCombatOwn(controller, at: .decision,
        ledger: work.ledger, lastCommand: work.lastCommand, work: work)
      let sourceMatches = game.bodies.filter { $0.nativeStationIdentity == utility.target }
      guard (current.stopped || pause.stage == .brake), current.craft.yaw == own.craft.yaw,
        current.craft.pitch == own.craft.pitch,
        sourceMatches.count == 1, let source = sourceMatches.first,
        source.id == controller.sourceBodyID, source.physical?.identity == controller.source,
        game.nativeStationBodyIsCurrent(source),
        let record = game.commander.nativeStations?.ledger.records.first(where: {
          $0.identity == utility.target
        }), record.tombstone == nil,
        record.binding?.actor == controller.source, record.binding?.bodyID == source.id
      else { throw UtilityCombatFailure.refused("rear shield pause source or stop changed") }
      let frame = try UtilityCombatFrame(body: source)
      let currentMatches = game.bodies.filter { $0.physical?.identity == hit.origin.owner }
      var currentAttacker: SpaceBody?
      if currentMatches.count == 1, let body = currentMatches.first,
        body.id == attacker.id, body.hull == attacker.hull,
        body.energy.isFinite, body.energy >= 0, body.position.finite,
        body.position.length.isFinite, body.position.length > 0,
        body.scriptNPC == nil, body.scriptShot == nil, body.missionInstanceID == nil,
        body.missionActorID == nil, body.nativeStationIdentity == nil, !game.isEMPDisabled(body),
        let actor = body.physical, actor.population == physical.population,
        actor.spawnIdentity == spawn, actor.empSource == nil, actor.empCrewPod == nil,
        actor.ordnance == nil, actor.payload == nil,
        let condition = actor.npc, condition.intention == .engage(controller.player),
        let actualResources = condition.resources, actualResources.valid,
        actualResources.profile == resources.profile, actualResources.energyRecharge == 0,
        actualResources.frontCapacity == 0, actualResources.rearCapacity == 0
      { currentAttacker = body }
      switch pause.stage {
      case .yawAway, .pitchAway, .hold:
        // Any lost opportunity ends the diversion; its bank still belongs to the return.
        if currentAttacker == nil || (currentAttacker?.energy ?? 0) <= 1
          || work.ledger.credit <= returnReserve
          || work.ledger.maximumCalls - work.ledger.calls <= returnReserve
        {
          pause.stage = .yawSource
          pause.remaining = yawBudget
        }
      case .brake, .yawSource, .pitchSource, .returned: break
      }
      if pause.stage == .returned {
        let bearing = controller.sourceAnchorDirection(in: frame)
        guard bearing.finite, bearing.length.isFinite, bearing.length > 0, bearing.z > 0,
          abs(atan2(bearing.x, bearing.z)) <= current.craft.yaw * controller.step,
          abs(atan2(bearing.y, hypot(bearing.x, bearing.z))) <= current.craft.pitch * controller.step
        else { throw UtilityCombatFailure.refused("actual rear shield return bearing unavailable") }
        // The caller's unchanged fresh native source-first contact still admits the next F.
        try utilityCombatCompleteRearShieldPause(work, utility: utility)
        return nil
      }
      var command = Controls()
      command.throttle = -1
      switch pause.stage {
      case .hold:
        guard let body = currentAttacker, body.position.z < 0,
          game.frontShield.isFinite, game.rearShield.isFinite,
          game.rearShield > game.frontShield, game.rearShield > 0
        else {
          pause.stage = .yawSource
          pause.remaining = yawBudget
          continue
        }
        let funded = work.ledger.credit >= returnReserve + 2
          && work.ledger.maximumCalls - work.ledger.calls >= returnReserve + 2
        let exterior = controller.manualPairExterior
        // Preserve the original short-circuit order; consume each existing result once.
        let outward: Bool? = funded ? controller.admitsOutwardPulse(in: frame) : nil
        let firstInput: String?
        if work.firstEligibleManualPair == nil, funded, outward == true {
          let flight = game.commander.flightSimulation
          firstInput = "phase=\(controller.diagnosticPhase) pauseStage=hold t=\(flight.physicalTime)"
            + " gameT=\(game.time) rev=\(game.gameplayRevision) screen=\(game.screen.rawValue)"
            + " E=\(game.energy) shields=\(game.frontShield),\(game.rearShield)"
            + " X=\(work.ledger.invoked) A=\(work.ledger.qualified) R=\(work.ledger.released)"
            + " K=\(work.ledger.calls) credit=\(work.ledger.credit) returnReserve=\(returnReserve)"
            + " funded=true renderedOutward=true step=\(controller.step)"
            + " player=\(utilityCombatActorText(flight.player)) owner=\(controller.owner)"
            + " equipmentOwner=\(String(describing: game.commander.equipmentOwnerID))"
            + " carrier=\(controller.carrier) activeHull=\(String(describing: game.commander.hullInstanceID))"
            + " worldOwner=\(String(describing: game.commander.nativeStations?.ledger.world))"
            + " target=\(String(describing: utility.target)) sourceActor=\(utilityCombatActorText(source.physical?.identity))"
            + " sourceTarget=\(String(describing: source.nativeStationIdentity))"
            + " sourceBody=\(source.id) lockedSourceActor=\(utilityCombatActorText(controller.source))"
            + " lockedSourceBody=\(controller.sourceBodyID) sourceE=\(source.energy)"
            + " sourceEpoch=\(game.nativeStationRuntimeEpoch) commandEpoch=\(game.ecmControl.epoch)"
            + " lockedSourceEpoch=\(controller.stationEpoch) lockedCommandEpoch=\(controller.commandEpoch)"
            + " attacker=\(utilityCombatActorText(body.physical?.identity)) attackerBody=\(body.id)"
            + " nativeSourceCurrentAndOwnerGuards=already-passed"
            + " pose=[\(utilityCombatPoseText(flight.pose))] motion=\(utilityCombatVectorText(current.motion))"
            + " renderedSourcePlayer=\(utilityCombatVectorText(frame.player))"
            + " normal=\(utilityCombatVectorText(exterior.normal)) floor=\(exterior.floor)"
            + " traceEpoch=\(game.gameplayCombatTrace?.epoch.uuidString ?? "nil")"
            + " droppedAtFirst=\(game.gameplayCombatTrace.map { String($0.dropped) } ?? "nil")"
            + " beforeCommand=[\(work.lastCommand?.diagnostic ?? "nil")]"
        } else { firstInput = nil }
        let nativeAdmission: Bool?
        if funded, outward == true {
          nativeAdmission = game.admitManualControlPair(
            source: utility.target, actor: controller.source, bodyID: controller.sourceBodyID,
            exteriorNormal: exterior.normal, exteriorFloor: exterior.floor, delta: controller.step)
        } else { nativeAdmission = nil }
        if nativeAdmission == true { work.manualPairAdmissionObserved = true }
        if let firstInput, let nativeAdmission {
          let disposition = nativeAdmission ? "admitted" : "refused-detailed-reason-not-exposed-by-Bool-API"
          work.firstEligibleManualPair = utilityCombatBoundedText(
            "nativeAdmission=\(nativeAdmission) disposition=\(disposition) " + firstInput,
            limit: 4096, marker: " [first-eligible-input-truncated]")
        }
        let admitted = nativeAdmission ?? false
        command = try pause.stage.holdOrBrake(
          outward: admitted, returnReserve: returnReserve, ledger: work.ledger)
      case .brake:
        command = try pause.stage.holdOrBrake(
          outward: false, returnReserve: returnReserve, ledger: work.ledger)
        pause.remaining = yawBudget
      case .yawAway, .pitchAway, .yawSource, .pitchSource:
        guard pause.remaining > 0 else {
          throw UtilityCombatFailure.refused("actual rear shield turn deadline")
        }
        let returning = pause.stage == .yawSource || pause.stage == .pitchSource
        let bearing = returning ? controller.sourceAnchorDirection(in: frame)
          : game.commander.flightSimulation.pose.orientation.transposed.apply(away)
        guard bearing.finite, bearing.length.isFinite, bearing.length > 0 else {
          throw UtilityCombatFailure.refused("actual rear shield bearing unavailable")
        }
        let yaw = pause.stage == .yawAway || pause.stage == .yawSource
        if yaw && bearing.x == 0 && bearing.z < 0 {
          throw UtilityCombatFailure.refused("ambiguous antiparallel rear shield bearing")
        }
        let angle = yaw ? atan2(bearing.x, bearing.z)
          : atan2(bearing.y, hypot(bearing.x, bearing.z))
        let limit = (yaw ? current.craft.yaw : current.craft.pitch) * controller.step
        let input = angle / limit
        guard input.isFinite else {
          throw UtilityCombatFailure.refused("nonfinite rear shield turn input")
        }
        if yaw { command.yaw = max(-1, min(1, input)) }
        else { command.pitch = max(-1, min(1, input)) }
        pause.remaining -= 1
        if abs(angle) <= limit {
          switch pause.stage {
          case .yawAway: pause.stage = .pitchAway; pause.remaining = pitchBudget
          case .pitchAway: pause.stage = .hold
          case .yawSource: pause.stage = .pitchSource; pause.remaining = pitchBudget
          case .pitchSource: pause.stage = .returned
          default: throw UtilityCombatFailure.refused("invalid rear shield turn stage")
          }
        }
      case .returned:
        throw UtilityCombatFailure.refused("rear shield return already completed")
      }
      let beforePose = game.commander.flightSimulation.pose
      let beforeTime = game.commander.flightSimulation.physicalTime
      let beforeImpact = game.stationImpactRevision
      work.lastCommand = utilityCombatCommandObservation(kind: "R", time: beforeTime,
        sourceEnergy: source.energy, input: command, pose: beforePose, motion: current.motion)
      try work.ledger.chargeRelease()
      return .init(
        work: work, command: command, epoch: controller.commandEpoch, delta: controller.step,
        stopsControls: true,
        continuation: .rearShield(pause, pose: beforePose, time: beforeTime, impact: beforeImpact))
    }
  }

  private func utilityCombatCompleteRearShieldPause(
    _ work: UtilityCombatWork, utility: NativeUtilityState
  ) throws {
    // This is the original rear-shield defer, before the caller observes its completed pause.
    setControls(Controls())
    work.phase = .recovery
    work.usedRearShieldPause = true
    guard let currentRecord = game.commander.nativeStations?.ledger.records.first(where: {
      $0.identity == utility.target
    }) else { throw UtilityCombatFailure.refused("rear shield pause lost source record") }
    work.attackRecord = currentRecord
  }

  private func utilityCombatCommandObservation(
    kind: String, time: Double, sourceEnergy: Double, input: Controls,
    pose: ShipPose, motion: Vector3
  ) -> UtilityCombatCommandObservation {
    .init(kind: kind, time: time, energy: game.energy,
      frontShield: game.frontShield, rearShield: game.rearShield,
      revision: game.gameplayRevision, impactRevision: game.stationImpactRevision,
      sourceEnergy: sourceEnergy, input: input, pose: pose, motion: motion,
      legal: game.commander.legal)
  }

  private func utilityCombatFailureContext(
    _ controller: UtilityCombatController, attacker: ActorIdentity?, player: ActorIdentity?,
    pose: ShipPose, motion: Vector3, lastCommand: UtilityCombatCommandObservation?
  ) -> String {
    var attackerBody: SpaceBody?
    var sourceBody: SpaceBody?
    var attackerMatches = 0
    var sourceActorMatches = 0
    var sourceIDMatches = 0
    var sourceExactMatches = 0
    var scanned = 0
    let bodies = game.bodies
    for body in bodies.prefix(512) {
      scanned += 1
      if let attacker, body.physical?.identity == attacker {
        attackerMatches += 1
        if attackerBody == nil { attackerBody = body }
      }
      if body.id == controller.sourceBodyID { sourceIDMatches += 1 }
      if body.physical?.identity == controller.source {
        sourceActorMatches += 1
        if body.id == controller.sourceBodyID {
          sourceExactMatches += 1
          if sourceBody == nil { sourceBody = body }
        }
      }
    }
    var text = "\nCURRENT_RAW attacker=\(utilityCombatActorText(attacker)) source=\(utilityCombatActorText(controller.source))"
      + " sourceBodyID=\(controller.sourceBodyID) bodies=\(bodies.count) scanned=\(scanned) incomplete=\(bodies.count > scanned)"
      + " attackerMatches=\(attackerMatches) sourceActorMatches=\(sourceActorMatches)"
      + " sourceIDMatches=\(sourceIDMatches) sourceExactMatches=\(sourceExactMatches)"
      + "\nATTACKER_FIRST_RAW [\(utilityCombatBodyText(attackerBody))]"
      + "\nSOURCE_FIRST_RAW [\(utilityCombatBodyText(sourceBody))]"
      + "\nAFTER_RETAINED pose=[\(utilityCombatPoseText(pose))] motion=\(utilityCombatVectorText(motion))"
      + " legal=\(game.commander.legal) positionChanged=\(lastCommand.map { String($0.pose.position != pose.position) } ?? "unknown")"
      + " orientationChanged=\(lastCommand.map { String($0.pose.orientation != pose.orientation) } ?? "unknown")"
      + " energyRechargeMultiplier=\(game.commander.energyRechargeMultiplier)"
      + " shieldCaps=\(game.commander.shieldCapacity),\(game.commander.rearShieldCapacity)"
      + " shieldRecharge=\(game.commander.frontShieldRecharge),\(game.commander.rearShieldRecharge)"
      + " stationEpoch=\(game.nativeStationRuntimeEpoch) commandEpoch=\(game.ecmControl.epoch)"
    if let world = game.commander.nativeStations {
      let target = game.commander.nativeUtility?.target
      var recordScanned = 0
      var poseScanned = 0
      var recordMatches = 0
      var poseMatches = 0
      var worldText = ""
      for record in world.ledger.records.prefix(64) {
        recordScanned += 1
        if let target, record.identity == target {
          recordMatches += 1
          worldText += " record=[rev=\(record.revision) tombstone=\(record.tombstone != nil)"
            + " actor=\(utilityCombatActorText(record.binding?.actor))"
            + " bodyID=\(record.binding.map { String($0.bodyID) } ?? "nil")]"
        }
      }
      for saved in world.poses.prefix(64) {
        poseScanned += 1
        if let target, saved.station == target {
          poseMatches += 1
          worldText += " saved=[E=\(saved.energy) p=\(utilityCombatVectorText(saved.position))"
            + " x=\(utilityCombatVectorText(saved.orientation.x))"
            + " y=\(utilityCombatVectorText(saved.orientation.y)) z=\(utilityCombatVectorText(saved.orientation.z))]"
        }
      }
      text += "\nWORLD_RAW owner=\(world.ledger.world) targetPresent=\(target != nil)"
        + " records=\(world.ledger.records.count) scanned=\(recordScanned) matches=\(recordMatches)"
        + " poses=\(world.poses.count) scanned=\(poseScanned) matches=\(poseMatches)"
        + " incomplete=\(world.ledger.records.count > recordScanned || world.poses.count > poseScanned)"
        + utilityCombatBoundedText(worldText, limit: 8192, marker: " [world-truncated]")
    } else { text += "\nWORLD_RAW nil" }
    let security = game.commander.stationSecurity
    var assignmentsScanned = 0
    var assignmentText = ""
    for assignment in security.assignments.prefix(32) {
      assignmentsScanned += 1
      let matchesAttacker = attacker.map { assignment.actor == $0 } ?? false
      let targetsPlayer = player.map { assignment.target == $0 } ?? false
      if matchesAttacker || targetsPlayer {
        let row = " officer=\(utilityCombatActorText(assignment.actor))"
          + " target=\(utilityCombatActorText(assignment.target)) phase=\(assignment.phase.rawValue)"
          + " contactAt=\(assignment.lastContactAt) lastKnown=\(utilityCombatVectorText(assignment.lastKnownPosition))"
        assignmentText += utilityCombatBoundedText(row, limit: 512, marker: " [assignment-truncated]") + "\n"
      }
    }
    text += "\nSECURITY_RAW phase=\(security.phase.rawValue) assignments=\(security.assignments.count)"
      + " scanned=\(assignmentsScanned) incomplete=\(security.assignments.count > assignmentsScanned)\n"
      + assignmentText
      + "UNAVAILABLE evictedTraceUnrecoverable=true intermediateTrajectory=not-recorded"
      + " priorMovingFPoses=not-recorded exactHistoricalDamage=not-recorded privateCrimeWindows=unavailable"
      + " privateSecurityThreats=unavailable rawBodiesAndStagesAreNotAuthority=true\n"
    return utilityCombatBoundedText(text, limit: 40960, marker: " [context-truncated]")
  }

  private func utilityCombatOwn(
    _ controller: UtilityCombatController, at site: UtilityCombatObservationSite,
    ledger: UtilityCombatLedger, lastCommand: UtilityCombatCommandObservation?, work: UtilityCombatWork
  ) throws -> UtilityCombatOwn {
    let player = game.commander.flightSimulation.player
    let pose = game.commander.flightSimulation.pose
    let craft = game.commander.performance
    let motion = game.autoPilot.velocity + Vector3(0, 0, game.speed * 18)
    do {
      try utilityCombatAuthority(
        player == controller.player,
        at: site, field: "playerIdentity")
      try utilityCombatAuthority(
        game.commander.equipmentOwnerID == controller.owner,
        at: site, field: "equipmentOwner")
      try utilityCombatAuthority(
        game.commander.hullInstanceID == controller.carrier,
        at: site, field: "hullCarrier")
      try utilityCombatAuthority(
        game.commander.nativeStations?.ledger.world == controller.owner,
        at: site, field: "worldOwner")
      try utilityCombatAuthority(
        game.nativeStationRuntimeEpoch == controller.stationEpoch,
        at: site, field: "stationEpoch")
      try utilityCombatAuthority(
        game.ecmControl.epoch == controller.commandEpoch,
        at: site, field: "commandEpoch")
      try utilityCombatAuthority(
        game.screen == .front,
        at: site, field: "frontView")
      try utilityCombatAuthority(
        !game.docked,
        at: site, field: "undocked")
      try utilityCombatAuthority(
        !game.paused,
        at: site, field: "unpaused")
      try utilityCombatAuthority(
        game.energy.isFinite,
        at: site, field: "finiteEnergy")
      try utilityCombatAuthority(
        game.energy > 0,
        at: site, field: "positiveEnergy")
      try utilityCombatAuthority(
        !game.playerEMPDisabled,
        at: site, field: "EMPAvailable")
      try utilityCombatAuthority(
        game.workGuidance == nil,
        at: site, field: "noWorkGuidance")
      try utilityCombatAuthority(
        game.workBraking == nil,
        at: site, field: "noWorkBraking")
      try utilityCombatAuthority(
        game.autoPilot.targetID == nil,
        at: site, field: "noAutopilotTarget")
      try utilityCombatAuthority(
        !game.dockingComputer,
        at: site, field: "noDockingComputer")
      try utilityCombatAuthority(
        !game.spin.mode,
        at: site, field: "noSpinMode")
      try utilityCombatAuthority(
        game.spin.actualRate == 0,
        at: site, field: "zeroSpinRate")
      try utilityCombatAuthority(
        game.jumpCountdown == nil,
        at: site, field: "noJumpCountdown")
      try utilityCombatAuthority(
        game.pendingNativeStationDock == nil,
        at: site, field: "noPendingDock")
      try utilityCombatAuthority(
        game.selectedFlightTool == .combatLaser,
        at: site, field: "combatTool")
      try utilityCombatAuthority(
        game.commander.laser(on: .front) == .military,
        at: site, field: "frontMilitary")
      try utilityCombatAuthority(
        pose.position.finite,
        at: site, field: "finitePosition")
      try utilityCombatAuthority(
        pose.orientation.validRotation,
        at: site, field: "validOrientation")
      try utilityCombatAuthority(
        motion.finite,
        at: site, field: "finiteMotion")
      try utilityCombatAuthority(
        game.laserHeat.isFinite,
        at: site, field: "finiteHeat")
      try utilityCombatAuthority(
        game.fireCooldown.isFinite,
        at: site, field: "finiteCooldown")
      try utilityCombatAuthority(
        game.speed.isFinite,
        at: site, field: "finiteSpeed")
      try utilityCombatAuthority(
        game.speed >= 0,
        at: site, field: "nonnegativeSpeed")
      try utilityCombatAuthority(
        game.manualResidualFlight || game.autoPilot.velocity == .init(0, 0, 0),
        at: site, field: "residualOrZeroDrift")
    } catch UtilityCombatFailure.refused(let reason) {
      let observation = utilityCombatRecordFailure(
        controller, at: site, ledger: ledger, lastCommand: lastCommand, work: work,
        player: player, pose: pose, craft: craft, motion: motion)
      throw UtilityCombatFailure.refused(reason + observation)
    }
    return .init(motion: motion, craft: craft,
      weaponReady: game.laserHeat < 240 && game.fireCooldown <= controller.step
        && game.energy > Game.combatLaserEnergyCost && !game.workFireSuspended)
  }

  /// One cold formatter for authority and controller refusals; observations do not replay guards.
  private func utilityCombatRecordFailure(
    _ controller: UtilityCombatController, at site: UtilityCombatObservationSite,
    ledger: UtilityCombatLedger, lastCommand: UtilityCombatCommandObservation?, work: UtilityCombatWork,
    player: ActorIdentity?, pose: ShipPose, craft: ShipPerformance, motion: Vector3,
    bearing: UtilityCombatBearingRefusal? = nil, obstruction: String? = nil
  ) -> String {
    // OBS reads are failure context, not evaluation of later guard predicates.
    let observedScreen = game.screen.rawValue
    let observedTime = game.commander.flightSimulation.physicalTime
    let observedEnergy = game.energy
    let observedDocked = game.docked
    let observedPaused = game.paused
    let locale = Locale(identifier: "en_US_POSIX")
    let timeText = String(format: "%.17g", locale: locale, observedTime)
    let energyText = String(format: "%.17g", locale: locale, observedEnergy)
    let observation =
      " OBS[s=\(observedScreen) t=\(timeText) E=\(energyText)"
      + " d=\(observedDocked) p=\(observedPaused) ph=\(controller.diagnosticPhase)"
      + " X=\(ledger.invoked) A=\(ledger.qualified) R=\(ledger.released) K=\(ledger.calls)]"
    // Reuse the already enabled bounded trace; absence/eviction is not a no-combat proof.
    let trace = game.gameplayCombatTrace
    let incidents = utilityCombatPlayerIncidents(trace, player: player)
    func actor(_ actor: ActorIdentity?) -> String {
      guard let actor else { return "nil" }
      return "\(actor.system.galaxy)/\(actor.system.system)/\(actor.visit)/\(actor.entity)"
    }
    func incident(_ incident: CombatIncident?) -> String {
      guard let incident else { return "nil" }
      return utilityCombatIncidentText(incident) + " victimMatch=true"
    }
    let input = controls
    var causal = "utility-combat-cause site=\(site.rawValue)" + observation
      + " player=\(actor(player)) trace=\(trace?.epoch.uuidString ?? "nil")"
      + " count=\(trace.map { String($0.incidents.count) } ?? "nil")"
      + " dropped=\(trace.map { String($0.dropped) } ?? "nil") scanned=\(incidents.scanned)"
      + " H=[\(incident(incidents.hit))] D=[\(incident(incidents.destruction))]"
      + " rev=\(game.gameplayRevision) impact=\(game.stationImpactRevision.map { String($0) } ?? "nil")"
      + " shields=\(game.frontShield),\(game.rearShield) heat=\(game.laserHeat) cooldown=\(game.fireCooldown)"
      + " rates=\(game.pitch),\(game.yaw),\(game.roll) suspended=\(game.workFireSuspended)"
      + " input=\(input.fire),\(input.pitch),\(input.yaw),\(input.roll),\(input.throttle)"
      + " fitted=\(craft.pitch),\(craft.yaw) step=\(controller.step) B=\(ledger.credit)"
      + " craftSpeed=\(craft.speed) acceleration=\(craft.acceleration) roll=\(craft.roll)"
      + " craftEnergy=\(craft.energy) recharge=\(craft.recharge)"
      + " beforeLastCommand=[\(lastCommand?.diagnostic ?? "nil")] \(controller.diagnosticTurns)"
    let attacker = incidents.destruction?.origin.owner ?? incidents.hit?.origin.owner
    causal += " attackerBasis=latest-retained-player-D-else-H"
      + " DAtObservation=\(incidents.destruction.map { String($0.physicalTime == observedTime) } ?? "NE")"
      + " HAtObservation=\(incidents.hit.map { String($0.physicalTime == observedTime) } ?? "NE")"
    causal += "\nMANUAL_PAIR_CONSUMER thisWorkOnly=true"
      + " holdDecisionObserved=\(work.manualPairHoldDecisionObserved)"
      + " eligibleNativeCallObserved=\(work.firstEligibleManualPair != nil)"
      + " anyNativeAdmissionObserved=\(work.manualPairAdmissionObserved)"
      + " first=[\(work.firstEligibleManualPair ?? "not-observed-in-this-work")]"
      + " earlierWork=unknown evictedTraceUnrecoverable=true impactPositionsAreNotEmissionPoses=true\n"
    causal += utilityCombatFailureContext(controller, attacker: attacker, player: player,
      pose: pose, motion: motion, lastCommand: lastCommand)
    if let bearing { causal += bearing.diagnostic + "\n" }
    if let obstruction { causal += obstruction + "\n" }
    causal += "TRACE_RETAINED order=newest-first cap=128 impactPositionsNotEmissionPoses=true\n"
      + incidents.history + "TRACE_RETAINED_END\n"
    let diagnostic = utilityCombatBoundedText(
      causal, limit: 196608, marker: " [causal-packet-truncated]")
    Issue.record(Comment(rawValue: diagnostic))
    return observation
  }
}


extension GameRuntime {

  /// Controlled preference/cargo policy fixture; preserves actual owned material and dock authority.
  fileprivate func utilityCapacityPolicyAndMarket(enableXYZzy: Bool, fill: Bool) throws {
    try scriptCommand { game in
      if enableXYZzy {
        game.commander.xyzzyActive = true
        game.commander.unlimitedCargo = true
      }
      if fill {
        game.commander.cargo[0] += game.commander.standardCargoCapacity - game.commander.cargoTonnes
        game.market[0].quantity = 2
        game.screen = .buy
        game.selection = 0
      }
      guard game.commander.valid else { throw SaveError.invalidCommander }
    }
  }
  /// Preparation publishes before the caller captures a blocked-writer boundary.
  func utilityPrepareTargetAttack() throws {
    try #require(scriptPublisher() != nil)
    let before = game.commander.flightSimulation.pose
    try scriptCommand { game in
      game.selectFlightTool(.combatLaser)
      _ = try utilityBeamApproach(&game, minimumHullClearance: true)
      try #require(game.commander.laser(on: .front) == .military)
      try #require(game.selectedFlightTool == .combatLaser && !game.playerEMPDisabled)
    }
    try #require(game.commander.flightSimulation.pose != before)
    let destination = try #require(scriptSaveURL)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: destination)
    try #require(persisted.flightSimulation.pose == game.commander.flightSimulation.pose)
    enableStationDefenceDiagnostics()
  }

  /// Native physical death survives failed publication; a later call retries only the saved facts.
  func utilityActualTargetDeath() throws {
    var publishing = false
    do {
      try utilityActualTargetDeath(publishing: &publishing)
    } catch {
      if !publishing {
        Issue.record(Comment(rawValue: utilityTargetDeathUnexpectedError(error)))
      }
      throw error
    }
  }

  private func utilityActualTargetDeath(publishing: inout Bool) throws {
    let attempt = try utilityCombatPrepareAttempt()
    defer { setControls(Controls()) }
    do {
      while let step = try utilityCombatNextStep(attempt) {
        setControls(step.command, expectedEpoch: step.epoch)
        _ = advance(delta: step.delta)
        if step.stopsControls { setControls(Controls()) }
        try utilityCombatDidAdvance(step, utility: attempt.utility)
      }
    } catch {
      if case .active(let work) = attempt.state, case .rearShield(_) = work.phase {
        setControls(Controls())
      }
      throw error
    }
    try utilityCombatPublish(attempt, publishing: &publishing)
  }

  private func utilityCombatPrepareAttempt() throws -> UtilityCombatAttempt {
    let destination = try #require(scriptSaveURL)
    let utility = try #require(game.commander.nativeUtility)
    let initial = try #require(game.commander.nativeStations?.ledger.records.first {
      $0.identity == utility.target
    })
    let before = game.commander.nativePeople?.utilityEngineer?.casualty
    return .init(destination: destination, utility: utility, initial: initial, before: before)
  }

  private func utilityCombatPrepareWork(_ attempt: UtilityCombatAttempt) throws -> UtilityCombatWork {
    let utility = attempt.utility
    let initial = attempt.initial
    let binding = try #require(NativeStationSource.binding(for: utility.target))
    let laser = try #require(game.commander.laser(on: .front))
    try #require(laser == .military && laser.damage == 23 && laser.firingInterval == 0.1)
    try #require(game.selectedFlightTool == .combatLaser && game.screen == .front)
    try #require(binding.maximumEnergy == 5000 && binding.recharge == 0 && utility.rechargeBonus <= 20)
    try #require(game.laserHeat == 0 && game.fireCooldown == 0 && !game.playerEMPDisabled)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0, includePlayer: false)
    let body = try #require(game.bodies.first { $0.nativeStationIdentity == utility.target })
    try #require(contact?.hit.target == .body(body.id) && game.nativeStationBodyIsCurrent(body))
    // Grouped releases retain the original total ceiling; admission is checked per actual shot.
    let net = laser.damage - (binding.recharge + utility.rechargeBonus) * 0.9
    try #require(net > 0 && net.isFinite)
    let shotCeiling = try utilityCombatInteger(ceil(binding.maximumEnergy / net))
    let maximumShots = try utilityCombatSum(shotCeiling, 1)
    let ledger = try UtilityCombatLedger(maximumShots: maximumShots)
    let player = try #require(game.commander.flightSimulation.player)
    let sourceBinding = try #require(initial.binding)
    let carrier = try #require(game.commander.hullInstanceID)
    let initialHit = try #require(contact?.hit.point)
    let controller = try UtilityCombatController(body: body, hit: initialHit, binding: binding,
      player: player, owner: utility.owner, carrier: carrier,
      stationEpoch: game.nativeStationRuntimeEpoch,
      commandEpoch: game.ecmControl.epoch, step: laser.firingInterval)
    try #require(sourceBinding.actor == controller.source && sourceBinding.bodyID == body.id)
    let attackRecord = initial
    let lastCommand: UtilityCombatCommandObservation? = nil
    let usedRearShieldPause = false
    let playerMesh = game.commander.playerMesh
    let combatShipID = game.commander.shipID
    // Same actual-mesh radius formula as the native station movement owner, cached once.
    let playerRadius = playerMesh.vertices.map(\.length).max() ?? .infinity
    let sourceRadius = binding.geometry.mesh.vertices.map(\.length).max() ?? .infinity
    guard playerRadius.isFinite, playerRadius > 0, sourceRadius.isFinite, sourceRadius > 0,
      let sourceSavedPose = game.commander.nativeStations?.pose(for: utility.target)
    else { throw UtilityCombatFailure.refused("actual combat sweep geometry unavailable") }
    // Establish the normal fresh-press path without advancing physics or borrowing credit.
    setControls(Controls())
    var firing = Controls()
    firing.fire = true
    return .init(
      binding: binding, maximumShots: maximumShots, sourceBinding: sourceBinding,
      playerMesh: playerMesh, combatShipID: combatShipID,
      playerRadius: playerRadius, sourceRadius: sourceRadius, sourceSavedPose: sourceSavedPose,
      ledger: ledger, controller: controller, attackRecord: attackRecord,
      lastCommand: lastCommand, usedRearShieldPause: usedRearShieldPause, firing: firing)
  }

  private func utilityCombatNextStep(_ attempt: UtilityCombatAttempt) throws -> UtilityCombatStep? {
    let utility = attempt.utility
    while true {
      switch attempt.state {
      case .unprepared:
        if attempt.initial.tombstone != nil { return nil }
        attempt.state = .active(try utilityCombatPrepareWork(attempt))
      case .active(let work):
        switch work.phase {
        case .beginAttempt:
          if work.attemptIndex >= work.maximumShots {
            work.phase = .finished
            return nil
          }
          if game.commander.nativeStations?.ledger.records.first(where: { $0.identity == utility.target })?
            .tombstone != nil {
            work.phase = .finished
            return nil
          }
          let currentScreen = game.screen
          let currentDocked = game.docked
          let flightPrefix = currentScreen.isFlight && !currentDocked
          let commanderValid: Bool? = flightPrefix ? game.commander.valid : nil
          let flightIsValid = flightPrefix && (commanderValid ?? false)
          let flightDiagnostic: String
          if flightIsValid {
            flightDiagnostic = ""
          } else {
            flightDiagnostic = utilityCombatFlightGuardDiagnostic(
              attemptIndex: work.attemptIndex, maximumShots: work.maximumShots, currentScreen: currentScreen,
              currentDocked: currentDocked, flightPrefix: flightPrefix, commanderValid: commanderValid)
          }
          try #require(flightIsValid, "\(flightDiagnostic)")
          work.firing = Controls()
          work.firing.fire = true
          work.maneuveredForPendingFire = false
          work.maneuverFire = false
          work.maneuverContact = nil
          work.phase = .recovery
        case .recovery:
          if work.attackRecord.tombstone != nil {
            work.phase = .afterRecovery
            continue
          }
          // A contact can survive zero-step dispatch, but never an actual recovery step.
          let pendingContact = work.maneuverContact
          work.maneuverContact = nil
          let own = try utilityCombatOwn(work.controller, at: .decision,
            ledger: work.ledger, lastCommand: work.lastCommand, work: work)
          if !work.usedRearShieldPause,
            let pause = try utilityCombatPrepareRearShieldPause(work, own: own, utility: utility)
          {
            work.phase = .rearShield(pause)
            continue
          }
          let requiresRelease = try work.controller.requiresRelease(own, credit: work.ledger.credit,
            mayStart: !work.maneuveredForPendingFire)
          let rearIsStronger = game.frontShield.isFinite && game.rearShield.isFinite
            && game.frontShield >= 0 && game.frontShield < game.rearShield && game.rearShield > 0
          var decisionContact: UtilityCombatTargetContact? = nil
          var sourceFirst = false
          if !work.controller.active, own.stopped {
            let candidate = try pendingContact
              ?? utilityCurrentTargetContact(game, utility: utility, binding: work.binding)
            decisionContact = candidate
            sourceFirst = candidate.contact?.hit.target == .body(candidate.body.id)
            if own.weaponReady && sourceFirst && !rearIsStronger {
              // Earn through the existing F admission before spending a funded outbound reserve.
              work.maneuverContact = candidate
              work.phase = .afterRecovery
              continue
            }
          }
          if !requiresRelease {
            work.maneuverContact = decisionContact
            work.phase = .afterRecovery
            continue
          }
          guard work.ledger.credit > 0 else {
            throw UtilityCombatFailure.refused("no earned credit for combat recovery")
          }
          guard let releasedBody = game.bodies.first(where: { $0.nativeStationIdentity == utility.target }),
            work.attackRecord.binding == work.sourceBinding, releasedBody.id == work.controller.sourceBodyID,
            releasedBody.physical?.identity == work.controller.source
          else { throw UtilityCombatFailure.refused("released source binding changed") }
          let releasedFrame = try UtilityCombatFrame(body: releasedBody)
          let wasActive = work.controller.active
          let releasedControls: Controls
          do {
            // Keep the existing funded defense available when the rear shield is stronger.
            releasedControls = try work.controller.controls(own, frame: releasedFrame,
              credit: work.ledger.credit,
              mayStart: !work.maneuveredForPendingFire && (!sourceFirst || rearIsStronger))
          } catch {
            let bearing = error as? UtilityCombatBearingRefusal
            let original: any Error
            if let bearing { original = bearing.original } else { original = error }
            if let refusal = original as? UtilityCombatFailure, case .refused(_) = refusal {
              _ = utilityCombatRecordFailure(
                work.controller, at: .decision, ledger: work.ledger, lastCommand: work.lastCommand, work: work,
                player: game.commander.flightSimulation.player,
                pose: game.commander.flightSimulation.pose, craft: own.craft, motion: own.motion,
                bearing: bearing)
            }
            throw original
          }
          if !wasActive && work.controller.active { work.maneuveredForPendingFire = true }
          // A fresh native hit can pay for this exact control step as F rather than R.
          if own.weaponReady {
            let candidate = try decisionContact
              ?? utilityCurrentTargetContact(game, utility: utility, binding: work.binding)
            if candidate.body.id == work.controller.sourceBodyID,
              candidate.body.physical?.identity == work.controller.source,
              candidate.contact?.hit.target == .body(candidate.body.id),
              work.controller.exteriorContains(releasedFrame.player)
            {
              work.maneuverContact = candidate
              work.firing = releasedControls
              work.firing.fire = true
              work.maneuverFire = true
              work.phase = .afterRecovery
              continue
            }
          }
          let beforeRelease = game.commander.flightSimulation.physicalTime
          work.lastCommand = utilityCombatCommandObservation(kind: "R", time: beforeRelease,
            sourceEnergy: releasedBody.energy, input: releasedControls,
            pose: game.commander.flightSimulation.pose, motion: own.motion)
          try work.ledger.chargeRelease()
          return .init(
            work: work, command: releasedControls, epoch: work.controller.commandEpoch,
            delta: work.controller.step, stopsControls: false,
            continuation: .release(time: beforeRelease))
        case .rearShield(let pause):
          if let step = try utilityCombatPlanRearShieldPause(pause, work: work, utility: utility) {
            return step
          }
        case .afterRecovery:
          if work.attackRecord.tombstone != nil {
            work.phase = .finished
            return nil
          }
          // Reuse an accepted pre-movement contact; no step has expired its native projection.
          let frame = try work.maneuverContact
            ?? utilityCurrentTargetContact(game, utility: utility, binding: work.binding)
          work.maneuverContact = nil
          work.phase = .contact(frame)
        case .contact(let frame):
          let blockedByLivingBody: Bool
          if let contact = frame.contact, case .body(let id) = contact.hit.target,
            let selected = contact.selectedTargetBody
          {
            blockedByLivingBody = selected.id == id && selected.energy > 0 && id != frame.body.id
          } else {
            blockedByLivingBody = false
          }
          if blockedByLivingBody {
            guard !work.maneuverFire else {
              throw UtilityCombatFailure.refused("maneuver fire projection became obstructed")
            }
            guard work.ledger.credit > 0 else {
              // Observe this refusal's owned contact; no query or guard replay grants authority.
              let contact = frame.contact
              let obstruction =
                "CONTACT_REFUSAL_OBSERVATION attemptIndex=\(work.attemptIndex) maximumShots=\(work.maximumShots)"
                + " maximumCalls=\(work.ledger.maximumCalls) maximumCredit=\(work.ledger.maximumCredit)"
                + " maneuveredForPendingFire=\(work.maneuveredForPendingFire) maneuverFire=\(work.maneuverFire)"
                + "\nCONTACT_RAY_RAW target=\(String(describing: contact?.hit.target))"
                + " distance=\(String(describing: contact?.hit.distance)) point=\(String(describing: contact?.hit.point))"
                + "\nCONTACT_SOURCE_RAW [\(utilityCombatBodyText(frame.body))]"
                + "\nCONTACT_SELECTED_RAW [\(utilityCombatBodyText(contact?.selectedTargetBody))]"
                + "\nCONTACT_LIMITS currentOwnedProjection=true observationsNotHistory=true"
                + " routeHistory=not-recorded intermediateTrajectory=not-recorded evictedTraceUnrecoverable=true"
              _ = utilityCombatRecordFailure(
                work.controller, at: .decision, ledger: work.ledger, lastCommand: work.lastCommand, work: work,
                player: game.commander.flightSimulation.player,
                pose: game.commander.flightSimulation.pose, craft: game.commander.performance,
                motion: game.autoPilot.velocity + Vector3(0, 0, game.speed * 18), obstruction: obstruction)
              throw UtilityCombatFailure.refused("initial obstruction has no earned release credit")
            }
            let prefix = min(8, work.ledger.credit)
            work.phase = .blocked(remaining: prefix)
            continue
          }
          work.phase = .fire(frame)
        case .blocked(let remaining):
          return try utilityCombatPlanBlockedRelease(work, utility: utility, remaining: remaining)
        case .afterBlocked:
          if work.attackRecord.tombstone != nil {
            work.phase = .finished
            return nil
          }
          // Native movement expires the earlier projection; reconsider this fresh contact.
          // Existing funded recovery precedes another stationary wait when the ray stays blocked.
          let frame = try utilityCurrentTargetContact(game, utility: utility, binding: work.binding)
          work.maneuverContact = frame
          work.phase = .recovery
        case .fire(let frame):
          return try utilityCombatPlanFire(work, utility: utility, frame: frame)
        case .finished:
          return nil
        }
      }
    }
  }

  private func utilityCombatPlanBlockedRelease(
    _ work: UtilityCombatWork, utility: NativeUtilityState, remaining: Int
  ) throws -> UtilityCombatStep {
    let own = try utilityCombatOwn(work.controller, at: .blocked,
      ledger: work.ledger, lastCommand: work.lastCommand, work: work)
    guard let releasedBody = game.bodies.first(where: { $0.nativeStationIdentity == utility.target }),
      work.attackRecord.binding == work.sourceBinding, releasedBody.id == work.controller.sourceBodyID,
      releasedBody.physical?.identity == work.controller.source
    else { throw UtilityCombatFailure.refused("obstructed source binding changed") }
    _ = try UtilityCombatFrame(body: releasedBody)
    var braking = Controls()
    if !own.stopped { braking.throttle = -1 }
    let beforeRelease = game.commander.flightSimulation.physicalTime
    work.lastCommand = utilityCombatCommandObservation(kind: "blockedR", time: beforeRelease,
      sourceEnergy: releasedBody.energy, input: braking,
      pose: game.commander.flightSimulation.pose, motion: own.motion)
    try work.ledger.chargeRelease()
    return .init(
      work: work, command: braking, epoch: work.controller.commandEpoch,
      delta: work.controller.step, stopsControls: false,
      continuation: .blocked(time: beforeRelease, remaining: remaining))
  }

  private func utilityCombatPlanFire(
    _ work: UtilityCombatWork, utility: NativeUtilityState, frame: UtilityCombatTargetContact
  ) throws -> UtilityCombatStep {
    let currentSource = frame.source
    let currentBody = frame.body
    let currentContact = frame.contact
    let currentTarget = currentContact?.hit.target
    let expectedTarget = GameplayHitTarget.body(currentBody.id)
    let contactDiagnostic: String
    if currentTarget == expectedTarget {
      contactDiagnostic = ""
    } else {
      contactDiagnostic = utilityCombatPreFireDiagnostic(
        attemptIndex: work.attemptIndex, currentSource: currentSource, utility: utility,
        currentContact: currentContact, currentTarget: currentTarget,
        expectedTarget: expectedTarget, currentBody: currentBody, firing: work.firing)
    }
    try #require(currentTarget == expectedTarget, "\(contactDiagnostic)")
    let ready = try utilityCombatOwn(work.controller, at: .preF,
      ledger: work.ledger, lastCommand: work.lastCommand, work: work)
    let fireFrame = try UtilityCombatFrame(body: currentBody)
    guard ready.weaponReady, work.maneuverFire || (ready.stopped && !work.controller.active),
      work.controller.exteriorContains(fireFrame.player),
      currentContact?.hit.distance.isFinite == true,
      (currentContact?.hit.distance ?? .infinity) >= 0,
      (currentContact?.hit.distance ?? .infinity) <= 6000,
      currentBody.id == work.controller.sourceBodyID, currentBody.physical?.identity == work.controller.source,
      work.attackRecord.binding == work.sourceBinding
    else { throw UtilityCombatFailure.refused("actual exterior target-first fire admission") }
    let energy = try #require(game.bodies.first { $0.nativeStationIdentity == utility.target }?.energy)
    let beforeTime = game.commander.flightSimulation.physicalTime
    let beforePose = game.commander.flightSimulation.pose
    let beforeImpact = game.stationImpactRevision
    let beforeIncident = game.commander.flightSimulation.nextIncident
    let beforeEmission = game.commander.flightSimulation.nextEmission
    let beforeTraceEpoch = try #require(game.gameplayCombatTrace?.epoch)
    work.lastCommand = utilityCombatCommandObservation(kind: "F", time: beforeTime,
      sourceEnergy: energy, input: work.firing, pose: beforePose, motion: ready.motion)
    work.lastCommand?.beforeTraceEpoch = beforeTraceEpoch
    work.lastCommand?.maneuverF = work.maneuverFire
    try work.ledger.chargeFire()
    return .init(
      work: work, command: work.firing, epoch: work.controller.commandEpoch,
      delta: work.controller.step, stopsControls: true,
      continuation: .fire(
        pose: beforePose, time: beforeTime, impact: beforeImpact, energy: energy,
        incident: beforeIncident, emission: beforeEmission, traceEpoch: beforeTraceEpoch))
  }

  private func utilityCombatDidAdvance(
    _ step: UtilityCombatStep, utility: NativeUtilityState
  ) throws {
    let work = step.work
    switch step.continuation {
    case .rearShield(let pause, let beforePose, let beforeTime, let beforeImpact):
      let controller = pause.controller
      try utilityCombatValidateStep(controller, utility: utility, binding: work.binding,
        saved: work.sourceSavedPose, player: work.playerMesh, shipID: work.combatShipID,
        playerRadius: work.playerRadius, sourceRadius: work.sourceRadius,
        from: beforePose, time: beforeTime, impact: beforeImpact)
      if game.commander.nativeStations?.ledger.records.first(where: {
        $0.identity == utility.target
      })?.tombstone != nil {
        try utilityCombatCompleteRearShieldPause(work, utility: utility)
      }
    case .release(let beforeRelease):
      work.attackRecord = try #require(game.commander.nativeStations?.ledger.records.first {
        $0.identity == utility.target
      })
      if work.attackRecord.tombstone != nil {
        work.phase = .afterRecovery
        return
      }
      let afterRelease = game.commander.flightSimulation.physicalTime
      guard afterRelease.isFinite, beforeRelease.isFinite, afterRelease > beforeRelease,
        work.attackRecord.binding == work.sourceBinding
      else { throw UtilityCombatFailure.refused("release refused time or source binding") }
      work.phase = .recovery
    case .blocked(let beforeRelease, let remaining):
      work.attackRecord = try #require(game.commander.nativeStations?.ledger.records.first {
        $0.identity == utility.target
      })
      if work.attackRecord.tombstone != nil {
        work.phase = .afterBlocked
        return
      }
      let afterRelease = game.commander.flightSimulation.physicalTime
      guard afterRelease.isFinite, beforeRelease.isFinite, afterRelease > beforeRelease,
        work.attackRecord.binding == work.sourceBinding
      else { throw UtilityCombatFailure.refused("obstruction release refused time or binding") }
      work.phase = remaining > 1 ? .blocked(remaining: remaining - 1) : .afterBlocked
    case .fire(let beforePose, let beforeTime, let beforeImpact, let energy,
      let beforeIncident, let beforeEmission, let beforeTraceEpoch):
      work.attackRecord = try #require(game.commander.nativeStations?.ledger.records.first {
        $0.identity == utility.target
      })
      if work.attackRecord.tombstone != nil {
        work.lastCommand?.terminalSeen = true
        work.lastCommand?.validationEntered = true
        try utilityCombatValidateStep(work.controller, utility: utility, binding: work.binding,
          saved: work.sourceSavedPose, player: work.playerMesh, shipID: work.combatShipID,
          playerRadius: work.playerRadius, sourceRadius: work.sourceRadius,
          from: beforePose, time: beforeTime, impact: beforeImpact)
        work.lastCommand?.validationReturned = true
        work.phase = .finished
        return
      }
      let wounded = try #require(game.bodies.first { $0.nativeStationIdentity == utility.target })
      try #require(wounded.energy < energy)
      work.lastCommand?.postSourceEnergy = wounded.energy
      work.lastCommand?.woundDecreasedPassed = true
      let afterTime = game.commander.flightSimulation.physicalTime
      let afterIncident = game.commander.flightSimulation.nextIncident
      let afterEmission = game.commander.flightSimulation.nextEmission
      let trace = try #require(game.gameplayCombatTrace)
      let currentWound = game.nativeStationBodyIsCurrent(wounded)
        && utilityCombatOrdinarySource(wounded) && wounded.id == work.controller.sourceBodyID
        && wounded.physical?.identity == work.controller.source && work.attackRecord.binding == work.sourceBinding
      work.lastCommand?.currentWound = currentWound
      let afterOwn = try utilityCombatOwn(work.controller, at: .postF,
        ledger: work.ledger, lastCommand: work.lastCommand, work: work)
      work.lastCommand?.validationEntered = true
      try utilityCombatValidateStep(work.controller, utility: utility, binding: work.binding,
        saved: work.sourceSavedPose, player: work.playerMesh, shipID: work.combatShipID,
        playerRadius: work.playerRadius, sourceRadius: work.sourceRadius,
        from: beforePose, time: beforeTime, impact: beforeImpact)
      work.lastCommand?.validationReturned = true
      guard currentWound, afterOwn.motion.finite,
        beforeTime.isFinite, afterTime.isFinite, afterTime > beforeTime,
        afterIncident > beforeIncident, afterEmission > beforeEmission,
        trace.epoch == beforeTraceEpoch
      else { throw UtilityCombatFailure.refused("actual source wound or F interval changed") }
      work.lastCommand?.woundGuardPassed = true
      var qualifiedHit = false
      for incident in trace.incidents.suffix(128).reversed() {
        if incident.id >= beforeIncident, incident.id < afterIncident,
          incident.origin.emissionID >= beforeEmission, incident.origin.emissionID < afterEmission,
          incident.kind == .laser, incident.outcome == .hit,
          incident.laser == .military, incident.mount == .front,
          incident.origin.owner == work.controller.player, incident.victim == work.controller.source,
          incident.origin.ordnance == nil,
          incident.physicalTime.isFinite, incident.physicalTime > beforeTime,
          incident.physicalTime <= afterTime, incident.origin.emittedAt.isFinite,
          incident.origin.emittedAt > beforeTime, incident.origin.emittedAt <= afterTime
        {
          qualifiedHit = true
          break
        }
      }
      guard qualifiedHit else {
        throw UtilityCombatFailure.refused("no retained authenticated military source hit")
      }
      work.lastCommand?.authenticatedHit = true
      try work.ledger.earnQualifiedHit()
      work.lastCommand?.awardCommitted = true
      work.attemptIndex += 1
      work.phase = .beginAttempt
    }
  }

  private func utilityCombatPublish(
    _ attempt: UtilityCombatAttempt, publishing: inout Bool
  ) throws {
    let utility = attempt.utility
    let before = attempt.before
    let destination = attempt.destination
    setControls(Controls())
    let record = try #require(game.commander.nativeStations?.ledger.records.first {
      $0.identity == utility.target
    })
    let casualty = try #require(game.commander.nativePeople?.utilityEngineer?.casualty)
    try #require(record.tombstone != nil && record.binding == nil && casualty.origin != nil)
    if let before { try #require(casualty == before) }
    try #require(game.screen.isFlight && game.energy > 0 && game.commander.valid)
    // The public writer retries retained physical facts; it never fires or creates another death.
    publishing = true
    try save(to: destination)
    publishing = false
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: destination)
    try #require(persisted.nativeUtility == game.commander.nativeUtility)
    try #require(persisted.nativePeople?.utilityEngineer?.casualty == casualty)
    let persistedTombstone = persisted.nativeStations?.ledger.records.first {
      $0.identity == utility.target
    }?.tombstone
    try #require(persistedTombstone == record.tombstone)
    try #require(WayfarerFieldReliefSave.validateClaims(persisted, requireRecordedLoss: true))
  }

  private func utilityCombatFlightGuardDiagnostic(
    attemptIndex: Int, maximumShots: Int, currentScreen: Screen, currentDocked: Bool,
    flightPrefix: Bool, commanderValid: Bool?
  ) -> String {
    let flightDiagnostic: String
    let time = game.commander.flightSimulation.physicalTime
    let energy = game.energy
    let frontShield = game.frontShield
    let rearShield = game.rearShield
    let paused = game.paused
    let heat = game.laserHeat
    let cooldown = game.fireCooldown
    let revision = game.gameplayRevision
    let impactRevision = game.stationImpactRevision
    let pendingEntry = game.pendingNativeStationDock != nil
    let mainDock = game.dockedAtMainStation
    let fatalTransition = game.nativeOriginalUtilityFatalTransition != nil
    let casualty = game.commander.nativePeople?.utilityEngineer?.casualty != nil
    let speed = game.speed
    let pitch = game.pitch
    let yaw = game.yaw
    let roll = game.roll
    let input = controls
    let autoTarget = game.autoPilot.targetID
    let autoVelocity = game.autoPilot.velocity
    let guidance = game.workGuidance != nil
    let braking = game.workBraking != nil
    let validity = commanderValid.map { String($0) } ?? "not-evaluated"
    let trace = game.gameplayCombatTrace
    let player = game.commander.flightSimulation.player
    let incidents = utilityCombatPlayerIncidents(trace, player: player)
    let lastPlayerHit = incidents.hit
    let lastPlayerDestruction = incidents.destruction
    let traceScanned = incidents.scanned
    let hitDiagnostic: String
    if let hit = lastPlayerHit {
      hitDiagnostic = "id=\(hit.id) time=\(hit.physicalTime) kind=\(hit.kind.rawValue)"
        + " outcome=\(hit.outcome.rawValue) owner=\(hit.origin.owner.system.galaxy)"
        + "/\(hit.origin.owner.system.system)/\(hit.origin.owner.visit)/\(hit.origin.owner.entity)"
        + " ordnance=\(hit.origin.ordnance != nil) laser=\(hit.laser?.rawValue ?? "nil")"
        + " mount=\(hit.mount?.rawValue ?? "nil") victimMatch=true"
    } else {
      hitDiagnostic = "nil"
    }
    let destructionDiagnostic: String
    if let destruction = lastPlayerDestruction {
      destructionDiagnostic = "id=\(destruction.id) time=\(destruction.physicalTime)"
        + " kind=\(destruction.kind.rawValue) outcome=\(destruction.outcome.rawValue)"
        + " owner=\(destruction.origin.owner.system.galaxy)"
        + "/\(destruction.origin.owner.system.system)/\(destruction.origin.owner.visit)"
        + "/\(destruction.origin.owner.entity) ordnance=\(destruction.origin.ordnance != nil)"
        + " laser=\(destruction.laser?.rawValue ?? "nil")"
        + " mount=\(destruction.mount?.rawValue ?? "nil") victimMatch=true"
    } else {
      destructionDiagnostic = "nil"
    }
    let traceDiagnostic = " tracePresent=\(trace != nil) playerPresent=\(player != nil)"
      + " traceEpoch=\(trace?.epoch.uuidString ?? "nil")"
      + " traceCount=\(String(describing: trace?.incidents.count))"
      + " traceDropped=\(String(describing: trace?.dropped)) traceScanned=\(traceScanned)"
      + " lastPlayerHit=[\(hitDiagnostic)] lastPlayerDestruction=[\(destructionDiagnostic)]"
    // Bound source bytes before escaping; strict decoding trims only an incomplete scalar.
    let messageBytes = Array(game.message.utf8.prefix(61))
    var prefixBytes = Array(messageBytes.prefix(60))
    while !prefixBytes.isEmpty && String(bytes: prefixBytes, encoding: .utf8) == nil {
      prefixBytes.removeLast()
    }
    let messageTruncated = messageBytes.count > prefixBytes.count
    let prefix = String(bytes: prefixBytes, encoding: .utf8) ?? ""
    var quotedMessage = "\""
    for scalar in prefix.unicodeScalars {
      switch scalar.value {
      case 0x22: quotedMessage += "\\\""
      case 0x5C: quotedMessage += "\\\\"
      case 0...0x1F, 0x7F...0x9F, 0x2028...0x202E, 0x2066...0x2069:
        quotedMessage += String(format: "\\u%04X", scalar.value)
      default: quotedMessage += String(scalar)
      }
    }
    if messageTruncated { quotedMessage += "...[truncated]" }
    quotedMessage += "\""
    let core = "flight-guard attemptIndex=\(attemptIndex) maximumShots=\(maximumShots) time=\(time)"
      + " screen=\(currentScreen.rawValue) docked=\(currentDocked) prefix=\(flightPrefix)"
      + " commanderValid=\(validity) energy=\(energy) shields=\(frontShield),\(rearShield)"
      + traceDiagnostic
      + " paused=\(paused) heat=\(heat) cooldown=\(cooldown) revision=\(revision)"
      + " stationImpactRevision=\(String(describing: impactRevision)) pendingEntry=\(pendingEntry)"
      + " mainDock=\(mainDock) targetFatalTransition=\(fatalTransition) casualty=\(casualty)"
      + " speed=\(speed) rates=\(pitch),\(yaw),\(roll)"
      + " controls=\(input.fire),\(input.pitch),\(input.yaw),\(input.roll),\(input.throttle)"
      + " autoTarget=\(String(describing: autoTarget))"
      + " autoVelocity=\(autoVelocity.x),\(autoVelocity.y),\(autoVelocity.z) work=\(guidance),\(braking)"
    let diagnostic = core + " messageTruncated=\(messageTruncated) messagePrefix=\(quotedMessage)"
    if diagnostic.utf8.prefix(2049).count <= 2048 {
      flightDiagnostic = diagnostic
    } else {
      // Drop the quoted suffix before truncation so partial escapes cannot become fields.
      let marker = " [diagnostic-truncated]"
      var bytes = Array(core.utf8.prefix(2048 - marker.utf8.count))
      while !bytes.isEmpty && String(bytes: bytes, encoding: .utf8) == nil {
        bytes.removeLast()
      }
      flightDiagnostic = (String(bytes: bytes, encoding: .utf8) ?? "") + marker
    }
    return flightDiagnostic
  }

  private func utilityCombatPreFireDiagnostic(
    attemptIndex: Int, currentSource: NativeStationSourceBinding, utility: NativeUtilityState,
    currentContact: MissionCollisionContact?, currentTarget: GameplayHitTarget?,
    expectedTarget: GameplayHitTarget, currentBody: SpaceBody, firing: Controls
  ) -> String {
    let contactDiagnostic: String
    let interceptor = currentContact?.selectedTargetBody
    let pose = game.commander.flightSimulation.pose
    let input = controls
    contactDiagnostic =
      "pre-fire attemptIndex=\(attemptIndex) time=\(game.commander.flightSimulation.physicalTime)"
      + " source=\(currentSource.site.rawValue) bonus=\(utility.rechargeBonus)"
      + " hit=\(String(describing: currentTarget)) expected=\(expectedTarget)"
      + " distance=\(String(describing: currentContact?.hit.distance))"
      + " point=\(String(describing: currentContact?.hit.point))"
      + " interceptor.id=\(String(describing: interceptor?.id))"
      + " hull=\(interceptor?.hull.rawValue ?? "nil")"
      + " actor=\(String(describing: interceptor?.physical?.identity))"
      + " population=\(interceptor?.physical?.population.rawValue ?? "nil")"
      + " role=\(interceptor?.physical?.npc?.role.rawValue ?? "nil")"
      + " spawn=\(String(describing: interceptor?.physical?.spawnIdentity))"
      + " station=\(interceptor?.nativeStationIdentity?.key ?? "nil")"
      + " catalogue=\(interceptor?.physical?.catalogueShipID ?? "nil")"
      + " mission=\(String(describing: interceptor?.missionInstanceID))"
      + " scriptNPC=\(interceptor?.scriptNPC != nil)"
      + " position=\(String(describing: interceptor?.position))"
      + " velocity=\(String(describing: interceptor?.physical?.velocity))"
      + " target.id=\(currentBody.id) actor=\(String(describing: currentBody.physical?.identity))"
      + " position=\(currentBody.position) velocity=\(String(describing: currentBody.physical?.velocity))"
      + " energy=\(currentBody.energy) player.position=\(pose.position) basis=\(pose.orientation)"
      + " speed=\(game.speed) rates=\(game.pitch),\(game.yaw),\(game.roll)"
      + " controls=\(input.fire),\(input.pitch),\(input.yaw),\(input.roll),\(input.throttle)"
      + " requested.fire=\(firing.fire) auto.target=\(String(describing: game.autoPilot.targetID))"
      + " auto.velocity=\(game.autoPilot.velocity) work=\(game.workGuidance != nil),\(game.workBraking != nil)"
    return contactDiagnostic
  }

  /// Controlled actor and ray produce the actual fatal native hit; no forged loss receipt.
  func utilityActualFatalHit() throws {
    let mesh = game.commander.playerMesh
    let face = try #require(
      mesh.faces.first { indices in
        indices.count == 3
          && (mesh.vertices[indices[0]] + mesh.vertices[indices[1]] + mesh.vertices[indices[2]]).z
            > 0
      })
    let center =
      (mesh.vertices[face[0]] + mesh.vertices[face[1]] + mesh.vertices[face[2]]) * (1.0 / 3.0)
    let position = center.unit * 500
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: position, hostile: true))
    game.ensurePhysicalActors()
    let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: position, direction: position.unit * -1,
      range: position.length + 1, radius: 0, excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let allocated = game.makeAttackOrigin(owner: actor)
    let origin = try #require(allocated)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let result = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(result != nil)
  }
}
