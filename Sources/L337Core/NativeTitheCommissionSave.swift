import Foundation

enum NativeTitheCommissionSave {
  static let field = "savedTitheCommission"
  static let maximumLeafBytes = 16384

  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativeTitheCommissionDefinition.marked(instance) else { return true }
    guard instance.definition == NativeTitheCommissionDefinition.stateID,
      instance.version == NativeTitheCommissionDefinition.version,
      instance.digest == NativeTitheCommissionDefinition.digest,
      let grant = instance.savedTitheCommission, grant.shapeValid,
      instance.id == grant.acceptance.mission, instance.outcome == .active,
      instance.revision == 1,
      instance.receipts == [NativeTitheCommissionDefinition.acceptReceipt], instance.milestones == [0],
      instance.hasAcknowledged(grant.acceptance.sequence),
      instance.contract == nil, instance.completionReceipt == nil, instance.gearIssues.isEmpty,
      instance.payloads.isEmpty, instance.timers.isEmpty, instance.dialogue == nil,
      instance.choiceReceipts.isEmpty, instance.conversationReceipts.isEmpty,
      instance.ownedEncounters.isEmpty, instance.campaignParent == nil,
      instance.campaignChildren.isEmpty, instance.data == .object([:]),
      instance.journal == NativeTitheCommissionDefinition.briefing
    else { return false }
    return true
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let cases = commander.withReadOnlyScriptState { $0.instances.values.filter(NativeTitheCommissionDefinition.marked) }
    guard cases.count <= 1 else { return false }
    guard let instance = cases.first else { return true }
    guard prefixValid(instance), let grant = instance.savedTitheCommission,
      let first = commander.scriptState.firstNativeCommoditySale,
      let second = commander.scriptState.secondNativeCommoditySale,
      NativeFirstCommoditySaleSave.validateClaims(commander),
      NativeSecondCommoditySaleSave.validateClaims(commander),
      grant.acceptance.owner == commander.equipmentOwnerID,
      grant.acceptance.firstSale == first.operation,
      grant.acceptance.secondSale == second.sale.operation,
      grant.acceptance.dock.actor.visit >= second.sale.dock.actor.visit,
      grant.acceptance.dock.sequence >= second.sale.dock.sequence,
      grant.acceptance.calendarSeconds >= second.sale.dock.calendarSeconds,
      grant.acceptance.physicalTime >= second.sale.physicalTime,
      grant.acceptance.physicalTime <= commander.flightSimulation.physicalTime,
      grant.acceptance.calendarSeconds <= commander.scriptState.calendarSeconds,
      grant.acceptance.sequence <= commander.scriptState.nextEvent,
      NativeStationPassengerJourney.historicalDock(grant.acceptance.dock, commander: commander),
      let world = commander.nativeStations
    else { return false }
    let currentVisit = commander.flightSimulation.visit
    guard grant.acceptance.visited.allSatisfy({
      world.mainStations.contains($0.station) && $0.actor.visit <= currentVisit
    }),
      NativeTitheCommissionContactSource.recognizesHistorical(grant.acceptance.desk, commander: commander)
    else { return false }
    return true
  }

  /// Current-field lexical presence runs before Foundation's dictionary conversion.
  /// Structural decode is not a desk source: validateClaims also requires real issuance.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard try ScriptSaveJSONPreflight.titheCommissionArchiveMayContainClaims(data, part: part) else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains(field), !root.keys.contains("titheCommission"),
      !root.keys.contains("titheCommissionMarkEntitlement")
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
        guard let value = raw as? [String: Any], !value.keys.contains("titheCommission"),
          !value.keys.contains("titheCommissionMarkEntitlement")
        else { throw SaveError.invalidCommander }
        let named = value["definition"] as? String == NativeTitheCommissionDefinition.stateID
        let pinned = value["digest"] as? String == NativeTitheCommissionDefinition.digest
        let claimed = value.keys.contains(field)
        guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
        guard named else { continue }
        guard !embedded, let leaf = value[field] as? [String: Any], leaf.count == 3,
          let acceptance = leaf["acceptance"] as? [String: Any],
          let visited = acceptance["visited"] as? [Any],
          visited.count == NativeTitheCommissionHistory.requiredDistinctSystems
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= maximumLeafBytes else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeTitheCommissionState.self, from: bytes)
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

extension Commander {
  /// An owning valid original case supplies the entitlement across hull changes. The
  /// current carrier is intentionally not equated with its historical acceptance hull.
  var titheCommissionMarkEntitlement: NativeTitheCommissionMarkEntitlement? {
    guard NativeTitheCommissionSave.validateClaims(self) else { return nil }
    return withReadOnlyScriptState { engine in
      engine.instances.values.first(where: NativeTitheCommissionDefinition.marked)?.savedTitheCommission?.mark
    }
  }
}
