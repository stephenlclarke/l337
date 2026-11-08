import Foundation
import Testing

@testable import L337Core

struct OriginalSecretarybirdSurveyPhysicalSourceUnitTests {
  private func source() throws -> OriginalSecretarybirdSurveyPhysicalSource {
    try #require(OriginalSecretarybirdSurveyPhysicalSource.current)
  }

  @Test func currentSecretarybirdSurveyHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH167"))
    #expect(specification.name == "SecretarybirdSurvey")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH167")
    let model = try OriginalFleetShowroomModels.model(for: "SH167")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH167"))
    #expect(finite.emptyDry.massKg == 30401)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 620 && model.nativeDesign.vertices.count == 352)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (6.209405982392761e-05)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.7704575917449273)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.447198472341914)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.7684016890457152)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.03947238577678366) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 42.926219532252226) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0006308040185407556)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.005600374984393085)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.009553154539584056)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 111.82032873998043) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteSecretarybirdSurvey() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH167")
    let path = OriginalSecretarybirdSurveyPhysicalSource.folder.appendingPathComponent(OriginalSecretarybirdSurveyPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH166")
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalSecretarybirdSurveyPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalSecretarybirdSurveyPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalSecretarybirdSurveyPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual620FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH167", sourceFaces: 620, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH167")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH167", actualSourceFaces: 620, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH167")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH167") == nil)
    #expect(ShipCatalogue.rawMesh("SH167") == nil)
    #expect(ShipCatalogue.ship("SH167")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH167"))
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
    let engineering = try OriginalFleetPhysicalData.record(for: "SH167")
    let model = try OriginalFleetShowroomModels.model(for: "SH167")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH167"])
    #expect(finite.metresPerSourceUnit == 12500.0 / 1587.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "12500/1587")
    #expect(engineering.metresPerSourceUnitExact == "12500/1587")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH167-design.toml")
    #expect(model.sourceSHA256 == "e3f38e953673b840106430b34385a1492e18c1bb2db3250619f380da6d4fdf4b")
    #expect(model.nativeDesign.vertices.first == [0.2028, 0.0, -1.9044])
    #expect(model.nativeDesign.faces.count == 620)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH167")
    let path = OriginalSecretarybirdSurveyPhysicalSource.folder.appendingPathComponent(OriginalSecretarybirdSurveyPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalSecretarybirdSurveyPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
