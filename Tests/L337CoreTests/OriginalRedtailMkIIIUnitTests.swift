import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalRedtailMkIIIUnitTests {
  private func retained(_ id: String = "SH103") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH103"))
    let model = try OriginalFleetShowroomModels.model(for: "SH103")
    let contract = try OriginalHullPhysicalContract.redtailMkIII.get()
    #expect(OriginalRedtailMkIIIActivation.supports(definition))
    let unavailable = OriginalFleetDefinition(
      id: definition.id, name: definition.name, family: definition.family, role: definition.role,
      playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
      authored: definition.authored, sourcePath: definition.sourcePath,
      sourceSHA256: definition.sourceSHA256, nativePerformance: nil,
      approvedMeshAvailable: definition.approvedMeshAvailable,
      integrationBlockers: definition.integrationBlockers)
    #expect(!OriginalRedtailMkIIIActivation.supports(unavailable))
    for (id, name, family, available) in [
      ("SH068", "Redtail Mk III", "redtail", true), ("SH103", "Badger", "redtail", true),
      ("SH103", "Redtail Mk III", "badger", true), ("SH103", "Redtail Mk III", "redtail", false),
    ] {
      let changed = OriginalFleetDefinition(
        id: id, name: name, family: family, role: definition.role,
        playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
        authored: definition.authored, sourcePath: definition.sourcePath,
        sourceSHA256: definition.sourceSHA256, nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: available, integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalRedtailMkIIIActivation.supports(changed))
    }
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, definition.sourceSHA256),
      ("leisure", "blueprintFabrication", true, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", true, definition.sourceSHA256),
      ("bountyHunter", "never", true, definition.sourceSHA256),
      ("bountyHunter", "blueprintFabrication", false, definition.sourceSHA256),
      ("bountyHunter", "blueprintFabrication", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalRedtailMkIIIActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-11, -9, -18.5))
    #expect(contract.envelope.maximum == .init(11, 4.936, 18.5))
    #expect(contract.nativeTriangles == 140)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH103", units: String? = "metres", path: String? = nil,
      hash: String? = nil
    ) -> OriginalFleetShowroomModel {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(id: "SH020"), changed(units: nil), changed(units: "showroom"),
      changed(path: "other.toml"), changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let other = try #require(OriginalFleetDefinitionData.definition(for: "SH020"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: other, model: model)
    }
    for id in ["SH005", "SH006", "SH094", "SH095", "SH096", "SH100", "SH102"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalRedtailMkIIIActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalRedtailMkIIIActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      #expect(ShipCatalogue.ship(id) == foreign)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH103"))
    let physical = try OriginalHullPhysicalContract.redtailMkIII.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 84 && mesh.faces.count == 140)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == 140)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign)
    #expect(ship.nativeDesign?.textures?.count == 3)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22, 13.936, 37]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
  }
}
