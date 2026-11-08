import Foundation
import Testing

@testable import L337Core

struct SelectedLegacyNPCBeamDirectorBirthTests {
  @Test
  func realLaterDirectorBirthAcceptsBothOrderedBeamHitsAgainstCurrentResources() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let firstCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let first = try #require(firstCandidate)
    let firstActor = try #require(first.physical?.identity)
    let firstIssue = try #require(first.physical?.currentNewtKitStock?.issue)
    let ownedBeamRequired1 = game.commander.encounterDirector
    let initialDirector = try #require(ownedBeamRequired1)
    try #require(initialDirector.decisionCount == 2)
    let ownedBeamRequired2 = game.commander.galaxy == 0 && game.commander.system == 2
    try #require(ownedBeamRequired2)
    let ownedBeamRequired3 = game.commander.flightSimulation.visit == 1
    try #require(ownedBeamRequired3)
    let firstTime = game.commander.flightSimulation.physicalTime
    let ownedBeamRequired4 = game.commander.flightSimulation.anchors
    let anchors = try #require(ownedBeamRequired4)
    let heading = (anchors.station.position - anchors.arrival).unit
    let up = abs(heading.y) < 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0)
    var camera = Basis3()
    // Observe across the trade lane. The first real trader travels laterally
    // away from the later arrival, rather than through the observer or beam.
    camera.z = heading.cross(up).unit
    camera.x = up.cross(camera.z).unit
    camera.y = camera.z.cross(camera.x).unit
    NativePagedSalvageFixture.moveObserver(&game, to: .init(
      position: anchors.arrival - camera.z * 210 - camera.y * 3,
      orientation: camera))
    game.speed = 0
    game.autoPilot.setApproachVelocity(.init(0, 0, 0))
    let ownedBeamRequired5 = game.gameplayContext()
    let context = try #require(ownedBeamRequired5)
    try #require(context.seed == 268890839879961 && context.government == 6)
    try #require(EncounterGeography.region(
      at: context.player.position, anchors: context.anchors) == .tradeLane)
    try #require(EncounterGeography.safe(
      anchors.arrival, context: context, civilianEntry: true))

    // Existing controlled opening-emitter fixture pattern: only the real
    // physical allocator issues source identities. Neither source is a T1
    // birth and neither supplies a target, contact or birth capability.
    game.bodies.append(try selectedLegacyBeamEmitter(id: 91_005, position: .init(-3000, 0, 5000)))
    game.bodies.append(try selectedLegacyBeamEmitter(id: 91_006, position: .init(3000, 0, 6000)))
    game.ensurePhysicalActors()
    let owners = try [91_005, 91_006].map { id in
      let ownedBeamRequired6 = game.bodies.first { $0.id == id }?.physical?.identity
      return try #require(ownedBeamRequired6)
    }
    let history = game.commander.equipmentPurchaseHistory
    try withEMPUnitWriter(&game) { scene, publish, _ in
      var frames = 0
      // Read the genuine director deadline after real decision 3. No deadline,
      // seed, request, physical time or decision count is rewritten or replayed.
      while true {
        let ownedBeamRequired7 = scene.commander.encounterDirector
        let director = try #require(ownedBeamRequired7)
        let time = scene.commander.flightSimulation.physicalTime
        if director.decisionCount == 3 && time + 0.1 >= director.nextDecisionTime { break }
        try #require(director.decisionCount < 4 && frames < 799)
        let ownedBeamRequired8 = scene.hasCurrentNewtNativeScene
        try #require(ownedBeamRequired8)
        try empUnitFrame(&scene, publish: publish)
        frames += 1
      }
      let ownedBeamRequired9 = scene.commander.encounterDirector
      let openingDirector = try #require(ownedBeamRequired9)
      let ownedBeamRequired10 = scene.commander.flightSimulation.player
      let player = try #require(ownedBeamRequired10)
      let emitters = [Vector3(100, 0, 1200), Vector3(250, 0, 1400)]
      let emitterSource = try selectedLegacyBeamEmitter(id: 91_005, position: emitters[0])
      let crossings = emitters.map { emitter in
        let end = LegacyNPCFlightDecision.ordinaryPosition(
          emitter, maximumSpeed: emitterSource.nativeNavalCombat?.speed, delta: 0.1)
        let aim = Game.nativePlayerSurfaceAim(from: end, mesh: scene.commander.playerMesh)
        return end + (aim - end) * ((210 - end.z) / (aim.z - end.z))
      }
      // Both genuine native rays approach the same player surface. Frame the
      // later fixed arrival through the existing SH029 lower carrier solid
      // (model y=-3), with its long axis across the two rays. No ray result,
      // target pose, collision component or hit is injected.
      try #require(abs(crossings[0].x - crossings[1].x) < 24)
      try #require(abs(crossings[0].y - crossings[1].y) < 2)
      let focus = (crossings[0] + crossings[1]) * 0.5
      NativePagedSalvageFixture.moveObserver(&scene, to: .init(
        position: anchors.arrival - camera.apply(.init(focus.x, focus.y + 3, 210)),
        orientation: camera))
      for (ordinal, owner) in owners.enumerated() {
        let indexCandidate = scene.bodies.firstIndex { $0.physical?.identity == owner }
        let index = try #require(indexCandidate)
        // Retain the same allocated sources. Arrange their controlled geometry
        // before this tick captures its real T0 scene, then leave it untouched.
        scene.bodies[index].position = emitters[ordinal]
        let ownedBeamRequired11 = scene.bodies[index].energy > 0 && !scene.isEMPDisabled(scene.bodies[index])
        try #require(ownedBeamRequired11)
        let ownedBeamRequired12 = scene.bodies[index].scriptNPC == nil
        try #require(ownedBeamRequired12)
        let ownedBeamRequired13 = scene.bodies[index].nativeNavalCombat == nil
        try #require(ownedBeamRequired13)
        let ownedBeamRequired14 = scene.bodies[index].physical?.npc?.intention == .engage(player)
        try #require(ownedBeamRequired14)
      }
      let opening = scene.commander.flightSimulation
      let present = Set(scene.bodies.compactMap { $0.physical?.identity })
      let allSatisfied = present.contains(firstActor) && owners.allSatisfy(present.contains)
      try #require(allSatisfied)
      let ownedBeamRequired15 = scene.bodies.first { $0.physical?.identity == firstActor }?
        .physical?.currentNewtKitStock?.issue == firstIssue
      try #require(ownedBeamRequired15)
      let ownedBeamRequired16 = scene.hasCurrentNewtNativeScene && openingDirector.decisionCount == 3
      try #require(ownedBeamRequired16)
      try #require(opening.physicalTime < openingDirector.nextDecisionTime)
      try #require(opening.physicalTime + 0.1 >= openingDirector.nextDecisionTime)
      let ownedBeamRequired17 = scene.gameplayContext()
      let liveContext = try #require(ownedBeamRequired17)
      try #require(EncounterGeography.region(
        at: liveContext.player.position, anchors: liveContext.anchors) == .tradeLane)
      try #require(EncounterGeography.safe(
        anchors.arrival, context: liveContext, civilianEntry: true))
      scene.gameplayCombatTrace = .init()
      try empUnitFrame(&scene, publish: publish)
      frames += 1
      let end = scene.commander.flightSimulation
      let ownedBeamRequired18 = scene.commander.encounterDirector
      let director = try #require(ownedBeamRequired18)
      try #require(director.decisionCount == 4 && director.admittedCount > openingDirector.admittedCount)
      let newbornCandidate = scene.bodies.first { body in
        guard let physical = body.physical else { return false }
        return !present.contains(physical.identity) && physical.catalogueShipID == "SH029"
          && physical.currentNewtKitStock != nil
      }
      let newborn = try #require(newbornCandidate)
      let physical = try #require(newborn.physical)
      let spawn = try #require(physical.spawnIdentity)
      let stock = try #require(physical.currentNewtKitStock)
      let source = try #require(CurrentNewtKitSource.current)
      try #require(physical.empCrewPod == nil && newborn.scriptNPC == nil)
      #expect(spawn.producer == .ambient && spawn.sequence == director.decisionCount)
      #expect(spawn.system == end.system && spawn.visit == end.visit)
      #expect(!director.pendingRequests.contains { $0.identity == spawn })
      #expect(stock.issue.birthActor == physical.identity && stock.issue.birthSpawn == spawn)
      #expect(stock.issue.person == .init(source: physical.identity, ordinal: 0))
      #expect(stock.issue.personProfile == source.personProfile)
      #expect(stock.issue.issuedAt == end.physicalTime && stock.observedAt == end.physicalTime)
      #expect(source.matches(stock, at: end.physicalTime))
      #expect(stock.phase == .stowed && stock.actuation == nil && stock.receipt == nil)
      #expect(stock.remaining == 1 && stock.work.guideWorkJoules == 0)
      // The actual newly admitted parent's model and velocity have zero prior
      // lifetime, while two later source turns consume its real shield charge.
      let ownedBeamExpected19 = (scene.modelPose(of: newborn).position - anchors.arrival).length < 1e-7
      #expect(ownedBeamExpected19)
      let ownedBeamExpected20 = (scene.modelPose(of: newborn).orientation.z - heading).length < 1e-7
      #expect(ownedBeamExpected20)
      #expect((physical.velocity - heading * 60).length < 1e-7)
      #expect(physical.angularVelocity == .init(0, 0, 0))
      #expect(newborn.rotation == 0 && newborn.rotationRate == 0 && physical.laserCooldown == 0)
      let ownedBeamRequired21 = scene.gameplayCombatTrace?.incidents
      let incidents = try #require(ownedBeamRequired21)
      let hits = incidents.filter { owners.contains($0.origin.owner) }
      try #require(hits.count == 2)
      #expect(hits.map { $0.origin.owner } == owners)
      let allSatisfied2 = hits.allSatisfy {
        $0.victim == physical.identity && $0.kind == .laser && $0.outcome == .hit
          && $0.physicalTime == end.physicalTime && $0.origin.emittedAt == end.physicalTime
      }
      #expect(allSatisfied2)
      #expect(hits[0].id < hits[1].id)
      let performance = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029")?.performance)
      let full = try #require(NPCResources.stock(performance))
      let resources = try #require(physical.npc?.resources)
      #expect(resources.frontCapacity == full.frontCapacity && resources.rearCapacity == full.rearCapacity)
      #expect(resources.energyCapacity == full.energyCapacity)
      let perBeam = 0.1 * 6 * 2
      #expect(abs(resources.frontShield + resources.rearShield
        - (full.frontShield + full.rearShield - 2 * perBeam)) < 1e-9)
      #expect(newborn.energy == performance.energy)
      #expect(end.physicalTime == opening.physicalTime + 0.1)
      #expect(frames <= 214 && end.physicalTime - firstTime <= 21.4 + 1e-7)
      let ownedBeamExpected22 = scene.commander.equipmentPurchaseHistory == history
      #expect(ownedBeamExpected22)
    }
  }
}
