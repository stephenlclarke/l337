import Foundation

extension Game {
  /// Conservative volume/radius queries only. This box is never the physical
  /// collision union: precise consumers retain each authenticated component.
  func currentNewtBroadPhaseEnvelope(for body: SpaceBody) -> Mesh? {
    guard let parts = try? currentNewtGeometryComponents(for: body), !parts.isEmpty else { return nil }
    let model = modelPose(of: body)
    let r = model.orientation
    let x = r.y.cross(r.z), y = r.z.cross(r.x), z = r.x.cross(r.y)
    let determinant = r.x.dot(x)
    guard determinant.isFinite, determinant > 0 else { return nil }
    let inverse = 1 / determinant
    let condition = max(x.length, max(y.length, z.length)) * abs(inverse)
    guard condition.isFinite else { return nil }
    var radius = 0.0
    var found = false
    for part in parts {
      guard let mesh = part.collisionMesh else { continue }
      for vertex in mesh.vertices {
        let world = part.pose.systemPoint(vertex)
        let delta = world - model.position
        // Invert the represented model basis, including its real roundoff.
        // A transpose alone can shrink an approximately orthogonal enclosure.
        let local = Vector3(delta.dot(x), delta.dot(y), delta.dot(z)) * inverse
        let scale = max(1, world.length + model.position.length + local.length)
        let padding = 512 * Double.ulpOfOne * scale * max(1, condition)
        guard world.finite, local.finite, padding.isFinite else { return nil }
        radius = max(radius,
          (max(abs(local.x), max(abs(local.y), abs(local.z))) + padding).nextUp)
        found = true
      }
    }
    guard found, radius.isFinite, radius > 0 else { return nil }
    return workObstacleBox(radius)
  }
}
