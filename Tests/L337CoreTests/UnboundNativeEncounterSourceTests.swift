import Testing

@testable import L337Core

struct UnboundNativeEncounterSourceTests {
  @Test(arguments: [false, true])
  func missingNativeBindingsRefuseBeforeGeometryOrAllocation(atomic: Bool) throws {
    let current = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    try #require(current.ship.name == "Peregrine Mk V")
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.bodies.removeAll { $0.id != 0 }
    game.ensurePhysicalActors()
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    let supported = SpawnRequest(
      identity: .init(
        system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
        sequence: sequence, member: 0),
      population: .civilian, hull: .cobra, position: .init(1000, 0, -3000),
      orientation: Basis3(), velocity: .init(0, 0, 10), npc: nil, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: current.ship.id)
    let positive = game.admitEncounterPlan(.init(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
      revision: game.gameplayRevision,
      batches: [.init(requests: [supported], atomic: atomic)], intents: []))
    try #require(positive.count == 1 && positive[0].actor != nil && positive[0].refusal == nil)
    try #require(game.bodies.contains { $0.physical?.spawnIdentity == supported.identity })

    let unavailable: [Hull] = [.cobra, .sidewinder, .constrictor, .thargoid, .thargon]
    try #require(unavailable.allSatisfy { ShipCatalogue.nativeShip($0) == nil })
    let allocatedUnavailableSequence = game.commander.flightSimulation.allocateSpawn()
    let unavailableSequence = try #require(allocatedUnavailableSequence)
    let requests = unavailable.enumerated().map { index, hull in
      SpawnRequest(
        identity: .init(
          system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
          sequence: unavailableSequence, member: UInt16(index)),
        population: .civilian, hull: hull, position: .init(5000 + Double(index) * 500, 0, -3000),
        orientation: Basis3(), velocity: .init(0, 0, 10), npc: nil, rock: nil, payload: nil,
        priority: .ordinary)
    }
    let commander = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    let time = game.time
    let refused = game.admitEncounterPlan(.init(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
      revision: game.gameplayRevision,
      batches: [.init(requests: requests, atomic: atomic)], intents: []))
    #expect(refused.count == requests.count)
    #expect(refused.map(\.request) == requests.map(\.identity))
    #expect(refused.allSatisfy { $0.actor == nil && $0.refusal == .unqualifiedOriginalHull })
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.nextBodyID == next && game.time == time)
  }
}
