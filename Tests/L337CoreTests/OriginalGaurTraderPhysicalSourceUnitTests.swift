import Foundation
import Testing

@testable import L337Core

struct OriginalGaurTraderPhysicalSourceUnitTests {
  private func source() throws -> OriginalGaurTraderPhysicalSource {
    try #require(OriginalGaurTraderPhysicalSource.current)
  }

  @Test func currentGaurTraderHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH127")
    let model = try OriginalFleetShowroomModels.model(for: "SH127")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH127"))
    #expect(finite.emptyDry.massKg == 55112)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 2188 && model.nativeDesign.vertices.count == 1216)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.00029478484395201724)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (0.08150150679021777)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.359525404390644)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 0.08289354304775337)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02177384235738133) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 23.679053563652197) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0003260427601126443)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0016483445672507968)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0027533864840767414)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 42.647669719128075) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteGaurTrader() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH127")
    let path = OriginalGaurTraderPhysicalSource.folder.appendingPathComponent(OriginalGaurTraderPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalGaurTraderPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalGaurTraderPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalGaurTraderPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH107")
    #expect(OriginalGaurTraderPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalGaurTraderPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalGaurTraderPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalGaurTraderPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual2188FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH127", sourceFaces: 2188, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH127")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH127", actualSourceFaces: 2188, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH127")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH127") == nil)
    #expect(ShipCatalogue.rawMesh("SH127") == nil)
    #expect(ShipCatalogue.ship("SH127")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH127"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(contract.accommodation?.operatingCrew == 3)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 26)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH127")
    let model = try OriginalFleetShowroomModels.model(for: "SH127")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH127"])
    #expect(finite.metresPerSourceUnit == 625.0 / 69.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "625/69")
    #expect(engineering.metresPerSourceUnitExact == "625/69")
    #expect(engineering.targetDetailedLengthMetres == 40)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH127-design.toml")
    #expect(model.sourceSHA256 == "33a5a9a095e417a76cdc2e55b73fc9819aa1b7390cfdee36d28661ff89bf6c70")
    #expect(model.nativeDesign.vertices.first == [0.104, 0.3, -2.208])
    #expect(model.nativeDesign.faces.count == 2188)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH127")
    let path = OriginalGaurTraderPhysicalSource.folder.appendingPathComponent(OriginalGaurTraderPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalGaurTraderPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalGaurTraderPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalGaurTraderPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
