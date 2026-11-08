import Foundation

/// Actual first-hit measurements only. No supplied or decoded Reading authorizes progress.
enum NativeC03WakeProbe {
  struct Reading: Codable, Equatable, Sendable {
    let actor: ActorIdentity
    let mark: NativeC03WakeGeometry.Mark
    let physicalTime: Double
    let pose: ShipPose
    let observerPose: ShipPose
    let rayOrigin: Vector3
    let heights: [Double]
    let surfaceRanges: [Double]
    let maximumProbeAngle: Double

    var shapeValid: Bool {
      guard actor.entity > 1, actor.visit > 0, physicalTime.isFinite, (0...1e12).contains(physicalTime),
        pose.position.finite, pose.position.length.isFinite, pose.orientation.validRotation,
        observerPose.position.finite, observerPose.position.length.isFinite,
        observerPose.orientation.validRotation, rayOrigin.finite, rayOrigin.length.isFinite,
        heights.count == 3, surfaceRanges.count == 12,
        zip(heights, NativeC03WakeGeometry.reliefHeights(mark)).allSatisfy({ pair in
          pair.0.isFinite && abs(pair.0 - pair.1) <= NativeC03WakeGeometry.maximumHeightError
        }),
        surfaceRanges.allSatisfy({ $0.isFinite && NativeC03WakeGeometry.surfaceRange.contains($0) }),
        maximumProbeAngle.isFinite, maximumProbeAngle >= 0,
        maximumProbeAngle <= NativeC03WakeGeometry.maximumProbeAngle
      else { return false }
      for (index, point) in NativeC03WakeGeometry.probeCentres(mark).enumerated() {
        let expected = (pose.systemPoint(point) - rayOrigin).length
        guard expected.isFinite,
          surfaceRanges[(index * 3)..<(index * 3 + 3)].allSatisfy({ abs($0 - expected) < 0.001 })
        else { return false }
      }
      return true
    }
  }

  /// All opaque scene geometry competes with the fragment. The exact fitted mesh is checked,
  /// not just its display name. Three nearby probes measure each plate/raised rib directly.
  static func measure(
    in game: borrowing Game, bodyID: Int, mark: NativeC03WakeGeometry.Mark, origin: Vector3
  ) throws -> Reading? {
    guard origin.finite, game.bodies.filter({ $0.id == bodyID }).count == 1,
      let body = game.bodies.first(where: { $0.id == bodyID }), body.energy > 0,
      let actor = body.physical?.identity, actor.entity > 1,
      let npc = body.scriptNPC, npc.valid,
      npc.fit.definition == NativeC03WakeGeometry.profile(mark),
      let digest = npc.fit.models[mark.model],
      game.withReadOnlyScriptState({ $0.geometry[digest] }) == NativeC03WakeGeometry.design(mark),
      (origin - body.position).dot(body.modelVector(.init(0, 0, 1))) > 0
    else { return nil }
    let pose = game.modelPose(of: body)
    let player = game.commander.flightSimulation.pose
    let spacing = NativeC03WakeGeometry.surfaceRange.lowerBound
      * NativeC03WakeGeometry.maximumProbeAngle * 0.25
    let offsets = [Vector3(0, 0, 0), .init(spacing, 0, 0), .init(0, spacing, 0)]
    var measured: [Double] = []
    var ranges: [Double] = []
    var maximumAngle = 0.0
    for centre in NativeC03WakeGeometry.probeCentres(mark) {
      var heights: [Double] = []
      var directions: [Vector3] = []
      for offset in offsets {
        let aim = body.position + body.modelVector(centre + offset) - origin
        guard aim.finite, aim.length.isFinite, aim.length > 0 else { return nil }
        let direction = aim.unit
        for previous in directions {
          let angle = atan2(previous.cross(direction).length, previous.dot(direction))
          guard angle.isFinite, angle <= NativeC03WakeGeometry.maximumProbeAngle else { return nil }
          maximumAngle = max(maximumAngle, angle)
        }
        directions.append(direction)
        guard let hit = try game.nearestMissionCollision(
          from: origin, direction: direction, range: NativeC03WakeGeometry.surfaceRange.upperBound,
          radius: 0, includePlayer: false),
          hit.hit.target == .body(bodyID), hit.victimPart == nil, hit.componentUUID == nil,
          NativeC03WakeGeometry.surfaceRange.contains(hit.hit.distance), hit.hit.point.finite
        else { return nil }
        let local = pose.orientation.inverse(player.systemPoint(hit.hit.point) - pose.position)
        guard local.finite else { return nil }
        heights.append(local.z)
        ranges.append(hit.hit.distance)
      }
      guard let low = heights.min(), let high = heights.max(),
        high - low <= NativeC03WakeGeometry.maximumHeightError
      else { return nil }
      measured.append(heights.reduce(0, +) / Double(heights.count))
    }
    guard let plate = measured.first else { return nil }
    let reading = Reading(
      actor: actor, mark: mark, physicalTime: game.commander.flightSimulation.physicalTime,
      pose: pose, observerPose: player, rayOrigin: player.systemPoint(origin),
      heights: measured.dropFirst().map { $0 - plate }, surfaceRanges: ranges,
      maximumProbeAngle: maximumAngle)
    return reading.shapeValid ? reading : nil
  }
}
