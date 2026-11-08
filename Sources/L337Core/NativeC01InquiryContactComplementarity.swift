import Foundation

/// Conditional instantaneous FREE-baseline contact complementarity. Actual
/// native forces/time/material/events and constrained finite flow remain G1's.
enum NativeC01InquiryContactComplementarity {
  typealias C = NativeC01InquiryCutContactSet
  typealias Solver = NativeC01InquiryCompoundValidatedCurve
  typealias I = Solver.Interval
  typealias G = NativeC01InquiryCurveGeometry

  struct ZeroRowRelation: Sendable {
    let row: Int
    let activeRows: [Int]
    let coefficients: [Double]
  }
  struct Certificate: Sendable {
    let contactOperator: C.Operator
    let activeBasis: [Int]
    /// Active entries enclose x=-K_AA^-1*b_A, not independent force choices.
    /// Nonactive entries are exactly zero. This chooses no scalar force.
    let force: [I]
    let acceleration: [I]
    let impliedZeroRows: [ZeroRowRelation]

    fileprivate init(_ value: C.Operator, basis: [Int], force: [I], acceleration: [I],
      relations: [ZeroRowRelation])
    {
      contactOperator = value; activeBasis = basis; self.force = force
      self.acceleration = acceleration; impliedZeroRows = relations
    }
  }
  enum Outcome: Sendable {
    case certified(Certificate)
    case unresolved
    case workExhausted
  }

  static func prepare(_ value: C.Operator, work: inout G.Work) -> Outcome {
    do {
      let n = value.rows.count
      guard n <= NativeC01InquiryFixtureGeometry.designedJoints.count * 4,
        value.matrix.count == n * n, value.freeAcceleration.count == n
      else { return .unresolved }
      try work.reservePreparedMetadataRecords(n)
      try work.reservePreparedMetadataRecords(n * n)
      guard value.matrix.allSatisfy(\.valid), value.freeAcceleration.allSatisfy(\.valid)
      else { return .unresolved }
      let angular = value.boundary.parentState.worldAngularMomentum
      let zeroExternal: Bool
      switch value.forceModel {
      case .free: zeroExternal = true
      case .applied(let wrenches):
        try work.reservePreparedMetadataRecords(wrenches.count)
        zeroExternal = wrenches.allSatisfy { value in
          [value.worldForce.x, value.worldForce.y, value.worldForce.z,
            value.worldTorqueAtCOM.x, value.worldTorqueAtCOM.y, value.worldTorqueAtCOM.z]
            .allSatisfy { $0.lower == 0 && $0.upper == 0 }
        }
      }
      if zeroExternal && [angular.x, angular.y, angular.z].allSatisfy({ $0.lower == 0 && $0.upper == 0 }) {
        // This source-derived boundary has inherited common translation. In
        // the FREE baseline its real b is exactly zero and f=0 is admissible.
        // External actual forces/contacts are not asserted absent by this fact.
        try work.reservePreparedMetadataRecords(n)
        try work.reservePreparedMetadataRecords(n)
        return .certified(.init(value, basis: [], force: Array(repeating: .point(0), count: n),
          acceleration: Array(repeating: .point(0), count: n), relations: []))
      }
      for mask in 0..<(1 << n) {
        try work.node()
        try work.reservePreparedMetadataRecords(n)
        let basis = (0..<n).filter { mask & (1 << $0) != 0 }
        if let result = try candidate(value, basis: basis, work: &work) { return .certified(result) }
      }
      return .unresolved
    } catch G.Failure.workBudgetExceeded {
      return .workExhausted
    } catch { return .unresolved }
  }

  private static func candidate(_ value: C.Operator, basis: [Int], work: inout G.Work)
    throws -> Certificate?
  {
    guard let result = try basisCandidate(rows: value.rows, coefficients: value.matrix,
      baseline: value.freeAcceleration, atlas: value.boundary.parentView.atlas, basis: basis, work: &work)
    else { return nil }
    return .init(value, basis: result.basis, force: result.force,
      acceleration: result.acceleration, relations: result.relations)
  }

  fileprivate struct BasisSolution {
    let basis: [Int]
    let force: [I]
    let acceleration: [I]
    let relations: [ZeroRowRelation]
  }

  /// Original and moving operators use the same interval solve and rank test.
  private static func basisCandidate(rows: [C.Row], coefficients: [I], baseline: [I],
    atlas: NativeC01InquiryCompoundMaterialAtlas, basis: [Int], work: inout G.Work)
    throws -> BasisSolution?
  {
    let n = rows.count
    var matrix: [I] = []
    var rhs: [I] = []
    for row in basis {
      try work.triangle()
      rhs.append(-baseline[row])
      for column in basis {
        try work.triangle()
        matrix.append(coefficients[row * n + column])
      }
    }
    guard let solution = try encloseLinearSystem(matrix: matrix, rhs: rhs,
      width: basis.count, work: &work) else { return nil }
    try work.reservePreparedMetadataRecords(n)
    try work.reservePreparedMetadataRecords(n)
    var force = Array(repeating: I.point(0), count: n)
    var acceleration = Array(repeating: I.point(0), count: n)
    for (index, row) in basis.enumerated() {
      try work.triangle()
      guard solution[index].valid, solution[index].lower >= 0 else { return nil }
      force[row] = solution[index]
      // Equality is the exact equation defining this correlated solution. It
      // is NOT inferred from an interval residual merely containing zero.
      acceleration[row] = .point(0)
    }
    var relations: [ZeroRowRelation] = []
    for row in 0..<n {
      try work.reservePreparedMetadataRecords(basis.count)
      if basis.contains(row) { continue }
      if let relation = try rectangularZeroRelation(rows: rows, atlas: atlas, row: row, activeBasis: basis, work: &work) {
        relations.append(relation)
        acceleration[row] = .point(0)
        continue
      }
      var result = baseline[row]
      for column in basis {
        try work.triangle()
        result = result + coefficients[row * n + column] * force[column]
      }
      guard result.valid, result.lower >= 0 else { return nil }
      acceleration[row] = result
    }
    return .init(basis: basis, force: force, acceleration: acceleration, relations: relations)
  }

  /// Outward interval elimination. Every selected pivot excludes zero for the
  /// entire represented matrix family. Successful back substitution encloses
  /// the exact implicit solution for each actual matrix/RHS in these boxes.
  /// No tolerance, diagonal regularization, midpoint or singular inverse.
  static func encloseLinearSystem(matrix input: [I], rhs inputRHS: [I], width n: Int,
    work: inout G.Work) throws -> [I]?
  {
    try work.query()
    guard n >= 0, n <= NativeC01InquiryFixtureGeometry.designedJoints.count * 4,
      input.count == n * n, inputRHS.count == n else { return nil }
    try work.reservePreparedMetadataRecords(input.count)
    try work.reservePreparedMetadataRecords(inputRHS.count)
    guard input.allSatisfy(\.valid), inputRHS.allSatisfy(\.valid) else { return nil }
    var matrix = input
    var rhs = inputRHS
    for column in 0..<n {
      var pivot: Int?
      for row in column..<n {
        try work.triangle()
        let value = matrix[row * n + column]
        if value.valid && (value.lower > 0 || value.upper < 0) { pivot = row; break }
      }
      guard let pivot else { return nil }
      if pivot != column {
        for j in 0..<n {
          try work.triangle()
          let temporary = matrix[column * n + j]
          matrix[column * n + j] = matrix[pivot * n + j]
          matrix[pivot * n + j] = temporary
        }
        try work.triangle()
        let temporary = rhs[column]; rhs[column] = rhs[pivot]; rhs[pivot] = temporary
      }
      for row in (column + 1)..<n {
        try work.triangle()
        let factor = matrix[row * n + column] / matrix[column * n + column]
        guard factor.valid else { return nil }
        for j in (column + 1)..<n {
          try work.triangle()
          let entry = matrix[row * n + j] - factor * matrix[column * n + j]
          guard entry.valid else { return nil }
          matrix[row * n + j] = entry
        }
        try work.triangle()
        let next = rhs[row] - factor * rhs[column]
        guard next.valid else { return nil }
        rhs[row] = next
        // Exact elimination identity; dependent interval entries do not imply
        // an actual residual. The remaining row boxes enclose that identity.
        matrix[row * n + column] = .point(0)
      }
    }
    try work.reservePreparedMetadataRecords(n)
    var result = Array(repeating: I.point(0), count: n)
    for row in (0..<n).reversed() {
      var value = rhs[row]
      for column in (row + 1)..<n {
        try work.triangle()
        value = value - matrix[row * n + column] * result[column]
      }
      try work.triangle()
      let diagonal = matrix[row * n + row]
      guard diagonal.valid, diagonal.lower > 0 || diagonal.upper < 0 else { return nil }
      result[row] = value / diagonal
      guard result[row].valid else { return nil }
    }
    return result
  }

  /// Exact represented rectangle plus shared parent/normal gives row0+row2
  /// =row1+row3 for BOTH K and free acceleration. If the other three rows are
  /// solved active equalities, this one is exactly zero despite rank deficiency.
  static func rectangularZeroRelation(_ value: C.Operator, row: Int, activeBasis: [Int],
    work: inout G.Work) throws -> ZeroRowRelation?
  {
    try rectangularZeroRelation(rows: value.rows, atlas: value.boundary.parentView.atlas,
      row: row, activeBasis: activeBasis, work: &work)
  }

  private static func rectangularZeroRelation(rows: [C.Row], atlas: NativeC01InquiryCompoundMaterialAtlas, row: Int, activeBasis: [Int],
    work: inout G.Work) throws -> ZeroRowRelation?
  {
    guard rows.indices.contains(row) else { return nil }
    try work.reservePreparedMetadataRecords(rows.count)
    let patch = rows[row].patchIndex
    let indices = rows.indices.filter { rows[$0].patchIndex == patch }
    guard indices.count == 4, let omitted = indices.firstIndex(of: row) else { return nil }
    try work.reservePreparedMetadataRecords(4)
    let other = indices.filter { $0 != row }
    for index in other {
      try work.reservePreparedMetadataRecords(activeBasis.count)
      guard activeBasis.contains(index) else { return nil }
    }
    try work.reservePreparedMetadataRecords(4)
    let points = indices.map { atlas.vertices[rows[$0].materialVertexID] }
    guard points[0].x == points[3].x, points[1].x == points[2].x,
      points[0].y == points[1].y, points[2].y == points[3].y,
      points.allSatisfy({ $0.z == points[0].z }),
      points[0].x != points[1].x, points[0].y != points[3].y
    else { return nil }
    let signs: [Double] = [1, -1, 1, -1]
    let coefficients = indices.indices.filter { $0 != omitted }.map { -signs[$0] * signs[omitted] }
    return .init(row: row, activeRows: other, coefficients: coefficients)
  }
}

extension NativeC01InquiryContactComplementarity {
  /// Correlated solution range lambda=-K_AA^-1*b_A over a supplied family.
  /// Neither g/gDot equality nor a force-law/time/native grant is implied.
  struct MovingBasisRange: Sendable {
    let contactOperator: C.MovingOperator
    let activeBasis: [Int]
    let force: [I]
    let acceleration: [I]
    let impliedZeroRows: [ZeroRowRelation]

    fileprivate init(value: C.MovingOperator, solution: BasisSolution) {
      contactOperator = value; activeBasis = solution.basis
      force = solution.force; acceleration = solution.acceleration
      impliedZeroRows = solution.relations
    }
  }
  enum MovingBasisOutcome: Sendable {
    case bounds(MovingBasisRange)
    case unresolved
    case workExhausted
  }

  static func prepareMovingBasis(_ value: C.MovingOperator, work: inout G.Work) -> MovingBasisOutcome {
    do {
      let n = value.rows.count
      guard n <= 12, value.matrix.count == n * n, value.baseline.count == n else { return .unresolved }
      try work.reservePreparedMetadataRecords(n * n + n + n)
      guard value.matrix.allSatisfy(\.valid), value.baseline.allSatisfy(\.valid) else { return .unresolved }
      let rows = value.rows.map(\.contact)
      // In particular, DO NOT use the original parent-L=0 shortcut here.
      // Current states, normals, external ranges and gap jets can differ.
      for mask in 0..<(1 << n) {
        try work.node()
        try work.reservePreparedMetadataRecords(n)
        let basis = (0..<n).filter { mask & (1 << $0) != 0 }
        if let solution = try basisCandidate(rows: rows, coefficients: value.matrix,
          baseline: value.baseline, atlas: value.sourceBoundary.parentView.atlas, basis: basis, work: &work)
        { return .bounds(.init(value: value, solution: solution)) }
      }
      return .unresolved
    } catch G.Failure.workBudgetExceeded { return .workExhausted }
    catch { return .unresolved }
  }

  static func movingRectangularZeroRelation(_ value: C.MovingOperator, row: Int,
    activeBasis: [Int], work: inout G.Work) throws -> ZeroRowRelation?
  {
    try work.reservePreparedMetadataRecords(value.rows.count)
    return try rectangularZeroRelation(rows: value.rows.map(\.contact),
      atlas: value.sourceBoundary.parentView.atlas, row: row, activeBasis: activeBasis, work: &work)
  }
}

extension NativeC01InquiryContactComplementarity {
  struct MovingBasisDifferential: Sendable {
    let range: MovingBasisRange
    let variables: Int
    /// Force-row-major: coefficient derivative [(i*n+j)*variables+k].
    let coefficientDerivatives: [I]
    /// Baseline-row-major: [i*variables+k].
    let baselineDerivatives: [I]
    let forceJacobian: [I]

    fileprivate init(range: MovingBasisRange, variables: Int,
      coefficients: [I], baseline: [I], force: [I])
    {
      self.range = range; self.variables = variables
      coefficientDerivatives = coefficients; baselineDerivatives = baseline; forceJacobian = force
    }
  }
  enum MovingDifferentialOutcome: Sendable {
    case bounds(MovingBasisDifferential)
    case unresolved
    case workExhausted
  }

  /// Exact implicit derivative for the SAME held active basis. Supplied dK/db
  /// must be analytic ranges of the same actual state/time law; neither arrays
  /// nor this result confer native provenance, basis persistence or g/gDot=0.
  static func prepareMovingBasisDifferential(_ range: MovingBasisRange, variables: Int,
    coefficientDerivatives: [I], baselineDerivatives: [I], work: inout G.Work
  ) -> MovingDifferentialOutcome {
    do {
      try work.query()
      let n = range.contactOperator.rows.count
      guard n <= 12, variables > 0, variables <= 53,
        coefficientDerivatives.count == n * n * variables,
        baselineDerivatives.count == n * variables else { return .unresolved }
      try work.reservePreparedMetadataRecords(coefficientDerivatives.count + baselineDerivatives.count)
      guard coefficientDerivatives.allSatisfy(\.valid), baselineDerivatives.allSatisfy(\.valid)
      else { return .unresolved }
      try work.reservePreparedMetadataRecords(n * variables)
      var result = Array(repeating: I.point(0), count: n * variables)
      let basis = range.activeBasis
      var matrix: [I] = []
      var solution: [I] = []
      for row in basis {
        try work.reservePreparedMetadataRecords(1)
        solution.append(range.force[row])
        for column in basis {
          try work.reservePreparedMetadataRecords(1)
          matrix.append(range.contactOperator.matrix[row * n + column])
        }
      }
      // An empty held basis defines every force as identically zero, including
      // its derivatives. This is algebraic, not a native FREE-force declaration.
      if !basis.isEmpty {
        for variable in 0..<variables {
          try work.node()
          var derivative: [I] = []
          var baseline: [I] = []
          for row in basis {
            try work.reservePreparedMetadataRecords(1)
            baseline.append(baselineDerivatives[row * variables + variable])
            for column in basis {
              try work.reservePreparedMetadataRecords(1)
              derivative.append(coefficientDerivatives[(row * n + column) * variables + variable])
            }
          }
          guard let column = try encloseBasisDerivative(matrix: matrix, solution: solution,
            matrixDerivative: derivative, baselineDerivative: baseline, width: basis.count, work: &work)
          else { return .unresolved }
          for (index, row) in basis.enumerated() {
            try work.reservePreparedMetadataRecords(1)
            result[row * variables + variable] = column[index]
          }
        }
      }
      try work.reservePreparedMetadataRecords(1)
      return .bounds(.init(range: range, variables: variables, coefficients: coefficientDerivatives,
        baseline: baselineDerivatives, force: result))
    } catch G.Failure.workBudgetExceeded { return .workExhausted }
    catch { return .unresolved }
  }

  /// Differentiate M*x=-b: M*dx=-db-dM*x. Reuses the ONE existing interval
  /// eliminator; no midpoint, finite difference or second linear solver.
  static func encloseBasisDerivative(matrix: [I], solution: [I], matrixDerivative: [I],
    baselineDerivative: [I], width n: Int, work: inout G.Work) throws -> [I]?
  {
    guard n >= 0, n <= 12, matrix.count == n * n, solution.count == n,
      matrixDerivative.count == n * n, baselineDerivative.count == n else { return nil }
    try work.reservePreparedMetadataRecords(n * n + n + n)
    guard solution.allSatisfy(\.valid), matrixDerivative.allSatisfy(\.valid), baselineDerivative.allSatisfy(\.valid)
    else { return nil }
    var rhs: [I] = []
    for row in 0..<n {
      try work.reservePreparedMetadataRecords(1)
      var value = -baselineDerivative[row]
      for column in 0..<n {
        try work.reservePreparedMetadataRecords(2)
        value = value - matrixDerivative[row * n + column] * solution[column]
      }
      try work.reservePreparedMetadataRecords(1)
      rhs.append(value)
    }
    return try encloseLinearSystem(matrix: matrix, rhs: rhs, width: n, work: &work)
  }
}

extension NativeC01InquiryContactComplementarity {
  /// Algebraic enclosure for ONE explicitly chosen held basis. This supplies
  /// no constraint-history, contact, force-law window or native time authority.
  static func encloseMovingBasis(_ value: C.MovingOperator, activeBasis: [Int], work: inout G.Work) -> MovingBasisOutcome {
    do {
      try work.node()
      let n = value.rows.count
      guard n <= 12, value.matrix.count == n * n, value.baseline.count == n,
        activeBasis.count <= n else { return .unresolved }
      var previous = -1
      for row in activeBasis {
        try work.reservePreparedMetadataRecords(1)
        guard row >= 0, row < n, row > previous else { return .unresolved }
        previous = row
      }
      try work.reservePreparedMetadataRecords(n * n + n + n)
      guard value.matrix.allSatisfy(\.valid), value.baseline.allSatisfy(\.valid) else { return .unresolved }
      let rows = value.rows.map(\.contact)
      guard let solution = try basisCandidate(rows: rows, coefficients: value.matrix,
        baseline: value.baseline, atlas: value.sourceBoundary.parentView.atlas, basis: activeBasis, work: &work)
      else { return .unresolved }
      return .bounds(.init(value: value, solution: solution))
    } catch G.Failure.workBudgetExceeded { return .workExhausted }
    catch { return .unresolved }
  }
}
