import Foundation

/// Newly exposed C01 designed-patch contacts at a mathematical cut boundary.
/// G1 binds a genuine accepted cut/current native source and ALL other scene
/// contacts. This helper creates no native event, separation or clear receipt.
enum NativeC01InquiryCutContactSet {
  typealias Role = NativeC01InquiryFixtureGeometry.Part
  typealias Atlas = NativeC01InquiryCompoundMaterialAtlas
  typealias Solver = NativeC01InquiryCompoundValidatedCurve
  typealias G = NativeC01InquiryCurveGeometry

  enum Failure: Error { case invalidBoundary, incompletePatch, unprovenOperator }

  struct Component: Sendable {
    let state: Solver.State
    let view: Atlas.View
  }
  struct Patch: Sendable {
    let head: Role
    let supportComponent: Int
    let headComponent: Int
    let supportFacet: Atlas.FacetID
    let headFacet: Atlas.FacetID
    let materialVertexIDs: [Int]
    let normalFromSupportIntoHead: Vector3
  }
  final class Boundary: Sendable {
    let parentState: Solver.State
    let parentView: Atlas.View
    let components: [Component]
    let patches: [Patch]
    let origin: BoundaryOrigin

    fileprivate init(parent: Solver.State, view: Atlas.View,
      components: [Component], patches: [Patch], origin: BoundaryOrigin)
    {
      parentState = parent; parentView = view
      self.components = components; self.patches = patches; self.origin = origin
    }
  }
  struct Row: Sendable {
    let patchIndex: Int
    let materialVertexID: Int
    /// Positive normal force acts on head; negative acts on support.
    let positiveComponent: Int
    let negativeComponent: Int
    let commonPoint: Solver.VectorBox
    let normal: Solver.VectorBox
  }
  struct ExternalWrench: Sendable {
    let worldForce: Solver.VectorBox
    let worldTorqueAtCOM: Solver.VectorBox
  }
  enum ForceModel: Sendable {
    /// Diagnostic FREE baseline, never proof actual external sources vanish.
    case free
    /// One explicit instantaneous exogenous wrench for EVERY component.
    /// Actual completeness/source/time/units remain native-owner obligations.
    case applied([ExternalWrench])
  }
  struct Operator: Sendable {
    let boundary: Boundary
    let rows: [Row]
    /// Row-major interval Delassus operator: acceleration = K * force + free.
    /// Planar corner rows can be redundant. No nonsingular inverse is assumed.
    let matrix: [Solver.Interval]
    /// Historical name: unconstrained baseline; .applied includes its actual
    /// supplied instantaneous exogenous wrenches before unknown contact forces.
    let freeAcceleration: [Solver.Interval]
    let forceModel: ForceModel

    fileprivate init(boundary: Boundary, rows: [Row], matrix: [Solver.Interval],
      free: [Solver.Interval], forceModel: ForceModel)
    {
      self.boundary = boundary; self.rows = rows; self.matrix = matrix
      freeAcceleration = free
      self.forceModel = forceModel
    }
  }

  /// Proposed cut topology only. Every child is derived from the SAME retained
  /// parent via metered Atlas.prepareTransfer. Symbolic point/velocity coincidence is
  /// scoped to this boundary, never inferred from overlapping interval boxes.
  static func prepare(_ parent: Solver.State, view: Atlas.View, cutHeadEdges cuts: [Role],
    work: inout G.Work) throws -> Boundary
  {
    try work.reservePreparedMetadataRecords(cuts.count)
    try reserveShape(view.representation, work: &work)
    try reserveShape(parent.representation, work: &work)
    guard cuts.count <= NativeC01InquiryFixtureGeometry.designedJoints.count,
      Set(cuts).count == cuts.count, view.matches(parent.representation)
    else { throw Failure.invalidBoundary }
    let roles = parent.representation.mass.parts.map(\.kind)
    guard roles.contains(.support), cuts.allSatisfy({ $0 != .support && roles.contains($0) })
    else { throw Failure.invalidBoundary }
    let orderedCuts = [Role.head0, .head1, .head2].filter(cuts.contains)
    let groups = [roles.filter { !cuts.contains($0) }] + orderedCuts.map { [$0] }
    var components: [Component] = []
    for group in groups {
      try work.node()
      let transfer = try preparedTransfer(view.atlas.prepareTransfer(parent,
        view: view, parts: group, work: &work))
      components.append(.init(state: transfer.componentState, view: transfer.componentView))
    }
    var patches: [Patch] = []
    for (offset, head) in orderedCuts.enumerated() {
      try work.node()
      let headIndex = offset + 1
      let headView = components[headIndex].view
      let supportView = components[0].view
      try work.reservePreparedMetadataRecords(headView.facetIDs.count)
      guard let headFace = headView.facetIDs.firstIndex(where: { $0.role == head && $0.sourceFace == 1 })
      else { throw Failure.incompletePatch }
      let headKeys = try faceKeys(headView, face: headFace, work: &work)
      try work.reservePreparedMetadataRecords(headKeys.count)
      let headSet = Set(headKeys)
      guard headKeys.count == 4, headSet.count == 4 else { throw Failure.incompletePatch }
      var supportFace: Int?
      for face in supportView.facetIDs.indices {
        try work.reservePreparedMetadataRecords(1)
        let id = supportView.facetIDs[face]
        guard id.role == .support, id.sourceFace == 0 else { continue }
        let keys = try faceKeys(supportView, face: face, work: &work)
        try work.reservePreparedMetadataRecords(keys.count)
        if keys.count == 4 && Set(keys) == headSet {
          guard supportFace == nil else { throw Failure.incompletePatch }
          supportFace = face
        }
      }
      guard let supportFace else { throw Failure.incompletePatch }
      try work.reservePreparedMetadataRecords(headKeys.count)
      let source = headKeys.map { view.atlas.sourceVertexKeys[$0] }
      guard source.allSatisfy({ $0.z == 1 }) else { throw Failure.incompletePatch }
      let headWinding = (source[1] - source[0]).cross(source[2] - source[0])
      let supportKeys = try faceKeys(supportView, face: supportFace, work: &work)
      try work.reservePreparedMetadataRecords(supportKeys.count)
      let supportSource = supportKeys.map { view.atlas.sourceVertexKeys[$0] }
      let supportWinding = (supportSource[1] - supportSource[0]).cross(supportSource[2] - supportSource[0])
      guard headWinding.x == 0, headWinding.y == 0, headWinding.z > 0,
        supportWinding.x == 0, supportWinding.y == 0, supportWinding.z < 0
      else { throw Failure.incompletePatch }
      patches.append(.init(head: head, supportComponent: 0, headComponent: headIndex,
        supportFacet: supportView.facetIDs[supportFace], headFacet: headView.facetIDs[headFace],
        materialVertexIDs: headKeys, normalFromSupportIntoHead: .init(0, 0, -1)))
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(parent: parent, view: view, components: components, patches: patches, origin: .rigidParentTransfer)
  }

  /// Instantaneous resting-contact operator only. A complementarity solution
  /// and validated constrained/lift-off/new-contact remainder are still needed.
  /// No force is applied and no finite physical time is advanced here.
  static func prepareOperator(_ boundary: Boundary, work: inout G.Work) throws -> Operator {
    try prepareOperator(boundary, forceModel: .free, work: &work)
  }

  /// Actual native owner supplies all instantaneous exogenous forces/torques.
  /// No missing-component zero fill or arbitrary default baseline is allowed.
  static func prepareOperator(_ boundary: Boundary, externalWrenches: [ExternalWrench],
    work: inout G.Work) throws -> Operator
  {
    try work.reservePreparedMetadataRecords(externalWrenches.count)
    guard externalWrenches.count == boundary.components.count,
      externalWrenches.allSatisfy({ $0.worldForce.valid && $0.worldTorqueAtCOM.valid })
    else { throw Failure.invalidBoundary }
    return try prepareOperator(boundary, forceModel: .applied(externalWrenches), work: &work)
  }

  private static func prepareOperator(_ boundary: Boundary, forceModel: ForceModel,
    work: inout G.Work) throws -> Operator
  {
    try work.reservePreparedMetadataRecords(1)
    guard case .rigidParentTransfer = boundary.origin else { throw Failure.invalidBoundary }
    var rows: [Row] = []
    for (patchIndex, patch) in boundary.patches.enumerated() {
      try work.node()
      let normal = try Solver.stateWorldVector(boundary.parentState,
        sourceVector: .point(patch.normalFromSupportIntoHead))
      for key in patch.materialVertexIDs {
        try work.triangle()
        let local = pointRelativeToParent(boundary, key: key)
        let point = try Solver.stateMaterialBounds(boundary.parentState, localPoint: local).position
        rows.append(.init(patchIndex: patchIndex, materialVertexID: key,
          positiveComponent: patch.headComponent, negativeComponent: patch.supportComponent,
          commonPoint: point, normal: normal))
      }
    }
    var free: [Solver.Interval] = []
    var matrix: [Solver.Interval] = []
    for row in rows {
      try work.triangle()
      let head = try baselineAcceleration(boundary, component: row.positiveComponent,
        point: row.commonPoint, forceModel: forceModel)
      try work.triangle()
      let support = try baselineAcceleration(boundary, component: row.negativeComponent,
        point: row.commonPoint, forceModel: forceModel)
      let acceleration = G.dot(row.normal, head - support)
      guard acceleration.valid else { throw Failure.unprovenOperator }
      free.append(acceleration)
      for column in rows {
        try work.triangle()
        var coefficient = Solver.Interval.point(0)
        for (index, sign) in [(row.positiveComponent, 1.0), (row.negativeComponent, -1.0)] {
          let columnSign: Double
          if index == column.positiveComponent { columnSign = 1 }
          else if index == column.negativeComponent { columnSign = -1 }
          else { continue }
          try work.triangle()
          let response = try Solver.statePointForceResponse(boundary.components[index].state,
            applicationPoint: column.commonPoint, forceDirection: column.normal,
            observationPoint: row.commonPoint)
          coefficient = coefficient + G.dot(row.normal, response) * .point(sign * columnSign)
        }
        guard coefficient.valid else { throw Failure.unprovenOperator }
        matrix.append(coefficient)
      }
    }
    return .init(boundary: boundary, rows: rows, matrix: matrix, free: free, forceModel: forceModel)
  }

  private static func baselineAcceleration(_ boundary: Boundary, component: Int,
    point: Solver.VectorBox, forceModel: ForceModel) throws -> Solver.VectorBox
  {
    let state = boundary.components[component].state
    switch forceModel {
    case .free: return try Solver.stateFreePointAcceleration(state, point: point)
    case .applied(let wrenches):
      let value = wrenches[component]
      return try Solver.statePointAcceleration(state, point: point,
        worldForce: value.worldForce, worldTorqueAtCOM: value.worldTorqueAtCOM)
    }
  }

  /// Positive restricted FREE-FLOW candidate. Actual native owner must account
  /// for every force/torque/foreign contact over the ENTIRE proposed interval
  /// before interpreting this as attained motion. This is no completed native
  /// remainder, contact exclusion, force-free authority flag or clear receipt.
  struct SharedTranslationCandidate: Sendable {
    let boundary: Boundary
    let commonCurve: Solver.Curve
    let endpointComponents: [Component]
    var suppliedCurveWork: Solver.Work { commonCurve.work }

    fileprivate init(boundary: Boundary, curve: Solver.Curve, endpoints: [Component]) {
      self.boundary = boundary; commonCurve = curve; endpointComponents = endpoints
    }

    /// Conditional equivalent-union geometry input only. Consumer still checks
    /// actual prepared atlas metadata/mesh and ALL actual foreign inputs. G1
    /// binds every constituent material/facet/registry identity and force law.
    func geometrySource(prepared: G.Prepared, referencePose: ShipPose) -> G.Source {
      .init(curve: commonCurve, prepared: prepared, referencePose: referencePose,
        materialView: boundary.parentView)
    }
  }

  /// No new solver run or budget is hidden here: caller owns/debits the actual
  /// supplied free curve preparation once before passing remaining allowances.
  /// Exact singleton L=0 gives omega=qdot=0. All source components inherit the
  /// same translation, and f=0 satisfies their internal patch constraints in
  /// this FREE model. External forces/contacts can invalidate it immediately.
  static func prepareSharedTranslation(_ boundary: Boundary, curve: Solver.Curve,
    work: inout G.Work) throws -> SharedTranslationCandidate
  {
    try work.reservePreparedMetadataRecords(1)
    guard case .rigidParentTransfer = boundary.origin else { throw Failure.invalidBoundary }
    try work.node()
    try reserveShape(boundary.parentState.representation, work: &work)
    try reserveShape(curve.initial.representation, work: &work)
    try work.reservePreparedMetadataRecords(16)
    let parent = boundary.parentState
    guard boundary.parentView.matches(curve.initial.representation),
      parent.quaternion.components == curve.initial.quaternion.components,
      sameBox(parent.centreOfMass, curve.initial.centreOfMass),
      sameBox(parent.linearMomentum, curve.initial.linearMomentum),
      sameBox(parent.worldAngularMomentum, curve.initial.worldAngularMomentum),
      singletonZero(parent.worldAngularMomentum),
      curve.duration.isFinite, curve.duration > 0, curve.duration <= 0.1
    else { throw Failure.invalidBoundary }
    var endpoints: [Component] = []
    for component in boundary.components {
      try work.node()
      try work.reservePreparedMetadataRecords(component.view.representation.mass.parts.count)
      let roles = component.view.representation.mass.parts.map(\.kind)
      let transfer = try preparedTransfer(boundary.parentView.atlas.prepareTransfer(curve.endpoint,
        view: boundary.parentView, parts: roles, work: &work))
      endpoints.append(.init(state: transfer.componentState, view: transfer.componentView))
    }
    return .init(boundary: boundary, curve: curve, endpoints: endpoints)
  }

  private static func singletonZero(_ value: Solver.VectorBox) -> Bool {
    [value.x, value.y, value.z].allSatisfy { $0.lower == 0 && $0.upper == 0 }
  }

  private static func sameBox(_ a: Solver.VectorBox, _ b: Solver.VectorBox) -> Bool {
    a.x == b.x && a.y == b.y && a.z == b.z
  }

  private static func preparedTransfer(_ outcome: NativeC01InquiryPreparationWork.Outcome<Atlas.ComponentTransfer>)
    throws -> Atlas.ComponentTransfer
  {
    // Actual mutable caller G.Work already contains success OR failure debit.
    // No second report debit or late inference of earlier atlas build cost.
    switch outcome {
    case .prepared(let transfer, _): return transfer
    case .refused(.allowance, _): throw G.Failure.workBudgetExceeded
    case .refused: throw Failure.invalidBoundary
    }
  }

  private static func faceKeys(_ view: Atlas.View, face: Int, work: inout G.Work) throws -> [Int] {
    let indices = view.representation.faces[face].indices
    try work.reservePreparedMetadataRecords(indices.count)
    return indices.map { view.vertexIDs[$0] }
  }

  private static func pointRelativeToParent(_ boundary: Boundary, key: Int) -> Solver.VectorBox {
    let atlas = boundary.parentView.atlas
    let point = Solver.VectorBox.point(atlas.vertices[key])
    let current = boundary.parentState.representation.mass.centreOfMassSource
    if current == atlas.ancestorCOMSource { return point }
    return point + Solver.sourceCOMDifference(from: current, to: atlas.ancestorCOMSource)
  }

  private static func reserveShape(_ shape: Atlas.Shape, work: inout G.Work) throws {
    try work.reservePreparedMetadataRecords(shape.mass.parts.count)
    try work.reservePreparedMetadataRecords(shape.sourceVertices.count)
    try work.reservePreparedMetadataRecords(shape.meshAtCentreOfMass.vertices.count)
    try work.reservePreparedMetadataRecords(shape.faces.count)
    for face in shape.faces { try work.reservePreparedMetadataRecords(face.indices.count) }
  }
}

extension NativeC01InquiryCutContactSet {
  /// Current moving material constraint and its two time derivatives. These
  /// boxes are range DATA, never proof that g/gDot are identically zero.
  struct MovingRow: Sendable {
    let contact: Row
    let supportAnchor: Solver.VectorBox
    let gap: Solver.Interval
    let gapVelocity: Solver.Interval
    let baselineGapAcceleration: Solver.Interval
    /// +1 means the head back-face opposite-outward axis matches support n.
    let normalAlignment: Solver.Interval
  }
  struct MovingOperator: Sendable {
    let sourceBoundary: Boundary
    let current: [Component]
    let externalRanges: [ExternalWrench]
    let baselineFields: [Solver.ConstrainedBodyField]
    let rows: [MovingRow]
    let matrix: [Solver.Interval]
    let baseline: [Solver.Interval]

    fileprivate init(source: Boundary, current: [Component], external: [ExternalWrench],
      fields: [Solver.ConstrainedBodyField], rows: [MovingRow], matrix: [Solver.Interval], baseline: [Solver.Interval])
    {
      sourceBoundary = source; self.current = current; externalRanges = external
      baselineFields = fields; self.rows = rows; self.matrix = matrix; self.baseline = baseline
    }
  }

  /// Evaluates current constraint geometry over the supplied state ranges.
  /// Actual whole-cell force law/ranges/Jacobian and native currentness must
  /// come from G1. Supplying instantaneous boxes cannot certify a time cell.
  static func prepareMovingOperator(_ source: Boundary, current: [Component],
    externalRanges: [ExternalWrench], work: inout G.Work) throws -> MovingOperator
  {
    try work.query()
    try work.reservePreparedMetadataRecords(3)
    guard current.count == source.components.count, externalRanges.count == current.count,
      current.count > 0, current.count <= 4 else { throw Failure.invalidBoundary }
    var fields: [Solver.ConstrainedBodyField] = []
    for index in current.indices {
      try work.node()
      let component = current[index], original = source.components[index]
      try movingMatches(component, original: original, atlas: source.parentView.atlas, work: &work)
      let value = externalRanges[index]
      let field = try movingField(Solver.prepareConstrainedBodyField(component.state,
        worldForce: value.worldForce, worldTorqueAtCOM: value.worldTorqueAtCOM, work: &work))
      fields.append(field)
    }
    var rows: [MovingRow] = []
    var baseline: [Solver.Interval] = []
    for (patchIndex, patch) in source.patches.enumerated() {
      try work.node()
      try work.reservePreparedMetadataRecords(2)
      guard current.indices.contains(patch.supportComponent), current.indices.contains(patch.headComponent)
      else { throw Failure.invalidBoundary }
      let supportField = fields[patch.supportComponent], headField = fields[patch.headComponent]
      let normal = try Solver.constrainedWorldVector(supportField,
        local: .point(patch.normalFromSupportIntoHead), work: &work)
      let headAxis = try Solver.constrainedWorldVector(headField,
        local: .point(patch.normalFromSupportIntoHead), work: &work)
      try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3 + 3)
      let normalDot = supportField.worldAngularVelocity.cross(normal)
      let normalDDot = supportField.worldAngularAcceleration.cross(normal)
        + supportField.worldAngularVelocity.cross(supportField.worldAngularVelocity.cross(normal))
      try work.reservePreparedMetadataRecords(3)
      let alignment = G.dot(normal, headAxis)
      for key in patch.materialVertexIDs {
        try work.node()
        let head = try Solver.constrainedMaterialPoint(headField,
          local: movingLocalPoint(current[patch.headComponent], key: key, work: &work), work: &work)
        let support = try Solver.constrainedMaterialPoint(supportField,
          local: movingLocalPoint(current[patch.supportComponent], key: key, work: &work), work: &work)
        try work.reservePreparedMetadataRecords(3 + 3 + 3)
        let separation = head.position - support.position
        let relativeVelocity = head.velocity - support.velocity
        let relativeAcceleration = head.acceleration - support.acceleration
        try work.reservePreparedMetadataRecords(3)
        let gap = G.dot(normal, separation)
        try work.reservePreparedMetadataRecords(3 + 3 + 1)
        let speed = G.dot(normal, relativeVelocity) + G.dot(normalDot, separation)
        try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3)
        let acceleration = G.dot(normal, relativeAcceleration)
          + Solver.Interval.point(2) * G.dot(normalDot, relativeVelocity)
          + G.dot(normalDDot, separation)
        try work.reservePreparedMetadataRecords(4)
        guard gap.valid, speed.valid, acceleration.valid, alignment.valid else { throw Failure.unprovenOperator }
        try work.reservePreparedMetadataRecords(2)
        let contact = Row(patchIndex: patchIndex, materialVertexID: key,
          positiveComponent: patch.headComponent, negativeComponent: patch.supportComponent,
          commonPoint: head.position, normal: normal)
        rows.append(.init(contact: contact, supportAnchor: support.position, gap: gap,
          gapVelocity: speed, baselineGapAcceleration: acceleration, normalAlignment: alignment))
        baseline.append(acceleration)
      }
    }
    var matrix: [Solver.Interval] = []
    for row in rows {
      for column in rows {
        try work.triangle()
        var coefficient = Solver.Interval.point(0)
        for (index, rowSign) in [(row.contact.positiveComponent, 1.0), (row.contact.negativeComponent, -1.0)] {
          try work.reservePreparedMetadataRecords(2)
          let columnSign: Double
          if index == column.contact.positiveComponent { columnSign = 1 }
          else if index == column.contact.negativeComponent { columnSign = -1 }
          else { continue }
          // Rotating-normal support torque changes gDDot as if its observation
          // lever ends at the ROW HEAD point, not the support material anchor.
          // This is the exact J M^-1 J^T support term, including separation.
          let response = try Solver.constrainedPointForceResponse(fields[index],
            application: column.contact.commonPoint, direction: column.contact.normal,
            observation: row.contact.commonPoint, work: &work)
          try work.reservePreparedMetadataRecords(3 + 2)
          coefficient = coefficient + G.dot(row.contact.normal, response) * .point(rowSign * columnSign)
        }
        try work.reservePreparedMetadataRecords(1)
        guard coefficient.valid else { throw Failure.unprovenOperator }
        matrix.append(coefficient)
      }
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(source: source, current: current, external: externalRanges,
      fields: fields, rows: rows, matrix: matrix, baseline: baseline)
  }

  /// Full coupled 13*m field range for a supplied correlated basis-force
  /// enclosure. Same J and exact opposite force are used at both endpoints.
  /// No force midpoint, time integration or implicit constraint proof occurs.
  static func assembleMovingField(_ value: MovingOperator, normalForces: [Solver.Interval],
    work: inout G.Work) throws -> [Solver.ConstrainedBodyField]
  {
    try work.query()
    try work.reservePreparedMetadataRecords(1)
    guard normalForces.count == value.rows.count else { throw Failure.unprovenOperator }
    try work.reservePreparedMetadataRecords(value.externalRanges.count * 2)
    var force = value.externalRanges.map(\.worldForce)
    var torque = value.externalRanges.map(\.worldTorqueAtCOM)
    for index in value.rows.indices {
      try work.node()
      try work.reservePreparedMetadataRecords(1)
      guard normalForces[index].valid, normalForces[index].lower >= 0 else { throw Failure.unprovenOperator }
      let row = value.rows[index].contact
      try work.reservePreparedMetadataRecords(3)
      let positive = row.normal * normalForces[index]
      for (component, sign) in [(row.positiveComponent, 1.0), (row.negativeComponent, -1.0)] {
        try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3 + 3)
        let applied = positive * .point(sign)
        force[component] = force[component] + applied
        torque[component] = torque[component]
          + (row.commonPoint - value.current[component].state.centreOfMass).cross(applied)
      }
    }
    var result: [Solver.ConstrainedBodyField] = []
    for index in value.current.indices {
      try work.node()
      let field = try movingField(Solver.prepareConstrainedBodyField(value.current[index].state,
        worldForce: force[index], worldTorqueAtCOM: torque[index], work: &work))
      try work.reservePreparedMetadataRecords(1)
      result.append(field)
    }
    return result
  }

  private static func movingMatches(_ component: Component, original: Component,
    atlas: Atlas, work: inout G.Work) throws
  {
    let a = component.view.representation, b = component.state.representation
    try work.reservePreparedMetadataRecords(10)
    guard component.view.atlas === atlas,
      component.view.vertexIDs.count == original.view.vertexIDs.count,
      component.view.facetIDs.count == original.view.facetIDs.count,
      a.mass.parts.count == b.mass.parts.count,
      a.mass.parts.count == original.view.representation.mass.parts.count,
      a.sourceVertices.count == b.sourceVertices.count,
      a.meshAtCentreOfMass.vertices.count == b.meshAtCentreOfMass.vertices.count,
      a.meshAtCentreOfMass.faces.count == b.meshAtCentreOfMass.faces.count
    else { throw Failure.invalidBoundary }
    for index in component.view.vertexIDs.indices {
      try work.reservePreparedMetadataRecords(1)
      guard component.view.vertexIDs[index] == original.view.vertexIDs[index] else { throw Failure.invalidBoundary }
    }
    for index in component.view.facetIDs.indices {
      try work.reservePreparedMetadataRecords(1)
      guard component.view.facetIDs[index] == original.view.facetIDs[index] else { throw Failure.invalidBoundary }
    }
    try work.reservePreparedMetadataRecords(3)
    guard a.mass.massKilograms == b.mass.massKilograms,
      a.mass.centreOfMassSource == b.mass.centreOfMassSource,
      a.mass.inertiaAtCentreOfMass == b.mass.inertiaAtCentreOfMass else { throw Failure.invalidBoundary }
    for index in a.mass.parts.indices {
      try work.reservePreparedMetadataRecords(5)
      let x = a.mass.parts[index], y = b.mass.parts[index]
      guard x.kind == y.kind, x.massKilograms == y.massKilograms,
        x.centreOfMassLocal == y.centreOfMassLocal, x.inertiaAtCentreOfMass == y.inertiaAtCentreOfMass,
        x.kind == original.view.representation.mass.parts[index].kind else { throw Failure.invalidBoundary }
    }
    for index in a.sourceVertices.indices {
      try work.reservePreparedMetadataRecords(1)
      guard a.sourceVertices[index] == b.sourceVertices[index] else { throw Failure.invalidBoundary }
    }
    for index in a.meshAtCentreOfMass.vertices.indices {
      try work.reservePreparedMetadataRecords(1)
      guard a.meshAtCentreOfMass.vertices[index] == b.meshAtCentreOfMass.vertices[index] else { throw Failure.invalidBoundary }
    }
    for index in a.meshAtCentreOfMass.faces.indices {
      let x = a.meshAtCentreOfMass.faces[index], y = b.meshAtCentreOfMass.faces[index]
      try work.reservePreparedMetadataRecords(1)
      guard x.count == y.count else { throw Failure.invalidBoundary }
      for corner in x.indices {
        try work.reservePreparedMetadataRecords(1)
        guard x[corner] == y[corner] else { throw Failure.invalidBoundary }
      }
    }
  }

  private static func movingLocalPoint(_ component: Component, key: Int,
    work: inout G.Work) throws -> Solver.VectorBox
  {
    let atlas = component.view.atlas
    try work.reservePreparedMetadataRecords(1)
    guard atlas.vertices.indices.contains(key) else { throw Failure.incompletePatch }
    try work.reservePreparedMetadataRecords(component.view.vertexIDs.count)
    guard component.view.vertexIDs.contains(key) else { throw Failure.incompletePatch }
    try work.reservePreparedMetadataRecords(3)
    let point = Solver.VectorBox.point(atlas.vertices[key])
    try work.reservePreparedMetadataRecords(3)
    let currentCOM = component.state.representation.mass.centreOfMassSource
    if currentCOM == atlas.ancestorCOMSource { return point }
    try work.reservePreparedMetadataRecords(3 + 3)
    return point + Solver.sourceCOMDifference(from: currentCOM, to: atlas.ancestorCOMSource)
  }

  private static func movingField(_ outcome: NativeC01InquiryPreparationWork.Outcome<Solver.ConstrainedBodyField>)
    throws -> Solver.ConstrainedBodyField
  {
    // Same caller Work already retains the actual successful OR failed debit.
    // Consuming range DATA does not pay any prior provider/atlas construction.
    switch outcome {
    case .prepared(let value, _): return value
    case .refused(.allowance, _): throw G.Failure.workBudgetExceeded
    case .refused: throw Failure.unprovenOperator
    }
  }
}

extension NativeC01InquiryCutContactSet {
  struct MovingPatchDifferential: Sendable {
    let normal: Solver.VectorBox
    let normalDot: Solver.VectorBox
    let normalDDot: Solver.VectorBox
    let normalJacobian: [Solver.Interval]
    let normalInput: Solver.ConstrainedCoupledVector
    let normalDotJacobian: [Solver.Interval]
    let normalDDotJacobian: [Solver.Interval]

    fileprivate init(normal: Solver.VectorBox, normalDot: Solver.VectorBox, normalDDot: Solver.VectorBox,
      n: [Solver.Interval], normalInput: Solver.ConstrainedCoupledVector,
      nd: [Solver.Interval], ndd: [Solver.Interval])
    {
      self.normal = normal; self.normalDot = normalDot; self.normalDDot = normalDDot
      normalJacobian = n; self.normalInput = normalInput
      normalDotJacobian = nd; normalDDotJacobian = ndd
    }
  }
  struct MovingRowDifferential: Sendable {
    let row: MovingRow
    let head: Solver.ConstrainedMaterialDifferential
    let support: Solver.ConstrainedMaterialDifferential
    let headPositionJacobian: [Solver.Interval]
    let headInput: Solver.ConstrainedCoupledVector
    let supportPositionJacobian: [Solver.Interval]
    let gapJacobian: [Solver.Interval]
    let gapVelocityJacobian: [Solver.Interval]
    let baselineJacobian: [Solver.Interval]

    fileprivate init(row: MovingRow, head: Solver.ConstrainedMaterialDifferential,
      support: Solver.ConstrainedMaterialDifferential, hp: [Solver.Interval], headInput: Solver.ConstrainedCoupledVector,
      sp: [Solver.Interval],
      gap: [Solver.Interval], speed: [Solver.Interval], baseline: [Solver.Interval])
    {
      self.row = row; self.head = head; self.support = support
      headPositionJacobian = hp; self.headInput = headInput; supportPositionJacobian = sp
      gapJacobian = gap; gapVelocityJacobian = speed; baselineJacobian = baseline
    }
  }
  struct MovingDifferential: Sendable {
    let contactOperator: MovingOperator
    let physicalTimeRange: Solver.Interval
    let variables: Int
    let externalJacobian: [Solver.Interval]
    let bodies: [Solver.ConstrainedBodyDifferential]
    let responses: [Solver.ConstrainedResponseDifferentialFrame]
    let patches: [MovingPatchDifferential]
    let rows: [MovingRowDifferential]
    let coefficientJacobian: [Solver.Interval]
    let baselineJacobian: [Solver.Interval]

    fileprivate init(value: MovingOperator, time: Solver.Interval, variables: Int,
      external: [Solver.Interval], bodies: [Solver.ConstrainedBodyDifferential],
      responses: [Solver.ConstrainedResponseDifferentialFrame], patches: [MovingPatchDifferential],
      rows: [MovingRowDifferential], coefficients: [Solver.Interval], baseline: [Solver.Interval])
    {
      contactOperator = value; physicalTimeRange = time; self.variables = variables
      externalJacobian = external; self.bodies = bodies; self.responses = responses
      self.patches = patches; self.rows = rows; coefficientJacobian = coefficients; baselineJacobian = baseline
    }
  }

  /// Mathematical chain over SAME state/force ranges. externalJacobian rows
  /// are all world F/tauCOM coordinates, columns 13*m state plus explicit time.
  /// G1 must authenticate the actual law/source/units/range/time derivative.
  /// Arrays/time metadata confer no native force, contact or time permission.
  static func prepareMovingDifferential(_ value: MovingOperator, physicalTimeRange: Solver.Interval,
    externalJacobian: [Solver.Interval], work: inout G.Work) throws -> MovingDifferential
  {
    try work.query()
    let m = value.current.count
    try work.reservePreparedMetadataRecords(2)
    guard m > 0, m <= 4, physicalTimeRange.valid else { throw Failure.unprovenOperator }
    let variables = 13 * m + 1
    try work.reservePreparedMetadataRecords(1)
    guard externalJacobian.count == 6 * m * variables else { throw Failure.unprovenOperator }
    try work.reservePreparedMetadataRecords(externalJacobian.count)
    guard externalJacobian.allSatisfy(\.valid) else { throw Failure.unprovenOperator }
    var bodies: [Solver.ConstrainedBodyDifferential] = []
    var responses: [Solver.ConstrainedResponseDifferentialFrame] = []
    for field in value.baselineFields {
      try work.node()
      let body = try chainPrepared(Solver.prepareConstrainedBodyDifferential(field, work: &work))
      let response = try chainPrepared(Solver.prepareConstrainedResponseDifferentialFrame(body, work: &work))
      try work.reservePreparedMetadataRecords(2)
      bodies.append(body); responses.append(response)
    }
    var patches: [MovingPatchDifferential] = []
    for patch in value.sourceBoundary.patches {
      try work.node()
      let differential = try movingPatchDifferential(patch, bodies: bodies, variables: variables,
        external: externalJacobian, work: &work)
      try work.reservePreparedMetadataRecords(1)
      patches.append(differential)
    }
    var rows: [MovingRowDifferential] = []
    var baseline: [Solver.Interval] = []
    for row in value.rows {
      try work.node()
      let differential = try movingRowDifferential(row, value: value,
        body: bodies, patch: patches[row.contact.patchIndex], variables: variables,
        external: externalJacobian, work: &work)
      try work.reservePreparedMetadataRecords(1)
      rows.append(differential)
      for item in differential.baselineJacobian {
        try work.reservePreparedMetadataRecords(1)
        baseline.append(item)
      }
    }
    let coefficients = try movingMatrixDifferential(value, responses: responses,
      rows: rows, patches: patches, variables: variables, work: &work)
    try work.reservePreparedMetadataRecords(1)
    return .init(value: value, time: physicalTimeRange, variables: variables, external: externalJacobian,
      bodies: bodies, responses: responses, patches: patches, rows: rows,
      coefficients: coefficients, baseline: baseline)
  }

  private static func chainPrepared<Value: Sendable>(_ outcome: NativeC01InquiryPreparationWork.Outcome<Value>) throws -> Value {
    switch outcome {
    case .prepared(let value, _): return value
    case .refused(.allowance, _): throw G.Failure.workBudgetExceeded
    case .refused: throw Failure.unprovenOperator
    }
  }

  /// Source-specific local19-to-coupled-state/time chain. Exact zero local
  /// force partials never spend a full dense product traversal for every column.
  private static func chainVector(_ local: [Solver.Interval], component: Int, variables: Int,
    external: [Solver.Interval], work: inout G.Work) throws -> [Solver.Interval]
  {
    try chainLocalMatrix(local, rows: 3, component: component, variables: variables, external: external, work: &work)
  }

  private static func chainVectorColumn(_ matrix: [Solver.Interval], variable: Int, variables: Int) -> Solver.VectorBox {
    .init(x: matrix[variable], y: matrix[variables + variable], z: matrix[2 * variables + variable])
  }
  private static func chainZero(_ value: Solver.Interval) -> Bool { value.lower == 0 && value.upper == 0 }
}

extension NativeC01InquiryCutContactSet {
  private static func movingPatchDifferential(_ patch: Patch,
    bodies: [Solver.ConstrainedBodyDifferential], variables: Int, external: [Solver.Interval], work: inout G.Work
  ) throws -> MovingPatchDifferential {
    let body = bodies[patch.supportComponent]
    let rotated = try Solver.constrainedRotatedVectorDifferential(body,
      local: .point(patch.normalFromSupportIntoHead), work: &work)
    let n = rotated.value, omega = body.field.worldAngularVelocity, alpha = body.field.worldAngularAcceleration
    let nj = try chainVector(rotated.jacobian, component: patch.supportComponent,
      variables: variables, external: external, work: &work)
    let wj = try chainVector(body.angularVelocityJacobian, component: patch.supportComponent,
      variables: variables, external: external, work: &work)
    let aj = try chainVector(body.angularAccelerationJacobian, component: patch.supportComponent,
      variables: variables, external: external, work: &work)
    try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3 + 3)
    let nd = omega.cross(n)
    let ndd = alpha.cross(n) + omega.cross(omega.cross(n))
    try work.reservePreparedMetadataRecords(6 * variables)
    var ndj = Array(repeating: Solver.Interval.point(0), count: 3 * variables)
    var nddj = Array(repeating: Solver.Interval.point(0), count: 3 * variables)
    for variable in 0..<variables {
      try work.reservePreparedMetadataRecords(9)
      let dn = chainVectorColumn(nj, variable: variable, variables: variables)
      let dw = chainVectorColumn(wj, variable: variable, variables: variables)
      let da = chainVectorColumn(aj, variable: variable, variables: variables)
      try work.reservePreparedMetadataRecords(9)
      let stationaryNormal = chainVectorZero(dn) && chainVectorZero(dw)
      let stationaryAcceleration = stationaryNormal && chainVectorZero(da)
      try work.reservePreparedMetadataRecords(3)
      var dnd = Solver.VectorBox.point(.init(0, 0, 0))
      var dndd = dnd
      if !stationaryNormal {
        try work.reservePreparedMetadataRecords(3 + 3 + 3)
        dnd = dw.cross(n) + omega.cross(dn)
      }
      if !stationaryAcceleration {
        try work.reservePreparedMetadataRecords(3 * 10)
        dndd = da.cross(n) + alpha.cross(dn) + dw.cross(nd)
          + omega.cross(dw.cross(n) + omega.cross(dn))
      }
      try work.reservePreparedMetadataRecords(6)
      guard dnd.valid, dndd.valid else { throw Failure.unprovenOperator }
      try work.reservePreparedMetadataRecords(6)
      let ds = dnd.values, dds = dndd.values
      try work.reservePreparedMetadataRecords(6)
      for coordinate in 0..<3 {
        ndj[coordinate * variables + variable] = ds[coordinate]
        nddj[coordinate * variables + variable] = dds[coordinate]
      }
    }
    let normalInput = try chainPrepared(Solver.prepareConstrainedCoupledVector(n,
      variables: variables, jacobian: nj, work: &work))
    try work.reservePreparedMetadataRecords(1)
    return .init(normal: n, normalDot: nd, normalDDot: ndd, n: nj, normalInput: normalInput, nd: ndj, ndd: nddj)
  }

  private static func movingRowDifferential(_ row: MovingRow, value: MovingOperator,
    body: [Solver.ConstrainedBodyDifferential], patch: MovingPatchDifferential,
    variables: Int, external: [Solver.Interval], work: inout G.Work) throws -> MovingRowDifferential
  {
    let headIndex = row.contact.positiveComponent, supportIndex = row.contact.negativeComponent
    let key = row.contact.materialVertexID
    let headLocal = try movingLocalPoint(value.current[headIndex], key: key, work: &work)
    let supportLocal = try movingLocalPoint(value.current[supportIndex], key: key, work: &work)
    let head = try Solver.constrainedMaterialDifferential(body[headIndex], local: headLocal, work: &work)
    let support = try Solver.constrainedMaterialDifferential(body[supportIndex], local: supportLocal, work: &work)
    try work.reservePreparedMetadataRecords(9)
    guard sameBox(head.value.position, row.contact.commonPoint), sameBox(support.value.position, row.supportAnchor),
      sameBox(patch.normal, row.contact.normal) else { throw Failure.unprovenOperator }
    let hp = try chainVector(head.positionJacobian, component: headIndex, variables: variables, external: external, work: &work)
    let sp = try chainVector(support.positionJacobian, component: supportIndex, variables: variables, external: external, work: &work)
    let hv = try chainVector(head.velocityJacobian, component: headIndex, variables: variables, external: external, work: &work)
    let sv = try chainVector(support.velocityJacobian, component: supportIndex, variables: variables, external: external, work: &work)
    let ha = try chainVector(head.accelerationJacobian, component: headIndex, variables: variables, external: external, work: &work)
    let sa = try chainVector(support.accelerationJacobian, component: supportIndex, variables: variables, external: external, work: &work)
    try work.reservePreparedMetadataRecords(9)
    let separation = head.value.position - support.value.position
    let velocity = head.value.velocity - support.value.velocity
    let acceleration = head.value.acceleration - support.value.acceleration
    try work.reservePreparedMetadataRecords(3 * variables)
    var gap = Array(repeating: Solver.Interval.point(0), count: variables)
    var speed = Array(repeating: Solver.Interval.point(0), count: variables)
    var baseline = Array(repeating: Solver.Interval.point(0), count: variables)
    for variable in 0..<variables {
      try work.reservePreparedMetadataRecords(27)
      let dhp = chainVectorColumn(hp, variable: variable, variables: variables)
      let dsp = chainVectorColumn(sp, variable: variable, variables: variables)
      let dhv = chainVectorColumn(hv, variable: variable, variables: variables)
      let dsv = chainVectorColumn(sv, variable: variable, variables: variables)
      let dha = chainVectorColumn(ha, variable: variable, variables: variables)
      let dsa = chainVectorColumn(sa, variable: variable, variables: variables)
      let dn = chainVectorColumn(patch.normalJacobian, variable: variable, variables: variables)
      let dnd = chainVectorColumn(patch.normalDotJacobian, variable: variable, variables: variables)
      let dndd = chainVectorColumn(patch.normalDDotJacobian, variable: variable, variables: variables)
      try work.reservePreparedMetadataRecords(9)
      let dd = dhp - dsp, ddv = dhv - dsv, dda = dha - dsa
      try work.reservePreparedMetadataRecords(9)
      let fixedGap = chainVectorZero(dn) && chainVectorZero(dhp) && chainVectorZero(dsp)
      try work.reservePreparedMetadataRecords(9)
      let fixedSpeed = fixedGap && chainVectorZero(dhv) && chainVectorZero(dsv) && chainVectorZero(dnd)
      try work.reservePreparedMetadataRecords(9)
      let fixedBaseline = fixedSpeed && chainVectorZero(dha) && chainVectorZero(dsa) && chainVectorZero(dndd)
      if !fixedGap {
        try work.reservePreparedMetadataRecords(7)
        gap[variable] = G.dot(dn, separation) + G.dot(patch.normal, dd)
      }
      if !fixedSpeed {
        try work.reservePreparedMetadataRecords(15)
        speed[variable] = G.dot(dn, velocity) + G.dot(patch.normal, ddv)
          + G.dot(dnd, separation) + G.dot(patch.normalDot, dd)
      }
      if !fixedBaseline {
        try work.reservePreparedMetadataRecords(24)
        baseline[variable] = G.dot(dn, acceleration) + G.dot(patch.normal, dda)
          + Solver.Interval.point(2) * (G.dot(dnd, velocity) + G.dot(patch.normalDot, ddv))
          + G.dot(dndd, separation) + G.dot(patch.normalDDot, dd)
      }
      try work.reservePreparedMetadataRecords(3)
      guard gap[variable].valid, speed[variable].valid, baseline[variable].valid else { throw Failure.unprovenOperator }
    }
    let headInput = try chainPrepared(Solver.prepareConstrainedCoupledVector(head.value.position,
      variables: variables, jacobian: hp, work: &work))
    try work.reservePreparedMetadataRecords(1)
    return .init(row: row, head: head, support: support, hp: hp, headInput: headInput, sp: sp,
      gap: gap, speed: speed, baseline: baseline)
  }

  private static func chainVectorZero(_ value: Solver.VectorBox) -> Bool {
    chainZero(value.x) && chainZero(value.y) && chainZero(value.z)
  }
}

extension NativeC01InquiryCutContactSet {
  private static func movingMatrixDifferential(_ value: MovingOperator,
    responses: [Solver.ConstrainedResponseDifferentialFrame], rows: [MovingRowDifferential],
    patches: [MovingPatchDifferential], variables: Int, work: inout G.Work) throws -> [Solver.Interval]
  {
    let n = rows.count
    try work.reservePreparedMetadataRecords(n * n * variables)
    var result = Array(repeating: Solver.Interval.point(0), count: n * n * variables)
    for rowIndex in rows.indices {
      let row = value.rows[rowIndex].contact
      for columnIndex in rows.indices {
        try work.triangle()
        let column = value.rows[columnIndex].contact
        for (component, rowSign) in [(row.positiveComponent, 1.0), (row.negativeComponent, -1.0)] {
          try work.reservePreparedMetadataRecords(2)
          let columnSign: Double
          if component == column.positiveComponent { columnSign = 1 }
          else if component == column.negativeComponent { columnSign = -1 }
          else { continue }
          let response = try chainPrepared(Solver.prepareCachedConstrainedPointForceDifferential(responses[component],
            component: component, application: rows[columnIndex].headInput,
            direction: patches[column.patchIndex].normalInput,
            observation: rows[rowIndex].headInput, work: &work))
          let sign = Solver.Interval.point(rowSign * columnSign)
          for variable in 0..<variables {
            try work.reservePreparedMetadataRecords(6)
            let dn = chainVectorColumn(patches[row.patchIndex].normalJacobian, variable: variable, variables: variables)
            let dr = chainVectorColumn(response.jacobian, variable: variable, variables: variables)
            try work.reservePreparedMetadataRecords(6)
            if chainVectorZero(dn) && chainVectorZero(dr) { continue }
            try work.reservePreparedMetadataRecords(9)
            let derivative = (G.dot(dn, response.value) + G.dot(row.normal, dr)) * sign
            let offset = (rowIndex * n + columnIndex) * variables + variable
            let accumulated = result[offset] + derivative
            try work.reservePreparedMetadataRecords(1)
            guard accumulated.valid else { throw Failure.unprovenOperator }
            try work.reservePreparedMetadataRecords(1)
            result[offset] = accumulated
          }
        }
      }
    }
    return result
  }
}

extension NativeC01InquiryCutContactSet {
  /// Only the fixed source vector3/body13 by local19 layouts are admitted.
  private static func chainLocalMatrix(_ local: [Solver.Interval], rows: Int, component: Int, variables: Int,
    external: [Solver.Interval], work: inout G.Work) throws -> [Solver.Interval]
  {
    try work.reservePreparedMetadataRecords(2)
    guard rows == 3 || rows == 13, local.count == rows * 19 else { throw Failure.unprovenOperator }
    try work.reservePreparedMetadataRecords(rows * variables)
    var result = Array(repeating: Solver.Interval.point(0), count: rows * variables)
    for row in 0..<rows {
      try work.node()
      var active: [Int] = []
      for coordinate in 0..<6 {
        try work.reservePreparedMetadataRecords(1)
        if !chainZero(local[row * 19 + 13 + coordinate]) {
          try work.reservePreparedMetadataRecords(1)
          active.append(coordinate)
        }
      }
      for variable in 0..<variables {
        try work.reservePreparedMetadataRecords(1)
        let index = variable - 13 * component
        var coefficient = (0..<13).contains(index) ? local[row * 19 + index] : .point(0)
        for coordinate in active {
          try work.reservePreparedMetadataRecords(1)
          let forceDerivative = external[(6 * component + coordinate) * variables + variable]
          if chainZero(forceDerivative) { continue }
          try work.reservePreparedMetadataRecords(2)
          coefficient = coefficient + local[row * 19 + 13 + coordinate] * forceDerivative
        }
        try work.reservePreparedMetadataRecords(1)
        guard coefficient.valid else { throw Failure.unprovenOperator }
        try work.reservePreparedMetadataRecords(1)
        result[row * variables + variable] = coefficient
      }
    }
    return result
  }
}

extension NativeC01InquiryCutContactSet {
  struct MovingFieldDifferential: Sendable {
    let moving: MovingDifferential
    let basis: NativeC01InquiryContactComplementarity.MovingBasisRange
    let basisDifferential: NativeC01InquiryContactComplementarity.MovingBasisDifferential
    let totalFields: [Solver.ConstrainedBodyField]
    /// Row-major total F/tauCOM: 6*m by moving.variables.
    let totalWrenchJacobian: [Solver.Interval]
    /// Row-major actual field qDot/CDot/PDot/LDot: 13*m by moving.variables.
    let fieldJacobian: [Solver.Interval]

    fileprivate init(moving: MovingDifferential, basis: NativeC01InquiryContactComplementarity.MovingBasisRange,
      derivative: NativeC01InquiryContactComplementarity.MovingBasisDifferential,
      fields: [Solver.ConstrainedBodyField], wrench: [Solver.Interval], field: [Solver.Interval])
    {
      self.moving = moving; self.basis = basis; basisDifferential = derivative
      totalFields = fields; totalWrenchJacobian = wrench; fieldJacobian = field
    }
  }
  enum MovingFieldOutcome: Sendable {
    case bounds(MovingFieldDifferential)
    case unresolved
    case workExhausted
  }

  /// Conditional full coupled field/Jacobian range on one algebraic basis.
  /// The exact same operator builds both lambda and dLambda internally. No
  /// unrelated solution/UUID/callback can substitute for that join. This does
  /// NOT prove initial g/gDot identities, branch persistence or finite time.
  static func prepareMovingFieldDifferential(_ value: MovingDifferential, activeBasis: [Int],
    work: inout G.Work) -> MovingFieldOutcome {
    typealias Q = NativeC01InquiryContactComplementarity
    do {
      let basis: Q.MovingBasisRange
      switch Q.encloseMovingBasis(value.contactOperator, activeBasis: activeBasis, work: &work) {
      case .bounds(let range): basis = range
      case .unresolved: return .unresolved
      case .workExhausted: return .workExhausted
      }
      let derivative: Q.MovingBasisDifferential
      switch Q.prepareMovingBasisDifferential(basis, variables: value.variables,
        coefficientDerivatives: value.coefficientJacobian, baselineDerivatives: value.baselineJacobian, work: &work)
      {
      case .bounds(let range): derivative = range
      case .unresolved: return .unresolved
      case .workExhausted: return .workExhausted
      }
      let fields = try assembleMovingField(value.contactOperator, normalForces: basis.force, work: &work)
      let wrench = try totalWrenchDifferential(value, basis: derivative, work: &work)
      let variables = value.variables
      var field: [Solver.Interval] = []
      for component in value.contactOperator.current.indices {
        try work.node()
        // These LOCAL thirteen-field partials depend only on the same q/L
        // and source mass, not the independent input values F/tau. In
        // particular, do not reuse baseline alpha as the total field alpha.
        let partials = value.bodies[component].fieldJacobian
        let block = try chainLocalMatrix(partials, rows: 13, component: component,
          variables: variables, external: wrench, work: &work)
        for coefficient in block {
          try work.reservePreparedMetadataRecords(1)
          field.append(coefficient)
        }
      }
      try work.reservePreparedMetadataRecords(1)
      return .bounds(.init(moving: value, basis: basis, derivative: derivative,
        fields: fields, wrench: wrench, field: field))
    } catch G.Failure.workBudgetExceeded { return .workExhausted }
    catch { return .unresolved }
  }

  private static func totalWrenchDifferential(_ value: MovingDifferential,
    basis: NativeC01InquiryContactComplementarity.MovingBasisDifferential,
    work: inout G.Work) throws -> [Solver.Interval]
  {
    let variables = value.variables
    // Explicit source copy BEFORE mutation: do not hide the retained input
    // array's first copy-on-write traversal behind one coefficient update.
    try work.reservePreparedMetadataRecords(value.externalJacobian.count)
    var result = value.externalJacobian.map { $0 }
    for rowIndex in basis.range.activeBasis {
      try work.node()
      let row = value.rows[rowIndex].row.contact
      let lambda = basis.range.force[rowIndex]
      try work.reservePreparedMetadataRecords(3)
      let positive = row.normal * lambda
      for variable in 0..<variables {
        try work.reservePreparedMetadataRecords(3 + 3 + 1)
        let dn = chainVectorColumn(value.patches[row.patchIndex].normalJacobian,
          variable: variable, variables: variables)
        let dp = chainVectorColumn(value.rows[rowIndex].headPositionJacobian,
          variable: variable, variables: variables)
        let dl = basis.forceJacobian[rowIndex * variables + variable]
        try work.reservePreparedMetadataRecords(3 + 3 + 3)
        let positiveDerivative = dn * lambda + row.normal * dl
        try work.reservePreparedMetadataRecords(2)
        for (component, sign) in [(row.positiveComponent, 1.0), (row.negativeComponent, -1.0)] {
          try work.reservePreparedMetadataRecords(3 + 3 + 3)
          let force = positive * .point(sign)
          let forceDerivative = positiveDerivative * .point(sign)
          let lever = row.commonPoint - value.contactOperator.current[component].state.centreOfMass
          try work.reservePreparedMetadataRecords(3)
          var dc = Solver.VectorBox.point(.init(0, 0, 0))
          let local = variable - 13 * component
          if (4..<7).contains(local) {
            try work.reservePreparedMetadataRecords(3)
            dc = chainAxis(local - 4)
          }
          try work.reservePreparedMetadataRecords(3 + 3 + 3 + 3)
          let torqueDerivative = (dp - dc).cross(force) + lever.cross(forceDerivative)
          try work.reservePreparedMetadataRecords(6)
          guard forceDerivative.valid, torqueDerivative.valid else { throw Failure.unprovenOperator }
          try work.reservePreparedMetadataRecords(6)
          let fs = forceDerivative.values, ts = torqueDerivative.values
          for coordinate in 0..<3 {
            let forceOffset = (6 * component + coordinate) * variables + variable
            let torqueOffset = (6 * component + 3 + coordinate) * variables + variable
            try work.reservePreparedMetadataRecords(2)
            let df = result[forceOffset] + fs[coordinate]
            let dt = result[torqueOffset] + ts[coordinate]
            try work.reservePreparedMetadataRecords(2)
            guard df.valid, dt.valid else { throw Failure.unprovenOperator }
            try work.reservePreparedMetadataRecords(2)
            result[forceOffset] = df; result[torqueOffset] = dt
          }
        }
      }
    }
    return result
  }

  private static func chainAxis(_ index: Int) -> Solver.VectorBox {
    .init(x: .point(index == 0 ? 1 : 0), y: .point(index == 1 ? 1 : 0), z: .point(index == 2 ? 1 : 0))
  }
}

extension NativeC01InquiryCutContactSet {
  /// Derivation only, never a native accepted cut or source/clock permission.
  enum BoundaryOrigin: Sendable {
    case rigidParentTransfer
    case validatedEndpointGraph(ValidatedCutOrigin)
  }
  struct CutRowKey: Sendable, Equatable { let head: Role; let materialVertexID: Int }
  struct RoleReindex: Sendable { let role: Role; let oldComponent: Int; let newComponent: Int }
  enum CutRowOrigin: Sendable {
    case retainedValidatedRow(Int)
    case newParentCut(parentComponent: Int, materialVertexID: Int)
  }
  final class ValidatedCutOrigin: Sendable {
    let previousCell: Solver.ConstrainedCellCandidate
    let newCuts: [Role]
    let oldComponentToNew: [[Int]]
    let roleMap: [RoleReindex]
    let oldRowToNew: [Int]
    let oldBasisToNew: [Int]
    let activeBasis: [Int]
    let rowOrigins: [CutRowOrigin]
    fileprivate init(cell: Solver.ConstrainedCellCandidate, cuts: [Role], components: [[Int]],
      roles: [RoleReindex], rows: [Int], oldBasis: [Int], basis: [Int], origins: [CutRowOrigin]) {
      previousCell = cell; newCuts = cuts; oldComponentToNew = components; roleMap = roles
      oldRowToNew = rows; oldBasisToNew = oldBasis; activeBasis = basis; rowOrigins = origins
    }
  }
  final class ValidatedCutGraph: Sendable {
    let boundary: Boundary
    let origin: ValidatedCutOrigin
    fileprivate init(boundary: Boundary, origin: ValidatedCutOrigin) { self.boundary = boundary; self.origin = origin }
  }

  /// Kinematic repartition from an actual privately validated mathematical
  /// endpoint. This is NOT an impulse/conservation/native event receipt.
  /// Adopted mass/COM/tensors remain unchanged; physical additive/conservative
  /// transfer and real native cut qualification are separate OPEN obligations.
  /// Old patches/basis/history survive; no inactive old row is reset to zero.
  static func prepareValidatedCutGraph(_ cell: Solver.ConstrainedCellCandidate,
    cutHeadEdges cuts: [Role], newlyActiveRows: [CutRowKey], work: inout G.Work) throws -> ValidatedCutGraph {
    try work.node()
    let oldStart = cell.domain.start, old = oldStart.sourceBoundary, endpoint = cell.endpoint
    try work.reservePreparedMetadataRecords(8)
    guard !cuts.isEmpty, cuts.count <= 3,
      endpoint.count == old.components.count, !endpoint.isEmpty, endpoint.count <= 4,
      oldStart.initialSeed.view.atlas === old.parentView.atlas,
      newlyActiveRows.count <= 4 * cuts.count else { throw Failure.invalidBoundary }
    try work.reservePreparedMetadataRecords(2 * cuts.count)
    guard Set(cuts).count == cuts.count, !cuts.contains(.support) else { throw Failure.invalidBoundary }
    try work.reservePreparedMetadataRecords(old.patches.count)
    let oldCuts = old.patches.map(\.head)
    try work.reservePreparedMetadataRecords(oldCuts.count + cuts.count * oldCuts.count + cuts.count + 1)
    guard Set(oldCuts).count == oldCuts.count, oldCuts.count + cuts.count <= 3,
      cuts.allSatisfy({ !oldCuts.contains($0) }) else { throw Failure.invalidBoundary }

    try work.reservePreparedMetadataRecords(old.parentView.representation.mass.parts.count)
    let universe = old.parentView.representation.mass.parts.map(\.kind)
    var beforeRoles: [(Role, Int)] = [], parentIndex: Int?
    for index in endpoint.indices {
      try movingMatches(endpoint[index], original: old.components[index], atlas: old.parentView.atlas, work: &work)
      try work.reservePreparedMetadataRecords(13)
      let state = endpoint[index].state
      guard state.quaternion.valid, state.centreOfMass.valid, state.linearMomentum.valid, state.worldAngularMomentum.valid
      else { throw Failure.invalidBoundary }
      for part in state.representation.mass.parts {
        try work.reservePreparedMetadataRecords(universe.count + beforeRoles.count + 1)
        guard universe.contains(part.kind), !beforeRoles.contains(where: { $0.0 == part.kind }) else { throw Failure.invalidBoundary }
        if part.kind == .support {
          guard parentIndex == nil else { throw Failure.invalidBoundary }
          parentIndex = index
        }
        try work.reservePreparedMetadataRecords(1)
        beforeRoles.append((part.kind, index))
      }
    }
    try work.reservePreparedMetadataRecords(2)
    guard beforeRoles.count == universe.count, let parentIndex else { throw Failure.invalidBoundary }
    let parent = endpoint[parentIndex]
    // The local existing builder preserves actual q and inherited material
    // velocity using the same atlas and REAL represented source-COM relation.
    // It builds ONLY genuinely new patches; old graph is merged below.
    let local = try prepare(parent.state, view: parent.view, cutHeadEdges: cuts, work: &work)
    try work.reservePreparedMetadataRecords(2)
    let newCount = endpoint.count + local.components.count - 1
    guard newCount <= 4, local.components.count == cuts.count + 1 else { throw Failure.invalidBoundary }
    try work.reservePreparedMetadataRecords(endpoint.count)
    var components = endpoint
    components[parentIndex] = local.components[0]
    var localToGlobal = [parentIndex]
    for child in 1..<local.components.count {
      try work.reservePreparedMetadataRecords(2)
      localToGlobal.append(components.count)
      components.append(local.components[child])
    }
    var componentMap: [[Int]] = []
    for index in endpoint.indices {
      try work.reservePreparedMetadataRecords(1)
      componentMap.append(index == parentIndex ? localToGlobal : [index])
    }
    var afterRoles: [(Role, Int)] = []
    for index in components.indices {
      for part in components[index].state.representation.mass.parts {
        try work.reservePreparedMetadataRecords(universe.count + afterRoles.count + 1)
        guard universe.contains(part.kind), !afterRoles.contains(where: { $0.0 == part.kind }) else { throw Failure.invalidBoundary }
        try work.reservePreparedMetadataRecords(1)
        afterRoles.append((part.kind, index))
      }
    }
    try work.reservePreparedMetadataRecords(1)
    guard afterRoles.count == beforeRoles.count else { throw Failure.invalidBoundary }
    var roleMap: [RoleReindex] = []
    for (role, oldIndex) in beforeRoles {
      try work.reservePreparedMetadataRecords(afterRoles.count + 1)
      guard let next = afterRoles.first(where: { $0.0 == role })?.1 else { throw Failure.invalidBoundary }
      try work.reservePreparedMetadataRecords(1)
      roleMap.append(.init(role: role, oldComponent: oldIndex, newComponent: next))
    }

    var patches: [Patch] = []
    for head in [Role.head0, .head1, .head2] {
      try work.reservePreparedMetadataRecords(old.patches.count + local.patches.count + 2)
      let previous = old.patches.first(where: { $0.head == head })
      let added = local.patches.first(where: { $0.head == head })
      if let _ = previous, let _ = added { throw Failure.invalidBoundary }
      guard let source = previous ?? added else { continue }
      try work.reservePreparedMetadataRecords(2 * roleMap.count)
      guard let supportIndex = roleMap.first(where: { $0.role == .support })?.newComponent,
        let headIndex = roleMap.first(where: { $0.role == head })?.newComponent else { throw Failure.invalidBoundary }
      let a = components[supportIndex].view, b = components[headIndex].view
      try work.reservePreparedMetadataRecords(a.facetIDs.count + b.facetIDs.count + source.materialVertexIDs.count + 1)
      guard a.facetIDs.contains(source.supportFacet), b.facetIDs.contains(source.headFacet),
        source.materialVertexIDs.count == 4, Set(source.materialVertexIDs).count == 4 else { throw Failure.incompletePatch }
      for key in source.materialVertexIDs {
        try work.reservePreparedMetadataRecords(a.vertexIDs.count + b.vertexIDs.count)
        guard a.vertexIDs.contains(key), b.vertexIDs.contains(key) else { throw Failure.incompletePatch }
      }
      try work.reservePreparedMetadataRecords(1)
      patches.append(.init(head: head, supportComponent: supportIndex, headComponent: headIndex,
        supportFacet: source.supportFacet, headFacet: source.headFacet, materialVertexIDs: source.materialVertexIDs,
        normalFromSupportIntoHead: source.normalFromSupportIntoHead))
    }
    try work.reservePreparedMetadataRecords(1)
    guard patches.count == old.patches.count + local.patches.count else { throw Failure.incompletePatch }
    var rowMap: [Int] = []
    for patch in old.patches {
      try work.reservePreparedMetadataRecords(patches.count)
      guard let index = patches.firstIndex(where: { $0.head == patch.head }) else { throw Failure.incompletePatch }
      for key in patch.materialVertexIDs {
        try work.reservePreparedMetadataRecords(patches[index].materialVertexIDs.count)
        guard let corner = patches[index].materialVertexIDs.firstIndex(of: key) else { throw Failure.incompletePatch }
        try work.reservePreparedMetadataRecords(1)
        rowMap.append(index * 4 + corner)
      }
    }
    var oldBasisMap: [Int] = [], basis: [Int] = []
    for row in oldStart.activeBasis {
      try work.reservePreparedMetadataRecords(1)
      guard rowMap.indices.contains(row) else { throw Failure.invalidBoundary }
      try work.reservePreparedMetadataRecords(2)
      oldBasisMap.append(rowMap[row]); basis.append(rowMap[row])
    }
    for request in newlyActiveRows {
      try work.reservePreparedMetadataRecords(cuts.count + patches.count + 1)
      guard cuts.contains(request.head), let patch = patches.firstIndex(where: { $0.head == request.head })
      else { throw Failure.invalidBoundary }
      try work.reservePreparedMetadataRecords(patches[patch].materialVertexIDs.count)
      guard let corner = patches[patch].materialVertexIDs.firstIndex(of: request.materialVertexID) else { throw Failure.incompletePatch }
      let row = patch * 4 + corner
      try work.reservePreparedMetadataRecords(basis.count)
      guard !basis.contains(row) else { throw Failure.invalidBoundary }
      try work.reservePreparedMetadataRecords(1)
      basis.append(row)
    }
    try basis.sort { a, b in try work.reservePreparedMetadataRecords(1); return a < b }
    var rowOrigins: [CutRowOrigin] = []
    for (patchIndex, patch) in patches.enumerated() {
      for corner in patch.materialVertexIDs.indices {
        let row = patchIndex * 4 + corner
        try work.reservePreparedMetadataRecords(rowMap.count)
        if let previous = rowMap.firstIndex(of: row) {
          try work.reservePreparedMetadataRecords(1)
          rowOrigins.append(.retainedValidatedRow(previous))
        } else {
          try work.reservePreparedMetadataRecords(cuts.count)
          guard cuts.contains(patch.head) else { throw Failure.invalidBoundary }
          try work.reservePreparedMetadataRecords(1)
          rowOrigins.append(.newParentCut(parentComponent: parentIndex, materialVertexID: patch.materialVertexIDs[corner]))
        }
      }
    }
    // At most three NEW source heads can be cut. Retaining the actual prior
    // cell gives a bounded topology provenance DAG, not a per-step cell chain.
    try work.reservePreparedMetadataRecords(1)
    let origin = ValidatedCutOrigin(cell: cell, cuts: cuts, components: componentMap,
      roles: roleMap, rows: rowMap, oldBasis: oldBasisMap, basis: basis, origins: rowOrigins)
    try work.reservePreparedMetadataRecords(1)
    let boundary = Boundary(parent: old.parentState, view: old.parentView, components: components,
      patches: patches, origin: .validatedEndpointGraph(origin))
    try work.reservePreparedMetadataRecords(1)
    return .init(boundary: boundary, origin: origin)
  }
}

extension NativeC01InquiryCutContactSet {
  enum ClosedCutPartitionFailure: Error { case unresolvedPartition }
  struct ClosedCutEdge: Sendable { let start: Int; let end: Int }
  struct ClosedCutFacet: Sendable {
    let id: Atlas.FacetID
    let axis: Int
    let plane: Double
    let u0: Double; let u1: Double; let v0: Double; let v1: Double
    let orientation: Int
    let vertices: [Int]
    let corners: [Int] // material corners in positive-axis cyclic order
  }
  final class ClosedCutConstituent: Sendable {
    let role: Role
    let view: Atlas.View
    let facets: [ClosedCutFacet]
    /// Supports of the PROVEN six-face solid, never an arbitrary hull AABB.
    let minimum: [Double]
    let maximum: [Double]
    let orientedEdges: [ClosedCutEdge]
    fileprivate init(role: Role, view: Atlas.View, facets: [ClosedCutFacet], minimum: [Double], maximum: [Double], edges: [ClosedCutEdge]) {
      self.role = role; self.view = view; self.facets = facets; self.minimum = minimum; self.maximum = maximum; orientedEdges = edges
    }
  }
  struct ClosedCutInterface: Sendable {
    let head: Role
    let support: ClosedCutFacet
    let headBack: ClosedCutFacet
  }
  struct ClosedCutComponentCover: Sendable {
    let component: Int
    let view: Atlas.View
    let roles: [Role]
    let exterior: [ClosedCutFacet]
    let cancelledInterfaces: [Role]
    let orientedEdges: [ClosedCutEdge]
  }
  /// SOURCE TEMPLATE geometry only. Old independently moving components need
  /// actual world/prefix/separation proof; template relations cannot supply it.
  final class ClosedCutPartition: Sendable {
    let transition: Solver.ValidatedCutTransition
    let constituents: [ClosedCutConstituent]
    let interfaces: [ClosedCutInterface]
    let before: [ClosedCutComponentCover]
    let after: [ClosedCutComponentCover]
    let roleMap: [RoleReindex]
    fileprivate init(transition: Solver.ValidatedCutTransition, constituents: [ClosedCutConstituent],
      interfaces: [ClosedCutInterface], before: [ClosedCutComponentCover], after: [ClosedCutComponentCover]) {
      self.transition = transition; self.constituents = constituents; self.interfaces = interfaces
      self.before = before; self.after = after; roleMap = transition.graph.origin.roleMap
    }
  }

  /// Verify actual rounded-atlas closed solids and exact oriented boundary
  /// cancellation. No descriptor-only geometry, source label, box proxy,
  /// interval contains-zero or native/clock/collision permission is issued.
  static func prepareClosedCutPartition(_ transition: Solver.ValidatedCutTransition,
    work: inout G.Work) throws -> ClosedCutPartition {
    try work.node()
    let origin = transition.graph.origin, old = origin.previousCell, atlas = transition.start.initialSeed.view.atlas
    try work.reservePreparedMetadataRecords(4)
    guard old.domain.start.initialSeed === transition.start.initialSeed,
      old.domain.start.anchorTime == transition.start.anchorTime,
      old.elapsedEndpoint == transition.start.elapsed,
      transition.start.sourceBoundary.parentView.atlas === atlas else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var constituents: [ClosedCutConstituent] = []
    try work.reservePreparedMetadataRecords(origin.roleMap.count)
    let roles = origin.roleMap.map(\.role)
    try work.reservePreparedMetadataRecords(2 * roles.count + 1)
    guard Set(roles).count == roles.count, roles.contains(.support), roles.count <= 4 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    for role in roles {
      let view: Atlas.View
      switch atlas.prepareView(parts: [role], work: &work) {
      case .prepared(let actual, _): view = actual
      case .refused(.allowance, _): throw G.Failure.workBudgetExceeded
      case .refused: throw ClosedCutPartitionFailure.unresolvedPartition
      }
      let value = try closedCutConstituent(role, view: view, work: &work)
      try work.reservePreparedMetadataRecords(1)
      constituents.append(value)
    }
    try work.reservePreparedMetadataRecords(constituents.count)
    guard let support = constituents.first(where: { $0.role == .support }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var interfaces: [ClosedCutInterface] = []
    for head in constituents {
      try work.reservePreparedMetadataRecords(1)
      guard head.role != .support else { continue }
      try work.reservePreparedMetadataRecords(head.facets.count)
      guard let back = head.facets.first(where: { $0.id.sourceFace == 1 }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      var matches: [ClosedCutFacet] = []
      for face in support.facets {
        try work.reservePreparedMetadataRecords(1)
        guard face.id.sourceFace == 0 else { continue }
        if try closedCutSameRectangle(face, back, opposite: true, work: &work) {
          try work.reservePreparedMetadataRecords(1)
          matches.append(face)
        }
      }
      try work.reservePreparedMetadataRecords(1)
      guard matches.count == 1 else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(1)
      interfaces.append(.init(head: head.role, support: matches[0], headBack: back))
    }
    // Once complete oriented six-face geometry is proved, these are EXACT
    // solid supports, not a replacement of general meshes by bounding boxes.
    // Source template parts must have disjoint interiors; only named support
    // interfaces may touch. This does not compare independently moving bodies.
    for i in constituents.indices {
      for j in constituents.indices {
        try work.reservePreparedMetadataRecords(1)
        guard j > i else { continue }
        let a = constituents[i], b = constituents[j]
        var strict = false, closed = false
        for axis in 0..<3 {
          try work.reservePreparedMetadataRecords(4)
          strict = strict || a.maximum[axis] < b.minimum[axis] || b.maximum[axis] < a.minimum[axis]
          closed = closed || a.maximum[axis] <= b.minimum[axis] || b.maximum[axis] <= a.minimum[axis]
        }
        try work.reservePreparedMetadataRecords(1)
        guard closed else { throw ClosedCutPartitionFailure.unresolvedPartition }
        if !strict {
          try work.reservePreparedMetadataRecords(interfaces.count + 2)
          let head = a.role == .support ? b.role : a.role
          guard a.role == .support || b.role == .support,
            interfaces.contains(where: { $0.head == head }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
        }
      }
    }
    var before: [ClosedCutComponentCover] = [], after: [ClosedCutComponentCover] = []
    for (index, component) in old.endpoint.enumerated() {
      let cover = try closedCutComponentCover(index, component: component, constituents: constituents, interfaces: interfaces, work: &work)
      try work.reservePreparedMetadataRecords(1)
      before.append(cover)
    }
    for (index, component) in transition.start.components.enumerated() {
      let cover = try closedCutComponentCover(index, component: component, constituents: constituents, interfaces: interfaces, work: &work)
      try work.reservePreparedMetadataRecords(1)
      after.append(cover)
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(transition: transition, constituents: constituents, interfaces: interfaces, before: before, after: after)
  }

  private static func closedCutConstituent(_ role: Role, view: Atlas.View,
    work: inout G.Work) throws -> ClosedCutConstituent {
    try work.reservePreparedMetadataRecords(3)
    guard view.representation.mass.parts.count == 1, view.representation.mass.parts[0].kind == role,
      view.facetIDs.count == view.meshInMaterialFrame.faces.count else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var lo = Array(repeating: Double.infinity, count: 3), hi = Array(repeating: -Double.infinity, count: 3)
    for key in view.vertexIDs {
      try work.reservePreparedMetadataRecords(4)
      guard view.atlas.vertices.indices.contains(key), view.atlas.vertices[key].finite else { throw ClosedCutPartitionFailure.unresolvedPartition }
      for axis in 0..<3 {
        try work.reservePreparedMetadataRecords(2)
        let x = closedCutCoordinate(view.atlas.vertices[key], axis)
        lo[axis] = min(lo[axis], x); hi[axis] = max(hi[axis], x)
      }
    }
    try work.reservePreparedMetadataRecords(3)
    guard (0..<3).allSatisfy({ lo[$0] < hi[$0] }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var facets: [ClosedCutFacet] = []
    for face in view.facetIDs.indices {
      let value = try closedCutFacet(view, face: face, work: &work)
      try work.reservePreparedMetadataRecords(1)
      guard value.id.role == role else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(1)
      facets.append(value)
    }
    let axes = [2, 2, 1, 0, 1, 0], signs = [-1, 1, -1, 1, 1, -1]
    for sourceFace in 0..<6 {
      try work.reservePreparedMetadataRecords(facets.count)
      let group = facets.filter { $0.id.sourceFace == sourceFace }
      let axis = axes[sourceFace], sign = signs[sourceFace], u = (axis + 1) % 3, v = (axis + 2) % 3
      try work.reservePreparedMetadataRecords(1)
      guard !group.isEmpty else { throw ClosedCutPartitionFailure.unresolvedPartition }
      for face in group {
        try work.reservePreparedMetadataRecords(3)
        guard face.axis == axis, face.orientation == sign, face.plane == (sign < 0 ? lo[axis] : hi[axis])
        else { throw ClosedCutPartitionFailure.unresolvedPartition }
      }
      if role == .support && sourceFace == 0 {
        try closedCutFrontCoverage(group, u0: lo[u], u1: hi[u], v0: lo[v], v1: hi[v], work: &work)
      } else {
        try work.reservePreparedMetadataRecords(6)
        guard group.count == 1, group[0].id.supportTile == nil, group[0].u0 == lo[u], group[0].u1 == hi[u],
          group[0].v0 == lo[v], group[0].v1 == hi[v] else { throw ClosedCutPartitionFailure.unresolvedPartition }
      }
    }
    try work.reservePreparedMetadataRecords(facets.count)
    guard facets.allSatisfy({ (0..<6).contains($0.id.sourceFace) }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
    let edges = try closedCutEdges(view: view, facets: facets, work: &work)
    try work.reservePreparedMetadataRecords(1)
    return .init(role: role, view: view, facets: facets, minimum: lo, maximum: hi, edges: edges)
  }

  /// A polygon must traverse its ACTUAL rectangle once in one orientation.
  /// Collinear edge subdivisions are allowed; backtracking/holes/diagonals/
  /// duplicate points/non-axis geometry refuse. No area tolerance is used.
  private static func closedCutFacet(_ view: Atlas.View, face: Int, work: inout G.Work) throws -> ClosedCutFacet {
    try work.reservePreparedMetadataRecords(2)
    guard view.facetIDs.indices.contains(face), view.meshInMaterialFrame.faces.indices.contains(face) else { throw ClosedCutPartitionFailure.unresolvedPartition }
    let indices = view.meshInMaterialFrame.faces[face]
    try work.reservePreparedMetadataRecords(1)
    guard indices.count >= 4 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var keys: [Int] = [], points: [Vector3] = []
    for index in indices {
      try work.reservePreparedMetadataRecords(2)
      guard view.vertexIDs.indices.contains(index), view.atlas.vertices.indices.contains(view.vertexIDs[index]) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      let key = view.vertexIDs[index], point = view.atlas.vertices[key]
      try work.reservePreparedMetadataRecords(3 + points.count)
      guard point.finite, !points.contains(point) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(2)
      keys.append(key); points.append(point)
    }
    var constant: [Int] = []
    for axis in 0..<3 {
      try work.reservePreparedMetadataRecords(points.count)
      if points.allSatisfy({ closedCutCoordinate($0, axis) == closedCutCoordinate(points[0], axis) }) {
        try work.reservePreparedMetadataRecords(1); constant.append(axis)
      }
    }
    try work.reservePreparedMetadataRecords(1)
    guard constant.count == 1 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    let axis = constant[0], u = (axis + 1) % 3, v = (axis + 2) % 3
    var u0 = Double.infinity, u1 = -Double.infinity, v0 = Double.infinity, v1 = -Double.infinity
    for point in points {
      try work.reservePreparedMetadataRecords(4)
      u0 = min(u0, closedCutCoordinate(point, u)); u1 = max(u1, closedCutCoordinate(point, u))
      v0 = min(v0, closedCutCoordinate(point, v)); v1 = max(v1, closedCutCoordinate(point, v))
    }
    var orientation: Int?
    for i in points.indices {
      let a = points[i], b = points[(i + 1) % points.count]
      let au = closedCutCoordinate(a, u), av = closedCutCoordinate(a, v)
      let bu = closedCutCoordinate(b, u), bv = closedCutCoordinate(b, v)
      try work.reservePreparedMetadataRecords(8)
      let positive = (av == v0 && bv == v0 && au < bu)
        || (au == u1 && bu == u1 && av < bv)
        || (av == v1 && bv == v1 && au > bu)
        || (au == u0 && bu == u0 && av > bv)
      let negative = (av == v0 && bv == v0 && au > bu)
        || (au == u1 && bu == u1 && av > bv)
        || (av == v1 && bv == v1 && au < bu)
        || (au == u0 && bu == u0 && av < bv)
      guard positive != negative else { throw ClosedCutPartitionFailure.unresolvedPartition }
      let sign = positive ? 1 : -1
      if let orientation { guard orientation == sign else { throw ClosedCutPartitionFailure.unresolvedPartition } }
      else { orientation = sign }
    }
    var corners: [Int] = []
    for (x, y) in [(u0, v0), (u1, v0), (u1, v1), (u0, v1)] {
      try work.reservePreparedMetadataRecords(points.count)
      guard let index = points.firstIndex(where: { closedCutCoordinate($0, u) == x && closedCutCoordinate($0, v) == y }) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(1)
      corners.append(keys[index])
    }
    guard let orientation else { throw ClosedCutPartitionFailure.unresolvedPartition }
    try work.reservePreparedMetadataRecords(1)
    return .init(id: view.facetIDs[face], axis: axis, plane: closedCutCoordinate(points[0], axis),
      u0: u0, u1: u1, v0: v0, v1: v1, orientation: orientation, vertices: keys, corners: corners)
  }

  private static func closedCutFrontCoverage(_ faces: [ClosedCutFacet], u0: Double, u1: Double,
    v0: Double, v1: Double, work: inout G.Work) throws {
    try work.reservePreparedMetadataRecords(1)
    guard faces.count == 15 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var us: [Double] = [], vs: [Double] = [], names: [Int] = []
    for face in faces {
      try work.reservePreparedMetadataRecords(1 + names.count)
      guard let name = face.id.supportTile, (0..<15).contains(name), !names.contains(name) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(5)
      names.append(name); us.append(face.u0); us.append(face.u1); vs.append(face.v0); vs.append(face.v1)
    }
    let x = try closedCutUniqueSorted(us, work: &work), y = try closedCutUniqueSorted(vs, work: &work)
    try work.reservePreparedMetadataRecords(6)
    guard x.count == 6, y.count == 4, x.first == u0, x.last == u1, y.first == v0, y.last == v1 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var cells: [Int] = []
    for face in faces {
      try work.reservePreparedMetadataRecords(2 * x.count + 2 * y.count)
      guard let a = x.firstIndex(of: face.u0), let b = x.firstIndex(of: face.u1),
        let c = y.firstIndex(of: face.v0), let d = y.firstIndex(of: face.v1), b == a + 1, d == c + 1
      else { throw ClosedCutPartitionFailure.unresolvedPartition }
      let cell = a * 3 + c
      try work.reservePreparedMetadataRecords(cells.count)
      guard !cells.contains(cell) else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(1); cells.append(cell)
    }
  }

  private static func closedCutComponentCover(_ index: Int, component: Component,
    constituents: [ClosedCutConstituent], interfaces: [ClosedCutInterface], work: inout G.Work) throws -> ClosedCutComponentCover {
    let view = component.view
    try reserveShape(component.state.representation, work: &work)
    guard view.matches(component.state.representation) else { throw ClosedCutPartitionFailure.unresolvedPartition }
    try work.reservePreparedMetadataRecords(component.state.representation.mass.parts.count)
    let roles = component.state.representation.mass.parts.map(\.kind)
    // A verified singleton is the SAME actual atlas geometry, not a rebuilt
    // model. Reuse its paid face/edge proof after checking the incoming view.
    if roles.count == 1 {
      try work.reservePreparedMetadataRecords(constituents.count)
      guard let part = constituents.first(where: { $0.role == roles[0] }), part.view.atlas === view.atlas
      else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(view.vertexIDs.count + view.facetIDs.count + view.meshInMaterialFrame.faces.count)
      for face in view.meshInMaterialFrame.faces { try work.reservePreparedMetadataRecords(face.count) }
      guard view.vertexIDs == part.view.vertexIDs, view.facetIDs == part.view.facetIDs,
        view.meshInMaterialFrame.faces == part.view.meshInMaterialFrame.faces else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(1)
      return .init(component: index, view: view, roles: roles, exterior: part.facets,
        cancelledInterfaces: [], orientedEdges: part.orientedEdges)
    }
    var expected: [ClosedCutFacet] = []
    for role in roles {
      try work.reservePreparedMetadataRecords(constituents.count)
      guard let part = constituents.first(where: { $0.role == role }), part.view.atlas === view.atlas else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(part.facets.count); expected.append(contentsOf: part.facets)
    }
    var cancelled: [Role] = []
    try work.reservePreparedMetadataRecords(roles.count)
    if roles.contains(.support) {
      for interface in interfaces {
        try work.reservePreparedMetadataRecords(roles.count)
        guard roles.contains(interface.head) else { continue }
        try work.reservePreparedMetadataRecords(2 * expected.count)
        guard let a = expected.firstIndex(where: { $0.id == interface.support.id }),
          let b = expected.firstIndex(where: { $0.id == interface.headBack.id }), a != b,
          try closedCutSameRectangle(expected[a], expected[b], opposite: true, work: &work)
        else { throw ClosedCutPartitionFailure.unresolvedPartition }
        var remaining: [ClosedCutFacet] = []
        for index in expected.indices {
          try work.reservePreparedMetadataRecords(1)
          if index != a && index != b { try work.reservePreparedMetadataRecords(1); remaining.append(expected[index]) }
        }
        expected = remaining
        try work.reservePreparedMetadataRecords(1); cancelled.append(interface.head)
      }
    }
    try work.reservePreparedMetadataRecords(1)
    guard expected.count == view.facetIDs.count else { throw ClosedCutPartitionFailure.unresolvedPartition }
    var actual: [ClosedCutFacet] = [], used: [Int] = []
    for face in view.facetIDs.indices {
      let value = try closedCutFacet(view, face: face, work: &work)
      try work.reservePreparedMetadataRecords(expected.count + used.count)
      guard let match = expected.firstIndex(where: { $0.id == value.id }), !used.contains(match),
        try closedCutSameRectangle(expected[match], value, opposite: false, work: &work)
      else { throw ClosedCutPartitionFailure.unresolvedPartition }
      try work.reservePreparedMetadataRecords(2); used.append(match); actual.append(value)
    }
    let edges = try closedCutEdges(view: view, facets: actual, work: &work)
    try work.reservePreparedMetadataRecords(1)
    return .init(component: index, view: view, roles: roles, exterior: actual, cancelledInterfaces: cancelled, orientedEdges: edges)
  }

  private static func closedCutSameRectangle(_ a: ClosedCutFacet, _ b: ClosedCutFacet, opposite: Bool,
    work: inout G.Work) throws -> Bool {
    try work.reservePreparedMetadataRecords(7 + a.corners.count + b.corners.count)
    return a.axis == b.axis && a.plane == b.plane && a.u0 == b.u0 && a.u1 == b.u1 && a.v0 == b.v0 && a.v1 == b.v1
      && a.orientation == (opposite ? -b.orientation : b.orientation) && Set(a.corners) == Set(b.corners)
  }

  /// Split each actual axis edge by ALL actual source points on it. Exactly
  /// one incidence in each orientation is required for every atomic segment.
  private static func closedCutEdges(view: Atlas.View, facets: [ClosedCutFacet], work: inout G.Work) throws -> [ClosedCutEdge] {
    var edges: [ClosedCutEdge] = []
    for face in facets {
      for i in face.vertices.indices {
        let a = face.vertices[i], b = face.vertices[(i + 1) % face.vertices.count]
        let p = view.atlas.vertices[a], q = view.atlas.vertices[b]
        var axes: [Int] = []
        for axis in 0..<3 {
          try work.reservePreparedMetadataRecords(1)
          if closedCutCoordinate(p, axis) != closedCutCoordinate(q, axis) { try work.reservePreparedMetadataRecords(1); axes.append(axis) }
        }
        try work.reservePreparedMetadataRecords(1)
        guard axes.count == 1 else { throw ClosedCutPartitionFailure.unresolvedPartition }
        let axis = axes[0], otherA = (axis + 1) % 3, otherB = (axis + 2) % 3
        let x0 = closedCutCoordinate(p, axis), x1 = closedCutCoordinate(q, axis)
        var points: [Int] = []
        for key in view.vertexIDs {
          try work.reservePreparedMetadataRecords(5)
          guard view.atlas.vertices.indices.contains(key) else { throw ClosedCutPartitionFailure.unresolvedPartition }
          let r = view.atlas.vertices[key], x = closedCutCoordinate(r, axis)
          if closedCutCoordinate(r, otherA) == closedCutCoordinate(p, otherA)
            && closedCutCoordinate(r, otherB) == closedCutCoordinate(p, otherB) && min(x0, x1) <= x && x <= max(x0, x1) {
            try work.reservePreparedMetadataRecords(1); points.append(key)
          }
        }
        try points.sort { a, b in
          try work.reservePreparedMetadataRecords(1)
          return closedCutCoordinate(view.atlas.vertices[a], axis) < closedCutCoordinate(view.atlas.vertices[b], axis)
        }
        try work.reservePreparedMetadataRecords(2)
        guard points.count >= 2, points.first == (x0 < x1 ? a : b), points.last == (x0 < x1 ? b : a)
        else { throw ClosedCutPartitionFailure.unresolvedPartition }
        for j in 1..<points.count {
          try work.reservePreparedMetadataRecords(1)
          guard closedCutCoordinate(view.atlas.vertices[points[j - 1]], axis) < closedCutCoordinate(view.atlas.vertices[points[j]], axis)
          else { throw ClosedCutPartitionFailure.unresolvedPartition }
          try work.reservePreparedMetadataRecords(1)
          edges.append(.init(start: x0 < x1 ? points[j - 1] : points[j], end: x0 < x1 ? points[j] : points[j - 1]))
        }
      }
    }
    for edge in edges {
      var forward = 0, reverse = 0
      for other in edges {
        try work.reservePreparedMetadataRecords(2)
        if edge.start == other.start && edge.end == other.end { forward += 1 }
        if edge.start == other.end && edge.end == other.start { reverse += 1 }
      }
      try work.reservePreparedMetadataRecords(2)
      guard forward == 1, reverse == 1 else { throw ClosedCutPartitionFailure.unresolvedPartition }
    }
    return edges
  }

  private static func closedCutUniqueSorted(_ values: [Double], work: inout G.Work) throws -> [Double] {
    var result: [Double] = []
    for value in values {
      try work.reservePreparedMetadataRecords(result.count)
      if !result.contains(value) { try work.reservePreparedMetadataRecords(1); result.append(value) }
    }
    try result.sort { a, b in try work.reservePreparedMetadataRecords(1); return a < b }
    return result
  }
  private static func closedCutCoordinate(_ point: Vector3, _ axis: Int) -> Double {
    switch axis { case 0: point.x; case 1: point.y; default: point.z }
  }
}
