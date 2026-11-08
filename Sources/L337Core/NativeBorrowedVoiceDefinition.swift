import Foundation

/// Original rescue-channel commission only. Beacon, witness and record producers remain separate.
enum NativeBorrowedVoiceDefinition {
  static let sourceID = NativeBorrowedVoiceOriginalReward.source
  static let missionID = "borrowed-voice"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8"
  static let issuer = NativeBorrowedVoiceOriginalStage.accept.world
  static let issuerName = NativeBorrowedVoiceOriginalStage.accept.location
  static let contactRole = "Coordinator Sera Dain"
  static let acceptReceipt = "borrowed-voice-accept"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "0bd36daa29c72bc97d7f86f32298f091e03c9e04bdc5725a1ce9c15083eda278"
  static let manifestSHA256 = "367c8ccbb2cdf537a81e9e548423d6d55fd1f46c516fe8c4f72248bc3a743c6a"
  static let moduleSHA256 = "fe302d20b0dc58ba837a967cb2205068a06b437f07eec2a2f0d0b5f15fdaf6d1"
  static let briefing = [
    "SERA DAIN: Our tenders have been called to three empty wrecks. Meanwhile, a real casualty waited alone. Compare the relay records at Ilasaeli. Do not broadcast patient locations; someone may be listening with one of our own keys.",
    NativeBorrowedVoiceOriginalStage.accept.dialogue,
  ]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("borrowed-voice-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == stateID { return true }
    if instance.digest == digest { return true }
    return instance.savedBorrowedVoice != nil
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
      && pack.manifest.mission.milestones == NativeBorrowedVoiceOriginalStage.allCases.map(\.objective)
  }

  /// The original native investigation cannot declare generic provider or verifier authority.
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else { return }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
    else { throw MissionPackError("Restore the original Borrowed Voice investigation.") }
  }
}

extension ScriptPackLibrary {
  static var bundledBorrowedVoiceDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-borrowed-voice")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// All physical stages, energy, custody, rewards and closure belong to native transactions.
  func validateBorrowedVoiceScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    let protected = NativeBorrowedVoiceDefinition.applies(pack)
    if !protected, !NativeBorrowedVoiceDefinition.marked(state) { return }
    guard NativeBorrowedVoiceDefinition.matches(pack),
      NativeBorrowedVoiceSave.prefixValid(state),
      let saved = state.savedBorrowedVoice,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedBorrowedVoice == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeBorrowedVoiceDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeBorrowedVoiceDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original The Borrowed Voice contact, custody and physical-stage transactions.") }
  }
}
