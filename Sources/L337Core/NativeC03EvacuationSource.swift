import Foundation

/// Current Game-owned source preparation only. Native geometry, fitting provenance and
/// occupied/loaded inertia must still be admitted by the actual native policy. In particular,
/// this context and the proposed local fit cannot qualify the currently blocked Saiga.
final class NativeC03EvacuationAdmissionContext: Sendable {
  struct Projection: Sendable {
    let body: SpaceBody
    let historicalPhysical: PhysicalActorState
  }

  let pin: NativeHollowManifestInstalledCase
  let initial: Bool
  let previousCustody: NativePeopleCustodyState?
  let originalSource: NativeC03CrewSourceState?
  let accommodation: NativeC03EvacuationAccommodation
  let heldRegister: NativeC03HeldRegisterData?
  let flight: FlightSimulationState
  let station: SpaceBody
  let anchors: SystemAnchors
  let reference: ShipPose
  let retention: ScriptOwnedEncounter
  let declaration: ScriptEncounterDefinition
  let designs: [String: ShipDesign]
  let previousGeometry: [String: ShipDesign]
  let geometry: [String: ShipDesign]
  let projections: [UUID: Projection]
  let epoch: UUID
  var installedEncounter: ScriptOwnedEncounter? { initial ? nil : retention }

  fileprivate init(
    pin: NativeHollowManifestInstalledCase, initial: Bool,
    previousCustody: NativePeopleCustodyState?, originalSource: NativeC03CrewSourceState?,
    accommodation: NativeC03EvacuationAccommodation, heldRegister: NativeC03HeldRegisterData?,
    flight: FlightSimulationState, station: SpaceBody, anchors: SystemAnchors, reference: ShipPose,
    retention: ScriptOwnedEncounter, declaration: ScriptEncounterDefinition,
    designs: [String: ShipDesign], previousGeometry: [String: ShipDesign], geometry: [String: ShipDesign],
    projections: [UUID: Projection], epoch: UUID
  ) {
    self.pin = pin
    self.initial = initial
    self.previousCustody = previousCustody
    self.originalSource = originalSource
    self.accommodation = accommodation
    self.heldRegister = heldRegister
    self.flight = flight
    self.station = station
    self.anchors = anchors
    self.reference = reference
    self.retention = retention
    self.declaration = declaration
    self.designs = designs
    self.previousGeometry = previousGeometry
    self.geometry = geometry
    self.projections = projections
    self.epoch = epoch
  }

  func role(of logical: UUID) -> NativeC03EvacuationHull.Role? {
    if logical == NativeC03CrewSourceState.logicalActor(mission: pin.missionID, launch: false) {
      return .carrier
    }
    if logical == NativeC03CrewSourceState.logicalActor(mission: pin.missionID, launch: true) {
      return .launch
    }
    return nil
  }
}

extension Game {
  /// No actor or person is allocated here. Only the actual installed case and original held
  /// kit/data can propose the first source. Existing sources retain their exact condition.
  @inline(never)
  func hollowManifestEvacuationAdmissionContext() throws -> NativeC03EvacuationAdmissionContext? {
    guard !docked, systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      let instance = hollowManifestMission,
      instance.savedHollowManifest?.custodyRegister?.recovery != nil
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    let custody = withReadOnlyCommander { $0.nativePeople }
    let source = custody?.hollowManifestCrew
    let initial = source == nil
    let held: NativeC03HeldRegisterData?
    let accommodation: NativeC03EvacuationAccommodation
    if initial {
      guard !paused, screen.isFlight, energy.isFinite, energy > 0, !playerEMPDisabled,
        jumpCountdown == nil, pendingNativeStationDock == nil,
        instance.outcome == .active, instance.suspension == nil,
        instance.milestones == [0, 1, 2, 3, 4], pin.state.phase == .admitted,
        pin.state.crewSource == nil,
        pin.state.terminals.isEmpty, pin.state.withdrawals.isEmpty, pin.state.firstCompromises.isEmpty,
        instance.ownedEncounters[NativeC03CrewSourceState.encounter] == nil
      else { return nil }
      held = try hollowManifestHeldRegisterData()
      accommodation = try .candidate(owner: pin.owner, mission: instance.id)
    } else {
      guard let custody, let source,
        withReadOnlyCommander({
          NativeC03CrewSourceSave.validSource(source, custody: custody, commander: $0)
        }),
        source.mission == instance.id, pin.state.crewSource == source.missionReference
      else { throw SaveError.invalidCommander }
      held = nil
      accommodation = source.registration.accommodation
    }
    let flight = withReadOnlyCommander { $0.flightSimulation }
    guard let station = scriptAnchor, bodies.contains(station), let current = flight.anchors,
      let projected = gameplayContext(), NativeC03AnchorFrames.matches(
        canonical: current, current: projected, flight: flight, station: station)
    else { return nil }
    let anchors = source?.registration.anchors ?? current
    let reference = try Self.c03EvacuationReference(anchors)
    guard source.map({ $0.registration.reference == reference }) ?? true else {
      throw SaveError.invalidCommander
    }
    let previousGeometry = withReadOnlyScriptState { $0.geometry }
    var geometry = previousGeometry
    let declared = try NativeC03EvacuationDefinitions.resolve()
    let designs = declared.designs
    let declaration = declared.encounter
    var prepared: [String: ScriptOwnedActor] = [:]
    let roles: [NativeC03EvacuationHull.Role] = [.carrier, .launch]
    for role in roles {
      let hull = try NativeC03EvacuationHull.resolve(role)
      let profile = try NativeC03EvacuationProfile.definition(role)
      guard geometry[hull.geometry] == nil || geometry[hull.geometry] == hull.design else {
        throw SaveError.invalidCommander
      }
      geometry[hull.geometry] = hull.design
      let target = role == .launch ? NativeC03CrewSourceState.launchTarget : NativeC03CrewSourceState.carrierTarget
      guard let spec = declaration.actors.first(where: { $0.id == target }), spec.npc == profile.id else {
        throw SaveError.invalidCommander
      }
      let point = Vector3(spec.x, spec.y, spec.z)
      if initial {
        let logical = NativeC03CrewSourceState.logicalActor(mission: instance.id, launch: role == .launch)
        var body = SpaceBody(id: -1, hull: .cobra,
          position: station.orientation.inverse(flight.pose.shipPoint(reference.systemPoint(point)) - station.position),
          hostile: false)
        body.orientation = reference.orientation.relative(to: flight.pose.orientation)
          .relative(to: station.orientation)
        body.energy = try NativeC03EvacuationProfile.initialHullEnergy(role)
        body.missiles = 0
        body.ecmEnabled = false
        body.rotation = 0
        body.rotationRate = 0
        body.missionInstanceID = instance.id
        body.missionActorID = logical
        body.scriptNPC = .init(fit: .init(definition: profile,
          models: [NativeC03EvacuationProfile.model(role): hull.geometry]),
          fuel: 0, guns: [:], components: [:])
        prepared[target] = .init(identity: logical, alias: target, body: body, presence: .prepared)
      }
    }
    let retention: ScriptOwnedEncounter
    var projections: [UUID: NativeC03EvacuationAdmissionContext.Projection] = [:]
    if initial {
      retention = .init(id: declaration.id, galaxy: declaration.galaxy,
        system: declaration.system, actors: prepared)
    } else {
      guard let owned = instance.ownedEncounters[NativeC03CrewSourceState.encounter] else {
        throw SaveError.invalidCommander
      }
      retention = owned
      for actor in owned.actors.values where [.outside, .unloaded].contains(actor.presence) {
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
        projections[actor.identity] = .init(body: body, historicalPhysical: physical)
      }
    }
    return .init(pin: pin, initial: initial, previousCustody: custody, originalSource: source,
      accommodation: accommodation, heldRegister: held, flight: flight, station: station,
      anchors: anchors, reference: reference, retention: retention, declaration: declaration,
      designs: designs, previousGeometry: previousGeometry, geometry: geometry,
      projections: projections, epoch: nativeStationRuntimeEpoch)
  }

  func acceptsHollowManifestEvacuationAdmissionContext(_ context: NativeC03EvacuationAdmissionContext) -> Bool {
    guard !docked, systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      acceptsHollowManifestInstalledCase(context.pin),
      withReadOnlyCommander({ $0.nativePeople == context.previousCustody }),
      withReadOnlyCommander({ $0.flightSimulation == context.flight }),
      withReadOnlyScriptState({ $0.geometry == context.previousGeometry }),
      nativeStationRuntimeEpoch == context.epoch, scriptAnchor == context.station,
      hollowManifestMission?.ownedEncounters[NativeC03CrewSourceState.encounter] == context.installedEncounter
    else { return false }
    if context.initial {
      guard !paused, screen.isFlight, energy.isFinite, energy > 0, !playerEMPDisabled,
        jumpCountdown == nil, pendingNativeStationDock == nil,
        let held = try? hollowManifestHeldRegisterData(),
        held.kit == context.heldRegister?.kit, held.transfer == context.heldRegister?.transfer,
        held.contents == context.heldRegister?.contents
      else { return false }
    }
    return true
  }

  /// New authored free-flight placement for the already departed launch. This is not a
  /// carrier departure port, docking corridor, obstacle clearance or arrival certificate.
  private static func c03EvacuationReference(_ anchors: SystemAnchors) throws -> ShipPose {
    guard anchors.system == NativeHollowManifestDefinition.carrierWorld,
      anchors.station.position.finite, anchors.planet.position.finite
    else { throw SaveError.invalidCommander }
    let delta = anchors.station.position - anchors.planet.position
    guard delta.length.isFinite, delta.length > 1e-6 else { throw SaveError.invalidCommander }
    let normal = delta.unit
    var axis = Vector3(1, 0, 0)
    for candidate in [Vector3(0, 1, 0), Vector3(0, 0, 1)] {
      if abs(candidate.dot(normal)) < abs(axis.dot(normal)) { axis = candidate }
    }
    let across = axis.cross(normal).unit
    var basis = Basis3()
    basis.x = across
    basis.z = normal * -1
    basis.y = basis.z.cross(basis.x)
    let point = anchors.station.position + normal * 12000 + across * 6000
    guard point.finite, point.length.isFinite, basis.validRotation else { throw SaveError.invalidCommander }
    return .init(position: point, orientation: basis)
  }
}
