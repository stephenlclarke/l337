import Testing

@testable import L337Core

struct NativeTitheOriginalObjectivesUnitTests {
  @Test func theOriginalFourteenStagesRetainDeliveryAndAuditBeforeClosing() {
    var remaining = Set(NativeTitheOriginalStage.allCases)
    var current: NativeTitheOriginalStage? = .accept
    for _ in NativeTitheOriginalStage.allCases {
      guard let stage = current else {
        Issue.record("Tithe's route ended before its remaining original objectives.")
        return
      }
      let removed = remaining.remove(stage)
      #expect(removed != nil)
      current = stage.next
    }
    #expect(current == nil && remaining.isEmpty)
    #expect(NativeTitheOriginalStage.auditAcquisitions.next == .protectLifeline)
    #expect(NativeTitheOriginalStage.settleFoundry.next == .verifyControl)
    #expect(NativeTitheOriginalStage.verifyControl.next == .closeCase)
    #expect(NativeTitheOriginalStage.auditAcquisitions.world == NativeTitheOriginalStage.verifyControl.world)
  }

  @Test func allThreeJunctionsRequireTheSelectedPlansDistinctOperations() {
    let stages = NativeTitheOriginalStage.allCases.filter { $0.settlementJunction != nil }
    #expect(stages == [.settleOre, .settleWater, .settleFoundry])
    for stage in stages {
      #expect(stage.requiredTargets() == nil && stage.authoredEvent() == nil)
      let charter = stage.requiredTargets(for: .boundedCharter) ?? []
      let sever = stage.requiredTargets(for: .severNetwork) ?? []
      #expect(charter.count == 2 && sever.count == 2)
      #expect(Set(charter).isDisjoint(with: Set(sever)))
      #expect(stage.authoredEvent(for: .boundedCharter) != stage.authoredEvent(for: .severNetwork))
    }
  }

  @Test func bothSettlementsRetainTheSameEarlierResourceAndSupplyRequirements() {
    let choices = NativeTitheOriginalStage.allCases.filter { !$0.choices.isEmpty }
    #expect(choices == [.chooseSettlement])
    for branch in NativeTitheSettlement.allCases {
      #expect(NativeTitheOriginalStage.secureOre.requiredTargets(for: branch)?.count == 3)
      #expect(NativeTitheOriginalStage.secureWater.requiredTargets(for: branch)?.count == 3)
      #expect(NativeTitheOriginalStage.protectLifeline.requiredTargets(for: branch)?.count == 1)
      #expect(NativeTitheOriginalStage.verifyControl.requiredTargets(for: branch)?.count == 1)
    }
  }
}
