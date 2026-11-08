import Foundation
import Testing

@testable import L337Core

struct OriginalFleetRuntimeHullSourceUnitTests {
  @Test func actualMissionCatalogueLoaderRetainsCurrentNativePhysicalGeometryAndDistinctObjectOwners() throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    let original = try #require(source.ship.nativeDesign)
    let loaded = try ScriptPackLibrary.currentCatalogueNPCDesign(source.ship.id)
    #expect(loaded.rawMesh.vertices == source.mesh.vertices && loaded.faces == source.mesh.faces)
    #expect(loaded.details == original.details && loaded.materials == original.materials)
    #expect(loaded.faceMaterials == original.faceMaterials && loaded.faceTextures == original.faceTextures)
    #expect(loaded.textures == original.textures && loaded.resolvedTextures == original.resolvedTextures)
    #expect(loaded.sourceTextures == original.sourceTextures && loaded.sourceFaceTextures == original.sourceFaceTextures)
    #expect(loaded.license == original.license && loaded.appearanceLicense == original.appearanceLicense)
    #expect(loaded.source.contains(source.contract.sourceSHA256))
    #expect(loaded.faces.reduce(0, { $0 + $1.count - 2 }) <= 512)
    let repeated = try ScriptPackLibrary.currentCatalogueNPCDesign(source.ship.id)
    #expect(try ScriptPackLibrary.canonicalGeometry(loaded) == ScriptPackLibrary.canonicalGeometry(repeated))
    for id in ["SH036", "SH067", "SH999"] {
      #expect(throws: (any Error).self) { try ScriptPackLibrary.currentCatalogueNPCDesign(id) }
    }
    let station = try #require(ShipCatalogue.ship("SH028"))
    #expect(try ScriptPackLibrary.currentCatalogueNPCDesign(station.id) == station.design)
  }

  @Test func currentOkapiUsesItsCalibratedNativeMeshForPlayerNPCAndSalvage() throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    let current = try #require(OriginalFleetR3Data.contract(for: source.ship.id))
    let native = try #require(source.ship.nativeDesign).rawMesh
    #expect(source.ship.name == "Okapi" && source.performance == current.performance)
    #expect(source.mesh.vertices == native.vertices && source.mesh.faces == native.faces)
    #expect(source.mesh.materials == native.materials && source.mesh.faceMaterials == native.faceMaterials)
    #expect(source.mesh.faceTextures == native.faceTextures)
    let maximum = max(source.envelope.dimensions.x,
      max(source.envelope.dimensions.y, source.envelope.dimensions.z))
    // The approved Okapi metre geometry is retained without showroom normalization.
    #expect(abs(maximum - 34.09) <= 0.001)
    var commander = Commander()
    commander.shipID = source.ship.id
    try #require(commander.shipID == source.ship.id)
    #expect(commander.playerMesh.vertices == source.mesh.vertices)
    #expect(commander.playerMesh.faces == source.mesh.faces)
    let salvage = try #require(SalvageCatalogue.empProfile(catalogueShipID: source.ship.id))
    #expect(salvage.mesh.vertices == source.mesh.vertices && salvage.mesh.faces == source.mesh.faces)
    let stock = try #require(NPCResources.stock(source.performance))
    #expect(stock.energyCapacity == source.performance.energy)
    #expect(stock.frontCapacity == source.performance.shield && stock.rearCapacity == source.performance.shield)
    let repeated = try #require(OriginalFleetRuntimeHullSource.source(for: source.ship.id))
    source.mesh.vertices.withUnsafeBufferPointer { first in
      repeated.mesh.vertices.withUnsafeBufferPointer { second in
        #expect(first.baseAddress == second.baseAddress && first.count == second.count)
      }
    }
  }

  @Test func fullPeregrineSourceCannotEnterTheCappedRuntimeOrMissionModel() throws {
    let ship = try #require(ShipCatalogue.ship("SH025"))
    let native = try #require(ship.nativeDesign)
    #expect(native.faces.count == 964)
    #expect(native.faces.reduce(0, { $0 + max(0, $1.count - 2) }) > 512)
    #expect(OriginalFleetRuntimeHullSource.source(for: ship.id) == nil)
    #expect(throws: (any Error).self) {
      try ScriptPackLibrary.currentCatalogueNPCDesign(ship.id)
    }
  }

  @Test func inspectablePhysicalModelsDoNotReleasePendingActorOrLoadedMassAuthority() throws {
    for id in ["SH036", "SH067", "SH076", "SH099", "SH100", "SH104"] {
      let ship = try #require(ShipCatalogue.ship(id))
      let physical = try #require(ship.physicalSourceContract)
      let candidate = try OriginalFleetCurrentHullSource(id: id)
      #expect(physical.engineering?.id == id)
      #expect(physical.physicalMesh.vertices == candidate.mesh.vertices)
      #expect(physical.physicalMesh.faces == candidate.mesh.faces)
      #expect(physical.physicalMesh.materials == candidate.mesh.materials)
      #expect(physical.physicalMesh.faceTextures == candidate.mesh.faceTextures)
      #expect(OriginalFleetRuntimeHullSource.source(for: id) == nil)
      #expect(ShipCatalogue.rawMesh(id) == nil)
      #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
    }
    for id in ["SH123", "SH171"] {
      #expect(OriginalFleetRuntimeHullSource.source(for: id) == nil)
      #expect(ShipCatalogue.ship(id)?.physicalSourceContract == nil)
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "Peregrine Mk V") == nil)
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH025-extra") == nil)
  }

  @Test func pendingOriginalObjectsRefuseMissionModelsBeforePublishingAnyGeometry() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(directory)
    let original = try #require(pack.manifest.npcs?.first)
    try #require(original.valid && !(original.components ?? []).isEmpty)
    var game = Game(executive: false)
    let beforePositive = game.commander.scriptState.geometry.count
    let actual = try game.makeScriptNPC(original, pack: pack, identity: UUID())
    #expect(actual.fit.definition == original && actual.fit.models.count == 2)
    try #require(game.commander.scriptState.geometry.count > beforePositive)

    // The actual asset-backed mission fit above is the positive control. Pending
    // originals cannot enter through either the main hull or a component model.
    for id in ["SH040", "SH156", "SH161", "SH162", "SH164"] {
      let object = try #require(ShipCatalogue.ship(id))
      let registration = try #require(OriginalDetailedHullStage.registration(for: id))
      try #require(object.catalogue.objectKind != .ship && registration.sourceNativeFaces > 512)
      let failure = OriginalDetailedHullStage.Failure.nativeLODUnqualified(
        id: id, actualSourceFaces: registration.sourceNativeFaces, maximum: 512)
      #expect(throws: failure) { try ScriptPackLibrary.currentCatalogueNPCDesign(id) }
      for component in [false, true] {
        var fields = try #require(
          JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        if component {
          var components = try #require(fields["components"] as? [[String: Any]])
          components[0]["model"] = "catalogue:" + id
          fields["components"] = components
        } else {
          fields["model"] = "catalogue:" + id
        }
        let definition = try JSONDecoder().decode(
          ScriptNPCDefinition.self, from: JSONSerialization.data(withJSONObject: fields))
        // Pending catalogue references are intentionally invalid even though
        // the original asset-backed fit was valid. The direct admission guard
        // must still refuse before publishing any other model from this request.
        try #require(!definition.valid)
        let before = game.commander
        let bodies = game.bodies.count
        #expect(throws: failure) {
          try game.makeScriptNPC(definition, pack: pack, identity: UUID())
        }
        #expect(game.commander == before && game.bodies.count == bodies)
      }
    }
  }
}
