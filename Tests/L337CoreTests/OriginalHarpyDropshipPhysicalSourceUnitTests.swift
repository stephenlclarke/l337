import Foundation
import Testing

@testable import L337Core

struct OriginalHarpyDropshipPhysicalSourceUnitTests {
  private func source() throws -> OriginalHarpyDropshipPhysicalSource {
    try #require(OriginalHarpyDropshipPhysicalSource.current)
  }

  @Test func currentHarpyDropshipHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH046")
    let contract = try #require(ShipCatalogue.ship("SH046")?.physicalSourceContract)
    #expect(contract.finiteHarpyDropshipDrySource?.emptyDry == finite.emptyDry)
    #expect(contract.finiteHarpyDrySource == nil)
    #expect(finite.emptyDry.massKg == 51822)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 240 && current.mesh.vertices.count == 144)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (-0.6631947156122244)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.106625320747543)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -0.6543373627557442)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02315618849137432) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 25.18235498436957) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.00024219868403036957)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0024636930002036555)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0034359326699812203)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 51.58353165566385) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteHarpyDropship() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH046")
    let path = OriginalHarpyDropshipPhysicalSource.folder.appendingPathComponent(OriginalHarpyDropshipPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalHarpyDropshipPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalHarpyDropshipPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalHarpyDropshipPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH044")
    #expect(OriginalHarpyDropshipPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalHarpyDropshipPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalHarpyDropshipPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalHarpyDropshipPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH046") == nil)
    #expect(ShipCatalogue.rawMesh("SH046") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH046", sourceFaces: 240)) {
      try OriginalDetailedHullStage.requireRuntime("SH046")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH046")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 5)
    #expect(current.contract.accommodation?.operatingCrew == 5)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 30)
  }
}
