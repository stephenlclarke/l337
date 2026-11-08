import Foundation
import Testing

@testable import L337Core

/// Actual engineering/loader joins only. No original NPC, people, source or port is issued.
struct NativeC03EvacuationHullUnitTests {
  @Test(arguments: NativeC03EvacuationHull.Role.allCases)
  func originalRescueHullUsesCurrentCalibratedNativeGeometryAndCompleteAppearance(
    _ role: NativeC03EvacuationHull.Role
  ) throws {
    let hull = try NativeC03EvacuationHull.resolve(role)
    let source = hull.source
    let current = try ScriptPackLibrary.currentCatalogueNPCDesign(role.fleetRole.id)
    #expect(hull.design == current)
    #expect(hull.design.rawMesh.vertices == source.physical.physicalMesh.vertices)
    #expect(hull.design.rawMesh.faces == source.physical.physicalMesh.faces)
    #expect(hull.design.faces.count <= 512)
    #expect(source.current.id == (role == .carrier ? "SH029" : "SH061"))
    #expect(source.physical.specificationSHA256 == source.current.sourceSHA256)
    #expect(source.physical.model.sourceSHA256 == source.current.referencedGeometrySHA256)
    #expect(hull.geometry == ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(current)))
    #expect(try NativeC03EvacuationHull.resolve(role).geometry == hull.geometry)
  }

  @Test func originalLaunchCannotUseItsUncalibratedSourceUnitMesh() throws {
    let hull = try NativeC03EvacuationHull.resolve(.launch)
    let physical = hull.source.physical
    #expect(physical.metresPerSourceUnit == 20)
    #expect(hull.design.rawMesh.vertices != physical.model.nativeDesign.rawMesh.vertices)
    #expect(hull.design.rawMesh.vertices == physical.model.nativeDesign.rawMesh.vertices.map { $0 * 20 })
    // Geometry/source adoption still creates neither the four-place cabin nor six people.
    #expect(hull.source.accommodation.initialPurchasedCabins == 0)
    #expect(hull.source.accommodation.intrinsicCrewPlaces == 2)
    #expect(!hull.source.fitting.roleKitIncluded)
  }
}
