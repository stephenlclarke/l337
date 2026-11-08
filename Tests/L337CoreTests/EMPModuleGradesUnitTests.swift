import Foundation
import Testing

@testable import L337Core

/// Modeled receipt values exercise validation, not physical purchase or pulse authority.
enum EMPModuleGradeValueFixture {
  static func receipt(
    before: EMPModuleGradeIndices, axis: EMPModuleAxis, index: Int,
    owner: UUID, module: UUID
  ) throws -> EMPModulePaidUpgradeReceipt {
    let after = try #require(before.advancing(axis))
    let prices = axis == .power ? [30000, 60000, 120000] : [15000, 30000, 60000]
    let price = prices[after.value(for: axis) - 1]
    return .init(
      operation: UUID(), owner: owner, module: module, axis: axis, before: before, after: after,
      sourceInventoryRevision: UInt64(index), resultingRevision: UInt64(index + 1),
      physicalTime: Double(index), shop: "galaxy:0/system:7", cataloguePrice: price,
      paidPrice: price)
  }
}

struct EMPModuleGradesUnitTests {
  @Test func adoptedEMPTableKeepsThreeIndependentAxesAndCurrentPriceUnits() throws {
    #expect(EMPModuleGradePolicy.pulseCost == 8 && EMPModuleGradePolicy.efficiency == 0.8)
    #expect(EMPModuleGradePolicy.massKilograms == 100)
    #expect(EMPModuleGradePolicy.powerMultipliers == [1, 2, 4, 8])
    #expect(EMPModuleGradePolicy.capacities == [8, 16, 32, 64])
    #expect(EMPModuleGradePolicy.rechargeRates == [0.4, 0.8, 1.6, 3.2])
    var total = 30000
    for axis in EMPModuleAxis.allCases {
      for next in 1...3 {
        let offer = try #require(EMPModuleGradePolicy.offer(axis: axis, next: next))
        let prices = axis == .power ? [30000, 60000, 120000] : [15000, 30000, 60000]
        #expect(offer.price == prices[next - 1])
        #expect(offer.technology == [9, 11, 13][next - 1])
        total += offer.price
      }
    }
    #expect(total == 450000)
    #expect(EMPModuleGradePolicy.offer(axis: .power, next: 0) == nil)
    #expect(EMPModuleGradePolicy.offer(axis: .capacity, next: 4) == nil)
  }

  @Test func allNineModeledStepsRoundTripWithExactPredecessorsAndNoTenthUpgrade() throws {
    let owner = UUID()
    let module = UUID()
    var grades = EMPModuleGrades.base
    for axis in EMPModuleAxis.allCases {
      for _ in 0..<3 {
        let receipt = try EMPModuleGradeValueFixture.receipt(
          before: grades.indices, axis: axis, index: grades.paid.count, owner: owner, module: module)
        grades = .init(
          power: receipt.after.power, capacity: receipt.after.capacity,
          recharge: receipt.after.recharge, paid: grades.paid + [receipt])
        #expect(grades.valid)
      }
      #expect(grades.indices.advancing(axis) == nil)
    }
    #expect(grades.paid.count == 9 && grades.power == 3 && grades.capacity == 3 && grades.recharge == 3)
    #expect(try JSONDecoder().decode(EMPModuleGrades.self, from: JSONEncoder().encode(grades)) == grades)
    let terms = try #require(grades.terms(maximumMainDebit: 4))
    #expect(terms.bankCapacity == 64 && terms.rechargePerSecond == 3.2 && terms.efficiency == 0.8)
    let overflow = EMPModuleGrades(power: 3, capacity: 3, recharge: 3, paid: grades.paid + [grades.paid[0]])
    #expect(!overflow.valid)
  }

  @Test func currentGradeCodecRejectsMissingNullAndUnpaidGrades() throws {
    let encoded = try JSONEncoder().encode(EMPModuleGrades.base)
    #expect(try JSONDecoder().decode(EMPModuleGrades.self, from: encoded) == .base)
    let original = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    for key in ["power", "capacity", "recharge", "paid"] {
      for null in [false, true] {
        var object = original
        if null { object[key] = NSNull() } else { object.removeValue(forKey: key) }
        #expect(throws: (any Error).self) {
          _ = try JSONDecoder().decode(
            EMPModuleGrades.self, from: JSONSerialization.data(withJSONObject: object))
        }
      }
    }
    var unpaid = original
    unpaid["power"] = 1
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(
        EMPModuleGrades.self, from: JSONSerialization.data(withJSONObject: unpaid))
    }
    let ordinary = try missionGearGame(missiles: 1)
    try ordinary.commander.validateEquipmentState()
    let inventory = try #require(ordinary.commander.equipmentInventory)
    let history = try #require(ordinary.commander.equipmentPurchaseHistory)
    try EMPModuleGrades.validate(
      inventory: inventory, history: history, at: ordinary.commander.flightSimulation.physicalTime)
    for badClock in [Double.nan, Double.infinity, -1.0] {
      #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics) {
        try EMPModuleGrades.validate(inventory: inventory, history: history, at: badClock)
      }
    }
    var foreign = ordinary.commander
    foreign.savedEquipmentPurchaseHistory = .init(
      owner: UUID(), revision: history.revision, paid: history.paid, legacy: history.legacy)
    #expect(throws: CommanderEquipmentError.incompleteState) {
      try foreign.validateEquipmentState()
    }
  }

  @Test func receiptCodecRejectsSkippedAxisPriceRevisionAndReplay() throws {
    let receipt = try EMPModuleGradeValueFixture.receipt(
      before: .base, axis: .power, index: 0, owner: UUID(), module: UUID())
    let grades = EMPModuleGrades(power: 1, capacity: 0, recharge: 0, paid: [receipt])
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(grades)) as? [String: Any])
    for kind in ["skip", "otherAxis", "price", "revision", "missingOperation", "replay"] {
      var object = original
      var paid = try #require(object["paid"] as? [[String: Any]])
      switch kind {
      case "skip": paid[0]["after"] = ["power": 2, "capacity": 0, "recharge": 0]
      case "otherAxis": paid[0]["after"] = ["power": 1, "capacity": 1, "recharge": 0]
      case "price": paid[0]["paidPrice"] = 0
      case "revision": paid[0]["resultingRevision"] = 0
      case "missingOperation": paid[0].removeValue(forKey: "operation")
      default: paid.append(paid[0])
      }
      object["paid"] = paid
      #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(
          EMPModuleGrades.self, from: JSONSerialization.data(withJSONObject: object))
      }
    }
    #expect(grades.valid)
  }
}
