import Foundation
import Testing

@testable import L337Core

struct NPCMiningSourceRefusalTests {
  @Test(arguments: ["unsupported", "unknown-source"])
  func currentSourceWithoutDeclaredMiningSupportCannotEmitFromMinerRole(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    try #require(source.performance.workTools?.contains(.miningLaser) != true)
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
    var npc = NPCState(role: .miner, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    // Controlled emitter-source boundary; a role is not installed equipment.
    var craft = SpaceBody(id: shooterID, hull: .cobra, position: .init(-5000, 0, 0))
    craft.energy = stock.energyCapacity
    craft.missiles = 0
    craft.physical = .init(
      identity: shooter, population: .civilian, npc: npc, catalogueShipID: source.ship.id)
    var rock = SpaceBody(id: targetID, hull: .asteroid, position: .init(-5000, 0, 300))
    rock.physical = .init(identity: target, population: .asteroid)
    game.bodies.append(contentsOf: [craft, rock])
    game.gameplayCombatTrace = .init()
    let contact = try #require(try game.nearestMissionCollision(
      from: craft.position, direction: craft.orientation.z.unit, range: 500, radius: 0,
      excludingBodyIDs: [shooterID], includePlayer: true))
    try #require(contact.selectedTargetBody?.id == targetID)
    if condition == "unknown-source" {
      let index = try #require(game.bodies.firstIndex { $0.id == shooterID })
      game.bodies[index].physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    }
    let context = try #require(game.gameplayContext())
    try #require(context.actors.contains { $0.identity == shooter })
    try #require(context.actors.contains { $0.identity == target })
    let before = game
    game.emitGameplayNPCBeam(bodyID: shooterID, target: target, context: context, mining: true)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
    #expect(game.laserHeat == before.laserHeat && game.fireCooldown == before.fireCooldown)
    #expect(game.gameplayCombatTrace?.incidents.count == before.gameplayCombatTrace?.incidents.count)
  }
}
