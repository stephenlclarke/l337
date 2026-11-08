import Foundation

enum NativeQuietChoirSave {
  static let field = "savedQuietChoir"
  static let maximumLeafBytes = 8192

  /// Only the original acceptance prefix exists; reading cannot qualify a physical stage.
  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativeQuietChoirDefinition.marked(instance) else { return true }
    guard instance.definition == NativeQuietChoirDefinition.stateID,
      instance.version == NativeQuietChoirDefinition.version,
      instance.digest == NativeQuietChoirDefinition.digest,
      let state = instance.savedQuietChoir, state.shapeValid,
      instance.id == state.acceptance.mission, instance.outcome == .active,
      instance.revision < UInt64(Int64.max),
      instance.receipts == [NativeQuietChoirDefinition.acceptReceipt], instance.milestones == [0],
      instance.contract == nil, instance.completionReceipt == nil, instance.gearIssues.isEmpty,
      instance.payloads.isEmpty, instance.timers.isEmpty, instance.dialogue == nil,
      instance.choiceReceipts.isEmpty, instance.conversationReceipts.isEmpty,
      instance.ownedEncounters.isEmpty, instance.campaignParent == nil,
      instance.campaignChildren.isEmpty, instance.data == .object([:]),
      instance.journal.count <= NativeQuietChoirDefinition.briefing.count,
      instance.journal == Array(NativeQuietChoirDefinition.briefing.prefix(instance.journal.count))
    else { return false }
    return true
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let cases = commander.withReadOnlyScriptState { engine in
      engine.instances.values.filter(NativeQuietChoirDefinition.marked)
    }
    guard cases.count <= 1 else { return false }
    guard let instance = cases.first else { return true }
    guard prefixValid(instance), let state = instance.savedQuietChoir,
      NativeQuietChoirTravelHistory.historical(state.acceptance, commander: commander),
      state.acceptance.owner == commander.equipmentOwnerID,
      state.acceptance.physicalTime <= commander.flightSimulation.physicalTime,
      state.acceptance.calendarSeconds <= commander.scriptState.calendarSeconds,
      state.acceptance.eventSequence <= commander.scriptState.nextEvent,
      instance.hasAcknowledged(state.acceptance.eventSequence),
      NativeStationPassengerJourney.historicalDock(state.acceptance.dock, commander: commander),
      instance.journal == NativeQuietChoirDefinition.briefing
    else { return false }
    return true
  }

  /// G1 joins the new closed selector to its existing bounded lexer before this decoder.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard try ScriptSaveJSONPreflight.quietChoirArchiveMayContainClaims(data, part: part) else { return }
    guard part == .missions,
      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw SaveError.invalidCommander }
    // The shared lexer supplies byte/depth/count and duplicate-key bounds first.
    // Presence is conservative: reject a field hidden under any other archive path.
    func containsClaim(_ value: Any) -> Bool {
      if let object = value as? [String: Any] {
        if object.keys.contains(field) || object.keys.contains("quietChoir")
          || object["definition"] as? String == NativeQuietChoirDefinition.stateID
          || object["digest"] as? String == NativeQuietChoirDefinition.digest { return true }
        return object.values.contains(where: containsClaim)
      }
      if let array = value as? [Any] { return array.contains(where: containsClaim) }
      return false
    }
    guard !containsClaim(root.filter { $0.key != "instances" }) else {
      throw SaveError.invalidCommander
    }
    func instances(_ raw: Any?) throws {
      guard let raw else { return }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else { throw SaveError.invalidCommander }
      for raw in values {
        guard let value = raw as? [String: Any], !value.keys.contains("quietChoir")
        else { throw SaveError.invalidCommander }
        let named = value["definition"] as? String == NativeQuietChoirDefinition.stateID
        let pinned = value["digest"] as? String == NativeQuietChoirDefinition.digest
        let claimed = value.keys.contains(field)
        guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
        var remaining = value
        remaining.removeValue(forKey: field)
        remaining.removeValue(forKey: "definition")
        remaining.removeValue(forKey: "digest")
        guard !containsClaim(remaining) else { throw SaveError.invalidCommander }
        guard named else { continue }
        guard let leaf = value[field] as? [String: Any], leaf.count == 2,
          let acceptance = leaf["acceptance"] as? [String: Any],
          let visited = acceptance["visited"] as? [Any],
          visited.count == NativeQuietChoirTravelHistory.minimumDistinctSystems
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= maximumLeafBytes else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeQuietChoirState.self, from: bytes)
        guard decoded.shapeValid,
          (leaf as NSDictionary).isEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    try instances(root["instances"])
  }
}
