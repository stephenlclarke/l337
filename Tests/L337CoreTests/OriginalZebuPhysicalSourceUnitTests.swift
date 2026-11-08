import Foundation
import Testing

@testable import L337Core

struct OriginalZebuPhysicalSourceUnitTests {
  private func source() throws -> OriginalZebuPhysicalSource {
    try #require(OriginalZebuPhysicalSource.current)
  }

  @Test func currentZebuHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH036")
    let contract = try #require(ShipCatalogue.ship("SH036")?.physicalSourceContract)
    #expect(contract.finiteZebuDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 64051)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 192 && current.mesh.vertices.count == 114)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - 0.854733097529368) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z + 0.4001289860995685) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.8683161281720966)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.01873507049070272) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 20.37438915863921) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x + 0.0004136130715478394) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y + 0.001402805808059771) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z + 0.0015150142386226688) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 35.53947547636924) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteZebu() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH036")
    let path = OriginalZebuPhysicalSource.folder.appendingPathComponent(OriginalZebuPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalZebuPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalZebuPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalZebuPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH041")
    #expect(OriginalZebuPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalZebuPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalZebuPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalZebuPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH036") == nil)
    #expect(ShipCatalogue.rawMesh("SH036") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH036", sourceFaces: 192)) {
      try OriginalDetailedHullStage.requireRuntime("SH036")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH036")
    #expect(current.contract.accommodation?.operatingCrew == 2)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 22)
  }
}
