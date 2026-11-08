import Foundation

/// Original C02 commission only. Actual signals, custody and protocol producers remain separate.
enum NativeQuietChoirDefinition {
  static let sourceID = NativeC02HistoryPrerequisites.logicalSourceID
  static let missionID = "quiet-choir"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60"
  static let issuer = NativeC02OriginalStage.accept.world
  static let issuerName = NativeC02OriginalStage.accept.location
  static let contactRole = "Captain Tamsin Holt"
  static let acceptReceipt = "quiet-choir-accept"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "1d75ade69e03918f911a617f177a5c1e42c1d5d6da378a663dd016726593e170"
  static let manifestSHA256 = "c8cc4cef754f24b61bc262f0a0fbe8196d91031057fecf28703622ea7ce675b6"
  static let moduleSHA256 = "60c1c8cca2ffe0f2bb14cc927f015a095b1e1c3860ac41ee24c9aa8f4027dbfe"
  static let briefing = [
    "Captain Tamsin Holt: No one has proved these pulses are an attack. Calibrate your receiver at Lobagom before approaching the source. Agent Mara Vale will compare what you find with the mining relays.",
    NativeC02OriginalStage.accept.dialogue,
  ]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("quiet-choir-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == stateID { return true }
    if instance.digest == digest { return true }
    return instance.savedQuietChoir != nil
  }

  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID || pack.digest == digest
  }

  static func matches(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
      && ScriptPackLibrary.hash(pack.manifestBytes) == manifestSHA256
      && ScriptPackLibrary.hash(pack.source) == moduleSHA256 && pack.entryBytes == pack.source
      && pack.models.isEmpty && pack.resourceBytes.isEmpty
      && pack.manifest.board == nil && pack.manifest.providerContract == nil
      && pack.manifest.equipment == nil && pack.manifest.encounters == nil
      && pack.manifest.npcs == nil && pack.manifest.modules == nil && pack.manifest.trial == nil
      && pack.manifest.handlers.count == 1
      && pack.manifest.handlers.first?.event == "mission.accepted"
      && pack.manifest.handlers.first?.function == "accepted"
      && Set(pack.manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
      && pack.manifest.mission.milestones == NativeC02OriginalStage.allCases.map(\.objective)
  }

  /// The original native investigation cannot declare generic provider or field-source authority.
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else { return }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
    else { throw MissionPackError("Restore the original Quiet Choir investigation.") }
  }
}

extension ScriptPackLibrary {
  static var bundledQuietChoirDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-quiet-choir")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// All physical stages, energy, custody, rewards and closure belong to native transactions.
  func validateQuietChoirScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    let protected = NativeQuietChoirDefinition.applies(pack)
    if !protected, !NativeQuietChoirDefinition.marked(state) { return }
    guard NativeQuietChoirDefinition.matches(pack),
      NativeQuietChoirSave.prefixValid(state),
      let saved = state.savedQuietChoir,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedQuietChoir == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeQuietChoirDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeQuietChoirDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original A Choir Beneath the Static contact, custody and physical-stage transactions.") }
  }
}
