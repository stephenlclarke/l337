import Foundation

/// Current retained-source namespace, owned by G1. No earlier envelope admits this root field.
enum NativeMemoryAtlasWatcherEnvelope {
  static let version = 143
  static let alienVersion = 144

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.savedMemoryAtlasWatcherSource != nil
  }

  /// Extract the only permitted root before Foundation can collapse duplicate keys or allocate
  /// the retained graph. The lexical gate rejects misplaced fields and nulls recursively.
  static func validateFields(
    _ data: Data, location: ScriptSaveJSONPreflight.InquiryArchiveLocation, schema: Int?,
    requireClaims: Bool = true
  ) throws {
    do {
      let permits = location == .commander && contains(schema)
      let leaf = try ScriptSaveJSONPreflight.extractMemoryAtlasWatcherSource(
        data, location: location, permitsRoot: permits)
      guard let leaf else {
        guard !permits || !requireClaims else { throw SaveError.invalidCommander }
        return
      }
      guard permits, leaf.count <= NativeMemoryAtlasWatcherSourceSave.maximumLeafBytes,
        let object = try JSONSerialization.jsonObject(with: leaf) as? [String: Any],
        Set(object.keys).isSubset(of: NativeMemoryAtlasWatcherSourceSave.rawRecordKeys),
        NativeMemoryAtlasWatcherSourceSave.rawRecordKeys.subtracting(["transfer"])
          .isSubset(of: Set(object.keys))
      else { throw SaveError.invalidCommander }
      let record = try JSONDecoder().decode(NativeMemoryAtlasWatcherSourceRecord.self, from: leaf)
      guard record.shapeValid,
        (object as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)))
      else { throw SaveError.invalidCommander }
    } catch {
      throw SaveError.invalidCommander
    }
  }
}
