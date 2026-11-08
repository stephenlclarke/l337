import Foundation

/// Physical measurements only. A reading grants no original identity, consent or stage receipt.
/// The mission observer must separately join its live original, captain and attained interval.
enum NativeC03SealProbe {
  struct Reading: Codable, Equatable, Sendable {
    let actor: ActorIdentity
    let component: UUID
    let slot: NativeC03SealGeometry.Slot
    let physicalTime: Double
    let rootPose: ShipPose
    /// Metres above the measured plate, in the actual component's local normal direction.
    let reliefHeights: [Double]
    let surfaceRanges: [Double]
    let maximumProbeAngle: Double
  }

  /// Twelve zero-radius first-hit queries: three adjacent probes on the plate and each relief.
  /// Every opaque body and the parent hull remain in the ordinary collision competition.
  static func measure(
    in game: borrowing Game, bodyID: Int, component: UUID,
    slot: NativeC03SealGeometry.Slot, origin: Vector3
  ) throws -> Reading? {
    guard origin.finite,
      let body = game.bodies.first(where: { $0.id == bodyID }), body.energy > 0,
      let actor = body.physical?.identity,
      let npc = body.scriptNPC, let part = npc.components[slot.rawValue],
      part.identity == component, part.energy > 0,
      let declaration = npc.fit.definition.components?.first(where: { $0.id == slot.rawValue }),
      (declaration.model == slot.model
        || (declaration.model == NativeHollowManifestCommission.sealModel
          && npc.fit.definition.id == "c03-original-" + slot.rawValue)),
      declaration.scale == NativeC03SealGeometry.componentScale,
      declaration.position == NativeC03SealGeometry.componentPosition,
      declaration.orientation == NativeC03SealGeometry.componentOrientation
    else { return nil }
    let pose = game.modelPose(of: body)
    let player = game.commander.flightSimulation.pose
    let centre = body.position + body.modelVector(NativeC03SealGeometry.componentPosition)
    let normal = body.modelVector(NativeC03SealGeometry.componentOrientation.z)
    guard (origin - centre).dot(normal) > 0 else { return nil }
    let spacing = NativeC03SealGeometry.surfaceRange.lowerBound
      * NativeC03SealGeometry.maximumAngularProbeSpacing * 0.25
    let offsets = [Vector3(0, 0, 0), .init(spacing, 0, 0), .init(0, spacing, 0)]
    let centres = [Vector3(0, 0, 0.03)] + NativeC03SealGeometry.reliefs.map(\.centre)
    var heights: [Double] = []
    var ranges: [Double] = []
    var maximumAngle = 0.0
    for point in centres {
      var samples: [Double] = []
      var directions: [Vector3] = []
      for offset in offsets {
        let rootPoint = NativeC03SealGeometry.componentPosition
          + NativeC03SealGeometry.componentOrientation.apply(point + offset)
        let aim = body.position + body.modelVector(rootPoint) - origin
        guard aim.finite, aim.length.isFinite, aim.length > 0 else { return nil }
        let direction = aim.unit
        for previous in directions {
          let angle = atan2(previous.cross(direction).length, previous.dot(direction))
          guard angle.isFinite, angle <= NativeC03SealGeometry.maximumAngularProbeSpacing else {
            return nil
          }
          maximumAngle = max(maximumAngle, angle)
        }
        directions.append(direction)
        guard let hit = try game.nearestMissionCollision(
          from: origin, direction: direction, range: NativeC03SealGeometry.surfaceRange.upperBound,
          radius: 0, includePlayer: false),
          hit.hit.target == .body(bodyID), hit.victimPart == slot.rawValue,
          hit.componentUUID == component, hit.hit.point.finite,
          NativeC03SealGeometry.surfaceRange.contains(hit.hit.distance)
        else { return nil }
        ranges.append(hit.hit.distance)
        let rootHit = pose.orientation.inverse(player.systemPoint(hit.hit.point) - pose.position)
        let local = NativeC03SealGeometry.componentOrientation.inverse(
          rootHit - NativeC03SealGeometry.componentPosition)
        guard local.finite else { return nil }
        samples.append(local.z)
      }
      guard let low = samples.min(), let high = samples.max(),
        high - low <= NativeC03SealGeometry.maximumReliefHeightError
      else { return nil }
      heights.append(samples.reduce(0, +) / Double(samples.count))
    }
    guard let plate = heights.first else { return nil }
    return .init(
      actor: actor, component: component, slot: slot,
      physicalTime: game.commander.flightSimulation.physicalTime, rootPose: pose,
      reliefHeights: heights.dropFirst().map { $0 - plate }, surfaceRanges: ranges,
      maximumProbeAngle: maximumAngle)
  }
}
