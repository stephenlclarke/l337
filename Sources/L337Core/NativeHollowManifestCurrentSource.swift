import Foundation

extension NativeHollowManifestCommission {
  /// Pure saved-claim consistency. This never constructs an installed pin or grants life.
  /// G2's admitted prefix can consume this only when the complete real producer composes.
  @inline(never)
  static func admittedActorClaimsMatch(_ instance: borrowing ScriptInstance) -> Bool {
    guard let state = instance.savedHollowManifest, state.shapeValid,
      state.phase != .unadmitted, let reference = state.sourceFrame,
      let anchors = state.routeAnchors, state.ownedEncounterID == encounter,
      Set(instance.ownedEncounters.keys) == NativeC03RegisterState.encounterKeys(for: state),
      NativeC03WakeTrail.actorClaimsMatch(instance),
      NativeC03RegisterState.actorClaimsMatch(instance),
      let owned = instance.ownedEncounters[encounter], owned.valid, owned.admitted,
      owned.id == encounter, owned.galaxy == 1, owned.system == 113,
      Set(owned.actors.keys) == Set(NativeHollowManifestState.Slot.allCases.map(\.rawValue)),
      let declarations = try? admissionDeclarations(
        birth: state.birth, anchors: anchors, sourceFrame: reference, encounter: encounter)
    else { return false }
    for slot in NativeHollowManifestState.Slot.allCases {
      guard let actor = owned.actors[slot.rawValue],
        let latest = state.latestAdmissions.first(where: { $0.slot == slot }),
        let admission = state.admissions.first(where: { $0.reference == latest }),
        actor.alias == slot.rawValue,
        actor.identity == logicalActor(mission: instance.id, slot: slot),
        actor.identity == admission.logicalActor, actor.body.missionActorID == actor.identity,
        actor.body.missionInstanceID == instance.id,
        actor.body.hull == .cobra, (1..<1_000_000_000).contains(actor.body.id),
        NativeC03RetainedMotion.retainedConditionShapeValid(actor.body),
        let physical = actor.body.physical, physical.identity == admission.original.actor,
        physical.spawnIdentity == admission.spawn, physical.population == .mission,
        physical.npc?.role == .mission, let resources = physical.npc?.resources, resources.valid,
        resources.profile == .nativeHull, resources.energyCapacity == state.birth.fit.hullEnergy,
        resources.energyRecharge == state.birth.fit.recharge,
        resources.frontCapacity == 0, resources.rearCapacity == 0, resources.shieldRecharge == 0,
        resources.fuel == 0, resources.fuelCapacity == 0,
        actor.body.ecmEnabled == false, actor.body.missiles == 0,
        physical.npc?.hasFuelScoops == false, physical.npc?.ordinaryCargo.isEmpty == true,
        physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
        physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
        physical.velocity.finite, physical.angularVelocity.finite,
        physical.laserCooldown.isFinite, physical.laserCooldown >= 0,
        let npc = actor.body.scriptNPC,
        let profile = declarations.profiles.first(where: { $0.id == npc.fit.definition.id }),
        npc.fit.definition == profile, npc.components.count == 1,
        npc.components[slot.rawValue]?.identity == admission.original.component,
        admission.original.component == component(logicalActor: actor.identity, slot: slot),
        npc.fit.models[rootModel] == admission.geometry.rootGeometryHash,
        npc.fit.models[sealModel] == admission.geometry.sealGeometryHash,
        [.present, .outside, .unloaded, .destroyed].contains(actor.presence)
      else { return false }
      if !state.firstCompromises.contains(where: { $0.admission.slot == slot }) {
        guard npc.components[slot.rawValue]?.energy == state.birth.fit.sealEnergy else {
          return false
        }
      }
      let terminal = state.terminals.contains { $0.effect.admission.slot == slot }
      guard terminal == (actor.presence == .destroyed),
        terminal ? actor.body.energy == 0 : actor.body.energy > 0
      else { return false }
    }
    return true
  }
}

extension Game {
  /// Recognition can refuse stale control only. It cannot authorize a body or source operation.
  func c03RecognizedBodyIDs() -> Set<Int> {
    guard let owner = commander.equipmentOwnerID,
      let instance = commander.scriptState.instances[
        NativeHollowManifestCommission.mission(owner: owner)],
      NativeHollowManifestCommission.marked(instance)
    else { return [] }
    let logical = Set(
      NativeHollowManifestState.Slot.allCases.map {
        NativeHollowManifestCommission.logicalActor(mission: instance.id, slot: $0)
      })
    return Set(
      bodies.lazy.filter {
        $0.missionInstanceID == instance.id && $0.missionActorID.map(logical.contains) == true
      }.map(\.id))
  }

  @inline(never)
  func c03LiveRouteInputs() -> (
    pin: NativeHollowManifestInstalledCase?, recognizedBodyIDs: Set<Int>,
    originals: [(
      slot: NativeHollowManifestState.Slot, owned: ScriptOwnedActor,
      admission: NativeHollowManifestState.Admission, route: NativeHollowManifestState.Route
    )]
  ) {
    let recognized = c03RecognizedBodyIDs()
    do {
      let pin = try hollowManifestInstalledCase()
      guard let instance = withReadOnlyScriptState({ $0.instances[pin.missionID] }),
        NativeHollowManifestCommission.admittedActorClaimsMatch(instance),
        let encounter = withReadOnlyScriptState({ $0.instances[pin.missionID]?
          .ownedEncounters[NativeHollowManifestCommission.encounter] })
      else { return (nil, recognized, []) }
      var inputs:
        [(
          slot: NativeHollowManifestState.Slot, owned: ScriptOwnedActor,
          admission: NativeHollowManifestState.Admission, route: NativeHollowManifestState.Route
        )] = []
      let flight = commander.flightSimulation
      for slot in NativeHollowManifestState.Slot.allCases {
        guard let owned = encounter.actors[slot.rawValue] else { return (nil, recognized, []) }
        if owned.presence != .present
          || pin.state.terminals.contains(where: {
            $0.effect.admission.slot == slot
          })
        {
          continue
        }
        let life = try hollowManifestOriginalLife(slot: slot)
        guard acceptsHollowManifestOriginalLife(life), life.pin.missionID == pin.missionID else {
          return (nil, recognized, [])
        }
        let matches = bodies.filter { $0.missionActorID == owned.identity }
        guard matches.count == 1, let body = matches.first, body.id == owned.body.id,
          body.missionInstanceID == pin.missionID, body.energy > 0,
          NativeHollowManifestCommission.nativeConditionMatches(body, fit: pin.state.birth.fit),
          let physical = body.physical, physical.identity == owned.body.physical?.identity,
          physical.identity.system == flight.system, physical.identity.visit == flight.visit,
          physical.identity.entity < flight.nextActor,
          physical.spawnIdentity == owned.body.physical?.spawnIdentity,
          let spawn = physical.spawnIdentity, spawn.sequence < flight.nextSpawn,
          let latest = pin.state.latestAdmissions.first(where: { $0.slot == slot }),
          let admission = pin.state.admissions.first(where: { $0.reference == latest }),
          admission.original.actor == physical.identity, admission.spawn == spawn,
          let route = pin.state.routes.first(where: { $0.admission == latest }),
          body.scriptNPC?.fit == owned.body.scriptNPC?.fit,
          body.scriptNPC?.components[slot.rawValue]?.identity == admission.original.component
        else { return (nil, recognized, []) }
        inputs.append((slot, owned, admission, route))
      }
      guard inputs.count <= 2, acceptsHollowManifestInstalledCase(pin) else {
        return (nil, recognized, [])
      }
      return (pin, recognized, inputs)
    } catch { return (nil, recognized, []) }
  }

}

extension Game {
  /// Actual installed condition joins for G2's own life/source gate. This proves no person life.
  /// It does not call that gate or any State installer, so owner validation cannot recurse.
  @inline(never)
  func c03OriginalConditionMatches(
    _ pin: NativeHollowManifestInstalledCase,
    slot: NativeHollowManifestState.Slot
  ) -> Bool {
    guard acceptsHollowManifestInstalledCase(pin),
      let instance = withReadOnlyScriptState({ $0.instances[pin.missionID] }),
      pin.state.birth.originals.contains(where: { $0.slot == slot })
    else { return false }
    if pin.state.phase == .unadmitted {
      return instance.ownedEncounters.isEmpty && pin.state.firstAdmissions.isEmpty
        && pin.state.latestAdmissions.isEmpty && pin.state.terminals.isEmpty
        && pin.state.sourceFrame == nil && pin.state.routeAnchors == nil
    }
    guard NativeHollowManifestCommission.admittedActorClaimsMatch(instance),
      !pin.state.terminals.contains(where: { $0.effect.admission.slot == slot }),
      let encounter = instance.ownedEncounters[NativeHollowManifestCommission.encounter],
      let owned = encounter.actors[slot.rawValue],
      let reference = pin.state.sourceFrame,
      let latest = pin.state.latestAdmissions.first(where: { $0.slot == slot }),
      let admission = pin.state.admissions.first(where: { $0.reference == latest })
    else { return false }
    let flight = commander.flightSimulation
    do {
      if owned.presence == .present {
        let matches = bodies.filter { $0.missionActorID == owned.identity }
        guard matches.count == 1, let actual = matches.first, actual.energy > 0,
          NativeHollowManifestCommission.nativeConditionMatches(actual, fit: pin.state.birth.fit)
        else {
          return false
        }
        if !pin.state.firstCompromises.contains(where: { $0.admission.slot == slot }) {
          guard
            actual.scriptNPC?.components[slot.rawValue]?.energy == pin.state.birth.fit.sealEnergy
          else { return false }
        }
        _ = try NativeC03RetainedMotion.capture(
          body: actual, owned: owned,
          original: admission.original, flight: flight, reference: reference)
      } else {
        guard [.outside, .unloaded].contains(owned.presence), let station = scriptAnchor,
          !bodies.contains(where: { $0.missionActorID == owned.identity })
        else { return false }
        _ = try NativeC03RetainedMotion.projectForAdmission(
          owned: owned,
          original: admission.original, reference: reference, flight: flight, station: station)
      }
      return true
    } catch { return false }
  }
}

extension Game {
  /// Physical binding only. Withdrawal, inspection consent and route eligibility are irrelevant.
  /// MC1 must separately authenticate G2's actual life gate and actual native root effect.
  @inline(never)
  func c03CurrentOriginalBinding(
    _ pin: NativeHollowManifestInstalledCase,
    slot: NativeHollowManifestState.Slot
  ) -> (owned: ScriptOwnedActor, admission: NativeHollowManifestState.Admission)? {
    guard c03OriginalConditionMatches(pin, slot: slot),
      let owned = withReadOnlyScriptState({ $0.instances[pin.missionID]?
        .ownedEncounters[NativeHollowManifestCommission.encounter]?.actors[slot.rawValue] }),
      owned.presence == .present,
      let latest = pin.state.latestAdmissions.first(where: { $0.slot == slot }),
      let admission = pin.state.admissions.first(where: { $0.reference == latest })
    else { return nil }
    return (owned, admission)
  }

  /// Prepare condition from the actual effect plan, before physical/source publication.
  /// No life transition or native effect is inferred or installed by this structural capture.
  @inline(never)
  func c03CapturedRootCondition(
    body: SpaceBody, pin: NativeHollowManifestInstalledCase,
    slot: NativeHollowManifestState.Slot, stagedFlight: FlightSimulationState
  ) throws -> ScriptOwnedActor {
    guard let current = c03CurrentOriginalBinding(pin, slot: slot),
      let reference = pin.state.sourceFrame,
      stagedFlight.pose == commander.flightSimulation.pose,
      stagedFlight.system == commander.flightSimulation.system,
      stagedFlight.visit == commander.flightSimulation.visit,
      stagedFlight.physicalTime == commander.flightSimulation.physicalTime,
      stagedFlight.nextActor == commander.flightSimulation.nextActor,
      stagedFlight.nextSpawn == commander.flightSimulation.nextSpawn
    else { throw NativeMissionActorAdmissionError.stalePlan }
    var owned = current.owned
    owned.body = try NativeC03RetainedMotion.capture(
      body: body, owned: owned,
      original: current.admission.original, flight: stagedFlight, reference: reference)
    return owned
  }
}

extension NativeHollowManifestCommission {
  /// Closed fitted capacities; spent hull/component/heat/electrical condition stays untouched.
  static func nativeConditionMatches(
    _ body: borrowing SpaceBody,
    fit: NativeHollowManifestSourceBirth.InspectionFit
  ) -> Bool {
    guard let physical = body.physical, physical.population == .mission,
      physical.npc?.role == .mission, let resources = physical.npc?.resources, resources.valid,
      resources.profile == .nativeHull, resources.energyCapacity == fit.hullEnergy,
      resources.energyRecharge == fit.recharge, resources.frontCapacity == 0,
      resources.rearCapacity == 0, resources.shieldRecharge == 0,
      resources.fuel == 0, resources.fuelCapacity == 0,
      body.missiles == 0, body.ecmEnabled == false,
      physical.npc?.hasFuelScoops == false, physical.npc?.ordinaryCargo.isEmpty == true,
      physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
      physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil
    else { return false }
    return true
  }
}
