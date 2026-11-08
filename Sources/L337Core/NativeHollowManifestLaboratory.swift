import Foundation

/// Historical laboratory/loan facts only. Decoding these never issues an item or a dock receipt.
struct NativeHollowManifestLaboratoryReceipt: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let issuer: UUID
    let dock: NativeMainStationDockReceipt
    let carrier: UUID
    let beforeInventoryRevision: UInt64
    let afterInventoryRevision: UInt64
    let beforeCredits: Int
    let afterCredits: Int
    let issueCommand: UUID
    let issueSource: EquipmentIssueSource
    let originalKit: UUID
    let inspections: [UUID]
    let analysis: NativeC03SealLaboratoryAnalysis
    let sequence: UInt64
    let physicalTime: Double
  }

  let operation: UUID
  let facts: Facts

  static func identity(_ facts: Facts) throws -> UUID {
    guard facts.analysis.shapeValid else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-native-laboratory-loan-v1:\(try NativeFlightReception.hash(facts))")
  }

  fileprivate init(actual: EquipmentIssueReceipt, facts: Facts) throws {
    guard actual.operation == .issued, actual.command == facts.issueCommand,
      actual.source == facts.issueSource, actual.originalItems == [facts.originalKit],
      actual.affectedItems == actual.originalItems, actual.consumedItems.isEmpty,
      actual.displacements.isEmpty
    else { throw EquipmentIssueError.identityMismatch }
    self.facts = facts
    operation = try Self.identity(facts)
  }

  func valid(in state: NativeHollowManifestState) -> Bool {
    let f = facts
    guard operation == (try? Self.identity(f)), f.mission == state.birth.input.mission,
      f.owner == state.birth.input.owner,
      f.issuer == NativeHollowManifestKitDefinition.issuer(owner: f.owner),
      f.dock.valid, f.dock.commanderOwner == f.owner, f.dock.station.world == f.owner,
      f.dock.station.system == NativeHollowManifestKitDefinition.issueLocation,
      f.dock.sequence > state.birth.input.dock.sequence,
      f.dock.calendarSeconds >= state.birth.input.dock.calendarSeconds,
      f.beforeInventoryRevision < UInt64(Int64.max) - 1,
      f.afterInventoryRevision == f.beforeInventoryRevision + 1,
      f.beforeCredits >= 0, f.afterCredits == f.beforeCredits,
      f.issueSource == EquipmentIssueSource(
        mission: f.mission, resource: NativeHollowManifestKitDefinition.resource,
        packDigest: NativeHollowManifestCommission.digest),
      f.originalKit == NativeHollowManifestKitDefinition.serial(mission: f.mission),
      state.inspections.count == 2, f.inspections == state.inspections.map(\.operation),
      f.analysis.valid(in: state),
      f.sequence < state.nextSourceSequence,
      f.physicalTime.isFinite, (state.birth.input.physicalTime...1e12).contains(f.physicalTime),
      state.inspections.allSatisfy({
        f.sequence > $0.facts.sequence && f.physicalTime >= $0.facts.last.physicalTime
          && f.dock.actor.visit > $0.facts.player.visit
          && f.beforeInventoryRevision >= $0.facts.inventoryRevision
      })
    else { return false }
    let barriers: [(UInt64, Double)] = state.firstCompromises.map {
      ($0.sourceSequence, $0.facts.cause.physicalTime)
    } + state.withdrawals.map { ($0.sourceSequence, $0.effect.incident.physicalTime) }
      + state.terminals.map { ($0.sourceSequence, $0.effect.incident.physicalTime) }
    return barriers.allSatisfy { f.sequence < $0.0 && f.physicalTime <= $0.1 }
  }
}

extension NativeHollowManifestState {
  /// Pure history retention only. The actual issue producer authenticates and installs it.
  func retainingLaboratory(_ receipt: NativeHollowManifestLaboratoryReceipt) throws -> Self {
    guard shapeValid, phase == .admitted, laboratory == nil,
      nextSourceSequence < UInt64(Int64.max) - 1, receipt.facts.sequence == nextSourceSequence
    else { throw Failure.invalidState }
    let candidate = Self(
      birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: receipt, wakeTrail: wakeTrail, custodyRegister: custodyRegister,
      crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: caseFile)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}

extension Game {
  /// Read-only stage eligibility. Physical arrival and native gear application remain mandatory.
  func hollowManifestLaboratoryIssue(at arrival: NativeMainStationArrivalContext?) -> String? {
    guard let arrival, acceptsNativeMainStationArrivalContext(arrival), !paused, !isMissionTrial,
      trialTitle == nil, scriptDurabilityAvailable,
      arrival.receipt.station.system == NativeHollowManifestKitDefinition.issueLocation,
      let instance = hollowManifestMission, instance.outcome == .active, instance.suspension == nil,
      let state = instance.savedHollowManifest, state.laboratory == nil,
      state.inspections.count == 2, instance.milestones == [0, 1],
      state.terminals.isEmpty, state.withdrawals.isEmpty, state.firstCompromises.isEmpty,
      NativeHollowManifestSave.validateClaims(commander),
      let inventory = commander.equipmentInventory, inventory.owner == state.birth.input.owner,
      !inventory.items.contains(where: { $0.node == NativeHollowManifestKitDefinition.node }),
      state.inspections.allSatisfy({ arrival.receipt.actor.visit > $0.facts.player.visit })
    else { return "Bring both original seal observations to Iven at the living Torenran main berth." }
    do {
      _ = try NativeC03SealLaboratoryAnalysis.examining(state)
      var proposed = commander
      var mission = instance
      guard try issueScriptGearWithReceipt(
        NativeHollowManifestKitDefinition.gear, fields: ["fit": .bool(false)], command: UUID(),
        state: &mission, candidate: &proposed) != nil
      else { return "The original inspection kit was already issued." }
    } catch {
      return "The original inspection kit requires one real free tonne and valid equipment custody."
    }
    return nil
  }

  /// Runs inside the actual contract Confirm candidate. No item or source state is installed
  /// until its opaque gear receipt, exact loan and complete candidate claims have all matched.
  mutating func confirmHollowManifestLaboratory(_ quote: NativeHollowManifestReview) throws {
    let current = hollowManifestReview(.laboratory)
    guard screen == .contracts, contractBoard.detail, contractBoard.action == .accept,
      contractBoard.selected?.hollowManifest == .laboratory,
      quote.action == .laboratory, quote.allowed, current.allowed,
      quote.arrival == current.arrival, quote.epoch == current.epoch,
      quote.owner == current.owner, quote.carrier == current.carrier,
      quote.inventoryRevision == current.inventoryRevision,
      quote.caseRevision == current.caseRevision, quote.sourceSequence == current.sourceSequence,
      quote.digest == current.digest, let arrival = current.arrival,
      hollowManifestLaboratoryIssue(at: arrival) == nil,
      var instance = hollowManifestMission, let state = instance.savedHollowManifest,
      let inventory = commander.equipmentInventory, let owner = commander.equipmentOwnerID,
      state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else { throw MissionPackError("Review Iven's actual berth, observations, kit and free hold again.") }
    let analysis = try NativeC03SealLaboratoryAnalysis.examining(state)
    var candidate = commander
    let cash = candidate.credits
    guard let issued = try issueScriptGearWithReceipt(
      NativeHollowManifestKitDefinition.gear, fields: ["fit": .bool(false)], command: UUID(),
      state: &instance, candidate: &candidate),
      let afterInventory = candidate.equipmentInventory
    else { throw EquipmentIssueError.staleObligation }
    let facts = NativeHollowManifestLaboratoryReceipt.Facts(
      mission: instance.id, owner: owner, issuer: NativeHollowManifestKitDefinition.issuer(owner: owner),
      dock: arrival.receipt, carrier: inventory.activeHull,
      beforeInventoryRevision: inventory.revision, afterInventoryRevision: afterInventory.revision,
      beforeCredits: cash, afterCredits: candidate.credits,
      issueCommand: issued.receipt.command, issueSource: issued.receipt.source,
      originalKit: NativeHollowManifestKitDefinition.serial(mission: instance.id),
      inspections: state.inspections.map(\.operation), analysis: analysis,
      sequence: state.nextSourceSequence,
      physicalTime: candidate.flightSimulation.physicalTime)
    let receipt = try NativeHollowManifestLaboratoryReceipt(actual: issued.receipt, facts: facts)
    instance.savedHollowManifest = try state.retainingLaboratory(receipt)
    instance.receipts.insert(NativeHollowManifestCommission.laboratoryReceipt)
    instance.milestones.insert(2)
    instance.journal.append(NativeHollowManifestCommission.laboratoryDialogue)
    instance.revision += 1
    candidate.scriptState.instances[instance.id] = instance
    guard candidate.credits == cash, NativeHollowManifestSave.validateClaims(candidate),
      let item = candidate.equipmentInventory?.items.first(where: { $0.id == facts.originalKit }),
      item.node == NativeHollowManifestKitDefinition.node, item.location == nil,
      candidate.equipmentInventory?.revision == inventory.revision + 1
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}
