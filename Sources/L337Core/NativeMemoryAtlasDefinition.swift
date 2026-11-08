import Foundation

/// Original C25 opening only. Later measured and receiving stages are separate native work.
enum NativeMemoryAtlasDefinition {
  static let sourceID = NativeMemoryAtlasOriginalReward.source
  static let missionID = "memory-atlas"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6"
  static let issuer = NativeMemoryAtlasOriginalStage.accept.world
  static let issuerName = NativeMemoryAtlasOriginalStage.accept.location
  static let contactRole = "Agent Mara Vale"
  static let acceptReceipt = "memory-atlas-accept"
  static let collectReceipt = "memory-atlas-collect-reference"
  static let authoredAcceptReceipt = sourceID + "/accept"
  static let authoredCollectReceipt = sourceID + "/collect-reference"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "ee7da4c00fded8856bf7407f29864e93ce30f65adf96c03ee0c2eb0280d4dbe6"
  static let manifestSHA256 = "233511e3e1336d19bd1c9231272545a1292bf493d7405bcd16f64ede22a6622f"
  static let moduleSHA256 = "6b6efafbb9d6137098e2924973f7b91f47200fbe61a84105ed7d43ba52df078c"
  static let briefing = [
    "ORR: A beautiful memory is not a measured approach vector.",
    NativeMemoryAtlasOriginalStage.accept.dialogue,
  ]
  static let collectionDialogue = NativeMemoryAtlasOriginalStage.collectReference.dialogue

  /// Attributes come from the existing watcher definition and this actual case source.
  /// This data declaration creates no item; the real issue kernel owns original creation.
  static func referenceGear(in instance: borrowing ScriptInstance) -> ScriptGearDefinition {
    NativeMemoryAtlasReferenceDefinition.gear(for: .init(mission: instance.id,
      resource: NativeMemoryAtlasReferenceDefinition.logicalResource, packDigest: instance.digest))
  }

  static func referenceSerial(mission: UUID) -> UUID {
    OwnedGear.issuedIdentity(mission: mission,
      resource: NativeMemoryAtlasReferenceDefinition.logicalResource, index: 0)
  }

  static func referenceIssuer(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c25-reris-vale-watcher-owner-v1:\(owner)")
  }

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c25-memory-atlas-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest || instance.savedMemoryAtlas != nil
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
  }

  /// The original native case declares no generic stock, issue or provider authority.
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else { return }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
    else { throw MissionPackError("Restore the original The Memory Atlas case.") }
  }
}

extension ScriptPackLibrary {
  static var bundledMemoryAtlasDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-memory-atlas")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// All custody, physical stages, rewards and closure belong to native transactions.
  func validateMemoryAtlasScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    guard NativeMemoryAtlasDefinition.applies(pack)
      || NativeMemoryAtlasDefinition.marked(state) else { return }
    guard NativeMemoryAtlasDefinition.matches(pack),
      NativeMemoryAtlasSave.prefixValid(state),
      let saved = state.savedMemoryAtlas, saved.collection == nil,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedMemoryAtlas == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeMemoryAtlasDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeMemoryAtlasDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original The Memory Atlas contact, custody and physical-stage transactions.") }
  }
}
