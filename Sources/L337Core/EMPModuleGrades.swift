import Foundation

public enum EMPModuleAxis: String, Codable, CaseIterable, Sendable {
  case power, capacity, recharge
}

struct EMPModuleGradeIndices: Equatable, Codable, Sendable {
  let power: Int
  let capacity: Int
  let recharge: Int

  static let base = Self(power: 0, capacity: 0, recharge: 0)
  var valid: Bool { (0...3).contains(power) && (0...3).contains(capacity) && (0...3).contains(recharge) }

  func value(for axis: EMPModuleAxis) -> Int {
    switch axis {
    case .power: power
    case .capacity: capacity
    case .recharge: recharge
    }
  }

  func advancing(_ axis: EMPModuleAxis) -> Self? {
    guard valid, value(for: axis) < 3 else { return nil }
    return .init(
      power: power + (axis == .power ? 1 : 0),
      capacity: capacity + (axis == .capacity ? 1 : 0),
      recharge: recharge + (axis == .recharge ? 1 : 0))
  }
}

/// NEW authoring estimates adopted by Root; these are not original designer balance evidence.
enum EMPModuleGradePolicy {
  static let pulseCost = 8.0
  static let efficiency = 0.8
  static let massKilograms = 100.0
  static let powerMultipliers = [1.0, 2, 4, 8]
  static let capacities = [8.0, 16, 32, 64]
  static let rechargeRates = [0.4, 0.8, 1.6, 3.2]

  static let node = EquipmentNodeID(
    family: EquipmentRuntimeCatalog.utilityFamily(.empPirateBlaster),
    key: Equipment.empPirateBlaster)

  static func offer(axis: EMPModuleAxis, next: Int) -> Equipment? {
    guard (1...3).contains(next) else { return nil }
    let prices = axis == .power ? [30000, 60000, 120000] : [15000, 30000, 60000]
    // Preserve Equipment's existing stored technology convention and normal shop availability.
    return .init(
      name: "EMP " + axis.rawValue + " grade " + String(next),
      price: prices[next - 1], technology: [9, 11, 13][next - 1])
  }

  static func shop(galaxy: Int, system: Int) -> String? {
    guard (0..<8).contains(galaxy), (0...Plugh.systemID).contains(system) else { return nil }
    return "galaxy:\(galaxy)/system:\(system)"
  }

  static func validPrice(_ receipt: EMPModulePaidUpgradeReceipt) -> Bool {
    let parts = receipt.shop.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].hasPrefix("galaxy:"), parts[1].hasPrefix("system:"),
      let galaxy = Int(parts[0].dropFirst(7)), let system = Int(parts[1].dropFirst(7)),
      shop(galaxy: galaxy, system: system) == receipt.shop,
      let offer = offer(axis: receipt.axis, next: receipt.after.value(for: receipt.axis)),
      receipt.cataloguePrice == offer.price
    else { return false }
    return receipt.paidPrice == (system == Plugh.systemID ? Plugh.discount(offer.price) : offer.price)
  }
}

/// Only the domain purchase owner can commit these facts; decoding confers no release authority.
struct EMPModulePaidUpgradeReceipt: Equatable, Codable, Sendable {
  let operation: UUID
  let owner: UUID
  let module: UUID
  let axis: EMPModuleAxis
  let before: EMPModuleGradeIndices
  let after: EMPModuleGradeIndices
  let sourceInventoryRevision: UInt64
  let resultingRevision: UInt64
  let physicalTime: Double
  let shop: String
  let cataloguePrice: Int
  let paidPrice: Int

  var valid: Bool {
    before.advancing(axis) == after && sourceInventoryRevision < UInt64.max
      && resultingRevision == sourceInventoryRevision + 1
      && physicalTime.isFinite && physicalTime >= 0 && shop.utf8.count <= 32
      && EMPModuleGradePolicy.validPrice(self)
  }
}

struct EMPModuleGrades: Equatable, Codable, Sendable {
  let power: Int
  let capacity: Int
  let recharge: Int
  let paid: [EMPModulePaidUpgradeReceipt]

  static let base = Self(power: 0, capacity: 0, recharge: 0, paid: [])
  var indices: EMPModuleGradeIndices { .init(power: power, capacity: capacity, recharge: recharge) }

  var valid: Bool {
    guard indices.valid, paid.count <= 9, paid.count == power + capacity + recharge else { return false }
    var prior = EMPModuleGradeIndices.base
    var revision: UInt64 = 0
    var time = 0.0
    var operations: Set<UUID> = []
    for receipt in paid {
      guard receipt.valid, receipt.before == prior,
        receipt.sourceInventoryRevision >= revision, receipt.physicalTime >= time,
        operations.insert(receipt.operation).inserted
      else { return false }
      prior = receipt.after
      revision = receipt.resultingRevision
      time = receipt.physicalTime
    }
    return prior == indices
  }

  init(power: Int, capacity: Int, recharge: Int, paid: [EMPModulePaidUpgradeReceipt]) {
    self.power = power
    self.capacity = capacity
    self.recharge = recharge
    self.paid = paid
  }

  private enum CodingKeys: String, CodingKey { case power, capacity, recharge, paid }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    power = try values.decode(Int.self, forKey: .power)
    capacity = try values.decode(Int.self, forKey: .capacity)
    recharge = try values.decode(Int.self, forKey: .recharge)
    var records = try values.nestedUnkeyedContainer(forKey: .paid)
    var decoded: [EMPModulePaidUpgradeReceipt] = []
    while !records.isAtEnd {
      guard decoded.count < 9 else {
        throw DecodingError.dataCorruptedError(in: records, debugDescription: "Too many EMP upgrades")
      }
      decoded.append(try records.decode(EMPModulePaidUpgradeReceipt.self))
    }
    paid = decoded
    guard valid else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid EMP module grades"))
    }
  }

  func encode(to encoder: any Encoder) throws {
    guard valid else {
      throw EncodingError.invalidValue(
        self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid EMP module grades"))
    }
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(power, forKey: .power)
    try values.encode(capacity, forKey: .capacity)
    try values.encode(recharge, forKey: .recharge)
    try values.encode(paid, forKey: .paid)
  }

  func terms(maximumMainDebit: Double) -> EMPBankTransfer.Terms? {
    guard valid else { return nil }
    let terms = EMPBankTransfer.Terms(
      bankCapacity: EMPModuleGradePolicy.capacities[capacity],
      rechargePerSecond: EMPModuleGradePolicy.rechargeRates[recharge],
      efficiency: EMPModuleGradePolicy.efficiency, maximumMainDebit: maximumMainDebit)
    return terms.valid ? terms : nil
  }

  static func hasPaidBase(
    _ item: OwnedEquipmentItem, owner: UUID, history: EquipmentPurchaseHistory
  ) -> Bool {
    paidBase(item, owner: owner, receipts: history.paid) != nil
  }

  private static func paidBase(
    _ item: OwnedEquipmentItem, owner: UUID, receipts: [EquipmentPaidPurchaseReceipt]
  ) -> EquipmentPaidPurchaseReceipt? {
    guard case .paid(let buyer, let operation) = item.provenance, buyer == owner else { return nil }
    return receipts.first {
      $0.owner == owner && $0.node == EMPModuleGradePolicy.node && $0.transaction == operation
        && $0.binding.request.newItem == item.id
    }
  }

  static func validate(
    inventory: OwnedEquipmentInventory, history: EquipmentPurchaseHistory, at time: Double
  ) throws {
    guard time.isFinite, time >= 0 else { throw CommanderEquipmentError.invalidRuntimeStatistics }
    guard inventory.items.contains(where: { $0.node == EMPModuleGradePolicy.node }) else {
      return
    }
    let bases = Dictionary(grouping: history.paid, by: \.transaction)
    var operations = Set(bases.keys)
    for item in inventory.items where item.node == EMPModuleGradePolicy.node {
      guard let bank = item.empBank, let grades = item.empGrades, item.empBankValid,
        bank.physicalTime <= time
      else { throw CommanderEquipmentError.invalidRuntimeStatistics }
      if case .paid(_, let operation) = item.provenance {
        guard let base = paidBase(item, owner: inventory.owner, receipts: bases[operation] ?? []),
          base.binding.snapshot.revision < inventory.revision,
          grades.paid.first.map({ $0.sourceInventoryRevision > base.binding.snapshot.revision }) ?? true
        else { throw CommanderEquipmentError.incompleteState }
      } else if !grades.paid.isEmpty {
        throw CommanderEquipmentError.incompleteState
      }
      for receipt in grades.paid {
        guard receipt.owner == inventory.owner, receipt.module == item.id,
          receipt.resultingRevision <= inventory.revision, receipt.physicalTime <= bank.physicalTime,
          operations.insert(receipt.operation).inserted
        else { throw CommanderEquipmentError.incompleteState }
      }
    }
  }
}
