import Foundation

/// Transient before-motion facts. There is deliberately no Codable or public initializer.
final class NativeC01TimingStandardFrame: Sendable {
  fileprivate let state: NativeC01TimingStandardState
  fileprivate let revision: UInt64
  fileprivate let player: ActorIdentity
  fileprivate let carrier: UUID
  fileprivate let inventoryRevision: UInt64
  fileprivate let scoop: EquipmentPurchaseItem
  fileprivate let epoch: UUID
  fileprivate let time: Double
  fileprivate let delta: Double
  fileprivate let pose: ShipPose
  fileprivate let velocity: Vector3
  fileprivate let manualEnd: ShipPose?
  fileprivate let manualVelocity: Vector3?
  fileprivate let manualTurnRate: Double
  fileprivate let automatic: Bool
  fileprivate let braking: Bool
  fileprivate let playerHull: PreparedHull
  fileprivate let obstacles: [HullSweepObstacle]
  fileprivate let projections: [Int: Projection]
  fileprivate let nativeOpening: FlightSimulationState?
  fileprivate let nativeBeforeBodies: [SpaceBody]?
  fileprivate let nativePath: CurrentNewtOuterMotion?
  fileprivate let births: [ActorIdentity: Birth]

  fileprivate struct Birth: Sendable {
    let bodyID: Int
    let state: CurrentNewtKitReceipt.BodyState
    let physical: PhysicalActorState
    let energy: Double
    let rotation: Double
    let rotationRate: Double
  }

  fileprivate struct Projection: Sendable {
    let identity: ActorIdentity
    let pose: ShipPose
    let velocity: Vector3
    let angularVelocity: Vector3
    let energy: Double
    let mesh: Mesh
    let hull: PreparedHull
  }

  fileprivate init?(
    game: inout Game, state: NativeC01TimingStandardState, delta: Double, startTime: Double,
    nativePath: CurrentNewtOuterMotion? = nil, bornAtEnd: CurrentNewtEndBirths? = nil
  ) {
    guard delta.isFinite, delta > 0, delta <= 0.1,
      startTime.isFinite, startTime >= state.source.physicalTime,
      nativePath == nil
        ? abs(game.commander.flightSimulation.physicalTime - startTime - delta) <= 1e-9
        : game.commander.flightSimulation.physicalTime == startTime,
      state.capture == nil, state.loss == nil,
      game.glassMeridianMission?.savedGlassMeridian?.timingStandard == state,
      NativeC01TimingStandard.joins(state.source, in: game),
      let mission = game.glassMeridianMission, mission.revision < UInt64(Int64.max) - 1,
      let player = game.commander.flightSimulation.player,
      let purchase = try? game.commander.purchaseSnapshot(),
      purchase.owner == state.source.owner,
      let fitted = game.commander.fittedEquipment(at: .utility(.fuelScoops)),
      let scoop = purchase.items.first(where: { $0.id == fitted.id }),
      scoop.location?.hull == purchase.activeHull,
      let target = game.c01TimingStandardActor(source: state.source, part: .standard),
      let playerHull = game.preparedWorkHull(
        mesh: game.commander.playerMesh, key: "c01-standard-player")
    else { return nil }
    guard bornAtEnd?.matchesNewtBirths(game) ?? true else { return nil }
    let birthActors = bornAtEnd?.actors ?? []
    if let nativePath {
      guard birthActors.isEmpty, nativePath.startTime == startTime,
        nativePath.endTime == startTime + delta,
        nativePath.motion.duration == delta,
        nativePath.motion.start == game.commander.flightSimulation.pose,
        nativePath.epoch == game.nativeStationRuntimeEpoch
      else { return nil }
    }
    if let guidance = game.workGuidance {
      guard game.weaponsTargetID == target.body.id,
        guidance.parent == target.body.physical?.identity,
        guidance.mode == .autoScoop(.salvage)
      else { return nil }
    }
    var obstacles: [HullSweepObstacle] = []
    let playerPose = game.commander.flightSimulation.pose
    for (index, celestial) in game.celestials.enumerated() {
      guard
        let hull = game.preparedWorkHull(
          mesh: game.workObstacleBox(celestial.radius),
          key: "celestial:\(index)")
      else { return nil }
      obstacles.append(
        .init(
          hull: hull,
          pose: .init(position: playerPose.systemPoint(celestial.position)), clearanceOverride: 0))
    }
    var projections: [Int: Projection] = [:]
    var bodyIDs: Set<Int> = []
    var births: [ActorIdentity: Birth] = [:]
    for body in game.bodies where body.energy > 0 {
      guard let physical = body.physical, physical.angularVelocity.finite,
        physical.velocity.finite, projections[body.id] == nil, bodyIDs.insert(body.id).inserted
      else { return nil }
      if birthActors.contains(physical.identity) {
        guard physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil,
          (try? game.currentNewtGeometryComponents(for: body)) != nil
        else { return nil }
        births[physical.identity] = .init(
          bodyID: body.id, state: game.currentNewtBodyState(body),
          physical: physical, energy: body.energy, rotation: body.rotation,
          rotationRate: body.rotationRate)
        continue
      }
      if nativePath != nil,
        physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil
      {
        guard (try? game.currentNewtGeometryComponents(for: body)) != nil else { return nil }
        continue
      }
      let part = NativeC01TimingStandard.Part.allCases.first {
        body.missionActorID == NativeC01TimingStandard.actor(source: state.source, part: $0)
      }
      let mesh = part?.design.rawMesh ?? game.gameplayMesh(for: body)
      guard let hull = game.preparedWorkHull(mesh: mesh, key: "c01-standard-scene:\(body.id)")
      else { return nil }
      projections[body.id] = .init(
        identity: physical.identity, pose: game.modelPose(of: body),
        velocity: physical.velocity, angularVelocity: physical.angularVelocity, energy: body.energy,
        mesh: mesh, hull: hull)
    }
    guard Set(births.keys) == birthActors else { return nil }
    for part in NativeC01TimingStandard.Part.allCases {
      guard
        let canonical = mission.ownedEncounters[NativeC01TimingStandard.encounter]?.actors[
          part.rawValue]
      else { return nil }
      if canonical.presence == .destroyed { continue }
      guard game.c01TimingStandardActor(source: state.source, part: part) != nil else { return nil }
    }
    let pose = game.commander.flightSimulation.pose
    let automatic = game.workGuidance != nil
    let braking = game.workBraking != nil
    self.state = state
    revision = mission.revision
    self.player = player
    carrier = purchase.activeHull
    inventoryRevision = purchase.revision
    self.scoop = scoop
    epoch = game.nativeStationRuntimeEpoch
    time = startTime
    self.delta = delta
    self.pose = pose
    velocity = game.flightWorldVelocity
    self.automatic = automatic
    self.braking = braking
    if !automatic && !braking {
      if let nativePath {
        // Its single control sample already rotated the pilot velocity.
        guard let endpoint = nativePath.state(at: nativePath.endTime) else { return nil }
        manualEnd = endpoint.pose
        manualVelocity = endpoint.velocity
      } else {
        var pilot = game.autoPilot
        pilot.rotateVelocity(
          pitch: game.pitch * delta, roll: game.roll * delta, yaw: game.yaw * delta)
        var end = pose
        end.advanceView(
          pitch: game.pitch * delta, roll: game.roll * delta, yaw: game.yaw * delta,
          translation: pilot.velocity * delta + Vector3(0, 0, game.speed * delta * 18))
        manualEnd = end
        manualVelocity = end.orientation.apply(pilot.velocity + .init(0, 0, game.speed * 18))
      }
    } else {
      manualEnd = nil
      manualVelocity = nil
    }
    manualTurnRate = abs(game.pitch) + abs(game.yaw) + abs(game.roll)
    self.playerHull = playerHull
    self.obstacles = obstacles
    self.projections = projections
    nativeOpening = nativePath == nil ? nil : game.commander.flightSimulation
    nativeBeforeBodies = nativePath == nil ? nil : game.bodies
    self.nativePath = nativePath
    self.births = births
  }

  /// These actual T1 births have no preceding trajectory. Their source-born
  /// state must survive camera conversion, and their full surfaces must clear
  /// the actual player endpoint before capture can be sealed.
  fileprivate func birthsClear(in game: Game) -> Bool {
    var remaining = HullSweepBudget.standard
    for (actor, birth) in births {
      guard let body = game.bodies.first(where: { $0.physical?.identity == actor }),
        body.id == birth.bodyID, body.physical == birth.physical, body.energy == birth.energy,
        body.rotation == birth.rotation, body.rotationRate == birth.rotationRate,
        let parts = try? game.currentNewtGeometryComponents(for: body)
      else { return false }
      let current = game.currentNewtBodyState(body)
      guard (current.pose.position - birth.state.pose.position).length < 1e-7,
        (current.pose.orientation.x - birth.state.pose.orientation.x).length < 1e-7,
        (current.pose.orientation.y - birth.state.pose.orientation.y).length < 1e-7,
        (current.pose.orientation.z - birth.state.pose.orientation.z).length < 1e-7,
        current.velocity == birth.state.velocity,
        current.angularVelocity == birth.state.angularVelocity
      else { return false }
      for part in parts {
        guard let mesh = part.collisionMesh else { continue }
        guard let hull = try? PreparedHull(mesh: mesh, maximumTriangles: 512) else { return false }
        let result = HullSweepSafety.currentNewtEndpointPairClearance(
          source: playerHull,
          sourcePose: game.commander.flightSimulation.pose, target: hull, targetPose: part.pose,
          budget: remaining)
        guard result.safe else { return false }
        remaining.distanceQueries -= result.distanceQueries
        remaining.triangleTests -= result.triangleTests
        remaining.nodeVisits -= result.nodeVisits
      }
    }
    return true
  }
}

/// A saved capture has no conversion to this live token.
final class NativeC01TimingStandardPending: Sendable {
  let capture: NativeC01TimingStandardCapture
  fileprivate let before: NativeC01TimingStandardState
  fileprivate let automatic: Bool
  fileprivate let braking: Bool
  fileprivate init(
    capture: NativeC01TimingStandardCapture, before: NativeC01TimingStandardState,
    automatic: Bool, braking: Bool
  ) {
    self.capture = capture
    self.before = before
    self.automatic = automatic
    self.braking = braking
  }
}

extension Game {
  mutating func beginC01TimingStandardObservation(
    state: NativeC01TimingStandardState, delta: Double, startTime: Double? = nil,
    nativePath: CurrentNewtOuterMotion? = nil, bornAtEnd: CurrentNewtEndBirths? = nil
  ) -> NativeC01TimingStandardFrame? {
    guard let startTime else { return nil }
    return NativeC01TimingStandardFrame(
      game: &self, state: state, delta: delta, startTime: startTime, nativePath: nativePath,
      bornAtEnd: bornAtEnd)
  }

  /// Call only after native motion. This observer returns authority; GameRuntime publishes custody.
  func sealC01TimingStandardCapture(
    _ frame: NativeC01TimingStandardFrame, state: NativeC01TimingStandardState,
    nativeEvidence: CurrentNewtNativeClockEvidence? = nil
  ) -> NativeC01TimingStandardPending? {
    guard state == frame.state, NativeC01TimingStandard.joins(state.source, in: self),
      let mission = glassMeridianMission, mission.revision == frame.revision,
      commander.flightSimulation.player == frame.player,
      commander.hullInstanceID == frame.carrier, nativeStationRuntimeEpoch == frame.epoch,
      commander.equipmentInventory?.revision == frame.inventoryRevision,
      commander.fittedEquipment(at: .utility(.fuelScoops))?.id == frame.scoop.id,
      (try? commander.purchaseSnapshot().items.contains(frame.scoop)) == true,
      abs(commander.flightSimulation.physicalTime - frame.time - frame.delta) <= 1e-9,
      let actor = c01TimingStandardActor(source: state.source, part: .standard),
      let physical = actor.body.physical
    else { return nil }
    let certifiedNativeMotion: HullSceneMotion?
    if let opening = frame.nativeOpening, let before = frame.nativeBeforeBodies,
      let path = frame.nativePath
    {
      guard let nativeEvidence,
        let certified = nativeEvidence.timingStandardMotion(
          from: opening, bodies: before, path: path, closing: self)
      else { return nil }
      certifiedNativeMotion = certified
    } else {
      guard nativeEvidence == nil else { return nil }
      certifiedNativeMotion = nil
    }
    let motion: HullSceneMotion
    if let expected = frame.manualEnd {
      guard workGuidance == nil, workBraking == nil,
        commander.flightSimulation.pose == expected, lastAppliedWorkMotion == nil,
        let velocity = frame.manualVelocity, (flightWorldVelocity - velocity).length <= 1e-6,
        let actual = NativeC01TimingStandard.rigidMotion(
          from: frame.pose, to: expected, duration: frame.delta, radius: frame.playerHull.radius)
      else { return nil }
      motion = certifiedNativeMotion ?? actual
    } else {
      guard let applied = lastAppliedWorkMotion, applied.start == frame.pose,
        applied.end == commander.flightSimulation.pose, applied.duration == frame.delta,
        applied.initialVelocity == frame.velocity
      else { return nil }
      if frame.automatic {
        guard weaponsTargetID == actor.body.id, let guidance = workGuidance,
          guidance.parent == physical.identity, guidance.mode == .autoScoop(.salvage)
        else { return nil }
      } else {
        guard frame.braking, workGuidance == nil else { return nil }
      }
      motion = applied
    }

    // Native steering is sampled at the real motion boundary. Each retained endpoint uses
    // the same rigid interpolation as the native contact pass, including changed velocity/spin.
    let current = bodies.filter {
      $0.energy > 0
        && !($0.physical.map { frame.births[$0.identity] != nil } ?? false)
        && (certifiedNativeMotion == nil
          || ($0.physical?.currentNewtKitStock == nil && $0.physical?.currentNewtKitReceipt == nil))
    }
    guard current.count == frame.projections.count else { return nil }
    var obstacles = frame.obstacles
    var targetMotion: HullSceneMotion?
    for body in current {
      guard let before = frame.projections[body.id], let native = body.physical,
        native.identity == before.identity, body.energy == before.energy,
        native.velocity.finite, native.angularVelocity.finite
      else { return nil }
      let part = NativeC01TimingStandard.Part.allCases.first {
        body.missionActorID == NativeC01TimingStandard.actor(source: state.source, part: $0)
      }
      let mesh = part?.design.rawMesh ?? gameplayMesh(for: body)
      guard mesh.vertices == before.mesh.vertices, mesh.faces == before.mesh.faces,
        let actual = NativeC01TimingStandard.rigidMotion(
          from: before.pose, to: modelPose(of: body), duration: frame.delta,
          radius: before.hull.radius)
      else { return nil }
      obstacles.append(
        .init(
          identity: native.identity, hull: before.hull, pose: before.pose,
          velocity: actual.initialVelocity, angularVelocity: actual.worldAngularVelocity,
          clearanceOverride: 0))
      if native.identity == physical.identity { targetMotion = actual }
    }
    guard let targetMotion, let before = frame.projections[actor.body.id] else { return nil }
    let radius = NativeC01TimingStandard.Part.standard.design.rawMesh.vertices.map(\.length).max()!
    let relativeVelocity = [
      physical.velocity - flightWorldVelocity,
      before.velocity - frame.velocity, targetMotion.initialVelocity - motion.initialVelocity,
    ]
    .max(by: { $0.length < $1.length })!
    let targetSpin = [
      targetMotion.worldAngularVelocity, physical.angularVelocity, before.angularVelocity,
    ]
    .max(by: { $0.length < $1.length })!
    let playerSpin =
      motion.worldAngularVelocity.length >= frame.manualTurnRate || frame.manualEnd == nil
      ? motion.worldAngularVelocity : Vector3(frame.manualTurnRate, 0, 0)
    let clear: Bool
    if let certifiedNativeMotion {
      guard certifiedNativeMotion == motion else { return nil }
      clear = true
    } else {
      clear =
        HullSweepSafety.validateSceneMotion(
          motion, player: frame.playerHull, obstacles: obstacles
        ).safe
    }
    guard
      let speed = NativeC01TimingStandard.approachSpeed(
        relativeVelocity: relativeVelocity,
        playerAngularVelocity: playerSpin, targetAngularVelocity: targetSpin),
      NativeC01Surveyor.approachAllowed(point: actor.body.position, radius: radius, speed: speed),
      clear,
      frame.birthsClear(in: self),
      let cargo = NativeC01TimingStandard.prospectiveCargo(commander),
      cargo <= commander.tradeCargoCapacity
    else { return nil }
    let capture = NativeC01TimingStandardCapture(
      operation: NativeC01TimingStandard.operation(source: state.source), source: state.source,
      missionRevision: mission.revision, marker: actor, collector: frame.player,
      carrier: frame.carrier, inventoryRevision: frame.inventoryRevision, scoop: frame.scoop,
      point: actor.body.position, relativeSpeed: speed, startTime: frame.time,
      physicalTime: commander.flightSimulation.physicalTime, epoch: frame.epoch)
    return .init(
      capture: capture, before: state, automatic: frame.automatic, braking: frame.braking)
  }

  /// Prepares custody only; GameRuntime installs mass, body removal and evidence together.
  func c01TimingStandardCandidate(
    _ pending: NativeC01TimingStandardPending, current: NativeC01TimingStandardState
  ) throws -> NativeC01TimingStandardState {
    let capture = pending.capture
    guard current == pending.before, current.capture == nil, current.loss == nil,
      glassMeridianMission?.savedGlassMeridian?.timingStandard == current,
      NativeC01TimingStandard.joins(current.source, in: self),
      glassMeridianMission?.revision == capture.missionRevision,
      nativeStationRuntimeEpoch == capture.epoch,
      commander.flightSimulation.physicalTime == capture.physicalTime,
      commander.flightSimulation.player == capture.collector,
      commander.hullInstanceID == capture.carrier,
      commander.equipmentInventory?.revision == capture.inventoryRevision,
      commander.fittedEquipment(at: .utility(.fuelScoops))?.id == capture.scoop.id,
      (try? commander.purchaseSnapshot().items.contains(capture.scoop)) == true,
      c01TimingStandardActor(source: current.source, part: .standard) == capture.marker,
      let cargo = NativeC01TimingStandard.prospectiveCargo(commander),
      cargo <= commander.tradeCargoCapacity
    else { throw SaveError.invalidCommander }
    if pending.automatic {
      guard weaponsTargetID == capture.marker.body.id,
        workGuidance?.parent == capture.marker.body.physical?.identity,
        workGuidance?.mode == .autoScoop(.salvage)
      else { throw SaveError.invalidCommander }
    } else {
      guard workGuidance == nil, pending.braking || workBraking == nil else {
        throw SaveError.invalidCommander
      }
    }
    var result = current
    result.capture = capture
    guard NativeC01TimingStandardSave.shapeValid(result) else { throw SaveError.invalidCommander }
    return result
  }

  /// Real destruction observations only. Escape must join the existing escape transaction later.
  func c01TimingStandardObservedLoss(
    current: NativeC01TimingStandardState
  ) -> NativeC01TimingStandardState? {
    guard current.loss == nil, let mission = glassMeridianMission,
      NativeC01TimingStandardSave.historyJoins(current, mission: mission, commander: commander),
      let collector = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID, energy.isFinite
    else { return nil }
    let loss: NativeC01TimingStandardLoss
    if current.capture == nil,
      let group = mission.ownedEncounters[NativeC01TimingStandard.encounter], group.valid,
      group.admitted, let actor = group.actors[NativeC01TimingStandard.target],
      actor.presence == .destroyed, actor.body.energy == 0
    {
      loss = .init(
        kind: .standardDestroyed, actor: actor, collector: collector, carrier: carrier,
        energy: energy, escapePod: nil, physicalTime: commander.flightSimulation.physicalTime)
    } else if current.held, screen == .gameOver, energy <= 0,
      current.capture?.carrier == carrier
    {
      loss = .init(
        kind: .carrierDestroyed, actor: nil, collector: collector, carrier: carrier,
        energy: energy, escapePod: nil, physicalTime: commander.flightSimulation.physicalTime)
    } else {
      return nil
    }
    var result = current
    result.loss = loss
    return NativeC01TimingStandardSave.shapeValid(result) ? result : nil
  }
}

extension Game {
  fileprivate mutating func applyC01TimingStandardCapture() throws -> Bool {
    guard let pending = nativeC01TimingStandardPending,
      var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      let current = opening.timingStandard,
      let index = bodies.firstIndex(where: { $0.id == pending.capture.marker.body.id })
    else {
      nativeC01TimingStandardPending = nil
      return false
    }
    opening.timingStandard = try c01TimingStandardCandidate(pending, current: current)
    mission.savedGlassMeridian = opening
    mission.milestones.insert(4)
    mission.receipts.formUnion([
      NativeC01TimingStandard.target, "recover-standard", NativeC01TimingStandard.receipt,
    ])
    mission.revision += 1
    mission.journal.append(
      "Recovered the original one-tonne timing standard at Enlirin. The same original 8kg recorder remains protected aboard: 1.008t exact protected mass. Next: calibrate the three original relay nodes at Lareria with this same standard. No payment or final clue."
    )
    commander.scriptState.instances[mission.id] = mission
    guard let cargo = commander.checkedCargoTonnes, cargo <= commander.tradeCargoCapacity else {
      throw MissionPackError(
        "The original timing standard and recorder do not fit the actual hold.")
    }
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    nativeC01TimingStandardPending = nil
    return true
  }

  mutating func recordC01TimingStandardLoss() throws -> Bool {
    guard var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      let current = opening.timingStandard,
      let lost = c01TimingStandardObservedLoss(current: current)
    else { return false }
    guard mission.revision < UInt64(Int64.max) - 1 else { throw SaveError.invalidCommander }
    opening.timingStandard = lost
    mission.savedGlassMeridian = opening
    mission.revision += 1
    mission.journal.append(
      "Original timing standard lost. This attempt cannot reissue it; the earlier recorder and Sorel audit history remain recorded. No payment or clue."
    )
    commander.scriptState.instances[mission.id] = mission
    nativeC01TimingStandardPending = nil
    return true
  }

  mutating func loseC01TimingStandardOnEscape(_ pod: EquipmentPurchaseItem?) throws {
    guard var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      var leaf = opening.timingStandard, leaf.held
    else { return }
    guard let pod, let collector = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID, energy.isFinite, energy > 0,
      mission.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    leaf.loss = .init(
      kind: .escape, actor: nil, collector: collector, carrier: carrier,
      energy: energy, escapePod: pod, physicalTime: commander.flightSimulation.physicalTime)
    guard NativeC01TimingStandardSave.shapeValid(leaf) else { throw SaveError.invalidCommander }
    opening.timingStandard = leaf
    mission.savedGlassMeridian = opening
    mission.revision += 1
    mission.journal.append(
      "Escape forfeited the original timing standard; no copy or replacement was created.")
    commander.scriptState.instances[mission.id] = mission
    nativeC01TimingStandardPending = nil
  }
}

extension GameRuntime {
  func commitC01TimingStandard() {
    guard game.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit != nil,
      let publish = scriptPublisher()
    else {
      game.nativeC01TimingStandardPending = nil
      return
    }
    var candidate = game
    do {
      let loss = try candidate.recordC01TimingStandardLoss()
      let capture = try candidate.applyC01TimingStandardCapture()
      let source = try candidate.prepareC01TimingStandard()
      guard loss || capture || source else {
        game.nativeC01TimingStandardPending = nil
        return
      }
      try publish(&candidate)
      game = candidate
      if capture { game.notify("ORIGINAL TIMING STANDARD ABOARD - RECORDER RETAINED") }
    } catch {
      game.nativeC01TimingStandardPending = nil
      game.notify("TIMING STANDARD UPDATE NOT SAVED - ORIGINAL CUSTODY RETAINED")
    }
  }
}
