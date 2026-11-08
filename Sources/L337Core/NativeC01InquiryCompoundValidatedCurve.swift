import Foundation

/// C01-only validated torque-free quaternion flow. It retains uncertainty and
/// installs no native scene receipt. G1 must qualify this same curve/geometry.
enum NativeC01InquiryCompoundValidatedCurve {
  enum Failure: Error, Sendable {
    case invalidSeed, invalidDuration, invalidBudget, singularTensor
    case workExhausted, subdivisionExhausted, cellCapacity, nonfiniteEnclosure, unprovenContact
  }

  struct WorkBudget: Sendable {
    let cellAttempts: Int
    let subdivisionDepth: Int
    let retainedCells: Int
  }

  struct Work: Sendable {
    let cellAttempts: Int
    let splits: Int
    let retainedCells: Int
  }

  /// Bounds refer to real arithmetic over represented input scalars. Each
  /// elementary operation expands both endpoints; invalid never becomes clear.
  struct Interval: Sendable, Equatable {
    let lower: Double
    let upper: Double
    var valid: Bool { lower.isFinite && upper.isFinite && lower <= upper }
    fileprivate static let invalid = Self(lower: .nan, upper: .nan)
    static func point(_ value: Double) -> Self { .init(lower: value, upper: value) }
    var magnitude: Double { max(abs(lower), abs(upper)) }
    static func rounded(_ lower: Double, _ upper: Double) -> Self {
      guard lower.isFinite, upper.isFinite else { return .invalid }
      let result = Self(lower: lower.nextDown, upper: upper.nextUp)
      return result.valid ? result : .invalid
    }
    static func + (a: Self, b: Self) -> Self {
      guard a.valid, b.valid else { return .invalid }
      return rounded(a.lower + b.lower, a.upper + b.upper)
    }
    static prefix func - (a: Self) -> Self {
      .init(lower: -a.upper, upper: -a.lower)
    }
    static func - (a: Self, b: Self) -> Self { a + (-b) }
    static func * (a: Self, b: Self) -> Self {
      guard a.valid, b.valid else { return .invalid }
      let values = [a.lower * b.lower, a.lower * b.upper, a.upper * b.lower, a.upper * b.upper]
      guard values.allSatisfy(\.isFinite), let lower = values.min(), let upper = values.max() else { return .invalid }
      return rounded(lower, upper)
    }
    static func / (a: Self, b: Self) -> Self {
      guard a.valid, b.valid, b.lower > 0 || b.upper < 0 else { return .invalid }
      return a * rounded(1 / b.upper, 1 / b.lower)
    }
    func squareRoot() -> Self {
      guard valid, lower >= 0 else { return .invalid }
      return Self.rounded(lower.squareRoot(), upper.squareRoot())
    }
    func union(_ other: Self) -> Self {
      guard valid, other.valid else { return .invalid }
      return .init(lower: min(lower, other.lower), upper: max(upper, other.upper))
    }
    func inflated() -> Self {
      guard valid else { return .invalid }
      let width = (upper - lower).nextUp
      return Self.rounded(lower - width, upper + width)
    }
    func strictlyContains(_ other: Self) -> Bool {
      valid && other.valid && lower < other.lower && other.upper < upper
    }
  }

  struct VectorBox: Sendable {
    let x: Interval
    let y: Interval
    let z: Interval
    var valid: Bool { x.valid && y.valid && z.valid }
    var values: [Interval] { [x, y, z] }
    static func point(_ v: Vector3) -> Self {
      .init(x: Interval.point(v.x), y: Interval.point(v.y), z: Interval.point(v.z))
    }
    static func + (a: Self, b: Self) -> Self { .init(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Self, b: Self) -> Self { .init(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Self, b: Interval) -> Self { .init(x: a.x * b, y: a.y * b, z: a.z * b) }
    func cross(_ b: Self) -> Self {
      .init(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
    }
    func union(_ b: Self) -> Self {
      .init(x: x.union(b.x), y: y.union(b.y), z: z.union(b.z))
    }
  }

  struct QuaternionBox: Sendable {
    /// Scalar-first quaternion. No midpoint is an authoritative native rotation.
    let components: [Interval]
    var valid: Bool { components.count == 4 && components.allSatisfy(\.valid) }
    func offset(_ derivative: Self, by time: Interval) -> Self {
      .init(components: zip(components, derivative.components).map { $0.0 + $0.1 * time })
    }
    func inflated() -> Self { .init(components: components.map { $0.inflated() }) }
    func strictlyContains(_ other: Self) -> Bool {
      valid && other.valid && zip(components, other.components).allSatisfy { $0.0.strictlyContains($0.1) }
    }
  }

  struct State: Sendable {
    let representation: NativeC01InquiryCompoundRepresentation
    let quaternion: QuaternionBox
    let centreOfMass: VectorBox
    let linearMomentum: VectorBox
    let worldAngularMomentum: VectorBox
    fileprivate init(representation: NativeC01InquiryCompoundRepresentation, quaternion: QuaternionBox,
      centreOfMass: VectorBox, linearMomentum: VectorBox, worldAngularMomentum: VectorBox)
    {
      self.representation = representation; self.quaternion = quaternion
      self.centreOfMass = centreOfMass; self.linearMomentum = linearMomentum
      self.worldAngularMomentum = worldAngularMomentum
    }
  }

  struct Sample: Sendable {
    let centreOfMass: VectorBox
    /// Row-major bounds for the common orientation, shared by every part.
    let orientation: [Interval]
    let angularVelocity: VectorBox
  }

  struct MaterialBounds: Sendable {
    let position: VectorBox
    let velocity: VectorBox
  }

  fileprivate struct Cell: Sendable {
    let start: Double
    let end: Double
    let quaternion: QuaternionBox
    let orientation: [Interval]
    let angularVelocity: VectorBox
  }

  struct Curve: Sendable {
    let initial: State
    let endpoint: State
    let duration: Double
    let work: Work
    fileprivate let cells: [Cell]

    /// Conservative pose/omega sampling; it never collapses a cell to a guessed
    /// point pose. A native adapter may refine or refuse a wide enclosure.
    func sample(at time: Double) -> Sample? {
      guard time.isFinite, time >= 0, time <= duration else { return nil }
      let selected = cells.filter { $0.start <= time && time <= $0.end }
      guard let first = selected.first else { return nil }
      var rotation = first.orientation
      var omega = first.angularVelocity
      for cell in selected.dropFirst() {
        rotation = zip(rotation, cell.orientation).map { $0.0.union($0.1) }
        omega = omega.union(cell.angularVelocity)
      }
      let centre = centre(at: Interval.point(time))
      guard centre.valid, rotation.allSatisfy(\.valid), omega.valid else { return nil }
      return .init(centreOfMass: centre, orientation: rotation, angularVelocity: omega)
    }

    /// All material points of a planar exterior facet lie in the convex hull of
    /// its vertices. G1 queries every facet/foreign surface, without pair skips.
    func materialBounds(vertex: Int, from start: Double, through end: Double) -> MaterialBounds? {
      let mesh = initial.representation.meshAtCentreOfMass
      guard mesh.vertices.indices.contains(vertex) else { return nil }
      return materialBounds(localPoint: VectorBox.point(mesh.vertices[vertex]), from: start, through: end)
    }

    /// Explicit local-to-current-COM enclosure. Stable material lineage passes
    /// ancestral represented coordinates plus its REAL current-COM relation;
    /// no newly rounded independent mesh or scalar state is installed here.
    func materialBounds(localPoint point: VectorBox, from start: Double,
      through end: Double) -> MaterialBounds?
    {
      guard point.valid, start.isFinite, end.isFinite,
        start >= 0, start <= end, end <= duration else { return nil }
      var result: MaterialBounds?
      for cell in cells where cell.start <= end && cell.end >= start {
        let time = Interval(lower: max(start, cell.start), upper: min(end, cell.end))
        let lever = NativeC01InquiryCompoundValidatedCurve.apply(cell.orientation, point)
        let position = centre(at: time) + lever
        let velocity = linearVelocity + cell.angularVelocity.cross(lever)
        guard position.valid, velocity.valid else { return nil }
        if let previous = result {
          result = .init(position: previous.position.union(position), velocity: previous.velocity.union(velocity))
        } else { result = .init(position: position, velocity: velocity) }
      }
      return result
    }

    private var linearVelocity: VectorBox {
      initial.linearMomentum * (Interval.point(1) / Interval.point(initial.representation.mass.massKilograms))
    }
    private func centre(at time: Interval) -> VectorBox { initial.centreOfMass + linearVelocity * time }
  }

  /// The mathematical source seed is rawQuaternion / its real Euclidean norm.
  /// G1 must register this same seed/common geometry, never convert and snap an
  /// independently attained Basis3 pose into a fresh authoritative rotation.
  static func seed(representation: NativeC01InquiryCompoundRepresentation,
    rawQuaternion: [Double], centreOfMass: Vector3,
    linearMomentum: Vector3, worldAngularMomentum: Vector3) throws -> State
  {
    guard rawQuaternion.count == 4, rawQuaternion.allSatisfy(\.isFinite), centreOfMass.finite,
      linearMomentum.finite, worldAngularMomentum.finite else { throw Failure.invalidSeed }
    let q = rawQuaternion.map(Interval.point)
    let normSquared = q.reduce(Interval.point(0)) { $0 + $1 * $1 }
    guard normSquared.valid, normSquared.lower > 0 else { throw Failure.invalidSeed }
    let norm = normSquared.squareRoot()
    let normalized = QuaternionBox(components: q.map { $0 / norm })
    guard normalized.valid else { throw Failure.invalidSeed }
    return .init(representation: representation, quaternion: normalized,
      centreOfMass: VectorBox.point(centreOfMass), linearMomentum: VectorBox.point(linearMomentum),
      worldAngularMomentum: VectorBox.point(worldAngularMomentum))
  }

  static func prepare(_ initial: State, duration: Double, budget: WorkBudget) throws -> Curve {
    try prepareRefined(initial, duration: duration, budget: budget, maximumCellDuration: duration)
  }

  /// Accuracy control is explicit; all forced splits use the same charged
  /// attempts/depth/cell allowances. This issues no new native time/step key.
  static func prepareRefined(_ initial: State, duration: Double, budget: WorkBudget,
    maximumCellDuration: Double) throws -> Curve
  {
    guard duration.isFinite, duration > 0, duration <= 0.1,
      maximumCellDuration.isFinite, maximumCellDuration > 0, maximumCellDuration <= duration
    else { throw Failure.invalidDuration }
    guard budget.cellAttempts > 0, budget.cellAttempts < Int.max,
      budget.subdivisionDepth >= 0, budget.subdivisionDepth < Int.max,
      budget.retainedCells > 0, budget.retainedCells < Int.max else { throw Failure.invalidBudget }
    guard initial.quaternion.valid, initial.centreOfMass.valid,
      initial.linearMomentum.valid, initial.worldAngularMomentum.valid else { throw Failure.invalidSeed }
    let inverse = try inverseTensor(initial.representation.mass.inertiaAtCentreOfMass)
    struct Segment { let start: Double; let end: Double; let depth: Int }
    var pending = [Segment(start: 0, end: duration, depth: 0)]
    var quaternion = initial.quaternion
    var cells: [Cell] = []
    var attempts = 0
    var splits = 0
    while let segment = pending.popLast() {
      guard attempts < budget.cellAttempts else { throw Failure.workExhausted }
      attempts += 1
      let difference = segment.end - segment.start
      let h = Interval(lower: max(0, difference.nextDown), upper: difference.nextUp)
      guard h.valid, h.upper > 0 else { throw Failure.nonfiniteEnclosure }
      let time = Interval(lower: 0, upper: h.upper)
      let firstDerivative = field(quaternion, inverse: inverse, momentum: initial.worldAngularMomentum)
      let candidate = quaternion.offset(firstDerivative, by: time).inflated()
      let derivative = field(candidate, inverse: inverse, momentum: initial.worldAngularMomentum)
      let image = quaternion.offset(derivative, by: time)
      let contraction = Interval.point(h.upper) * lipschitz(candidate, inverse: inverse,
        momentum: initial.worldAngularMomentum)
      if difference <= maximumCellDuration,
        candidate.strictlyContains(image), contraction.valid, contraction.upper < 1
      {
        let next = quaternion.offset(derivative, by: h)
        let rotation = orientation(candidate)
        let omega = angularVelocity(rotation, inverse: inverse, momentum: initial.worldAngularMomentum)
        guard next.valid, rotation.allSatisfy(\.valid), omega.valid else { throw Failure.nonfiniteEnclosure }
        guard cells.count < budget.retainedCells else { throw Failure.cellCapacity }
        cells.append(.init(start: segment.start, end: segment.end, quaternion: candidate,
          orientation: rotation, angularVelocity: omega))
        quaternion = next
      } else {
        guard segment.depth < budget.subdivisionDepth else { throw Failure.subdivisionExhausted }
        let middle = segment.start + difference * 0.5
        guard middle > segment.start, middle < segment.end else { throw Failure.subdivisionExhausted }
        splits += 1
        pending.append(.init(start: middle, end: segment.end, depth: segment.depth + 1))
        pending.append(.init(start: segment.start, end: middle, depth: segment.depth + 1))
      }
    }
    let mass = Interval.point(initial.representation.mass.massKilograms)
    let centre = initial.centreOfMass + initial.linearMomentum * (Interval.point(duration) / mass)
    guard centre.valid else { throw Failure.nonfiniteEnclosure }
    let endpoint = State(representation: initial.representation, quaternion: quaternion, centreOfMass: centre,
      linearMomentum: initial.linearMomentum, worldAngularMomentum: initial.worldAngularMomentum)
    return .init(initial: initial, endpoint: endpoint, duration: duration,
      work: .init(cellAttempts: attempts, splits: splits, retainedCells: cells.count), cells: cells)
  }

  /// Point-state bounds retain current endpoint uncertainty rather than the
  /// wider temporal cell. Vertices are the actual common prepared mesh values.
  static func stateMaterialBounds(_ state: State, vertex: Int) throws -> MaterialBounds {
    let mesh = state.representation.meshAtCentreOfMass
    guard mesh.vertices.indices.contains(vertex) else { throw Failure.invalidSeed }
    return try stateMaterialBounds(state, localPoint: VectorBox.point(mesh.vertices[vertex]))
  }

  /// Endpoint counterpart of the explicit stable material-frame relation.
  static func stateMaterialBounds(_ state: State, localPoint: VectorBox) throws -> MaterialBounds {
    guard localPoint.valid else { throw Failure.invalidSeed }
    let rotation = orientation(state.quaternion)
    let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: state.worldAngularMomentum)
    let lever = apply(rotation, localPoint)
    let position = state.centreOfMass + lever
    let velocity = state.linearMomentum * (Interval.point(1) / Interval.point(state.representation.mass.massKilograms))
      + omega.cross(lever)
    guard position.valid, velocity.valid else { throw Failure.nonfiniteEnclosure }
    return .init(position: position, velocity: velocity)
  }

  /// Preserve the parent's enclosed orientation and inherited rigid motion.
  /// Actual event/material routing and native component registration are G1's.
  static func component(_ parent: State,
    parts roles: [NativeC01InquiryFixtureGeometry.Part]) throws -> State
  {
    guard roles.allSatisfy({ role in parent.representation.mass.parts.contains { $0.kind == role } }),
      let selected = NativeC01InquiryCompoundRepresentation.make(parts: roles)
    else { throw Failure.invalidSeed }
    let rotation = orientation(parent.quaternion)
    let inverse = try inverseTensor(parent.representation.mass.inertiaAtCentreOfMass)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: parent.worldAngularMomentum)
    let lever = apply(rotation, sourceCOMDifference(
      from: parent.representation.mass.centreOfMassSource, to: selected.mass.centreOfMassSource))
    let velocity = parent.linearMomentum * (Interval.point(1) / Interval.point(parent.representation.mass.massKilograms))
      + omega.cross(lever)
    let i = selected.mass.inertiaAtCentreOfMass
    let matrix = [i.xx, i.xy, i.xz, i.xy, i.yy, i.yz, i.xz, i.yz, i.zz].map(Interval.point)
    let transpose = [rotation[0], rotation[3], rotation[6], rotation[1], rotation[4], rotation[7],
      rotation[2], rotation[5], rotation[8]]
    let spin = apply(rotation, apply(matrix, apply(transpose, omega)))
    let centre = parent.centreOfMass + lever
    let momentum = velocity * Interval.point(selected.mass.massKilograms)
    guard centre.valid, momentum.valid, spin.valid else { throw Failure.nonfiniteEnclosure }
    return .init(representation: selected, quaternion: parent.quaternion, centreOfMass: centre,
      linearMomentum: momentum, worldAngularMomentum: spin)
  }

  /// Source COM scalars are represented inputs; their REAL difference is
  /// derived arithmetic and must be enclosed before any rotation or contact use.
  static func sourceCOMDifference(from parent: Vector3, to selected: Vector3) -> VectorBox {
    VectorBox.point(selected) - VectorBox.point(parent)
  }

  /// A prescribed actual impulse remains enclosed. This constructs no contact
  /// or native event; the owner must bind the witness and qualify a new remainder.
  static func applyingImpulse(_ parent: State, impulse: VectorBox, point: VectorBox) throws -> State {
    guard impulse.valid, point.valid else { throw Failure.unprovenContact }
    let momentum = parent.linearMomentum + impulse
    let spin = parent.worldAngularMomentum + (point - parent.centreOfMass).cross(impulse)
    guard momentum.valid, spin.valid else { throw Failure.nonfiniteEnclosure }
    return .init(representation: parent.representation, quaternion: parent.quaternion,
      centreOfMass: parent.centreOfMass, linearMomentum: momentum, worldAngularMomentum: spin)
  }

  struct IntervalContact: Sendable {
    let state: State
    let compoundImpulse: VectorBox
    let oppositeImpulse: VectorBox
  }

  /// Normal boxes must enclose the genuine native unit contact normal. They
  /// cannot prove that witness or replace the other endpoint's rotating response.
  /// Straddled closing/denominator or unsupported uncertainty returns no result.
  static func preparePointImpulse(_ parent: State, point: VectorBox, unitNormal: VectorBox,
    opposingVelocity: VectorBox, opposingInverseEffectiveMass: Interval,
    restitution: Double) throws -> IntervalContact
  {
    guard point.valid, unitNormal.valid, opposingVelocity.valid,
      opposingInverseEffectiveMass.valid, opposingInverseEffectiveMass.lower >= 0,
      restitution.isFinite, (0...1).contains(restitution) else { throw Failure.unprovenContact }
    let rotation = orientation(parent.quaternion)
    let inverse = try inverseTensor(parent.representation.mass.inertiaAtCentreOfMass)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: parent.worldAngularMomentum)
    let r = point - parent.centreOfMass
    let normalTorque = r.cross(unitNormal)
    let angularResponse = angularVelocity(rotation, inverse: inverse, momentum: normalTorque)
    let rotational = dot(unitNormal, angularResponse.cross(r))
    let denominator = Interval.point(1) / Interval.point(parent.representation.mass.massKilograms)
      + rotational + opposingInverseEffectiveMass
    let velocity = parent.linearMomentum * (Interval.point(1) / Interval.point(parent.representation.mass.massKilograms))
      + omega.cross(r)
    let closing = dot(velocity - opposingVelocity, unitNormal)
    guard denominator.valid, denominator.lower > 0, closing.valid, closing.upper < 0
    else { throw Failure.unprovenContact }
    let magnitude = -(Interval.point(1) + Interval.point(restitution)) * closing / denominator
    guard magnitude.valid, magnitude.lower > 0 else { throw Failure.unprovenContact }
    let impulse = unitNormal * magnitude
    let state = try applyingImpulse(parent, impulse: impulse, point: point)
    return .init(state: state, compoundImpulse: impulse, oppositeImpulse: impulse * Interval.point(-1))
  }

  struct IntervalPairContact: Sendable {
    let firstBefore: State
    let secondBefore: State
    let firstAfter: State
    let secondAfter: State
    /// Both endpoints use ONE real impulse, never independent interval choices.
    let firstImpulse: VectorBox
    var secondImpulse: VectorBox {
      .init(x: -firstImpulse.x, y: -firstImpulse.y, z: -firstImpulse.z)
    }

    fileprivate init(firstBefore: State, secondBefore: State,
      firstAfter: State, secondAfter: State, firstImpulse: VectorBox)
    {
      self.firstBefore = firstBefore; self.secondBefore = secondBefore
      self.firstAfter = firstAfter; self.secondAfter = secondAfter
      self.firstImpulse = firstImpulse
    }
  }

  /// Instantaneous paired normal response from BOTH retained full-tensor
  /// states. The caller must bind the genuine same-time contact point/unit
  /// normal and restitution; lower-boundary geometry records alone do not.
  /// This grants no event-time, damage, cut, native commit or remainder proof.
  static func prepareCompoundPairImpulse(_ first: State, _ second: State,
    point: VectorBox, unitNormalIntoFirst: VectorBox, restitution: Double
  ) throws -> IntervalPairContact {
    guard point.valid, unitNormalIntoFirst.valid else { throw Failure.unprovenContact }
    let rotation = orientation(second.quaternion)
    let inverse = try inverseTensor(second.representation.mass.inertiaAtCentreOfMass)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: second.worldAngularMomentum)
    let lever = point - second.centreOfMass
    let inverseMass = Interval.point(1) / Interval.point(second.representation.mass.massKilograms)
    let opposingVelocity = second.linearMomentum * inverseMass + omega.cross(lever)
    let torque = lever.cross(unitNormalIntoFirst)
    let angularResponse = angularVelocity(rotation, inverse: inverse, momentum: torque)
    let opposingEffectiveMass = inverseMass + dot(unitNormalIntoFirst, angularResponse.cross(lever))
    guard opposingVelocity.valid, opposingEffectiveMass.valid, opposingEffectiveMass.lower > 0
    else { throw Failure.unprovenContact }
    let response = try preparePointImpulse(first, point: point, unitNormal: unitNormalIntoFirst,
      opposingVelocity: opposingVelocity, opposingInverseEffectiveMass: opposingEffectiveMass,
      restitution: restitution)
    // Negation of finite represented interval endpoints is exact. Retain the
    // common impulse relation instead of inventing a second independently
    // rounded impulse or choosing a scalar/midpoint for either endpoint.
    let opposite = VectorBox(x: -response.compoundImpulse.x,
      y: -response.compoundImpulse.y, z: -response.compoundImpulse.z)
    let changedSecond = try applyingImpulse(second, impulse: opposite, point: point)
    return .init(firstBefore: first, secondBefore: second,
      firstAfter: response.state, secondAfter: changedSecond, firstImpulse: response.compoundImpulse)
  }

  /// Common source-vector rotation for a retained mathematical State. The
  /// caller still binds the actual source facet/unit normal and native time.
  static func stateWorldVector(_ state: State, sourceVector: VectorBox) throws -> VectorBox {
    guard sourceVector.valid else { throw Failure.unprovenContact }
    let result = apply(orientation(state.quaternion), sourceVector)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }

  /// Torque-free instantaneous material acceleration, with no contact force
  /// applied. This is NOT a finite-time contact or constrained-motion curve.
  static func stateFreePointAcceleration(_ state: State, point: VectorBox) throws -> VectorBox {
    guard point.valid else { throw Failure.unprovenContact }
    let rotation = orientation(state.quaternion)
    let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: state.worldAngularMomentum)
    let gyroscopic = omega.cross(state.worldAngularMomentum) * Interval.point(-1)
    let alpha = angularVelocity(rotation, inverse: inverse, momentum: gyroscopic)
    let lever = point - state.centreOfMass
    let result = alpha.cross(lever) + omega.cross(omega.cross(lever))
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }

  /// Acceleration at observationPoint from one unit force direction applied
  /// at applicationPoint on THIS endpoint. Full current tensor and distinct
  /// lever arms are retained; coupled contact rows sum both endpoint signs.
  static func statePointForceResponse(_ state: State, applicationPoint: VectorBox,
    forceDirection: VectorBox, observationPoint: VectorBox) throws -> VectorBox
  {
    guard applicationPoint.valid, forceDirection.valid, observationPoint.valid
    else { throw Failure.unprovenContact }
    let rotation = orientation(state.quaternion)
    let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
    let torque = (applicationPoint - state.centreOfMass).cross(forceDirection)
    let alpha = angularVelocity(rotation, inverse: inverse, momentum: torque)
    let translation = forceDirection * (Interval.point(1) / Interval.point(state.representation.mass.massKilograms))
    let result = translation + alpha.cross(observationPoint - state.centreOfMass)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }

  private static func dot(_ a: VectorBox, _ b: VectorBox) -> Interval {
    a.x * b.x + a.y * b.y + a.z * b.z
  }

  private static func orientation(_ q: QuaternionBox) -> [Interval] {
    guard q.valid else { return Array(repeating: .invalid, count: 9) }
    let w = q.components[0], x = q.components[1], y = q.components[2], z = q.components[3]
    let one = Interval.point(1), two = Interval.point(2)
    return [one - two * (y * y + z * z), two * (x * y - w * z), two * (x * z + w * y),
      two * (x * y + w * z), one - two * (x * x + z * z), two * (y * z - w * x),
      two * (x * z - w * y), two * (y * z + w * x), one - two * (x * x + y * y)]
  }

  private static func apply(_ matrix: [Interval], _ vector: VectorBox) -> VectorBox {
    .init(x: matrix[0] * vector.x + matrix[1] * vector.y + matrix[2] * vector.z,
      y: matrix[3] * vector.x + matrix[4] * vector.y + matrix[5] * vector.z,
      z: matrix[6] * vector.x + matrix[7] * vector.y + matrix[8] * vector.z)
  }

  private static func angularVelocity(_ r: [Interval], inverse: [Interval], momentum: VectorBox) -> VectorBox {
    let transpose = [r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8]]
    return apply(r, apply(inverse, apply(transpose, momentum)))
  }

  private static func field(_ q: QuaternionBox, inverse: [Interval], momentum: VectorBox) -> QuaternionBox {
    guard q.valid else { return .init(components: Array(repeating: .invalid, count: 4)) }
    let omega = angularVelocity(orientation(q), inverse: inverse, momentum: momentum)
    let w = q.components[0], x = q.components[1], y = q.components[2], z = q.components[3]
    let half = Interval.point(0.5)
    return .init(components: [-(omega.x * x + omega.y * y + omega.z * z) * half,
      (omega.x * w + omega.y * z - omega.z * y) * half,
      (omega.y * w + omega.z * x - omega.x * z) * half,
      (omega.z * w + omega.x * y - omega.y * x) * half])
  }

  private static func lipschitz(_ q: QuaternionBox, inverse: [Interval], momentum: VectorBox) -> Interval {
    guard q.valid else { return .invalid }
    let magnitude = q.components.map(\.magnitude).max() ?? .infinity
    var inverseNorm = 0.0
    for row in 0..<3 {
      let sum = inverse[(row * 3)..<(row * 3 + 3)].reduce(Interval.point(0)) { $0 + Interval.point($1.magnitude) }
      guard sum.valid else { return .invalid }
      inverseNorm = max(inverseNorm, sum.upper)
    }
    let qMax = Interval.point(magnitude)
    let a = Interval.point(1) + Interval.point(4) * qMax * qMax
    let scale = Interval.point(inverseNorm) * Interval.point(momentum.values.map(\.magnitude).max() ?? .infinity)
    let w = Interval.point(9) * a * a * scale
    let d = Interval.point(144) * qMax * a * scale
    return Interval.point(6) * (d * qMax + w)
  }

  private static func inverseTensor(_ tensor: NativeC01InquiryCompoundMassProperties.Tensor) throws -> [Interval] {
    guard tensor.finitePositiveDefinite else { throw Failure.singularTensor }
    let xx = Interval.point(tensor.xx), yy = Interval.point(tensor.yy), zz = Interval.point(tensor.zz)
    let xy = Interval.point(tensor.xy), xz = Interval.point(tensor.xz), yz = Interval.point(tensor.yz)
    let a = yy * zz - yz * yz, b = xz * yz - xy * zz, c = xy * yz - xz * yy
    let d = xx * zz - xz * xz, e = xy * xz - xx * yz, f = xx * yy - xy * xy
    let determinant = xx * a + xy * b + xz * c
    guard determinant.valid, determinant.lower > 0 else { throw Failure.singularTensor }
    let result = [a, b, c, b, d, e, c, e, f].map { $0 / determinant }
    guard result.allSatisfy(\.valid) else { throw Failure.singularTensor }
    return result
  }
}


extension NativeC01InquiryCompoundValidatedCurve {

  static func prepareSeed(representation: NativeC01InquiryCompoundRepresentation,
    rawQuaternion: [Double], centreOfMass: Vector3, linearMomentum: Vector3,
    worldAngularMomentum: Vector3, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<State> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      guard rawQuaternion.count == 4 else { throw Failure.invalidSeed }
      // Actual fixed source finite/map/reduce/normalize/validity passes.
      for _ in 0..<5 { try meter.records(4, .curveSetup) }
      try meter.records(9, .curveSetup)
      try meter.records(9, .curveSetup)
      try meter.records(1, .curveSetup)
      return try seed(representation: representation, rawQuaternion: rawQuaternion,
        centreOfMass: centreOfMass, linearMomentum: linearMomentum,
        worldAngularMomentum: worldAngularMomentum)
    }
  }

  private static func c01ReserveInverseSetup(_ meter: NativeC01InquiryPreparationWork.Meter) throws {
    try meter.records(8, .curveSetup) // tensor finite/minor/determinant predicates
    try meter.records(6, .curveSetup) // represented tensor coefficients
    try meter.records(6, .curveSetup) // fixed cofactor records
    try meter.records(1, .curveSetup) // determinant record
    try meter.records(9, .curveSetup) // normalized inverse coefficient map
    try meter.records(9, .curveSetup) // inverse validity predicates
  }

  /// Selected source representation was actually prepared in the retained
  /// atlas. Do not repeat raw unmetered Shape.make during component transfer.
  static func c01Component(_ parent: State, representation selected: NativeC01InquiryCompoundRepresentation,
    meter: NativeC01InquiryPreparationWork.Meter) throws -> State
  {
    try meter.node(.curveSetup)
    try meter.records(parent.representation.mass.parts.count * selected.mass.parts.count, .curveSetup)
    guard !selected.mass.parts.isEmpty,
      selected.mass.parts.allSatisfy({ part in parent.representation.mass.parts.contains { $0.kind == part.kind } })
    else { throw Failure.invalidSeed }
    try meter.records(9, .curveSetup)
    let rotation = orientation(parent.quaternion)
    try c01ReserveInverseSetup(meter)
    let inverse = try inverseTensor(parent.representation.mass.inertiaAtCentreOfMass)
    try meter.records(9, .curveSetup)
    try meter.records(9, .curveSetup)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: parent.worldAngularMomentum)
    try meter.records(3, .curveSetup)
    try meter.records(3, .curveSetup)
    let lever = apply(rotation, sourceCOMDifference(
      from: parent.representation.mass.centreOfMassSource, to: selected.mass.centreOfMassSource))
    try meter.records(9, .curveSetup)
    let velocity = parent.linearMomentum * (Interval.point(1) / Interval.point(parent.representation.mass.massKilograms))
      + omega.cross(lever)
    let i = selected.mass.inertiaAtCentreOfMass
    try meter.records(9, .curveSetup)
    let matrix = [i.xx, i.xy, i.xz, i.xy, i.yy, i.yz, i.xz, i.yz, i.zz].map(Interval.point)
    try meter.records(9, .curveSetup)
    let transpose = [rotation[0], rotation[3], rotation[6], rotation[1], rotation[4], rotation[7],
      rotation[2], rotation[5], rotation[8]]
    try meter.records(9, .curveSetup)
    let spin = apply(rotation, apply(matrix, apply(transpose, omega)))
    try meter.records(3, .curveSetup)
    let centre = parent.centreOfMass + lever
    try meter.records(3, .curveSetup)
    let momentum = velocity * Interval.point(selected.mass.massKilograms)
    try meter.records(9, .curveSetup)
    guard centre.valid, momentum.valid, spin.valid else { throw Failure.nonfiniteEnclosure }
    return .init(representation: selected, quaternion: parent.quaternion, centreOfMass: centre,
      linearMomentum: momentum, worldAngularMomentum: spin)
  }


  enum CurvePreparationOutcome: Sendable {
    case prepared(Curve, NativeC01InquiryPreparationWork.Report)
    case refused(NativeC01InquiryPreparationWork.Failure, Work, NativeC01InquiryPreparationWork.Report)
  }

  private struct C01PreparationSegment { let start: Double; let end: Double; let depth: Int }

  /// Actual supplied remaining ODE allowances; every failure carries its REAL
  /// partial attempts/splits/cells plus cumulative setup report. No zero-work
  /// fiction, allowance reset or input/refinement double charge is introduced.
  static func prepareMeasured(_ initial: State, duration: Double, budget: WorkBudget,
    maximumCellDuration: Double, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> CurvePreparationOutcome {
    var attempts = 0
    var splits = 0
    var retainedCells = 0
    let outcome: NativeC01InquiryPreparationWork.Outcome<Curve> = NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      guard duration.isFinite, duration > 0, duration <= 0.1,
        maximumCellDuration.isFinite, maximumCellDuration > 0, maximumCellDuration <= duration
      else { throw Failure.invalidDuration }
      guard budget.cellAttempts > 0, budget.cellAttempts < Int.max,
        budget.subdivisionDepth >= 0, budget.subdivisionDepth < Int.max,
        budget.retainedCells > 0, budget.retainedCells < Int.max else { throw Failure.invalidBudget }
      try meter.records(4, .curveSetup)
      try meter.records(9, .curveSetup)
      guard initial.quaternion.valid, initial.centreOfMass.valid,
        initial.linearMomentum.valid, initial.worldAngularMomentum.valid else { throw Failure.invalidSeed }
      try c01ReserveInverseSetup(meter)
      let inverse = try inverseTensor(initial.representation.mass.inertiaAtCentreOfMass)
      var pending = [C01PreparationSegment(start: 0, end: duration, depth: 0)]
      var quaternion = initial.quaternion
      var cells: [Cell] = []
      while let segment = pending.popLast() {
        guard attempts < budget.cellAttempts else { throw Failure.workExhausted }
        attempts += 1
        let difference = segment.end - segment.start
        let h = Interval(lower: max(0, difference.nextDown), upper: difference.nextUp)
        guard h.valid, h.upper > 0 else { throw Failure.nonfiniteEnclosure }
        let time = Interval(lower: 0, upper: h.upper)
        let firstDerivative = field(quaternion, inverse: inverse, momentum: initial.worldAngularMomentum)
        let candidate = quaternion.offset(firstDerivative, by: time).inflated()
        let derivative = field(candidate, inverse: inverse, momentum: initial.worldAngularMomentum)
        let image = quaternion.offset(derivative, by: time)
        let contraction = Interval.point(h.upper) * lipschitz(candidate, inverse: inverse,
          momentum: initial.worldAngularMomentum)
        if difference <= maximumCellDuration,
          candidate.strictlyContains(image), contraction.valid, contraction.upper < 1
        {
          let next = quaternion.offset(derivative, by: h)
          let rotation = orientation(candidate)
          let omega = angularVelocity(rotation, inverse: inverse, momentum: initial.worldAngularMomentum)
          guard next.valid, rotation.allSatisfy(\.valid), omega.valid else { throw Failure.nonfiniteEnclosure }
          guard cells.count < budget.retainedCells else { throw Failure.cellCapacity }
          cells.append(.init(start: segment.start, end: segment.end, quaternion: candidate,
            orientation: rotation, angularVelocity: omega))
          retainedCells = cells.count
          quaternion = next
        } else {
          guard segment.depth < budget.subdivisionDepth else { throw Failure.subdivisionExhausted }
          let middle = segment.start + difference * 0.5
          guard middle > segment.start, middle < segment.end else { throw Failure.subdivisionExhausted }
          splits += 1
          pending.append(.init(start: middle, end: segment.end, depth: segment.depth + 1))
          pending.append(.init(start: segment.start, end: middle, depth: segment.depth + 1))
        }
      }
      try meter.records(3, .curveSetup)
      let mass = Interval.point(initial.representation.mass.massKilograms)
      let centre = initial.centreOfMass + initial.linearMomentum * (Interval.point(duration) / mass)
      guard centre.valid else { throw Failure.nonfiniteEnclosure }
      try meter.records(1, .curveSetup)
      let endpoint = State(representation: initial.representation, quaternion: quaternion, centreOfMass: centre,
        linearMomentum: initial.linearMomentum, worldAngularMomentum: initial.worldAngularMomentum)
      try meter.records(1, .curveSetup)
      return .init(initial: initial, endpoint: endpoint, duration: duration,
        work: .init(cellAttempts: attempts, splits: splits, retainedCells: cells.count), cells: cells)
    }

    switch outcome {
    case .prepared(let curve, let report): return .prepared(curve, report)
    case .refused(let failure, let report):
      return .refused(failure, .init(cellAttempts: attempts, splits: splits, retainedCells: retainedCells), report)
    }
  }

}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Instantaneous external wrench correction to the SAME free acceleration.
  /// Torque is WORLD torque about this current COM, excluding the unknown
  /// contact forces being solved. G1 binds actual sources/units/time; these
  /// boxes grant no force-free or held-wrench finite-time motion window.
  static func statePointAcceleration(_ state: State, point: VectorBox,
    worldForce: VectorBox, worldTorqueAtCOM: VectorBox) throws -> VectorBox
  {
    guard worldForce.valid, worldTorqueAtCOM.valid else { throw Failure.unprovenContact }
    let free = try stateFreePointAcceleration(state, point: point)
    let rotation = orientation(state.quaternion)
    let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
    let alpha = angularVelocity(rotation, inverse: inverse, momentum: worldTorqueAtCOM)
    let translation = worldForce * (Interval.point(1) / Interval.point(state.representation.mass.massKilograms))
    let result = free + translation + alpha.cross(point - state.centreOfMass)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// A defined real unit rotation projected from the represented native basis.
  /// It neither replaces that basis nor asserts exact orthogonality of it.
  struct NativeFrameProjection: Sendable {
    let nativeSourceFrame: ShipPose
    let quaternion: QuaternionBox
    let rotation: [Interval]
    let rotationMinusNativeBasis: [Interval]
    let selectedComponent: Int

    fileprivate init(nativeSourceFrame: ShipPose, quaternion: QuaternionBox,
      rotation: [Interval], rotationMinusNativeBasis: [Interval], selectedComponent: Int)
    {
      self.nativeSourceFrame = nativeSourceFrame; self.quaternion = quaternion
      self.rotation = rotation; self.rotationMinusNativeBasis = rotationMinusNativeBasis
      self.selectedComponent = selectedComponent
    }
  }

  struct NativeFrameMaterialPoint: Sendable {
    let projectedPosition: VectorBox
    let representedNativePosition: Vector3
    let projectedMinusNative: VectorBox
  }

  /// Source-origin frame only. Actual staged recipe velocity/spin conventions,
  /// compound COM/P/L, units and native registration remain the G1 producer's
  /// input contract. No State or future Curve is manufactured here.
  static func prepareNativeFrameProjection(_ frame: ShipPose,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<NativeFrameProjection> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      // Native predicates: position3, basis finite9, lengths3, dot products3.
      try meter.records(18, .curveSetup)
      guard frame.position.finite, frame.orientation.validRotation else { throw Failure.invalidSeed }
      let basis = frame.orientation
      try meter.records(9, .curveSetup)
      let b = [basis.x.x, basis.y.x, basis.z.x,
        basis.x.y, basis.y.y, basis.z.y, basis.x.z, basis.y.z, basis.z.z].map(Interval.point)
      // validRotation is approximate and does not exclude reflection. Require
      // a strictly positive REAL determinant, without adding a tolerance.
      try meter.records(3, .curveSetup)
      let c0 = b[4] * b[8] - b[5] * b[7]
      let c1 = b[3] * b[8] - b[5] * b[6]
      let c2 = b[3] * b[7] - b[4] * b[6]
      try meter.records(1, .curveSetup)
      let determinant = b[0] * c0 - b[1] * c1 + b[2] * c2
      try meter.records(1, .curveSetup)
      guard determinant.valid, determinant.lower > 0 else { throw Failure.invalidSeed }
      let one = Interval.point(1)
      try meter.records(4, .curveSetup)
      let candidates = [one + b[0] + b[4] + b[8], one + b[0] - b[4] - b[8],
        one - b[0] + b[4] - b[8], one - b[0] - b[4] + b[8]]
      var selected = 0
      for index in candidates.indices {
        try meter.records(1, .curveSetup)
        guard candidates[index].valid else { throw Failure.nonfiniteEnclosure }
        try meter.records(1, .curveSetup)
        if candidates[index].lower > candidates[selected].lower { selected = index }
      }
      try meter.records(1, .curveSetup)
      guard candidates[selected].lower > 0 else { throw Failure.invalidSeed }
      // Exact rotation identities in the solver's scalar-first Hamilton
      // convention define this projection even when the native basis is only
      // approximately orthonormal. All additions/subtractions stay enclosed.
      try meter.records(4, .curveSetup)
      let raw: [Interval]
      switch selected {
      case 0: raw = [candidates[0], b[7] - b[5], b[2] - b[6], b[3] - b[1]]
      case 1: raw = [b[7] - b[5], candidates[1], b[1] + b[3], b[2] + b[6]]
      case 2: raw = [b[2] - b[6], b[1] + b[3], candidates[2], b[5] + b[7]]
      default: raw = [b[3] - b[1], b[2] + b[6], b[5] + b[7], candidates[3]]
      }
      var squaredNorm = Interval.point(0)
      for value in raw {
        try meter.records(1, .curveSetup)
        squaredNorm = squaredNorm + value * value
      }
      try meter.records(1, .curveSetup)
      guard squaredNorm.valid, squaredNorm.lower > 0 else { throw Failure.invalidSeed }
      try meter.records(1, .curveSetup)
      let norm = squaredNorm.squareRoot()
      var components: [Interval] = []
      for value in raw {
        try meter.records(1, .curveSetup)
        components.append(value / norm)
      }
      try meter.records(4, .curveSetup)
      let quaternion = QuaternionBox(components: components)
      guard quaternion.valid else { throw Failure.nonfiniteEnclosure }
      try meter.records(9, .curveSetup)
      let rotation = orientation(quaternion)
      var difference: [Interval] = []
      for index in rotation.indices {
        try meter.records(1, .curveSetup)
        difference.append(rotation[index] - b[index])
        try meter.records(1, .curveSetup)
        guard rotation[index].valid, difference[index].valid else { throw Failure.nonfiniteEnclosure }
      }
      try meter.records(1, .curveSetup)
      return .init(nativeSourceFrame: frame, quaternion: quaternion, rotation: rotation,
        rotationMinusNativeBasis: difference, selectedComponent: selected)
    }
  }

  /// Relation for a represented SOURCE-origin point, not a guessed part COM or
  /// independently rounded atlas vertex. Native systemPoint is evaluated with
  /// its actual operation graph and compared to the real projected position.
  static func prepareNativeFrameMaterialPoint(_ projection: NativeFrameProjection,
    sourcePoint: Vector3, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<NativeFrameMaterialPoint> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(3, .curveSetup)
      guard sourcePoint.finite else { throw Failure.invalidSeed }
      try meter.records(3, .curveSetup)
      let local = VectorBox.point(sourcePoint)
      try meter.records(9, .curveSetup)
      let lever = apply(projection.rotation, local)
      try meter.records(3, .curveSetup)
      let origin = VectorBox.point(projection.nativeSourceFrame.position)
      try meter.records(3, .curveSetup)
      let projected = origin + lever
      // Native graph: three vector scale records (9 coordinates), two vector
      // sums (6 coordinates), then source-origin addition (3 coordinates).
      try meter.records(18, .curveSetup)
      let native = projection.nativeSourceFrame.systemPoint(sourcePoint)
      try meter.records(3, .curveSetup)
      let nativePoint = VectorBox.point(native)
      try meter.records(3, .curveSetup)
      let difference = projected - nativePoint
      try meter.records(9, .curveSetup)
      guard projected.valid, native.finite, difference.valid else { throw Failure.nonfiniteEnclosure }
      try meter.records(1, .curveSetup)
      return .init(projectedPosition: projected, representedNativePosition: native,
        projectedMinusNative: difference)
    }
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  struct BirthRecipeMaterialPoint: Sendable {
    let role: NativeC01InquiryFixtureGeometry.Part
    let recipeVertex: Int
    let atlasVertex: Int
    let projectedPosition: VectorBox
    let representedRecipePosition: Vector3
    let projectedMinusRecipe: VectorBox
  }

  /// Mathematical initial-state candidate, never an authenticated host motion,
  /// staged birth, installed native material owner or positive permission.
  struct TranslatedBirthSeed: Sendable {
    let state: State
    let materialView: NativeC01InquiryCompoundMaterialAtlas.View
    let frameProjection: NativeFrameProjection
    let nativeCOMShadow: ShipPose
    let actualRecipes: [NativeC01InquiryFixturePhysicalAdmission.Part]
    let materialPoints: [BirthRecipeMaterialPoint]

    fileprivate init(state: State, materialView: NativeC01InquiryCompoundMaterialAtlas.View,
      frameProjection: NativeFrameProjection, nativeCOMShadow: ShipPose,
      actualRecipes: [NativeC01InquiryFixturePhysicalAdmission.Part], materialPoints: [BirthRecipeMaterialPoint])
    {
      self.state = state; self.materialView = materialView; self.frameProjection = frameProjection
      self.nativeCOMShadow = nativeCOMShadow; self.actualRecipes = actualRecipes
      self.materialPoints = materialPoints
    }
  }

  enum TranslatedBirthPreparationOutcome: Sendable {
    /// Actual ordered stage reports; caller retains each once, never re-debits.
    case prepared(TranslatedBirthSeed, [NativeC01InquiryPreparationWork.Report])
    case refused(NativeC01InquiryPreparationWork.Failure, [NativeC01InquiryPreparationWork.Report])
  }

  /// Root's NEW initial recipe: all four actual model origins translate with
  /// the same explicitly prescribed world velocity and exactly ZERO world
  /// spin. G1 must supply genuine current host motion; unknown is refusal.
  /// This does not infer compatibility from existing finite-only staging.
  static func prepareTranslatedBirth(sourceFrame: ShipPose,
    recipes: [NativeC01InquiryFixturePhysicalAdmission.Part],
    materialView: NativeC01InquiryCompoundMaterialAtlas.View,
    prescribedWorldTranslation: Vector3, metricRevision: String, metresPerWorldUnit: Double,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> TranslatedBirthPreparationOutcome {
    let projection: NativeFrameProjection
    let frameReport: NativeC01InquiryPreparationWork.Report
    switch prepareNativeFrameProjection(sourceFrame, work: &work) {
    case .prepared(let value, let report): projection = value; frameReport = report
    case .refused(let failure, let report): return .refused(failure, [report])
    }
    let result: NativeC01InquiryPreparationWork.Outcome<TranslatedBirthSeed> =
      NativeC01InquiryPreparationWork.perform(work: &work) { meter in
        let shape = materialView.representation
        let mass = shape.mass
        try meter.records(8, .curveSetup)
        guard recipes.count == 4, mass.parts.count == 4,
          metricRevision == NativeC01InquiryFixtureGeometry.metricRevision,
          metricRevision == "c01-inquiry-project-metres-v1",
          metresPerWorldUnit == NativeC01InquiryFixtureGeometry.metresPerWorldUnit,
          metresPerWorldUnit == 1,
          materialView.atlas.ancestorCOMSource == mass.centreOfMassSource,
          materialView.atlas.sourceVertexKeys.count == materialView.atlas.vertices.count
        else { throw Failure.invalidSeed }
        try meter.records(3, .curveSetup)
        guard prescribedWorldTranslation.finite else { throw Failure.invalidSeed }
        let roles: [NativeC01InquiryFixtureGeometry.Part] = [.support, .head0, .head1, .head2]
        for index in roles.indices {
          try meter.records(2, .curveSetup)
          guard recipes[index].kind == roles[index], mass.parts[index].kind == roles[index]
          else { throw Failure.invalidSeed }
          try c01ValidateTranslatedRecipe(recipes[index], mass: mass.parts[index],
            frame: sourceFrame, translation: prescribedWorldTranslation, meter: meter)
        }
        try meter.records(8, .curveSetup)
        guard mass.inertiaAtCentreOfMass.finitePositiveDefinite else { throw Failure.singularTensor }
        try meter.records(5, .curveSetup)
        guard mass.massKilograms.isFinite, mass.massKilograms > 0,
          mass.centreOfMassSource.finite else { throw Failure.invalidSeed }
        try meter.records(3, .curveSetup)
        let sourceCOM = VectorBox.point(mass.centreOfMassSource)
        try meter.records(9, .curveSetup)
        let lever = apply(projection.rotation, sourceCOM)
        try meter.records(3, .curveSetup)
        let origin = VectorBox.point(sourceFrame.position)
        try meter.records(3, .curveSetup)
        let centre = origin + lever
        try meter.records(3, .curveSetup)
        let velocity = VectorBox.point(prescribedWorldTranslation)
        try meter.records(3, .curveSetup)
        let momentum = velocity * Interval.point(mass.massKilograms)
        // At explicit world omega=0 every part COM has its actual model-origin
        // velocity, including parts whose source structural COM is offset.
        // Common translation contributes no angular momentum about the COM.
        try meter.records(3, .curveSetup)
        let spin = VectorBox.point(.init(0, 0, 0))
        try meter.records(6, .curveSetup)
        guard centre.valid, momentum.valid else { throw Failure.nonfiniteEnclosure }
        try meter.records(1, .curveSetup)
        let state = State(representation: shape, quaternion: projection.quaternion,
          centreOfMass: centre, linearMomentum: momentum, worldAngularMomentum: spin)
        try meter.records(18, .curveSetup)
        let nativeCOM = sourceFrame.systemPoint(mass.centreOfMassSource)
        try meter.records(3, .curveSetup)
        guard nativeCOM.finite else { throw Failure.nonfiniteEnclosure }
        try meter.records(1, .curveSetup)
        var shadow = sourceFrame; shadow.position = nativeCOM
        var points: [BirthRecipeMaterialPoint] = []
        for recipe in recipes {
          // The exact descriptor was validated above. Charge its actual
          // accessor record again; no new raw source mass/mesh construction.
          try meter.records(1, .curveSetup)
          let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: recipe.kind)
          for index in recipe.mesh.vertices.indices {
            let relation = try c01BirthMaterialPoint(recipe, vertex: index,
              descriptorCentre: descriptor.centreNative, state: state,
              projection: projection, atlas: materialView.atlas, meter: meter)
            try meter.records(1, .curveSetup)
            points.append(relation)
          }
        }
        try meter.records(1, .curveSetup)
        return .init(state: state, materialView: materialView, frameProjection: projection,
          nativeCOMShadow: shadow, actualRecipes: recipes, materialPoints: points)
      }
    switch result {
    case .prepared(let seed, let report): return .prepared(seed, [frameReport, report])
    case .refused(let failure, let report): return .refused(failure, [frameReport, report])
    }
  }

  private static func c01ValidateTranslatedRecipe(_ recipe: NativeC01InquiryFixturePhysicalAdmission.Part,
    mass: NativeC01InquiryCompoundMassProperties.Part, frame: ShipPose, translation: Vector3,
    meter: NativeC01InquiryPreparationWork.Meter) throws
  {
    try meter.records(2, .curveSetup)
    guard recipe.mesh.vertices.count == 8, recipe.mesh.faces.count == 6 else { throw Failure.invalidSeed }
    // Exact lazy descriptor source: eight vertex literals and native vertex
    // conversions, six face headers/24 indices, one native centre conversion,
    // fixed Descriptor/Mesh records (preserveWinding early-return path).
    try meter.records(8 + 8 + 6 + 24 + 1 + 2, .curveSetup)
    let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: recipe.kind)
    try meter.records(1, .curveSetup)
    let budget = NativeC01InquiryFixtureGeometry.physicalBudget(for: recipe.kind)
    try meter.records(3, .curveSetup)
    guard recipe.massKilograms == mass.massKilograms,
      recipe.massKilograms == budget.massKilograms, recipe.maximumEnergy == budget.energy
    else { throw Failure.invalidSeed }
    for index in recipe.mesh.vertices.indices {
      try meter.records(3, .curveSetup)
      guard recipe.mesh.vertices[index] == descriptor.mesh.vertices[index] else { throw Failure.invalidSeed }
    }
    for index in recipe.mesh.faces.indices {
      try meter.records(1, .curveSetup)
      guard recipe.mesh.faces[index].count == descriptor.mesh.faces[index].count else { throw Failure.invalidSeed }
      for corner in recipe.mesh.faces[index].indices {
        try meter.records(1, .curveSetup)
        guard recipe.mesh.faces[index][corner] == descriptor.mesh.faces[index][corner] else { throw Failure.invalidSeed }
      }
    }
    try meter.records(18, .curveSetup)
    let expectedOrigin = frame.systemPoint(descriptor.centreNative)
    try meter.records(3 + 9 + 3 + 3, .curveSetup)
    guard recipe.pose.position == expectedOrigin, recipe.pose.orientation == frame.orientation,
      recipe.velocity == translation, recipe.angularVelocity == .init(0, 0, 0)
    else { throw Failure.invalidSeed }
  }

  private static func c01BirthMaterialPoint(_ recipe: NativeC01InquiryFixturePhysicalAdmission.Part,
    vertex: Int, descriptorCentre: Vector3, state: State, projection: NativeFrameProjection,
    atlas: NativeC01InquiryCompoundMaterialAtlas, meter: NativeC01InquiryPreparationWork.Meter
  ) throws -> BirthRecipeMaterialPoint {
    let local = recipe.mesh.vertices[vertex]
    try meter.records(3, .curveSetup)
    let sourceKey = descriptorCentre + local
    var found: Int?
    for index in atlas.sourceVertexKeys.indices {
      try meter.records(3, .curveSetup)
      if atlas.sourceVertexKeys[index] == sourceKey { found = index; break }
    }
    guard let atlasVertex = found else { throw Failure.invalidSeed }
    try meter.records(3, .curveSetup)
    let actualMaterialPoint = VectorBox.point(atlas.vertices[atlasVertex])
    try meter.records(9, .curveSetup)
    let lever = apply(projection.rotation, actualMaterialPoint)
    try meter.records(3, .curveSetup)
    let projected = state.centreOfMass + lever
    try meter.records(18, .curveSetup)
    let native = recipe.pose.systemPoint(local)
    try meter.records(3, .curveSetup)
    let nativePoint = VectorBox.point(native)
    try meter.records(3, .curveSetup)
    let difference = projected - nativePoint
    try meter.records(9, .curveSetup)
    guard projected.valid, native.finite, difference.valid else { throw Failure.nonfiniteEnclosure }
    try meter.records(1, .curveSetup)
    return .init(role: recipe.kind, recipeVertex: vertex, atlasVertex: atlasVertex,
      projectedPosition: projected, representedRecipePosition: native, projectedMinusRecipe: difference)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Full thirteen-component state derivative for one supplied force range.
  /// A range evaluation alone certifies neither its source nor a time window.
  struct ConstrainedBodyField: Sendable {
    let state: State
    let rotation: [Interval]
    let worldAngularVelocity: VectorBox
    let worldAngularAcceleration: VectorBox
    let quaternionDerivative: QuaternionBox
    let centreDerivative: VectorBox
    let linearMomentumDerivative: VectorBox
    let angularMomentumDerivative: VectorBox
    fileprivate let inverseBodyTensor: [Interval]

    fileprivate init(state: State, rotation: [Interval], inverse: [Interval], omega: VectorBox,
      alpha: VectorBox, qDot: QuaternionBox, cDot: VectorBox, force: VectorBox, torque: VectorBox)
    {
      self.state = state; self.rotation = rotation; inverseBodyTensor = inverse
      worldAngularVelocity = omega; worldAngularAcceleration = alpha
      quaternionDerivative = qDot; centreDerivative = cDot
      linearMomentumDerivative = force; angularMomentumDerivative = torque
    }
  }

  struct AcceleratedMaterialPoint: Sendable {
    let position: VectorBox
    let velocity: VectorBox
    let acceleration: VectorBox
  }

  /// Evaluates the body field over the supplied state/force boxes. Caller must
  /// supply ranges of the SAME actual law over the SAME whole candidate cell,
  /// with analytic derivatives for the later Picard uniqueness gate. No held
  /// instantaneous wrench, native authority or temporal certificate is issued.
  static func prepareConstrainedBodyField(_ state: State, worldForce: VectorBox,
    worldTorqueAtCOM: VectorBox, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedBodyField> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(19, .curveSetup)
      guard state.quaternion.valid, state.centreOfMass.valid, state.linearMomentum.valid,
        state.worldAngularMomentum.valid, worldForce.valid, worldTorqueAtCOM.valid
      else { throw Failure.invalidSeed }
      try meter.records(2, .curveSetup)
      let mass = state.representation.mass.massKilograms
      guard mass.isFinite, mass > 0 else { throw Failure.invalidSeed }
      try meter.records(9, .curveSetup)
      let rotation = orientation(state.quaternion)
      try c01ReserveInverseSetup(meter)
      let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
      // Each world inverse application uses a 9-entry transpose and three
      // actual 3-by-3 applications. These are source records, not CPU counts.
      try meter.records(9 + 9 + 9 + 9, .curveSetup)
      let omega = angularVelocity(rotation, inverse: inverse, momentum: state.worldAngularMomentum)
      try meter.records(3, .curveSetup)
      let gyroscopic = omega.cross(state.worldAngularMomentum)
      try meter.records(3, .curveSetup)
      let effectiveTorque = worldTorqueAtCOM - gyroscopic
      try meter.records(9 + 9 + 9 + 9, .curveSetup)
      let alpha = angularVelocity(rotation, inverse: inverse, momentum: effectiveTorque)
      // Reuse the unchanged quaternion field including its actual second
      // orientation/world-inverse evaluation, rather than a rounded reseed.
      try meter.records(9 + 9 + 9 + 9 + 9 + 4, .curveSetup)
      let qDot = field(state.quaternion, inverse: inverse, momentum: state.worldAngularMomentum)
      try meter.records(3, .curveSetup)
      let cDot = state.linearMomentum * (Interval.point(1) / Interval.point(mass))
      try meter.records(9 + 3 + 3 + 4 + 3, .curveSetup)
      guard rotation.allSatisfy(\.valid), omega.valid, alpha.valid, qDot.valid, cDot.valid
      else { throw Failure.nonfiniteEnclosure }
      try meter.records(1, .curveSetup)
      return .init(state: state, rotation: rotation, inverse: inverse, omega: omega,
        alpha: alpha, qDot: qDot, cDot: cDot, force: worldForce, torque: worldTorqueAtCOM)
    }
  }

  static func constrainedWorldVector(_ field: ConstrainedBodyField, local: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox
  {
    try work.reservePreparedMetadataRecords(3)
    guard local.valid else { throw Failure.invalidSeed }
    try work.reservePreparedMetadataRecords(9)
    let result = apply(field.rotation, local)
    try work.reservePreparedMetadataRecords(3)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }

  static func constrainedMaterialPoint(_ field: ConstrainedBodyField, local: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> AcceleratedMaterialPoint
  {
    let lever = try constrainedWorldVector(field, local: local, work: &work)
    try work.reservePreparedMetadataRecords(3)
    let position = field.state.centreOfMass + lever
    try work.reservePreparedMetadataRecords(3 + 3)
    let velocity = field.centreDerivative + field.worldAngularVelocity.cross(lever)
    try work.reservePreparedMetadataRecords(3)
    let translation = field.linearMomentumDerivative
      * (Interval.point(1) / Interval.point(field.state.representation.mass.massKilograms))
    try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3 + 3)
    let acceleration = translation + field.worldAngularAcceleration.cross(lever)
      + field.worldAngularVelocity.cross(field.worldAngularVelocity.cross(lever))
    try work.reservePreparedMetadataRecords(9)
    guard position.valid, velocity.valid, acceleration.valid else { throw Failure.nonfiniteEnclosure }
    try work.reservePreparedMetadataRecords(1)
    return .init(position: position, velocity: velocity, acceleration: acceleration)
  }

  /// Uses the already prepared SAME current tensor, without an unmetered
  /// repeated inverse. Distinct application/observation points are retained.
  static func constrainedPointForceResponse(_ field: ConstrainedBodyField,
    application: VectorBox, direction: VectorBox, observation: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox
  {
    try work.reservePreparedMetadataRecords(9)
    guard application.valid, direction.valid, observation.valid else { throw Failure.unprovenContact }
    try work.reservePreparedMetadataRecords(3 + 3)
    let torque = (application - field.state.centreOfMass).cross(direction)
    try work.reservePreparedMetadataRecords(9 + 9 + 9 + 9)
    let alpha = angularVelocity(field.rotation, inverse: field.inverseBodyTensor, momentum: torque)
    try work.reservePreparedMetadataRecords(3)
    let translation = direction * (Interval.point(1) / Interval.point(field.state.representation.mass.massKilograms))
    try work.reservePreparedMetadataRecords(3 + 3 + 3)
    let result = translation + alpha.cross(observation - field.state.centreOfMass)
    try work.reservePreparedMetadataRecords(3)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  struct ConstrainedBodyDifferential: Sendable {
    let field: ConstrainedBodyField
    /// Row-major, columns q4/C3/P3/L3/F3/tau3. No time column is invented.
    let fieldJacobian: [Interval] // 13 by 19
    let rotationJacobian: [Interval] // 9 by 19
    let angularVelocityJacobian: [Interval] // 3 by 19
    let angularAccelerationJacobian: [Interval] // 3 by 19

    fileprivate init(field: ConstrainedBodyField, state: [Interval], rotation: [Interval],
      omega: [Interval], alpha: [Interval])
    {
      self.field = field; fieldJacobian = state; rotationJacobian = rotation
      angularVelocityJacobian = omega; angularAccelerationJacobian = alpha
    }
  }

  /// Analytic derivative of the exact source body-field polynomial/rational
  /// extension. Total F and tau are independent inputs here. The actual
  /// external/contact law chain is still required for a full coupled Jacobian.
  static func prepareConstrainedBodyDifferential(_ value: ConstrainedBodyField,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedBodyDifferential> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      let zero = Interval.point(0), one = Interval.point(1), two = Interval.point(2), four = Interval.point(4)
      let q = value.state.quaternion.components
      let w = q[0], x = q[1], y = q[2], z = q[3]
      try meter.records(36, .curveSetup)
      // Derivatives of the unchanged source orientation polynomial. Columns
      // refer to raw current q coordinates; no sphere projection/reseed occurs.
      let dRotation = [
        [zero, -two * z, two * y, two * z, zero, -two * x, -two * y, two * x, zero],
        [zero, two * y, two * z, two * y, -four * x, -two * w, two * z, two * w, -four * x],
        [-four * y, two * x, two * w, two * x, zero, two * z, -two * w, two * z, -four * y],
        [-four * z, -two * w, two * x, two * w, -four * z, two * y, two * x, two * y, zero],
      ]
      for matrix in dRotation {
        try meter.records(9, .curveSetup)
        guard matrix.allSatisfy(\.valid) else { throw Failure.nonfiniteEnclosure }
      }
      try meter.records(13 * 19 + 9 * 19 + 3 * 19 + 3 * 19, .curveSetup)
      var stateJacobian = Array(repeating: zero, count: 13 * 19)
      var rotationJacobian = Array(repeating: zero, count: 9 * 19)
      var omegaJacobian = Array(repeating: zero, count: 3 * 19)
      var alphaJacobian = Array(repeating: zero, count: 3 * 19)
      try meter.records(3, .curveSetup)
      let zeroVector = VectorBox.point(.init(0, 0, 0))
      let omega = value.worldAngularVelocity
      let angularMomentum = value.state.worldAngularMomentum
      try meter.records(3 + 3, .curveSetup)
      let effectiveTorque = value.angularMomentumDerivative - omega.cross(angularMomentum)
      for column in 0..<19 {
        try meter.node(.curveSetup)
        let isQuaternion = column < 4
        let isMomentum = (10..<13).contains(column)
        let isTorque = (16..<19).contains(column)
        var dOmega = zeroVector
        var dAlpha = zeroVector
        var dL = zeroVector
        if isMomentum {
          try meter.records(3, .curveSetup)
          dL = c01DifferentialAxis(column - 10)
        }
        if isQuaternion {
          try meter.records(9, .curveSetup)
          for row in 0..<9 { rotationJacobian[row * 19 + column] = dRotation[column][row] }
          dOmega = try c01WorldInverseDifferential(value, derivative: dRotation[column],
            vector: angularMomentum, meter: meter)
        } else if isMomentum {
          try meter.records(9 + 9 + 9 + 9, .curveSetup)
          dOmega = angularVelocity(value.rotation, inverse: value.inverseBodyTensor, momentum: dL)
        }
        if isQuaternion || isMomentum || isTorque {
          var dTorque = zeroVector
          if isTorque {
            try meter.records(3, .curveSetup)
            dTorque = c01DifferentialAxis(column - 16)
          }
          try meter.records(3 + 3 + 3 + 3, .curveSetup)
          let dEffective = dTorque - dOmega.cross(angularMomentum) - omega.cross(dL)
          try meter.records(9 + 9 + 9 + 9, .curveSetup)
          dAlpha = angularVelocity(value.rotation, inverse: value.inverseBodyTensor, momentum: dEffective)
          if isQuaternion {
            let changedInverse = try c01WorldInverseDifferential(value, derivative: dRotation[column],
              vector: effectiveTorque, meter: meter)
            try meter.records(3, .curveSetup)
            dAlpha = dAlpha + changedInverse
          }
        }
        try meter.records(3 + 3, .curveSetup)
        guard dOmega.valid, dAlpha.valid else { throw Failure.nonfiniteEnclosure }
        try meter.records(3 + 3, .curveSetup)
        let omegaValues = dOmega.values, alphaValues = dAlpha.values
        try meter.records(3 + 3, .curveSetup)
        for row in 0..<3 {
          omegaJacobian[row * 19 + column] = omegaValues[row]
          alphaJacobian[row * 19 + column] = alphaValues[row]
        }
        if isQuaternion || isMomentum {
          try meter.records(4, .curveSetup)
          let dq = (0..<4).map { column == $0 ? one : zero }
          let half = Interval.point(0.5)
          try meter.records(4, .curveSetup)
          let derivative = [
            -(dOmega.x * x + omega.x * dq[1] + dOmega.y * y + omega.y * dq[2]
              + dOmega.z * z + omega.z * dq[3]) * half,
            (dOmega.x * w + omega.x * dq[0] + dOmega.y * z + omega.y * dq[3]
              - dOmega.z * y - omega.z * dq[2]) * half,
            (dOmega.y * w + omega.y * dq[0] + dOmega.z * x + omega.z * dq[1]
              - dOmega.x * z - omega.x * dq[3]) * half,
            (dOmega.z * w + omega.z * dq[0] + dOmega.x * y + omega.x * dq[2]
              - dOmega.y * x - omega.y * dq[1]) * half,
          ]
          try meter.records(4, .curveSetup)
          guard derivative.allSatisfy(\.valid) else { throw Failure.nonfiniteEnclosure }
          try meter.records(4, .curveSetup)
          for row in 0..<4 { stateJacobian[row * 19 + column] = derivative[row] }
        }
      }
      try meter.records(1, .curveSetup)
      let inverseMass = one / .point(value.state.representation.mass.massKilograms)
      try meter.records(1, .curveSetup)
      guard inverseMass.valid else { throw Failure.nonfiniteEnclosure }
      for coordinate in 0..<3 {
        try meter.records(3, .curveSetup)
        stateJacobian[(4 + coordinate) * 19 + 7 + coordinate] = inverseMass
        stateJacobian[(7 + coordinate) * 19 + 13 + coordinate] = one
        stateJacobian[(10 + coordinate) * 19 + 16 + coordinate] = one
      }
      try meter.records(1, .curveSetup)
      return .init(field: value, state: stateJacobian, rotation: rotationJacobian,
        omega: omegaJacobian, alpha: alphaJacobian)
    }
  }

  private static func c01DifferentialAxis(_ index: Int) -> VectorBox {
    .init(x: .point(index == 0 ? 1 : 0), y: .point(index == 1 ? 1 : 0), z: .point(index == 2 ? 1 : 0))
  }

  /// d(R I^-1 R^T)*v with the same represented body inverse. Neither v nor
  /// the original R is differentiated by this partial derivative routine.
  private static func c01WorldInverseDifferential(_ value: ConstrainedBodyField,
    derivative: [Interval], vector: VectorBox, meter: NativeC01InquiryPreparationWork.Meter
  ) throws -> VectorBox {
    let r = value.rotation
    try meter.records(9 + 9, .curveSetup)
    let rt = [r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8]]
    let dt = [derivative[0], derivative[3], derivative[6], derivative[1], derivative[4],
      derivative[7], derivative[2], derivative[5], derivative[8]]
    try meter.records(9 + 9 + 9 + 9 + 9 + 9 + 3, .curveSetup)
    let result = apply(derivative, apply(value.inverseBodyTensor, apply(rt, vector)))
      + apply(r, apply(value.inverseBodyTensor, apply(dt, vector)))
    try meter.records(3, .curveSetup)
    guard result.valid else { throw Failure.nonfiniteEnclosure }
    return result
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  struct ConstrainedRotatedVectorDifferential: Sendable {
    let body: ConstrainedBodyDifferential
    let local: VectorBox
    let value: VectorBox
    let jacobian: [Interval] // 3 by 19

    fileprivate init(body: ConstrainedBodyDifferential, local: VectorBox, value: VectorBox, jacobian: [Interval]) {
      self.body = body; self.local = local; self.value = value; self.jacobian = jacobian
    }
  }
  struct ConstrainedMaterialDifferential: Sendable {
    let body: ConstrainedBodyDifferential
    let local: VectorBox
    let value: AcceleratedMaterialPoint
    let leverJacobian: [Interval]
    let positionJacobian: [Interval]
    let velocityJacobian: [Interval]
    let accelerationJacobian: [Interval]

    fileprivate init(body: ConstrainedBodyDifferential, local: VectorBox, value: AcceleratedMaterialPoint,
      lever: [Interval], position: [Interval], velocity: [Interval], acceleration: [Interval])
    {
      self.body = body; self.local = local; self.value = value
      leverJacobian = lever; positionJacobian = position
      velocityJacobian = velocity; accelerationJacobian = acceleration
    }
  }

  /// Rotation of a FIXED local material vector and its actual q derivatives.
  /// The same primitive supplies the moving support normal's derivative.
  static func constrainedRotatedVectorDifferential(_ body: ConstrainedBodyDifferential,
    local: VectorBox, work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedRotatedVectorDifferential {
    let value = try constrainedWorldVector(body.field, local: local, work: &work)
    try work.reservePreparedMetadataRecords(3 * 19)
    var jacobian = Array(repeating: Interval.point(0), count: 3 * 19)
    for column in 0..<4 {
      try work.node()
      try work.reservePreparedMetadataRecords(9)
      let matrix = (0..<9).map { body.rotationJacobian[$0 * 19 + column] }
      try work.reservePreparedMetadataRecords(9)
      let derivative = apply(matrix, local)
      try work.reservePreparedMetadataRecords(3)
      guard derivative.valid else { throw Failure.nonfiniteEnclosure }
      try work.reservePreparedMetadataRecords(3)
      let values = derivative.values
      try work.reservePreparedMetadataRecords(3)
      for row in 0..<3 { jacobian[row * 19 + column] = values[row] }
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(body: body, local: local, value: value, jacobian: jacobian)
  }

  /// Fixed retained-atlas local point. Source mass/COM and the exact local
  /// material relation are constant inputs; native observed positions never
  /// replace them. External/contact law composition still follows this step.
  static func constrainedMaterialDifferential(_ body: ConstrainedBodyDifferential,
    local: VectorBox, work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedMaterialDifferential {
    let rotated = try constrainedRotatedVectorDifferential(body, local: local, work: &work)
    let value = try constrainedMaterialPoint(body.field, local: local, work: &work)
    let r = rotated.value, omega = body.field.worldAngularVelocity
    let alpha = body.field.worldAngularAcceleration
    try work.reservePreparedMetadataRecords(3)
    let omegaCrossLever = omega.cross(r)
    try work.reservePreparedMetadataRecords(3 * 19 * 3)
    var position = Array(repeating: Interval.point(0), count: 3 * 19)
    var velocity = Array(repeating: Interval.point(0), count: 3 * 19)
    var acceleration = Array(repeating: Interval.point(0), count: 3 * 19)
    try work.reservePreparedMetadataRecords(1)
    let inverseMass = Interval.point(1) / .point(body.field.state.representation.mass.massKilograms)
    try work.reservePreparedMetadataRecords(1)
    guard inverseMass.valid else { throw Failure.nonfiniteEnclosure }
    try work.reservePreparedMetadataRecords(3)
    let zero = VectorBox.point(.init(0, 0, 0))
    for column in 0..<19 {
      try work.node()
      var dx = zero, dv = zero, da = zero
      let isRotation = column < 4
      let isMomentum = (10..<13).contains(column)
      let isTorque = (16..<19).contains(column)
      try work.reservePreparedMetadataRecords(3)
      let dr = VectorBox(x: rotated.jacobian[column], y: rotated.jacobian[19 + column],
        z: rotated.jacobian[38 + column])
      if isRotation { dx = dr }
      if (4..<7).contains(column) {
        try work.reservePreparedMetadataRecords(3)
        dx = c01ScaledDifferentialAxis(column - 4, scale: .point(1))
      }
      if (7..<10).contains(column) {
        try work.reservePreparedMetadataRecords(3)
        dv = c01ScaledDifferentialAxis(column - 7, scale: inverseMass)
      }
      if (13..<16).contains(column) {
        try work.reservePreparedMetadataRecords(3)
        da = c01ScaledDifferentialAxis(column - 13, scale: inverseMass)
      }
      if isRotation || isMomentum || isTorque {
        try work.reservePreparedMetadataRecords(3 + 3)
        let dw = VectorBox(x: body.angularVelocityJacobian[column],
          y: body.angularVelocityJacobian[19 + column], z: body.angularVelocityJacobian[38 + column])
        let dalpha = VectorBox(x: body.angularAccelerationJacobian[column],
          y: body.angularAccelerationJacobian[19 + column], z: body.angularAccelerationJacobian[38 + column])
        if isRotation || isMomentum {
          try work.reservePreparedMetadataRecords(3 + 3 + 3)
          dv = dw.cross(r) + omega.cross(dr)
        }
        // Ten fixed vector cross/add records; differentiate both appearances
        // of omega and both appearances of the rotating material lever.
        try work.reservePreparedMetadataRecords(3 * 10)
        da = dalpha.cross(r) + alpha.cross(dr) + dw.cross(omegaCrossLever)
          + omega.cross(dw.cross(r) + omega.cross(dr))
      }
      try work.reservePreparedMetadataRecords(3 + 3 + 3)
      guard dx.valid, dv.valid, da.valid else { throw Failure.nonfiniteEnclosure }
      try work.reservePreparedMetadataRecords(3 + 3 + 3)
      let xs = dx.values, vs = dv.values, accelerations = da.values
      try work.reservePreparedMetadataRecords(3 + 3 + 3)
      for row in 0..<3 {
        position[row * 19 + column] = xs[row]
        velocity[row * 19 + column] = vs[row]
        acceleration[row * 19 + column] = accelerations[row]
      }
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(body: body, local: local, value: value, lever: rotated.jacobian,
      position: position, velocity: velocity, acceleration: acceleration)
  }

  private static func c01ScaledDifferentialAxis(_ index: Int, scale: Interval) -> VectorBox {
    .init(x: index == 0 ? scale : .point(0), y: index == 1 ? scale : .point(0), z: index == 2 ? scale : .point(0))
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  struct ConstrainedPointForceDifferential: Sendable {
    let body: ConstrainedBodyDifferential
    let component: Int
    let variables: Int
    let application: VectorBox
    let direction: VectorBox
    let observation: VectorBox
    let applicationJacobian: [Interval]
    let directionJacobian: [Interval]
    let observationJacobian: [Interval]
    let value: VectorBox
    let jacobian: [Interval]

    fileprivate init(body: ConstrainedBodyDifferential, component: Int, variables: Int,
      application: VectorBox, direction: VectorBox, observation: VectorBox,
      applicationJacobian: [Interval], directionJacobian: [Interval], observationJacobian: [Interval],
      value: VectorBox, jacobian: [Interval])
    {
      self.body = body; self.component = component; self.variables = variables
      self.application = application; self.direction = direction; self.observation = observation
      self.applicationJacobian = applicationJacobian; self.directionJacobian = directionJacobian
      self.observationJacobian = observationJacobian; self.value = value; self.jacobian = jacobian
    }
  }

  /// Analytic moving-point force response. Global columns are q/C/P/L for
  /// every component, then explicit physical time. Input point/direction
  /// matrices are conditional range DATA, not a native/source-law grant.
  static func prepareConstrainedPointForceDifferential(_ frame: ConstrainedResponseDifferentialFrame,
    component: Int, variables: Int, application: VectorBox, applicationJacobian: [Interval],
    direction: VectorBox, directionJacobian: [Interval], observation: VectorBox, observationJacobian: [Interval],
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedPointForceDifferential> {
    c01PrepareResponse(frame, component: component, variables: variables,
      geometry: .raw(.init(application: application, applicationJacobian: applicationJacobian,
        direction: direction, directionJacobian: directionJacobian,
        observation: observation, observationJacobian: observationJacobian)), work: &work)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Prepared ONCE per current component, reused by all row/column responses.
  /// Earlier actual construction work stays in the same owner ledger.
  struct ConstrainedResponseDifferentialFrame: Sendable {
    let body: ConstrainedBodyDifferential
    let worldInverse: [Interval]
    let worldInverseQuaternionDifferential: [[Interval]]

    fileprivate init(body: ConstrainedBodyDifferential, inverse: [Interval], derivative: [[Interval]]) {
      self.body = body; worldInverse = inverse; worldInverseQuaternionDifferential = derivative
    }
  }

  static func prepareConstrainedResponseDifferentialFrame(_ body: ConstrainedBodyDifferential,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedResponseDifferentialFrame> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(9, .curveSetup)
      var inverse = Array(repeating: Interval.point(0), count: 9)
      var derivatives: [[Interval]] = []
      for axis in 0..<3 {
        try meter.node(.curveSetup)
        try meter.records(3, .curveSetup)
        let vector = c01DifferentialAxis(axis)
        try meter.records(9 + 9 + 9 + 9, .curveSetup)
        let column = angularVelocity(body.field.rotation, inverse: body.field.inverseBodyTensor, momentum: vector)
        try meter.records(3, .curveSetup)
        guard column.valid else { throw Failure.nonfiniteEnclosure }
        try meter.records(3, .curveSetup)
        let values = column.values
        try meter.records(3, .curveSetup)
        for row in 0..<3 { inverse[row * 3 + axis] = values[row] }
      }
      for variable in 0..<4 {
        try meter.node(.curveSetup)
        try meter.records(9, .curveSetup)
        var derivative = Array(repeating: Interval.point(0), count: 9)
        try meter.records(9, .curveSetup)
        let dRotation = (0..<9).map { body.rotationJacobian[$0 * 19 + variable] }
        for axis in 0..<3 {
          try meter.records(3, .curveSetup)
          let vector = c01DifferentialAxis(axis)
          let column = try c01WorldInverseDifferential(body.field, derivative: dRotation, vector: vector, meter: meter)
          try meter.records(3, .curveSetup)
          let values = column.values
          try meter.records(3, .curveSetup)
          for row in 0..<3 { derivative[row * 3 + axis] = values[row] }
        }
        try meter.records(1, .curveSetup)
        derivatives.append(derivative)
      }
      try meter.records(1, .curveSetup)
      return .init(body: body, inverse: inverse, derivative: derivatives)
    }
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  private static func c01DerivativeZero(_ value: Interval) -> Bool {
    value.lower == 0 && value.upper == 0
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  private struct ResponseGeometryRaw {
    let application: VectorBox
    let applicationJacobian: [Interval]
    let direction: VectorBox
    let directionJacobian: [Interval]
    let observation: VectorBox
    let observationJacobian: [Interval]
  }
  private enum ResponseGeometryInput {
    case raw(ResponseGeometryRaw)
    case checked(ConstrainedCoupledVector, ConstrainedCoupledVector, ConstrainedCoupledVector)
  }

  private static func c01PrepareResponse(_ frame: ConstrainedResponseDifferentialFrame,
    component: Int, variables: Int, geometry: ResponseGeometryInput,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedPointForceDifferential> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      let body = frame.body
      guard component >= 0, component < 4, variables >= 14, variables <= 53,
        (variables - 1) % 13 == 0, variables >= 13 * (component + 1) + 1
      else { throw Failure.unprovenContact }
      let application: VectorBox, direction: VectorBox, observation: VectorBox
      let applicationJacobian: [Interval], directionJacobian: [Interval], observationJacobian: [Interval]
      let activeMask: UInt64?
      switch geometry {
      case .raw(let input):
        guard input.applicationJacobian.count == 3 * variables, input.directionJacobian.count == 3 * variables,
          input.observationJacobian.count == 3 * variables else { throw Failure.unprovenContact }
        try meter.records(9 + 9 * variables, .curveSetup)
        guard input.application.valid, input.direction.valid, input.observation.valid,
          input.applicationJacobian.allSatisfy(\.valid), input.directionJacobian.allSatisfy(\.valid),
          input.observationJacobian.allSatisfy(\.valid) else { throw Failure.unprovenContact }
        application = input.application; direction = input.direction; observation = input.observation
        applicationJacobian = input.applicationJacobian; directionJacobian = input.directionJacobian
        observationJacobian = input.observationJacobian; activeMask = nil
      case .checked(let a, let n, let o):
        guard a.variables == variables, n.variables == variables, o.variables == variables
        else { throw Failure.unprovenContact }
        try meter.records(10, .curveSetup)
        application = a.value; direction = n.value; observation = o.value
        applicationJacobian = a.jacobian; directionJacobian = n.jacobian; observationJacobian = o.jacobian
        activeMask = a.activeMask | n.activeMask | o.activeMask | (UInt64(0x7f) << (13 * component))
      }
      let field = body.field
      try meter.records(3 + 3 + 3, .curveSetup)
      let applicationLever = application - field.state.centreOfMass
      let observationLever = observation - field.state.centreOfMass
      let torque = applicationLever.cross(direction)
      try meter.records(9, .curveSetup)
      let alpha = apply(frame.worldInverse, torque)
      try meter.records(1, .curveSetup)
      let inverseMass = Interval.point(1) / .point(field.state.representation.mass.massKilograms)
      try meter.records(3 + 3 + 3, .curveSetup)
      let value = direction * inverseMass + alpha.cross(observationLever)
      try meter.records(3, .curveSetup)
      guard value.valid else { throw Failure.nonfiniteEnclosure }
      try meter.records(3 * variables, .curveSetup)
      var jacobian = Array(repeating: Interval.point(0), count: 3 * variables)
      for variable in 0..<variables {
        let localColumn = variable - 13 * component
        if let activeMask {
          try meter.records(1, .curveSetup)
          if activeMask & (UInt64(1) << variable) == 0 { continue }
          try meter.node(.curveSetup)
        } else {
          try meter.node(.curveSetup)
          try meter.records(9, .curveSetup)
          let independentGeometryIsZero = c01DerivativeZero(applicationJacobian[variable])
            && c01DerivativeZero(applicationJacobian[variables + variable])
            && c01DerivativeZero(applicationJacobian[2 * variables + variable])
            && c01DerivativeZero(directionJacobian[variable])
            && c01DerivativeZero(directionJacobian[variables + variable])
            && c01DerivativeZero(directionJacobian[2 * variables + variable])
            && c01DerivativeZero(observationJacobian[variable])
            && c01DerivativeZero(observationJacobian[variables + variable])
            && c01DerivativeZero(observationJacobian[2 * variables + variable])
          if !(0..<7).contains(localColumn) && independentGeometryIsZero { continue }
        }
        try meter.records(9, .curveSetup)
        let da = VectorBox(x: applicationJacobian[variable], y: applicationJacobian[variables + variable],
          z: applicationJacobian[2 * variables + variable])
        let dn = VectorBox(x: directionJacobian[variable], y: directionJacobian[variables + variable],
          z: directionJacobian[2 * variables + variable])
        let dObservation = VectorBox(x: observationJacobian[variable], y: observationJacobian[variables + variable],
          z: observationJacobian[2 * variables + variable])
        try meter.records(3, .curveSetup)
        var dCentre = VectorBox.point(.init(0, 0, 0))
        if (4..<7).contains(localColumn) {
          try meter.records(3, .curveSetup)
          dCentre = c01DifferentialAxis(localColumn - 4)
        }
        try meter.records(3 + 3 + 3 + 3, .curveSetup)
        let dTorque = (da - dCentre).cross(direction) + applicationLever.cross(dn)
        try meter.records(9, .curveSetup)
        var dAlpha = apply(frame.worldInverse, dTorque)
        if (0..<4).contains(localColumn) {
          try meter.records(1, .curveSetup)
          let derivative = frame.worldInverseQuaternionDifferential[localColumn]
          try meter.records(9, .curveSetup)
          let changedInverse = apply(derivative, torque)
          try meter.records(3, .curveSetup)
          dAlpha = dAlpha + changedInverse
        }
        try meter.records(3 * 6, .curveSetup)
        let response = dn * inverseMass + dAlpha.cross(observationLever)
          + alpha.cross(dObservation - dCentre)
        try meter.records(3, .curveSetup)
        guard response.valid else { throw Failure.nonfiniteEnclosure }
        try meter.records(3, .curveSetup)
        let values = response.values
        try meter.records(3, .curveSetup)
        for coordinate in 0..<3 { jacobian[coordinate * variables + variable] = values[coordinate] }
      }
      try meter.records(1, .curveSetup)
      return .init(body: body, component: component, variables: variables,
        application: application, direction: direction, observation: observation,
        applicationJacobian: applicationJacobian, directionJacobian: directionJacobian,
        observationJacobian: observationJacobian, value: value, jacobian: jacobian)
    }
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Checked immutable MATH DATA only. This does not authenticate a force law,
  /// state/time source, native material, unit scale or any admission/clock.
  struct ConstrainedCoupledVector: Sendable {
    let value: VectorBox
    let variables: Int
    let jacobian: [Interval]
    fileprivate let activeMask: UInt64

    fileprivate init(value: VectorBox, variables: Int, jacobian: [Interval], activeMask: UInt64) {
      self.value = value; self.variables = variables; self.jacobian = jacobian; self.activeMask = activeMask
    }
  }

  static func prepareConstrainedCoupledVector(_ value: VectorBox, variables: Int, jacobian: [Interval],
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedCoupledVector> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      guard variables >= 14, variables <= 53, (variables - 1) % 13 == 0,
        jacobian.count == 3 * variables else { throw Failure.unprovenContact }
      try meter.records(3, .curveSetup)
      guard value.valid else { throw Failure.unprovenContact }
      var active: UInt64 = 0
      for variable in 0..<variables {
        try meter.records(9, .curveSetup)
        let x = jacobian[variable], y = jacobian[variables + variable], z = jacobian[2 * variables + variable]
        guard x.valid, y.valid, z.valid else { throw Failure.unprovenContact }
        if !c01DerivativeZero(x) || !c01DerivativeZero(y) || !c01DerivativeZero(z) {
          try meter.records(1, .curveSetup)
          active |= UInt64(1) << variable
        }
      }
      try meter.records(1, .curveSetup)
      return .init(value: value, variables: variables, jacobian: jacobian, activeMask: active)
    }
  }

  /// Reuses the ONE exact same response evaluator. Checked geometry was paid
  /// once before retention; this call pays its actual mask/active-column work.
  static func prepareCachedConstrainedPointForceDifferential(_ frame: ConstrainedResponseDifferentialFrame,
    component: Int, application: ConstrainedCoupledVector, direction: ConstrainedCoupledVector,
    observation: ConstrainedCoupledVector, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedPointForceDifferential> {
    c01PrepareResponse(frame, component: component, variables: application.variables,
      geometry: .checked(application, direction, observation), work: &work)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  enum ConstrainedCellFailure: Error, Sendable {
    case invalidStart, invalidDomain, unrelatedField, nonfinite, notContractive, notSelfIncluding
  }
  /// Concrete mathematical source derivation. These are declared NEW IVP
  /// inputs, never a conversion from a retained candidate/endpoint State.
  final class ConstrainedInitialSeed: Sendable {
    enum Source: Sendable {
      case normalizedRawQuaternion(raw: [Double], centreOfMass: Vector3,
        linearMomentum: Vector3, worldAngularMomentum: Vector3)
      case translatedBirth(TranslatedBirthSeed)
    }
    let source: Source
    /// Fixed declared mathematical initial time; never a native elapsed receipt.
    let declaredAnchorTime: Double
    let state: State
    let view: NativeC01InquiryCompoundMaterialAtlas.View

    fileprivate init(source: Source, declaredAnchorTime: Double, state: State,
      view: NativeC01InquiryCompoundMaterialAtlas.View) {
      self.source = source; self.declaredAnchorTime = declaredAnchorTime; self.state = state; self.view = view
    }
  }

  /// Diagnostic NEW mathematical IVP only. The ONE seed normalization computes
  /// raw/realNorm, proving exact unit q for that declared source. No State,
  /// candidate box, native attained endpoint or history is accepted here.
  static func prepareConstrainedInitialSeed(view: NativeC01InquiryCompoundMaterialAtlas.View,
    declaredAnchorTime: Double, rawQuaternion: [Double], centreOfMass: Vector3, linearMomentum: Vector3,
    worldAngularMomentum: Vector3, work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedInitialSeed> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(2, .curveSetup)
      guard declaredAnchorTime.isFinite, declaredAnchorTime >= 0 else { throw Failure.invalidSeed }
      guard rawQuaternion.count == 4 else { throw Failure.invalidSeed }
      // Same actual normalization algorithm and records as prepareSeed.
      for _ in 0..<5 { try meter.records(4, .curveSetup) }
      try meter.records(9, .curveSetup)
      try meter.records(9, .curveSetup)
      try meter.records(1, .curveSetup)
      let state = try seed(representation: view.representation, rawQuaternion: rawQuaternion,
        centreOfMass: centreOfMass, linearMomentum: linearMomentum,
        worldAngularMomentum: worldAngularMomentum)
      // Retain the actual source scalars/View and immutable derivation object.
      try meter.records(4 + 9 + 1 + 1 + 1, .curveSetup)
      return .init(source: .normalizedRawQuaternion(raw: rawQuaternion, centreOfMass: centreOfMass,
        linearMomentum: linearMomentum, worldAngularMomentum: worldAngularMomentum), declaredAnchorTime: declaredAnchorTime, state: state, view: view)
    }
  }

  /// A mathematical birth seed has no genuine retained birth-time join.
  /// Fail closed until G1's same GameBirthPreparation source/time API is used;
  /// a caller Double or installed-model time cannot supply that missing fact.
  static func prepareConstrainedInitialSeed(_ birth: TranslatedBirthSeed,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedInitialSeed> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(1, .curveSetup)
      throw NativeC01InquiryPreparationWork.Failure.invalidSource
    }
  }

  enum ConstrainedInitialRelation: Sendable {
    case sameParentAtlasTransfer
    case validatedPicardEndpoint
    case validatedEndpointCutTransfer
  }

  /// Mathematical IVP state only. Source/native accepted cut, elapsed time,
  /// force provenance and lifetime are NOT granted by this immutable object.
  final class ConstrainedCellStart: Sendable {
    let initialSeed: ConstrainedInitialSeed
    let sourceBoundary: NativeC01InquiryCutContactSet.Boundary
    let components: [NativeC01InquiryCutContactSet.Component]
    let initialBounds: [Interval]
    let anchorTime: Double
    let elapsed: Interval
    let activeBasis: [Int]
    let relation: ConstrainedInitialRelation

    fileprivate init(initialSeed: ConstrainedInitialSeed, boundary: NativeC01InquiryCutContactSet.Boundary,
      components: [NativeC01InquiryCutContactSet.Component], initial: [Interval], anchor: Double,
      elapsed: Interval, basis: [Int], relation: ConstrainedInitialRelation)
    {
      self.initialSeed = initialSeed; sourceBoundary = boundary; self.components = components; initialBounds = initial
      anchorTime = anchor; self.elapsed = elapsed; activeBasis = basis; self.relation = relation
    }
  }
  final class ConstrainedCellDomain: Sendable {
    let start: ConstrainedCellStart
    let duration: Double
    let enclosure: [Interval]
    let proofScales: [Double]
    let components: [NativeC01InquiryCutContactSet.Component]
    let absoluteTimeRange: Interval

    fileprivate init(start: ConstrainedCellStart, duration: Double, enclosure: [Interval], scales: [Double],
      components: [NativeC01InquiryCutContactSet.Component], time: Interval)
    {
      self.start = start; self.duration = duration; self.enclosure = enclosure
      proofScales = scales; self.components = components; absoluteTimeRange = time
    }
  }
  /// Conditional mathematical Picard/contraction result. Native whole-solid,
  /// finite footprint/event/provider/clock/epoch installation is still required.
  final class ConstrainedCellCandidate: Sendable {
    let domain: ConstrainedCellDomain
    let field: NativeC01InquiryCutContactSet.MovingFieldDifferential
    let picardImage: [Interval]
    let endpointBounds: [Interval]
    let endpoint: [NativeC01InquiryCutContactSet.Component]
    let elapsedEndpoint: Interval
    let lipschitzUpper: Double
    let contractionUpper: Double

    fileprivate init(domain: ConstrainedCellDomain,
      field: NativeC01InquiryCutContactSet.MovingFieldDifferential, image: [Interval], endpoint: [Interval],
      components: [NativeC01InquiryCutContactSet.Component], elapsed: Interval, lipschitz: Double, contraction: Double)
    {
      self.domain = domain; self.field = field; picardImage = image; endpointBounds = endpoint
      self.endpoint = components; elapsedEndpoint = elapsed
      lipschitzUpper = lipschitz; contractionUpper = contraction
    }
  }

  /// A generic Boundary may have been built from a computational candidate B.
  /// Shape/atlas equality or zero-containing residuals cannot establish a unit
  /// quaternion or attained contact history. This legacy entry fails closed.
  static func prepareConstrainedCellStart(_ boundary: NativeC01InquiryCutContactSet.Boundary,
    anchorTime: Double, activeBasis: [Int], work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedCellStart {
    try work.node()
    try work.reservePreparedMetadataRecords(1)
    throw ConstrainedCellFailure.invalidStart
  }

  /// Derive the initial cut internally from the EXACT retained source, never
  /// from an externally supplied Boundary/State. The source's real normalized
  /// q makes transfer R orthogonal; the SAME parent's inherited rigid velocity
  /// and material points therefore give exact initial g/gDot by source algebra.
  /// All later starts come only from actual validated-cell continuation below.
  static func prepareConstrainedCellStart(_ initialSeed: ConstrainedInitialSeed,
    cutHeadEdges: [NativeC01InquiryFixtureGeometry.Part], anchorTime: Double,
    activeBasis: [Int], work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedCellStart {
    try work.node()
    try work.reservePreparedMetadataRecords(3)
    guard anchorTime.isFinite, anchorTime >= 0, anchorTime == initialSeed.declaredAnchorTime
    else { throw ConstrainedCellFailure.invalidStart }
    let boundary = try NativeC01InquiryCutContactSet.prepare(initialSeed.state,
      view: initialSeed.view, cutHeadEdges: cutHeadEdges, work: &work)
    try work.node()
    try work.reservePreparedMetadataRecords(3)
    guard !boundary.components.isEmpty, boundary.components.count <= 4,
      anchorTime.isFinite, anchorTime >= 0 else { throw ConstrainedCellFailure.invalidStart }
    var rows = 0
    for patch in boundary.patches {
      try work.reservePreparedMetadataRecords(1)
      rows += patch.materialVertexIDs.count
    }
    try work.reservePreparedMetadataRecords(2)
    guard rows <= 12, activeBasis.count <= rows else { throw ConstrainedCellFailure.invalidStart }
    var previous = -1
    for row in activeBasis {
      try work.reservePreparedMetadataRecords(1)
      guard row >= 0, row < rows, row > previous else { throw ConstrainedCellFailure.invalidStart }
      previous = row
    }
    let initial = try c01ConstrainedStateBounds(boundary.components, work: &work)
    try work.reservePreparedMetadataRecords(2)
    return .init(initialSeed: initialSeed, boundary: boundary, components: boundary.components, initial: initial,
      anchor: initialSeed.declaredAnchorTime, elapsed: .point(0), basis: activeBasis, relation: .sameParentAtlasTransfer)
  }

  static func prepareConstrainedCellDomain(_ start: ConstrainedCellStart, duration: Double,
    enclosure: [Interval], proofScales: [Double], work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedCellDomain {
    try work.node()
    let n = start.initialBounds.count
    try work.reservePreparedMetadataRecords(3)
    guard duration.isFinite, duration > 0, duration <= 0.1,
      enclosure.count == n, proofScales.count == n else { throw ConstrainedCellFailure.invalidDomain }
    for coordinate in 0..<n {
      try work.reservePreparedMetadataRecords(3)
      let initial = start.initialBounds[coordinate], box = enclosure[coordinate], scale = proofScales[coordinate]
      guard box.valid, box.lower <= initial.lower, box.upper >= initial.upper,
        scale.isFinite, scale > 0 else { throw ConstrainedCellFailure.invalidDomain }
    }
    try work.reservePreparedMetadataRecords(2)
    let elapsed = start.elapsed + Interval(lower: 0, upper: duration)
    let absolute = Interval.point(start.anchorTime) + elapsed
    try work.reservePreparedMetadataRecords(1)
    guard absolute.valid else { throw ConstrainedCellFailure.nonfinite }
    // True elapsed is nonnegative by construction. This lower bound follows
    // that fact, not a numerical epsilon or a native time advancement claim.
    let time = Interval(lower: max(start.anchorTime, absolute.lower), upper: absolute.upper)
    let components = try c01ConstrainedStates(enclosure, templates: start.components, work: &work)
    try work.reservePreparedMetadataRecords(1)
    return .init(start: start, duration: duration, enclosure: enclosure, scales: proofScales,
      components: components, time: time)
  }

  /// No evaluator callback is accepted. The separately constructed full field
  /// must match this EXACT domain and time. Its actual source-law/range/Jacobian
  /// truth remains a conditional assumption until G1 qualifies the provider.
  static func validateConstrainedCell(_ domain: ConstrainedCellDomain,
    field: NativeC01InquiryCutContactSet.MovingFieldDifferential,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedCellCandidate {
    try work.query()
    try c01BindConstrainedField(domain, field: field, work: &work)
    let n = domain.enclosure.count, variables = n + 1
    try work.reservePreparedMetadataRecords(field.fieldJacobian.count)
    guard field.fieldJacobian.allSatisfy(\.valid) else { throw ConstrainedCellFailure.nonfinite }
    var upper = 0.0
    for row in 0..<n {
      try work.node()
      var sum = Interval.point(0)
      for column in 0..<n {
        try work.reservePreparedMetadataRecords(4)
        let magnitude = Interval.point(field.fieldJacobian[row * variables + column].magnitude)
        let ratio = Interval.point(domain.proofScales[column]) / .point(domain.proofScales[row])
        sum = sum + magnitude * ratio
      }
      try work.reservePreparedMetadataRecords(1)
      guard sum.valid else { throw ConstrainedCellFailure.nonfinite }
      upper = max(upper, sum.upper)
    }
    try work.reservePreparedMetadataRecords(1)
    let contraction = Interval.point(domain.duration) * .point(upper)
    try work.reservePreparedMetadataRecords(1)
    guard contraction.valid, contraction.upper < 1 else { throw ConstrainedCellFailure.notContractive }
    let rates = try c01ConstrainedFieldBounds(field.totalFields, work: &work)
    var image: [Interval] = [], endpoint: [Interval] = []
    for coordinate in 0..<n {
      try work.reservePreparedMetadataRecords(4)
      let initial = domain.start.initialBounds[coordinate], rate = rates[coordinate]
      let allTimes = initial + Interval(lower: 0, upper: domain.duration) * rate
      let attained = initial + Interval.point(domain.duration) * rate
      try work.reservePreparedMetadataRecords(2)
      guard allTimes.valid, attained.valid else { throw ConstrainedCellFailure.nonfinite }
      try work.reservePreparedMetadataRecords(1)
      guard domain.enclosure[coordinate].strictlyContains(allTimes) else { throw ConstrainedCellFailure.notSelfIncluding }
      try work.reservePreparedMetadataRecords(2)
      image.append(allTimes); endpoint.append(attained)
    }
    let components = try c01ConstrainedStates(endpoint, templates: domain.components, work: &work)
    try work.reservePreparedMetadataRecords(1)
    let elapsed = domain.start.elapsed + Interval.point(domain.duration)
    try work.reservePreparedMetadataRecords(1)
    guard elapsed.valid else { throw ConstrainedCellFailure.nonfinite }
    try work.reservePreparedMetadataRecords(1)
    return .init(domain: domain, field: field, image: image, endpoint: endpoint, components: components,
      elapsed: .init(lower: max(0, elapsed.lower), upper: elapsed.upper), lipschitz: upper, contraction: contraction.upper)
  }

  /// Inductive mathematical continuation only: same basis/atlas, ALL endpoint
  /// q/C/P/L intervals retained. No temporal-cell chain is added here; source
  /// boundary may retain at most three actual cut-origin cells. No native
  /// preparation/owner/snapshot or scalar time/pose reseed is retained.
  static func prepareConstrainedCellContinuation(_ cell: ConstrainedCellCandidate,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedCellStart {
    try work.node()
    try work.reservePreparedMetadataRecords(2)
    return .init(initialSeed: cell.domain.start.initialSeed,
      boundary: cell.domain.start.sourceBoundary, components: cell.endpoint,
      initial: cell.endpointBounds, anchor: cell.domain.start.anchorTime, elapsed: cell.elapsedEndpoint,
      basis: cell.domain.start.activeBasis, relation: .validatedPicardEndpoint)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  private static func c01ConstrainedStateBounds(_ components: [NativeC01InquiryCutContactSet.Component],
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> [Interval] {
    var result: [Interval] = []
    for component in components {
      let state = component.state
      try work.reservePreparedMetadataRecords(13)
      guard state.quaternion.valid, state.centreOfMass.valid, state.linearMomentum.valid,
        state.worldAngularMomentum.valid else { throw ConstrainedCellFailure.invalidStart }
      for coordinate in state.quaternion.components {
        try work.reservePreparedMetadataRecords(1)
        result.append(coordinate)
      }
      try work.reservePreparedMetadataRecords(3)
      for vector in [state.centreOfMass, state.linearMomentum, state.worldAngularMomentum] {
        try work.reservePreparedMetadataRecords(3)
        let values = vector.values
        for coordinate in values {
          try work.reservePreparedMetadataRecords(1)
          result.append(coordinate)
        }
      }
    }
    return result
  }

  private static func c01ConstrainedFieldBounds(_ fields: [ConstrainedBodyField],
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> [Interval] {
    var result: [Interval] = []
    for field in fields {
      for coordinate in field.quaternionDerivative.components {
        try work.reservePreparedMetadataRecords(1)
        result.append(coordinate)
      }
      try work.reservePreparedMetadataRecords(3)
      for vector in [field.centreDerivative, field.linearMomentumDerivative, field.angularMomentumDerivative] {
        try work.reservePreparedMetadataRecords(3)
        let values = vector.values
        for coordinate in values {
          try work.reservePreparedMetadataRecords(1)
          result.append(coordinate)
        }
      }
    }
    return result
  }

  /// Candidate/endpoint boxes preserve every represented interval and the same
  /// actual source representation/view. No public raw-State constructor or
  /// rounded pose/quaternion/component seed is added by the time solver.
  private static func c01ConstrainedStates(_ box: [Interval], templates: [NativeC01InquiryCutContactSet.Component],
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> [NativeC01InquiryCutContactSet.Component] {
    try work.reservePreparedMetadataRecords(1)
    guard box.count == 13 * templates.count else { throw ConstrainedCellFailure.invalidDomain }
    var result: [NativeC01InquiryCutContactSet.Component] = []
    for index in templates.indices {
      let offset = 13 * index, original = templates[index]
      try work.reservePreparedMetadataRecords(13)
      let quaternion = QuaternionBox(components: [box[offset], box[offset + 1], box[offset + 2], box[offset + 3]])
      let centre = VectorBox(x: box[offset + 4], y: box[offset + 5], z: box[offset + 6])
      let momentum = VectorBox(x: box[offset + 7], y: box[offset + 8], z: box[offset + 9])
      let angular = VectorBox(x: box[offset + 10], y: box[offset + 11], z: box[offset + 12])
      try work.reservePreparedMetadataRecords(13)
      guard quaternion.valid, centre.valid, momentum.valid, angular.valid else { throw ConstrainedCellFailure.nonfinite }
      try work.reservePreparedMetadataRecords(1)
      let state = State(representation: original.state.representation, quaternion: quaternion,
        centreOfMass: centre, linearMomentum: momentum, worldAngularMomentum: angular)
      try work.reservePreparedMetadataRecords(2)
      result.append(.init(state: state, view: original.view))
    }
    return result
  }

  private static func c01BindConstrainedField(_ domain: ConstrainedCellDomain,
    field: NativeC01InquiryCutContactSet.MovingFieldDifferential,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    let moving = field.moving, value = moving.contactOperator
    let n = domain.enclosure.count, expected = domain.start.sourceBoundary
    // Equal numerical patches cannot substitute another retained cut-origin
    // graph when binding this conditional field to the exact start's history.
    try work.reservePreparedMetadataRecords(9 + domain.start.activeBasis.count)
    guard value.sourceBoundary === expected,
      moving.physicalTimeRange == domain.absoluteTimeRange,
      moving.variables == n + 1, field.fieldJacobian.count == n * (n + 1),
      field.basis.activeBasis == domain.start.activeBasis,
      value.current.count == domain.components.count, field.totalFields.count == domain.components.count,
      value.sourceBoundary.parentView.atlas === expected.parentView.atlas,
      value.sourceBoundary.patches.count == expected.patches.count else { throw ConstrainedCellFailure.unrelatedField }
    for index in expected.patches.indices {
      let a = expected.patches[index], b = value.sourceBoundary.patches[index]
      try work.reservePreparedMetadataRecords(7 + a.materialVertexIDs.count)
      guard a.head == b.head, a.supportComponent == b.supportComponent, a.headComponent == b.headComponent,
        a.supportFacet == b.supportFacet, a.headFacet == b.headFacet,
        a.materialVertexIDs == b.materialVertexIDs, a.normalFromSupportIntoHead == b.normalFromSupportIntoHead
      else { throw ConstrainedCellFailure.unrelatedField }
    }
    for index in domain.components.indices {
      let a = domain.components[index], b = value.current[index]
      try work.reservePreparedMetadataRecords(3 + a.view.vertexIDs.count + a.view.facetIDs.count)
      guard a.view.atlas === b.view.atlas, a.view.vertexIDs == b.view.vertexIDs,
        a.view.facetIDs == b.view.facetIDs else { throw ConstrainedCellFailure.unrelatedField }
      try c01ConstrainedStateMatch(a.state, b.state, work: &work)
      try c01ConstrainedStateMatch(a.state, field.totalFields[index].state, work: &work)
    }
  }

  private static func c01ConstrainedStateMatch(_ a: State, _ b: State,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    try work.reservePreparedMetadataRecords(13 + 3)
    guard a.quaternion.components == b.quaternion.components,
      a.centreOfMass.x == b.centreOfMass.x, a.centreOfMass.y == b.centreOfMass.y, a.centreOfMass.z == b.centreOfMass.z,
      a.linearMomentum.x == b.linearMomentum.x, a.linearMomentum.y == b.linearMomentum.y, a.linearMomentum.z == b.linearMomentum.z,
      a.worldAngularMomentum.x == b.worldAngularMomentum.x, a.worldAngularMomentum.y == b.worldAngularMomentum.y,
      a.worldAngularMomentum.z == b.worldAngularMomentum.z,
      a.representation.mass.massKilograms == b.representation.mass.massKilograms,
      a.representation.mass.centreOfMassSource == b.representation.mass.centreOfMassSource,
      a.representation.mass.inertiaAtCentreOfMass == b.representation.mass.inertiaAtCentreOfMass
    else { throw ConstrainedCellFailure.unrelatedField }
    try work.reservePreparedMetadataRecords(1)
    guard a.representation.mass.parts.count == b.representation.mass.parts.count
    else { throw ConstrainedCellFailure.unrelatedField }
    try work.reservePreparedMetadataRecords(3 * a.representation.mass.parts.count)
    guard a.representation.mass.parts.map(\.kind) == b.representation.mass.parts.map(\.kind)
    else { throw ConstrainedCellFailure.unrelatedField }
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Same conditional cell branch over a LOCAL subrange, never a native time
  /// receipt. All q/C/P/L evolve; this is not a constant-momentum free Curve.
  struct ConstrainedCellSlice: Sendable {
    let cell: ConstrainedCellCandidate
    let component: Int
    let fromLocal: Double
    let throughLocal: Double
    let state: State
    let view: NativeC01InquiryCompoundMaterialAtlas.View
    let rotation: [Interval]
    let worldAngularVelocity: VectorBox
    let linearVelocity: VectorBox

    fileprivate init(cell: ConstrainedCellCandidate, component: Int, from: Double, through: Double,
      state: State, view: NativeC01InquiryCompoundMaterialAtlas.View,
      rotation: [Interval], omega: VectorBox, velocity: VectorBox)
    {
      self.cell = cell; self.component = component; fromLocal = from; throughLocal = through
      self.state = state; self.view = view; self.rotation = rotation
      worldAngularVelocity = omega; linearVelocity = velocity
    }
  }

  static func prepareConstrainedCellSlice(_ cell: ConstrainedCellCandidate, component: Int,
    fromLocal: Double, throughLocal: Double, work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedCellSlice {
    try work.node()
    try work.reservePreparedMetadataRecords(7)
    guard component >= 0, component < cell.domain.components.count,
      fromLocal.isFinite, throughLocal.isFinite, fromLocal >= 0,
      fromLocal <= throughLocal, throughLocal <= cell.domain.duration
    else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(1)
    let rates = try c01ConstrainedFieldBounds([cell.field.totalFields[component]], work: &work)
    let offset = 13 * component
    var box: [Interval] = []
    let time = Interval(lower: fromLocal, upper: throughLocal)
    for coordinate in 0..<13 {
      try work.reservePreparedMetadataRecords(2)
      let integrated = cell.domain.start.initialBounds[offset + coordinate] + time * rates[coordinate]
      try work.reservePreparedMetadataRecords(1)
      let enclosure = cell.domain.enclosure[offset + coordinate]
      try work.reservePreparedMetadataRecords(1)
      let bounded = Interval(lower: max(integrated.lower, enclosure.lower), upper: min(integrated.upper, enclosure.upper))
      try work.reservePreparedMetadataRecords(1)
      guard bounded.valid else { throw ConstrainedCellFailure.nonfinite }
      try work.reservePreparedMetadataRecords(1)
      box.append(bounded)
    }
    try work.reservePreparedMetadataRecords(1)
    let states = try c01ConstrainedStates(box, templates: [cell.domain.components[component]], work: &work)
    let geometry = try c01PrepareMaterialGeometry(states[0], work: &work)
    try work.reservePreparedMetadataRecords(1)
    return .init(cell: cell, component: component, from: fromLocal, through: throughLocal,
      state: geometry.state, view: geometry.view, rotation: geometry.rotation,
      omega: geometry.worldAngularVelocity, velocity: geometry.linearVelocity)
  }

  static func constrainedSliceMaterialBounds(_ slice: ConstrainedCellSlice, vertex: Int,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    let local = try c01MaterialLocalPoint(.init(state: slice.state, view: slice.view), vertex: vertex, work: &work)
    return try constrainedSliceMaterialBounds(slice, localPoint: local, work: &work)
  }

  static func constrainedSliceMaterialBounds(_ slice: ConstrainedCellSlice, localPoint: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    try c01MaterialPointBounds(state: slice.state, rotation: slice.rotation,
      worldAngularVelocity: slice.worldAngularVelocity, linearVelocity: slice.linearVelocity,
      localPoint: localPoint, work: &work)
  }

}

extension NativeC01InquiryCompoundValidatedCurve {
  enum ConstrainedAdvanceStop: Sendable {
    case attemptLimit, subdivisionLimit, retainedCellLimit, unsplittableDuration
    case workLimit, invalidInput, invalidSubmission, unrelatedField, nonfinite
    case externalSourceOrEventBoundary
  }
  enum ConstrainedFieldRejection: Sendable {
    case unresolvedMathematicalRange
    case actualSourceOrEventBoundary
  }
  /// Conditional ODE target coverage only. All native source/event/geometry,
  /// time/currentness/lifetime/installation qualification remains independent.
  final class ConstrainedAdvanceCandidate: Sendable {
    let start: ConstrainedCellStart
    let targetDuration: Double
    let cells: [ConstrainedCellCandidate]
    let endpoint: ConstrainedCellStart
    let work: Work

    fileprivate init(start: ConstrainedCellStart, target: Double, cells: [ConstrainedCellCandidate],
      endpoint: ConstrainedCellStart, work: Work)
    {
      self.start = start; targetDuration = target; self.cells = cells; self.endpoint = endpoint; self.work = work
    }
  }
  enum ConstrainedAdvanceAction: Sendable {
    case request(ConstrainedCellDomain)
    case awaitingSubmission
    case targetCandidate(ConstrainedAdvanceCandidate)
    case stopped(ConstrainedAdvanceStop)
  }
  enum ConstrainedAdvanceSubmission: Sendable {
    case acceptedCell(ConstrainedCellCandidate)
    case retryQueued
    case stopped(ConstrainedAdvanceStop)
  }

  /// Deliberately synchronous and NON-Sendable. This controls mathematical
  /// attempts only; G1 owns the real cumulative native phase/query allowance.
  /// No callback/force framework, Game snapshot or native permission is added.
  final class ConstrainedAdvanceController {
    private struct Chunk {
      let duration: Double
      let depth: Int
      let hint: [Interval]?
    }
    private let originalStart: ConstrainedCellStart
    private let target: Double
    private let scales: [Double]
    private let budget: WorkBudget
    private var chunks: [Chunk]
    private var cells: [ConstrainedCellCandidate] = []
    private var current: ConstrainedCellStart
    private var pending: ConstrainedCellDomain?
    private var pendingChunk: Chunk?
    private var attempts = 0
    private var splitCount = 0
    private var terminal: ConstrainedAdvanceStop?
    private var finished: ConstrainedAdvanceCandidate?

    fileprivate init(start: ConstrainedCellStart, target: Double, proposal: [Interval], scales: [Double], budget: WorkBudget) {
      originalStart = start; self.target = target; self.scales = scales; self.budget = budget
      current = start; chunks = [.init(duration: target, depth: 0, hint: proposal)]
    }
    /// Actual THIS-controller method history. Not native activity/elapsed time
    /// or proof that earlier source/provider/geometry preparation was paid.
    var statistics: Work { .init(cellAttempts: attempts, splits: splitCount, retainedCells: cells.count) }
    var endpointStart: ConstrainedCellStart { current }

    private enum NextDecision {
      case terminal(ConstrainedAdvanceStop)
      case finished(ConstrainedAdvanceCandidate)
      case awaitingSubmission
      case finalize
      case stop(ConstrainedAdvanceStop)
      case attempt
    }

    /// The single branch decision for both native preflight and nextDomain.
    /// Reading it does not count an attempt or spend/mutate any allowance.
    private func nextDecision() -> NextDecision {
      if let terminal { return .terminal(terminal) }
      if let finished { return .finished(finished) }
      if pending != nil { return .awaitingSubmission }
      if chunks.isEmpty { return .finalize }
      if attempts >= budget.cellAttempts { return .stop(.attemptLimit) }
      if cells.count >= budget.retainedCells { return .stop(.retainedCellLimit) }
      return .attempt
    }

    /// True exactly when the next synchronous nextDomain call will increment
    /// this controller's actual attempt counter, including failed construction.
    /// The caller preflights its cumulative allowance but adopts only the actual
    /// statistics delta after nextDomain; this property is not a debit/reservation.
    var nextDomainWillCountAttempt: Bool {
      if case .attempt = nextDecision() { return true }
      return false
    }

    func nextDomain(work: inout NativeC01InquiryCurveGeometry.Work) -> ConstrainedAdvanceAction {
      do {
        switch nextDecision() {
        case .terminal(let reason): return .stopped(reason)
        case .finished(let candidate): return .targetCandidate(candidate)
        case .awaitingSubmission: return .awaitingSubmission
        case .stop(let reason): return stopAction(reason)
        case .finalize:
          try work.reservePreparedMetadataRecords(1)
          let result = ConstrainedAdvanceCandidate(start: originalStart, target: target,
            cells: cells, endpoint: current, work: statistics)
          finished = result
          return .targetCandidate(result)
        case .attempt: break
        }
        // Count BEFORE domain construction and BEFORE the caller's separately
        // metered actual field preparation. Even a failed domain spends it.
        attempts += 1
        try work.node()
        try work.reservePreparedMetadataRecords(1)
        let chunk = chunks.removeLast()
        pendingChunk = chunk
        let proposal: [Interval]
        if let hint = chunk.hint { proposal = hint }
        else {
          var box: [Interval] = []
          for coordinate in current.initialBounds {
            try work.reservePreparedMetadataRecords(2)
            let expanded = coordinate.inflated().inflated()
            try work.reservePreparedMetadataRecords(1)
            box.append(expanded)
          }
          proposal = box
        }
        let domain = try NativeC01InquiryCompoundValidatedCurve.prepareConstrainedCellDomain(current,
          duration: chunk.duration, enclosure: proposal, proofScales: scales, work: &work)
        pending = domain
        return .request(domain)
      } catch NativeC01InquiryCurveGeometry.Failure.workBudgetExceeded { return stopAction(.workLimit) }
      catch { return stopAction(.invalidInput) }
    }

    func submit(_ domain: ConstrainedCellDomain, field: NativeC01InquiryCutContactSet.MovingFieldDifferential,
      work: inout NativeC01InquiryCurveGeometry.Work) -> ConstrainedAdvanceSubmission {
      if let terminal { return .stopped(terminal) }
      do {
        try work.reservePreparedMetadataRecords(1)
        guard pending === domain, let chunk = pendingChunk else { return stopSubmission(.invalidSubmission) }
        do {
          let cell = try NativeC01InquiryCompoundValidatedCurve.validateConstrainedCell(domain, field: field, work: &work)
          let next = try NativeC01InquiryCompoundValidatedCurve.prepareConstrainedCellContinuation(cell, work: &work)
          try work.reservePreparedMetadataRecords(1)
          cells.append(cell)
          current = next; pending = nil; pendingChunk = nil
          return .acceptedCell(cell)
        } catch ConstrainedCellFailure.notSelfIncluding {
          // Proposal refinement is not a state reset or a physical projection.
          // All actual prior domain/field/proof spending remains in caller Work.
          let proposal = try expandedProposal(domain, field: field, work: &work)
          try work.reservePreparedMetadataRecords(1)
          chunks.append(.init(duration: chunk.duration, depth: chunk.depth, hint: proposal))
          pending = nil; pendingChunk = nil
          return .retryQueued
        } catch ConstrainedCellFailure.notContractive {
          return try subdivide(chunk, work: &work)
        } catch NativeC01InquiryCurveGeometry.Failure.workBudgetExceeded { return stopSubmission(.workLimit) }
        catch ConstrainedCellFailure.unrelatedField { return stopSubmission(.unrelatedField) }
        catch ConstrainedCellFailure.nonfinite { return stopSubmission(.nonfinite) }
        catch { return stopSubmission(.invalidInput) }
      } catch NativeC01InquiryCurveGeometry.Failure.workBudgetExceeded { return stopSubmission(.workLimit) }
      catch { return stopSubmission(.invalidInput) }
    }

    /// Must be called when separately prepared field construction fails. The
    /// already-started attempt is never erased. Actual source/event/window
    /// invalidation STOPS; subdivision cannot manufacture a valid native law.
    func rejectField(_ domain: ConstrainedCellDomain, reason: ConstrainedFieldRejection,
      work: inout NativeC01InquiryCurveGeometry.Work) -> ConstrainedAdvanceSubmission {
      if let terminal { return .stopped(terminal) }
      do {
        try work.reservePreparedMetadataRecords(1)
        guard pending === domain, let chunk = pendingChunk else { return stopSubmission(.invalidSubmission) }
        switch reason {
        case .actualSourceOrEventBoundary: return stopSubmission(.externalSourceOrEventBoundary)
        case .unresolvedMathematicalRange: return try subdivide(chunk, work: &work)
        }
      } catch NativeC01InquiryCurveGeometry.Failure.workBudgetExceeded { return stopSubmission(.workLimit) }
      catch { return stopSubmission(.invalidInput) }
    }

    /// Explicit paid copy of the retained mathematical prefix. It confers no
    /// geometry/event/native-time qualification. No implicit array alias escapes
    /// while the controller is still appending to its private cell storage.
    func retainedPrefix(work: inout NativeC01InquiryCurveGeometry.Work) throws -> [ConstrainedCellCandidate] {
      try work.reservePreparedMetadataRecords(cells.count)
      return cells.map { $0 }
    }

    private func expandedProposal(_ domain: ConstrainedCellDomain,
      field: NativeC01InquiryCutContactSet.MovingFieldDifferential,
      work: inout NativeC01InquiryCurveGeometry.Work) throws -> [Interval] {
      // Typed notSelfIncluding catch above means exact-domain binding and
      // contraction already succeeded. Reuse that SAME field, never a point
      // sample or a new uncharged native/provider call.
      let rates = try NativeC01InquiryCompoundValidatedCurve.c01ConstrainedFieldBounds(field.totalFields, work: &work)
      var result: [Interval] = []
      for coordinate in domain.enclosure.indices {
        try work.reservePreparedMetadataRecords(4)
        let image = domain.start.initialBounds[coordinate]
          + Interval(lower: 0, upper: domain.duration) * rates[coordinate]
        let proposal = domain.enclosure[coordinate].union(image).inflated()
        try work.reservePreparedMetadataRecords(1)
        guard proposal.valid else { throw ConstrainedCellFailure.nonfinite }
        try work.reservePreparedMetadataRecords(1)
        result.append(proposal)
      }
      return result
    }

    private func subdivide(_ chunk: Chunk, work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedAdvanceSubmission {
      guard attempts < budget.cellAttempts else { return stopSubmission(.attemptLimit) }
      guard chunk.depth < budget.subdivisionDepth else { return stopSubmission(.subdivisionLimit) }
      try work.reservePreparedMetadataRecords(3)
      let half = chunk.duration * 0.5
      guard half.isFinite, half > 0, half < chunk.duration, half + half == chunk.duration
      else { return stopSubmission(.unsplittableDuration) }
      // half+half is exact for these positive finite halves. Repeated valid
      // splits form an exact real-duration partition; no rounded h-sum is used
      // to decide target coverage. Stack right then left is chronological.
      try work.reservePreparedMetadataRecords(2)
      chunks.append(.init(duration: half, depth: chunk.depth + 1, hint: nil))
      chunks.append(.init(duration: half, depth: chunk.depth + 1, hint: nil))
      splitCount += 1; pending = nil; pendingChunk = nil
      return .retryQueued
    }
    private func stopAction(_ reason: ConstrainedAdvanceStop) -> ConstrainedAdvanceAction {
      terminal = reason; return .stopped(reason)
    }
    private func stopSubmission(_ reason: ConstrainedAdvanceStop) -> ConstrainedAdvanceSubmission {
      terminal = reason; return .stopped(reason)
    }
  }

  static func prepareConstrainedAdvanceController(_ start: ConstrainedCellStart, targetDuration: Double,
    initialEnclosure: [Interval], proofScales: [Double], budget: WorkBudget,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedAdvanceController {
    try work.node()
    try work.reservePreparedMetadataRecords(11)
    guard targetDuration.isFinite, targetDuration > 0, targetDuration <= 0.1,
      budget.cellAttempts > 0, budget.cellAttempts < Int.max,
      budget.subdivisionDepth >= 0, budget.subdivisionDepth < Int.max,
      budget.retainedCells > 0, budget.retainedCells < Int.max,
      initialEnclosure.count == start.initialBounds.count, proofScales.count == start.initialBounds.count
    else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(1)
    return .init(start: start, target: targetDuration, proposal: initialEnclosure, scales: proofScales, budget: budget)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// One shared conditional trajectory for all components. Actual controller
  /// input Work is DATA, not proof of native provenance or prior paid setup.
  final class ConstrainedTrajectoryGeometry: Sendable {
    let candidate: ConstrainedAdvanceCandidate
    let cellStarts: [Interval]
    let cellEnds: [Interval]

    fileprivate init(candidate: ConstrainedAdvanceCandidate, starts: [Interval], ends: [Interval]) {
      self.candidate = candidate; cellStarts = starts; cellEnds = ends
    }
  }
  struct ConstrainedComponentMotion: Sendable {
    let group: ConstrainedTrajectoryGeometry
    let component: Int
    var initial: State { group.candidate.start.components[component].state }
    var endpoint: State { group.candidate.endpoint.components[component].state }
    var view: NativeC01InquiryCompoundMaterialAtlas.View { group.candidate.start.components[component].view }
    var duration: Double { group.candidate.targetDuration }
    var inputWork: Work { group.candidate.work }

    fileprivate init(group: ConstrainedTrajectoryGeometry, component: Int) { self.group = group; self.component = component }
  }
  struct ConstrainedMotionSlice: Sendable {
    let motion: ConstrainedComponentMotion
    let from: Double
    let through: Double
    let cells: [ConstrainedCellSlice]

    fileprivate init(motion: ConstrainedComponentMotion, from: Double, through: Double, cells: [ConstrainedCellSlice]) {
      self.motion = motion; self.from = from; self.through = through; self.cells = cells
    }
  }

  static func prepareConstrainedTrajectoryGeometry(_ candidate: ConstrainedAdvanceCandidate,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedTrajectoryGeometry {
    try work.node()
    try work.reservePreparedMetadataRecords(4)
    guard !candidate.cells.isEmpty, candidate.targetDuration.isFinite,
      candidate.targetDuration > 0, candidate.targetDuration <= 0.1 else { throw ConstrainedCellFailure.invalidDomain }
    var starts: [Interval] = [], ends: [Interval] = []
    var offset = Interval.point(0)
    for cell in candidate.cells {
      try work.node()
      try work.reservePreparedMetadataRecords(1)
      starts.append(offset)
      try work.reservePreparedMetadataRecords(1)
      let next = offset + Interval.point(cell.domain.duration)
      try work.reservePreparedMetadataRecords(1)
      guard next.valid else { throw ConstrainedCellFailure.nonfinite }
      offset = .init(lower: max(0, next.lower), upper: next.upper)
      try work.reservePreparedMetadataRecords(1)
      ends.append(offset)
    }
    try work.reservePreparedMetadataRecords(1)
    guard offset.lower <= candidate.targetDuration, candidate.targetDuration <= offset.upper
    else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(1)
    return .init(candidate: candidate, starts: starts, ends: ends)
  }

  static func prepareConstrainedComponentMotion(_ group: ConstrainedTrajectoryGeometry, component: Int,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedComponentMotion {
    try work.reservePreparedMetadataRecords(2)
    guard component >= 0, component < group.candidate.start.components.count else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(1)
    return .init(group: group, component: component)
  }

  /// Conservatively includes every potentially overlapping cell. Interval
  /// offset arithmetic prevents losing a shared boundary to scalar h-sum
  /// rounding. The actual coupled trajectory is never reintegrated as FREE.
  static func prepareConstrainedMotionSlice(_ motion: ConstrainedComponentMotion,
    from start: Double, through end: Double, work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> ConstrainedMotionSlice {
    try work.reservePreparedMetadataRecords(5)
    guard start.isFinite, end.isFinite, start >= 0, start <= end, end <= motion.duration
    else { throw ConstrainedCellFailure.invalidDomain }
    let group = motion.group, time = Interval(lower: start, upper: end)
    var result: [ConstrainedCellSlice] = []
    for index in group.candidate.cells.indices {
      try work.node()
      try work.reservePreparedMetadataRecords(2)
      if end < group.cellStarts[index].lower || start > group.cellEnds[index].upper { continue }
      try work.reservePreparedMetadataRecords(1)
      let relative = time - group.cellStarts[index]
      try work.reservePreparedMetadataRecords(1)
      guard relative.valid else { throw ConstrainedCellFailure.nonfinite }
      let cell = group.candidate.cells[index]
      try work.reservePreparedMetadataRecords(2)
      let lower = max(0, relative.lower), upper = min(cell.domain.duration, relative.upper)
      if lower > upper { continue }
      let slice = try prepareConstrainedCellSlice(cell, component: motion.component,
        fromLocal: lower, throughLocal: upper, work: &work)
      try work.reservePreparedMetadataRecords(1)
      result.append(slice)
    }
    try work.reservePreparedMetadataRecords(1)
    guard !result.isEmpty else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(1)
    return .init(motion: motion, from: start, through: end, cells: result)
  }

  static func constrainedMotionMaterialBounds(_ slice: ConstrainedMotionSlice, vertex: Int,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    var result: MaterialBounds?
    for cell in slice.cells {
      let bounds = try constrainedSliceMaterialBounds(cell, vertex: vertex, work: &work)
      if let old = result {
        try work.reservePreparedMetadataRecords(6 + 1)
        result = .init(position: old.position.union(bounds.position), velocity: old.velocity.union(bounds.velocity))
      } else { result = bounds }
    }
    guard let result else { throw ConstrainedCellFailure.invalidDomain }
    return result
  }

  static func constrainedMotionMaterialBounds(_ slice: ConstrainedMotionSlice, localPoint: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    var result: MaterialBounds?
    for cell in slice.cells {
      let bounds = try constrainedSliceMaterialBounds(cell, localPoint: localPoint, work: &work)
      if let old = result {
        try work.reservePreparedMetadataRecords(6 + 1)
        result = .init(position: old.position.union(bounds.position), velocity: old.velocity.union(bounds.velocity))
      } else { result = bounds }
    }
    guard let result else { throw ConstrainedCellFailure.invalidDomain }
    return result
  }

  static func constrainedMotionStateBounds(_ motion: ConstrainedComponentMotion, at time: Double,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> State {
    try work.reservePreparedMetadataRecords(3)
    guard time.isFinite, time >= 0, time <= motion.duration else { throw ConstrainedCellFailure.invalidDomain }
    if time == 0 { return motion.initial }
    if time == motion.duration { return motion.endpoint }
    let slice = try prepareConstrainedMotionSlice(motion, from: time, through: time, work: &work)
    var joined: [Interval]?
    for cell in slice.cells {
      try work.reservePreparedMetadataRecords(2)
      let box = try c01ConstrainedStateBounds([.init(state: cell.state, view: motion.view)], work: &work)
      if let old = joined {
        var next: [Interval] = []
        for coordinate in 0..<13 {
          try work.reservePreparedMetadataRecords(2)
          next.append(old[coordinate].union(box[coordinate]))
        }
        joined = next
      } else { joined = box }
    }
    guard let joined else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(2)
    let states = try c01ConstrainedStates(joined, templates: [.init(state: motion.initial, view: motion.view)], work: &work)
    return states[0].state
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Join the exact genuine preparation's current source, original birth time
  /// and rigorous seed. No caller seed/time pair, installed-model time, sampled
  /// quaternion or ordinary State can enter this factory. Synchronous only;
  /// the actual owner keeps its preparation/currentness and cumulative work.
  ///
  /// Fixed adapter checks/storage below are charged. G1's existing deep
  /// matchesCurrentBirthSource snapshot traversals have no Meter parameter;
  /// their native metering remains an OPEN obligation, not a fee covered by
  /// these fixed records or proof of complete query/source allowance payment.
  static func prepareConstrainedInitialSeed(
    _ preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    game: borrowing Game, workOwner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ConstrainedInitialSeed> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try meter.records(8, .metadata)
      guard preparation.matchesCurrentBirthSource(game: game, workOwner: workOwner)
      else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
      try meter.records(2, .curveSetup)
      let birth = preparation.seed
      let anchor = preparation.actualBirthPhysicalTime
      try meter.records(2, .curveSetup)
      guard anchor.isFinite, anchor >= 0 else { throw Failure.invalidSeed }
      try meter.records(4, .curveSetup)
      return .init(source: .translatedBirth(birth), declaredAnchorTime: anchor,
        state: birth.state, view: birth.materialView)
    }
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Conditional mathematical event candidate, not native cut/time/impulse or
  /// conservative transfer permission. G1 must join its exact accepted prior
  /// cell/source/epoch and qualify ALL actual event/material/foreign effects.
  final class ValidatedCutTransition: Sendable {
    let graph: NativeC01InquiryCutContactSet.ValidatedCutGraph
    let start: ConstrainedCellStart
    fileprivate init(graph: NativeC01InquiryCutContactSet.ValidatedCutGraph, start: ConstrainedCellStart) {
      self.graph = graph; self.start = start
    }
  }

  static func prepareValidatedCutTransition(_ cell: ConstrainedCellCandidate,
    cutHeadEdges: [NativeC01InquiryFixtureGeometry.Part],
    newlyActiveRows: [NativeC01InquiryCutContactSet.CutRowKey],
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ValidatedCutTransition {
    let graph = try NativeC01InquiryCutContactSet.prepareValidatedCutGraph(cell,
      cutHeadEdges: cutHeadEdges, newlyActiveRows: newlyActiveRows, work: &work)
    try work.reservePreparedMetadataRecords(2)
    guard graph.origin.previousCell === cell,
      case .validatedEndpointGraph(let origin) = graph.boundary.origin, origin === graph.origin
    else { throw ConstrainedCellFailure.invalidStart }
    let initial = try c01ConstrainedStateBounds(graph.boundary.components, work: &work)
    try work.reservePreparedMetadataRecords(2)
    let start = ConstrainedCellStart(initialSeed: cell.domain.start.initialSeed, boundary: graph.boundary,
      components: graph.boundary.components, initial: initial, anchor: cell.domain.start.anchorTime,
      elapsed: cell.elapsedEndpoint, basis: graph.origin.activeBasis, relation: .validatedEndpointCutTransfer)
    try work.reservePreparedMetadataRecords(1)
    return .init(graph: graph, start: start)
  }
}

extension NativeC01InquiryCompoundValidatedCurve {
  /// Mathematical material range cache, not a new State/source seed, unit-q,
  /// actual native entry, initial-solid, cut, collision or elapsed permission.
  struct ConstrainedMaterialGeometry: Sendable {
    let state: State
    let view: NativeC01InquiryCompoundMaterialAtlas.View
    let rotation: [Interval]
    let worldAngularVelocity: VectorBox
    let linearVelocity: VectorBox
    fileprivate init(state: State, view: NativeC01InquiryCompoundMaterialAtlas.View,
      rotation: [Interval], omega: VectorBox, velocity: VectorBox) {
      self.state = state; self.view = view; self.rotation = rotation
      worldAngularVelocity = omega; linearVelocity = velocity
    }
  }

  /// Public input is the actual privately constructed cut transition, not an
  /// arbitrary State/Boundary-to-provenance factory. Geometry remains DATA.
  static func prepareCutMaterialGeometry(_ transition: ValidatedCutTransition, component: Int,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedMaterialGeometry {
    try work.reservePreparedMetadataRecords(2)
    guard transition.start.components.indices.contains(component) else { throw ConstrainedCellFailure.invalidDomain }
    return try c01PrepareMaterialGeometry(transition.start.components[component], work: &work)
  }

  private static func c01PrepareMaterialGeometry(_ component: NativeC01InquiryCutContactSet.Component,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedMaterialGeometry {
    let state = component.state
    try work.reservePreparedMetadataRecords(9)
    let rotation = orientation(state.quaternion)
    // Same inverse-setup source records as c01ReserveInverseSetup, direct Work
    // here because the slice helper does not fabricate a phase Report.
    try work.reservePreparedMetadataRecords(8 + 6 + 6 + 1 + 9 + 9)
    let inverse = try inverseTensor(state.representation.mass.inertiaAtCentreOfMass)
    try work.reservePreparedMetadataRecords(9 + 9 + 9 + 9)
    let omega = angularVelocity(rotation, inverse: inverse, momentum: state.worldAngularMomentum)
    try work.reservePreparedMetadataRecords(3)
    let velocity = state.linearMomentum * (Interval.point(1) / .point(state.representation.mass.massKilograms))
    try work.reservePreparedMetadataRecords(9 + 3 + 3)
    guard rotation.allSatisfy(\.valid), omega.valid, velocity.valid else { throw ConstrainedCellFailure.nonfinite }
    try work.reservePreparedMetadataRecords(1)
    return .init(state: state, view: component.view, rotation: rotation, omega: omega, velocity: velocity)
  }

  static func constrainedMaterialGeometryBounds(_ geometry: ConstrainedMaterialGeometry, vertex: Int,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    let local = try c01MaterialLocalPoint(.init(state: geometry.state, view: geometry.view), vertex: vertex, work: &work)
    return try constrainedMaterialGeometryBounds(geometry, localPoint: local, work: &work)
  }

  static func constrainedMaterialGeometryBounds(_ geometry: ConstrainedMaterialGeometry, localPoint: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    try c01MaterialPointBounds(state: geometry.state, rotation: geometry.rotation,
      worldAngularVelocity: geometry.worldAngularVelocity, linearVelocity: geometry.linearVelocity,
      localPoint: localPoint, work: &work)
  }

  private static func c01MaterialLocalPoint(_ component: NativeC01InquiryCutContactSet.Component,
    vertex: Int, work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox {
    let atlas = component.view.atlas
    try work.reservePreparedMetadataRecords(1)
    guard component.view.vertexIDs.indices.contains(vertex) else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(3)
    var local = VectorBox.point(atlas.vertices[component.view.vertexIDs[vertex]])
    let currentCOM = component.state.representation.mass.centreOfMassSource
    try work.reservePreparedMetadataRecords(3)
    if currentCOM != atlas.ancestorCOMSource {
      // REAL scalar COM relation, not a separately rounded recentered mesh.
      try work.reservePreparedMetadataRecords(9 + 3)
      local = local + sourceCOMDifference(from: currentCOM, to: atlas.ancestorCOMSource)
    }
    return local
  }

  private static func c01MaterialPointBounds(state: State, rotation: [Interval], worldAngularVelocity: VectorBox,
    linearVelocity: VectorBox, localPoint: VectorBox, work: inout NativeC01InquiryCurveGeometry.Work) throws -> MaterialBounds {
    try work.reservePreparedMetadataRecords(3)
    guard localPoint.valid else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(9)
    let lever = apply(rotation, localPoint)
    try work.reservePreparedMetadataRecords(3 + 3 + 3)
    let position = state.centreOfMass + lever
    let velocity = linearVelocity + worldAngularVelocity.cross(lever)
    try work.reservePreparedMetadataRecords(6)
    guard position.valid, velocity.valid else { throw ConstrainedCellFailure.nonfinite }
    try work.reservePreparedMetadataRecords(1)
    return .init(position: position, velocity: velocity)
  }
}


extension NativeC01InquiryCompoundValidatedCurve {
  /// Original initial-source geometry DATA, not a cut, endpoint reseed or native
  /// admission. The private source factory retains state/view from this same
  /// translated birth. G1 must additionally bind the original seed object to
  /// its SAME birth/owner/current Game before using the result.
  static func prepareInitialSourceMaterialGeometry(_ initial: ConstrainedInitialSeed,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> ConstrainedMaterialGeometry
  {
    try work.reservePreparedMetadataRecords(4)
    guard case .translatedBirth(let birth) = initial.source,
      initial.declaredAnchorTime.isFinite, initial.declaredAnchorTime >= 0,
      initial.view.atlas === birth.materialView.atlas else {
      throw ConstrainedCellFailure.invalidStart
    }
    // Reuse the original source q/C/P/L and stable View. No State constructor,
    // normalization, geometry clone, fake transition or elapsed step is needed.
    try work.reservePreparedMetadataRecords(2)
    return try c01PrepareMaterialGeometry(.init(state: initial.state, view: initial.view), work: &work)
  }
}
