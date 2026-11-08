import Foundation

/// The one register-data owner and its historical location. Equipment ownership remains in
/// the real inventory. No decoded record, receipt, identity or location grants live access.
struct NativeC03RegisterState: Codable, Equatable, Sendable {
  struct Origin: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let source: UUID
    let archive: UUID
    let contents: NativeC03CustodyRegisterContent
    let anchors: SystemAnchors
    let reference: ShipPose
    let sequence: UInt64
    let physicalTime: Double
  }

  struct Admission: Codable, Equatable, Sendable {
    let revision: UInt64
    let actor: ActorIdentity
    let logicalActor: UUID
    let spawn: SpawnIdentity
    let component: UUID
    let rootGeometry: String
    let faceGeometry: String
    let sequence: UInt64
    let physicalTime: Double
  }

  struct Recovery: Codable, Equatable, Sendable {
    struct Facts: Codable, Equatable, Sendable {
      let source: UUID
      let register: UUID
      let contentsHash: String
      let comparison: NativeC03RegisterComparison
      let admission: Admission
      let player: ActorIdentity
      let originalKit: UUID
      let issueCommand: UUID
      let carrier: UUID
      let inventoryRevision: UInt64
      let instrument: NativeC03WakeTrail.Instrument
      let epoch: UUID
      let frame: UInt64
      let sequence: UInt64
      let readout: NativeC03RegisterProbe.Reading
    }
    let operation: UUID
    let facts: Facts

    static func identity(_ facts: Facts) throws -> UUID {
      guard facts.comparison.bounded else { throw SaveError.invalidCommander }
      return ScriptIdentity.uuid("c03-original-register-data-transfer-v1:\(try NativeFlightReception.hash(facts))")
    }
  }

  enum Holder: Equatable, Sendable {
    case originalArchive(UUID)
    case originalInspectionKit(UUID)
  }

  let origin: Origin
  let admissions: [Admission]
  let recovery: Recovery?

  /// The content is stored once. Source and receiver projections consult this same owner;
  /// there is no second archive copy or independent kit Boolean to update or reconstruct.
  var holder: Holder {
    recovery.map { .originalInspectionKit($0.facts.originalKit) } ?? .originalArchive(origin.archive)
  }
  var sourceContents: NativeC03CustodyRegisterContent? { recovery == nil ? origin.contents : nil }
  var latest: Admission? { admissions.max { $0.revision < $1.revision } }
  var sequences: [UInt64] {
    [origin.sequence] + admissions.map(\.sequence) + [recovery?.facts.sequence].compactMap { $0 }
  }

  static let encounter = "c03-original-register-archive"
  static let receipt = "hollow-manifest-original-register"

  static func source(mission: UUID, register: UUID) -> UUID {
    ScriptIdentity.uuid("c03-original-register-source-v1:\(mission):\(register)")
  }
  static func archive(source: UUID) -> UUID {
    ScriptIdentity.uuid("c03-original-register-archive-v1:\(source)")
  }
  static func logicalActor(mission: UUID) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(NativeHollowManifestCommission.digest):\(encounter):\(NativeC03CustodyRegisterContent.target)")
  }
  static func component(mission: UUID) -> UUID {
    ScriptIdentity.uuid("script-component-v2:\(logicalActor(mission: mission)):\(NativeC03CustodyRegisterContent.target)")
  }

  static func encounterKeys(for state: borrowing NativeHollowManifestState) -> Set<String> {
    var values: Set<String> = [NativeHollowManifestCommission.encounter]
    if state.wakeTrail != nil { values.insert(NativeC03WakeTrail.encounter) }
    if state.custodyRegister != nil { values.insert(encounter) }
    if state.crewSource != nil { values.insert(NativeC03CrewSourceState.encounter) }
    return values
  }

  /// Pure retained-claim validation; actual source and current scene must be joined anew.
  static func actorClaimsMatch(_ instance: borrowing ScriptInstance) -> Bool {
    guard let state = instance.savedHollowManifest else { return false }
    guard let register = state.custodyRegister else { return instance.ownedEncounters[encounter] == nil }
    guard let latest = register.latest, let owned = instance.ownedEncounters[encounter],
      owned.valid, owned.admitted, owned.id == encounter,
      owned.galaxy == NativeHollowManifestDefinition.registerWorld.galaxy,
      owned.system == NativeHollowManifestDefinition.registerWorld.system,
      Set(owned.actors.keys) == [NativeC03CustodyRegisterContent.target],
      let actor = owned.actors[NativeC03CustodyRegisterContent.target],
      actor.identity == latest.logicalActor, actor.alias == NativeC03CustodyRegisterContent.target,
      actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == instance.id,
      (1..<1_000_000_000).contains(actor.body.id), actor.body.hull == .cobra,
      actor.body.position.finite, actor.body.position.length.isFinite,
      actor.body.orientation.validRotation, actor.body.rotation.isFinite,
      actor.body.rotationRate == 0, actor.body.energy.isFinite, (0...16).contains(actor.body.energy),
      actor.body.missiles == 0, !actor.body.ecmEnabled,
      [.present, .outside, .unloaded, .destroyed].contains(actor.presence),
      (actor.presence == .destroyed) == (actor.body.energy == 0),
      let physical = actor.body.physical, physical.identity == latest.actor,
      physical.spawnIdentity == latest.spawn, physical.population == .mission,
      physical.npc?.role == .mission, let resources = physical.npc?.resources, resources.valid,
      resources.profile == .nativeHull, resources.energyCapacity == 16, resources.energyRecharge == 0,
      resources.frontCapacity == 0, resources.rearCapacity == 0, resources.shieldRecharge == 0,
      resources.fuel == 0, resources.fuelCapacity == 0,
      physical.npc?.hasFuelScoops == false, physical.npc?.ordinaryCargo.isEmpty == true,
      physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
      physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
      physical.velocity.finite, physical.angularVelocity.finite,
      let npc = actor.body.scriptNPC, npc.valid, npc.fit.definition == NativeC03RegisterGeometry.profile,
      npc.fit.models == [NativeC03RegisterGeometry.rootModel: latest.rootGeometry,
        NativeC03RegisterGeometry.faceModel: latest.faceGeometry],
      npc.components.count == 1,
      let face = npc.components[NativeC03RegisterGeometry.component],
      face.identity == latest.component, face.energy.isFinite, (0...1).contains(face.energy),
      face.guns.isEmpty, npc.guns.isEmpty, npc.shots == 0, npc.intent == nil, npc.fuel == 0,
      (register.origin.reference.orientation.apply(npc.velocity) - physical.velocity).length < 1e-8
    else { return false }
    return true
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    guard let lab = state.laboratory, let trail = state.wakeTrail,
      trail.observations.count == 3, let last = trail.observations.last,
      origin.mission == state.birth.input.mission, origin.owner == state.birth.input.owner,
      origin.contents.valid(in: state),
      origin.source == Self.source(mission: origin.mission, register: origin.contents.serial),
      origin.archive == Self.archive(source: origin.source),
      origin.sequence > last.sequence, origin.sequence < state.nextSourceSequence,
      origin.physicalTime.isFinite, (last.reading.physicalTime...1e12).contains(origin.physicalTime),
      origin.anchors.station.identity.visit > last.player.visit,
      origin.reference == (try? NativeC03RegisterGeometry.candidateFrame(anchors: origin.anchors)),
      (1...3).contains(admissions.count), let first = admissions.first(where: { $0.revision == 1 }),
      let latest, Set(admissions.map(\.revision)).count == admissions.count,
      Set(admissions.map(\.actor)).count == admissions.count,
      Set(sequences).count == sequences.count
    else { return false }
    for sequence in sequences {
      guard sequence < state.nextSourceSequence else { return false }
    }
    guard let hashes = try? NativeC03RegisterGeometry.hashes.get() else { return false }
    for admission in admissions {
      guard admission.revision > 0, admission.revision < UInt64(Int64.max),
        admission.logicalActor == Self.logicalActor(mission: origin.mission),
        admission.component == Self.component(mission: origin.mission),
        admission.actor.system == NativeHollowManifestDefinition.registerWorld,
        admission.actor.entity > 1, admission.actor.visit >= origin.anchors.station.identity.visit,
        admission.spawn.system == admission.actor.system, admission.spawn.visit == admission.actor.visit,
        admission.spawn.producer == .mission, admission.spawn.sequence > 0, admission.spawn.member == 0,
        admission.rootGeometry == hashes.root, admission.faceGeometry == hashes.face,
        admission.sequence > origin.sequence, admission.sequence < state.nextSourceSequence,
        admission.physicalTime.isFinite, (origin.physicalTime...1e12).contains(admission.physicalTime),
        admission.sequence >= first.sequence, admission.physicalTime >= first.physicalTime,
        admission.actor.visit >= first.actor.visit,
        admission.revision <= latest.revision, admission.sequence <= latest.sequence,
        admission.physicalTime <= latest.physicalTime, admission.actor.visit <= latest.actor.visit,
        admission == first || admission == latest || admission == recovery?.facts.admission
      else { return false }
    }
    guard let recovery else { return true }
    let f = recovery.facts
    guard f.source == origin.source, f.register == origin.contents.serial,
      f.contentsHash == (try? NativeFlightReception.hash(origin.contents)),
      f.comparison.valid(in: state, contents: origin.contents),
      admissions.contains(f.admission), f.sequence > f.admission.sequence,
      f.player.entity == 0, f.player.system == f.admission.actor.system,
      f.player.visit == f.admission.actor.visit, f.originalKit == lab.facts.originalKit,
      f.issueCommand == lab.facts.issueCommand,
      f.inventoryRevision >= lab.facts.afterInventoryRevision, f.inventoryRevision < UInt64(Int64.max),
      f.instrument.location == .init(hullInstanceID: f.carrier, slot: .targetingCore),
      TargetingTier.from(f.instrument.node.key) != nil,
      EquipmentRuntimeCatalog.node(for: f.instrument.node.key) == f.instrument.node,
      f.frame > 0, f.readout.shapeValid, f.readout.actor == f.admission.actor,
      f.readout.component == f.admission.component,
      f.readout.rayOrigin == f.readout.observerPose.position,
      f.readout.physicalTime >= f.admission.physicalTime,
      recovery.operation == (try? Recovery.identity(f))
    else { return false }
    let centre = f.readout.archivePose.systemPoint(NativeC03RegisterGeometry.componentPosition)
    let relative = f.readout.observerPose.shipPoint(centre)
    return relative.z > 0 && atan2(hypot(relative.x, relative.y), relative.z)
      <= NativeC03RegisterGeometry.maximumTargetAngle
  }

  func preservesHistory(of old: Self) -> Bool {
    guard origin == old.origin, old.recovery == nil || recovery == old.recovery,
      old.admissions.filter({ $0.revision == 1 }).allSatisfy(admissions.contains),
      let before = old.latest, let after = latest
    else { return false }
    return after.revision >= before.revision && (after.revision != before.revision || before == after)
  }
}

extension NativeHollowManifestState {
  /// Candidate history only. The real native source/receiver producer must separately
  /// authenticate and atomically publish this owner together with its stage evidence.
  func retainingCustodyRegister(_ record: NativeC03RegisterState) throws -> Self {
    guard shapeValid, phase == .admitted, wakeTrail?.observations.count == 3,
      custodyRegister.map({ record.preservesHistory(of: $0) }) ?? true
    else { throw Failure.invalidState }
    let previous = Set(custodyRegister?.sequences ?? [])
    let added = record.sequences.filter { !previous.contains($0) }.sorted()
    guard !added.isEmpty, added.count <= 2,
      nextSourceSequence < UInt64(Int64.max) - UInt64(added.count),
      added == (0..<added.count).map({ nextSourceSequence + UInt64($0) })
    else { throw Failure.invalidState }
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + UInt64(added.count),
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory,
      wakeTrail: wakeTrail, custodyRegister: record,
      crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}

extension NativeC03RegisterState {
  /// Unpublished scratch for the actual sealed native adapter. Caller facts alone cannot
  /// allocate an actor or install this record; the real plan must still commit unchanged.
  static func preparingAdmission(
    context: NativeC03RegisterAdmissionContext, admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> (state: NativeHollowManifestState, encounter: ScriptOwnedEncounter) {
    let state = context.pin.state
    guard admitted.count == 1, let body = admitted.first,
      context.flight.nextActor < UInt64.max - 1, context.flight.nextSpawn < UInt64.max - 1,
      flight.nextActor == context.flight.nextActor + 1, flight.nextSpawn == context.flight.nextSpawn + 1,
      flight.system == context.flight.system, flight.visit == context.flight.visit,
      flight.pose == context.flight.pose, flight.physicalTime == context.flight.physicalTime,
      state.nextSourceSequence < UInt64(Int64.max) - 2,
      let physical = body.physical, physical.identity.system == flight.system,
      physical.identity.visit == flight.visit, physical.identity.entity == context.flight.nextActor,
      let spawn = physical.spawnIdentity, spawn.system == physical.identity.system,
      spawn.visit == flight.visit, spawn.sequence == context.flight.nextSpawn,
      spawn.member == 0, spawn.producer == .mission,
      body.missionInstanceID == context.pin.missionID,
      body.missionActorID == logicalActor(mission: context.pin.missionID),
      let npc = body.scriptNPC, npc.fit.definition == NativeC03RegisterGeometry.profile,
      npc.components[NativeC03RegisterGeometry.component]?.identity == component(mission: context.pin.missionID),
      var actor = context.retention.actors[NativeC03CustodyRegisterContent.target],
      context.initial ? actor.presence == .prepared : [.outside, .unloaded].contains(actor.presence),
      let root = npc.fit.models[NativeC03RegisterGeometry.rootModel],
      let face = npc.fit.models[NativeC03RegisterGeometry.faceModel], body.energy > 0
    else { throw SaveError.invalidCommander }
    let expected = context.projection?.body ?? actor.body
    let point = context.station.position + context.station.orientation.apply(expected.position)
    let basis = expected.orientation.transformed(by: context.station.orientation)
    guard (body.position - point).length <= 1e-7,
      (body.orientation.x - basis.x).length <= 1e-9,
      (body.orientation.y - basis.y).length <= 1e-9,
      (body.orientation.z - basis.z).length <= 1e-9,
      body.energy == expected.energy, body.rotation == expected.rotation,
      body.rotationRate == expected.rotationRate
    else { throw SaveError.invalidCommander }
    var sequence = state.nextSourceSequence
    let origin: Origin
    if context.initial {
      let sourceID = Self.source(mission: context.pin.missionID, register: context.contents.serial)
      origin = .init(
        mission: context.pin.missionID, owner: context.pin.owner,
        source: sourceID, archive: Self.archive(source: sourceID), contents: context.contents,
        anchors: context.anchors, reference: context.reference,
        sequence: sequence, physicalTime: flight.physicalTime)
      sequence += 1
    } else {
      guard let old = state.custodyRegister else { throw SaveError.invalidCommander }
      origin = old.origin
    }
    let admission = Admission(
      revision: (state.custodyRegister?.latest?.revision ?? 0) + 1,
      actor: physical.identity, logicalActor: logicalActor(mission: context.pin.missionID),
      spawn: spawn, component: component(mission: context.pin.missionID),
      rootGeometry: root, faceGeometry: face, sequence: sequence, physicalTime: flight.physicalTime)
    var entries = (state.custodyRegister?.admissions ?? []) + [admission]
    let recovery = state.custodyRegister?.recovery
    entries = entries.filter { $0.revision == 1 || $0 == admission || $0 == recovery?.facts.admission }
    actor.body = try capture(body, reference: context.reference, flight: flight)
    actor.presence = .present
    if let old = context.projection {
      guard physical.velocity == old.historicalPhysical.velocity,
        physical.angularVelocity == old.historicalPhysical.angularVelocity,
        physical.canonicalSpin == old.historicalPhysical.canonicalSpin,
        physical.laserCooldown == old.historicalPhysical.laserCooldown,
        preservesCondition(physical.npc, old.historicalPhysical.npc)
      else { throw SaveError.invalidCommander }
    }
    var owned = context.retention
    owned.admitted = true
    owned.actors[NativeC03CustodyRegisterContent.target] = actor
    let record = Self(origin: origin, admissions: entries, recovery: recovery)
    return (try state.retainingCustodyRegister(record), owned)
  }

  static func capture(_ body: SpaceBody, reference: ShipPose, flight: FlightSimulationState) throws
    -> SpaceBody
  {
    guard flight.valid, reference.position.finite, reference.orientation.validRotation,
      body.position.finite, body.orientation.validRotation, body.rotation.isFinite,
      body.rotationRate == 0, let physical = body.physical, let npc = body.scriptNPC,
      physical.velocity.finite, physical.angularVelocity.finite,
      (flight.pose.orientation.apply(npc.velocity) - physical.velocity).length < 1e-8
    else { throw SaveError.invalidCommander }
    var value = body
    value.position = reference.shipPoint(flight.pose.systemPoint(body.position))
    value.orientation = body.orientation.transformed(by: flight.pose.orientation)
      .relative(to: reference.orientation)
    value.scriptNPC?.velocity = reference.shipVector(physical.velocity)
    return value
  }

  /// Only existing native admission policy sanitizes stale AI addresses; preserve all other
  /// condition, including exact actual resources, with no refill or new policy exception.
  private static func preservesCondition(_ new: NPCState?, _ old: NPCState?) -> Bool {
    guard var new, let old else { return new == old }
    new.firstAggressor = old.firstAggressor
    new.intention = old.intention
    return new == old
  }
}
