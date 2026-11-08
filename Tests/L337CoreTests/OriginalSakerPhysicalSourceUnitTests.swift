import Foundation
import Testing

@testable import L337Core

struct OriginalSakerPhysicalSourceUnitTests {
  private func source() throws -> OriginalSakerPhysicalSource {
    try #require(OriginalSakerPhysicalSource.current)
  }

  @Test func currentSakerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH042")
    let contract = try #require(ShipCatalogue.ship("SH042")?.physicalSourceContract)
    #expect(contract.finiteSakerDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 26588)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 220 && current.mesh.vertices.count == 132)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - 0.12022601970437655) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z + 6.249922187870627) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.12041407754473776)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.045133142771174965) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 49.08229276365277) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - 0.0001027635544307499) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y + 0.0025032428257172057) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z + 0.007388591404433681) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 80.8708964462027) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteSaker() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH042")
    let path = OriginalSakerPhysicalSource.folder.appendingPathComponent(OriginalSakerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalSakerPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalSakerPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalSakerPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH041")
    #expect(OriginalSakerPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalSakerPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalSakerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalSakerPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH042") == nil)
    #expect(ShipCatalogue.rawMesh("SH042") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH042", sourceFaces: 220)) {
      try OriginalDetailedHullStage.requireRuntime("SH042")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH042")
    #expect(current.contract.accommodation?.operatingCrew == 1)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 16)
  }
}
