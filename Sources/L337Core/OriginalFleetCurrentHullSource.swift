import Foundation

/// Binds current requirements, named engineering stock and the exact authored native source.
/// This source candidate grants no actor admission, fitting, blueprint or native qualification.
struct OriginalFleetCurrentHullSource: Sendable {
  enum Failure: Error, Equatable, Sendable {
    case missingCurrentContract(String)
    case inconsistentNativeSource(String)
    case nativeLODUnqualified(id: String, sourceFaces: Int, maximum: Int)
  }

  let contract: OriginalFleetR3Contract
  let engineering: OriginalFleetPhysicalRecord
  let model: OriginalFleetShowroomModel
  let mesh: Mesh
  let envelope: OriginalHullEnvelope
  let nativeTriangles: Int

  /// Resolve at an admission/load boundary; retain the immutable source rather than reload in a frame.
  init(id: String, model: OriginalFleetShowroomModel? = nil) throws {
    guard let definition = OriginalFleetR3Data.contract(for: id), definition.objectKind == .ship,
      let performance = definition.performance,
      performance.valid(purchasePolicy: definition.purchasePolicy == .never ? .never : .blueprintFabrication),
      definition.accommodation != nil, definition.fitting != nil
    else { throw Failure.missingCurrentContract(id) }
    let record = try OriginalFleetPhysicalData.record(for: id)
    guard let expected = OriginalFleetPhysicalData.registrations[id] else {
      throw OriginalFleetPhysicalData.Failure.unissued(id)
    }
    let source: OriginalFleetShowroomModel
    if let model {
      // Caller-supplied provenance strings cannot authenticate changed geometry or appearance.
      guard model.nativeDesign == (try OriginalFleetShowroomModels.model(for: id)).nativeDesign else {
        throw Failure.inconsistentNativeSource(id)
      }
      source = model
    } else {
      source = try OriginalFleetShowroomModels.model(for: id)
    }
    let expectedUnits: String? = expected.calibration == .declaredMetres ? "metres" : nil
    guard source.id == definition.id, source.coordinateUnits == expectedUnits,
      source.sourcePath == expected.nativeSourcePath,
      source.sourceSHA256 == expected.nativeSourceSHA256
    else { throw Failure.inconsistentNativeSource(id) }
    guard source.nativeDesign.faces.count <= 512 else {
      throw Failure.nativeLODUnqualified(
        id: id, sourceFaces: source.nativeDesign.faces.count, maximum: 512)
    }
    guard source.nativeDesign.valid,
      source.nativeDesign.faces.allSatisfy({ $0.count == 3 }),
      !source.nativeDesign.faces.isEmpty
    else { throw Failure.inconsistentNativeSource(id) }
    let original = source.nativeDesign.rawMesh
    let scale = expected.calibration.metresPerSourceUnit
    let physical = Mesh(
      vertices: original.vertices.map { $0 * scale }, faces: original.faces,
      details: original.details, materials: original.materials,
      faceMaterials: original.faceMaterials, faceTextures: original.faceTextures,
      preserveWinding: true)
    let bounds = try OriginalHullEnvelope(vertices: physical.vertices)
    contract = definition
    engineering = record
    self.model = source
    mesh = physical
    envelope = bounds
    nativeTriangles = source.nativeDesign.faces.count
  }
}
