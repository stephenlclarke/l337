import Foundation

extension NativeC01InquiryCompoundValidatedCurve {
  /// Snapshot display/projection DATA only. World source/currentness and native
  /// sample/frame/time identity must come from G1, never from a small residual.
  struct NativeQueryViewPositionError: Sendable {
    let world: NativeMaterialPositionError
    let queryPose: ShipPose
    let screen: Screen
    let representedWorldPoint: Vector3
    let representedQueryPoint: Vector3
    let representedViewPoint: Vector3
    let mathematicalQueryPosition: VectorBox
    let mathematicalViewPosition: VectorBox
    let worldResidualInQuery: VectorBox
    let queryArithmeticResidual: VectorBox
    let viewArithmeticResidual: VectorBox
    let queryDifference: VectorBox
    let viewDifference: VectorBox
    let queryError: Interval
    let viewError: Interval

    fileprivate init(world: NativeMaterialPositionError, queryPose: ShipPose, screen: Screen,
      representedWorldPoint: Vector3, representedQueryPoint: Vector3, representedViewPoint: Vector3,
      mathematicalQuery: VectorBox, mathematicalView: VectorBox, linearResidual: VectorBox,
      queryArithmeticResidual: VectorBox, viewArithmeticResidual: VectorBox,
      queryDifference: VectorBox, viewDifference: VectorBox, queryError: Interval, viewError: Interval)
    {
      self.world = world; self.queryPose = queryPose; self.screen = screen
      self.representedWorldPoint = representedWorldPoint
      self.representedQueryPoint = representedQueryPoint; self.representedViewPoint = representedViewPoint
      mathematicalQueryPosition = mathematicalQuery; mathematicalViewPosition = mathematicalView
      worldResidualInQuery = linearResidual
      self.queryArithmeticResidual = queryArithmeticResidual; self.viewArithmeticResidual = viewArithmeticResidual
      self.queryDifference = queryDifference; self.viewDifference = viewDifference
      self.queryError = queryError; self.viewError = viewError
    }
  }

  /// Reuse the EXACT captured shipPoint then viewPosition graph. A is the
  /// represented basis TRANSPOSE used by shipVector, not a general inverse or
  /// an exact rigid camera. Query norms/radii are not thereby world metrics.
  static func prepareNativeQueryViewPositionError(_ world: NativeMaterialPositionError,
    queryPose: ShipPose, screen: Screen, representedWorldPoint: Vector3,
    representedQueryPoint: Vector3, representedViewPoint: Vector3,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeQueryViewPositionError
  {
    try work.reservePreparedMetadataRecords(2)
    try work.reservePreparedMetadataRecords(21)
    guard representedWorldPoint.finite, representedQueryPoint.finite, representedViewPoint.finite,
      queryPose.position.finite, queryPose.orientation.x.finite,
      queryPose.orientation.y.finite, queryPose.orientation.z.finite else {
      throw ConstrainedCellFailure.invalidDomain
    }
    try work.reservePreparedMetadataRecords(1)
    guard screen.isFlight else { throw ConstrainedCellFailure.invalidDomain }
    try work.reservePreparedMetadataRecords(3)
    let nativeWorldBox = VectorBox.point(representedWorldPoint)
    try work.reservePreparedMetadataRecords(3)
    guard world.representedPosition.values == nativeWorldBox.values else {
      throw ConstrainedCellFailure.invalidDomain
    }
    // Real native operation graph, not an independently reimplemented camera:
    // subtraction3 and three (products3+sums2), then selected view coordinates3.
    try work.reservePreparedMetadataRecords(18)
    let nativeQuery = queryPose.shipPoint(representedWorldPoint)
    try work.reservePreparedMetadataRecords(3)
    let nativeView = Game.viewPosition(nativeQuery, screen: screen)
    try work.reservePreparedMetadataRecords(14)
    guard nativeQuery.length.isFinite, nativeView.length.isFinite else {
      throw ConstrainedCellFailure.nonfinite
    }
    try work.reservePreparedMetadataRecords(6)
    guard sameNativePosition(nativeQuery, representedQueryPoint),
      sameNativePosition(nativeView, representedViewPoint) else {
      throw ConstrainedCellFailure.invalidDomain
    }
    try work.reservePreparedMetadataRecords(6)
    let nativeQueryBox = VectorBox.point(representedQueryPoint)
    let nativeViewBox = VectorBox.point(representedViewPoint)
    try work.reservePreparedMetadataRecords(12)
    let rows = (x: VectorBox.point(queryPose.orientation.x),
      y: VectorBox.point(queryPose.orientation.y), z: VectorBox.point(queryPose.orientation.z))
    let origin = VectorBox.point(queryPose.position)
    let mathematicalQuery = try queryPosition(world.mathematicalPosition, origin: origin, rows: rows, work: &work)
    let projectedNativeWorld = try queryPosition(nativeWorldBox, origin: origin, rows: rows, work: &work)
    let linearResidual = try queryVector(world.mathematicalMinusRepresented, rows: rows, work: &work)
    try work.reservePreparedMetadataRecords(3)
    let queryArithmeticResidual = projectedNativeWorld - nativeQueryBox
    try work.reservePreparedMetadataRecords(3)
    let queryDifference = linearResidual + queryArithmeticResidual
    let mathematicalView = try viewPositionBounds(mathematicalQuery, screen: screen, work: &work)
    let projectedNativeQuery = try viewPositionBounds(nativeQueryBox, screen: screen, work: &work)
    try work.reservePreparedMetadataRecords(3)
    let viewArithmeticResidual = projectedNativeQuery - nativeViewBox
    let projectedQueryDifference = try viewPositionBounds(queryDifference, screen: screen, work: &work)
    try work.reservePreparedMetadataRecords(3)
    let viewDifference = projectedQueryDifference + viewArithmeticResidual
    try work.reservePreparedMetadataRecords(9)
    let queryError = NativeC01InquiryCurveGeometry.length(queryDifference)
    try work.reservePreparedMetadataRecords(9)
    let viewError = NativeC01InquiryCurveGeometry.length(viewDifference)
    try work.reservePreparedMetadataRecords(28)
    guard mathematicalQuery.valid, mathematicalView.valid, projectedNativeWorld.valid, linearResidual.valid,
      queryArithmeticResidual.valid, queryDifference.valid, viewArithmeticResidual.valid, viewDifference.valid,
      queryError.valid, viewError.valid, queryError.lower >= 0, viewError.lower >= 0 else {
      throw ConstrainedCellFailure.nonfinite
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(world: world, queryPose: queryPose, screen: screen,
      representedWorldPoint: representedWorldPoint, representedQueryPoint: representedQueryPoint,
      representedViewPoint: representedViewPoint, mathematicalQuery: mathematicalQuery,
      mathematicalView: mathematicalView, linearResidual: linearResidual,
      queryArithmeticResidual: queryArithmeticResidual, viewArithmeticResidual: viewArithmeticResidual,
      queryDifference: queryDifference, viewDifference: viewDifference, queryError: queryError, viewError: viewError)
  }

  private static func sameNativePosition(_ first: Vector3, _ second: Vector3) -> Bool {
    first.x.bitPattern == second.x.bitPattern && first.y.bitPattern == second.y.bitPattern
      && first.z.bitPattern == second.z.bitPattern
  }

  private static func queryPosition(_ point: VectorBox, origin: VectorBox,
    rows: (x: VectorBox, y: VectorBox, z: VectorBox),
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox
  {
    try work.reservePreparedMetadataRecords(3)
    let relative = point - origin
    return try queryVector(relative, rows: rows, work: &work)
  }

  private static func queryVector(_ vector: VectorBox, rows: (x: VectorBox, y: VectorBox, z: VectorBox),
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox
  {
    try work.reservePreparedMetadataRecords(15)
    return .init(x: NativeC01InquiryCurveGeometry.dot(vector, rows.x),
      y: NativeC01InquiryCurveGeometry.dot(vector, rows.y),
      z: NativeC01InquiryCurveGeometry.dot(vector, rows.z))
  }

  private static func viewPositionBounds(_ point: VectorBox, screen: Screen,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> VectorBox
  {
    try work.reservePreparedMetadataRecords(3)
    switch screen {
    case .rear: return .init(x: -point.x, y: point.y, z: -point.z)
    case .left: return .init(x: point.z, y: point.y, z: -point.x)
    case .right: return .init(x: -point.z, y: point.y, z: point.x)
    default: return point
    }
  }
}
