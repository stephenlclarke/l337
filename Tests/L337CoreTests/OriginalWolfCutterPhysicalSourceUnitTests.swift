import Foundation
import Testing

@testable import L337Core

struct OriginalWolfCutterPhysicalSourceUnitTests {
  private func source() throws -> OriginalWolfCutterPhysicalSource {
    try #require(OriginalWolfCutterPhysicalSource.current)
  }

  @Test func currentWolfCutterHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH160"))
    #expect(specification.name == "Wolf Cutter")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH160")
    let model = try OriginalFleetShowroomModels.model(for: "SH160")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH160"))
    #expect(finite.emptyDry.massKg == 33038)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 764 && model.nativeDesign.vertices.count == 440)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.2815806030536419)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (0.5370744544403186)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-1.8908650240178204)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 0.538966263691374)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.03632181124765422) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 39.49996973182397) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0010351914110074867)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.004179944745273164)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.005370089727873887)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 84.09541072002678) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteWolfCutter() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH160")
    let path = OriginalWolfCutterPhysicalSource.folder.appendingPathComponent(OriginalWolfCutterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalWolfCutterPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalWolfCutterPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalWolfCutterPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH159")
    #expect(OriginalWolfCutterPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalWolfCutterPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalWolfCutterPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalWolfCutterPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual764FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH160", sourceFaces: 764, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH160")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH160", actualSourceFaces: 764, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH160")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH160") == nil)
    #expect(ShipCatalogue.rawMesh("SH160") == nil)
    #expect(ShipCatalogue.ship("SH160")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH160"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(contract.accommodation?.operatingCrew == 3)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 26)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH160")
    let model = try OriginalFleetShowroomModels.model(for: "SH160")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH160"])
    #expect(finite.metresPerSourceUnit == 3000000.0 / 377113.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "3000000/377113")
    #expect(engineering.metresPerSourceUnitExact == "3000000/377113")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH160-design.toml")
    #expect(model.sourceSHA256 == "febeb15ca6ed5dc6b53b3c59f8405edec733ff85af13f923fab3122d14f73083")
    #expect(model.nativeDesign.vertices.first == [-0.836062, -0.34, -1.84756])
    #expect(model.nativeDesign.faces.count == 764)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH160")
    let path = OriginalWolfCutterPhysicalSource.folder.appendingPathComponent(OriginalWolfCutterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalWolfCutterPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalWolfCutterPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalWolfCutterPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
