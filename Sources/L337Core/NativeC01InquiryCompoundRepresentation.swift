import Foundation

/// One source-specific exterior. This value installs no native registration.
/// Render/ray/contact/sweep adapters must consume this same COM mesh and pose.
struct NativeC01InquiryCompoundRepresentation: Sendable {
  typealias Role = NativeC01InquiryFixtureGeometry.Part
  struct Face: Sendable {
    let role: Role
    let sourceFace: Int
    let indices: [Int]
  }

  let mass: NativeC01InquiryCompoundMassProperties.Assembly
  let sourceVertices: [Vector3]
  let faces: [Face]
  let meshAtCentreOfMass: Mesh

  private init(mass: NativeC01InquiryCompoundMassProperties.Assembly,
    sourceVertices: [Vector3], faces: [Face], mesh: Mesh)
  {
    self.mass = mass; self.sourceVertices = sourceVertices
    self.faces = faces; meshAtCentreOfMass = mesh
  }

  static func make() -> Self? {
    make(parts: Role.allCases)
  }

  /// One actually connected source component: support plus joined heads, or
  /// one detached head. G1 owns event/graph authorization and native currentness.
  static func make(parts roles: [Role]) -> Self? {
    guard let mass = NativeC01InquiryCompoundMassProperties.assembly(parts: roles),
      roles.contains(.support) || roles.count == 1 else { return nil }
    var vertices: [Vector3] = []
    var faces: [Face] = []
    func append(_ points: [Vector3], role: Role, sourceFace: Int) {
      let indices = points.map { point in
        if let index = vertices.firstIndex(of: point) { return index }
        vertices.append(point)
        return vertices.count - 1
      }
      faces.append(.init(role: role, sourceFace: sourceFace, indices: indices))
    }
    for role in roles {
      let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: role)
      for (index, face) in descriptor.mesh.faces.enumerated() {
        if role == .support && index == 0 { continue }
        if role != .support && roles.contains(.support) && index == 1 { continue }
        append(face.map { descriptor.centreNative + descriptor.mesh.vertices[$0] },
          role: role, sourceFace: index)
      }
    }
    // Only the three exact internal contact patches disappear from the union.
    let xs: [Double] = [-301, -299, -1, 1, 299, 301]
    let ys: [Double] = [-1, 1, 99, 101]
    for x in 0..<5 where roles.contains(.support) {
      for y in 0..<3 {
        if (x == 0 && y == 0 && roles.contains(.head0))
          || (x == 2 && y == 2 && roles.contains(.head1))
          || (x == 4 && y == 0 && roles.contains(.head2)) { continue }
        append([.init(xs[x], ys[y], 1), .init(xs[x], ys[y + 1], 1),
          .init(xs[x + 1], ys[y + 1], 1), .init(xs[x + 1], ys[y], 1)],
          role: .support, sourceFace: 0)
      }
    }
    // Source coordinates are fixed integers. Split shared edges before the
    // one common COM subtraction; native consumers must never independently
    // rebuild head/support world coordinates from rounded body-centre poses.
    let conforming = faces.map { face in
      var boundary: [Int] = []
      for index in face.indices.indices {
        let a = vertices[face.indices[index]]
        let b = vertices[face.indices[(index + 1) % face.indices.count]]
        let edge = b - a
        let axis = edge.x != 0 ? 0 : edge.y != 0 ? 1 : 2
        func component(_ p: Vector3) -> Double { axis == 0 ? p.x : axis == 1 ? p.y : p.z }
        let candidates = vertices.indices.filter { candidate in
          let p = vertices[candidate]
          let aligned = axis == 0 ? p.y == a.y && p.z == a.z
            : axis == 1 ? p.x == a.x && p.z == a.z : p.x == a.x && p.y == a.y
          return aligned && component(p) >= min(component(a), component(b))
            && component(p) <= max(component(a), component(b))
        }.sorted { component(a) < component(b)
          ? component(vertices[$0]) < component(vertices[$1])
          : component(vertices[$0]) > component(vertices[$1]) }
        boundary.append(contentsOf: candidates.dropLast())
      }
      return Face(role: face.role, sourceFace: face.sourceFace, indices: boundary)
    }
    let expectedFaces = roles.contains(.support) ? 20 + 4 * (roles.count - 1) : 6
    guard conforming.count == expectedFaces, vertices.allSatisfy(\.finite),
      conforming.allSatisfy({ $0.indices.count >= 4 && Set($0.indices).count == $0.indices.count })
    else { return nil }
    let centred = vertices.map { $0 - mass.centreOfMassSource }
    guard centred.allSatisfy(\.finite) else { return nil }
    return .init(mass: mass, sourceVertices: vertices, faces: conforming,
      mesh: .init(vertices: centred, faces: conforming.map(\.indices), preserveWinding: true))
  }
}


extension NativeC01InquiryCompoundRepresentation {
  /// Actual source construction entry. Prior unmetered make is compatibility
  /// only; G1 native admission must retain/debit this real result or failure.
  static func prepare(parts: [Role], work: inout NativeC01InquiryCurveGeometry.Work)
    -> NativeC01InquiryPreparationWork.Outcome<Self>
  {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try c01Make(parts: parts, meter: meter)
    }
  }

  static func c01Make(parts roles: [Role], meter: NativeC01InquiryPreparationWork.Meter) throws -> Self {
    guard !roles.isEmpty, roles.count <= Role.allCases.count
    else {
      throw NativeC01InquiryPreparationWork.Failure.invalidSource
    }
    try c01ReserveMass(parts: roles, meter: meter)
    guard let mass = NativeC01InquiryCompoundMassProperties.assembly(parts: roles),
      roles.contains(.support) || roles.count == 1 else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    var vertices: [Vector3] = []
    var faces: [Face] = []
    func append(_ points: [Vector3], role: Role, sourceFace: Int) throws {
      let indices = try points.map { point in
        try meter.records(vertices.count, .sourceRepresentation)
        if let index = vertices.firstIndex(of: point) { return index }
        try meter.records(1, .sourceRepresentation)
        vertices.append(point)
        return vertices.count - 1
      }
      try meter.records(1, .sourceRepresentation)
      faces.append(.init(role: role, sourceFace: sourceFace, indices: indices))
    }
    for role in roles {
      try meter.records(1, .sourceRepresentation)
      let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: role)
      for (index, face) in descriptor.mesh.faces.enumerated() {
        try meter.records(1, .sourceRepresentation)
        if role == .support && index == 0 { continue }
        if role != .support && roles.contains(.support) && index == 1 { continue }
        try meter.records(face.count, .sourceRepresentation)
        try append(face.map { descriptor.centreNative + descriptor.mesh.vertices[$0] },
          role: role, sourceFace: index)
      }
    }
    // Only the three exact internal contact patches disappear from the union.
    let xs: [Double] = [-301, -299, -1, 1, 299, 301]
    let ys: [Double] = [-1, 1, 99, 101]
    for x in 0..<5 where roles.contains(.support) {
      for y in 0..<3 {
        if (x == 0 && y == 0 && roles.contains(.head0))
          || (x == 2 && y == 2 && roles.contains(.head1))
          || (x == 4 && y == 0 && roles.contains(.head2)) { continue }
        try meter.records(4, .sourceRepresentation)
        try append([.init(xs[x], ys[y], 1), .init(xs[x], ys[y + 1], 1),
          .init(xs[x + 1], ys[y + 1], 1), .init(xs[x + 1], ys[y], 1)],
          role: .support, sourceFace: 0)
      }
    }
    // Source coordinates are fixed integers. Split shared edges before the
    // one common COM subtraction; native consumers must never independently
    // rebuild head/support world coordinates from rounded body-centre poses.
    let conforming = try faces.map { face in
      try meter.records(1, .sourceRepresentation)
      var boundary: [Int] = []
      for index in face.indices.indices {
        try meter.records(1, .sourceRepresentation)
        let a = vertices[face.indices[index]]
        let b = vertices[face.indices[(index + 1) % face.indices.count]]
        let edge = b - a
        let axis = edge.x != 0 ? 0 : edge.y != 0 ? 1 : 2
        func component(_ p: Vector3) -> Double { axis == 0 ? p.x : axis == 1 ? p.y : p.z }
        try meter.records(vertices.count, .sourceRepresentation)
        try meter.records(vertices.count, .sourceRepresentation)
        let candidates = try vertices.indices.filter { candidate in
          let p = vertices[candidate]
          let aligned = axis == 0 ? p.y == a.y && p.z == a.z
            : axis == 1 ? p.x == a.x && p.z == a.z : p.x == a.x && p.y == a.y
          return aligned && component(p) >= min(component(a), component(b))
            && component(p) <= max(component(a), component(b))
        }.sorted {
          try meter.records(1, .sourceRepresentation)
          return component(a) < component(b)
          ? component(vertices[$0]) < component(vertices[$1])
          : component(vertices[$0]) > component(vertices[$1]) }
        try meter.records(candidates.count, .sourceRepresentation)
        boundary.append(contentsOf: candidates.dropLast())
      }
      return Face(role: face.role, sourceFace: face.sourceFace, indices: boundary)
    }
    let expectedFaces = roles.contains(.support) ? 20 + 4 * (roles.count - 1) : 6
    try meter.records(vertices.count, .sourceRepresentation)
    guard conforming.count == expectedFaces, vertices.allSatisfy(\.finite),
      try conforming.allSatisfy({ face in
        try meter.records(face.indices.count, .sourceRepresentation)
        return face.indices.count >= 4 && Set(face.indices).count == face.indices.count
      })
    else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    try meter.records(vertices.count, .sourceRepresentation)
    let centred = vertices.map { $0 - mass.centreOfMassSource }
    try meter.records(centred.count, .sourceRepresentation)
    guard centred.allSatisfy(\.finite) else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    try meter.records(conforming.count, .sourceRepresentation)
    return .init(mass: mass, sourceVertices: vertices, faces: conforming,
      mesh: .init(vertices: centred, faces: conforming.map(\.indices), preserveWinding: true))
  }
  /// Closed precharge from PINNED G1 source mass helper (6c2406bb...), not an
  /// assumed hardware cost or alternate mass law. Each rectangle/include and
  /// Moment/Tensor record has fixed arity; all variable arrays are itemized.
  private static func c01ReserveMass(parts roles: [Role],
    meter: NativeC01InquiryPreparationWork.Meter) throws
  {
    try meter.records(Role.allCases.count * roles.count, .sourceMass)
    try meter.records(roles.count, .sourceMass)
    for role in roles {
      // Lazy descriptor, local fixed comparison arrays, then TWO geometry
      // equality passes. Native conversion maps the eight lazy vertices too.
      for _ in 0..<4 {
        try meter.records(8, .sourceMass)
        try meter.records(6, .sourceMass)
        try meter.records(24, .sourceMass)
      }
      try meter.records(8, .sourceMass)
      try meter.records(1, .sourceMass) // fixed descriptor centre conversion
      let rectangles = 6 + (role == .support ? 3 : 1)
      try meter.records(rectangles, .sourceMass) // fixed rectangle moment records
      try meter.records(rectangles, .sourceMass) // fixed include records
      try meter.records(6, .sourceMass) // raw second-moment finite predicates
      try meter.records(8, .sourceMass) // tensor fields/minor/determinant predicates
      try meter.records(3, .sourceMass) // first moment finite predicates
      try meter.records(3, .sourceMass) // COM finite predicates
      try meter.records(4, .sourceMass) // intrinsic/return/tensor/shift Moment records
    }
    try meter.records(roles.count, .sourceMass) // parts map
    try meter.records(roles.count, .sourceMass) // equality
    try meter.records(roles.count, .sourceMass) // reduction
    try meter.records(6, .sourceMass)
    try meter.records(8, .sourceMass)
    try meter.records(3, .sourceMass)
    try meter.records(3, .sourceMass)
    try meter.records(2, .sourceMass) // final Moment/Tensor records
  }

}
