import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalBesraUnitTests {
  private func retained(_ id: String = "SH108") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  private func fieldsOutsideBisonDelivery(_ ship: CatalogueShip) throws -> Data {
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    var metadata = try #require(fields["catalogue"] as? [String: Any])
    for key in ["normalPurchaseEligible", "purchasePolicy", "mechanicsStatus", "basis"] {
      metadata.removeValue(forKey: key)
    }
    fields["catalogue"] = metadata
    return try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
  }

  private func requireIndependentBisonDelivery(_ raw: CatalogueShip) throws {
    let expectedSHA256 =
      raw.id == "SH005"
      ? "a1592e007d95c8608f5bcc893d3ecf450fa94e9b4437d15f5fddc593f4d6e9fb"
      : "1fcf843a53ef11d4b0f6c503219cebfebf81ef6b97051a9b395ddbd4acec46c8"
    try #require(raw.id == "SH005" || raw.id == "SH006")
    let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(raw.id + ".toml"))
    try #require(ScriptPackLibrary.hash(bytes) == expectedSHA256)
    let expected = try OriginalBisonFixture.expected(raw.id)
    let canonical = try #require(ShipCatalogue.ship(raw.id))
    #expect(canonical.id == raw.id && canonical.name == expected.name)
    #expect(raw.game == expected.performance && canonical.game == expected.performance)
    #expect(
      !raw.catalogue.normalPurchaseEligible && raw.catalogue.purchasePolicy == .pendingFabrication)
    #expect(raw.catalogue.mechanicsStatus == .pending)
    #expect(canonical.catalogue.normalPurchaseEligible)
    #expect(canonical.catalogue.purchasePolicy == .blueprintFabrication)
    #expect(canonical.catalogue.mechanicsStatus == .ready)
    #expect(canonical.catalogue.minimumBuildTechLevel == (raw.id == "SH005" ? 9 : 11))
    #expect(
      canonical.catalogue.basis.hasPrefix(raw.id + " current adopted r3 source " + expectedSHA256))
    let unchangedFields =
      try fieldsOutsideBisonDelivery(canonical) == fieldsOutsideBisonDelivery(raw)
    #expect(unchangedFields, "Only the four declared Bison delivery metadata fields may change.")
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH108"))
    let model = try OriginalFleetShowroomModels.model(for: "SH108")
    let contract = try OriginalHullPhysicalContract.besra.get()
    #expect(OriginalBesraActivation.supports(definition))
    let unavailable = OriginalFleetDefinition(
      id: definition.id, name: definition.name, family: definition.family, role: definition.role,
      playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
      authored: definition.authored, sourcePath: definition.sourcePath,
      sourceSHA256: definition.sourceSHA256, nativePerformance: nil,
      approvedMeshAvailable: definition.approvedMeshAvailable,
      integrationBlockers: definition.integrationBlockers)
    #expect(!OriginalBesraActivation.supports(unavailable))
    for (id, name, family, available) in [
      ("SH068", "Besra", "besra", true), ("SH108", "Badger", "besra", true),
      ("SH108", "Besra", "badger", true), ("SH108", "Besra", "besra", false),
    ] {
      let changed = OriginalFleetDefinition(
        id: id, name: name, family: family, role: definition.role,
        playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
        authored: definition.authored, sourcePath: definition.sourcePath,
        sourceSHA256: definition.sourceSHA256, nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: available, integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalBesraActivation.supports(changed))
    }
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, definition.sourceSHA256),
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
      #expect(!OriginalBesraActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-11.124, -4.6, -22.09))
    #expect(contract.envelope.maximum == .init(11.124, 6.124, 14))
    #expect(contract.nativeTriangles == 208)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH108", units: String? = "metres", path: String? = nil,
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
    for id in ["SH005", "SH006", "SH104", "SH105", "SH106", "SH107"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalBesraActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalBesraActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      if id == "SH005" || id == "SH006" {
        try requireIndependentBisonDelivery(foreign)
      } else {
        #expect(ShipCatalogue.ship(id) == foreign)
      }
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH108"))
    let physical = try OriginalHullPhysicalContract.besra.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 122 && mesh.faces.count == 208)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == 208)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign)
    #expect(ship.nativeDesign?.textures?.count == 3)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22.248, 10.724, 36.09]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    let preview = try #require(ship.previewMesh)
    #expect(preview.vertices != source.vertices)
    for id in ["SH025", "SH103"] {
      let earlier = try #require(ShipCatalogue.ship(id))
      let native = try #require(earlier.nativeDesign).rawMesh
      var existing = Commander()
      existing.shipID = id
      #expect(existing.playerMesh.vertices == native.vertices)
      #expect(existing.playerMesh.faces == native.faces)
      #expect(existing.playerMesh.details == native.details)
      #expect(existing.playerMesh.materials == native.materials)
      #expect(existing.playerMesh.faceMaterials == native.faceMaterials)
      #expect(existing.playerMesh.faceTextures == native.faceTextures)
    }
  }
}
