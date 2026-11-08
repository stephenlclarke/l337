import Foundation

/// One finite NPC-source terminal contribution, only after full reciprocal source and actual
/// native-disposition claims validate. It does not admit people or mint a count from a tag.
struct NativeC03CrewHistoryBudget: Sendable {
  /// Raw allocation envelope only. Semantic validation permits the extra entry solely for
  /// the one real validated C03 terminal; ordinary budgets remain exactly maximumPeople.
  static let maximumRawTransfers = NativePeopleCustodyState.maximumPeople + 1
  let terminalContribution: Int

  private init(terminalContribution: Int) { self.terminalContribution = terminalContribution }

  var maximumTransfers: Int { NativePeopleCustodyState.maximumPeople + terminalContribution }
  var maximumRevision: UInt64 {
    UInt64(NativePeopleCustodyState.maximumPeople) * 2 + UInt64(terminalContribution)
  }

  @inline(never)
  static func current(
    custody: borrowing NativePeopleCustodyState, commander: borrowing Commander
  ) -> Self? {
    guard custody.owner == commander.equipmentOwnerID,
      NativeC03CrewSourceSave.validSource(custody.hollowManifestCrew, custody: custody, commander: commander)
    else { return nil }
    // validSource has already required the exact six originals, sole reciprocal transfer,
    // actual retained launch death/native binding, owner/revision/clock/epoch and no pickup.
    let contribution = custody.hollowManifestCrew?.loss == nil ? 0 : 1
    return .init(terminalContribution: contribution)
  }

  func countsWithinLimits(_ custody: borrowing NativePeopleCustodyState) -> Bool {
    let contribution = UInt64(terminalContribution)
    guard custody.admissions.count <= NativePeopleCustodyState.maximumPeople,
      custody.transfers.count >= terminalContribution,
      custody.transfers.count - terminalContribution <= NativePeopleCustodyState.maximumPeople,
      custody.revision >= contribution,
      custody.revision - contribution <= UInt64(NativePeopleCustodyState.maximumPeople) * 2
    else { return false }
    return true
  }

  func canAppendOrdinaryMutation(_ custody: borrowing NativePeopleCustodyState) -> Bool {
    countsWithinLimits(custody) && custody.revision < maximumRevision
  }

  func canAppendOrdinaryTransfer(_ custody: borrowing NativePeopleCustodyState) -> Bool {
    canAppendOrdinaryMutation(custody) && custody.transfers.count < maximumTransfers
  }
}
