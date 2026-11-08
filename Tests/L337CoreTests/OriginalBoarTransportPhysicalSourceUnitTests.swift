import Foundation
import Testing

@testable import L337Core

struct OriginalBoarTransportPhysicalSourceUnitTests {
  private func source() throws -> OriginalBoarTransportPhysicalSource {
    try #require(OriginalBoarTransportPhysicalSource.current)
  }

  @Test func currentBoarTransportHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH128")
    let model = try OriginalFleetShowroomModels.model(for: "SH128")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH128"))
    #expect(finite.emptyDry.massKg == 318064)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 620 && model.nativeDesign.vertices.count == 348)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (0.0001220708996312375)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (0.9282264850561391)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.794971001286907)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 0.9294969166865056)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.0037728255948488356) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 4.102947834398108) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-8.71515694471125e-06)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-3.587910844911309e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-3.285150159326242e-05)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 4.36532012934473) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteBoarTransport() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH128")
    let path = OriginalBoarTransportPhysicalSource.folder.appendingPathComponent(OriginalBoarTransportPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalBoarTransportPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalBoarTransportPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalBoarTransportPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH127")
    #expect(OriginalBoarTransportPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalBoarTransportPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalBoarTransportPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalBoarTransportPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual620FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH128", sourceFaces: 620, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH128")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH128", actualSourceFaces: 620, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH128")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH128") == nil)
    #expect(ShipCatalogue.rawMesh("SH128") == nil)
    #expect(ShipCatalogue.ship("SH128")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH128"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 5)
    #expect(contract.accommodation?.operatingCrew == 5)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 32)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH128")
    let model = try OriginalFleetShowroomModels.model(for: "SH128")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH128"])
    #expect(finite.metresPerSourceUnit == 19000.0 / 697.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "19000/697")
    #expect(engineering.metresPerSourceUnitExact == "19000/697")
    #expect(engineering.targetDetailedLengthMetres == 76)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH128-design.toml")
    #expect(model.sourceSHA256 == "f5b934ab51d55b29d5cdcfc112b9e5300030dbc2d9f0f33d5290562c1b2cd4aa")
    #expect(model.nativeDesign.vertices.first == [0.104, 0.3, -1.38])
    #expect(model.nativeDesign.faces.count == 620)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH128")
    let path = OriginalBoarTransportPhysicalSource.folder.appendingPathComponent(OriginalBoarTransportPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalBoarTransportPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalBoarTransportPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalBoarTransportPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
