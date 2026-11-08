import Foundation

/// G1 owns the root-only bounded lexical gate and new envelope; this is the retained typed join.
enum NativeMemoryAtlasWatcherSourceSave {
  static let field = "savedMemoryAtlasWatcherSource"
  static let maximumLeafBytes = 32768
  static let rawRecordKeys: Set<String> = [
    "adoptionRevision", "sourceRevision", "owner", "issuer", "caseID", "original", "station",
    "resource", "name", "node", "quantity", "cargoTonnes", "heldOnly", "loan", "returnPolicy",
    "packVersion", "packDigest", "initialization", "custody", "transfer",
  ]
  static let rawInitializationKeys: Set<String> = [
    "dock", "eventSequence", "physicalTime", "calendarSeconds",
  ]
  static let rawTransferKeys: Set<String> = [
    "beforeSourceRevision", "afterSourceRevision", "collection",
  ]

  /// Direction is source -> original mission validator, never the reverse. Both join at the outer writer.
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let cases = commander.withReadOnlyScriptState {
      $0.instances.values.filter(NativeMemoryAtlasDefinition.marked)
    }
    let issues = commander.withReadOnlyScriptState { engine in
      engine.instances.values.flatMap { instance in
        instance.gearIssues.values.filter {
          $0.resource == NativeMemoryAtlasWatcherSource.resource
            || $0.node == NativeMemoryAtlasWatcherSource.node
            || $0.kind == .module(NativeMemoryAtlasWatcherSource.name)
            || $0.source?.resource == NativeMemoryAtlasWatcherSource.resource
        }.map { (instance.id, $0) }
      }
    }
    let inventory = commander.equipmentInventory
    let carried: [OwnedEquipmentItem]
    if let inventory {
      let original = NativeMemoryAtlasWatcherSource.original(owner: inventory.owner)
      carried = inventory.items.filter { $0.node == NativeMemoryAtlasWatcherSource.node || $0.id == original }
    } else {
      carried = []
    }
    guard let source = commander.savedMemoryAtlasWatcherSource else {
      return cases.isEmpty && issues.isEmpty && carried.isEmpty
    }
    guard source.shapeValid, source.owner == commander.equipmentOwnerID,
      let inventory, inventory.owner == source.owner,
      let world = commander.nativeStations, world.valid, world.ledger.world == source.owner,
      world.mainStations.contains(source.station),
      source.initialization.dock.sequence < world.nextMainDockSequence,
      source.initialization.dock.actor.visit <= commander.flightSimulation.visit,
      source.initialization.physicalTime <= commander.flightSimulation.physicalTime,
      source.initialization.calendarSeconds <= commander.scriptState.calendarSeconds,
      source.initialization.eventSequence <= commander.scriptState.nextEvent,
      cases.count <= 1, NativeMemoryAtlasSave.validateClaims(commander)
    else { return false }
    if source.initialization.dock.actor.visit == commander.flightSimulation.visit,
      source.station.system != commander.flightSimulation.system
    { return false }
    let instance = cases.first
    if let instance {
      guard instance.id == source.caseID, instance.version == source.packVersion,
        instance.digest == source.packDigest, let state = instance.savedMemoryAtlas,
        state.acceptance.owner == source.owner, state.acceptance.dock.station == source.station,
        state.acceptance.dock.sequence >= source.initialization.dock.sequence,
        state.acceptance.eventSequence > source.initialization.eventSequence,
        state.acceptance.physicalTime >= source.initialization.physicalTime,
        state.acceptance.calendarSeconds >= source.initialization.calendarSeconds
      else { return false }
    }
    switch source.custody {
    case .available:
      return issues.isEmpty && carried.isEmpty && instance?.savedMemoryAtlas?.collection == nil
    case .onLoan:
      guard let instance, let collection = instance.savedMemoryAtlas?.collection,
        let transfer = source.transfer, transfer.collection == collection,
        issues.count == 1, issues[0].0 == source.caseID,
        let issue = instance.gearIssues[source.resource], issue == issues[0].1,
        issue.valid(for: instance), issue.source == collection.facts.source,
        issue.items == [source.original], issue.node == source.node,
        issue.loan, !issue.returnRemaining, issue.status == .issued,
        let obligation = issue.obligation,
        let obligations = try? commander.equipmentIssueObligations(),
        obligations.filter({ $0.source == obligation.source }) == [obligation]
      else { return false }
      // Existing mission/equipment validation owns genuine consumption and held-item attributes.
      // The finite source stays onLoan/owed even when that exact original is recorded consumed.
      return issue.consumed.isEmpty
        ? carried.count == 1 && carried[0].id == source.original
        : issue.consumed == [source.original] && carried.isEmpty
    }
  }
}
