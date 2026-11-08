import Foundation
import Testing

@testable import L337Core

struct OriginalFleetNPCSteeringTests {
  /// Controlled flight scene using a genuine current source and the real admission path.
  private func admittedOkapi(
    localTarget: Vector3, bank: Double
  ) throws -> (game: Game, actor: ActorIdentity, basis: Basis3, craft: ShipPerformance) {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.docked = false
    game.screen = .front
    game.speed = 0
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    let anchors = try #require(game.commander.flightSimulation.anchors)
    game.commander.flightSimulation.pose.position = anchors.arrival * 0.6
      + anchors.station.position * 0.4
    game.bodies.removeAll()
    let context = try #require(game.gameplayContext())
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    let current = try #require(OriginalFleetR3Data.contract(for: "SH029"))
    let craft = source.performance
    try #require(craft == current.performance)
    try #require(craft.pitch == 0.84 && craft.yaw == 0.78 && craft.roll == 0.95)
    let stock = try #require(NPCResources.stock(craft))
    let position = context.player.position + Vector3(0, 0, 3000)
    var basis = Basis3()
    basis.rotate(pitch: 0, roll: bank, yaw: 0)
    var npc = NPCState(
      role: .trader, origin: context.system, destination: context.system,
      legalProvenance: .generated, cargoProvenance: .generated,
      routeProvenance: .generated, resources: stock)
    npc.ordinaryCargo = [.init(commodity: .food, quantity: 1)]
    npc.intention = .navigate(position: position + basis.apply(localTarget), speedUnitsPerSecond: 100)
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: sequence, member: 0),
      population: .civilian, hull: .cobra, position: position, orientation: basis,
      velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: source.ship.id)
    try #require(OriginalFleetRuntimeHullSource.matchesAmbientTrader(request, context: context))
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: false)], intents: []))
    let actor = try #require(receipts.first?.actor)
    try #require(receipts.first?.refusal == nil)
    let admitted = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(admitted.physical?.catalogueShipID == source.ship.id)
    try #require(admitted.missionActorID == nil && admitted.missionInstanceID == nil && admitted.scriptNPC == nil)
    return (game, actor, basis, craft)
  }

  @Test(arguments: ["pitch", "yaw", "aligned", "zero"], [0.0, 0.6])
  func currentSourceIntentKeepsSeparateAxesAndActualBank(axis: String, bank: Double) throws {
    let target: Vector3
    switch axis {
    case "pitch": target = .init(0, 4000, 0)
    case "yaw": target = .init(4000, 0, 0)
    case "aligned": target = .init(0, 0, 4000)
    default: target = .init(0, 0, 0)
    }
    let scene = try admittedOkapi(localTarget: target, bank: bank)
    var game = scene.game
    let before = try #require(game.gameplayContext())
    let actor = try #require(before.actors.first { $0.identity == scene.actor })
    let intent = try #require(TrafficIntent.intents(context: before).first { $0.actor == scene.actor })
    try #require(intent.action == actor.npc?.intention)
    let initialPools = try #require(actor.npc?.resources)
    let emissions = game.commander.flightSimulation.nextEmission
    // Isolate this actual admitted intention from new encounter proposals.
    game.commander.encounterDirector = EncounterDirector(context: before)
    let delta = 0.1
    game.advanceGameplayEncounters(delta: delta)
    let after = try #require(game.gameplayContext()?.actors.first { $0.identity == scene.actor })
    // Measure applied local axes independently of the controller's clamp formula.
    let localForward = actor.orientation.inverse(after.orientation.z)
    let expectedPitch = axis == "pitch" ? scene.craft.pitch * delta : 0
    let expectedYaw = axis == "yaw" ? scene.craft.yaw * delta : 0
    #expect(abs(asin(localForward.y) - expectedPitch) < 1e-9)
    #expect(abs(atan2(localForward.x, localForward.z) - expectedYaw) < 1e-9)
    if axis == "pitch" {
      #expect((after.orientation.x - actor.orientation.x).length < 1e-9)
    } else if axis == "yaw" {
      #expect((after.orientation.y - actor.orientation.y).length < 1e-9)
    } else {
      #expect((after.orientation.x - actor.orientation.x).length < 1e-9)
      #expect((after.orientation.y - actor.orientation.y).length < 1e-9)
      #expect((after.orientation.z - actor.orientation.z).length < 1e-9)
    }
    let expectedSpeed = axis == "zero" ? 0 : scene.craft.acceleration * 18 * delta
    #expect(abs(after.velocity.length - expectedSpeed) < 1e-9)
    #expect(after.velocity.length <= 100 && after.velocity.length <= after.maximumSpeedUnitsPerSecond)
    #expect(after.position == actor.position)
    let pools = try #require(after.npc?.resources)
    #expect(after.energy == actor.energy && pools.fuel == initialPools.fuel)
    #expect(pools.frontShield == initialPools.frontShield && pools.rearShield == initialPools.rearShield)
    #expect(pools.laserHeat == initialPools.laserHeat)
    #expect(after.npc?.ordinaryCargo == actor.npc?.ordinaryCargo)
    #expect(game.commander.flightSimulation.nextEmission == emissions)
    #expect(after.catalogueShipID == "SH029")
  }

  @Test func unqualifiedPeregrineRemainsUnavailableToTheSteeringFixture() throws {
    let ship = try #require(ShipCatalogue.ship("SH025"))
    let native = try #require(ship.nativeDesign)
    #expect(native.faces.count == 964)
    #expect(OriginalFleetRuntimeHullSource.source(for: ship.id) == nil)
    #expect(throws: (any Error).self) {
      try ScriptPackLibrary.currentCatalogueNPCDesign(ship.id)
    }
  }

  @Test func zeroDurationKeepsRolledCurrentSourceAndVelocityUntouched() throws {
    let scene = try admittedOkapi(localTarget: .init(4000, 0, 0), bank: 0.6)
    var game = scene.game
    let before = try #require(game.gameplayContext())
    let actor = try #require(before.actors.first { $0.identity == scene.actor })
    game.commander.encounterDirector = EncounterDirector(context: before)
    let emissions = game.commander.flightSimulation.nextEmission
    game.advanceGameplayEncounters(delta: 0)
    let after = try #require(game.gameplayContext()?.actors.first { $0.identity == scene.actor })
    #expect(after.orientation == actor.orientation && after.velocity == actor.velocity)
    #expect(after.position == actor.position && after.energy == actor.energy)
    #expect(after.npc?.resources == actor.npc?.resources)
    #expect(game.commander.flightSimulation.nextEmission == emissions)
  }
}
