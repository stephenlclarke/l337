import Foundation
import Testing

@testable import L337Core

struct EMPBankTransferTests {
  @Test func transferMetersOneExistingMainDebitAndAccountsForBankGainAndLoss() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: 8)
    let staged = try EMPBankTransfer.stage(
      bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
    #expect(staged.mainDebited == 8 && staged.bankGained == 4 && staged.conversionLoss == 4)
    #expect(staged.bankGained + staged.conversionLoss == staged.mainDebited)
    #expect(staged.main.remaining == 8 && staged.bank.remaining == 4)
    #expect(staged.bank.physicalTime == 1 && staged.main.physicalTime == 1)
    #expect(staged.stillMatches(bank: bank, main: main))
    #expect(bank.remaining == 0 && main.remaining == 16)
    let fractionalMain = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 0.125))
    let fractionalTerms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 2.3, efficiency: 0.7, maximumMainDebit: 1)
    let fractional = try EMPBankTransfer.stage(
      bank: bank, module: module, main: fractionalMain, start: 0, end: 0.125,
      paused: false, terms: fractionalTerms).get()
    #expect(fractional.mainDebited > 0 && fractional.mainDebited <= 1)
    #expect(fractional.bankGained > 0 && fractional.bankGained <= 2.3 * 0.125)
    #expect(fractional.bankGained <= fractional.mainDebited * 0.7)
    #expect(fractional.bankGained + fractional.conversionLoss == fractional.mainDebited)
  }

  @Test func capacityRateAndExplicitHeadroomIndependentlyBoundTheTransfer() throws {
    let module = UUID()
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    for (remaining, rate, limit, expectedGain) in [
      (6.0, 4.0, 8.0, 2.0), (0, 1, 8, 1), (0, 4, 2, 1),
    ] {
      let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: remaining, at: 0))
      let terms = EMPBankTransfer.Terms(
        bankCapacity: 8, rechargePerSecond: rate, efficiency: 0.5, maximumMainDebit: limit)
      let stage = try EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
      #expect(stage.bankGained == expectedGain && stage.mainDebited == expectedGain * 2)
      #expect(stage.bank.remaining <= stage.bank.capacity && stage.mainDebited <= limit)
    }
  }

  @Test func fullBankAndExplicitZeroHeadroomConsumeNoMainEnergyOrFutureCatchup() throws {
    let module = UUID()
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    for (remaining, limit) in [(8.0, 8.0), (0, 0)] {
      let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: remaining, at: 0))
      let terms = EMPBankTransfer.Terms(
        bankCapacity: 8, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: limit)
      let stage = try EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
      #expect(stage.main == main && stage.bank.remaining == remaining && stage.bankGained == 0)
      #expect(stage.mainDebited == 0 && stage.conversionLoss == 0 && stage.bank.physicalTime == 1)
      #expect(
        EMPBankTransfer.stage(
          bank: stage.bank, module: module, main: main, start: 0, end: 1,
          paused: false, terms: terms) == .failure(.invalidInterval))
    }
  }

  @Test func missingPausedDisabledAndUnpostedMainSupplyRefuseWithoutRecharging() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: 8)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: nil, start: 0, end: 1,
        paused: false, terms: terms) == .failure(.missingMainReserve))
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1,
        paused: true, terms: terms) == .failure(.paused))
    var disabled = main
    let drained = disabled.drain(16, at: 1)
    #expect(drained)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: disabled, start: 0, end: 1,
        paused: false, terms: terms) == .failure(.unavailableMainReserve))
    let unposted = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 0))
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: unposted, start: 0, end: 1,
        paused: false, terms: terms) == .failure(.unpostedMainReserve))
    #expect(bank.remaining == 0 && main.remaining == 16)
  }

  @Test func foreignModuleCapacityAndStaleSnapshotsOrIntervalsAreRefused() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: 8)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: UUID(), main: main, start: 0, end: 1,
        paused: false, terms: terms) == .failure(.foreignModule))
    let foreign = EMPBankTransfer.Terms(
      bankCapacity: 16, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: 8)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1,
        paused: false, terms: foreign) == .failure(.foreignCapacity))
    for (start, end) in [(0.0, 0.0), (1, 2), (-1, 1), (.nan, 1), (0, .infinity)] {
      #expect(
        EMPBankTransfer.stage(
          bank: bank, module: module, main: main, start: start, end: end,
          paused: false, terms: terms) == .failure(.invalidInterval))
    }
    let stage = try EMPBankTransfer.stage(
      bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
    #expect(!stage.stillMatches(bank: stage.bank, main: main))
    #expect(!stage.stillMatches(bank: bank, main: stage.main))
  }

  @Test func missingOrInvalidTermsNeverBecomeDefaultSupplyOrOverstatedHeadroom() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1,
        paused: false, terms: nil) == .failure(.missingTerms))
    for (rate, efficiency, limit) in [
      (0.0, 0.5, 8.0), (-1, 0.5, 8), (.infinity, 0.5, 8), (4, 0, 8),
      (4, 1.1, 8), (4, .nan, 8), (4, 0.5, -1), (4, 0.5, .infinity),
    ] {
      let terms = EMPBankTransfer.Terms(
        bankCapacity: 8, rechargePerSecond: rate, efficiency: efficiency, maximumMainDebit: limit)
      #expect(
        EMPBankTransfer.stage(
          bank: bank, module: module, main: main, start: 0, end: 1,
          paused: false, terms: terms) == .failure(.invalidTerms))
    }
    let overstated = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 4, efficiency: 0.5, maximumMainDebit: 17)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1,
        paused: false, terms: overstated) == .failure(.overdrawnHeadroom))
  }

  @Test func overflowAndInvisibleMainDebitsCannotMintBankEnergy() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 2))
    let overflow = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: .greatestFiniteMagnitude,
      efficiency: 0.5, maximumMainDebit: 8)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 2,
        paused: false, terms: overflow) == .failure(.arithmeticRefusal))
    let huge = try #require(ElectricalReserve(capacity: 1e300, recharge: 0, at: 1))
    let invisible = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 1, efficiency: 1, maximumMainDebit: 1)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: huge, start: 0, end: 1,
        paused: false, terms: invisible) == .failure(.arithmeticRefusal))
    let rounded = try #require(ElectricalReserve(capacity: 1e16, recharge: 0, at: 1))
    let overpayment = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 3, efficiency: 1, maximumMainDebit: 4)
    let conservative = try EMPBankTransfer.stage(
      bank: bank, module: module, main: rounded, start: 0, end: 1,
      paused: false, terms: overpayment).get()
    #expect(conservative.mainDebited == 2 && conservative.bankGained == 2)
    #expect(conservative.conversionLoss == 0)
    let largeBank = try #require(
      EMPBankState(module: module, capacity: 1e16 + 8, remaining: 1e16, at: 0))
    let smallMain = try #require(ElectricalReserve(capacity: 16, recharge: 0, at: 1))
    let roundedCredit = EMPBankTransfer.Terms(
      bankCapacity: 1e16 + 8, rechargePerSecond: 3, efficiency: 1, maximumMainDebit: 3)
    let credit = try EMPBankTransfer.stage(
      bank: largeBank, module: module, main: smallMain, start: 0, end: 1,
      paused: false, terms: roundedCredit).get()
    #expect(credit.mainDebited == 3 && credit.bankGained == 2 && credit.conversionLoss == 1)
    #expect(bank.remaining == 0 && huge.remaining == 1e300)
  }

  @Test func unappliedStagesStayValuesAndDoNotAdvanceLegacyRechargeOrProveCommit() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let main = try #require(ElectricalReserve(capacity: 16, recharge: 100, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 2, efficiency: 1, maximumMainDebit: 4)
    let first = try EMPBankTransfer.stage(
      bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
    let repeatedUnapplied = try EMPBankTransfer.stage(
      bank: bank, module: module, main: main, start: 0, end: 1, paused: false, terms: terms).get()
    #expect(first == repeatedUnapplied && first.bankGained == 2 && first.mainDebited == 2)
    #expect(first.main.remaining == 14 && first.main.recharge == 100)
    #expect(main.remaining == 16 && bank.remaining == 0 && bank.physicalTime == 0)
    #expect(!first.stillMatches(bank: first.bank, main: first.main))
    // Repeating an uncommitted value plan is allowed. Only the future existing owner can
    // atomically validate/persist both results; this is not durable once-only evidence.
  }

  @Test(arguments: [30.4, 4.0, 16.0])
  func lastFractionalBankGapPaysRepresentableMainDebitWithExplicitLoss(mainValue: Double) throws {
    let module = UUID()
    let bank = try #require(
      EMPBankState(module: module, capacity: 8, remaining: 8.0.nextDown, at: 0))
    let main = try #require(ElectricalReserve(capacity: mainValue, recharge: 0, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 0.4, efficiency: 0.8, maximumMainDebit: 0.05)
    let gap = bank.capacity - bank.remaining
    let requested = gap / terms.efficiency
    let expectedClosing: Double
    switch mainValue {
    case 30.4: expectedClosing = mainValue.nextDown
    case 4: expectedClosing = (mainValue - requested).nextDown
    case 16: expectedClosing = mainValue - requested
    default: throw SaveError.invalidCommander
    }
    let stage = try EMPBankTransfer.stage(
      bank: bank, module: module, main: main, start: 0, end: 1,
      paused: false, terms: terms).get()
    let actualPaid = main.remaining - stage.main.remaining
    let actualGain = stage.bank.remaining - bank.remaining
    #expect(stage.bank.remaining == 8 && actualGain == gap && stage.bankGained == actualGain)
    #expect(stage.main.remaining == expectedClosing && stage.main.remaining > 0)
    #expect(stage.main.disabledAt == nil && stage.main.capacity == main.capacity)
    #expect(actualPaid == stage.mainDebited && actualPaid > requested)
    #expect(actualPaid <= terms.maximumMainDebit)
    #expect(actualGain <= min(gap, terms.rechargePerSecond, terms.maximumMainDebit * 0.8))
    #expect(actualGain <= actualPaid * 0.8)
    #expect(stage.conversionLoss.isFinite && stage.conversionLoss > 0)
    #expect(actualGain + stage.conversionLoss == actualPaid)
    #expect(stage.bank.physicalTime == 1 && stage.main.physicalTime == 1)
    #expect(stage.bank.module == module && stage.bank.lastDischarge == bank.lastDischarge)
    #expect(stage.stillMatches(bank: bank, main: main))
    #expect(bank.remaining == 8.0.nextDown && bank.physicalTime == 0)
    #expect(main.remaining == mainValue && main.physicalTime == 1)
  }

  @Test(arguments: ["ownerBudget", "hugeMainULP", "subnormalCredit"])
  func unrepresentableFallbackCannotExceedOwnerAllocationOrSpendForInvisibleCredit(
    scenario: String
  ) throws {
    let mainValue: Double
    let maximum: Double
    switch scenario {
    case "ownerBudget":
      mainValue = 4
      maximum = 1e-15
    case "hugeMainULP":
      mainValue = Double(1 << 60)
      maximum = 0.05
    case "subnormalCredit":
      mainValue = 2 * Double.leastNonzeroMagnitude
      maximum = Double.leastNonzeroMagnitude
    default: throw SaveError.invalidCommander
    }
    let module = UUID()
    let bank = try #require(
      EMPBankState(module: module, capacity: 8, remaining: 8.0.nextDown, at: 0))
    let main = try #require(ElectricalReserve(capacity: mainValue, recharge: 0, at: 1))
    let terms = EMPBankTransfer.Terms(
      bankCapacity: 8, rechargePerSecond: 0.4, efficiency: 0.8, maximumMainDebit: maximum)
    try #require(bank.valid && main.valid && terms.valid && maximum > 0)
    try #require(maximum <= main.remaining && main.physicalTime == 1)
    #expect(
      EMPBankTransfer.stage(
        bank: bank, module: module, main: main, start: 0, end: 1,
        paused: false, terms: terms) == .failure(.arithmeticRefusal))
    #expect(bank.remaining == 8.0.nextDown && bank.physicalTime == 0)
    #expect(bank.module == module && bank.lastDischarge == nil)
    #expect(main.remaining == mainValue && main.physicalTime == 1 && main.disabledAt == nil)
  }
}
