import Foundation

/// Current-format historical records, not authority to issue, restore or observe an object.
struct NativeC03WakeTrail: Codable, Equatable, Sendable {
  typealias Mark = NativeC03WakeGeometry.Mark

  struct Origin: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let source: UUID
    let laboratory: UUID
    let originalKit: UUID
    let anchors: SystemAnchors
    let reference: ShipPose
    let sequence: UInt64
    let physicalTime: Double
  }

  struct Admission: Codable, Equatable, Sendable {
    let mark: Mark
    let revision: UInt64
    let fragment: UUID
    let logicalActor: UUID
    let actor: ActorIdentity
    let spawn: SpawnIdentity
    let geometry: String
    let sequence: UInt64
    let physicalTime: Double
  }

  struct Observation: Codable, Equatable, Sendable {
    let operation: UUID
    let admission: Admission
    let player: ActorIdentity
    let carrier: UUID
    let originalKit: UUID
    let issueCommand: UUID
    let inventoryRevision: UInt64
    let instrument: Instrument
    let epoch: UUID
    let frame: UInt64
    let sequence: UInt64
    let reading: NativeC03WakeProbe.Reading
  }

  /// Historical fitting address only, not a second equipment item or upgrade/provenance owner.
  struct Instrument: Codable, Equatable, Sendable {
    let item: UUID
    let node: EquipmentNodeID
    let location: ComponentFittingLocation
  }

  let origin: Origin
  let admissions: [Admission]
  let observations: [Observation]

  static let encounter = "c03-original-wake-trail"
  static let receipt = "hollow-manifest-wake-trail"
  static let dialogue =
    "The marks lead away from the station approach. The cradle accepted cargo that has no line in the carrier's declared manifest."

  static func source(mission: UUID, laboratory: UUID) -> UUID {
    ScriptIdentity.uuid("c03-original-wake-source-v1:\(mission):\(laboratory)")
  }

  static func fragment(source: UUID, mark: Mark) -> UUID {
    ScriptIdentity.uuid("c03-original-wake-fragment-v1:\(source):\(mark.rawValue)")
  }

  static func logicalActor(mission: UUID, mark: Mark) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(NativeHollowManifestCommission.digest):\(encounter):\(mark.rawValue)")
  }

  static func observationIdentity(
    source: UUID, admission: Admission, player: ActorIdentity, kit: UUID,
    carrier: UUID, issueCommand: UUID, inventoryRevision: UInt64,
    instrument: Instrument, epoch: UUID, frame: UInt64,
    sequence: UInt64, reading: NativeC03WakeProbe.Reading
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "c03-original-wake-observation-v1:\(source):\(try NativeFlightReception.hash(admission)):\(try NativeFlightReception.hash(player)):\(kit):\(carrier):\(issueCommand):\(inventoryRevision):\(try NativeFlightReception.hash(instrument)):\(epoch):\(frame):\(sequence):\(try NativeFlightReception.hash(reading))")
  }

  func latest(_ mark: Mark) -> Admission? {
    admissions.filter { $0.mark == mark }.max { $0.revision < $1.revision }
  }

  var nextMark: Mark? {
    observations.count < Mark.allCases.count ? Mark.allCases[observations.count] : nil
  }

  var sequences: [UInt64] {
    [origin.sequence] + admissions.map(\.sequence) + observations.map(\.sequence)
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    guard let lab = state.laboratory,
      origin.mission == state.birth.input.mission, origin.owner == state.birth.input.owner,
      origin.laboratory == lab.operation, origin.originalKit == lab.facts.originalKit,
      origin.source == Self.source(mission: origin.mission, laboratory: origin.laboratory),
      origin.sequence > lab.facts.sequence, origin.sequence < state.nextSourceSequence,
      origin.physicalTime.isFinite, (lab.facts.physicalTime...1e12).contains(origin.physicalTime),
      origin.anchors.station.identity.visit > lab.facts.dock.actor.visit,
      let layout = try? NativeC03WakeGeometry.candidateLayout(anchors: origin.anchors),
      layout.reference == origin.reference,
      (3...9).contains(admissions.count), observations.count <= 3,
      Set(admissions.map(\.actor)).count == admissions.count,
      Set(sequences).count == sequences.count
    else { return false }
    for sequence in sequences {
      guard sequence < state.nextSourceSequence else { return false }
    }
    guard observations.map({ $0.admission.mark }) == Array(Mark.allCases.prefix(observations.count))
    else { return false }
    for mark in Mark.allCases {
      let entries = admissions.filter { $0.mark == mark }
      guard (1...3).contains(entries.count), let first = entries.first(where: { $0.revision == 1 }),
        let current = latest(mark),
        Set(entries.map(\.revision)).count == entries.count
      else { return false }
      for admission in entries {
        guard admission.revision > 0 && admission.revision < UInt64(Int64.max)
            && admission.fragment == Self.fragment(source: origin.source, mark: mark)
            && admission.logicalActor == Self.logicalActor(mission: origin.mission, mark: mark)
            && admission.actor.system == NativeC03WakeGeometry.world
            && admission.actor.entity > 1 && admission.actor.visit >= origin.anchors.station.identity.visit
            && admission.spawn.system == admission.actor.system
            && admission.spawn.visit == admission.actor.visit && admission.spawn.producer == .mission
            && admission.spawn.sequence > 0 && admission.spawn.member < 3
            && admission.sequence > origin.sequence && admission.sequence < state.nextSourceSequence
            && admission.physicalTime.isFinite
            && (origin.physicalTime...1e12).contains(admission.physicalTime)
            && admission.geometry == (try? NativeC03WakeGeometry.geometryHash(mark))
        else { return false }
      }
      guard entries.allSatisfy({ item in
          item.revision >= first.revision && item.sequence >= first.sequence
            && item.physicalTime >= first.physicalTime && item.actor.visit >= first.actor.visit
            && item.revision <= current.revision && item.sequence <= current.sequence
            && item.physicalTime <= current.physicalTime && item.actor.visit <= current.actor.visit
        })
      else { return false }
      let retained = [first, current] + observations.filter { $0.admission.mark == mark }.map(\.admission)
      guard entries.allSatisfy(retained.contains) else { return false }
    }
    var previousSequence = origin.sequence
    var previousTime = origin.physicalTime
    for observed in observations {
      let admission = observed.admission
      guard admissions.contains(admission), observed.player.entity == 0,
        observed.player.system == admission.actor.system, observed.player.visit == admission.actor.visit,
        observed.originalKit == origin.originalKit, observed.issueCommand == lab.facts.issueCommand,
        observed.inventoryRevision >= lab.facts.afterInventoryRevision,
        observed.inventoryRevision < UInt64(Int64.max),
        observed.instrument.location == .init(hullInstanceID: observed.carrier, slot: .targetingCore),
        TargetingTier.from(observed.instrument.node.key) != nil,
        EquipmentRuntimeCatalog.node(for: observed.instrument.node.key) == observed.instrument.node,
        observed.frame > 0, observed.sequence > admission.sequence,
        observed.sequence > previousSequence,
        observed.reading.shapeValid, observed.reading.actor == admission.actor,
        observed.reading.mark == admission.mark,
        observed.reading.rayOrigin == observed.reading.observerPose.position,
        observed.reading.physicalTime >= admission.physicalTime,
        observed.reading.physicalTime >= previousTime,
        observed.operation == (try? Self.observationIdentity(
          source: origin.source, admission: admission, player: observed.player,
          kit: observed.originalKit, carrier: observed.carrier, issueCommand: observed.issueCommand,
          inventoryRevision: observed.inventoryRevision, instrument: observed.instrument,
          epoch: observed.epoch, frame: observed.frame,
          sequence: observed.sequence, reading: observed.reading))
      else { return false }
      let relative = observed.reading.observerPose.shipPoint(observed.reading.pose.position)
      guard relative.z > 0, atan2(hypot(relative.x, relative.y), relative.z)
        <= NativeC03WakeGeometry.maximumTargetAngle
      else { return false }
      previousSequence = observed.sequence
      previousTime = observed.reading.physicalTime
    }
    return true
  }

  func preservesHistory(of old: Self) -> Bool {
    origin == old.origin && observations.starts(with: old.observations)
      && Mark.allCases.allSatisfy { mark in
        guard let before = old.latest(mark), let after = latest(mark) else { return false }
        return after.revision >= before.revision
          && (after.revision != before.revision || after == before)
          && old.admissions.filter({ $0.mark == mark && $0.revision == 1 }).allSatisfy(admissions.contains)
      }
  }
}

extension NativeHollowManifestState {
  /// Historical reducer only. Actual native preparation or the live observer must authenticate
  /// and publish its candidate. Every newly retained operation consumes this source's sequence.
  func retainingWakeTrail(_ trail: NativeC03WakeTrail) throws -> Self {
    guard shapeValid, laboratory != nil, phase == .admitted,
      wakeTrail.map({ trail.preservesHistory(of: $0) }) ?? true
    else { throw Failure.invalidState }
    let previous = Set(wakeTrail?.sequences ?? [])
    let added = trail.sequences.filter { !previous.contains($0) }.sorted()
    guard !added.isEmpty, added.count <= 4,
      nextSourceSequence < UInt64(Int64.max) - UInt64(added.count),
      added == (0..<added.count).map({ nextSourceSequence + UInt64($0) })
    else { throw Failure.invalidState }
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + UInt64(added.count),
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory, wakeTrail: trail, custodyRegister: custodyRegister,
      crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}

extension NativeC03WakeTrail {
  /// Precommit scratch from the real adapter's sealed source and staged native cohort. This
  /// creates no Game actor; the native plan still must validate and commit before publication.
  static func preparingAdmission(
    context: NativeC03WakeAdmissionContext, admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> (state: NativeHollowManifestState, encounter: ScriptOwnedEncounter) {
    let state = context.pin.state
    guard let lab = state.laboratory, (1...3).contains(admitted.count),
      !context.initial || admitted.count == 3,
      Set(admitted.map(\.id)).count == admitted.count,
      Set(admitted.compactMap(\.missionActorID)).count == admitted.count,
      context.flight.nextActor <= UInt64.max - UInt64(admitted.count),
      context.flight.nextSpawn < UInt64.max,
      flight.system == context.flight.system, flight.visit == context.flight.visit,
      flight.pose == context.flight.pose, flight.physicalTime == context.flight.physicalTime,
      flight.nextActor == context.flight.nextActor + UInt64(admitted.count),
      flight.nextSpawn == context.flight.nextSpawn + 1,
      state.nextSourceSequence < UInt64(Int64.max) - 4
    else { throw SaveError.invalidCommander }
    var next = state.nextSourceSequence
    let origin: Origin
    if context.initial {
      origin = .init(
        mission: context.pin.missionID, owner: context.pin.owner,
        source: source(mission: context.pin.missionID, laboratory: lab.operation),
        laboratory: lab.operation, originalKit: lab.facts.originalKit,
        anchors: context.anchors, reference: context.reference,
        sequence: next, physicalTime: flight.physicalTime)
      next += 1
    } else {
      guard let old = state.wakeTrail else { throw SaveError.invalidCommander }
      origin = old.origin
    }
    var entries = state.wakeTrail?.admissions ?? []
    var owned = context.retention
    for mark in Mark.allCases {
      let logical = logicalActor(mission: context.pin.missionID, mark: mark)
      guard let body = admitted.first(where: { $0.missionActorID == logical }) else { continue }
      guard var actor = owned.actors[mark.rawValue], actor.identity == logical,
        body.missionInstanceID == context.pin.missionID, let physical = body.physical,
        physical.identity.system == flight.system, physical.identity.visit == flight.visit,
        (context.flight.nextActor..<flight.nextActor).contains(physical.identity.entity),
        let spawn = physical.spawnIdentity, spawn.system == flight.system,
        spawn.visit == flight.visit, spawn.sequence == context.flight.nextSpawn,
        spawn.producer == .mission,
        let geometry = body.scriptNPC?.fit.models[mark.model],
        body.scriptNPC?.fit.definition == NativeC03WakeGeometry.profile(mark),
        context.initial ? actor.presence == .prepared : [.outside, .unloaded].contains(actor.presence),
        body.energy > 0
      else { throw SaveError.invalidCommander }
      let expected = context.projections[logical]?.body ?? actor.body
      let expectedPosition = context.station.position
        + context.station.orientation.apply(expected.position)
      let expectedOrientation = expected.orientation.transformed(by: context.station.orientation)
      guard (body.position - expectedPosition).length < 1e-7,
        (body.orientation.x - expectedOrientation.x).length < 1e-9,
        (body.orientation.y - expectedOrientation.y).length < 1e-9,
        (body.orientation.z - expectedOrientation.z).length < 1e-9,
        body.energy == expected.energy, body.rotation == expected.rotation,
        body.rotationRate == expected.rotationRate
      else { throw SaveError.invalidCommander }
      let revision = (state.wakeTrail?.latest(mark)?.revision ?? 0) + 1
      entries.append(.init(
        mark: mark, revision: revision, fragment: fragment(source: origin.source, mark: mark),
        logicalActor: logical, actor: physical.identity, spawn: spawn, geometry: geometry,
        sequence: next, physicalTime: flight.physicalTime))
      next += 1
      actor.body = try capture(body, reference: context.reference, flight: flight)
      actor.presence = .present
      owned.actors[mark.rawValue] = actor
      if let old = context.projections[logical] {
        guard body.energy == old.body.energy, body.rotation == old.body.rotation,
          body.rotationRate == old.body.rotationRate,
          physical.velocity == old.historicalPhysical.velocity,
          physical.angularVelocity == old.historicalPhysical.angularVelocity,
          physical.canonicalSpin == old.historicalPhysical.canonicalSpin,
          physical.laserCooldown == old.historicalPhysical.laserCooldown,
          sameRetainedCondition(physical.npc, old.historicalPhysical.npc)
        else { throw SaveError.invalidCommander }
      }
    }
    let observations = state.wakeTrail?.observations ?? []
    entries = entries.filter { item in
      item.revision == 1 || observations.contains(where: { $0.admission == item })
        || item.revision == entries.filter({ $0.mark == item.mark }).map(\.revision).max()
    }
    let trail = Self(origin: origin, admissions: entries, observations: observations)
    owned.admitted = true
    return (try state.retainingWakeTrail(trail), owned)
  }

  /// Frame projection only; no integration, repair, power refill or new physical identity.
  static func capture(_ body: SpaceBody, reference: ShipPose, flight: FlightSimulationState) throws
    -> SpaceBody
  {
    guard flight.valid, reference.position.finite, reference.orientation.validRotation,
      body.position.finite, body.orientation.validRotation, body.rotation.isFinite,
      body.rotationRate.isFinite, let physical = body.physical, let npc = body.scriptNPC,
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

  /// The existing native admission policy alone clears stale AI targets. Preserve all other
  /// condition exactly, including resources; this comparison cannot authorize a cleanup itself.
  private static func sameRetainedCondition(_ new: NPCState?, _ old: NPCState?) -> Bool {
    guard var new, let old else { return new == old }
    new.firstAggressor = old.firstAggressor
    new.intention = old.intention
    return new == old
  }
}
