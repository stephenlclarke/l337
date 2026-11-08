import Foundation
import Testing

@testable import L337Core

/// Analytic geometry oracles only. No actor, source role, impact or clock grant.
struct NativeSphereCurveQueryTests {
  @Test func actualClockWindowDoesNotCreditAPositiveNominalTimeThatRoundsToOpening() throws {
    let start = 86_400.0
    let window = try #require(NativeCurveClockWindow(start: start, end: start.nextUp))
    #expect(window.frontier(at: start.ulp * 0.25) == nil)
    let attained = try #require(window.frontier(at: start.ulp * 0.75))
    #expect(attained.physical == start.nextUp && attained.elapsed == start.ulp)
    #expect(window.lowerBound(at: start.ulp * 0.75) == start)
    let hull = try PreparedHull(mesh: box())
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: window.duration, pointSpeed: 0, targetPointSpeed: 0,
      pointAt: { _ in .init(0.013, 0.023, 0.037) }, targetAt: { _ in .init() }, clockWindow: window)
    guard case .contact(let contact, _) = query else {
      Issue.record("Genuine opening overlap was denied or borrowed future time"); return
    }
    #expect(contact.upperTime == 0 && contact.lowerTime == 0)
    #expect(contact.upperPhysicalTime == start && contact.lowerPhysicalTime == start)
  }

  @Test func continuouslySeparatedNativeCurvesReturnClearWithinTheSameBudget() throws {
    let hull = try PreparedHull(mesh: box())
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
      pointAt: { .init(-0.5 + 10 * $0, 0.023, 0.037) },
      targetAt: { _ in .init(position: .init(0, 2, 0)) })
    guard case .clear(let cost) = query else { Issue.record("Separated curves were not proved clear"); return }
    #expect(cost.failure == nil && cost.distanceQueries <= HullSweepBudget.standard.distanceQueries)
  }

  @Test func realPointCrossingHasClearEndpointsAndANativeFirstEntryBracket() throws {
    let hull = try PreparedHull(mesh: box())
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
      pointAt: { .init(-0.5 + 10 * $0, 0.023, 0.037) }, targetAt: { _ in .init() })
    guard case .contact(let contact, let report) = query else {
      Issue.record("Native point crossing did not produce a genuine solid witness"); return
    }
    #expect(contact.lowerTime <= 0.04 && contact.upperTime >= 0.04)
    #expect(contact.upperTime - contact.lowerTime <= 0.1 / 4096)
    #expect(contact.centre.x > -0.1 && contact.centre.x < 0.1)
    #expect(contact.matches(hull) && report.failure == nil && report.distanceQueries > 0)
    #expect(!contact.matches(try PreparedHull(mesh: box())))
  }

  @Test func movingTargetCrossesAStationaryPointWithoutAnEndpointOverlap() throws {
    let hull = try PreparedHull(mesh: box())
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0.1, pointSpeed: 0, targetPointSpeed: 10,
      pointAt: { _ in .init(0, 0.023, 0.037) },
      targetAt: { .init(position: .init(-0.5 + 10 * $0, 0, 0)) })
    guard case .contact(let contact, _) = query else {
      Issue.record("Moving hull crossed the real point without a native witness"); return
    }
    #expect(contact.lowerTime <= 0.04 && contact.upperTime >= 0.04)
    #expect(contact.targetPose.position.x > -0.1 && contact.targetPose.position.x < 0.1)
  }

  @Test func realRotatingTargetCannotBeReplacedByItsClearEndpointChord() throws {
    let hull = try PreparedHull(mesh: box(.init(0.4, 0.03, 0.1)))
    let omega = Double.pi / 0.2
    let motion = HullSceneMotion(start: .init(), end: .init(), initialVelocity: .init(0, 0, 0),
      acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, omega),
      duration: 0.1, playerRadius: 0)
    let bound = try #require(CurrentNewtQueryFrame.pointSpeedBound(motion: motion,
      localExtent: hull.radius, relativeTo: .init(0, 0, 0)))
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0.1, pointSpeed: 0, targetPointSpeed: bound,
      pointAt: { _ in .init(0.25, 0.25, 0.013) },
      targetAt: { HullSweepSafety.shipPose(motion, at: $0) })
    guard case .contact(let contact, let report) = query else {
      Issue.record("Actual rotating hull had no native interior witness"); return
    }
    #expect(contact.upperTime > 0 && contact.upperTime < 0.1)
    #expect(contact.matches(hull) && report.failure == nil && contact.radius == 0)
    #expect(contact.centre == .init(0.25, 0.25, 0.013))
    #expect(contact.targetPose == HullSweepSafety.shipPose(motion, at: contact.upperTime))
    #expect(contact.lowerTime >= 0 && contact.lowerTime <= contact.upperTime)
    #expect(contact.upperTime - contact.lowerTime <= 0.1 / Double(1 << HullSweepBudget.standard.subdivisionDepth))
    for time in [0.0, 0.1] {
      let endpoint = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
        duration: 0, pointSpeed: 0, targetPointSpeed: 0,
        pointAt: { _ in .init(0.25, 0.25, 0.013) }, targetAt: { _ in HullSweepSafety.shipPose(motion, at: time) })
      guard case .clear = endpoint else { Issue.record("Real rotating endpoint was not separated"); return }
    }
    let middle = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0, pointSpeed: 0, targetPointSpeed: 0,
      pointAt: { _ in .init(0.25, 0.25, 0.013) }, targetAt: { _ in HullSweepSafety.shipPose(motion, at: 0.05) })
    guard case .contact(let interior, _) = middle else { Issue.record("Real midpoint lost its native solid witness"); return }
    #expect(interior.matches(hull) && interior.upperTime == 0)
    let localInterior = interior.targetPose.shipPoint(interior.centre)
    #expect(abs(localInterior.x) < 0.4 && abs(localInterior.y) < 0.03 && abs(localInterior.z) < 0.1)
    #expect(report.distanceQueries <= HullSweepBudget.standard.distanceQueries
      && report.triangleTests <= HullSweepBudget.standard.triangleTests
      && report.nodeVisits <= HullSweepBudget.standard.nodeVisits)
  }

  @Test func actualWitnessAndBracketUseOneCommonBoostedQueryFrame() throws {
    let hull = try PreparedHull(mesh: box())
    var hits: [NativeSphereCurveContact] = []
    let offset = Vector3(1_000_000, -200_000, 30_000)
    for speed in [0.0, 80, -1200] {
      let boost = Vector3(speed, 7, -3)
      let frame = try #require(CurrentNewtQueryFrame(origin: offset, velocity: boost))
      let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
        duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
        pointAt: { offset + boost * $0 + Vector3(-0.5 + 10 * $0, 0.023, 0.037) },
        targetAt: { .init(position: offset + boost * $0) }, queryFrame: frame)
      guard case .contact(let hit, _) = query else {
        Issue.record("Common boost lost a genuine native point crossing"); return
      }
      hits.append(hit)
      let local = hit.centre - offset - boost * hit.upperTime
      #expect((local - Vector3(-0.5 + 10 * hit.upperTime, 0.023, 0.037)).length < 1e-7)
      #expect(hit.lowerTime <= 0.04 && hit.upperTime >= 0.04)
    }
    let allSatisfied = hits.allSatisfy { abs($0.upperTime - hits[0].upperTime) < 1e-6 }
    #expect(allSatisfied)
  }

  @Test func zeroTimeInteriorAndExactSurfaceContactDoNotBorrowFutureTime() throws {
    let hull = try PreparedHull(mesh: box())
    for point in [Vector3(0.013, 0.023, 0.037), .init(0.1, 0.023, 0.037)] {
      let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
        duration: 0, pointSpeed: 0, targetPointSpeed: 0,
        pointAt: { $0 == 0 ? point : nil }, targetAt: { $0 == 0 ? .init() : nil })
      guard case .contact(let contact, _) = query else {
        Issue.record("Genuine T0 native overlap was replaced by a positive-time frontier"); return
      }
      #expect(contact.lowerTime == 0 && contact.upperTime == 0 && contact.centre == point)
    }
  }

  @Test func finiteRadiusUsesRealTriangleFaceSupportWithoutAMissileHull() throws {
    let hull = try PreparedHull(mesh: box())
    let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0.06,
      duration: 0, pointSpeed: 0, targetPointSpeed: 0,
      pointAt: { _ in .init(0.15, 0.023, 0.037) }, targetAt: { _ in .init() })
    guard case .contact(let contact, _) = query else {
      Issue.record("Native sphere-face overlap required an invented source mesh"); return
    }
    #expect(contact.radius == 0.06 && contact.upperTime == 0)
  }

  @Test func anUnobservedThinCrossingAndExhaustedBudgetCannotBecomeClear() throws {
    // Retain the exact thin box and all six original quad surfaces. Explicit
    // triangles use native certified area support; polygon ear/projection
    // conditioning is not the subject of this curve/budget refusal regression.
    let thinBox = box(.init(1e-10, 0.1, 0.1))
    let thinFaces = thinBox.faces.flatMap { face in
      [[face[0], face[1], face[2]], [face[0], face[2], face[3]]]
    }
    let thin = try PreparedHull(mesh: .init(vertices: thinBox.vertices, faces: thinFaces))
    #expect(thin.triangleCount == 12 && thin.isClosed)
    let crossing = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: thin, radius: 0,
      duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
      pointAt: { .init(-0.347123 + 10 * $0, 0.023, 0.037) }, targetAt: { _ in .init() })
    if case .clear = crossing { Issue.record("Thin unobserved native crossing was falsely cleared") }
    let hull = try PreparedHull(mesh: box())
    let exhausted = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
      pointAt: { .init(-0.5 + 10 * $0, 0.023, 0.037) }, targetAt: { _ in .init() },
      budget: .init(distanceQueries: 1, triangleTests: 500_000, nodeVisits: 500_000, subdivisionDepth: 12))
    guard case .refused(let report) = exhausted else {
      Issue.record("Native query escaped the original work budget"); return
    }
    #expect(report.failure == .workBudgetExceeded)
  }

  @Test func missingCurveAndInvalidRadiusRefuseWithoutASurrogatePath() throws {
    let hull = try PreparedHull(mesh: box())
    for radius in [-1.0, 0] {
      let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: radius,
        duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
        pointAt: { $0 == 0 ? .init(-0.5, 0.023, 0.037) : nil }, targetAt: { _ in .init() })
      guard case .refused = query else { Issue.record("Absent actual curve/radius did not refuse"); return }
    }
  }

  @Test func nativeCandidateBracketsKeepEarliestSelectionIndependentOfArrayOrder() throws {
    let hull = try PreparedHull(mesh: box())
    var hits: [NativeSphereCurveContact] = []
    for centre in [0.3, 0.7] {
      let query = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
        duration: 0.1, pointSpeed: 10, targetPointSpeed: 0,
        pointAt: { .init(10 * $0, 0.023, 0.037) },
        targetAt: { _ in .init(position: .init(centre, 0, 0)) })
      guard case .contact(let hit, _) = query else { Issue.record("Actual candidate lacks native witness"); return }
      hits.append(hit)
    }
    for values in [hits, Array(hits.reversed())] {
      let index = try #require(CurrentNewtContactChronology.earliest(values.map {
        .init(lower: $0.lowerTime, upper: $0.upperTime)
      }))
      #expect(values[index].upperTime == hits[0].upperTime)
    }
  }

  private func box(_ h: Vector3 = .init(0.1, 0.1, 0.1)) -> Mesh {
    .init(vertices: [.init(-h.x, -h.y, -h.z), .init(h.x, -h.y, -h.z), .init(h.x, h.y, -h.z), .init(-h.x, h.y, -h.z),
      .init(-h.x, -h.y, h.z), .init(h.x, -h.y, h.z), .init(h.x, h.y, h.z), .init(-h.x, h.y, h.z)],
      faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]])
  }
}
