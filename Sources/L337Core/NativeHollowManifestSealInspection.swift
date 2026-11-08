import Foundation

/// Historical native snapshots, not a saved live permission or a continuous-visibility claim.
struct NativeHollowManifestSealInspection: Codable, Equatable, Sendable {
  enum Evidence: String, Codable, Sendable { case nativeSnapshotPair }

  struct Facts: Codable, Equatable, Sendable {
    let evidence: Evidence
    let admission: NativeHollowManifestState.Reference
    let original: NativeHollowManifestOriginalSealBinding
    let request: UUID
    let reply: UUID
    let player: ActorIdentity
    let carrier: UUID
    let inventoryRevision: UInt64
    let instrument: OwnedEquipmentItem
    let epoch: UUID
    let sequence: UInt64
    let firstFrame: UInt64
    let lastFrame: UInt64
    let first: NativeC03SealProbe.Reading
    let last: NativeC03SealProbe.Reading
  }

  let operation: UUID
  let facts: Facts

  static func identity(_ facts: Facts) throws -> UUID {
    ScriptIdentity.uuid("c03-native-seal-inspection-v1:\(try NativeFlightReception.hash(facts))")
  }

  /// Closed historical joins only. The actual runtime producer separately rejoins live authority.
  func valid(in state: NativeHollowManifestState) -> Bool {
    let f = facts
    guard f.evidence == .nativeSnapshotPair,
      operation == (try? Self.identity(f)), f.original.shapeValid,
      let admission = state.admissions.first(where: { $0.reference == f.admission }),
      admission.original == f.original,
      let consent = state.consents.first(where: { $0.requestAdmission.slot == f.admission.slot }),
      let reply = consent.reply, reply.decision == .granted,
      consent.request.operation == f.request, reply.operation == f.reply,
      consent.request.binding.source == f.original.source,
      consent.request.binding.captain == f.original.captain,
      consent.request.binding.seal == f.original.seal,
      reply.sequence < f.sequence, f.sequence < state.nextSourceSequence,
      f.sequence > f.original.issuedSequence, f.first.physicalTime >= reply.physicalTime,
      f.inventoryRevision >= consent.request.inventoryRevision,
      f.inventoryRevision < UInt64(Int64.max),
      f.instrument.location == .init(hullInstanceID: f.carrier, slot: .targetingCore),
      TargetingTier.from(f.instrument.node.key) != nil,
      EquipmentRuntimeCatalog.node(for: f.instrument.node.key) == f.instrument.node,
      f.player.system == f.original.actor.system, f.player.visit == f.original.actor.visit,
      f.player.entity == 0,
      f.firstFrame < UInt64.max - 1, f.lastFrame == f.firstFrame + 1,
      Self.validInterval(start: f.first.physicalTime, end: f.last.physicalTime),
      readingValid(f.first, original: f.original), readingValid(f.last, original: f.original)
    else { return false }
    let barriers = state.firstCompromises.filter { $0.admission.slot == f.admission.slot }.map {
      ($0.sourceSequence, $0.facts.cause.physicalTime)
    } + state.withdrawals.filter { $0.effect.admission.slot == f.admission.slot }.map {
      ($0.sourceSequence, $0.effect.incident.physicalTime)
    } + state.terminals.filter { $0.effect.admission.slot == f.admission.slot }.map {
      ($0.sourceSequence, $0.effect.incident.physicalTime)
    } + [consent.revocation].compactMap { $0 }.map { ($0.sequence, $0.physicalTime) }
    return barriers.allSatisfy { f.sequence < $0.0 && f.last.physicalTime <= $0.1 }
  }

  static func validInterval(start: Double, end: Double) -> Bool {
    start.isFinite && end.isFinite && start >= 0 && end > start && end <= 1e12
      && end - start <= 0.100001
  }

  private func readingValid(
    _ reading: NativeC03SealProbe.Reading, original: NativeHollowManifestOriginalSealBinding
  ) -> Bool {
    guard reading.actor == original.actor, reading.component == original.component,
      reading.slot.rawValue == original.slot.rawValue,
      reading.physicalTime.isFinite, (original.issuedTime...1e12).contains(reading.physicalTime),
      reading.rootPose.position.finite, reading.rootPose.position.length <= 1e9,
      reading.rootPose.orientation.validRotation, reading.surfaceRanges.count == 12,
      reading.surfaceRanges.allSatisfy({ $0.isFinite && NativeC03SealGeometry.surfaceRange.contains($0) }),
      reading.maximumProbeAngle.isFinite, reading.maximumProbeAngle >= 0,
      reading.maximumProbeAngle <= NativeC03SealGeometry.maximumAngularProbeSpacing,
      reading.reliefHeights.count == NativeC03SealGeometry.reliefs.count
    else { return false }
    return zip(reading.reliefHeights, NativeC03SealGeometry.reliefs).allSatisfy {
      $0.0.isFinite && abs($0.0 - $0.1.size.z) <= NativeC03SealGeometry.maximumReliefHeightError
    }
  }
}

extension NativeHollowManifestState {
  /// Untrusted history reducer. A constructed receipt grants no authority to install this state.
  func retainingInspection(_ inspection: NativeHollowManifestSealInspection) throws -> Self {
    guard shapeValid, phase == .admitted, nextSourceSequence < UInt64(Int64.max) - 1,
      inspection.facts.sequence == nextSourceSequence,
      latestAdmissions.contains(inspection.facts.admission), inspections.count < 2,
      !inspections.contains(where: { $0.facts.admission.slot == inspection.facts.admission.slot })
    else { throw Failure.invalidState }
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections + [inspection], laboratory: laboratory, wakeTrail: wakeTrail, custodyRegister: custodyRegister,
      crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else {
      throw Failure.invalidState
    }
    return candidate
  }
}
