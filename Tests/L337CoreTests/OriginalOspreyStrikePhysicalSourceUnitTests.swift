import Foundation
import Testing

@testable import L337Core

struct OriginalOspreyStrikePhysicalSourceUnitTests {
  private func source() throws -> OriginalOspreyStrikePhysicalSource {
    try #require(OriginalOspreyStrikePhysicalSource.current)
  }

  @Test func currentOspreyStrikeHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH153")
    let model = try OriginalFleetShowroomModels.model(for: "SH153")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH153"))
    #expect(finite.emptyDry.massKg == 29110)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1384 && model.nativeDesign.vertices.count == 752)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.34283870318705845)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.1143917622464716)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.6512028716265665)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.1307032083655069)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.041222947440742015) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 44.82995534180694) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0010658741018032992)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.004080065401483867)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.003968181960705937)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 79.13073981966633) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteOspreyStrike() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH153")
    let path = OriginalOspreyStrikePhysicalSource.folder.appendingPathComponent(OriginalOspreyStrikePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalOspreyStrikePhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalOspreyStrikePhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalOspreyStrikePhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH152")
    #expect(OriginalOspreyStrikePhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalOspreyStrikePhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalOspreyStrikePhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalOspreyStrikePhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1384FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH153", sourceFaces: 1384, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH153")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH153", actualSourceFaces: 1384, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH153")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH153") == nil)
    #expect(ShipCatalogue.rawMesh("SH153") == nil)
    #expect(ShipCatalogue.ship("SH153")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH153"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 1)
    #expect(contract.accommodation?.operatingCrew == 1)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 18)
    #expect(contract.fitting?.utilityMounts == 1)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH153")
    let model = try OriginalFleetShowroomModels.model(for: "SH153")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH153"])
    #expect(finite.metresPerSourceUnit == 750000.0 / 95803.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "750000/95803")
    #expect(engineering.metresPerSourceUnitExact == "750000/95803")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH153-design.toml")
    #expect(model.sourceSHA256 == "9ccb8ce4115e6f93a7fa06618e6ca2c001761b6d3135fbca477e7d1acb6be085")
    #expect(model.nativeDesign.vertices.first == [-0.8856, 0.1, -1.91606])
    #expect(model.nativeDesign.faces.count == 1384)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH153")
    let path = OriginalOspreyStrikePhysicalSource.folder.appendingPathComponent(OriginalOspreyStrikePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalOspreyStrikePhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalOspreyStrikePhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalOspreyStrikePhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
