import Foundation
import Testing

@testable import L337Core

struct OriginalFleetPendingTradeReviewTests {
  @Test(arguments: ["SH008", "SH036", "SH067", "SH112", "SH117", "SH123", "SH040"])
  func stagedOriginalKeepsSourceValuesButRefusesAllEmptyReviewEntries(shipID: String) throws {
    var initial = Game(executive: false)
    try initial.commander.prepareEquipment(legacy: false)
    initial.screen = .status
    initial.key("6")
    initial.showroom.selection = shipID
    let ship = try #require(initial.showroomShip)
    try #require(ship.game != nil && OriginalDetailedHullStage.blocksRuntime(shipID))
    try #require(initial.shipTradeQuote == nil && !initial.showroom.trading)
    let commander = initial.commander
    let bodies = initial.bodies
    for width in [512.0, 1512] {
      for action in PendingOriginalTradeAction.allCases {
        var game = initial
        game.viewportWidth = width
        game.viewportHeight = 982
        let layout = ShowroomLayout(width: width, height: 982, detail: false)
        var frame = Frame()
        frame.rasterizeGraphics = false
        frame.canvas = .init(x: 0, y: 0, width: width, height: 982)
        Display.showroomTradeAction(game, layout: layout, into: &frame)
        let label = try #require(frame.labels.first { $0.text == "Original qualification pending" })
        #expect(label.bounds.maxX <= layout.trade.maxX)
        #expect(!frame.labels.contains { $0.text == "Display only - cannot fly" })
        switch action {
        case .shortcut:
          game.key("showroom-trade")
        case .detailReturn:
          game.showroom.detail = true
          game.key("return")
        case .pointer:
          game.showroomClick(x: layout.trade.x + 8, y: layout.trade.y + 8)
        }
        #expect(game.screen == .showroom && !game.showroom.trading && !game.showroom.confirmTrade)
        #expect(game.message == "ORIGINAL HULL QUALIFICATION PENDING")
        #expect(game.commander == commander && game.bodies == bodies)
        #expect(game.showroomShip == ship && game.shipTradeQuote == nil)
        #expect(game.showroom.sourceProfiles == initial.showroom.sourceProfiles)
        #expect(game.showroom.baselineUsesCurrent == initial.showroom.baselineUsesCurrent)
      }
    }
  }

  @Test(arguments: ["SH031", "SH013", "SH014"])
  func unblockedOriginalStillReviewsItsActualBlockedQuoteWithoutExchanging(shipID: String) throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.screen = .status
    game.key("6")
    game.showroom.selection = shipID
    let ship = try #require(game.showroomShip)
    try #require(ship.game != nil && !OriginalDetailedHullStage.blocksRuntime(shipID))
    let quote = try #require(game.shipTradeQuote)
    try #require(!quote.allowed)
    let commander = game.commander
    let bodies = game.bodies
    game.key("showroom-trade")
    #expect(game.showroom.trading && game.shipTradeQuote?.selected == ship)
    game.key("right")
    game.key("return")
    #expect(game.showroom.trading && game.commander == commander && game.bodies == bodies)
    game.key("escape")
    #expect(!game.showroom.trading && game.commander == commander)
  }

  @Test(arguments: ["SH028", "SH156", "SH162"])
  func actualDisplayOnlyObjectsKeepTheirExistingNonflyableEntry(shipID: String) throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.screen = .status
    game.key("6")
    game.showroom.selection = shipID
    try #require(game.showroomShip?.game == nil && game.shipTradeQuote == nil)
    let commander = game.commander
    let layout = ShowroomLayout(width: 512, height: 982, detail: false)
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 512, height: 982)
    Display.showroomTradeAction(game, layout: layout, into: &frame)
    #expect(frame.labels.contains { $0.text == "Display only - cannot fly" })
    game.key("showroom-trade")
    #expect(!game.showroom.trading && game.message == "THIS OBJECT IS NOT A FLYABLE HULL")
    #expect(game.commander == commander && game.shipTradeQuote == nil)
  }
}

private enum PendingOriginalTradeAction: CaseIterable {
  case shortcut, detailReturn, pointer
}
