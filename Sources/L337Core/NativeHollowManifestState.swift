import Foundation

/// Untrusted retained data only. These joins grant no source, physical, life or save authority.
struct NativeHollowManifestState: Codable, Sendable, Equatable {
  typealias Slot = NativeHollowManifestOriginalSealBinding.Slot
  enum Phase: String, Codable, Sendable { case unadmitted, admitted, originalLossRetained }
  enum Failure: Error, Equatable { case invalidState, missingActualRetainedMotion }

  struct Reference: Codable, Sendable, Hashable {
    let slot: Slot
    let revision: UInt64
  }
  struct Admission: Codable, Sendable, Equatable {
    let reference: Reference
    let original: NativeHollowManifestOriginalSealBinding
    let logicalActor: UUID
    let spawn: SpawnIdentity
    let geometry: NativeHollowManifestSealGeometryReference
  }

  /// Preserve the actual incident independently from the actual physical energy result.
  struct RootIncident: Codable, Sendable, Equatable {
    enum Path: String, Codable, Sendable { case nativeMission, ordinaryCombat }
    let path: Path
    let id: UInt64
    let physicalTime: Double
    let victim: ActorIdentity
    let kind: AttackKind
    let outcome: AttackOutcome
    let position: Vector3
    let origin: AttackOrigin?
    let attribution: NativeHollowManifestSealNativeEffectCause.Attribution
    let terminalShot: UUID?
    let victimPart: String?
    let component: UUID?
    /// Actual law/event data if supplied; constructing it is not proof of accepted law policy.
    let lawIncident: CombatIncident?

    var shapeValid: Bool {
      guard id > 0, physicalTime.isFinite, (0...1e12).contains(physicalTime),
        victim.system == NativeHollowManifestDefinition.freighterWorld,
        victim.entity > 1, victim.visit > 0,
        position.finite, position.length.isFinite, victimPart == nil, component == nil,
        [.hit, .destruction].contains(outcome)
      else { return false }
      if let origin {
        guard origin.emissionID > 0, origin.owner.system == victim.system,
          origin.emittedAt.isFinite, origin.emittedAt >= 0, origin.emittedAt <= physicalTime
        else { return false }
      }
      if let lawIncident {
        guard lawIncident.id == id, lawIncident.physicalTime == physicalTime,
          lawIncident.victim == victim, lawIncident.kind == kind,
          lawIncident.outcome == outcome, lawIncident.position == position,
          lawIncident.origin == origin, lawIncident.victimPart == nil
        else { return false }
      }
      if path == .ordinaryCombat {
        return outcome == .hit && lawIncident != nil && origin?.owner.visit == victim.visit
          && attribution == .currentVisit && terminalShot == nil
          && [.laser, .missile, .bomb, .plasma, .collision].contains(kind)
      }
      switch attribution {
      case .currentVisit:
        return origin?.owner.visit == victim.visit && terminalShot == nil
          && [.laser, .missile, .bomb, .plasma].contains(kind)
      case .frozenLaunch: return kind == .plasma && terminalShot != nil && origin != nil
      case .unknown: return kind == .plasma && terminalShot != nil
      }
    }
  }

  struct RootEffect: Codable, Sendable, Equatable {
    let admission: Reference
    let incident: RootIncident
    let requestedDamage: Double
    /// Actual amount applied to hull AFTER absorption, not requested weapon/impulse damage.
    let hullAppliedDamage: Double
    let beforeHull: Double
    let afterHull: Double
    /// Optional actual substep contact clock; never substituted for the native event clock.
    let contactPhysicalTime: Double?
    let damageAdmitted: Bool
    let hullDestroyed: Bool
    let destructionIncident: CombatIncident?

    var shapeValid: Bool {
      guard let source = try? NativeHollowManifestFleetSource.resolve(.inspectionFreighter),
        incident.shapeValid, damageAdmitted,
        requestedDamage.isFinite, requestedDamage > 0,
        hullAppliedDamage.isFinite, hullAppliedDamage > 0, hullAppliedDamage <= requestedDamage,
        beforeHull.isFinite, beforeHull > 0, beforeHull <= Double(source.performance.energy),
        afterHull.isFinite, afterHull == max(0, beforeHull - hullAppliedDamage),
        hullDestroyed == (afterHull == 0)
      else { return false }
      if incident.kind == .bomb, hullAppliedDamage != requestedDamage { return false }
      if let contactPhysicalTime {
        guard contactPhysicalTime.isFinite, contactPhysicalTime >= 0,
          contactPhysicalTime <= incident.physicalTime
        else { return false }
      }
      if incident.path == .nativeMission,
        incident.outcome != (hullDestroyed ? .destruction : .hit)
      {
        return false
      }
      if let death = destructionIncident {
        guard hullDestroyed, death.outcome == .destruction, death.victimPart == nil,
          death.victim == incident.victim, death.kind == incident.kind,
          death.physicalTime == incident.physicalTime, death.position == incident.position,
          death.origin == incident.origin,
          incident.path == .ordinaryCombat ? death.id > incident.id : death.id == incident.id
        else { return false }
      }
      return true
    }
  }

  struct Terminal: Codable, Sendable, Equatable {
    let captain: UUID
    let hull: UUID
    let sourceSequence: UInt64
    let effect: RootEffect
  }
  struct SealEffect: Codable, Sendable, Equatable {
    let admission: Reference
    let sourceSequence: UInt64
    let facts: NativeHollowManifestSealDamageFacts
  }
  struct Consent: Codable, Sendable, Equatable {
    let request: NativeHollowManifestSealConsentRequest
    let requestAdmission: Reference
    let reply: NativeHollowManifestSealConsentReply?
    let replyAdmission: Reference?
    let revocation: NativeHollowManifestSealConsentReply?
    let revocationAdmission: Reference?
  }
  struct Withdrawal: Codable, Sendable, Equatable {
    let owner: UUID
    let source: UUID
    let sourceSequence: UInt64
    let player: ActorIdentity
    /// Only a real validated physical hostility effect may feed the future private producer.
    let effect: RootEffect
  }
  struct Route: Codable, Sendable, Equatable {
    enum Target: String, Codable, Sendable { case first, second }
    let admission: Reference
    let first: Vector3
    let second: Vector3
    let target: Target
    let revision: UInt64
  }

  let birth: NativeHollowManifestSourceBirth
  let phase: Phase
  let nextSourceSequence: UInt64
  let admissions: [Admission]
  let firstAdmissions: [Reference]
  let latestAdmissions: [Reference]
  let terminals: [Terminal]
  let consents: [Consent]
  let firstCompromises: [SealEffect]
  let latestSealDamage: SealEffect?
  let damageRevision: UInt64
  let withdrawals: [Withdrawal]
  let routeAnchors: SystemAnchors?
  /// Frozen FIRST source reference, not a second retained ship pose/motion owner.
  let sourceFrame: ShipPose?
  let ownedEncounterID: String?
  let routes: [Route]
  let inspections: [NativeHollowManifestSealInspection]
  let laboratory: NativeHollowManifestLaboratoryReceipt?
  let wakeTrail: NativeC03WakeTrail?
  let custodyRegister: NativeC03RegisterState?
  let crewSource: NativeC03CrewSourceReference?
  let crewLogAccess: NativeC03CrewLogAccessReceipt?
  let caseFile: NativeC03CaseFile?

  static func unadmitted(_ birth: NativeHollowManifestSourceBirth) throws -> Self {
    let value = Self(
      birth: birth, phase: .unadmitted, nextSourceSequence: birth.nextSourceSequence,
      admissions: [], firstAdmissions: [], latestAdmissions: [], terminals: [], consents: [],
      firstCompromises: [], latestSealDamage: nil, damageRevision: 0,
      withdrawals: [], routeAnchors: nil, sourceFrame: nil, ownedEncounterID: nil, routes: [], inspections: [], laboratory: nil, wakeTrail: nil, custodyRegister: nil, crewSource: nil, crewLogAccess: nil, caseFile: nil)
    guard value.shapeValid else { throw Failure.invalidState }
    return value
  }

  /// The generic encounter API does not preserve fresh C03 native identity/canonical spin.
  /// G3 owns the actual retained-motion boundary. No substitute/default motion is accepted here.
  func requireReadmissionMotion() throws {
    throw Failure.missingActualRetainedMotion
  }

  /// Pure candidate history check, not authorization to publish or apply a physical effect.
  func preservesHistory(of earlier: Self) -> Bool {
    guard shapeValid, earlier.shapeValid, birth == earlier.birth,
      nextSourceSequence >= earlier.nextSourceSequence, damageRevision >= earlier.damageRevision,
      earlier.terminals.allSatisfy(terminals.contains),
      earlier.firstCompromises.allSatisfy(firstCompromises.contains),
      earlier.withdrawals.allSatisfy(withdrawals.contains),
      earlier.inspections.allSatisfy(inspections.contains),
      earlier.laboratory == nil || earlier.laboratory == laboratory,
      earlier.wakeTrail.map({ old in wakeTrail?.preservesHistory(of: old) == true }) ?? true,
      earlier.custodyRegister.map({ old in custodyRegister?.preservesHistory(of: old) == true }) ?? true,
      earlier.crewSource == nil || earlier.crewSource == crewSource,
      (earlier.crewLogAccess == nil || earlier.crewLogAccess == crewLogAccess),
      earlier.caseFile.map({ old in caseFile?.preservesHistory(of: old) == true }) ?? true,
      earlier.admissions.allSatisfy({ old in
        admission(old.reference).map { $0 == old } ?? true
      }), earlier.consents.allSatisfy(preservesConsent),
      preservesDamageWatermark(earlier)
    else { return false }
    if earlier.phase == .unadmitted { return true }
    guard firstAdmissions == earlier.firstAdmissions, sourceFrame == earlier.sourceFrame,
      routeAnchors == earlier.routeAnchors, ownedEncounterID == earlier.ownedEncounterID
    else { return false }
    return earlier.latestAdmissions.allSatisfy { old in
      latestAdmissions.contains { $0.slot == old.slot && $0.revision >= old.revision }
    }
      && earlier.routes.allSatisfy { old in
        routes.contains { new in
          new.admission.slot == old.admission.slot && new.revision >= old.revision
            && (new.revision != old.revision || new.target == old.target)
        }
      }
  }

  private func preservesConsent(_ old: Consent) -> Bool {
    guard
      let new = consents.first(where: { $0.requestAdmission.slot == old.requestAdmission.slot }),
      new.request == old.request, new.requestAdmission == old.requestAdmission
    else { return false }
    return
      (old.reply == nil || (new.reply == old.reply && new.replyAdmission == old.replyAdmission))
      && (old.revocation == nil
        || (new.revocation == old.revocation && new.revocationAdmission == old.revocationAdmission))
  }

  private func preservesDamageWatermark(_ earlier: Self) -> Bool {
    guard let old = earlier.latestSealDamage else { return true }
    guard let new = latestSealDamage else { return false }
    if new == old { return damageRevision == earlier.damageRevision }
    return new.facts.cause.id > old.facts.cause.id && new.sourceSequence > old.sourceSequence
      && new.facts.cause.physicalTime >= old.facts.cause.physicalTime
      && damageRevision > earlier.damageRevision
  }

  var shapeValid: Bool {
    guard birth.shapeValid, nextSourceSequence >= birth.nextSourceSequence,
      nextSourceSequence < UInt64(Int64.max), admissions.count <= 20,
      firstAdmissions.count <= 2, latestAdmissions.count <= 2, terminals.count <= 2,
      consents.count <= 2, firstCompromises.count <= 2, withdrawals.count <= 2, routes.count <= 2,
      inspections.count <= 2, Set(inspections.map { $0.facts.admission.slot }).count == inspections.count,
      Set(inspections.map(\.operation)).count == inspections.count,
      damageRevision < UInt64(Int64.max), damageRevision >= UInt64(firstCompromises.count)
    else { return false }
    if phase == .unadmitted {
      return nextSourceSequence == birth.nextSourceSequence && admissions.isEmpty
        && firstAdmissions.isEmpty && latestAdmissions.isEmpty && terminals.isEmpty
        && consents.isEmpty && firstCompromises.isEmpty && latestSealDamage == nil
        && damageRevision == 0 && withdrawals.isEmpty && routeAnchors == nil
        && sourceFrame == nil && ownedEncounterID == nil && routes.isEmpty && inspections.isEmpty && laboratory == nil && wakeTrail == nil && custodyRegister == nil && crewSource == nil && crewLogAccess == nil && caseFile == nil
    }
    guard Set(admissions.map(\.reference)).count == admissions.count,
      Set(admissions.map { $0.original.actor }).count == admissions.count,
      firstAdmissions.count == 2, latestAdmissions.count == 2,
      Set(firstAdmissions.map(\.slot)) == Set(Slot.allCases),
      Set(latestAdmissions.map(\.slot)) == Set(Slot.allCases),
      firstAdmissions.allSatisfy({ $0.revision == 1 }),
      admissions.allSatisfy(validAdmission),
      validAdmissionOrder,
      Set(terminals.map { $0.effect.admission.slot }).count == terminals.count,
      Set(consents.map { $0.requestAdmission.slot }).count == consents.count,
      Set(firstCompromises.map { $0.admission.slot }).count == firstCompromises.count,
      Set(withdrawals.map { $0.effect.admission.slot }).count == withdrawals.count,
      phase == (terminals.isEmpty ? .admitted : .originalLossRetained),
      terminals.allSatisfy(validTerminal), consents.allSatisfy(validConsent),
      firstCompromises.allSatisfy(validSealEffect), withdrawals.allSatisfy(validWithdrawal),
      validIntegrity, validRoutes, validNativeEventIdentities,
      inspections.allSatisfy({ $0.valid(in: self) }), validInspectionSequenceOwnership,
      laboratory.map({ $0.valid(in: self) }) ?? true,
      wakeTrail.map({ $0.valid(in: self) }) ?? true,
      custodyRegister.map({ $0.valid(in: self) }) ?? true,
      crewSource.map({ $0.valid(in: self) }) ?? true,
      crewLogAccess.map({ $0.valid(in: self) }) ?? true,
      caseFile.map({ $0.valid(in: self) }) ?? true
    else { return false }
    let references = retainedReferences
    return Set(references) == Set(admissions.map(\.reference))
      && Slot.allCases.allSatisfy { slot in
        references.filter { $0.slot == slot }.count <= 10
          && admissions.filter { $0.reference.slot == slot }.count <= 10
      }
  }

  private var validInspectionSequenceOwnership: Bool {
    var occupied = Set(birth.operations.map(\.sequence))
    for admission in admissions { occupied.insert(admission.original.issuedSequence) }
    for consent in consents {
      occupied.insert(consent.request.sequence)
      if let reply = consent.reply { occupied.insert(reply.sequence) }
      if let revocation = consent.revocation { occupied.insert(revocation.sequence) }
    }
    for compromise in firstCompromises { occupied.insert(compromise.sourceSequence) }
    if let latestSealDamage { occupied.insert(latestSealDamage.sourceSequence) }
    for withdrawal in withdrawals { occupied.insert(withdrawal.sourceSequence) }
    for terminal in terminals { occupied.insert(terminal.sourceSequence) }
    var sequences = inspections.map { $0.facts.sequence }
    if let laboratory { sequences.append(laboratory.facts.sequence) }
    if let wakeTrail { sequences += wakeTrail.sequences }
    if let custodyRegister { sequences += custodyRegister.sequences }
    if let crewSource { sequences.append(crewSource.sequence) }
    if let caseFile { sequences += caseFile.sequences }
    return Set(sequences).count == sequences.count && sequences.allSatisfy { !occupied.contains($0) }
  }

  private func admission(_ reference: Reference) -> Admission? {
    admissions.first { $0.reference == reference }
  }
  private func original(_ slot: Slot) -> NativeHollowManifestSourceBirth.Original? {
    birth.originals.first { $0.slot == slot }
  }
  private func validAdmission(_ value: Admission) -> Bool {
    let binding = value.original
    guard let source = original(value.reference.slot), binding.shapeValid,
      value.reference.revision > 0, value.reference.revision < UInt64(Int64.max),
      binding.slot == source.slot, binding.mission == birth.input.mission,
      binding.owner == birth.input.owner, binding.source == source.source,
      binding.hull == source.hull, binding.captain == source.captain,
      binding.seal == source.seal, binding.master == source.master,
      binding.imprint == source.imprint,
      binding.sourceRevision == value.reference.revision,
      binding.issuedSequence >= birth.nextSourceSequence,
      binding.issuedSequence < nextSourceSequence, binding.issuedTime >= birth.input.physicalTime,
      value.spawn.system == binding.actor.system, value.spawn.visit == binding.actor.visit,
      value.spawn.sequence > 0, value.spawn.producer == .mission,
      value.geometry.shapeValid, value.geometry.revision == 1,
      value.geometry.componentPose
        == ShipPose(
          position: NativeC03SealGeometry.componentPosition,
          orientation: NativeC03SealGeometry.componentOrientation),
      let firstRef = firstAdmissions.first(where: { $0.slot == source.slot }),
      let latestRef = latestAdmissions.first(where: { $0.slot == source.slot }),
      let first = admission(firstRef), let latest = admission(latestRef),
      value.reference.revision <= latest.reference.revision,
      value.logicalActor == first.logicalActor, binding.component == first.original.component,
      value.geometry == first.geometry,
      binding.issuedSequence <= latest.original.issuedSequence,
      binding.issuedTime <= latest.original.issuedTime,
      binding.actor.visit <= latest.original.actor.visit,
      let root = try? ScriptPackLibrary.canonicalGeometry(birth.rootDesign),
      let seal = try? ScriptPackLibrary.canonicalGeometry(birth.master.template)
    else { return false }
    return value.geometry.rootGeometryHash == ScriptPackLibrary.hash(root)
      && value.geometry.sealGeometryHash == ScriptPackLibrary.hash(seal)
  }

  private func validRootEffect(_ effect: RootEffect) -> Bool {
    guard effect.shapeValid, let witness = admission(effect.admission) else { return false }
    return effect.incident.victim == witness.original.actor
      && effect.incident.physicalTime >= witness.original.issuedTime
      && (effect.contactPhysicalTime.map { $0 >= witness.original.issuedTime } ?? true)
  }
  private func validTerminal(_ terminal: Terminal) -> Bool {
    guard validRootEffect(terminal.effect), terminal.effect.hullDestroyed,
      let witness = admission(terminal.effect.admission),
      terminal.sourceSequence > witness.original.issuedSequence,
      terminal.sourceSequence < nextSourceSequence,
      let source = original(terminal.effect.admission.slot),
      let latest = latestAdmissions.first(where: { $0.slot == source.slot })
    else { return false }
    return terminal.captain == source.captain && terminal.hull == source.hull
      && latest == terminal.effect.admission
  }
  private func validSealEffect(_ effect: SealEffect) -> Bool {
    guard let witness = admission(effect.admission),
      effect.sourceSequence > witness.original.issuedSequence,
      effect.sourceSequence < nextSourceSequence
    else { return false }
    return effect.facts.structurallyMatches(
      .init(
        original: witness.original, geometry: witness.geometry,
        originalComponentEnergy: birth.fit.sealEnergy))
  }
  private var validIntegrity: Bool {
    guard let latestSealDamage else {
      return firstCompromises.isEmpty && damageRevision == 0
    }
    guard validSealEffect(latestSealDamage), !firstCompromises.isEmpty,
      Set(firstCompromises.map { $0.facts.cause.id }).count == firstCompromises.count,
      firstCompromises.allSatisfy({
        $0.facts.beforeEnergy == birth.fit.sealEnergy
          && $0.sourceSequence <= latestSealDamage.sourceSequence
          && $0.facts.cause.id <= latestSealDamage.facts.cause.id
          && $0.facts.cause.physicalTime <= latestSealDamage.facts.cause.physicalTime
          && ($0.facts.cause.id != latestSealDamage.facts.cause.id || $0 == latestSealDamage)
      }), firstCompromises.contains(where: { $0.admission.slot == latestSealDamage.admission.slot })
    else { return false }
    let extra = firstCompromises.contains(latestSealDamage) ? 0 : 1
    return damageRevision >= UInt64(firstCompromises.count + extra)
  }
  private func validConsent(_ value: Consent) -> Bool {
    guard let requestWitness = admission(value.requestAdmission),
      value.request.structurallyMatches(requestWitness.original),
      value.request.sequence < nextSourceSequence,
      (value.reply == nil) == (value.replyAdmission == nil),
      (value.revocation == nil) == (value.revocationAdmission == nil)
    else { return false }
    let terminal = terminals.first { $0.effect.admission.slot == value.requestAdmission.slot }
      .map { ($0.sourceSequence, $0.effect.incident.physicalTime) }
    let compromised = firstCompromises.first { $0.admission.slot == value.requestAdmission.slot }
      .map { ($0.sourceSequence, $0.facts.cause.physicalTime) }
    let withdrawn = withdrawals.first { $0.effect.admission.slot == value.requestAdmission.slot }
      .map { ($0.sourceSequence, $0.effect.incident.physicalTime) }
    guard
      [terminal, compromised, withdrawn].allSatisfy({
        precedes(value.request.sequence, time: value.request.physicalTime, barrier: $0)
      })
    else { return false }
    if let reply = value.reply, let reference = value.replyAdmission {
      guard let witness = admission(reference), reference.slot == value.requestAdmission.slot,
        reference.revision >= value.requestAdmission.revision,
        reply.structurallyMatches(value.request, original: requestWitness.original),
        reply.sequence > witness.original.issuedSequence, reply.sequence < nextSourceSequence,
        reply.physicalTime >= witness.original.issuedTime
      else { return false }
      guard precedes(reply.sequence, time: reply.physicalTime, barrier: terminal)
      else { return false }
      if reply.decision == .granted {
        guard
          [compromised, withdrawn].allSatisfy({
            precedes(reply.sequence, time: reply.physicalTime, barrier: $0)
          })
        else { return false }
      }
    }
    if let revocation = value.revocation, let reference = value.revocationAdmission {
      guard let reply = value.reply, let witness = admission(reference),
        reference.slot == value.requestAdmission.slot,
        reference.revision >= (value.replyAdmission?.revision ?? 0),
        revocation.structurallyMatches(
          value.request, original: requestWitness.original, previous: reply),
        revocation.sequence > witness.original.issuedSequence,
        revocation.sequence < nextSourceSequence,
        revocation.physicalTime >= witness.original.issuedTime
      else { return false }
      guard precedes(revocation.sequence, time: revocation.physicalTime, barrier: terminal)
      else { return false }
    }
    return true
  }
  private func precedes(_ sequence: UInt64, time: Double, barrier: (UInt64, Double)?) -> Bool {
    guard let barrier else { return true }
    return sequence < barrier.0 && time <= barrier.1
  }
  private func validWithdrawal(_ value: Withdrawal) -> Bool {
    guard validRootEffect(value.effect), let source = original(value.effect.admission.slot),
      let witness = admission(value.effect.admission),
      let law = value.effect.incident.lawIncident,
      value.owner == birth.input.owner, value.source == source.source,
      value.sourceSequence > witness.original.issuedSequence,
      value.sourceSequence < nextSourceSequence,
      value.player.entity == 0, value.player.system == value.effect.incident.victim.system,
      value.player.visit == value.effect.incident.victim.visit,
      law.origin.owner == value.player, law.victimRole == .mission, law.victimIsStation == false
    else { return false }
    return true
  }
  private var validRoutes: Bool {
    guard let layout = try? NativeC03FreighterRoute.candidateLayout(anchors: routeAnchors),
      let sourceFrame, let ownedEncounterID, PackValidation.localID(ownedEncounterID),
      let first = firstAdmissions.first.flatMap(admission),
      routeAnchors?.station.identity.visit == first.original.actor.visit,
      routes.count == 2, Set(routes.map { $0.admission.slot }) == Set(Slot.allCases)
    else { return false }
    var basis = Basis3()
    basis.x = layout.u
    basis.y = layout.v
    basis.z = layout.normal
    guard
      sourceFrame
        == ShipPose(
          position: (layout.firstCentre + layout.secondCentre) * 0.5, orientation: basis)
    else { return false }
    return routes.allSatisfy { route in
      let endpoints = route.admission.slot == .first ? layout.first : layout.second
      return latestAdmissions.contains(route.admission) && route.revision > 0
        && route.revision < UInt64(Int64.max)
        && route.first == endpoints.first && route.second == endpoints.second
    }
  }
  private var validAdmissionOrder: Bool {
    let first = firstAdmissions.compactMap(admission)
    guard Set(first.map(\.logicalActor)).count == 2,
      Set(first.map { $0.original.actor.visit }).count == 1,
      Set(first.map { $0.original.issuedTime }).count == 1,
      Set(first.map { $0.spawn.sequence }).count == 1,
      Set(first.map { $0.spawn.member }).count == 2,
      NativeHollowManifestOriginalSealBinding.rosterShapeValid(first.map(\.original))
    else { return false }
    return Slot.allCases.allSatisfy { slot in
      let values = admissions.filter { $0.reference.slot == slot }
        .sorted { $0.reference.revision < $1.reference.revision }
      return zip(values, values.dropFirst()).allSatisfy { earlier, later in
        earlier.original.issuedSequence < later.original.issuedSequence
          && earlier.original.issuedTime <= later.original.issuedTime
          && earlier.original.actor.visit <= later.original.actor.visit
          && earlier.original.actor.entity < later.original.actor.entity
      }
    }
  }
  private var retainedReferences: [Reference] {
    firstAdmissions + latestAdmissions + terminals.map(\.effect.admission)
      + inspections.map { $0.facts.admission }
      + consents.flatMap {
        [$0.requestAdmission] + [$0.replyAdmission, $0.revocationAdmission].compactMap { $0 }
      }
      + firstCompromises.map(\.admission) + [latestSealDamage?.admission].compactMap { $0 }
      + withdrawals.map(\.effect.admission)
  }

  /// At most eleven projections from already bounded C03 facts; never a new event ledger.
  private struct PhysicalEvent {
    struct Identity: Equatable {
      let id: UInt64
      let time: Double
      let victim: ActorIdentity?
      let kind: AttackKind
      let outcome: AttackOutcome
      let position: Vector3
      let origin: AttackOrigin?
      let part: String?
      let component: UUID?
    }
    struct Attribution: Equatable {
      let value: NativeHollowManifestSealNativeEffectCause.Attribution
      let terminalShot: UUID?
    }
    let identity: Identity
    let attribution: Attribution?
    let law: CombatIncident?
    let root: RootEffect?
    let seal: NativeHollowManifestSealDamageFacts?

    func agrees(with other: Self) -> Bool {
      guard identity == other.identity else { return false }
      if let attribution, let rhs = other.attribution, attribution != rhs { return false }
      if let law, let rhs = other.law, law != rhs { return false }
      if let root, let rhs = other.root, root != rhs { return false }
      if let seal, let rhs = other.seal, seal != rhs { return false }
      return true
    }
  }

  private func rootEvents(_ effect: RootEffect) -> [PhysicalEvent] {
    let cause = effect.incident
    var values: [PhysicalEvent] = [
      .init(
        identity: .init(
          id: cause.id, time: cause.physicalTime, victim: cause.victim, kind: cause.kind,
          outcome: cause.outcome, position: cause.position, origin: cause.origin,
          part: cause.victimPart, component: cause.component),
        attribution: .init(value: cause.attribution, terminalShot: cause.terminalShot),
        law: cause.lawIncident, root: effect, seal: nil)
    ]
    if let death = effect.destructionIncident {
      values.append(
        .init(
          identity: .init(
            id: death.id, time: death.physicalTime, victim: death.victim, kind: death.kind,
            outcome: death.outcome, position: death.position, origin: death.origin,
            part: death.victimPart, component: nil),
          attribution: nil, law: death, root: nil, seal: nil))
    }
    return values
  }

  private var validNativeEventIdentities: Bool {
    var values =
      terminals.flatMap { rootEvents($0.effect) }
      + withdrawals.flatMap { rootEvents($0.effect) }
    for effect in firstCompromises + [latestSealDamage].compactMap({ $0 }) {
      let cause = effect.facts.cause
      values.append(
        .init(
          identity: .init(
            id: cause.id, time: cause.physicalTime, victim: cause.victim, kind: cause.kind,
            outcome: cause.outcome, position: cause.position, origin: cause.origin,
            part: cause.victimPart, component: cause.component),
          attribution: .init(value: cause.attribution, terminalShot: cause.terminalShot),
          law: nil, root: nil, seal: effect.facts))
    }
    for (index, value) in values.enumerated() {
      for other in values.dropFirst(index + 1) where value.identity.id == other.identity.id {
        guard value.agrees(with: other) else { return false }
      }
    }
    return true
  }
}

extension NativeHollowManifestState {
  /// PURE untrusted candidate arithmetic. Only G3's actual staged physical plan may supply these
  /// witnesses and publish after the installed pin STILL matches. Construction grants no admission.
  static func preparingFirstAdmission(
    from state: Self, admissions: [Admission], stagedFlight: FlightSimulationState,
    sourceFrame: ShipPose, anchors: SystemAnchors, encounter: String,
    initialTargets: [Slot: Route.Target]
  ) throws -> Self {
    guard state.shapeValid, state.phase == .unadmitted,
      encounter == NativeHollowManifestCommission.encounter,
      admissions.count == 2, Set(admissions.map { $0.reference.slot }) == Set(Slot.allCases),
      Set(initialTargets.keys) == Set(Slot.allCases),
      initialTargets.values.allSatisfy({ $0 == .first }),
      stagedFlight.valid, stagedFlight.anchors == anchors,
      admissions.allSatisfy({ $0.reference.revision == 1 }),
      stagedAdmissionsValid(admissions, from: state, flight: stagedFlight)
    else { throw Failure.invalidState }
    _ = try NativeHollowManifestCommission.admissionDeclarations(
      birth: state.birth, anchors: anchors, sourceFrame: sourceFrame, encounter: encounter)
    let layout = try NativeC03FreighterRoute.candidateLayout(anchors: anchors)
    let references = admissions.map(\.reference)
    let routes: [Route] = admissions.map { admission in
      let endpoints = admission.reference.slot == .first ? layout.first : layout.second
      return .init(
        admission: admission.reference, first: endpoints.first, second: endpoints.second,
        target: .first, revision: 1)
    }
    let candidate = Self(
      birth: state.birth, phase: .admitted, nextSourceSequence: state.nextSourceSequence + 2,
      admissions: admissions, firstAdmissions: references, latestAdmissions: references,
      terminals: [], consents: [], firstCompromises: [], latestSealDamage: nil, damageRevision: 0,
      withdrawals: [], routeAnchors: anchors, sourceFrame: sourceFrame,
      ownedEncounterID: encounter, routes: routes, inspections: state.inspections, laboratory: state.laboratory, wakeTrail: state.wakeTrail, custodyRegister: state.custodyRegister, crewSource: state.crewSource, crewLogAccess: state.crewLogAccess, caseFile: state.caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: state) else {
      throw Failure.invalidState
    }
    return candidate
  }

  /// Pure bounded retained variant: never recreates birth/frame/anchors, resets a route target,
  /// clears an irreversible fact, or grants a replacement for an original with a terminal loss.
  static func preparingRetainedAdmission(
    from state: Self, admissions: [Admission], stagedFlight: FlightSimulationState
  ) throws -> Self {
    guard state.shapeValid, state.phase != .unadmitted,
      (1...2).contains(admissions.count),
      Set(admissions.map { $0.reference.slot }).count == admissions.count,
      state.ownedEncounterID == NativeHollowManifestCommission.encounter,
      stagedFlight.valid, stagedAdmissionsValid(admissions, from: state, flight: stagedFlight)
    else { throw Failure.invalidState }
    var latest = state.latestAdmissions
    var routes = state.routes
    for admission in admissions {
      let slot = admission.reference.slot
      guard !state.terminals.contains(where: { $0.effect.admission.slot == slot }),
        let old = state.latestAdmissions.first(where: { $0.slot == slot }),
        admission.reference.revision == old.revision + 1,
        let index = latest.firstIndex(where: { $0.slot == slot }),
        let routeIndex = routes.firstIndex(where: { $0.admission.slot == slot })
      else { throw Failure.invalidState }
      latest[index] = admission.reference
      let route = routes[routeIndex]
      routes[routeIndex] = .init(
        admission: admission.reference, first: route.first,
        second: route.second, target: route.target, revision: route.revision)
    }
    var candidate = Self(
      birth: state.birth, phase: state.phase,
      nextSourceSequence: state.nextSourceSequence + UInt64(admissions.count),
      admissions: state.admissions + admissions,
      firstAdmissions: state.firstAdmissions, latestAdmissions: latest,
      terminals: state.terminals, consents: state.consents,
      firstCompromises: state.firstCompromises, latestSealDamage: state.latestSealDamage,
      damageRevision: state.damageRevision, withdrawals: state.withdrawals,
      routeAnchors: state.routeAnchors, sourceFrame: state.sourceFrame,
      ownedEncounterID: state.ownedEncounterID, routes: routes, inspections: state.inspections, laboratory: state.laboratory, wakeTrail: state.wakeTrail, custodyRegister: state.custodyRegister, crewSource: state.crewSource, crewLogAccess: state.crewLogAccess, caseFile: state.caseFile)
    let retained = Set(candidate.retainedReferences)
    candidate = Self(
      birth: candidate.birth, phase: candidate.phase,
      nextSourceSequence: candidate.nextSourceSequence,
      admissions: candidate.admissions.filter { retained.contains($0.reference) },
      firstAdmissions: candidate.firstAdmissions, latestAdmissions: candidate.latestAdmissions,
      terminals: candidate.terminals, consents: candidate.consents,
      firstCompromises: candidate.firstCompromises, latestSealDamage: candidate.latestSealDamage,
      damageRevision: candidate.damageRevision, withdrawals: candidate.withdrawals,
      routeAnchors: candidate.routeAnchors, sourceFrame: candidate.sourceFrame,
      ownedEncounterID: candidate.ownedEncounterID, routes: candidate.routes,
      inspections: candidate.inspections, laboratory: candidate.laboratory, wakeTrail: candidate.wakeTrail, custodyRegister: candidate.custodyRegister, crewSource: candidate.crewSource, crewLogAccess: candidate.crewLogAccess, caseFile: candidate.caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: state) else {
      throw Failure.invalidState
    }
    return candidate
  }

  private static func stagedAdmissionsValid(
    _ admissions: [Admission], from state: Self,
    flight: FlightSimulationState
  ) -> Bool {
    guard state.nextSourceSequence < UInt64(Int64.max) - 3,
      flight.anchors?.system == NativeHollowManifestDefinition.freighterWorld,
      flight.physicalTime >= state.birth.input.physicalTime,
      state.admissions.allSatisfy({ $0.original.issuedTime <= flight.physicalTime }),
      (state.terminals.map(\.effect) + state.withdrawals.map(\.effect)).allSatisfy({
        $0.incident.physicalTime <= flight.physicalTime
      }),
      (state.firstCompromises + [state.latestSealDamage].compactMap { $0 }).allSatisfy({
        $0.facts.cause.physicalTime <= flight.physicalTime
      }),
      state.consents.allSatisfy({
        $0.request.physicalTime <= flight.physicalTime
          && [$0.reply?.physicalTime, $0.revocation?.physicalTime].compactMap { $0 }
            .allSatisfy { $0 <= flight.physicalTime }
      })
    else { return false }
    return admissions.enumerated().allSatisfy { index, admission in
      let original = admission.original
      let logical = NativeHollowManifestCommission.logicalActor(
        mission: state.birth.input.mission, slot: admission.reference.slot)
      return admission.logicalActor == logical
        && original.component
          == NativeHollowManifestCommission.component(
            logicalActor: logical, slot: admission.reference.slot)
        && original.issuedSequence == state.nextSourceSequence + UInt64(index)
        && original.issuedTime == flight.physicalTime
        && original.actor.visit == flight.visit && original.actor.entity < flight.nextActor
        && admission.spawn.sequence < flight.nextSpawn
    }
  }
}

extension NativeHollowManifestState {
  /// PURE route replacement, not actual arrival evidence. G4's native observer owns the measured
  /// <=5m AND speed<1 guard before calling this and authenticates the installed source afterward.
  func replacingRoutes(candidateRoutes: [Route]) throws -> Self {
    guard shapeValid, phase != .unadmitted, candidateRoutes.count == 2,
      zip(routes, candidateRoutes).allSatisfy({ old, new in
        guard old.admission == new.admission, old.first == new.first, old.second == new.second
        else {
          return false
        }
        if old.target == new.target { return old.revision == new.revision }
        return old.revision < UInt64(Int64.max) - 1 && new.revision == old.revision + 1
      })
    else { throw Failure.invalidState }
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: candidateRoutes, inspections: inspections, laboratory: laboratory, wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else {
      throw Failure.invalidState
    }
    return candidate
  }
}

extension NativeHollowManifestState {
  /// PURE untrusted reducer. Only the actual effect owner may submit an accepted physical effect
  /// and publish its prepared instance with that effect. No energy scan, cull or supplied flag
  /// creates native authority here; all incident and post-absorption fields remain unchanged.
  func retainingRootEffect(effect: RootEffect, actualPlayer: ActorIdentity?) throws -> Self {
    guard shapeValid, phase != .unadmitted, effect.shapeValid,
      rootEffectAgreesWithRetainedEvents(effect)
    else { throw Failure.invalidState }
    // A replay cannot backfill new facts after a terminal, consent barrier or fresh admission.
    if terminals.contains(where: { $0.effect == effect })
      || withdrawals.contains(where: { $0.effect == effect })
    {
      return self
    }
    guard latestAdmissions.contains(effect.admission), validRootEffect(effect),
      !terminals.contains(where: { $0.effect.admission.slot == effect.admission.slot }),
      effect.incident.physicalTime >= lastRetainedEffectTime,
      let source = original(effect.admission.slot)
    else { throw Failure.invalidState }
    if let actualPlayer {
      guard actualPlayer.entity == 0, actualPlayer.system == effect.incident.victim.system,
        actualPlayer.visit == effect.incident.victim.visit
      else { throw Failure.invalidState }
    }
    let existingWithdrawal = withdrawals.contains {
      $0.effect.admission.slot == effect.admission.slot
    }
    let hostilePlayer: ActorIdentity?
    if !existingWithdrawal, let actualPlayer, let law = effect.incident.lawIncident,
      law.origin.owner == actualPlayer, law.victimRole == .mission, !law.victimIsStation
    {
      hostilePlayer = actualPlayer
    } else {
      hostilePlayer = nil
    }
    let demand = (hostilePlayer == nil ? 0 : 1) + (effect.hullDestroyed ? 1 : 0)
    guard demand > 0 else { return self }
    guard terminals.count + (effect.hullDestroyed ? 1 : 0) <= 2,
      withdrawals.count + (hostilePlayer == nil ? 0 : 1) <= 2,
      nextSourceSequence < UInt64(Int64.max) - UInt64(demand)
    else { throw Failure.invalidState }
    var next = nextSourceSequence
    var newWithdrawals = withdrawals
    var newTerminals = terminals
    if let hostilePlayer {
      newWithdrawals.append(
        .init(
          owner: birth.input.owner, source: source.source,
          sourceSequence: next, player: hostilePlayer, effect: effect))
      next += 1
    }
    if effect.hullDestroyed {
      newTerminals.append(
        .init(
          captain: source.captain, hull: source.hull,
          sourceSequence: next, effect: effect))
      next += 1
    }
    let candidate = Self(
      birth: birth, phase: newTerminals.isEmpty ? .admitted : .originalLossRetained,
      nextSourceSequence: next, admissions: admissions, firstAdmissions: firstAdmissions,
      latestAdmissions: latestAdmissions, terminals: newTerminals, consents: consents,
      firstCompromises: firstCompromises, latestSealDamage: latestSealDamage,
      damageRevision: damageRevision, withdrawals: newWithdrawals, routeAnchors: routeAnchors,
      sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID, routes: routes, inspections: inspections, laboratory: laboratory, wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else {
      throw Failure.invalidState
    }
    return candidate
  }

  private var lastRetainedEffectTime: Double {
    let birthTimes: [Double] = [birth.input.physicalTime]
    let admissionTimes: [Double] = admissions.map { $0.original.issuedTime }
    let terminalEffects: [RootEffect] = terminals.map(\.effect)
    let withdrawalEffects: [RootEffect] = withdrawals.map(\.effect)
    let rootEffects: [RootEffect] = terminalEffects + withdrawalEffects
    let rootTimes: [Double] = rootEffects.map { $0.incident.physicalTime }
    let latestSealEffects: [SealEffect] = [latestSealDamage].compactMap { $0 }
    let sealEffects: [SealEffect] = firstCompromises + latestSealEffects
    let sealTimes: [Double] = sealEffects.map { $0.facts.cause.physicalTime }
    let consentTimes: [Double] = consents.flatMap { (consent: Consent) -> [Double] in
      let requestTimes: [Double] = [consent.request.physicalTime]
      let optionalReplyTimes: [Double?] =
        [consent.reply?.physicalTime, consent.revocation?.physicalTime]
      let replyTimes: [Double] = optionalReplyTimes.compactMap { $0 }
      return requestTimes + replyTimes
    }
    let times: [Double] = birthTimes + admissionTimes + rootTimes + sealTimes + consentTimes
    return times.max() ?? birth.input.physicalTime
  }

  /// Same bounded event projections as the reviewed State identity check, including optional
  /// actual death and component causes. A no-new-fact input must not bypass conflict refusal.
  private func rootEffectAgreesWithRetainedEvents(_ effect: RootEffect) -> Bool {
    let incoming = rootEvents(effect)
    let roots =
      terminals.flatMap { rootEvents($0.effect) } + withdrawals.flatMap { rootEvents($0.effect) }
    for new in incoming {
      for old in roots where old.identity.id == new.identity.id {
        guard new.agrees(with: old) else { return false }
      }
    }
    for seal in firstCompromises + [latestSealDamage].compactMap({ $0 }) {
      let cause = seal.facts.cause
      let old = PhysicalEvent(
        identity: .init(
          id: cause.id, time: cause.physicalTime, victim: cause.victim,
          kind: cause.kind, outcome: cause.outcome, position: cause.position, origin: cause.origin,
          part: cause.victimPart, component: cause.component),
        attribution: .init(value: cause.attribution, terminalShot: cause.terminalShot),
        law: nil, root: nil, seal: seal.facts)
      for new in incoming where new.identity.id == old.identity.id {
        guard new.agrees(with: old) else { return false }
      }
    }
    return true
  }
}

extension NativeHollowManifestState {
  /// Pure retained candidates only. Actual UI, item, contact and source authority belong to
  /// the native producer. A later fit or admission never replaces an original request.
  func retainingConsentRequest(
    request: NativeHollowManifestSealConsentRequest, admission reference: Reference
  ) throws -> Self {
    guard shapeValid, phase != .unadmitted, consentOperationsAreUnique else {
      throw Failure.invalidState
    }
    if let old = consents.first(where: { $0.requestAdmission.slot == reference.slot }) {
      guard old.request == request, old.requestAdmission == reference else {
        throw Failure.invalidState
      }
      return self
    }
    guard let witness = currentConsentWitness(reference), consents.count < 2,
      request.structurallyMatches(witness.original), consentWorkHasNoBarrier(reference.slot),
      acceptsNewConsentFact(
        operation: request.operation, sequence: request.sequence,
        physicalTime: request.physicalTime)
    else { throw Failure.invalidState }
    return try retainingConsents(
      consents + [
        .init(
          request: request, requestAdmission: reference, reply: nil, replyAdmission: nil,
          revocation: nil, revocationAdmission: nil)
      ])
  }

  func retainingConsentReply(
    reply: NativeHollowManifestSealConsentReply, admission reference: Reference
  ) throws -> Self {
    guard shapeValid, phase != .unadmitted, consentOperationsAreUnique,
      let index = consents.firstIndex(where: { $0.request.operation == reply.request })
    else { throw Failure.invalidState }
    let old = consents[index]
    if let retained = old.reply {
      guard retained == reply, old.replyAdmission == reference else { throw Failure.invalidState }
      return self
    }
    guard let witness = currentConsentWitness(reference),
      reference.slot == old.requestAdmission.slot,
      let original = admission(old.requestAdmission)?.original,
      reply.structurallyMatches(old.request, original: original),
      reply.physicalTime > old.request.physicalTime,
      reply.sequence > witness.original.issuedSequence,
      reply.physicalTime >= witness.original.issuedTime,
      !terminals.contains(where: { $0.effect.admission.slot == reference.slot }),
      reply.decision != .granted || consentWorkHasNoBarrier(reference.slot),
      acceptsNewConsentFact(
        operation: reply.operation, sequence: reply.sequence,
        physicalTime: reply.physicalTime)
    else { throw Failure.invalidState }
    var candidates = consents
    candidates[index] = .init(
      request: old.request, requestAdmission: old.requestAdmission,
      reply: reply, replyAdmission: reference, revocation: nil, revocationAdmission: nil)
    return try retainingConsents(candidates)
  }

  func retainingConsentRevocation(
    revocation: NativeHollowManifestSealConsentReply, admission reference: Reference
  ) throws -> Self {
    guard shapeValid, phase != .unadmitted, consentOperationsAreUnique,
      let index = consents.firstIndex(where: { $0.request.operation == revocation.request })
    else { throw Failure.invalidState }
    let old = consents[index]
    if let retained = old.revocation {
      guard retained == revocation, old.revocationAdmission == reference else {
        throw Failure.invalidState
      }
      return self
    }
    guard let witness = currentConsentWitness(reference),
      reference.slot == old.requestAdmission.slot,
      let original = admission(old.requestAdmission)?.original, let reply = old.reply,
      revocation.structurallyMatches(old.request, original: original, previous: reply),
      revocation.sequence > witness.original.issuedSequence,
      revocation.physicalTime >= witness.original.issuedTime,
      !terminals.contains(where: { $0.effect.admission.slot == reference.slot }),
      consentRevocationHasCause(slot: reference.slot, reply: reply, revocation: revocation),
      acceptsNewConsentFact(
        operation: revocation.operation, sequence: revocation.sequence,
        physicalTime: revocation.physicalTime)
    else { throw Failure.invalidState }
    var candidates = consents
    candidates[index] = .init(
      request: old.request, requestAdmission: old.requestAdmission,
      reply: reply, replyAdmission: old.replyAdmission,
      revocation: revocation, revocationAdmission: reference)
    return try retainingConsents(candidates)
  }

  private func currentConsentWitness(_ reference: Reference) -> Admission? {
    guard latestAdmissions.contains(reference) else { return nil }
    return admission(reference)
  }

  private func consentWorkHasNoBarrier(_ slot: Slot) -> Bool {
    !terminals.contains(where: { $0.effect.admission.slot == slot })
      && !withdrawals.contains(where: { $0.effect.admission.slot == slot })
      && !firstCompromises.contains(where: { $0.admission.slot == slot })
  }

  private func acceptsNewConsentFact(operation: UUID, sequence: UInt64, physicalTime: Double)
    -> Bool
  {
    return !consentOperations.contains(operation) && sequence == nextSourceSequence
      && nextSourceSequence < UInt64(Int64.max) - 1
      && physicalTime.isFinite && physicalTime >= lastRetainedEffectTime && physicalTime <= 1e12
  }

  private var consentOperations: [UUID] {
    consents.flatMap {
      [$0.request.operation] + [$0.reply?.operation, $0.revocation?.operation].compactMap { $0 }
    }
  }

  private var consentOperationsAreUnique: Bool {
    Set(consentOperations).count == consentOperations.count
  }

  private func consentRevocationHasCause(
    slot: Slot, reply: NativeHollowManifestSealConsentReply,
    revocation: NativeHollowManifestSealConsentReply
  ) -> Bool {
    let causes =
      withdrawals.filter { $0.effect.admission.slot == slot }.map {
        ($0.sourceSequence, $0.effect.incident.physicalTime)
      }
      + firstCompromises.filter { $0.admission.slot == slot }.map {
        ($0.sourceSequence, $0.facts.cause.physicalTime)
      }
    return causes.contains { sequence, time in
      sequence > reply.sequence && sequence < revocation.sequence
        && time >= reply.physicalTime && time <= revocation.physicalTime
    }
  }

  private func retainingConsents(_ candidates: [Consent]) throws -> Self {
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: candidates, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory, wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else {
      throw Failure.invalidState
    }
    return candidate
  }
}

extension NativeHollowManifestState {
  /// Pure untrusted retention only. The component producer owns actual pre/post kernel facts,
  /// native attribution and atomic physical/source publication; energy alone supplies no cause.
  func retainingSealDamage(
    facts: NativeHollowManifestSealDamageFacts, admission reference: Reference
  ) throws -> Self {
    guard shapeValid, phase != .unadmitted, sealCauseDoesNotCollideWithRoot(facts.cause.id)
    else { throw Failure.invalidState }
    let known = firstCompromises + [latestSealDamage].compactMap { $0 }
    if let old = known.first(where: { $0.facts.cause.id == facts.cause.id }) {
      guard old.facts == facts, old.admission == reference else { throw Failure.invalidState }
      return self
    }
    guard latestAdmissions.contains(reference), let witness = admission(reference),
      !terminals.contains(where: { $0.effect.admission.slot == reference.slot }),
      facts.structurallyMatches(
        .init(
          original: witness.original, geometry: witness.geometry,
          originalComponentEnergy: birth.fit.sealEnergy)),
      facts.cause.physicalTime >= lastRetainedEffectTime,
      nextSourceSequence < UInt64(Int64.max) - 1,
      damageRevision < UInt64(Int64.max) - 1
    else { throw Failure.invalidState }
    if let latestSealDamage {
      guard facts.cause.id > latestSealDamage.facts.cause.id,
        facts.cause.physicalTime >= latestSealDamage.facts.cause.physicalTime
      else { throw Failure.invalidState }
      if latestSealDamage.admission.slot == reference.slot {
        guard facts.beforeEnergy == latestSealDamage.facts.afterEnergy else {
          throw Failure.invalidState
        }
      }
    }
    let effect = SealEffect(admission: reference, sourceSequence: nextSourceSequence, facts: facts)
    var first = firstCompromises
    if let previous = first.first(where: { $0.admission.slot == reference.slot }) {
      guard facts.beforeEnergy <= previous.facts.afterEnergy else { throw Failure.invalidState }
    } else {
      guard first.count < 2, facts.beforeEnergy == birth.fit.sealEnergy else {
        throw Failure.invalidState
      }
      first.append(effect)
    }
    var candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: first,
      latestSealDamage: effect, damageRevision: damageRevision + 1, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory, wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    // Replacing the one latest watermark may release its old admission witness. All first,
    // latest, consent, withdrawal and terminal references remain retained exactly as before.
    let retained = Set(candidate.retainedReferences)
    candidate = Self(
      birth: candidate.birth, phase: candidate.phase,
      nextSourceSequence: candidate.nextSourceSequence,
      admissions: candidate.admissions.filter { retained.contains($0.reference) },
      firstAdmissions: candidate.firstAdmissions, latestAdmissions: candidate.latestAdmissions,
      terminals: candidate.terminals, consents: candidate.consents,
      firstCompromises: candidate.firstCompromises, latestSealDamage: candidate.latestSealDamage,
      damageRevision: candidate.damageRevision, withdrawals: candidate.withdrawals,
      routeAnchors: candidate.routeAnchors, sourceFrame: candidate.sourceFrame,
      ownedEncounterID: candidate.ownedEncounterID, routes: candidate.routes,
      inspections: candidate.inspections, laboratory: candidate.laboratory, wakeTrail: candidate.wakeTrail, custodyRegister: candidate.custodyRegister, crewSource: candidate.crewSource, crewLogAccess: candidate.crewLogAccess, caseFile: candidate.caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else {
      throw Failure.invalidState
    }
    return candidate
  }

  private func sealCauseDoesNotCollideWithRoot(_ id: UInt64) -> Bool {
    (terminals.flatMap { rootEvents($0.effect) } + withdrawals.flatMap { rootEvents($0.effect) })
      .allSatisfy { $0.identity.id != id }
  }
}
