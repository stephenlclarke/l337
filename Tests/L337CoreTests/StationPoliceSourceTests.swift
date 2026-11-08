import Foundation
import Testing

@testable import L337Core

struct StationPoliceSourceTests {
  @Test func pendingAtomicWaveRequiresItsActualEpochCurrentSourceAndUnspentStock() throws {
    let context = crimeTestContext(4)
    let current = try #require(StationPoliceSource.current())
    var game = Game(executive: false)
    let plan = game.commander.stationSecurity.advance(context: context)
    let requests = plan.encounters.batches.flatMap(\.requests)
    try #require(!requests.isEmpty)
    let request = try #require(requests.first)
    #expect(request.catalogueShipID == current.source.ship.id && request.hull == .viper)
    #expect(request.npc?.resources == current.stock && request.recoveredSecuritySource == nil)
    for request in requests {
      #expect(game.securitySpawnSourceIsValid(request, context: context))
    }
    let before = game
    var wrongSource = request
    wrongSource.catalogueShipID = nil
    #expect(!game.securitySpawnSourceIsValid(wrongSource, context: context))
    wrongSource.catalogueShipID = "SH067"
    #expect(!game.securitySpawnSourceIsValid(wrongSource, context: context))
    var missingReceipt = request
    missingReceipt.recoveredSecuritySource = crimeTestID(50)
    #expect(!game.securitySpawnSourceIsValid(missingReceipt, context: context))
    var inventedEnergy = request
    inventedEnergy.energy = 1
    #expect(!game.securitySpawnSourceIsValid(inventedEnergy, context: context))
    #expect(!game.securitySpawnSourceIsValid(request, context: crimeTestContext(4, visit: 2)))
    var spentNPC = try #require(request.npc)
    spentNPC.resources?.fuel = 0
    let spent = SpawnRequest(
      identity: request.identity, population: request.population, hull: request.hull,
      position: request.position, orientation: request.orientation, velocity: request.velocity,
      npc: spentNPC, rock: nil, payload: nil, priority: request.priority,
      catalogueShipID: request.catalogueShipID)
    #expect(!game.securitySpawnSourceIsValid(spent, context: context))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    var unowned = game
    unowned.commander.stationSecurity = StationSecurity()
    #expect(!unowned.securitySpawnSourceIsValid(request, context: context))
    game.commander.stationSecurity.acknowledge(receipts: [
      .init(request: request.identity, actor: crimeTestID(30), refusal: nil)
    ])
    #expect(!game.securitySpawnSourceIsValid(request, context: context))
    for remaining in requests.dropFirst() {
      #expect(game.securitySpawnSourceIsValid(remaining, context: context))
    }
  }

  @Test func explicitPoliceBindingKeepsActualNativeMeshAndNeverInfersUnlabelledCrew() throws {
    let current = try #require(StationPoliceSource.current())
    let ship = current.source.ship
    let physical = try #require(ship.physicalSourceContract)
    #expect(ship.id == "SH031" && ship.name == "Kite Interceptor" && ship.nativeHull == .viper)
    #expect(ShipCatalogue.nativeShip(.viper)?.id == ship.id)
    for mesh in [Mesh.hull(.viper), try #require(ShipCatalogue.rawMesh(ship.id)), current.source.mesh] {
      #expect(mesh.vertices == physical.physicalMesh.vertices)
      #expect(mesh.faces == physical.physicalMesh.faces)
      #expect(mesh.materials == physical.physicalMesh.materials)
      #expect(mesh.faceMaterials == physical.physicalMesh.faceMaterials)
      #expect(mesh.faceTextures == physical.physicalMesh.faceTextures)
    }
    var body = SpaceBody(id: 2, hull: .viper, position: .init(0, 0, 1000))
    var npc = NPCState(role: .police, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = current.stock
    body.physical = .init(identity: crimeTestID(2), population: .police, npc: npc)
    #expect(StationPoliceSource.empCatalogueID(for: body) == nil)
    body.physical?.catalogueShipID = ship.id
    #expect(StationPoliceSource.empCatalogueID(for: body) == ship.id)
    let wrongBinding = try #require(OriginalFleetRuntimeHullSource.source(for: "SH030"))
    try #require(wrongBinding.ship.nativeHull != body.hull)
    body.physical?.catalogueShipID = wrongBinding.ship.id
    #expect(StationPoliceSource.empCatalogueID(for: body) == nil)
    var other = SpaceBody(id: 3, hull: .cobra, position: .init(0, 0, 1000))
    #expect(StationPoliceSource.empCatalogueID(for: other) == nil)
    other.physical = .init(
      identity: crimeTestID(3), population: .civilian, npc: npc, catalogueShipID: ship.id)
    #expect(StationPoliceSource.empCatalogueID(for: other) == nil)
    let trader = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    try #require(trader.ship.nativeHull == nil || trader.ship.nativeHull == other.hull)
    other.physical?.catalogueShipID = trader.ship.id
    #expect(StationPoliceSource.empCatalogueID(for: other) == trader.ship.id)
    other.physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    #expect(StationPoliceSource.empCatalogueID(for: other) == nil)
    other.physical?.catalogueShipID = nil
    #expect(StationPoliceSource.empCatalogueID(for: other) == nil)
  }

  @Test func genuineRecoveredPoliceCustodyRetainsSpentConditionAndRefusesUnjoinedClaims() async throws {
    let paid = try await paidEMPNativeFixture()
    defer { paid.clean() }
    var game = await paid.runtime.snapshot()
    let current = try #require(StationPoliceSource.current())
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let id = game.nextBodyID
    game.nextBodyID += 1
    // Controlled non-traffic owner boundary, not a claim of a new earned police journey.
    var npc = NPCState(role: .police, origin: game.systemIdentity, destination: game.systemIdentity)
    var worn = current.stock
    worn.frontShield = 0
    worn.rearShield = 0
    worn.fuel = 0
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(ElectricalReserve(
      capacity: worn.energyCapacity, recharge: worn.energyRecharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(drained)
    worn.electrical = reserve
    npc.resources = worn
    var body = SpaceBody(id: id, hull: .viper, position: .init(0, 0, 1000))
    body.energy = current.source.performance.energy - 3
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .police, npc: npc, blocksNavalEncounter: true,
      catalogueShipID: current.source.ship.id)
    game.bodies.append(body)
    _ = try await disableNativeEMPActor(actor, game: &game)
    let source = try #require(game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let disabled = try #require(game.commander.nativeEMPCustodyRecord(for: source))
    try #require(disabled.custody.kind == .police && disabled.custody.traffic == nil)
    try #require(disabled.activeTrafficTransfer == nil && disabled.crewAboard == disabled.crewTotal)
    let deadline = try #require(disabled.crewDeadline)
    let delta = deadline - game.commander.flightSimulation.physicalTime
    try #require(delta > 0)
    game.commander.flightSimulation.advancePhysicalTime(delta)
    game.advanceEMPActors()
    let recovered = try #require(game.commander.nativeEMPCustodyRecord(for: source))
    try #require(recovered.isRecovered && recovered.hull.binding == actor)
    #expect(recovered.hull.body.energy == body.energy)
    #expect(recovered.hull.body.physical?.npc?.resources?.fuel == 0)
    #expect(recovered.crewAboard == disabled.crewAboard && recovered.crewTotal == disabled.crewTotal)
    // Actual persistence captures controlled scene absence; no receipt or archive fields are forged.
    game.bodies.removeAll { $0.physical?.identity == actor }
    let persisted = game.persistEMPState()
    try #require(persisted)
    let archived = try #require(game.commander.nativeEMPCustodyRecord(for: source))
    let physical = try #require(archived.hull.body.physical)
    let context = try #require(game.gameplayContext())
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .security),
      population: .police, hull: archived.hull.body.hull, position: archived.hull.body.position,
      orientation: archived.hull.body.orientation, velocity: physical.velocity, npc: physical.npc,
      rock: nil, payload: nil, priority: .police, catalogueShipID: physical.catalogueShipID,
      energy: archived.hull.body.energy, angularVelocity: physical.angularVelocity,
      recoveredSecuritySource: source)
    let before = game
    #expect(game.securitySpawnSourceIsValid(request, context: context))
    var missing = request
    missing.recoveredSecuritySource = nil
    #expect(!game.securitySpawnSourceIsValid(missing, context: context))
    missing.recoveredSecuritySource = .init(system: source.system, visit: source.visit, entity: UInt64.max - 1)
    #expect(!game.securitySpawnSourceIsValid(missing, context: context))
    var refilled = request
    refilled.energy = current.stock.energyCapacity
    #expect(!game.securitySpawnSourceIsValid(refilled, context: context))
    var different = request
    different.catalogueShipID = nil
    #expect(!game.securitySpawnSourceIsValid(different, context: context))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    let duplicate = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: sequence + 1,
        member: 0, producer: .security),
      population: request.population, hull: request.hull, position: request.position,
      orientation: request.orientation, velocity: request.velocity, npc: request.npc,
      rock: nil, payload: nil, priority: request.priority, catalogueShipID: request.catalogueShipID,
      energy: request.energy, angularVelocity: request.angularVelocity,
      recoveredSecuritySource: source)
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request, duplicate], atomic: true)], intents: []))
    #expect(receipts.count == 2 && receipts.allSatisfy { $0.refusal == .staleContext && $0.actor == nil })
    #expect(game.commander == before.commander && game.bodies == before.bodies)
  }
}
