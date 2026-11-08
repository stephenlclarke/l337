import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalPantherFamilyUnitTests {
  private struct Facts: Sendable {
    let vertices: Int
    let faces: Int
  }
  private static let facts: [String: Facts] = [
    "SH032": .init(vertices: 206, faces: 352),
    "SH033": .init(vertices: 188, faces: 320),
  ]

  private func retained(_ id: String) throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test(arguments: ["SH032", "SH033"])
  func exactMetreContractsRefuseSwappedModelsWrongRolesAndChangedSources(id: String) throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: id))
    let approved = try #require(OriginalPantherFamilyActivation.registration(for: id))
    let model = try OriginalFleetShowroomModels.model(for: id)
    let contract = try OriginalHullPhysicalContract(definition: definition, model: model)
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(
      definition.role == approved.role.rawValue
        && definition.sourceSHA256 == approved.specificationSHA256)
    #expect(model.sourcePath == approved.modelPath && model.sourceSHA256 == approved.modelSHA256)
    #expect(contract.envelope.minimum == .init(-9.829, -6.2, -20.09))
    #expect(contract.envelope.maximum == .init(9.829, 7.48, 17))
    func changed(units: String? = "metres", path: String? = nil, hash: String? = nil)
      -> OriginalFleetShowroomModel
    {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(units: nil), changed(units: "showroom"), changed(path: "other.toml"),
      changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let otherID = id == "SH032" ? "SH033" : "SH032"
    let other = try #require(OriginalFleetDefinitionData.definition(for: otherID))
    let otherModel = try OriginalFleetShowroomModels.model(for: otherID)
    #expect(
      model.nativeDesign != otherModel.nativeDesign && model.sourceSHA256 != otherModel.sourceSHA256
    )
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: definition, model: otherModel)
    }
    let wrongRole = OriginalFleetDefinition(
      id: definition.id, name: definition.name, family: definition.family, role: other.role,
      playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
      authored: definition.authored, sourcePath: definition.sourcePath,
      sourceSHA256: definition.sourceSHA256,
      nativePerformance: definition.nativePerformance,
      approvedMeshAvailable: definition.approvedMeshAvailable,
      integrationBlockers: definition.integrationBlockers)
    #expect(!OriginalPantherFamilyActivation.supports(wrongRole))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: wrongRole, model: model)
    }
    #expect(OriginalPantherFamilyActivation.registration(for: "SH034") == nil)
  }

  @Test(arguments: ["SH032", "SH033"])
  func everyPhysicalPlayerVertexAndAppearanceAssignmentUsesItsOwnApprovedSource(id: String) throws {
    let expected = try #require(Self.facts[id])
    let ship = try #require(ShipCatalogue.ship(id))
    let contract = try #require(ship.physicalSourceContract)
    let source = try OriginalFleetShowroomModels.model(for: id)
    #expect(ship.nativeDesign == source.nativeDesign)
    var commander = Commander()
    commander.shipID = id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(id))] {
      #expect(
        mesh.vertices == contract.physicalMesh.vertices && mesh.faces == source.displayMesh.faces)
      #expect(mesh.vertices.count == expected.vertices && mesh.faces.count == expected.faces)
      #expect(mesh.materials == source.displayMesh.materials && mesh.materials.count == 8)
      #expect(
        mesh.faceMaterials == source.displayMesh.faceMaterials
          && mesh.details == source.displayMesh.details)
      #expect(mesh.faceTextures == source.displayMesh.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [19.658, 13.68, 37.09]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.previewMesh?.vertices != source.displayMesh.vertices)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
  }
}
