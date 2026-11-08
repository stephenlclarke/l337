import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalSaigaActivationUnitTests {
  private func retained(_ id: String = "SH061") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func calibratedPhysicalAndPlayerGeometryNeverChangesTheRawSourceOrItsAppearance() throws {
    let source = try OriginalFleetShowroomModels.model(for: "SH061")
    let contract = try OriginalHullPhysicalContract.saiga.get()
    let ship = try #require(ShipCatalogue.ship("SH061"))
    var commander = Commander()
    commander.shipID = ship.id
    #expect(source.coordinateUnits == nil && contract.metresPerSourceUnit == 20)
    #expect(ship.nativeDesign == source.nativeDesign)
    let raw = source.displayMesh
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices.count == 912 && mesh.faces.count == 1720)
      for (physical, original) in zip(mesh.vertices, raw.vertices) {
        #expect((physical - original * 20).length < 1e-12)
        #expect(physical.length <= contract.envelope.clearanceRadius)
      }
      #expect(mesh.vertices == contract.physicalMesh.vertices)
      #expect(mesh.faces == raw.faces && mesh.details == raw.details)
      #expect(mesh.materials == raw.materials && mesh.materials.count == 10)
      #expect(mesh.faceMaterials == raw.faceMaterials && mesh.faceTextures == raw.faceTextures)
    }
    #expect(ship.geometryContext.contains("20 metres per SH061 source unit"))
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [41.536, 35.7, 80]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.previewMesh?.vertices != contract.physicalMesh.vertices)
    #expect(source.displayMesh.vertices == raw.vertices)
  }
}
