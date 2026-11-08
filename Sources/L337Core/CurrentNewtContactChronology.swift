import Foundation

/// Order already proved contact brackets. Overlap supplies no simultaneous
/// impact policy and never lets actor/component array order choose the impulse.
enum CurrentNewtContactChronology {
  enum Order { case before, after, ambiguous }
  struct Bracket {
    let lower: Double
    let upper: Double
  }

  /// Decide only after collecting the bounded scene candidates. Overlap later
  /// than a proved earlier event cannot veto that event under one actor order.
  static func earliest(_ candidates: [Bracket]) -> Int? {
    guard !candidates.isEmpty, candidates.count <= AsteroidImpactPolicy.maximumCandidatePairs,
      let first = candidates.indices.min(by: { candidates[$0].lower < candidates[$1].lower })
    else { return nil }
    let selected = candidates[first]
    for index in candidates.indices where index != first {
      guard compare(lower: selected.lower, upper: selected.upper,
        againstLower: candidates[index].lower, againstUpper: candidates[index].upper) == .before
      else { return nil }
    }
    guard selected.lower.isFinite, selected.upper.isFinite,
      selected.lower >= 0, selected.upper >= selected.lower else { return nil }
    return first
  }

  static func compare(lower: Double, upper: Double,
    againstLower: Double, againstUpper: Double) -> Order
  {
    guard lower.isFinite, upper.isFinite, againstLower.isFinite, againstUpper.isFinite,
      lower >= 0, upper >= lower, againstLower >= 0, againstUpper >= againstLower
    else { return .ambiguous }
    if upper < againstLower { return .before }
    if againstUpper < lower { return .after }
    return .ambiguous
  }
}
