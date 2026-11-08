import Foundation

/// Conditional geometry evidence only. Actual native source/world binding and
/// receipt construction remain private to G1's live owner.
enum NativeC01InquiryCurveGeometry {
  typealias Solver = NativeC01InquiryCompoundValidatedCurve
  typealias I = Solver.Interval
  typealias B = Solver.VectorBox
  typealias Material = Solver.MaterialBounds

  enum Failure: Error, Sendable {
    case invalidInput, incompleteWorld, initialSolidUnproven, workBudgetExceeded
    case unproven, ambiguousContact, refinementUnavailable
  }

  struct Work: Sendable {
    let budget: HullSweepBudget
    var queries = 0
    var triangles = 0
    var nodes = 0
    init(_ budget: HullSweepBudget) throws {
      guard budget.distanceQueries > 0, budget.triangleTests > 0, budget.nodeVisits > 0,
        (0...20).contains(budget.subdivisionDepth) else { throw Failure.invalidInput }
      self.budget = budget
    }
    mutating func query() throws {
      guard queries < budget.distanceQueries else { throw Failure.workBudgetExceeded }
      queries += 1
    }
    mutating func triangle() throws {
      guard triangles < budget.triangleTests else { throw Failure.workBudgetExceeded }
      triangles += 1
    }
    /// Conservative support-record debit from the EXISTING triangle budget.
    /// Called before readonly metadata traversal/allocation/comparison; a later
    /// mismatch cannot erase this reservation or fund a free retry.
    mutating func reservePreparedMetadataRecords(_ count: Int) throws {
      guard count >= 0, count <= budget.triangleTests - triangles else { throw Failure.workBudgetExceeded }
      triangles += count
    }
    mutating func node() throws {
      guard nodes < budget.nodeVisits else { throw Failure.workBudgetExceeded }
      nodes += 1
    }
  }

  struct Triangle: Sendable {
    let vertices: [Vector3]
    let sourceFace: Int
    let unresolvedSupport: Bool
  }
  struct Component: Sendable {
    let triangles: [Int]
    let representative: Vector3
    let closed: Bool
    let hasResolvedSurface: Bool
  }
  /// Created from actual PreparedHull metadata by the reserved native bridge.
  /// Its values are geometric inputs, never a live registration capability.
  struct Prepared: Sendable {
    let nativeID: UUID
    let hull: PreparedHull
    let sourceVertices: [Vector3]
    let sourceFaces: [[Int]]
    let triangles: [Triangle]
    let components: [Component]
  }
  /// Shared readonly facts for the existing curve initial state and the
  /// instantaneous state seam. Math DATA, never actual native currentness.
  struct MaterialState: Sendable {
    let state: Solver.State
    let prepared: Prepared
    let referencePose: ShipPose
    let materialView: NativeC01InquiryCompoundMaterialAtlas.View?
  }
  /// Birth/material point query needs no invented future interval. The actual
  /// G1 registry retains physicalTime separately and binds this SAME View.
  struct InstantaneousSource: Sendable {
    let state: Solver.State
    let prepared: Prepared
    let referencePose: ShipPose
    let materialView: NativeC01InquiryCompoundMaterialAtlas.View

    var materialState: MaterialState {
      .init(state: state, prepared: prepared, referencePose: referencePose, materialView: materialView)
    }
  }
  /// Mathematical motion inputs only. A coupled trajectory is never replaced
  /// by a torque-free integration from its initial or projected state.
  enum Motion: Sendable {
    case torqueFree(Solver.Curve)
    case constrained(Solver.ConstrainedComponentMotion)

    var initial: Solver.State {
      switch self { case .torqueFree(let curve): return curve.initial
      case .constrained(let motion): return motion.initial }
    }
    var endpoint: Solver.State {
      switch self { case .torqueFree(let curve): return curve.endpoint
      case .constrained(let motion): return motion.endpoint }
    }
    var duration: Double {
      switch self { case .torqueFree(let curve): return curve.duration
      case .constrained(let motion): return motion.duration }
    }
    /// DATA only. Handles of one constrained group share one already owned
    /// construction; this per-input report must not debit that group again.
    var inputWork: Solver.Work {
      switch self { case .torqueFree(let curve): return curve.work
      case .constrained(let motion): return motion.inputWork }
    }
    var requiresODEPreparation: Bool {
      switch self { case .torqueFree: return true; case .constrained: return false }
    }
  }
  struct Source: Sendable {
    let motion: Motion
    let prepared: Prepared
    /// Shadow pose of the prepared GEOMETRY frame. With retained material
    /// lineage this is the ancestral material frame, not a new rounded COM pose.
    let referencePose: ShipPose
    let materialView: NativeC01InquiryCompoundMaterialAtlas.View?

    var materialState: MaterialState {
      .init(state: motion.initial, prepared: prepared, referencePose: referencePose, materialView: materialView)
    }

    init(curve: Solver.Curve, prepared: Prepared, referencePose: ShipPose,
      materialView: NativeC01InquiryCompoundMaterialAtlas.View? = nil)
    {
      motion = .torqueFree(curve); self.prepared = prepared; self.referencePose = referencePose
      self.materialView = materialView
    }
    init(constrained: Solver.ConstrainedComponentMotion, prepared: Prepared, referencePose: ShipPose) {
      motion = .constrained(constrained); self.prepared = prepared; self.referencePose = referencePose
      materialView = constrained.view
    }
  }
  enum Purpose: Sendable, Equatable { case physicalSurface, separationOnly }
  enum ForeignMotion: Sendable {
    case ordinary(HullSceneMotion)
    case compound(Source)
  }
  struct Foreign: Sendable {
    let instance: UUID
    let prepared: Prepared
    let motion: ForeignMotion
    let clearance: Double
    /// Genuine provider binding is G1's; policy volumes cannot cause impacts.
    let purpose: Purpose

    init(instance: UUID, prepared: Prepared, motion: HullSceneMotion,
      clearance: Double, purpose: Purpose)
    {
      self.instance = instance; self.prepared = prepared; self.motion = .ordinary(motion)
      self.clearance = clearance; self.purpose = purpose
    }
    init(instance: UUID, compound: Source, clearance: Double, purpose: Purpose) {
      self.instance = instance; prepared = compound.prepared; motion = .compound(compound)
      self.clearance = clearance; self.purpose = purpose
    }
  }
  struct ForeignInputCurveWork: Sendable {
    let foreignIndex: Int
    let instance: UUID
    let work: Solver.Work
  }
  struct Contact: Sendable {
    let foreignIndex: Int
    let sourceTriangle: Int
    let foreignTriangle: Int
    /// Input face index of the common exterior mesh.
    let sourceFace: Int
    /// Original descriptor face index within the actual source part.
    let partSourceFace: Int
    let part: NativeC01InquiryFixtureGeometry.Part
    let lowerTime: Double
    let upperTime: Double
    let point: B
    let normalIntoCompound: B
    let lowerState: Solver.State
    /// Actual retained foreign lower-boundary enclosure for compound inputs.
    /// Native event-time selection/impulse/continuation still require G1 proof.
    let foreignLowerState: Solver.State?
  }
  struct Report: Sendable {
    let queries: Int
    let triangles: Int
    let nodes: Int
    let odeAttempts: Int
    let odeCells: Int
    /// Actual supplied curve producer work, already owned/debited by caller.
    /// The ode fields above are query-refinement charges, not this input cost.
    let inputCurveWork: Solver.Work
    /// Supplied foreign preparations are caller-debited once, separate from
    /// shared query refinement. Ordinary inputs have no entry in this list.
    /// Nil means the query refused before its charged input inspection.
    let foreignInputCurveWork: [ForeignInputCurveWork]?

    init(queries: Int, triangles: Int, nodes: Int, odeAttempts: Int, odeCells: Int,
      inputCurveWork: Solver.Work, foreignInputCurveWork: [ForeignInputCurveWork]? = nil)
    {
      self.queries = queries; self.triangles = triangles; self.nodes = nodes
      self.odeAttempts = odeAttempts; self.odeCells = odeCells
      self.inputCurveWork = inputCurveWork; self.foreignInputCurveWork = foreignInputCurveWork
    }
  }
  enum Outcome: Sendable {
    case clear(Report)
    case contact(Contact, Report)
    case refused(Failure, Report)
  }

  static func dot(_ a: B, _ b: B) -> I { a.x * b.x + a.y * b.y + a.z * b.z }
  static func square(_ a: I) -> I {
    guard a.valid else { return .init(lower: .nan, upper: .nan) }
    let lo = a.lower <= 0 && a.upper >= 0 ? 0 : min(abs(a.lower), abs(a.upper))
    let hi = max(abs(a.lower), abs(a.upper))
    return .init(lower: max(0, (lo * lo).nextDown), upper: (hi * hi).nextUp)
  }
  static func length(_ a: B) -> I {
    let sum = square(a.x) + square(a.y) + square(a.z)
    guard sum.valid, sum.upper >= 0 else { return .init(lower: .nan, upper: .nan) }
    return .init(lower: max(0, max(0, sum.lower).squareRoot().nextDown),
      upper: sum.upper.squareRoot().nextUp)
  }
  static func weighted(_ vertices: [Material]) throws -> Material {
    guard vertices.count == 3 else { throw Failure.invalidInput }
    let position = vertices[0].position * I.point(0.5)
      + vertices[1].position * I.point(0.25) + vertices[2].position * I.point(0.25)
    let velocity = vertices[0].velocity * I.point(0.5)
      + vertices[1].velocity * I.point(0.25) + vertices[2].velocity * I.point(0.25)
    guard position.valid, velocity.valid else { throw Failure.unproven }
    return .init(position: position, velocity: velocity)
  }

  /// Native ordinary interpolation coefficients are represented inputs to this
  /// enclosure. Full sine/cosine ranges avoid an invented libm accuracy margin.
  /// Nearby spinning geometry can remain unproven; its triangles never disappear.
  static func ordinary(_ motion: HullSceneMotion, local: Vector3, from start: Double,
    through end: Double) throws -> Material
  {
    guard start.isFinite, end.isFinite, 0 <= start, start <= end, end <= motion.duration,
      motion.duration.isFinite, motion.duration > 0, motion.duration <= 0.1,
      local.finite, motion.start.position.finite, motion.start.orientation.validRotation,
      motion.initialVelocity.finite, motion.acceleration.finite, motion.worldAngularVelocity.finite
    else { throw Failure.invalidInput }
    let t = I(lower: start, upper: end)
    let basis = motion.start.orientation
    let original = B.point(basis.x) * I.point(local.x)
      + B.point(basis.y) * I.point(local.y) + B.point(basis.z) * I.point(local.z)
    let rate = motion.worldAngularVelocity.length
    guard rate.isFinite else { throw Failure.invalidInput }
    let lever: B
    let rotationalVelocity: B
    if rate > 1e-12 {
      // These are the SAME coefficients computed by native sweepPose. Their
      // represented values define its interpolation, not a new torque-free law.
      let axis = B.point(motion.worldAngularVelocity * (1 / rate))
      let cosine = start == 0 && end == 0 ? I.point(1) : I(lower: -1, upper: 1)
      let sine = start == 0 && end == 0 ? I.point(0) : I(lower: -1, upper: 1)
      // Match the native operation graph: rotate each basis column BEFORE
      // applying the local point. Real linear equivalence alone would drop the
      // different rounding errors from rotating an already-summed point.
      let columns = [B.point(basis.x), B.point(basis.y), B.point(basis.z)]
      let rotated = columns.map { column in
        column * cosine + axis.cross(column) * sine + axis * dot(axis, column) * (I.point(1) - cosine)
      }
      let derivatives = columns.map { column in
        (column * (-sine) + axis.cross(column) * cosine + axis * dot(axis, column) * sine) * I.point(rate)
      }
      lever = rotated[0] * I.point(local.x) + rotated[1] * I.point(local.y) + rotated[2] * I.point(local.z)
      rotationalVelocity = derivatives[0] * I.point(local.x)
        + derivatives[1] * I.point(local.y) + derivatives[2] * I.point(local.z)
    } else {
      lever = original
      rotationalVelocity = B.point(.init(0, 0, 0))
    }
    let centre = B.point(motion.start.position) + B.point(motion.initialVelocity) * t
      + B.point(motion.acceleration) * (I.point(0.5) * t * t)
    let position = centre + lever
    let velocity = B.point(motion.initialVelocity) + B.point(motion.acceleration) * t + rotationalVelocity
    guard position.valid, velocity.valid else { throw Failure.unproven }
    return .init(position: position, velocity: velocity)
  }

  /// A witness exists only when opposite strict endpoint signs force an actual
  /// crossing and the material point stays strictly inside the moving triangle.
  static func crossing(point: Material, firstPoint: Material, lastPoint: Material,
    face: [Material], firstFace: [Material], lastFace: [Material], pointIsCompound: Bool
  ) throws -> (point: B, normal: B)? {
    guard face.count == 3, firstFace.count == 3, lastFace.count == 3 else { throw Failure.invalidInput }
    func signed(_ point: B, _ face: [Material]) -> I {
      dot(point - face[0].position,
        (face[1].position - face[0].position).cross(face[2].position - face[0].position))
    }
    let first = signed(firstPoint.position, firstFace)
    let last = signed(lastPoint.position, lastFace)
    guard first.valid, last.valid else { return nil }
    let sign: Double
    if first.lower > 0 && last.upper < 0 { sign = 1 }
    else if first.upper < 0 && last.lower > 0 { sign = -1 }
    else { return nil }
    let e = face[1].position - face[0].position
    let f = face[2].position - face[0].position
    let d = point.position - face[0].position
    let ee = dot(e, e), ef = dot(e, f), ff = dot(f, f)
    let determinant = ee * ff - ef * ef
    guard determinant.valid, determinant.lower > 0 else { return nil }
    let u = (ff * dot(e, d) - ef * dot(f, d)) / determinant
    let v = (ee * dot(f, d) - ef * dot(e, d)) / determinant
    let sum = u + v
    guard u.valid, v.valid, sum.valid, u.lower > 0, v.lower > 0, sum.upper < 1 else { return nil }
    let normal = e.cross(f)
    let norm = length(normal)
    guard norm.valid, norm.lower > 0 else { return nil }
    let entryNormal = normal * (I.point(sign) / norm)
    let faceVelocity = face[0].velocity + (face[1].velocity - face[0].velocity) * u
      + (face[2].velocity - face[0].velocity) * v
    let closing = dot(point.velocity - faceVelocity, entryNormal)
    guard closing.valid, closing.upper < 0 else { return nil }
    return (point.position, entryNormal * I.point(pointIsCompound ? 1 : -1))
  }
}

extension NativeC01InquiryCurveGeometry {
  /// Initial source geometry DATA only. These cases do not classify an actual
  /// world pair, exempt a collision pair or establish current native ownership.
  enum InitialCutPairGeometryData: Sendable {
    case strictSeparation(lowerBound: Double)
    case sourceInterfaceTemplate(NativeC01InquiryCutContactSet.ClosedCutInterface)
  }
  struct InitialCutPairData: Sendable {
    let sourceComponent: Int
    let targetComponent: Int
    let sourceFacet: NativeC01InquiryCompoundMaterialAtlas.FacetID
    let targetFacet: NativeC01InquiryCompoundMaterialAtlas.FacetID
    let geometry: InitialCutPairGeometryData
  }
  /// Unissued private initial-only candidate DATA. No factory is added here:
  /// later Consumer/source/native-shadow/whole-solid/current-prefix checks are
  /// still required, and initial contact is not a full-interval contact proof.
  /// Existing query/Foreign/SAT/containment/crossing gates stay unchanged.
  final class InitialCutSolidCandidate: Sendable {
    let partition: NativeC01InquiryCutContactSet.ClosedCutPartition
    let owned: [InstantaneousSource]
    let foreignCount: Int
    let pairs: [InitialCutPairData]
    private init(partition: NativeC01InquiryCutContactSet.ClosedCutPartition,
      owned: [InstantaneousSource], foreignCount: Int, pairs: [InitialCutPairData]) {
      self.partition = partition; self.owned = owned; self.foreignCount = foreignCount; self.pairs = pairs
    }
  }
}
