import Foundation

/// New release placement only. Existing independent fragments retain their recorded motion.
/// This support-plane construction grants no spawn permission; common admission still proves it.
enum NativeSalvageReleasePlacement {
  @inline(never)
  static func outsideParent(
    _ lots: [SalvageLot], mesh: Mesh, pose: ShipPose, normal: Vector3
  ) throws -> [SalvageLot] {
    guard !mesh.vertices.isEmpty, mesh.vertices.allSatisfy(\.finite),
      pose.position.finite, pose.orientation.validRotation, normal.finite, normal.length > 0
    else { throw HullSweepFailure.invalidGeometry }
    let direction = normal.unit
    let support = mesh.vertices.reduce(-Double.infinity) { max($0, $1.dot(direction)) }
    guard support.isFinite else { throw HullSweepFailure.invalidGeometry }
    return try lots.map { lot in
      let radius = lot.halfExtents.length
      guard lot.position.finite, radius.isFinite, radius > 0 else {
        throw HullSweepFailure.invalidGeometry
      }
      let local = pose.shipPoint(lot.position)
      // Preserve the original 10-unit release gap, including the 8-unit admission clearance.
      let advance = max(0, support + radius + 10 - local.dot(direction))
      guard advance.isFinite else { throw HullSweepFailure.invalidMotion }
      if advance == 0 { return lot }
      var placed = lot
      placed.position = lot.position + pose.orientation.apply(direction * advance)
      guard placed.position.finite else { throw HullSweepFailure.invalidMotion }
      return placed
    }
  }
}
