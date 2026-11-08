import Foundation
import Testing

@testable import L337Core

struct OriginalCamelRescuePhysicalSourceUnitTests {
  private func source() throws -> OriginalCamelRescuePhysicalSource {
    try #require(OriginalCamelRescuePhysicalSource.current)
  }

  @Test func currentCamelRescueHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH166"))
    #expect(specification.name == "CamelRescue")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH166")
    let model = try OriginalFleetShowroomModels.model(for: "SH166")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH166"))
    #expect(finite.emptyDry.massKg == 264817)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 988 && model.nativeDesign.vertices.count == 552)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.20142049653092997)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.7771975238118831)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-6.186535136408919)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.776939845353517)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.00453143113923955) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 4.927931363923011) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (1.0136491811062528e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-4.4614966717030506e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-7.473594260746784e-05)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 5.383572164161165) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteCamelRescue() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH166")
    let path = OriginalCamelRescuePhysicalSource.folder.appendingPathComponent(OriginalCamelRescuePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalCamelRescuePhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalCamelRescuePhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalCamelRescuePhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH165")
    #expect(OriginalCamelRescuePhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalCamelRescuePhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalCamelRescuePhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalCamelRescuePhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual988FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH166", sourceFaces: 988, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH166")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH166", actualSourceFaces: 988, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH166")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH166") == nil)
    #expect(ShipCatalogue.rawMesh("SH166") == nil)
    #expect(ShipCatalogue.ship("SH166")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH166"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 8)
    #expect(contract.accommodation?.operatingCrew == 8)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 46)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH166")
    let model = try OriginalFleetShowroomModels.model(for: "SH166")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH166"])
    #expect(finite.metresPerSourceUnit == 9500.0 / 341.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "9500/341")
    #expect(engineering.metresPerSourceUnitExact == "9500/341")
    #expect(engineering.targetDetailedLengthMetres == 76)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH166-design.toml")
    #expect(model.sourceSHA256 == "5d782369e19a839d28bce557aa327701b0d9904e6381880fbabe9cf161f56db4")
    #expect(model.nativeDesign.vertices.first == [-0.7464, -0.1, -1.271])
    #expect(model.nativeDesign.faces.count == 988)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH166")
    let path = OriginalCamelRescuePhysicalSource.folder.appendingPathComponent(OriginalCamelRescuePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalCamelRescuePhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalCamelRescuePhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalCamelRescuePhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
