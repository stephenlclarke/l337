import Foundation

/// The second distinct native sale, retained once alongside the immutable first-sale witness.
/// A bulk sale has one operation regardless of how many units it transfers.
final class NativeSecondCommoditySale: Codable, Sendable, Equatable {
  let firstOperation: UUID
  let sale: NativeFirstCommoditySale

  fileprivate init(first: NativeFirstCommoditySale, sale: NativeFirstCommoditySale) {
    firstOperation = first.operation
    self.sale = sale
  }

  func valid(after first: NativeFirstCommoditySale) -> Bool {
    first.valid && sale.valid && firstOperation == first.operation
      && sale.operation != firstOperation && sale.owner == first.owner
      && sale.dock.sequence >= first.dock.sequence
      && sale.dock.actor.visit >= first.dock.actor.visit
      && sale.physicalTime >= first.physicalTime
      && sale.calendarOperation >= first.calendarOperation
  }

  static func == (lhs: NativeSecondCommoditySale, rhs: NativeSecondCommoditySale) -> Bool {
    lhs.firstOperation == rhs.firstOperation && lhs.sale == rhs.sale
  }
}

extension Game {
  /// The market kernel supplies one operation ID per successful sale. The command writer
  /// publishes this history in the same candidate as the cash, cargo and market balances.
  mutating func retainNativeOrdinarySale(_ sale: NativeFirstCommoditySale) {
    guard sale.valid, !isMissionTrial, trialTitle == nil,
      sale.owner == commander.equipmentOwnerID
    else { return }
    guard let first = commander.scriptState.firstNativeCommoditySale else {
      commander.scriptState.firstNativeCommoditySale = sale
      return
    }
    guard commander.scriptState.secondNativeCommoditySale == nil,
      first.operation != sale.operation
    else { return }
    let second = NativeSecondCommoditySale(first: first, sale: sale)
    guard second.valid(after: first) else { return }
    commander.scriptState.secondNativeCommoditySale = second
  }
}
