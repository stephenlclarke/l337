import Foundation
import Testing

@testable import L337Core

struct OriginalOspreySupportPhysicalSourceUnitTests {
  private func source() throws -> OriginalOspreySupportPhysicalSource {
    try #require(OriginalOspreySupportPhysicalSource.current)
  }

  @Test func currentOspreySupportHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH155")
    let model = try OriginalFleetShowroomModels.model(for: "SH155")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH155"))
    #expect(finite.emptyDry.massKg == 27661)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1384 && model.nativeDesign.vertices.count == 752)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.5044885249010047)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.1431560509401486)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.5586601516031333)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.153847644838467)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.04338237952351687) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 47.17833773182459) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0010641266997029424)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.004375345212914125)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.004364913506171488)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 84.88574709423526) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteOspreySupport() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH155")
    let path = OriginalOspreySupportPhysicalSource.folder.appendingPathComponent(OriginalOspreySupportPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalOspreySupportPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalOspreySupportPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalOspreySupportPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH154")
    #expect(OriginalOspreySupportPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalOspreySupportPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalOspreySupportPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalOspreySupportPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1384FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH155", sourceFaces: 1384, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH155")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH155", actualSourceFaces: 1384, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH155")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH155") == nil)
    #expect(ShipCatalogue.rawMesh("SH155") == nil)
    #expect(ShipCatalogue.ship("SH155")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH155"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 6)
    #expect(contract.accommodation?.operatingCrew == 6)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 34)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH155")
    let model = try OriginalFleetShowroomModels.model(for: "SH155")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH155"])
    #expect(finite.metresPerSourceUnit == 750000.0 / 101809.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "750000/101809")
    #expect(engineering.metresPerSourceUnitExact == "750000/101809")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH155-design.toml")
    #expect(model.sourceSHA256 == "63ddbc6a3f6e21dbd1641b8fd703297bfac0403e724b4926be46f2e57346fddb")
    #expect(model.nativeDesign.vertices.first == [-0.9288, 0.1, -2.03618])
    #expect(model.nativeDesign.faces.count == 1384)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH155")
    let path = OriginalOspreySupportPhysicalSource.folder.appendingPathComponent(OriginalOspreySupportPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalOspreySupportPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalOspreySupportPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalOspreySupportPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
