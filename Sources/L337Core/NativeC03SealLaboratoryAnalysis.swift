import Foundation

/// Historical analysis of two already recorded original measurements. Codable data and this
/// result never supply consent, a live source, a physical observation or a receiving permission.
struct NativeC03SealLaboratoryAnalysis: Codable, Equatable, Sendable {
  struct Observation: Codable, Equatable, Sendable {
    let slot: NativeHollowManifestState.Slot
    let inspection: UUID
    let source: UUID
    let hull: UUID
    let seal: UUID
    let imprint: UUID
    let component: UUID
    let firstFrame: UInt64
    let lastFrame: UInt64
  }

  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let master: UUID
    let observations: [Observation]
    /// Largest cross-original difference for each relief over all four recorded-pose pairs.
    /// These certify discrete snapshots, never continuous visibility or an unmeasured date.
    let reliefDifferencesMetres: [Double]
  }

  let operation: UUID
  let facts: Facts

  private init(facts: Facts) throws {
    self.facts = facts
    operation = try Self.identity(facts)
  }

  var shapeValid: Bool {
    Self.factsBounded(facts) && operation == (try? Self.identity(facts))
  }

  static func identity(_ facts: Facts) throws -> UUID {
    guard factsBounded(facts) else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-original-laboratory-pattern-comparison-v1:\(try NativeFlightReception.hash(facts))")
  }

  private static func factsBounded(_ facts: Facts) -> Bool {
    guard facts.observations.count == 2,
      facts.observations.map(\.slot) == NativeHollowManifestState.Slot.allCases,
      Set(facts.observations.map(\.inspection)).count == 2,
      Set(facts.observations.map(\.source)).count == 2,
      Set(facts.observations.map(\.hull)).count == 2,
      Set(facts.observations.map(\.seal)).count == 2,
      Set(facts.observations.map(\.imprint)).count == 2,
      Set(facts.observations.map(\.component)).count == 2,
      facts.observations.allSatisfy({
        $0.firstFrame < UInt64.max - 1 && $0.lastFrame == $0.firstFrame + 1
      }),
      facts.reliefDifferencesMetres.count == NativeC03SealGeometry.reliefs.count
    else { return false }
    return facts.reliefDifferencesMetres.allSatisfy {
      $0.isFinite && $0 >= 0
    }
  }

  /// Pure historical computation only. The native lab producer separately validates the
  /// current case/berth and actual issue transaction. Do NOT call state.shapeValid here:
  /// the state's laboratory receipt validates this child by recomputing it.
  static func examining(_ state: borrowing NativeHollowManifestState) throws -> Self {
    guard state.birth.shapeValid, state.phase != .unadmitted,
      state.inspections.count == 2
    else { throw SaveError.invalidCommander }
    for inspection in state.inspections {
      guard inspection.valid(in: state) else { throw SaveError.invalidCommander }
    }
    guard Set(state.inspections.map { $0.facts.admission.slot }) == Set(NativeHollowManifestState.Slot.allCases),
      let first = state.inspections.first(where: { $0.facts.admission.slot == .first }),
      let second = state.inspections.first(where: { $0.facts.admission.slot == .second })
    else { throw SaveError.invalidCommander }
    let ordered = [first, second]
    for inspection in ordered {
      let original = inspection.facts.original
      guard let source = state.birth.originals.first(where: { $0.slot == original.slot }),
        original.source == source.source, original.hull == source.hull,
        original.captain == source.captain, original.seal == source.seal,
        original.imprint == source.imprint, original.master == source.master,
        original.master == state.birth.master.id
      else { throw SaveError.invalidCommander }
    }
    guard first.facts.original.source != second.facts.original.source,
      first.facts.original.hull != second.facts.original.hull,
      first.facts.original.seal != second.facts.original.seal,
      first.facts.original.imprint != second.facts.original.imprint,
      first.facts.original.component != second.facts.original.component,
      first.operation != second.operation
    else { throw SaveError.invalidCommander }
    let differences = try measuredDifferences(first, second)
    let observations = ordered.map { inspection in
      let original = inspection.facts.original
      return Observation(slot: inspection.facts.admission.slot, inspection: inspection.operation,
        source: original.source, hull: original.hull, seal: original.seal, imprint: original.imprint,
        component: original.component, firstFrame: inspection.facts.firstFrame,
        lastFrame: inspection.facts.lastFrame)
    }
    return try .init(facts: .init(mission: state.birth.input.mission, owner: state.birth.input.owner,
      master: state.birth.master.id, observations: observations, reliefDifferencesMetres: differences))
  }

  // Each actual observation has already passed the source's per-relief bounds.
  // Report their differences without adding a second physical calibration threshold.
  private static func measuredDifferences(_ first: NativeHollowManifestSealInspection,
    _ second: NativeHollowManifestSealInspection) throws -> [Double]
  {
    let firstReadings = [first.facts.first.reliefHeights, first.facts.last.reliefHeights]
    let secondReadings = [second.facts.first.reliefHeights, second.facts.last.reliefHeights]
    let count = NativeC03SealGeometry.reliefs.count
    guard count > 0, (firstReadings + secondReadings).allSatisfy({ $0.count == count }) else {
      throw SaveError.invalidCommander
    }
    var differences: [Double] = []
    for index in 0..<count {
      var greatest = 0.0
      for left in firstReadings {
        for right in secondReadings {
          let difference = abs(left[index] - right[index])
          guard difference.isFinite
          else { throw SaveError.invalidCommander }
          greatest = max(greatest, difference)
        }
      }
      differences.append(greatest)
    }
    return differences
  }

  /// An internally rehashed but source-mismatched result is still invalid. Recompute from
  /// the original records rather than accepting the result's own identity or count.
  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    shapeValid && self == (try? Self.examining(state))
  }
}

extension Game {
  func hollowManifestSealComparisonLines() -> [String] {
    guard let state = hollowManifestMission?.savedHollowManifest,
      NativeHollowManifestSave.validateClaims(commander),
      (try? NativeC03SealLaboratoryAnalysis.examining(state)) != nil
    else { return ["Bring both captains' consented original seal readings for examination."] }
    return [
      "PATTERN COMPARISON: TWO DISTINCT ORIGINAL SEALS MATCH",
      "Both recorded poses of each seal match the shared master pattern within measurement bounds.",
      "The laboratory retains both original observation identities with this examination.",
    ]
  }
}
