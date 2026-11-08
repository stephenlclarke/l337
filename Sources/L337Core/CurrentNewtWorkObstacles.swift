import Foundation

extension Game {
  /// Static internal fittings can use the existing rigid native work sweep.
  /// During powered internal motion, that sweep cannot authorize thrust: G1's
  /// actual source-curve/contact owner still advances the unpowered scene once.
  mutating func currentNewtRigidWorkObstacles(for body: SpaceBody) -> [HullSweepObstacle]? {
    guard let physical = body.physical,
      let parts = try? currentNewtGeometryComponents(for: body), !parts.isEmpty
    else { return nil }
    let stock: CurrentNewtKitStock?
    if let receipt = physical.currentNewtKitReceipt {
      stock = commander.savedEMPState?.records[receipt.issue.person.source]?
        .hull.body.physical?.currentNewtKitStock
      guard stock?.receipt == receipt else { return nil }
    } else { stock = physical.currentNewtKitStock }
    if let stock, stock.interruptedAt == nil, stock.actuation != nil {
      guard let source = CurrentNewtKitSource.current else { return nil }
      // A nominal completion clock cannot turn unfinished independent motion
      // into a rigid obstacle. Only actual retained work establishes the stop.
      if stock.phase == .actuating || stock.work.rodMetres < source.stroke
        || stock.work.rodVelocity != 0 { return nil }
    }
    var obstacles: [HullSweepObstacle] = []
    for part in parts {
      guard let mesh = part.collisionMesh else { continue }
      guard let hull = preparedWorkHull(mesh: mesh,
        key: "newt-work:\(physical.identity.entity):\(part.id)")
      else { return nil }
      obstacles.append(.init(identity: physical.identity, hull: hull, pose: part.pose,
        velocity: part.velocity, angularVelocity: part.angularVelocity, clearanceOverride: 0))
    }
    return obstacles.isEmpty ? nil : obstacles
  }
}
