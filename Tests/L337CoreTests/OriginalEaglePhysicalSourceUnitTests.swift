import Foundation
import Testing

@testable import L337Core

struct OriginalEaglePhysicalSourceUnitTests {
  private func source() throws -> OriginalEaglePhysicalSource {
    try #require(OriginalEaglePhysicalSource.current)
  }

  @Test func currentEagleHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH043")
    let contract = try #require(ShipCatalogue.ship("SH043")?.physicalSourceContract)
    #expect(contract.finiteEagleDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 295038)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 248 && current.mesh.vertices.count == 148)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y + 0.5281819326177067) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z + 9.059854150686174) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -0.5278429924422999)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(12000, -6000, 9000), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.04067272690297521) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 442.3159050698554) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(24, 10, -45), impulse = Vector3(12000, -6000, 9000)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x + 0.00047198599321717757) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y + 0.001977915082951284) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z + 0.0028021946437614487) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 1489.7487193302495) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteEagle() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH043")
    let path = OriginalEaglePhysicalSource.folder.appendingPathComponent(OriginalEaglePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalEaglePhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalEaglePhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalEaglePhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH042")
    #expect(OriginalEaglePhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalEaglePhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalEaglePhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalEaglePhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH043") == nil)
    #expect(ShipCatalogue.rawMesh("SH043") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH043", sourceFaces: 248)) {
      try OriginalDetailedHullStage.requireRuntime("SH043")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH043")
    #expect(!current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .never)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 28)
    #expect(current.contract.accommodation?.operatingCrew == 28)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 60)
  }
}
