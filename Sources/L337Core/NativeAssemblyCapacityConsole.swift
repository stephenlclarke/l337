import Foundation

/// Actual carried-console context only. This cannot authenticate the proposed register,
/// survey, consent, people, corridor use or either measured functional test.
final class NativeAssemblyCapacityContext: Sendable {
  let mission: UUID
  let reference: NativeAssemblyReferenceBinding
  let caseRevision: UInt64
  private let epoch: UUID
  private let digest: String

  fileprivate init(game: borrowing Game, instance: ScriptInstance,
    reference: NativeAssemblyReferenceBinding)
  {
    mission = instance.id
    self.reference = reference
    caseRevision = instance.revision
    epoch = game.nativeStationRuntimeEpoch
    digest = instance.digest
  }

  func isCurrent(in game: borrowing Game) -> Bool {
    guard !game.isMissionTrial, game.trialTitle == nil,
      game.nativeStationRuntimeEpoch == epoch,
      game.assemblyOfOrbitsPack?.digest == digest,
      let instance = game.assemblyOfOrbitsMission, instance.id == mission,
      instance.revision == caseRevision, instance.digest == digest,
      NativeAssemblyOfOrbitsSave.validateClaims(game.commander),
      let held = try? NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: game.commander)
    else { return false }
    return held == reference
  }
}

extension Game {
  /// The actual loan can support preparation while travelling or paused. The final tests
  /// still require Brekudek and their original measured source/permission, supplied separately.
  func assemblyCapacityContext() throws -> NativeAssemblyCapacityContext {
    guard !isMissionTrial, trialTitle == nil,
      let instance = assemblyOfOrbitsMission,
      assemblyOfOrbitsPack?.digest == instance.digest,
      NativeAssemblyOfOrbitsSave.validateClaims(commander)
    else { throw MissionPackError("Collect Voss's original assembly reference before using its console.") }
    let reference = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: commander)
    return .init(game: self, instance: instance, reference: reference)
  }

  /// Read-only interpretation of PLAYER CANDIDATE data. No native result can be published
  /// from this report; the real surveyed register and physical work remain separate joins.
  func previewAssemblyCapacity(_ draft: NativeAssemblyCapacityDraft,
    context: NativeAssemblyCapacityContext) throws -> NativeAssemblyCapacityAssessment
  {
    guard context.isCurrent(in: self), draft.register.mission == context.mission else {
      throw MissionPackError("The assembly case or original console changed; review its current custody.")
    }
    return try draft.assess()
  }
}
