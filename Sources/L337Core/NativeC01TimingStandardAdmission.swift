import Foundation

extension NativeC01TimingStandard {
  /// No new schema or scene is installed here. The caller must publish admission atomically.
  static func source(in game: borrowing Game) -> NativeC01TimingStandardSource? {
    guard eligible(in: game), let mission = game.glassMeridianMission,
      let opening = mission.savedGlassMeridian, let audit = opening.reservationCase?.audit,
      let recorder = opening.surveyor?.capture, let context = game.gameplayContext(),
      let anchors = game.commander.flightSimulation.anchors, let anchor = game.scriptAnchor
    else { return nil }
    let pose = game.commander.flightSimulation.pose
    let result = NativeC01TimingStandardSource(
      mission: mission.id, permission: opening.permission.operation,
      owner: opening.permission.owner, audit: audit.operation, recorder: recorder.operation,
      anchors: anchors,
      reference: .init(
        position: pose.systemPoint(anchor.position),
        orientation: anchor.orientation.transformed(by: pose.orientation)),
      visit: context.visit, physicalTime: context.physicalTime)
    return result.valid ? result : nil
  }

  static func eligible(in game: borrowing Game) -> Bool {
    guard !game.docked, !game.paused, game.screen.isFlight,
      !game.playerEMPDisabled, game.energy.isFinite, game.energy > 0,
      game.jumpCountdown == nil, game.pendingNativeStationDock == nil,
      game.systemIdentity == location, let mission = game.glassMeridianMission,
      mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version, mission.outcome == .active,
      mission.suspension == nil, mission.milestones == [0, 1, 2, 3],
      !mission.receipts.contains(receipt), let opening = mission.savedGlassMeridian,
      opening.surveyor?.held == true, opening.reservationCase?.audit != nil,
      opening.permission.owner == game.commander.equipmentOwnerID,
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening),
      NativeC01SurveyorSave.valid(mission, commander: game.commander),
      NativeC01ReservationAuditSave.valid(mission, commander: game.commander)
    else { return false }
    return true
  }

  static func sourceJoins(_ source: NativeC01TimingStandardSource, in game: borrowing Game) -> Bool
  {
    guard source.valid, let mission = game.glassMeridianMission,
      let leaf = mission.savedGlassMeridian?.timingStandard, leaf.source == source,
      NativeC01TimingStandardSave.historyJoins(leaf, mission: mission, commander: game.commander)
    else { return false }
    return true
  }

  static func joins(_ source: NativeC01TimingStandardSource, in game: borrowing Game) -> Bool {
    sourceJoins(source, in: game) && eligible(in: game)
      && game.commander.flightSimulation.anchors == source.anchors
  }

  static func definition(_ mission: ScriptInstance, id: String) -> ScriptEncounterDefinition? {
    guard id == encounter, mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      let opening = mission.savedGlassMeridian, let leaf = opening.timingStandard,
      NativeC01TimingStandardSave.shapeValid(leaf), leaf.source.mission == mission.id,
      leaf.source.permission == opening.permission.operation,
      leaf.source.audit == opening.reservationCase?.audit?.operation,
      leaf.source.recorder == opening.surveyor?.capture?.operation,
      leaf.source.owner == opening.permission.owner
    else { return nil }
    return .init(
      id: encounter, galaxy: 0, system: 162, profile: "profiled-local-freeze-v1",
      actors: Part.allCases.map { part in
        let point = leaf.source.reference.shipPoint(leaf.source.position + part.centre)
        return .init(
          id: part.rawValue, hull: nil, npc: part.profile.id,
          x: point.x, y: point.y, z: point.z, hostile: false)
      })
  }

  static func profiles(_ mission: ScriptInstance) -> [ScriptNPCDefinition] {
    definition(mission, id: encounter) == nil ? [] : Part.allCases.map(\.profile)
  }
  static func designs(_ mission: ScriptInstance) -> [String: ShipDesign] {
    guard definition(mission, id: encounter) != nil else { return [:] }
    return Dictionary(uniqueKeysWithValues: Part.allCases.map { ($0.model, $0.design) })
  }

  static func preparedEncounter(_ source: NativeC01TimingStandardSource) throws
    -> ScriptOwnedEncounter
  {
    guard source.valid else { throw SaveError.invalidCommander }
    var actors: [String: ScriptOwnedActor] = [:]
    for part in Part.allCases {
      let id = actor(source: source, part: part)
      guard let hash = try modelHashes.get()[part] else { throw SaveError.invalidCommander }
      var body = SpaceBody(
        id: -1, hull: .cobra,
        position: source.reference.shipPoint(source.position + part.centre), hostile: false)
      body.orientation = Basis3().relative(to: source.reference.orientation)
      body.energy = part.profile.energy
      body.missiles = 0
      body.ecmEnabled = false
      body.rotationRate = 0
      body.missionActorID = id
      body.missionInstanceID = source.mission
      body.scriptNPC = .init(
        fit: .init(definition: part.profile, models: [part.model: hash]), fuel: 0,
        guns: [:], components: [:])
      actors[part.rawValue] = .init(
        identity: id, alias: part.rawValue, body: body, presence: .prepared)
    }
    return .init(id: encounter, galaxy: 0, system: 162, actors: actors)
  }

  @inline(never)
  static func original(
    _ value: borrowing ScriptOwnedActor, source: borrowing NativeC01TimingStandardSource, part: Part
  ) -> Bool {
    guard value.valid, value.alias == part.rawValue,
      value.identity == actor(source: source, part: part)
    else { return false }
    return originalBody(value.body, identity: value.identity, source: source, part: part)
  }

  @inline(never)
  private static func originalBody(
    _ body: borrowing SpaceBody, identity: UUID,
    source: borrowing NativeC01TimingStandardSource, part: Part
  ) -> Bool {
    guard body.missionActorID == identity, body.missionInstanceID == source.mission,
      body.hull == .cobra, !body.hostile, body.missiles == 0,
      !body.ecmEnabled, body.rotationRate == 0,
      body.scriptNPC?.fit.definition == part.profile,
      let hashes = try? modelHashes.get(), let hash = hashes[part],
      body.scriptNPC?.fit.models == [part.model: hash]
    else { return false }
    return true
  }

  static func nativeValid(
    _ physical: PhysicalActorState, source: NativeC01TimingStandardSource,
    part: Part
  ) -> Bool {
    physical.identity.visit >= source.visit && nativeValid(physical, part: part)
  }

  /// The admission source has already validated the mission, identity, fit and source visit.
  /// Retention uses the actual staged physical snapshot before any cohort is committed.
  static func nativeValid(_ physical: PhysicalActorState, part: Part) -> Bool {
    guard physical.identity.system == location, physical.identity.visit > 0,
      physical.identity.entity > 1, physical.population == .mission,
      physical.velocity.finite, physical.angularVelocity.finite,
      physical.npc?.role == .mission, physical.ordnance == nil, physical.payload == nil,
      physical.rock == nil, physical.salvage == nil, physical.empSource == nil,
      physical.empCrewPod == nil, let spawn = physical.spawnIdentity,
      spawn.producer == .mission, spawn.system == location,
      spawn.visit == physical.identity.visit, spawn.sequence > 0,
      spawn.sequence < UInt64(Int64.max),
      let resources = physical.npc?.resources, resources.valid,
      resources.profile == .legacyEnergyOnly, resources.energyCapacity == part.profile.energy,
      resources.energyRecharge == 0, resources.frontCapacity == 0, resources.rearCapacity == 0,
      resources.electrical == nil
    else { return false }
    return true
  }
}

extension Game {
  func c01TimingStandardActor(
    source: NativeC01TimingStandardSource, part: NativeC01TimingStandard.Part
  ) -> ScriptOwnedActor? {
    guard NativeC01TimingStandard.sourceJoins(source, in: self),
      let group = glassMeridianMission?.ownedEncounters[NativeC01TimingStandard.encounter],
      group.valid, group.admitted, group.galaxy == 0, group.system == 162,
      Set(group.actors.keys) == Set(NativeC01TimingStandard.Part.allCases.map(\.rawValue)),
      var actor = group.actors[part.rawValue], actor.presence == .present,
      NativeC01TimingStandard.original(actor, source: source, part: part),
      let body = bodies.first(where: { $0.id == actor.body.id }), body.energy > 0,
      body.missionActorID == actor.identity, body.missionInstanceID == source.mission,
      body.scriptNPC?.fit == actor.body.scriptNPC?.fit,
      let physical = body.physical, physical.identity == actor.body.physical?.identity,
      physical.identity.visit == commander.flightSimulation.visit,
      physical.identity.entity < commander.flightSimulation.nextActor,
      (physical.spawnIdentity?.sequence ?? UInt64.max) < commander.flightSimulation.nextSpawn,
      NativeC01TimingStandard.nativeValid(physical, source: source, part: part)
    else { return nil }
    actor.body = body
    return NativeC01TimingStandard.original(actor, source: source, part: part) ? actor : nil
  }
}

extension Game {
  func c01TimingStandardPart(_ body: SpaceBody) -> NativeC01TimingStandard.Part? {
    guard let mission = glassMeridianMission, let leaf = mission.savedGlassMeridian?.timingStandard,
      body.missionInstanceID == mission.id,
      NativeC01TimingStandard.definition(mission, id: NativeC01TimingStandard.encounter) != nil,
      let part = NativeC01TimingStandard.Part.allCases.first(where: {
        body.missionActorID == NativeC01TimingStandard.actor(source: leaf.source, part: $0)
      }), let id = body.missionActorID,
      NativeC01TimingStandard.original(
        .init(
          identity: id, alias: part.rawValue,
          body: body, presence: .prepared), source: leaf.source, part: part)
    else { return nil }
    return part
  }
  func c01TimingStandardCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let part = c01TimingStandardPart(body),
      let source = glassMeridianMission?.savedGlassMeridian?.timingStandard?.source,
      c01TimingStandardActor(source: source, part: part)?.body.id == body.id
    else { return nil }
    return (part.design.rawMesh, part.massKg)
  }
}

extension NativeC01TimingStandard {
  static func pairSeparated(first: Part, pose: ShipPose, second: Part, other: ShipPose) -> Bool {
    guard first != second, let hulls = try? hulls.get(),
      let a = hulls[first], let b = hulls[second]
    else { return false }
    let stationary = HullSceneMotion(
      start: pose, end: pose,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: a.radius)
    return HullSweepSafety.validateSceneMotion(
      stationary, player: a,
      obstacles: [.init(hull: b, pose: other)]
    ).safe
  }
}

extension Game {
  func c01TimingStandardPairSeparated(
    _ a: SpawnRequest, _ first: MissionActorAdmissionTemplate,
    _ b: SpawnRequest, _ second: MissionActorAdmissionTemplate
  ) -> Bool {
    guard first.canonicalBody.missionInstanceID == second.canonicalBody.missionInstanceID,
      let left = c01TimingStandardPart(first.canonicalBody),
      let right = c01TimingStandardPart(second.canonicalBody)
    else { return false }
    return NativeC01TimingStandard.pairSeparated(
      first: left,
      pose: .init(position: a.position, orientation: a.orientation), second: right,
      other: .init(position: b.position, orientation: b.orientation))
  }
  func c01TimingStandardRetainedPairSeparated(
    _ request: SpawnRequest,
    _ template: MissionActorAdmissionTemplate, _ body: SpaceBody
  ) -> Bool {
    guard template.canonicalBody.missionInstanceID == body.missionInstanceID,
      let source = glassMeridianMission?.savedGlassMeridian?.timingStandard?.source,
      let first = c01TimingStandardPart(template.canonicalBody),
      let second = c01TimingStandardPart(body),
      c01TimingStandardActor(source: source, part: second)?.body.id == body.id
    else { return false }
    return NativeC01TimingStandard.pairSeparated(
      first: first,
      pose: .init(position: request.position, orientation: request.orientation), second: second,
      other: modelPose(of: body))
  }

  mutating func prepareC01TimingStandard() throws -> Bool {
    guard NativeC01TimingStandard.eligible(in: self),
      var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      let pack = glassMeridianPack
    else { return false }
    if mission.ownedEncounters[NativeC01TimingStandard.encounter]?.admitted == true { return false }
    if opening.timingStandard == nil {
      guard let source = NativeC01TimingStandard.source(in: self) else { return false }
      opening.timingStandard = .init(source: source)
      mission.savedGlassMeridian = opening
    }
    guard let leaf = opening.timingStandard, leaf.capture == nil, leaf.loss == nil else {
      return false
    }
    if mission.ownedEncounters[NativeC01TimingStandard.encounter] == nil {
      mission.ownedEncounters[NativeC01TimingStandard.encounter] =
        try NativeC01TimingStandard.preparedEncounter(leaf.source)
    }
    commander.scriptState.instances[mission.id] = mission
    let hashes = try NativeC01TimingStandard.modelHashes.get()
    for part in NativeC01TimingStandard.Part.allCases {
      guard let hash = hashes[part] else { throw SaveError.invalidCommander }
      commander.scriptState.geometry[hash] = part.design
    }
    guard let cohort = mission.ownedEncounters[NativeC01TimingStandard.encounter] else {
      throw SaveError.invalidCommander
    }
    let source = try c01TimingStandardAdmissionSource(pack: pack, state: mission, encounter: cohort)
    switch try prepareMissionActorAdmission(source) {
    case .pending: return false
    case .unchanged: throw NativeMissionActorAdmissionError.invalidTemplate
    case .ready(let plan):
      let staged = try plan.retentionPatch.preparingInstance(mission)
      _ = try commitMissionActorAdmission(plan)
      commander.scriptState.instances[mission.id] = staged
      return true
    }
  }
}

extension Game {
  func c01TimingStandardFacts(_ body: SpaceBody, context: EncounterContext)
    -> NativeC01TimingStandardSelectionFacts?
  {
    guard let leaf = glassMeridianMission?.savedGlassMeridian?.timingStandard,
      leaf.capture == nil, leaf.loss == nil, context.system == systemIdentity,
      context.visit == commander.flightSimulation.visit,
      NativeC01TimingStandard.joins(leaf.source, in: self),
      let actor = c01TimingStandardActor(source: leaf.source, part: .standard),
      actor.body.id == body.id,
      let cargo = NativeC01TimingStandard.prospectiveCargo(commander)
    else { return nil }
    return .init(logicalActor: actor.identity, fits: cargo <= commander.tradeCargoCapacity)
  }
  func c01TimingStandardMetadata(_ body: SpaceBody, context: EncounterContext)
    -> SalvageTargetMetadata?
  {
    guard c01TimingStandardFacts(body, context: context) != nil,
      let mesh = c01TimingStandardCollision(body)?.mesh
    else { return nil }
    return .init(
      category: .cargo, ownership: .missionProtected, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: mesh.vertices.map(\.length).max() ?? 0),
      workSurfaces: [])
  }
  func c01TimingStandardCompatibleMesh(_ body: SpaceBody) -> Mesh? {
    guard c01TimingStandardPart(body) == .standard else { return nil }
    return c01TimingStandardCollision(body)?.mesh
  }
}

extension Game {
  func c01TimingStandardBriefing(_ opening: NativeGlassMeridianState) -> [String] {
    if let leaf = opening.timingStandard, leaf.loss != nil {
      return ["The original timing standard was lost. It cannot be reissued. No payment or clue."]
    }
    if opening.surveyor?.loss != nil {
      return [
        "The original recorder was lost. Its saved audit remains; this attempt cannot recover the standard."
      ]
    }
    if opening.timingStandard?.held == true || opening.timingStandard?.used != nil {
      return c01LaneRepairBriefing(opening)
    }
    return [
      "Next: recover-standard at Enlirin (G01-S162).",
      "The abandoned cradle is 25km above the planet toward the star. Recover manually with fitted Scoops, or select the original timing standard for Auto Scoop.",
      "The damaged arm blocks the direct tug path. Go around its end and approach from the side.",
      "Fitted Fuel Scoops collect it in the lower-front aperture on a slow centred approach. Keep aperture-relative speed at or below 15m/s, including turning and target spin.",
      "Auto Scoop also requires the normal targeting core and Salvage Module; an obstructed path refuses.",
      "The original recorder stays aboard. Both originals total 1.008t; stored mass rounds up once for hold capacity. No payment or clue here.",
    ]
  }
}
