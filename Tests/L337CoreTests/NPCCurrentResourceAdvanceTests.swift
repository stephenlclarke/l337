import Foundation
import Testing

@testable import L337Core

struct NPCCurrentResourceAdvanceTests {
  @Test(arguments: [
    "current-spent", "wrong-profile", "unknown-fuel", "missile-overflow", "unknown-source",
  ])
  func currentResourceUpdatesRequireTheirActualSource(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    let fuel = try #require(stock.fuel)
    try #require(fuel > 1)
    var spent = stock
    spent.frontShield *= 0.5
    spent.rearShield *= 0.75
    spent.laserHeat = 10
    spent.fuel = fuel - 1
    try #require(spent.valid && spent.frontShield > 0 && spent.rearShield > 0)
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.screen.isFlight)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let bodyID = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = spent
    try #require(npc.hasFuelScoops == nil)
    var craft = SpaceBody(id: bodyID, hull: .cobra, position: .init(-5000, 0, 0))
    craft.energy = stock.energyCapacity * 0.75
    craft.missiles = 0
    craft.physical = .init(
      identity: actor, population: .civilian, npc: npc, catalogueShipID: source.ship.id)
    switch condition {
    case "wrong-profile":
      var generic = try #require(NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
      generic.laserHeat = 10
      craft.physical?.npc?.resources = generic
    case "unknown-fuel": craft.physical?.npc?.resources?.fuel = nil
    case "missile-overflow": craft.missiles = source.performance.missiles + 1
    case "unknown-source": craft.physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    case "current-spent": break
    default:
      Issue.record("Unknown controlled NPC resource condition")
      return
    }
    try #require(craft.physical?.npc?.resources?.valid == true)
    game.bodies.append(craft)
    let commander = game.commander
    game.advanceNPCResources(delta: 0.1)
    let advanced = try #require(game.bodies.first { $0.id == bodyID })
    #expect(game.commander == commander)
    if condition == "current-spent" {
      let resources = try #require(advanced.physical?.npc?.resources)
      #expect(advanced.energy > craft.energy && advanced.energy <= stock.energyCapacity)
      #expect(resources.frontShield > spent.frontShield && resources.frontShield <= stock.frontCapacity)
      #expect(resources.rearShield > spent.rearShield && resources.rearShield <= stock.rearCapacity)
      #expect(resources.laserHeat < spent.laserHeat && resources.fuel == spent.fuel)
      #expect(resources.profile == stock.profile && resources.energyCapacity == stock.energyCapacity)
      #expect(resources.frontCapacity == stock.frontCapacity && resources.rearCapacity == stock.rearCapacity)
      #expect(resources.fuelCapacity == stock.fuelCapacity)
      #expect(advanced.physical?.identity == actor && advanced.physical?.catalogueShipID == source.ship.id)
      #expect(advanced.missiles == craft.missiles && advanced.physical?.npc?.ordinaryCargo == npc.ordinaryCargo)
    } else {
      #expect(advanced == craft)
    }
  }
}
