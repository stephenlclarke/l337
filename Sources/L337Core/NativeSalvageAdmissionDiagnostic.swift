import Foundation
import os

/// Optional observation shared by private candidates, never encoded or used for admission.
/// One first failure and one first structural failure bound the entire retained record.
final class NativeSalvageAdmissionDiagnostic: Sendable {
  struct Observation: Sendable, Equatable {
    let lot: SalvageLotIdentity
    let stage: String
    let reason: String
  }
  private struct State {
    var first: Observation?
    var structural: Observation?
  }
  private let state = OSAllocatedUnfairLock(initialState: State())

  func record(lot: SalvageLotIdentity, structural: Bool, stage: String, reason: String) {
    let observation = Observation(lot: lot, stage: String(stage.prefix(64)),
      reason: String(reason.prefix(160)))
    state.withLock {
      if $0.first == nil { $0.first = observation }
      if structural && $0.structural == nil { $0.structural = observation }
    }
  }

  var observations: [Observation] {
    state.withLock { [$0.first, $0.structural].compactMap { $0 } }
  }

  func detail() -> String {
    observations.map {
      "section=\($0.lot.section.section),lot=\($0.lot.lot),stage=\($0.stage),reason=\($0.reason)"
    }.joined(separator: " | ")
  }
}

extension Game {
  /// Reads the retained allocator witness only. No admission or geometry query is repeated.
  func recordNativeSalvageAdmissionRefusal(
    lot: SalvageLotIdentity, stage: String, reason: String
  ) {
    guard let diagnostic = nativeSalvageAdmissionDiagnostic else { return }
    let plan = commander.alienStorageState?.current.salvage.native.plansByWreck[lot.section.wreck]?
      .first { $0.plan.section == lot.section }
    let structural = lot.lot == 0 && (plan?.progress.structuralUnits ?? 0) > 0
    diagnostic.record(lot: lot, structural: structural, stage: stage, reason: reason)
  }

  func recordNativeSalvageAdmissionRefusal(
    request: SpawnRequest?, stage: String, reason: String
  ) {
    guard nativeSalvageAdmissionDiagnostic != nil,
      let request, request.identity.producer == .salvage,
      case .salvage(let identity)? = request.payload
    else { return }
    recordNativeSalvageAdmissionRefusal(lot: identity, stage: stage, reason: reason)
  }
}
