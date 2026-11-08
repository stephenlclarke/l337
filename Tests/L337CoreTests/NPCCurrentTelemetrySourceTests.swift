import Foundation
import Testing

@testable import L337Core

struct NPCCurrentTelemetrySourceTests {
  @Test(arguments: [
    "current-full", "current-spent", "wrong-profile", "unknown-fuel", "missile-overflow",
    "unknown-source",
  ])
  func trackedCurrentResourcesRequireTheirActualSourceBeforeDisclosure(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.docked && game.screen.isFlight)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let bodyID = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    var body = SpaceBody(id: bodyID, hull: .cobra, position: .init(-5000, 0, 0))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .civilian, npc: npc, catalogueShipID: source.ship.id)
    let baseline = game.telemetryFacts(for: body)
    try #require(baseline.resources == stock.telemetry)
    switch condition {
    case "current-spent":
      var spent = stock
      let fuel = try #require(spent.fuel)
      try #require(fuel > 1)
      spent.frontShield *= 0.5
      spent.rearShield *= 0.75
      spent.laserHeat = 10
      spent.fuel = fuel - 1
      body.physical?.npc?.resources = spent
    case "wrong-profile":
      body.physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
    case "unknown-fuel": body.physical?.npc?.resources?.fuel = nil
    case "missile-overflow": body.missiles = source.performance.missiles + 1
    case "unknown-source": body.physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    case "current-full": break
    default:
      Issue.record("Unknown controlled telemetry source condition")
      return
    }
    let actual = try #require(body.physical?.npc?.resources)
    try #require(actual.valid)
    game.bodies.append(body)
    let facts = game.telemetryFacts(for: body)
    #expect(facts.cargo == baseline.cargo && facts.origin == baseline.origin)
    #expect(facts.destination == baseline.destination && facts.legal == baseline.legal)
    #expect(facts.hostile == baseline.hostile)
    if condition == "current-full" || condition == "current-spent" {
      #expect(facts.resources == actual.telemetry)
      if condition == "current-spent" { #expect(facts.resources != stock.telemetry) }
    } else {
      #expect(facts.resources == nil)
      // Supplying a tier tests formatting; it does not install an observer device.
      let fields = TargetTelemetry.fields(
        facts: facts, tier: .military, targetIsShip: true, observerGalaxy: game.commander.galaxy)
      for label in ["Front shield", "Rear shield", "Laser heat", "Fuel"] {
        #expect(fields.first { $0.label == label }?.value == "Unknown")
      }
    }
  }
}
