import Foundation
import Testing

@testable import L337Core

struct NativeC01OriginalPropUnitTests {
  @Test func originalResourcesDecodeClosedMetreGeometryAndActualFaces() throws {
    for kind in [NativeC01Props.Kind.relay, .standard] {
      let record = try (kind == .relay ? NativeC01Props.relay : NativeC01Props.standard).get()
      #expect(record.sourceSHA256 == kind.recipeSHA256)
      #expect(record.sourcePath == kind.sourcePath)
      #expect(record.nativeDesign != record.design)
      #expect(try PreparedHull(mesh: record.nativeDesign.rawMesh).isClosed)
      #expect(record.interactionFace.valid(in: record.nativeDesign))
      #expect(record.interactionFace.contains(record.interactionFace.center, in: record.nativeDesign))
      #expect(!record.interactionFace.contains(
        record.interactionFace.center + record.interactionFace.outward, in: record.nativeDesign))
      #expect(!record.interactionFace.contains(
        record.interactionFace.center + record.interactionFace.up * 20, in: record.nativeDesign))
      #expect(record.nativeDesign.faces.count == (kind == .relay ? 500 : 360))
      #expect(record.massKilograms == (kind == .relay ? 7014 : 1000))
      #expect(record.structuralPolicy.valid(kind))
    }
  }

  @Test func resourceDecoderRejectsForeignRecipePolicyScaleFaceAndUnknownKeys() throws {
    let record = try NativeC01Props.relay.get()
    let data = try JSONEncoder().encode(record)
    let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var mutations: [[String: Any]] = []
    for (key, value) in [("sourceSHA256", "wrong" as Any), ("metresPerSourceUnit", 1 as Any),
                         ("id", "foreign" as Any), ("unexpected", true as Any)] {
      var changed = original
      changed[key] = value
      mutations.append(changed)
    }
    var policy = try #require(original["structuralPolicy"] as? [String: Any])
    policy["weapons"] = true
    var changed = original
    changed["structuralPolicy"] = policy
    mutations.append(changed)
    var face = try #require(original["interactionFace"] as? [String: Any])
    face["nativeFaceIndices"] = [0]
    changed = original
    changed["interactionFace"] = face
    mutations.append(changed)
    for changed in mutations {
      let bytes = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
      #expect(throws: (any Error).self) { try NativeC01Props.decode(bytes, kind: .relay) }
    }
    #expect(throws: (any Error).self) { try NativeC01Props.decode(Data(), kind: .relay) }
    #expect(throws: (any Error).self) { try NativeC01Props.decode(data, kind: .standard) }
  }

  @Test func actualRelayFirstHitReloadRepeatedHitsAndDeathPreserveLawWithoutShipCredit() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    var game = try await f.atRelays()
    try f.park(&game, at: .inner)
    // This deep-space assault has a real native police witness, not station-wide sight.
    let observation = try #require(game.gameplayContext())
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    let request = SpawnRequest(
      identity: .init(
        system: observation.system, visit: observation.visit, sequence: sequence, member: 0,
        producer: .security),
      population: .police, hull: .viper,
      position: observation.player.position + observation.player.orientation.apply(.init(500, 0, 0)),
      orientation: observation.player.orientation, velocity: .init(0, 0, 0),
      npc: .init(role: .police, origin: observation.system, destination: observation.system),
      rock: nil, payload: nil, priority: .police)
    let admissions = game.admitEncounterPlan(.init(
      system: observation.system, visit: observation.visit, revision: observation.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
    let witnessID = try #require(admissions.first?.actor)
    let witnessBody = try #require(game.bodies.first { $0.physical?.identity == witnessID })
    try #require(witnessBody.hull == .viper
      && witnessBody.physical?.spawnIdentity?.producer == .security)
    let witnessedScene = try #require(game.gameplayContext())
    let witness = try #require(witnessedScene.actors.first { $0.identity == witnessID })
    try #require(witness.energy > 0 && witness.npc?.role == .police && witness.legal.value == 0
      && !witnessedScene.protection.protectedActors.contains(witnessID))
    let witnessMesh = game.gameplayMesh(for: witnessBody)
    let maximumWitnessRadius = witnessMesh.vertices.map { $0.length }.max()
    let witnessRadius = try #require(maximumWitnessRadius)
    try #require(witnessRadius.isFinite && witnessRadius > 0
      && abs(witnessBody.position.x) > witnessRadius)
    let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let actor = try #require(game.c01LaneRepairActor(source: source, target: .inner))
    let index = try #require(game.bodies.firstIndex { $0.id == actor.body.id })
    let player = try #require(game.commander.flightSimulation.player)
    let originResult = game.makeAttackOrigin(owner: player)
    let origin = try #require(originResult)
    let contact = try #require(try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 150, radius: 0, includePlayer: false))
    try #require(contact.hit.target == .body(actor.body.id))
    let actualContactPosition = game.commander.flightSimulation.pose.systemPoint(contact.hit.point)
    try #require((witness.position - actualContactPosition).length <= 2500)
    let priorCareers = game.commander.wantedCareers
    let refused = game.persistNPCStates()
    try #require(refused.isEmpty)
    for (identity, prior) in priorCareers.careers {
      try #require(game.commander.wantedCareers.careers[identity] == prior)
    }
    try #require(game.commander.wantedCareers.playerRecordedKills == priorCareers.playerRecordedKills)
    let witnessLogical = try #require(game.commander.npcPersistence.logicalIdentity(for: witnessID))
    let observedWitness = try #require(game.commander.wantedCareers.careers[witnessLogical])
    try #require(observedWitness.binding == witnessID && observedWitness.legal.value == 0
      && observedWitness.legal.bountyTenths == 0 && observedWitness.recordedKills == 0)
    let kills = game.commander.kills
    let credits = game.commander.credits
    let career = game.commander.wantedCareers
    let firstResult = game.applyCombatHit(
      contact.hit, origin: origin, kind: .laser, damage: 1, laser: .pulse)
    let first = try #require(firstResult)
    #expect(first.victim == actor.body.physical?.identity)
    #expect(game.bodies[index].energy == 99 && !game.bodies[index].hostile)
    #expect(game.bodies[index].physical?.npc?.firstAggressor == player)
    #expect(game.bodies[index].physical?.npc?.intention == .engage(player))
    #expect(game.commander.legal > 0)
    #expect(game.commander.stationSecurity.phase == .investigating)
    #expect(game.isC01StructuralProp(game.bodies[index]))
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    game = await cold.snapshot()
    let loadedIndex = try #require(game.bodies.firstIndex { $0.missionActorID == actor.identity })
    #expect(game.isC01StructuralProp(game.bodies[loadedIndex]))
    #expect(game.bodies[loadedIndex].physical?.npc?.firstAggressor == player)
    let nextResult = game.makeAttackOrigin(owner: player)
    let next = try #require(nextResult)
    let hit = GameplayHit(target: .body(game.bodies[loadedIndex].id),
      distance: game.bodies[loadedIndex].position.length, point: game.bodies[loadedIndex].position)
    game.applyCombatHit(hit, origin: next, kind: .laser, damage: 1, laser: .pulse)
    #expect(game.bodies[loadedIndex].energy == 98 && !game.bodies[loadedIndex].hostile)
    game.applyCombatHit(hit, origin: next, kind: .laser, damage: 1000, laser: .pulse)
    #expect(game.bodies[loadedIndex].energy == 0)
    #expect(game.bodies[loadedIndex].physical?.deathOrigin == next)
    #expect(game.isC01StructuralProp(game.bodies[loadedIndex]))
    #expect(game.commander.kills == kills && game.commander.credits == credits)
    #expect(game.commander.wantedCareers == career)
    #expect(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.isEmpty == true)
    #expect(game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.missionActorID == actor.identity })
    game.persistScriptActors()
    #expect(game.glassMeridianMission?.ownedEncounters[NativeC01LaneRepair.encounter]?
      .actors[NativeC01LaneRepair.Target.inner.rawValue]?.presence == .destroyed)
    #expect(game.commander.valid)
  }

  @Test func actualStandardAndCradleDamageUseSameClosedClassification() async throws {
    for part in [NativeC01TimingStandard.Part.standard, .arm] {
      let f = try await C01LaneRepairJourneyFixture()
      defer { f.clean() }
      var game = try await f.atStandard()
      let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.source)
      let actor = try #require(game.c01TimingStandardActor(source: source, part: part))
      let index = try #require(game.bodies.firstIndex { $0.id == actor.body.id })
      let player = try #require(game.commander.flightSimulation.player)
      let originResult = game.makeAttackOrigin(owner: player)
      let origin = try #require(originResult)
      let hit = GameplayHit(target: .body(actor.body.id), distance: actor.body.position.length,
        point: actor.body.position)
      let kills = game.commander.kills
      let credits = game.commander.credits
      game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 1, laser: .pulse)
      #expect(game.isC01StructuralProp(game.bodies[index]) && !game.bodies[index].hostile)
      #expect(game.bodies[index].physical?.npc?.firstAggressor == origin.owner)
      game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 1000, laser: .pulse)
      #expect(game.bodies[index].energy == 0)
      #expect(game.bodies[index].physical?.deathOrigin == origin)
      #expect(game.commander.kills == kills && game.commander.credits == credits)
      game.resolveDestroyed()
      game.persistScriptActors()
      let loss = try game.recordC01TimingStandardLoss()
      #expect(loss == (part == .standard))
      #expect((game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.loss != nil)
        == (part == .standard))
      #expect(game.commander.valid)
    }
  }

  @Test func foreignLookalikeDoesNotReceiveCanonicalPropExemption() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    var game = try await f.atRelays()
    let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let actor = try #require(game.c01LaneRepairActor(source: source, target: .inner))
    let index = try #require(game.bodies.firstIndex { $0.id == actor.body.id })
    game.bodies[index].missionInstanceID = UUID()
    #expect(!game.isC01StructuralProp(game.bodies[index]))
    let player = try #require(game.commander.flightSimulation.player)
    let originResult = game.makeAttackOrigin(owner: player)
    let origin = try #require(originResult)
    let hit = GameplayHit(target: .body(actor.body.id), distance: actor.body.position.length,
      point: actor.body.position)
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 1, laser: .pulse)
    #expect(game.bodies[index].hostile)
    let kills = game.commander.kills
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 1000, laser: .pulse)
    #expect(game.commander.kills == kills + 1)
  }

  @Test func ordinaryTraderRetainsRetaliationLawAndOneShipKill() throws {
    var game = Game(executive: false)
    game.docked = false
    game.screen = .front
    game.speed = 0
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    game.energy = game.commander.performance.energy
    var body = SpaceBody(id: 10, hull: .cobra, position: .init(0, 0, 1000))
    body.energy = 40
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actorIdentity = try #require(allocatedActor)
    body.physical = .init(identity: actorIdentity,
      population: .civilian, npc: .init(role: .trader, origin: game.systemIdentity,
        destination: game.systemIdentity))
    game.bodies = [body]
    let player = try #require(game.commander.flightSimulation.player)
    let originResult = game.makeAttackOrigin(owner: player)
    let origin = try #require(originResult)
    let hit = GameplayHit(target: .body(10), distance: 1000, point: body.position)
    let kills = game.commander.kills
    let credits = game.commander.credits
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 1, laser: .pulse)
    #expect(game.bodies[0].hostile && game.bodies[0].physical?.npc?.firstAggressor == origin.owner)
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 50, laser: .pulse)
    #expect(game.commander.kills == kills + 1 && game.commander.credits == credits)
    #expect(game.commander.legal == 40)
  }
}
