import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalDetailedHullStageUnitTests {
  @Test(arguments: ["SH008", "SH009"])
  func detailedResourcesAuthenticateButCannotBecomeNativeAuthority(_ id: String) throws {
    let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
    let resource = try TOMLDecoder().decode(CatalogueShip.self, from: bytes)
    let entry = try #require(OriginalDetailedHullStage.registration(for: id))
    try OriginalDetailedHullStage.authenticate(resource, bytes: bytes)
    #expect(try OriginalPlayerHullActivation.resolve(resource) == resource)
    #expect(resource.name == entry.name && resource.catalogue.family == "goshawk")
    #expect(resource.nativeHull == nil && resource.nativeDesign == nil && resource.nativeCombat == nil)
    #expect(resource.design.vertices.count == entry.detailedVertices)
    #expect(resource.design.faces.count == entry.detailedFaces)
    #expect(resource.catalogue.aliases?.isEmpty != false)
    #expect(resource.availability == "Original hull pending; unavailable for flight or purchase")
    #expect(throws: OriginalDetailedHullStage.Failure.invalidDetailedResource(id)) {
      try OriginalDetailedHullStage.authenticate(resource, bytes: bytes + Data("\n".utf8))
    }
    #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
      id: id, actualSourceFaces: id == "SH008" ? 964 : 1012, maximum: 512)) {
      try OriginalDetailedHullStage.requireRuntime(id)
    }
  }

  @Test(arguments: ["SH008", "SH009"])
  func pendingOriginalHasNoSalvageOrScriptActorFallback(_ id: String) {
    #expect(ShipCatalogue.rawMesh(id) == nil)
    #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
    #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
    #expect(throws: (any Error).self) {
      try OriginalDetailedHullStage.requireRuntime(modelReference: "catalogue:" + id)
    }
  }

  @Test(arguments: ["SH008", "SH009"])
  func exchangeRefusalPreservesTheCurrentCommanderAndFittings(_ id: String) throws {
    var game = Game(executive: false)
    let before = game.commander
    let ship = try #require(ShipCatalogue.ship(id))
    #expect(game.shipTradeQuote(for: ship) == nil)
    #expect(throws: (any Error).self) {
      try game.commander.projectedEquipmentTransfer(to: id)
    }
    #expect(throws: (any Error).self) {
      try game.commander.transferEquipment(to: id, hullID: UUID())
    }
    #expect(game.commander == before)
    game.commander.shipID = id
    #expect(!game.commander.valid)
  }

  @Test(arguments: ["SH008", "SH009"])
  func pendingPlayerClaimStopsCollisionAndFlightBeforeAdvancingState(_ id: String) {
    var game = Game(executive: false)
    game.commander.shipID = id
    let before = game.commander
    let bodies = game.bodies
    #expect(throws: (any Error).self) {
      try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 100, radius: 0, includePlayer: false)
    }
    let flightAdmitted = game.admitFlightWorkAdvance(controls: Controls())
    #expect(!flightAdmitted)
    #expect(game.commander == before)
    #expect(game.bodies == bodies)
  }

  @Test func unrelatedHullAndAssetReferencesAreNotStagedByFamilyOrPrefix() throws {
    #expect(OriginalDetailedHullStage.registration(for: "SH007") == nil)
    try OriginalDetailedHullStage.requireRuntime("SH007")
    try OriginalDetailedHullStage.requireRuntime(modelReference: "asset:SH008")
    try OriginalDetailedHullStage.requireRuntime(modelReference: "catalogue:SH008-extra")
  }
}
