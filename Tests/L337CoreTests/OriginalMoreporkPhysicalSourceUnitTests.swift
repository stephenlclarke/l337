import Foundation
import Testing

@testable import L337Core

struct OriginalMoreporkPhysicalSourceUnitTests {
  private func source() throws -> OriginalMoreporkPhysicalSource {
    try #require(OriginalMoreporkPhysicalSource.current)
  }

  @Test func currentMoreporkHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH148")
    let model = try OriginalFleetShowroomModels.model(for: "SH148")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH148"))
    #expect(finite.emptyDry.massKg == 52211)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 792 && model.nativeDesign.vertices.count == 444)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.0003536651669148569)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.8073553255135242)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.3303291537890747)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.8085523982554916)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02298366244661087) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 24.994732910689315) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0011526436025275678)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.002181312375108296)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0011304680416741758)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 43.15854740004468) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteMorepork() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH148")
    let path = OriginalMoreporkPhysicalSource.folder.appendingPathComponent(OriginalMoreporkPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalMoreporkPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalMoreporkPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalMoreporkPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH143")
    #expect(OriginalMoreporkPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalMoreporkPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalMoreporkPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalMoreporkPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual792FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH148", sourceFaces: 792, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH148")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH148", actualSourceFaces: 792, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH148")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH148") == nil)
    #expect(ShipCatalogue.rawMesh("SH148") == nil)
    #expect(ShipCatalogue.ship("SH148")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH148"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(contract.accommodation?.operatingCrew == 2)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 20)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH148")
    let model = try OriginalFleetShowroomModels.model(for: "SH148")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH148"])
    #expect(finite.metresPerSourceUnit == 30000.0 / 2521.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "30000/2521")
    #expect(engineering.metresPerSourceUnitExact == "30000/2521")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH148-design.toml")
    #expect(model.sourceSHA256 == "c662ad791478a0709e2e136bcb70e3292665d48ac52d06c67e13a20d07879ecc")
    #expect(model.nativeDesign.vertices.first == [0.2028, 0.0, -1.242])
    #expect(model.nativeDesign.faces.count == 792)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH148")
    let path = OriginalMoreporkPhysicalSource.folder.appendingPathComponent(OriginalMoreporkPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalMoreporkPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalMoreporkPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalMoreporkPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
