import Foundation
import Testing

@testable import L337Core

struct EMPCurrentTargetSourceTests {
  @Test(arguments: [
    "current", "wrong-profile", "unknown-fuel", "missile-overflow", "missing-source", "unknown-source",
  ])
  func targetEligibilityRequiresExplicitCurrentResourceIdentity(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    try #require(EMPState.hasSupportedCrew(source.ship))
    try #require(SalvageCatalogue.empProfile(catalogueShipID: source.ship.id) != nil)
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.screen.isFlight)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    var body = SpaceBody(id: id, hull: .cobra, position: .init(0, 0, 1000))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .civilian, npc: npc, catalogueShipID: source.ship.id)
    game.bodies.append(body)
    try #require(game.empPulseEligible(body))
    switch condition {
    case "wrong-profile":
      body.physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
    case "unknown-fuel": body.physical?.npc?.resources?.fuel = nil
    case "missile-overflow": body.missiles = source.performance.missiles + 1
    case "missing-source": body.physical?.catalogueShipID = nil
    case "unknown-source": body.physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    case "current": break
    default:
      Issue.record("Unknown controlled EMP target-source condition")
      return
    }
    try #require(body.physical?.npc?.resources?.valid == true)
    let index = try #require(game.bodies.firstIndex { $0.id == id })
    game.bodies[index] = body
    let before = game
    let eligible = game.empPulseEligible(game.bodies[index])
    #expect(eligible == (condition == "current"))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
  }
}
