import Foundation

/// Geometric facts about one authenticated rod/shoe pair. This is neither a
/// native contact frontier nor permission to omit a parent or any other pair.
struct CurrentNewtDriveSurface: Sendable {
  let rodID: String
  let shoeID: String
  let rodFace: Int
  let shoeFace: Int
  let normal: Vector3
  let point: Vector3
  let gapMetres: Double
  let relativeNormalVelocity: Double
}

enum CurrentNewtDriveContact {
  /// The actual mechanical scene must separately bind kit, actors, phase and paid
  /// force/work. A touching source face alone does not establish driven motion.
  static func surface(
    rod: CurrentNewtKitComponent, shoe: CurrentNewtKitComponent,
    source: CurrentNewtKitSource
  ) -> CurrentNewtDriveSurface? {
    guard rod.validForCurrentNewtQuery, shoe.validForCurrentNewtQuery,
      rod.id.hasPrefix("moving-rod-"), shoe.id.hasPrefix("portable-thrust-shoe-"),
      let rodSource = source.retainedParts.first(where: { $0.id == rod.id }),
      let shoeSource = source.releasedParts.first(where: { $0.id == shoe.id }),
      let rodMesh = rod.collisionMesh, let shoeMesh = shoe.collisionMesh,
      let shoeReference = shoeSource.collisionMesh,
      sameMesh(rodMesh, rodSource.mesh), sameMesh(shoeMesh, shoeReference),
      source.matchesMass(rod.massProperties, rodSource.stowed),
      source.matchesMass(shoe.massProperties, shoeSource.mass),
      let rodFace = supportFace(rodMesh, maximum: true),
      let shoeFace = supportFace(shoeMesh, maximum: false)
    else { return nil }
    let normal = shoe.pose.orientation.x
    guard rod.pose.orientation.x.dot(normal) > 0 else { return nil }
    let rodPoints = rodMesh.faces[rodFace].map { rod.pose.systemPoint(rodMesh.vertices[$0]) }
    let shoePoints = shoeMesh.faces[shoeFace].map { shoe.pose.systemPoint(shoeMesh.vertices[$0]) }
    guard let reference = rodPoints.first, let shoePoint = shoePoints.first else { return nil }
    let scale = max(1, max(reference.length, shoePoint.length))
    let tolerance = 128 * Double.ulpOfOne * scale
    guard let support = rodPoints.map({ ($0 - reference).dot(normal) }).max() else { return nil }
    let supporting = rodPoints.filter { abs(($0 - reference).dot(normal) - support) <= tolerance }
    guard !supporting.isEmpty else { return nil }
    let rodPoint = supporting.reduce(Vector3(0, 0, 0), +) * (1 / Double(supporting.count))
    let gap = (shoePoint - rodPoint).dot(normal)
    guard gap.isFinite,
      shoePoints.allSatisfy({ abs(($0 - shoePoint).dot(normal)) <= tolerance }),
      // The separating support plane applies to the COMPLETE solids. Face
      // removal or an open-mesh surrogate would lose the initial-solid proof.
      rodMesh.vertices.allSatisfy({
        (rod.pose.systemPoint($0) - rodPoint).dot(normal) <= tolerance
      }),
      shoeMesh.vertices.allSatisfy({
        (shoe.pose.systemPoint($0) - shoePoint).dot(normal) >= -tolerance
      }), gap >= -tolerance,
      footprintContains(rodPoints, shoe: shoePoints, pose: shoe.pose, tolerance: tolerance)
    else { return nil }
    let rodVelocity = rod.velocity + rod.angularVelocity.cross(rodPoint - rod.pose.position)
    let shoeVelocity = shoe.velocity + shoe.angularVelocity.cross(rodPoint - shoe.pose.position)
    let relative = (shoeVelocity - rodVelocity).dot(normal)
    guard relative.isFinite else { return nil }
    return .init(rodID: rod.id, shoeID: shoe.id, rodFace: rodFace, shoeFace: shoeFace,
      normal: normal, point: rodPoint, gapMetres: gap, relativeNormalVelocity: relative)
  }

  private static func sameMesh(_ a: Mesh, _ b: Mesh) -> Bool {
    a.vertices == b.vertices && a.faces == b.faces
  }

  /// Source rods are boxes; the shoe's opposing face is a rectangle on its
  /// conformal wedge. Resolve original face indices rather than inventing IDs.
  private static func supportFace(_ mesh: Mesh, maximum: Bool) -> Int? {
    let values = mesh.vertices.map(\.x)
    guard let extreme = maximum ? values.max() : values.min() else { return nil }
    let candidates = mesh.faces.indices.filter { index in
      let face = mesh.faces[index]
      return face.count == 4 && face.allSatisfy { mesh.vertices[$0].x == extreme }
    }
    return candidates.count == 1 ? candidates[0] : nil
  }

  private static func footprintContains(
    _ rod: [Vector3], shoe: [Vector3], pose: ShipPose, tolerance: Double
  ) -> Bool {
    let points = shoe.map { pose.shipPoint($0) }
    guard points.count == 4,
      let y0 = points.map(\.y).min(), let y1 = points.map(\.y).max(),
      let z0 = points.map(\.z).min(), let z1 = points.map(\.z).max(),
      y1 > y0, z1 > z0,
      points.allSatisfy({
        (abs($0.y - y0) <= tolerance || abs($0.y - y1) <= tolerance)
          && (abs($0.z - z0) <= tolerance || abs($0.z - z1) <= tolerance)
      })
    else { return false }
    return rod.allSatisfy { world in
      let point = pose.shipPoint(world)
      return point.y > y0 + tolerance && point.y < y1 - tolerance
        && point.z > z0 + tolerance && point.z < z1 - tolerance
    }
  }
}
