import Foundation

/// Historical examination of recorded evidence. Neither this Codable value nor its identity
/// proves a shipment, witness knowledge, legal finding, receiving permission or a live source.
struct NativeC03RegisterComparison: Codable, Equatable, Sendable {
  enum Finding: String, Codable, Equatable, Sendable {
    case conflictingCargoDeclarations = "conflicting-cargo-declarations"
  }

  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let register: UUID
    let contentsHash: String
    let laboratory: UUID
    let sealAnalysis: UUID
    let inspections: [UUID]
    let wakeObservations: [UUID]
    let finding: Finding
  }

  let operation: UUID
  let facts: Facts

  private init(facts: Facts) throws {
    self.facts = facts
    operation = try Self.identity(facts)
  }

  /// Used before a containing recovery receipt or current save hashes this child.
  var bounded: Bool { Self.factsBounded(facts) }
  var shapeValid: Bool { bounded && operation == (try? Self.identity(facts)) }

  private static func factsBounded(_ facts: Facts) -> Bool {
    guard facts.inspections.count == 2, facts.wakeObservations.count == 3,
      facts.contentsHash.utf8.count == 64,
      ScriptCompletionReceipt.validDigest(facts.contentsHash)
    else { return false }
    return Set(facts.inspections).count == 2 && Set(facts.wakeObservations).count == 3
  }

  static func identity(_ facts: Facts) throws -> UUID {
    guard factsBounded(facts) else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-original-register-comparison-v1:\(try NativeFlightReception.hash(facts))")
  }

  /// Pure historical candidate only. The original archive recovery producer separately
  /// checks the physical read, source admission, real kit and atomic publication.
  /// Do not call state.shapeValid/register.valid here: register validation recomputes us.
  static func examining(_ state: borrowing NativeHollowManifestState,
    contents: NativeC03CustodyRegisterContent) throws -> Self
  {
    guard state.birth.shapeValid, state.phase != .unadmitted,
      contents.valid(in: state), state.custodyRegister?.origin.contents == contents,
      let lab = state.laboratory, lab.valid(in: state),
      let trail = state.wakeTrail, trail.observations.count == 3, trail.valid(in: state),
      contents.master == lab.facts.analysis.facts.master,
      contents.seals.count == 2, lab.facts.analysis.facts.observations.count == 2,
      contents.wakeObservations == trail.observations.map(\.operation),
      contents.recordedCargo != contents.insuranceDeclaration
    else { throw SaveError.invalidCommander }
    for (entry, observation) in zip(contents.seals, lab.facts.analysis.facts.observations) {
      guard entry.source == observation.source, entry.hull == observation.hull,
        entry.seal == observation.seal, entry.imprint == observation.imprint
      else { throw SaveError.invalidCommander }
    }
    return try .init(facts: .init(mission: contents.mission, owner: contents.owner,
      register: contents.serial, contentsHash: NativeFlightReception.hash(contents),
      laboratory: lab.operation, sealAnalysis: lab.facts.analysis.operation,
      inspections: lab.facts.analysis.facts.observations.map(\.inspection),
      wakeObservations: trail.observations.map(\.operation), finding: .conflictingCargoDeclarations))
  }

  /// Even a correctly rehashed child must match the retained originals and actual lab result.
  func valid(in state: borrowing NativeHollowManifestState,
    contents: NativeC03CustodyRegisterContent) -> Bool
  {
    guard shapeValid else { return false }
    return self == (try? Self.examining(state, contents: contents))
  }
}

extension Game {
  /// Read through the actual held original kit. Historical analysis alone cannot expose
  /// a missing, uncollected or consumed kit's register as currently accessible evidence.
  func hollowManifestRegisterComparisonLines() -> [String] {
    guard hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery != nil else {
      return []
    }
    guard let held = try? hollowManifestHeldRegisterData(),
      let state = hollowManifestMission?.savedHollowManifest,
      held.comparison.valid(in: state, contents: held.contents)
    else {
      return ["The register comparison is unavailable. Restore access to the original held inspection kit."]
    }
    return [
      "REGISTER COMPARISON / TWO OBSERVED SEALS / THREE RECORDED WAKE MARKS",
      "The recovered register identifies the same two original seals examined by the laboratory.",
      "Its wake references match all three original recorded observations.",
      "REGISTER CLAIM: sealed refinery waste. INSURANCE DECLARATION: machinery.",
      "Those declarations conflict. The register also claims that the crew were not told the contents.",
      "These are recovered document claims, not proof of actual cargo, warehouse dates, crew knowledge or responsibility.",
      "Rescue the original crew and obtain its unaltered log before Toren can reconcile the complete ledger.",
    ]
  }
}
