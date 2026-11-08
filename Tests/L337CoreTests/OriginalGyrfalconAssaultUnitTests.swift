import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalGyrfalconAssaultUnitTests {
  private func retained(_ id: String = "SH002") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func authenticatedAuthoredMetresProvideAllVertexBoundsAndRejectChangedSource() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH002"))
    let model = try OriginalFleetShowroomModels.model(for: "SH002")
    let contract = try OriginalHullPhysicalContract.gyrfalconAssault.get()
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-11.445, -3.289, -14.016))
    #expect(contract.envelope.maximum == .init(11.445, 5.16, 14.1))
    #expect(contract.nativeTriangles == 340)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    #expect(contract.envelope.clearanceRadius == model.displayMesh.vertices.map(\.length).max())
    func changed(
      id: String = "SH002", units: String? = "metres", path: String? = nil,
      hash: String? = nil
    ) -> OriginalFleetShowroomModel {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(id: "SH003"), changed(units: nil), changed(units: "centimetres"),
      changed(path: "other.toml"), changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let foreign = try #require(OriginalFleetDefinitionData.definition(for: "SH003"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: foreign, model: model)
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepTheCompleteApprovedGeometryAndAppearance() throws {
    let contract = try OriginalHullPhysicalContract.gyrfalconAssault.get()
    let ship = try #require(ShipCatalogue.ship("SH002"))
    var commander = Commander()
    commander.shipID = ship.id
    let source = contract.model.displayMesh
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 204 && mesh.faces.count == 340)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.details == source.details && mesh.faceMaterials == source.faceMaterials)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == contract.model.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22.89, 8.449, 28.116]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    let notes = try #require(ship.sourceProfilesIncludingPhysical.last)
    #expect(notes.group == "original-physical-metres")
    #expect(notes.fields.first { $0.key == "original.physical.width" }?.text == "22.89 m")
    #expect(ship.previewMesh?.vertices != source.vertices)
  }
}
