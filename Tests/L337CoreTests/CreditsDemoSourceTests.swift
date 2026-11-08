import Foundation
import Testing

@testable import L337Core

struct CreditsDemoSourceTests {
  @Test(arguments: [0.0, 2.0])
  func originalPresentationMeshesRenderWithoutNativeArchetypeFallbackOrWorldMutation(time: Double)
    throws
  {
    var game = Game(executive: false)
    game.screen = .demo
    game.time = time
    let commander = game.commander
    let bodies = game.bodies
    let flight = game.commander.flightSimulation
    let frame = Display.render(game, rasterizeGraphics: false, dashboard: false)
    #expect(!frame.shipPanels.isEmpty)
    #expect(frame.shipPanels.allSatisfy { panel in
      panel.vertices.count >= 3 && panel.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite }
    })
    #expect(game.commander == commander && game.bodies == bodies && game.time == time)
    #expect(game.commander.flightSimulation == flight && game.screen == .demo)
    #expect(game.commander.shipID == NewCommanderDefaults.shipID)
  }
}
