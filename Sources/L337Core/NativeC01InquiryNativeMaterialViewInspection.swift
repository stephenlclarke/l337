/// Structural source parity only. Equal geometry does not authenticate a live
/// atlas, native material owner, unit quaternion, accepted event or time window.
enum NativeC01InquiryNativeMaterialViewInspection {
  typealias Atlas = NativeC01InquiryCompoundMaterialAtlas
  typealias Shape = NativeC01InquiryCompoundRepresentation
  typealias P = NativeC01InquiryPreparationWork

  /// Same six predicates and ordering as Atlas.View.matches. Real traversals
  /// pay before comparison; the old unmetered predicate is never called here.
  static func matches(_ view: Atlas.View, shape: Shape, meter: P.Meter) throws -> Bool {
    let stored = view.representation
    try meter.records(1, .metadata)
    guard stored.mass.parts.count == shape.mass.parts.count else { return false }
    for index in stored.mass.parts.indices {
      try meter.records(1, .metadata)
      guard stored.mass.parts[index].kind == shape.mass.parts[index].kind else { return false }
    }
    try meter.records(1, .metadata)
    guard stored.mass.massKilograms == shape.mass.massKilograms else { return false }
    try meter.records(1, .metadata)
    guard stored.mass.centreOfMassSource == shape.mass.centreOfMassSource else { return false }
    guard try verticesMatch(stored.sourceVertices, shape.sourceVertices, meter: meter) else { return false }
    guard try verticesMatch(stored.meshAtCentreOfMass.vertices, shape.meshAtCentreOfMass.vertices,
      meter: meter) else { return false }
    return try facesMatch(stored.meshAtCentreOfMass.faces, shape.meshAtCentreOfMass.faces, meter: meter)
  }

  private static func verticesMatch(_ first: [Vector3], _ second: [Vector3],
    meter: P.Meter) throws -> Bool
  {
    try meter.records(1, .metadata)
    guard first.count == second.count else { return false }
    for index in first.indices {
      try meter.records(1, .metadata)
      guard first[index] == second[index] else { return false }
    }
    return true
  }

  private static func facesMatch(_ first: [[Int]], _ second: [[Int]],
    meter: P.Meter) throws -> Bool
  {
    try meter.records(1, .metadata)
    guard first.count == second.count else { return false }
    for index in first.indices {
      try meter.records(1, .metadata)
      guard first[index].count == second[index].count else { return false }
      for vertex in first[index].indices {
        try meter.records(1, .metadata)
        guard first[index][vertex] == second[index][vertex] else { return false }
      }
    }
    return true
  }
}
