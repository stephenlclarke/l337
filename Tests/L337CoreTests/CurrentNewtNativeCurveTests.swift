import Foundation
import Testing

@testable import L337Core

/// Geometry units only; these shapes install no kit, person or runtime actor.
struct CurrentNewtNativeCurveTests {
  @Test
  func actualStaticClearanceCanBeProvedWithTheNativeSolidQuery() throws {
    let hull = try PreparedHull(mesh: box())
    let result = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 0,
      sourceAt: { _ in .init(position: .init(-2, 0, 0)) },
      targetAt: { _ in .init(position: .init(2, 0, 0)) })
    guard case .clear = result else {
      Issue.record("A separated static native pair was not proved clear")
      return
    }
  }

  @Test
  func nonlinearCrossingCannotBeClearedByItsSeparatedEndpointChord() throws {
    let hull = try PreparedHull(mesh: box())
    let result = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 105, targetPointSpeed: 0,
      sourceAt: { time in
        let u = time / 0.1
        return .init(position: .init(-2 + 4 * u, 2 - 2 * sin(.pi * u), 0))
      }, targetAt: { _ in .init() })
    if case .clear = result { Issue.record("The actual curved solid crossing was falsely cleared") }
  }

  @Test
  func initialTouchCannotAcquireAnOrdinaryNativeContinuation() throws {
    let hull = try PreparedHull(mesh: box())
    let result = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 0,
      sourceAt: { _ in .init(position: .init(-0.1, 0, 0)) },
      targetAt: { _ in .init(position: .init(0.1, 0, 0)) })
    guard case .refused = result else {
      Issue.record("Initial zero-gap contact bypassed native proof")
      return
    }
  }

  @Test
  func exhaustedNativeBudgetCannotClearAnUnobservedCurve() throws {
    let hull = try PreparedHull(mesh: box())
    let result = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 10, targetPointSpeed: 0,
      sourceAt: { time in .init(position: .init(-2 + time, 0, 0)) },
      targetAt: { _ in .init(position: .init(2, 0, 0)) },
      budget: .init(
        distanceQueries: 1, triangleTests: 500_000,
        nodeVisits: 500_000, subdivisionDepth: 12))
    guard case .refused = result else {
      Issue.record("Unobserved interval escaped its native work budget")
      return
    }
  }

  private func box() -> Mesh {
    let r = 0.1
    return .init(
      vertices: [
        .init(-r, -r, -r), .init(r, -r, -r), .init(r, r, -r), .init(-r, r, -r),
        .init(-r, -r, r), .init(r, -r, r), .init(r, r, r), .init(-r, r, r),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
      ])
  }
}

extension CurrentNewtNativeCurveTests {
  @Test func reportedWorkCarriesTheRealBudgetAcrossSeparateNativePairs() throws {
    let hull = try PreparedHull(mesh: box())
    var budget = HullSweepBudget.standard
    budget.distanceQueries = 3
    var first = HullSweepResult(
      failure: nil, obstacle: nil, minimumSampledClearance: nil,
      distanceQueries: 0, triangleTests: 0, nodeVisits: 0)
    let clear = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 0,
      sourceAt: { _ in .init(position: .init(-2, 0, 0)) },
      targetAt: { _ in .init(position: .init(2, 0, 0)) }, budget: budget, report: &first)
    guard case .clear = clear else {
      Issue.record("First separated pair was not proved clear")
      return
    }
    try #require(first.distanceQueries > 0 && first.distanceQueries < budget.distanceQueries)
    budget.distanceQueries -= first.distanceQueries
    budget.triangleTests -= first.triangleTests
    budget.nodeVisits -= first.nodeVisits
    var second = HullSweepResult(
      failure: nil, obstacle: nil, minimumSampledClearance: nil,
      distanceQueries: 0, triangleTests: 0, nodeVisits: 0)
    let refused = HullSweepSafety.firstCurrentNewtCurveContact(
      source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 0,
      sourceAt: { _ in .init(position: .init(-3, 0, 0)) },
      targetAt: { _ in .init(position: .init(3, 0, 0)) }, budget: budget, report: &second)
    guard case .refused(.workBudgetExceeded) = refused else {
      Issue.record("A later pair received a fresh budget instead of the remaining work")
      return
    }
    #expect(first.distanceQueries + second.distanceQueries == 3)
    #expect(second.failure == .workBudgetExceeded)
    #expect(first.triangleTests + second.triangleTests <= HullSweepBudget.standard.triangleTests)
    #expect(first.nodeVisits + second.nodeVisits <= HullSweepBudget.standard.nodeVisits)
  }
}
