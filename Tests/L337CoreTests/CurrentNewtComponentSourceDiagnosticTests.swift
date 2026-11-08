import Foundation
import Testing

@testable import L337Core

struct CurrentNewtComponentSourceDiagnosticTests {
  @Test func componentPredicateEvidenceIsActorScopedAndRetainsCompleteText() {
    let diagnostic = GameplayEncounterBirthDiagnostic()
    let actor = ActorIdentity(system: .init(galaxy: 2, system: 49), visit: 1, entity: 6)
    let other = ActorIdentity(system: actor.system, visit: actor.visit, entity: 7)
    let complete = String(repeating: "actual-source-α", count: 1024)
    diagnostic.recordComponentSourceRefusal(actor: actor, detail: complete)
    diagnostic.recordComponentSourceRefusal(actor: other, detail: "other-query")
    #expect(diagnostic.componentSourceRefusal(actor: actor) == complete)
    #expect(diagnostic.componentSourceRefusal(actor: other) == "other-query")
    diagnostic.clearComponentSourceRefusal(actor: actor)
    #expect(diagnostic.componentSourceRefusal(actor: actor) == nil)
    #expect(diagnostic.componentSourceRefusal(actor: other) == "other-query")
    #expect(diagnostic.endpointRefusal == nil)
  }

  @Test(arguments: ["catalogue", "membership"])
  func actualSourceRefusalReportsItsFirstPredicateWithoutChangingTheOriginal(mode: String) throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyActualSourceRefusal(&game, mode: mode)
  }

  @inline(never)
  private func verifyActualSourceRefusal(_ game: inout Game, mode: String) throws {
    let originalCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let original = try #require(originalCandidate)
    let actor = try #require(original.physical?.identity)
    let stock = try #require(original.physical?.currentNewtKitStock)
    let commander = game.commander
    let bodies = game.bodies
    let diagnostic = GameplayEncounterBirthDiagnostic()
    game.nativeEncounterBirthDiagnostic = diagnostic
    diagnostic.recordComponentSourceRefusal(actor: actor, detail: "stale-previous-query")
    var changed = original
    let predicate: String
    if mode == "catalogue" {
      changed.physical?.catalogueShipID = "foreign-negative-input"
      predicate = "catalogue-birth-load"
    } else {
      changed.id = -1
      predicate = "current-body-membership"
    }
    do {
      _ = try game.currentNewtGeometryComponents(for: changed)
      Issue.record("Changed source unexpectedly passed the original validation")
    } catch let error as MissionNativeBridgeError {
      #expect(error == .invalidGeometry)
    }
    let detail = try #require(diagnostic.componentSourceRefusal(actor: actor))
    #expect(detail.contains("predicate=\(predicate)"))
    #expect(detail.contains("configuration=\(stock.issue.configuration)"))
    #expect(detail.contains("issueSHA=\(stock.issue.sourceSHA256)"))
    #expect(detail.contains("liveResources="))
    #expect(!detail.contains("stale-previous-query"))
    #expect(game.commander == commander && game.bodies == bodies)
    let actualParts = try game.currentNewtGeometryComponents(for: original)
    #expect(actualParts != nil)
    #expect(diagnostic.componentSourceRefusal(actor: actor) == nil)
    #expect(game.commander == commander && game.bodies == bodies)
  }
}
