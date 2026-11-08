import Foundation

enum NativeUnderTowAction: String, Sendable {
  case accept, collectReference, progress
  var key: String { NativeUnderTowDefinition.stateID + "/" + rawValue }
}

/// Review of the actual original service, not a decoded permission or a living NPC birth.
final class NativeUnderTowReview: Sendable {
  let action: NativeUnderTowAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let tradeOperation: UUID?
  let caseRevision: UInt64?
  let digest: String?
  let epoch: UUID
  let resources: CommanderSnapshot
  let issues: [String]
  var allowed: Bool { action != .progress && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativeUnderTowAction,
    arrival: NativeMainStationArrivalContext?, tradeOperation: UUID?, issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.tradeOperation = tradeOperation
    caseRevision = game.underTowMission?.revision
    digest = game.underTowPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var underTowRows: [ContractBoardRow] {
    guard underTowPack != nil else { return [] }
    if let instance = underTowMission {
      var result: [ContractBoardRow] = []
      if systemIdentity == NativeUnderTowDefinition.issuer,
        instance.savedUnderTow?.collection == nil
      {
        result.append(.init(board: NativeUnderTowAction.collectReference.key, offer: nil,
          title: "Tug Lead Mira Penn / collect original tow-interface reference",
          reason: underTowReview(.collectReference).issues.first,
          underTow: .collectReference))
      }
      result.append(.init(board: NativeUnderTowAction.progress.key, offer: nil,
        title: "Under Tow / current case", reason: nil, underTow: .progress))
      return result
    }
    guard systemIdentity == NativeUnderTowDefinition.issuer else { return [] }
    return [.init(board: NativeUnderTowAction.accept.key, offer: nil,
      title: "Tug Lead Mira Penn / review Under Tow",
      reason: underTowReview(.accept).issues.first, underTow: .accept)]
  }

  func underTowReview(_ action: NativeUnderTowAction) -> NativeUnderTowReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let trade = NativeFirstCommodityTradeSave.validateClaims(commander)
      ? commander.scriptState.firstNativeCommodityTrade : nil
    var issues: [String] = []
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        tradeOperation: trade?.operation, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeUnderTowDefinition.issuer || arrival == nil {
      issues.append("Review with Tug Lead Mira Penn at the actual living Luera main berth in Galaxy 8.")
    }
    if underTowPack == nil { issues.append("Restore the original Under Tow commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeUnderTowSave.validateClaims(commander) {
      issues.append("The original Under Tow case and reference custody cannot currently be verified.")
    }
    if action == .accept {
      if trade == nil { issues.append("Complete one actual ordinary purchase or sale first.") }
      if underTowMission != nil {
        issues.append("The original case already exists; follow its current record.")
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The mission record capacity is full.")
      }
    } else {
      if let instance = underTowMission {
        if instance.suspension != nil || instance.outcome != .active
          || instance.savedUnderTow?.collection != nil
        {
          issues.append("The original reference is already issued or this case is unavailable.")
        }
      } else { issues.append("Accept Penn's actual Under Tow commission first.") }
      if NativeUnderTowReferenceDefinition.gear.kind?.canonicalNode != NativeUnderTowReferenceDefinition.node {
        issues.append("Restore the original reference equipment definition.")
      }
      if issues.isEmpty, var selected = underTowMission {
        // This discarded native issue is a capacity quote; Penn still holds the original.
        var preview = commander
        do {
          let before = preview.checkedCargoTonnes
          _ = try issueScriptGearWithReceipt(NativeUnderTowReferenceDefinition.gear,
            fields: ["fit": .bool(false)], command: UUID(), state: &selected, candidate: &preview)
          guard let before else { throw EquipmentIssueError.invalidBudget }
          let occupied = before.addingReportingOverflow(NativeUnderTowReferenceDefinition.cargoTonnes)
          guard !occupied.overflow, preview.checkedCargoTonnes == occupied.partialValue else {
            throw EquipmentIssueError.invalidBudget
          }
        } catch {
          issues.append("The original reference needs one real free tonne; Penn retains it until it fits.")
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
      tradeOperation: trade?.operation, issues: issues)
  }

  func underTowDetail() -> [String] {
    guard let action = contractBoard.selected?.underTow else { return [] }
    let quote = contractBoard.underTowQuote
    var lines = NativeUnderTowDefinition.briefing
    lines.append("One original reference tonne is collected separately here and stays aboard through the field work.")
    lines.append("The 8300 CR fee and clue require actual collar measurements, both load tests, living tender receiving, settlement and original-reference return.")
    if action == .progress {
      guard let instance = underTowMission,
        NativeUnderTowSave.validateClaims(commander)
      else { return lines + ["The original case record cannot currently be verified."] }
      if instance.savedUnderTow?.collection == nil {
        lines.append("Collect the original reference from Penn at Luera when your hold has room.")
      } else if (try? NativeUnderTowCustody.resolve(instance: instance, commander: commander)) != nil {
        lines.append("Original reference held. Compare the three original rescue collars and their independent load limits at Allion.")
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
