import Foundation
import Testing

@testable import L337Core

struct OriginalRhinocerosTraderPhysicalSourceUnitTests {
  private func source() throws -> OriginalRhinocerosTraderPhysicalSource {
    try #require(OriginalRhinocerosTraderPhysicalSource.current)
  }

  @Test func currentRhinocerosTraderHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH067")
    #expect(finite.emptyDry.massKg == 61087)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 388 && current.mesh.vertices.count == 220)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (-0.3135693082184946)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.664103778607366)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -0.3126381439368439)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.01964411413230311) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 21.36297411887963) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-2.519623493011849e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0007562766161812471)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0012790800054787177)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 29.226171393682833) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteRhinocerosTrader() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH067")
    let path = OriginalRhinocerosTraderPhysicalSource.folder.appendingPathComponent(OriginalRhinocerosTraderPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalRhinocerosTraderPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalRhinocerosTraderPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalRhinocerosTraderPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH144")
    #expect(OriginalRhinocerosTraderPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalRhinocerosTraderPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalRhinocerosTraderPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalRhinocerosTraderPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH067") == nil)
    #expect(ShipCatalogue.rawMesh("SH067") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH067", sourceFaces: 388)) {
      try OriginalDetailedHullStage.requireRuntime("SH067")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH067")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(current.contract.accommodation?.operatingCrew == 3)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 24)
  }

  @Test func supportedRelativeSourceKeepsCalibrationAndOriginalCoordinates() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH067")
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH067"])
    #expect(finite.metresPerSourceUnit == 40000.0 / 3263.0)
    #expect(registration.calibration.exactScale == "40000/3263")
    #expect(current.engineering.metresPerSourceUnitExact == "40000/3263")
    #expect(current.engineering.targetDetailedLengthMetres == 40)
    #expect(current.model.coordinateUnits == nil)
    #expect(current.mesh.vertices == current.model.nativeDesign.rawMesh.vertices.map {
      $0 * current.engineering.metresPerSourceUnit
    })
    #expect(current.mesh.faces == current.model.nativeDesign.rawMesh.faces)
    #expect(current.contract.fitting?.utilityMounts == 2)
  }

  @Test func copiedProvenanceCannotConstructChangedCanonicalGeometryAppearanceOrUnits() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH067")
    let wrongUnits = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
      sourceSHA256: model.sourceSHA256, coordinateUnits: "metres", nativeDesign: model.nativeDesign)
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH067")) {
      try OriginalFleetCurrentHullSource(id: "SH067", model: wrongUnits)
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
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH067")) {
      try OriginalFleetCurrentHullSource(id: "SH067", model: wrongGeometry)
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
    #expect(throws: OriginalFleetCurrentHullSource.Failure.inconsistentNativeSource("SH067")) {
      try OriginalFleetCurrentHullSource(id: "SH067", model: wrongAppearance)
    }
  }
}
