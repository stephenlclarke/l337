import Foundation
import Testing

@testable import L337Core

@Suite(.serialized)
struct OriginalFleetMilestonePreviewTests {
  @Test func actualFrogDoorwayRevealsFullGalleryWithoutPurchaseRightsAcrossColdSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(site: .frog)
    let owner = try #require(game.commander.equipmentOwnerID)
    let ship = try #require(ShipCatalogue.ship("SH034"))
    let expected = OriginalStationSite.frog.identity(world: owner)
    let station = try #require(game.bodies.first { $0.nativeStationIdentity == expected })
    let identity = try #require(station.nativeStationIdentity)
    let actor = try #require(station.physical?.identity)
    try #require(game.nativeStationBodyIsCurrent(station))
    try #require(ship.catalogue.collectionMilestone == .docking && ship.catalogue.purchasePolicy == .never)
    try #require(game.commander.scriptState.savedFleetDiscovery?.entries[ship.id] == nil)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: owner, ownedShip: game.commander.shipID,
      discovery: game.commander.scriptState.savedFleetDiscovery) == .silhouette)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    game = await runtime.advance(delta: 0.1)
    try #require(game.docked && !game.dockedAtMainStation && !game.paused)
    let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
    try #require(game.nativeStationDockEvidenceIsCurrent && receipt.station == identity)
    #expect(receipt.dockingBinding == .init(actor: actor, bodyID: station.id))
    let discovery = try #require(game.commander.scriptState.savedFleetDiscovery)
    let entry = try #require(discovery.entries[ship.id])
    let milestone = try #require(entry.milestone)
    try #require(discovery.valid && entry.valid && milestone.valid)
    #expect(milestone.kind == .stationDocking && milestone.secondaryDock == receipt && milestone.mainDock == nil)
    let commander = game.commander
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: owner, ownedShip: commander.shipID, discovery: discovery) == .shaded)
    #expect(commander == game.commander && !ship.catalogue.normalPurchaseEligible && !ship.catalogue.playerFlyable)
    #expect(commander.fleetBlueprintAcquisition(for: ship.id) == nil)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: UUID(), ownedShip: commander.shipID, discovery: discovery) == .silhouette)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: nil, ownedShip: commander.shipID, discovery: discovery) == .silhouette)

    // Remove or corrupt only recorded history from this genuine arrival; issue no replacement proof.
    let encoded = try JSONEncoder().encode(discovery)
    var root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var entries = try #require(root["entries"] as? [String: Any])
    var recorded = try #require(entries[ship.id] as? [String: Any])
    recorded.removeValue(forKey: "milestone")
    entries[ship.id] = recorded
    root["entries"] = entries
    let incomplete = try JSONDecoder().decode(
      NativeFleetDiscovery.self, from: JSONSerialization.data(withJSONObject: root))
    try #require(incomplete.valid && incomplete.entries[ship.id]?.milestone == nil)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: owner, ownedShip: commander.shipID, discovery: incomplete) == .recordedWireframe)
    root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    entries = try #require(root["entries"] as? [String: Any])
    recorded = try #require(entries[ship.id] as? [String: Any])
    var altered = try #require(recorded["milestone"] as? [String: Any])
    altered["owner"] = UUID().uuidString
    recorded["milestone"] = altered
    entries[ship.id] = recorded
    root["entries"] = entries
    let invalid = try JSONDecoder().decode(
      NativeFleetDiscovery.self, from: JSONSerialization.data(withJSONObject: root))
    #expect(!invalid.valid)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: owner, ownedShip: commander.shipID, discovery: invalid) == .silhouette)
    #expect(game.commander == commander)

    try await runtime.save(to: storage.url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    #expect(saved.scriptState.savedFleetDiscovery == discovery)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot().commander
    #expect(restored == saved && restored.scriptState.savedFleetDiscovery == discovery)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: restored.equipmentOwnerID, ownedShip: restored.shipID,
      discovery: restored.scriptState.savedFleetDiscovery) == .shaded)
    #expect(restored.fleetBlueprintAcquisition(for: ship.id) == nil)
  }

  @Test(arguments: ["SH043", "SH081", "SH123"])
  func pendingCapitalCannotObtainGalleryDetailFromARefusedDestructionClaim(shipID: String) throws {
    let ship = try #require(ShipCatalogue.ship(shipID))
    try #require(ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .vessel)
    try #require(ship.catalogue.collectionMilestone == .destruction && ship.catalogue.purchasePolicy == .never)
    try #require(OriginalDetailedHullStage.blocksRuntime(shipID))
    let owner = UUID()
    let system = SystemIdentity(galaxy: 0, system: 7)
    let player = ActorIdentity(system: system, visit: 1, entity: 0)
    let actor = ActorIdentity(system: system, visit: 1, entity: 2)
    // A negative policy input cannot stand in for a native capital birth or death.
    let refused = FleetDiscoveryEvidence(
      owner: owner, ship: shipID, kind: .playerDestruction, actor: actor, player: player,
      physicalTime: 1, death: .init(victim: actor, owner: player, lawful: true, bountyTenths: 0),
      mainDock: nil, secondaryDock: nil)
    #expect(!refused.valid)
    var discovery = NativeFleetDiscovery(owner: owner)
    #expect(throws: SaveError.self) { try discovery.record(refused) }
    #expect(discovery.entries.isEmpty)
    #expect(FleetCataloguePreview.mode(
      ship: ship, owner: owner, ownedShip: "SH025", discovery: discovery) == .silhouette)
  }
}
