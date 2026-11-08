import Foundation
import Testing

@testable import L337Core

struct OriginalLammergeierPhysicalSourceUnitTests {
  private func source() throws -> OriginalLammergeierPhysicalSource {
    try #require(OriginalLammergeierPhysicalSource.current)
  }

  @Test func currentLammergeierHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH163"))
    #expect(specification.name == "Lammergeier")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH163")
    let model = try OriginalFleetShowroomModels.model(for: "SH163")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH163"))
    #expect(finite.emptyDry.massKg == 17513)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 620 && model.nativeDesign.vertices.count == 352)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (0.00011265542313353317)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.06934121724870057)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.5234790416302566)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.06577243089367092)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.06852052760806258) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 74.51607377376807) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0010781404431505926)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.009151468521995592)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.026685623528833285)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 208.32192501107676) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteLammergeier() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH163")
    let path = OriginalLammergeierPhysicalSource.folder.appendingPathComponent(OriginalLammergeierPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalLammergeierPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalLammergeierPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalLammergeierPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH160")
    #expect(OriginalLammergeierPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalLammergeierPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalLammergeierPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalLammergeierPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual620FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH163", sourceFaces: 620, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH163")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH163", actualSourceFaces: 620, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH163")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH163") == nil)
    #expect(ShipCatalogue.rawMesh("SH163") == nil)
    #expect(ShipCatalogue.ship("SH163")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH163"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(contract.accommodation?.operatingCrew == 3)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 28)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH163")
    let model = try OriginalFleetShowroomModels.model(for: "SH163")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH163"])
    #expect(finite.metresPerSourceUnit == 300.0 / 43.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "300/43")
    #expect(engineering.metresPerSourceUnitExact == "300/43")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH163-design.toml")
    #expect(model.sourceSHA256 == "35c56db12a269759f3c87d95be388022146d95bfa4f8b8e4e09a4214cc84c9cc")
    #expect(model.nativeDesign.vertices.first == [0.1768, 0.0, -2.15])
    #expect(model.nativeDesign.faces.count == 620)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH163")
    let path = OriginalLammergeierPhysicalSource.folder.appendingPathComponent(OriginalLammergeierPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalLammergeierPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalLammergeierPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalLammergeierPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
