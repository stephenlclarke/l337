import Foundation
import Testing

@testable import L337Core

/// Negative claims derived only from an existing genuine native mission result.
enum NativeIsolationPublicationAssertions {
  enum Corruption {
    case missingChild, orphanedSource, lateReturn, reorderedPaidProofs, wrongLossCause
  }

  static func reject(_ corruption: Corruption, runtime: GameRuntime, at save: URL) async throws {
    let before = await runtime.snapshot()
    try #require(before.commander.valid && before.scriptWorldSave.valid)
    let invalid = try candidate(corruption, from: before.commander)
    let directory = save.deletingLastPathComponent()
    let files = try disk(directory)
    let world = before.scriptWorldSave
    #expect(throws: SaveError.self) {
      _ = try ScriptSaveStore.write(commander: invalid, world: before.scriptWorldSave, to: save)
    }
    let afterDirect = try disk(directory)
    try #require(afterDirect.paths == files.paths && afterDirect.files == files.files)
    // The action itself cannot throw: the real transaction must reject publication and roll back.
    await #expect(throws: SaveError.self) {
      try await runtime.scriptCommand { candidate in candidate.commander = invalid }
    }
    let after = await runtime.snapshot()
    let afterCommand = try disk(directory)
    let commanderUnchanged = after.commander == before.commander
    #expect(commanderUnchanged)
    #expect(after.scriptWorldSave == world)
    #expect(afterCommand.paths == files.paths && afterCommand.files == files.files)
  }

  /// Untrusted negative mission data, shared by actual publication and current-load checks.
  static func candidate(_ corruption: Corruption, from original: Commander) throws -> Commander {
    try #require(validators(original) == [true, true, true])
    try #require(original.valid)
    let parent = try #require(original.isolationParentInstance())
    let proof = try #require(parent.savedIsolationWorkParent)
    var changed = original
    let expected: [Bool]
    switch corruption {
    case .missingChild:
      try #require(parent.outcome == .active && proof.terminal == nil)
      let removed = changed.scriptState.instances.removeValue(
        forKey: NativeIsolationWorkPack.instance(source: proof.source))
      try #require(removed != nil)
      expected = [false, true, true]
    case .orphanedSource:
      guard case .returned? = proof.cutoff else {
        throw SaveError.invalidCommander
      }
      changed.scriptState.instances.removeValue(forKey: parent.id)
      expected = [true, false, true]
    case .lateReturn, .reorderedPaidProofs, .wrongLossCause:
      var invalidParent = parent
      var invalidProof = proof
      invalidProof.terminal = try terminal(corruption, proof: proof)
      invalidParent.savedIsolationWorkParent = invalidProof
      changed.scriptState.instances[parent.id] = invalidParent
      expected = [true, true, false]
    }
    let invalid = changed
    // Structural/generic validity must not stand in for the missing native graph joins.
    try #require(invalid.scriptState.instances.values.allSatisfy {
      NativeIsolationLeafValidation.valid($0)
    })
    try #require(invalid.valid)
    try #require(validators(invalid) == expected)
    return invalid
  }

  /// Wrap the already-attained loss; no new hull, people, damage or loss fact is created.
  static func rejectWrongLossCause(_ game: Game) async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    try await reject(.wrongLossCause, runtime: runtime, at: files.save)
  }

  private static func validators(_ commander: borrowing Commander) -> [Bool] {
    [NativeIsolationWorkParentSave.validateClaims(commander),
      NativeIsolationWorkSave.validateClaims(commander),
      NativeIsolationContractSave.validateClaims(commander)]
  }

  private static func terminal(
    _ corruption: Corruption, proof: NativeIsolationWorkParentState
  ) throws -> NativeIsolationContractTerminal {
    let original = try #require(proof.terminal)
    let facts = original.facts
    var dock = facts.dock
    var returned = facts.returnedCommand
    var verifications = facts.verifications
    var failure = facts.failure
    switch corruption {
    case .lateReturn:
      guard case .returned(let actual)? = proof.cutoff else {
        throw SaveError.invalidCommander
      }
      try #require(facts.outcome == .abandoned && facts.returnedCommand == nil && facts.dock == nil)
      try #require(actual.sequence > facts.sequence)
      dock = actual.dock
      returned = actual.operation
    case .reorderedPaidProofs:
      try #require(facts.outcome == .complete && verifications.count == 2)
      try #require(verifications[0] != verifications[1])
      verifications.reverse()
    case .wrongLossCause:
      guard case .lost(let actual)? = proof.cutoff else {
        throw SaveError.invalidCommander
      }
      try #require(facts.outcome == .failed && facts.failure == .programmer(actual.operation))
      try #require(actual.operation != proof.issue.operation)
      failure = .programmer(proof.issue.operation)
    case .missingChild, .orphanedSource:
      throw SaveError.invalidCommander
    }
    let invalid = NativeIsolationContractTerminalFacts(
      parent: facts.parent, authorization: facts.authorization, issueOperation: facts.issueOperation,
      owner: facts.owner, source: facts.source, outcome: facts.outcome, sequence: facts.sequence,
      physicalTime: facts.physicalTime, cause: facts.cause, dock: dock, returnedCommand: returned,
      verifications: verifications, proofs: facts.proofs, failure: failure)
    // Recompute only an untrusted structural identity; no private native witness is constructed.
    let candidate = NativeIsolationContractTerminal(
      operation: try NativeIsolationContractTerminal.identity(invalid), facts: invalid)
    try #require(candidate.shapeValid(proof: proof))
    return candidate
  }

  private static func disk(_ directory: URL) throws -> (paths: Set<String>, files: [String: Data]) {
    let enumeration = try #require(FileManager.default.enumerator(atPath: directory.path))
    let paths = Set(enumeration.allObjects.compactMap { $0 as? String })
    return (paths, try ScriptFinanceTestFixture.files(directory))
  }
}
