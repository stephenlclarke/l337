import Foundation
import Testing

@testable import L337Core

/// Query fixtures only: no C03 original vessel, captain, fit admission or scan is issued.
struct NativeC03SealGeometryUnitTests {
  private func scene(
    slot: NativeC03SealGeometry.Slot = .a, rotated: Bool = false, originalMasterModel: Bool = false
  ) throws
    -> (Game, Int, UUID)
  {
    var (game, _, index) = try actualMissionBridgeGame()
    var body = game.bodies[index]
    let npc = try #require(body.scriptNPC)
    let old = npc.fit.definition
    let state = try #require(npc.components.values.first)
    let geometry = try NativeC03SealGeometry.onager.get()
    let root = "asset:c03-geometry-test-root"
    let sealModel = originalMasterModel ? NativeHollowManifestCommission.sealModel : slot.model
    let component = ScriptNPCComponent(
      id: slot.rawValue, model: sealModel, scale: NativeC03SealGeometry.componentScale,
      position: NativeC03SealGeometry.componentPosition,
      orientation: NativeC03SealGeometry.componentOrientation, energy: state.energy,
      solid: true, weapons: nil)
    let definition = ScriptNPCDefinition(
      id: originalMasterModel ? "c03-original-" + slot.rawValue : old.id,
      name: old.name, source: old.source, basis: "C03 geometry query fixture only",
      model: root, scale: NativeC03SealGeometry.rootScale, energy: old.energy,
      recharge: old.recharge, speed: old.speed, acceleration: old.acceleration,
      pitch: old.pitch, yaw: old.yaw, roll: old.roll, missiles: old.missiles, fuel: old.fuel,
      ecm: old.ecm, bounty: old.bounty, lasers: nil, components: [component])
    var models: [String: String] = [:]
    for (reference, design) in [(root, geometry.rootDesign), (sealModel, geometry.sealDesign)] {
      let digest = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      models[reference] = digest
      game.commander.scriptState.geometry[digest] = design
    }
    body.scriptNPC = .init(
      fit: .init(definition: definition, models: models), fuel: npc.fuel, guns: [:],
      components: [slot.rawValue: .init(identity: state.identity, energy: state.energy, guns: [:])])
    try #require(body.scriptNPC?.valid == true)
    body.position = .init(31, -17, 53)
    body.orientation = .init()
    body.rotation = rotated ? 0.3 : 0
    if rotated { body.orientation.rotate(pitch: 0.27, roll: -0.39, yaw: 0.62) }
    body.rotationRate = 0
    game.bodies = [body]
    game.celestials = []
    return (game, body.id, state.identity)
  }

  private func contact(_ game: Game, origin: Vector3, point: Vector3) throws
    -> MissionCollisionContact?
  {
    let body = try #require(game.bodies.first)
    let worldOrigin = body.position + body.modelVector(origin)
    let worldPoint = body.position + body.modelVector(point)
    return try game.nearestMissionCollision(
      from: worldOrigin, direction: (worldPoint - worldOrigin).unit,
      range: 1600, radius: 0, includePlayer: false)
  }

  @Test func approvedRootAndAppearanceAreUnchangedAndSlotsIssueNoIdentities() throws {
    let geometry = try NativeC03SealGeometry.onager.get()
    let physical = try OriginalHullPhysicalContract.onager.get()
    #expect(geometry.rootDesign == physical.model.nativeDesign)
    #expect(geometry.physical.physicalMesh.vertices == physical.physicalMesh.vertices)
    #expect(geometry.physical.physicalMesh.faces == physical.physicalMesh.faces)
    #expect(geometry.physical.metresPerSourceUnit == 1)
    #expect(
      NativeC03SealGeometry.Slot.allCases.map(\.rawValue) == [
        "freighter-seal-a", "freighter-seal-b",
      ])
    #expect(Set(NativeC03SealGeometry.Slot.allCases.map(\.model)).count == 2)
    #expect(NativeC03SealGeometry.surfaceRange.contains(250))
    #expect(NativeC03SealGeometry.surfaceRange.contains(1500))
    #expect(!NativeC03SealGeometry.surfaceRange.contains(249.999))
    #expect(!NativeC03SealGeometry.surfaceRange.contains(1500.001))
  }

  @Test func allEightSolidsAreClosedOutwardAndFeetTouchTheUnchangedSkin() throws {
    let geometry = try NativeC03SealGeometry.onager.get()
    let mesh = geometry.sealDesign.rawMesh
    #expect(ScriptPackLibrary.scriptGeometryValid(geometry.sealDesign))
    #expect(mesh.vertices.count == 64 && mesh.faces.count == 96)
    for block in 0..<8 {
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
    let attached = geometry.hullLocalSeal
    for block in 1...4 {
      let foot = attached.vertices[(block * 8)..<(block * 8 + 8)]
      #expect(abs(try #require(foot.map(\.x).min()) - 6.5) < 1e-12)
    }
    #expect(
      attached.vertices.allSatisfy { (-2.0...0).contains($0.y) && (-1.5...1.5).contains($0.z) })
    #expect(NativeC03SealGeometry.componentOrientation.validRotation)
  }

  @Test(arguments: [250.1, 1499.9], [false, true])
  func actualHierarchyHitsEachFeatureBeforeRetainedRootAtBothExampleRanges(
    distance: Double, rotated: Bool
  ) throws {
    let (game, id, identity) = try scene(rotated: rotated)
    let body = try #require(game.bodies.first)
    let origin = Vector3(6.55 + distance, -1, 0)
    for relief in NativeC03SealGeometry.reliefs {
      let local = relief.centre + .init(0, 0, relief.size.z)
      let point =
        NativeC03SealGeometry.componentPosition
        + NativeC03SealGeometry.componentOrientation.apply(local)
      let hit = try #require(try contact(game, origin: origin, point: point))
      #expect(
        hit.hit.target == .body(id) && hit.victimPart == NativeC03SealGeometry.Slot.a.rawValue)
      #expect(hit.componentUUID == identity)
      #expect((hit.hit.point - (body.position + body.modelVector(point))).length < 1e-7)
      #expect(NativeC03SealGeometry.surfaceRange.contains(hit.hit.distance))
      var bare = game
      bare.bodies[0].scriptNPC?.components[NativeC03SealGeometry.Slot.a.rawValue]?.energy = 0
      let root = try #require(try contact(bare, origin: origin, point: point))
      #expect(root.victimPart == nil && root.componentUUID == nil)
      #expect(root.hit.distance > hit.hit.distance + 0.064)
    }
  }

  @Test(arguments: NativeC03SealGeometry.Slot.allCases)
  func actualNormalHitsMeasureRelativeReliefHeightWithoutPatternHash(
    slot: NativeC03SealGeometry.Slot
  ) throws {
    let (game, _, identity) = try scene(slot: slot)
    let body = try #require(game.bodies.first)
    let plate = try #require(try contact(game, origin: .init(400, -1, 0), point: .init(6.55, -1, 0)))
    for relief in NativeC03SealGeometry.reliefs {
      let centre =
        NativeC03SealGeometry.componentPosition
        + NativeC03SealGeometry.componentOrientation.apply(relief.centre)
      let hit = try #require(try contact(game, origin: .init(400, centre.y, centre.z), point: centre))
      #expect(hit.victimPart == slot.rawValue && hit.componentUUID == identity)
      let height = (hit.hit.point - plate.hit.point).dot(body.modelVector(.init(1, 0, 0)))
      #expect(abs(height - relief.size.z) < 1e-7)
    }
  }

  @Test func parentAndOtherOpaqueActorRemainInCompetitionAndMissingSealFailsClosed() throws {
    var (game, id, _) = try scene()
    let back = try #require(try contact(game, origin: .init(-400, -1, 0), point: .init(6.55, -1, 0)))
    #expect(back.hit.target == .body(id) && back.victimPart == nil)
    var occluder = try #require(game.bodies.first)
    occluder.id = id + 1000
    occluder.position.x += 100
    game.bodies.append(occluder)
    let blocked = try #require(try contact(game, origin: .init(400, -1, 0), point: .init(6.55, -1, 0)))
    #expect(blocked.hit.target == .body(occluder.id))
    game.bodies.removeLast()
    let digest = try #require(
      game.bodies[0].scriptNPC?.fit.models[NativeC03SealGeometry.Slot.a.model])
    game.commander.scriptState.geometry.removeValue(forKey: digest)
    #expect(throws: (any Error).self) {
      try contact(game, origin: .init(400, -1, 0), point: .init(6.55, -1, 0))
    }
  }

  @Test(arguments: [false, true])
  func boundedNativeProbeMeasuresReliefHeightsThroughActualRotatedCollisionGeometry(
    rotated: Bool
  ) throws {
    let (game, id, component) = try scene(rotated: rotated)
    let body = try #require(game.bodies.first)
    let origin = body.position + body.modelVector(.init(406.55, -1, 0))
    let before = game.commander
    let bodies = game.bodies
    let reading = try #require(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: .a, origin: origin))
    #expect(reading.actor == body.physical?.identity && reading.component == component)
    #expect(reading.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(reading.rootPose == game.modelPose(of: body))
    #expect(reading.maximumProbeAngle <= NativeC03SealGeometry.maximumAngularProbeSpacing)
    #expect(reading.reliefHeights.count == NativeC03SealGeometry.reliefs.count)
    for (height, relief) in zip(reading.reliefHeights, NativeC03SealGeometry.reliefs) {
      #expect(abs(height - relief.size.z) < NativeC03SealGeometry.maximumReliefHeightError)
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func nativeProbeRejectsForeignComponentOcclusionWrongSideAndMissingSeal() throws {
    var (game, id, component) = try scene()
    let body = try #require(game.bodies.first)
    let origin = body.position + body.modelVector(.init(406.55, -1, 0))
    #expect(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: UUID(), slot: .a, origin: origin) == nil)
    #expect(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: .b, origin: origin) == nil)
    let back = body.position + body.modelVector(.init(-400, -1, 0))
    #expect(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: .a, origin: back) == nil)
    var occluder = body
    occluder.id += 1000
    occluder.position.x += 100
    game.bodies.append(occluder)
    #expect(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: .a, origin: origin) == nil)
    game.bodies.removeLast()
    game.bodies[0].scriptNPC?.components[NativeC03SealGeometry.Slot.a.rawValue]?.energy = 0
    #expect(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: .a, origin: origin) == nil)
  }

  @Test(arguments: NativeC03SealGeometry.Slot.allCases)
  func probeRecognizesOriginalMasterDeclarationWithoutGrantingMissionIdentity(
    slot: NativeC03SealGeometry.Slot
  ) throws {
    let (game, id, component) = try scene(slot: slot, rotated: true, originalMasterModel: true)
    let body = try #require(game.bodies.first)
    let origin = body.position + body.modelVector(.init(406.55, -1, 0))
    let reading = try #require(try NativeC03SealProbe.measure(
      in: game, bodyID: id, component: component, slot: slot, origin: origin))
    #expect(reading.surfaceRanges.count == 12)
    #expect(reading.surfaceRanges.allSatisfy(NativeC03SealGeometry.surfaceRange.contains))
    #expect(reading.reliefHeights.count == 3 && reading.slot == slot)
    #expect(game.hollowManifestInspectionSample() == nil)
    #expect(game.hollowManifestMission == nil)
  }
}
