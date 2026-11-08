import Foundation
import Testing

@testable import L337Core

struct OriginalSpringbokStarlinerPhysicalSourceUnitTests {
  private func source() throws -> OriginalSpringbokStarlinerPhysicalSource {
    try #require(OriginalSpringbokStarlinerPhysicalSource.current)
  }

  @Test func currentSpringbokStarlinerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH088")
    let model = try OriginalFleetShowroomModels.model(for: "SH088")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH088"))
    #expect(finite.emptyDry.massKg == 89404)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 912 && model.nativeDesign.vertices.count == 488)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.12933560405244443)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.1001608697932215)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.528364235454314)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.1001608697932224)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.013422218245268668) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 14.596662341729678) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-5.772761547332559e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.00029352168968018475)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0005134481589161953)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 17.37245859497584) < 1e-10)
    let mass = finite.emptyDry.massKg
    #expect((r.centreVelocityDelta * mass - impulse).length < 1e-9)
    let a = finite.emptyDry.inertiaAboutCentreOfMassKgM2, w = r.angularVelocityDelta
    let spin = Vector3(a[0] * w.x + a[1] * w.y + a[2] * w.z,
      a[3] * w.x + a[4] * w.y + a[5] * w.z,
      a[6] * w.x + a[7] * w.y + a[8] * w.z)
    #expect((spin - r.angularMomentumDelta).length < 1e-8)
    #expect((finite.emptyDry.centre.cross(impulse) + spin - point.cross(impulse)).length < 1e-8)
    let pointVelocity = r.centreVelocityDelta + w.cross(point - finite.emptyDry.centre)
    #expect(abs(impulse.dot(pointVelocity) / 2 - r.kineticEnergyFromRestJoules) < 1e-10)
    let diagonalOnly = Vector3(r.angularMomentumDelta.x / a[0],
      r.angularMomentumDelta.y / a[4], r.angularMomentumDelta.z / a[8])
    #expect(((diagonalOnly - w) * 10).length > 1e-5)
  }

  @Test func invalidImpulseOrPointHasNoReferenceResponse() throws {
    let finite = try source()
    #expect(finite.responseFromRest(impulse: .init(.nan, 0, 0), atLocalPoint: .init(0, 0, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(1, 0, 0), atLocalPoint: .init(0, .infinity, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(.greatestFiniteMagnitude, 1, 0),
      atLocalPoint: .init(0, 10, 10)) == nil)
  }

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteSpringbokStarliner() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH088")
    let path = OriginalSpringbokStarlinerPhysicalSource.folder.appendingPathComponent(OriginalSpringbokStarlinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH087")
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalSpringbokStarlinerPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalSpringbokStarlinerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalSpringbokStarlinerPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual912FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH088", sourceFaces: 912, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH088")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH088", actualSourceFaces: 912, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH088")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH088") == nil)
    #expect(ShipCatalogue.rawMesh("SH088") == nil)
    #expect(ShipCatalogue.ship("SH088")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH088"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 8)
    #expect(contract.accommodation?.operatingCrew == 8)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 46)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH088")
    let model = try OriginalFleetShowroomModels.model(for: "SH088")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH088"])
    #expect(finite.metresPerSourceUnit == 64000000.0 / 4107151.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "64000000/4107151")
    #expect(engineering.metresPerSourceUnitExact == "64000000/4107151")
    #expect(engineering.targetDetailedLengthMetres == 64)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH088-design.toml")
    #expect(model.sourceSHA256 == "8382b438252441ae6bb373bf307f7d341ec4d5d16fc525ab8d3edfa8cefbb8de")
    #expect(model.nativeDesign.vertices.first == [-0.310245, -0.04, 2.021151])
    #expect(model.nativeDesign.faces.count == 912)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH088")
    let path = OriginalSpringbokStarlinerPhysicalSource.folder.appendingPathComponent(OriginalSpringbokStarlinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(data, model: wrongUnits) == nil)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(model.nativeDesign)) as? [String: Any])
    var vertices = try #require(object["vertices"] as? [[Double]])
    vertices[0][0] += 0.01
    object["vertices"] = vertices
    let shifted = try JSONDecoder().decode(ShipDesign.self,
      from: JSONSerialization.data(withJSONObject: object))
    try #require(shifted.valid)
    let wrongGeometry = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: model.coordinateUnits, nativeDesign: shifted)
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(data, model: wrongGeometry) == nil)
    object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(model.nativeDesign)) as? [String: Any])
    var materials = try #require(object["faceMaterials"] as? [Int])
    materials[0] = materials[0] == 0 ? 1 : 0
    object["faceMaterials"] = materials
    let painted = try JSONDecoder().decode(ShipDesign.self,
      from: JSONSerialization.data(withJSONObject: object))
    try #require(painted.valid)
    let wrongAppearance = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: model.coordinateUnits, nativeDesign: painted)
    #expect(OriginalSpringbokStarlinerPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
