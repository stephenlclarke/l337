import Foundation
import Testing

@testable import L337Core

struct CurrentNewtNativeDriveTests {
  @Test
  func translatedAbsoluteClockRetainsItsActualStrokeRootConditioning() throws {
    let start = 86_400.0, h = 0.001, fraction = 0.5
    let q0 = 0.5995, derivative = 0.001
    let error = try #require(CurrentNewtNativeDriveCurve.strokeClockFractionError(
      start: start, duration: h, fraction: fraction))
    let time = start + fraction * h
    let observed = q0 + derivative * ((time - start) / h)
    let root = q0 + derivative * fraction
    #expect(abs(observed - root) <= derivative * error)
    #expect(error >= abs((time - start) / h - fraction))
    let nearZero = try #require(CurrentNewtNativeDriveCurve.strokeClockFractionError(
      start: 0, duration: h, fraction: fraction))
    #expect(error > nearZero)
  }

  @Test
  func realIssuedDriveReachesItsActualStopAndKeepsTheIndependentPodCoasting() throws {
    var game = try NativePeopleTestFixture.disabled()
    let logical = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[logical])
    let episode = try #require(original.disableEpisodes.last)
    let source = try #require(CurrentNewtKitSource.current)
    let issued = try #require(original.hull.body.physical?.currentNewtKitStock)
    let choiceCandidate = episode.ejections.first { $0.ordinal == issued.issue.person.ordinal }
    let choice = try #require(choiceCandidate)
    let due = episode.incident.physicalTime + choice.delay
    try #require(due + source.dropDuration < episode.deadline)
    while game.commander.flightSimulation.physicalTime < due {
      let before = game.commander.flightSimulation.physicalTime
      game.tick(delta: min(0.05, due - before))
      try #require(game.commander.flightSimulation.physicalTime > before)
    }
    var observedStop = false
    var observedContactBrake = false
    for _ in 0..<40 {
      let now = game.commander.flightSimulation.physicalTime
      let remaining = CurrentNewtMechanicalInterval(start: now, end: now + 0.05)
      let interval = CurrentNewtMechanicalInterval(start: now,
        end: game.nextCurrentNewtMechanicalEndpoint(in: remaining) ?? remaining.end)
      let ownedPreparationRequired1 = game.currentNewtMechanicalPlan(interval)
      let plan = try #require(ownedPreparationRequired1)
      for drive in plan.drives {
        let ownerCandidate = plan.owners.first { $0.parent == drive.parentActor }
        let owner = try #require(ownerCandidate)
        let curve = try #require(CurrentNewtNativeDriveCurve.make(plan: drive, stock: owner.stock))
        let contactTime = interval.start + (interval.end - interval.start) * 0.5
        if let incoming = curve.sample(at: contactTime), incoming.work.rodVelocity > 0 {
          let stopped = try #require(curve.interrupted(at: contactTime))
          #expect(stopped.sample.pod == incoming.pod)
          #expect(stopped.sample.parent.pose == incoming.parent.pose)
          #expect(stopped.sample.work.rodMetres == incoming.work.rodMetres)
          #expect(stopped.sample.work.rodVelocity == 0)
          #expect(stopped.sample.work.ejectionWorkJoules == incoming.work.ejectionWorkJoules)
          #expect(stopped.outcome.interruptedAt == contactTime)
          #expect(stopped.outcome.observedAt == interval.end)
          #expect(stopped.outcome.impulseOnPod == incoming.impulseOnPod)
          let p0 = try #require(CurrentNewtComponentMechanics.momentum(incoming.parentComponents,
            about: incoming.parent.pose.position))
          let p1 = try #require(CurrentNewtComponentMechanics.momentum(stopped.sample.parentComponents,
            about: incoming.parent.pose.position))
          #expect((p0.linearMomentum - p1.linearMomentum).length < 1e-6)
          #expect((p0.angularMomentum - p1.angularMomentum).length < 1e-6)
          #expect(p1.kineticEnergyJoules <= p0.kineticEnergyJoules + 1e-6)
          #expect(game.commander.savedEMPState?.records[logical]?.hull.body.physical?.currentNewtKitStock == owner.stock)
          observedContactBrake = true
        }
        let outcome = try #require(curve.outcome(at: interval.end))
        #expect(outcome.valid(for: drive))
        #expect(outcome.impulseOnPod.length <= drive.maximumForceNewtons * (interval.end - now) + 1e-6)
        if let stopTime = curve.rodStopTime {
          let incoming = try #require(curve.rodStopIncoming)
          let stopped = try #require(curve.rodStopAfter)
          #expect(stopTime > now && stopTime <= interval.end)
          #expect(incoming.work.rodMetres == source.stroke && incoming.work.rodVelocity > 0)
          #expect(stopped.work.rodMetres == source.stroke && stopped.work.rodVelocity == 0)
          #expect(stopped.parent.pose == incoming.parent.pose && stopped.pod == incoming.pod)
          #expect(stopped.work.ejectionWorkJoules == source.maximumForceNewtons * source.stroke)
          let before = try #require(CurrentNewtComponentMechanics.momentum(incoming.parentComponents,
            about: incoming.parent.pose.position))
          let after = try #require(CurrentNewtComponentMechanics.momentum(stopped.parentComponents,
            about: incoming.parent.pose.position))
          #expect((before.linearMomentum - after.linearMomentum).length < 1e-6)
          #expect((before.angularMomentum - after.angularMomentum).length < 1e-6)
          #expect(after.kineticEnergyJoules <= before.kineticEnergyJoules + 1e-6)
          let end = try #require(curve.sample(at: interval.end))
          #expect(end.work == stopped.work && end.impulseOnPod == stopped.impulseOnPod)
          if interval.end > stopTime {
            #expect((end.pod.pose.position - stopped.pod.pose.position).length > 0)
          }
          observedStop = true
        }
      }
      game.tick(delta: interval.end - interval.start)
      try #require(game.commander.flightSimulation.physicalTime == interval.end)
      let stock = try #require(game.commander.savedEMPState?.records[logical]?.hull.body.physical?.currentNewtKitStock)
      #expect(stock.issue == issued.issue && source.validWork(stock.work))
      if observedStop && stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0 { break }
    }
    #expect(observedStop)
    #expect(observedContactBrake)
    let final = try #require(game.commander.savedEMPState?.records[logical])
    #expect(final.crewAboard == 0 && final.pods.count == 1 && final.valid && game.commander.valid)
    #expect(final.pods[0].body.physical?.empCrewPod == issued.issue.person)
  }
}
