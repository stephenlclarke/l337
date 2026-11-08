import Foundation

/// Raw actual frame data only. No time is assigned to a phase within the native tick.
/// In particular, none of these records certifies a swept path, visibility or observation.
enum NativeC03AttainedMotionResult: Sendable {
  case recorded(NativeC03AttainedMotion)
  case recordedNative(NativeC03NativeAttainedMotion)
  case refused(NativeC03MotionRefusal)

  var recordsAttainedFrame: Bool {
    switch self {
    case .recorded, .recordedNative: return true
    case .refused: return false
    }
  }
}

enum NativeC03MotionRefusal: Error, Sendable {
  case unavailableSource, unsupportedScene, missingPhase, unsupportedWork
  case changedBinding, changedScene, changedEffect
}

struct NativeC03AttainedMotion: Sendable {
  let startTime: Double
  let endTime: Double
  let frame: UInt64
  let player: ActorIdentity
  let playerPhase: NativeC03AppliedCameraStep
  let acceptedWork: HullSceneMotion?
  let originals: [Original]
  let stationBody: SpaceBody
  let stationMesh: Mesh
  let playerMesh: Mesh
  let stationStart: ShipPose
  let stationAfterCamera: ShipPose
  let celestialStart: [CelestialBody]
  let celestialEnd: [CelestialBody]
  struct Original: Sendable {
    let admission: NativeHollowManifestState.Admission
    let sourceFrame: ShipPose
    let rootStart: ShipPose
    let rootAfterCamera: ShipPose
    let rootEnd: ShipPose
    let componentStart: ShipPose
    let componentEnd: ShipPose
    let powered: NativeC03AppliedNPCStep
    let initialRotation: Double
    let cameraRotation: Double
    let rotationRate: Double
    let worldSpin: Vector3
    let canonicalSpin: Bool
    let routeStart: NativeHollowManifestState.Route
    let routeEnd: NativeHollowManifestState.Route
    fileprivate init(
      authenticAdmission: NativeHollowManifestState.Admission, sourceFrame: ShipPose,
      rootStart: ShipPose, rootAfterCamera: ShipPose, rootEnd: ShipPose,
      componentStart: ShipPose, componentEnd: ShipPose, powered: NativeC03AppliedNPCStep,
      initialRotation: Double, cameraRotation: Double, rotationRate: Double,
      worldSpin: Vector3, canonicalSpin: Bool,
      routeStart: NativeHollowManifestState.Route, routeEnd: NativeHollowManifestState.Route
    ) {
      self.admission = authenticAdmission
      self.sourceFrame = sourceFrame
      self.rootStart = rootStart
      self.rootAfterCamera = rootAfterCamera
      self.rootEnd = rootEnd
      self.componentStart = componentStart
      self.componentEnd = componentEnd
      self.powered = powered
      self.initialRotation = initialRotation
      self.cameraRotation = cameraRotation
      self.rotationRate = rotationRate
      self.worldSpin = worldSpin
      self.canonicalSpin = canonicalSpin
      self.routeStart = routeStart
      self.routeEnd = routeEnd
    }
  }
  fileprivate init(
    pending: NativeC03MotionPending, phase: NativeC03AppliedCameraStep,
    work: HullSceneMotion?, originals: [Original], station: ShipPose,
    celestials: [CelestialBody], endTime: Double, frame: UInt64, player: ActorIdentity
  ) {
    startTime = pending.flight.physicalTime
    self.endTime = endTime
    self.frame = frame
    self.player = player
    playerPhase = phase
    acceptedWork = work
    self.originals = originals
    stationBody = pending.station
    stationMesh = pending.stationMesh
    playerMesh = pending.playerMesh
    stationStart = pending.stationPose
    stationAfterCamera = station
    celestialStart = pending.celestials
    celestialEnd = celestials
  }
}

/// The native path is simultaneous motion, not a fictional camera-then-powered phase.
/// Only the sealer below constructs this after accepted clock-leg identity validation.
struct NativeC03NativeAttainedMotion: Sendable {
  struct Original: Sendable {
    let admission: NativeHollowManifestState.Admission
    let rootStart: ShipPose
    let rootEnd: ShipPose
    let componentStart: ShipPose
    let componentEnd: ShipPose
  }
  let startTime: Double
  let endTime: Double
  let frame: UInt64
  let player: ActorIdentity
  let playerStart: ShipPose
  let playerEnd: ShipPose
  let appliedPath: HullSceneMotion
  let acceptedWork: HullSceneMotion?
  let segments: [NativeC03NewtAppliedSegment]
  let originals: [Original]

  fileprivate init(pending: NativeC03MotionPending, closing: FlightSimulationState,
    path: CurrentNewtOuterMotion, frame: UInt64, player: ActorIdentity, originals: [Original])
  {
    startTime = pending.flight.physicalTime
    endTime = closing.physicalTime
    self.frame = frame
    self.player = player
    playerStart = pending.flight.pose
    playerEnd = closing.pose
    appliedPath = path.motion
    acceptedWork = path.approval
    segments = pending.nativeSegments
    self.originals = originals
  }
}

/// One fixed native frame, at most two originals and the one original main station. A foreign
/// actor is unsupported, never silently omitted from the opaque scene. No history accumulates.
struct NativeC03MotionPending: Sendable {
  fileprivate struct Source: Sendable {
    let admission: NativeHollowManifestState.Admission
    let body: SpaceBody
    let pose: ShipPose
    let mesh: Mesh
    let route: NativeHollowManifestState.Route
  }
  fileprivate let pin: NativeHollowManifestInstalledCase
  fileprivate let instance: ScriptInstance
  fileprivate let flight: FlightSimulationState
  fileprivate let openingBodies: [SpaceBody]
  fileprivate let epoch: UUID
  fileprivate let frame: UInt64
  fileprivate let playerMesh: Mesh
  fileprivate let shipID: String
  fileprivate let carrier: UUID
  fileprivate let inventory: OwnedEquipmentInventory
  fileprivate let nextEvent: UInt64
  fileprivate let events: [ScriptEvent]
  fileprivate let sources: [Source]
  fileprivate let station: SpaceBody
  fileprivate let stationPose: ShipPose
  fileprivate let stationMesh: Mesh
  fileprivate let celestials: [CelestialBody]
  fileprivate var camera: NativeC03AppliedCameraStep?
  fileprivate var cameraBodies: [SpaceBody] = []
  fileprivate var work: HullSceneMotion?
  fileprivate var powered: [NativeC03AppliedNPCStep] = []
  fileprivate var nativeSegments: [NativeC03NewtAppliedSegment] = []
  fileprivate var routes: [NativeHollowManifestState.Route] = []
  fileprivate var failure: NativeC03MotionRefusal?
}

extension Game {
  /// Actor lifecycle, before the actual native tick; takes no caller-built source or motion.
  mutating func beginC03AttainedMotionStep() {
    nativeC03MotionPending = nil
    nativeC03AttainedMotion = nil
    let inputs = c03LiveRouteInputs()
    guard !inputs.recognizedBodyIDs.isEmpty else { return }
    do {
      guard !paused, !docked, screen.isFlight, !playerEMPDisabled,
        let pin = inputs.pin, (1...2).contains(inputs.originals.count),
        let instance = commander.scriptState.instances[pin.missionID],
        let carrier = commander.hullInstanceID, let inventory = commander.equipmentInventory,
        inventory.activeHull == carrier, commander.flightSimulation.valid,
        commander.flightSimulation.pose.orientation.validRotation, gameplayRevision < UInt64.max,
        let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
        station.physical?.identity == commander.flightSimulation.anchors?.station.identity,
        station.nativeStationIdentity == nil
      else { throw NativeC03MotionRefusal.unavailableSource }
      let ids = Set(inputs.originals.map { $0.owned.body.id }).union([0])
      guard Set(bodies.map(\.id)).count == bodies.count,
        Set(bodies.map(\.id)) == ids, celestials.count <= 2,
        Set(celestials.map { $0.kind == .sun ? 1 : 0 }).count == celestials.count
      else { throw NativeC03MotionRefusal.unsupportedScene }
      var sources: [NativeC03MotionPending.Source] = []
      for original in inputs.originals {
        let life = try hollowManifestOriginalLife(slot: original.slot)
        guard acceptsHollowManifestOriginalLife(life),
          let body = bodies.first(where: { $0.id == original.owned.body.id }),
          let mesh = scriptNPCMesh(body), !mesh.vertices.isEmpty, !mesh.faces.isEmpty
        else { throw NativeC03MotionRefusal.unavailableSource }
        sources.append(
          .init(
            admission: original.admission, body: body,
            pose: modelPose(of: body), mesh: mesh, route: original.route))
      }
      nativeC03MotionPending = .init(
        pin: pin, instance: instance, flight: commander.flightSimulation, openingBodies: bodies,
        epoch: nativeStationRuntimeEpoch, frame: gameplayRevision,
        playerMesh: commander.playerMesh, shipID: commander.shipID, carrier: carrier,
        inventory: inventory, nextEvent: commander.scriptState.nextEvent,
        events: commander.scriptState.pendingEvents, sources: sources,
        station: station, stationPose: modelPose(of: station),
        stationMesh: gameplayMesh(for: station),
        celestials: celestials)
    } catch {
      nativeC03AttainedMotion = .refused(error as? NativeC03MotionRefusal ?? .unavailableSource)
    }
  }

  /// Input construction is confined to Game.moveBodies, after the actual camera/spin branch.
  mutating func captureC03CameraStep(_ actual: NativeC03AppliedCameraStep) {
    guard var pending = nativeC03MotionPending else { return }
    defer { nativeC03MotionPending = pending }
    guard pending.camera == nil, actual.before == pending.flight.pose,
      actual.after == commander.flightSimulation.pose,
      actual.delta.isFinite, actual.delta > 0, actual.delta <= 0.1,
      actual.after.position.finite, actual.after.orientation.validRotation,
      actual.manual.map({
        $0.pitch.isFinite && $0.roll.isFinite && $0.yaw.isFinite
          && $0.translation.finite
      }) ?? true
    else {
      pending.failure = .missingPhase
      return
    }
    pending.camera = actual
    if actual.work {
      guard let work = lastAppliedWorkMotion, work.start == actual.before,
        work.end == actual.after, work.duration == actual.delta
      else {
        pending.failure = .unsupportedWork
        return
      }
      pending.work = work
    }
    guard bodies.count == pending.sources.count + 1,
      Set(bodies.map(\.id)) == Set(pending.sources.map { $0.body.id }).union([0])
    else {
      pending.failure = .unsupportedScene
      return
    }
    guard let station = bodies.first(where: { $0.id == 0 }),
      c03StationCameraMatches(pending, station: station, phase: actual)
    else {
      pending.failure = .changedScene
      return
    }
    pending.cameraBodies = bodies
  }

  /// Input construction is confined to the existing powered actor mutation, never a predictor.
  mutating func captureC03PoweredStep(_ actual: NativeC03AppliedNPCStep) {
    guard var pending = nativeC03MotionPending,
      pending.sources.contains(where: { $0.body.id == actual.after.id })
    else { return }
    defer { nativeC03MotionPending = pending }
    guard let source = pending.sources.first(where: { $0.body.id == actual.after.id }),
      let camera = pending.camera, camera.delta == actual.delta,
      !pending.powered.contains(where: { $0.after.id == actual.after.id }),
      let current = hollowManifestMission?.savedHollowManifest?.routes.first(where: {
        $0.admission == source.admission.reference
      })
    else {
      pending.failure = .missingPhase
      return
    }
    pending.powered.append(actual)
    pending.routes.append(current)
  }

  /// After every native/post-physics effect and restore. Failure discards data, never physics.
  mutating func finishC03AttainedMotionStep(native: CurrentNewtNativeClockEvidence? = nil) {
    guard let pending = nativeC03MotionPending else { return }
    nativeC03MotionPending = nil
    do {
      if let native {
        nativeC03AttainedMotion = .recordedNative(try sealC03NativeAttainedMotion(pending, evidence: native))
      } else {
        guard pending.nativeSegments.isEmpty else { throw NativeC03MotionRefusal.missingPhase }
        nativeC03AttainedMotion = .recorded(try sealC03AttainedMotion(pending))
      }
    } catch {
      nativeC03AttainedMotion = .refused(error as? NativeC03MotionRefusal ?? .changedBinding)
    }
  }

  private func sealC03AttainedMotion(_ pending: NativeC03MotionPending) throws
    -> NativeC03AttainedMotion
  {
    if let failure = pending.failure { throw failure }
    let flight = commander.flightSimulation
    guard let phase = pending.camera, pending.powered.count == pending.sources.count,
      pending.cameraBodies.count == pending.sources.count + 1
    else { throw NativeC03MotionRefusal.missingPhase }
    let elapsed = flight.physicalTime - pending.flight.physicalTime
    let tolerance = min(1e-8, 2 * max(flight.physicalTime.ulp, pending.flight.physicalTime.ulp))
    guard !paused, !docked, screen.isFlight, !playerEMPDisabled,
      nativeStationRuntimeEpoch == pending.epoch, pending.frame < UInt64.max,
      gameplayRevision == pending.frame + 1,
      flight.valid, flight.anchors == pending.flight.anchors,
      flight.player == pending.flight.player, let player = flight.player,
      flight.pose == phase.after, abs(elapsed - phase.delta) <= tolerance,
      flight.nextActor == pending.flight.nextActor, flight.nextSpawn == pending.flight.nextSpawn,
      flight.nextEmission == pending.flight.nextEmission,
      flight.nextIncident == pending.flight.nextIncident,
      commander.scriptState.nextEvent == pending.nextEvent,
      commander.scriptState.pendingEvents == pending.events,
      commander.shipID == pending.shipID, sameMesh(commander.playerMesh, pending.playerMesh),
      commander.hullInstanceID == pending.carrier,
      commander.equipmentInventory == pending.inventory,
      stationImpactRevision != gameplayRevision, pendingNativeStationDock == nil
    else { throw NativeC03MotionRefusal.changedEffect }
    guard Set(bodies.map(\.id)) == Set(pending.cameraBodies.map(\.id)),
      bodies.count == pending.cameraBodies.count,
      let station = bodies.first(where: { $0.id == 0 }),
      station == pending.cameraBodies.first(where: { $0.id == 0 }),
      sameMesh(gameplayMesh(for: station), pending.stationMesh),
      celestials.count == pending.celestials.count
    else { throw NativeC03MotionRefusal.changedScene }
    for (a, b) in zip(pending.celestials, celestials) {
      guard a.kind == b.kind, a.radius == b.radius,
        (pending.flight.pose.systemPoint(a.position) - flight.pose.systemPoint(b.position)).length
          < 1e-7
      else { throw NativeC03MotionRefusal.changedScene }
    }
    var routes = pending.pin.state.routes
    for actual in pending.routes {
      guard let index = routes.firstIndex(where: { $0.admission == actual.admission }) else {
        throw NativeC03MotionRefusal.changedBinding
      }
      routes[index] = actual
    }
    if phase.work {
      guard pending.work != nil, pending.work == lastAppliedWorkMotion else {
        throw NativeC03MotionRefusal.unsupportedWork
      }
    } else if lastAppliedWorkMotion != nil {
      throw NativeC03MotionRefusal.unsupportedWork
    }
    let end = try hollowManifestInstalledCase()
    guard end.owner == pending.pin.owner, end.missionID == pending.pin.missionID,
      end.state == (try pending.pin.state.replacingRoutes(candidateRoutes: routes)),
      let current = commander.scriptState.instances[end.missionID],
      let frame = end.state.sourceFrame,
      var encounter = pending.instance.ownedEncounters[NativeHollowManifestCommission.encounter]
    else { throw NativeC03MotionRefusal.changedBinding }
    var records: [NativeC03AttainedMotion.Original] = []
    for source in pending.sources {
      let slot = source.admission.reference.slot
      let life = try hollowManifestOriginalLife(slot: slot)
      guard acceptsHollowManifestOriginalLife(life), life.admission == source.admission,
        let bound = c03CurrentOriginalBinding(end, slot: slot), bound.admission == source.admission,
        let body = bodies.first(where: { $0.id == source.body.id }),
        let camera = pending.cameraBodies.first(where: { $0.id == body.id }),
        let powered = pending.powered.first(where: { $0.after.id == body.id }),
        let route = pending.routes.first(where: { $0.admission.slot == slot }),
        let mesh = scriptNPCMesh(body), sameMesh(mesh, source.mesh)
      else { throw NativeC03MotionRefusal.changedBinding }
      var expectedCamera = source.body
      expectedCamera.position = camera.position
      expectedCamera.orientation = camera.orientation
      expectedCamera.rotation = camera.rotation
      expectedCamera.scriptNPC?.velocity = camera.scriptNPC?.velocity ?? .init(0, 0, 0)
      var expectedBefore = camera
      expectedBefore.scriptNPC?.intent = powered.before.scriptNPC?.intent
      var expectedEnd = powered.after
      if let velocity = expectedEnd.scriptNPC?.velocity {
        expectedEnd.physical?.velocity = flight.pose.orientation.apply(velocity)
      }
      guard expectedCamera == camera, expectedBefore == powered.before, expectedEnd == body,
        body.energy == source.body.energy,
        body.scriptNPC?.components == source.body.scriptNPC?.components,
        body.physical?.identity == source.admission.original.actor,
        body.physical?.spawnIdentity == source.admission.spawn,
        let physical = body.physical
      else { throw NativeC03MotionRefusal.changedScene }
      let rootEnd = modelPose(of: body)
      records.append(
        .init(
          authenticAdmission: source.admission, sourceFrame: frame,
          rootStart: source.pose, rootAfterCamera: Self.modelPose(of: camera, player: phase.after),
          rootEnd: rootEnd, componentStart: componentPose(source.pose, source.admission),
          componentEnd: componentPose(rootEnd, source.admission), powered: powered,
          initialRotation: source.body.rotation, cameraRotation: camera.rotation,
          rotationRate: source.body.rotationRate, worldSpin: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin == true, routeStart: source.route, routeEnd: route))
      encounter.actors[slot.rawValue] = bound.owned
    }
    var expected = pending.instance
    expected.savedHollowManifest = end.state
    expected.ownedEncounters[encounter.id] = encounter
    guard expected == current else { throw NativeC03MotionRefusal.changedBinding }
    return .init(
      pending: pending, phase: phase, work: pending.work, originals: records,
      station: modelPose(of: station), celestials: celestials,
      endTime: flight.physicalTime, frame: gameplayRevision, player: player)
  }

  private func c03StationCameraMatches(
    _ pending: NativeC03MotionPending, station: SpaceBody, phase: NativeC03AppliedCameraStep
  ) -> Bool {
    guard let physical = pending.station.physical, physical.velocity == Vector3(0, 0, 0),
      physical.angularVelocity.finite,
      sameMesh(gameplayMesh(for: station), pending.stationMesh)
    else { return false }
    var expected = pending.station
    expected.position = station.position
    expected.orientation = station.orientation
    expected.rotation = station.rotation
    guard expected == station,
      (pending.flight.pose.systemPoint(pending.station.position)
        - phase.after.systemPoint(station.position)).length < 1e-7,
      station.rotation == pending.station.rotation + phase.delta * pending.station.rotationRate
    else { return false }
    var world = pending.station.orientation.transformed(by: pending.flight.pose.orientation)
    if physical.canonicalSpin == true {
      world = RelativeWorkController.rotated(
        world, omega: physical.angularVelocity,
        delta: phase.delta)
    }
    let actual = station.orientation.transformed(by: phase.after.orientation)
    // Equality validation of the actual native branch, never a second physical integration or
    // a claim that this phase acquired substep timing/continuous rotational visibility.
    return (world.x - actual.x).length < 1e-7 && (world.y - actual.y).length < 1e-7
      && (world.z - actual.z).length < 1e-7
  }

  private func componentPose(_ root: ShipPose, _ admission: NativeHollowManifestState.Admission)
    -> ShipPose
  {
    let local = admission.geometry.componentPose
    return .init(
      position: root.systemPoint(local.position),
      orientation: local.orientation.transformed(by: root.orientation))
  }

  private func sameMesh(_ a: Mesh, _ b: Mesh) -> Bool {
    a.vertices == b.vertices && a.faces == b.faces
  }
}


extension Game {
  /// This input can be constructed only at the actual native retention mutation above.
  /// Capture remains provisional until the clock owner reciprocates every exact opening.
  mutating func captureC03NativeAppliedSegment(_ applied: NativeC03NewtAppliedSegment) {
    guard var pending = nativeC03MotionPending else { return }
    defer { nativeC03MotionPending = pending }
    let opening = applied.opening
    guard pending.camera == nil, pending.powered.isEmpty,
      applied.epoch == pending.epoch, opening.interval.valid,
      applied.beforeBodies == opening.before.bodies,
      applied.afterFlight.physicalTime == opening.interval.end,
      opening.before.storedFlightSimulation().physicalTime == opening.interval.start,
      applied.afterFlight.player == pending.flight.player,
      applied.afterFlight.anchors == pending.flight.anchors
    else { pending.failure = .missingPhase; return }
    if let previous = pending.nativeSegments.last {
      guard previous.afterFlight == opening.before.storedFlightSimulation(),
        previous.afterBodies == applied.beforeBodies,
        previous.afterCelestials == opening.before.celestials else {
        pending.failure = .changedScene
        return
      }
    } else {
      var expected = pending.openingBodies
      for index in expected.indices {
        let bodyID = expected[index].id
        guard pending.sources.contains(where: { $0.body.id == bodyID }) else { continue }
        let observed = applied.beforeBodies.first(where: { $0.id == bodyID })?.scriptNPC?.intent
        expected[index].scriptNPC?.intent = observed
      }
      guard opening.before.storedFlightSimulation() == pending.flight,
        applied.beforeBodies == expected else {
        pending.failure = .changedBinding
        return
      }
    }
    pending.nativeSegments.append(applied)
  }

  /// Read-only mutation captures, not a clock, source, frame or inspection authority.
  var c03NativeAppliedSegments: [NativeC03NewtAppliedSegment] {
    nativeC03MotionPending?.nativeSegments ?? []
  }

  /// Diagnostics expose no saved state or admission permission. The clock owner checks
  /// identity, chronology and the actual retained body chain, never caller Boolean claims.
  func c03NativeAppliedChainMatches(_ evidence: CurrentNewtNativeClockEvidence) -> Bool {
    guard let pending = nativeC03MotionPending, pending.failure == nil else { return false }
    guard let first = pending.nativeSegments.first else { return false }
    return evidence.validatesC03AppliedSegments(pending.nativeSegments,
      opening: pending.flight, bodies: first.beforeBodies, current: self)
  }

  private func sealC03NativeAttainedMotion(_ pending: NativeC03MotionPending,
    evidence: CurrentNewtNativeClockEvidence) throws -> NativeC03NativeAttainedMotion
  {
    if let failure = pending.failure { throw failure }
    guard pending.camera == nil, pending.powered.isEmpty,
      let first = pending.nativeSegments.first, let last = pending.nativeSegments.last,
      let path = first.opening.npcFrame?.path.rootMotion,
      evidence.validatesC03AppliedSegments(pending.nativeSegments,
        opening: pending.flight, bodies: first.beforeBodies, current: self)
    else { throw NativeC03MotionRefusal.missingPhase }
    let flight = commander.flightSimulation
    let elapsed = flight.physicalTime - pending.flight.physicalTime
    let tolerance = min(1e-8, 2 * max(flight.physicalTime.ulp, pending.flight.physicalTime.ulp))
    guard !paused, !docked, screen.isFlight, !playerEMPDisabled,
      nativeStationRuntimeEpoch == pending.epoch, pending.frame < UInt64.max,
      gameplayRevision == pending.frame + 1,
      flight.valid, flight.anchors == pending.flight.anchors,
      flight.player == pending.flight.player, let player = flight.player,
      path.epoch == pending.epoch, path.motion.start == pending.flight.pose,
      path.motion.end == flight.pose,
      abs(elapsed - path.motion.duration) <= tolerance,
      flight.nextActor == pending.flight.nextActor, flight.nextSpawn == pending.flight.nextSpawn,
      flight.nextEmission == pending.flight.nextEmission, flight.nextIncident == pending.flight.nextIncident,
      commander.scriptState.nextEvent == pending.nextEvent,
      commander.scriptState.pendingEvents == pending.events,
      commander.shipID == pending.shipID, sameMesh(commander.playerMesh, pending.playerMesh),
      commander.hullInstanceID == pending.carrier, commander.equipmentInventory == pending.inventory,
      stationImpactRevision != gameplayRevision, pendingNativeStationDock == nil,
      Set(bodies.map(\.id)) == Set(pending.openingBodies.map(\.id)),
      bodies.count == pending.openingBodies.count,
      celestials.count == pending.celestials.count
    else { throw NativeC03MotionRefusal.changedEffect }
    if path.workMode && path.approval == nil { throw NativeC03MotionRefusal.unsupportedWork }
    for (before, after) in zip(pending.celestials, celestials) {
      guard before.kind == after.kind, before.radius == after.radius,
        (pending.flight.pose.systemPoint(before.position) - flight.pose.systemPoint(after.position)).length < 1e-7
      else { throw NativeC03MotionRefusal.changedScene }
    }
    let end = try hollowManifestInstalledCase()
    guard end.state == (try pending.pin.state.replacingRoutes(candidateRoutes: end.state.routes)),
      let current = commander.scriptState.instances[end.missionID],
      var encounter = pending.instance.ownedEncounters[NativeHollowManifestCommission.encounter]
    else { throw NativeC03MotionRefusal.changedBinding }
    var originals: [NativeC03NativeAttainedMotion.Original] = []
    for source in pending.sources {
      let slot = source.admission.reference.slot
      let life = try hollowManifestOriginalLife(slot: slot)
      guard acceptsHollowManifestOriginalLife(life), life.admission == source.admission,
        let bound = c03CurrentOriginalBinding(end, slot: slot), bound.admission == source.admission,
        let body = bodies.first(where: { $0.id == source.body.id }),
        let opening = first.beforeBodies.first(where: { $0.id == body.id }),
        let retained = last.afterBodies.first(where: { $0.id == body.id }),
        let actor = body.physical?.identity,
        let decision = last.opening.npcFrame?.entries[actor]?.decision,
        let velocity = retained.physical?.velocity,
        let mesh = scriptNPCMesh(body), sameMesh(mesh, source.mesh)
      else { throw NativeC03MotionRefusal.changedBinding }
      var expectedOpening = source.body
      expectedOpening.scriptNPC?.intent = opening.scriptNPC?.intent
      var expectedEnd = retained
      expectedEnd.scriptNPC?.intent = decision.intent
      expectedEnd.scriptNPC?.velocity = flight.pose.shipVector(velocity)
      expectedEnd.physical?.velocity = flight.pose.orientation.apply(flight.pose.shipVector(velocity))
      guard expectedOpening == opening, expectedEnd == body,
        body.energy == source.body.energy,
        body.scriptNPC?.components == source.body.scriptNPC?.components,
        body.physical?.identity == source.admission.original.actor,
        body.physical?.spawnIdentity == source.admission.spawn
      else { throw NativeC03MotionRefusal.changedScene }
      let root = modelPose(of: body)
      originals.append(.init(admission: source.admission, rootStart: source.pose, rootEnd: root,
        componentStart: componentPose(source.pose, source.admission),
        componentEnd: componentPose(root, source.admission)))
      encounter.actors[slot.rawValue] = bound.owned
    }
    // The main station is part of the exact actual retained scene too.
    guard let station = bodies.first(where: { $0.id == 0 }),
      let retainedStation = last.afterBodies.first(where: { $0.id == 0 }), station == retainedStation,
      sameMesh(gameplayMesh(for: station), pending.stationMesh)
    else { throw NativeC03MotionRefusal.changedScene }
    var expected = pending.instance
    expected.savedHollowManifest = end.state
    expected.ownedEncounters[encounter.id] = encounter
    guard expected == current else { throw NativeC03MotionRefusal.changedBinding }
    return .init(pending: pending, closing: flight, path: path, frame: gameplayRevision,
      player: player, originals: originals)
  }
}
