import Foundation
import Testing

@testable import L337Core

struct OriginalWolfMkIIPhysicalSourceUnitTests {
  private func source() throws -> OriginalWolfMkIIPhysicalSource {
    try #require(OriginalWolfMkIIPhysicalSource.current)
  }

  @Test func currentWolfMkIIHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH159")
    let model = try OriginalFleetShowroomModels.model(for: "SH159")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH159"))
    #expect(finite.emptyDry.massKg == 34023)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 764 && model.nativeDesign.vertices.count == 440)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.25584081025501787)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (0.5591107707732874)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-1.9267812318112958)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 0.560947787541235)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.035270258354642446) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 38.35640596067366) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0010254165868434164)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.004039958824079847)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.005061378134920621)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 80.89461844306979) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteWolfMkII() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH159")
    let path = OriginalWolfMkIIPhysicalSource.folder.appendingPathComponent(OriginalWolfMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalWolfMkIIPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalWolfMkIIPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalWolfMkIIPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH158")
    #expect(OriginalWolfMkIIPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalWolfMkIIPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalWolfMkIIPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalWolfMkIIPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual764FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH159", sourceFaces: 764, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH159")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH159", actualSourceFaces: 764, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH159")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH159") == nil)
    #expect(ShipCatalogue.rawMesh("SH159") == nil)
    #expect(ShipCatalogue.ship("SH159")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH159"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(contract.accommodation?.operatingCrew == 2)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 22)
    #expect(contract.fitting?.utilityMounts == 2)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH159")
    let model = try OriginalFleetShowroomModels.model(for: "SH159")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH159"])
    #expect(finite.metresPerSourceUnit == 1500000.0 / 182771.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "1500000/182771")
    #expect(engineering.metresPerSourceUnitExact == "1500000/182771")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH159-design.toml")
    #expect(model.sourceSHA256 == "6a683a22e7fb9238426da2f284d1eacb29bb008b4b3514208d18e666af0569eb")
    #expect(model.nativeDesign.vertices.first == [-0.819875, -0.34, -1.78904])
    #expect(model.nativeDesign.faces.count == 764)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH159")
    let path = OriginalWolfMkIIPhysicalSource.folder.appendingPathComponent(OriginalWolfMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalWolfMkIIPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalWolfMkIIPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalWolfMkIIPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
