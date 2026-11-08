import Foundation

/// Sealed, attempt-local source from actual installed case/loan and current native visit.
/// Only the Game factory below constructs this; it is not Codable or an actor admission.
final class NativeC03WakeAdmissionContext: Sendable {
  struct Projection: Sendable {
    let body: SpaceBody
    let historicalPhysical: PhysicalActorState
  }

  let pin: NativeHollowManifestInstalledCase
  let initial: Bool
  let reference: ShipPose
  let anchors: SystemAnchors
  let flight: FlightSimulationState
  let station: SpaceBody
  let retention: ScriptOwnedEncounter
  let declaration: ScriptEncounterDefinition
  let profiles: [ScriptNPCDefinition]
  let designs: [String: ShipDesign]
  let previousGeometry: [String: ShipDesign]
  let geometry: [String: ShipDesign]
  let projections: [UUID: Projection]
  var installedEncounter: ScriptOwnedEncounter? { initial ? nil : retention }

  fileprivate init(
    pin: NativeHollowManifestInstalledCase, initial: Bool, reference: ShipPose,
    anchors: SystemAnchors, flight: FlightSimulationState, station: SpaceBody,
    retention: ScriptOwnedEncounter, declaration: ScriptEncounterDefinition,
    profiles: [ScriptNPCDefinition], designs: [String: ShipDesign],
    previousGeometry: [String: ShipDesign], geometry: [String: ShipDesign], projections: [UUID: Projection]
  ) {
    self.pin = pin
    self.initial = initial
    self.reference = reference
    self.anchors = anchors
    self.flight = flight
    self.station = station
    self.retention = retention
    self.declaration = declaration
    self.profiles = profiles
    self.designs = designs
    self.previousGeometry = previousGeometry
    self.geometry = geometry
    self.projections = projections
  }
}

extension Game {
  /// The originals are born together by the real native allocator, not by a script event,
  /// visible mesh, hash, catalogue row or decoded trail. First issuance needs the held loan.
  @inline(never)
  func hollowManifestWakeAdmissionContext() throws -> NativeC03WakeAdmissionContext? {
    guard !docked, systemIdentity == NativeC03WakeGeometry.world,
      let instance = hollowManifestMission, instance.savedHollowManifest?.laboratory != nil
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    let initial = pin.state.wakeTrail == nil
    if initial {
      guard instance.outcome == .active, instance.suspension == nil,
        instance.milestones == [0, 1, 2], pin.state.phase == .admitted,
        pin.state.terminals.isEmpty, pin.state.withdrawals.isEmpty,
        pin.state.firstCompromises.isEmpty
      else { return nil }
      _ = try withReadOnlyCommander {
        try NativeHollowManifestKitCustody.resolve(instance: instance, commander: $0)
      }
    }
    let flight = withReadOnlyCommander { $0.flightSimulation }
    guard flight.valid, let station = scriptAnchor, station.energy > 0,
      bodies.contains(station), let current = flight.anchors, let projected = gameplayContext(),
      NativeC03AnchorFrames.matches(
        canonical: current, current: projected, flight: flight, station: station),
      station.physical?.identity == current.station.identity,
      current.system == NativeC03WakeGeometry.world, flight.system == current.system,
      flight.visit == current.station.identity.visit
    else { return nil }
    let anchors = pin.state.wakeTrail?.origin.anchors ?? current
    let layout = try NativeC03WakeGeometry.candidateLayout(anchors: anchors)
    let reference = pin.state.wakeTrail?.origin.reference ?? layout.reference
    guard reference == layout.reference else { throw SaveError.invalidCommander }
    let previousGeometry = withReadOnlyScriptState { $0.geometry }
    var geometry = previousGeometry
    var designs: [String: ShipDesign] = [:]
    var hashes: [String: String] = [:]
    let profiles = NativeC03WakeGeometry.Mark.allCases.map(NativeC03WakeGeometry.profile)
    for mark in NativeC03WakeGeometry.Mark.allCases {
      let design = NativeC03WakeGeometry.design(mark)
      let hash = try NativeC03WakeGeometry.geometryHash(mark)
      guard geometry[hash] == nil || geometry[hash] == design else { throw SaveError.invalidCommander }
      designs[mark.model] = design
      hashes[mark.model] = hash
      geometry[hash] = design
    }
    let declaration = try NativeC03WakeGeometry.declaration(anchors: anchors)
    guard declaration.valid, profiles.allSatisfy(\.valid) else { throw SaveError.invalidCommander }
    let retention: ScriptOwnedEncounter
    var projections: [UUID: NativeC03WakeAdmissionContext.Projection] = [:]
    if initial {
      guard instance.ownedEncounters[NativeC03WakeTrail.encounter] == nil else {
        throw SaveError.invalidCommander
      }
      var actors: [String: ScriptOwnedActor] = [:]
      for mark in NativeC03WakeGeometry.Mark.allCases {
        let logical = NativeC03WakeTrail.logicalActor(mission: instance.id, mark: mark)
        guard let hash = hashes[mark.model] else { throw SaveError.invalidCommander }
        var body = SpaceBody(
          id: -1, hull: .cobra,
          position: station.orientation.inverse(
            flight.pose.shipPoint(layout.positions[mark.index]) - station.position), hostile: false)
        body.orientation = reference.orientation.relative(to: flight.pose.orientation)
          .relative(to: station.orientation)
        body.energy = 1
        body.rotation = 0
        body.rotationRate = 0
        body.missiles = 0
        body.ecmEnabled = false
        body.missionInstanceID = instance.id
        body.missionActorID = logical
        body.scriptNPC = .init(
          fit: .init(definition: NativeC03WakeGeometry.profile(mark), models: [mark.model: hash]),
          fuel: 0, guns: [:], components: [:])
        actors[mark.rawValue] = .init(
          identity: logical, alias: mark.rawValue, body: body, presence: .prepared)
      }
      retention = .init(
        id: declaration.id, galaxy: declaration.galaxy, system: declaration.system, actors: actors)
    } else {
      guard let trail = pin.state.wakeTrail,
        let owned = instance.ownedEncounters[NativeC03WakeTrail.encounter],
        NativeC03WakeTrail.actorClaimsMatch(instance)
      else { throw SaveError.invalidCommander }
      retention = owned
      for actor in owned.actors.values where [.outside, .unloaded].contains(actor.presence) {
        guard let mark = NativeC03WakeGeometry.Mark(rawValue: actor.alias),
          let admission = trail.latest(mark), actor.body.energy > 0,
          let physical = actor.body.physical, physical.identity == admission.actor
        else { throw SaveError.invalidCommander }
        var body = actor.body
        let point = reference.systemPoint(body.position)
        let orientation = body.orientation.transformed(by: reference.orientation)
        body.position = station.orientation.inverse(flight.pose.shipPoint(point) - station.position)
        body.orientation = orientation.relative(to: flight.pose.orientation).relative(to: station.orientation)
        body.scriptNPC?.velocity = station.orientation.inverse(flight.pose.shipVector(physical.velocity))
        body.id = -1
        body.physical = nil
        projections[actor.identity] = .init(body: body, historicalPhysical: physical)
      }
    }
    return .init(
      pin: pin, initial: initial, reference: reference, anchors: anchors, flight: flight,
      station: station, retention: retention, declaration: declaration, profiles: profiles,
      designs: designs, previousGeometry: previousGeometry, geometry: geometry, projections: projections)
  }

  func acceptsHollowManifestWakeAdmissionContext(_ context: NativeC03WakeAdmissionContext) -> Bool {
    guard acceptsHollowManifestInstalledCase(context.pin),
      withReadOnlyCommander({ $0.flightSimulation }) == context.flight,
      withReadOnlyScriptState({ $0.geometry }) == context.previousGeometry,
      scriptAnchor == context.station,
      withReadOnlyScriptState({ $0.instances[context.pin.missionID]?
        .ownedEncounters[NativeC03WakeTrail.encounter] }) == context.installedEncounter
    else { return false }
    if context.initial {
      guard let instance = hollowManifestMission,
        (try? withReadOnlyCommander {
          try NativeHollowManifestKitCustody.resolve(instance: instance, commander: $0)
        }) != nil
      else { return false }
    }
    return true
  }
}

extension NativeC03WakeTrail {
  /// Pure saved-claim check, never native allocation or a live observation capability.
  @inline(never)
  static func actorClaimsMatch(_ instance: borrowing ScriptInstance) -> Bool {
    guard let state = instance.savedHollowManifest else { return false }
    guard let trail = state.wakeTrail else {
      return instance.ownedEncounters[encounter] == nil
    }
    guard let owned = instance.ownedEncounters[encounter], owned.valid, owned.admitted,
      owned.id == encounter, owned.galaxy == NativeC03WakeGeometry.world.galaxy,
      owned.system == NativeC03WakeGeometry.world.system,
      Set(owned.actors.keys) == Set(Mark.allCases.map(\.rawValue))
    else { return false }
    for mark in Mark.allCases {
      guard let actor = owned.actors[mark.rawValue], let admission = trail.latest(mark),
        actor.alias == mark.rawValue, actor.identity == admission.logicalActor,
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == instance.id,
        (1..<1_000_000_000).contains(actor.body.id), actor.body.hull == .cobra,
        actor.body.position.finite, actor.body.position.length.isFinite,
        actor.body.orientation.validRotation, actor.body.rotation.isFinite,
        actor.body.rotationRate.isFinite, actor.body.energy.isFinite,
        (0...1).contains(actor.body.energy), actor.body.missiles == 0, !actor.body.ecmEnabled,
        [.present, .outside, .unloaded, .destroyed].contains(actor.presence),
        (actor.presence == .destroyed) == (actor.body.energy == 0),
        let physical = actor.body.physical, physical.identity == admission.actor,
        physical.spawnIdentity == admission.spawn, physical.population == .mission,
        physical.npc?.role == .mission, let resources = physical.npc?.resources, resources.valid,
        resources.profile == .nativeHull, resources.energyCapacity == 1, resources.energyRecharge == 0,
        resources.frontCapacity == 0, resources.rearCapacity == 0, resources.shieldRecharge == 0,
        resources.fuel == 0, resources.fuelCapacity == 0,
        physical.npc?.hasFuelScoops == false, physical.npc?.ordinaryCargo.isEmpty == true,
        physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
        physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
        physical.velocity.finite, physical.angularVelocity.finite,
        let npc = actor.body.scriptNPC, npc.valid,
        npc.fit.definition == NativeC03WakeGeometry.profile(mark),
        npc.fit.models[mark.model] == admission.geometry,
        npc.components.isEmpty, npc.guns.isEmpty, npc.shots == 0, npc.fuel == 0,
        npc.intent == nil,
        (trail.origin.reference.orientation.apply(npc.velocity) - physical.velocity).length < 1e-8
      else { return false }
    }
    return true
  }
}
