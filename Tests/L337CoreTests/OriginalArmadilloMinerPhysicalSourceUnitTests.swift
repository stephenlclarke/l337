import Foundation
import Testing

@testable import L337Core

struct OriginalArmadilloMinerPhysicalSourceUnitTests {
  private func source() throws -> OriginalArmadilloMinerPhysicalSource {
    try #require(OriginalArmadilloMinerPhysicalSource.current)
  }

  @Test func currentArmadilloMinerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH168"))
    #expect(specification.name == "ArmadilloMiner")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH168")
    let model = try OriginalFleetShowroomModels.model(for: "SH168")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH168"))
    #expect(finite.emptyDry.massKg == 78039)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1452 && model.nativeDesign.vertices.count == 768)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.00014047133535866196)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (1.8943422972211252)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.667866248345238)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == 1.8999344746616678)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.015376926921154808) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 16.722408026755854) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0001688385139813721)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0005613676795467361)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0005553882944974778)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 20.74988477174878) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteArmadilloMiner() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH168")
    let path = OriginalArmadilloMinerPhysicalSource.folder.appendingPathComponent(OriginalArmadilloMinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalArmadilloMinerPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalArmadilloMinerPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalArmadilloMinerPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH167")
    #expect(OriginalArmadilloMinerPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalArmadilloMinerPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalArmadilloMinerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalArmadilloMinerPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1452FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH168", sourceFaces: 1452, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH168")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH168", actualSourceFaces: 1452, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH168")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH168") == nil)
    #expect(ShipCatalogue.rawMesh("SH168") == nil)
    #expect(ShipCatalogue.ship("SH168")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH168"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(contract.accommodation?.operatingCrew == 2)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 24)
    #expect(contract.fitting?.utilityMounts == 3)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH168")
    let model = try OriginalFleetShowroomModels.model(for: "SH168")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH168"])
    #expect(finite.metresPerSourceUnit == 46000.0 / 3083.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "46000/3083")
    #expect(engineering.metresPerSourceUnitExact == "46000/3083")
    #expect(engineering.targetDetailedLengthMetres == 46)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH168-design.toml")
    #expect(model.sourceSHA256 == "6b938c4b4879fa1e41b29fc1f1c81c5a950733937e8ad8337b5439854dca237f")
    #expect(model.nativeDesign.vertices.first == [0.29744, 0.15, -1.575])
    #expect(model.nativeDesign.faces.count == 1452)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH168")
    let path = OriginalArmadilloMinerPhysicalSource.folder.appendingPathComponent(OriginalArmadilloMinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalArmadilloMinerPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalArmadilloMinerPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalArmadilloMinerPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
