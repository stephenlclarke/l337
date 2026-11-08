import Testing

@testable import L337Core

struct NativeMemoryAtlasOriginalObjectivesUnitTests {
  @Test func originalLoanReceivingAndAuditRemainInTheNineStageRoute() {
    var remaining = Set(NativeMemoryAtlasOriginalStage.allCases)
    var current: NativeMemoryAtlasOriginalStage? = .accept
    for _ in NativeMemoryAtlasOriginalStage.allCases {
      guard let stage = current else {
        Issue.record("Memory Atlas ended before its remaining original objectives.")
        return
      }
      #expect(remaining.remove(stage) != nil)
      current = stage.next
    }
    #expect(current == nil && remaining.isEmpty)
    #expect(NativeMemoryAtlasOriginalStage.collectReference.next == .survey)
    #expect(NativeMemoryAtlasOriginalStage.returnAndAudit.next == .closeCase)
    #expect(NativeMemoryAtlasOriginalStage.collectReference.world == NativeMemoryAtlasOriginalStage.returnAndAudit.world)
  }

  @Test func theAuthoredChoiceRemainsAtTheWitnessReceiver() {
    let witness = NativeMemoryAtlasOriginalStage.independentWitness
    #expect(witness.next == .chooseSettlement)
    #expect(witness.world == NativeMemoryAtlasOriginalStage.chooseSettlement.world)
    #expect(witness.world != NativeMemoryAtlasOriginalStage.accept.world)
    #expect(NativeMemoryAtlasOriginalStage.fieldWork.world == NativeMemoryAtlasOriginalStage.applySettlement.world)
  }

  @Test func privateCustodyAndConsentedPublicationHaveDistinctRequiredProofs() {
    let stage = NativeMemoryAtlasOriginalStage.applySettlement
    #expect(stage.requiredTargets() == nil)
    let published = stage.requiredTargets(for: .separatedAtlas) ?? []
    let privateCustody = stage.requiredTargets(for: .privateCustody) ?? []
    #expect(published.count == 2 && privateCustody.count == 2)
    #expect(Set(published).isDisjoint(with: Set(privateCustody)))
    let summary = "memory-atlas-settlement-summary"
    #expect(!published.contains(summary) && !privateCustody.contains(summary))
    for branch in NativeMemoryAtlasSettlement.allCases {
      #expect(NativeMemoryAtlasOriginalStage.survey.requiredTargets(for: branch)?.count == 3)
      #expect(NativeMemoryAtlasOriginalStage.fieldWork.requiredTargets(for: branch)?.count == 2)
    }
  }

  @Test func journalGroupingKeepsCoLocatedStagesInFourOrderedGroups() throws {
    let stages = NativeMemoryAtlasOriginalStage.allCases
    let phases = stages.map(\.journalPhase)
    let order = try phases.map { phase in
      try #require(NativeMemoryAtlasJournalPhase.allCases.firstIndex(of: phase))
    }
    #expect(order == order.sorted())
    let changes = zip(phases, phases.dropFirst()).filter { pair in pair.0 != pair.1 }.count
    #expect(changes == NativeMemoryAtlasJournalPhase.allCases.count - 1)
    #expect(NativeMemoryAtlasOriginalStage.accept.journalPhase == NativeMemoryAtlasOriginalStage.collectReference.journalPhase)
    #expect(NativeMemoryAtlasOriginalStage.returnAndAudit.journalPhase == NativeMemoryAtlasOriginalStage.closeCase.journalPhase)
  }
}
