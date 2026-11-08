import Foundation
import Testing

@testable import L337Core

/// Controlled geometry/velocity queries only, not a C03 archive, source or custody producer.
struct NativeC03RegisterGeometryUnitTests {
  private func scene(distance: Double = 100, rotated: Bool = false) throws -> (Game, Int, UUID) {
    var (game, _, index) = try actualMissionBridgeGame()
    var body = game.bodies[index]
    let component = try #require(body.scriptNPC?.components.values.first?.identity)
    var models: [String: String] = [:]
    for (name, design) in [
      (NativeC03RegisterGeometry.rootModel, NativeC03RegisterGeometry.rootDesign),
      (NativeC03RegisterGeometry.faceModel, NativeC03RegisterGeometry.faceDesign),
    ] {
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      models[name] = hash
      game.commander.scriptState.geometry[hash] = design
    }
    body.scriptNPC = .init(
      fit: .init(definition: NativeC03RegisterGeometry.profile, models: models), fuel: 0,
      guns: [:], components: [
        NativeC03RegisterGeometry.component: .init(identity: component, energy: 1, guns: [:]),
      ])
    body.energy = 16
    body.position = .init(31, -17, 53)
    body.orientation = .init()
    if rotated { body.orientation.rotate(pitch: 0.27, roll: -0.39, yaw: 0.62) }
    body.rotation = rotated ? 0.3 : 0
    body.rotationRate = 0
    try #require(body.scriptNPC?.valid == true)
    game.bodies = [body]
    game.celestials = []
    game.speed = 0
    game.autoPilot.setApproachVelocity(.init(0, 0, 0))
    let previous = game.commander.flightSimulation.pose
    let centre = body.position + body.modelVector(NativeC03RegisterGeometry.componentPosition
      + .init(0, 0, NativeC03RegisterGeometry.plateHeight + 0.035))
    let normal = body.modelVector(.init(0, 0, 1))
    var pose = ShipPose(position: previous.systemPoint(centre + normal * distance))
    pose.orientation.z = previous.orientation.apply(normal * -1)
    pose.orientation.y = previous.orientation.apply(body.modelVector(.init(0, 1, 0)))
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.rotateScriptNPCVelocities(from: previous, to: pose)
    try #require(game.gameplayContext()?.player.velocity.length == 0)
    return (game, body.id, component)
  }

  @Test func archiveAndOpticalFaceAreClosedDistinctPassiveGeometry() throws {
    for design in [NativeC03RegisterGeometry.rootDesign, NativeC03RegisterGeometry.faceDesign] {
      #expect(ScriptPackLibrary.scriptGeometryValid(design))
      let mesh = design.rawMesh
      for block in 0..<(mesh.vertices.count / 8) {
        let vertices = Array(mesh.vertices[(block * 8)..<(block * 8 + 8)])
        let centre = vertices.reduce(Vector3(0, 0, 0), +) * 0.125
        var edges: [String: Int] = [:]
        for face in mesh.faces[(block * 12)..<(block * 12 + 12)] {
          let a = mesh.vertices[face[0]]
          let b = mesh.vertices[face[1]]
          let c = mesh.vertices[face[2]]
          #expect((b - a).cross(c - a).dot(a - centre) > 0)
          for (u, v) in [(face[0], face[1]), (face[1], face[2]), (face[2], face[0])] {
            edges["\(min(u, v)):\(max(u, v))", default: 0] += 1
          }
        }
        #expect(edges.count == 18 && edges.values.allSatisfy { $0 == 2 })
      }
    }
    #expect(NativeC03RegisterGeometry.rootDesign.vertices.count == 8)
    #expect(NativeC03RegisterGeometry.faceDesign.vertices.count == 32)
    let profile = NativeC03RegisterGeometry.profile
    #expect(profile.valid && profile.speed == 0 && profile.acceleration == 0 && profile.recharge == 0)
    #expect(profile.drive == nil && profile.missiles == 0 && profile.fuel == 0 && !profile.ecm)
    #expect(profile.components?.count == 1 && profile.lasers?.isEmpty == true)
    #expect(NativeC03RegisterGeometry.component == NativeHollowManifestStage.recoverRegister.requiredTargets.first)
  }

  @Test(arguments: [false, true])
  func actualCloseRangeRotatedQueriesMeasureTheFaceWithoutGrantingRegisterCustody(rotated: Bool) throws {
    for distance in [50.1, 149.9] {
      let (game, id, component) = try scene(distance: distance, rotated: rotated)
      let before = game.commander
      let bodies = game.bodies
      let reading = try #require(try NativeC03RegisterProbe.measure(
        in: game, bodyID: id, component: component))
      #expect(reading.shapeValid && reading.surfaceRanges.count == 12)
      #expect(reading.observerPose == game.commander.flightSimulation.pose)
      #expect(reading.rayOrigin == reading.observerPose.position)
      #expect(reading.surfaceRelativeSpeed == 0)
      for (actual, expected) in zip(reading.heights, NativeC03RegisterGeometry.reliefHeights) {
        #expect(abs(actual - expected) < 1e-7)
      }
      #expect(game.commander == before && game.bodies == bodies)
      #expect(game.hollowManifestMission == nil)
    }
  }

  @Test func actualOcclusionForeignFaceAndExcessRelativeVelocityRefuse() throws {
    var (game, id, component) = try scene(rotated: true)
    _ = try #require(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component))
    #expect(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: UUID()) == nil)
    var spinning = game
    let body = try #require(spinning.bodies.first)
    // Negative-only native omega. The centre stays stationary while the sampled edges move
    // too fast, so a centre-only relative-speed check would incorrectly accept this snapshot.
    spinning.bodies[0].physical?.angularVelocity = spinning.modelPose(of: body).orientation.z * 10
    #expect(try NativeC03RegisterProbe.measure(in: spinning, bodyID: id, component: component) == nil)
    game.speed = 0.2
    #expect(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component) == nil)
    game.speed = 0
    var blocker = try #require(game.bodies.first)
    blocker.id += 1000
    blocker.position.z -= 20
    game.bodies.append(blocker)
    #expect(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component) == nil)
    game.bodies.removeLast()
    game.bodies[0].scriptNPC?.components[NativeC03RegisterGeometry.component]?.energy = 0
    #expect(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component) == nil)
  }

  @Test func missingGeometryAndOutOfRangeCannotBecomeARegisterTransfer() throws {
    var (game, id, component) = try scene()
    _ = try #require(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component))
    let hash = try #require(game.bodies.first?.scriptNPC?.fit.models[NativeC03RegisterGeometry.faceModel])
    game.commander.scriptState.geometry.removeValue(forKey: hash)
    #expect(try NativeC03RegisterProbe.measure(in: game, bodyID: id, component: component) == nil)
    for distance in [30.0, 170.0] {
      let (outside, id, component) = try scene(distance: distance)
      #expect(try NativeC03RegisterProbe.measure(in: outside, bodyID: id, component: component) == nil)
    }
  }
}
