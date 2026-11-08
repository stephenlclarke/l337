import Foundation

extension NativeC01LaneRepair {
  static func eligible(in game: borrowing Game) -> Bool {
    guard !game.docked, !game.paused, game.screen.isFlight, game.energy > 0,
      !game.playerEMPDisabled, game.systemIdentity == location,
      let mission = game.glassMeridianMission, mission.outcome == .active,
      mission.suspension == nil, mission.milestones == [0, 1, 2, 3, 4],
      let opening = mission.savedGlassMeridian,
      opening.surveyor?.held == true, opening.timingStandard?.held == true,
      opening.reservationCase?.audit != nil, opening.laneRepair?.installation == nil,
      opening.permission.owner == game.commander.equipmentOwnerID,
      NativeC01SurveyorSave.valid(mission, commander: game.commander),
      NativeC01ReservationAuditSave.valid(mission, commander: game.commander),
      let standard = opening.timingStandard,
      NativeC01TimingStandardSave.valid(standard, mission: mission, commander: game.commander)
    else { return false }
    return true
  }

  static func source(in game: borrowing Game) -> NativeC01LaneRepairSource? {
    guard eligible(in: game), let mission = game.glassMeridianMission,
      let opening = mission.savedGlassMeridian,
      let audit = opening.reservationCase?.audit, let recorder = opening.surveyor?.capture,
      let standard = opening.timingStandard?.capture, let context = game.gameplayContext(),
      let anchors = game.commander.flightSimulation.anchors, let anchor = game.scriptAnchor
    else { return nil }
    let pose = game.commander.flightSimulation.pose
    let result = NativeC01LaneRepairSource(
      mission: mission.id, permission: opening.permission.operation,
      owner: opening.permission.owner, audit: audit.operation, recorder: recorder.operation,
      standard: standard.operation, anchors: anchors,
      reference: .init(
        position: pose.systemPoint(anchor.position),
        orientation: anchor.orientation.transformed(by: pose.orientation)),
      visit: context.visit, physicalTime: context.physicalTime)
    return result.valid ? result : nil
  }

  static func definition(_ mission: ScriptInstance, id: String) -> ScriptEncounterDefinition? {
    guard id == encounter, mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      let opening = mission.savedGlassMeridian, let state = opening.laneRepair,
      NativeC01LaneRepairSave.shapeValid(state), state.source.mission == mission.id,
      state.source.permission == opening.permission.operation,
      state.source.owner == opening.permission.owner,
      state.source.standard == opening.timingStandard?.capture?.operation,
      state.source.recorder == opening.surveyor?.capture?.operation,
      state.source.audit == opening.reservationCase?.audit?.operation
    else { return nil }
    return .init(
      id: encounter, galaxy: 0, system: 91, profile: "profiled-local-freeze-v1",
      actors: Target.allCases.map { target in
        let point = state.source.reference.shipPoint(state.source.position(target))
        return .init(
          id: target.rawValue, hull: nil, npc: profile(target).id,
          x: point.x, y: point.y, z: point.z, hostile: false)
      })
  }

  static func profiles(_ mission: ScriptInstance) -> [ScriptNPCDefinition] {
    definition(mission, id: encounter) == nil ? [] : Target.allCases.map { profile($0) }
  }

  static func designs(_ mission: ScriptInstance) -> [String: ShipDesign] {
    guard definition(mission, id: encounter) != nil else { return [:] }
    guard let record = try? NativeC01Props.relay.get() else {
      preconditionFailure("The original C01 relay resource is required.")
    }
    return ["asset:c01-original-relay-node": record.nativeDesign]
  }

  static func design(_ target: Target) throws -> ShipDesign {
    try NativeC01Props.relay.get().nativeDesign
  }

  static func profile(_ target: Target) -> ScriptNPCDefinition {
    guard let record = try? NativeC01Props.relay.get() else {
      preconditionFailure("The original C01 relay resource is required.")
    }
    return .init(
      id: "c01-" + target.rawValue, name: "Meridian " + target.rawValue,
      source: record.sourcePath + "; SHA256 " + record.sourceSHA256,
      basis: "Original native relay geometry; explicit structural health, no shield/fuel/weapons/drive/crew.",
      model: "asset:c01-original-relay-node", scale: 1,
      energy: record.structuralPolicy.energy, recharge: record.structuralPolicy.recharge,
      speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0,
      missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
  }

  static func initialResources(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    guard state.definition == NativeGlassMeridian.stateID,
      state.digest == NativeGlassMeridian.digest, let target = Target(rawValue: actor.alias)
    else { return nil }
    guard let leaf = state.savedGlassMeridian?.laneRepair,
      definition(copy state, id: encounter) != nil, leaf.source.mission == state.id,
      actor.presence == .prepared, actor.body.physical == nil,
      original(actor, source: leaf.source, target: target),
      let record = try? NativeC01Props.relay.get(),
      actor.body.energy == record.structuralPolicy.energy
    else { throw SaveError.invalidCommander }
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: record.structuralPolicy.energy,
      energyRecharge: record.structuralPolicy.recharge,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
      heatCapacity: 0, heatCooling: 0, fuel: 0, fuelCapacity: 0)
    guard resources.valid else { throw SaveError.invalidCommander }
    return .init(
      role: .mission, origin: location, destination: location, legalProvenance: .recorded,
      cargoProvenance: .recorded, routeProvenance: .recorded,
      resources: resources, hasFuelScoops: false)
  }

  static func nativeValid(
    _ physical: PhysicalActorState, source: NativeC01LaneRepairSource, target: Target
  ) -> Bool {
    physical.identity.visit >= source.visit && nativeValid(physical, target: target)
  }

  static func nativeValid(_ physical: PhysicalActorState, target: Target) -> Bool {
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
      resources.profile == .nativeHull, resources.energyCapacity == profile(target).energy,
      resources.energyRecharge == 0, resources.frontCapacity == 0, resources.rearCapacity == 0,
      resources.shieldRecharge == 0, resources.frontShield == 0, resources.rearShield == 0,
      resources.heatCapacity == 0, resources.heatCooling == 0,
      resources.fuel == 0, resources.fuelCapacity == 0, resources.electrical == nil
    else { return false }
    return true
  }

  static func preparedEncounter(_ source: NativeC01LaneRepairSource) throws -> ScriptOwnedEncounter {
    guard source.valid else { throw SaveError.invalidCommander }
    var actors: [String: ScriptOwnedActor] = [:]
    for target in Target.allCases {
      let identity = actor(source: source, target: target)
      let profile = profile(target)
      let geometry = try design(target)
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(geometry))
      var body = SpaceBody(
        id: -1, hull: .cobra, position: source.reference.shipPoint(source.position(target)),
        hostile: false)
      body.orientation = Basis3().relative(to: source.reference.orientation)
      body.energy = profile.energy
      body.missiles = 0
      body.ecmEnabled = false
      body.rotationRate = 0
      body.missionActorID = identity
      body.missionInstanceID = source.mission
      body.scriptNPC = .init(
        fit: .init(definition: profile, models: [profile.model: hash]), fuel: 0,
        guns: [:], components: [:])
      actors[target.rawValue] = .init(
        identity: identity, alias: target.rawValue, body: body, presence: .prepared)
    }
    return .init(id: encounter, galaxy: 0, system: 91, actors: actors)
  }

  static func original(
    _ actor: ScriptOwnedActor, source: NativeC01LaneRepairSource, target: Target
  ) -> Bool {
    guard actor.valid, actor.alias == target.rawValue,
      actor.identity == self.actor(source: source, target: target),
      actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == source.mission,
      actor.body.hull == .cobra, !actor.body.hostile, actor.body.missiles == 0,
      !actor.body.ecmEnabled, actor.body.rotationRate == 0,
      actor.body.scriptNPC?.fit.definition == profile(target),
      let hash = try? NativeC01Props.relayModelHash.get()
    else { return false }
    let definition = profile(target)
    return actor.body.scriptNPC?.fit.models == [definition.model: hash]
  }
}

extension Game {
  mutating func prepareC01LaneRepair() throws -> Bool {
    guard NativeC01LaneRepair.eligible(in: self), var mission = glassMeridianMission,
      var opening = mission.savedGlassMeridian, let pack = glassMeridianPack
    else { return false }
    if mission.ownedEncounters[NativeC01LaneRepair.encounter]?.admitted == true { return false }
    if opening.laneRepair == nil {
      guard let source = NativeC01LaneRepair.source(in: self) else { return false }
      opening.laneRepair = .init(source: source)
      mission.savedGlassMeridian = opening
    }
    guard let state = opening.laneRepair, state.installation == nil else { return false }
    if mission.ownedEncounters[NativeC01LaneRepair.encounter] == nil {
      mission.ownedEncounters[NativeC01LaneRepair.encounter] =
        try NativeC01LaneRepair.preparedEncounter(state.source)
    }
    commander.scriptState.instances[mission.id] = mission
    for target in NativeC01LaneRepair.Target.allCases {
      let geometry = try NativeC01LaneRepair.design(target)
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(geometry))
      commander.scriptState.geometry[hash] = geometry
    }
    guard let cohort = mission.ownedEncounters[NativeC01LaneRepair.encounter] else {
      throw NativeMissionActorAdmissionError.invalidTemplate
    }
    let admission = try c01LaneRepairAdmissionSource(pack: pack, state: mission, encounter: cohort)
    switch try prepareMissionActorAdmission(admission) {
    case .pending: return false
    case .unchanged: throw NativeMissionActorAdmissionError.invalidTemplate
    case .ready(let plan):
      let staged = try plan.retentionPatch.preparingInstance(mission)
      _ = try commitMissionActorAdmission(plan)
      commander.scriptState.instances[mission.id] = staged
      return true
    }
  }

  func c01LaneRepairTarget(_ body: SpaceBody) -> NativeC01LaneRepair.Target? {
    guard let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.laneRepair,
      body.missionInstanceID == mission.id,
      NativeC01LaneRepair.definition(mission, id: NativeC01LaneRepair.encounter) != nil,
      let target = NativeC01LaneRepair.Target.allCases.first(where: {
        body.missionActorID == NativeC01LaneRepair.actor(source: state.source, target: $0)
      }), let identity = body.missionActorID,
      NativeC01LaneRepair.original(
        .init(identity: identity, alias: target.rawValue, body: body, presence: .prepared),
        source: state.source, target: target)
    else { return nil }
    return target
  }

  func c01LaneRepairActor(
    source: NativeC01LaneRepairSource, target: NativeC01LaneRepair.Target
  ) -> ScriptOwnedActor? {
    guard let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.laneRepair,
      state.source == source,
      NativeC01LaneRepairSave.historyJoins(state, mission: mission, commander: commander),
      let group = mission.ownedEncounters[NativeC01LaneRepair.encounter], group.valid, group.admitted,
      Set(group.actors.keys) == Set(NativeC01LaneRepair.Target.allCases.map(\.rawValue)),
      var actor = group.actors[target.rawValue], actor.presence == .present,
      NativeC01LaneRepair.original(actor, source: source, target: target),
      let body = bodies.first(where: { $0.id == actor.body.id }), body.energy > 0,
      body.missionActorID == actor.identity, body.missionInstanceID == source.mission,
      body.scriptNPC?.fit == actor.body.scriptNPC?.fit,
      let physical = body.physical, physical.identity == actor.body.physical?.identity,
      physical.identity.visit == commander.flightSimulation.visit,
      physical.identity.entity < commander.flightSimulation.nextActor,
      (physical.spawnIdentity?.sequence ?? UInt64.max) < commander.flightSimulation.nextSpawn,
      NativeC01LaneRepair.nativeValid(physical, source: source, target: target)
    else { return nil }
    actor.body = body
    return NativeC01LaneRepair.original(actor, source: source, target: target) ? actor : nil
  }
}

extension Game {
  func c01LaneRepairCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let target = c01LaneRepairTarget(body), let mission = glassMeridianMission,
      let source = mission.savedGlassMeridian?.laneRepair?.source,
      c01LaneRepairActor(source: source, target: target)?.body.id == body.id,
      let record = try? NativeC01Props.relay.get()
    else { return nil }
    return (record.nativeDesign.rawMesh, record.massKilograms)
  }
}
