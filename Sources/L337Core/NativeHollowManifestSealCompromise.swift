import Foundation

/// Untrusted geometry references. Actual source admission must supply the approved physical packet.
struct NativeHollowManifestSealGeometryReference: Codable, Sendable, Equatable {
  let rootGeometryHash: String
  let sealGeometryHash: String
  let revision: UInt64
  let componentPose: ShipPose
  let rootScale: Double
  let componentScale: Double

  var shapeValid: Bool {
    [rootGeometryHash, sealGeometryHash].allSatisfy {
      $0.utf8.count == 64
        && $0.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
      && revision > 0 && revision < UInt64(Int64.max)
      && componentPose.position.finite && componentPose.position.length.isFinite
      && componentPose.orientation.validRotation && rootScale == 1 && componentScale == 1
  }
}

struct NativeHollowManifestSealCompromiseContext: Codable, Sendable, Equatable {
  let original: NativeHollowManifestOriginalSealBinding
  let geometry: NativeHollowManifestSealGeometryReference
  let originalComponentEnergy: Double

  var shapeValid: Bool {
    original.shapeValid && geometry.shapeValid
      && originalComponentEnergy.isFinite && originalComponentEnergy > 0
  }
}

/// Real native-effect data, not a CombatIncident factory or an attribution capability.
struct NativeHollowManifestSealNativeEffectCause: Codable, Sendable, Equatable {
  enum Attribution: String, Codable, Sendable { case currentVisit, frozenLaunch, unknown }

  let id: UInt64
  let physicalTime: Double
  let mission: UUID
  let victim: ActorIdentity?
  let victimPart: String?
  let component: UUID?
  let kind: AttackKind
  let outcome: AttackOutcome
  let position: Vector3
  let attribution: Attribution
  let origin: AttackOrigin?
  let terminalShot: UUID?

  var shapeValid: Bool {
    guard id > 0, physicalTime.isFinite, (0...1e12).contains(physicalTime),
      let victim, victim.entity > 1, victim.visit > 0,
      let victimPart, PackValidation.localID(victimPart), component != nil,
      [.hit, .componentDestruction].contains(outcome),
      position.finite, position.length.isFinite
    else { return false }
    if let origin {
      guard origin.emissionID > 0, origin.emittedAt.isFinite,
        origin.emittedAt >= 0, origin.emittedAt <= physicalTime,
        origin.owner.system == victim.system
      else { return false }
    }
    switch attribution {
    case .currentVisit:
      return terminalShot == nil && origin?.owner.visit == victim.visit
        && [.laser, .missile, .bomb, .plasma].contains(kind)
    case .frozenLaunch:
      return terminalShot != nil && origin != nil && kind == .plasma
    case .unknown:
      // The existing retained Script projectile path is plasma and may have no origin.
      return terminalShot != nil && kind == .plasma
    }
  }
}

/// Controlled facts can satisfy these joins. Only the future private damage kernel can supply authority.
struct NativeHollowManifestSealDamageFacts: Codable, Sendable, Equatable {
  let original: NativeHollowManifestOriginalSealBinding
  let geometry: NativeHollowManifestSealGeometryReference
  let component: UUID
  let cause: NativeHollowManifestSealNativeEffectCause
  let admittedDamage: Double
  let beforeEnergy: Double
  let afterEnergy: Double

  func structurallyMatches(_ context: NativeHollowManifestSealCompromiseContext) -> Bool {
    context.shapeValid && original == context.original && geometry == context.geometry
      && component == original.component && cause.component == component
      && cause.shapeValid && cause.mission == original.mission && cause.victim == original.actor
      && cause.victimPart == original.slot.rawValue && cause.physicalTime >= original.issuedTime
      && admittedDamage.isFinite && admittedDamage > 0
      && beforeEnergy.isFinite && beforeEnergy > 0
      && beforeEnergy <= context.originalComponentEnergy
      && afterEnergy.isFinite && afterEnergy == max(0, beforeEnergy - admittedDamage)
      && cause.outcome == (afterEnergy == 0 ? .componentDestruction : .hit)
  }
}

/// Bounded structural reducer, not installed mission state or a native damage/permission capability.
struct NativeHollowManifestSealCompromiseState: Codable, Sendable, Equatable {
  enum Failure: Error {
    case invalidState, wrongOriginal, invalidCause, staleCause, exhaustedRevision
  }

  /// A diagnostic revision stamp is deliberately not a native pending observation or grant.
  struct StructuralCandidateStamp: Sendable, Equatable {
    fileprivate let contexts: [NativeHollowManifestSealCompromiseContext]
    fileprivate let slot: NativeHollowManifestOriginalSealBinding.Slot
    fileprivate let damageRevision: UInt64
  }

  let contexts: [NativeHollowManifestSealCompromiseContext]
  private(set) var firstCompromises: [NativeHollowManifestSealDamageFacts] = []
  private(set) var latestDamage: NativeHollowManifestSealDamageFacts?
  /// Separate from C03 source operations, native incident IDs and Script event sequences.
  private(set) var damageRevision: UInt64 = 0

  init(contexts: [NativeHollowManifestSealCompromiseContext]) throws {
    self.contexts = contexts
    guard shapeValid else { throw Failure.invalidState }
  }

  var shapeValid: Bool {
    guard contexts.count == 2, contexts.allSatisfy(\.shapeValid),
      NativeHollowManifestOriginalSealBinding.rosterShapeValid(contexts.map(\.original)),
      firstCompromises.count <= 2,
      Set(firstCompromises.map { $0.original.slot }).count == firstCompromises.count,
      damageRevision < UInt64(Int64.max), damageRevision >= UInt64(firstCompromises.count)
    else { return false }
    if firstCompromises.isEmpty { return latestDamage == nil && damageRevision == 0 }
    guard let latestDamage, let latestContext = context(for: latestDamage.original.slot),
      latestDamage.structurallyMatches(latestContext),
      firstCompromises.contains(where: { $0.original.slot == latestDamage.original.slot })
    else { return false }
    let latestIsFirst = firstCompromises.contains(latestDamage)
    let minimumDamageCount = UInt64(firstCompromises.count) + (latestIsFirst ? 0 : 1)
    guard damageRevision >= minimumDamageCount else { return false }
    var lastIncident: UInt64 = 0
    var lastTime = 0.0
    for first in firstCompromises {
      guard let context = context(for: first.original.slot), first.structurallyMatches(context),
        first.beforeEnergy == context.originalComponentEnergy,
        first.cause.id > lastIncident, first.cause.physicalTime >= lastTime,
        first.cause.id <= latestDamage.cause.id,
        first.cause.physicalTime <= latestDamage.cause.physicalTime
      else { return false }
      if first.cause.id == latestDamage.cause.id, first != latestDamage { return false }
      lastIncident = first.cause.id
      lastTime = first.cause.physicalTime
    }
    return true
  }

  /// Native causes retain their own namespace; no comparison with original.issuedSequence occurs.
  func recording(_ facts: NativeHollowManifestSealDamageFacts) throws -> Self {
    guard shapeValid else { throw Failure.invalidState }
    guard let context = context(for: facts.original.slot), facts.original == context.original else {
      throw Failure.wrongOriginal
    }
    guard facts.structurallyMatches(context) else { throw Failure.invalidCause }
    if let known = firstCompromises.first(where: { $0.cause.id == facts.cause.id }) {
      guard known == facts else { throw Failure.invalidCause }
      return self
    }
    if let latestDamage {
      if latestDamage.cause.id == facts.cause.id {
        guard latestDamage == facts else { throw Failure.invalidCause }
        return self
      }
      guard facts.cause.id > latestDamage.cause.id,
        facts.cause.physicalTime >= latestDamage.cause.physicalTime
      else { throw Failure.staleCause }
    }
    guard damageRevision < UInt64(Int64.max) - 1 else { throw Failure.exhaustedRevision }
    var next = self
    if !firstCompromises.contains(where: { $0.original.slot == facts.original.slot }) {
      guard facts.beforeEnergy == context.originalComponentEnergy else {
        throw Failure.invalidCause
      }
      next.firstCompromises.append(facts)
    }
    next.latestDamage = facts
    next.damageRevision += 1
    guard next.shapeValid else { throw Failure.invalidState }
    return next
  }

  func structuralCandidateStamp(
    for slot: NativeHollowManifestOriginalSealBinding.Slot
  ) -> StructuralCandidateStamp? {
    guard shapeValid, !firstCompromises.contains(where: { $0.original.slot == slot }) else {
      return nil
    }
    return .init(contexts: contexts, slot: slot, damageRevision: damageRevision)
  }

  func matchesStructuralCandidate(_ stamp: StructuralCandidateStamp) -> Bool {
    shapeValid && contexts == stamp.contexts && damageRevision == stamp.damageRevision
      && !firstCompromises.contains(where: { $0.original.slot == stamp.slot })
  }

  private func context(
    for slot: NativeHollowManifestOriginalSealBinding.Slot
  ) -> NativeHollowManifestSealCompromiseContext? {
    contexts.first { $0.original.slot == slot }
  }
}
