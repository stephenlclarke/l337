import Foundation
import Testing

@testable import L337Core

struct OriginalErnePhysicalSourceUnitTests {
  private func source() throws -> OriginalErnePhysicalSource {
    try #require(OriginalErnePhysicalSource.current)
  }

  @Test func currentErneHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH045")
    let contract = try #require(ShipCatalogue.ship("SH045")?.physicalSourceContract)
    #expect(contract.finiteErneDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 84357)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 120 && current.mesh.vertices.count == 76)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (-1.4665569774750895)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-3.307149524505723)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == -1.4647788079154702)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(2400, -1200, 1800), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.028450513887407092) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 61.87986770511042) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(10, 6, -20), impulse = Vector3(2400, -1200, 1800)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.00027824769270922404)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0026606342723298065)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.006785369301210037)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 241.54714310915523) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteErne() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH045")
    let path = OriginalErnePhysicalSource.folder.appendingPathComponent(OriginalErnePhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalErnePhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalErnePhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalErnePhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH044")
    #expect(OriginalErnePhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalErnePhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalErnePhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalErnePhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH045") == nil)
    #expect(ShipCatalogue.rawMesh("SH045") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH045", sourceFaces: 120)) {
      try OriginalDetailedHullStage.requireRuntime("SH045")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH045")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 5)
    #expect(current.contract.accommodation?.operatingCrew == 5)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 28)
  }
}
