import Foundation
import Testing

@testable import L337Core

@Test func originalStationGeometryUsesSameTypedCatalogueMeshAndPort() throws {
  let sources = try NativeStationSource.requireBindings()
  #expect(Set(sources.map(\.site)) == Set(OriginalStationSite.allCases))
  for source in sources {
    let ship = try #require(ShipCatalogue.ship(source.site.catalogueID))
    let design = try #require(ship.nativeDesign)
    let port = try #require(ship.nativeDocking)
    #expect(design.valid && port.valid && ship.catalogue.objectKind == .station)
    #expect(source.geometry.site == source.site)
    #expect(source.geometry.mesh.vertices == design.rawMesh.vertices)
    #expect(source.geometry.mesh.faces == design.rawMesh.faces)
    #expect(source.geometry.docking == port && source.geometry.launch == port)
    #expect(source.physical == OriginalStationPhysical.read(from: ship))
    let minimum = design.rawMesh.vertices.reduce(Vector3(.infinity, .infinity, .infinity)) {
      .init(min($0.x, $1.x), min($0.y, $1.y), min($0.z, $1.z))
    }
    let maximum = design.rawMesh.vertices.reduce(Vector3(-.infinity, -.infinity, -.infinity)) {
      .init(max($0.x, $1.x), max($0.y, $1.y), max($0.z, $1.z))
    }
    #expect(source.geometry.bounds.minimum == minimum)
    #expect(source.geometry.bounds.maximum == maximum)
    #expect(source.geometry.docking.tunnelDepth > 0)
    #expect(source.descriptor.sourceRoles == [source.identity(world: UUID()).definition])
  }
}

@Test func originalStationRawMetreGeometryNeedsNoImportedAxisAdaptation() throws {
  let owner = UUID()
  let world = try NativeStationWorld(owner: owner)
  for source in try NativeStationSource.requireBindings() {
    let identity = source.identity(world: owner)
    let saved = try #require(world.pose(for: identity))
    #expect(saved.orientation == Basis3())
    #expect(saved.orientation(at: 0) == saved.orientation(at: 12_345))
    #expect(saved.orientation(at: .nan) == nil)
    #expect(source.rotationRate == 0 && source.recharge == 0)
    let ship = try #require(ShipCatalogue.ship(source.catalogueShipID))
    let design = try #require(ship.nativeDesign)
    let original = design.rawMesh
    // Both vertices and face winding stay in their original metre-space convention.
    #expect(source.geometry.mesh.vertices == original.vertices)
    #expect(source.geometry.mesh.faces == original.faces)
    #expect(source.geometry.launch == source.geometry.docking)
    #expect(saved.orientation.x.cross(saved.orientation.y) == saved.orientation.z)
  }
}

@Test func originalStationPlacementUsesItsExactSiteAndFullSceneSafety() throws {
  let offsets: [OriginalStationSite: Vector3] = [
    .salamander: .init(6000, 0, 0), .frog: .init(-6000, 0, 0),
    .dhole: .init(0, 6000, 0), .remoteUtility: .init(0, -6000, 0),
  ]
  for source in try NativeStationSource.requireBindings() {
    let anchors = NativeStationSource.canonicalAnchors(system: source.system)
    let expected = anchors.station.position + (try #require(offsets[source.site]))
    #expect(source.geometry.position(in: anchors) == expected)
    #expect(source.site.sourcePose(in: anchors)?.position == expected)
    let foreign = NativeStationSource.canonicalAnchors(system: .init(galaxy: 1, system: 7))
    #expect(source.geometry.position(in: foreign) == nil)
    for point in [Vector3(.nan, 0, 0), .init(.infinity, 0, 0)] {
      let bad = SystemAnchors(
        system: anchors.system,
        station: .init(
          identity: anchors.station.identity, position: point,
          orientation: anchors.station.orientation, exitPosition: anchors.station.exitPosition,
          exitDirection: anchors.station.exitDirection),
        arrival: anchors.arrival, planet: anchors.planet, sun: anchors.sun)
      #expect(source.geometry.position(in: bad) == nil)
    }
    // This is a candidate pose, not admission. The actual population tests retain
    // celestial, other-hull and complete-cohort refusal before any publication.
    #expect(source.site.sourcePose(in: anchors)?.orientation == Basis3())
  }
}

@Test func originalStationAperturesAndExitsCheckEveryEffectiveFlyableHull() throws {
  // Performance profiles also cover hulls whose runtime meshes are still pending.
  let profiles = ShipCatalogue.all.filter { $0.game != nil }
  let pending = profiles.filter { OriginalDetailedHullStage.blocksRuntime($0.id) }
  let ships = profiles.filter { !OriginalDetailedHullStage.blocksRuntime($0.id) }
  #expect(profiles.count == 163)
  #expect(pending.count == 140)
  #expect(ships.count == 23)
  #expect(pending.contains { $0.id == "SH001" })
  for ship in pending {
    #expect(ShipCatalogue.rawMesh(ship.id) == nil, "\(ship.id) pending runtime mesh")
  }
  for ship in ships {
    var commander = Commander()
    commander.shipID = ship.id
    let player = commander.playerMesh
    for source in try NativeStationSource.requireBindings() {
      let geometry = source.geometry
      let aperture = geometry.docking.aperture
      // Independent convex half-plane test on the actual effective player vertices.
      let fits: Bool = aperture.indices.allSatisfy { index in
        let a = aperture[index]
        let b = aperture[(index + 1) % aperture.count]
        return player.vertices.allSatisfy { (point: Vector3) -> Bool in
          let firstProduct: Double = (b.x - a.x) * (point.y - a.y)
          let secondProduct: Double = (b.y - a.y) * (point.x - a.x)
          let crossProduct: Double = firstProduct - secondProduct
          return crossProduct > 0
        }
      }
      #expect(geometry.docking.fits(player) == fits, "\(source.site) / \(ship.id) docking")
      #expect(geometry.launch.fits(player) == fits, "\(source.site) / \(ship.id) launch")
      let exit = geometry.exit(for: player)
      #expect((exit != nil) == fits, "\(source.site) / \(ship.id) exit refusal")
      if let exit {
        #expect(exit.orientation.x.cross(exit.orientation.y) == exit.orientation.z)
        #expect(exit.orientation.apply(.init(0, 0, 1)) == exit.direction)
        for vertex in player.vertices {
          let point = exit.center + exit.orientation.apply(vertex)
          let separation = point.dot(exit.direction) - geometry.bounds.support(exit.direction)
          #expect(separation >= exit.clearance - 1e-9, "\(ship.id) exit bound")
          #expect(
            (point + exit.direction * 10000).dot(exit.direction)
              > geometry.bounds.support(exit.direction), "\(ship.id) outward ray")
        }
      }
    }
  }
}

private func stationProbe(around center: Vector3, radius: Double) -> Mesh {
  Mesh(
    vertices: [
      center + .init(-radius, -radius, -1), center + .init(radius, -radius, -1),
      center + .init(radius, radius, 1), center + .init(-radius, radius, 1),
    ],
    faces: [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]])
}

@Test func originalStationAperturesRefuseBoundaryOversizeAndInvalidGeometry() throws {
  for source in try NativeStationSource.requireBindings() {
    let geometry = source.geometry
    let port = geometry.docking
    let center = port.aperture.reduce(Vector3(0, 0, 0), +) * (1 / Double(port.aperture.count))
    let distances = port.aperture.indices.map { index in
      let a = port.aperture[index]
      let b = port.aperture[(index + 1) % port.aperture.count]
      let edge = b - a
      return (edge.x * (center.y - a.y) - edge.y * (center.x - a.x)) / edge.length
    }
    let distance = try #require(distances.min())
    try #require(distance.isFinite && distance > 0)
    let interior = stationProbe(around: center, radius: distance * 0.25)
    #expect(port.fits(interior))
    let a = port.aperture[0]
    let b = port.aperture[1]
    let edgePoint = a
    var boundaryVertices = interior.vertices
    boundaryVertices[0] = edgePoint
    let boundary = Mesh(vertices: boundaryVertices, faces: interior.faces)
    #expect(!port.fits(boundary))
    #expect(geometry.exit(for: boundary) == nil)
    let outward = Vector3(b.y - a.y, a.x - b.x, 0).unit
    var oversizedVertices = interior.vertices
    oversizedVertices[0] = edgePoint + outward
    let oversized = Mesh(vertices: oversizedVertices, faces: interior.faces)
    #expect(!port.fits(oversized))
    #expect(!port.fits(interior, margin: distance * 2))
    #expect(!port.fits(stationProbe(around: center, radius: .infinity)))
    #expect(!port.fits(interior, margin: .nan))
    #expect(geometry.exit(for: interior, clearance: 0) == nil)
    #expect(geometry.exit(for: interior, clearance: .infinity) == nil)
    // A malformed port cannot inherit validity from its otherwise authentic source.
    let invalid = NativeStationGeometry.Port(
      center: port.center, outward: .init(0, 0, 0), up: port.up,
      tunnelDepth: port.tunnelDepth, aperture: port.aperture)
    #expect(!invalid.valid && !invalid.fits(interior))
    #expect(NativeStationGeometry(site: source.site, mesh: geometry.mesh, port: invalid) == nil)
  }
}
