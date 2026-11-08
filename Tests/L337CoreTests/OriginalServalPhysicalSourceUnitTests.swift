import Foundation
import Testing

@testable import L337Core

struct OriginalServalPhysicalSourceUnitTests {
  private func source() throws -> OriginalServalPhysicalSource {
    try #require(OriginalServalPhysicalSource.current)
  }

  @Test(arguments: ["short-centre", "short-tensor", "asymmetric", "nonpositive", "zero-mass", "non-finite"])
  func sharedMassRejectsMalformedValuesBeforeReadingCentreOrSolving(_ condition: String) {
    var mass = 1.0
    var centre: [Double] = [0, 0, 0]
    var inertia: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    switch condition {
    case "short-centre": centre.removeLast()
    case "short-tensor": inertia.removeLast()
    case "asymmetric": inertia[1] = 0.5
    case "nonpositive": inertia[0] = -1
    case "zero-mass": mass = 0
    default: centre[0] = .nan
    }
    let invalid = OriginalFiniteDryMass(id: "invalid-reference", massKg: mass,
      centreMetres: centre, inertiaAboutCentreOfMassKgM2: inertia)
    #expect(!invalid.valid)
    #expect(invalid.responseFromRest(impulse: .init(1, 2, 3), atLocalPoint: .init(0, 0, 0)) == nil)
  }

  @Test func currentServalHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH041")
    let contract = try #require(ShipCatalogue.ship("SH041")?.physicalSourceContract)
    #expect(contract.finiteServalDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 23775)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 224 && current.mesh.vertices.count == 128)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - 0.24448571852127368) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z + 3.811728906885495) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.2915946416655059)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.050473186119873815) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 54.88958990536278) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x + 0.0009200196960147724) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y + 0.00639829930399419) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z + 0.009251041122036091) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 117.12644198574581) < 1e-10)
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
    #expect((diagonalOnly - w).length > 1e-5)
  }

  @Test func invalidImpulseOrPointHasNoReferenceResponse() throws {
    let finite = try source()
    #expect(finite.responseFromRest(impulse: .init(.nan, 0, 0), atLocalPoint: .init(0, 0, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(1, 0, 0), atLocalPoint: .init(0, .infinity, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(.greatestFiniteMagnitude, 1, 0),
      atLocalPoint: .init(0, 10, 10)) == nil)
  }

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteServal() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH041")
    let path = OriginalServalPhysicalSource.folder.appendingPathComponent(OriginalServalPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalServalPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalServalPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalServalPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH036")
    #expect(OriginalServalPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalServalPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalServalPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalServalPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH041") == nil)
    #expect(ShipCatalogue.rawMesh("SH041") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH041", sourceFaces: 224)) {
      try OriginalDetailedHullStage.requireRuntime("SH041")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH041")
    #expect(current.contract.accommodation?.operatingCrew == 1)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 18)
  }
}
