import Foundation
import Testing

@testable import L337Core

struct OriginalWarthogTankerPhysicalSourceUnitTests {
  private func source() throws -> OriginalWarthogTankerPhysicalSource {
    try #require(OriginalWarthogTankerPhysicalSource.current)
  }

  @Test func currentWarthogTankerHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH133")
    let contract = try #require(ShipCatalogue.ship("SH133")?.physicalSourceContract)
    #expect(contract.finiteWarthogTankerDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 143152)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 160 && current.mesh.vertices.count == 96)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (1.3406576024690775)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-2.0849954175014305)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 1.3411116664020861)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.008382698111098692) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 9.116184195819827) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-8.965441222779352e-05)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.00026652674180067536)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.00021311887219459247)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 11.475532725315265) < 1e-10)
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
    #expect(((diagonalOnly - w) * 100).length > 1e-5)
  }

  @Test func invalidImpulseOrPointHasNoReferenceResponse() throws {
    let finite = try source()
    #expect(finite.responseFromRest(impulse: .init(.nan, 0, 0), atLocalPoint: .init(0, 0, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(1, 0, 0), atLocalPoint: .init(0, .infinity, 0)) == nil)
    #expect(finite.responseFromRest(impulse: .init(.greatestFiniteMagnitude, 1, 0),
      atLocalPoint: .init(0, 10, 10)) == nil)
  }

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteWarthogTanker() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH133")
    let path = OriginalWarthogTankerPhysicalSource.folder.appendingPathComponent(OriginalWarthogTankerPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalWarthogTankerPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalWarthogTankerPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalWarthogTankerPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH132")
    #expect(OriginalWarthogTankerPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalWarthogTankerPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalWarthogTankerPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalWarthogTankerPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH133") == nil)
    #expect(ShipCatalogue.rawMesh("SH133") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH133", sourceFaces: 160)) {
      try OriginalDetailedHullStage.requireRuntime("SH133")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH133")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 6)
    #expect(current.contract.accommodation?.operatingCrew == 6)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 40)
  }
}
