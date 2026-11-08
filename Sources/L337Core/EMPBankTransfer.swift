import Foundation

/// EMP-only arithmetic staging against the existing main reserve, never a new balance owner.
/// The future owner must rederive terms, actual fit, state and qualified interval before commit.
enum EMPBankTransfer {
  struct Terms: Equatable, Sendable {
    let bankCapacity: Double
    let rechargePerSecond: Double
    let efficiency: Double
    let maximumMainDebit: Double

    var valid: Bool {
      bankCapacity.isFinite && bankCapacity > 0
        && rechargePerSecond.isFinite && rechargePerSecond > 0
        && efficiency.isFinite && efficiency > 0 && efficiency <= 1
        && maximumMainDebit.isFinite && maximumMainDebit >= 0
    }
  }

  enum Refusal: Error, Equatable, Sendable {
    case invalidBank, foreignModule, paused, invalidInterval, missingMainReserve
    case unavailableMainReserve, unpostedMainReserve, missingTerms, invalidTerms
    case foreignCapacity, overdrawnHeadroom, arithmeticRefusal
  }

  struct Stage: Equatable, Sendable {
    let expectedBank: EMPBankState
    let expectedMain: ElectricalReserve
    let bank: EMPBankState
    let main: ElectricalReserve
    let terms: Terms
    let start: Double
    let end: Double
    let mainDebited: Double
    let bankGained: Double
    let conversionLoss: Double

    fileprivate init(
      expectedBank: EMPBankState, expectedMain: ElectricalReserve,
      bank: EMPBankState, main: ElectricalReserve, terms: Terms, start: Double, end: Double
    ) {
      self.expectedBank = expectedBank
      self.expectedMain = expectedMain
      self.bank = bank
      self.main = main
      self.terms = terms
      self.start = start
      self.end = end
      mainDebited = expectedMain.remaining - main.remaining
      bankGained = bank.remaining - expectedBank.remaining
      conversionLoss = mainDebited - bankGained
    }

    /// Snapshot equality only. It is not item, interval, paid-resource or publication authority.
    func stillMatches(bank: EMPBankState, main: ElectricalReserve) -> Bool {
      expectedBank == bank && expectedMain == main
    }
  }

  static func stage(
    bank: EMPBankState, module: UUID, main: ElectricalReserve?,
    start: Double, end: Double, paused: Bool, terms: Terms?
  ) -> Result<Stage, Refusal> {
    guard bank.valid else { return .failure(.invalidBank) }
    guard bank.module == module else { return .failure(.foreignModule) }
    guard !paused else { return .failure(.paused) }
    guard start.isFinite, start >= 0, end.isFinite, end > start,
      bank.physicalTime == start
    else { return .failure(.invalidInterval) }
    guard let main else { return .failure(.missingMainReserve) }
    guard main.valid, main.disabledAt == nil else { return .failure(.unavailableMainReserve) }
    guard main.physicalTime == end else { return .failure(.unpostedMainReserve) }
    guard let terms else { return .failure(.missingTerms) }
    guard terms.valid else { return .failure(.invalidTerms) }
    guard terms.bankCapacity == bank.capacity else { return .failure(.foreignCapacity) }
    guard terms.maximumMainDebit <= main.remaining else { return .failure(.overdrawnHeadroom) }
    let wanted = terms.rechargePerSecond * (end - start)
    let affordable = terms.maximumMainDebit * terms.efficiency
    guard wanted.isFinite, affordable.isFinite else { return .failure(.arithmeticRefusal) }
    let gain = min(bank.capacity - bank.remaining, wanted, affordable)
    if gain == 0 {
      guard let candidate = bank.creditForStaging(0, at: end) else {
        return .failure(.arithmeticRefusal)
      }
      return .success(
        .init(
          expectedBank: bank, expectedMain: main, bank: candidate, main: main,
          terms: terms, start: start, end: end))
    }
    return stagePositiveTransfer(
      bank: bank, main: main, terms: terms, start: start, end: end, gain: gain)
  }

  private static func stagePositiveTransfer(
    bank: EMPBankState, main: ElectricalReserve, terms: Terms,
    start: Double, end: Double, gain: Double
  ) -> Result<Stage, Refusal> {
    let requestedDebit = gain / terms.efficiency
    guard requestedDebit.isFinite, requestedDebit > 0,
      requestedDebit <= terms.maximumMainDebit, requestedDebit <= main.remaining
    else { return .failure(.arithmeticRefusal) }
    let closing = main.remaining - requestedDebit
    let roundedDebit = main.remaining - closing
    let meteredDebit =
      roundedDebit > requestedDebit ? main.remaining - closing.nextUp : requestedDebit
    var failedClosing = main.remaining
    if meteredDebit != 0 {
      guard meteredDebit.isFinite, meteredDebit > 0, meteredDebit <= requestedDebit else {
        return .failure(.arithmeticRefusal)
      }
      var candidateMain = main
      // No advance/catch-up/generation. The existing reserve is already posted at interval end.
      guard candidateMain.drain(meteredDebit, at: end) else {
        return .failure(.arithmeticRefusal)
      }
      let paid = main.remaining - candidateMain.remaining
      if paid != 0 {
        guard paid.isFinite, paid > 0, paid <= requestedDebit, paid <= terms.maximumMainDebit else {
          return .failure(.arithmeticRefusal)
        }
        let paidGainLimit = paid * terms.efficiency
        let credit = min(gain, paidGainLimit)
        guard credit > 0, let candidateBank = bank.creditForStaging(credit, at: end) else {
          return .failure(.arithmeticRefusal)
        }
        let actualGain = candidateBank.remaining - bank.remaining
        let loss = paid - actualGain
        if actualGain != 0 {
          guard actualGain > 0, actualGain <= gain, actualGain <= paidGainLimit,
            loss.isFinite, loss >= 0, actualGain + loss == paid
          else { return .failure(.arithmeticRefusal) }
          return .success(
            .init(
              expectedBank: bank, expectedMain: main, bank: candidateBank, main: candidateMain,
              terms: terms, start: start, end: end))
        }
      }
      failedClosing = candidateMain.remaining
    }
    // Only a represented zero debit or valid zero credit reaches these two local trials.
    // A larger represented payment is explicit rounding loss, bounded by the owner allocation.
    for fallbackClosing in [closing, closing.nextDown] {
      guard fallbackClosing.isFinite, fallbackClosing > 0,
        fallbackClosing < failedClosing, fallbackClosing < main.remaining
      else { continue }
      let fallbackDebit = main.remaining - fallbackClosing
      guard fallbackDebit.isFinite, fallbackDebit > requestedDebit,
        fallbackDebit <= terms.maximumMainDebit
      else { continue }
      var candidateMain = main
      guard candidateMain.drain(fallbackDebit, at: end) else {
        return .failure(.arithmeticRefusal)
      }
      let paid = main.remaining - candidateMain.remaining
      guard candidateMain.remaining == fallbackClosing, candidateMain.remaining > 0,
        paid.isFinite, paid > requestedDebit, paid <= terms.maximumMainDebit
      else { continue }
      let paidGainLimit = paid * terms.efficiency
      let credit = min(gain, paidGainLimit)
      guard credit > 0 else { continue }
      guard let candidateBank = bank.creditForStaging(credit, at: end) else {
        return .failure(.arithmeticRefusal)
      }
      let actualGain = candidateBank.remaining - bank.remaining
      let loss = paid - actualGain
      if actualGain == 0 { continue }
      guard actualGain > 0, actualGain <= gain, actualGain <= paidGainLimit,
        loss.isFinite, loss >= 0, actualGain + loss == paid
      else { return .failure(.arithmeticRefusal) }
      return .success(
        .init(
          expectedBank: bank, expectedMain: main, bank: candidateBank, main: candidateMain,
          terms: terms, start: start, end: end))
    }
    return .failure(.arithmeticRefusal)
  }
}
