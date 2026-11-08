import Foundation

struct NativeC01ClinicGuidance: Sendable {
  let worldVelocity: Vector3
  let worldOrientation: Basis3
  let angularTravel: Double
  let status: String

  init(worldVelocity: Vector3, worldOrientation: Basis3, angularTravel: Double = 0, status: String) {
    self.worldVelocity = worldVelocity
    self.worldOrientation = worldOrientation
    self.angularTravel = angularTravel
    self.status = status
  }
}

struct NativeC01ClinicSteering: Sendable {
  let orientation: Basis3
  let angularTravel: Double
}

extension NativeC01ClinicEscort {
  /// Steering is a proposal. The separate actual native full-scene sweep owns acceptance.
  static func guidance(
    tender: ShipPose, player: ShipPose, station: ShipPose, stationVelocity: Vector3,
    cradle: ShipPose?, profile: ScriptNPCDefinition, delta: Double
  ) throws -> NativeC01ClinicGuidance {
    guard delta.isFinite, delta > 0, delta <= 0.1,
      tender.position.finite, player.position.finite, station.position.finite,
      (cradle?.position.finite ?? true), stationVelocity.finite,
      tender.orientation.validRotation, station.orientation.validRotation,
      (cradle?.orientation.validRotation ?? true), profile.valid
    else { throw SaveError.invalidCommander }
    if (tender.position - player.position).length > stayNearMetres {
      return .init(worldVelocity: .init(0, 0, 0), worldOrientation: tender.orientation,
        status: "HOLDING FOR ESCORT - RETURN WITHIN1500m")
    }
    let original = try NativeC01SurveyorGeometry.harrier.get()
    if let cradle {
      let source = try NativeC01ClinicCradle.original.get()
      let minimumZ = try requireMinimumZ(original.collision.vertices)
      let exit = source.nativeDocking.port
      let local = cradle.shipPoint(tender.position)
      let clearCOM = exit.center.z - minimumZ + 5
      if abs(local.x) < 100, abs(local.y) < 100, local.z < clearCOM,
        local.length < 200
      {
        let forward = cradle.orientation.apply(exit.outward)
        let up = cradle.orientation.apply(exit.up)
        let turn = clinicSteering(tender.orientation, forward: forward, up: up,
          profile: profile, delta: delta)
        let basis = turn.orientation
        let centered = cradle.systemPoint(.init(0, 0, local.z))
        let correction = (centered - tender.position) * 0.8
        let aligned = basis.z.dot(forward) > 0.999 && basis.y.dot(up) > 0.999
        return .init(worldVelocity: (correction + forward * (aligned ? 30 : 0))
          .limited(to: min(profile.speed, 30)), worldOrientation: basis, angularTravel: turn.angularTravel,
          status: "DEPARTING ACTUAL MAINTENANCE CRADLE")
      }
    }

    let port = MainStationGeometry.docking
    let normal = station.orientation.apply(port.outward)
    let up = station.orientation.apply(port.up)
    let entrance = station.systemPoint(port.center)
    let yValues = original.collision.vertices.map(\.y)
    guard let minY = yValues.min(), let maxY = yValues.max() else {
      throw SaveError.invalidCommander
    }
    let centered = entrance - up * ((minY + maxY) / 2)
    let relative = tender.position - centered
    let depth = relative.dot(normal)
    let lateral = relative - normal * depth
    let inward = normal * -1
    if depth <= 1100, depth > -port.tunnelDepth, lateral.length < 80 {
      let turn = clinicSteering(tender.orientation, forward: inward, up: up,
        profile: profile, delta: delta)
      let basis = turn.orientation
      // An uncommitted crossing never becomes a saved arrival. After a failed receiver
      // write the real hull backs out and must attain another inward crossing.
      if depth <= 0 {
        return .init(worldVelocity: (stationVelocity + normal * 30).limited(to: profile.speed),
          worldOrientation: basis, angularTravel: turn.angularTravel,
          status: "RECEIVING NOT COMMITTED - ACTUAL REAPPROACH")
      }
      let corrected = centered + normal * min(depth, 900)
      let correction = (corrected - tender.position) * 0.8
      let aligned = basis.z.dot(inward) > 0.999 && basis.y.dot(up) > 0.999
      let entry = aligned && lateral.length < 3 ? 30.0 : 0
      return .init(worldVelocity: (stationVelocity + correction + inward * entry)
        .limited(to: min(profile.speed, 80)), worldOrientation: basis, angularTravel: turn.angularTravel,
        status: "LARERIA NATIVE ARRIVAL CONTROL - ALIGNING")
    }
    var goal = centered + normal * 1000
    if depth < 300, lateral.length > 200 { goal = centered + normal * 1200 + up * 600 }
    let offset = goal - tender.position
    guard offset.length.isFinite, offset.length > 1e-6 else {
      return .init(worldVelocity: stationVelocity, worldOrientation: tender.orientation,
        status: "WAITING FOR SAFE ARRIVAL COURSE")
    }
    let turn = clinicSteering(tender.orientation, forward: offset.unit, up: up,
      profile: profile, delta: delta)
    let basis = turn.orientation
    let speed = basis.z.dot(offset.unit) > 0.98
      ? min(profile.speed, sqrt(max(0, 2 * profile.acceleration * max(0, offset.length - 10)))) : 0
    return .init(worldVelocity: (stationVelocity + basis.z * speed).limited(to: profile.speed),
      worldOrientation: basis, status: "ESCORT TO LARERIA MAIN STATION")
  }

  /// Parked ships retain independent current motion; their actual pilots steer toward
  /// the moving berth. No position, velocity or condition is reset to a cradle template.
  static func parkedGuidance(
    tender: ShipPose, cradle: ShipPose, cradleVelocity: Vector3, cradleAngularVelocity: Vector3,
    ordinal: Int, profile: ScriptNPCDefinition, delta: Double
  ) throws -> NativeC01ClinicGuidance {
    guard (0..<maximumLaunches).contains(ordinal), delta.isFinite, delta > 0, delta <= 0.1,
      tender.position.finite, tender.orientation.validRotation,
      cradle.position.finite, cradle.orientation.validRotation,
      cradleVelocity.finite, cradleAngularVelocity.finite, profile.valid
    else { throw SaveError.invalidCommander }
    let berth = parkedPose(cradle: cradle, ordinal: ordinal)
    let offset = berth.position - tender.position
    let turn = clinicSteering(tender.orientation, forward: cradle.orientation.z,
      up: cradle.orientation.y, profile: profile, delta: delta)
    let inherited = cradleVelocity
      + cradleAngularVelocity.cross(berth.position - cradle.position)
    let correction = offset * 0.8
    return .init(worldVelocity: (inherited + correction).limited(to: profile.speed),
      worldOrientation: turn.orientation, angularTravel: turn.angularTravel,
      status: ordinal == 0 ? "FRONT TENDER HOLDING ITS ACTUAL BERTH" : "RESERVE TENDER HOLDING ITS ACTUAL BERTH")
  }

  private static func requireMinimumZ(_ vertices: [Vector3]) throws -> Double {
    guard let minimum = vertices.map(\.z).min(), minimum.isFinite else {
      throw SaveError.invalidCommander
    }
    return minimum
  }

  private static func clinicSteering(
    _ orientation: Basis3, forward: Vector3, up: Vector3,
    profile: ScriptNPCDefinition, delta: Double
  ) -> NativeC01ClinicSteering {
    let local = orientation.inverse(forward)
    let pitch = max(-profile.pitch * delta,
      min(profile.pitch * delta, -atan2(local.y, hypot(local.x, local.z))))
    let yaw = max(-profile.yaw * delta, min(profile.yaw * delta, -atan2(local.x, local.z)))
    var step = Basis3()
    step.rotate(pitch: pitch, roll: 0, yaw: yaw)
    var basis = step.transformed(by: orientation)
    let localUp = basis.inverse(up)
    let roll = max(-profile.roll * delta, min(profile.roll * delta, -atan2(localUp.x, localUp.y)))
    step = Basis3()
    step.rotate(pitch: 0, roll: roll, yaw: 0)
    basis = step.transformed(by: basis)
    return .init(orientation: basis, angularTravel: abs(pitch) + abs(yaw) + abs(roll))
  }
}


/// Actual applied pitch/yaw/roll path for one current actor in one physical step.
/// This is transient evidence, never a save record or source/crew authorization.
struct NativeC01ClinicControlProof: Sendable {
  let actor: ActorIdentity
  let epoch: UUID
  let startTime: Double
  let duration: Double
  let from: ShipPose
  let proposedOrientation: Basis3
  let steeringTravel: Double
  let nativeAngularVelocity: Vector3

  fileprivate init(actor: ActorIdentity, epoch: UUID, startTime: Double, duration: Double,
    from: ShipPose, guidance: NativeC01ClinicGuidance, nativeAngularVelocity: Vector3)
  {
    self.actor = actor
    self.epoch = epoch
    self.startTime = startTime
    self.duration = duration
    self.from = from
    proposedOrientation = guidance.worldOrientation
    steeringTravel = guidance.angularTravel
    self.nativeAngularVelocity = nativeAngularVelocity
  }

  func angularTravel(actor: ActorIdentity, epoch: UUID, from: ShipPose, to: ShipPose,
    startTime: Double, duration: Double, includesNativeSpin: Bool) -> Double?
  {
    guard self.actor == actor, self.epoch == epoch,
      (self.from.position - from.position).length < 1e-7,
      abs(self.startTime - startTime) <= 1e-10, abs(self.duration - duration) <= 1e-10,
      Self.sameBasis(proposedOrientation, to.orientation),
      steeringTravel.isFinite, steeringTravel >= 0, nativeAngularVelocity.finite
    else { return nil }
    let spin: Double
    if includesNativeSpin {
      spin = nativeAngularVelocity.length * self.duration
      guard spin.isFinite, spin < 1 else { return nil }
      let spun = RelativeWorkController.rotated(from.orientation,
        omega: nativeAngularVelocity, delta: self.duration)
      guard Self.sameBasis(spun, self.from.orientation) else { return nil }
    } else {
      guard Self.sameBasis(self.from.orientation, from.orientation) else { return nil }
      spin = 0
    }
    guard spin.isFinite, spin >= 0, spin + steeringTravel < 1 else { return nil }
    return spin + steeringTravel
  }

  private static func sameBasis(_ lhs: Basis3, _ rhs: Basis3) -> Bool {
    (lhs.x - rhs.x).length < 1e-8 && (lhs.y - rhs.y).length < 1e-8
      && (lhs.z - rhs.z).length < 1e-8
  }
}

extension Game {
  /// Read-only course calculation. A proposal installs no control proof or status.
  func c01ClinicCourse(
    _ body: SpaceBody, profile: ScriptNPCDefinition, delta: Double
  ) -> NativeC01ClinicGuidance? {
    guard delta.isFinite, delta > 0, delta <= 0.1,
      let ordinal = c01ClinicStockOrdinal(body), body.energy > 0,
      let physical = body.physical,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      state.loss(for: ordinal) == nil,
      let unit = state.birth.unit(ordinal),
      let pilot = c01ClinicStoredPilotFacts(ordinal: ordinal),
      pilot.pilot == unit.pilot, pilot.registeredHull == unit.registeredHull,
      pilot.actor == body.missionActorID, pilot.intrinsicPlace == 0,
      pilot.mass.valid, pilot.loadedMassKilograms == 25625,
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station && $0.energy > 0 }),
      let stationPhysical = station.physical
    else { return nil }
    let tender = modelPose(of: body)
    let cradleBody = bodies.first(where: {
      $0.missionActorID == NativeC01ClinicEscort.cradle(mission: mission.id)
        && $0.energy > 0 && c01ClinicCradleActor($0) != nil
    })
    let cradle = cradleBody.map { modelPose(of: $0) }
    let result: NativeC01ClinicGuidance
    do {
      if let launch = state.launch(for: ordinal) {
        guard pilot.location == .aboardOperating(launch: launch.operation) else { return nil }
        result = try NativeC01ClinicEscort.guidance(tender: tender,
          player: storedFlightSimulation().pose, station: modelPose(of: station),
          stationVelocity: stationPhysical.velocity, cradle: cradle, profile: profile, delta: delta)
      } else {
        guard pilot.location == .aboardStored, let cradle,
          let cradlePhysical = cradleBody?.physical
        else { return nil }
        result = try NativeC01ClinicEscort.parkedGuidance(tender: tender, cradle: cradle,
          cradleVelocity: cradlePhysical.velocity, cradleAngularVelocity: cradlePhysical.angularVelocity,
          ordinal: ordinal, profile: profile, delta: delta)
      }
    } catch { return nil }
    // A nonzero native spin must have the actual canonical Rodrigues integration owner.
    // This refuses unintegrated angular velocity rather than inventing a rotation path.
    guard body.rotationRate == 0, body.rotation == 0, physical.angularVelocity.finite,
      physical.angularVelocity.length == 0 || physical.canonicalSpin == true,
      result.angularTravel.isFinite, result.angularTravel >= 0, result.angularTravel < 1
    else { return nil }
    return result
  }

  /// This call is inside the sole profiled-flight mover, before its normal acceleration step.
  mutating func c01ClinicGuidance(
    _ body: SpaceBody, profile: ScriptNPCDefinition, delta: Double
  ) -> (orientation: Basis3, desired: Vector3)? {
    guard let physical = body.physical,
      let result = c01ClinicCourse(body, profile: profile, delta: delta)
    else { return nil }
    let tender = modelPose(of: body)
    let physicalTime = storedFlightSimulation().physicalTime
    let startTime: Double
    if let observed = c01ClinicEscortRuntime.attainedSample,
      observed.epoch == nativeStationRuntimeEpoch,
      abs(physicalTime - observed.native.physicalTime - delta) <= 1e-10
    {
      startTime = observed.native.physicalTime
    } else {
      // Only the profiled-motion resolver uses this synthetic phase timestamp. Actual
      // arrival/fatal authority always requires its separate real pre-tick sample.
      startTime = physicalTime - delta
    }
    let proof = NativeC01ClinicControlProof(actor: physical.identity,
      epoch: nativeStationRuntimeEpoch, startTime: startTime, duration: delta,
      from: tender, guidance: result, nativeAngularVelocity: physical.angularVelocity)
    c01ClinicEscortRuntime.controls.removeAll { $0.actor == physical.identity }
    guard c01ClinicEscortRuntime.controls.count < NativeC01ClinicEscort.maximumLaunches else { return nil }
    c01ClinicEscortRuntime.controls.append(proof)
    c01ClinicEscortRuntime.reason = result.status
    return (result.worldOrientation.relative(to: storedFlightSimulation().pose.orientation),
      storedFlightSimulation().pose.shipVector(result.worldVelocity))
  }
}


extension Game {
  /// Reject the whole coupled stock motion set before changing any endpoint. This avoids
  /// proving the reserve against a front endpoint that is then rolled back into its path.
  mutating func resolveC01ClinicMotion(before: [SpaceBody], delta: Double) {
    guard let mission = glassMeridianMission, mission.savedGlassMeridian?.clinicEscort != nil
    else { return }
    let identities = Set((0..<NativeC01ClinicEscort.maximumLaunches).map {
      NativeC01ClinicEscort.actor(mission: mission.id, ordinal: $0)
    })
    let selected = bodies.indices.filter {
      bodies[$0].missionInstanceID == mission.id
        && bodies[$0].missionActorID.map({ identities.contains($0) }) == true
        && bodies[$0].energy > 0
    }
    guard !selected.isEmpty else { return }
    let sample = NativeC01ClinicSceneSample(
      NativeWormholeMotionSample.profiledMotion(in: self, before: before, delta: delta))
    var clear = true
    for index in selected {
      if !c01ClinicSceneMotionIsClear(bodies[index], from: sample, playerMesh: nativeGuidanceStoredPlayerMesh(), includesNativeSpin: false) {
        clear = false
      }
    }
    guard !clear else { return }
    for index in selected {
      guard let identity = bodies[index].physical?.identity,
        let old = before.first(where: { $0.physical?.identity == identity })
      else { continue }
      bodies[index].position = old.position
      bodies[index].orientation = old.orientation
      bodies[index].scriptNPC?.velocity = .init(0, 0, 0)
      c01ClinicEscortRuntime.controls.removeAll { $0.actor == identity }
    }
    c01ClinicEscortRuntime.reason = "CLINIC MOTION PAUSED - ACTUAL HULL CLEARANCE REQUIRED"
  }
}
