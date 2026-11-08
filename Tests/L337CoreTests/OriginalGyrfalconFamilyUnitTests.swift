import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalGyrfalconFamilyUnitTests {
  private func retained(_ id: String) throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test(arguments: ["SH003", "SH004"])
  func eachApprovedMetreContractRejectsForeignMissingUnitsAndChangedSource(id: String) throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: id))
    let registration = try #require(OriginalGyrfalconFamilyActivation.registration(for: id))
    let model = try OriginalFleetShowroomModels.model(for: id)
    let contract = try OriginalHullPhysicalContract(definition: definition, model: model)
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(definition.sourceSHA256 == registration.specificationSHA256)
    #expect(
      model.sourceSHA256 == registration.modelSHA256 && model.sourcePath == registration.modelPath)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    #expect(contract.envelope.minimum == .init(-11.445, -3.289, -14.016))
    #expect(contract.envelope.maximum == .init(11.445, 5.16, 14.1))
    func changed(units: String? = "metres", hash: String? = nil, path: String? = nil)
      -> OriginalFleetShowroomModel
    {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(units: nil), changed(units: "showroom"),
      changed(hash: String(repeating: "0", count: 64)), changed(path: "other.toml"),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let otherID = id == "SH003" ? "SH004" : "SH003"
    let foreign = try OriginalFleetShowroomModels.model(for: otherID)
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: definition, model: foreign)
    }
    #expect(model.sourceSHA256 != foreign.sourceSHA256)
    #expect(model.nativeDesign != foreign.nativeDesign)
    #expect(OriginalGyrfalconFamilyActivation.registration(for: "SH005") == nil)
  }

  @Test(arguments: ["SH003", "SH004"])
  func completePhysicalPlayerGeometryAndAppearanceUseOnlyThatVariantsApprovedMetres(id: String)
    throws
  {
    let ship = try #require(ShipCatalogue.ship(id))
    let contract = try #require(ship.physicalSourceContract)
    let source = try OriginalFleetShowroomModels.model(for: id)
    #expect(ship.nativeDesign == source.nativeDesign)
    var commander = Commander()
    commander.shipID = id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(id))] {
      #expect(
        mesh.vertices == contract.physicalMesh.vertices && mesh.faces == source.displayMesh.faces)
      #expect(mesh.vertices.count == (id == "SH003" ? 214 : 152))
      #expect(mesh.faces.count == (id == "SH003" ? 364 : 252))
      #expect(mesh.materials.count == 8 && mesh.materials == source.displayMesh.materials)
      #expect(mesh.faceMaterials == source.displayMesh.faceMaterials)
      #expect(mesh.faceTextures == source.displayMesh.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.details == source.displayMesh.details)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22.89, 8.449, 28.116]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.displayMesh.vertices)
  }
}
