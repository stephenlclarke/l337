import Foundation
import Testing

@testable import L337Core

struct NativeStationImpactTests {
  @Test(arguments: ["cruise", "residual", "work"])
  func actualNativeTickStopsThePlayerAtASolidOriginalPanelInsteadOfFlyingThrough(_ mode: String) throws {
    var game = try solidApproach()
    let velocity = game.commander.flightSimulation.pose.orientation.z * 576
    switch mode {
    case "residual":
      game.speed = 0
      game.manualResidualFlight = true
      game.autoPilot.setApproachVelocity(game.commander.flightSimulation.pose.shipVector(velocity))
    case "work":
      game.speed = 0
      game.workBraking = .init(velocity: velocity, angularVelocity: .init(0, 0, 0))
    default: game.speed = 32
    }
    let stations = game.bodies.filter { $0.nativeStationIdentity != nil }.map {
      (id: $0.id, point: game.commander.flightSimulation.pose.systemPoint($0.position))
    }
    let celestials = game.celestials.map {
      game.commander.flightSimulation.pose.systemPoint($0.position)
    }
    var hit = false
    for _ in 0..<12 {
      let before = game.commander.flightSimulation.pose
      let movingNPCs = game.bodies.compactMap { body -> (Int, Vector3)? in
        guard body.physical?.npc?.role != .mission, body.physical?.npc != nil else { return nil }
        return (body.id, before.systemPoint(body.position))
      }
      game.tick(delta: 0.1, controls: Controls())
      if game.message == "STATION DOCKING COLLISION" {
        hit = true
        #expect(game.commander.flightSimulation.pose == before)
        #expect(game.speed == 0 && game.flightWorldVelocity.length == 0)
        #expect(game.workGuidance == nil && game.workBraking == nil)
        #expect(game.lastAppliedWorkMotion == nil && !game.manualResidualFlight)
        #expect(!game.docked && game.screen.isFlight)
        #expect(game.stationImpactRevision == game.gameplayRevision)
        #expect(
          movingNPCs.contains { entry in
            let (id, point) = entry
            guard let actor = game.bodies.first(where: { $0.id == id }),
              let velocity = actor.physical?.velocity, velocity.length > 0
            else { return false }
            return (before.systemPoint(actor.position) - point).length > 1e-6
          },
          "An independently moving native NPC must retain its actual collision-frame displacement")
        break
      }
    }
    #expect(hit, "The actual effective player hull must meet the retained solid original station panel")
    for station in stations {
      let body = try #require(game.bodies.first { $0.id == station.id })
      let point = game.commander.flightSimulation.pose.systemPoint(body.position)
      #expect((point - station.point).length < 1e-8)
    }
    for (index, point) in celestials.enumerated() {
      let current = game.commander.flightSimulation.pose.systemPoint(
        game.celestials[index].position)
      #expect((current - point).length < 1e-8)
    }
    #expect(
      game.nativeStationFlightObservations(from: nil, delta: nil).allSatisfy {
        $0.rigidPoseConsistent
      })
  }

  @Test func actualBreakupContactEarnsOriginalStationCoastAndRetainsItAcrossCurrentLoad()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var (game, station, root) = try currentBreakupStationContact()
    let before = try #require(game.commander.nativeStations?.inertia(for: station))
    let breakup = try #require(game.commander.miningLedger.breakups[root])
    try #require(before.valid && before.contacts > 0 && before.momentum.length > 0)
    let start = game.commander.flightSimulation.physicalTime
    let position = try #require(game.commander.nativeStations?.currentPosition(for: station, at: start))
    // Move only the observer clear of the accepted contact. All actors keep their
    // attained world poses, velocities and histories during the subsequent coast.
    var observer = game.commander.flightSimulation.pose
    observer.position = observer.position + observer.orientation.y * 2000
    NativeStationTestFixture.reframe(&game, to: observer)
    game.speed = 0
    game.tick(delta: 0.1, controls: Controls())
    try #require(!game.paused && !game.docked && game.screen.isFlight)
    let end = game.commander.flightSimulation.physicalTime
    let after = try #require(game.commander.nativeStations?.inertia(for: station))
    let attained = try #require(game.commander.nativeStations?.currentPosition(for: station, at: end))
    #expect(after.contacts == before.contacts && after.momentum == before.momentum)
    #expect((attained - position - before.velocity * (end - start)).length < 1e-5)
    #expect((attained - position).length > 0)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let saved = await runtime.snapshot()
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.commander.nativeStations?.inertia(for: station) == after)
    let restoredBreakup = try #require(restored.commander.miningLedger.breakups[root])
    #expect(restoredBreakup.rock == breakup.rock && restoredBreakup.birthMassKg == breakup.birthMassKg)
    #expect(restoredBreakup.aggregateMassKg == breakup.aggregateMassKg)
    #expect(restoredBreakup.motion == saved.commander.miningLedger.breakups[root]?.motion)
    let frame = await cold.advance(delta: 0.1)
    try #require(!frame.paused && !frame.docked && frame.screen.isFlight)
    let retained = try #require(frame.commander.nativeStations?.inertia(for: station))
    #expect(retained.contacts == after.contacts && retained.momentum == after.momentum)
    let expected = try #require(frame.commander.nativeStations?.currentPosition(
      for: station, at: frame.commander.flightSimulation.physicalTime))
    let actualBody = try #require(frame.bodies.first { frame.stationInertialIdentity(for: $0) == station })
    #expect((frame.modelPose(of: actualBody).position - expected).length < 1e-5)
  }

  @Test func refusedEndpointReprojectsEveryCurrentActorWithoutUndoingTheirWorldMotion() throws {
    var game = try solidApproach()
    let before = game.commander.flightSimulation.pose
    var attempted = before
    attempted.position = before.systemPoint(.init(0, 0, 160))
    NativeStationTestFixture.reframe(&game, to: attempted)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    for index in game.bodies.indices where game.bodies[index].nativeStationIdentity != nil {
      game.bodies[index].rotation += game.bodies[index].rotationRate * 0.1
    }
    let points = game.bodies.map { attempted.systemPoint($0.position) }
    let orientations = game.bodies.map { $0.orientation.transformed(by: attempted.orientation) }
    let identities = game.bodies.map { $0.physical?.identity }
    let time = game.commander.flightSimulation.physicalTime
    let shield = game.frontShield
    game.collideWithNativeStationStructures(from: before, delta: 0.1)
    #expect(game.commander.flightSimulation.pose == before)
    #expect(game.commander.flightSimulation.physicalTime == time)
    #expect(game.frontShield < shield && game.message == "STATION DOCKING COLLISION")
    #expect(game.bodies.map { $0.physical?.identity } == identities)
    for index in game.bodies.indices {
      let point = before.systemPoint(game.bodies[index].position)
      let orientation = game.bodies[index].orientation.transformed(by: before.orientation)
      #expect((point - points[index]).length < 1e-8)
      #expect((orientation.x - orientations[index].x).length < 1e-8)
      #expect((orientation.y - orientations[index].y).length < 1e-8)
      #expect((orientation.z - orientations[index].z).length < 1e-8)
    }
  }

  @Test func wrongSideImpactAtTheOriginalMainStationUsesTheSamePhysicalStop() throws {
    var game = try NativeStationTestFixture.launched()
    var pose = ShipPose(position: .init(300, 0, 0))
    pose.orientation.x = .init(0, 0, 1)
    pose.orientation.y = .init(0, 1, 0)
    pose.orientation.z = .init(-1, 0, 0)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 32
    var hit = false
    for _ in 0..<6 {
      let before = game.commander.flightSimulation.pose
      game.tick(delta: 0.1, controls: Controls())
      if game.message == "DOCKING COLLISION" {
        hit = true
        #expect(game.commander.flightSimulation.pose == before)
        #expect(game.speed == 0 && game.flightWorldVelocity.length == 0 && !game.docked)
        break
      }
    }
    #expect(hit)
  }

  @Test func unprovedContactPausesWithoutTurningConservativeRefusalIntoInstantDeath() throws {
    var game = try NativeStationTestFixture.launched()
    let owner = try #require(game.commander.nativeStations?.ledger.world)
    let body = try #require(game.bodies.first {
      $0.nativeStationIdentity == OriginalStationSite.salamander.identity(world: owner)
    })
    let identity = try #require(body.nativeStationIdentity)
    let saved = try #require(game.commander.nativeStations?.pose(for: identity))
    let orientation = try #require(saved.orientation(at: 0))
    let source = try #require(NativeStationSource.binding(for: identity))
    let panel = try sourcePanel(source.geometry.mesh)
    let pose = ShipPose(
      position: saved.position + orientation.apply(panel.point), orientation: orientation)
    // Deliberately unproved initial placement: no prior clear pose can authorize
    // a kinematic contact transport or justify a fabricated terminal collision.
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 0
    let energy = game.energy
    let shield = game.frontShield
    game.tick(delta: 0.1, controls: Controls())
    #expect(game.paused && game.screen.isFlight && game.energy == energy)
    #expect(game.frontShield < shield && game.stationImpactRevision == game.gameplayRevision)
    #expect(game.message == "STATION CONTACT UNRESOLVED - FLIGHT PAUSED")
  }

  @Test(arguments: [false, true])
  func actualRefusedNativeStepRetainsCompleteThreeOrFourMemberCohort(main: Bool) throws {
    var (game, earned, root) = try currentBreakupStationContact(main: main)
    let originalWorld = try #require(game.commander.nativeStations)
    let owner = originalWorld.ledger.world
    var expected = Set([OriginalStationSite.salamander, .frog, .dhole].map {
      StationInertialIdentity.originalStation($0.identity(world: owner))
    })
    if main { expected.insert(earned) }
    let aggregateIndex = try #require(game.bodies.firstIndex { $0.physical?.rock == root })
    let aggregate = game.bodies[aggregateIndex]
    let obstruction = try #require(game.bodies.first {
      $0.nativeStationIdentity == OriginalStationSite.frog.identity(world: owner)
    })
    let sourceID = try #require(obstruction.nativeStationIdentity)
    let source = try #require(NativeStationSource.binding(for: sourceID))
    let panel = try sourcePanel(source.geometry.mesh)
    let interior = game.modelPose(of: obstruction).systemPoint(panel.point)
    // Deliberately unproved initial overlap, using the genuinely born aggregate.
    // This is a refusal witness, never a positive contact or an earned impulse.
    game.bodies[aggregateIndex].position = game.commander.flightSimulation.pose.shipPoint(interior)
    game.persistAsteroidBreakupMotion()
    #expect(game.bodies[aggregateIndex].physical == aggregate.physical)
    var observer = game.commander.flightSimulation.pose
    observer.position = interior + Vector3(0, 0, 2000)
    NativeStationTestFixture.reframe(&game, to: observer)
    game.speed = 0
    let before = game.commander.flightSimulation.physicalTime
    let previous = try #require(game.commander.nativeStations)
    let previousBreakup = try #require(game.commander.miningLedger.breakups[root])
    let poses = game.bodies.filter { $0.hull == .station }.map {
      (id: $0.id, pose: game.modelPose(of: $0))
    }
    game.tick(delta: 0.1, controls: Controls())
    let end = game.commander.flightSimulation.physicalTime
    try #require(game.paused && !game.docked && game.screen.isFlight)
    #expect(end == before + 0.1)
    #expect(game.message.hasPrefix("DEBRIS CONTACT DEFERRED:"))
    #expect(!game.message.contains("STATION ROLLBACK UNPROVEN"))
    let retained = try #require(game.commander.nativeStations)
    let members = retained.stationInertia.filter { $0.station.system == game.systemIdentity }
    #expect(Set(members.map(\.station)) == expected && members.count == (main ? 4 : 3))
    for member in members {
      let prior = previous.inertia(for: member.station)
      #expect(member.valid && member.physicalTime == end && member.priorTime == before)
      #expect(member.massKilograms == member.station.sourceMassKilograms)
      #expect(member.contacts == (prior?.contacts ?? 0))
      #expect(member.momentum == (prior?.momentum ?? Vector3(0, 0, 0)))
      #expect(member.displacement == (prior?.displacement ?? Vector3(0, 0, 0)))
      #expect(member.refusedSteps == (prior?.refusedSteps ?? 0) + 1)
      #expect(abs(member.refusedMotionTime - (prior?.refusedMotionTime ?? 0) - 0.1) < 1e-8)
    }
    for saved in poses {
      let body = try #require(game.bodies.first { $0.id == saved.id })
      #expect(game.modelPose(of: body) == saved.pose)
    }
    #expect(retained.ledger == previous.ledger && retained.poses == previous.poses)
    let finalBreakup = try #require(game.commander.miningLedger.breakups[root])
    #expect(finalBreakup.birthMassKg == previousBreakup.birthMassKg)
    #expect(finalBreakup.aggregateMassKg == previousBreakup.aggregateMassKg)
    #expect(finalBreakup.motion == previousBreakup.motion)
  }

  private func solidApproach() throws -> Game {
    var game = try NativeStationTestFixture.launched()
    let owner = try #require(game.commander.nativeStations?.ledger.world)
    let station = try #require(game.bodies.first {
      $0.nativeStationIdentity == OriginalStationSite.salamander.identity(world: owner)
    })
    let identity = try #require(station.nativeStationIdentity)
    let source = try #require(NativeStationSource.binding(for: identity))
    let model = game.modelPose(of: station)
    let panel = try sourcePanel(source.geometry.mesh)
    let normal = model.orientation.apply(panel.normal)
    let up = abs(normal.y) < 0.9 ? Vector3(0, 1, 0) : Vector3(0, 0, 1)
    var pose = ShipPose()
    pose.orientation.z = normal * -1
    pose.orientation.x = up.cross(pose.orientation.z).unit
    pose.orientation.y = pose.orientation.z.cross(pose.orientation.x)
    let support = try #require(game.commander.playerMesh.vertices.map {
      pose.orientation.apply($0).dot(normal * -1)
    }.max())
    pose.position = model.systemPoint(panel.point) + normal * (support + 80)
    NativeStationTestFixture.reframe(&game, to: pose)
    return game
  }

  private func sourcePanel(_ mesh: Mesh) throws -> (point: Vector3, normal: Vector3) {
    let face = try #require(mesh.faces.filter { $0.count >= 3 }.max { lhs, rhs in
      lhs.map { mesh.vertices[$0].x }.reduce(0, +) / Double(lhs.count)
        < rhs.map { mesh.vertices[$0].x }.reduce(0, +) / Double(rhs.count)
    })
    let points = face.map { mesh.vertices[$0] }
    let point = points.reduce(Vector3(0, 0, 0), +) * (1 / Double(points.count))
    let normal = (points[1] - points[0]).cross(points[2] - points[0]).unit
    try #require(normal.length > 0 && normal.dot(point) > 0)
    return (point, normal)
  }

  private func currentBreakupStationContact(main: Bool = false) throws -> (Game, StationInertialIdentity, RockIdentity) {
    var game = try NativeStationTestFixture.launched()
    let laser = try #require(game.commander.laser(on: .front))
    try #require(laser != .mining)
    let rock = try #require(game.miningFields.flatMap(\.rocks).first {
      $0.identity.field >= 4 && (AsteroidBeltDefinition.chunk(for: $0.identity)?.units ?? 0) > 20
    })
    let chunk = try #require(AsteroidBeltDefinition.chunk(for: rock.identity))
    try #require(rock.birthMassKg != nil && !game.commander.miningLedger.isDepleted(rock.identity))
    var observer = ShipPose(position: rock.position - Vector3(0, 0, rock.radius + 500))
    NativeStationTestFixture.reframe(&game, to: observer)
    game.speed = 0
    game.activateNearbyMiningFields()
    let initial = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
    let physical = try #require(initial.physical)
    // Resolve a real unoccluded firing pose against the complete current scene.
    // Reframing moves only the observer; no rock/NPC/station is removed or moved.
    let directions: [Vector3] = [
      .init(0, 0, 1), .init(0, 0, -1), .init(1, 0, 0),
      .init(-1, 0, 0), .init(0, 1, 0), .init(0, -1, 0),
    ]
    var aimed = false
    for direction in directions {
      observer = ShipPose(position: rock.position - direction * (rock.radius + 500))
      observer.orientation.z = direction
      let up = abs(direction.y) < 0.9 ? Vector3(0, 1, 0) : Vector3(0, 0, 1)
      observer.orientation.x = up.cross(direction).unit
      observer.orientation.y = direction.cross(observer.orientation.x)
      NativeStationTestFixture.reframe(&game, to: observer)
      let contact = try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
        radius: 0, includePlayer: false)
      if contact?.hit.target == .body(initial.id) { aimed = true; break }
    }
    try #require(aimed)
    game.selectFlightTool(.combatLaser)
    try #require(game.selectedFlightTool == .combatLaser)
    try #require(physical.identity.system == game.systemIdentity)
    try #require(physical.identity.visit == game.commander.flightSimulation.visit)
    var fire = Controls()
    fire.fire = true
    // The fitted ordinary weapon owns damage, heat, energy and firing cadence.
    // The finite bound covers the canonical source energy at its fitted damage.
    let shots = Int(ceil(chunk.energy / max(1, laser.damage))) + 2
    let budget = Int(ceil(Double(shots) * max(0.1, laser.firingInterval) / 0.1)) + 20
    for _ in 0..<budget where game.commander.miningLedger.breakups[rock.identity] == nil {
      game.tick(delta: 0.1, controls: fire)
      try #require(!game.paused && !game.docked && game.screen.isFlight)
    }
    let breakup = try #require(game.commander.miningLedger.breakups[rock.identity])
    try #require(breakup.valid && breakup.binding == physical.identity)
    try #require(breakup.birthMassKg == rock.birthMassKg && breakup.aggregateMassKg > 0)
    try #require(game.commander.miningLedger.isDepleted(rock.identity))
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == physical.identity })
    let aggregate = game.bodies[index]
    try #require(aggregate.energy > 0 && (game.asteroidDebrisMassKg(aggregate) ?? 0) > 0)
    let owner = try #require(game.commander.nativeStations?.ledger.world)
    if main { try game.registerOriginalNativeMainStation() }
    let targetIdentity = OriginalStationSite.salamander.identity(world: owner)
    let station = try #require(game.bodies.first {
      main ? $0.id == 0 && $0.hull == .station : $0.nativeStationIdentity == targetIdentity
    })
    let identity = try #require(game.stationInertialIdentity(for: station))
    let mesh: Mesh
    if main { mesh = MainStationGeometry.mesh }
    else { mesh = try #require(NativeStationSource.binding(for: targetIdentity)?.geometry.mesh) }
    let panel = try sourcePanel(mesh)
    let model = game.modelPose(of: station)
    let normal = model.orientation.apply(panel.normal)
    let rockMesh = game.gameplayMesh(for: aggregate)
    let rockOrientation = game.modelPose(of: aggregate).orientation
    let rockSupport = try #require(rockMesh.vertices.map {
      rockOrientation.apply($0).dot(normal * -1)
    }.max())
    let point = model.systemPoint(panel.point) + normal * (rockSupport + 40)
    // Explicit controlled pre-contact pose of an already genuine aggregate.
    // Preserve its actor, mass, energy, orientation, attained velocity and scene.
    game.bodies[index].position = game.commander.flightSimulation.pose.shipPoint(point)
    game.persistAsteroidBreakupMotion()
    #expect(game.bodies[index].physical == aggregate.physical && game.bodies[index].energy == aggregate.energy)
    let placed = try #require(game.commander.miningLedger.breakups[rock.identity])
    #expect(placed.birthMassKg == breakup.birthMassKg && placed.aggregateMassKg == breakup.aggregateMassKg)
    observer.orientation.z = normal * -1
    let up = abs(normal.y) < 0.9 ? Vector3(0, 1, 0) : Vector3(0, 0, 1)
    observer.orientation.x = up.cross(observer.orientation.z).unit
    observer.orientation.y = observer.orientation.z.cross(observer.orientation.x)
    let playerSupport = try #require(game.commander.playerMesh.vertices.map {
      observer.orientation.apply($0).dot(normal * -1)
    }.max())
    let outwardRockSupport = try #require(rockMesh.vertices.map {
      rockOrientation.apply($0).dot(normal)
    }.max())
    observer.position = point + normal * (outwardRockSupport + playerSupport + 20)
    NativeStationTestFixture.reframe(&game, to: observer)
    game.speed = 2
    var observedAggregateImpulse = false
    for _ in 0..<100 where (game.commander.nativeStations?.inertia(for: identity)?.contacts ?? 0) == 0 {
      game.tick(delta: 0.1, controls: Controls())
      try #require(!game.paused && !game.docked && game.screen.isFlight)
      let body = try #require(game.bodies.first { $0.physical?.identity == physical.identity })
      observedAggregateImpulse = observedAggregateImpulse || (body.physical?.velocity.length ?? 0) > 0
    }
    let inertia = try #require(game.commander.nativeStations?.inertia(for: identity))
    let retainedStation = try #require(game.bodies.first { $0.id == station.id })
    try #require(observedAggregateImpulse && inertia.contacts > 0 && inertia.momentum.length > 0)
    try #require(retainedStation.energy > 0)
    try #require(game.stationInertialIdentity(for: retainedStation) == identity)
    if !main { try #require(game.nativeStationBodyIsCurrent(retainedStation)) }
    #expect(inertia.massKilograms == identity.sourceMassKilograms)
    return (game, identity, rock.identity)
  }
}
