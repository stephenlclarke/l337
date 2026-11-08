import Foundation

/// The original rod/shoe interface after an actual native internal stop. It
/// carries zero force; all complete-solid vertices must continue separating.
enum CurrentNewtOpeningContactProof {
  static func proves(rod: CurrentNewtKitComponent, shoe: CurrentNewtKitComponent,
    parent: CurrentNewtRigidCoast, pod: CurrentNewtRigidCoast,
    duration: Double, source: CurrentNewtKitSource) -> Bool
  {
    guard duration.isFinite, duration > 0,
      CurrentNewtDriveContact.surface(rod: rod, shoe: shoe, source: source) != nil,
      let a = rod.collisionMesh, let b = shoe.collisionMesh
    else { return false }
    let aExtent = (rod.pose.position - parent.initial.pose.position).length
      + (a.vertices.map(\.length).max() ?? .infinity)
    let bExtent = (shoe.pose.position - pod.initial.pose.position).length
      + (b.vertices.map(\.length).max() ?? .infinity)
    // The separating plane uses point/velocity differences. Bound both actual
    // coasts in the same translating frame; no contact rule or force is waived.
    let reference = parent.initial.velocity
    guard let va = parent.pointSpeedBound(localExtent: aExtent, relativeTo: reference),
      let vb = pod.pointSpeedBound(localExtent: bExtent, relativeTo: reference),
      let aa = parent.pointAccelerationBound(localExtent: aExtent),
      let ab = pod.pointAccelerationBound(localExtent: bExtent)
    else { return false }
    let normal = shoe.pose.orientation.x
    let normalRate = shoe.angularVelocity.cross(normal)
    let omega = pod.maximumWorldAngularSpeed
    let alpha = pod.maximumWorldAngularAcceleration
    for av in a.vertices {
      let aPoint = rod.pose.systemPoint(av)
      let aVelocity = rod.velocity + rod.angularVelocity.cross(rod.pose.orientation.apply(av))
      for bv in b.vertices {
        let bPoint = shoe.pose.systemPoint(bv)
        let bVelocity = shoe.velocity + shoe.angularVelocity.cross(shoe.pose.orientation.apply(bv))
        let offset = bPoint - aPoint
        let gap = normal.dot(offset)
        let derivative = normal.dot(bVelocity - aVelocity) + normalRate.dot(offset)
        let positionBound = offset.length + (va + vb) * duration
        let second = (2 * (alpha + omega * omega) * positionBound
          + 4 * omega * (va + vb) + 2 * (aa + ab)).nextUp
        let numerical = 128 * Double.ulpOfOne * max(1, aPoint.length + bPoint.length)
        guard gap.isFinite, derivative.isFinite, second.isFinite, gap >= -numerical else { return false }
        let rateError = 128 * Double.ulpOfOne * max(1, abs(derivative) + second * duration)
        if derivative - second * duration > rateError { continue }
        let lower = gap + min(0, derivative * duration) - 0.5 * second * duration * duration
        guard lower > numerical else { return false }
      }
    }
    return true
  }
}
