import Foundation

extension Display {
  /// A claimed fitted body is rendered only through its authenticated phase query.
  /// Component copies carry projection data only; simulation and identities stay in GameRuntime.
  static func drawCurrentNewtKit(
    _ body: SpaceBody, game: borrowing Game, into frame: inout Frame,
    projection: FlightProjection, screen: Screen
  ) -> Bool {
    guard body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil
    else { return false }
    do {
      guard let components = try game.currentNewtGeometryComponents(for: body) else { return true }
      let observer = game.commander.flightSimulation.pose
      let projected = components.compactMap {
        component -> (mesh: Mesh, body: SpaceBody, depth: Double)? in
        guard let mesh = component.displayMesh else { return nil }
        var part = body
        part.position = observer.shipPoint(component.pose.position)
        part.orientation = component.pose.orientation.relative(to: observer.orientation)
        // The source pose already includes physical rotation and mechanism travel.
        part.rotation = 0
        let depth = Game.viewPosition(part.position, screen: screen).z
        guard depth.isFinite else { return nil }
        return (mesh, part, depth)
      }
      for part in projected.sorted(by: { $0.depth > $1.depth }) {
        draw(
          part.body, game: game, into: &frame, projection: projection,
          mesh: part.mesh, screen: screen)
      }
    } catch {
      // Refused current geometry cannot acquire a bare-hull rendering through this entry.
      return true
    }
    return true
  }
}
