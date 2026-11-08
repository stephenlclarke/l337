import Foundation
import Testing

@testable import L337Core

struct OccupiedNewtCapsuleAdmissionTests {
  @Test(arguments: [false, true])
  func bareNewtRequestCannotUseGenericAdmission(atomic: Bool) throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.ensurePhysicalActors()
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    let ownedPreparationRequired1 = game.gameplayContext()
    let context = try #require(ownedPreparationRequired1)
    let source = context.player.identity
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 1, producer: .emp),
      population: .cargo, hull: .cargo, position: .init(1000, 0, -3000),
      orientation: Basis3(), velocity: .init(0, 0, 10), npc: nil, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: "SH040", energy: 1,
      angularVelocity: .init(0, 0, 0),
      salvage: .init(
        category: .occupiedPod, ownership: .occupied, claimant: source,
        wreck: nil, section: nil, lot: nil,
        bounds: .init(center: .init(0, 0, 0), radius: 2), workSurfaces: []))
    let before = game
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: atomic)], intents: []))
    #expect(receipts.count == 1)
    #expect(receipts.first?.request == request.identity)
    #expect(receipts.first?.actor == nil)
    #expect(receipts.first?.refusal == .unqualifiedOriginalHull)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID && game.time == before.time)
    #expect(game.gameplayRevision == before.gameplayRevision)
  }

  @Test
  func bareStoredNewtPersonAndSalvageClaimsCannotMintOccupiedHardware() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.ensurePhysicalActors()
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    let ownedPreparationRequired2 = game.gameplayContext()
    let context = try #require(ownedPreparationRequired2)
    let person = EMPCrewIdentity(source: actor, ordinal: 0)
    var body = SpaceBody(id: game.nextBodyID, hull: .cargo, position: .init(1000, 0, -3000))
    body.energy = 1
    body.hostile = false
    body.physical = .init(
      identity: actor, population: .cargo,
      spawnIdentity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 1, producer: .emp),
      catalogueShipID: "SH040",
      salvage: .init(
        category: .occupiedPod, ownership: .occupied, claimant: actor,
        wreck: nil, section: nil, lot: nil,
        bounds: .init(center: .init(0, 0, 0), radius: 2), workSurfaces: []),
      empCrewPod: person)
    let object = EMPStoredObject(body: body, pose: ShipPose(), time: context.physicalTime)
    #expect(!object.valid)
    let restored = try JSONDecoder().decode(
      EMPStoredObject.self, from: JSONEncoder().encode(object))
    #expect(restored == object && !restored.valid)
    #expect(OriginalDetailedHullStage.blocksRuntime("SH040"))
    #expect(ShipCatalogue.rawMesh("SH040") == nil)
  }
}
