import Foundation

/// Bounded attempt-local observations, not another simulator or person ledger. G1 owns
/// its Game storage/tick/actual-writer-ack coupling; neither observation is saved as proof.
struct NativeC03CrewRuntime: Sendable {
  var before: NativeC03CrewFatalBefore?
  var pendingDeath: NativeC03CrewDeathWitness?
}

/// Actual live before observation, captured only by Game before its existing native tick.
/// This is neither a clock/mover nor a continuous-contact/arrival certificate.
final class NativeC03CrewFatalBefore: Sendable {
  let registration: NativeC03CrewSourceState.Registration
  let admission: NativeC03CrewSourceState.NativeBinding
  let body: SpaceBody
  let native: MissionActorBinding
  let flight: FlightSimulationState
  let epoch: UUID

  fileprivate init(registration: NativeC03CrewSourceState.Registration,
    admission: NativeC03CrewSourceState.NativeBinding, body: SpaceBody,
    native: MissionActorBinding, flight: FlightSimulationState, epoch: UUID)
  {
    self.registration = registration
    self.admission = admission
    self.body = body
    self.native = native
    self.flight = flight
    self.epoch = epoch
  }
}

enum NativeC03CrewDeathCause: Sendable {
  case nativeReceipt(NativeMissionImpactReceipt)
  case positiveFrame(NativeC03CrewFatalBefore)
}

/// Only these two real observations can create the attempt-local loss witness. Decoded
/// death facts, arbitrary health/counter values and actor absence never construct one.
final class NativeC03CrewDeathWitness: Sendable {
  let cause: NativeC03CrewDeathCause
  let pin: NativeHollowManifestInstalledCase
  let custody: NativePeopleCustodyState
  let source: NativeC03CrewSourceState
  let body: SpaceBody
  let flight: FlightSimulationState
  let epoch: UUID
  let calendarSeconds: Double

  fileprivate init(cause: NativeC03CrewDeathCause, pin: NativeHollowManifestInstalledCase,
    custody: NativePeopleCustodyState, source: NativeC03CrewSourceState,
    body: SpaceBody, flight: FlightSimulationState, epoch: UUID, calendarSeconds: Double)
  {
    self.cause = cause
    self.pin = pin
    self.custody = custody
    self.source = source
    self.body = body
    self.flight = flight
    self.epoch = epoch
    self.calendarSeconds = calendarSeconds
  }
}

extension Game {
  mutating func beginC03CrewFatalObservation() {
    c03CrewRuntime.before = c03CrewFatalBeforeObservation()
  }

  mutating func retainC03CrewFatalObservation() {
    if c03CrewRuntime.pendingDeath == nil, let before = c03CrewRuntime.before,
      let witness = c03CrewDeathWitness(from: before)
    { c03CrewRuntime.pendingDeath = witness }
  }

  mutating func endC03CrewFatalObservation() {
    retainC03CrewFatalObservation()
    c03CrewRuntime.before = nil
  }

  mutating func retainC03CrewNativeImpact(_ receipt: NativeMissionImpactReceipt) {
    if c03CrewRuntime.pendingDeath == nil, let witness = c03CrewDeathWitness(from: receipt) {
      c03CrewRuntime.pendingDeath = witness
    }
  }

  func c03CrewFatalBeforeObservation() -> NativeC03CrewFatalBefore? {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      let pin = try? hollowManifestInstalledCase(),
      let custody = commander.nativePeople, let source = custody.hollowManifestCrew,
      source.loss == nil,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      let admission = source.nativeBindings.first(where: \.launch),
      let actor = hollowManifestMission?.ownedEncounters[NativeC03CrewSourceState.encounter]?
        .actors[NativeC03CrewSourceState.launchTarget], actor.presence == .present,
      let body = bodies.first(where: { $0.id == actor.body.id }), body.energy > 0,
      bodies.filter({ $0.missionActorID == actor.identity }) == [body],
      body.physical?.identity == admission.actor, body.physical?.spawnIdentity == admission.spawn,
      body.physical?.deathIncidentID == nil, body.physical?.deathOrigin == nil,
      let descriptor = currentMissionActorDescriptor(bodyID: body.id),
      let context = gameplayContext(),
      let native = try? MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context),
      native.nativeActor == admission.actor, acceptsHollowManifestInstalledCase(pin)
    else { return nil }
    return .init(registration: source.registration, admission: admission, body: body,
      native: native, flight: commander.flightSimulation, epoch: nativeStationRuntimeEpoch)
  }

  func c03CrewDeathWitness(from receipt: NativeMissionImpactReceipt) -> NativeC03CrewDeathWitness? {
    guard receipt.damageAdmitted, receipt.hullDestroyed, receipt.damage.isFinite, receipt.damage > 0,
      receipt.victimPart == nil, receipt.victimComponentID == nil,
      let id = receipt.targetBodyID, let event = receipt.eventID,
      let body = bodies.first(where: { $0.id == id }),
      receipt.targetMissionInstanceID == body.missionInstanceID,
      receipt.targetMissionActorID == body.missionActorID,
      body.physical?.deathIncidentID == event, body.physical?.deathOrigin == receipt.originalOrigin
    else { return nil }
    return c03CrewDeathWitness(cause: .nativeReceipt(receipt), body: body)
  }

  func c03CrewDeathWitness(from before: NativeC03CrewFatalBefore) -> NativeC03CrewDeathWitness? {
    let flight = commander.flightSimulation
    let duration = flight.physicalTime - before.flight.physicalTime
    guard before.epoch == nativeStationRuntimeEpoch,
      before.flight.system == flight.system, before.flight.visit == flight.visit,
      duration.isFinite, duration > 0, duration <= 0.1 + 1e-9,
      flight.nextIncident > before.flight.nextIncident,
      before.body.energy > 0, before.body.physical?.deathIncidentID == nil,
      before.native.nativeActor == before.admission.actor,
      let body = bodies.first(where: { $0.id == before.body.id }),
      body.missionActorID == before.body.missionActorID,
      body.physical?.identity == before.admission.actor,
      body.physical?.spawnIdentity == before.admission.spawn,
      let incident = body.physical?.deathIncidentID,
      incident >= before.flight.nextIncident, incident < flight.nextIncident,
      let source = commander.nativePeople?.hollowManifestCrew,
      source.registration == before.registration,
      source.nativeBindings.first(where: \.launch) == before.admission
    else { return nil }
    return c03CrewDeathWitness(cause: .positiveFrame(before), body: body)
  }

  private func c03CrewDeathWitness(cause: NativeC03CrewDeathCause, body: SpaceBody)
    -> NativeC03CrewDeathWitness?
  {
    let flight = commander.flightSimulation
    guard flight.valid, !docked, systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      commander.scriptState.calendarSeconds.isFinite, commander.scriptState.calendarSeconds >= 0,
      let pin = try? hollowManifestInstalledCase(), let custody = commander.nativePeople,
      let source = custody.hollowManifestCrew, source.loss == nil,
      source.mission == pin.missionID, pin.state.crewSource == source.missionReference,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      let admission = source.nativeBindings.first(where: \.launch),
      body.missionInstanceID == source.mission,
      body.missionActorID == NativeC03CrewSourceState.logicalActor(mission: source.mission, launch: true),
      bodies.filter({ $0.id == body.id }) == [body],
      bodies.filter({ $0.missionActorID == body.missionActorID }) == [body],
      body.energy == 0, let physical = body.physical,
      physical.identity == admission.actor, physical.spawnIdentity == admission.spawn,
      physical.identity.system == flight.system, physical.identity.visit == flight.visit,
      let incident = physical.deathIncidentID, incident > 0, incident < flight.nextIncident,
      let retained = hollowManifestMission?.ownedEncounters[NativeC03CrewSourceState.encounter]?
        .actors[NativeC03CrewSourceState.launchTarget], retained.presence == .present,
      retained.body.id == body.id, retained.body.energy > 0,
      retained.body.physical?.identity == physical.identity,
      retained.body.physical?.spawnIdentity == physical.spawnIdentity,
      retained.body.scriptNPC?.fit == body.scriptNPC?.fit,
      acceptsHollowManifestInstalledCase(pin)
    else { return nil }
    if let origin = physical.deathOrigin {
      guard origin.owner.system == flight.system, origin.owner.visit > 0,
        origin.owner.visit <= flight.visit, origin.owner.entity < flight.nextActor,
        origin.emissionID > 0, origin.emissionID < flight.nextEmission,
        origin.emittedAt.isFinite, (0...flight.physicalTime).contains(origin.emittedAt)
      else { return nil }
    }
    return .init(cause: cause, pin: pin, custody: custody, source: source,
      body: body, flight: flight, epoch: nativeStationRuntimeEpoch,
      calendarSeconds: commander.scriptState.calendarSeconds)
  }

  func acceptsC03CrewDeathWitness(_ witness: NativeC03CrewDeathWitness) -> Bool {
    let current: NativeC03CrewDeathWitness?
    switch witness.cause {
    case .nativeReceipt(let receipt): current = c03CrewDeathWitness(from: receipt)
    case .positiveFrame(let before): current = c03CrewDeathWitness(from: before)
    }
    guard let current, acceptsHollowManifestInstalledCase(witness.pin) else { return false }
    return current.custody == witness.custody && current.source == witness.source
      && current.body == witness.body && current.flight == witness.flight && current.epoch == witness.epoch
      && current.calendarSeconds == witness.calendarSeconds
  }

  /// Publication retries use the original opaque observation, not a later zero-HP scan or
  /// a new death timestamp. Unrelated frame/record activity must not erase that actual death.
  func acceptsPendingC03CrewDeath(_ witness: NativeC03CrewDeathWitness) -> Bool {
    guard c03CrewRuntime.pendingDeath === witness,
      witness.epoch == nativeStationRuntimeEpoch,
      !docked, systemIdentity == witness.flight.system,
      commander.flightSimulation.visit == witness.flight.visit,
      commander.flightSimulation.physicalTime >= witness.flight.physicalTime,
      commander.scriptState.calendarSeconds.isFinite,
      commander.scriptState.calendarSeconds >= witness.calendarSeconds,
      let pin = try? hollowManifestInstalledCase(),
      let custody = commander.nativePeople, let source = custody.hollowManifestCrew,
      source.loss == nil, source.registration == witness.source.registration,
      source.nativeBindings.first(where: \.launch) == witness.source.nativeBindings.first(where: \.launch),
      source.hardware == witness.source.hardware, source.operatingPlaces == witness.source.operatingPlaces,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      let physical = witness.body.physical,
      physical.deathIncidentID != nil, witness.body.energy == 0,
      let retained = hollowManifestMission?.ownedEncounters[NativeC03CrewSourceState.encounter]?
        .actors[NativeC03CrewSourceState.launchTarget],
      retained.presence == .present, retained.body.energy > 0,
      retained.identity == witness.body.missionActorID,
      retained.body.physical?.identity == physical.identity,
      retained.body.physical?.spawnIdentity == physical.spawnIdentity,
      acceptsHollowManifestInstalledCase(pin)
    else { return false }
    let current = bodies.filter { $0.missionActorID == witness.body.missionActorID }
    if current.isEmpty {
      // The original witnessed death remains valid after actual cleanup. Absence without
      // this exact pending kernel/frame witness never enters this branch.
      return true
    }
    guard current.count == 1, let body = current.first,
      body.energy == 0, body.id == witness.body.id,
      body.missionInstanceID == witness.body.missionInstanceID,
      body.physical?.identity == physical.identity,
      body.physical?.spawnIdentity == physical.spawnIdentity,
      body.physical?.deathIncidentID == physical.deathIncidentID,
      body.physical?.deathOrigin == physical.deathOrigin,
      body.scriptNPC?.fit == witness.body.scriptNPC?.fit
    else { return false }
    return true
  }

  /// Only the real successful writer acknowledgement may call this. Failed publication or
  /// disk write leaves the one opaque witness available; it never restores physical health.
  mutating func acknowledgeC03CrewDeathPersistence() {
    guard !isMissionTrial, trialTitle == nil,
      let witness = c03CrewRuntime.pendingDeath, witness.epoch == nativeStationRuntimeEpoch,
      let source = commander.nativePeople?.hollowManifestCrew, let loss = source.loss,
      source.registration == witness.source.registration,
      loss.actor == witness.body.physical?.identity,
      loss.spawn == witness.body.physical?.spawnIdentity,
      loss.incident == witness.body.physical?.deathIncidentID,
      loss.origin == witness.body.physical?.deathOrigin,
      loss.physicalTime == witness.flight.physicalTime, loss.epoch == witness.epoch,
      let custody = commander.nativePeople,
      let transfer = custody.transfers.first(where: { $0.operation == loss.transfer }),
      transfer.calendarSeconds == witness.calendarSeconds,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander)
    else { return }
    c03CrewRuntime.pendingDeath = nil
  }
}
