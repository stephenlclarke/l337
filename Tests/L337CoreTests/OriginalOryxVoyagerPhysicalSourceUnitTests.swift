import Foundation
import Testing

@testable import L337Core

struct OriginalOryxVoyagerPhysicalSourceUnitTests {
  private func source() throws -> OriginalOryxVoyagerPhysicalSource {
    try #require(OriginalOryxVoyagerPhysicalSource.current)
  }

  @Test func currentOryxVoyagerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH078")
    let contract = try #require(ShipCatalogue.ship("SH078")?.physicalSourceContract)
    #expect(contract.finiteOryxVoyagerDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 50196)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 200 && current.mesh.vertices.count == 112)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (0.31199056070820247)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-5.4099199098931265)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.31328550343876815)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.02390628735357399) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 25.998087497011714) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-2.7734661653086167e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0005935067346568209)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.001345619824115354)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 32.49055608027446) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteOryxVoyager() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH078")
    let path = OriginalOryxVoyagerPhysicalSource.folder.appendingPathComponent(OriginalOryxVoyagerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalOryxVoyagerPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalOryxVoyagerPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalOryxVoyagerPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH077")
    #expect(OriginalOryxVoyagerPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalOryxVoyagerPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalOryxVoyagerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalOryxVoyagerPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH078") == nil)
    #expect(ShipCatalogue.rawMesh("SH078") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH078", sourceFaces: 200)) {
      try OriginalDetailedHullStage.requireRuntime("SH078")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH078")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 3)
    #expect(current.contract.accommodation?.operatingCrew == 3)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 32)
  }
}
