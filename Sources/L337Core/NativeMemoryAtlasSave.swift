import Foundation

enum NativeMemoryAtlasSave {
  static let field = "savedMemoryAtlas"
  static let maximumLeafBytes = 32768

  /// Structural prefix only. Live contact, ordinary trade and physical custody are separate joins.
  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativeMemoryAtlasDefinition.marked(instance) else { return true }
    guard instance.definition == NativeMemoryAtlasDefinition.stateID,
      instance.version == NativeMemoryAtlasDefinition.version,
      instance.digest == NativeMemoryAtlasDefinition.digest,
      let state = instance.savedMemoryAtlas, state.shapeValid,
      instance.id == state.acceptance.mission, instance.outcome == .active,
      instance.contract == nil, instance.completionReceipt == nil,
      instance.payloads.isEmpty, instance.timers.isEmpty, instance.dialogue == nil,
      instance.choiceReceipts.isEmpty, instance.conversationReceipts.isEmpty,
      instance.ownedEncounters.isEmpty, instance.campaignParent == nil,
      instance.campaignChildren.isEmpty, instance.data == .object([:])
    else { return false }
    var receipts: Set<String> = [NativeMemoryAtlasDefinition.acceptReceipt]
    var milestones: Set<Int> = [0]
    var journal = NativeMemoryAtlasDefinition.briefing
    if let collection = state.collection {
      receipts.insert(NativeMemoryAtlasDefinition.collectReceipt)
      milestones.insert(1)
      journal.append(NativeMemoryAtlasDefinition.collectionDialogue)
      guard instance.revision >= collection.facts.afterCaseRevision,
        Set(instance.gearIssues.keys) == [NativeMemoryAtlasReferenceDefinition.logicalResource]
      else { return false }
    } else if !instance.gearIssues.isEmpty { return false }
    return instance.receipts == receipts && instance.milestones == milestones
      && instance.journal.count <= journal.count
      && instance.journal == Array(journal.prefix(instance.journal.count))
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let cases = commander.withReadOnlyScriptState {
      $0.instances.values.filter(NativeMemoryAtlasDefinition.marked)
    }
    guard cases.count <= 1 else { return false }
    let carried = commander.equipmentInventory?.items.filter {
      $0.node == NativeMemoryAtlasReferenceDefinition.node
    } ?? []
    guard let instance = cases.first else {
      guard carried.isEmpty else { return false }
      return noForeignIssues(commander, expectedMission: nil)
    }
    guard prefixValid(instance), let state = instance.savedMemoryAtlas,
      NativeFirstCommodityTradeSave.validateClaims(commander),
      let trade = commander.scriptState.firstNativeCommodityTrade,
      trade.operation == state.acceptance.ordinaryTrade,
      trade.owner == state.acceptance.owner,
      trade.physicalTime <= state.acceptance.physicalTime,
      state.acceptance.owner == commander.equipmentOwnerID,
      state.acceptance.physicalTime <= commander.flightSimulation.physicalTime,
      state.acceptance.calendarSeconds <= commander.scriptState.calendarSeconds,
      state.acceptance.eventSequence <= commander.scriptState.nextEvent,
      instance.hasAcknowledged(state.acceptance.eventSequence),
      NativeStationPassengerJourney.historicalDock(state.acceptance.dock, commander: commander),
      noForeignIssues(commander, expectedMission: instance.id)
    else { return false }
    var expectedJournal = NativeMemoryAtlasDefinition.briefing
    guard let collection = state.collection else {
      return carried.isEmpty && instance.journal == expectedJournal
    }
    expectedJournal.append(NativeMemoryAtlasDefinition.collectionDialogue)
    guard instance.journal == expectedJournal,
      collection.facts.physicalTime <= commander.flightSimulation.physicalTime,
      collection.facts.calendarSeconds <= commander.scriptState.calendarSeconds,
      collection.facts.eventSequence <= commander.scriptState.nextEvent,
      instance.hasAcknowledged(collection.facts.eventSequence),
      NativeStationPassengerJourney.historicalDock(collection.facts.dock, commander: commander),
      let inventory = commander.equipmentInventory,
      inventory.owner == state.acceptance.owner,
      inventory.revision >= collection.facts.afterInventoryRevision,
      let issue = instance.gearIssues[NativeMemoryAtlasReferenceDefinition.logicalResource],
      issue.valid(for: instance), issue.savedGearVersion == 2,
      issue.kind == .module(NativeMemoryAtlasReferenceDefinition.name),
      issue.node == NativeMemoryAtlasReferenceDefinition.node,
      issue.source == collection.facts.source, issue.items == [collection.facts.original],
      issue.status == .issued, issue.loan, !issue.returnRemaining,
      issue.displacements?.isEmpty == true, issue.legacyMissingItems?.isEmpty ?? true
    else { return false }
    if issue.consumed.isEmpty {
      guard carried.count == 1 else { return false }
      return (try? NativeMemoryAtlasCustody.retainedBinding(instance: instance, commander: commander)) != nil
    }
    // Retain the equipment kernel's actual consumed-original history. It supplies neither
    // a held reference, a replacement unit, a loss outcome nor a physical-stage receipt.
    return issue.consumed == [collection.facts.original] && carried.isEmpty
      && !inventory.items.contains(where: { $0.id == collection.facts.original })
  }

  private static func noForeignIssues(_ commander: borrowing Commander, expectedMission: UUID?) -> Bool {
    commander.withReadOnlyScriptState { engine in
      for instance in engine.instances.values {
        for issue in instance.gearIssues.values where
          issue.node == NativeMemoryAtlasReferenceDefinition.node
            || issue.kind == .module(NativeMemoryAtlasReferenceDefinition.name)
        {
          guard instance.id == expectedMission,
            issue.resource == NativeMemoryAtlasReferenceDefinition.logicalResource else { return false }
        }
      }
      return true
    }
  }

  /// G1 joins this at the existing current raw-part entry before the root typed decoder.
  /// No feature version, old reader or missing-native-field default is introduced.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard try ScriptSaveJSONPreflight.memoryAtlasArchiveMayContainClaims(data, part: part) else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains(field), !root.keys.contains("memoryAtlas")
    else { throw SaveError.invalidCommander }
    func validateInstances(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else { throw SaveError.invalidCommander }
      for raw in values {
        guard let value = raw as? [String: Any], !value.keys.contains("memoryAtlas") else {
          throw SaveError.invalidCommander
        }
        let named = value["definition"] as? String == NativeMemoryAtlasDefinition.stateID
        let pinned = value["digest"] as? String == NativeMemoryAtlasDefinition.digest
        let claimed = value.keys.contains(field)
        guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
        guard named else { continue }
        guard !embedded, let leaf = value[field] as? [String: Any], leaf.count <= 3 else {
          throw SaveError.invalidCommander
        }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= maximumLeafBytes else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeMemoryAtlasState.self, from: bytes)
        guard decoded.shapeValid,
          (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if part == .missions { try validateInstances(root["instances"], embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validateInstances(embedded["instances"], embedded: true)
    }
  }
}
