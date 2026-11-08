import Foundation

typealias ScriptPublisher = @Sendable (inout Game) throws -> Void

/// Immutable earlier DATA from this synchronous actor turn. It grants no source
/// authority; the current root still validates every candidate before publication.
private struct NativeC03PublicationHistory: Sendable {
  let states: [UUID: NativeHollowManifestState]
  let complete: Bool

  init(_ commander: borrowing Commander) {
    let observed = commander.withReadOnlyScriptState { script -> (
      [UUID: NativeHollowManifestState], Bool
    ) in
      var retained: [UUID: NativeHollowManifestState] = [:]
      // Iterate small keys and borrow the indexed value. Iterating values would
      // materialize whole ScriptInstance payloads before selecting C03 history.
      for key in script.instances.keys {
        guard let index = script.instances.index(forKey: key),
          Self.retain(script.instances[index].value, in: &retained)
        else { return (retained, false) }
      }
      return (retained, true)
    }
    states = observed.0
    complete = observed.1
  }

  @inline(never)
  private static func retain(
    _ instance: borrowing ScriptInstance, in retained: inout [UUID: NativeHollowManifestState]
  ) -> Bool {
    guard NativeHollowManifestCommission.marked(instance) else { return true }
    guard retained.isEmpty, let state = instance.savedHollowManifest else { return false }
    retained[instance.id] = state
    return true
  }

  @inline(never)
  private static func preserves(
    _ instance: borrowing ScriptInstance, earlier: NativeHollowManifestState
  ) -> Bool {
    guard NativeHollowManifestCommission.marked(instance),
      let candidate = instance.savedHollowManifest else { return false }
    return candidate.birth == earlier.birth && candidate.preservesHistory(of: earlier)
  }

  func requirePreserved(in commander: borrowing Commander) throws {
    guard complete else { throw SaveError.invalidCommander }
    let preserved = commander.withReadOnlyScriptState { current in
      for (id, earlier) in states {
        guard let index = current.instances.index(forKey: id),
          Self.preserves(current.instances[index].value, earlier: earlier) else { return false }
      }
      return true
    }
    guard preserved else { throw SaveError.invalidCommander }
  }
}

extension GameRuntime {
  /// Captures value paths and a bounded Sendable, non-authoritative observation reference.
  /// No writer, actor or interpreter callback escapes this turn.
  func scriptPublisher(
    requireNativeSalvage: Bool = false, requireNativeMainArrival: Bool = false, diagnosticBoundary: ScriptRefusalBoundary = .publication,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) -> ScriptPublisher? {
    guard game.requiresScriptDurability || requireNativeSalvage || requireNativeMainArrival,
      let url = scriptSaveURL else {
      return nil
    }
    let namespace = galleryNamespace
    let diagnostics = scriptRefusalDiagnostic
    let c03History = NativeC03PublicationHistory(game.commander)
    return { candidate in
      try c03History.requirePreserved(in: candidate.commander)
      let prepared = try Self.prepareScriptPublication(
        &candidate, to: url, namespace: namespace, diagnostics: diagnostics,
        diagnosticBoundary: diagnosticBoundary)
      try c03History.requirePreserved(in: prepared.commander)
      let alienPublication: AlienStoragePublication?
      do {
        alienPublication = try Self.writeScriptPublication(
          prepared, to: url, namespace: namespace,
          exclusive: candidate.pendingNewSaveDestination == url, diagnostics: diagnostics,
          diagnosticBoundary: diagnosticBoundary, navigationBinding: navigationBinding)
      } catch {
        Self.recordScriptPublicationFailure(
          prepared, error: error, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
        throw error
      }
      Self.commitScriptPublication(
        prepared, alienPublication: alienPublication, to: url, candidate: &candidate)
    }
  }

  /// Return only immutable native ownership before the encoder call chain begins.
  @inline(never)
  private static func prepareScriptPublication(
    _ candidate: inout Game, to url: URL, namespace: URL?,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary
  ) throws -> NativeSavePreparation {
    try Self.requireGalleryFileAccess(url, namespace: namespace)
    let originalJournal = candidate.commander.savedBisonUnitAllocations
    // Both publication paths pin current policy before choosing the save schema.
    try candidate.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    if candidate.commander.scriptState.calendarLedger == nil {
      let legacy =
        candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
      candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
      if candidate.jumpCountdown != nil {
        candidate.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    try candidate.persistScriptActorsChecked()
    candidate.inductionArkDockPublicationPending = false
    candidate.inductionRescueDockPublicationPending = false
    candidate.inductionUtilityWorkRuntime.dirty = false
    candidate.inductionUtilityWorkRuntime.publishedSeconds =
      candidate.inductionUtilityQualifiedSeconds
    guard candidate.commander.savedBisonUnitAllocations == originalJournal else { throw SaveError.invalidCommander }
    return try Self.prepareNativeSaveState(
      candidate, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }

  @inline(never)
  private static func writeScriptPublication(
    _ prepared: NativeSavePreparation, to url: URL, namespace: URL?, exclusive: Bool,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary,
    navigationBinding: ScriptNavigationTradeBinding?
  ) throws -> AlienStoragePublication? {
    try ScriptSaveStore.write(
      commander: prepared.commander,
      world: try BisonUnitJournalSave.preparedWorld(prepared.game.scriptWorldSave, commander: prepared.commander), to: url,
      scope: namespace == nil ? "commander" : "gallery",
      exclusive: exclusive, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary,
      navigationBinding: navigationBinding)
  }

  @inline(never)
  private static func recordScriptPublicationFailure(
    _ prepared: NativeSavePreparation, error: any Error,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary
  ) {
    diagnostics?.record(
      diagnosticBoundary, .init(stage: .storeWrite, error: error, game: prepared.game))
  }

  /// The original whole-candidate copy and post-publication effects stay together.
  @inline(never)
  private static func commitScriptPublication(
    _ prepared: NativeSavePreparation, alienPublication: AlienStoragePublication?, to url: URL,
    candidate: inout Game
  ) {
    candidate = prepared.game
    candidate.commander.publishAlienStorage(alienPublication)
    candidate.recordNewCommanderSavePublication(to: url)
  }

  /// User commands are staged before a frame is published. Disk failure publishes no
  /// command effects; autonomous physics uses a separate proposal-only barrier.
  func commitScriptCommand(
    from before: Game, navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws {
    var stage = ScriptRefusalStage.commandFlush
    do {
      let c03History = NativeC03PublicationHistory(before.commander)
      guard game.flushNativeSalvageWork() else { throw SaveError.invalidCommander }
      try c03History.requirePreserved(in: game.commander)
      let ownsPersistentState =
        before.requiresScriptDurability || game.requiresScriptDurability
      let changed =
        before.commander != game.commander || before.docked != game.docked
        || before.bodies != game.bodies || before.jumpCountdown != game.jumpCountdown
        || game.inductionUtilityWorkRuntime.dirty
      guard ownsPersistentState, changed else { return }
      var candidate = game
      stage = .commandPublish
      if let publish = scriptPublisher(navigationBinding: navigationBinding) {
        try publish(&candidate)
      } else if before.requiresScriptDurability, !game.requiresScriptDurability,
        let url = scriptSaveURL
      {
        // Clearing the last retained feature still replaces the bound save. Native-only
        // commanders use the existing writer without inventing a new script calendar.
        try requireGalleryFileAccess(url)
        try Self.writeCommander(&candidate, to: url)
      } else {
        return
      }
      game = candidate
    } catch {
      scriptRefusalDiagnostic?.record(
        .publication, .init(stage: stage, error: error, game: game))
      throw error
    }
  }
  func scriptCommand<T>(
    navigationBinding: ScriptNavigationTradeBinding? = nil, _ action: (inout Game) throws -> T
  ) throws -> T {
    let before = game
    do {
      let value = try action(&game)
      try commitScriptCommand(from: before, navigationBinding: navigationBinding)
      return value
    } catch {
      game = before
      throw error
    }
  }
  func nativeCommand(_ action: @Sendable (inout Game) -> Void) {
    do { try scriptCommand(action) } catch {
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  static func writeCommander(
    _ candidate: inout Game, to url: URL, navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws {
    let c03History = NativeC03PublicationHistory(candidate.commander)
    let originalJournal = candidate.commander.savedBisonUnitAllocations
    try candidate.commander.prepareEquipment()
    try candidate.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    if (candidate.requiresScriptDurability || candidate.commander.usesEconomyMiningSaveVersion
      || candidate.commander.usesModularDriveSaveVersion)
      && candidate.commander.scriptState.calendarLedger == nil
    {
      let legacy = candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
      candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
      if candidate.jumpCountdown != nil {
        candidate.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    try candidate.persistScriptActorsChecked()
    guard candidate.commander.savedBisonUnitAllocations == originalJournal else { throw SaveError.invalidCommander }
    let prepared = try Self.prepareNativeSaveState(candidate)
    try c03History.requirePreserved(in: prepared.commander)
    try writePreparedCommander(
      &candidate, prepared: prepared, to: url, navigationBinding: navigationBinding)
  }

  @inline(never)
  private static func writePreparedCommander(
    _ candidate: inout Game, prepared: NativeSavePreparation, to url: URL,
    navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    var alienPublication: AlienStoragePublication?
    if prepared.game.requiresScriptDurability {
      alienPublication = try ScriptSaveStore.write(
        commander: prepared.commander,
        world: try BisonUnitJournalSave.preparedWorld(prepared.game.scriptWorldSave, commander: prepared.commander), to: url,
        scope: prepared.game.isMissionTrial ? "gallery" : "commander",
        exclusive: candidate.pendingNewSaveDestination == url, navigationBinding: navigationBinding)
    } else {
      let data = try JSONEncoder().encode(prepared.commander)
      guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try CommanderSavePublication.write(
        data, to: url, exclusive: candidate.pendingNewSaveDestination == url)
    }
    finishCommanderPublication(
      &candidate, prepared: prepared, alienPublication: alienPublication, to: url)
  }

  // Reserve the deliberate final Game copy only after all encoding/publication work returns.
  @inline(never)
  private static func finishCommanderPublication(
    _ candidate: inout Game, prepared: NativeSavePreparation,
    alienPublication: AlienStoragePublication?, to url: URL
  ) {
    candidate = prepared.game
    candidate.commander.publishAlienStorage(alienPublication)
    candidate.recordNewCommanderSavePublication(to: url)
  }
}

extension Game {
  mutating func recordScriptFailure(_ id: UUID, error: any Error, publish: ScriptPublisher?) {
    commander.scriptState.instances[id]?.suspension = String(
      error.localizedDescription.prefix(1024))
    notify("MISSION SUSPENDED - SEE MISSION GALLERY")
    // A deterministic script/validation fault can be saved without its rejected proposal.
    // A failed filesystem write is not retried here; live native facts remain intact.
    guard error is MissionPackError, let publish else { return }
    var fault = self
    do {
      try publish(&fault)
      self = fault
    } catch { notify("MISSION SUSPENDED - SAVE UNAVAILABLE") }
  }
}

/// Actual command writer return plus installed candidate; no caller constructor.
struct NativeC01InquiryR2WriterACK: Sendable {
  let intent: NativeC01InquiryR2PublicationIntent
  fileprivate init(published intent: NativeC01InquiryR2PublicationIntent) { self.intent = intent }
}

extension GameRuntime {
  func publishC01InquiryR2Command(_ intent: NativeC01InquiryR2PublicationIntent) throws
    -> NativeC01InquiryR2WriterACK
  {
    guard game.c01InquiryR2PublicationMatches(intent), let publish = scriptPublisher() else {
      throw NativeC01InquiryStepFailure.unavailableR2Publication
    }
    var candidate = game
    try publish(&candidate)
    game = candidate
    return .init(published: intent)
  }
}
