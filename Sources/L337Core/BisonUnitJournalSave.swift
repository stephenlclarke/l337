import Foundation

/// An archive checksum/presence join, never actor admission or physical state.
struct BisonUnitJournalCheckpoint: Codable, Equatable, Sendable {
  let version: Int
  let journalWireVersion: Int
  let configuration: String
  let sourceSHA256: String
  let commissioningSHA256: String
  let checkpointSHA256: String

  fileprivate init(checkpointSHA256: String) {
    version = 1
    journalWireVersion = 2
    configuration = CurrentBisonWideShoePhysicalSource.configurationID
    sourceSHA256 = CurrentBisonWideShoePhysicalSource.sourceSHA256
    commissioningSHA256 = CurrentBisonWideShoePhysicalSource.commissioningSHA256
    self.checkpointSHA256 = checkpointSHA256
  }
  private enum CodingKeys: String, CodingKey {
    case version, journalWireVersion, configuration, sourceSHA256, commissioningSHA256, checkpointSHA256
  }
  init(from decoder: any Decoder) throws {
    try validateCabinRecordKeys(decoder, ["version", "journalWireVersion", "configuration", "sourceSHA256",
      "commissioningSHA256", "checkpointSHA256"])
    let v = try decoder.container(keyedBy: CodingKeys.self)
    version = try v.decode(Int.self, forKey: .version)
    journalWireVersion = try v.decode(Int.self, forKey: .journalWireVersion)
    configuration = try v.decode(String.self, forKey: .configuration)
    sourceSHA256 = try v.decode(String.self, forKey: .sourceSHA256)
    commissioningSHA256 = try v.decode(String.self, forKey: .commissioningSHA256)
    checkpointSHA256 = try v.decode(String.self, forKey: .checkpointSHA256)
    guard self == Self(checkpointSHA256: checkpointSHA256), checkpointSHA256.count == 64,
      checkpointSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
      throw SaveError.invalidCommander
    }
  }
}

enum BisonUnitJournalSave {
  static let journalField = "savedBisonUnitAllocations"
  static let checkpointField = "bisonUnitJournalCheckpoint"
  enum Location: Equatable { case pointer, commander, world, other }

  static func checkpoint(_ commander: borrowing Commander) throws -> BisonUnitJournalCheckpoint? {
    guard let journal = commander.savedBisonUnitAllocations else { return nil }
    guard journal.valid(in: commander) else { throw SaveError.invalidCommander }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(journal)
    guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
    return .init(checkpointSHA256: ScriptPackLibrary.hash(data))
  }

  static func validateLeaf(_ data: Data) throws {
    guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
    let journal = try JSONDecoder().decode(BisonUnitAllocationJournal.self, from: data)
    try exactLeaf(data, encoded: JSONEncoder().encode(journal))
  }

  /// Reuse the bounded exact-key lexical walker rather than materializing
  /// unrelated missions/contracts as a second full JSON object tree.
  static func validateFields(_ data: Data, location: Location) throws {
    try ScriptSaveJSONPreflight.validateBisonJournalFields(data, location: location)
  }

  static func validateCheckpointLeaf(_ data: Data) throws {
    let binding = try JSONDecoder().decode(BisonUnitJournalCheckpoint.self, from: data)
    try exactLeaf(data, encoded: JSONEncoder().encode(binding))
  }

  private static func exactLeaf(_ data: Data, encoded: Data) throws {
    guard let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary,
      original.isEqual(try JSONSerialization.jsonObject(with: encoded)) else { throw SaveError.invalidCommander }
  }

  static func sceneIsConsistent(_ bodies: [SpaceBody], commander: Commander) -> Bool {
    // This version cannot own a configured published Bison, with or without a
    // journal. Ordinary bare SH005 and independent SH029 follow their own rules.
    guard !bodies.contains(where: { body in
      let physical = (copy body).physical
      return physical?.currentNewtKitStock?.issue.configuration == CurrentBisonWideShoePhysicalSource.configurationID
        || physical?.currentNewtKitReceipt?.issue.configuration == CurrentBisonWideShoePhysicalSource.configurationID
    }) else { return false }
    guard let journal = commander.savedBisonUnitAllocations else { return true }
    return journal.unpublishedSceneIsConsistent(bodies, commander: commander)
  }

  static func preparedWorld(_ world: ScriptWorldSave, commander: Commander) throws -> ScriptWorldSave {
    let expected = try checkpoint(commander)
    guard world.bisonUnitJournalCheckpoint == nil || world.bisonUnitJournalCheckpoint == expected,
      sceneIsConsistent(world.bodies, commander: commander) else { throw SaveError.invalidCommander }
    var result = world
    result.bisonUnitJournalCheckpoint = expected
    return result
  }

  static func validateArchive(commander: Commander, world: ScriptWorldSave,
    pointer: BisonUnitJournalCheckpoint?) throws {
    let expected = try checkpoint(commander)
    guard pointer == expected, world.bisonUnitJournalCheckpoint == expected,
      sceneIsConsistent(world.bodies, commander: commander) else { throw SaveError.invalidCommander }
  }

  static func validatePreservation(from before: Game, to candidate: Game) throws {
    guard before.commander.savedBisonUnitAllocations == candidate.commander.savedBisonUnitAllocations,
      sceneIsConsistent(before.bodies, commander: before.commander),
      sceneIsConsistent(candidate.bodies, commander: candidate.commander) else { throw SaveError.invalidCommander }
  }
}
