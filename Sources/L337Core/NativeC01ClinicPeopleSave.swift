import Foundation

enum NativeC01ClinicPeopleSave {
  static func decodeClosed(_ bytes: Data) throws -> NativeC01ClinicSourceState {
    guard !bytes.isEmpty, bytes.count <= NativeC01ClinicPeople.maximumSourceBytes,
      let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      Set(raw.keys) == ["registration", "assignments", "dispositions"],
      let registration = raw["registration"] as? [String: Any],
      let units = registration["units"] as? [Any], units.count == 2,
      let birth = registration["birth"] as? [String: Any],
      let stock = birth["units"] as? [Any], stock.count == 2,
      let assignments = raw["assignments"] as? [Any], assignments.count <= 2,
      let dispositions = raw["dispositions"] as? [Any], dispositions.count <= 2
    else { throw SaveError.invalidCommander }
    let state = try JSONDecoder().decode(NativeC01ClinicSourceState.self, from: bytes)
    let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    guard (raw as NSDictionary).isEqual(canonical), shapeValid(state) else {
      throw SaveError.invalidCommander
    }
    return state
  }

  static func shapeValid(_ state: borrowing NativeC01ClinicSourceState) -> Bool {
    let registration = state.registration
    let source = registration.source
    guard source.valid,
      source.mission == ScriptIdentity.uuid("glass-meridian-commission-v1:\(source.owner)"),
      registration.operation == NativeC01ClinicPeople.registrationOperation(owner: source.owner),
      registration.facility == NativeC01ClinicPeople.facility(owner: source.owner),
      registration.birth.registration == registration.operation,
      registration.birth.physicalTime == registration.physicalTime,
      registration.birth.physicalTime == source.physicalTime,
      registration.birth.cradle == registration.cradlePose,
      registration.birth.reference == source.reference,
      registration.birth.cradle.position == source.position,
      registration.birth.cradle.orientation == Basis3(),
      registration.birth.units.count == 2,
      registration.resourceSHA256 == NativeC01ClinicCradle.resourceSHA256,
      registration.recipeSHA256 == NativeC01ClinicCradle.recipeSHA256,
      registration.physicalTime.isFinite, registration.physicalTime >= source.physicalTime,
      registration.physicalTime <= 1e12, poseValid(registration.cradlePose),
      registration.cradleVelocity.finite, registration.cradleAngularVelocity.finite,
      actorValid(registration.cradle, source: source), registration.units.count == 2,
      Set(registration.units.map(\.ordinal)) == [0, 1],
      Set(registration.units.map(\.registeredHull)).count == 2,
      Set(registration.units.map(\.pilot)).count == 2,
      Set(registration.units.map(\.actor)).count == 2,
      Set(registration.units.map(\.birthPhysical)).count == 2,
      state.assignments.count <= NativeC01ClinicPeople.maximumAssignments,
      state.dispositions.count <= NativeC01ClinicPeople.maximumDispositions
    else { return false }
    for (index, unit) in registration.units.enumerated() {
      guard unit.ordinal == index,
        unit.registeredHull == NativeC01ClinicPeople.hull(owner: source.owner, ordinal: index),
        unit.pilot == NativeC01ClinicPeople.person(owner: source.owner, ordinal: index),
        unit.pilot.valid, unit.pilotName == NativeC01ClinicPeople.definitions[index].name,
        unit.adult, unit.consentPolicy == NativeC01ClinicPeople.consentPolicy,
        unit.intrinsicPlace == 0, unit.mass.valid,
        unit.actor == NativeC01ClinicEscort.actor(mission: source.mission, ordinal: index),
        unit.actor != registration.facility,
        registration.birth.units[index] == .init(
          ordinal: index, registeredHull: unit.registeredHull, pilot: .clinicPilot(unit.pilot)),
        unit.berth == NativeC01ClinicEscort.parkedPose(
          cradle: registration.birth.cradle, ordinal: index),
        actorValid(unit.birthPhysical, source: source),
        unit.birthPhysical.visit == registration.cradle.visit,
        unit.birthPhysical != registration.cradle, poseValid(unit.berth)
      else { return false }
    }
    let revisions = state.assignments.map(\.revision) + state.dispositions.map(\.revision)
    let operations = [registration.operation] + state.assignments.map(\.operation)
      + state.dispositions.map(\.operation)
    guard Set(revisions).count == revisions.count,
      Set(revisions) == Set((0..<revisions.count).map { UInt64($0 + 1) }),
      Set(operations).count == operations.count,
      Set(state.assignments.map { $0.launch.ordinal }).count == state.assignments.count,
      Set(state.dispositions.map(\.ordinal)).count == state.dispositions.count
    else { return false }
    var phases: [NativeC01ClinicPilotLocation] = [.aboardStored, .aboardStored]
    var physicalTime = registration.physicalTime
    for index in 0..<revisions.count {
      let revision = UInt64(index + 1)
      if let assignment = state.assignments.first(where: { $0.revision == revision }) {
        let ordinal = assignment.launch.ordinal
        guard (0..<2).contains(ordinal), phases[ordinal] == .aboardStored,
          phases.indices.first(where: { phases[$0] == .aboardStored }) == ordinal,
          !phases.contains(where: { if case .aboardOperating = $0 { true } else { false } }),
          !phases.contains(where: { if case .receiver = $0 { true } else { false } }),
          assignment.launch.physicalTime >= physicalTime,
          assignmentValid(assignment, registration: registration)
        else { return false }
        phases[ordinal] = .aboardOperating(launch: assignment.launch.operation)
        physicalTime = assignment.launch.physicalTime
      } else {
        guard let disposition = state.dispositions.first(where: { $0.revision == revision }),
          (0..<2).contains(disposition.ordinal),
          disposition.kind.physicalTime >= physicalTime,
          dispositionValid(disposition, state: state)
        else { return false }
        let ordinal = disposition.ordinal
        switch disposition.kind {
        case .casualty(let evidence):
          switch phases[ordinal] {
          case .aboardStored: if disposition.assignment != nil { return false }
          case .aboardOperating:
            if disposition.assignment != state.assignment(ordinal)?.operation { return false }
          case .receiver, .casualtyWithDestroyedHull: return false
          }
          phases[ordinal] = .casualtyWithDestroyedHull(incident: evidence.incident)
        case .reception(let evidence):
          guard case .aboardOperating = phases[ordinal],
            disposition.assignment == state.assignment(ordinal)?.operation
          else { return false }
          phases[ordinal] = .receiver(evidence.station)
        }
        physicalTime = disposition.kind.physicalTime
      }
    }
    return true
  }

  private static func poseValid(_ pose: ShipPose) -> Bool {
    pose.position.finite && pose.orientation.validRotation
  }
  private static func actorValid(
    _ actor: ActorIdentity, source: NativeC01ClinicEscortSource
  ) -> Bool {
    actor.system == source.station.system && actor.visit >= source.visit
      && actor.visit < UInt64(Int64.max) && actor.entity > 1 && actor.entity < UInt64(Int64.max)
  }
  private static func assignmentValid(
    _ assignment: NativeC01ClinicPeopleAssignment,
    registration: NativeC01ClinicSourceRegistration
  ) -> Bool {
    let launch = assignment.launch
    guard registration.units.indices.contains(launch.ordinal) else { return false }
    let unit = registration.units[launch.ordinal]
    let source = registration.source
    let consent = assignment.consent
    guard assignment.operation == NativeC01ClinicPeople.reservationOperation(
      registration: registration, unit: unit),
      assignment.revision > 0 && assignment.revision <= 4,
      launch.sourceReceipt == assignment.operation, launch.registeredHull == unit.registeredHull,
      launch.pilot == .clinicPilot(unit.pilot), launch.loss == nil,
      launch.nativeActor == assignment.physical,
      launch.physicalTime.isFinite, launch.physicalTime <= 1e12,
      poseValid(launch.berth), poseValid(launch.reference),
      launch.operation == (try? NativeC01ClinicEscort.launchOperation(
        source: source, reservation: assignment.operation, hull: unit.registeredHull,
        pilot: .clinicPilot(unit.pilot), ordinal: unit.ordinal,
        berth: launch.berth, reference: launch.reference)),
      assignment.actor == unit.actor, actorValid(assignment.physical, source: source),
      assignment.physical.visit >= unit.birthPhysical.visit,
      assignment.observer.system == source.station.system, assignment.observer.entity == 0,
      assignment.observer.visit == assignment.physical.visit,
      !registration.units.contains(where: { $0.registeredHull == assignment.carrier }),
      (0...4_294_967_295).contains(assignment.beforeCash),
      assignment.afterCash == assignment.beforeCash,
      consent.pilot == unit.pilot, consent.registeredHull == unit.registeredHull,
      consent.reservation == assignment.operation, consent.sourceRevision < 4,
      consent.sourceRevision + 1 == assignment.revision,
      consent.destination == source.station, consent.actor == assignment.physical,
      actorValid(consent.cradle, source: source), consent.cradle != assignment.physical,
      consent.cradle.visit == assignment.physical.visit,
      consent.berth == launch.berth, consent.reference == launch.reference,
      consent.velocity.finite, consent.angularVelocity.finite, poseValid(consent.cradlePose),
      consent.cradleVelocity.finite, consent.cradleAngularVelocity.finite,
      consent.physicalTime == launch.physicalTime
    else { return false }
    return true
  }

  private static func dispositionValid(
    _ disposition: NativeC01ClinicPeopleDisposition, state: borrowing NativeC01ClinicSourceState
  ) -> Bool {
    let registration = state.registration
    guard let unit = state.unit(disposition.ordinal),
      disposition.registeredHull == unit.registeredHull, disposition.pilot == unit.pilot,
      disposition.kind.actor == unit.actor,
      disposition.operation == (try? NativeC01ClinicPeople.dispositionOperation(
        registration: registration, unit: unit, assignment: disposition.assignment,
        kind: disposition.kind))
    else { return false }
    switch disposition.kind {
    case .casualty(let evidence):
      guard actorValid(evidence.physical, source: registration.source),
        evidence.physical.visit >= unit.birthPhysical.visit, evidence.incident > 0,
        evidence.startTime.isFinite, evidence.physicalTime.isFinite,
        evidence.startTime >= registration.physicalTime,
        evidence.physicalTime > evidence.startTime, evidence.physicalTime <= 1e12,
        evidence.physicalTime - evidence.startTime <= NativeC01LaneRepair.maximumPhysicalInterval
      else { return false }
      if let origin = evidence.origin {
        guard origin.emittedAt.isFinite, origin.emittedAt >= 0,
          origin.emittedAt <= evidence.physicalTime,
          origin.owner.system == registration.source.station.system,
          origin.owner.visit > 0 && origin.owner.visit <= evidence.physical.visit
        else { return false }
      }
    case .reception(let evidence):
      guard disposition.assignment != nil, let assignment = state.assignment(unit.ordinal),
        evidence.station == registration.source.station,
        actorValid(evidence.physical, source: registration.source),
        evidence.physical.visit >= assignment.physical.visit,
        evidence.stationActor.system == evidence.station.system,
        evidence.stationActor.entity == 1,
        evidence.stationActor.visit == evidence.physical.visit,
        evidence.startTime.isFinite, evidence.startTime >= assignment.launch.physicalTime,
        evidence.physicalTime.isFinite, evidence.physicalTime > evidence.startTime,
        evidence.physicalTime <= 1e12,
        evidence.physicalTime - evidence.startTime <= NativeC01LaneRepair.maximumPhysicalInterval
      else { return false }
    }
    return true
  }

  static func validSource(
    _ optional: NativeC01ClinicSourceState?, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    guard let source = optional else {
      // A clinic leaf is published only with its actual three-actor/source birth.
      // Prepared geometry is a transient candidate, never a current-save population.
      if commander.scriptState.instances.values.contains(where: {
        $0.savedGlassMeridian?.clinicEscort != nil
      }) { return false }
      return true
    }
    guard source.owner == custody.owner, source.owner == commander.equipmentOwnerID,
      shapeValid(source), source.registration.physicalTime <= commander.flightSimulation.physicalTime,
      let mission = commander.scriptState.instances[source.registration.source.mission],
      let state = mission.savedGlassMeridian?.clinicEscort
    else { return false }
    let people = Set(source.registration.units.map { $0.pilot.id })
    let hulls = Set(source.registration.units.map(\.registeredHull))
    guard !people.contains(source.owner),
      commander.hullInstanceID.map({ !hulls.contains($0) }) ?? true,
      custody.admissions.allSatisfy({ admission in
        admission.person.nativeID.map { !people.contains($0) } ?? true
      }),
      commander.accommodation.ownedBerths.allSatisfy({
        $0.use.personID.map { !people.contains($0) } ?? true
      }),
      custody.crewService?.people.allSatisfy({ !people.contains($0.identity.id) }) ?? true,
      claimsMatch(source, state: state, mission: mission, commander: commander)
    else { return false }
    return true
  }

  /// Bounded reciprocal source/mission facts only. Never call a global validity chain here.
  static func sourceClaimsMatch(
    _ state: NativeC01ClinicEscortState, mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard let source = commander.nativePeople?.clinicSource else { return false }
    return claimsMatch(source, state: state, mission: mission, commander: commander)
  }

  private static func claimsMatch(
    _ source: borrowing NativeC01ClinicSourceState, state: NativeC01ClinicEscortState,
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard shapeValid(source), source.registration.source == state.source,
      source.registration.birth == state.birth,
      mission.id == state.source.mission, mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      state.source.owner == commander.equipmentOwnerID,
      mission.savedGlassMeridian?.permission.operation == state.source.permission,
      mission.savedGlassMeridian?.laneRepair?.installation?.operation == state.source.installation,
      mission.savedGlassMeridian?.surveyor?.capture?.operation == state.source.recorder,
      source.registration.cradle.visit <= commander.flightSimulation.visit,
      source.registration.cradle.entity < commander.flightSimulation.nextActor,
      source.assignments.count == state.launches.count, state.launches.count <= 2,
      state.parkedLosses.count <= 2,
      state.parkedLosses.allSatisfy({ (0..<2).contains($0.ordinal) && $0.launch == nil }),
      Set(state.launches.map(\.ordinal)).count == state.launches.count,
      Set(state.parkedLosses.map(\.ordinal)).count == state.parkedLosses.count,
      !state.parkedLosses.contains(where: { loss in
        state.launches.contains(where: { $0.ordinal == loss.ordinal })
      })
    else { return false }
    let owned = mission.ownedEncounters.values.flatMap { Array($0.actors.values) }
    let facility = source.registration.facility
    let cradles = owned.filter { $0.identity == facility }
    guard cradles.count == 1, let cradle = cradles.first, cradle.valid,
      cradle.body.missionInstanceID == mission.id,
      let cradlePhysical = cradle.body.physical,
      cradlePhysical.identity.system == state.source.station.system,
      cradlePhysical.identity.visit >= source.registration.cradle.visit,
      cradlePhysical.identity.visit <= commander.flightSimulation.visit,
      cradlePhysical.identity.entity < commander.flightSimulation.nextActor
    else { return false }
    for unit in source.registration.units {
      let actors = owned.filter { $0.identity == unit.actor }
      guard actors.count == 1, let actor = actors.first, actor.valid,
        actor.body.missionInstanceID == mission.id, actor.body.missionActorID == unit.actor,
        let physical = actor.body.physical,
        physical.identity.system == state.source.station.system,
        physical.identity.visit >= unit.birthPhysical.visit,
        physical.identity.visit <= commander.flightSimulation.visit,
        physical.identity.entity < commander.flightSimulation.nextActor
      else { return false }
      if let assignment = source.assignment(unit.ordinal) {
        guard assignment.launch.physicalTime <= commander.flightSimulation.physicalTime,
          assignment.physical.entity < commander.flightSimulation.nextActor,
          assignment.physical.visit <= commander.flightSimulation.visit,
          let launch = state.launches.first(where: { $0.sourceReceipt == assignment.operation })
        else { return false }
        var original = launch
        original.loss = nil
        guard original == assignment.launch else { return false }
      }
      if let disposition = source.disposition(unit.ordinal) {
        guard disposition.kind.physicalTime <= commander.flightSimulation.physicalTime else {
          return false
        }
        switch disposition.kind {
        case .casualty(let facts):
          guard let loss = state.loss(for: unit.ordinal), loss.ordinal == unit.ordinal,
            loss.launch == source.assignment(unit.ordinal)?.launch.operation,
            loss.sourceDisposition == disposition.operation,
            loss.actor == actor, loss.physicalTime == facts.physicalTime,
            actor.presence == .destroyed, actor.body.energy == 0,
            physical.identity == facts.physical,
            physical.deathIncidentID == facts.incident,
            physical.deathOrigin == facts.origin,
            facts.incident < commander.flightSimulation.nextIncident
          else { return false }
        case .reception(let facts):
          guard let arrival = state.arrival, actor.presence != .destroyed, actor.body.energy > 0,
            arrival.sourceReception == disposition.operation,
            arrival.registeredHull == unit.registeredHull, arrival.pilot == .clinicPilot(unit.pilot),
            arrival.launch == source.assignment(unit.ordinal)?.launch.operation,
            arrival.actor == facts.physical, arrival.station == facts.station,
            arrival.stationActor == facts.stationActor,
            arrival.startTime == facts.startTime, arrival.physicalTime == facts.physicalTime
          else { return false }
        }
      } else {
        guard state.arrival?.registeredHull != unit.registeredHull,
          state.loss(for: unit.ordinal) == nil,
          actor.presence != .destroyed, actor.body.energy > 0 else { return false }
      }
    }
    if let arrival = state.arrival {
      guard source.dispositions.contains(where: { $0.operation == arrival.sourceReception }) else {
        return false
      }
    }
    return true
  }

  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      root["clinicSource"] == nil, root["nativeClinicPeople"] == nil
    else { throw SaveError.invalidCommander }
    guard part == .commander else {
      guard root["savedNativePeopleCustody"] == nil else { throw SaveError.invalidCommander }
      return
    }
    let custody = root["savedNativePeopleCustody"] as? [String: Any] ?? [:]
    guard let raw = custody["clinicSource"] else { return }
    _ = try decodeClosed(JSONSerialization.data(withJSONObject: raw))
  }
}
