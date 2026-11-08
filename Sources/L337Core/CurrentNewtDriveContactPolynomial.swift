import Foundation

/// Continuous support proof for the two original source interfaces only. The
/// complete rod and shoe solids remain present; no face is cut from a native hull.
enum CurrentNewtDriveContactPolynomial {
  private typealias Polynomial = [Double]
  private typealias Point = [Polynomial]

  static func proves(
    initial: [Double], slopes: [[Double]], duration: Double, fraction: Double = 1,
    rod: CurrentNewtKitSource.Part, shoe: Mesh, stroke: Double,
    stageForces: [Double], maximumForce: Double
  ) -> Bool {
    guard initial.count == 41, slopes.count == 4,
      slopes.allSatisfy({ $0.count == 41 && $0.allSatisfy(\.isFinite) }),
      duration.isFinite, duration > 0, fraction.isFinite, fraction > 0, fraction <= 1, stroke.isFinite, stroke > 0,
      stageForces.count == 4, stageForces.allSatisfy({ $0.isFinite && $0 >= 0 }),
      maximumForce.isFinite, maximumForce > 0,
      CurrentNewtKitComponent.currentNewtCollisionMeshIsValid(rod.mesh),
      CurrentNewtKitComponent.currentNewtCollisionMeshIsValid(shoe)
    else { return false }
    func value(_ index: Int) -> Polynomial {
      let k = slopes.map { $0[index] }
      return [initial[index], duration * k[0] * fraction,
        duration * (-1.5 * k[0] + k[1] + k[2] - 0.5 * k[3]) * fraction * fraction,
        duration * (2.0 / 3) * (k[0] - k[1] - k[2] + k[3]) * fraction * fraction * fraction]
    }
    func vector(_ index: Int) -> Point { (0..<3).map { value(index + $0) } }
    func transform(_ point: Point, base: Int) -> Point {
      (0..<3).map { axis in
        var result = value(base + axis)
        for local in 0..<3 { result = add(result, multiply(value(base + 3 + local * 3 + axis), point[local])) }
        return result
      }
    }
    let lower = rod.lowered.centreOfMassMetres - rod.stowed.centreOfMassMetres
    let direction = (rod.extended.centreOfMassMetres - rod.lowered.centreOfMassMetres) * (1 / stroke)
    let q = value(36)
    let rodPoints: [Point] = rod.mesh.vertices.map { vertex in
      let coordinates = [vertex.x + lower.x, vertex.y + lower.y, vertex.z + lower.z]
      let axis = [direction.x, direction.y, direction.z]
      return transform((0..<3).map { add([coordinates[$0]], scale(q, by: axis[$0])) }, base: 0)
    }
    let shoePoints: [Point] = shoe.vertices.map { transform(constant($0), base: 18) }
    let normal = vector(21)
    let yAxis = vector(24), zAxis = vector(27), podOrigin = vector(18)
    let force = [stageForces[0],
      (-3 * stageForces[0] + 2 * stageForces[1] + 2 * stageForces[2] - stageForces[3]) * fraction,
      (2 * stageForces[0] - 2 * stageForces[1] - 2 * stageForces[2] + 2 * stageForces[3]) * fraction * fraction]
    let forceRoundoff = 2048 * Double.ulpOfOne * max(1, maximumForce)
    guard nonnegative(force, tolerance: forceRoundoff),
      nonnegative(add([maximumForce], scale(force, by: -1)), tolerance: forceRoundoff)
    else { return false }
    let worldScale = max(1, Vector3(initial[0], initial[1], initial[2]).length
      + Vector3(initial[18], initial[19], initial[20]).length)
    // Same native position-roundoff scale as the full-solid curve query. The
    // additional term bounds the bounded degree-nine coefficient arithmetic.
    let nativeRoundoff = 128 * Double.ulpOfOne * worldScale
    var gaps: [[Polynomial]] = []
    for point in rodPoints {
      let values = shoePoints.map { dot(normal, subtract($0, point)) }
      guard values.allSatisfy({ nonnegative($0, tolerance: nativeRoundoff + arithmeticError($0)) })
      else { return false }
      gaps.append(values)
    }
    guard let rodMaxX = rod.mesh.vertices.map(\.x).max(), let shoeMinX = shoe.vertices.map(\.x).min()
    else { return false }
    let rodFace = rod.mesh.vertices.indices.filter { rod.mesh.vertices[$0].x == rodMaxX }
    let shoeFace = shoe.vertices.indices.filter { shoe.vertices[$0].x == shoeMinX }
    guard rodFace.count == 4, shoeFace.count == 4,
      let y0 = shoeFace.map({ shoe.vertices[$0].y }).min(),
      let y1 = shoeFace.map({ shoe.vertices[$0].y }).max(),
      let z0 = shoeFace.map({ shoe.vertices[$0].z }).min(),
      let z1 = shoeFace.map({ shoe.vertices[$0].z }).max()
    else { return false }
    for index in rodFace {
      let relative = subtract(rodPoints[index], podOrigin)
      let y = dot(yAxis, relative), z = dot(zAxis, relative)
      for margin in [add(y, [-y0]), add([y1], scale(y, by: -1)),
        add(z, [-z0]), add([z1], scale(z, by: -1))] {
        guard nonnegative(add(margin, [-nativeRoundoff - arithmeticError(margin)]), tolerance: 0)
        else { return false }
      }
    }
    // An opening pair is supported by the separating plane alone. Positive
    // source force additionally needs a touching, nonclosing original face.
    if nonnegative(scale(force, by: -1), tolerance: forceRoundoff) { return true }
    return rodFace.contains { index in
      guard let face = shoeFace.first else { return false }
      let gap = gaps[index][face]
      let error = nativeRoundoff + arithmeticError(gap)
      let velocity = gap.enumerated().dropFirst().map { Double($0.offset) * $0.element / (duration * fraction) }
      return nonnegative(scale(gap, by: -1), tolerance: error)
        && nonnegative(velocity, tolerance: 1e-7 + arithmeticError(velocity))
    }
  }

  static func boundsTotalForce(_ stages: [Double], maximum: Double, fraction: Double = 1) -> Bool {
    guard stages.count == 4, stages.allSatisfy({ $0.isFinite && $0 >= 0 }),
      maximum.isFinite, maximum > 0, fraction > 0, fraction <= 1 else { return false }
    let force = [stages[0], (-3 * stages[0] + 2 * stages[1] + 2 * stages[2] - stages[3]) * fraction,
      (2 * stages[0] - 2 * stages[1] - 2 * stages[2] + 2 * stages[3]) * fraction * fraction]
    let error = arithmeticError(force)
    return nonnegative(force, tolerance: error)
      && nonnegative(add([maximum], scale(force, by: -1)), tolerance: error)
  }

  private static func constant(_ point: Vector3) -> Point { [[point.x], [point.y], [point.z]] }
  private static func subtract(_ a: Point, _ b: Point) -> Point {
    zip(a, b).map { add($0, scale($1, by: -1)) }
  }
  private static func dot(_ a: Point, _ b: Point) -> Polynomial {
    zip(a, b).reduce([0.0]) { add($0, multiply($1.0, $1.1)) }
  }
  private static func add(_ a: Polynomial, _ b: Polynomial) -> Polynomial {
    (0..<max(a.count, b.count)).map { (a.indices.contains($0) ? a[$0] : 0) + (b.indices.contains($0) ? b[$0] : 0) }
  }
  private static func scale(_ value: Polynomial, by factor: Double) -> Polynomial { value.map { $0 * factor } }
  private static func multiply(_ a: Polynomial, _ b: Polynomial) -> Polynomial {
    var result = Array(repeating: 0.0, count: a.count + b.count - 1)
    for i in a.indices { for j in b.indices { result[i + j] += a[i] * b[j] } }
    return result
  }
  private static func arithmeticError(_ value: Polynomial) -> Double {
    2048 * Double.ulpOfOne * max(1, value.reduce(0) { $0 + abs($1) })
  }
  private static func choose(_ n: Int, _ k: Int) -> Double {
    guard k > 0 else { return 1 }
    return (1...k).reduce(1.0) { $0 * Double(n - k + $1) / Double($1) }
  }
  private static func nonnegative(_ power: Polynomial, tolerance: Double) -> Bool {
    guard !power.isEmpty, power.count <= 10, power.allSatisfy(\.isFinite),
      tolerance.isFinite, tolerance >= 0 else { return false }
    let degree = power.count - 1
    let bernstein = (0...degree).map { k in
      (0...k).reduce(0.0) { $0 + power[$1] * choose(k, $1) / choose(degree, $1) }
    }
    var pending: [([Double], Int)] = [(bernstein, 0)]
    while let (bounds, depth) = pending.popLast() {
      if bounds.allSatisfy({ $0 >= -tolerance }) { continue }
      guard depth < 12, bounds.contains(where: { $0 >= -tolerance }) else { return false }
      var row = bounds, left = [bounds[0]], right = [bounds[bounds.count - 1]]
      while row.count > 1 {
        row = zip(row, row.dropFirst()).map { ($0 + $1) * 0.5 }
        left.append(row[0]); right.append(row[row.count - 1])
      }
      pending.append((Array(right.reversed()), depth + 1))
      pending.append((left, depth + 1))
    }
    return true
  }
}
