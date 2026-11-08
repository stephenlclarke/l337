import Foundation
import Testing

@testable import L337Core

struct OriginalDzoMkIIPhysicalSourceUnitTests {
  private func source() throws -> OriginalDzoMkIIPhysicalSource {
    try #require(OriginalDzoMkIIPhysicalSource.current)
  }

  @Test func currentDzoMkIIHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH075")
    let contract = try #require(ShipCatalogue.ship("SH075")?.physicalSourceContract)
    #expect(contract.finiteDzoMkIIDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 88810)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 448 && current.mesh.vertices.count == 242)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.x - (-0.2012762917270384)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.y - (0.9901622381760614)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.8890882440692183)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.9908941437750067)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.013511991892804864) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 14.694291183425287) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0001187194063145138)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0005317323398434229)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.0006511792845415159)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 19.720113731462945) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteDzoMkII() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH075")
    let path = OriginalDzoMkIIPhysicalSource.folder.appendingPathComponent(OriginalDzoMkIIPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalDzoMkIIPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalDzoMkIIPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalDzoMkIIPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH074")
    #expect(OriginalDzoMkIIPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalDzoMkIIPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalDzoMkIIPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalDzoMkIIPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH075") == nil)
    #expect(ShipCatalogue.rawMesh("SH075") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH075", sourceFaces: 448)) {
      try OriginalDetailedHullStage.requireRuntime("SH075")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH075")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 8)
    #expect(current.contract.accommodation?.operatingCrew == 8)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 40)
  }
}
