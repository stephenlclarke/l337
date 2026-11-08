import Foundation
import Testing

@testable import L337Core

/// Pure curve/query units. These construct no actor, kit, stock or impact rights.
struct CurrentNewtRelativeQueryTests {
  @Test func actualCareerCoastJumpsAreCoveredInBothSolidBroadPhaseRoles() throws {
    for start in [86_400.0, 604_800.0] {
      let coast = try careerCoast(start: start)
      let collider = try coastCollider(coast, mesh: box())
      let q = start.ulp
      let a = q * (0.5 - 1.0 / 16), b = q * (0.5 + 1.0 / 16)
      let left = try #require(collider.poseAt(a)), right = try #require(collider.poseAt(b))
      let jump = (right.position - left.position).length
      #expect(jump > 60 * (b - a))
      let adapter = try #require(CurrentNewtQueryFrame.clockSamplingTimeError(
        start: start, end: coast.end, origins: [start]))
      let error = try #require(collider.samplingPositionError(adapterTimeError: adapter))
      #expect(jump <= 60 * (b - a) + 2 * error)
      let separation = jump * 0.25
      let numerical = 128 * Double.ulpOfOne
      // Common physical velocity can make relative travel zero. The actual
      // absolute-clock jump still forbids the old broad-phase early clear.
      #expect(HullSweepSafety.currentNewtCurvePairClearanceProven(separation: separation,
        travel: 0, numerical: numerical, sourceSamplingError: 0, targetSamplingError: 0))
      for targetRole in [false, true] {
        #expect(!HullSweepSafety.currentNewtCurvePairClearanceProven(separation: separation,
          travel: 0, numerical: numerical, sourceSamplingError: targetRole ? 0 : error,
          targetSamplingError: targetRole ? error : 0))
      }
    }
  }

  @Test func actualSolidCoastCallbackCannotClearASkippedAdjacentClockCrossing() throws {
    for start in [86_400.0, 604_800.0] {
      let coast = try careerCoast(start: start)
      let first = try #require(coast.state(at: start)), next = try #require(coast.state(at: start.nextUp))
      let jump = next.pose.position.x - first.pose.position.x
      try #require(jump > 0)
      let middle = first.pose.position + Vector3(jump * 0.875, 0, 0)
      let mesh = box(halfExtents: .init(jump / 32, 10, 10))
      let collider = try coastCollider(coast, mesh: mesh)
      let window = try #require(NativeCurveClockWindow(start: start, end: start.nextUp))
      let adapter = try #require(CurrentNewtQueryFrame.clockSamplingTimeError(
        start: start, end: window.end, origins: [start]))
      let error = try #require(collider.samplingPositionError(adapterTimeError: adapter))
      let speed = try #require(collider.pointSpeedRelativeTo(.init(0, 0, 0)))
      func actual(_ elapsed: Double) -> ShipPose? {
        guard let value = collider.pose(at: elapsed, in: window, rootClock: start) else { return nil }
        return .init(position: value.position - middle, orientation: value.orientation)
      }
      for targetRole in [false, true] {
        let result = HullSweepSafety.firstCurrentNewtCurveContact(source: collider.hull, target: collider.hull,
          duration: window.duration, sourcePointSpeed: targetRole ? 0 : speed,
          targetPointSpeed: targetRole ? speed : 0,
          sourceAt: { targetRole ? ShipPose() : actual($0) },
          targetAt: { targetRole ? actual($0) : ShipPose() },
          sourceSamplingError: targetRole ? 0 : error, targetSamplingError: targetRole ? error : 0,
          clockWindow: window)
        guard case .refused(.unproven) = result else {
          Issue.record("Actual solid coast clock jump supplied an unsupported clear/contact"); return
        }
        // At a week the initial gap exceeds the unchanged one-nanometre
        // initial guard. Omitting the clock envelope reproduces the false clear.
        if start == 604_800 {
          let missingBound = HullSweepSafety.firstCurrentNewtCurveContact(
            source: collider.hull, target: collider.hull, duration: window.duration,
            sourcePointSpeed: targetRole ? 0 : speed, targetPointSpeed: targetRole ? speed : 0,
            sourceAt: { targetRole ? ShipPose() : actual($0) },
            targetAt: { targetRole ? actual($0) : ShipPose() })
          guard case .clear = missingBound else {
            Issue.record("Missing-envelope control did not reproduce the solid false clear"); return
          }
        }
      }
    }
  }

  @Test func actualCareerSolidWitnessRetainsBothWorldPosesAtTheSharedPhysicalFrontier() throws {
    for start in [86_400.0, 604_800.0] {
      let coast = try careerCoast(start: start, angularVelocity: .init(0.001, 0.002, 0.003))
      let collider = try coastCollider(coast, mesh: box())
      let window = try #require(NativeCurveClockWindow(start: start, end: start + 0.01))
      let adapter = try #require(CurrentNewtQueryFrame.clockSamplingTimeError(
        start: start, end: window.end, origins: [start]))
      let error = try #require(collider.samplingPositionError(adapterTimeError: adapter))
      let target = ShipPose(position: .init(1.23, 0, 0))
      let speed = try #require(collider.pointSpeedRelativeTo(.init(0, 0, 0)))
      let result = HullSweepSafety.firstCurrentNewtCurveContact(source: collider.hull, target: collider.hull,
        duration: window.duration, sourcePointSpeed: speed, targetPointSpeed: 0,
        sourceAt: { collider.pose(at: $0, in: window, rootClock: start) }, targetAt: { _ in target },
        sourceSamplingError: error, clockWindow: window)
      guard case .contact(let contact) = result else {
        Issue.record("Actual solid coast crossing lost its native world witness"); return
      }
      let upper = try #require(contact.upperPhysicalTime), lower = try #require(contact.lowerPhysicalTime)
      let actual = try #require(coast.state(at: upper))
      #expect(lower >= start && lower <= upper && upper > start && upper <= window.end)
      #expect(contact.upperTime == upper - start && start + contact.upperTime == upper)
      #expect(contact.sourcePose == actual.pose && contact.targetPose == target)
      #expect(contact.point.finite && contact.normal.finite)
      let exhausted = HullSweepSafety.firstCurrentNewtCurveContact(source: collider.hull, target: collider.hull,
        duration: window.duration, sourcePointSpeed: speed, targetPointSpeed: 0,
        sourceAt: { collider.pose(at: $0, in: window, rootClock: start) }, targetAt: { _ in target },
        sourceSamplingError: error, clockWindow: window,
        budget: .init(distanceQueries: 1, triangleTests: 500_000, nodeVisits: 500_000, subdivisionDepth: 12))
      guard case .refused(.workBudgetExceeded) = exhausted else {
        Issue.record("Solid clock conditioning escaped the actual work budget"); return
      }
    }
  }

  @Test func actualPostImpactSuffixSamplesItsCanonicalRootClockRatherThanAnAliasedOffsetSum() throws {
    let root = 86_400.0
    let coast = try careerCoast(start: root)
    let collider = try coastCollider(coast, mesh: box())
    let now = root + 0.03125
    let window = try #require(NativeCurveClockWindow(start: now, end: now + now.ulp * 8))
    let nominal = now.ulp * (0.5 + 1e-7)
    let old = try #require(collider.poseAt((now - root) + nominal))
    let actual = try #require(coast.state(at: now + nominal))
    let canonical = try #require(collider.pose(at: nominal, in: window, rootClock: root))
    #expect(old != actual.pose && canonical == actual.pose)
    let frontier = try #require(window.frontier(at: nominal))
    #expect(frontier.physical > now && frontier.physical - now == frontier.elapsed)
    #expect(collider.pose(at: frontier.elapsed, in: window, rootClock: root) == canonical)
    #expect(window.frontier(at: now.ulp * 0.25) == nil)
    #expect(collider.pose(at: now.ulp * 0.25, in: window, rootClock: root) == coast.state(at: now)?.pose)
    #expect(collider.pose(at: window.duration.nextUp, in: window, rootClock: root) == nil)
  }

  @Test func realLocalElapsedMetadataStaysZeroAndCoMovingSolidClearanceRemainsProvable() throws {
    for start in [86_400.0, 604_800.0] {
      let coast = try careerCoast(start: start)
      let source = try coastCollider(coast, mesh: box())
      let window = try #require(NativeCurveClockWindow(start: start, end: start + 0.01))
      let seed = HullSceneMotion(start: .init(position: .init(1.23, 0, 0)),
        end: .init(position: .init(1.23 + 60 * window.duration, 0, 0)),
        initialVelocity: .init(60, 0, 0), acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: window.duration, playerRadius: 0)
      let speed = try #require(CurrentNewtQueryFrame.pointSpeedBound(motion: seed,
        localExtent: source.hull.radius, relativeTo: .init(0, 0, 0)))
      let target = CurrentNewtNativeCollider(actor: nil, component: "local-kernel-unit", newt: false,
        debris: false, asteroid: false, station: false, hull: source.hull, mesh: source.mesh,
        centre: .init(0, 0, 0), radius: source.radius, maximumPointSpeed: speed, clockSamplingTimeError: 0,
        referenceVelocity: seed.initialVelocity,
        pointSpeedRelativeTo: { CurrentNewtQueryFrame.pointSpeedBound(motion: seed,
          localExtent: source.hull.radius, relativeTo: $0) },
        poseAt: { HullSweepSafety.shipPose(seed, at: $0) })
      #expect(target.clockSamplingTimeError == 0 && target.samplingPositionError(adapterTimeError: 0) == 0)
      let adapter = try #require(CurrentNewtQueryFrame.clockSamplingTimeError(
        start: start, end: window.end, origins: [start]))
      let sourceError = try #require(source.samplingPositionError(adapterTimeError: adapter))
      let targetError = try #require(target.samplingPositionError(adapterTimeError: adapter))
      let aSpeed = try #require(source.pointSpeedRelativeTo(.init(60, 0, 0)))
      let bSpeed = try #require(target.pointSpeedRelativeTo(.init(60, 0, 0)))
      let frame = try #require(CurrentNewtQueryFrame(origin: .init(1, 0, 0), velocity: .init(60, 0, 0)))
      let result = HullSweepSafety.firstCurrentNewtCurveContact(source: source.hull, target: target.hull,
        duration: window.duration, sourcePointSpeed: aSpeed, targetPointSpeed: bSpeed,
        sourceAt: { source.pose(at: $0, in: window, rootClock: start) },
        targetAt: { target.pose(at: $0, in: window, rootClock: start) }, queryFrame: frame,
        sourceSamplingError: sourceError, targetSamplingError: targetError, clockWindow: window)
      guard case .clear = result else {
        Issue.record("Derived clock errors lost genuine three-centimetre solid clearance"); return
      }
    }
  }

  @Test func denseDerivativeIncludesInteriorExtremaAndIsGalileanInvariant() throws {
    let slopes = [[79.0, 0, 0], [81, 0, 0], [81, 0, 0], [79, 0, 0]]
    let reference = Vector3(80, 0, 0)
    let bound = try #require(CurrentNewtQueryFrame.denseDerivativeBound(
      slopes: slopes, at: 0, relativeTo: reference))
    #expect(bound >= 2 && bound < 3.000001)
    let boost = Vector3(-1200, 600, 50)
    let shifted = slopes.map { [$0[0] + boost.x, $0[1] + boost.y, $0[2] + boost.z] }
    let other = try #require(CurrentNewtQueryFrame.denseDerivativeBound(
      slopes: shifted, at: 0, relativeTo: reference + boost))
    #expect(abs(bound - other) < 1e-8)
    for step in 0...100 {
      let u = Double(step) / 100
      let actual = abs(-1 + 12 * u - 12 * u * u)
      #expect(actual <= bound)
    }
    // Subtracting speed magnitudes loses transverse relative motion.
    let transverse = try #require(CurrentNewtQueryFrame.denseDerivativeBound(
      slopes: Array(repeating: [80, 1, 0], count: 4), at: 0, relativeTo: reference))
    #expect(transverse >= 1)
  }

  @Test func denseBasisValueAndDerivativeBoundsCoverActualPolynomialColumns() throws {
    let initial = Vector3(1, 0, 0)
    let slopes = [[0.0, 0.03, 0.02], [0.001, 0.04, 0.01],
      [-0.001, 0.02, 0.03], [0, 0.035, 0.025]]
    let duration = 0.001
    let value = try #require(CurrentNewtQueryFrame.denseValueBound(initial: initial,
      slopes: slopes, at: 0, duration: duration))
    let derivative = try #require(CurrentNewtQueryFrame.denseDerivativeBound(slopes: slopes, at: 0))
    let k = slopes.map { Vector3($0[0], $0[1], $0[2]) }
    for step in 0...100 {
      let u = Double(step) / 100
      let a = k[0]
      let b = k[0] * -1.5 + k[1] + k[2] - k[3] * 0.5
      let c = (k[0] - k[1] - k[2] + k[3]) * (2.0 / 3)
      let actual = initial + (a * u + b * (u * u) + c * (u * u * u)) * duration
      let rate = a + b * (2 * u) + c * (3 * u * u)
      #expect(actual.length <= value && rate.length <= derivative)
    }
  }

  @Test func fullTensorCoastBoundCoversPointsAndCommonVelocityTranslation() throws {
    let mass = CurrentNewtKitReceipt.MassProperties(massKilograms: 100,
      centreOfMassMetres: .init(0.2, -0.1, 0.05),
      inertiaKgM2: [2, 0.1, 0.05, 0.1, 3, 0.08, 0.05, 0.08, 4])
    let initial = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(10, -20, 30)),
      velocity: .init(3, -2, 1), angularVelocity: .init(0.02, 0.03, 0.01))
    let boost = Vector3(80, 7, -3)
    let shifted = CurrentNewtKitReceipt.BodyState(pose: initial.pose,
      velocity: initial.velocity + boost, angularVelocity: initial.angularVelocity)
    let a = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: 0.1, maximumAngularSpeed: 0.05))
    let b = try #require(CurrentNewtRigidCoast(initial: shifted, mass: mass,
      duration: 0.1, maximumAngularSpeed: 0.05))
    let bound = try #require(a.pointSpeedBound(localExtent: 2, relativeTo: initial.velocity))
    let shiftedBound = try #require(b.pointSpeedBound(localExtent: 2, relativeTo: shifted.velocity))
    #expect(abs(bound - shiftedBound) < 1e-8)
    for step in 0...20 {
      let t = Double(step) / 200
      let sa = try #require(a.state(at: t)), sb = try #require(b.state(at: t))
      #expect((sb.pose.position - sa.pose.position - boost * t).length < 1e-8)
      for local in [Vector3(2, 0, 0), .init(0, -2, 0), .init(0, 0, 2)] {
        let velocity = sa.velocity + sa.angularVelocity.cross(sa.pose.orientation.apply(local))
        #expect((velocity - initial.velocity).length <= bound)
      }
    }
  }

  @Test func actualAcceleratingRotatingOrdinaryCurveKeepsItsPointBound() throws {
    let seed = HullSceneMotion(start: .init(), end: .init(), initialVelocity: .init(80, 0, 0),
      acceleration: .init(-2, 1, 0), worldAngularVelocity: .init(0.02, 0.03, 0.01),
      duration: 0.1, playerRadius: 2)
    let bound = try #require(CurrentNewtQueryFrame.pointSpeedBound(motion: seed,
      localExtent: 2, relativeTo: .init(80, 0, 0)))
    for step in 0...100 {
      let t = Double(step) / 1000
      let pose = HullSweepSafety.shipPose(seed, at: t)
      let rate = seed.initialVelocity + seed.acceleration * t
        + seed.worldAngularVelocity.cross(pose.orientation.apply(.init(2, 0, 0)))
      #expect((rate - Vector3(80, 0, 0)).length <= bound)
    }
  }

  @Test func sharedEightyMetreVelocityKeepsRealThreeCentimetreClearanceWithinStandardBudget() throws {
    let hull = try PreparedHull(mesh: box())
    for speed in [0.0, 80, -1200] {
      let frame = try #require(CurrentNewtQueryFrame(origin: .init(0, 0, 0), velocity: .init(speed, 0, 0)))
      let result = HullSweepSafety.firstCurrentNewtCurveContact(source: hull, target: hull,
        duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 0,
        sourceAt: { .init(position: .init(speed * $0, 0, 0)) },
        targetAt: { .init(position: .init(0.23 + speed * $0, 0, 0)) }, queryFrame: frame)
      guard case .clear = result else { Issue.record("Common velocity exhausted unchanged query budget"); return }
    }
    let old = HullSweepSafety.firstCurrentNewtCurveContact(source: hull, target: hull,
      duration: 0.1, sourcePointSpeed: 80, targetPointSpeed: 80,
      sourceAt: { .init(position: .init(80 * $0, 0, 0)) },
      targetAt: { .init(position: .init(0.23 + 80 * $0, 0, 0)) })
    guard case .refused = old else { Issue.record("Control did not reproduce absolute-speed exhaustion"); return }
  }

  @Test func genuineNativeContactWitnessReturnsToWorldAtItsOwnUpperTime() throws {
    let hull = try PreparedHull(mesh: box())
    var contacts: [NativeHullContact] = []
    for speed in [0.0, 80] {
      let frame = try #require(CurrentNewtQueryFrame(origin: .init(0, 0, 0), velocity: .init(speed, 0, 0)))
      let result = HullSweepSafety.firstCurrentNewtCurveContact(source: hull, target: hull,
        duration: 0.1, sourcePointSpeed: 0, targetPointSpeed: 1,
        sourceAt: { .init(position: .init(speed * $0, 0, 0)) },
        targetAt: { .init(position: .init(0.23 + (speed - 1) * $0, 0, 0)) }, queryFrame: frame)
      guard case .contact(let contact) = result else { Issue.record("True curve crossing has no native witness"); return }
      contacts.append(contact)
    }
    #expect(abs(contacts[0].upperTime - contacts[1].upperTime) < 1e-8)
    #expect((contacts[1].point - Vector3(80, 0, 0) * contacts[1].upperTime - contacts[0].point).length < 1e-6)
    #expect((contacts[0].normal - contacts[1].normal).length < 1e-8)
  }

  @Test func actualFullTensorContinuationUsesItsPostImpactReferenceBound() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bodyCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate)
    let actor = try #require(body.physical?.identity)
    let partsCandidate = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(partsCandidate)
    let old = game.currentNewtBodyState(body)
    let state = CurrentNewtKitReceipt.BodyState(pose: old.pose, velocity: .init(80, 0, 0),
      angularVelocity: .init(0.002, 0.003, 0.001))
    let mass = try #require(CurrentNewtImpactContinuation.mass(of: parts, in: state.pose))
    let continuation = try #require(CurrentNewtImpactContinuation(actor: actor,
      start: 7, end: 7.1, initial: state, mass: .tensor(mass), components: parts,
      maximumAngularSpeed: 0.05))
    let extent = parts.map { ($0.pose.position - state.pose.position).length
      + ($0.collisionMesh?.vertices.map(\.length).max() ?? 0) }.max() ?? 0
    let bound = try #require(continuation.pointSpeedBound(extent: extent, relativeTo: state.velocity))
    for step in 0...10 {
      let time = 7 + Double(step) / 100
      for original in parts {
        guard let mesh = original.collisionMesh else { continue }
        let part = try #require(continuation.part(original.id, at: time))
        for vertex in mesh.vertices {
          let speed = part.velocity + part.angularVelocity.cross(part.pose.orientation.apply(vertex))
          #expect((speed - state.velocity).length <= bound)
        }
      }
    }
  }

  @Test func oneSharedEpochRoundTripsAndInvalidQueryMathRefuses() throws {
    let frame = try #require(CurrentNewtQueryFrame(origin: .init(10, -20, 30),
      velocity: .init(80, 7, -3), timeOrigin: 100))
    let world = ShipPose(position: .init(13.1, -19.7, 29.8))
    let query = try #require(frame.pose(world, at: 100.0375))
    let back = try #require(frame.worldPoint(query.position, at: 100.0375))
    #expect((back - world.position).length < 1e-10 && query.orientation == world.orientation)
    #expect(CurrentNewtQueryFrame(origin: .init(0, 0, 0), velocity: .init(.nan, 0, 0)) == nil)
    #expect(CurrentNewtQueryFrame.denseDerivativeBound(slopes: [[0, 0, 0]], at: 0) == nil)
    #expect(CurrentNewtQueryFrame.denseValueBound(initial: .init(0, 0, 0),
      slopes: Array(repeating: [0, 0, 0], count: 4), at: 0, duration: 0) == nil)
  }

  /// Declared mechanics unit, not an aged Game or a natural source grant. Use
  /// the real born kit's complete component masses and the actual full-tensor
  /// continuation callback. Only its unit coordinate frame/velocity are chosen.
  private func careerCoast(start: Double, angularVelocity: Vector3 = .init(0, 0, 0)) throws -> CurrentNewtImpactContinuation {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bodyCandidate2 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate2)
    let actor = try #require(body.physical?.identity)
    let partsCandidate2 = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(partsCandidate2)
    let original = game.currentNewtBodyState(body)
    let initial = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(1, 0, 0)),
      velocity: .init(60, 0, 0), angularVelocity: angularVelocity)
    let local = try parts.map { part -> CurrentNewtKitComponent in
      try #require(part.pose.orientation == original.pose.orientation)
      return .init(id: part.id, collisionMesh: part.collisionMesh, displayMesh: part.displayMesh,
        pose: .init(position: initial.pose.systemPoint(original.pose.shipPoint(part.pose.position)),
          orientation: initial.pose.orientation), massProperties: part.massProperties,
        velocity: initial.velocity + initial.angularVelocity.cross(
          initial.pose.systemPoint(original.pose.shipPoint(part.pose.position)) - initial.pose.position),
        angularVelocity: initial.angularVelocity)
    }
    let mass = try #require(CurrentNewtImpactContinuation.mass(of: local, in: initial.pose))
    return try #require(CurrentNewtImpactContinuation(actor: actor, start: start, end: start + 0.1,
      initial: initial, mass: .tensor(mass), components: local, maximumAngularSpeed: 0.05))
  }

  /// Plain geometry input around the actual continuation callback, never a
  /// private native scene/actor/contact factory or clock capability.
  private func coastCollider(_ coast: CurrentNewtImpactContinuation, mesh: Mesh) throws -> CurrentNewtNativeCollider {
    let hull = try PreparedHull(mesh: mesh)
    let speed = try #require(coast.pointSpeedBound(extent: hull.radius))
    let seconds = try #require(CurrentNewtQueryFrame.clockSamplingTimeError(
      start: coast.start, end: coast.end, origins: [coast.start]))
    return .init(actor: coast.actor, component: "coast-kernel-unit", newt: true,
      debris: false, asteroid: false, station: false, hull: hull, mesh: mesh,
      centre: .init(0, 0, 0), radius: hull.radius, maximumPointSpeed: speed,
      clockSamplingTimeError: seconds, referenceVelocity: coast.initial.velocity,
      pointSpeedRelativeTo: { coast.pointSpeedBound(extent: hull.radius, relativeTo: $0) },
      poseAt: { coast.state(at: coast.start + $0)?.pose })
  }

  private func box(halfExtents h: Vector3) -> Mesh {
    .init(vertices: [.init(-h.x, -h.y, -h.z), .init(h.x, -h.y, -h.z), .init(h.x, h.y, -h.z), .init(-h.x, h.y, -h.z),
      .init(-h.x, -h.y, h.z), .init(h.x, -h.y, h.z), .init(h.x, h.y, h.z), .init(-h.x, h.y, h.z)],
      faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]])
  }

  private func box() -> Mesh {
    let r = 0.1
    return .init(vertices: [.init(-r, -r, -r), .init(r, -r, -r), .init(r, r, -r), .init(-r, r, -r),
      .init(-r, -r, r), .init(r, -r, r), .init(r, r, r), .init(-r, r, r)],
      faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]])
  }
}
