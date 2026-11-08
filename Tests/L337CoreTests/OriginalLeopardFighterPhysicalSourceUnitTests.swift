import Foundation
import Testing

@testable import L337Core

struct OriginalLeopardFighterPhysicalSourceUnitTests {
  private func source() throws -> OriginalLeopardFighterPhysicalSource {
    try #require(OriginalLeopardFighterPhysicalSource.current)
  }

  @Test func currentLeopardFighterHasSeparateFiniteDryTensorWithoutReplacingItsOriginalBudget() throws {
    let finite = try source()
    let current = try OriginalFleetCurrentHullSource(id: "SH110")
    let contract = try #require(ShipCatalogue.ship("SH110")?.physicalSourceContract)
    #expect(contract.finiteLeopardFighterDrySource?.emptyDry == finite.emptyDry)
    #expect(finite.emptyDry.massKg == 40293)
    #expect(finite.emptyDry.massKg == Double(current.engineering.dryMassKilograms))
    #expect(current.nativeTriangles == 108 && current.mesh.vertices.count == 68)
    #expect(finite.specificationSHA256 == current.contract.sourceSHA256)
    #expect(finite.nativeSourceSHA256 == current.model.sourceSHA256)
    #expect(abs(finite.emptyDry.centre.y - (0.11081322700174441)) < 1e-12)
    #expect(abs(finite.emptyDry.centre.z - (-1.9472830114361048)) < 1e-12)
    #expect(finite.emptyDry.inertiaAboutCentreOfMassKgM2
      != current.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(current.engineering.centreOfMassMetres[1] == 0.11242643023744502)
  }

  @Test func centreImpulseHasTranslationAndNoReferenceSpin() throws {
    let finite = try source()
    let r = try #require(finite.responseFromRest(
      impulse: .init(1200, -600, 900), atLocalPoint: finite.emptyDry.centre))
    #expect(r.angularVelocityDelta.length == 0)
    #expect(r.angularMomentumDelta.length == 0)
    #expect(abs(r.centreVelocityDelta.x - 0.029781847963666147) < 1e-14)
    #expect(abs(r.kineticEnergyFromRestJoules - 32.387759660486935) < 1e-10)
  }

  @Test func offAxisImpulseUsesFullTensorAndConservesWorkAndMomentum() throws {
    let finite = try source()
    let point = Vector3(4, 3, -10), impulse = Vector3(1200, -600, 900)
    let r = try #require(finite.responseFromRest(impulse: impulse, atLocalPoint: point))
    // MBA independent box/stock quadrature and a full linear solve supply these values.
    #expect(abs(r.angularVelocityDelta.x - (-0.0007398571771555805)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.y - (-0.0033596188720389345)) < 1e-13)
    #expect(abs(r.angularVelocityDelta.z - (-0.003987439143331809)) < 1e-13)
    #expect(abs(r.kineticEnergyFromRestJoules - 67.19015507167765) < 1e-10)
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

  @Test func missingChangedOrForeignSourceCannotBecomeFiniteLeopardFighter() throws {
    let current = try OriginalFleetCurrentHullSource(id: "SH110")
    let path = OriginalLeopardFighterPhysicalSource.folder.appendingPathComponent(OriginalLeopardFighterPhysicalSource.fileName)
    let data = try Data(contentsOf: path)
    #expect(OriginalLeopardFighterPhysicalSource.decode(data, source: current) != nil)
    var changed = data
    changed[changed.startIndex] = 0
    #expect(OriginalLeopardFighterPhysicalSource.decode(changed, source: current) == nil)
    #expect(OriginalLeopardFighterPhysicalSource.decode(Data(), source: current) == nil)
    let foreign = try OriginalFleetCurrentHullSource(id: "SH109")
    #expect(OriginalLeopardFighterPhysicalSource.decode(data, source: foreign) == nil)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    #expect(OriginalLeopardFighterPhysicalSource.load(from: root, source: current) == nil)
    let file = root.appendingPathComponent(OriginalLeopardFighterPhysicalSource.fileName)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: path)
    #expect(OriginalLeopardFighterPhysicalSource.load(from: root, source: current) == nil)
  }

  @Test func finiteDrySourceIssuesNoNativeActorPlayerFittingOrCrewAuthority() throws {
    _ = try source()
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH110") == nil)
    #expect(ShipCatalogue.rawMesh("SH110") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH110", sourceFaces: 108)) {
      try OriginalDetailedHullStage.requireRuntime("SH110")
    }
    let current = try OriginalFleetCurrentHullSource(id: "SH110")
    #expect(current.contract.playerFlyable)
    #expect(current.contract.purchasePolicy == .blueprintFabrication)
    #expect(current.contract.accommodation?.intrinsicCrewPlaces == 2)
    #expect(current.contract.accommodation?.operatingCrew == 2)
    #expect(current.contract.accommodation?.nativeAutonomous == false)
    #expect(current.contract.fitting?.roleKitIncluded == false)
    #expect(current.contract.fitting?.equipmentUnits == 20)
  }
}
