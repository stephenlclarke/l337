import Foundation
import Testing

@testable import L337Core

private func bankRelease(module: UUID, start: Double, end: Double) -> EMPChargeState {
  let system = SystemIdentity(galaxy: 0, system: 7)
  var charge = EMPChargeState(
    player: .init(system: system, visit: 1, entity: 0),
    target: .init(system: system, visit: 1, entity: 2),
    owner: UUID(), hull: UUID(), weapon: module, startedAt: start)
  charge.phase = .released
  charge.endedAt = end
  return charge
}

private func bankObject(_ bank: EMPBankState) throws -> [String: Any] {
  try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(bank)) as? [String: Any])
}

struct EMPBankStateTests {
  @Test func explicitStateNeverMintsAFullBankAndDepletionRemainsValid() throws {
    let module = UUID()
    let empty = try #require(EMPBankState(module: module, capacity: 8, remaining: 0, at: 0))
    let partial = try #require(EMPBankState(module: module, capacity: 8, remaining: 3, at: 0))
    #expect(empty.valid && empty.remaining == 0 && empty.availableShots(cost: 2) == 0)
    #expect(partial.remaining == 3 && partial.availableShots(cost: 2) == 1)
    for (capacity, remaining, time) in [
      (0.0, 0.0, 0.0), (-1, 0, 0), (8, -1, 0), (8, 9, 0), (8, 0, -1),
      (.infinity, 0, 0), (8, .nan, 0), (8, 0, .infinity),
    ] {
      #expect(EMPBankState(module: module, capacity: capacity, remaining: remaining, at: time) == nil)
    }
  }

  @Test func capacityChangesKeepChargeAndReportDiscardWithoutARefund() throws {
    let bank = try #require(EMPBankState(module: UUID(), capacity: 8, remaining: 6, at: 2))
    let increase = try #require(bank.changingCapacity(to: 16, at: 3))
    #expect(increase.expected == bank && increase.bank.remaining == 6 && increase.discarded == 0)
    let shrink = try #require(increase.bank.changingCapacity(to: 4, at: 4))
    #expect(shrink.bank.remaining == 4 && shrink.bank.capacity == 4 && shrink.discarded == 2)
    #expect(shrink.bank.module == bank.module && bank.remaining == 6)
    #expect(bank.changingCapacity(to: 0, at: 3) == nil)
    #expect(bank.changingCapacity(to: 16, at: 1) == nil)
  }

  @Test func aReleasedPulseCanExhaustTheBankWithoutDisablingIt() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 4, at: 0))
    let charge = bankRelease(module: module, start: 0, end: 10)
    let debit = try #require(bank.stagingDischarge(charge, cost: 4))
    #expect(debit.expected == bank && debit.debited == 4 && debit.charge == charge)
    #expect(debit.bank.remaining == 0 && debit.bank.valid && debit.bank.physicalTime == 10)
    #expect(debit.bank.lastDischarge == charge && bank.remaining == 4)
  }

  @Test func nonreleasedForeignInsufficientAndStalePulsesLeaveTheModelUnchanged() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 8, remaining: 4, at: 0))
    let charge = bankRelease(module: module, start: 0, end: 10)
    var charging = charge
    charging.phase = .charging
    charging.endedAt = nil
    var cancelled = charge
    cancelled.phase = .cancelled
    #expect(bank.stagingDischarge(charging, cost: 2) == nil)
    #expect(bank.stagingDischarge(cancelled, cost: 2) == nil)
    #expect(bank.stagingDischarge(bankRelease(module: UUID(), start: 0, end: 10), cost: 2) == nil)
    for cost in [5.0, 0, -1, .nan, .infinity] {
      #expect(bank.stagingDischarge(charge, cost: cost) == nil)
    }
    let later = try #require(bank.skippingCharge(to: 11))
    #expect(later.stagingDischarge(charge, cost: 2) == nil)
    #expect(bank.remaining == 4 && bank.lastDischarge == nil && bank.physicalTime == 0)
  }

  @Test func modeledReleaseHistorySurvivesCopyAndCodableWithoutClaimingNativeDurability() throws {
    let module = UUID()
    let initial = try #require(EMPBankState(module: module, capacity: 8, remaining: 6, at: 0))
    let first = bankRelease(module: module, start: 0, end: 10)
    let paid = try #require(initial.stagingDischarge(first, cost: 2)).bank
    let copied = paid
    let restored = try JSONDecoder().decode(EMPBankState.self, from: JSONEncoder().encode(paid))
    #expect(restored == copied && restored.lastDischarge == first)
    #expect(copied.stagingDischarge(first, cost: 2) == nil)
    #expect(restored.stagingDischarge(first, cost: 2) == nil)
    #expect(restored.stagingDischarge(bankRelease(module: module, start: 0, end: 9), cost: 2) == nil)
    let next = try #require(
      restored.stagingDischarge(bankRelease(module: module, start: 11, end: 21), cost: 2))
    #expect(next.bank.remaining == 2 && next.bank.physicalTime == 21)
    // This checks only value coding; no Commander codec, writer or inventory is exercised.
  }

  @Test func malformedDecodedBalancesAndReplayMarkersAreRejected() throws {
    let module = UUID()
    let initial = try #require(EMPBankState(module: module, capacity: 8, remaining: 6, at: 0))
    let paid = try #require(
      initial.stagingDischarge(bankRelease(module: module, start: 0, end: 10), cost: 2)).bank
    let original = try bankObject(paid)
    for (key, value) in [("remaining", 9.0), ("capacity", 0), ("physicalTime", -1)] {
      var bad = original
      bad[key] = value
      let bytes = try JSONSerialization.data(withJSONObject: bad)
      #expect(throws: DecodingError.self) { try JSONDecoder().decode(EMPBankState.self, from: bytes) }
    }
    var missing = original
    missing.removeValue(forKey: "lastDischarge")
    let missingBytes = try JSONSerialization.data(withJSONObject: missing)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(EMPBankState.self, from: missingBytes)
    }
    var foreign = original
    var release = try #require(foreign["lastDischarge"] as? [String: Any])
    release["weapon"] = UUID().uuidString
    foreign["lastDischarge"] = release
    let foreignBytes = try JSONSerialization.data(withJSONObject: foreign)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(EMPBankState.self, from: foreignBytes)
    }
    let emptyBytes = try JSONEncoder().encode(initial)
    #expect(try JSONDecoder().decode(EMPBankState.self, from: emptyBytes) == initial)
  }

  @Test func skippedTimeNeverCreditsEnergyOrRewindsTheClock() throws {
    let bank = try #require(EMPBankState(module: UUID(), capacity: 8, remaining: 3, at: 2))
    let skipped = try #require(bank.skippingCharge(to: 200))
    #expect(skipped.remaining == 3 && skipped.module == bank.module && skipped.lastDischarge == nil)
    #expect(skipped.physicalTime == 200 && bank.physicalTime == 2)
    #expect(skipped.skippingCharge(to: 199) == nil)
    #expect(skipped.skippingCharge(to: .infinity) == nil)
  }

  @Test func invisiblePulseDebitsAndUnrepresentableShotCountsCannotGrantEnergy() throws {
    let module = UUID()
    let bank = try #require(EMPBankState(module: module, capacity: 1, remaining: 1, at: 0))
    let charge = bankRelease(module: module, start: 0, end: 10)
    #expect(bank.stagingDischarge(charge, cost: .leastNonzeroMagnitude) == nil)
    #expect(bank.availableShots(cost: .leastNonzeroMagnitude) == nil)
    #expect(bank.availableShots(cost: 0) == nil)
    #expect(bank.availableShots(cost: .nan) == nil)
    #expect(bank.remaining == 1 && bank.lastDischarge == nil)
  }
}
