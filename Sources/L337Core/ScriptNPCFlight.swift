import Foundation

extension Game {
  mutating func applyScriptNPCIntent(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance
  ) throws -> (String, [String: ScriptValue])? {
    guard pack.manifest.capabilities.contains("profiled-encounters-v2"), state.outcome == .active,
      let fields = command.object,
      Set(fields.keys).isSubset(of: [
        "op", "id", "encounter", "actor", "mode", "target", "offset", "speed", "tolerance",
      ]),
      let request = fields["id"]?.string, PackValidation.localID(request),
      let encounterID = fields["encounter"]?.string, let alias = fields["actor"]?.string,
      let modeName = fields["mode"]?.string, let mode = ScriptNPCIntentMode(rawValue: modeName),
      let speed = fields["speed"]?.double, let tolerance = fields["tolerance"]?.double,
      let coordinates = fields["offset"]?.array, coordinates.count == 3,
      let x = coordinates[0].double, let y = coordinates[1].double, let z = coordinates[2].double,
      var encounter = state.ownedEncounters[encounterID], var actor = encounter.actors[alias],
      ![.destroyed, .inTransit, .arrivalPending].contains(actor.presence),
      var npc = actor.body.scriptNPC
    else { throw MissionPackError("A flight request requires a declared owned profiled NPC.") }
    let receipt = "intent-" + request
    if state.receipts.contains(receipt) { return nil }
    let targetName = fields["target"]?.string
    let player = targetName == "player"
    var target: UUID?
    if let targetName, !player {
      let candidates = state.ownedEncounters.values.flatMap { $0.actors.values }.filter {
        $0.alias == targetName && $0.identity != actor.identity && $0.presence != .destroyed
      }
      guard candidates.count == 1 else {
        throw MissionPackError("Flight targets must identify one distinct owned actor or player.")
      }
      target = candidates[0].identity
    }
    let intent = ScriptNPCIntent(
      request: request, mode: mode, target: target, player: player,
      offset: .init(x, y, z), speed: speed, tolerance: tolerance)
    guard intent.valid else { throw MissionPackError("Invalid flight intent or target.") }
    npc.intent = intent
    actor.body.scriptNPC = npc
    encounter.actors[alias] = actor
    state.ownedEncounters[encounterID] = encounter
    if let index = bodies.firstIndex(where: { $0.missionActorID == actor.identity }) {
      bodies[index].scriptNPC?.intent = intent
    }
    state.receipts.insert(receipt)
    return (
      "actor.intent.accepted",
      [
        "actor_id": .string(actor.identity.uuidString),
        "request": .string(request), "mode": .string(mode.rawValue),
      ]
    )
  }

  /// All actors observe the same post-camera snapshot; array order cannot change steering.
  mutating func advanceScriptNPCFlight(delta: Double, excluding: Set<ActorIdentity> = []) {
    let snapshot = bodies
    let owned = Dictionary(
      snapshot.compactMap { body in
        body.missionActorID.map { ($0, body) }
      }, uniquingKeysWith: { first, _ in first })
    let station = snapshot.first { $0.id == 0 && $0.hull == .station }
    for index in bodies.indices {
      if let actor = bodies[index].physical?.identity, excluding.contains(actor) { continue }
      observeNativeTransitSpool(bodies[index])
      guard bodies[index].energy > 0, var npc = bodies[index].scriptNPC else { continue }
      let definition = npc.fit.definition
      // C01's native inertia already moved inside the physical sweep; no powered second pass.
      if c01SurveyorActor(bodies[index]) != nil || c01TimingStandardPart(bodies[index]) != nil
          || c01LaneRepairTarget(bodies[index]) != nil
          || c01ClinicCradleDeclared(bodies[index]) {
        continue
      }
      if bodies[index].physical?.npc?.resources?.profile != .nativeHull {
        bodies[index].energy = min(
          definition.energy, bodies[index].energy + definition.recharge * delta)
      }
      let guidance =
        c01ClinicGuidance(bodies[index], profile: definition, delta: delta)
        .map({ NativeArkDockGuidance(desired: $0.desired, orientation: $0.orientation) })
        ?? inductionArkDockGuidance(bodies[index], profile: definition, delta: delta)
        ?? inductionRescueDockGuidance(bodies[index], profile: definition, delta: delta)
      let decision = scriptNPCFlightDecision(
        bodies[index], npc: npc, owned: owned,
        station: station, guidance: guidance, delta: delta)
      bodies[index].orientation = decision.orientation
      if let pending = decision.pending {
        emitScriptNPCFlightResult(
          bodies[index], intent: pending.intent, kind: pending.kind.rawValue)
      }
      npc.intent = decision.intent
      npc.velocity = decision.translation.velocity
      bodies[index].position = decision.translation.end
      bodies[index].scriptNPC = npc
    }
    resolveC01ClinicMotion(before: snapshot, delta: delta)
    resolveInductionArkDockMotion(before: snapshot, delta: delta)
    resolveNativeTransitMotion(before: snapshot, delta: delta)
  }
  private mutating func emitScriptNPCFlightResult(
    _ body: SpaceBody, intent: ScriptNPCIntent, kind: String
  ) {
    guard let actor = body.missionActorID, let instance = body.missionInstanceID else { return }
    emitScriptEvent(
      kind,
      values: [
        "actor_id": .string(actor.uuidString),
        "request": .string(intent.request), "mode": .string(intent.mode.rawValue),
      ],
      only: instance, drain: false)
  }

  /// Consume only the real opening cohort after its physical paths have been
  /// retained. Motion is not integrated here, and T1 births are not in this set.
  mutating func commitCurrentNewtNPCDecisions(
    _ frame: CurrentNewtNPCFrame,
    evidence: CurrentNewtNativeClockEvidence? = nil, admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> Bool {
    guard nativeStationRuntimeEpoch == frame.epoch,
      commander.flightSimulation.system == frame.opening.system,
      commander.flightSimulation.visit == frame.opening.visit,
      commander.flightSimulation.physicalTime == frame.path.endTime
    else { return false }
    for body in bodies {
      guard let actor = body.physical?.identity, let entry = frame.entries[actor], body.energy > 0
      else { continue }
      if let legacy = entry.legacy {
        guard body.id == entry.bodyID, body.physical?.npc?.intention == legacy.intention,
          body.blackjackIdentity == legacy.blackjackIdentity, body.scriptNPC == nil
        else { return false }
        continue
      }
      guard body.id == entry.bodyID, body.missionActorID == entry.missionActor,
        body.missionInstanceID == entry.missionInstance,
        let original = entry.originalNPC, let npc = body.scriptNPC, npc.fit == original.fit,
        npc.intent == original.intent
      else { return false }
    }
    var birthView = admittedAtEnd
    for index in bodies.indices {
      guard let actor = bodies[index].physical?.identity, let entry = frame.entries[actor],
        let legacy = entry.legacy, bodies[index].energy > 0
      else { continue }
      // The actual full interval has been retained. No effect phase runs for a
      // T1 birth, and no old controller is called again for a mechanical cut.
      guard let evidence,
        let native = evidence.legacyEffectContext(
          for: actor, path: frame.path,
          admittedAtEnd: birthView)
      else { return false }
      _ = applyLegacyNPCFlightEffects(
        index: index, delta: frame.path.motion.duration,
        blackjackStartingDistance: legacy.start.length, native: native)
      if let births = birthView {
        if let accepted = native.acceptedCombat {
          guard let updated = births.accepting(accepted, in: self) else { return false }
          birthView = updated
        } else if let accepted = native.acceptedMission {
          guard let updated = births.accepting(accepted, in: self) else { return false }
          birthView = updated
        }
      }
    }
    for index in bodies.indices {
      guard let actor = bodies[index].physical?.identity, let entry = frame.entries[actor],
        bodies[index].energy > 0, var npc = bodies[index].scriptNPC,
        let decision = entry.decision
      else { continue }
      observeNativeTransitSpool(bodies[index])
      if bodies[index].physical?.npc?.resources?.profile != .nativeHull {
        let definition = npc.fit.definition
        bodies[index].energy = min(
          definition.energy,
          bodies[index].energy + definition.recharge * frame.path.motion.duration)
      }
      npc.intent = decision.intent
      if let velocity = bodies[index].physical?.velocity {
        npc.velocity = commander.flightSimulation.pose.shipVector(velocity)
      }
      bodies[index].scriptNPC = npc
      if let notice = decision.pending {
        emitScriptNPCFlightResult(bodies[index], intent: notice.intent, kind: notice.kind.rawValue)
      }
    }
    return true
  }
}
