import Foundation

/// Conditional whole-input geometry algorithm. G1 binds the actual complete
/// current/staged world and source interval before any native receipt/commit.
enum NativeC01InquiryCurveGeometryConsumer {
  typealias G = NativeC01InquiryCurveGeometry
  typealias Solver = NativeC01InquiryCompoundValidatedCurve

  private struct ODELedger {
    let budget: Solver.WorkBudget
    var attempts = 0
    var cells = 0
    mutating func prepare(_ state: Solver.State, duration: Double, maximumCell: Double,
      work: inout G.Work) throws -> Solver.Curve {
      let remaining = Solver.WorkBudget(cellAttempts: budget.cellAttempts - attempts,
        subdivisionDepth: budget.subdivisionDepth, retainedCells: budget.retainedCells - cells)
      guard remaining.cellAttempts > 0, remaining.retainedCells > 0 else { throw G.Failure.refinementUnavailable }
      // SAME query ledger pays actual fixed setup/endpoint construction. Cell
      // attempts/cells remain separate actual remaining ODE allowances.
      switch Solver.prepareMeasured(state, duration: duration, budget: remaining,
        maximumCellDuration: min(duration, maximumCell), work: &work) {
      case .prepared(let result, _):
        attempts += result.work.cellAttempts
        cells += result.work.retainedCells
        return result
      case .refused(let failure, let actual, _):
        attempts += actual.cellAttempts
        cells += actual.retainedCells
        if case .allowance = failure { throw G.Failure.workBudgetExceeded }
        // No retry, reset or fictitious full-allowance burn. Report the real
        // partial attempt/cell work even when geometry setup/storage failed.
        throw G.Failure.refinementUnavailable
      }
    }
  }
  private struct Segment {
    let lower: Solver.State
    let upper: Solver.State
    enum Bounds {
      case torqueFree(Solver.Curve)
      case constrained(Solver.ConstrainedMotionSlice)
    }
    let bounds: Bounds
    let width: Double

    init(lower: Solver.State, upper: Solver.State, curve: Solver.Curve, width: Double) {
      self.lower = lower; self.upper = upper; bounds = .torqueFree(curve); self.width = width
    }
    init(lower: Solver.State, upper: Solver.State, slice: Solver.ConstrainedMotionSlice, width: Double) {
      self.lower = lower; self.upper = upper; bounds = .constrained(slice); self.width = width
    }
  }
  private struct Candidate {
    let foreign: Int
    let sourceTriangle: Int
    let foreignTriangle: Int
    let source: [G.Material]
    let target: [G.Material]
  }

  static func query(source: NativeC01InquiryCurveGeometry.Source,
    foreign: [NativeC01InquiryCurveGeometry.Foreign], budget: HullSweepBudget,
    odeBudget: Solver.WorkBudget) -> NativeC01InquiryCurveGeometry.Outcome
  {
    // DATA only: actual native owner debits every supplied preparation before
    // passing remaining allowances. Nil reports refusal before input inspection.
    var foreignInputWork: [G.ForeignInputCurveWork]?
    var work: G.Work
    do { work = try .init(budget) }
    catch { return .refused(.invalidInput, .init(queries: 0, triangles: 0, nodes: 0, odeAttempts: 0, odeCells: 0,
        inputCurveWork: source.motion.inputWork, foreignInputCurveWork: foreignInputWork)) }
    var ode = ODELedger(budget: odeBudget)
    func report(_ work: G.Work, _ ode: ODELedger) -> G.Report {
      .init(queries: work.queries, triangles: work.triangles, nodes: work.nodes,
        odeAttempts: ode.attempts, odeCells: ode.cells, inputCurveWork: source.motion.inputWork, foreignInputCurveWork: foreignInputWork)
    }
    do {
      try work.reservePreparedMetadataRecords(foreign.count)
      try work.reservePreparedMetadataRecords(foreign.count)
      var requiresODEPreparation = source.motion.requiresODEPreparation
      foreignInputWork = foreign.enumerated().compactMap { index, entry in
        guard case .compound(let compound) = entry.motion else { return nil }
        requiresODEPreparation = requiresODEPreparation || compound.motion.requiresODEPreparation
        return .init(foreignIndex: index, instance: entry.instance, work: compound.motion.inputWork)
      }
      guard !foreign.isEmpty, Set(foreign.map(\.instance)).count == foreign.count else { throw G.Failure.incompleteWorld }
      guard odeBudget.cellAttempts >= 0, odeBudget.cellAttempts < Int.max,
        odeBudget.retainedCells >= 0, odeBudget.retainedCells < Int.max,
        !requiresODEPreparation || (odeBudget.cellAttempts > 0 && odeBudget.retainedCells > 0),
        odeBudget.subdivisionDepth >= 0, odeBudget.subdivisionDepth < Int.max,
        source.motion.duration > 0, source.motion.duration <= 0.1 else { throw G.Failure.invalidInput }
      try validate(source.prepared, work: &work)
      let representation = source.motion.initial.representation
      let sourceIndices = try compoundIndices(source, work: &work)
      var foreignIndices: [[[Int]]?] = []
      for entry in foreign {
        try validate(entry.prepared, work: &work)
        guard entry.clearance.isFinite, entry.clearance >= 0 else { throw G.Failure.invalidInput }
        let reference: ShipPose
        let otherDeviation: Double
        switch entry.motion {
        case .ordinary(let motion):
          try HullSweepSafety.c01ValidateOrdinaryMotion(motion, hull: entry.prepared.hull, budget: work.budget)
          guard motion.duration == source.motion.duration else { throw G.Failure.invalidInput }
          foreignIndices.append(nil)
          reference = motion.start
          otherDeviation = try ordinaryDeviation(entry.prepared, motion: motion, work: &work)
        case .compound(let compound):
          guard compound.motion.duration == source.motion.duration else { throw G.Failure.invalidInput }
          foreignIndices.append(try compoundIndices(compound, work: &work))
          reference = compound.referencePose
          otherDeviation = try sourceDeviation(compound, work: &work)
        }
        let separation = try HullSweepSafety.c01InitialSolidSeparation(source.prepared.hull,
          pose: source.referencePose, target: entry.prepared.hull, pose: reference, work: &work)
        let ownDeviation = try sourceDeviation(source, work: &work)
        let margin = G.I.point(ownDeviation) + G.I.point(otherDeviation) + G.I.point(entry.clearance)
        guard margin.valid, separation > margin.upper else { throw G.Failure.initialSolidUnproven }
      }
      struct Interval { let start: Double; let end: Double; let depth: Int }
      var pending = [Interval(start: 0, end: source.motion.duration, depth: 0)]
      while let interval = pending.popLast() {
        try work.query()
        let segment = try refined(source.motion, from: interval.start, through: interval.end,
          ode: &ode, work: &work)
        // Refine once per actual foreign input/node, never per triangle or
        // with a fresh budget. Every compound shares the source ODE ledger.
        var foreignSegments: [Segment?] = []
        for entry in foreign {
          switch entry.motion {
          case .ordinary: foreignSegments.append(nil)
          case .compound(let compound):
            foreignSegments.append(try refined(compound.motion,
              from: interval.start, through: interval.end, ode: &ode, work: &work))
          }
        }
        var candidates: [Candidate] = []
        for (foreignIndex, entry) in foreign.enumerated() {
          for (sourceIndex, indices) in sourceIndices.enumerated() {
            let left = try indices.map { index -> G.Material in
              guard let value = try materialBounds(source, segment: segment, vertex: index, work: &work)
              else { throw G.Failure.unproven }
              return value
            }
            for (targetIndex, triangle) in entry.prepared.triangles.enumerated() {
              let right: [G.Material]
              switch entry.motion {
              case .ordinary(let motion):
                right = try triangle.vertices.map {
                  try G.ordinary(motion, local: $0, from: interval.start, through: interval.end)
                }
              case .compound(let compound):
                guard let other = foreignSegments[foreignIndex],
                  let indices = foreignIndices[foreignIndex] else { throw G.Failure.invalidInput }
                right = try indices[targetIndex].map { index in
                  guard let value = try materialBounds(compound, segment: other, vertex: index, work: &work)
                  else { throw G.Failure.unproven }
                  return value
                }
              }
              let separation = try HullSweepSafety.c01IntervalTriangleSeparation(
                left.map(\.position), right.map(\.position), work: &work)
              if separation > entry.clearance { continue }
              candidates.append(.init(foreign: foreignIndex, sourceTriangle: sourceIndex,
                foreignTriangle: targetIndex, source: left, target: right))
            }
          }
        }
        if candidates.isEmpty { continue }
        if interval.depth < work.budget.subdivisionDepth {
          let middle = interval.start + (interval.end - interval.start) * 0.5
          guard middle > interval.start, middle < interval.end else { throw G.Failure.unproven }
          pending.append(.init(start: middle, end: interval.end, depth: interval.depth + 1))
          pending.append(.init(start: interval.start, end: middle, depth: interval.depth + 1))
          continue
        }
        guard candidates.count == 1, let candidate = candidates.first else { throw G.Failure.ambiguousContact }
        let entry = foreign[candidate.foreign]
        let sourceTriangle = source.prepared.triangles[candidate.sourceTriangle]
        let targetTriangle = entry.prepared.triangles[candidate.foreignTriangle]
        guard entry.purpose == .physicalSurface, entry.clearance == 0, !sourceTriangle.unresolvedSupport, !targetTriangle.unresolvedSupport
        else { throw G.Failure.unproven }
        try work.triangle()
        let firstSource = try sourceIndices[candidate.sourceTriangle].map { try materialBounds(source, state: segment.lower, vertex: $0) }
        let lastSource = try sourceIndices[candidate.sourceTriangle].map { try materialBounds(source, state: segment.upper, vertex: $0) }
        let firstTarget: [G.Material]
        let lastTarget: [G.Material]
        switch entry.motion {
        case .ordinary(let motion):
          firstTarget = try targetTriangle.vertices.map {
            try G.ordinary(motion, local: $0, from: interval.start, through: interval.start)
          }
          lastTarget = try targetTriangle.vertices.map {
            try G.ordinary(motion, local: $0, from: interval.end, through: interval.end)
          }
        case .compound(let compound):
          guard let other = foreignSegments[candidate.foreign],
            let indices = foreignIndices[candidate.foreign] else { throw G.Failure.invalidInput }
          firstTarget = try indices[candidate.foreignTriangle].map {
            try materialBounds(compound, state: other.lower, vertex: $0)
          }
          lastTarget = try indices[candidate.foreignTriangle].map {
            try materialBounds(compound, state: other.upper, vertex: $0)
          }
        }
        var witness = try G.crossing(point: G.weighted(candidate.source), firstPoint: G.weighted(firstSource),
          lastPoint: G.weighted(lastSource), face: candidate.target, firstFace: firstTarget,
          lastFace: lastTarget, pointIsCompound: true)
        if witness == nil {
          witness = try G.crossing(point: G.weighted(candidate.target), firstPoint: G.weighted(firstTarget),
            lastPoint: G.weighted(lastTarget), face: candidate.source, firstFace: firstSource,
            lastFace: lastSource, pointIsCompound: false)
        }
        guard let witness else { throw G.Failure.unproven }
        let face = sourceTriangle.sourceFace
        let contact = G.Contact(foreignIndex: candidate.foreign, sourceTriangle: candidate.sourceTriangle,
          foreignTriangle: candidate.foreignTriangle, sourceFace: face,
          partSourceFace: representation.faces[face].sourceFace,
          part: representation.faces[face].role, lowerTime: interval.start, upperTime: interval.end,
          point: witness.point, normalIntoCompound: witness.normal, lowerState: segment.lower,
          foreignLowerState: foreignSegments[candidate.foreign]?.lower)
        return .contact(contact, report(work, ode))
      }
      return .clear(report(work, ode))
    } catch let failure as G.Failure {
      return .refused(failure, report(work, ode))
    } catch { return .refused(.unproven, report(work, ode)) }
  }

  /// Requalify a genuinely updated remainder against ALL supplied foreign
  /// inputs. Prior work is deducted, never reset. Native event/state/world
  /// binding remains mandatory; a zero-gap/unproved initial frontier refuses.
  static func qualifyPreparedRemainder(source: G.Source, foreign: [G.Foreign],
    originalBudget: HullSweepBudget, originalODEBudget: Solver.WorkBudget,
    spent: G.Report) -> G.Outcome
  {
    guard spent.queries >= 0, spent.triangles >= 0, spent.nodes >= 0,
      spent.odeAttempts >= 0, spent.odeCells >= 0,
      spent.queries < originalBudget.distanceQueries, spent.triangles < originalBudget.triangleTests,
      spent.nodes < originalBudget.nodeVisits, spent.odeAttempts <= originalODEBudget.cellAttempts,
      spent.odeCells <= originalODEBudget.retainedCells
    else { return .refused(.workBudgetExceeded, spent) }
    let remaining = HullSweepBudget(distanceQueries: originalBudget.distanceQueries - spent.queries,
      triangleTests: originalBudget.triangleTests - spent.triangles, nodeVisits: originalBudget.nodeVisits - spent.nodes,
      subdivisionDepth: originalBudget.subdivisionDepth)
    let ode = Solver.WorkBudget(cellAttempts: originalODEBudget.cellAttempts - spent.odeAttempts,
      subdivisionDepth: originalODEBudget.subdivisionDepth, retainedCells: originalODEBudget.retainedCells - spent.odeCells)
    // Query performs its already charged input scan before deciding whether
    // any free-motion input needs new ODE work. Fully coupled inputs need none.
    let result = query(source: source, foreign: foreign, budget: remaining, odeBudget: ode)
    func cumulative(_ next: G.Report) -> G.Report {
      .init(queries: spent.queries + next.queries, triangles: spent.triangles + next.triangles,
        nodes: spent.nodes + next.nodes, odeAttempts: spent.odeAttempts + next.odeAttempts,
        odeCells: spent.odeCells + next.odeCells, inputCurveWork: next.inputCurveWork,
        foreignInputCurveWork: next.foreignInputCurveWork)
    }
    switch result {
    case .clear(let next): return .clear(cumulative(next))
    case .contact(let contact, let next): return .contact(contact, cumulative(next))
    case .refused(let failure, let next): return .refused(failure, cumulative(next))
    }
  }

  private static func refined(_ motion: G.Motion, from start: Double, through end: Double,
    ode: inout ODELedger, work: inout G.Work) throws -> Segment
  {
    switch motion {
    case .torqueFree(let curve):
      return try refined(curve.initial, from: start, through: end, ode: &ode, work: &work)
    case .constrained(let coupled):
      // Slice the actual shared q/C/P/L trajectory. Geometry bisection alone
      // does not create a tighter trajectory; unresolved ranges still refuse.
      let slice = try Solver.prepareConstrainedMotionSlice(coupled, from: start, through: end, work: &work)
      let lower = try Solver.constrainedMotionStateBounds(coupled, at: start, work: &work)
      let upper = try Solver.constrainedMotionStateBounds(coupled, at: end, work: &work)
      try work.reservePreparedMetadataRecords(1)
      return .init(lower: lower, upper: upper, slice: slice, width: end - start)
    }
  }

  private static func refined(_ initial: Solver.State, from start: Double, through end: Double,
    ode: inout ODELedger, work: inout G.Work) throws -> Segment
  {
    // Chronological dyadic bisection intervals are zero-based or satisfy the
    // Sterbenz domain. Never replace a real duration difference by an unchecked
    // rounded scalar when constructing the new mathematical segment.
    guard start >= 0, end > start, start == 0 || end <= 2 * start else { throw G.Failure.unproven }
    let width = end - start
    let lower: Solver.State
    if start == 0 { lower = initial }
    else { lower = try ode.prepare(initial, duration: start, maximumCell: width, work: &work).endpoint }
    let curve = try ode.prepare(lower, duration: width, maximumCell: width, work: &work)
    return .init(lower: lower, upper: curve.endpoint, curve: curve, width: width)
  }

  private static func validate(_ prepared: G.Prepared, work: inout G.Work) throws {
    guard prepared.hull.triangleCount > 0,
      prepared.triangles.count == prepared.hull.triangleCount,
      prepared.hull.triangleCount <= work.budget.triangleTests - work.triangles
    else { throw G.Failure.workBudgetExceeded }
    try HullSweepSafety.c01ReservePreparedGeometryMetadata(prepared.hull, work: &work)
    let actual = try HullSweepSafety.c01PreparedGeometry(prepared.hull)
    guard prepared.nativeID == actual.nativeID, !prepared.triangles.isEmpty,
      prepared.sourceVertices == actual.sourceVertices, prepared.sourceFaces == actual.sourceFaces,
      prepared.triangles.count == actual.triangles.count, prepared.components.count == actual.components.count
    else { throw G.Failure.invalidInput }
    for (a, b) in zip(prepared.triangles, actual.triangles) {
      guard a.vertices == b.vertices, a.sourceFace == b.sourceFace,
        a.unresolvedSupport == b.unresolvedSupport else { throw G.Failure.invalidInput }
    }
    for (a, b) in zip(prepared.components, actual.components) {
      guard a.triangles == b.triangles, a.representative == b.representative,
        a.closed == b.closed, a.hasResolvedSurface == b.hasResolvedSurface else { throw G.Failure.invalidInput }
    }
  }

  private static func materialMesh(_ source: G.Source) -> Mesh { materialMesh(source.materialState) }

  private static func materialMesh(_ source: G.MaterialState) -> Mesh {
    source.materialView?.meshInMaterialFrame ?? source.state.representation.meshAtCentreOfMass
  }

  // Shape/view binding was checked once under charged compoundIndices. These
  // point operations preserve that relation without rescanning a whole mesh
  // for every pair/vertex, and never convert retained states to scalar poses.
  private static func materialBounds(_ source: G.Source, segment: Segment, vertex: Int,
    work: inout G.Work) throws -> G.Material?
  {
    switch segment.bounds {
    case .torqueFree(let curve):
      return try materialBounds(source, curve: curve, vertex: vertex, from: 0, through: segment.width)
    case .constrained(let slice):
      // The constrained Source initializer binds the same immutable View.
      // compoundIndices checked the actual prepared mesh once before traversal.
      return try Solver.constrainedMotionMaterialBounds(slice, vertex: vertex, work: &work)
    }
  }

  private static func materialBounds(_ source: G.Source, curve: Solver.Curve,
    vertex: Int, from start: Double, through end: Double) throws -> G.Material?
  {
    if let view = source.materialView {
      return curve.materialBounds(localPoint: try view.pointRelativeToCurrentCOM(vertex: vertex),
        from: start, through: end)
    }
    return curve.materialBounds(vertex: vertex, from: start, through: end)
  }

  private static func materialBounds(_ source: G.Source, state: Solver.State,
    vertex: Int) throws -> G.Material
  {
    try materialBounds(source.materialState, state: state, vertex: vertex)
  }

  private static func materialBounds(_ source: G.MaterialState, state: Solver.State,
    vertex: Int) throws -> G.Material
  {
    if let view = source.materialView {
      return try Solver.stateMaterialBounds(state,
        localPoint: view.pointRelativeToCurrentCOM(vertex: vertex))
    }
    return try Solver.stateMaterialBounds(state, vertex: vertex)
  }

  /// Mesh binding is a conditional input check, never a native registration.
  /// Reserve each variable search before traversal; mismatch retains its debit.
  private static func compoundIndices(_ source: G.Source, work: inout G.Work) throws -> [[Int]] {
    try compoundIndices(source.materialState, work: &work)
  }

  private static func compoundIndices(_ source: G.MaterialState, work: inout G.Work) throws -> [[Int]] {
    let representation = source.state.representation
    if let view = source.materialView {
      // Pay for the complete shape comparison before reading its arrays.
      try work.reservePreparedMetadataRecords(representation.mass.parts.count)
      try work.reservePreparedMetadataRecords(representation.sourceVertices.count)
      try work.reservePreparedMetadataRecords(representation.meshAtCentreOfMass.vertices.count)
      try work.reservePreparedMetadataRecords(representation.meshAtCentreOfMass.faces.count)
      for face in representation.meshAtCentreOfMass.faces {
        try work.reservePreparedMetadataRecords(face.count)
      }
      guard view.matches(representation) else { throw G.Failure.invalidInput }
    }
    let mesh = materialMesh(source)
    try work.reservePreparedMetadataRecords(mesh.vertices.count)
    try work.reservePreparedMetadataRecords(mesh.faces.count)
    for face in mesh.faces { try work.reservePreparedMetadataRecords(face.count) }
    guard source.prepared.sourceVertices == mesh.vertices, source.prepared.sourceFaces == mesh.faces
    else { throw G.Failure.invalidInput }
    return try source.prepared.triangles.map { triangle in
      guard representation.faces.indices.contains(triangle.sourceFace) else { throw G.Failure.invalidInput }
      return try triangle.vertices.map { vertex in
        try work.reservePreparedMetadataRecords(mesh.vertices.count)
        try work.reservePreparedMetadataRecords(representation.faces[triangle.sourceFace].indices.count)
        guard let index = mesh.vertices.firstIndex(of: vertex),
          representation.faces[triangle.sourceFace].indices.contains(index)
        else { throw G.Failure.invalidInput }
        return index
      }
    }
  }

  private static func sourceDeviation(_ source: G.Source, work: inout G.Work) throws -> Double {
    try stateDeviation(source.materialState, work: &work)
  }

  /// Conservative maximum material-vertex deviation from the actual represented
  /// shadow frame at this ONE retained State. Native placement/solid/clearance
  /// and complete actual world/source/currentness remain G1's existing checks.
  static func initialMaterialDeviation(_ source: G.InstantaneousSource, work: inout G.Work) throws -> Double {
    try work.reservePreparedMetadataRecords(4)
    let frame = source.referencePose
    guard frame.position.finite, frame.orientation.x.finite,
      frame.orientation.y.finite, frame.orientation.z.finite else { throw G.Failure.invalidInput }
    try validate(source.prepared, work: &work)
    _ = try compoundIndices(source.materialState, work: &work)
    return try stateDeviation(source.materialState, work: &work)
  }

  private static func stateDeviation(_ source: G.MaterialState, work: inout G.Work) throws -> Double {
    let vertices = materialMesh(source).vertices
    var deviation = 0.0
    for index in vertices.indices {
      try work.reservePreparedMetadataRecords(1)
      let bounds = try materialBounds(source, state: source.state, vertex: index)
      let difference = bounds.position - G.B.point(source.referencePose.systemPoint(vertices[index]))
      let length = G.length(difference)
      guard length.valid else { throw G.Failure.unproven }
      deviation = max(deviation, length.upper)
    }
    return deviation
  }

  private static func ordinaryDeviation(_ prepared: G.Prepared, motion: HullSceneMotion,
    work: inout G.Work) throws -> Double
  {
    var deviation = 0.0
    for triangle in prepared.triangles {
      try work.triangle()
      for point in triangle.vertices {
        let bounds = try G.ordinary(motion, local: point, from: 0, through: 0)
        let difference = bounds.position - G.B.point(motion.start.systemPoint(point))
        let length = G.length(difference)
        guard length.valid else { throw G.Failure.unproven }
        deviation = max(deviation, length.upper)
      }
    }
    return deviation
  }
}
