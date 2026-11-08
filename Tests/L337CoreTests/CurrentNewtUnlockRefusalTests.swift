import Foundation
import Testing

@testable import L337Core

struct CurrentNewtUnlockRefusalTests {
  @Test
  func decodedFutureWorkCannotMoveAnActualAttachedKitAheadOfItsClock() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try #require(try releaseDamagedEMPBoundary(&game))
    let logical = try #require(game.bodies.first { $0.physical?.empSource != nil }?.physical?.empSource)
    try withEMPUnitWriter(&game) { game, publish, _ in
      for _ in 0..<320 {
        let record = try #require(game.commander.savedEMPState?.records[logical])
        let actual = try #require(record.hull.body.physical?.currentNewtKitStock)
        if let actuation = actual.actuation {
          let source = try #require(CurrentNewtKitSource.current)
          let now = game.commander.flightSimulation.physicalTime
          try #require(now < actuation.unlockAt && actual.interruptedAt == nil)
          #expect(source.matches(actual, at: now))
          let before = game
          var object = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(actual)) as? [String: Any])
          let future = source.work(at: actuation.unlockAt, actuation: actuation)
          object["work"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(future))
          object["charges"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            source.charges(at: now, actuation: actuation, work: future)))
          // Negative decoded evidence has a genuine original issue and matching
          // arithmetic balances, but no attained native lowering at this clock.
          let forged = try JSONDecoder().decode(CurrentNewtKitStock.self,
            from: JSONSerialization.data(withJSONObject: object))
          #expect(forged.structurallyValid)
          #expect(!source.matches(forged, at: now))
          #expect(game.commander == before.commander && game.bodies == before.bodies)
          #expect(game.time == before.time && game.nextBodyID == before.nextBodyID)
          return
        }
        try empUnitFrame(&game, publish: publish)
      }
      Issue.record("The genuine sampled mechanism did not start within its crew deadline")
    }
  }

  @Test
  func actualAllocatorRefusalAtUnlockKeepsCrewAndPaidWorkWhileTimeContinues() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try #require(try releaseDamagedEMPBoundary(&game))
    let disabledCandidate = game.bodies.first { $0.physical?.empSource != nil }
    let disabled = try #require(disabledCandidate)
    let logical = try #require(disabled.physical?.empSource)
    try withEMPUnitWriter(&game) { game, publish, _ in
      // Follow the genuine sampled delay through the existing native tick owner.
      var armed: CurrentNewtKitStock?
      for _ in 0..<320 {
        let record = try #require(game.commander.savedEMPState?.records[logical])
        let stock = try #require(record.hull.body.physical?.currentNewtKitStock)
        if stock.phase == .actuating {
          armed = stock
          break
        }
        try empUnitFrame(&game, publish: publish)
      }
      let actual = try #require(armed)
      let actuation = try #require(actual.actuation)
      try #require(game.commander.flightSimulation.physicalTime < actuation.unlockAt)
      let actorCounter = game.commander.flightSimulation.nextActor
      let issue = actual.issue
      // A negative boundary input exhausts the real allocator. It grants no pod,
      // person, source stock, request, pose or physical time.
      let availableBodyID = game.nextBodyID
      game.nextBodyID = Int.max
      for _ in 0..<4 {
        try empUnitFrame(&game, publish: publish)
      }
      let stoppedRecord = try #require(game.commander.savedEMPState?.records[logical])
      let stopped = try #require(stoppedRecord.hull.body.physical?.currentNewtKitStock)
      let source = try #require(CurrentNewtKitSource.current)
      #expect(stopped.issue == issue && stopped.phase == .actuating)
      #expect(stopped.interruptedAt == actuation.unlockAt && stopped.receipt == nil)
      #expect(stopped.work == source.work(at: actuation.unlockAt, actuation: actuation,
        interruptedAt: actuation.unlockAt))
      #expect(stoppedRecord.crewOutcome(ordinal: issue.person.ordinal) == .aboard)
      #expect(stoppedRecord.pods.isEmpty && stoppedRecord.crewAboard == stoppedRecord.crewTotal)
      #expect(game.commander.flightSimulation.nextActor == actorCounter)
      #expect(!game.bodies.contains { $0.physical?.currentNewtKitReceipt?.issue.kitID == issue.kitID })
      let time = game.commander.flightSimulation.physicalTime
      let guide = stopped.charges.guideMechanicalJoules
      let eject = stopped.charges.ejectionMechanicalJoules
      try empUnitFrame(&game, publish: publish)
      let later = try #require(game.commander.savedEMPState?.records[logical]?
        .hull.body.physical?.currentNewtKitStock)
      #expect(game.commander.flightSimulation.physicalTime == time + 0.1)
      #expect(later.work == stopped.work && later.interruptedAt == stopped.interruptedAt)
      #expect(later.charges.guideMechanicalJoules == guide)
      #expect(later.charges.ejectionMechanicalJoules == eject)
      #expect(later.charges.electricalJoules < stopped.charges.electricalJoules)
      #expect(later.issue == issue && later.receipt == nil)
      // End the negative allocator fault, then follow the existing real EMP
      // recovery deadline. Recovery restores ship power, never kit stores/work.
      game.nextBodyID = availableBodyID
      for _ in 0..<320 {
        if game.commander.savedEMPState?.records[logical]?.isRecovered == true { break }
        try empUnitFrame(&game, publish: publish)
      }
      let recovered = try #require(game.commander.savedEMPState?.records[logical])
      try #require(recovered.isRecovered && recovered.crewAboard == recovered.crewTotal)
      let binding = try #require(recovered.hull.binding)
      let ordinaryCandidate = game.bodies.first { $0.physical?.identity == binding }
      let ordinary = try #require(ordinaryCandidate)
      #expect(ordinary.physical?.empSource == nil)
      #expect(game.commander.npcPersistence.logicalIdentity(for: binding) == logical)
      let retained = try #require(ordinary.physical?.currentNewtKitStock)
      #expect(retained.issue == issue && retained.work == later.work)
      #expect(retained.interruptedAt == later.interruptedAt && retained.receipt == nil)
      #expect(retained.charges.guideMechanicalJoules == guide)
      #expect(retained.charges.ejectionMechanicalJoules == eject)
      let recoveryTime = game.commander.flightSimulation.physicalTime
      let ownedPreparationRequired1 = game.currentNewtMechanicalPlan(.init(
        start: recoveryTime, end: recoveryTime + 0.1))
      let coast = try #require(ownedPreparationRequired1)
      let containsMatch = coast.coasts.contains { $0.actor == binding }
      #expect(containsMatch)
      try empUnitFrame(&game, publish: publish)
      #expect(game.commander.flightSimulation.physicalTime == recoveryTime + 0.1)
      #expect(game.commander.savedEMPState?.records[logical]?.hull.body.physical?
        .currentNewtKitStock?.issue == issue)
    }
  }
}
