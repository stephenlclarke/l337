import Foundation
import Testing

@testable import L337Core

struct SelectedLegacyNPCBeamBirthTests {
  @Test
  func realMidLegPodBirthOccludesTheSelectedBeamExactlyOnceInItsRetainedPhase() throws {
    var game = try NativePeopleTestFixture.disabled()
    try verifyRealMidLegPodOcclusion(&game)
  }

  @inline(never)
  private func verifyRealMidLegPodOcclusion(_ game: inout Game) throws {
    let logical = try NativePeopleTestFixture.source(game)
    let physical = try #require(CurrentNewtKitSource.current)
    let ownedBeamRequired1 = game.commander.savedEMPState?.records[logical]
    let record = try #require(ownedBeamRequired1)
    let stock = try #require(record.hull.body.physical?.currentNewtKitStock)
    try #require(stock.phase == .stowed)
    let episode = try #require(record.disableEpisodes.last)
    let ejectionCandidate = episode.ejections.first { $0.ordinal == stock.issue.person.ordinal }
    let ejection = try #require(ejectionCandidate)
    let due = episode.incident.physicalTime + ejection.delay
    let beforeUnlock = due + physical.dropDuration - 0.02
    let ownedBeamRequired2 = beforeUnlock > game.storedFlightSimulation().physicalTime
    try #require(ownedBeamRequired2)

    // Place the genuinely born stowed assembly before its real actuation begins.
    // +X points towards the later emitter, so the portable enclosure is in front
    // of the parent along the beam. Hardware, person, stock and clock stay real.
    let emitterStart = Vector3(0, 0, 1400)
    let emitter = try selectedLegacyBeamEmitter(id: 91_002, position: emitterStart)
    let emitterEnd = LegacyNPCFlightDecision.ordinaryPosition(emitterStart, maximumSpeed: emitter.nativeNavalCombat?.speed, delta: 0.05)
    let aim = Game.nativePlayerSurfaceAim(from: emitterEnd, mesh: game.commander.playerMesh)
    let desiredPod = emitterEnd + (aim - emitterEnd) * 0.6
    var orientation = Basis3()
    orientation.x = .init(0, 0, 1)
    orientation.y = .init(0, 1, 0)
    orientation.z = .init(-1, 0, 0)
    let parentCandidate = game.bodies.firstIndex { $0.physical?.identity == record.hull.binding }
    let parent = try #require(parentCandidate)
    game.bodies[parent].position = desiredPod - orientation.apply(physical.podOrigin)
    game.bodies[parent].orientation = orientation
    game.bodies[parent].rotation = 0
    game.bodies[parent].rotationRate = 0
    game.bodies[parent].physical?.velocity = .init(0, 0, 0)
    game.bodies[parent].physical?.angularVelocity = .init(0, 0, 0)
    game.speed = 0
    game.autoPilot.setApproachVelocity(.init(0, 0, 0))
    let statePersisted = game.persistEMPState()
    try #require(statePersisted)
    while game.storedFlightSimulation().physicalTime < beforeUnlock {
      let oldTime = game.storedFlightSimulation().physicalTime
      game.tick(delta: min(0.05, beforeUnlock - oldTime))
      let ownedBeamRequired3 = game.storedFlightSimulation().physicalTime > oldTime
      try #require(ownedBeamRequired3)
    }
    let ownedBeamRequired4 = game.commander.savedEMPState?.records[logical]?.hull.body.physical?.currentNewtKitStock
    let active = try #require(ownedBeamRequired4)
    try #require(active.issue == stock.issue && active.phase == .actuating)
    let actuation = try #require(active.actuation)
    let start = game.storedFlightSimulation().physicalTime
    try #require(actuation.unlockAt > start && actuation.unlockAt < start + 0.05)
    let allSatisfied = game.bodies.allSatisfy { $0.physical?.currentNewtKitReceipt == nil }
    try #require(allSatisfied)

    // The emitter is an ordinary controlled legacy actor, allocated by the
    // existing physical producer only after the real pre-unlock clock frontier.
    game.bodies.append(emitter)
    game.ensurePhysicalActors()
    let ownedBeamRequired5 = game.bodies.first { $0.id == 91_002 }?.physical?.identity
    let owner = try #require(ownedBeamRequired5)
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate)
    var frameRefusal: CurrentNewtPreparationRefusal? = nil
    let frameCandidate = game.prepareCurrentNewtNPCFrame(path, report: {
      if frameRefusal == nil { frameRefusal = $0 }
    })
    let frameReason = frameRefusal?.summary ?? "NPC frame refusal checkpoint missing (instrumentation incomplete)"
    let frame = try #require(frameCandidate, Comment(rawValue: frameReason))
    let geometry = try game.prepareSelectedNPCBeamGeometry(for: path)
    let planCandidate = game.prepareSelectedLegacyNPCBeam(
      entry: try #require(frame.entries[owner]), geometry: geometry)
    let plan = try #require(planCandidate)
    let interval = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame)
    let evidence = try #require(interval.evidence)
    try #require(evidence.completedOuterInterval)
    let podCandidate = game.bodies.first { $0.physical?.currentNewtKitReceipt?.issue == stock.issue }
    let pod = try #require(podCandidate)
    let receipt = try #require(pod.physical?.currentNewtKitReceipt)
    let actor = try #require(pod.physical?.identity)
    #expect(receipt.releasedAt == actuation.unlockAt && receipt.releasedAt > start)
    let allSatisfied2 = geometry.openingBodies.allSatisfy { $0.physical?.identity != actor }
    #expect(allSatisfied2)
    let ownedBeamExpected6 = game.storedFlightSimulation().physicalTime == path.endTime
    #expect(ownedBeamExpected6)
    let parts = try #require(evidence.selectedLegacyBeamComponents(
      geometry: geometry, source: owner, current: game))
    let parentActor = try #require(record.hull.binding)
    let parentParts = try #require(parts[parentActor])
    let podParts = try #require(parts[actor])
    let portableIDs = Set(physical.releasedParts.map(\.id))
    #expect(Set(parentParts.map(\.id)).isDisjoint(with: portableIDs))
    #expect(Set(podParts.map(\.id)) == portableIDs)
    let ownedBeamRequired7 = game.bodies.first {
      $0.physical?.identity == parentActor
    }?.physical?.currentNewtKitStock
    let retainedStock = try #require(ownedBeamRequired7)
    #expect(retainedStock.receipt == receipt && retainedStock.remaining == 0)
    #expect(retainedStock.work.guideWorkJoules == physical.dropWork)
    var foreign = game
    let podIndexCandidate = foreign.bodies.firstIndex { $0.physical?.identity == actor }
    let podIndex = try #require(podIndexCandidate)
    foreign.bodies[podIndex].physical?.currentNewtKitReceipt = nil
    let ownedBeamExpected8 = foreign.querySelectedLegacyNPCBeam(plan, evidence: evidence) == nil
    #expect(ownedBeamExpected8)
    let ownedBeamRequired9 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let query = try #require(ownedBeamRequired9)
    let contact = try #require(query.contact)
    #expect(contact.hit.target == .body(pod.id))
    #expect(contact.selectedTargetBody?.physical?.currentNewtKitReceipt == receipt)
    let before = game.storedFlightSimulation()
    // Occupied crew pods retain the existing damage immunity. This proves
    // the real birth, native occlusion and incident, not hull damage or death.
    let health = pod.energy
    let originCandidate = game.makeAttackOrigin(owner: owner)
    let origin = try #require(originCandidate)
    let afterEmission = game.storedFlightSimulation()
    let effectCandidate = game.applySelectedNativeNPCBeamHit(contact, origin: origin,
      damage: 1, emissionPosition: query.launch, evidence: evidence)
    let effect = try #require(effectCandidate)
    let ownedBeamExpected10 = effect.applying(to: afterEmission) == game.storedFlightSimulation()
    #expect(ownedBeamExpected10)
    let ownedBeamExpected11 = game.storedFlightSimulation().physicalTime == before.physicalTime
    #expect(ownedBeamExpected11)
    #expect(effect.incident.victim == actor && effect.incident.origin.owner == owner)
    let ownedBeamExpected12 = game.bodies.first { $0.physical?.identity == actor }?.energy == health
    #expect(ownedBeamExpected12)
    let ownedBeamExpected13 = game.bodies.filter { $0.physical?.empCrewPod == stock.issue.person }.count == 1
    #expect(ownedBeamExpected13)
    let ownedBeamExpected14 = game.bodies.first { $0.physical?.identity == actor }?.physical?.currentNewtKitReceipt == receipt
    #expect(ownedBeamExpected14)
  }
}
