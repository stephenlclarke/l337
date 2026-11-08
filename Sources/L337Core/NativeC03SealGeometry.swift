import Foundation

/// Root-approved C03 geometry only. This issues no original actor, consent or scan evidence.
enum NativeC03SealGeometry {
  enum Slot: String, CaseIterable, Codable, Sendable {
    case a = "freighter-seal-a"
    case b = "freighter-seal-b"
    var model: String { self == .a ? "asset:c03-seal-relief-a" : "asset:c03-seal-relief-b" }
  }

  struct Geometry: Sendable {
    let physical: OriginalHullPhysicalContract
    /// Complete approved root design, including its appearance and source metadata.
    var rootDesign: ShipDesign { physical.model.nativeDesign }
    let sealDesign: ShipDesign
    var hullLocalSeal: Mesh {
      let mesh = sealDesign.rawMesh
      return .init(
        vertices: mesh.vertices.map { componentPosition + componentOrientation.apply($0) },
        faces: mesh.faces, preserveWinding: true)
    }
  }

  struct Relief: Sendable {
    let centre: Vector3
    let size: Vector3
    let angle: Double
  }

  static let componentPosition = Vector3(6.52, -1, 0)
  static let componentOrientation: Basis3 = {
    var basis = Basis3()
    basis.x = .init(0, 0, -1)
    basis.y = .init(0, 1, 0)
    basis.z = .init(1, 0, 0)
    return basis
  }()
  static let rootScale = 1.0
  static let componentScale = 1.0
  static let hatchTriangles = [[1, 2, 6], [1, 6, 5]]

  // Requirements for a future measured observer; these constants grant no scan capability.
  static let surfaceRange = 250.0...1500.0
  static let maximumAngularProbeSpacing = 0.000004
  static let maximumReliefHeightError = 0.005
  static let reliefs: [Relief] = [
    .init(centre: .init(-0.65, 0.30, 0.03), size: .init(0.50, 0.06, 0.020), angle: 0.20),
    .init(centre: .init(0.30, -0.32, 0.03), size: .init(0.34, 0.04, 0.015), angle: -0.55),
    .init(centre: .init(0.72, 0.24, 0.03), size: .init(0.24, 0.07, 0.025), angle: 0.90),
  ]

  static let onager: Result<Geometry, any Error> = Result {
    let physical = try OriginalHullPhysicalContract.onager.get()
    guard physical.id == OriginalOnagerActivation.id,
      physical.specificationSHA256 == OriginalOnagerActivation.specificationSHA256,
      physical.metresPerSourceUnit == 1, physical.model.coordinateUnits == "metres",
      physical.model.sourcePath
        == "fleet-completion-20261019/batch-02-native-lod/SH018-design.toml",
      physical.model.sourceSHA256
        == "40e2a5fdd0f7945141cb55701deab76a64f974a38133f86333bb4fd8d199fbf6",
      physical.physicalMesh.vertices.count == 140, physical.physicalMesh.faces.count == 236,
      physical.nativeTriangles == 236,
      Array(physical.physicalMesh.faces[6...7]) == hatchTriangles,
      physical.physicalMesh.vertices[1] == .init(6.5, -4.5, -12.5),
      physical.physicalMesh.vertices[2] == .init(6.5, 2.5, -12.5),
      physical.physicalMesh.vertices[6] == .init(6.5, 2.5, 12.5),
      physical.physicalMesh.vertices[5] == .init(6.5, -4.5, 12.5)
    else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    return .init(physical: physical, sealDesign: makeSeal())
  }

  private static func makeSeal() -> ShipDesign {
    var vertices: [[Double]] = []
    var faces: [[Int]] = []
    let corners: [(Double, Double, Double)] = [
      (0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0),
      (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1),
    ]
    let quads = [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ]
    func append(centre: Vector3, size: Vector3, angle: Double = 0) {
      let start = vertices.count
      for (u, v, w) in corners {
        let x = (u - 0.5) * size.x
        let y = (v - 0.5) * size.y
        vertices.append([
          centre.x + x * cos(angle) - y * sin(angle),
          centre.y + x * sin(angle) + y * cos(angle), centre.z + w * size.z,
        ])
      }
      for quad in quads {
        faces.append([quad[0], quad[1], quad[2]].map { start + $0 })
        faces.append([quad[0], quad[2], quad[3]].map { start + $0 })
      }
    }
    append(centre: .init(0, 0, 0), size: .init(2.4, 1.4, 0.03))
    for (u, v) in [(-1.05, -0.55), (-1.05, 0.55), (1.05, -0.55), (1.05, 0.55)] {
      append(centre: .init(u, v, -0.02), size: .init(0.1, 0.1, 0.02))
    }
    for relief in reliefs { append(centre: relief.centre, size: relief.size, angle: relief.angle) }
    return .init(
      vertices: vertices, faces: faces, license: "MIT",
      source:
        "L337 C03 Root-approved Onager hatch seal recipe; authored metres; no original provenance")
  }
}
