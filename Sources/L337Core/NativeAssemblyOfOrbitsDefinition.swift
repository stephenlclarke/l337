import Foundation

/// Original C23 opening only. Later measured and receiving stages are separate native work.
enum NativeAssemblyOfOrbitsDefinition {
  static let sourceID = "l337.assembly-of-orbits"
  static let missionID = "assembly-of-orbits"
  static let stateID = sourceID + "/" + missionID
  static let version = "1.0.0"
  static let sourceSHA256 = "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514"
  static let issuer = SystemIdentity(galaxy: 6, system: 7)
  static let issuerName = "Irkenan"
  static let contactRole = "Marshal Nera Voss"
  static let acceptReceipt = "assembly-of-orbits-accept"
  static let collectReceipt = "assembly-of-orbits-collect-reference"
  static let authoredAcceptReceipt = sourceID + "/accept"
  static let authoredCollectReceipt = sourceID + "/collect-reference"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "0f81d5cc7f14c2d5b9930d450ee15fb9b65e0787951b4760df9213be295ae808"
  static let manifestSHA256 = "dd4d1326e388b5f17ed7a0072745180662679cbbbee2e0a704f8b3fe5c613f00"
  static let moduleSHA256 = "fbac637d8248a1e4beb7915dbf23074372a37d004b919b9135a859602db738f0"
  static let briefing = [
    "VOSS: A share certificate cannot stand in for the people on the next shift.",
    "Marshal Nera Voss: A cluster of orbital homes must share a single transfer corridor during a maintenance season. Review the complete survey, loan and receiving requirements before confirming.",
  ]
  static let collectionDialogue = "Marshal Nera Voss: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity."

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c23-assembly-commission-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest || instance.savedAssemblyOfOrbits != nil
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
}

extension ScriptPackLibrary {
  static var bundledAssemblyOfOrbitsDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-assembly-of-orbits")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// All custody, physical stages, rewards and closure belong to native transactions.
  func validateAssemblyOfOrbitsScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    guard NativeAssemblyOfOrbitsDefinition.applies(pack)
      || NativeAssemblyOfOrbitsDefinition.marked(state) else { return }
    guard NativeAssemblyOfOrbitsDefinition.matches(pack),
      NativeAssemblyOfOrbitsSave.prefixValid(state),
      let saved = state.savedAssemblyOfOrbits, saved.collection == nil,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.acceptance.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedAssemblyOfOrbits == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeAssemblyOfOrbitsDefinition.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeAssemblyOfOrbitsDefinition.briefing[state.journal.count]
    else { throw MissionPackError("Use the original Assembly contact, custody and physical-stage transactions.") }
  }
}
