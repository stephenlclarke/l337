import Foundation
import Testing

@testable import L337Core

struct OriginalCarabaoHighlinerPhysicalSourceUnitTests {
  private func source() throws -> OriginalCarabaoHighlinerPhysicalSource {
    try #require(OriginalCarabaoHighlinerPhysicalSource.current)
  }

  @Test func currentCarabaoHighlinerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH080")
    let contract = try #require(ShipCatalogue.ship("SH080")?.physicalSourceContract)
    #expect(contract.finiteCarabaoHighlinerDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 197841)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 236 && current.mesh.vertices.count == 150)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (0.592181750731577)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.1059795060377797)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.5925102979448935)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.006065476822296693) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 6.596206044247654) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-2.6821239234677136e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0001180833168829471)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.00019051804667135434)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 7.90636556495199) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteCarabaoHighliner() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH080")
    let path = OriginalCarabaoHighlinerPhysicalSource.folder.appendingPathComponent(OriginalCarabaoHighlinerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalCarabaoHighlinerPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalCarabaoHighlinerPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalCarabaoHighlinerPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH079")
    #expect(OriginalCarabaoHighlinerPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalCarabaoHighlinerPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalCarabaoHighlinerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalCarabaoHighlinerPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH080") == nil)
    #expect(ShipCatalogue.rawMesh("SH080") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH080", sourceFaces: 236)) {
      try OriginalDetailedHullStage.requireRuntime("SH080")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH080")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 10)
    #expect(current.contract.accommodation?.operatingCrew == 10)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 48)
  }
}
