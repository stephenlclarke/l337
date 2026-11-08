import Foundation
import Testing

@testable import L337Core

struct OriginalWildebeestPhysicalSourceUnitTests {
  private func source() throws -> OriginalWildebeestPhysicalSource {
    try #require(OriginalWildebeestPhysicalSource.current)
  }

  @Test func currentWildebeestHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH104")
    #expect(finite.emptyDry.massKg == 98146)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 424 && current.mesh.vertices.count == 244)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (-0.27522570813010605)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-1.488429340444259)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -0.2748153388412199)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.012226682697206203) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 13.296517433211747) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.00012621156375106988)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0004831563279547302)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0004418729777471034)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 18.16849865535159) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteWildebeest() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH104")
    let path = OriginalWildebeestPhysicalSource.folder.appendingPathComponent(OriginalWildebeestPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalWildebeestPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalWildebeestPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalWildebeestPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH144")
    #expect(OriginalWildebeestPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalWildebeestPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalWildebeestPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalWildebeestPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH104") == nil)
    #expect(ShipCatalogue.rawMesh("SH104") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH104", sourceFaces: 424)) {
      try OriginalDetailedHullStage.requireRuntime("SH104")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH104")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(current.contract.accommodation?.operatingCrew == 3)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 26)
  }

  @Test func supportedRelativeSourceKeepsCalibrationAndOriginalCoordinates() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH104")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH104"])
    #expect(finite.metresPerSourceUnit == 10000.0 / 667.0)
    #expect(registration.calibration.exactScale == "10000/667")
    #expect(current.engineering.metresPerSourceUnitExact == "10000/667")
    #expect(current.engineering.targetDetailedLengthMetres == 40)
    #expect(current.model.coordinateUnits == nil)
    #expect(current.mesh.vertices == current.model.nativeDesign.rawMesh.vertices.map {
      $0 * current.engineering.metresPerSourceUnit
    })
    #expect(current.mesh.faces == current.model.nativeDesign.rawMesh.faces)
    #expect(current.contract.fitting?.utilityMounts == 4)
  }

  @Test func copiedProvenanceCannotConstructChangedCanonicalGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH104")
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH104")) {
      try OriginalFleetCurrentHullSource(id: "SH104", model: wrongUnits)
    }
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
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH104")) {
      try OriginalFleetCurrentHullSource(id: "SH104", model: wrongGeometry)
    }
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
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH104")) {
      try OriginalFleetCurrentHullSource(id: "SH104", model: wrongAppearance)
    }
  }
}
