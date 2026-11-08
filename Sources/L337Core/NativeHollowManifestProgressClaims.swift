import Foundation

extension NativeHollowManifestCommission {
  static func expectedReceipts(_ state: borrowing NativeHollowManifestState) -> Set<String> {
    var values: Set<String> = [receipt]
    if state.inspections.count == 2 { values.insert(inspectionReceipt) }
    if state.laboratory != nil { values.insert(laboratoryReceipt) }
    if state.wakeTrail?.observations.count == 3 { values.insert(NativeC03WakeTrail.receipt) }
    if state.custodyRegister?.recovery != nil { values.insert(NativeC03RegisterState.receipt) }
    if state.crewLogAccess != nil { values.insert(NativeC03CrewLogAccessReceipt.receipt) }
    if state.caseFile != nil { values.insert(NativeC03LedgerReconstructionReceipt.receipt) }
    if state.caseFile?.remedy != nil { values.insert(NativeC03RemedyReceipt.receipt) }
    if state.caseFile?.evidenceReturn != nil { values.insert(NativeC03EvidenceReturnReceipt.receipt) }
    if state.caseFile?.closure != nil {
      values.formUnion([NativeC03CaseClosure.receipt, NativeHollowManifestDefinition.terminalRewardReceipt])
    }
    return values
  }

  static func expectedMilestones(_ state: borrowing NativeHollowManifestState) -> Set<Int> {
    var values: Set<Int> = [0]
    if state.inspections.count == 2 { values.insert(1) }
    if state.laboratory != nil { values.insert(2) }
    if state.wakeTrail?.observations.count == 3 { values.insert(3) }
    if state.custodyRegister?.recovery != nil { values.insert(4) }
    if state.crewLogAccess != nil { values.insert(5) }
    if state.caseFile != nil { values.insert(6) }
    if state.caseFile?.remedy != nil { values.insert(7) }
    if state.caseFile?.evidenceReturn != nil { values.insert(8) }
    if state.caseFile?.closure != nil { values.insert(9) }
    return values
  }

  static func expectedJournal(_ state: borrowing NativeHollowManifestState) -> [String] {
    var values = briefing
    if state.inspections.count == 2 { values.append(inspectionDialogue) }
    if state.laboratory != nil { values.append(laboratoryDialogue) }
    if state.wakeTrail?.observations.count == 3 { values.append(NativeC03WakeTrail.dialogue) }
    if state.custodyRegister?.recovery != nil { values.append(NativeC03CustodyRegisterContent.dialogue) }
    if state.crewLogAccess != nil { values.append(NativeC03CrewLogAccessReceipt.dialogue) }
    if state.caseFile != nil { values.append(NativeC03LedgerReconstructionReceipt.dialogue) }
    if let remedy = state.caseFile?.remedy { values += remedy.journal }
    if state.caseFile?.evidenceReturn != nil { values.append(NativeC03EvidenceReturnReceipt.dialogue) }
    if state.caseFile?.closure != nil { values += NativeC03CaseClosure.journal }
    return values
  }

  /// Canonical issue obligation owns custody. This records no parallel inventory or fitting.
  static func gearClaimsMatch(
    _ instance: borrowing ScriptInstance, state: borrowing NativeHollowManifestState
  ) -> Bool {
    guard let lab = state.laboratory else { return instance.gearIssues.isEmpty }
    guard instance.gearIssues.count == 1,
      let issue = instance.gearIssues[NativeHollowManifestKitDefinition.resource],
      issue.valid(for: instance), let obligation = issue.obligation,
      issue.kind == .module(NativeHollowManifestKitDefinition.name),
      issue.loan, !issue.returnRemaining,
      issue.items == [lab.facts.originalKit], issue.displacements?.isEmpty == true,
      issue.legacyMissingItems == nil,
      obligation.source == lab.facts.issueSource,
      obligation.node == NativeHollowManifestKitDefinition.node,
      obligation.consumed.isSubset(of: [lab.facts.originalKit])
    else { return false }
    if state.caseFile?.evidenceReturn != nil {
      return issue.status == .returned && issue.consumed.isEmpty
    }
    return issue.status == .issued
  }
}
