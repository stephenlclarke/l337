import Foundation

extension NativeC01ClinicEscort {
  static func definition(_ mission: ScriptInstance, id: String) -> ScriptEncounterDefinition? {
    guard id == sourceEncounter, mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      let opening = mission.savedGlassMeridian, let leaf = opening.clinicEscort,
      NativeC01ClinicEscortSave.shapeValid(leaf), leaf.source.mission == mission.id,
      leaf.source.permission == opening.permission.operation,
      leaf.source.owner == opening.permission.owner,
      leaf.source.installation == opening.laneRepair?.installation?.operation,
      leaf.source.recorder == opening.surveyor?.capture?.operation,
      let cradleProfile = try? profile(cradle: true), let tender = try? profile(cradle: false)
    else { return nil }
    let frame = leaf.birth.reference
    let cradle = leaf.birth.cradle
    let specs = [cradleTarget, stockTarget(0), stockTarget(1)].enumerated().map { index, alias in
      let pose = index == 0 ? cradle : parkedPose(cradle: cradle, ordinal: index - 1)
      let point = frame.shipPoint(pose.position)
      return ScriptActorDefinition(id: alias, hull: nil,
        npc: index == 0 ? cradleProfile.id : tender.id,
        x: point.x, y: point.y, z: point.z, hostile: false)
    }
    return .init(id: id, galaxy: 0, system: 91, profile: "profiled-local-freeze-v1", actors: specs)
  }

  static func profiles(_ mission: ScriptInstance) -> [ScriptNPCDefinition] {
    guard definition(mission, id: sourceEncounter) != nil,
      let cradle = try? profile(cradle: true), let tender = try? profile(cradle: false)
    else { return [] }
    return [cradle, tender]
  }
  static func designs(_ mission: ScriptInstance) -> [String: ShipDesign] {
    guard definition(mission, id: sourceEncounter) != nil,
      let cradle = try? NativeC01ClinicCradle.original.get(),
      let tender = try? NativeC01SurveyorGeometry.harrier.get()
    else { return [:] }
    return [cradleModel: cradle.nativeDesign, tenderModel: tender.design]
  }

  static func original(
    _ actor: ScriptOwnedActor, source: NativeC01ClinicEscortSource, ordinal: Int?
  ) -> Bool {
    if let ordinal, !(0..<maximumLaunches).contains(ordinal) { return false }
    let isCradle = ordinal == nil
    let alias = ordinal.map { stockTarget($0) } ?? cradleTarget
    let identity = ordinal.map { self.actor(mission: source.mission, ordinal: $0) }
      ?? cradle(mission: source.mission)
    guard actor.valid, actor.alias == alias, actor.identity == identity,
      actor.body.missionActorID == identity, actor.body.missionInstanceID == source.mission,
      actor.body.hull == .cobra, actor.body.rotationRate == 0, actor.body.rotation == 0,
      actor.body.missiles == 0, !actor.body.ecmEnabled,
      let profile = try? profile(cradle: isCradle), actor.body.scriptNPC?.fit.definition == profile,
      let hash = try? modelHash(cradle: isCradle),
      actor.body.scriptNPC?.fit.models == [profile.model: hash]
    else { return false }
    // Both parked and released tenders remain real ships for actual attacks and law.
    return !isCradle || !actor.body.hostile
  }

  static func preparedEncounter(
    source: NativeC01ClinicEscortSource, birth: NativeC01ClinicStockBirth
  ) throws -> ScriptOwnedEncounter {
    guard source.valid, birth.units.count == 2,
      Set(birth.units.map(\.ordinal)) == [0, 1]
    else { throw SaveError.invalidCommander }
    var actors: [String: ScriptOwnedActor] = [:]
    for index in 0..<3 {
      let ordinal: Int? = index == 0 ? nil : index - 1
      let isCradle = ordinal == nil
      let profile = try profile(cradle: isCradle)
      let alias = ordinal.map { stockTarget($0) } ?? cradleTarget
      let identity = ordinal.map { actor(mission: source.mission, ordinal: $0) }
        ?? cradle(mission: source.mission)
      let pose = ordinal.map { parkedPose(cradle: birth.cradle, ordinal: $0) } ?? birth.cradle
      var body = SpaceBody(id: -1, hull: .cobra,
        position: birth.reference.shipPoint(pose.position), hostile: false)
      body.orientation = pose.orientation.relative(to: birth.reference.orientation)
      body.energy = profile.energy
      body.missiles = 0
      body.ecmEnabled = false
      body.rotationRate = 0
      body.missionActorID = identity
      body.missionInstanceID = source.mission
      body.scriptNPC = .init(
        fit: .init(definition: profile, models: [profile.model: try modelHash(cradle: isCradle)]),
        fuel: 0, guns: [:], components: [:])
      let owned = ScriptOwnedActor(identity: identity, alias: alias, body: body, presence: .prepared)
      guard original(owned, source: source, ordinal: ordinal) else { throw SaveError.invalidCommander }
      actors[alias] = owned
    }
    return .init(id: sourceEncounter, galaxy: 0, system: 91, actors: actors)
  }

  static func initialResources(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    let ordinal = stockOrdinal(alias: actor.alias)
    guard state.definition == NativeGlassMeridian.stateID, state.digest == NativeGlassMeridian.digest,
      actor.alias == cradleTarget || ordinal != nil
    else { return nil }
    guard let leaf = state.savedGlassMeridian?.clinicEscort,
      actor.presence == .prepared, actor.body.physical == nil,
      leaf.launches.isEmpty, leaf.parkedLosses.isEmpty, leaf.arrival == nil,
      original(actor, source: leaf.source, ordinal: ordinal),
      actor.body.energy == (try profile(cradle: ordinal == nil)).energy
    else { throw SaveError.invalidCommander }
    // Native source registration and both aboard pilots must be prepared in the SAME
    // source-birth capsule. Launch never calls this initial-condition factory.
    let resources: NPCResources
    if ordinal == nil {
      resources = .init(profile: .nativeHull, energyCapacity: 100, energyRecharge: 0,
        frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
        heatCapacity: 0, heatCooling: 0, fuel: 0, fuelCapacity: 0)
    } else {
      guard var healthy = NPCResources.stock(try NativeC01SurveyorGeometry.harrier.get().performance)
      else { throw SaveError.invalidCommander }
      healthy.fuel = 0
      resources = healthy
    }
    guard resources.valid else { throw SaveError.invalidCommander }
    return .init(role: .mission, origin: location, destination: location,
      legalProvenance: .recorded, cargoProvenance: .recorded, routeProvenance: .recorded,
      resources: resources, hasFuelScoops: false)
  }

  static func nativeValid(_ physical: PhysicalActorState, cradle: Bool) -> Bool {
    guard physical.identity.system == location, physical.identity.visit > 0,
      physical.identity.entity > 1, physical.population == .mission,
      physical.npc?.role == .mission, physical.npc?.hasFuelScoops == false,
      physical.velocity.finite, physical.angularVelocity.finite,
      physical.ordnance == nil, physical.payload == nil, physical.rock == nil,
      physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
      let spawn = physical.spawnIdentity, spawn.producer == .mission,
      spawn.system == location, spawn.visit == physical.identity.visit,
      spawn.sequence > 0, spawn.sequence < UInt64(Int64.max),
      let resources = physical.npc?.resources, resources.valid,
      resources.profile == .nativeHull, resources.fuel == 0, resources.electrical == nil
    else { return false }
    if cradle {
      return resources.energyCapacity == 100 && resources.energyRecharge == 0
        && resources.frontCapacity == 0 && resources.rearCapacity == 0
        && resources.frontShield == 0 && resources.rearShield == 0 && resources.shieldRecharge == 0
        && resources.heatCapacity == 0 && resources.heatCooling == 0 && resources.fuelCapacity == 0
    }
    guard let p = try? NativeC01SurveyorGeometry.harrier.get().performance else { return false }
    return resources.energyCapacity == p.energy && resources.energyRecharge == p.recharge
      && resources.frontCapacity == p.shield && resources.rearCapacity == p.shield
      && resources.shieldRecharge == p.shieldRecharge && resources.fuelCapacity == p.fuel
      && resources.heatCapacity == 240 && resources.heatCooling == 12
  }
}

extension Game {
  func c01ClinicCradleActor(_ body: SpaceBody) -> ScriptOwnedActor? {
    c01ClinicActor(body, ordinal: nil)
  }

  func c01ClinicTenderActor(launch: NativeC01ClinicLaunch) -> ScriptOwnedActor? {
    guard let mission = glassMeridianMission,
      mission.savedGlassMeridian?.clinicEscort?.current == launch, launch.loss == nil,
      let body = bodies.first(where: {
        $0.missionActorID == NativeC01ClinicEscort.actor(mission: mission.id, ordinal: launch.ordinal)
      }), body.energy > 0
    else { return nil }
    return c01ClinicActor(body, ordinal: launch.ordinal)
  }

  func c01ClinicStockOrdinal(_ body: SpaceBody) -> Int? {
    guard let mission = glassMeridianMission, body.missionInstanceID == mission.id else { return nil }
    for ordinal in 0..<NativeC01ClinicEscort.maximumLaunches {
      if body.missionActorID == NativeC01ClinicEscort.actor(mission: mission.id, ordinal: ordinal),
        c01ClinicActor(body, ordinal: ordinal) != nil
      {
        return ordinal
      }
    }
    return nil
  }

  func c01ClinicStockActor(_ body: SpaceBody, ordinal: Int) -> ScriptOwnedActor? {
    c01ClinicActor(body, ordinal: ordinal)
  }

  private func c01ClinicActor(_ body: SpaceBody, ordinal: Int?) -> ScriptOwnedActor? {
    guard let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      c01ClinicStoredHistoryJoins(state, mission: mission),
      body.missionInstanceID == mission.id, let physical = body.physical,
      physical.identity.visit == storedFlightSimulation().visit,
      physical.identity.entity < storedFlightSimulation().nextActor,
      physical.identity.visit >= state.source.visit,
      (physical.spawnIdentity?.sequence ?? UInt64.max) < storedFlightSimulation().nextSpawn,
      NativeC01ClinicEscort.nativeValid(physical, cradle: ordinal == nil),
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      let group = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter],
      group.valid, group.admitted,
      Set(group.actors.keys) == [NativeC01ClinicEscort.cradleTarget,
        NativeC01ClinicEscort.stockTarget(0), NativeC01ClinicEscort.stockTarget(1)]
    else { return nil }
    let alias = ordinal.map { NativeC01ClinicEscort.stockTarget($0) }
      ?? NativeC01ClinicEscort.cradleTarget
    guard var owned = group.actors[alias],
      owned.presence == .present || owned.presence == .destroyed,
      owned.body.id == body.id, owned.body.physical?.identity == physical.identity,
      owned.body.scriptNPC?.fit == body.scriptNPC?.fit
    else { return nil }
    owned.body = body
    return NativeC01ClinicEscort.original(owned, source: state.source, ordinal: ordinal) ? owned : nil
  }

  /// Source/fit declaration is available before native addresses are allocated.
  func c01ClinicCradleDeclared(_ body: SpaceBody) -> Bool {
    guard let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      state.source.owner == storedEquipmentOwnerID(),
      NativeC01ClinicEscort.definition(mission, id: NativeC01ClinicEscort.sourceEncounter) != nil,
      body.missionInstanceID == mission.id,
      body.missionActorID == NativeC01ClinicEscort.cradle(mission: mission.id)
    else { return false }
    return NativeC01ClinicEscort.original(
      .init(identity: NativeC01ClinicEscort.cradle(mission: mission.id),
        alias: NativeC01ClinicEscort.cradleTarget, body: body, presence: .prepared),
      source: state.source, ordinal: nil)
  }
}


extension NativeC01ClinicEscort {
  static func consumed(_ actorID: UUID, commander: borrowing Commander) -> Bool {
    for mission in commander.scriptState.instances.values {
      guard mission.definition == NativeGlassMeridian.stateID,
        mission.digest == NativeGlassMeridian.digest,
        mission.version == NativeGlassMeridian.version,
        let opening = mission.savedGlassMeridian, let state = opening.clinicEscort,
        NativeC01ClinicEscortSave.shapeValid(state), let arrival = state.arrival,
        let launch = state.current, launch.loss == nil,
        arrival.launch == launch.operation,
        actorID == actor(mission: mission.id, ordinal: launch.ordinal),
        state.source.owner == commander.equipmentOwnerID,
        mission.receipts.contains(receipt)
      else { continue }
      return NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission,
        commander: commander)
    }
    return false
  }
}


extension Game {
  /// Only the same uncommitted three-actor clinic source may replace the broad
  /// cohort padding with a proof against both complete authenticated native hulls.
  @inline(never)
  func c01ClinicPreparedPairSeparated(
    _ a: SpawnRequest, _ first: MissionActorAdmissionTemplate,
    _ b: SpawnRequest, _ second: MissionActorAdmissionTemplate
  ) -> Bool {
    guard first.actorID != second.actorID, first.alias != second.alias,
      let mission = glassMeridianMission,
      first.canonicalBody.missionInstanceID == mission.id,
      second.canonicalBody.missionInstanceID == mission.id,
      let state = mission.savedGlassMeridian?.clinicEscort,
      state.source == c01ClinicSourceContext(),
      state.source.owner == commander.equipmentOwnerID,
      state.source.visit == commander.flightSimulation.visit,
      state.source.physicalTime == commander.flightSimulation.physicalTime,
      state.birth.physicalTime == state.source.physicalTime,
      state.birth.reference == state.source.reference,
      commander.nativePeople?.clinicSource == nil,
      state.launches.isEmpty, state.parkedLosses.isEmpty, state.arrival == nil,
      let group = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter],
      group.valid, !group.admitted, group.galaxy == 0, group.system == 91,
      Set(group.actors.keys) == [NativeC01ClinicEscort.cradleTarget,
        NativeC01ClinicEscort.stockTarget(0), NativeC01ClinicEscort.stockTarget(1)],
      let left = group.actors[first.alias], let right = group.actors[second.alias],
      a.identity != b.identity, a.identity.system == state.source.station.system,
      b.identity.system == a.identity.system,
      a.identity.visit == state.source.visit, b.identity.visit == a.identity.visit,
      a.identity.producer == .mission, b.identity.producer == .mission,
      a.identity.sequence == b.identity.sequence,
      a.identity.sequence == commander.flightSimulation.nextSpawn,
      a.identity.member != b.identity.member,
      NativeC01ClinicEscort.sourceAdmissionMemberMatches(a, first, actor: left, state: state),
      NativeC01ClinicEscort.sourceAdmissionMemberMatches(b, second, actor: right, state: state)
    else { return false }
    return NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: first.alias, pose: .init(position: a.position, orientation: a.orientation),
      second: second.alias, other: .init(position: b.position, orientation: b.orientation))
  }
}

extension NativeC01ClinicEscort {
  private static let sourceAdmissionHulls: Result<
    (cradle: PreparedHull, tender: PreparedHull, cradleMesh: Mesh, tenderMesh: Mesh), any Error
  > = Result {
    let cradleMesh = try NativeC01ClinicCradle.original.get().nativeDesign.rawMesh
    let tenderMesh = try NativeC01SurveyorGeometry.harrier.get().collision
    let cradle = try PreparedHull(mesh: cradleMesh)
    let tender = try PreparedHull(mesh: tenderMesh)
    guard cradle.isClosed, tender.isClosed else { throw HullSweepFailure.invalidGeometry }
    return (cradle, tender, cradleMesh, tenderMesh)
  }

  /// Data-only geometry proof. Calling this creates no native actor, pilot or live authority.
  /// The caller above must first bind both requests/templates to the current prepared source.
  @inline(never)
  static func sourceAdmissionPairSeparated(
    first: String, pose: ShipPose, second: String, other: ShipPose
  ) -> Bool {
    guard first != second,
      first == cradleTarget || stockOrdinal(alias: first) != nil,
      second == cradleTarget || stockOrdinal(alias: second) != nil,
      pose.position.finite, pose.orientation.validRotation,
      other.position.finite, other.orientation.validRotation,
      let hulls = try? sourceAdmissionHulls.get()
    else { return false }
    // Keep the open cradle as the obstacle, matching the actual whole-hull flight proof.
    let player = hulls.tender
    let start = first == cradleTarget ? other : pose
    let obstacle = first == cradleTarget || second == cradleTarget ? hulls.cradle : hulls.tender
    let obstaclePose = first == cradleTarget ? pose : other
    let motion = HullSceneMotion(start: start, end: start,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1,
      playerRadius: player.radius, requiredClearance: 5)
    return HullSweepSafety.validateSceneMotion(motion, player: player,
      obstacles: [.init(hull: obstacle, pose: obstaclePose, clearanceOverride: 5)]).safe
  }

  @inline(never)
  fileprivate static func sourceAdmissionMemberMatches(
    _ request: borrowing SpawnRequest, _ template: borrowing MissionActorAdmissionTemplate,
    actor: borrowing ScriptOwnedActor, state: borrowing NativeC01ClinicEscortState
  ) -> Bool {
    let ordinal = stockOrdinal(alias: template.alias)
    let isCradle = template.alias == cradleTarget
    guard isCradle || ordinal != nil,
      template.presence == .prepared, actor.presence == .prepared,
      actor.alias == template.alias, actor.identity == template.actorID,
      actor.body == template.canonicalBody,
      original(actor, source: state.source, ordinal: ordinal),
      actor.body.physical == nil,
      request.priority == .mission, request.population == .mission,
      request.hull == actor.body.hull, request.energy == actor.body.energy,
      request.rock == nil, request.payload == nil, request.salvage == nil,
      request.catalogueShipID == nil,
      request.npc == template.retainedNativeCondition,
      request.velocity == Vector3(0, 0, 0), request.angularVelocity == Vector3(0, 0, 0),
      request.identity.member == (isCradle ? 2 : UInt16(ordinal ?? -1)),
      template.parts.count == 1, template.nativeUnits == 1,
      let part = template.parts.first, part.solid, part.alias == nil, part.componentID == nil,
      let hulls = try? sourceAdmissionHulls.get()
    else { return false }
    let mesh = isCradle ? hulls.cradleMesh : hulls.tenderMesh
    let hull = isCradle ? hulls.cradle : hulls.tender
    guard part.mesh.vertices == mesh.vertices, part.mesh.faces == mesh.faces,
      template.radius == hull.radius,
      part.energy == actor.body.energy, part.maximumEnergy == template.maximumHullEnergy
    else { return false }
    let expected: ShipPose
    if let ordinal {
      expected = parkedPose(cradle: state.birth.cradle, ordinal: ordinal)
    } else {
      expected = state.birth.cradle
    }
    guard actor.body.position == state.birth.reference.shipPoint(expected.position),
      actor.body.orientation == expected.orientation.relative(to: state.birth.reference.orientation),
      request.position.finite, (request.position - expected.position).length < 1e-6,
      request.orientation.validRotation
    else { return false }
    guard (request.orientation.x - expected.orientation.x).length < 1e-7 else { return false }
    guard (request.orientation.y - expected.orientation.y).length < 1e-7 else { return false }
    return (request.orientation.z - expected.orientation.z).length < 1e-7
  }
}
