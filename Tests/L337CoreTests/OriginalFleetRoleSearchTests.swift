import Foundation
import Testing

@testable import L337Core

struct OriginalFleetRoleSearchTests {
  @Test func genuineMultirolePeregrineMatchesSecondaryRolesAndReadableLabels() throws {
    let ship = try #require(ShipCatalogue.ship("SH025"))
    let source = try #require(OriginalFleetR3Data.contract(for: ship.id))
    #expect(source.classification == "trader")
    #expect(ship.catalogue.primaryType == .trader && ship.catalogue.primaryRole == .trader)
    let preferences = ship.catalogue.roleWeights
    try #require(preferences.count == 3)
    #expect(preferences[0].role == .trader && preferences[0].weight == 4)
    #expect(preferences[1].role == .pirate && preferences[1].weight == 1)
    #expect(preferences[2].role == .bountyHunter && preferences[2].weight == 1)
    let metadata = ship.catalogue
    let profiles = ship.profiles
    var game = Game(executive: false)
    let commander = game.commander
    let bodies = game.bodies
    game.showroom.selection = ship.id
    for query in ["pirate", "PIRATE", "bounty hunter", "BOUNTY HUNTER", "bountyHunter", "trader"] {
      game.showroom.query = query
      let first = game.showroomShips.map(\.id)
      #expect(first.contains(ship.id))
      #expect(game.showroomShip?.id == ship.id)
      #expect(game.showroomShips.map(\.id) == first)
      #expect(game.showroom.query == query)
    }
    // This actual hull declares no miner role; other declared miners still match.
    game.showroom.query = "miner"
    #expect(game.showroomShip == nil)
    #expect(!game.showroomShips.contains { $0.id == ship.id })
    #expect(game.showroomShips.contains { $0.catalogue.primaryRole == .miner })
    // Keep the existing substring/case conventions; do not silently trim a query.
    game.showroom.query = "  pirate  "
    #expect(game.showroomShip == nil && game.showroom.query == "  pirate  ")
    #expect(ShipCatalogue.ship(ship.id)?.catalogue == metadata)
    #expect(ShipCatalogue.ship(ship.id)?.profiles == profiles)
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func completeCurrentFleetRoleQueriesPreserveExistingIdentityAndSourceMatching() throws {
    let ships = ShipCatalogue.all
    #expect(Set(ships.map(\.id)) == Set((1...171).map { String(format: "SH%03d", $0) }))
    let metadata = Dictionary(uniqueKeysWithValues: ships.map { ($0.id, $0.catalogue) })
    var game = Game(executive: false)
    let commander = game.commander
    for ship in ships {
      var queries = [ship.id, ship.name, ship.appearances] + (ship.catalogue.aliases ?? [])
      if let type = ship.catalogue.primaryType { queries += [type.rawValue, type.label] }
      if let role = ship.catalogue.primaryRole { queries += [role.rawValue, role.label] }
      for preference in ship.catalogue.roleWeights {
        queries += [preference.role.rawValue, preference.role.label]
      }
      for query in Set(queries) where !query.isEmpty {
        game.showroom.selection = ship.id
        game.showroom.query = query
        #expect(game.showroomShips.contains { $0.id == ship.id })
        #expect(game.showroomShip?.id == ship.id)
      }
    }
    #expect(Dictionary(uniqueKeysWithValues: ShipCatalogue.all.map { ($0.id, $0.catalogue) }) == metadata)
    #expect(game.commander == commander)
  }

  @Test func searchingDeclaredPendingRolesDoesNotGrantVisibilityKnowledgeOrTrade() throws {
    var game = Game(executive: false)
    let commander = game.commander
    let bodies = game.bodies
    let pending = try #require(ShipCatalogue.ship("SH067"))
    try #require(pending.catalogue.primaryType == .trader && pending.catalogue.primaryRole == .trader)
    try #require(pending.catalogue.roleWeights.isEmpty && pending.catalogue.discoveryEligible)
    try #require(OriginalDetailedHullStage.blocksRuntime(pending.id))
    let before = FleetCataloguePreview.mode(
      ship: pending, owner: nil, ownedShip: commander.shipID, discovery: nil)
    #expect(before == .silhouette)
    game.showroom.selection = pending.id
    game.showroom.query = "TRADER"
    #expect(game.showroomShips.contains { $0.id == pending.id })
    #expect(game.showroomShip?.id == pending.id)
    #expect(game.shipTradeQuote == nil)
    #expect(FleetCataloguePreview.mode(
      ship: pending, owner: nil, ownedShip: commander.shipID, discovery: nil) == before)
    game.showroom.query = "role-not-declared-anywhere-in-this-current-fleet"
    #expect(game.showroomShips.isEmpty && game.showroomShip == nil)
    game.showroom.query = ""
    #expect(game.showroomShips.count == 171)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(OriginalDetailedHullStage.blocksRuntime(pending.id))
  }
}
