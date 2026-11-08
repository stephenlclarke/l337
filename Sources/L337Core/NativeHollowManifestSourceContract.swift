import Foundation

/// Untrusted historical data interfaces only. Decoding or matching them grants no native authority.
struct NativeHollowManifestOriginalSealBinding: Codable, Sendable, Equatable {
  enum Slot: String, CaseIterable, Codable, Sendable {
    case first = "freighter-seal-a"
    case second = "freighter-seal-b"
  }

  let slot: Slot
  let mission: UUID
  let owner: UUID
  let source: UUID
  let hull: UUID
  let captain: UUID
  let seal: UUID
  let master: UUID
  let imprint: UUID
  let actor: ActorIdentity
  let component: UUID
  let sourceRevision: UInt64
  let issuedSequence: UInt64
  let issuedTime: Double

  /// Names/references are bounded and internally consistent, not authenticated original issuance.
  var shapeValid: Bool {
    actor.system == NativeHollowManifestDefinition.freighterWorld && actor.entity > 1
      && actor.visit > 0 && actor.visit < UInt64(Int64.max)
      && sourceRevision > 0 && sourceRevision < UInt64(Int64.max)
      && issuedSequence > 0 && issuedSequence < UInt64(Int64.max)
      && issuedTime.isFinite && (0...1e12).contains(issuedTime)
  }

  /// Two distinct original declarations share a master, never a seal, imprint, hull or captain.
  static func rosterShapeValid(_ bindings: [Self]) -> Bool {
    guard bindings.count == 2, bindings.allSatisfy(\.shapeValid),
      Set(bindings.map(\.slot)) == Set(Slot.allCases),
      let first = bindings.first,
      bindings.allSatisfy({
        $0.mission == first.mission && $0.owner == first.owner && $0.master == first.master
      }),
      Set(bindings.map(\.source)).count == 2, Set(bindings.map(\.hull)).count == 2,
      Set(bindings.map(\.captain)).count == 2, Set(bindings.map(\.seal)).count == 2,
      Set(bindings.map(\.imprint)).count == 2, Set(bindings.map(\.actor)).count == 2,
      Set(bindings.map(\.component)).count == 2
    else { return false }
    return true
  }
}

/// A request record is not a reply, grant, original-person assignment or communication ingress.
struct NativeHollowManifestSealConsentRequest: Codable, Sendable, Equatable {
  enum Purpose: String, Codable, Sendable {
    case observeOriginalCargoSeal = "observe-original-cargo-seal"
  }

  let operation: UUID
  let binding: NativeHollowManifestOriginalSealBinding
  let purpose: Purpose
  let player: ActorIdentity
  let playerHull: UUID
  let targetingEquipment: UUID
  let inventoryRevision: UInt64
  let sequence: UInt64
  let physicalTime: Double

  func structurallyMatches(_ original: NativeHollowManifestOriginalSealBinding) -> Bool {
    binding == original && original.shapeValid
      && player.system == original.actor.system && player.visit == original.actor.visit
      && player.entity == 0 && inventoryRevision < UInt64(Int64.max)
      && sequence > original.issuedSequence && sequence < UInt64(Int64.max)
      && physicalTime.isFinite && physicalTime >= original.issuedTime && physicalTime <= 1e12
  }
}

/// Records the expected causal join only. The future source must supply the real native reply.
struct NativeHollowManifestSealConsentReply: Codable, Sendable, Equatable {
  enum Decision: String, Codable, Sendable { case granted, declined, revoked }

  let operation: UUID
  let request: UUID
  let originalSource: UUID
  let captain: UUID
  let seal: UUID
  let decision: Decision
  let revision: UInt64
  let previousReply: UUID?
  let sequence: UInt64
  let physicalTime: Double

  func structurallyMatches(
    _ request: NativeHollowManifestSealConsentRequest,
    original: NativeHollowManifestOriginalSealBinding,
    previous: NativeHollowManifestSealConsentReply? = nil
  ) -> Bool {
    guard request.structurallyMatches(original), self.request == request.operation,
      originalSource == original.source, captain == original.captain, seal == original.seal,
      operation != request.operation, sequence > request.sequence, sequence < UInt64(Int64.max),
      physicalTime.isFinite, physicalTime >= request.physicalTime, physicalTime <= 1e12
    else { return false }
    if let previous {
      // This bounded protocol has one real reply and at most one irreversible revocation.
      return previous.structurallyMatches(request, original: original)
        && previous.decision == .granted && decision == .revoked
        && previousReply == previous.operation && operation != previous.operation
        && revision == 2 && sequence > previous.sequence && physicalTime >= previous.physicalTime
    }
    return previousReply == nil && revision == 1 && decision != .revoked
  }
}
