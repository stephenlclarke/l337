import Foundation
import Testing

@testable import L337Core

struct OriginalFleetPendingComparisonTests {
  @Test(arguments: ["SH008", "SH036", "SH067", "SH112", "SH117", "SH123", "SH040"])
  func actualPendingOriginalsShowQualificationWithoutProjectingACarriedFit(_ id: String) throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    let bodies = game.bodies
    let schema = before.gameShipProfile
    let ship = try #require(ShipCatalogue.ship(id))
    try #require(ship.game != nil && OriginalDetailedHullStage.blocksRuntime(id))
    #expect(throws: (any Error).self) { try before.projectedEquipmentTransfer(to: id) }
    game.showroom.selection = id
    let profile = try #require(game.showroomProfile)
    #expect(profile.id == "game-" + id && profile.group == "native-game")
    #expect(profile.title == ship.name + " / original qualification pending")
    #expect(profile.context == "This original hull awaits native and actual-game qualification. Use Source notes for authored requirements.")
    #expect(!profile.title.contains("incompatible carried fit"))
    #expect(profile.fields.map(\.key) == schema.fields.map(\.key))
    #expect(profile.fields.map(\.unit) == schema.fields.map(\.unit))
    #expect(profile.fields.map(\.label) == schema.fields.map(\.label))
    #expect(profile.fields.allSatisfy {
      $0.text == "Unavailable" && $0.number == nil && $0.status == "game"
        && $0.basis == "Original hull qualification pending"
    })
    #expect(!game.showroomComparison.isEmpty)
    #expect(game.showroomComparison.allSatisfy { $0.rating == .unavailable && $0.difference.isEmpty })
    #expect(game.showroomTradeoffs.isEmpty && game.shipTradeQuote == nil)
    #expect(game.showroomBaselineProfile == schema)
    game.showroom.sourceProfiles = true
    let notes = game.showroomProfiles
    #expect(Array(notes.prefix(ship.profiles.count)) == ship.profiles)
    let original = try #require(notes.first { $0.group == OriginalFleetDefinition.sourceProfileGroup })
    #expect(original.fields.allSatisfy { $0.number == nil && $0.status == "source" })
    #expect(original.context.contains("current game fittings and hull activation are separate"))
    #expect(game.commander == before && game.bodies == bodies)
    #expect(OriginalDetailedHullStage.blocksRuntime(id))
  }

  @Test func genuineStartingFuelIncompatibilityKeepsTheOldLabelAndOwnFitStaysAvailable() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    try #require(before.shipID == "SH025" && before.fuel == 130 && before.fuelStorageUnits == 0)
    let target = try #require(ShipCatalogue.ship("SH002"))
    let performance = try #require(target.game)
    try #require(!OriginalDetailedHullStage.blocksRuntime(target.id) && performance.fuel == 120)
    try #require(before.fuel > performance.fuel)
    #expect(throws: (any Error).self) { try before.projectedEquipmentTransfer(to: target.id) }
    game.showroom.selection = target.id
    let unavailable = try #require(game.showroomProfile)
    #expect(unavailable.title == target.name + " / incompatible carried fit")
    #expect(unavailable.context == "Carried fittings or resources cannot transfer to this hull. Review trade for details.")
    #expect(unavailable.group == "native-game" && unavailable.fields.allSatisfy {
      $0.text == "Unavailable" && $0.number == nil && $0.status == "game"
        && $0.basis == "Incompatible carried fit"
    })
    game.showroom.selection = before.shipID
    let available = try #require(game.showroomProfile)
    #expect(available == before.gameShipProfile)
    #expect(available.title == before.ship.name + " / carried fit")
    #expect(available.fields.contains { $0.number != nil })
    #expect(game.commander == before)
  }

  @Test func genuineEnvironmentObjectsKeepNilGameProfileAndSeparateSourceNotes() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    let bodies = game.bodies
    for id in ["SH028", "SH156", "SH162"] {
      let ship = try #require(ShipCatalogue.ship(id))
      try #require(ship.game == nil)
      game.showroom.sourceProfiles = false
      game.showroom.selection = id
      #expect(game.showroomProfile == nil && game.showroomProfiles.isEmpty)
      #expect(game.shipTradeQuote == nil)
      game.showroom.sourceProfiles = true
      #expect(game.showroomProfiles.contains { $0.group == OriginalFleetDefinition.sourceProfileGroup })
    }
    #expect(game.commander == before && game.bodies == bodies)
  }
}
