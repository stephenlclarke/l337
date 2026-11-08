import Foundation

enum NativeAssemblyOfOrbitsAction: String, Sendable {
  case accept, collectReference, progress
  var key: String { NativeAssemblyOfOrbitsDefinition.stateID + "/" + rawValue }
}

/// Review of the actual original service, not a decoded permission or a living NPC birth.
final class NativeAssemblyOfOrbitsReview: Sendable {
  let action: NativeAssemblyOfOrbitsAction
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
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }

  fileprivate init(game: borrowing Game, action: NativeAssemblyOfOrbitsAction,
    arrival: NativeMainStationArrivalContext?, tradeOperation: UUID?, issues: [String])
  {
    self.action = action
    self.arrival = arrival
    owner = game.commander.equipmentOwnerID
    carrier = game.commander.hullInstanceID
    inventoryRevision = game.commander.equipmentInventory?.revision
    self.tradeOperation = tradeOperation
    caseRevision = game.assemblyOfOrbitsMission?.revision
    digest = game.assemblyOfOrbitsPack?.digest
    epoch = game.nativeStationRuntimeEpoch
    resources = CommanderSnapshot(game.commander.contractQuoteResources)
    self.issues = issues
  }
}

extension Game {
  var assemblyOfOrbitsRows: [ContractBoardRow] {
    guard assemblyOfOrbitsPack != nil else { return [] }
    if let instance = assemblyOfOrbitsMission {
      var result: [ContractBoardRow] = []
      if systemIdentity == NativeAssemblyOfOrbitsDefinition.issuer,
        instance.savedAssemblyOfOrbits?.collection == nil
      {
        result.append(.init(board: NativeAssemblyOfOrbitsAction.collectReference.key, offer: nil,
          title: "Marshal Nera Voss / collect original assembly reference",
          reason: assemblyOfOrbitsReview(.collectReference).issues.first,
          assemblyOfOrbits: .collectReference))
      }
      result.append(.init(board: NativeAssemblyOfOrbitsAction.progress.key, offer: nil,
        title: "An Assembly of Orbits / current case", reason: nil, assemblyOfOrbits: .progress))
      return result
    }
    guard systemIdentity == NativeAssemblyOfOrbitsDefinition.issuer else { return [] }
    return [.init(board: NativeAssemblyOfOrbitsAction.accept.key, offer: nil,
      title: "Marshal Nera Voss / review An Assembly of Orbits",
      reason: assemblyOfOrbitsReview(.accept).issues.first, assemblyOfOrbits: .accept)]
  }

  func assemblyOfOrbitsReview(_ action: NativeAssemblyOfOrbitsAction) -> NativeAssemblyOfOrbitsReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let trade = NativeAssemblyOfOrbitsTrade.current(in: commander)
    var issues: [String] = []
    if action == .progress {
      return .init(game: self, action: action, arrival: arrival,
        tradeOperation: trade?.operation, issues: [])
    }
    if paused || isMissionTrial || trialTitle != nil {
      issues.append("Use your unpaused actual commander outside a trial.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if systemIdentity != NativeAssemblyOfOrbitsDefinition.issuer || arrival == nil {
      issues.append("Review with Marshal Nera Voss at the actual living Irkenan main berth in Galaxy 7.")
    }
    if assemblyOfOrbitsPack == nil { issues.append("Restore the original Assembly commission.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil || !commander.equipmentStateValid
    {
      issues.append("Restore the actual owned carrier and equipment inventory.")
    }
    if !NativeAssemblyOfOrbitsSave.validateClaims(commander) {
      issues.append("The original Assembly case and reference custody cannot currently be verified.")
    }
    if action == .accept {
      if trade == nil { issues.append("Complete one actual ordinary purchase or sale first.") }
      if assemblyOfOrbitsMission != nil {
        issues.append("The original case already exists; follow its current record.")
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The mission record capacity is full.")
      }
    } else {
      if let instance = assemblyOfOrbitsMission {
        if instance.suspension != nil || instance.outcome != .active
          || instance.savedAssemblyOfOrbits?.collection != nil
        {
          issues.append("The original reference is already issued or this case is unavailable.")
        }
      } else { issues.append("Accept Voss's actual Assembly commission first.") }
      if NativeAssemblyReferenceDefinition.gear.kind?.canonicalNode != NativeAssemblyReferenceDefinition.node {
        issues.append("Restore the original reference equipment definition.")
      }
      if issues.isEmpty, var selected = assemblyOfOrbitsMission {
        // This discarded native issue is a capacity quote; Voss still holds the original.
        var preview = commander
        do {
          let before = preview.checkedCargoTonnes
          _ = try issueScriptGearWithReceipt(NativeAssemblyReferenceDefinition.gear,
            fields: ["fit": .bool(false)], command: UUID(), state: &selected, candidate: &preview)
          guard let before else { throw EquipmentIssueError.invalidBudget }
          let occupied = before.addingReportingOverflow(NativeAssemblyReferenceDefinition.cargoTonnes)
          guard !occupied.overflow, preview.checkedCargoTonnes == occupied.partialValue else {
            throw EquipmentIssueError.invalidBudget
          }
        } catch {
          issues.append("The original reference needs one real free tonne; Voss retains it until it fits.")
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

  func assemblyOfOrbitsDetail() -> [String] {
    guard let action = contractBoard.selected?.assemblyOfOrbits else { return [] }
    let quote = contractBoard.assemblyOfOrbitsQuote
    var lines = NativeAssemblyOfOrbitsDefinition.briefing
    lines.append("One original reference tonne is collected separately here and stays aboard through the field work.")
    lines.append("The 7700 CR fee and clue require the later actual survey, witness reception, settlement and return audit.")
    if action == .progress {
      guard let instance = assemblyOfOrbitsMission,
        NativeAssemblyOfOrbitsSave.validateClaims(commander)
      else { return lines + ["The original case record cannot currently be verified."] }
      if instance.savedAssemblyOfOrbits?.collection == nil {
        lines.append("Collect the original reference from Voss at Irkenan when your hold has room.")
      } else if (try? NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: commander)) != nil {
        lines.append("Original reference held. Compare the three consented occupancy/work registers at Darik.")
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
