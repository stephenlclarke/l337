import Testing

@testable import L337Core

struct NativeStationSurfaceTests {
  @Test func originalExteriorWindingKeepsSolidPanelsAndTheDeclaredPortOpening() throws {
    for source in try NativeStationSource.requireBindings() {
      let mesh = source.geometry.mesh
      #expect(signedVolume(mesh) > 0, "\(source.site) outward solid surfaces")
      let face = try #require(mesh.faces.first { face in
        face.count >= 3 && (mesh.vertices[face[1]] - mesh.vertices[face[0]])
          .cross(mesh.vertices[face[2]] - mesh.vertices[face[0]]).length > 0
      })
      let points = face.map { mesh.vertices[$0] }
      let center = points.reduce(Vector3(0, 0, 0), +) * (1 / Double(points.count))
      let normal = (points[1] - points[0]).cross(points[2] - points[0]).unit
      #expect(visible(points, camera: center + normal * 10))
      let body = SpaceBody(id: 17, hull: .station, position: .init(0, 0, 0))
      let solid = try #require(GameplayRaycast.nearest(
        origin: center + normal * 10, direction: normal * -1, maxDistance: 20,
        bodies: [body], meshOverrides: [body.id: mesh]))
      #expect(solid.target == .body(body.id) && solid.distance <= 10.000001)
      let port = source.geometry.docking
      let opening = GameplayRaycast.nearest(
        origin: port.center + port.outward, direction: port.outward * -1,
        maxDistance: 1 + port.tunnelDepth * 0.5,
        bodies: [body], meshOverrides: [body.id: mesh])
      #expect(opening == nil, "\(source.site) declared opening must not be filled by a panel")
    }
  }

  @Test func originalPortCorridorWallsRemainVisibleToTheArrivingPilot() throws {
    for source in try NativeStationSource.requireBindings() {
      let mesh = source.geometry.mesh
      let port = source.geometry.docking
      let camera = port.center - port.outward * (port.tunnelDepth * 0.5)
      let apertureRadius = try #require(port.aperture.map(\.length).max())
      let corridorFaces = mesh.faces.filter { face in
        let center = face.map { mesh.vertices[$0] }.reduce(Vector3(0, 0, 0), +)
          * (1 / Double(face.count))
        let fromPort = center - port.center
        let depth = -fromPort.dot(port.outward)
        let transverse = fromPort + port.outward * depth
        return depth > 0 && depth < port.tunnelDepth && transverse.length <= apertureRadius * 2
      }
      #expect(!corridorFaces.isEmpty, "\(source.site) actual port corridor surfaces")
      #expect(corridorFaces.contains { face in
        visible(face.map { mesh.vertices[$0] }, camera: camera)
      }, "\(source.site) interior surface winding")
      #expect(source.geometry.launch == port)
    }
  }

  @Test func originalEffectivePortUsesItsExactSourceEnvelopeAndRefusesItsBoundary() throws {
    let compatible = try #require(ShipCatalogue.ship("SH026")?.nativeDesign)
    let player = compatible.rawMesh
    let fresh = Commander()
    try #require(fresh.shipID == "SH025")
    let defaultHull = fresh.playerMesh
    for source in try NativeStationSource.requireBindings() {
      let ship = try #require(ShipCatalogue.ship(source.catalogueShipID))
      let port = try #require(ship.nativeDocking)
      #expect(source.geometry.docking == port && source.geometry.launch == port)
      #expect(source.geometry.docking.fits(player) && source.geometry.launch.fits(player))
      #expect(source.geometry.exit(for: player) != nil)
      if source.site == .salamander {
        #expect(!source.geometry.docking.fits(defaultHull))
        #expect(!source.geometry.launch.fits(defaultHull))
        #expect(source.geometry.exit(for: defaultHull) == nil)
      }
      let small = probe(halfWidth: 1, halfHeight: 1)
      #expect(port.fits(small))
      var vertices = small.vertices
      vertices[0] = port.aperture[0]
      let boundary = Mesh(vertices: vertices, faces: small.faces)
      #expect(!source.geometry.docking.fits(boundary) && !source.geometry.launch.fits(boundary))
      #expect(source.geometry.exit(for: boundary) == nil)
      let original = try #require(ship.nativeDesign)
      #expect(source.geometry.mesh.vertices == original.rawMesh.vertices)
      #expect(source.geometry.mesh.faces == original.rawMesh.faces)
    }
  }

  @Test func realStationTriangleStraddlingTheNearPlaneRetainsItsVisiblePanel() throws {
    for source in try NativeStationSource.requireBindings() {
      let mesh = source.geometry.mesh
      let face = try #require(mesh.faces.first { face in
        let depth = face.map { mesh.vertices[$0].z }
        return (depth.max() ?? 0) - (depth.min() ?? 0) > 1
      })
      let points = face.map { mesh.vertices[$0] }
      let minimum = try #require(points.map(\.z).min())
      let maximum = try #require(points.map(\.z).max())
      let shifted = points.map { $0 + Vector3(0, 0, 1 - (minimum + maximum) * 0.5) }
      #expect(shifted.contains { $0.z < 1 } && shifted.contains { $0.z > 1 })
      let panel = ShipProjection.polygon(shifted)
      #expect(panel.count >= 3 && panel.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
  }

  private func visible(_ points: [Vector3], camera: Vector3) -> Bool {
    let normal = (points[1] - points[0]).cross(points[2] - points[0])
    return normal.dot(points[0] - camera) < 0
  }

  private func signedVolume(_ mesh: Mesh) -> Double {
    mesh.faces.reduce(0) { volume, face in
      guard face.count >= 3 else { return volume }
      let a = mesh.vertices[face[0]]
      return volume + (1..<(face.count - 1)).reduce(0) { subtotal, index in
        subtotal + a.dot(mesh.vertices[face[index]].cross(mesh.vertices[face[index + 1]])) / 6
      }
    }
  }

  private func probe(halfWidth: Double, halfHeight: Double) -> Mesh {
    .init(
      vertices: [
        .init(-halfWidth, -halfHeight, -1), .init(halfWidth, -halfHeight, -1),
        .init(halfWidth, halfHeight, 1), .init(-halfWidth, halfHeight, 1),
      ], faces: [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]])
  }
}
