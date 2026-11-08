import Foundation

extension Game {
  /// Current mission/physical context only. The native producer owns registration,
  /// fixed stock and people; observing this context creates none of those records.
  func c01ClinicSourceContext() -> NativeC01ClinicEscortSource? {
    guard !docked, !paused, screen.isFlight, energy > 0,
      systemIdentity == NativeC01ClinicEscort.location,
      let mission = glassMeridianMission, mission.outcome == .active, mission.suspension == nil,
      mission.milestones == [0, 1, 2, 3, 4, 5],
      let opening = mission.savedGlassMeridian,
      let installation = opening.laneRepair?.installation,
      opening.timingStandard?.used == installation, opening.timingStandard?.loss == nil,
      opening.surveyor?.held == true, let recorder = opening.surveyor?.capture,
      let owner = commander.equipmentOwnerID, owner == opening.permission.owner,
      glassMeridianPack != nil, let anchor = scriptAnchor,
      let anchors = commander.flightSimulation.anchors,
      case .living(let station) = nativeOriginalMainStationDestination,
      station.identity.world == owner, station.identity.system == systemIdentity
    else { return nil }
    if let existing = opening.clinicEscort {
      guard existing.arrival == nil,
        NativeC01ClinicEscortSave.historyJoins(existing, mission: mission, commander: commander)
      else { return nil }
      return existing.source
    }
    let pose = commander.flightSimulation.pose
    let source = NativeC01ClinicEscortSource(
      mission: mission.id, permission: opening.permission.operation, owner: owner,
      installation: installation.operation, recorder: recorder.operation,
      station: station.identity, anchors: anchors,
      reference: .init(position: pose.systemPoint(anchor.position),
        orientation: anchor.orientation.transformed(by: pose.orientation)),
      visit: commander.flightSimulation.visit,
      physicalTime: commander.flightSimulation.physicalTime)
    return source.valid ? source : nil
  }

  /// The caller operates on the existing publisher's candidate Game. Refusal restores
  /// provisional mission/geometry, so another candidate change cannot publish empty stock.
  mutating func prepareC01ClinicSource() throws -> Bool {
    guard let source = c01ClinicSourceContext(),
      var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      opening.clinicEscort == nil,
      mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] == nil,
      mission.revision < UInt64(Int64.max) - 1, let pack = glassMeridianPack
    else { return false }
    let intent = try prepareC01ClinicSourceIntent(source)
    let previousMission = mission
    let previousGeometry = commander.scriptState.geometry
    var committed = false
    defer {
      if !committed {
        commander.scriptState.instances[previousMission.id] = previousMission
        commander.scriptState.geometry = previousGeometry
      }
    }
    let state = NativeC01ClinicEscortState(source: source, birth: intent.birth)
    guard NativeC01ClinicEscortSave.shapeValid(state) else { throw SaveError.invalidCommander }
    opening.clinicEscort = state
    mission.savedGlassMeridian = opening
    mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] =
      try NativeC01ClinicEscort.preparedEncounter(source: source, birth: intent.birth)
    mission.revision += 1
    commander.scriptState.instances[mission.id] = mission
    for design in NativeC01ClinicEscort.designs(mission).values {
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      commander.scriptState.geometry[hash] = design
    }
    guard let cohort = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] else {
      throw NativeMissionActorAdmissionError.invalidTemplate
    }
    let sourceAdmission = try c01ClinicSourceAdmissionSource(
      pack: pack, state: mission, encounter: cohort)
    switch try prepareMissionActorAdmission(sourceAdmission) {
    case .pending: return false
    case .unchanged: throw NativeMissionActorAdmissionError.invalidTemplate
    case .ready(let admission):
      let capsule = try prepareC01ClinicSourceAdmission(intent, admission: admission)
      _ = try commitC01ClinicSourceAdmission(capsule)
      committed = true
      return true
    }
  }

  func c01ClinicStockCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let ordinal = c01ClinicStockOrdinal(body),
      let state = glassMeridianMission?.savedGlassMeridian?.clinicEscort,
      let unit = state.birth.unit(ordinal),
      let facts = commander.c01ClinicStockPilotFacts(ordinal: ordinal),
      facts.pilot == unit.pilot, facts.registeredHull == unit.registeredHull,
      facts.actor == body.missionActorID, facts.intrinsicPlace == 0,
      facts.mass.valid, facts.massKilograms == 80, facts.loadedMassKilograms == 25625,
      let original = try? NativeC01SurveyorGeometry.harrier.get()
    else { return nil }
    // Each real source hull has its own collider. Never add these people/hulls to cradle mass.
    return (original.collision, facts.loadedMassKilograms)
  }

  func c01ClinicCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    c01ClinicCradleCollision(body) ?? c01ClinicStockCollision(body)
  }

  func c01ClinicCradleCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard c01ClinicCradleActor(body) != nil,
      let source = try? NativeC01ClinicCradle.original.get()
    else { return nil }
    return (source.nativeDesign.rawMesh, source.massKilograms)
  }
}

extension Game {
  /// Prepare every mission edit before committing native source custody. After that
  /// commit, only direct installation of these already-validated values remains.
  mutating func recordC01ClinicLosses() throws -> Bool {
    let pending = c01ClinicEscortRuntime.pendingDeaths
    var changed = false
    for transition in pending {
      guard var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
        var state = opening.clinicEscort, state.loss(for: transition.ordinal) == nil,
        mission.revision < UInt64(Int64.max) - 1,
        let witness = c01ClinicPilotLossWitness(transition),
        witness.actor == transition.actor, witness.physicalTime == transition.physicalTime
      else { continue }
      let disposition = try prepareC01ClinicPilotLoss(witness)
      let launch = state.launch(for: transition.ordinal)
      let operation = NativeC01ClinicEscortSave.lossOperation(source: state.source,
        birth: state.birth, ordinal: transition.ordinal, launch: launch?.operation,
        disposition: disposition.operation, actor: witness.actor, physicalTime: witness.physicalTime)
      let loss = NativeC01ClinicHullLoss(ordinal: transition.ordinal, launch: launch?.operation,
        operation: operation, sourceDisposition: disposition.operation,
        actor: witness.actor, physicalTime: witness.physicalTime)
      if let launch {
        guard let index = state.launches.firstIndex(where: { $0.operation == launch.operation }),
          state.launches[index].loss == nil
        else { throw SaveError.invalidCommander }
        state.launches[index].loss = loss
      } else {
        guard state.parkedLosses.count < NativeC01ClinicEscort.maximumLaunches else {
          throw SaveError.invalidCommander
        }
        state.parkedLosses.append(loss)
      }
      guard NativeC01ClinicEscortSave.shapeValid(state) else { throw SaveError.invalidCommander }
      opening.clinicEscort = state
      mission.savedGlassMeridian = opening
      mission.revision += 1
      mission.journal.append("An actual clinic source Harrier was destroyed. Its registered hull and native crew casualty are recorded; no replacement was created and no escort arrival was granted.")
      let postSequence = try NativeC01CompletionSave.recordPostTerminalLoss(
        loss, mission: &mission, commander: commander)
      guard NativeC01ClinicEscortSave.physicalClaimsMatch(state,
        mission: mission, commander: commander)
      else { throw SaveError.invalidCommander }
      try commitC01ClinicPeopleDisposition(disposition)
      commander.scriptState.instances[mission.id] = mission
      if let postSequence { commander.scriptState.nextEvent = postSequence }
      c01ClinicEscortRuntime.pendingDeaths.removeAll { $0.ordinal == transition.ordinal }
      changed = true
    }
    return changed
  }

  mutating func applyC01ClinicArrival(_ witness: NativeC01ClinicArrivalWitness) throws -> Bool {
    guard var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      var state = opening.clinicEscort, state.arrival == nil, state.source == witness.source,
      state.current == witness.launch, witness.launch.loss == nil,
      witness.epoch == nativeStationRuntimeEpoch,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let actor = c01ClinicTenderActor(launch: witness.launch), actor == witness.actor,
      let physical = actor.body.physical,
      let index = bodies.firstIndex(where: {
        $0.id == actor.body.id && $0.physical?.identity == physical.identity
      }), let anchor = scriptAnchor,
      var group = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter],
      let original = group.actors[NativeC01ClinicEscort.stockTarget(witness.launch.ordinal)],
      original.identity == actor.identity
    else { return false }
    // Keep the actual current receiving body present until MC1's currentness check commits.
    let disposition = try prepareC01ClinicPilotReception(witness)
    let sequence = commander.scriptState.nextEvent + 1
    let operation = try NativeC01ClinicEscortSave.arrivalOperation(source: state.source,
      launch: witness.launch.operation, reception: disposition.operation,
      actor: physical.identity, stationActor: witness.stationActor,
      startTime: witness.startTime, physicalTime: witness.physicalTime,
      poses: [witness.from, witness.to, witness.stationFrom, witness.stationTo])
    state.arrival = .init(operation: operation, sequence: sequence,
      launch: witness.launch.operation, registeredHull: witness.launch.registeredHull,
      pilot: witness.launch.pilot, sourceReception: disposition.operation,
      actor: physical.identity, station: state.source.station, stationActor: witness.stationActor,
      from: witness.from, to: witness.to, stationFrom: witness.stationFrom,
      stationTo: witness.stationTo, startTime: witness.startTime, physicalTime: witness.physicalTime)
    var received = actor
    received.body.position = anchor.orientation.inverse(actor.body.position - anchor.position)
    received.body.orientation = actor.body.orientation.relative(to: anchor.orientation)
    received.body.scriptNPC?.velocity = anchor.orientation.inverse(
      actor.body.scriptNPC?.velocity ?? .init(0, 0, 0))
    received.presence = .outside
    group.actors[received.alias] = received
    opening.clinicEscort = state
    mission.savedGlassMeridian = opening
    mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] = group
    mission.milestones.insert(6)
    mission.receipts.formUnion([
      NativeC01ClinicEscort.receipt, "escort-clinic", NativeC01ClinicEscort.target,
    ])
    mission.acknowledge(sequence)
    mission.revision += 1
    mission.journal.append("Lareria main station accepted the same registered clinic tender through its actual native berth. Its living source pilot is received. The original recorder remains aboard and the same timing standard remains installed. Next: Avenor evidence contact. No payment or final clue.")
    do {
      var prospective = commander
      prospective.scriptState.instances[mission.id] = mission
      prospective.scriptState.nextEvent = sequence
      guard NativeC01ClinicEscortSave.physicalClaimsMatch(state,
        mission: mission, commander: prospective)
      else { throw SaveError.invalidCommander }
    }
    let clearSelectedTarget = weaponsTargetID == actor.body.id
    try commitC01ClinicPeopleDisposition(disposition)
    // No lookup, validation, source mutation or throwing work follows this boundary.
    commander.scriptState.instances[mission.id] = mission
    commander.scriptState.nextEvent = sequence
    bodies.remove(at: index)
    if clearSelectedTarget { weaponsTargetID = nil }
    c01ClinicEscortRuntime.review = nil
    c01ClinicEscortRuntime.reason = "LARERIA ACCEPTED THE SAME TENDER AND PILOT - ESCORT COMPLETE"
    return true
  }
}

extension GameRuntime {
  func commitC01ClinicEscort() {
    guard game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.installation != nil,
      let publish = scriptPublisher()
    else { return }
    var candidate = game
    do {
      let loss = try candidate.recordC01ClinicLosses()
      var arrival = false
      if let sample = candidate.c01ClinicEscortRuntime.attainedSample,
        let witness = candidate.c01ClinicArrivalWitness(from: sample)
      {
        arrival = try candidate.applyC01ClinicArrival(witness)
      }
      let source = try candidate.prepareC01ClinicSource()
      guard loss || arrival || source else { return }
      try publish(&candidate)
      game = candidate
      if arrival { game.notify("CLINIC TENDER AND PILOT ACCEPTED BY LARERIA MAIN STATION") }
    } catch {
      // Actual native destruction remains observed in the running game. Its transient
      // evidence retries; failed reception must attain a new real inward crossing.
      game.notify("CLINIC UPDATE NOT SAVED - SOURCE CUSTODY AND MISSION RECEIPTS RETAINED")
    }
  }
}
