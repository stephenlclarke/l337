import Foundation
import Testing

@testable import L337Core

struct NativeFleetLaunchSourceTests {
  @Test func unsupportedInitialOwnersAndPlacementNeverSubstituteAnotherCurrentHull() throws {
    let context = crimeTestContext(4)
    let actor = crimeTestID(2)
    _ = try #require(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    #expect(NativeFleetLaunchSource.resolve(
      role: .mission, actor: actor, seed: context.seed, context: context,
      position: context.anchors.arrival) == nil)
    #expect(NativeFleetLaunchSource.resolve(
      role: .police, actor: actor, seed: context.seed, context: context,
      position: context.anchors.arrival) == nil)
    #expect(NativeFleetLaunchSource.resolve(
      role: .trader, actor: actor, seed: context.seed,
      context: crimeTestContext(4, visit: 2), position: context.anchors.arrival) == nil)
    #expect(NativeFleetLaunchSource.resolve(
      role: .trader, actor: actor, seed: context.seed, context: context,
      position: .init(.nan, 0, 0)) == nil)
    // The actual published initial trader permits trade lane/deep space, not station security.
    #expect(NativeFleetLaunchSource.resolve(
      role: .trader, actor: actor, seed: context.seed, context: context,
      position: context.anchors.station.position) == nil)
  }

  @Test func arrivalKeepsFlightAndStationWhenOptionalPirateIsOmitted() throws {
    var game = try NativeStationTestFixture.launched()
    let origin = game.currentSystem
    let range = game.commander.maximumJumpDistance
    let destination = try #require(game.systems.first {
      !$0.isPlugh && $0.id != origin.id && $0.government < 4 && origin.distance(to: $0) <= range
    })
    game.selectedSystem = destination.id
    game.arrive()
    #expect(!game.docked && !game.paused && game.commander.system == destination.id)
    #expect(game.bodies.contains { $0.id == 0 && $0.hull == .station })
    #expect(game.bodies.allSatisfy { $0.id != 1 })
  }

  @Test func nativeClearanceExcludesOnlyItsOwnActorAndKeepsTheWholeWorldUnchanged() throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    var game = Game(executive: false)
    game.commander.shipID = source.ship.id
    let initial = crimeTestContext(4)
    let position = initial.anchors.arrival
    var own = crimeTestActor(2, position: position, hull: .viper)
    own.catalogueShipID = source.ship.id
    var context = crimeTestContext(4, actors: [own])
    let beforeCommander = game.commander
    let beforeBodies = game.bodies
    let beforeRandom = game.scriptSimulationSave.randomState
    let clearLaunch = game.nativeLaunchGeometryIsSafe(
      source: source, actor: own.identity, position: position, context: context)
    #expect(clearLaunch)
    let playerLaunch = game.nativeLaunchGeometryIsSafe(
      source: source, actor: own.identity, position: context.player.position, context: context)
    #expect(!playerLaunch)
    let planetLaunch = game.nativeLaunchGeometryIsSafe(
      source: source, actor: own.identity,
      position: context.anchors.planet.position, context: context)
    #expect(!planetLaunch)
    let sunLaunch = game.nativeLaunchGeometryIsSafe(
      source: source, actor: own.identity,
      position: context.anchors.sun.position, context: context)
    #expect(!sunLaunch)
    var other = crimeTestActor(3, position: position, hull: .viper)
    other.catalogueShipID = source.ship.id
    context = crimeTestContext(4, actors: [own, other])
    let occupiedLaunch = game.nativeLaunchGeometryIsSafe(
      source: source, actor: own.identity, position: position, context: context)
    #expect(!occupiedLaunch)
    #expect(game.commander == beforeCommander && game.bodies == beforeBodies)
    #expect(game.scriptSimulationSave.randomState == beforeRandom)
  }


  @Test func planetProfilerFixtureUsesOrdinaryLaunchInItsIndustrialSystem() async throws {
    let game = try Game.planetFrameProfileFixture(system: 114)
    #expect(game.currentSystem.name == "Cetanas")
    #expect(game.docked && game.screen == .status)
    #expect(game.commander.equipmentInventory != nil && !game.commander.xyzzyActive)
    let runtime = GameRuntime(game: game)
    await runtime.key("0")
    let flight = await runtime.snapshot()
    #expect(!flight.docked && flight.screen == .front)
    #expect(flight.commander.system == 114 && flight.commander.flightSimulation.anchors != nil)
    #expect(flight.commander.shipDisplayStyle == .shadedPanels)
  }

  @Test func freshLaunchRetainsResolvedTrafficAlongsideTheActualStationCohort() throws {
    let game = try NativeStationTestFixture.launched()
    try requireNativeLaunchFleetAndStationPopulation(game, expectedRole: .trader)
  }
}

/// Inspect the retained body from a real launch/arrival, never a replacement fixture body.
func requireNativeLaunchFleetAndStationPopulation(_ game: Game, expectedRole: NPCRole) throws {
  let flight = game.commander.flightSimulation
  let body = try #require(game.bodies.first { $0.id == 1 })
  let physical = try #require(body.physical)
  let npc = try #require(physical.npc)
  let context = try #require(game.gameplayContext())
  let source = try #require(NativeFleetLaunchSource.resolve(
    role: npc.role, actor: physical.identity, seed: game.gameplaySeed, context: context,
    position: flight.pose.systemPoint(body.position)))
  #expect(!game.docked && !game.paused && game.screen.isFlight)
  #expect(npc.role == expectedRole && npc.routeProvenance == .generated)
  #expect(npc.resources == NPCResources.stock(source.performance))
  #expect(physical.identity.system == game.systemIdentity && physical.identity.visit == flight.visit)
  #expect(physical.catalogueShipID == source.ship.id && physical.spawnIdentity == nil)
  if expectedRole == .trader { #expect(source.ship.id == "SH029") }
  if let hull = source.ship.nativeHull { #expect(body.hull == hull) }
  let mesh = game.gameplayMesh(for: body)
  #expect(!mesh.vertices.isEmpty && !mesh.faces.isEmpty)
  let snapshot = try #require(NPCPersistenceSnapshot.capture(
    body: body, pose: flight.pose, physicalTime: context.physicalTime,
    protection: context.protection))
  #expect(snapshot.valid && snapshot.actor == physical.identity)
  #expect(snapshot.catalogueShipID == source.ship.id)

  let world = try #require(game.commander.nativeStations)
  let sources = NativeStationSource.bindings.filter { $0.system == game.systemIdentity }
  try #require(Set(sources.map(\.site)) == Set([
    OriginalStationSite.salamander, .frog, .dhole,
  ]))
  let expected = Set(sources.map { $0.identity(world: world.ledger.world) })
  let stations = game.bodies.filter { $0.nativeStationIdentity != nil }
  #expect(world.valid && game.commander.nativeStationStateValid)
  #expect(stations.count == expected.count && Set(stations.compactMap(\.nativeStationIdentity)) == expected)
  for identity in expected {
    let station = try #require(stations.first { $0.nativeStationIdentity == identity })
    let actor = try #require(station.physical?.identity)
    #expect(game.nativeStationBodyIsCurrent(station))
    #expect(world.bodyRigidPoseIsConsistent(station, flight: flight))
    #expect(world.ledger.records.first { $0.identity == identity }?.binding
      == .init(actor: actor, bodyID: station.id))
  }
}
