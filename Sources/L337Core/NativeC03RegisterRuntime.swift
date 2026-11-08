import Foundation

/// Read-only projection of the sole native data owner through its REAL held original kit.
/// This view is not Codable and cannot be used to issue or move any data.
struct NativeC03HeldRegisterData: Sendable {
  let mission: UUID
  let kit: NativeHollowManifestKitBinding
  let transfer: UUID
  let contents: NativeC03CustodyRegisterContent
  let comparison: NativeC03RegisterComparison

  fileprivate init(
    mission: UUID, kit: NativeHollowManifestKitBinding,
    transfer: UUID, contents: NativeC03CustodyRegisterContent, comparison: NativeC03RegisterComparison
  ) {
    self.mission = mission
    self.kit = kit
    self.transfer = transfer
    self.contents = contents
    self.comparison = comparison
  }
}

private final class NativeC03ReadableRegisterSource {
  let pin: NativeHollowManifestInstalledCase
  let record: NativeC03RegisterState
  let admission: NativeC03RegisterState.Admission
  let kit: NativeHollowManifestKitBinding
  let body: SpaceBody
  let player: ActorIdentity
  let instrument: OwnedEquipmentItem
  let flight: FlightSimulationState
  let epoch: UUID
  let frame: UInt64

  init(
    pin: NativeHollowManifestInstalledCase, record: NativeC03RegisterState,
    admission: NativeC03RegisterState.Admission, kit: NativeHollowManifestKitBinding,
    body: SpaceBody, player: ActorIdentity,
    instrument: OwnedEquipmentItem, flight: FlightSimulationState, epoch: UUID, frame: UInt64
  ) {
    self.pin = pin
    self.record = record
    self.admission = admission
    self.kit = kit
    self.body = body
    self.player = player
    self.instrument = instrument
    self.flight = flight
    self.epoch = epoch
    self.frame = frame
  }
}

extension Game {
  var hollowManifestRegisterTarget: ActorIdentity? {
    (try? currentHollowManifestRegisterSource())?.admission.actor
  }

  /// The same original kit may travel or move to a different owned hull. Its current binding
  /// is mandatory; the historical transfer carrier/scene alone cannot supply held contents.
  func hollowManifestHeldRegisterData() throws -> NativeC03HeldRegisterData {
    let pin = try hollowManifestInstalledCase()
    guard let instance = hollowManifestMission, let record = pin.state.custodyRegister,
      let recovery = record.recovery
    else { throw SaveError.invalidCommander }
    let kit = try withReadOnlyCommander {
      try NativeHollowManifestKitCustody.resolve(instance: instance, commander: $0)
    }
    guard record.holder == .originalInspectionKit(kit.serial), record.sourceContents == nil,
      kit.serial == recovery.facts.originalKit, kit.issueCommand == recovery.facts.issueCommand,
      acceptsHollowManifestInstalledCase(pin)
    else { throw EquipmentIssueError.staleObligation }
    return .init(
      mission: instance.id, kit: kit, transfer: recovery.operation, contents: record.origin.contents,
      comparison: recovery.facts.comparison)
  }

  @inline(never)
  private func currentHollowManifestRegisterSource() throws -> NativeC03ReadableRegisterSource {
    guard !docked, !paused, screen == .front, !isMissionTrial, trialTitle == nil,
      !playerEMPDisabled, energy.isFinite, energy > 0, jumpCountdown == nil,
      pendingNativeStationDock == nil, scriptDurabilityAvailable, gameplayRevision > 0,
      systemIdentity == NativeHollowManifestDefinition.registerWorld,
      let instance = hollowManifestMission, instance.outcome == .active, instance.suspension == nil,
      instance.milestones == [0, 1, 2, 3],
      let state = instance.savedHollowManifest, state.phase == .admitted,
      let record = state.custodyRegister, record.sourceContents == record.origin.contents,
      record.holder == .originalArchive(record.origin.archive), let admission = record.latest,
      let owned = instance.ownedEncounters[NativeC03RegisterState.encounter]?
        .actors[NativeC03CustodyRegisterContent.target], owned.presence == .present,
      owned.identity == admission.logicalActor,
      let target = informationTargetBody?.id ?? weaponsTargetID, target == owned.body.id,
      bodies.filter({ $0.id == target }).count == 1,
      let body = bodies.first(where: { $0.id == target }), body.energy > 0,
      body.missionActorID == owned.identity, body.missionInstanceID == instance.id,
      let physical = body.physical, physical.identity == admission.actor,
      physical.spawnIdentity == admission.spawn, physical.population == .mission,
      physical.npc?.resources?.electrical?.disabledAt == nil,
      body.scriptNPC?.fit == owned.body.scriptNPC?.fit,
      let component = body.scriptNPC?.components[NativeC03RegisterGeometry.component],
      component.identity == admission.component, component.energy > 0,
      let inventory = withReadOnlyCommander({ $0.equipmentInventory }),
      let instrument = withReadOnlyCommander({ $0.fittedEquipment(at: .targetingCore) }),
      inventory.items.filter({ $0.id == instrument.id }) == [instrument],
      instrument.location == .init(hullInstanceID: inventory.activeHull, slot: .targetingCore),
      TargetingTier.from(instrument.node.key) != nil,
      withReadOnlyCommander({ $0.hullInstanceID == inventory.activeHull }),
      let player = withReadOnlyCommander({ $0.flightSimulation.player }), player.entity == 0,
      player.system == admission.actor.system, player.visit == admission.actor.visit
    else { throw SaveError.invalidCommander }
    let point = (body.position + body.modelVector(NativeC03RegisterGeometry.componentPosition))
    guard point.z > 0, atan2(hypot(point.x, point.y), point.z) <= NativeC03RegisterGeometry.maximumTargetAngle
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    let kit = try withReadOnlyCommander {
      try NativeHollowManifestKitCustody.resolve(instance: instance, commander: $0)
    }
    guard kit.serial == state.laboratory?.facts.originalKit, kit.owner == record.origin.owner,
      kit.carrier == inventory.activeHull, kit.inventoryRevision == inventory.revision,
      acceptsHollowManifestInstalledCase(pin)
    else { throw EquipmentIssueError.staleObligation }
    return .init(
      pin: pin, record: record, admission: admission, kit: kit, body: body,
      player: player, instrument: instrument, flight: withReadOnlyCommander({ $0.flightSimulation }),
      epoch: nativeStationRuntimeEpoch, frame: gameplayRevision)
  }

  /// Actual original data moves between the two projections of ONE native owner. Nothing is
  /// taken from the archive until its real kit receiver, physical face and full candidate join.
  @inline(never)
  mutating func recoverHollowManifestRegister() throws {
    let source = try currentHollowManifestRegisterSource()
    guard let reading = try NativeC03RegisterProbe.measure(
      in: self, bodyID: source.body.id, component: source.admission.component),
      reading.actor == source.admission.actor, reading.archivePose == modelPose(of: source.body),
      reading.observerPose == source.flight.pose, reading.physicalTime == source.flight.physicalTime,
      acceptsHollowManifestInstalledCase(source.pin),
      withReadOnlyCommander({ $0.flightSimulation == source.flight }),
      nativeStationRuntimeEpoch == source.epoch, gameplayRevision == source.frame,
      bodies.filter({ $0.id == source.body.id }) == [source.body],
      withReadOnlyCommander({ $0.fittedEquipment(at: .targetingCore) == source.instrument }),
      let instance = hollowManifestMission,
      try withReadOnlyCommander({
        try NativeHollowManifestKitCustody.resolve(instance: instance, commander: $0) == source.kit
      }),
      source.record.sourceContents == source.record.origin.contents,
      source.pin.state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let comparison = try NativeC03RegisterComparison.examining(
      source.pin.state, contents: source.record.origin.contents)
    let facts = NativeC03RegisterState.Recovery.Facts(
      source: source.record.origin.source, register: source.record.origin.contents.serial,
      contentsHash: try NativeFlightReception.hash(source.record.origin.contents), comparison: comparison,
      admission: source.admission, player: source.player, originalKit: source.kit.serial,
      issueCommand: source.kit.issueCommand, carrier: source.kit.carrier,
      inventoryRevision: source.kit.inventoryRevision,
      instrument: .init(item: source.instrument.id, node: source.instrument.node,
        location: .init(hullInstanceID: source.kit.carrier, slot: .targetingCore)),
      epoch: source.epoch, frame: source.frame,
      sequence: source.pin.state.nextSourceSequence, readout: reading)
    let recovery = NativeC03RegisterState.Recovery(
      operation: try NativeC03RegisterState.Recovery.identity(facts), facts: facts)
    let record = NativeC03RegisterState(
      origin: source.record.origin, admissions: source.record.admissions, recovery: recovery)
    var selected = instance
    selected.savedHollowManifest = try source.pin.state.retainingCustodyRegister(record)
    selected.receipts.insert(NativeC03RegisterState.receipt)
    selected.milestones.insert(4)
    selected.journal.append(NativeC03CustodyRegisterContent.dialogue)
    selected.revision += 1
    selected.ownedEncounters[NativeC03RegisterState.encounter]?
      .actors[NativeC03CustodyRegisterContent.target]?.body = try NativeC03RegisterState.capture(
        source.body, reference: record.origin.reference, flight: source.flight)
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    let receiver = try NativeHollowManifestKitCustody.resolve(instance: selected, commander: candidate)
    guard record.sourceContents == nil, record.holder == .originalInspectionKit(receiver.serial),
      receiver == source.kit, record.origin.contents == source.record.origin.contents,
      withReadOnlyCommander({
        candidate.equipmentInventory == $0.equipmentInventory && candidate.credits == $0.credits
      }),
      NativeHollowManifestSave.validateClaims(candidate)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}

extension GameRuntime {
  func handleHollowManifestRegisterKey(_ key: String) -> Bool {
    guard key == "original-register-recover" else { return false }
    guard scriptSaveURL != nil, galleryNamespace == nil, galleryParent == nil,
      game.hollowManifestRegisterTarget != nil
    else { return true }
    do {
      try scriptCommand { try $0.recoverHollowManifestRegister() }
      game.notify("ORIGINAL REGISTER SECURED IN THE ORIGINAL KIT - RESCUE THE CREW AT HALDATOR")
    } catch {
      game.notify("REGISTER TRANSFER NOT COMMITTED - ARCHIVE AND KIT CUSTODY UNCHANGED", voiced: false)
    }
    return true
  }
}
