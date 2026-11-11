import Foundation

/// Original C24 opening only. Later measured and receiving stages are separate native work.
enum NativeUnderTowDefinition {
  static let sourceID = "l337.under-tow"
  static let missionID = "under-tow"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2"
  static let issuer = SystemIdentity(galaxy: 7, system: 45)
  static let issuerName = "Luera"
  static let contactRole = "Tug Lead Mira Penn"
  static let acceptReceipt = "under-tow-accept"
  static let collectReceipt = "under-tow-collect-reference"
  static let authoredAcceptReceipt = sourceID + "/accept"
  static let authoredCollectReceipt = sourceID + "/collect-reference"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "a2d8c970cfea6ac683c004136f2c67cd7351d430437979ea1ef63d56ebd75fc6"
  static let manifestSHA256 = "35ad65273115189f0415bbbcb7d8e95664c0d39e954e582cc12697d89aff8dcf"
  static let moduleSHA256 = "a48b01984c5d43136b8d94dde9485685c47f517d16d09190cb191ab66879dc35"
  static let briefing = [
    "PENN: Matching form numbers do not make these collars fit.",
    "Tug Lead Mira Penn: An emergency transport network has standardised its forms but not the physical coupling limits of its vessels. Review the complete survey, loan and receiving requirements before confirming.",
  ]
  static let collectionDialogue = "Tug Lead Mira Penn: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity."

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c24-under-tow-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest || instance.savedUnderTow != nil
  }

  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID || pack.digest == digest
  }

  @inline(never)
  static func matches(_ pack: borrowing ScriptPack) -> Bool {
    matchesIdentity(pack)
      && ScriptPackLibrary.hash(pack.manifestBytes) == manifestSHA256
      && ScriptPackLibrary.hash(pack.source) == moduleSHA256 && pack.entryBytes == pack.source
      && pack.models.isEmpty && pack.resourceBytes.isEmpty
      && matchesDeclaration(pack)
  }

  // End large manifest projections before the separately called byte hash routines.
  @inline(never)
  private static func matchesIdentity(_ pack: borrowing ScriptPack) -> Bool {
    matchesIdentity(pack, manifest: pack.manifest)
  }

  @inline(never)
  private static func matchesIdentity(
    _ pack: borrowing ScriptPack, manifest: borrowing ScriptManifest
  ) -> Bool {
    manifest.stateID == stateID && manifest.version == version && pack.digest == digest
  }

  @inline(never)
  private static func matchesDeclaration(_ pack: borrowing ScriptPack) -> Bool {
    matchesDeclaration(pack.manifest)
  }

  @inline(never)
  private static func matchesDeclaration(_ manifest: borrowing ScriptManifest) -> Bool {
    manifest.board == nil && manifest.providerContract == nil
      && manifest.equipment == nil && manifest.encounters == nil
      && manifest.npcs == nil && manifest.modules == nil && manifest.trial == nil
      && manifest.handlers.count == 1
      && manifest.handlers.first?.event == "mission.accepted"
      && manifest.handlers.first?.function == "accepted"
      && Set(manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
  }
}

extension ScriptPackLibrary {
  static var bundledUnderTowDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-under-tow")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// All custody, physical stages, rewards and closure belong to native transactions.
  func validateUnderTowScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    guard NativeUnderTowDefinition.applies(pack)
      || NativeUnderTowDefinition.marked(state) else { return }
    guard NativeUnderTowDefinition.matches(pack),
      NativeUnderTowSave.prefixValid(state),
      let saved = state.savedUnderTow, saved.collection == nil,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedUnderTow == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeUnderTowDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeUnderTowDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original Under Tow contact, custody and physical-stage transactions.") }
  }
}
