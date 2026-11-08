import Foundation
import Testing

@testable import L337Core

struct OriginalTapirShuttlePhysicalSourceUnitTests {
  private func source() throws -> OriginalTapirShuttlePhysicalSource {
    try #require(OriginalTapirShuttlePhysicalSource.current)
  }

  @Test func currentTapirShuttleHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH105")
    let model = try OriginalFleetShowroomModels.model(for: "SH105")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH105"))
    #expect(finite.emptyDry.massKg == 209283)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 908 && model.nativeDesign.vertices.count == 480)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.02170028987792235)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.8465352046118607)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-6.150512462375381)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.9583331646781225)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.00573386275999484) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 6.235575751494388) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (1.1269047000390332e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-7.786527603860655e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-8.74748861948672e-05)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 6.870254965794563) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteTapirShuttle() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH105")
    let path = OriginalTapirShuttlePhysicalSource.folder.appendingPathComponent(OriginalTapirShuttlePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalTapirShuttlePhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalTapirShuttlePhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalTapirShuttlePhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH098")
    #expect(OriginalTapirShuttlePhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalTapirShuttlePhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalTapirShuttlePhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalTapirShuttlePhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual908FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH105", sourceFaces: 908, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH105")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH105", actualSourceFaces: 908, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH105")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH105") == nil)
    #expect(ShipCatalogue.rawMesh("SH105") == nil)
    #expect(ShipCatalogue.ship("SH105")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH105"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 5)
    #expect(contract.accommodation?.operatingCrew == 5)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 38)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH105")
    let model = try OriginalFleetShowroomModels.model(for: "SH105")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH105"])
    #expect(finite.metresPerSourceUnit == 1900.0 / 61.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "1900/61")
    #expect(engineering.metresPerSourceUnitExact == "1900/61")
    #expect(engineering.targetDetailedLengthMetres == 76)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH105-design.toml")
    #expect(model.sourceSHA256 == "daf3fa9551a9f488edbcfd5ee164507616cf120b43f912c07171a3ddead2d96e")
    #expect(model.nativeDesign.vertices.first == [1.004, 0.16, 0.0])
    #expect(model.nativeDesign.faces.count == 908)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH105")
    let path = OriginalTapirShuttlePhysicalSource.folder.appendingPathComponent(OriginalTapirShuttlePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalTapirShuttlePhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalTapirShuttlePhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalTapirShuttlePhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
