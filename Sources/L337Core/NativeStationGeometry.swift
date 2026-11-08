import Foundation

/// The same original catalogue mesh and port serve every native consumer.
struct NativeStationGeometry: Sendable {
  struct Bounds: Sendable, Equatable {
    let minimum: Vector3
    let maximum: Vector3
    func support(_ direction: Vector3) -> Double {
      Vector3(
        direction.x >= 0 ? maximum.x : minimum.x,
        direction.y >= 0 ? maximum.y : minimum.y,
        direction.z >= 0 ? maximum.z : minimum.z
      ).dot(direction)
    }
  }

  struct Port: Codable, Sendable, Equatable {
    let center: Vector3
    let outward: Vector3
    let up: Vector3
    let tunnelDepth: Double
    let aperture: [Vector3]

    var valid: Bool {
      guard center.finiteStationVector, outward.finiteStationVector, up.finiteStationVector,
        abs(outward.length - 1) < 1e-8, abs(up.length - 1) < 1e-8,
        abs(outward.dot(up)) < 1e-8, tunnelDepth.isFinite, tunnelDepth > 0,
        (3...64).contains(aperture.count),
        aperture.allSatisfy({ $0.finiteStationVector && $0.z == 0 })
      else { return false }
      for index in aperture.indices {
        let a = aperture[index]
        let next = (index + 1) % aperture.count
        let edge = aperture[next] - a
        guard edge.length.isFinite, edge.length > 0 else { return false }
        for other in aperture.indices where other != index && other != next {
          let cross = edge.x * (aperture[other].y - a.y) - edge.y * (aperture[other].x - a.x)
          guard cross.isFinite, cross > 0 else { return false }
        }
      }
      return true
    }

    /// Convex aperture containment proves the whole aligned mesh's transverse projection fits.
    /// It does not prove an approach through the station, or clearance from another actor.
    func fits(_ player: Mesh, margin: Double = 0) -> Bool {
      guard valid, margin.isFinite, margin >= 0, player.vertices.count >= 4,
        player.vertices.allSatisfy({ $0.finiteStationVector }),
        player.vertices.contains(where: { $0.length > 0 }), player.faces.count >= 4,
        player.faces.allSatisfy({ face in
          face.count >= 3 && face.allSatisfy { player.vertices.indices.contains($0) }
        })
      else { return false }
      for index in aperture.indices {
        let a = aperture[index]
        let b = aperture[(index + 1) % aperture.count]
        let edge = b - a
        let length = edge.length
        guard length > 0 else { return false }
        // The aperture is counterclockwise in the port's x/y plane.
        for vertex in player.vertices {
          let distance = (edge.x * (vertex.y - a.y) - edge.y * (vertex.x - a.x)) / length
          guard distance > margin else { return false }
        }
      }
      return true
    }
  }

  struct Exit: Sendable, Equatable {
    let center: Vector3
    let direction: Vector3
    let orientation: Basis3
    let clearance: Double
  }

  static let adapterRevision = "original-station-geometry-v1"
  let site: OriginalStationSite
  let mesh: Mesh
  let bounds: Bounds
  let docking: Port
  let launch: Port
  init?(site: OriginalStationSite, mesh: Mesh, port: Port) {
    guard port.valid, !mesh.vertices.isEmpty,
      mesh.vertices.allSatisfy({ $0.finiteStationVector }),
      let minX = mesh.vertices.map(\.x).min(), let maxX = mesh.vertices.map(\.x).max(),
      let minY = mesh.vertices.map(\.y).min(), let maxY = mesh.vertices.map(\.y).max(),
      let minZ = mesh.vertices.map(\.z).min(), let maxZ = mesh.vertices.map(\.z).max()
    else { return nil }
    self.site = site
    self.mesh = mesh
    bounds = .init(minimum: .init(minX, minY, minZ), maximum: .init(maxX, maxY, maxZ))
    docking = port
    launch = port
  }
  func position(in anchors: SystemAnchors) -> Vector3? { site.sourcePose(in: anchors)?.position }

  /// Analytic separating-plane proof: every player vertex is beyond the complete
  /// structural station bound, and motion along direction only increases separation.
  /// Runtime must separately sweep against all other scene actors and celestials.
  func exit(for player: Mesh, clearance: Double = 1000) -> Exit? {
    guard launch.fits(player), clearance.isFinite, clearance > 0 else { return nil }
    let direction = launch.outward
    var orientation = Basis3()
    orientation.x = .init(direction.z, 0, 0)
    orientation.z = direction
    let rear = player.vertices.map { orientation.apply($0).dot(direction) }.min()!
    let distance = bounds.support(direction) - launch.center.dot(direction) - rear + clearance
    guard distance.isFinite, distance > 0 else { return nil }
    return .init(
      center: launch.center + direction * distance,
      direction: direction, orientation: orientation, clearance: clearance)
  }

}

extension Vector3 {
  fileprivate var finiteStationVector: Bool {
    [x, y, z].allSatisfy { $0.isFinite && abs($0) <= 1e12 }
  }
}
