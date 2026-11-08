import Foundation
import Testing

@testable import L337Core

struct OriginalSeriemaCourierPhysicalSourceUnitTests {
  private func source() throws -> OriginalSeriemaCourierPhysicalSource {
    try #require(OriginalSeriemaCourierPhysicalSource.current)
  }

  @Test func currentSeriemaCourierHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH063")
    let model = try OriginalFleetShowroomModels.model(for: "SH063")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH063"))
    #expect(finite.emptyDry.massKg == 14539)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 608 && model.nativeDesign.vertices.count == 344)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (0.0001236276205539275)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.8247760338022205)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.391560842372961)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.8209930663848787)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.08253662562762226) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 89.75858037003921) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0005966177063443191)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.01014289575534811)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.07120394546424366)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 397.2339797903911) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteSeriemaCourier() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH063")
    let path = OriginalSeriemaCourierPhysicalSource.folder.appendingPathComponent(OriginalSeriemaCourierPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalSeriemaCourierPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalSeriemaCourierPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalSeriemaCourierPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH060")
    #expect(OriginalSeriemaCourierPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalSeriemaCourierPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalSeriemaCourierPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalSeriemaCourierPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual608FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH063", sourceFaces: 608, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH063")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH063", actualSourceFaces: 608, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH063")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH063") == nil)
    #expect(ShipCatalogue.rawMesh("SH063") == nil)
    #expect(ShipCatalogue.ship("SH063")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH063"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 1)
    #expect(contract.accommodation?.operatingCrew == 1)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 20)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH063")
    let model = try OriginalFleetShowroomModels.model(for: "SH063")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH063"])
    #expect(finite.metresPerSourceUnit == 75.0 / 11.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "75/11")
    #expect(engineering.metresPerSourceUnitExact == "75/11")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH063-design.toml")
    #expect(model.sourceSHA256 == "557e9ad9e2a496ee0f29ae34b5db40a05ceddd7e8f8ed5ddf9a7ee0b78edc722")
    #expect(model.nativeDesign.vertices.first == [0.13, 0.0, -2.2])
    #expect(model.nativeDesign.faces.count == 608)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH063")
    let path = OriginalSeriemaCourierPhysicalSource.folder.appendingPathComponent(OriginalSeriemaCourierPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalSeriemaCourierPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalSeriemaCourierPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalSeriemaCourierPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
