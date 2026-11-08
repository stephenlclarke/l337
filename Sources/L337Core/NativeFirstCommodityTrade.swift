import Foundation

struct NativeCommodityTradeBalance: Codable, Sendable, Equatable {
  let stock: Int
  let cargo: Int
  let credits: Int

  var valid: Bool {
    (0...Int.max / 17).contains(stock) && (0...Int.max / 17).contains(cargo)
      && (0...4_294_967_295).contains(credits)
  }
}

/// First successful ordinary purchase or sale. This is historical data, not an entitlement.
/// Immutable reference storage avoids adding the dock and balances to inline Game copies.
final class NativeFirstCommodityTrade: Codable, Sendable, Equatable {
  enum Side: String, Codable, Sendable, Equatable { case buy, sell }

  let operation: UUID
  let owner: UUID
  let side: Side
  let commodity: Int
  let dock: NativeMainStationDockReceipt
  let physicalTime: Double
  let calendarOperation: UInt64
  let unitPrice: Int
  let quantity: Int
  let paymentWaived: Bool
  let before: NativeCommodityTradeBalance
  let after: NativeCommodityTradeBalance

  fileprivate init(
    operation: UUID, owner: UUID, side: Side, commodity: Int,
    dock: NativeMainStationDockReceipt, physicalTime: Double, calendarOperation: UInt64,
    unitPrice: Int, quantity: Int, paymentWaived: Bool,
    before: NativeCommodityTradeBalance, after: NativeCommodityTradeBalance
  ) {
    self.operation = operation
    self.owner = owner
    self.side = side
    self.commodity = commodity
    self.dock = dock
    self.physicalTime = physicalTime
    self.calendarOperation = calendarOperation
    self.unitPrice = unitPrice
    self.quantity = quantity
    self.paymentWaived = paymentWaived
    self.before = before
    self.after = after
  }

  var valid: Bool {
    guard dock.valid, dock.commanderOwner == owner, dock.station.world == owner,
      Commodity.all.indices.contains(commodity), physicalTime.isFinite,
      (0...1e12).contains(physicalTime), calendarOperation < UInt64(Int64.max),
      (0...1_000_000).contains(unitPrice), before.valid, after.valid,
      (1...Int.max / 17).contains(quantity),
      let quote = OriginalLiveMarkets.initialQuote(
        galaxy: dock.station.system.galaxy, system: dock.station.system.system,
        commodity: commodity)
    else { return false }
    switch side {
    case .buy:
      guard unitPrice == quote.price, before.stock - after.stock == quantity,
        after.cargo - before.cargo == quantity else { return false }
      if paymentWaived { return before.credits == after.credits }
      let cost = quantity.multipliedReportingOverflow(by: unitPrice)
      return !cost.overflow && cost.partialValue <= before.credits
        && after.credits == before.credits - cost.partialValue
    case .sell:
      guard !paymentWaived, unitPrice == quote.bidPrice,
        after.stock - before.stock == quantity, before.cargo - after.cargo == quantity
      else { return false }
      let revenue = quantity.multipliedReportingOverflow(by: unitPrice)
      let expected = revenue.overflow ? 4_294_967_295
        : min(4_294_967_295, before.credits + min(revenue.partialValue, 4_294_967_295))
      return after.credits == expected
    }
  }

  static func == (lhs: NativeFirstCommodityTrade, rhs: NativeFirstCommodityTrade) -> Bool {
    lhs.operation == rhs.operation && lhs.owner == rhs.owner && lhs.side == rhs.side
      && lhs.commodity == rhs.commodity && lhs.dock == rhs.dock
      && lhs.physicalTime == rhs.physicalTime && lhs.calendarOperation == rhs.calendarOperation
      && lhs.unitPrice == rhs.unitPrice && lhs.quantity == rhs.quantity
      && lhs.paymentWaived == rhs.paymentWaived && lhs.before == rhs.before && lhs.after == rhs.after
  }
}

extension Game {
  /// Record immediately after the kernel balance changes. A later command refusal discards
  /// this same candidate through the existing transaction; no second operation is performed.
  mutating func recordFirstNativeCommodityTrade(
    buying: Bool, index: Int, before: NativeCommodityTradeBalance, unitPrice: Int
  ) {
    guard commander.scriptState.firstNativeCommodityTrade == nil, !paused, before.valid,
      !isMissionTrial, trialTitle == nil, nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      let owner = commander.equipmentOwnerID,
      market.indices.contains(index), commander.cargo.indices.contains(index)
    else { return }
    let after = NativeCommodityTradeBalance(
      stock: market[index].quantity, cargo: commander.cargo[index], credits: commander.credits)
    guard after.valid else { return }
    let evidence = NativeFirstCommodityTrade(
      operation: UUID(), owner: owner, side: buying ? .buy : .sell, commodity: index, dock: dock,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarOperation: commander.scriptState.calendarLedger?.operation ?? 0,
      unitPrice: unitPrice,
      quantity: buying ? after.cargo - before.cargo : before.cargo - after.cargo,
      paymentWaived: buying && commander.unlimitedCash, before: before, after: after)
    guard evidence.valid else { return }
    commander.scriptState.firstNativeCommodityTrade = evidence
  }
}

/// Assembly consumes validated historical commerce, without requiring the original berth
/// to remain the current berth. Receipt creation stays in the ordinary market kernel.
enum NativeAssemblyOfOrbitsTrade {
  static func current(in commander: borrowing Commander) -> NativeFirstCommodityTrade? {
    guard NativeFirstCommodityTradeSave.validateClaims(commander) else { return nil }
    return commander.scriptState.firstNativeCommodityTrade
  }
}
