import Foundation
import Testing

@testable import L337Core

struct OriginalFalconMkIIPhysicalSourceUnitTests {
  private func source() throws -> OriginalFalconMkIIPhysicalSource {
    try #require(OriginalFalconMkIIPhysicalSource.current)
  }

  @Test func currentFalconMkIIHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH137")
    let model = try OriginalFleetShowroomModels.model(for: "SH137")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH137"))
    #expect(finite.emptyDry.massKg == 40133)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 636 && model.nativeDesign.vertices.count == 360)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (1.7817173325015136e-06)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.7508122589631212)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.2790957531409415)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.7504085774949589)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02990058056960606) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 32.516881369446594) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.000414462842581053)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.003692626969064056)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.004928680271171603)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 73.53665565810311) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteFalconMkII() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH137")
    let path = OriginalFalconMkIIPhysicalSource.folder.appendingPathComponent(OriginalFalconMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalFalconMkIIPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalFalconMkIIPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalFalconMkIIPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH136")
    #expect(OriginalFalconMkIIPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalFalconMkIIPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalFalconMkIIPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalFalconMkIIPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual636FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH137", sourceFaces: 636, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH137")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH137", actualSourceFaces: 636, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH137")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH137") == nil)
    #expect(ShipCatalogue.rawMesh("SH137") == nil)
    #expect(ShipCatalogue.ship("SH137")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH137"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 1)
    #expect(contract.accommodation?.operatingCrew == 1)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 16)
    #expect(contract.fitting?.utilityMounts == 1)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH137")
    let model = try OriginalFleetShowroomModels.model(for: "SH137")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH137"])
    #expect(finite.metresPerSourceUnit == 15000000.0 / 1458761.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "15000000/1458761")
    #expect(engineering.metresPerSourceUnitExact == "15000000/1458761")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH137-design.toml")
    #expect(model.sourceSHA256 == "1ae68958ef5c8372692b3540b03a3ce699c8de8f247958b06e5f18d344d78137")
    #expect(model.nativeDesign.vertices.first == [0.1404, 0.24, -0.978805])
    #expect(model.nativeDesign.faces.count == 636)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH137")
    let path = OriginalFalconMkIIPhysicalSource.folder.appendingPathComponent(OriginalFalconMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalFalconMkIIPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalFalconMkIIPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalFalconMkIIPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
