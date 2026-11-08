import Foundation
import Testing

@testable import L337Core

/// Actual preceding producers and native admission, with labelled controlled remote scenes.
/// No positive Birth, State, loan, wake admission, observation or stage receipt is injected.
func actualHollowWakeRuntime() async throws -> (
  runtime: GameRuntime, commission: HollowManifestCommissionFixture
) {
  let (laboratory, commission) = try await actualHollowLaboratoryRuntime()
  do {
    let reviewed = try await reviewActualHollowLaboratory(laboratory)
    try #require(reviewed.contractBoard.hollowManifestQuote?.allowed == true)
    await laboratory.scriptPageKey("right", expected: reviewed.scriptPagePresentation)
    let confirm = await laboratory.snapshot()
    try #require(confirm.contractBoard.action == .accept)
    await laboratory.scriptPageKey("return", expected: confirm.scriptPagePresentation)
    let issued = await laboratory.snapshot()
    let instance = try #require(issued.hollowManifestMission)
    let kit = try NativeHollowManifestKitCustody.resolve(instance: instance, commander: issued.commander)
    try #require(instance.savedHollowManifest?.laboratory?.facts.originalKit == kit.serial)
    try #require(instance.savedHollowManifest?.wakeTrail == nil)
    await laboratory.nativeCommand { $0.screen = .status }
    await laboratory.key("0")
    var game = await laboratory.snapshot()
    try #require(!game.docked, Comment(rawValue: game.message))
    try #require(game.commander.nativeStations?.currentMainDock == nil)
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    // Controlled remote scene is not an earned flight. The original held loan and every
    // preceding mission receipt still come from the actual producers above.
    let world = NativeC03WakeGeometry.world
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.speed = 0
    game.screen = .front
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    try #require(try game.hollowManifestWakeAdmissionContext()?.initial == true)
    let source = try #require(try game.retainedMissionActorAdmissionSources().first {
      $0.encounterID == NativeC03WakeTrail.encounter
    })
    try #require(source.mode == .prepared && source.actors.count == 3)
    for template in source.actors {
      let actual = try #require(source.retention.actors[template.alias])
      let condition = try #require(template.retainedNativeCondition)
      let resources = try #require(condition.resources)
      try #require(condition.role == .mission && condition.hasFuelScoops == false)
      try #require(resources.valid && resources.profile == .nativeHull)
      try #require(resources.energyCapacity == actual.body.energy)
      try #require(resources.energyCapacity == actual.body.scriptNPC?.fit.definition.energy)
      try #require(resources.energyCapacity == template.maximumHullEnergy && resources.energyCapacity == 1)
      try #require(resources.energyRecharge == 0 && resources.frontCapacity == 0 && resources.rearCapacity == 0)
      try #require(resources.fuel == 0 && resources.fuelCapacity == 0)
    }
    let before = game.commander.flightSimulation
    try game.restoreScriptActors()
    let selected = try #require(game.hollowManifestMission)
    let trail = try #require(selected.savedHollowManifest?.wakeTrail)
    try #require(trail.admissions.count == 3 && trail.observations.isEmpty)
    try #require(game.commander.flightSimulation.nextActor == before.nextActor + 3)
    try #require(game.commander.flightSimulation.nextSpawn == before.nextSpawn + 1)
    try #require(game.commander.flightSimulation.physicalTime == before.physicalTime)
    for admission in trail.admissions {
      let body = try #require(game.bodies.first { $0.physical?.identity == admission.actor })
      let prepared = try #require(source.actors.first { $0.actorID == admission.logicalActor })
      let condition = try #require(body.physical?.npc)
      try #require(condition.resources == prepared.retainedNativeCondition?.resources)
      try #require(condition.hasFuelScoops == false && condition.resources?.profile == .nativeHull)
    }
    try #require(NativeHollowManifestSave.validateClaims(game.commander))
    let runtime = GameRuntime(game: game, saveURL: commission.files.save)
    try await runtime.save(to: commission.files.save)
    return (runtime, commission)
  } catch {
    commission.clean()
    throw error
  }
}

/// Controlled viewpoint only; the selected physical actor and nearest mesh remain actual.
private func aimAtActualHollowWake(_ game: inout Game, mark: NativeC03WakeGeometry.Mark) throws {
  let instance = try #require(game.hollowManifestMission)
  let trail = try #require(instance.savedHollowManifest?.wakeTrail)
  let admission = try #require(trail.latest(mark))
  let body = try #require(game.bodies.first {
    $0.missionActorID == admission.logicalActor && $0.physical?.identity == admission.actor
  })
  let previous = game.commander.flightSimulation.pose
  let normal = body.modelVector(.init(0, 0, 1))
  let centre = body.modelPoint(.init(0, 0, NativeC03WakeGeometry.plateHeight + 0.16))
  var pose = ShipPose(position: previous.systemPoint(centre + normal * 400))
  pose.orientation.z = previous.orientation.apply(normal * -1)
  pose.orientation.y = previous.orientation.apply(body.modelVector(.init(0, 1, 0)))
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.rotateScriptNPCVelocities(from: previous, to: pose)
  game.screen = .front
  game.speed = 0
  game.cancelAutoTarget()
  game.weaponsTargetID = body.id
  let contact = try #require(try game.nearestMissionCollision(
    from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 1600,
    radius: 0, includePlayer: false))
  try #require(contact.hit.target == .body(body.id) && contact.victimPart == nil)
}

func selectActualHollowWake(
  _ runtime: GameRuntime, mark: NativeC03WakeGeometry.Mark
) async throws -> Game {
  try await runtime.scriptCommand { try aimAtActualHollowWake(&$0, mark: mark) }
  let selected = await runtime.snapshot()
  _ = try #require(try NativeC03WakeProbe.measure(
    in: selected, bodyID: try #require(selected.weaponsTargetID), mark: mark, origin: .init(0, 0, 0)))
  return selected
}

struct NativeC03WakeRuntimeUnitTests {
  /// Negative-only DTO edits after the actual source/control has succeeded.
  private func changedContext(
    _ original: EncounterContext, system: SystemIdentity? = nil, visit: UInt64? = nil,
    time: Double? = nil, anchors: SystemAnchors? = nil
  ) -> EncounterContext {
    .init(
      system: system ?? original.system, seed: original.seed, government: original.government,
      visit: visit ?? original.visit, revision: original.revision,
      physicalTime: time ?? original.physicalTime, anchors: anchors ?? original.anchors,
      player: original.player, actors: original.actors, protection: original.protection,
      budget: original.budget, perceptionRadius: original.perceptionRadius,
      depletedRocks: original.depletedRocks, miningPresence: original.miningPresence)
  }

  @Test func actualOriginalsAndHeldLoanObserveThreePhysicalMarksInOrderExactlyOnce() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let initial = await runtime.snapshot()
    let original = try #require(initial.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    let nativeSource = try #require(try initial.retainedMissionActorAdmissionSources().first {
      $0.encounterID == NativeC03WakeTrail.encounter
    })
    let context = try #require(nativeSource.actors.first?.c03WakeContext)
    #expect(nativeSource.actors.count == 3 && !context.initial)
    #expect(nativeSource.actors.allSatisfy { $0.c03Context == nil && $0.c03WakeContext === context })
    let inventory = initial.commander.equipmentInventory
    let cash = initial.commander.credits
    for mark in NativeC03WakeGeometry.Mark.allCases {
      let selected = try await selectActualHollowWake(runtime, mark: mark)
      try #require(MissionUIAction.originalWakeScan.isEnabled(in: selected))
      let before = selected.commander.flightSimulation
      await runtime.missionUICommand(.init(
        action: .originalWakeScan, game: selected, presentation: selected.scriptPagePresentation))
      let observed = await runtime.snapshot()
      let trail = try #require(observed.hollowManifestMission?.savedHollowManifest?.wakeTrail)
      #expect(trail.observations.count == mark.index + 1 && trail.origin == original.origin)
      #expect(trail.observations.last?.admission == trail.latest(mark))
      #expect(trail.observations.last?.reading.shapeValid == true)
      #expect(observed.commander.flightSimulation == before)
      #expect(observed.commander.credits == cash && observed.commander.equipmentInventory == inventory)
      #expect(observed.hollowManifestMission?.outcome == .active)
      let committed = observed.commander
      await runtime.key("original-wake-scan")
      #expect(await runtime.snapshot().commander == committed)
    }
    let complete = await runtime.snapshot()
    #expect(complete.hollowManifestMission?.milestones == [0, 1, 2, 3])
    #expect(complete.hollowManifestMission?.receipts.contains(NativeC03WakeTrail.receipt) == true)
    #expect(complete.hollowManifestMission?.savedHollowManifest?.laboratory != nil)
    #expect(complete.hollowManifestMission?.completionReceipt == nil)
    let restored = try ScriptSaveStore.read(
      Data(contentsOf: commission.files.save), from: commission.files.save).0
    #expect(restored.scriptState.instances[try #require(complete.hollowManifestMission?.id)]?
      .savedHollowManifest?.wakeTrail == complete.hollowManifestMission?.savedHollowManifest?.wakeTrail)
  }

  @Test func physicalVisibilityAloneCannotSkipTheOrderedOriginalSource() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowWake(runtime, mark: .third)
    // A genuine physical reading exists, but the preceding two originals remain unobserved.
    #expect(selected.hollowManifestWakeTarget == nil)
    let before = selected.commander
    let bytes = try Data(contentsOf: commission.files.save)
    await runtime.key("original-wake-scan")
    #expect(await runtime.snapshot().commander == before)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
    let first = try await selectActualHollowWake(runtime, mark: .first)
    try #require(first.hollowManifestWakeTarget != nil)
    await runtime.missionUICommand(.init(
      action: .originalWakeScan, game: first, presentation: first.scriptPagePresentation))
    #expect(await runtime.snapshot().hollowManifestMission?.savedHollowManifest?
      .wakeTrail?.observations.count == 1)
  }

  @Test func staleQueuedNativeTargetAndOpaqueBlockerCannotGrantObservation() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let first = try await selectActualHollowWake(runtime, mark: .first)
    try #require(first.hollowManifestWakeTarget != nil)
    let queued = MissionUIIntent(action: .originalWakeScan, game: first, presentation: first.scriptPagePresentation)
    _ = try await selectActualHollowWake(runtime, mark: .second)
    let changed = await runtime.snapshot()
    #expect(!queued.isCurrent(in: changed))
    await runtime.missionUICommand(queued)
    #expect(await runtime.snapshot().hollowManifestMission?.savedHollowManifest?
      .wakeTrail?.observations.isEmpty == true)
    var blocked = try await selectActualHollowWake(runtime, mark: .first)
    let id = try #require(blocked.weaponsTargetID)
    let original = try #require(blocked.bodies.first { $0.id == id })
    var blocker = original
    blocker.id += 1000
    blocker.position.z -= 100
    // Negative-only opaque query object; it carries no positive source or admission claim.
    blocker.missionActorID = nil
    blocker.missionInstanceID = nil
    blocked.bodies.append(blocker)
    let before = blocked.commander
    #expect(throws: (any Error).self) { try blocked.recordHollowManifestWakeObservation() }
    #expect(blocked.commander == before)
  }

  @Test func writerRefusalRetainsOriginalLoanAndNoProgressThenAllowsOneRetry() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let first = try await selectActualHollowWake(runtime, mark: .first)
    try #require(first.hollowManifestWakeTarget != nil)
    let bytes = try Data(contentsOf: commission.files.save)
    let directory = commission.files.save.deletingLastPathComponent()
    let parked = directory.appendingPathExtension("parked")
    try FileManager.default.moveItem(at: directory, to: parked)
    defer {
      if FileManager.default.fileExists(atPath: parked.path) {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.moveItem(at: parked, to: directory)
      }
    }
    try Data("writer-refusal".utf8).write(to: directory)
    await runtime.missionUICommand(.init(
      action: .originalWakeScan, game: first, presentation: first.scriptPagePresentation))
    let refused = await runtime.snapshot()
    #expect(refused.commander == first.commander)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.wakeTrail?.observations.isEmpty == true)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: parked, to: directory)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
    await runtime.missionUICommand(.init(
      action: .originalWakeScan, game: refused, presentation: refused.scriptPagePresentation))
    #expect(await runtime.snapshot().hollowManifestMission?.savedHollowManifest?
      .wakeTrail?.observations.count == 1)
    #expect(await runtime.snapshot().commander.equipmentInventory == first.commander.equipmentInventory)
    #expect(await runtime.snapshot().commander.credits == first.commander.credits)
  }

  @Test func missingOriginalLoanOrFittedInstrumentRefusesDespiteActualVisibleGeometry() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowWake(runtime, mark: .first)
    try #require(selected.hollowManifestWakeTarget != nil)
    let inventory = try #require(selected.commander.equipmentInventory)
    let lab = try #require(selected.hollowManifestMission?.savedHollowManifest?.laboratory)
    let targeting = try #require(selected.commander.fittedEquipment(at: .targetingCore))
    for missing in [lab.facts.originalKit, targeting.id] {
      var broken = selected
      // Negative-only removal from a genuine inventory. No issue, custody or positive proof
      // is constructed; the real original case and actual visible object stay unchanged.
      broken.commander.equipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull,
        revision: inventory.revision + 1, items: inventory.items.filter { $0.id != missing })
      let before = broken.commander
      _ = try #require(try NativeC03WakeProbe.measure(
        in: broken, bodyID: try #require(broken.weaponsTargetID), mark: .first, origin: .init(0, 0, 0)))
      #expect(broken.hollowManifestWakeTarget == nil)
      #expect(throws: (any Error).self) { try broken.recordHollowManifestWakeObservation() }
      #expect(broken.commander == before)
    }
  }

  @Test func realReadmissionRetainsOriginalFragmentsAndOldObservationWithFreshAddresses() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let first = try await selectActualHollowWake(runtime, mark: .first)
    await runtime.missionUICommand(.init(
      action: .originalWakeScan, game: first, presentation: first.scriptPagePresentation))
    var game = await runtime.snapshot()
    let before = try #require(game.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    let retained = try #require(game.hollowManifestMission?.ownedEncounters[NativeC03WakeTrail.encounter])
    try #require(before.observations.count == 1)
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.speed = 0
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let flight = game.commander.flightSimulation
    try game.restoreScriptActors()
    let after = try #require(game.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    let rebound = try #require(game.hollowManifestMission?.ownedEncounters[NativeC03WakeTrail.encounter])
    #expect(after.origin == before.origin && after.observations == before.observations)
    #expect(game.commander.flightSimulation.nextActor == flight.nextActor + 3)
    #expect(game.commander.flightSimulation.nextSpawn == flight.nextSpawn + 1)
    #expect(game.commander.flightSimulation.physicalTime == flight.physicalTime)
    for mark in NativeC03WakeGeometry.Mark.allCases {
      let old = try #require(before.latest(mark))
      let new = try #require(after.latest(mark))
      #expect(old.fragment == new.fragment && old.logicalActor == new.logicalActor)
      #expect(old.actor != new.actor && new.actor.visit > old.actor.visit)
      #expect(new.revision == old.revision + 1)
      let oldBody = try #require(retained.actors[mark.rawValue]?.body)
      let newBody = try #require(rebound.actors[mark.rawValue]?.body)
      #expect(newBody.energy == oldBody.energy)
      #expect(newBody.physical?.npc?.resources == oldBody.physical?.npc?.resources)
      #expect(newBody.physical?.npc?.hasFuelScoops == oldBody.physical?.npc?.hasFuelScoops)
      #expect(newBody.physical?.laserCooldown == oldBody.physical?.laserCooldown)
      #expect(newBody.physical?.angularVelocity == oldBody.physical?.angularVelocity)
      #expect(newBody.physical?.canonicalSpin == oldBody.physical?.canonicalSpin)
    }
    let restored = GameRuntime(game: game, saveURL: commission.files.save)
    try await restored.save(to: commission.files.save)
    let second = try await selectActualHollowWake(restored, mark: .second)
    try #require(second.hollowManifestWakeTarget != nil)
    await restored.missionUICommand(.init(
      action: .originalWakeScan, game: second, presentation: second.scriptPagePresentation))
    let observed = await restored.snapshot()
    #expect(observed.hollowManifestMission?.savedHollowManifest?.wakeTrail?.observations.count == 2)
    #expect(observed.hollowManifestMission?.savedHollowManifest?.wakeTrail?.observations.first
      == before.observations.first)
  }

  @Test func refusedOwnedCapturePreservesCommanderNativeSceneAndOriginalRecords() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    var game = await runtime.snapshot()
    let instance = try #require(game.hollowManifestMission)
    let trail = try #require(instance.savedHollowManifest?.wakeTrail)
    let first = try #require(trail.latest(.first))
    let second = try #require(trail.latest(.second))
    let firstIndex = try #require(game.bodies.firstIndex { $0.physical?.identity == first.actor })
    let secondIndex = try #require(game.bodies.firstIndex { $0.physical?.identity == second.actor })
    // A controlled pose change makes a leaked earlier capture visible; the later negative
    // velocity mismatch must refuse, never publish the first fragment's partial update.
    game.bodies[firstIndex].position.x += 17
    game.bodies[secondIndex].scriptNPC?.velocity.x += 1
    let before = game.commander
    let bodies = game.bodies
    #expect(throws: (any Error).self) { try game.persistScriptActorsChecked(unloading: true) }
    #expect(game.commander == before && game.bodies == bodies)
    let refused = game.persistC03ActorsPreservingRefusals(unloading: true)
    #expect(refused == game.c03WakeRecognizedBodyIDs())
    #expect(refused.count == 3 && game.commander == before && game.bodies == bodies)
    #expect(game.hollowManifestMission?.savedHollowManifest?.wakeTrail == trail)
  }

  @Test func actualStationSpinRetainsCanonicalLayoutAndCurrentNativeSource() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let first = await runtime.snapshot()
    let station = try #require(first.scriptAnchor)
    try #require(station.rotationRate != 0 && !first.paused && !first.docked)
    let original = try #require(first.hollowManifestMission?.savedHollowManifest?.wakeTrail)
    let oldPose = first.modelPose(of: station)
    let spun = await runtime.advance(delta: 0.05)
    let current = try #require(spun.gameplayContext())
    let flight = spun.commander.flightSimulation
    let canonical = try #require(flight.anchors)
    let live = try #require(spun.scriptAnchor)
    try #require(flight.physicalTime > first.commander.flightSimulation.physicalTime)
    try #require(spun.modelPose(of: live).orientation != oldPose.orientation)
    #expect(current.anchors != canonical)
    #expect(NativeC03AnchorFrames.matches(
      canonical: canonical, current: current, flight: flight, station: live))
    let source = try #require(try spun.hollowManifestWakeAdmissionContext())
    #expect(spun.acceptsHollowManifestWakeAdmissionContext(source))
    #expect(source.anchors == original.origin.anchors && source.reference == original.origin.reference)
    #expect(spun.hollowManifestMission?.savedHollowManifest?.wakeTrail == original)
  }

  @Test func actualAnchorJoinRefusesForeignCurrentnessPoseGeometryAndNativeIdentity() async throws {
    let (runtime, commission) = try await actualHollowWakeRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let context = try #require(game.gameplayContext())
    let flight = game.commander.flightSimulation
    let canonical = try #require(flight.anchors)
    let station = try #require(game.scriptAnchor)
    let source = try #require(try game.hollowManifestWakeAdmissionContext())
    try #require(game.acceptsHollowManifestWakeAdmissionContext(source))
    try #require(NativeC03AnchorFrames.matches(
      canonical: canonical, current: context, flight: flight, station: station))
    let match: (EncounterContext, FlightSimulationState, SpaceBody) -> Bool = { current, clock, body in
      NativeC03AnchorFrames.matches(canonical: canonical, current: current, flight: clock, station: body)
    }
    #expect(!match(changedContext(context, system: NativeHollowManifestDefinition.freighterWorld), flight, station))
    #expect(!match(changedContext(context, visit: context.visit + 1), flight, station))
    #expect(!match(changedContext(context, time: context.physicalTime + 0.05), flight, station))
    let wrongSpheres = SystemAnchors(
      system: canonical.system, station: context.anchors.station, arrival: canonical.arrival,
      planet: .init(position: canonical.planet.position, radius: canonical.planet.radius + 1),
      sun: canonical.sun)
    #expect(!match(changedContext(context, anchors: wrongSpheres), flight, station))
    var wrongActor = station
    wrongActor.physical = nil
    #expect(!match(context, flight, wrongActor))
    var moved = station
    moved.position.x += 1
    #expect(!match(context, flight, moved))
    var turned = station
    turned.rotation += 0.2
    #expect(!match(context, flight, turned))
    var changed = game
    let index = try #require(changed.bodies.firstIndex { $0.id == station.id })
    changed.bodies[index].rotation += 0.2
    #expect(!changed.acceptsHollowManifestWakeAdmissionContext(source))
    changed = game
    let mark = NativeC03WakeGeometry.Mark.first
    let hash = try NativeC03WakeGeometry.geometryHash(mark)
    changed.commander.scriptState.geometry.removeValue(forKey: hash)
    #expect(!changed.acceptsHollowManifestWakeAdmissionContext(source))
    #expect(game.acceptsHollowManifestWakeAdmissionContext(source))
  }
}
