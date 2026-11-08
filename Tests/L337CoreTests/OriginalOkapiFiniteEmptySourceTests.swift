import Foundation
import Testing

@testable import L337Core

struct OriginalOkapiFiniteEmptySourceTests {
  private func source() throws -> OriginalOkapiFiniteEmptySource {
    try #require(OriginalOkapiFiniteEmptySource.current)
  }

  @Test func finiteReferencePreservesAdoptedPointContractAndCurrentKitSource() throws {
    let before = try OriginalHullPhysicalContract.okapi.get()
    let old = try #require(before.engineering)
    let kitSHA = CurrentNewtKitSource.current?.sourceSHA256
    let kitConfiguration = CurrentNewtKitSource.current?.configuration
    let finite = try source()
    let after = try OriginalHullPhysicalContract.okapi.get()
    let retained = try #require(after.engineering)
    #expect(finite.emptyDry.massKg == 45520 && finite.emptyDry.massKg == Double(old.dryMassKilograms))
    #expect(finite.specificationSHA256 == before.specificationSHA256)
    #expect(finite.nativeSourceSHA256 == before.model.sourceSHA256)
    #expect(before.physicalMesh.vertices == after.physicalMesh.vertices)
    #expect(before.physicalMesh.faces == after.physicalMesh.faces)
    #expect(old.centreOfMassMetres == retained.centreOfMassMetres)
    #expect(old.inertiaAboutCentreOfMassKgM2 == retained.inertiaAboutCentreOfMassKgM2)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != old.inertiaAboutCentreOfMassKgM2)
    #expect(CurrentNewtKitSource.current?.sourceSHA256 == kitSHA)
    #expect(CurrentNewtKitSource.current?.configuration == kitConfiguration)
    #expect(before.metresPerSourceUnit == 1 && before.model.coordinateUnits == "metres")
    #expect(before.nativeTriangles == 120 && after.nativeTriangles == 120)
    #expect(abs(finite.emptyDry.centre.x - (-0.000439370327030006)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-1.425719911368685)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.212408784621561)) < 1e-12)
  }

  @Test func centreImpulseProducesOnlyReferenceTranslation() throws {
    let finite = try source()
    let impulse = Vector3(1200, -600, 900)
    let result = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: finite.emptyDry.centre))
    #expect(result.angularVelocityDelta.length == 0 && result.angularMomentumDelta.length == 0)
    #expect(abs(result.centreVelocityDelta.x - 0.026362038664323375) < 1e-14)
    #expect(abs(result.centreVelocityDelta.y - (-0.013181019332161687)) < 1e-14)
    #expect(abs(result.centreVelocityDelta.z - 0.01977152899824253) < 1e-14)
    #expect(abs(result.kineticEnergyFromRestJoules - impulse.dot(result.centreVelocityDelta) / 2) < 1e-10)
  }

  @Test func offAxisReferenceMatchesIndependentIntegralsAndFullTensorSolve() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let result = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA box/tetrahedron/surface quadrature plus an independent full linear solve.
    #expect(abs(result.angularVelocityDelta.x - (-0.00016480753782537286)) < 1e-13)
    #expect(abs(result.angularVelocityDelta.y - (-0.0025322975943658896)) < 1e-13)
    #expect(abs(result.angularVelocityDelta.z - (-0.004797469268593641)) < 1e-13)
    #expect(abs(result.kineticEnergyFromRestJoules - 63.61341085616152) < 1e-10)
    let a = finite.emptyDry.inertiaAboutCentreOfMassKgM2, w = result.angularVelocityDelta
    let moment = Vector3(a[0] * w.x + a[1] * w.y + a[2] * w.z,
      a[3] * w.x + a[4] * w.y + a[5] * w.z,
      a[6] * w.x + a[7] * w.y + a[8] * w.z)
    #expect((moment - result.angularMomentumDelta).length < 1e-8)
    #expect((result.centreVelocityDelta * finite.emptyDry.massKg - impulse).length < 1e-9)
    #expect((finite.emptyDry.centre.cross(impulse) + moment - point.cross(impulse)).length < 1e-8)
    let pointVelocity = result.centreVelocityDelta + w.cross(point - finite.emptyDry.centre)
    #expect(abs(impulse.dot(pointVelocity) / 2 - result.kineticEnergyFromRestJoules) < 1e-10)
    let diagonal = Vector3(result.angularMomentumDelta.x / a[0],
      result.angularMomentumDelta.y / a[4], result.angularMomentumDelta.z / a[8])
    let wrongMoment = Vector3(a[0] * diagonal.x + a[1] * diagonal.y + a[2] * diagonal.z,
      a[3] * diagonal.x + a[4] * diagonal.y + a[5] * diagonal.z,
      a[6] * diagonal.x + a[7] * diagonal.y + a[8] * diagonal.z)
    #expect((wrongMoment - result.angularMomentumDelta).length > 1e-6)
  }

  @Test func nonfiniteInputHasNoReferenceResponse() throws {
    let finite = try source()
    #expect(finite.responseFromRest(impulse: .init(.nan, 0, 0), atLocalPoint: .init(0, 0, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(1, 0, 0), atLocalPoint: .init(0, .infinity, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(.greatestFiniteMagnitude, 1, 0),
      atLocalPoint: .init(0, 10, 10)) == nil)
  }

  @Test func missingChangedTruncatedForeignOrSymlinkedReferenceRefuses() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH029")
    let path = OriginalOkapiFiniteEmptySource.folder.appendingPathComponent(OriginalOkapiFiniteEmptySource.fileName)
    let bytes = try Data(contentsOf: path)
    #expect(OriginalOkapiFiniteEmptySource.decode(bytes, model: model) != nil)
    var changed = bytes
    changed[changed.startIndex] = 0
    #expect(OriginalOkapiFiniteEmptySource.decode(changed, model: model) == nil)
    #expect(OriginalOkapiFiniteEmptySource.decode(Data(bytes.dropLast()), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH061")
    #expect(OriginalOkapiFiniteEmptySource.decode(bytes, model: foreign) == nil)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    #expect(OriginalOkapiFiniteEmptySource.load(from: directory, model: model) == nil)
    try FileManager.default.createSymbolicLink(
      at: directory.appendingPathComponent(OriginalOkapiFiniteEmptySource.fileName), withDestinationURL: path)
    #expect(OriginalOkapiFiniteEmptySource.load(from: directory, model: model) == nil)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH029")
    let path = OriginalOkapiFiniteEmptySource.folder.appendingPathComponent(OriginalOkapiFiniteEmptySource.fileName)
    let bytes = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: nil, nativeDesign: model.nativeDesign)
    #expect(OriginalOkapiFiniteEmptySource.decode(bytes, model: wrongUnits) == nil)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model.nativeDesign))
      as? [String: Any])
    var vertices = try #require(object["vertices"] as? [[Double]])
    vertices[0][0] += 0.01
    object["vertices"] = vertices
    let shifted = try JSONDecoder().decode(ShipDesign.self, from: JSONSerialization.data(withJSONObject: object))
    try #require(shifted.valid)
    let wrongGeometry = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: model.coordinateUnits, nativeDesign: shifted)
    #expect(OriginalOkapiFiniteEmptySource.decode(bytes, model: wrongGeometry) == nil)
    object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model.nativeDesign))
      as? [String: Any])
    var materials = try #require(object["faceMaterials"] as? [Int])
    materials[0] = materials[0] == 0 ? 1 : 0
    object["faceMaterials"] = materials
    let painted = try JSONDecoder().decode(ShipDesign.self, from: JSONSerialization.data(withJSONObject: object))
    try #require(painted.valid)
    let wrongAppearance = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: model.coordinateUnits, nativeDesign: painted)
    #expect(OriginalOkapiFiniteEmptySource.decode(bytes, model: wrongAppearance) == nil)
  }
}
