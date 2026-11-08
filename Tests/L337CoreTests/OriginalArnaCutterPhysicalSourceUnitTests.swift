import Foundation
import Testing

@testable import L337Core

struct OriginalArnaCutterPhysicalSourceUnitTests {
  private func source() throws -> OriginalArnaCutterPhysicalSource {
    try #require(OriginalArnaCutterPhysicalSource.current)
  }

  @Test func currentArnaCutterHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH064")
    let contract = try #require(ShipCatalogue.ship("SH064")?.physicalSourceContract)
    #expect(contract.finiteArnaCutterDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 137251)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 184 && current.mesh.vertices.count == 112)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (-1.13927326002517)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-4.43677673029896)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -1.138836103421676)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.008743105696861953) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 9.508127445337374) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (1.1015868129974463e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.00020484565217576144)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0004490308141081862)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 12.21677844017042) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteArnaCutter() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH064")
    let path = OriginalArnaCutterPhysicalSource.folder.appendingPathComponent(OriginalArnaCutterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalArnaCutterPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalArnaCutterPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalArnaCutterPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH062")
    #expect(OriginalArnaCutterPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalArnaCutterPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalArnaCutterPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalArnaCutterPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH064") == nil)
    #expect(ShipCatalogue.rawMesh("SH064") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH064", sourceFaces: 184)) {
      try OriginalDetailedHullStage.requireRuntime("SH064")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH064")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 5)
    #expect(current.contract.accommodation?.operatingCrew == 5)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 32)
  }
}
