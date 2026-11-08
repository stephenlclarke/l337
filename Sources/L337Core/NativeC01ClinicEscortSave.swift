import Foundation

enum NativeC01ClinicEscortSave {
  static func decodeClosed(_ data: Data) throws -> NativeC01ClinicEscortState {
    guard data.count <= 1_048_576 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    let state = try JSONDecoder().decode(NativeC01ClinicEscortState.self, from: data)
    guard shapeValid(state),
      let source = try JSONSerialization.jsonObject(with: data) as? NSDictionary,
      source.isEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)))
    else { throw SaveError.invalidCommander }
    return state
  }

  static func shapeValid(_ state: borrowing NativeC01ClinicEscortState) -> Bool {
    let birth = state.birth
    guard state.source.valid, birth.units.count == 2,
      birth.units.map(\.ordinal) == [0, 1],
      Set(birth.units.map(\.registeredHull)).count == 2,
      Set(birth.units.map(\.pilot)).count == 2,
      birth.units.allSatisfy({ $0.pilot.nativeID != nil }),
      birth.cradle.position == state.source.position,
      birth.cradle.orientation == Basis3(), birth.reference == state.source.reference,
      birth.physicalTime == state.source.physicalTime,
      state.launches.count <= NativeC01ClinicEscort.maximumLaunches,
      state.parkedLosses.count <= NativeC01ClinicEscort.maximumLaunches,
      Set(state.launches.map(\.ordinal)).count == state.launches.count,
      Set(state.parkedLosses.map(\.ordinal)).count == state.parkedLosses.count,
      Set(state.launches.map(\.registeredHull)).count == state.launches.count,
      Set(state.launches.map(\.pilot)).count == state.launches.count,
      Set(state.launches.map(\.sourceReceipt)).count == state.launches.count,
      Set(state.launches.map(\.operation)).count == state.launches.count
    else { return false }
    var spent: Set<Int> = []
    for loss in state.parkedLosses {
      guard loss.launch == nil, lossValid(loss, source: state.source, birth: birth),
        spent.insert(loss.ordinal).inserted,
        !state.launches.contains(where: { $0.ordinal == loss.ordinal })
      else { return false }
    }
    var previous = birth.physicalTime
    for (index, launch) in state.launches.enumerated() {
      guard let unit = birth.unit(launch.ordinal), !spent.contains(launch.ordinal),
        unit.registeredHull == launch.registeredHull, unit.pilot == launch.pilot,
        launch.nativeActor.system == NativeC01ClinicEscort.location,
        launch.nativeActor.visit >= state.source.visit, launch.nativeActor.entity > 1,
        launch.berth.position.finite, launch.berth.orientation.validRotation,
        launch.reference.position.finite, launch.reference.orientation.validRotation,
        launch.physicalTime.isFinite, launch.physicalTime >= previous,
        launch.physicalTime <= 1e12,
        launch.operation == (try? NativeC01ClinicEscort.launchOperation(
          source: state.source, reservation: launch.sourceReceipt, hull: launch.registeredHull,
          pilot: launch.pilot, ordinal: launch.ordinal, berth: launch.berth,
          reference: launch.reference))
      else { return false }
      // Unit1 can be the FIRST chronological launch after a genuine parked unit0 loss.
      if index == 0 && launch.ordinal == 1 {
        guard let frontLoss = state.parkedLosses.first(where: { $0.ordinal == 0 }),
          frontLoss.physicalTime <= launch.physicalTime
        else { return false }
      }
      if let loss = launch.loss {
        guard loss.ordinal == launch.ordinal, loss.launch == launch.operation,
          loss.physicalTime >= launch.physicalTime,
          lossValid(loss, source: state.source, birth: birth),
          spent.insert(launch.ordinal).inserted
        else { return false }
        previous = loss.physicalTime
      } else {
        guard index == state.launches.count - 1 else { return false }
        previous = launch.physicalTime
      }
    }
    guard spent.count <= NativeC01ClinicEscort.maximumLaunches else { return false }
    if let arrival = state.arrival {
      guard let launch = state.current, launch.loss == nil,
        arrival.sequence > 0, arrival.sequence < UInt64(Int64.max),
        arrival.launch == launch.operation, arrival.registeredHull == launch.registeredHull,
        arrival.pilot == launch.pilot, arrival.station == state.source.station,
        arrival.actor.system == NativeC01ClinicEscort.location,
        arrival.actor.visit >= launch.nativeActor.visit, arrival.actor.entity > 1,
        arrival.stationActor.system == arrival.actor.system,
        arrival.stationActor.visit == arrival.actor.visit, arrival.stationActor.entity == 1,
        arrival.startTime.isFinite, arrival.physicalTime.isFinite,
        arrival.startTime >= launch.physicalTime, arrival.physicalTime > arrival.startTime,
        arrival.physicalTime <= 1e12,
        arrival.physicalTime - arrival.startTime <= NativeC01LaneRepair.maximumPhysicalInterval,
        NativeArkDockCrossing.admits(from: arrival.from, to: arrival.to,
          stationFrom: arrival.stationFrom, stationTo: arrival.stationTo,
          delta: arrival.physicalTime - arrival.startTime),
        arrival.operation == (try? arrivalOperation(source: state.source, arrival: arrival))
      else { return false }
    }
    return true
  }

  private static func lossValid(_ loss: NativeC01ClinicHullLoss,
    source: NativeC01ClinicEscortSource, birth: NativeC01ClinicStockBirth) -> Bool
  {
    guard birth.unit(loss.ordinal) != nil,
      loss.physicalTime.isFinite, loss.physicalTime >= birth.physicalTime,
      loss.physicalTime <= 1e12, loss.actor.presence == .destroyed, loss.actor.body.energy == 0,
      NativeC01ClinicEscort.original(loss.actor, source: source, ordinal: loss.ordinal),
      let physical = loss.actor.body.physical,
      NativeC01ClinicEscort.nativeValid(physical, cradle: false),
      physical.identity.visit >= source.visit,
      let incident = physical.deathIncidentID, incident > 0,
      loss.operation == lossOperation(source: source, birth: birth, loss: loss)
    else { return false }
    // Presence of an attacker is not required: native environmental deaths have nil origin.
    return true
  }

  static func lossOperation(source: NativeC01ClinicEscortSource,
    birth: NativeC01ClinicStockBirth, loss: NativeC01ClinicHullLoss) -> UUID
  {
    lossOperation(source: source, birth: birth, ordinal: loss.ordinal, launch: loss.launch,
      disposition: loss.sourceDisposition, actor: loss.actor, physicalTime: loss.physicalTime)
  }

  static func lossOperation(source: NativeC01ClinicEscortSource, birth: NativeC01ClinicStockBirth,
    ordinal: Int, launch: UUID?, disposition: UUID, actor: ScriptOwnedActor,
    physicalTime: Double) -> UUID
  {
    ScriptIdentity.uuid(
      "c01-clinic-loss-v1:\(source.mission):\(birth.registration):\(ordinal):\(launch?.uuidString ?? "parked"):\(disposition):\(actor.identity):\(actor.body.physical?.deathIncidentID ?? 0):\(physicalTime.bitPattern)")
  }

  static func arrivalOperation(source: NativeC01ClinicEscortSource,
    arrival: NativeC01ClinicArrival) throws -> UUID
  {
    try arrivalOperation(source: source, launch: arrival.launch,
      reception: arrival.sourceReception, actor: arrival.actor, stationActor: arrival.stationActor,
      startTime: arrival.startTime, physicalTime: arrival.physicalTime,
      poses: [arrival.from, arrival.to, arrival.stationFrom, arrival.stationTo])
  }

  static func arrivalOperation(source: NativeC01ClinicEscortSource, launch: UUID,
    reception: UUID, actor: ActorIdentity, stationActor: ActorIdentity,
    startTime: Double, physicalTime: Double, poses: [ShipPose]) throws -> UUID
  {
    ScriptIdentity.uuid(
      "c01-clinic-arrival-v1:\(source.mission):\(source.permission):\(source.installation):\(launch):\(reception):\(actor):\(stationActor):\(startTime.bitPattern):\(physicalTime.bitPattern):\(try NativeFlightReception.hash(poses))")
  }

  static func historyJoins(
    _ state: borrowing NativeC01ClinicEscortState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard shapeValid(state), mission.id == state.source.mission,
      mission.definition == NativeGlassMeridian.stateID, mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version,
      mission.outcome == .active || mission.outcome == .complete,
      let opening = mission.savedGlassMeridian,
      opening.permission.operation == state.source.permission,
      opening.permission.owner == state.source.owner, commander.equipmentOwnerID == state.source.owner,
      let lane = opening.laneRepair, NativeC01LaneRepairSave.shapeValid(lane),
      lane.installation?.operation == state.source.installation,
      opening.timingStandard?.used == lane.installation,
      opening.timingStandard?.loss == nil,
      opening.surveyor?.capture?.operation == state.source.recorder,
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening),
      NativeC01SurveyorSave.valid(mission, commander: commander),
      NativeC01ReservationAuditSave.valid(mission, commander: commander),
      let standard = opening.timingStandard,
      NativeC01TimingStandardSave.valid(standard, mission: mission, commander: commander),
      state.source.physicalTime >= (lane.installation?.physicalTime ?? .infinity),
      state.source.physicalTime <= commander.flightSimulation.physicalTime,
      state.source.visit >= lane.source.visit,
      state.source.visit <= commander.flightSimulation.visit,
      commander.nativeStations?.mainStations.contains(state.source.station) == true
    else { return false }
    let physicalTime = commander.flightSimulation.physicalTime
    let nextIncident = commander.flightSimulation.nextIncident
    for launch in state.launches {
      guard launch.physicalTime <= physicalTime,
        launch.nativeActor.visit <= commander.flightSimulation.visit,
        launch.nativeActor.entity < commander.flightSimulation.nextActor
      else { return false }
      if let loss = launch.loss {
        guard loss.physicalTime <= physicalTime,
          let incident = loss.actor.body.physical?.deathIncidentID, incident < nextIncident
        else { return false }
      }
    }
    for loss in state.parkedLosses {
      guard loss.physicalTime <= physicalTime,
        let incident = loss.actor.body.physical?.deathIncidentID, incident < nextIncident
      else { return false }
    }
    if let arrival = state.arrival {
      guard arrival.physicalTime <= commander.flightSimulation.physicalTime,
        arrival.actor.visit <= commander.flightSimulation.visit,
        arrival.actor.entity < commander.flightSimulation.nextActor,
        arrival.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(arrival.sequence),
        mission.receipts.contains(NativeC01ClinicEscort.receipt),
        mission.milestones == NativeC01Completion.milestones(opening)
      else { return false }
    } else {
      guard !mission.receipts.contains(NativeC01ClinicEscort.receipt),
        mission.milestones == [0, 1, 2, 3, 4, 5]
      else { return false }
    }
    return true
  }

  /// Current persisted physics/mission joins. The native people owner supplies its
  /// separate bounded reciprocal sourceClaimsMatch check at the final save seam.
  static func physicalClaimsMatch(
    _ state: borrowing NativeC01ClinicEscortState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard historyJoins(state, mission: mission, commander: commander),
      let group = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter],
      group.valid, group.admitted, group.galaxy == 0, group.system == 91,
      Set(group.actors.keys) == [NativeC01ClinicEscort.cradleTarget,
        NativeC01ClinicEscort.stockTarget(0), NativeC01ClinicEscort.stockTarget(1)]
    else { return false }
    var identities: Set<ActorIdentity> = []
    for alias in [NativeC01ClinicEscort.cradleTarget,
      NativeC01ClinicEscort.stockTarget(0), NativeC01ClinicEscort.stockTarget(1)]
    {
      let ordinal = NativeC01ClinicEscort.stockOrdinal(alias: alias)
      guard let actor = group.actors[alias],
        NativeC01ClinicEscort.original(actor, source: state.source, ordinal: ordinal),
        let physical = actor.body.physical,
        NativeC01ClinicEscort.nativeValid(physical, cradle: ordinal == nil),
        identities.insert(physical.identity).inserted,
        physical.identity.visit >= state.source.visit,
        physical.identity.visit <= commander.flightSimulation.visit,
        physical.identity.entity < commander.flightSimulation.nextActor,
        (physical.spawnIdentity?.sequence ?? UInt64.max) < commander.flightSimulation.nextSpawn
      else { return false }
      if let ordinal {
        if let loss = state.loss(for: ordinal) {
          guard actor.presence == .destroyed, actor.body.energy == 0,
            actor.identity == loss.actor.identity,
            physical.identity == loss.actor.body.physical?.identity,
            physical.deathIncidentID == loss.actor.body.physical?.deathIncidentID,
            physical.deathOrigin == loss.actor.body.physical?.deathOrigin
          else { return false }
        } else if let arrival = state.arrival,
          state.current?.ordinal == ordinal
        {
          guard actor.presence == .outside, actor.body.energy > 0,
            arrival.actor == physical.identity,
            physical.deathIncidentID == nil, physical.deathOrigin == nil
          else { return false }
        } else {
          guard [.present, .unloaded, .outside].contains(actor.presence), actor.body.energy > 0,
            physical.deathIncidentID == nil, physical.deathOrigin == nil
          else { return false }
        }
      }
    }
    return true
  }

  static func valid(_ state: NativeC01ClinicEscortState, mission: ScriptInstance,
    commander: borrowing Commander) -> Bool
  {
    guard physicalClaimsMatch(state, mission: mission, commander: commander) else { return false }
    return NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission, commander: commander)
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("clinicEscort"), !root.keys.contains("nativeC01ClinicEscort")
    else { throw SaveError.invalidCommander }
    func check(_ object: [String: Any], embedded: Bool) throws {
      let values: [Any]
      if let raw = object["instances"] as? [String: Any], raw.count <= 128 {
        values = Array(raw.values)
      } else if let raw = object["instances"] as? [Any], raw.count <= 256,
        raw.count.isMultiple(of: 2)
      {
        values = stride(from: 1, to: raw.count, by: 2).map { raw[$0] }
      } else if object["instances"] == nil { values = [] }
      else { throw SaveError.invalidCommander }
      for value in values {
        guard let mission = value as? [String: Any], !mission.keys.contains("clinicEscort"),
          !mission.keys.contains("nativeC01ClinicEscort")
        else { throw SaveError.invalidCommander }
        guard let opening = mission["savedGlassMeridian"] as? [String: Any],
          opening.keys.contains("clinicEscort")
        else { continue }
        guard NativeC01ReservationAuditSave.contains(schema), !embedded,
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["digest"] as? String == NativeGlassMeridian.digest,
          mission["version"] as? String == NativeGlassMeridian.version,
          let leaf = opening["clinicEscort"] as? [String: Any],
          NativeGlassMeridianSave.boundedFields(opening)
        else { throw SaveError.invalidCommander }
        _ = try decodeClosed(JSONSerialization.data(withJSONObject: leaf))
      }
    }
    try check(root, embedded: part != .missions)
    if let embedded = root["savedScriptState"] as? [String: Any] {
      try check(embedded, embedded: true)
    }
  }
}
