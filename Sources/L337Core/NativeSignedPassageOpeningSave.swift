import Foundation

enum NativeSignedPassageOpeningSave {
  static let field = "savedNativeSignedPassageOpening"
  static let maximumLeafBytes = 8192

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard NativeSignedPassageOpening.Reference.occupiedTonnes(in: commander.equipmentInventory) == 0
    else { return false }
    let cases = commander.withReadOnlyScriptState { engine in
      engine.instances.values.filter(NativeSignedPassageOpening.marked)
    }
    guard cases.count <= 1 else { return false }
    // Acceptance issues no original reference, serial or collection; another case's payload or receipt cannot supply Senn's source stock.
    let noMaterialIssues = commander.withReadOnlyScriptState { engine in
      for instance in engine.instances.values {
        for issue in instance.gearIssues.values {
          if issue.node == NativeSignedPassageOpening.Reference.node { return false }
          if case .module(let name) = issue.kind,
            name == NativeSignedPassageOpening.Reference.name { return false }
        }
      }
      return true
    }
    guard noMaterialIssues else { return false }
    guard let instance = cases.first else { return true }
    guard NativeSignedPassageOpening.prefixValid(instance), let state = instance.savedNativeSignedPassageOpening,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade,
      trade.operation == state.opening.trade, trade.owner == state.opening.owner,
      trade.physicalTime <= state.opening.physicalTime,
      state.opening.owner == commander.equipmentOwnerID,
      state.opening.physicalTime <= commander.flightSimulation.physicalTime,
      state.opening.calendarSeconds <= commander.scriptState.calendarSeconds,
      state.opening.eventSequence <= commander.scriptState.nextEvent,
      instance.hasAcknowledged(state.opening.eventSequence),
      NativeStationPassengerJourney.historicalDock(state.opening.dock, commander: commander),
      instance.journal == NativeSignedPassageOpening.briefing
    else { return false }
    return true
  }

  /// G1 joins the new closed selector to its existing bounded lexer before this decoder.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard try ScriptSaveJSONPreflight.nativeSignedPassageOpeningArchiveMayContainClaims(data, part: part) else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains(field), !root.keys.contains("signedPassageOpening")
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
        guard let value = raw as? [String: Any], !value.keys.contains("signedPassageOpening")
        else { throw SaveError.invalidCommander }
        let named = value["definition"] as? String == NativeSignedPassageOpening.stateID
        let pinned = value["digest"] as? String == NativeSignedPassageOpening.digest
        let claimed = value.keys.contains(field)
        guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
        guard named else { continue }
        guard !embedded, let leaf = value[field] as? [String: Any], leaf.count == 1
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= maximumLeafBytes else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeSignedPassageOpeningState.self, from: bytes)
        guard decoded.valid,
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
