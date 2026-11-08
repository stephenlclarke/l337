import Foundation

/// EMP-domain value for one physical module. Construction is not purchase, fit or save authority.
/// All amounts use the existing native-energy convention; production terms remain owner inputs.
struct EMPBankState: Equatable, Codable, Sendable {
  let module: UUID
  private(set) var capacity: Double
  private(set) var remaining: Double
  private(set) var physicalTime: Double
  private(set) var lastDischarge: EMPChargeState?

  var valid: Bool {
    guard capacity.isFinite, capacity > 0, remaining.isFinite,
      remaining >= 0, remaining <= capacity, physicalTime.isFinite, physicalTime >= 0
    else { return false }
    guard let lastDischarge else { return true }
    return lastDischarge.valid && lastDischarge.phase == .released
      && lastDischarge.weapon == module
      && lastDischarge.endedAt.map { $0 <= physicalTime } == true
  }

  /// Initial charge is mandatory. There is no full-bank, empty-bank or purchase-policy default.
  init?(module: UUID, capacity: Double, remaining: Double, at time: Double) {
    self.module = module
    self.capacity = capacity
    self.remaining = remaining
    physicalTime = time
    lastDischarge = nil
    guard valid else { return nil }
  }

  private enum CodingKeys: String, CodingKey {
    case module, capacity, remaining, physicalTime, lastDischarge
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    module = try values.decode(UUID.self, forKey: .module)
    capacity = try values.decode(Double.self, forKey: .capacity)
    remaining = try values.decode(Double.self, forKey: .remaining)
    physicalTime = try values.decode(Double.self, forKey: .physicalTime)
    guard values.contains(.lastDischarge) else {
      throw DecodingError.keyNotFound(
        CodingKeys.lastDischarge,
        .init(codingPath: decoder.codingPath, debugDescription: "Missing EMP replay state"))
    }
    lastDischarge = try values.decodeIfPresent(EMPChargeState.self, forKey: .lastDischarge)
    guard valid else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid EMP bank state"))
    }
  }

  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(module, forKey: .module)
    try values.encode(capacity, forKey: .capacity)
    try values.encode(remaining, forKey: .remaining)
    try values.encode(physicalTime, forKey: .physicalTime)
    if let lastDischarge {
      try values.encode(lastDischarge, forKey: .lastDischarge)
    } else {
      try values.encodeNil(forKey: .lastDischarge)
    }
  }

  struct CapacityChange: Equatable, Sendable {
    let expected: EMPBankState
    let bank: EMPBankState
    let discarded: Double

    fileprivate init(expected: EMPBankState, bank: EMPBankState, discarded: Double) {
      self.expected = expected
      self.bank = bank
      self.discarded = discarded
    }
  }

  /// The existing item owner must authorize the upgrade. Shrinkage is discard, never main credit.
  func changingCapacity(to capacity: Double, at time: Double) -> CapacityChange? {
    guard valid, capacity.isFinite, capacity > 0, time.isFinite, time >= physicalTime else {
      return nil
    }
    var candidate = self
    candidate.capacity = capacity
    candidate.remaining = min(remaining, capacity)
    candidate.physicalTime = time
    guard candidate.valid else { return nil }
    return .init(expected: self, bank: candidate, discarded: remaining - candidate.remaining)
  }

  /// Skip a noncharging interval explicitly; elapsed time alone never produces bank energy.
  func skippingCharge(to time: Double) -> Self? {
    guard valid, time.isFinite, time >= physicalTime else { return nil }
    var candidate = self
    candidate.physicalTime = time
    return candidate
  }

  func availableShots(cost: Double) -> Int? {
    guard valid, cost.isFinite, cost > 0 else { return nil }
    let count = (remaining / cost).rounded(.down)
    guard count.isFinite else { return nil }
    return Int(exactly: count)
  }

  struct Discharge: Equatable, Sendable {
    let expected: EMPBankState
    let bank: EMPBankState
    let charge: EMPChargeState
    let debited: Double

    fileprivate init(
      expected: EMPBankState, bank: EMPBankState, charge: EMPChargeState, debited: Double
    ) {
      self.expected = expected
      self.bank = bank
      self.charge = charge
      self.debited = debited
    }
  }

  /// Models one released charge, not release admission. Existing warmup/ECM/victim/save gates
  /// must still run in the owner transaction. Copy/Codable replay state is not native durability.
  func stagingDischarge(_ charge: EMPChargeState, cost: Double) -> Discharge? {
    guard valid, charge.valid, charge.phase == .released, charge.weapon == module,
      let end = charge.endedAt, end >= physicalTime,
      cost.isFinite, cost > 0, remaining >= cost
    else { return nil }
    if let previous = lastDischarge {
      guard let previousEnd = previous.endedAt,
        charge.startedAt > previous.startedAt, end > previousEnd
      else { return nil }
    }
    var candidate = self
    candidate.remaining = remaining - cost
    candidate.physicalTime = end
    candidate.lastDischarge = charge
    // Never report a paid pulse when subtraction cannot represent its full debit.
    guard remaining - candidate.remaining == cost, candidate.valid else { return nil }
    return .init(expected: self, bank: candidate, charge: charge, debited: cost)
  }

  /// Arithmetic-only building block for EMPBankTransfer. This value cannot publish charge.
  func creditForStaging(_ amount: Double, at time: Double) -> Self? {
    guard valid, amount.isFinite, amount >= 0, time.isFinite, time >= physicalTime else {
      return nil
    }
    let total = remaining + amount
    guard total.isFinite else { return nil }
    var candidate = self
    candidate.remaining = min(capacity, total)
    if candidate.remaining - remaining > amount {
      candidate.remaining = max(remaining, candidate.remaining.nextDown)
    }
    candidate.physicalTime = time
    guard candidate.valid else { return nil }
    return candidate
  }
}
