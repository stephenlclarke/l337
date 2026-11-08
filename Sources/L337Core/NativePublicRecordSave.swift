import Foundation

enum NativePublicRecordSave {
  static let field = "savedPublicRecord"
  static let maximumLeafBytes = 8192

  /// Only the original acceptance prefix exists; reading cannot qualify a physical stage.
  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativePublicRecordDefinition.marked(instance) else { return true }
    guard instance.definition == NativePublicRecordDefinition.stateID,
      instance.version == NativePublicRecordDefinition.version,
      instance.digest == NativePublicRecordDefinition.digest,
      let state = instance.savedPublicRecord, state.shapeValid,
      instance.id == state.acceptance.mission, instance.outcome == .active,
      instance.revision < UInt64(Int64.max),
      instance.receipts == [NativePublicRecordDefinition.acceptReceipt], instance.milestones == [0],
      instance.contract == nil, instance.completionReceipt == nil, instance.gearIssues.isEmpty,
      instance.payloads.isEmpty, instance.timers.isEmpty, instance.dialogue == nil,
      instance.choiceReceipts.isEmpty, instance.conversationReceipts.isEmpty,
      instance.ownedEncounters.isEmpty, instance.campaignParent == nil,
      instance.campaignChildren.isEmpty, instance.data == .object([:]),
      instance.journal.count <= NativePublicRecordDefinition.briefing.count,
      instance.journal == Array(NativePublicRecordDefinition.briefing.prefix(instance.journal.count))
    else { return false }
    return true
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard NativePublicRecordReferenceDefinition.occupiedTonnes(in: commander.equipmentInventory) == 0
    else { return false }
    let cases = commander.withReadOnlyScriptState { engine in
      engine.instances.values.filter(NativePublicRecordDefinition.marked)
    }
    guard cases.count <= 1 else { return false }
    // Acceptance issues no reference, observer permission, independent record or reply period; another case's history cannot supply Sol's original.
    let noMaterialIssues = commander.withReadOnlyScriptState { engine in
      for instance in engine.instances.values {
        for issue in instance.gearIssues.values {
          if issue.node == NativePublicRecordReferenceDefinition.node { return false }
          if case .module(let name) = issue.kind,
            name == NativePublicRecordReferenceDefinition.name { return false }
        }
      }
      return true
    }
    guard noMaterialIssues else { return false }
    guard let instance = cases.first else { return true }
    guard prefixValid(instance), let state = instance.savedPublicRecord,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade,
      trade.operation == state.acceptance.ordinaryTrade, trade.owner == state.acceptance.owner,
      trade.physicalTime <= state.acceptance.physicalTime,
      state.acceptance.owner == commander.equipmentOwnerID,
      state.acceptance.physicalTime <= commander.flightSimulation.physicalTime,
      state.acceptance.calendarSeconds <= commander.scriptState.calendarSeconds,
      state.acceptance.eventSequence <= commander.scriptState.nextEvent,
      instance.hasAcknowledged(state.acceptance.eventSequence),
      NativeStationPassengerJourney.historicalDock(state.acceptance.dock, commander: commander),
      instance.journal == NativePublicRecordDefinition.briefing
    else { return false }
    return true
  }

  /// G1 joins the new closed selector to its existing bounded lexer before this decoder.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard try ScriptSaveJSONPreflight.publicRecordArchiveMayContainClaims(data, part: part) else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains(field), !root.keys.contains("publicRecord")
    else { throw SaveError.invalidCommander }
    func instances(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else { throw SaveError.invalidCommander }
      for raw in values {
        guard let value = raw as? [String: Any], !value.keys.contains("publicRecord")
        else { throw SaveError.invalidCommander }
        let named = value["definition"] as? String == NativePublicRecordDefinition.stateID
        let pinned = value["digest"] as? String == NativePublicRecordDefinition.digest
        let claimed = value.keys.contains(field)
        guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
        guard named else { continue }
        guard !embedded, let leaf = value[field] as? [String: Any], leaf.count == 2
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= maximumLeafBytes else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativePublicRecordState.self, from: bytes)
        guard decoded.shapeValid,
          (leaf as NSDictionary).isEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if part == .missions { try instances(root["instances"], embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try instances(embedded["instances"], embedded: true)
    }
  }
}
