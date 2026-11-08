import Testing

@testable import L337Core

struct NativeC02OriginalObjectivesUnitTests {
  @Test func authoredRouteReachesEveryObjectiveOnceWithoutACycle() {
    var remaining = Set(NativeC02OriginalStage.allCases)
    var current: NativeC02OriginalStage? = .accept
    for _ in NativeC02OriginalStage.allCases {
      guard let stage = current else {
        Issue.record("The original Choir route ended before its remaining objectives.")
        return
      }
      #expect(remaining.remove(stage) != nil)
      current = stage.next
    }
    #expect(current == nil && remaining.isEmpty)
  }

  @Test func calibrationBandsAndListeningPositionsRemainSeparateObjectives() {
    let stages = NativeC02OriginalStage.allCases
    let targets = stages.flatMap(\.requiredTargets)
    #expect(Set(targets).count == targets.count)
    #expect(Set(NativeC02OriginalStage.calibrate.requiredTargets).count == 3)
    #expect(Set(NativeC02OriginalStage.listen.requiredTargets).count == 3)
    #expect(NativeC02OriginalStage.calibrate.world != NativeC02OriginalStage.listen.world)
    #expect(stages.allSatisfy { !$0.requiredTargets.isEmpty && !$0.objective.isEmpty })
  }

  @Test func independentChoicesReconvergeBeforeTheSameCaseClosure() {
    let branching = NativeC02OriginalStage.allCases.filter { !$0.choices.isEmpty }
    #expect(branching == [.exposeImitation, .rendezvous])
    #expect(branching.allSatisfy { $0.choices.count == 2 && Set($0.choices).count == 2 })
    #expect(NativeC02OriginalStage.exposeImitation.next == .rendezvous)
    #expect(NativeC02OriginalStage.rendezvous.next == .closeCase)
    #expect(NativeC02OriginalStage.closeCase.world == NativeC02OriginalStage.accept.world)
  }
}
