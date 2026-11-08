import Foundation
import Testing

@testable import L337Core

struct CurrentNewtNativeImpactTests {
  @Test
  func aRealReleasedPodReturningToItsSpentRodsUsesNativeImpactAndTheRemainingCoast() throws {
    try returningPodImpact(partialStroke: false)
  }

  @Test
  func nativeContactDuringARealPaidPartialStrokeInterruptsOnlyTheActualForcePrefix() throws {
    try returningPodImpact(partialStroke: true)
  }

  @inline(never)
  private func returningPodImpact(partialStroke: Bool) throws {
    var game = try releasedGame(partialStroke: partialStroke)
    try verifyReturningPodImpact(&game, partialStroke: partialStroke)
  }

  @inline(never)
  private func verifyReturningPodImpact(_ game: inout Game, partialStroke: Bool) throws {
    let logical = try NativePeopleTestFixture.source(game)
    let source = try #require(CurrentNewtKitSource.current)
    let record = try #require(game.nativeMechanicalStoredEMPState()?.records[logical])
    let parentCandidate = game.bodies.firstIndex { $0.physical?.identity == record.hull.binding }
    let parent = try #require(parentCandidate)
    let podCandidate = game.bodies.firstIndex { $0.physical?.empCrewPod != nil }
    let pod = try #require(podCandidate)
    let stock = try #require(game.bodies[parent].physical?.currentNewtKitStock)
    let receipt = try #require(game.bodies[pod].physical?.currentNewtKitReceipt)
    try #require(stock.phase == .released && stock.receipt == receipt)
    if partialStroke {
      try #require(stock.work.rodMetres > 0 && stock.work.rodMetres < source.stroke)
      try #require(stock.work.rodVelocity > 0 && stock.interruptedAt == nil)
    } else {
      try #require(stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0)
    }
    let issue = stock.issue
    let person = receipt.issue.person
    let observer = game.storedFlightSimulation().pose
    let parentPose = game.modelPose(of: game.bodies[parent])
    // Controlled collision fixture after genuine birth, paid stroke and release.
    // Keep the same actor/person/hardware; only its actual free-body pose and
    // incoming velocity are selected, as in the owning rescue fixtures.
    game.bodies[parent].orientation = parentPose.orientation.relative(to: observer.orientation)
    game.bodies[parent].rotation = 0
    game.bodies[parent].rotationRate = 0
    game.bodies[parent].physical?.angularVelocity = .init(0, 0, 0)
    let parentVelocity = try #require(game.bodies[parent].physical?.velocity)
    let incoming =
      parentVelocity
      + parentPose.orientation.apply(source.direction * (stock.work.rodVelocity - 0.03))
    // Separate the two real shoe arrival times; coincident contact brackets
    // have no authored simultaneous response and must refuse independently.
    var podOrientation = parentPose.orientation
    podOrientation.rotate(pitch: 0, roll: 0, yaw: 0.0002)
    let podPose = ShipPose(
      position: parentPose.systemPoint(
        source.podOrigin + source.direction * (stock.work.rodMetres + 0.0005)),
      orientation: podOrientation)
    game.bodies[pod].position = observer.shipPoint(podPose.position)
    game.bodies[pod].orientation = podPose.orientation.relative(to: observer.orientation)
    game.bodies[pod].rotation = 0
    game.bodies[pod].rotationRate = 0
    game.bodies[pod].physical?.velocity = incoming
    game.bodies[pod].physical?.angularVelocity = .init(0, 0, 0)
    game.speed = 0
    let statePersisted = game.persistEMPState()
    try #require(statePersisted)
    let ownedPreparationRequired1 = game.currentOccupiedNewtPodHasCurrentCustody(game.bodies[pod])
    try #require(ownedPreparationRequired1)
    // Retain the same complete opening through the existing small CoW handle;
    // full Commander equality reads its actual storage without an inline copy.
    let beforeOpening = game
    let beforeBodies = game.bodies
    let parentActor = try #require(game.bodies[parent].physical?.identity)
    let ownedPreparationRequired2 = try game.currentNewtGeometryComponents(for: game.bodies[parent])
    let beforeParent = try #require(ownedPreparationRequired2)
    let ownedPreparationRequired3 = try game.currentNewtGeometryComponents(for: game.bodies[pod])
    let beforePod = try #require(ownedPreparationRequired3)
    let beforeMomentum = try #require(
      CurrentNewtComponentMechanics.momentum(
        beforeParent + beforePod,
        about: parentPose.position))
    let time = game.storedFlightSimulation().physicalTime
    let interval = CurrentNewtMechanicalInterval(start: time, end: time + 0.05)
    let player = HullSceneMotion(
      start: observer, end: observer,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: interval.end - interval.start, playerRadius: 0
    )
    let ownedPreparationRequired4 = game.beginCurrentNewtNativeSegment(
        interval, playerMotion: player,
        playerEnd: .init(pose: observer, velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0)))
    let opening = try #require(ownedPreparationRequired4)
    let ownedPreparationRequired5 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired5)
    let ownedPreparationRequired6 = game.prepareCurrentNewtNativeContact(opening: opening, mechanics: mechanics)
    let prepared = try #require(ownedPreparationRequired6)
    let originalPreparationUnchanged = game.currentNewtNativeCommanderMatches(beforeOpening) && game.bodies == beforeBodies
    #expect(originalPreparationUnchanged)
    let impacts = prepared.resolution.impacts
    try #require(!impacts.isEmpty)
    let allSatisfied = impacts.allSatisfy { $0.contactPhysicalTime > time && $0.contactPhysicalTime < interval.end }
    #expect(allSatisfied)
    let allSatisfied2 = impacts.allSatisfy { $0.impulse.damage > 0 && $0.impulse.transferred.length > 0 }
    #expect(allSatisfied2)
    let podActor = try #require(game.bodies[pod].physical?.identity)
    let allSatisfied3 = impacts.allSatisfy {
      ($0.sourceActor == parentActor && $0.targetActor == podActor)
        || ($0.sourceActor == podActor && $0.targetActor == parentActor)
    }
    #expect(allSatisfied3)
    let end = try #require(prepared.resolution.bodies[podActor])
    let parentEnd = try #require(prepared.resolution.bodies[parentActor])
    #expect((end.velocity - incoming).length > 1e-6)
    #expect((end.pose.position - podPose.position).length > 0)
    if partialStroke {
      try #require(impacts.count == 1)
      let impact = impacts[0]
      let frontier = interval.start + impact.contact.lowerTime
      let suffix = interval.end - frontier
      try #require(frontier > interval.start && suffix > 0)
      let driveCandidate = mechanics.drives.first { $0.issue.kitID == issue.kitID }
      let drive = try #require(driveCandidate)
      let ownerCandidate = mechanics.owners.first { $0.parent == parentActor }
      let owner = try #require(ownerCandidate)
      let curve = try #require(CurrentNewtNativeDriveCurve.make(plan: drive, stock: owner.stock))
      let normal =
        impact.sourceActor == parentActor ? impact.contact.normal : impact.contact.normal * -1
      let stopped = try #require(
        curve.rodImpact(at: frontier, point: impact.contact.point, normal: normal))
      #expect(stopped.outcome.interruptedAt == frontier)
      #expect(prepared.resolution.stoppedAt[parentActor] == frontier)
      let mass = try #require(source.loadedParentMass(work: stopped.sample.work, load: drive.load))
      let parentFlow = try #require(
        CurrentNewtRigidCoast(
          initial: stopped.sample.parent,
          mass: mass, duration: suffix, maximumAngularSpeed: source.maximumAngularSpeed))
      let podFlow = try #require(
        CurrentNewtRigidCoast(
          initial: stopped.sample.pod,
          mass: source.podMass, duration: suffix, maximumAngularSpeed: source.maximumAngularSpeed))
      #expect(source.matchesState(try #require(parentFlow.state(at: suffix)), parentEnd))
      #expect(source.matchesState(try #require(podFlow.state(at: suffix)), end))
      for (initial, final, properties) in [
        (stopped.sample.parent, parentEnd, mass),
        (stopped.sample.pod, end, source.podMass),
      ] {
        let a = CurrentNewtKitMass.centre(properties, state: initial)
        let b = CurrentNewtKitMass.centre(properties, state: final)
        let displacement = CurrentNewtKitMass.centreVelocity(properties, state: initial) * suffix
        let error = 512 * Double.ulpOfOne * max(1, a.length + b.length + displacement.length)
        #expect((b - a - displacement).length <= error)
      }
      // Same real actors, archive, time and work; array order grants no choice
      // of damage victim or attack origin. No second kit/body is fabricated.
      var reordered = game
      reordered.bodies.reverse()
      let ownedPreparationRequired7 = reordered.beginCurrentNewtNativeSegment(
          interval,
          playerMotion: player, playerEnd: opening.playerEnd)
      let reversedOpening = try #require(ownedPreparationRequired7)
      let ownedPreparationRequired8 = reordered.currentNewtMechanicalPlan(interval)
      let reversedMechanics = try #require(ownedPreparationRequired8)
      let ownedPreparationRequired9 = reordered.prepareCurrentNewtNativeContact(
          opening: reversedOpening, mechanics: reversedMechanics)
      let reverse = try #require(ownedPreparationRequired9)
      #expect(reverse.resolution.impacts.count == impacts.count)
      let allSatisfied4 = zip(reverse.resolution.impacts, impacts).allSatisfy {
        $0.0.sourceActor == $0.1.sourceActor && $0.0.targetActor == $0.1.targetActor
      }
      #expect(allSatisfied4)
      let receipts = try consequenceReceipts(prepared)
      let reversedReceipts = try consequenceReceipts(reverse)
      #expect(receipts.count == reversedReceipts.count)
      let allSatisfied5 = zip(receipts, reversedReceipts).allSatisfy {
        $0.0.source == $0.1.source && $0.0.target == $0.1.target
          && $0.0.incident == $0.1.incident && $0.0.damage == $0.1.damage
          && $0.0.transferredMomentum == $0.1.transferredMomentum
      }
      #expect(allSatisfied5)
    }
    let beforeHealth = game.bodies.filter {
      $0.physical?.identity == parentActor || $0.physical?.identity == podActor
    }.reduce(0) { $0 + $1.energy }
    game.tick(delta: interval.end - interval.start)
    let ownedStartupCheck1 = game.storedFlightSimulation().physicalTime == interval.end
    #expect(ownedStartupCheck1)
    let actualCandidate = game.bodies.first { $0.physical?.identity == podActor }
    let actual = try #require(actualCandidate)
    let afterHealth = game.bodies.filter {
      $0.physical?.identity == parentActor || $0.physical?.identity == podActor
    }.reduce(0) { $0 + $1.energy }
    #expect(afterHealth < beforeHealth)
    let ownedStartupCheck2 = source.matchesState(game.currentNewtBodyState(actual), end)
    #expect(ownedStartupCheck2)
    #expect(
      actual.physical?.currentNewtKitReceipt == receipt && actual.physical?.empCrewPod == person)
    let after = try #require(game.nativeMechanicalStoredEMPState()?.records[logical])
    #expect(after.hull.body.physical?.currentNewtKitStock?.issue == issue)
    let finalStock = try #require(after.hull.body.physical?.currentNewtKitStock)
    if partialStroke {
      let outcomeCandidate = prepared.resolution.drives.first { $0.kitID == issue.kitID }
      let outcome = try #require(outcomeCandidate)
      let stopped = try #require(finalStock.interruptedAt)
      #expect(stopped >= time && stopped < interval.end)
      #expect(finalStock.work == outcome.work && finalStock.work.rodVelocity == 0)
      #expect(
        finalStock.work.rodMetres >= stock.work.rodMetres
          && finalStock.work.rodMetres < source.stroke)
      #expect(
        finalStock.work.ejectionWorkJoules == source.maximumForceNewtons * finalStock.work.rodMetres
      )
    } else {
      #expect(finalStock.work == stock.work)
    }
    let retainedParentCandidate = game.bodies.first { $0.physical?.identity == parentActor }
    let retainedParent = try #require(retainedParentCandidate)
    let ownedStartupCheck3 = source.matchesState(game.currentNewtBodyState(retainedParent), parentEnd)
    #expect(ownedStartupCheck3)
    let ownedPreparationRequired10 = try game.currentNewtGeometryComponents(for: retainedParent)
    let afterParent = try #require(ownedPreparationRequired10)
    let ownedPreparationRequired11 = try game.currentNewtGeometryComponents(for: actual)
    let afterPod = try #require(ownedPreparationRequired11)
    let afterMomentum = try #require(
      CurrentNewtComponentMechanics.momentum(
        afterParent + afterPod,
        about: parentPose.position))
    #expect(
      (beforeMomentum.linearMomentum - afterMomentum.linearMomentum).length
        <= 1e-8 * max(1, beforeMomentum.linearMomentum.length))
    #expect(
      (beforeMomentum.angularMomentum - afterMomentum.angularMomentum).length
        <= 1e-8 * max(1, beforeMomentum.angularMomentum.length))
    let paid = finalStock.work.ejectionWorkJoules - stock.work.ejectionWorkJoules
    #expect(
      afterMomentum.kineticEnergyJoules <= beforeMomentum.kineticEnergyJoules + paid
        + 1e-8 * max(1, beforeMomentum.kineticEnergyJoules))
    let ownedStartupCheck4 = after.crewAboard == 0 && after.pods.count == 1 && after.valid && game.commander.valid
    #expect(ownedStartupCheck4)
  }

  @inline(never)
  private func releasedGame(partialStroke: Bool) throws -> Game {
    var game = try NativePeopleTestFixture.disabled()
    return try releasePeopleGame(&game, partialStroke: partialStroke)
  }

  @inline(never)
  private func releasePeopleGame(_ game: inout Game, partialStroke: Bool) throws -> Game {
    let logical = try NativePeopleTestFixture.source(game)
    if !partialStroke {
      try ejectScheduledEMPCrewBoundary(&game, source: logical)
      return game
    }
    let record = try #require(game.nativeMechanicalStoredEMPState()?.records[logical])
    let stock = try #require(record.hull.body.physical?.currentNewtKitStock)
    let episode = try #require(record.disableEpisodes.last)
    let choiceCandidate = episode.ejections.first { $0.ordinal == stock.issue.person.ordinal }
    let choice = try #require(choiceCandidate)
    let due = episode.incident.physicalTime + choice.delay
    while game.storedFlightSimulation().physicalTime < due {
      let before = game.storedFlightSimulation().physicalTime
      game.tick(delta: min(0.05, due - before))
      let ownedStartupCheck5 = game.storedFlightSimulation().physicalTime > before
      try #require(ownedStartupCheck5)
    }
    // Same bounded native leg horizon as the owning drive test. No sampled
    // delay, stock phase, person, work or physical clock is written by the test.
    for _ in 0..<40 {
      let actual = try #require(
        game.nativeMechanicalStoredEMPState()?.records[logical]?.hull.body.physical?.currentNewtKitStock)
      if actual.phase == .released, actual.work.rodMetres > 0,
        let source = CurrentNewtKitSource.current, actual.work.rodMetres < source.stroke,
        actual.work.rodVelocity > 0, actual.interruptedAt == nil
      {
        return game
      }
      let now = game.storedFlightSimulation().physicalTime
      let remaining = CurrentNewtMechanicalInterval(start: now, end: now + 0.05)
      let end = game.nextCurrentNewtMechanicalEndpoint(in: remaining) ?? remaining.end
      game.tick(delta: end - now)
      let ownedStartupCheck6 = game.storedFlightSimulation().physicalTime == end
      try #require(ownedStartupCheck6)
    }
    try #require(false, "No real accepted partial-stroke frontier in the existing owning horizon")
    return game
  }

  private func consequenceReceipts(_ prepared: CurrentNewtPreparedNativeContact) throws
    -> [AsteroidImpactReceipt]
  {
    var candidate = prepared.motion.proposed
    var receipts: [AsteroidImpactReceipt] = []
    for impact in prepared.resolution.impacts {
      let impactReceiptCandidate = candidate.applyNativeDebrisContactEffect(
        contact: impact.contact, impulse: impact.impulse, sourceID: impact.sourceID,
        sourceActor: impact.sourceActor, targetID: impact.targetID,
        targetActor: impact.targetActor,
        playerPose: impact.playerPose, sourcePose: impact.sourcePose,
        targetPose: impact.targetPose,
        contactPhysicalTime: impact.contactPhysicalTime, captureClockEffect: true)
      receipts.append(
        try #require(impactReceiptCandidate))
    }
    return receipts
  }
}

extension CurrentNewtNativeImpactTests {
  @Test func aRealLaterContactRefusalRetainsOnlyTheAttainedMechanicalPrefix() throws {
    var game = try releasedGame(partialStroke: true)
    let logical = try NativePeopleTestFixture.source(game)
    let initial = try #require(
      game.commander.savedEMPState?.records[logical]?
        .hull.body.physical?.currentNewtKitStock)
    let actuation = try #require(initial.actuation)
    let boundary = actuation.completeAt
    let targetTime = boundary - 0.025
    try #require(game.commander.flightSimulation.physicalTime < targetTime)
    // Reach this real source frontier through the actual native owner. Neither
    // stock work, the sampled delay nor physical time is written by this test.
    while game.commander.flightSimulation.physicalTime < targetTime {
      let now = game.commander.flightSimulation.physicalTime
      game.tick(delta: min(0.05, targetTime - now))
      try #require(game.commander.flightSimulation.physicalTime > now && !game.paused)
    }
    let parentCandidate2 = game.bodies.firstIndex { $0.physical?.currentNewtKitStock != nil }
    let parent = try #require(parentCandidate2)
    let podCandidate2 = game.bodies.firstIndex { $0.physical?.empCrewPod != nil }
    let pod = try #require(podCandidate2)
    let stock = try #require(game.bodies[parent].physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.current)
    try #require(stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0)
    let camera = game.commander.flightSimulation.pose
    let pose = game.modelPose(of: game.bodies[parent])
    game.bodies[parent].orientation = pose.orientation.relative(to: camera.orientation)
    game.bodies[parent].rotation = 0
    game.bodies[parent].rotationRate = 0
    game.bodies[parent].physical?.angularVelocity = .init(0, 0, 0)
    var axes = pose.orientation
    axes.rotate(pitch: 0, roll: 0, yaw: 0.0002)
    let returning = ShipPose(
      position: pose.systemPoint(
        source.podOrigin + source.direction * (source.stroke + 0.0018)), orientation: axes)
    game.bodies[pod].position = camera.shipPoint(returning.position)
    game.bodies[pod].orientation = axes.relative(to: camera.orientation)
    game.bodies[pod].rotation = 0
    game.bodies[pod].rotationRate = 0
    let velocity = try #require(game.bodies[parent].physical?.velocity)
    game.bodies[pod].physical?.velocity =
      velocity + pose.orientation.apply(source.direction * -0.03)
    game.bodies[pod].physical?.angularVelocity = .init(0, 0, 0)
    game.speed = 0
    let statePersisted2 = game.persistEMPState()
    try #require(statePersisted2)
    let now = game.commander.flightSimulation.physicalTime
    let interval = CurrentNewtMechanicalInterval(start: now, end: now + 0.1)
    let ownedPreparationRequired12 = game.nextCurrentNewtMechanicalEndpoint(in: interval) == boundary
    try #require(ownedPreparationRequired12)
    // Negative allocator pressure on an otherwise genuine collision. The
    // first clear leg needs no incident; the later impact cannot publish one.
    var raw = try #require(
      JSONSerialization.jsonObject(
        with: JSONEncoder().encode(game.commander.flightSimulation)) as? [String: Any])
    raw["nextIncident"] = NSNumber(value: UInt64.max - 1)
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self,
      from: JSONSerialization.data(withJSONObject: raw))
    try #require(game.commander.flightSimulation.valid)
    let opening = game.commander.flightSimulation
    let header = game.commander.savedPlayerElectrical
    let equipment = game.commander.equipmentInventory
    let charges = game.commander.savedEMPCharge
    let audio = game.dischargeAudio.events
    let time = game.time
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.1, controls: held)
    #expect(game.paused)
    #expect(game.commander.flightSimulation.physicalTime == boundary)
    #expect(boundary > now && boundary < interval.end)
    #expect(abs(game.time - time - (boundary - now)) < 1e-9)
    #expect(game.commander.flightSimulation.nextIncident == opening.nextIncident)
    #expect(game.commander.savedPlayerElectrical == header)
    #expect(game.commander.equipmentInventory == equipment)
    #expect(game.commander.savedEMPCharge == charges && game.dischargeAudio.events == audio)
    let actual = try #require(
      game.commander.savedEMPState?.records[logical]?
        .hull.body.physical?.currentNewtKitStock)
    #expect(
      actual.issue == stock.issue && actual.work == stock.work && actual.observedAt == boundary)
    #expect(actual.receipt == stock.receipt)
  }
}
