import Foundation

/// A live projection only. Saved records and probe readings cannot construct this source.
private final class NativeC03WakeObservationSource {
  let pin: NativeHollowManifestInstalledCase
  let kit: NativeHollowManifestKitBinding
  let admission: NativeC03WakeTrail.Admission
  let owned: ScriptOwnedActor
  let body: SpaceBody
  let player: ActorIdentity
  let instrument: OwnedEquipmentItem
  let epoch: UUID
  let frame: UInt64
  let flight: FlightSimulationState

  init(
    pin: NativeHollowManifestInstalledCase, kit: NativeHollowManifestKitBinding,
    admission: NativeC03WakeTrail.Admission, owned: ScriptOwnedActor, body: SpaceBody,
    player: ActorIdentity, instrument: OwnedEquipmentItem, epoch: UUID,
    frame: UInt64, flight: FlightSimulationState
  ) {
    self.pin = pin
    self.kit = kit
    self.admission = admission
    self.owned = owned
    self.body = body
    self.player = player
    self.instrument = instrument
    self.epoch = epoch
    self.frame = frame
    self.flight = flight
  }
}

extension Game {
  /// Menu eligibility does not run the physical scan or create evidence.
  var hollowManifestWakeTarget: ActorIdentity? {
    (try? currentHollowManifestWakeObservationSource())?.admission.actor
  }

  @inline(never)
  private func currentHollowManifestWakeObservationSource() throws -> NativeC03WakeObservationSource {
    guard !docked, !paused, screen == .front, !isMissionTrial, trialTitle == nil,
      !playerEMPDisabled, energy.isFinite, energy > 0, jumpCountdown == nil,
      pendingNativeStationDock == nil, scriptDurabilityAvailable, gameplayRevision > 0,
      systemIdentity == NativeC03WakeGeometry.world,
      let instance = hollowManifestMission, instance.outcome == .active, instance.suspension == nil,
      instance.milestones == [0, 1, 2],
      let trail = instance.savedHollowManifest?.wakeTrail, let mark = trail.nextMark,
      let admission = trail.latest(mark),
      let owned = instance.ownedEncounters[NativeC03WakeTrail.encounter]?.actors[mark.rawValue],
      owned.presence == .present, owned.identity == admission.logicalActor,
      let target = informationTargetBody?.id ?? weaponsTargetID, target == owned.body.id,
      bodies.filter({ $0.id == target }).count == 1,
      let body = bodies.first(where: { $0.id == target }), body.energy > 0, body.position.z > 0,
      atan2(hypot(body.position.x, body.position.y), body.position.z)
        <= NativeC03WakeGeometry.maximumTargetAngle,
      body.missionActorID == owned.identity, body.missionInstanceID == instance.id,
      let physical = body.physical, physical.identity == admission.actor,
      physical.spawnIdentity == admission.spawn, physical.population == .mission,
      physical.npc?.resources?.electrical?.disabledAt == nil,
      body.scriptNPC?.fit == owned.body.scriptNPC?.fit,
      let inventory = commander.equipmentInventory,
      let fitted = commander.fittedEquipment(at: .targetingCore),
      let instrument = inventory.items.first(where: { $0.id == fitted.id }), instrument == fitted,
      inventory.items.filter({ $0.id == fitted.id }).count == 1,
      instrument.location == .init(hullInstanceID: inventory.activeHull, slot: .targetingCore),
      TargetingTier.from(instrument.node.key) != nil,
      commander.hullInstanceID == inventory.activeHull,
      let player = commander.flightSimulation.player, player.entity == 0,
      player.system == admission.actor.system, player.visit == admission.actor.visit
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    let kit = try NativeHollowManifestKitCustody.resolve(instance: instance, commander: commander)
    guard kit.carrier == inventory.activeHull, kit.owner == inventory.owner,
      kit.inventoryRevision == inventory.revision, kit.serial == trail.origin.originalKit,
      acceptsHollowManifestInstalledCase(pin)
    else { throw EquipmentIssueError.staleObligation }
    return .init(
      pin: pin, kit: kit, admission: admission, owned: owned, body: body, player: player,
      instrument: instrument, epoch: nativeStationRuntimeEpoch,
      frame: gameplayRevision, flight: commander.flightSimulation)
  }

  /// One explicit scan command owns one real physical snapshot. There is no dwell, timer,
  /// continuous visibility or synthetic frame claim. Full writer failure rolls it all back.
  @inline(never)
  mutating func recordHollowManifestWakeObservation() throws {
    let source = try currentHollowManifestWakeObservationSource()
    guard let reading = try NativeC03WakeProbe.measure(
      in: self, bodyID: source.body.id, mark: source.admission.mark, origin: .init(0, 0, 0)),
      reading.actor == source.admission.actor, reading.pose == modelPose(of: source.body),
      reading.physicalTime == source.flight.physicalTime,
      acceptsHollowManifestInstalledCase(source.pin),
      commander.flightSimulation == source.flight,
      nativeStationRuntimeEpoch == source.epoch, gameplayRevision == source.frame,
      bodies.first(where: { $0.id == source.body.id }) == source.body,
      let instance = hollowManifestMission,
      try NativeHollowManifestKitCustody.resolve(instance: instance, commander: commander) == source.kit,
      let trail = source.pin.state.wakeTrail, trail.nextMark == source.admission.mark,
      source.pin.state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = source.pin.state.nextSourceSequence
    let instrument = NativeC03WakeTrail.Instrument(
      item: source.instrument.id, node: source.instrument.node,
      location: .init(hullInstanceID: source.kit.carrier, slot: .targetingCore))
    let operation = try NativeC03WakeTrail.observationIdentity(
      source: trail.origin.source, admission: source.admission, player: source.player,
      kit: source.kit.serial, carrier: source.kit.carrier, issueCommand: source.kit.issueCommand,
      inventoryRevision: source.kit.inventoryRevision, instrument: instrument,
      epoch: source.epoch, frame: source.frame, sequence: sequence, reading: reading)
    let observation = NativeC03WakeTrail.Observation(
      operation: operation, admission: source.admission, player: source.player,
      carrier: source.kit.carrier, originalKit: source.kit.serial, issueCommand: source.kit.issueCommand,
      inventoryRevision: source.kit.inventoryRevision, instrument: instrument,
      epoch: source.epoch, frame: source.frame, sequence: sequence, reading: reading)
    let next = NativeC03WakeTrail(
      origin: trail.origin, admissions: trail.admissions, observations: trail.observations + [observation])
    var selected = instance
    selected.savedHollowManifest = try source.pin.state.retainingWakeTrail(next)
    if next.observations.count == 3 {
      selected.receipts.insert(NativeC03WakeTrail.receipt)
      selected.milestones.insert(3)
      selected.journal.append(NativeC03WakeTrail.dialogue)
    }
    selected.revision += 1
    selected.ownedEncounters[NativeC03WakeTrail.encounter]?.actors[source.admission.mark.rawValue]?
      .body = try NativeC03WakeTrail.capture(
        source.body, reference: trail.origin.reference, flight: source.flight)
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard candidate.equipmentInventory == commander.equipmentInventory,
      candidate.credits == commander.credits, NativeHollowManifestSave.validateClaims(candidate)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}

extension GameRuntime {
  /// Called by the explicit native mission menu action, not a generic Lua event or timer.
  func handleHollowManifestWakeKey(_ key: String) -> Bool {
    guard key == "original-wake-scan" else { return false }
    guard scriptSaveURL != nil, galleryNamespace == nil, galleryParent == nil,
      game.hollowManifestWakeTarget != nil
    else { return true }
    do {
      try scriptCommand { try $0.recordHollowManifestWakeObservation() }
      let count = game.hollowManifestMission?.savedHollowManifest?.wakeTrail?.observations.count ?? 0
      game.notify(count == 3
        ? "THREE ORIGINAL WAKE MARKS RECORDED - RECOVER THE REGISTER AT DURENRAN"
        : "ORIGINAL WAKE MARK RECORDED - FOLLOW THE NEXT MARK")
    } catch {
      game.notify("WAKE SCAN NOT COMMITTED - KEEP THE ORIGINAL KIT AND REACQUIRE THE MARK", voiced: false)
    }
    return true
  }
}
