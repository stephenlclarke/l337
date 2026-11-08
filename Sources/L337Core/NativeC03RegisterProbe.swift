import Foundation

/// One actual optical snapshot, not a register issuance or a data-custody transition.
enum NativeC03RegisterProbe {
  struct Reading: Codable, Equatable, Sendable {
    let actor: ActorIdentity
    let component: UUID
    let physicalTime: Double
    let archivePose: ShipPose
    let observerPose: ShipPose
    let rayOrigin: Vector3
    let surfaceRelativeSpeed: Double
    let heights: [Double]
    let surfaceRanges: [Double]
    let maximumProbeAngle: Double

    var shapeValid: Bool {
      guard actor.entity > 1, actor.visit > 0,
        physicalTime.isFinite, (0...1e12).contains(physicalTime),
        archivePose.position.finite, archivePose.position.length.isFinite,
        archivePose.orientation.validRotation, observerPose.position.finite,
        observerPose.position.length.isFinite, observerPose.orientation.validRotation,
        rayOrigin.finite, rayOrigin.length.isFinite,
        surfaceRelativeSpeed.isFinite, (0...NativeC03RegisterGeometry.maximumRelativeSpeed)
          .contains(surfaceRelativeSpeed),
        heights.count == 3, surfaceRanges.count == 12,
        zip(heights, NativeC03RegisterGeometry.reliefHeights).allSatisfy({ pair in
          pair.0.isFinite && abs(pair.0 - pair.1) <= NativeC03RegisterGeometry.maximumHeightError
        }),
        surfaceRanges.allSatisfy({ $0.isFinite && NativeC03RegisterGeometry.surfaceRange.contains($0) }),
        maximumProbeAngle.isFinite, (0...NativeC03RegisterGeometry.maximumProbeAngle)
          .contains(maximumProbeAngle)
      else { return false }
      for (index, point) in NativeC03RegisterGeometry.probeCentres.enumerated() {
        let expected = (archivePose.systemPoint(NativeC03RegisterGeometry.componentPosition + point)
          - rayOrigin).length
        guard expected.isFinite, surfaceRanges[(index * 3)..<(index * 3 + 3)]
          .allSatisfy({ abs($0 - expected) < 0.001 })
        else { return false }
      }
      return true
    }
  }

  /// Whole-scene first hits must land on the current original face. The data source and the
  /// real kit receiver must subsequently authenticate/commit their unique custody separately.
  static func measure(in game: borrowing Game, bodyID: Int, component: UUID) throws -> Reading? {
    let definition = NativeC03RegisterGeometry.profile
    let alias = NativeC03RegisterGeometry.component
    guard game.bodies.filter({ $0.id == bodyID }).count == 1,
      let body = game.bodies.first(where: { $0.id == bodyID }), body.energy > 0,
      let physical = body.physical, let npc = body.scriptNPC, npc.valid,
      npc.fit.definition == definition, let part = npc.components[alias],
      part.identity == component, part.energy > 0,
      let root = npc.fit.models[NativeC03RegisterGeometry.rootModel],
      let face = npc.fit.models[NativeC03RegisterGeometry.faceModel],
      game.withReadOnlyScriptState({ $0.geometry[root] }) == NativeC03RegisterGeometry.rootDesign,
      game.withReadOnlyScriptState({ $0.geometry[face] }) == NativeC03RegisterGeometry.faceDesign,
      let context = game.gameplayContext(), context.player.identity == game.commander.flightSimulation.player,
      context.physicalTime == game.commander.flightSimulation.physicalTime,
      context.player.velocity.finite, physical.velocity.finite, physical.angularVelocity.finite
    else { return nil }
    let player = game.commander.flightSimulation.pose
    let pose = game.modelPose(of: body)
    let centre = (body.position + body.modelVector(NativeC03RegisterGeometry.componentPosition))
    let normal = body.modelVector(.init(0, 0, 1))
    guard (centre * -1).dot(normal) > 0 else { return nil }
    let spacing = NativeC03RegisterGeometry.surfaceRange.lowerBound
      * NativeC03RegisterGeometry.maximumProbeAngle * 0.25
    let offsets = [Vector3(0, 0, 0), .init(spacing, 0, 0), .init(0, spacing, 0)]
    var relativeSpeed = 0.0
    for centre in NativeC03RegisterGeometry.probeCentres {
      for offset in offsets {
        let point = pose.systemPoint(NativeC03RegisterGeometry.componentPosition + centre + offset)
        let velocity = physical.velocity + physical.angularVelocity.cross(point - pose.position)
        let speed = (context.player.velocity - velocity).length
        guard speed.isFinite, speed <= NativeC03RegisterGeometry.maximumRelativeSpeed else { return nil }
        relativeSpeed = max(relativeSpeed, speed)
      }
    }
    var measured: [Double] = []
    var ranges: [Double] = []
    var maximumAngle = 0.0
    for centre in NativeC03RegisterGeometry.probeCentres {
      var heights: [Double] = []
      var directions: [Vector3] = []
      for offset in offsets {
        let aim = (body.position + body.modelVector(NativeC03RegisterGeometry.componentPosition + centre + offset))
        guard aim.finite, aim.length.isFinite, aim.length > 0 else { return nil }
        let direction = aim.unit
        for previous in directions {
          let angle = atan2(previous.cross(direction).length, previous.dot(direction))
          guard angle.isFinite, angle <= NativeC03RegisterGeometry.maximumProbeAngle else { return nil }
          maximumAngle = max(maximumAngle, angle)
        }
        directions.append(direction)
        guard let hit = try game.nearestMissionCollision(
          from: .init(0, 0, 0), direction: direction,
          range: NativeC03RegisterGeometry.surfaceRange.upperBound, radius: 0, includePlayer: false),
          hit.hit.target == .body(bodyID), hit.victimPart == alias, hit.componentUUID == component,
          NativeC03RegisterGeometry.surfaceRange.contains(hit.hit.distance), hit.hit.point.finite
        else { return nil }
        let local = pose.orientation.inverse(player.systemPoint(hit.hit.point) - pose.position)
          - NativeC03RegisterGeometry.componentPosition
        guard local.finite else { return nil }
        heights.append(local.z)
        ranges.append(hit.hit.distance)
      }
      guard let low = heights.min(), let high = heights.max(),
        high - low <= NativeC03RegisterGeometry.maximumHeightError
      else { return nil }
      measured.append(heights.reduce(0, +) / Double(heights.count))
    }
    guard let plate = measured.first else { return nil }
    let reading = Reading(
      actor: physical.identity, component: component, physicalTime: context.physicalTime,
      archivePose: pose, observerPose: player, rayOrigin: player.position,
      surfaceRelativeSpeed: relativeSpeed, heights: measured.dropFirst().map { $0 - plate },
      surfaceRanges: ranges, maximumProbeAngle: maximumAngle)
    return reading.shapeValid ? reading : nil
  }
}
