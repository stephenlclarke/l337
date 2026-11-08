import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalOkapiActivationUnitTests {
  private func retained(_ id: String = "SH029") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func playerAndPhysicalMeshesKeepEveryApprovedMetreVertexMaterialAndTexture() throws {
    let contract = try OriginalHullPhysicalContract.okapi.get()
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let physical = contract.physicalMesh
    var commander = Commander()
    commander.shipID = "SH029"
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh("SH029"))] {
      #expect(mesh.vertices == physical.vertices && mesh.faces == physical.faces)
      #expect(mesh.details == physical.details && mesh.materials == physical.materials)
      #expect(
        mesh.faceMaterials == physical.faceMaterials && mesh.faceTextures == physical.faceTextures)
      #expect(mesh.vertices.count == 76 && mesh.faces.count == 120)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    #expect(
      ship.nativeDesign == contract.model.nativeDesign
    )
    #expect(zip(ship.dimensions ?? [], [20.0, 10.04, 34.09]).allSatisfy { abs($0 - $1) < 1e-9 })
    #expect(ship.dimensions?.count == 3)
    #expect(ship.previewMesh?.vertices != physical.vertices)
    #expect(physical.materials.count == 8 && !physical.faceTextures.isEmpty)
  }
}
