import Foundation
import Testing

@testable import L337Core

struct OriginalCaracaraMkIIPhysicalSourceUnitTests {
  private func source() throws -> OriginalCaracaraMkIIPhysicalSource {
    try #require(OriginalCaracaraMkIIPhysicalSource.current)
  }

  @Test func currentCaracaraMkIIHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let specification = try #require(OriginalFleetR3Data.contract(for: "SH170"))
    #expect(specification.name == "CaracaraMkII")
    let engineering = try OriginalFleetPhysicalData.record(for: "SH170")
    let model = try OriginalFleetShowroomModels.model(for: "SH170")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH170"))
    #expect(finite.emptyDry.massKg == 39242)
    #expect(finite.emptyDry.massKg == Double(engineering.dryMassKilograms))
    #expect(finite.nativeTriangles == 1364 && model.nativeDesign.vertices.count == 720)
    #expect(finite.specificationSHA256 == contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (1.1228094615796658e-05)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (-0.32333995868477367)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.402346891009327)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2 != engineering.inertiaAboutCentreOfMassKgM2)
    #expect(engineering.centreOfMassMetres[1] == -0.32174726233764683)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.03057948116813618) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 33.2551857703481) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0006367768281140172)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0039438065404249585)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.00396018863744967)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 71.48016813074594) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteCaracaraMkII() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH170")
    let path = OriginalCaracaraMkIIPhysicalSource.folder.appendingPathComponent(OriginalCaracaraMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(data, model: model) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(changed, model: model) == nil)
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(Data(), model: model) == nil)
    let foreign = try OriginalFleetShowroomModels.model(for: "SH169")
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(data, model: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalCaracaraMkIIPhysicalSource.load(from: root, model: model) == nil)
    let file = root.appendingPathComponent(OriginalCaracaraMkIIPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalCaracaraMkIIPhysicalSource.load(from: root, model: model) == nil)
  }

  @Test func finiteDrySourcePreservesBothActual1364FaceRefusalsAndNoActorAuthority() throws {
    _ = try source()
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH170", sourceFaces: 1364, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH170")
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: "SH170", actualSourceFaces: 1364, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime("SH170")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH170") == nil)
    #expect(ShipCatalogue.rawMesh("SH170") == nil)
    #expect(ShipCatalogue.ship("SH170")?.physicalSourceContract == nil)
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH170"))
    #expect(contract.playerFlyable && contract.purchasePolicy == .blueprintFabrication)
    #expect(contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(contract.accommodation?.operatingCrew == 2)
    #expect(contract.accommodation?.nativeAutonomous == false)
    #expect(contract.fitting?.roleKitIncluded == false)
    #expect(contract.fitting?.equipmentUnits == 22)
    #expect(contract.fitting?.utilityMounts == 2)
  }

  @Test func originalRelativeCalibrationIsPreservedWithoutNormalisationOrTargetRefit() throws {
    let finite = try source()
    let engineering = try OriginalFleetPhysicalData.record(for: "SH170")
    let model = try OriginalFleetShowroomModels.model(for: "SH170")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH170"])
    #expect(finite.metresPerSourceUnit == 600000.0 / 57629.0)
    #expect(finite.metresPerSourceUnit == engineering.metresPerSourceUnit)
    #expect(registration.calibration.exactScale == "600000/57629")
    #expect(engineering.metresPerSourceUnitExact == "600000/57629")
    #expect(engineering.targetDetailedLengthMetres == 30)
    #expect(model.coordinateUnits == nil)
    #expect(model.sourcePath == "replacement-hulls/SH170-design.toml")
    #expect(model.sourceSHA256 == "db011887f67e1ae1c5f235fe2b7c4db4a65b29b37906a830433d69d9c8a5527b")
    #expect(model.nativeDesign.vertices.first == [0.2028, 0.0, -1.4283])
    #expect(model.nativeDesign.faces.count == 1364)
  }

  @Test func copiedProvenanceCannotAuthenticateChangedGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH170")
    let path = OriginalCaracaraMkIIPhysicalSource.folder.appendingPathComponent(OriginalCaracaraMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(data, model: wrongUnits) == nil)
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
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(data, model: wrongGeometry) == nil)
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
    #expect(OriginalCaracaraMkIIPhysicalSource.decode(data, model: wrongAppearance) == nil)
  }
}
