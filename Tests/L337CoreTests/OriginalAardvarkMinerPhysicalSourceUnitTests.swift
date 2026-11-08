import Foundation
import Testing

@testable import L337Core

struct OriginalAardvarkMinerPhysicalSourceUnitTests {
  private func source() throws -> OriginalAardvarkMinerPhysicalSource {
    try #require(OriginalAardvarkMinerPhysicalSource.current)
  }

  @Test func currentAardvarkMinerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH143")
    let model = try OriginalFleetShowroomModels.model(for: "SH143")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH143"))
    #expect(finite.emptyDry.massKg == 50705)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1112 && model.nativeDesign.vertices.count == 624)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (9.94493384642264e-05)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.9718307848413351)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.4107131983746446)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.9693730187752888)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.023666305098116555) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 25.73710679420175) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0001642013073186012)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0016762159745448211)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.00406712186796001)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 51.04013793273437) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteAardvarkMiner() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH143")
    let path = OriginalAardvarkMinerPhysicalSource.folder.appendingPathComponent(OriginalAardvarkMinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalAardvarkMinerPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalAardvarkMinerPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalAardvarkMinerPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH142")
    #expect(OriginalAardvarkMinerPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalAardvarkMinerPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalAardvarkMinerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalAardvarkMinerPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1112FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH143", sourceFaces: 1112, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH143")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH143", actualSourceFaces: 1112, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH143")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH143") == nil)
    #expect(ShipCatalogue.rawMesh("SH143") == nil)
    #expect(ShipCatalogue.ship("SH143")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH143"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 4)
    #expect(contract.accommodation?.operatingCrew == 4)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 34)
    #expect(contract.fitting?.utilityMounts == 4)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH143")
    let model = try OriginalFleetShowroomModels.model(for: "SH143")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH143"])
    #expect(finite.metresPerSourceUnit == 4600.0 / 481.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "4600/481")
    #expect(engineering.metresPerSourceUnitExact == "4600/481")
    #expect(engineering.targetDetailedLengthMetres == 46)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH143-design.toml")
    #expect(model.sourceSHA256 == "68f8b505e2c51ad34b2ff4a1fc7bb49c55903b58694e2ad353ddbc4728359341")
    #expect(model.nativeDesign.vertices.first == [0.22984, 0.15, -2.07])
    #expect(model.nativeDesign.faces.count == 1112)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH143")
    let path = OriginalAardvarkMinerPhysicalSource.folder.appendingPathComponent(OriginalAardvarkMinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalAardvarkMinerPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalAardvarkMinerPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalAardvarkMinerPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
