import Foundation

/// Source-specific material coordinates, not a native lifetime/event grant.
/// One atlas is born from the actual full compound's represented mesh. Every
/// descendant retains these same points, including initially hidden cut faces.
final class NativeC01InquiryCompoundMaterialAtlas: Sendable {
  typealias Shape = NativeC01InquiryCompoundRepresentation
  typealias Role = NativeC01InquiryFixtureGeometry.Part
  typealias Solver = NativeC01InquiryCompoundValidatedCurve

  enum Failure: Error { case invalidAncestor, invalidSubset, invalidFrame, invalidVertex }

  struct FacetID: Sendable, Equatable {
    let role: Role
    let sourceFace: Int
    /// Support front consists of the fixed 5-by-3 source tiles. Other faces
    /// have no tile. A face key survives a different collinear edge split.
    let supportTile: Int?
  }

  fileprivate struct Entry: Sendable {
    let shape: Shape
    let vertices: [Int]
    let facets: [FacetID]
  }

  /// A view cannot be manufactured by a caller. Raw keys and mesh are DATA;
  /// actual native owner still binds this atlas identity to its real registry.
  struct View: Sendable {
    let atlas: NativeC01InquiryCompoundMaterialAtlas
    let representation: Shape
    let vertexIDs: [Int]
    let facetIDs: [FacetID]
    let meshInMaterialFrame: Mesh

    fileprivate init(atlas: NativeC01InquiryCompoundMaterialAtlas, entry: Entry) {
      self.atlas = atlas; representation = entry.shape
      vertexIDs = entry.vertices; facetIDs = entry.facets
      meshInMaterialFrame = .init(vertices: entry.vertices.map { atlas.vertices[$0] },
        faces: entry.shape.faces.map(\.indices), preserveWinding: true)
    }

    /// The relation is symbolic over represented inputs, then enclosed BEFORE
    /// rotation. Equal COM scalars have exactly zero real displacement.
    func pointRelativeToCurrentCOM(vertex index: Int) throws -> Solver.VectorBox {
      guard vertexIDs.indices.contains(index) else { throw Failure.invalidVertex }
      let point = Solver.VectorBox.point(atlas.vertices[vertexIDs[index]])
      let current = representation.mass.centreOfMassSource
      if current == atlas.ancestorCOMSource { return point }
      return point + Solver.sourceCOMDifference(from: current, to: atlas.ancestorCOMSource)
    }

    func materialBounds(_ curve: Solver.Curve, vertex: Int, from start: Double,
      through end: Double) throws -> Solver.MaterialBounds
    {
      guard matches(curve.initial.representation),
        let result = curve.materialBounds(localPoint: try pointRelativeToCurrentCOM(vertex: vertex),
          from: start, through: end) else { throw Failure.invalidFrame }
      return result
    }

    func materialBounds(_ state: Solver.State, vertex: Int) throws -> Solver.MaterialBounds {
      guard matches(state.representation) else { throw Failure.invalidFrame }
      return try Solver.stateMaterialBounds(state, localPoint: pointRelativeToCurrentCOM(vertex: vertex))
    }

    func matches(_ shape: Shape) -> Bool {
      representation.mass.parts.map(\.kind) == shape.mass.parts.map(\.kind)
        && representation.mass.massKilograms == shape.mass.massKilograms
        && representation.mass.centreOfMassSource == shape.mass.centreOfMassSource
        && representation.sourceVertices == shape.sourceVertices
        && representation.meshAtCentreOfMass.vertices == shape.meshAtCentreOfMass.vertices
        && representation.meshAtCentreOfMass.faces == shape.meshAtCentreOfMass.faces
    }
  }

  /// This actual construction path binds old/new state enclosures and views to
  /// one material atlas. It is a mathematical transfer candidate. G1 must bind
  /// a genuine accepted cut/death, keep source material alive as appropriate,
  /// and qualify every new contact frontier before any native adoption.
  struct ComponentTransfer: Sendable {
    let parentState: Solver.State
    let parentView: View
    let componentState: Solver.State
    let componentView: View

    fileprivate init(parentState: Solver.State, parentView: View,
      componentState: Solver.State, componentView: View)
    {
      self.parentState = parentState; self.parentView = parentView
      self.componentState = componentState; self.componentView = componentView
    }
  }

  let ancestorCOMSource: Vector3
  /// Actual immutable represented material coordinates, never recentered.
  let vertices: [Vector3]
  /// Source coordinates name the material; they do not replace represented
  /// points with a nominal source-minus-newCOM mesh on a later separation.
  let sourceVertexKeys: [Vector3]
  private let entries: [Entry]

  private init(ancestorCOMSource: Vector3, vertices: [Vector3],
    sourceVertexKeys: [Vector3], entries: [Entry])
  {
    self.ancestorCOMSource = ancestorCOMSource; self.vertices = vertices
    self.sourceVertexKeys = sourceVertexKeys; self.entries = entries
  }

  /// Fixed C01 star graph has eight support-containing subsets and three
  /// single-head components. Cataloguing latent faces issues no cut right.
  static func make(ancestor: Shape) throws -> NativeC01InquiryCompoundMaterialAtlas {
    let roles = ancestor.mass.parts.map(\.kind)
    guard roles.count == Role.allCases.count,
      Role.allCases.allSatisfy({ roles.contains($0) }),
      ancestor.sourceVertices.count == ancestor.meshAtCentreOfMass.vertices.count
    else { throw Failure.invalidAncestor }
    var keys = ancestor.sourceVertices
    var vertices = ancestor.meshAtCentreOfMass.vertices
    var entries: [Entry] = []
    let heads: [Role] = [.head0, .head1, .head2]
    var subsets: [[Role]] = []
    for mask in 0..<8 {
      subsets.append([.support] + heads.enumerated().compactMap { index, role in
        mask & (1 << index) != 0 ? role : nil
      })
    }
    subsets.append(contentsOf: heads.map { [$0] })
    for subset in subsets {
      guard let shape = Shape.make(parts: subset) else { throw Failure.invalidSubset }
      let mapped = shape.sourceVertices.map { source -> Int in
        if let index = keys.firstIndex(of: source) { return index }
        // Only genuinely latent source vertices are initialized here, once at
        // atlas birth in the ANCESTOR frame. Existing points are never rebuilt.
        keys.append(source)
        vertices.append(source - ancestor.mass.centreOfMassSource)
        return keys.count - 1
      }
      let facets = try shape.faces.map { try facetID($0, shape: shape) }
      guard vertices.allSatisfy(\.finite), Set(mapped).count == mapped.count
      else { throw Failure.invalidAncestor }
      entries.append(.init(shape: shape, vertices: mapped, facets: facets))
    }
    return .init(ancestorCOMSource: ancestor.mass.centreOfMassSource,
      vertices: vertices, sourceVertexKeys: keys, entries: entries)
  }

  func view(parts roles: [Role]) throws -> View {
    guard !roles.isEmpty, Set(roles).count == roles.count,
      let entry = entries.first(where: { entry in
        let actual = entry.shape.mass.parts.map(\.kind)
        return actual.count == roles.count && actual.allSatisfy { roles.contains($0) }
      }) else { throw Failure.invalidSubset }
    return .init(atlas: self, entry: entry)
  }

  func transfer(_ parent: Solver.State, view: View, parts roles: [Role]) throws -> ComponentTransfer {
    guard !roles.isEmpty, Set(roles).count == roles.count,
      view.atlas === self, view.matches(parent.representation),
      roles.allSatisfy({ role in view.representation.mass.parts.contains { $0.kind == role } })
    else { throw Failure.invalidFrame }
    if roles.count == view.representation.mass.parts.count {
      // A mathematical no-op keeps the exact original enclosures and view.
      return .init(parentState: parent, parentView: view, componentState: parent, componentView: view)
    }
    let selected = try self.view(parts: roles)
    let state = try Solver.component(parent, parts: selected.representation.mass.parts.map(\.kind))
    guard selected.matches(state.representation) else { throw Failure.invalidFrame }
    return .init(parentState: parent, parentView: view, componentState: state, componentView: selected)
  }

  private static func facetID(_ face: Shape.Face, shape: Shape) throws -> FacetID {
    guard face.role == .support, face.sourceFace == 0 else {
      return .init(role: face.role, sourceFace: face.sourceFace, supportTile: nil)
    }
    let points = face.indices.map { shape.sourceVertices[$0] }
    let xs: [Double] = [-301, -299, -1, 1, 299, 301]
    let ys: [Double] = [-1, 1, 99, 101]
    guard let x0 = points.map(\.x).min(), let x1 = points.map(\.x).max(),
      let y0 = points.map(\.y).min(), let y1 = points.map(\.y).max(),
      let x = xs.dropLast().firstIndex(of: x0), let y = ys.dropLast().firstIndex(of: y0),
      xs[x + 1] == x1, ys[y + 1] == y1, points.allSatisfy({ $0.z == 1 })
    else { throw Failure.invalidAncestor }
    return .init(role: face.role, sourceFace: face.sourceFace, supportTile: x * 3 + y)
  }
}


extension NativeC01InquiryCompoundMaterialAtlas {
  static func prepare(ancestor: Shape, work: inout NativeC01InquiryCurveGeometry.Work)
    -> NativeC01InquiryPreparationWork.Outcome<NativeC01InquiryCompoundMaterialAtlas>
  {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try c01Make(ancestor: ancestor, meter: meter)
    }
  }

  /// Pays this actual view allocation only. The actual atlas construction and
  /// its ancestor source shape require their own retained real preparation.
  func prepareView(parts: [Role], work: inout NativeC01InquiryCurveGeometry.Work)
    -> NativeC01InquiryPreparationWork.Outcome<View>
  {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      try c01View(parts: parts, meter: meter)
    }
  }

  static func c01Make(ancestor: Shape, meter: NativeC01InquiryPreparationWork.Meter) throws -> NativeC01InquiryCompoundMaterialAtlas {
    try meter.records(ancestor.mass.parts.count, .atlas)
    try meter.records(Role.allCases.count * ancestor.mass.parts.count, .atlas)
    let roles = ancestor.mass.parts.map(\.kind)
    guard roles.count == Role.allCases.count,
      Role.allCases.allSatisfy({ roles.contains($0) }),
      ancestor.sourceVertices.count == ancestor.meshAtCentreOfMass.vertices.count
    else { throw Failure.invalidAncestor }
    try meter.records(ancestor.sourceVertices.count, .atlas)
    try meter.records(ancestor.meshAtCentreOfMass.vertices.count, .atlas)
    var keys = ancestor.sourceVertices
    var vertices = ancestor.meshAtCentreOfMass.vertices
    var entries: [Entry] = []
    let heads: [Role] = [.head0, .head1, .head2]
    var subsets: [[Role]] = []
    for mask in 0..<8 {
      try meter.records(heads.count, .atlas)
      subsets.append([.support] + heads.enumerated().compactMap { index, role in
        mask & (1 << index) != 0 ? role : nil
      })
    }
    try meter.records(heads.count, .atlas)
    subsets.append(contentsOf: heads.map { [$0] })
    for subset in subsets {
      try meter.node(.atlas)
      let shape = try Shape.c01Make(parts: subset, meter: meter)
      let mapped = try shape.sourceVertices.map { source -> Int in
        try meter.records(keys.count, .atlas)
        if let index = keys.firstIndex(of: source) { return index }
        // Only genuinely latent source vertices are initialized here, once at
        // atlas birth in the ANCESTOR frame. Existing points are never rebuilt.
        try meter.records(keys.count, .atlas)
        try meter.records(vertices.count, .atlas)
        try meter.records(1, .atlas)
        keys.append(source)
        vertices.append(source - ancestor.mass.centreOfMassSource)
        return keys.count - 1
      }
      let facets = try shape.faces.map { face in
        try meter.records(1, .atlas)
        if face.role == .support && face.sourceFace == 0 {
          for _ in 0..<10 { try meter.records(face.indices.count, .atlas) }
          try meter.records(8, .atlas)
        }
        return try facetID(face, shape: shape)
      }
      try meter.records(vertices.count, .atlas)
      try meter.records(mapped.count, .atlas)
      guard vertices.allSatisfy(\.finite), Set(mapped).count == mapped.count
      else { throw Failure.invalidAncestor }
      entries.append(.init(shape: shape, vertices: mapped, facets: facets))
    }
    return .init(ancestorCOMSource: ancestor.mass.centreOfMassSource,
      vertices: vertices, sourceVertexKeys: keys, entries: entries)
  }

  func c01View(parts roles: [Role], meter: NativeC01InquiryPreparationWork.Meter) throws -> View {
    try meter.records(roles.count, .materialView)
    guard !roles.isEmpty, Set(roles).count == roles.count,
      let entry = try entries.first(where: { entry in
        try meter.records(1, .materialView)
        try meter.records(entry.shape.mass.parts.count, .materialView)
        try meter.records(entry.shape.mass.parts.count * roles.count, .materialView)
        let actual = entry.shape.mass.parts.map(\.kind)
        return actual.count == roles.count && actual.allSatisfy { roles.contains($0) }
      }) else { throw Failure.invalidSubset }
    try meter.records(entry.vertices.count, .materialView)
    try meter.records(entry.shape.faces.count, .materialView)
    return .init(atlas: self, entry: entry)
  }


}


extension NativeC01InquiryCompoundMaterialAtlas {
  func prepareTransfer(_ parent: Solver.State, view: View, parts roles: [Role],
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<ComponentTransfer> {
    NativeC01InquiryPreparationWork.perform(work: &work) { meter in
      guard roles.count <= Role.allCases.count else { throw Failure.invalidFrame }
      try meter.records(roles.count, .materialView)
      try c01ReserveShapeMatch(view.representation, meter: meter)
      try c01ReserveShapeMatch(parent.representation, meter: meter)
      try meter.records(roles.count * parent.representation.mass.parts.count, .materialView)
      guard !roles.isEmpty, Set(roles).count == roles.count,
        view.atlas === self, view.matches(parent.representation),
        roles.allSatisfy({ role in view.representation.mass.parts.contains { $0.kind == role } })
      else { throw Failure.invalidFrame }
      if roles.count == view.representation.mass.parts.count {
        return .init(parentState: parent, parentView: view, componentState: parent, componentView: view)
      }
      let selected = try c01View(parts: roles, meter: meter)
      let state = try Solver.c01Component(parent, representation: selected.representation, meter: meter)
      // The selected representation is used directly by the private State
      // initializer; no unmetered duplicate Shape.make or second view exists.
      return .init(parentState: parent, parentView: view, componentState: state, componentView: selected)
    }
  }

  private func c01ReserveShapeMatch(_ shape: Shape,
    meter: NativeC01InquiryPreparationWork.Meter) throws
  {
    try meter.records(shape.mass.parts.count, .materialView)
    try meter.records(shape.sourceVertices.count, .materialView)
    try meter.records(shape.meshAtCentreOfMass.vertices.count, .materialView)
    try meter.records(shape.meshAtCentreOfMass.faces.count, .materialView)
    for face in shape.meshAtCentreOfMass.faces { try meter.records(face.count, .materialView) }
  }
}
