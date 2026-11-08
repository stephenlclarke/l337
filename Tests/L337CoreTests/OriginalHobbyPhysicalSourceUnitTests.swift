import Foundation
import Testing

@testable import L337Core

struct OriginalHobbyPhysicalSourceUnitTests {
  private func source() throws -> OriginalHobbyPhysicalSource {
    try #require(OriginalHobbyPhysicalSource.current)
  }

  @Test func currentHobbyHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH054")
    let contract = try #require(ShipCatalogue.ship("SH054")?.physicalSourceContract)
    #expect(contract.finiteHobbyDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 19880)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 192 && current.mesh.vertices.count == 114)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (0.040017928134760475)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.4641169392163578)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.04379070125096609)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.060362173038229376) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 65.64386317907444) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0012868894397726378)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0124036341312909)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.022835417146518672)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 205.37874304765683) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteHobby() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH054")
    let path = OriginalHobbyPhysicalSource.folder.appendingPathComponent(OriginalHobbyPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalHobbyPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalHobbyPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalHobbyPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH047")
    #expect(OriginalHobbyPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalHobbyPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalHobbyPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalHobbyPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH054") == nil)
    #expect(ShipCatalogue.rawMesh("SH054") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH054", sourceFaces: 192)) {
      try OriginalDetailedHullStage.requireRuntime("SH054")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH054")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 1)
    #expect(current.contract.accommodation?.operatingCrew == 1)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 14)
  }
}
