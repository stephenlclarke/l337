import Foundation

/// Constructed only by the live original/captain/consent/instrument and physical query below.
/// No saved sample, selected name or caller-supplied reading can create one.
final class NativeHollowManifestInspectionSample: Sendable {
  let source: NativeHollowManifestConsentSource
  let consent: NativeHollowManifestState.Consent
  let instrument: OwnedEquipmentItem
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let frame: UInt64
  let reading: NativeC03SealProbe.Reading

  fileprivate init(
    source: NativeHollowManifestConsentSource, consent: NativeHollowManifestState.Consent,
    instrument: OwnedEquipmentItem, carrier: UUID, inventoryRevision: UInt64,
    epoch: UUID, frame: UInt64, reading: NativeC03SealProbe.Reading
  ) {
    self.source = source
    self.consent = consent
    self.instrument = instrument
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
    self.epoch = epoch
    self.frame = frame
    self.reading = reading
  }

  fileprivate func sameAuthority(as other: NativeHollowManifestInspectionSample) -> Bool {
    source.life.original == other.source.life.original
      && source.life.pin.missionID == other.source.life.pin.missionID
      && source.life.pin.owner == other.source.life.pin.owner
      && source.life.pin.digest == other.source.life.pin.digest
      && source.admission == other.source.admission && source.player == other.source.player
      && consent == other.consent && instrument == other.instrument
      && carrier == other.carrier && inventoryRevision == other.inventoryRevision
      && epoch == other.epoch
  }
}

/// A read-only projection of a frame already sealed by either actual motion owner.
/// Its initializer cannot turn an unsealed capture, clock snapshot or DTO into a record.
private struct NativeC03InspectionFrame {
  let frame: UInt64
  let player: ActorIdentity
  let startTime: Double
  let endTime: Double
  let rootStart: ShipPose
  let rootEnd: ShipPose

  init?(record: NativeC03AttainedMotionResult,
    admission: NativeHollowManifestState.Admission)
  {
    switch record {
    case .recorded(let actual):
      let originals = actual.originals.filter { $0.admission == admission }
      guard originals.count == 1, let original = originals.first else { return nil }
      frame = actual.frame
      player = actual.player
      startTime = actual.startTime
      endTime = actual.endTime
      rootStart = original.rootStart
      rootEnd = original.rootEnd
    case .recordedNative(let actual):
      let originals = actual.originals.filter { $0.admission == admission }
      guard originals.count == 1, let original = originals.first else { return nil }
      frame = actual.frame
      player = actual.player
      startTime = actual.startTime
      endTime = actual.endTime
      rootStart = original.rootStart
      rootEnd = original.rootEnd
    case .refused: return nil
    }
  }
}

extension Game {
  /// A targeting computer probes the selected original only after its own captain has replied.
  /// Twelve actual first-hit rays see the original seal, the parent hull and every opaque actor.
  @inline(never)
  func hollowManifestInspectionSample() -> NativeHollowManifestInspectionSample? {
    guard !docked, !paused, !isMissionTrial, trialTitle == nil, screen == .front,
      !playerEMPDisabled, energy.isFinite, energy > 0, jumpCountdown == nil,
      pendingNativeStationDock == nil,
      systemIdentity == NativeHollowManifestDefinition.freighterWorld,
      let target = informationTargetBody?.id ?? weaponsTargetID,
      bodies.filter({ $0.id == target }).count == 1,
      let body = bodies.first(where: { $0.id == target }), body.position.z > 0,
      let inventory = commander.equipmentInventory, let carrier = commander.hullInstanceID,
      inventory.activeHull == carrier, let fitted = commander.fittedEquipment(at: .targetingCore),
      inventory.items.filter({ $0.id == fitted.id }).count == 1,
      let instrument = inventory.items.first(where: { $0.id == fitted.id }),
      instrument.location == .init(hullInstanceID: carrier, slot: .targetingCore),
      TargetingTier.from(instrument.node.key) != nil
    else { return nil }
    for slot in NativeHollowManifestState.Slot.allCases {
      guard let source = try? hollowManifestConsentSource(slot: slot),
        inventory.owner == source.life.pin.owner,
        source.owned.body.id == target, source.owned.presence == .present,
        body.physical?.identity == source.admission.original.actor,
        body.scriptNPC?.components[slot.rawValue]?.identity == source.admission.original.component,
        hollowManifestConsentWorkIsEligible(source),
        !source.life.pin.state.inspections.contains(where: { $0.facts.admission.slot == slot }),
        let consent = source.life.pin.state.consents.first(where: { $0.requestAdmission.slot == slot }),
        consent.reply?.decision == .granted, consent.revocation == nil,
        let probeSlot = NativeC03SealGeometry.Slot(rawValue: slot.rawValue),
        let reading = try? NativeC03SealProbe.measure(
          in: self, bodyID: target, component: source.admission.original.component,
          slot: probeSlot, origin: .init(0, 0, 0)),
        acceptsHollowManifestConsentSource(source)
      else { continue }
      return .init(
        source: source, consent: consent, instrument: instrument, carrier: carrier,
        inventoryRevision: inventory.revision, epoch: nativeStationRuntimeEpoch,
        frame: gameplayRevision, reading: reading)
    }
    return nil
  }

  /// The original raw native frame must agree with both query poses. This records discrete
  /// physical snapshots; it certifies no swept ray, dwell duration or visibility between them.
  @inline(never)
  mutating func retainHollowManifestInspection(from start: NativeHollowManifestInspectionSample)
    throws
  {
    guard let end = hollowManifestInspectionSample(), start.sameAuthority(as: end),
      let record = nativeC03AttainedMotion,
      let actual = NativeC03InspectionFrame(record: record, admission: end.source.admission),
      actual.frame == end.frame, start.frame < UInt64.max - 1, end.frame == start.frame + 1,
      actual.player == end.source.player, actual.startTime == start.reading.physicalTime,
      actual.endTime == end.reading.physicalTime,
      NativeHollowManifestSealInspection.validInterval(start: actual.startTime, end: actual.endTime),
      actual.rootStart == start.reading.rootPose, actual.rootEnd == end.reading.rootPose,
      acceptsHollowManifestConsentSource(end.source),
      var instance = withReadOnlyScriptState({ $0.instances[end.source.life.pin.missionID] }),
      instance.revision < UInt64(Int64.max) - 1, let state = instance.savedHollowManifest,
      state == end.source.life.pin.state,
      state.nextSourceSequence < UInt64(Int64.max) - 1,
      let reply = end.consent.reply
    else { throw SaveError.invalidCommander }
    let facts = NativeHollowManifestSealInspection.Facts(
      evidence: .nativeSnapshotPair, admission: end.source.admission.reference,
      original: end.source.admission.original, request: end.consent.request.operation,
      reply: reply.operation, player: end.source.player, carrier: end.carrier,
      inventoryRevision: end.inventoryRevision, instrument: end.instrument, epoch: end.epoch,
      sequence: state.nextSourceSequence, firstFrame: start.frame, lastFrame: end.frame,
      first: start.reading, last: end.reading)
    let receipt = NativeHollowManifestSealInspection(
      operation: try NativeHollowManifestSealInspection.identity(facts), facts: facts)
    instance.savedHollowManifest = try state.retainingInspection(receipt)
    instance.revision += 1
    if instance.savedHollowManifest?.inspections.count == 2 {
      instance.receipts.insert(NativeHollowManifestCommission.inspectionReceipt)
      instance.milestones.insert(1)
      instance.journal.append(NativeHollowManifestCommission.inspectionDialogue)
    }
    guard NativeHollowManifestCommission.prefixValid(instance) else { throw SaveError.invalidCommander }
    var candidate = commander
    candidate.scriptState.instances[instance.id] = instance
    guard NativeHollowManifestSave.validateClaims(candidate) else { throw SaveError.invalidCommander }
    commander = candidate
  }
}

extension GameRuntime {
  func commitHollowManifestInspection(from start: NativeHollowManifestInspectionSample?) {
    guard let start, scriptSaveURL != nil, galleryNamespace == nil, galleryParent == nil,
      game.nativeC03AttainedMotion?.recordsAttainedFrame == true
    else { return }
    do {
      try scriptCommand { try $0.retainHollowManifestInspection(from: start) }
      let count = game.hollowManifestMission?.savedHollowManifest?.inspections.count ?? 0
      game.notify(count == 2 ? "BOTH ORIGINAL SEALS RECORDED - VISIT IVEN AT TORENRAN" : "ORIGINAL SEAL RECORDED - ONE FREIGHTER REMAINS")
    } catch {
      game.notify("SEAL OBSERVATION NOT COMMITTED - KEEP CONSENT AND REACQUIRE THE ORIGINAL", voiced: false)
    }
  }
}
