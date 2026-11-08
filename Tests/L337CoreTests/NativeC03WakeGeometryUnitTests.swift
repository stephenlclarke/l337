import Foundation
import Testing

@testable import L337Core

/// Controlled query scenes only. No original wake source, loan or mission progress is injected.
struct NativeC03WakeGeometryUnitTests {
  private func scene(mark: NativeC03WakeGeometry.Mark, rotated: Bool = false) throws
    -> (Game, SpaceBody)
  {
    var (game, _, index) = try actualMissionBridgeGame()
    var body = game.bodies[index]
    let design = NativeC03WakeGeometry.design(mark)
    let digest = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
    game.commander.scriptState.geometry[digest] = design
    body.scriptNPC = .init(
      fit: .init(definition: NativeC03WakeGeometry.profile(mark), models: [mark.model: digest]),
      fuel: 0, guns: [:], components: [:])
    body.energy = 1
    body.position = .init(31, -17, 53)
    body.orientation = .init()
    body.rotation = rotated ? 0.3 : 0
    if rotated { body.orientation.rotate(pitch: 0.27, roll: -0.39, yaw: 0.62) }
    body.rotationRate = 0
    try #require(body.scriptNPC?.valid == true)
    try #require(body.physical != nil)
    game.bodies = [body]
    game.celestials = []
    return (game, body)
  }

  private func origin(_ body: SpaceBody, distance: Double = 400) -> Vector3 {
    body.position + body.modelVector(.init(0, 0, distance + NativeC03WakeGeometry.plateHeight + 0.16))
  }

  @Test func threeCanonicalTargetsHaveDistinctClosedMeasuredPatternsAndNoShipCapabilities() throws {
    let marks = NativeC03WakeGeometry.Mark.allCases
    #expect(marks.map(\.rawValue) == NativeHollowManifestStage.followCarrier.requiredTargets)
    var hashes: Set<String> = []
    for mark in marks {
      let design = NativeC03WakeGeometry.design(mark)
      let mesh = design.rawMesh
      #expect(ScriptPackLibrary.scriptGeometryValid(design))
      #expect(mesh.vertices.count == 32 && mesh.faces.count == 48)
      hashes.insert(ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design)))
      for block in 0..<4 {
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
      let profile = NativeC03WakeGeometry.profile(mark)
      #expect(profile.valid && profile.model == mark.model && profile.scale == 1)
      #expect(profile.speed == 0 && profile.acceleration == 0 && profile.recharge == 0)
      #expect(profile.missiles == 0 && profile.fuel == 0 && profile.drive == nil && !profile.ecm)
      #expect(profile.lasers?.isEmpty == true && profile.components?.isEmpty == true)
    }
    #expect(hashes.count == 3)
  }

  @Test(arguments: NativeC03WakeGeometry.Mark.allCases, [false, true])
  func actualFirstHitQueriesMeasureEveryPatternThroughTheRotatedMesh(
    mark: NativeC03WakeGeometry.Mark, rotated: Bool
  ) throws {
    let (game, body) = try scene(mark: mark, rotated: rotated)
    let before = game.commander
    let beforeBodies = game.bodies
    for distance in [250.2, 1499.8] {
      let measured = try #require(NativeC03WakeProbe.measure(
        in: game, bodyID: body.id, mark: mark, origin: origin(body, distance: distance)))
      #expect(measured.shapeValid && measured.mark == mark)
      #expect(measured.actor == body.physical?.identity)
      #expect(measured.pose == game.modelPose(of: body))
      #expect(measured.physicalTime == game.commander.flightSimulation.physicalTime)
      #expect(measured.surfaceRanges.count == 12)
      for (actual, expected) in zip(measured.heights, NativeC03WakeGeometry.reliefHeights(mark)) {
        #expect(abs(actual - expected) < 1e-7)
      }
    }
    #expect(game.commander == before && game.bodies == beforeBodies)
    #expect(game.hollowManifestMission == nil)
  }

  @Test func occlusionWrongSideWrongPatternAndRangeRefuseAfterGenuineMeasurement() throws {
    var (game, body) = try scene(mark: .first, rotated: true)
    let point = origin(body)
    _ = try #require(NativeC03WakeProbe.measure(in: game, bodyID: body.id, mark: .first, origin: point))
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .second, origin: point) == nil)
    let back = body.position + body.modelVector(.init(0, 0, -400))
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .first, origin: back) == nil)
    for distance in [100.0, 1600.0] {
      #expect(try NativeC03WakeProbe.measure(
        in: game, bodyID: body.id, mark: .first, origin: origin(body, distance: distance)) == nil)
    }
    var blocker = body
    blocker.id += 1000
    blocker.position = blocker.position + body.modelVector(.init(0, 0, 100))
    game.bodies.append(blocker)
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .first, origin: point) == nil)
    game.bodies.removeLast()
    game.bodies.append(body)
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .first, origin: point) == nil)
  }

  @Test func aNamedSubstituteOrMissingPhysicalIdentityCannotSupplyTheMeasuredMesh() throws {
    var (game, body) = try scene(mark: .third)
    let point = origin(body)
    _ = try #require(NativeC03WakeProbe.measure(in: game, bodyID: body.id, mark: .third, origin: point))
    let digest = try #require(body.scriptNPC?.fit.models[NativeC03WakeGeometry.Mark.third.model])
    game.commander.scriptState.geometry[digest] = NativeC03WakeGeometry.design(.first)
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .third, origin: point) == nil)
    game.commander.scriptState.geometry[digest] = NativeC03WakeGeometry.design(.third)
    game.bodies[0].physical = nil
    #expect(try NativeC03WakeProbe.measure(
      in: game, bodyID: body.id, mark: .third, origin: point) == nil)
  }

  @Test func proposedTrailUsesThreeInertialPositionsAndRefusesForeignWorldAnchors() throws {
    let world = NativeC03WakeGeometry.world
    let station = StationAnchor(
      identity: .init(system: world, visit: 1, entity: 1), position: .init(0, 0, 0),
      orientation: .init(), exitPosition: .init(0, 0, 1000), exitDirection: .init(0, 0, 1))
    let anchors = SystemAnchors(
      system: world, station: station, arrival: .init(0, 0, 80_000),
      planet: .init(position: .init(0, 0, -100_000), radius: 10_000),
      sun: .init(position: .init(1_000_000, 0, 0), radius: 100_000))
    let layout = try NativeC03WakeGeometry.candidateLayout(anchors: anchors)
    #expect(layout.positions.count == 3 && layout.reference.orientation.validRotation)
    #expect(layout.reference.position == layout.positions[0])
    for (index, point) in layout.positions.enumerated() {
      #expect(point.z == 12_000 + Double(index) * 6000)
      #expect(point.length > 10_000)
      if index > 0 { #expect((point - layout.positions[index - 1]).length > 6000) }
    }
    let foreign = SystemAnchors(
      system: NativeHollowManifestDefinition.freighterWorld, station: station,
      arrival: anchors.arrival, planet: anchors.planet, sun: anchors.sun)
    #expect(throws: NativeC03WakeGeometry.Failure.self) {
      try NativeC03WakeGeometry.candidateLayout(anchors: foreign)
    }
  }
}
