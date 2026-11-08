import Foundation

enum NativeMemoryAtlasAction: String, Sendable {
  case accept, collectReference, progress
  var key: String { NativeMemoryAtlasDefinition.stateID + "/" + rawValue }
}

/// Review of the actual original service, not a decoded permission or a living NPC birth.
final class NativeMemoryAtlasReview: Sendable {
  let action: NativeMemoryAtlasAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let tradeOperation: UUID?
  let caseRevision: UInt64?
  let digest: String?
  let epoch: UUID
  let resources: CommanderSnapshot
  let source: NativeMemoryAtlasWatcherSourceProjection?
  let watcherSource: NativeMemoryAtlasWatcherSourceQuote?
  let issues: [String]
  var allowed: Bool { action != .progress && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativeMemoryAtlasAction,
    arrival: NativeMainStationArrivalContext?, tradeOperation: UUID?, issues: [String],
    watcherSource: NativeMemoryAtlasWatcherSourceQuote? = nil)
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.tradeOperation = tradeOperation
    caseRevision = game.memoryAtlasMission?.revision
    digest = game.memoryAtlasPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
    source = game.memoryAtlasWatcherSourceProjection
    self.watcherSource = watcherSource
  }
}

extension Game {
  var memoryAtlasRows: [ContractBoardRow] {
    guard memoryAtlasPack != nil else { return [] }
    if let instance = memoryAtlasMission {
      var result: [ContractBoardRow] = []
      if systemIdentity == NativeMemoryAtlasDefinition.issuer,
        instance.savedMemoryAtlas?.collection == nil
      {
        result.append(.init(board: NativeMemoryAtlasAction.collectReference.key, offer: nil,
          title: "Agent Mara Vale / collect original Atlas watcher",
          reason: memoryAtlasReview(.collectReference).issues.first,
          memoryAtlas: .collectReference))
      }
      result.append(.init(board: NativeMemoryAtlasAction.progress.key, offer: nil,
        title: "The Memory Atlas / current case", reason: nil, memoryAtlas: .progress))
      return result
    }
    guard systemIdentity == NativeMemoryAtlasDefinition.issuer else { return [] }
    return [.init(board: NativeMemoryAtlasAction.accept.key, offer: nil,
      title: "Agent Mara Vale / review The Memory Atlas",
      reason: memoryAtlasReview(.accept).issues.first, memoryAtlas: .accept)]
  }

  func memoryAtlasReview(_ action: NativeMemoryAtlasAction) -> NativeMemoryAtlasReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let trade = NativeFirstCommodityTradeSave.validateClaims(commander)
      ? commander.scriptState.firstNativeCommodityTrade : nil
    var issues: [String] = []
    var watcher: NativeMemoryAtlasWatcherSourceQuote? = nil
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        tradeOperation: trade?.operation, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeMemoryAtlasDefinition.issuer || arrival == nil {
      issues.append("Review with Agent Mara Vale at the actual living Reris main berth in Galaxy 1.")
    }
    if memoryAtlasPack == nil { issues.append("Restore the original The Memory Atlas commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeMemoryAtlasSave.validateClaims(commander)
      || !NativeMemoryAtlasWatcherSourceSave.validateClaims(commander)
      || memoryAtlasWatcherSourceProjection == nil
    {
      issues.append("The original The Memory Atlas case and reference custody cannot currently be verified.")
    }
    if action == .accept {
      if trade == nil { issues.append("Complete one actual ordinary purchase or sale first.") }
      if memoryAtlasMission != nil {
        issues.append("The original case already exists; follow its current record.")
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The mission record capacity is full.")
      }
    } else {
      if let instance = memoryAtlasMission {
        if instance.suspension != nil || instance.outcome != .active
          || instance.savedMemoryAtlas?.collection != nil
        {
          issues.append("The original reference is already issued or this case is unavailable.")
        }
      } else { issues.append("Accept Vale's actual The Memory Atlas commission first.") }
      if OwnedGearKind.module(NativeMemoryAtlasReferenceDefinition.name).canonicalNode != NativeMemoryAtlasReferenceDefinition.node {
        issues.append("Restore the original reference equipment definition.")
      }
      if issues.isEmpty {
        watcher = memoryAtlasWatcherSourceQuote()
        if watcher == nil {
          issues.append("Vale's actual original source and one free tonne must be available; review the current loan.")
        }
      }
    }
    if commander.scriptState.pendingEvents.count >= 4096
      || commander.scriptState.nextEvent >= UInt64(Int64.max) - 2
      || scriptDispatching || scriptEventsDeferred || !commander.scriptState.pendingEvents.isEmpty
    {
      issues.append("Finish the current native command before confirming.")
    }
    return .init(game: self, action: action, arrival: arrival,
      tradeOperation: trade?.operation, issues: issues, watcherSource: watcher)
  }

  func memoryAtlasDetail() -> [String] {
    guard let action = contractBoard.selected?.memoryAtlas else { return [] }
    let quote = contractBoard.memoryAtlasQuote
    var lines = NativeMemoryAtlasDefinition.briefing
    lines.append("One original reference tonne is collected separately here and stays aboard through the field work.")
    lines.append("The 7200 CR fee and clue require actual independent landmark observations, both instrument tests, living custodian receiving, settlement and original-reference return.")
    if action == .progress {
      guard let instance = memoryAtlasMission,
        NativeMemoryAtlasSave.validateClaims(commander),
        NativeMemoryAtlasWatcherSourceSave.validateClaims(commander)
      else { return lines + ["The original case record cannot currently be verified."] }
      if instance.savedMemoryAtlas?.collection == nil {
        lines.append("Collect the original reference from Vale at Reris when your hold has room.")
      } else if (try? NativeMemoryAtlasCustody.resolve(instance: instance, commander: commander)) != nil {
        lines.append("Original watcher held. Observe the three original orbital landmarks at Nedasen independently of the diaries.")
      } else {
        lines.append("The original reference is unavailable; its original issue history remains. No replacement is granted.")
      }
      lines += instance.journal
    } else {
      lines += quote?.issues ?? ["Review the current berth, trade and loan requirements."]
      lines.append("Confirm commits only this stated action. Back changes nothing.")
    }
    return lines
  }
}
