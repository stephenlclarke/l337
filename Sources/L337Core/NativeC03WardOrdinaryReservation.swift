import Foundation

/// Restrictive post-care accounting, never a provider, person, boarding or terminal proof.
/// No caller can construct it from U/H, family tags or decoded receipts. Positive care
/// remains unavailable until the complete actual ward/source/holder validator is adopted.
final class NativeC03WardOrdinaryReservation: Sendable {
  private let snapshot: CommanderSnapshot
  private let epoch: UUID
  private let terminalContribution: Int
  let reservedAdmissions: Int
  let reservedTransfers: Int
  let reservedRevisions: UInt64

  private init(game: borrowing Game, terminalContribution: Int, unboarded: Int, held: Int) {
    snapshot = CommanderSnapshot(game.commander)
    epoch = game.nativeStationRuntimeEpoch
    self.terminalContribution = terminalContribution
    reservedAdmissions = unboarded
    reservedTransfers = unboarded + held
    reservedRevisions = UInt64(2 * unboarded + held)
  }

  /// This does not call broader Commander/NativePeople validity, which may itself consume
  /// this restrictive projection. Actual native mutation owners still validate the full
  /// candidate and genuine effect/holder proofs separately before any publication.
  @inline(never)
  static func currentPostCare(in game: borrowing Game) -> NativeC03WardOrdinaryReservation? {
    guard let owner = game.commander.equipmentOwnerID else { return nil }
    let custody = game.commander.nativePeople ?? .init(owner: owner)
    guard let history = NativeC03CrewHistoryBudget.current(custody: custody, commander: game.commander),
      history.countsWithinLimits(custody)
    else { return nil }
    guard let source = custody.hollowManifestCrew else {
      return .init(game: game, terminalContribution: history.terminalContribution, unboarded: 0, held: 0)
    }
    if source.loss != nil {
      return .init(game: game, terminalContribution: history.terminalContribution, unboarded: 0, held: 0)
    }
    // Full source validation above must authenticate the ORIGINAL care operation and all
    // real current ward/admission/terminal/holder joins. This query is not a substitute.
    let care = custody.transfers.filter {
      $0.kind == .care && $0.members == source.references
    }.min(by: { $0.revision < $1.revision })
    guard let care else {
      // No accepted care: this projection supplies no post-care encumbrance. Future durable
      // pre-care clearance requires its own actual reservation join before service activation.
      return .init(game: game, terminalContribution: history.terminalContribution, unboarded: 0, held: 0)
    }
    guard history.terminalContribution == 1, source.references.count == 6,
      Set(source.references).count == 6 else { return nil }
    var unboarded = 0
    var held = 0
    for person in source.references {
      let admissions = custody.admissions.filter { $0.person == person }
      let terminals = custody.transfers.filter {
        $0.revision > care.revision && $0.members.contains(person)
      }
      guard admissions.count <= 1, terminals.count <= 1 else { return nil }
      if let admission = admissions.first {
        guard admission.revision > care.revision, admission.physicalTime >= care.physicalTime else {
          return nil
        }
        if let terminal = terminals.first {
          guard terminal.revision > admission.revision,
            terminal.physicalTime >= admission.physicalTime else { return nil }
        } else { held += 1 }
      } else if let terminal = terminals.first {
        // Actual ward death has no invented earlier player admission. The full source
        // validator must already join this receipt to its genuine station-held fatal event.
        guard terminal.kind == .loss, terminal.dock == nil,
          terminal.physicalTime >= care.physicalTime else { return nil }
      } else { unboarded += 1 }
    }
    guard unboarded + held <= 6 else { return nil }
    return .init(game: game, terminalContribution: history.terminalContribution,
      unboarded: unboarded, held: held)
  }

  /// Same uninterrupted candidate only. Resource/ward/current native proofs remain the
  /// actual mutation owner's responsibility; equality never authorizes a physical effect.
  func isCurrent(in game: borrowing Game) -> Bool {
    guard game.nativeStationRuntimeEpoch == epoch else { return false }
    return game.commander == snapshot.value
  }

  /// Use on the actual fully staged result after its real member obligations close, not
  /// as a before-only terminal rejection. Ordinary counts retain their existing maxima.
  func countsWithinLimits() -> Bool {
    let custody = snapshot.value.nativePeople
    let admissions = custody?.admissions.count ?? 0
    let transfers = custody?.transfers.count ?? 0
    let revision = custody?.revision ?? 0
    let maximum = NativePeopleCustodyState.maximumPeople
    guard (0...1).contains(terminalContribution),
      reservedAdmissions <= maximum, reservedTransfers <= maximum,
      reservedRevisions <= UInt64(maximum * 2),
      admissions <= maximum - reservedAdmissions,
      transfers >= terminalContribution, revision >= UInt64(terminalContribution)
    else { return false }
    return transfers - terminalContribution <= maximum - reservedTransfers
      && revision - UInt64(terminalContribution) <= UInt64(maximum * 2) - reservedRevisions
  }
}
