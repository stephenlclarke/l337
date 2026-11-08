import Foundation

/// New C01 source estimates. These moments install no native mass or motion owner.
enum NativeC01InquiryCompoundMassProperties {
  struct Tensor: Sendable, Equatable {
    let xx: Double
    let yy: Double
    let zz: Double
    let xy: Double
    let xz: Double
    let yz: Double

    var finitePositiveDefinite: Bool {
      let minor = xx * yy - xy * xy
      let determinant = xx * (yy * zz - yz * yz)
        - xy * (xy * zz - yz * xz) + xz * (xy * yz - yy * xz)
      return [xx, yy, zz, xy, xz, yz, minor, determinant].allSatisfy(\.isFinite)
        && xx > 0 && minor > 0 && determinant > 0
    }
  }

  struct Part: Sendable {
    let kind: NativeC01InquiryFixtureGeometry.Part
    let massKilograms: Double
    let centreOfMassLocal: Vector3
    let inertiaAtCentreOfMass: Tensor
    fileprivate let moments: Moments
  }

  struct Assembly: Sendable {
    let parts: [Part]
    let massKilograms: Double
    let centreOfMassSource: Vector3
    let inertiaAtCentreOfMass: Tensor
  }

  /// Raw second moments use descriptor-centred axes; they are not an inertia tensor.
  fileprivate struct Moments: Sendable {
    var mass: Double = 0
    var first = Vector3(0, 0, 0)
    var xx: Double = 0
    var yy: Double = 0
    var zz: Double = 0
    var xy: Double = 0
    var xz: Double = 0
    var yz: Double = 0

    mutating func include(_ other: Moments) {
      mass += other.mass
      first = first + other.first
      xx += other.xx; yy += other.yy; zz += other.zz
      xy += other.xy; xz += other.xz; yz += other.yz
    }

    func shifted(by p: Vector3) -> Moments {
      .init(mass: mass, first: first + p * mass,
        xx: xx + 2 * p.x * first.x + mass * p.x * p.x,
        yy: yy + 2 * p.y * first.y + mass * p.y * p.y,
        zz: zz + 2 * p.z * first.z + mass * p.z * p.z,
        xy: xy + p.x * first.y + first.x * p.y + mass * p.x * p.y,
        xz: xz + p.x * first.z + first.x * p.z + mass * p.x * p.z,
        yz: yz + p.y * first.z + first.y * p.z + mass * p.y * p.z)
    }

    var centre: Vector3 { first * (1 / mass) }
    var tensor: Tensor {
      let qxx = xx - first.x * first.x / mass
      let qyy = yy - first.y * first.y / mass
      let qzz = zz - first.z * first.z / mass
      return .init(xx: qyy + qzz, yy: qxx + qzz, zz: qxx + qyy,
        xy: -(xy - first.x * first.y / mass),
        xz: -(xz - first.x * first.z / mass),
        yz: -(yz - first.y * first.z / mass))
    }

    var valid: Bool {
      mass.isFinite && mass > 0 && first.finite && centre.finite
        && [xx, yy, zz, xy, xz, yz].allSatisfy(\.isFinite)
        && tensor.finitePositiveDefinite
    }
  }

  /// The actual fixed source mesh and project metric must agree before using its budget.
  static func part(
    _ kind: NativeC01InquiryFixtureGeometry.Part, mesh: Mesh,
    metricRevision: String, metresPerWorldUnit: Double
  ) -> Part? {
    let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: kind)
    let support = kind == .support
    let half = support ? Vector3(301, 51, 1) : Vector3(1, 1, 1)
    let centre: Vector3
    switch kind {
    case .support: centre = .init(0, 50, 2)
    case .head0: centre = .init(-300, 0, 0)
    case .head1: centre = .init(0, 100, 0)
    case .head2: centre = .init(300, 0, 0)
    }
    let fixedVertices: [Vector3] = [
      .init(-half.x, -half.y, -half.z), .init(half.x, -half.y, -half.z),
      .init(half.x, half.y, -half.z), .init(-half.x, half.y, -half.z),
      .init(-half.x, -half.y, half.z), .init(half.x, -half.y, half.z),
      .init(half.x, half.y, half.z), .init(-half.x, half.y, half.z),
    ]
    let fixedFaces = [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
      [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ]
    guard NativeC01InquiryFixtureGeometry.revision == "c01-inquiry-apparatus-geometry-v1",
      metricRevision == NativeC01InquiryFixtureGeometry.metricRevision,
      metricRevision == "c01-inquiry-project-metres-v1",
      metresPerWorldUnit == NativeC01InquiryFixtureGeometry.metresPerWorldUnit,
      metresPerWorldUnit == 1, descriptor.centreNative == centre,
      descriptor.mesh.vertices == fixedVertices, descriptor.mesh.faces == fixedFaces,
      mesh.vertices == fixedVertices, mesh.faces == fixedFaces
    else { return nil }
    let x = Vector3(1, 0, 0), y = Vector3(0, 1, 0), z = Vector3(0, 0, 1)
    var result = Moments(mass: support ? 300 : 100)
    // All closed faces carry sheet mass before subtracting only the source joint patches.
    for sign in [-1.0, 1.0] {
      result.include(rectangle(centre: x * (sign * half.x), u: y, v: z,
        a: half.y, b: half.z, sign: 1))
      result.include(rectangle(centre: y * (sign * half.y), u: x, v: z,
        a: half.x, b: half.z, sign: 1))
      result.include(rectangle(centre: z * (sign * half.z), u: x, v: y,
        a: half.x, b: half.y, sign: 1))
    }
    if support {
      for centre in [Vector3(-300, -50, -1), .init(0, 50, -1), .init(300, -50, -1)] {
        result.include(rectangle(centre: centre, u: x, v: y, a: 1, b: 1, sign: -1))
      }
    } else {
      result.include(rectangle(centre: .init(0, 0, 1), u: x, v: y, a: 1, b: 1, sign: -1))
    }
    let sourceMass = NativeC01InquiryFixtureGeometry.physicalBudget(for: kind).massKilograms
    guard result.valid, result.mass == sourceMass else { return nil }
    return .init(kind: kind, massKilograms: result.mass, centreOfMassLocal: result.centre,
      inertiaAtCentreOfMass: result.tensor, moments: result)
  }

  /// Aggregate actual source constituents by the parallel-axis law, never by render radius.
  static func assembly() -> Assembly? {
    assembly(parts: NativeC01InquiryFixtureGeometry.Part.allCases)
  }

  /// Mass DATA for a selected surviving set. Only the native owner can authorize its topology.
  static func assembly(parts selected: [NativeC01InquiryFixtureGeometry.Part]) -> Assembly? {
    let canonical = NativeC01InquiryFixtureGeometry.Part.allCases.filter { selected.contains($0) }
    guard !selected.isEmpty, selected == canonical else { return nil }
    var result = Moments()
    var parts: [Part] = []
    for kind in selected {
      let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: kind)
      guard descriptor.centreNative.finite,
        let component = part(kind, mesh: descriptor.mesh,
          metricRevision: NativeC01InquiryFixtureGeometry.metricRevision,
          metresPerWorldUnit: NativeC01InquiryFixtureGeometry.metresPerWorldUnit)
      else { return nil }
      parts.append(component)
      result.include(component.moments.shifted(by: descriptor.centreNative))
    }
    guard parts.map(\.kind) == selected, result.valid,
      result.mass == parts.reduce(0, { $0 + $1.massKilograms })
    else { return nil }
    return .init(parts: parts, massKilograms: result.mass, centreOfMassSource: result.centre,
      inertiaAtCentreOfMass: result.tensor)
  }

  /// Fixed uniform sheet rectangle: first moment m*q, second moment integral of r*r^T.
  private static func rectangle(
    centre q: Vector3, u: Vector3, v: Vector3, a: Double, b: Double, sign: Double
  ) -> Moments {
    let mass = sign * 14 * (4 * a * b)
    let au = a * a / 3, bv = b * b / 3
    return .init(mass: mass, first: q * mass,
      xx: mass * (q.x * q.x + au * u.x * u.x + bv * v.x * v.x),
      yy: mass * (q.y * q.y + au * u.y * u.y + bv * v.y * v.y),
      zz: mass * (q.z * q.z + au * u.z * u.z + bv * v.z * v.z),
      xy: mass * (q.x * q.y + au * u.x * u.y + bv * v.x * v.y),
      xz: mass * (q.x * q.z + au * u.x * u.z + bv * v.x * v.z),
      yz: mass * (q.y * q.z + au * u.y * u.z + bv * v.y * v.z))
  }
}
