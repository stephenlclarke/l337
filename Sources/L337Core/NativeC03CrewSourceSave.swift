import Foundation

/// Reciprocal saved claims only. This validator never issues a person, fitting, native
/// actor, loss or care receipt and never calls a broader Commander validity chain.
enum NativeC03CrewSourceSave {
  static let maximumBytes = 131_072

  /// G1's current raw reader must slice/bound this leaf before the root decoder. There is
  /// no new save version or historical reader; only this exact current source shape exists.
  static func decodeClosed(_ bytes: Data) throws -> NativeC03CrewSourceState {
    guard !bytes.isEmpty, bytes.count <= maximumBytes,
      let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      let registration = raw["registration"] as? [String: Any],
      let log = registration["crewLog"] as? [String: Any],
      let logSeals = log["seals"] as? [Any], logSeals.count == 2,
      let fit = registration["accommodation"] as? [String: Any],
      let assignments = fit["assignments"] as? [Any], assignments.count == 6,
      let expectedBerths = fit["berths"] as? [Any], expectedBerths.count == 4,
      let hardware = raw["hardware"] as? [String: Any],
      let cabins = hardware["ownedCabins"] as? [Any], cabins.count == 1,
      let berths = hardware["ownedBerths"] as? [Any], berths.count == 4,
      let fitted = hardware["fitted"] as? [Any], fitted.count == 1,
      let people = hardware["people"] as? [Any], people.isEmpty,
      let operators = raw["operatingPlaces"] as? [Any],
      operators.count == (raw["loss"] == nil ? 2 : 0),
      let bindings = raw["nativeBindings"] as? [Any], bindings.count == 2
    else { throw SaveError.invalidCommander }
    let value = try JSONDecoder().decode(NativeC03CrewSourceState.self, from: bytes)
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    guard (raw as NSDictionary).isEqual(encoded), shapeValid(value) else {
      throw SaveError.invalidCommander
    }
    return value
  }

  static func shapeValid(_ source: borrowing NativeC03CrewSourceState) -> Bool {
    let r = source.registration
    let fit = r.accommodation
    let world = NativeHollowManifestDefinition.carrierWorld
    guard source.occupancyShapeValid, r.crewLog.shapeValid(fit: fit),
      fit.mission == NativeHollowManifestCommission.mission(owner: fit.owner),
      r.caseSourceSequence > 0, r.caseSourceSequence < UInt64(Int64.max),
      r.custodyRevision <= UInt64(NativePeopleCustodyState.maximumPeople * 2),
      r.physicalTime.isFinite, (0...1e12).contains(r.physicalTime),
      r.anchors.system == world, r.anchors.station.identity.system == world,
      r.anchors.station.identity.entity == 1, r.anchors.station.identity.visit > 0,
      r.reference.position.finite, r.reference.position.length.isFinite,
      r.reference.orientation.validRotation,
      r.carrier.originalHull == fit.originalCarrier, r.launch.originalHull == fit.originalLaunch,
      r.carrier.logicalActor == NativeC03CrewSourceState.logicalActor(mission: fit.mission, launch: false),
      r.launch.logicalActor == NativeC03CrewSourceState.logicalActor(mission: fit.mission, launch: true),
      r.carrier.birthActor != r.launch.birthActor,
      r.carrier.birthActor.entity < UInt64(Int64.max) - 1,
      r.launch.birthActor.entity == r.carrier.birthActor.entity + 1,
      r.carrier.birthActor.visit == r.anchors.station.identity.visit,
      r.launch.birthActor.visit == r.carrier.birthActor.visit,
      r.carrier.birthSpawn.sequence == r.launch.birthSpawn.sequence,
      r.carrier.birthSpawn.member == 0, r.launch.birthSpawn.member == 1,
      unitValid(r.carrier, role: .carrier), unitValid(r.launch, role: .launch),
      r.operation == (try? NativeC03CrewSourceState.registrationOperation(
        source: fit.source, carrier: r.carrier.birthActor, launch: r.launch.birthActor,
        spawn: r.carrier.birthSpawn)),
      source.nativeBindings.count == 2,
      source.nativeBindings.map(\.launch) == [false, true],
      source.nativeBindings.allSatisfy({ bindingValid($0, registration: r) })
    else { return false }
    guard let loss = source.loss else { return true }
    guard loss.incident > 0, loss.incident < UInt64(Int64.max),
      loss.actor.system == world, loss.actor.visit >= r.launch.birthActor.visit,
      loss.actor.entity > 1, loss.actor.entity < UInt64(Int64.max),
      loss.spawn.system == world, loss.spawn.visit == loss.actor.visit,
      loss.spawn.producer == .mission, loss.spawn.sequence > 0, loss.spawn.member < 2,
      let binding = source.nativeBindings.first(where: \.launch),
      loss.actor == binding.actor, loss.spawn == binding.spawn,
      loss.physicalTime >= binding.physicalTime,
      loss.physicalTime.isFinite, (r.physicalTime...1e12).contains(loss.physicalTime)
    else { return false }
    if let origin = loss.origin {
      guard origin.emissionID > 0, origin.owner.system == world,
        origin.emittedAt.isFinite, (0...loss.physicalTime).contains(origin.emittedAt)
      else { return false }
    }
    return true
  }

  static func sourceRequired(_ commander: borrowing Commander) -> Bool {
    if commander.accommodation.ownedBerths.contains(where: {
      if case .nativePerson(let person) = $0.use { return person.hollowManifestCrew != nil }
      return false
    }) { return true }
    if let custody = commander.nativePeople,
      custody.admissions.contains(where: { $0.person.hollowManifestCrew != nil })
        || custody.transfers.contains(where: { $0.members.contains { $0.hollowManifestCrew != nil } })
    { return true }
    return commander.scriptState.instances.values.contains {
      NativeHollowManifestCommission.marked($0)
        && ($0.savedHollowManifest?.crewSource != nil
          || $0.ownedEncounters[NativeC03CrewSourceState.encounter] != nil)
    }
  }

  static func validSource(
    _ source: NativeC03CrewSourceState?, custody: borrowing NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    let admissions = custody.admissions.filter { $0.person.hollowManifestCrew != nil }
    let transfers = custody.transfers.filter { $0.members.contains { $0.hollowManifestCrew != nil } }
    guard let source else {
      return admissions.isEmpty && transfers.isEmpty && !sourceRequired(commander)
    }
    let r = source.registration
    guard shapeValid(source), source.owner == custody.owner,
      source.owner == commander.equipmentOwnerID, r.custodyRevision <= custody.revision,
      r.physicalTime <= commander.flightSimulation.physicalTime
    else { return false }
    for unit in [r.carrier, r.launch] {
      let visit = commander.flightSimulation.visit
      guard unit.birthActor.visit <= visit else { return false }
      let nextActor = commander.flightSimulation.nextActor
      guard unit.birthActor.entity < nextActor else { return false }
      let nextSpawn = commander.flightSimulation.nextSpawn
      guard unit.birthSpawn.sequence < nextSpawn else { return false }
    }
    guard
      // The original escort never picks these people up into a player hull. A future real
      // pickup needs its own holder transition; it cannot be faked with a tool/collector UUID.
      admissions.isEmpty,
      let mission = commander.scriptState.instances[source.mission],
      let state = mission.savedHollowManifest,
      mission.definition == NativeHollowManifestCommission.stateID,
      mission.version == NativeHollowManifestCommission.version,
      mission.digest == NativeHollowManifestCommission.digest,
      state.crewSource == source.missionReference,
      r.crewLog.valid(in: state, fit: r.accommodation),
      state.birth.input.owner == source.owner, state.birth.input.mission == source.mission,
      r.caseSourceSequence < state.nextSourceSequence,
      let recovery = state.custodyRegister?.recovery,
      recovery.operation == r.registerTransfer, recovery.facts.sequence < r.caseSourceSequence,
      recovery.facts.originalKit == r.originalKit,
      state.laboratory?.facts.originalKit == r.originalKit,
      actorClaimsMatch(source, mission: mission, commander: commander),
      originalIDsExclusive(source, custody: custody, commander: commander)
    else { return false }
    if let access = source.crewLogAccess {
      guard access.valid(source: source, commander: commander) else { return false }
    } else {
      switch source.crewLogHolder {
      case .originalInspectionKit, .institutionalRecipient: return false
      case .originalLaunch, .stationWard: break
      }
    }
    if let loss = source.loss {
      guard source.crewLogHolder == .originalLaunch, source.crewLogAccess == nil,
        transfers.count == 1, let transfer = transfers.first,
        transfer.operation == loss.transfer, transfer.revision <= custody.revision,
        custody.transfers.filter({ $0.operation == loss.transfer }).count == 1
      else { return false }
      return validDirectTransfer(transfer, source: source, commander: commander)
    }
    // A care transfer is deliberately unsupported until the dedicated real recipient and
    // provider acceptance exist. A MAIN dock or a decoded .care receipt cannot fill that gap.
    return transfers.isEmpty && source.crewLogHolder == .originalLaunch && source.crewLogAccess == nil
  }

  static func actorClaimsMatch(
    _ source: borrowing NativeC03CrewSourceState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard let group = mission.ownedEncounters[NativeC03CrewSourceState.encounter],
      group.valid, group.admitted,
      group.id == NativeC03CrewSourceState.encounter,
      group.galaxy == NativeHollowManifestDefinition.carrierWorld.galaxy,
      group.system == NativeHollowManifestDefinition.carrierWorld.system,
      Set(group.actors.keys) == [NativeC03CrewSourceState.carrierTarget, NativeC03CrewSourceState.launchTarget]
    else { return false }
    let roles: [NativeC03EvacuationHull.Role] = [.carrier, .launch]
    for role in roles {
      let launch = role == .launch
      let unit = launch ? source.registration.launch : source.registration.carrier
      let target = launch ? NativeC03CrewSourceState.launchTarget : NativeC03CrewSourceState.carrierTarget
      guard let binding = source.nativeBindings.first(where: { $0.launch == launch }),
        binding.physicalTime <= commander.flightSimulation.physicalTime,
        let hull = try? NativeC03EvacuationHull.resolve(role),
        let profile = try? NativeC03EvacuationProfile.definition(role),
        let actor = group.actors[target], actor.identity == unit.logicalActor, actor.alias == target,
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == source.mission,
        (1..<1_000_000_000).contains(actor.body.id), actor.body.hull == .cobra,
        actor.body.position.finite, actor.body.orientation.validRotation,
        actor.body.energy.isFinite, (0...profile.energy).contains(actor.body.energy),
        actor.body.missiles == 0, !actor.body.ecmEnabled,
        actor.body.rotation.isFinite, actor.body.rotationRate.isFinite,
        [.present, .outside, .unloaded, .destroyed].contains(actor.presence),
        (actor.presence == .destroyed) == (actor.body.energy == 0),
        let physical = actor.body.physical, physical.population == .mission,
        physical.identity == binding.actor,
        physical.catalogueShipID == hull.source.current.id,
        physical.identity.system == NativeHollowManifestDefinition.carrierWorld,
        physical.identity.visit >= unit.birthActor.visit,
        physical.identity.visit <= commander.flightSimulation.visit,
        physical.identity.entity > 1, physical.identity.entity < commander.flightSimulation.nextActor,
        let spawn = physical.spawnIdentity, spawn.system == physical.identity.system,
        spawn == binding.spawn, spawn.member == binding.selectedOrdinal,
        spawn.visit == physical.identity.visit, spawn.producer == .mission,
        spawn.sequence > 0, spawn.sequence < commander.flightSimulation.nextSpawn,
        spawn.member < 2, physical.npc?.role == .mission,
        let resources = physical.npc?.resources, resources.valid,
        resources.profile == .nativeHull, resources.energyCapacity == profile.energy,
        resources.energyRecharge == profile.recharge,
        resources.frontCapacity == 0, resources.rearCapacity == 0, resources.shieldRecharge == 0,
        resources.frontShield == 0, resources.rearShield == 0,
        resources.heatCapacity == 0, resources.heatCooling == 0,
        resources.fuel == 0, resources.fuelCapacity == 0,
        physical.npc?.hasFuelScoops == false, physical.npc?.ordinaryCargo.isEmpty == true,
        physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
        physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
        physical.velocity.finite, physical.angularVelocity.finite,
        physical.laserCooldown.isFinite, physical.laserCooldown >= 0,
        let npc = actor.body.scriptNPC, npc.valid, npc.fit.definition == profile,
        npc.fit.models == [NativeC03EvacuationProfile.model(role): hull.geometry],
        npc.components.isEmpty, npc.guns.isEmpty, npc.shots == 0, npc.fuel == 0,
        commander.scriptState.geometry[hull.geometry] == hull.design
      else { return false }
      if actor.body.energy == 0 {
        guard let incident = physical.deathIncidentID,
          incident > 0, incident < commander.flightSimulation.nextIncident
        else { return false }
      } else if physical.deathIncidentID != nil || physical.deathOrigin != nil { return false }
      if launch {
        if let loss = source.loss {
          guard actor.presence == .destroyed, physical.identity == loss.actor,
            spawn == loss.spawn, physical.deathIncidentID == loss.incident,
            physical.deathOrigin == loss.origin
          else { return false }
        } else if actor.body.energy <= 0 { return false }
      }
    }
    return true
  }

  static func validDirectTransfer(
    _ transfer: borrowing NativePeopleTransferReceipt, source: borrowing NativeC03CrewSourceState,
    commander: borrowing Commander
  ) -> Bool {
    guard let loss = source.loss, transfer.kind == .loss, transfer.operation == loss.transfer,
      transfer.members == source.references, transfer.owner == source.owner,
      transfer.revision > source.registration.custodyRevision,
      transfer.dock == nil, transfer.price == 0, transfer.beforeCash == transfer.afterCash,
      (0...4_294_967_295).contains(transfer.beforeCash),
      transfer.beforeSlaves == transfer.afterSlaves,
      transfer.beforeSlaves >= 0,
      transfer.physicalTime == loss.physicalTime,
      transfer.physicalTime <= commander.flightSimulation.physicalTime,
      transfer.collector.entity == 0, transfer.collector.system == loss.actor.system,
      transfer.collector.visit == loss.actor.visit,
      transfer.calendarSeconds.isFinite,
      calendarInCurrentBounds(transfer: transfer.calendarSeconds,
        current: commander.scriptState.calendarSeconds),
      transfer.epoch == loss.epoch
    else { return false }
    return true
  }

  /// Scalar clock validation only, never source/receipt authority. Avoid ClosedRange
  /// construction because a malformed current upper bound can trap before returning false.
  static func calendarInCurrentBounds(transfer: Double, current: Double) -> Bool {
    guard transfer.isFinite, transfer >= 0 else { return false }
    guard current.isFinite else { return false }
    return current >= transfer
  }

  private static func unitValid(
    _ unit: NativeC03CrewSourceState.Unit, role: NativeC03EvacuationHull.Role
  ) -> Bool {
    guard let hull = try? NativeC03EvacuationHull.resolve(role),
      unit.rootGeometry == hull.geometry,
      unit.birthActor.system == NativeHollowManifestDefinition.carrierWorld,
      unit.birthActor.visit > 0, unit.birthActor.visit < UInt64(Int64.max),
      unit.birthActor.entity > 1, unit.birthActor.entity < UInt64(Int64.max),
      unit.birthSpawn.system == unit.birthActor.system,
      unit.birthSpawn.visit == unit.birthActor.visit,
      unit.birthSpawn.sequence > 0, unit.birthSpawn.sequence < UInt64(Int64.max),
      unit.birthSpawn.producer == .mission
    else { return false }
    return true
  }

  private static func bindingValid(
    _ binding: NativeC03CrewSourceState.NativeBinding,
    registration: NativeC03CrewSourceState.Registration
  ) -> Bool {
    let unit = binding.launch ? registration.launch : registration.carrier
    guard binding.generation > 0, binding.generation < UInt64(Int64.max),
      (1...2).contains(binding.cohortCount), binding.selectedOrdinal < binding.cohortCount,
      binding.cohortFirstEntity > 1,
      binding.cohortFirstEntity < UInt64.max - UInt64(binding.cohortCount),
      binding.actor.entity == binding.cohortFirstEntity + UInt64(binding.selectedOrdinal),
      binding.actor.system == unit.birthActor.system,
      binding.actor.visit >= unit.birthActor.visit,
      binding.spawn.system == binding.actor.system, binding.spawn.visit == binding.actor.visit,
      binding.spawn.producer == .mission, binding.spawn.member == binding.selectedOrdinal,
      binding.physicalTime.isFinite, (registration.physicalTime...1e12).contains(binding.physicalTime)
    else { return false }
    if binding.generation == 1 {
      return binding.actor == unit.birthActor && binding.spawn == unit.birthSpawn
        && binding.cohortCount == 2 && binding.selectedOrdinal == (binding.launch ? 1 : 0)
        && binding.cohortFirstEntity == registration.carrier.birthActor.entity
        && binding.physicalTime == registration.physicalTime
    }
    return binding.actor.entity > unit.birthActor.entity
      && binding.spawn.sequence > unit.birthSpawn.sequence
  }

  private static func originalIDsExclusive(
    _ source: borrowing NativeC03CrewSourceState, custody: borrowing NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    let people = Set(source.registration.accommodation.assignments.map(\.person.id))
    let hulls: Set<UUID> = [source.registration.carrier.originalHull, source.registration.launch.originalHull]
    guard !people.contains(source.owner),
      commander.hullInstanceID.map({ !hulls.contains($0) }) ?? true,
      commander.accommodation.ownedBerths.allSatisfy({
        $0.use.personID.map { !people.contains($0) } ?? true
      }),
      custody.admissions.allSatisfy({ $0.person.nativeID.map { !people.contains($0) } ?? true }),
      custody.crewService?.people.allSatisfy({ !people.contains($0.identity.id) }) ?? true
    else { return false }
    return true
  }
}
