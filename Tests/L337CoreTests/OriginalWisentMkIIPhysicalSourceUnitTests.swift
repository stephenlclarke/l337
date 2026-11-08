import Foundation
import Testing

@testable import L337Core

struct OriginalWisentMkIIPhysicalSourceUnitTests {
  private func source() throws -> OriginalWisentMkIIPhysicalSource {
    try #require(OriginalWisentMkIIPhysicalSource.current)
  }

  @Test func currentWisentMkIIHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH097")
    let model = try OriginalFleetShowroomModels.model(for: "SH097")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH097"))
    #expect(finite.emptyDry.massKg == 220975)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 816 && model.nativeDesign.vertices.count == 460)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.12369375942558755)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-1.9531475291268456)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-0.5161337972377449)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -1.952743034878037)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.005430478560923181) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 5.905645435003959) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-1.1639345867307818e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-9.430354539695496e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.00012507587370525958)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 7.150874886690125) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteWisentMkII() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH097")
    let path = OriginalWisentMkIIPhysicalSource.folder.appendingPathComponent(OriginalWisentMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalWisentMkIIPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalWisentMkIIPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalWisentMkIIPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH096")
    #expect(OriginalWisentMkIIPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalWisentMkIIPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalWisentMkIIPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalWisentMkIIPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual816FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH097", sourceFaces: 816, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH097")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH097", actualSourceFaces: 816, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH097")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH097") == nil)
    #expect(ShipCatalogue.rawMesh("SH097") == nil)
    #expect(ShipCatalogue.ship("SH097")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH097"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 4)
    #expect(contract.accommodation?.operatingCrew == 4)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 30)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH097")
    let model = try OriginalFleetShowroomModels.model(for: "SH097")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH097"])
    #expect(finite.metresPerSourceUnit == 30400.0 / 1863.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "30400/1863")
    #expect(engineering.metresPerSourceUnitExact == "30400/1863")
    #expect(engineering.targetDetailedLengthMetres == 76)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH097-design.toml")
    #expect(model.sourceSHA256 == "c5bff7a81f87ad4b6ad0a05ba8e689fc1114f1812e6e85461b09a4c15aac2b0a")
    #expect(model.nativeDesign.vertices.first == [-0.580232, -0.2, -2.32875])
    #expect(model.nativeDesign.faces.count == 816)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH097")
    let path = OriginalWisentMkIIPhysicalSource.folder.appendingPathComponent(OriginalWisentMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalWisentMkIIPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalWisentMkIIPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalWisentMkIIPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
