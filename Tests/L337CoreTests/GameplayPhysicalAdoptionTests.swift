import Foundation
import Testing

@testable import L337Core

/// Legacy-body adoption components only; these fixtures grant no station or mission authority.
struct GameplayPhysicalAdoptionTests {
  @Test func adoptionKeepsMainAnchorAndAllocatesOrdinaryActorsInBodyOrder() throws {
    var game = Game(executive: false)
    var pirate = SpaceBody(id: 70, hull: .cobra, position: .init(0, 0, 1000), hostile: true)
    pirate.energy = 45
    game.bodies = [
      .init(id: 0, hull: .station, position: .init(0, 0, 0)), pirate,
      .init(id: 71, hull: .viper, position: .init(200, 0, 1000)),
      .init(id: 72, hull: .asteroid, position: .init(-200, 0, 1000)),
    ]
    let before = game
    game.ensurePhysicalActors()
    let flight = game.commander.flightSimulation
    #expect(flight.system == game.systemIdentity && flight.visit == 1)
    #expect(flight.nextActor == 5 && flight.nextSpawn == 1)
    #expect(game.bodies.map { $0.physical?.identity.entity } == [1, 2, 3, 4])
    #expect(game.bodies[0].physical?.identity == flight.anchors?.station.identity)
    #expect(game.bodies[0].physical?.population == .mission && game.bodies[0].physical?.npc == nil)
    #expect(game.bodies[1].physical?.population == .pirate)
    #expect(game.bodies[1].physical?.npc?.role == .pirate)
    #expect(game.bodies[1].physical?.npc?.intention == flight.player.map { .engage($0) })
    #expect(game.bodies[1].physical?.npc?.routeProvenance == .inferredLocal)
    #expect(game.bodies[1].physical?.npc?.resources?.profile == .legacyEnergyOnly)
    #expect(game.bodies[2].physical?.population == .police)
    #expect(game.bodies[2].physical?.blocksNavalEncounter == true)
    #expect(game.bodies[3].physical?.population == .asteroid)
    for (index, body) in game.bodies.enumerated() {
      #expect(body.id == before.bodies[index].id && body.hull == before.bodies[index].hull)
      #expect(
        body.position == before.bodies[index].position && body.energy == before.bodies[index].energy
      )
      #expect(body.physical?.velocity == .init(0, 0, 0) && body.physical?.spawnIdentity == nil)
    }
    #expect(game.nextBodyID == before.nextBodyID)
    #expect(game.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(
      game.commander.credits == before.commander.credits
        && game.commander.cargo == before.commander.cargo)
    #expect(game.commander.missiles == before.commander.missiles)
    let adopted = game
    game.ensurePhysicalActors()
    #expect(game.commander == adopted.commander && game.bodies == adopted.bodies)
    #expect(game.nextBodyID == adopted.nextBodyID)
    #expect(before.bodies.allSatisfy { $0.physical == nil })
  }

  @Test(arguments: ["physical", "physical-nan", "shot", "station", "combined"])
  func existingOwnershipTagsSkipAdoptionWithoutChangingCursorsOrValues(scenario: String) throws {
    var game = prepared()
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let spawn = SpawnIdentity(
      system: game.systemIdentity, visit: actor.visit, sequence: 9, member: 0, producer: .mission)
    var body = SpaceBody(id: 70, hull: .cobra, position: .init(0, 0, 1000))
    if scenario == "physical" || scenario == "physical-nan" || scenario == "combined" {
      body.physical = .init(
        identity: actor, population: .civilian, velocity: .init(17, 18, 19), spawnIdentity: spawn)
      if scenario == "physical-nan" { body.physical?.laserCooldown = .nan }
    }
    if scenario == "shot" || scenario == "combined" {
      body.scriptShot = .init(
        identity: UUID(), owner: UUID(), instance: UUID(), weapon: "component-shot", component: nil,
        velocity: .init(1, 2, 3), age: 0, lifetime: 1, damage: 1, radius: 1, collisionDelay: 0)
    }
    if scenario == "station" || scenario == "combined" {
      let source = try #require(NativeStationSource.bindings.first)
      body.nativeStationIdentity = source.identity(world: UUID())
    }
    game.bodies = [body]
    let before = game
    game.ensurePhysicalActors()
    #expect(game.commander == before.commander)
    var actualBodies = game.bodies
    var retainedBodies = before.bodies
    if scenario == "physical-nan" {
      #expect(game.bodies[0].physical?.laserCooldown.isNaN == true)
      #expect(before.bodies[0].physical?.laserCooldown.isNaN == true)
      // Normalize only comparison copies: every other stored body value must still match.
      actualBodies[0].physical?.laserCooldown = 0
      retainedBodies[0].physical?.laserCooldown = 0
    }
    #expect(actualBodies == retainedBodies)
    #expect(game.commander.flightSimulation == before.commander.flightSimulation)
    #expect(game.nextBodyID == before.nextBodyID)
    #expect(game.bodies[0].physical?.identity == body.physical?.identity)
    #expect(game.bodies[0].physical?.velocity == body.physical?.velocity)
    #expect(game.bodies[0].physical?.spawnIdentity == body.physical?.spawnIdentity)
    if scenario == "physical-nan" { #expect(game.bodies[0].physical?.laserCooldown.isNaN == true) }
    if scenario == "shot" || scenario == "station" { #expect(game.bodies[0].physical == nil) }
  }

  @Test(arguments: [false, true])
  func systemChangeEntersExactlyOnceEvenWhenNoBodyNeedsAdoption(empty: Bool) throws {
    var game = prepared()
    let allocated = game.commander.flightSimulation.allocateActor()
    let originalActor = try #require(allocated)
    var bound = SpaceBody(id: 70, hull: .cobra, position: .init(0, 0, 1000))
    bound.physical = .init(identity: originalActor, population: .civilian, velocity: .init(3, 4, 5))
    game.commander.flightSimulation.physicalTime = 25
    game.commander.flightSimulation.pose.position = .init(1, 2, 3)
    game.commander.system = 85
    game.bodies =
      empty
      ? []
      : [
        bound, .init(id: 0, hull: .station, position: .init(0, 0, 0)),
        .init(id: 71, hull: .cobra, position: .init(0, 0, 2000)),
      ]
    let before = game
    game.ensurePhysicalActors()
    let flight = game.commander.flightSimulation
    #expect(flight.system == game.systemIdentity && flight.visit == originalActor.visit + 1)
    #expect(flight.physicalTime == 25 && flight.pose.position == .init(0, 0, 500))
    #expect(flight.nextActor == before.commander.flightSimulation.nextActor + (empty ? 0 : 1))
    #expect(flight.nextSpawn == before.commander.flightSimulation.nextSpawn)
    if !empty {
      #expect(game.bodies[0] == bound)
      #expect(game.bodies[1].physical?.identity == flight.anchors?.station.identity)
      let adopted = try #require(game.bodies[2].physical?.identity)
      #expect(adopted.system == game.systemIdentity && adopted.visit == flight.visit)
      #expect(adopted.entity == before.commander.flightSimulation.nextActor)
    }
    let entered = game
    game.ensurePhysicalActors()
    #expect(game.commander == entered.commander && game.bodies == entered.bodies)
  }

  @Test(arguments: ["exhausted", "missing-main-anchor"])
  func failedIdentitySelectionSkipsOnlyThatBodyAndPreservesSpawnCursor(scenario: String) throws {
    var game = prepared()
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander.flightSimulation))
        as? [String: Any])
    if scenario == "exhausted" {
      fields["nextActor"] = UInt64.max
    } else {
      fields["anchors"] = NSNull()
    }
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: fields))
    game.bodies = [
      .init(id: 70, hull: .cobra, position: .init(0, 0, 1000)),
      .init(id: 0, hull: .station, position: .init(0, 0, 0)),
      .init(id: 71, hull: .asteroid, position: .init(100, 0, 1000)),
    ]
    let before = game
    game.ensurePhysicalActors()
    if scenario == "exhausted" {
      #expect(game.bodies[0].physical == nil && game.bodies[2].physical == nil)
      #expect(
        game.bodies[1].physical?.identity
          == before.commander.flightSimulation.anchors?.station.identity)
      #expect(game.commander.flightSimulation.nextActor == UInt64.max)
    } else {
      #expect(game.bodies[1].physical == nil)
      #expect(game.bodies[0].physical?.identity.entity == 2)
      #expect(game.bodies[2].physical?.identity.entity == 3)
      #expect(game.commander.flightSimulation.nextActor == 4)
    }
    #expect(game.commander.flightSimulation.visit == before.commander.flightSimulation.visit)
    #expect(
      game.commander.flightSimulation.nextSpawn == before.commander.flightSimulation.nextSpawn)
    #expect(game.nextBodyID == before.nextBodyID)
    #expect(before.bodies.allSatisfy { $0.physical == nil })
  }

  @Test(arguments: ["default", "changed", "upper", "invalid"])
  func adoptionSystemReadPreservesExactScalarsAndRetainedCommanderBytes(scenario: String) throws {
    var game = Game(executive: false)
    let expected: SystemIdentity
    switch scenario {
    case "default":
      expected = .init(galaxy: NewCommanderDefaults.galaxy, system: NewCommanderDefaults.system)
    case "changed":
      game.commander.galaxy = 3
      game.commander.system = 149
      expected = .init(galaxy: 3, system: 149)
    case "upper":
      game.commander.galaxy = 7
      game.commander.system = 255
      expected = .init(galaxy: 7, system: 255)
    case "invalid":
      // The existing identity read does not validate or repair caller-owned scalar values.
      game.commander.galaxy = -1
      game.commander.system = 256
      expected = .init(galaxy: -1, system: 256)
    default:
      Issue.record(Comment(rawValue: "Unrecognised adoption identity fixture: " + scenario))
      return
    }
    let before = game
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(before.commander)
    let identity = game.nativePhysicalAdoptionSystemIdentity()
    #expect(identity == expected)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(try encoder.encode(game.commander) == bytes)
    var changed = game
    changed.commander.system = 1
    let changedIdentity = changed.nativePhysicalAdoptionSystemIdentity()
    let retainedIdentity = game.nativePhysicalAdoptionSystemIdentity()
    #expect(changedIdentity == .init(galaxy: expected.galaxy, system: 1))
    #expect(retainedIdentity == expected)
    #expect(try encoder.encode(before.commander) == bytes)
  }

  private func prepared() -> Game {
    var game = Game(executive: false)
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
    return game
  }
}

extension GameplayPhysicalAdoptionTests {
  @Test(arguments: [false, true])
  func actualContextPreservesEveryProtectionFlagAndPopulationCountWithoutMutation(blockNaval: Bool) throws {
    var game = prepared()
    game.bodies = []
    _ = try appendProtectionReadBody("station", id: 0, blockNaval: blockNaval, to: &game)
    let modes = ["naval", "blackjack", "mission-npc", "mission-instance", "pod", "combined",
      "ordinary", "unphysical-protected"]
    var protected: Set<ActorIdentity> = []
    for (index, mode) in modes.enumerated() {
      let identity = try appendProtectionReadBody(mode, id: 80 + index, blockNaval: blockNaval, to: &game)
      if index < 6, let identity { protected.insert(identity) }
    }
    let before = game
    let context = try #require(game.gameplayContext())
    #expect(context.protection.protectedActors == protected && protected.count == 6)
    #expect(context.protection.protectedPayloads.isEmpty)
    #expect(!context.protection.suppressAmbientShips && context.protection.reservedSlots == 4)
    #expect(context.protection.blocksNavalEncounter == blockNaval)
    // Nine actual component values include the station and an unphysical value.
    // The station consumes total capacity but no population slot; a missing
    // physical value remains in total capacity without inventing a population.
    #expect(context.budget.total == 9 && context.actors.count == 8)
    #expect(context.budget.active == [.civilian: 4, .police: 1, .mission: 1, .cargo: 1])
    #expect(context.budget.maximum == 128 && context.budget.policeReserve == 8)
    #expect(context.budget.missionReserve == 4)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.commander.savedEMPState == nil && game.commander.nativePeople == nil)
  }

  /// Controlled read-only component tags use real allocator identities. They
  /// grant no mission, person, installed kit, admission, rescue or save authority.
  @inline(never)
  private func appendProtectionReadBody(
    _ mode: String, id: Int, blockNaval: Bool, to game: inout Game
  ) throws -> ActorIdentity? {
    var body = SpaceBody(id: id, hull: id == 0 ? .station : .cobra,
      position: .init(Double(id) * 100, 0, 2000))
    if mode == "unphysical-protected" {
      body.navalTarget = true
      #expect(body.gameplayProtectionReasons == .navalTarget)
      game.bodies.append(body)
      return nil
    }
    let actor: ActorIdentity
    if mode == "station" { actor = try #require(game.commander.flightSimulation.anchors?.station.identity) }
    else {
      let allocated = game.commander.flightSimulation.allocateActor()
      actor = try #require(allocated)
    }
    let population: PopulationClass = mode == "station" || mode == "mission-npc" ? .mission
      : mode == "blackjack" ? .police : mode == "pod" ? .cargo : .civilian
    var physical = PhysicalActorState(identity: actor, population: population)
    let expected: GameplayActorProtectionReasons
    switch mode {
    case "naval":
      body.navalTarget = true
      expected = .navalTarget
    case "blackjack":
      body.blackjackRole = .witness
      physical.blocksNavalEncounter = blockNaval
      expected = .blackjackRole
    case "mission-npc":
      physical.npc = .init(role: .mission, origin: actor.system, destination: actor.system)
      expected = .missionNPC
    case "mission-instance":
      body.missionInstanceID = UUID()
      expected = .missionInstance
    case "pod":
      physical.empCrewPod = .init(source: actor, ordinal: 0)
      expected = .empCrewPod
    case "combined":
      body.navalTarget = true
      body.blackjackRole = .witness
      body.missionInstanceID = UUID()
      physical.empCrewPod = .init(source: actor, ordinal: 0)
      physical.npc = .init(role: .mission, origin: actor.system, destination: actor.system)
      expected = [.empCrewPod, .navalTarget, .blackjackRole, .missionNPC, .missionInstance]
    default: expected = []
    }
    body.physical = physical
    #expect(body.gameplayProtectionReasons == expected)
    game.bodies.append(body)
    return actor
  }

  @Test func genuineRuntimeAdvanceReachesTheOrdinaryPersistenceAndContextReadChain() async throws {
    let runtime = try launchedProtectionReadRuntime()
    let before = await runtime.snapshot()
    let opening = try #require(before.gameplayContext())
    let start = before.commander.flightSimulation.physicalTime
    _ = await runtime.advance(delta: 0.02)
    let after = await runtime.snapshot()
    let current = try #require(after.gameplayContext())
    // Enter the genuine actor executor/tick/persistence/context chain from the
    // matched crash, rather than directly invoking a scalar projection helper.
    #expect(after.commander.flightSimulation.physicalTime == start + 0.02)
    #expect(current.physicalTime == start + 0.02 && current.visit == opening.visit)
    #expect(current.system == opening.system && current.seed == opening.seed)
    #expect(current.protection.reservedSlots == 4)
    #expect(current.budget.maximum == 128 && current.budget.policeReserve == 8)
    #expect(current.budget.missionReserve == 4)
    #expect(after.commander.equipmentOwnerID == before.commander.equipmentOwnerID)
    #expect(after.commander.hullInstanceID == before.commander.hullInstanceID)
    #expect(after.commander.nativePeople == before.commander.nativePeople)
  }

  @inline(never)
  private func launchedProtectionReadRuntime() throws -> GameRuntime {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    let alive = !game.docked && !game.paused && game.screen.isFlight
    try #require(alive)
    return GameRuntime(game: game)
  }
}
