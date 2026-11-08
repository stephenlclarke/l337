import Foundation
import Testing

@testable import L337Core

struct OriginalReindeerFreighterPhysicalSourceUnitTests {
  private func source() throws -> OriginalReindeerFreighterPhysicalSource {
    try #require(OriginalReindeerFreighterPhysicalSource.current)
  }

  @Test func currentReindeerFreighterHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH150")
    let model = try OriginalFleetShowroomModels.model(for: "SH150")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH150"))
    #expect(finite.emptyDry.massKg == 500446)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1052 && model.nativeDesign.vertices.count == 624)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (0.00019412238304488143)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.16702879541887)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.967068629884141)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.1670051208776957)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.0023978611078917605) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 2.6076739548322894) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-3.6860390302550758e-06)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-1.654913314406534e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-1.8961369095130256e-05)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 2.733566357356487) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteReindeerFreighter() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH150")
    let path = OriginalReindeerFreighterPhysicalSource.folder.appendingPathComponent(OriginalReindeerFreighterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalReindeerFreighterPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalReindeerFreighterPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalReindeerFreighterPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH149")
    #expect(OriginalReindeerFreighterPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalReindeerFreighterPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalReindeerFreighterPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalReindeerFreighterPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1052FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH150", sourceFaces: 1052, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH150")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH150", actualSourceFaces: 1052, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH150")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH150") == nil)
    #expect(ShipCatalogue.rawMesh("SH150") == nil)
    #expect(ShipCatalogue.ship("SH150")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH150"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 8)
    #expect(contract.accommodation?.operatingCrew == 8)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 40)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH150")
    let model = try OriginalFleetShowroomModels.model(for: "SH150")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH150"])
    #expect(finite.metresPerSourceUnit == 1375.0 / 46.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "1375/46")
    #expect(engineering.metresPerSourceUnitExact == "1375/46")
    #expect(engineering.targetDetailedLengthMetres == 110)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH150-design.toml")
    #expect(model.sourceSHA256 == "06cbe5e88f8d62e9f65b09c5cb74ba85b7d84ee183ceed0f40f6a8f3a1542f34")
    #expect(model.nativeDesign.vertices.first == [0.104, 0.3, -1.84])
    #expect(model.nativeDesign.faces.count == 1052)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH150")
    let path = OriginalReindeerFreighterPhysicalSource.folder.appendingPathComponent(OriginalReindeerFreighterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalReindeerFreighterPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalReindeerFreighterPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalReindeerFreighterPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
