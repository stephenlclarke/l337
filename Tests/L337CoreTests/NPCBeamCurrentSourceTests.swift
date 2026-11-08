import Foundation
import Testing

@testable import L337Core

struct NPCBeamCurrentSourceTests {
  @Test(arguments: ["wrong-profile", "unknown-fuel", "missile-overflow", "unknown-source"])
  func malformedOrdinaryCurrentSourceCannotPublishAnOtherwiseAlignedPulse(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    let stock = try #require(NPCResources.stock(source.performance))
    try #require(source.performance.supports(.front))
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.screen.isFlight)
    let allocatedShooter = game.commander.flightSimulation.allocateActor()
    let shooter = try #require(allocatedShooter)
    let allocatedTarget = game.commander.flightSimulation.allocateActor()
    let target = try #require(allocatedTarget)
    let shooterID = game.nextBodyID
    game.nextBodyID += 1
    let targetID = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .pirate, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    var craft = SpaceBody(id: shooterID, hull: .cobra, position: .init(-5000, 0, 0))
    craft.energy = stock.energyCapacity
    craft.missiles = 0
    craft.physical = .init(
      identity: shooter, population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    var cargo = SpaceBody(id: targetID, hull: .cargo, position: .init(-5000, 0, 300))
    cargo.physical = .init(identity: target, population: .cargo)
    game.bodies.append(contentsOf: [craft, cargo])
    game.gameplayCombatTrace = .init()
    let contact = try #require(try game.nearestMissionCollision(
      from: craft.position, direction: craft.orientation.z.unit, range: 1500, radius: 0,
      excludingBodyIDs: [shooterID], includePlayer: true))
    try #require(contact.selectedTargetBody?.id == targetID)
    // Controlled emitter boundary: a real pulse on a copy proves this path is otherwise usable.
    do {
      var emitted = game
      let context = try #require(emitted.gameplayContext())
      emitted.emitGameplayNPCBeam(bodyID: shooterID, target: target, context: context)
      let actual = try #require(emitted.bodies.first { $0.id == shooterID })
      let cooldown = try #require(actual.physical?.laserCooldown)
      try #require(actual.energy < craft.energy && cooldown > 0)
      let heat = try #require(actual.physical?.npc?.resources?.laserHeat)
      try #require(heat > stock.laserHeat)
      try #require(emitted.commander.flightSimulation.nextEmission
        > game.commander.flightSimulation.nextEmission)
    }
    let index = try #require(game.bodies.firstIndex { $0.id == shooterID })
    switch condition {
    case "wrong-profile":
      game.bodies[index].physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
    case "unknown-fuel": game.bodies[index].physical?.npc?.resources?.fuel = nil
    case "missile-overflow": game.bodies[index].missiles = source.performance.missiles + 1
    case "unknown-source": game.bodies[index].physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    default:
      Issue.record("Unknown controlled NPC source corruption")
      return
    }
    let context = try #require(game.gameplayContext())
    let before = game
    game.emitGameplayNPCBeam(bodyID: shooterID, target: target, context: context)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
    #expect(game.laserHeat == before.laserHeat && game.fireCooldown == before.fireCooldown)
    #expect(game.gameplayCombatTrace?.incidents.count == before.gameplayCombatTrace?.incidents.count)
  }
}
