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


extension Game {
  /// Recall only through the same actual carried console. A saved proposal is not a
  /// surveyed register and cannot authorize the physical capacity tests.
  func savedAssemblyCapacityDraft(_ side: NativeAssemblyCapacityDraft.Side,
    context: NativeAssemblyCapacityContext) throws -> NativeAssemblyCapacityDraft?
  {
    guard context.isCurrent(in: self),
      let state = assemblyOfOrbitsMission?.savedAssemblyOfOrbits
    else { throw MissionPackError("Use the current original Assembly console to recall a player proposal.") }
    return state.capacityDrafts?[side.rawValue]
  }

  /// Conflicting but structurally valid choices remain editable. Saving them neither
  /// dispatches a crew nor increments a mission milestone, clock, event or work receipt.
  @discardableResult
  mutating func saveAssemblyCapacityDraft(_ draft: NativeAssemblyCapacityDraft,
    context: NativeAssemblyCapacityContext) throws -> Bool
  {
    try updateAssemblyCapacityDraft(draft, side: draft.side, context: context)
  }

  @discardableResult
  mutating func clearAssemblyCapacityDraft(_ side: NativeAssemblyCapacityDraft.Side,
    context: NativeAssemblyCapacityContext) throws -> Bool
  {
    try updateAssemblyCapacityDraft(nil, side: side, context: context)
  }

  private mutating func updateAssemblyCapacityDraft(_ draft: NativeAssemblyCapacityDraft?,
    side: NativeAssemblyCapacityDraft.Side, context: NativeAssemblyCapacityContext) throws -> Bool
  {
    guard scriptDurabilityAvailable else {
      throw MissionPackError("Choose a bound commander save before changing an Assembly proposal.")
    }
    guard context.isCurrent(in: self), !scriptDispatching, !scriptEventsDeferred,
      var instance = assemblyOfOrbitsMission, instance.id == context.mission,
      var state = instance.savedAssemblyOfOrbits, state.collection != nil
    else { throw MissionPackError("The original Assembly case, console or fitting changed; review again.") }
    if let draft {
      guard draft.shapeValid, draft.side == side, draft.register.mission == instance.id
      else { throw NativeAssemblyCapacityDraft.Failure.invalidDraft }
    }
    var drafts = state.capacityDrafts ?? [:]
    if let draft {
      if drafts[side.rawValue] == draft { return false }
      drafts[side.rawValue] = draft
    } else {
      guard drafts.removeValue(forKey: side.rawValue) != nil else { return false }
    }
    guard instance.revision < UInt64(Int64.max) - 1 else { throw SaveError.invalidCommander }
    state.capacityDrafts = drafts.isEmpty ? nil : drafts
    guard state.shapeValid else { throw SaveError.invalidCommander }
    instance.savedAssemblyOfOrbits = state
    instance.revision += 1
    var candidate = commander
    candidate.scriptState.instances[instance.id] = instance
    guard NativeAssemblyOfOrbitsSave.validateClaims(candidate) else { throw SaveError.invalidCommander }
    commander = candidate
    return true
  }
}

extension GameRuntime {
  func assemblyCapacityContext() throws -> NativeAssemblyCapacityContext {
    try game.assemblyCapacityContext()
  }
  func savedAssemblyCapacityDraft(_ side: NativeAssemblyCapacityDraft.Side,
    context: NativeAssemblyCapacityContext) throws -> NativeAssemblyCapacityDraft?
  {
    try game.savedAssemblyCapacityDraft(side, context: context)
  }
  @discardableResult
  func saveAssemblyCapacityDraft(_ draft: NativeAssemblyCapacityDraft,
    context: NativeAssemblyCapacityContext) throws -> Bool
  {
    guard game.scriptDurabilityAvailable, scriptPublisher() != nil else {
      throw MissionPackError("Choose a bound commander save before changing an Assembly proposal.")
    }
    return try scriptCommand { try $0.saveAssemblyCapacityDraft(draft, context: context) }
  }
  @discardableResult
  func clearAssemblyCapacityDraft(_ side: NativeAssemblyCapacityDraft.Side,
    context: NativeAssemblyCapacityContext) throws -> Bool
  {
    guard game.scriptDurabilityAvailable, scriptPublisher() != nil else {
      throw MissionPackError("Choose a bound commander save before changing an Assembly proposal.")
    }
    return try scriptCommand { try $0.clearAssemblyCapacityDraft(side, context: context) }
  }
}
