import Foundation
import Testing

@testable import L337Core

struct OriginalLynxEscortPhysicalSourceUnitTests {
  private func source() throws -> OriginalLynxEscortPhysicalSource {
    try #require(OriginalLynxEscortPhysicalSource.current)
  }

  @Test func currentLynxEscortHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH151")
    let model = try OriginalFleetShowroomModels.model(for: "SH151")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH151"))
    #expect(finite.emptyDry.massKg == 50393)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 988 && model.nativeDesign.vertices.count == 552)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-3.966833043486268e-06)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.19614047713110322)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.9688327413682543)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.19490020707580863)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02381283114718314) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 25.896453872561665) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0005406155139334325)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.001914352715313142)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0015170440789583478)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 42.510838972668154) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteLynxEscort() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH151")
    let path = OriginalLynxEscortPhysicalSource.folder.appendingPathComponent(OriginalLynxEscortPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalLynxEscortPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalLynxEscortPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalLynxEscortPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH150")
    #expect(OriginalLynxEscortPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalLynxEscortPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalLynxEscortPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalLynxEscortPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual988FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH151", sourceFaces: 988, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH151")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH151", actualSourceFaces: 988, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH151")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH151") == nil)
    #expect(ShipCatalogue.rawMesh("SH151") == nil)
    #expect(ShipCatalogue.ship("SH151")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH151"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(contract.accommodation?.operatingCrew == 2)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 22)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH151")
    let model = try OriginalFleetShowroomModels.model(for: "SH151")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH151"])
    #expect(finite.metresPerSourceUnit == 30000.0 / 2521.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "30000/2521")
    #expect(engineering.metresPerSourceUnitExact == "30000/2521")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH151-design.toml")
    #expect(model.sourceSHA256 == "a568ebe3e5acd9833c743c5c325581ddfaa436a6e4be491887779b22b814681e")
    #expect(model.nativeDesign.vertices.first == [0.2028, 0.0, -1.242])
    #expect(model.nativeDesign.faces.count == 988)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH151")
    let path = OriginalLynxEscortPhysicalSource.folder.appendingPathComponent(OriginalLynxEscortPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalLynxEscortPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalLynxEscortPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalLynxEscortPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
