import Foundation

/// Actual attempt-local source, not Codable and not constructible from a document or marker.
final class NativeC03RegisterAdmissionContext: Sendable {
  struct Projection: Sendable {
    let body: SpaceBody
    let historicalPhysical: PhysicalActorState
  }

  let pin: NativeHollowManifestInstalledCase
  let initial: Bool
  let contents: NativeC03CustodyRegisterContent
  let reference: ShipPose
  let anchors: SystemAnchors
  let flight: FlightSimulationState
  let station: SpaceBody
  let retention: ScriptOwnedEncounter
  let declaration: ScriptEncounterDefinition
  let designs: [String: ShipDesign]
  let previousGeometry: [String: ShipDesign]
  let geometry: [String: ShipDesign]
  let projection: Projection?
  var installedEncounter: ScriptOwnedEncounter? { initial ? nil : retention }

  fileprivate init(
    pin: NativeHollowManifestInstalledCase, initial: Bool, contents: NativeC03CustodyRegisterContent,
    reference: ShipPose, anchors: SystemAnchors, flight: FlightSimulationState, station: SpaceBody,
    retention: ScriptOwnedEncounter, declaration: ScriptEncounterDefinition,
    designs: [String: ShipDesign], previousGeometry: [String: ShipDesign],
    geometry: [String: ShipDesign], projection: Projection?
  ) {
    self.pin = pin
    self.initial = initial
    self.contents = contents
    self.reference = reference
    self.anchors = anchors
    self.flight = flight
    self.station = station
    self.retention = retention
    self.declaration = declaration
    self.designs = designs
    self.previousGeometry = previousGeometry
    self.geometry = geometry
    self.projection = projection
  }
}

extension NativeC03RegisterGeometry {
  static let declaration = ScriptEncounterDefinition(
    id: NativeC03RegisterState.encounter,
    galaxy: NativeHollowManifestDefinition.registerWorld.galaxy,
    system: NativeHollowManifestDefinition.registerWorld.system,
    profile: "profiled-local-freeze-v1", actors: [
      .init(id: component, hull: nil, npc: profileID, x: 0, y: 0, z: 0, hostile: false),
    ])
}

extension Game {
  /// Only the actual installed three-mark case, held original kit and current native world
  /// can propose the first archive. The real allocator/policy must still issue it atomically.
  @inline(never)
  func hollowManifestRegisterAdmissionContext() throws -> NativeC03RegisterAdmissionContext? {
    guard !docked, systemIdentity == NativeHollowManifestDefinition.registerWorld,
      let instance = hollowManifestMission,
      instance.savedHollowManifest?.wakeTrail?.observations.count == 3
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    let initial = pin.state.custodyRegister == nil
    if initial {
      guard instance.outcome == .active, instance.suspension == nil,
        instance.milestones == [0, 1, 2, 3], pin.state.phase == .admitted,
        pin.state.terminals.isEmpty, pin.state.withdrawals.isEmpty, pin.state.firstCompromises.isEmpty,
        (try? NativeHollowManifestKitCustody.resolve(instance: instance, commander: commander)) != nil
      else { return nil }
    }
    let flight = withReadOnlyCommander { $0.flightSimulation }
    guard let station = scriptAnchor, bodies.contains(station), let current = flight.anchors,
      let projected = gameplayContext(), NativeC03AnchorFrames.matches(
        canonical: current, current: projected, flight: flight, station: station)
    else { return nil }
    let anchors = pin.state.custodyRegister?.origin.anchors ?? current
    let reference = try NativeC03RegisterGeometry.candidateFrame(anchors: anchors)
    let contents = try NativeC03CustodyRegisterContent.candidate(state: pin.state)
    if let saved = pin.state.custodyRegister {
      guard saved.origin.reference == reference, saved.origin.contents == contents else {
        throw SaveError.invalidCommander
      }
    }
    let hashes = try NativeC03RegisterGeometry.hashes.get()
    let designs = [NativeC03RegisterGeometry.rootModel: NativeC03RegisterGeometry.rootDesign,
      NativeC03RegisterGeometry.faceModel: NativeC03RegisterGeometry.faceDesign]
    let previous = withReadOnlyScriptState { $0.geometry }
    var geometry = previous
    for (hash, design) in [(hashes.root, NativeC03RegisterGeometry.rootDesign),
      (hashes.face, NativeC03RegisterGeometry.faceDesign)] {
      guard geometry[hash] == nil || geometry[hash] == design else { throw SaveError.invalidCommander }
      geometry[hash] = design
    }
    let logical = NativeC03RegisterState.logicalActor(mission: instance.id)
    let retention: ScriptOwnedEncounter
    var projection: NativeC03RegisterAdmissionContext.Projection?
    if initial {
      guard instance.ownedEncounters[NativeC03RegisterState.encounter] == nil else {
        throw SaveError.invalidCommander
      }
      var body = SpaceBody(
        id: -1, hull: .cobra,
        position: station.orientation.inverse(flight.pose.shipPoint(reference.position) - station.position),
        hostile: false)
      body.orientation = reference.orientation.relative(to: flight.pose.orientation)
        .relative(to: station.orientation)
      body.energy = 16
      body.missiles = 0
      body.ecmEnabled = false
      body.rotation = 0
      body.rotationRate = 0
      body.missionInstanceID = instance.id
      body.missionActorID = logical
      body.scriptNPC = .init(
        fit: .init(definition: NativeC03RegisterGeometry.profile, models: [
          NativeC03RegisterGeometry.rootModel: hashes.root,
          NativeC03RegisterGeometry.faceModel: hashes.face,
        ]), fuel: 0, guns: [:], components: [
          NativeC03RegisterGeometry.component: .init(
            identity: NativeC03RegisterState.component(mission: instance.id), energy: 1, guns: [:]),
        ])
      retention = .init(
        id: NativeC03RegisterState.encounter,
        galaxy: NativeHollowManifestDefinition.registerWorld.galaxy,
        system: NativeHollowManifestDefinition.registerWorld.system,
        actors: [NativeC03CustodyRegisterContent.target: .init(
          identity: logical, alias: NativeC03CustodyRegisterContent.target, body: body, presence: .prepared)])
    } else {
      guard NativeC03RegisterState.actorClaimsMatch(instance),
        let owned = instance.ownedEncounters[NativeC03RegisterState.encounter],
        let actor = owned.actors[NativeC03CustodyRegisterContent.target]
      else { throw SaveError.invalidCommander }
      retention = owned
      if [.outside, .unloaded].contains(actor.presence) {
        guard let physical = actor.body.physical, actor.body.energy > 0 else {
          throw SaveError.invalidCommander
        }
        var body = actor.body
        let point = reference.systemPoint(body.position)
        let orientation = body.orientation.transformed(by: reference.orientation)
        body.position = station.orientation.inverse(flight.pose.shipPoint(point) - station.position)
        body.orientation = orientation.relative(to: flight.pose.orientation).relative(to: station.orientation)
        body.scriptNPC?.velocity = station.orientation.inverse(flight.pose.shipVector(physical.velocity))
        body.id = -1
        body.physical = nil
        projection = .init(body: body, historicalPhysical: physical)
      }
    }
    return .init(
      pin: pin, initial: initial, contents: contents, reference: reference, anchors: anchors,
      flight: flight, station: station, retention: retention,
      declaration: NativeC03RegisterGeometry.declaration, designs: designs,
      previousGeometry: previous, geometry: geometry, projection: projection)
  }

  func acceptsHollowManifestRegisterAdmissionContext(_ context: NativeC03RegisterAdmissionContext) -> Bool {
    guard acceptsHollowManifestInstalledCase(context.pin),
      withReadOnlyCommander({ $0.flightSimulation }) == context.flight,
      withReadOnlyScriptState({ $0.geometry }) == context.previousGeometry,
      scriptAnchor == context.station,
      withReadOnlyScriptState({ $0.instances[context.pin.missionID]?
        .ownedEncounters[NativeC03RegisterState.encounter] }) == context.installedEncounter
    else { return false }
    if context.initial {
      guard let instance = hollowManifestMission,
        (try? NativeHollowManifestKitCustody.resolve(instance: instance, commander: commander)) != nil
      else { return false }
    }
    return true
  }
}
