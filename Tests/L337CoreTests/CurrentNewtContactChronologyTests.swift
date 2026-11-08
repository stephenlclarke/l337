import Testing

@testable import L337Core

struct CurrentNewtContactChronologyTests {
  @Test
  func laterOverlapCannotHideAGenuinelyEarlierEventUnderAnyActorPermutation() throws {
    let a = CurrentNewtContactChronology.Bracket(lower: 0.02, upper: 0.03)
    let b = CurrentNewtContactChronology.Bracket(lower: 0.025, upper: 0.035)
    let c = CurrentNewtContactChronology.Bracket(lower: 0.001, upper: 0.002)
    for permutation in [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]] {
      let selected = try #require(CurrentNewtContactChronology.earliest(permutation))
      #expect(permutation[selected].lower == c.lower && permutation[selected].upper == c.upper)
    }
    #expect(CurrentNewtContactChronology.earliest([a, b]) == nil)
    #expect(CurrentNewtContactChronology.earliest([b, a]) == nil)
  }

  @Test
  func disjointWitnessBracketsKeepPhysicalOrderWhenActorsAreReordered() {
    #expect(CurrentNewtContactChronology.compare(lower: 0.01, upper: 0.011,
      againstLower: 0.02, againstUpper: 0.021) == .before)
    #expect(CurrentNewtContactChronology.compare(lower: 0.02, upper: 0.021,
      againstLower: 0.01, againstUpper: 0.011) == .after)
  }

  @Test
  func sameLowerBinsWithDifferentUpperWitnessesRefuseInBothActorOrders() {
    #expect(CurrentNewtContactChronology.compare(lower: 0.01, upper: 0.0105,
      againstLower: 0.01, againstUpper: 0.0108) == .ambiguous)
    #expect(CurrentNewtContactChronology.compare(lower: 0.01, upper: 0.0108,
      againstLower: 0.01, againstUpper: 0.0105) == .ambiguous)
  }

  @Test
  func intersectingAndTouchingBracketsDoNotInventASimultaneousPolicy() {
    #expect(CurrentNewtContactChronology.compare(lower: 0.01, upper: 0.02,
      againstLower: 0.015, againstUpper: 0.025) == .ambiguous)
    #expect(CurrentNewtContactChronology.compare(lower: 0.025, upper: 0.03,
      againstLower: 0.015, againstUpper: 0.025) == .ambiguous)
    #expect(CurrentNewtContactChronology.compare(lower: .nan, upper: 0.02,
      againstLower: 0.015, againstUpper: 0.025) == .ambiguous)
  }
}
