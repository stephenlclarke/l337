import Foundation

/// One authenticated fitted component, never a flattened replacement catalogue hull.
/// A mass-only interior allocation intentionally has no collision/display mesh.
struct CurrentNewtKitComponent: Sendable {
  let id: String
  let collisionMesh: Mesh?
  let displayMesh: Mesh?
  let pose: ShipPose
  let massProperties: CurrentNewtKitReceipt.MassProperties
  let velocity: Vector3
  let angularVelocity: Vector3

  var collisionTriangles: Int {
    collisionMesh?.faces.reduce(0, { $0 + max(0, $1.count - 2) }) ?? 0
  }
}

enum CurrentNewtKitGeometry {
  private static let faces = [
    [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
    [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
  ]
  private static let material = ShipMaterial(name: "Newt commissioned mechanism",
    colour: 0x8D969FFF, emissive: false)

  static func mesh(part: [String: Any]) -> Mesh? {
    guard let shape = part["shape"] as? String else { return nil }
    switch shape {
    case "hollowStorageAssembly", "hollowEnvironmentalAssembly":
      guard let centre = vector(part["centreMetres"]),
        let outer = vector(part["dimensionsMetres"]),
        let inner = vector(part["cavityDimensionsMetres"]), positive(outer), positive(inner),
        outer.x > inner.x, outer.y > inner.y, outer.z > inner.z else { return nil }
      return make(vertices: corners(centre, outer) + corners(centre, inner),
        faces: faces + faces.map { $0.reversed().map { $0 + 8 } })
    case "solidBox", "effectiveUniformBoxMassModel":
      guard let centre = vector(part["centreMetres"]),
        let dimensions = vector(part["dimensionsMetres"]), positive(dimensions)
      else { return nil }
      return make(vertices: corners(centre, dimensions), faces: faces)
    case "hollowRectangularPrism":
      guard let centre = vector(part["centreMetres"]),
        let outer = vector(part["outerDimensionsMetres"]),
        let inner = vector(part["innerDimensionsMetres"]), positive(outer), positive(inner)
      else { return nil }
      let a = [outer.x, outer.y, outer.z], b = [inner.x, inner.y, inner.z]
      guard zip(a, b).allSatisfy({ pair in pair.0 >= pair.1 }) else { return nil }
      let vertices = corners(centre, outer) + corners(centre, inner)
      let openPairs = [[4, 5], [2, 3], [0, 1]]
      var open: Set<Int> = []
      for axis in 0..<3 where a[axis] == b[axis] { open.formUnion(openPairs[axis]) }
      var surface: [[Int]] = []
      for i in faces.indices {
        if open.contains(i) {
          let ring = faces[i]
          for j in ring.indices {
            let next = (j + 1) % ring.count
            surface.append([ring[j], ring[next], ring[next] + 8, ring[j] + 8])
          }
        } else {
          surface.append(faces[i])
          surface.append(faces[i].reversed().map { $0 + 8 })
        }
      }
      return make(vertices: vertices, faces: surface)
    case "affineHeightWedge", "affineExtrudedQuadrilateral":
      guard let vertices = vertices(part["verticesMetres"]), vertices.count == 8 else { return nil }
      return make(vertices: vertices, faces: faces)
    case "affineHeightWedgeDifference":
      guard let outer = vertices(part["verticesMetres"]), outer.count == 8,
        let inner = vertices(part["subtractedVerticesMetres"]), inner.count == 8
      else { return nil }
      // The source coating is the thin top layer, not a second filled saddle.
      let cap = [inner[3], inner[2], outer[2], outer[3], inner[7], inner[6], outer[6], outer[7]]
      return make(vertices: cap, faces: faces)
    case "unchangedPinnedSource":
      return OriginalCryostasisCapsule.source?.collisionDesign.rawMesh
    case "pressureCellPointMassApproximation":
      return nil
    default: return nil
    }
  }

  static func mass(part: [String: Any]) -> CurrentNewtKitReceipt.MassProperties? {
    guard let mass = part["massKg"] as? Double, let centre = vector(part["centreMetres"]),
      let tensor = part["inertiaAboutCentreOfMassKgM2"] as? [Double]
    else { return nil }
    let value = CurrentNewtKitReceipt.MassProperties(massKilograms: mass,
      centreOfMassMetres: centre, inertiaKgM2: tensor)
    return CurrentNewtKitMass.componentIsValid(value) ? value : nil
  }

  private static func vector(_ value: Any?) -> Vector3? {
    guard let a = value as? [Double], a.count == 3, a.allSatisfy(\.isFinite) else { return nil }
    return .init(a[0], a[1], a[2])
  }

  private static func vertices(_ value: Any?) -> [Vector3]? {
    guard let a = value as? [[Double]], !a.isEmpty else { return nil }
    let parsed = a.compactMap { vector($0) }
    return parsed.count == a.count ? parsed : nil
  }

  private static func positive(_ value: Vector3) -> Bool {
    value.finite && value.x > 0 && value.y > 0 && value.z > 0
  }

  private static func corners(_ c: Vector3, _ dimensions: Vector3) -> [Vector3] {
    let h = dimensions * 0.5
    return [
      c + .init(-h.x, -h.y, -h.z), c + .init(h.x, -h.y, -h.z),
      c + .init(h.x, h.y, -h.z), c + .init(-h.x, h.y, -h.z),
      c + .init(-h.x, -h.y, h.z), c + .init(h.x, -h.y, h.z),
      c + .init(h.x, h.y, h.z), c + .init(-h.x, h.y, h.z),
    ]
  }

  private static func make(vertices: [Vector3], faces: [[Int]]) -> Mesh {
    Mesh(vertices: vertices, faces: faces, materials: [material],
      faceMaterials: Array(repeating: 0, count: faces.count), preserveWinding: true)
  }
}
