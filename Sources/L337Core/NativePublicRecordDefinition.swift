import Foundation

/// Original C37 opening only. Later measured and receiving stages are separate native work.
enum NativePublicRecordDefinition {
  static let sourceID = NativePublicRecordOriginalReward.source
  static let missionID = "public-record"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5"
  static let issuer = NativePublicRecordOriginalStage.accept.world
  static let issuerName = NativePublicRecordOriginalStage.accept.location
  static let contactRole = "Dispatcher Neris Sol"
  static let acceptReceipt = sourceID + "/accept"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "4f8ac9ebc5d0fab679c99f77f4b4c16947a93b030941d3b10ee688fd8877ee80"
  static let manifestSHA256 = "10b3968028ad67cd7aa8738750103910e60029783603a1d79e9a7c81e9428da9"
  static let moduleSHA256 = "cb8c82f6f8a9df9676c71dd99742f675c78190c983bf34e06681295dc69a357f"
  static let briefing = [
    "SOL: A story that cannot survive an independent reading is not ready to publish.",
    NativePublicRecordOriginalStage.accept.dialogue,
  ]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("public-record-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == stateID { return true }
    if instance.digest == digest { return true }
    return instance.savedPublicRecord != nil
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
      && pack.manifest.mission.milestones == NativePublicRecordOriginalStage.allCases.map(\.objective)
  }

  /// The original native case cannot declare generic provider or material authority.
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else { return }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
    else { throw MissionPackError("Restore the original Public Record case.") }
  }
}

extension ScriptPackLibrary {
  static var bundledPublicRecordDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-public-record")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// Actual independent readings, immutable evidence, reply permissions and receiving belong to native transactions.
  func validatePublicRecordScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    let protected = NativePublicRecordDefinition.applies(pack)
    if !protected, !NativePublicRecordDefinition.marked(state) { return }
    guard NativePublicRecordDefinition.matches(pack),
      NativePublicRecordSave.prefixValid(state),
      let saved = state.savedPublicRecord,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedPublicRecord == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativePublicRecordDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativePublicRecordDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original Public Record contact, custody and physical-stage transactions.") }
  }
}
