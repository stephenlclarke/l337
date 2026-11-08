import Foundation

/// Matches the existing emitter's bounds. This arithmetic grants no effect or event rights.
enum NativeC03CrewCaptureEventCapacity {
  static func permits(next: UInt64, pending: Int, demand: Int) -> Bool {
    demand >= 0 && demand <= 2 && pending >= 0 && pending <= 4096 - demand
      && next <= UInt64(Int64.max) - 1 - UInt64(demand)
  }
}

private struct NativeC03CrewCaptureEvent: Sendable {
  let body: SpaceBody
  let alias: String
  let destroyed: Bool
}

private final class NativeC03CrewCapture: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let previousCustody: NativePeopleCustodyState
  let selectedCommander: CommanderSnapshot
  let flight: FlightSimulationState
  let observed: [SpaceBody]
  let death: NativeC03CrewDeathWitness?
  let events: [NativeC03CrewCaptureEvent]

  init(pin: NativeHollowManifestInstalledCase, previousCustody: NativePeopleCustodyState,
    flight: FlightSimulationState,
    observed: [SpaceBody], death: NativeC03CrewDeathWitness?, selectedCommander: Commander,
    events: [NativeC03CrewCaptureEvent])
  {
    self.pin = pin
    self.previousCustody = previousCustody
    self.flight = flight
    self.observed = observed
    self.death = death
    self.selectedCommander = CommanderSnapshot(selectedCommander)
    self.events = events
  }
}

extension Game {
  /// Recognition only. It can refuse unsafe removal but cannot issue a source or person.
  func c03EvacuationRecognizedBodyIDs() -> Set<Int> {
    guard let owner = commander.equipmentOwnerID else { return [] }
    let mission = NativeHollowManifestCommission.mission(owner: owner)
    let logical: Set<UUID> = [NativeC03CrewSourceState.logicalActor(mission: mission, launch: false),
      NativeC03CrewSourceState.logicalActor(mission: mission, launch: true)]
    return Set(bodies.filter {
      $0.missionInstanceID == mission && $0.missionActorID.map(logical.contains) == true
    }.map(\.id))
  }

  func isC03EvacuationBody(_ body: SpaceBody) -> Bool {
    c03EvacuationRecognizedBodyIDs().contains(body.id)
  }

  /// No physical state is written here. All source condition, people/places and the common
  /// loss receipt publish in one Commander replacement, never by restoring physical health.
  @inline(never)
  mutating func captureC03EvacuationActors(unloading: Bool = false) throws {
    retainC03CrewFatalObservation()
    if let captured = try prepareC03EvacuationCapture(unloading: unloading, removal: nil) {
      try publishC03EvacuationCapture(captured)
    }
  }

  /// Actual cull owner must pass its still-present body. The transition projects its existing
  /// removal event once, together with retention and custody, before later native cleanup.
  @inline(never)
  mutating func recordC03EvacuationRemoval(_ body: SpaceBody, destroyed: Bool) throws {
    guard bodies.filter({ $0.id == body.id }) == [body],
      destroyed == (body.energy == 0), body.energy.isFinite, body.energy >= 0
    else { throw SaveError.invalidCommander }
    retainC03CrewFatalObservation()
    if let captured = try prepareC03EvacuationCapture(unloading: false, removal: (body, destroyed)) {
      try publishC03EvacuationCapture(captured)
    }
  }

  @inline(never)
  private func prepareC03EvacuationCapture(
    unloading: Bool, removal: (body: SpaceBody, destroyed: Bool)?
  ) throws -> NativeC03CrewCapture? {
    guard systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      let previousCustody = commander.nativePeople, let original = previousCustody.hollowManifestCrew,
      let instance = hollowManifestMission
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    let flight = commander.flightSimulation
    guard flight.valid, let expected = instance.ownedEncounters[NativeC03CrewSourceState.encounter],
      sourceWorldMatches(original, instance: instance)
    else { throw SaveError.invalidCommander }
    var updated = expected
    var observed: [SpaceBody] = []
    var death: NativeC03CrewDeathWitness?
    var events: [NativeC03CrewCaptureEvent] = []
    for launch in [false, true] {
      let target = launch ? NativeC03CrewSourceState.launchTarget : NativeC03CrewSourceState.carrierTarget
      guard var actor = updated.actors[target],
        let binding = original.nativeBindings.first(where: { $0.launch == launch })
      else { throw SaveError.invalidCommander }
      guard actor.presence == .present else {
        if let removal, removal.body.missionActorID == actor.identity {
          guard actor.presence == .destroyed, removal.destroyed,
            removal.body.physical?.identity == binding.actor,
            removal.body.physical?.spawnIdentity == binding.spawn,
            actor.body.physical?.deathIncidentID == removal.body.physical?.deathIncidentID
          else { throw SaveError.invalidCommander }
        }
        continue
      }
      let matching = bodies.filter { $0.missionActorID == actor.identity }
      let body: SpaceBody
      let captureFlight: FlightSimulationState
      if matching.count == 1, let actual = matching.first {
        body = actual
        captureFlight = flight
        observed.append(actual)
      } else if matching.isEmpty, launch, let pending = c03CrewRuntime.pendingDeath,
        acceptsPendingC03CrewDeath(pending) {
        // Actual kernel/frame death was already witnessed before cleanup. Its frozen body
        // and native frame preserve that event; absence itself never creates a death.
        body = pending.body
        captureFlight = pending.flight
      } else { throw SaveError.invalidCommander }
      guard body.id == actor.body.id, body.missionInstanceID == instance.id,
        body.missionActorID == actor.identity, body.physical?.identity == binding.actor,
        body.physical?.spawnIdentity == binding.spawn,
        binding.actor.system == flight.system, binding.actor.visit == flight.visit,
        body.scriptNPC?.fit == actor.body.scriptNPC?.fit,
        body.energy.isFinite, body.energy >= 0
      else { throw SaveError.invalidCommander }
      if launch, body.energy == 0, original.loss == nil {
        guard let pending = c03CrewRuntime.pendingDeath, acceptsPendingC03CrewDeath(pending),
          pending.body.physical?.identity == body.physical?.identity,
          pending.body.physical?.deathIncidentID == body.physical?.deathIncidentID
        else { throw SaveError.invalidCommander }
        death = pending
      }
      actor.body = try NativeC03CrewSourceState.captureEvacuationBody(
        body, reference: original.registration.reference, flight: captureFlight)
      actor.presence = body.energy == 0 ? .destroyed : unloading ? .unloaded : .present
      if body.energy == 0 {
        actor.destroyedByPlayer = body.destroyedByPlayer == true
        events.append(.init(body: body, alias: actor.alias, destroyed: true))
      }
      if let removal, removal.body.missionActorID == actor.identity {
        guard removal.body == body else { throw SaveError.invalidCommander }
        actor.presence = removal.destroyed ? .destroyed : .outside
        if !removal.destroyed {
          events.append(.init(body: body, alias: actor.alias, destroyed: false))
        }
      }
      updated.actors[target] = actor
    }
    var custody = previousCustody
    if let death {
      try stageC03CrewNativeLoss(death, custody: &custody)
    }
    guard updated != expected || custody != previousCustody else { return nil }
    var selected = instance
    selected.ownedEncounters[NativeC03CrewSourceState.encounter] = updated
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    candidate.savedNativePeopleCustody = custody
    let demand = selected.outcome == .active ? events.count : 0
    guard NativeC03CrewCaptureEventCapacity.permits(next: candidate.scriptState.nextEvent,
      pending: candidate.scriptState.pendingEvents.count, demand: demand),
      NativeHollowManifestSave.validateClaims(candidate), custody.valid(commander: candidate),
      let budget = NativeC03CrewHistoryBudget.current(custody: custody, commander: candidate),
      budget.countsWithinLimits(custody)
    else { throw SaveError.invalidCommander }
    return .init(pin: pin, previousCustody: previousCustody,
      flight: flight, observed: observed, death: death, selectedCommander: candidate, events: events)
  }

  private func sourceWorldMatches(_ source: NativeC03CrewSourceState, instance: ScriptInstance) -> Bool {
    source.mission == instance.id && instance.savedHollowManifest?.crewSource == source.missionReference
      && source.owner == commander.equipmentOwnerID
  }

  private func stageC03CrewNativeLoss(
    _ witness: NativeC03CrewDeathWitness, custody: inout NativePeopleCustodyState
  ) throws {
    guard acceptsPendingC03CrewDeath(witness), var source = custody.hollowManifestCrew,
      source.loss == nil, source.registration == witness.source.registration,
      let physical = witness.body.physical, let spawn = physical.spawnIdentity,
      let incident = physical.deathIncidentID,
      let player = commander.flightSimulation.player,
      player.system == physical.identity.system, player.visit == physical.identity.visit,
      let beforeBudget = NativeC03CrewHistoryBudget.current(custody: custody, commander: commander),
      beforeBudget.terminalContribution == 0, beforeBudget.countsWithinLimits(custody),
      custody.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let operation = ScriptIdentity.uuid(
      "c03-original-six-crew-native-loss-v1:\(source.source):\(incident):\(try NativeFlightReception.hash(physical.identity))")
    guard !custody.transfers.contains(where: { $0.operation == operation }) else {
      throw SaveError.invalidCommander
    }
    let cash = commander.credits
    let slaves = commander.cargo[CommodityIdentity.slaves.rawValue]
    let revision = custody.revision + 1
    let receipt = NativePeopleTransferReceipt(operation: operation, members: source.references,
      kind: .loss, dock: nil, collector: player, owner: source.owner,
      physicalTime: witness.flight.physicalTime, calendarSeconds: witness.calendarSeconds,
      beforeCash: cash, afterCash: cash, beforeSlaves: slaves, afterSlaves: slaves,
      price: 0, epoch: witness.epoch, revision: revision)
    source.loss = .init(transfer: operation, actor: physical.identity, spawn: spawn,
      incident: incident, origin: physical.deathOrigin,
      physicalTime: witness.flight.physicalTime, epoch: witness.epoch)
    for index in source.hardware.ownedBerths.indices {
      source.hardware.ownedBerths[index].use = .empty
    }
    source.operatingPlaces = []
    custody.hollowManifestCrew = source
    custody.transfers.append(receipt)
    custody.revision = revision
    // Exactly one actual terminal contribution is staged. The full candidate source/death,
    // ordinary budgets and revision-set joins are checked before any Commander publication.
  }

  @inline(never)
  private mutating func publishC03EvacuationCapture(_ captured: NativeC03CrewCapture) throws {
    let demand = captured.selectedCommander.value.scriptState.instances[captured.pin.missionID]?
      .outcome == .active ? captured.events.count : 0
    guard acceptsHollowManifestInstalledCase(captured.pin),
      commander.nativePeople == captured.previousCustody, commander.flightSimulation == captured.flight,
      captured.observed.allSatisfy({ body in bodies.filter({ $0.id == body.id }) == [body] }),
      NativeC03CrewCaptureEventCapacity.permits(next: commander.scriptState.nextEvent,
        pending: commander.scriptState.pendingEvents.count, demand: demand)
    else { throw NativeMissionActorAdmissionError.stalePlan }
    if let death = captured.death, !acceptsPendingC03CrewDeath(death) {
      throw NativeMissionActorAdmissionError.stalePlan
    }
    // Publish the already validated source, encounter and common history in one replacement.
    commander = captured.selectedCommander.value
    for event in captured.events {
      guard let identity = event.body.missionActorID else { continue }
      emitScriptEvent(event.destroyed ? "actor.destroyed" : "actor.removed", values: [
        "actor_id": .string(identity.uuidString), "alias": .string(event.alias),
        "encounter_id": .string(NativeC03CrewSourceState.encounter),
        "destroyed_by_player": .bool(event.body.destroyedByPlayer == true),
      ], only: captured.pin.missionID, drain: false)
    }
    // Keep the opaque actual observation until the real writer acknowledges these records.
  }
}
