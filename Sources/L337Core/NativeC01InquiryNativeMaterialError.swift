import Foundation

extension NativeC01InquiryCompoundValidatedCurve {
  /// Conditional mathematical error DATA, never a native source/pose/event seal.
  /// G1 must bind represented bounds to the same actual material vertex, frame,
  /// component and time interval and retain that native owner independently.
  struct NativeMaterialError: Sendable {
    let view: NativeC01InquiryCompoundMaterialAtlas.View
    let vertex: Int
    let mathematical: MaterialBounds
    let represented: MaterialBounds
    let mathematicalMinusRepresented: MaterialBounds
    let positionError: Interval
    let velocityError: Interval

    fileprivate init(view: NativeC01InquiryCompoundMaterialAtlas.View, vertex: Int,
      mathematical: MaterialBounds, represented: MaterialBounds, difference: MaterialBounds,
      positionError: Interval, velocityError: Interval)
    {
      self.view = view; self.vertex = vertex
      self.mathematical = mathematical; self.represented = represented
      mathematicalMinusRepresented = difference
      self.positionError = positionError; self.velocityError = velocityError
    }
  }

  /// Existing cut-derived material geometry supplies q/C/P/L and the stable
  /// atlas/REAL COM relation. A represented endpoint point-box is merely a
  /// proxy comparison, never a new authoritative State or quaternion seed.
  static func prepareCutNativeMaterialError(_ geometry: ConstrainedMaterialGeometry,
    vertex: Int, represented: MaterialBounds,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialError
  {
    try work.reservePreparedMetadataRecords(2)
    try validateRepresentedMaterialBounds(represented, work: &work)
    let mathematical = try constrainedMaterialGeometryBounds(geometry, vertex: vertex, work: &work)
    return try materialError(view: geometry.view, vertex: vertex,
      mathematical: mathematical, represented: represented, work: &work)
  }

  /// Reuse the actual coupled slice, including every potentially overlapping
  /// validated cell. No free trajectory, midpoint pose or endpoint interpolation
  /// replaces the retained motion. G1 must enclose its actual represented Y(t)
  /// over this SAME slice before this comparison has a native interpretation.
  static func prepareConstrainedNativeMaterialError(_ slice: ConstrainedMotionSlice,
    vertex: Int, represented: MaterialBounds,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialError
  {
    try work.reservePreparedMetadataRecords(2)
    try validateRepresentedMaterialBounds(represented, work: &work)
    let mathematical = try constrainedMotionMaterialBounds(slice, vertex: vertex, work: &work)
    return try materialError(view: slice.motion.view, vertex: vertex,
      mathematical: mathematical, represented: represented, work: &work)
  }

  private static func validateRepresentedMaterialBounds(_ represented: MaterialBounds,
    work: inout NativeC01InquiryCurveGeometry.Work) throws
  {
    try work.reservePreparedMetadataRecords(6)
    guard represented.position.valid, represented.velocity.valid else {
      throw ConstrainedCellFailure.invalidDomain
    }
  }

  private static func materialError(view: NativeC01InquiryCompoundMaterialAtlas.View,
    vertex: Int, mathematical: MaterialBounds, represented: MaterialBounds,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialError
  {
    try work.reservePreparedMetadataRecords(6)
    guard mathematical.position.valid, mathematical.velocity.valid else {
      throw ConstrainedCellFailure.nonfinite
    }
    try work.reservePreparedMetadataRecords(3)
    let positionDifference = mathematical.position - represented.position
    try work.reservePreparedMetadataRecords(3)
    let velocityDifference = mathematical.velocity - represented.velocity
    // Reuse the existing outward Euclidean norm: three square records, two
    // sums, sum-validity, two rooted endpoints and return, prepaid separately.
    try work.reservePreparedMetadataRecords(9)
    let positionError = NativeC01InquiryCurveGeometry.length(positionDifference)
    try work.reservePreparedMetadataRecords(9)
    let velocityError = NativeC01InquiryCurveGeometry.length(velocityDifference)
    try work.reservePreparedMetadataRecords(10)
    guard positionDifference.valid, velocityDifference.valid,
      positionError.valid, velocityError.valid,
      positionError.lower >= 0, velocityError.lower >= 0 else {
      throw ConstrainedCellFailure.nonfinite
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(view: view, vertex: vertex, mathematical: mathematical,
      represented: represented, difference: .init(position: positionDifference, velocity: velocityDifference),
      positionError: positionError, velocityError: velocityError)
  }
}


extension NativeC01InquiryCompoundValidatedCurve {
  /// Position-only comparison for an actual point-buffer producer. No native
  /// velocity, trajectory, motion receipt or zero-velocity assumption is stored.
  struct NativeMaterialPositionError: Sendable {
    let view: NativeC01InquiryCompoundMaterialAtlas.View
    let vertex: Int
    let mathematicalPosition: VectorBox
    let representedPosition: VectorBox
    let mathematicalMinusRepresented: VectorBox
    let positionError: Interval

    fileprivate init(view: NativeC01InquiryCompoundMaterialAtlas.View, vertex: Int,
      mathematical: VectorBox, represented: VectorBox, difference: VectorBox, error: Interval)
    {
      self.view = view; self.vertex = vertex
      mathematicalPosition = mathematical; representedPosition = represented
      mathematicalMinusRepresented = difference; positionError = error
    }
  }

  /// G1 may supply point boxes from ACTUAL represented endpoint vertices only
  /// after its source/material/frame/time join. This does not generate a pose.
  static func prepareCutNativePositionError(_ geometry: ConstrainedMaterialGeometry,
    vertex: Int, representedPosition: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialPositionError
  {
    try work.reservePreparedMetadataRecords(2)
    try validateRepresentedPosition(representedPosition, work: &work)
    let mathematical = try constrainedMaterialGeometryBounds(geometry, vertex: vertex, work: &work)
    return try positionMaterialError(view: geometry.view, vertex: vertex,
      mathematical: mathematical.position, represented: representedPosition, work: &work)
  }

  /// A slice requires a real conservative enclosure of represented Y(t) on
  /// that SAME interval. Two endpoint point boxes do not supply this premise.
  static func prepareConstrainedNativePositionError(_ slice: ConstrainedMotionSlice,
    vertex: Int, representedPosition: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialPositionError
  {
    try work.reservePreparedMetadataRecords(2)
    try validateRepresentedPosition(representedPosition, work: &work)
    let mathematical = try constrainedMotionMaterialBounds(slice, vertex: vertex, work: &work)
    return try positionMaterialError(view: slice.motion.view, vertex: vertex,
      mathematical: mathematical.position, represented: representedPosition, work: &work)
  }

  private static func validateRepresentedPosition(_ position: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws
  {
    try work.reservePreparedMetadataRecords(3)
    guard position.valid else { throw ConstrainedCellFailure.invalidDomain }
  }

  private static func positionMaterialError(view: NativeC01InquiryCompoundMaterialAtlas.View,
    vertex: Int, mathematical: VectorBox, represented: VectorBox,
    work: inout NativeC01InquiryCurveGeometry.Work) throws -> NativeMaterialPositionError
  {
    try work.reservePreparedMetadataRecords(3)
    guard mathematical.valid else { throw ConstrainedCellFailure.nonfinite }
    try work.reservePreparedMetadataRecords(3)
    let difference = mathematical - represented
    // Same existing outward norm and nine declared processing records as the
    // full comparison. No alternate norm/quaternion/geometry routine is added.
    try work.reservePreparedMetadataRecords(9)
    let error = NativeC01InquiryCurveGeometry.length(difference)
    try work.reservePreparedMetadataRecords(5)
    guard difference.valid, error.valid, error.lower >= 0 else {
      throw ConstrainedCellFailure.nonfinite
    }
    try work.reservePreparedMetadataRecords(1)
    return .init(view: view, vertex: vertex, mathematical: mathematical,
      represented: represented, difference: difference, error: error)
  }
}
