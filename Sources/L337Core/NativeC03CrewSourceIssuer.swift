import Foundation

/// Unpublished scratch for the real sealed native admission adapter. Calling this reducer
/// cannot commit an allocator, install a source or issue a person. The adapter must validate
/// the full staged Commander and native fitting/mass policy, then publish all owners together.
struct NativeC03CrewSourcePreparation: Sendable {
  let state: NativeHollowManifestState
  let encounter: ScriptOwnedEncounter
  let custody: NativePeopleCustodyState
}

extension Game {
  /// The sealed admission owner calls this only AFTER its real physical policy has accepted
  /// the complete paired cohort and occupied fitting. This stages reciprocal saved owners;
  /// it supplies no physical qualification, live allocator commit or authority factory.
  @inline(never)
  func prepareC03EvacuationCrewSource(
    context: NativeC03EvacuationAdmissionContext, admitted: [SpaceBody],
    flight: FlightSimulationState
  ) throws -> NativeC03CrewSourcePreparation {
    guard acceptsHollowManifestEvacuationAdmissionContext(context),
      let previous = hollowManifestMission, previous.id == context.pin.missionID,
      previous.savedHollowManifest == context.pin.state,
      previous.ownedEncounters[NativeC03CrewSourceState.encounter] == context.installedEncounter
    else { throw NativeMissionActorAdmissionError.stalePlan }
    let prepared = try NativeC03CrewSourceState.preparingAdmission(
      context: context, admitted: admitted, flight: flight)
    var selected = previous
    selected.savedHollowManifest = prepared.state
    selected.ownedEncounters[NativeC03CrewSourceState.encounter] = prepared.encounter
    var candidate = commander
    candidate.flightSimulation = flight
    candidate.savedNativePeopleCustody = prepared.custody
    candidate.scriptState.geometry = context.geometry
    candidate.scriptState.instances[selected.id] = selected
    guard prepared.state.preservesHistory(of: context.pin.state),
      prepared.encounter.valid,
      NativeHollowManifestCommission.prefixValid(selected),
      NativeC03CrewSourceSave.validSource(
        prepared.custody.hollowManifestCrew, custody: prepared.custody, commander: candidate),
      NativeHollowManifestSave.validateClaims(candidate), candidate.nativePeopleStateValid,
      candidate.valid, acceptsHollowManifestEvacuationAdmissionContext(context)
    else { throw SaveError.invalidCommander }
    return prepared
  }
}

extension NativeC03CrewSourceState {
  static func preparingAdmission(
    context: NativeC03EvacuationAdmissionContext, admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> NativeC03CrewSourcePreparation {
    guard !admitted.isEmpty, admitted.count <= 2,
      context.initial ? admitted.count == 2 : true,
      context.flight.nextActor < UInt64.max - UInt64(admitted.count),
      context.flight.nextSpawn < UInt64.max - 1,
      flight.nextActor == context.flight.nextActor + UInt64(admitted.count),
      flight.nextSpawn == context.flight.nextSpawn + 1,
      flight.system == context.flight.system, flight.visit == context.flight.visit,
      flight.pose == context.flight.pose, flight.physicalTime == context.flight.physicalTime,
      Set(admitted.compactMap(\.missionActorID)).count == admitted.count
    else { throw SaveError.invalidCommander }
    var encounter = context.retention
    var bindings = context.originalSource?.nativeBindings ?? []
    for (index, body) in admitted.enumerated() {
      guard let logical = body.missionActorID, let role = context.role(of: logical),
        let physical = body.physical, let spawn = physical.spawnIdentity,
        physical.identity.system == flight.system, physical.identity.visit == flight.visit,
        physical.identity.entity == context.flight.nextActor + UInt64(index),
        spawn.system == flight.system, spawn.visit == flight.visit,
        spawn.sequence == context.flight.nextSpawn, spawn.member == UInt16(index),
        spawn.producer == .mission, body.missionInstanceID == context.pin.missionID,
        let hull = try? NativeC03EvacuationHull.resolve(role),
        physical.catalogueShipID == hull.source.current.id,
        let npc = body.scriptNPC, npc.valid,
        npc.fit.definition == (try? NativeC03EvacuationProfile.definition(role)),
        npc.fit.models == [NativeC03EvacuationProfile.model(role): hull.geometry]
      else { throw SaveError.invalidCommander }
      let target = role == .launch ? launchTarget : carrierTarget
      guard var actor = encounter.actors[target], actor.identity == logical,
        context.initial ? actor.presence == .prepared : [.outside, .unloaded].contains(actor.presence)
      else { throw SaveError.invalidCommander }
      let expected = context.projections[logical]?.body ?? actor.body
      let position = context.station.position + context.station.orientation.apply(expected.position)
      let orientation = expected.orientation.transformed(by: context.station.orientation)
      guard (body.position - position).length <= 1e-7,
        (body.orientation.x - orientation.x).length <= 1e-9,
        (body.orientation.y - orientation.y).length <= 1e-9,
        (body.orientation.z - orientation.z).length <= 1e-9,
        body.energy == expected.energy, body.rotation == expected.rotation,
        body.rotationRate == expected.rotationRate,
        npc.fit == expected.scriptNPC?.fit, npc.fuel == expected.scriptNPC?.fuel,
        npc.guns == expected.scriptNPC?.guns, npc.components == expected.scriptNPC?.components,
        npc.shots == expected.scriptNPC?.shots, npc.intent == expected.scriptNPC?.intent
      else { throw SaveError.invalidCommander }
      if context.initial {
        let proposed = try NativeC03EvacuationProfile.initialNativeCondition(role)
        guard physical.npc == proposed,
          physical.velocity == Vector3(0, 0, 0), physical.angularVelocity == Vector3(0, 0, 0),
          physical.laserCooldown == 0, physical.deathIncidentID == nil, physical.deathOrigin == nil
        else { throw SaveError.invalidCommander }
      } else {
        guard let old = context.projections[logical]?.historicalPhysical,
          physical.velocity == old.velocity, physical.angularVelocity == old.angularVelocity,
          physical.laserCooldown == old.laserCooldown, physical.canonicalSpin == old.canonicalSpin,
          physical.catalogueShipID == old.catalogueShipID,
          preservesNPCCondition(physical.npc, old.npc)
        else { throw SaveError.invalidCommander }
      }
      actor.body = try captureEvacuationBody(body, reference: context.reference, flight: flight)
      actor.presence = .present
      encounter.actors[target] = actor
      let previousBinding = bindings.first { $0.launch == (role == .launch) }
      guard (previousBinding?.generation ?? 0) < UInt64(Int64.max) - 1 else {
        throw SaveError.invalidCommander
      }
      if let previousBinding {
        guard physical.identity.entity > previousBinding.actor.entity,
          spawn.sequence > previousBinding.spawn.sequence,
          flight.physicalTime >= previousBinding.physicalTime
        else { throw SaveError.invalidCommander }
      }
      bindings.removeAll { $0.launch == (role == .launch) }
      bindings.append(.init(launch: role == .launch,
        generation: (previousBinding?.generation ?? 0) + 1,
        actor: physical.identity, spawn: spawn, selectedOrdinal: UInt16(index),
        cohortCount: UInt16(admitted.count), cohortFirstEntity: context.flight.nextActor,
        physicalTime: flight.physicalTime))
    }
    bindings.sort { ($0.launch ? 1 : 0) < ($1.launch ? 1 : 0) }
    encounter.admitted = true
    var custody = context.previousCustody ?? .init(owner: context.pin.owner)
    guard custody.owner == context.pin.owner else { throw SaveError.invalidCommander }
    let state: NativeHollowManifestState
    if context.initial {
      guard custody.hollowManifestCrew == nil, context.pin.state.crewSource == nil,
        let held = context.heldRegister,
        let carrier = encounter.actors[carrierTarget]?.body,
        let launch = encounter.actors[launchTarget]?.body,
        let carrierPhysical = carrier.physical, let launchPhysical = launch.physical,
        let carrierSpawn = carrierPhysical.spawnIdentity, let launchSpawn = launchPhysical.spawnIdentity,
        carrierSpawn.member == 0, launchSpawn.member == 1,
        let carrierGeometry = carrier.scriptNPC?.fit.models[NativeC03EvacuationProfile.model(.carrier)],
        let launchGeometry = launch.scriptNPC?.fit.models[NativeC03EvacuationProfile.model(.launch)]
      else { throw SaveError.invalidCommander }
      let fit = context.accommodation
      let operation = try registrationOperation(source: fit.source,
        carrier: carrierPhysical.identity, launch: launchPhysical.identity, spawn: carrierSpawn)
      let registration = Registration(operation: operation, accommodation: fit,
        caseSourceSequence: context.pin.state.nextSourceSequence, custodyRevision: custody.revision,
        registerTransfer: held.transfer, originalKit: held.kit.serial,
        crewLog: try NativeC03OriginalCrewLogContent.candidate(state: context.pin.state, fit: fit),
        carrier: .init(originalHull: fit.originalCarrier,
          logicalActor: logicalActor(mission: fit.mission, launch: false),
          birthActor: carrierPhysical.identity, birthSpawn: carrierSpawn, rootGeometry: carrierGeometry),
        launch: .init(originalHull: fit.originalLaunch,
          logicalActor: logicalActor(mission: fit.mission, launch: true),
          birthActor: launchPhysical.identity, birthSpawn: launchSpawn, rootGeometry: launchGeometry),
        anchors: context.anchors, reference: context.reference,
        physicalTime: flight.physicalTime, epoch: context.epoch)
      var hardware = fit.emptyHardware
      for index in hardware.ownedBerths.indices {
        hardware.ownedBerths[index].use = .nativePerson(.hollowManifestCrew(fit.assignments[index + 2].person))
      }
      let source = Self(registration: registration, nativeBindings: bindings, hardware: hardware,
        operatingPlaces: fit.assignments.prefix(2).map { .init(index: $0.ordinal, person: $0.person) },
        crewLogHolder: .originalLaunch, crewLogAccess: nil,
        loss: nil)
      guard NativeC03CrewSourceSave.shapeValid(source) else { throw SaveError.invalidCommander }
      custody.hollowManifestCrew = source
      state = try context.pin.state.retainingCrewSource(source.missionReference)
    } else {
      guard custody.hollowManifestCrew == context.originalSource,
        var source = context.originalSource,
        context.pin.state.crewSource == source.missionReference
      else { throw SaveError.invalidCommander }
      // Only native incarnation/condition changes. Never recreate people, the fitted module,
      // places, source registration, shared custody revision or an original lost launch.
      source.nativeBindings = bindings
      guard NativeC03CrewSourceSave.shapeValid(source) else { throw SaveError.invalidCommander }
      custody.hollowManifestCrew = source
      state = context.pin.state
    }
    return .init(state: state, encounter: encounter, custody: custody)
  }

  static func captureEvacuationBody(_ body: SpaceBody, reference: ShipPose, flight: FlightSimulationState) throws
    -> SpaceBody
  {
    guard flight.valid, reference.position.finite, reference.orientation.validRotation,
      body.position.finite, body.orientation.validRotation, body.rotation.isFinite,
      body.rotationRate.isFinite, let physical = body.physical, let npc = body.scriptNPC,
      physical.velocity.finite, physical.angularVelocity.finite,
      (flight.pose.orientation.apply(npc.velocity) - physical.velocity).length < 1e-8
    else { throw SaveError.invalidCommander }
    var captured = body
    captured.position = reference.shipPoint(flight.pose.systemPoint(body.position))
    captured.orientation = body.orientation.transformed(by: flight.pose.orientation)
      .relative(to: reference.orientation)
    captured.scriptNPC?.velocity = reference.shipVector(physical.velocity)
    return captured
  }

  private static func preservesNPCCondition(_ new: NPCState?, _ old: NPCState?) -> Bool {
    guard var new, let old else { return new == old }
    // Only the existing native core may sanitize former-visit AI addresses.
    new.firstAggressor = old.firstAggressor
    new.intention = old.intention
    return new == old
  }
}

extension NativeHollowManifestState {
  func retainingCrewSource(_ reference: NativeC03CrewSourceReference) throws -> Self {
    guard shapeValid, phase == .admitted, crewSource == nil,
      custodyRegister?.recovery != nil, reference.sequence == nextSourceSequence,
      nextSourceSequence < UInt64(Int64.max) - 1
    else { throw Failure.invalidState }
    let candidate = Self(birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory,
      wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: reference, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}
