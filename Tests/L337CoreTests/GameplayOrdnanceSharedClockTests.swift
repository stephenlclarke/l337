import Foundation
import Testing

@testable import L337Core
@testable import L337SimulationTestCases

/// Reuses the existing controlled combat-role fixture and real missile launcher.
/// These are kernel oracles, not a natural Okapi source/admission qualification.
private enum OrdnanceClockFixture {
  static func game(distance: Double = 1800, launch: Bool = true, birthTime: Double = 0) throws -> Game {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    // Advance the real clock before actor admission and the actual launcher.
    // This is a declared kernel fixture, not a natural career qualification.
    game.commander.flightSimulation.advancePhysicalTime(birthTime)
    game.speed = 0
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    let target = try exactCombatFixtureBody(&game, id: 70, position: .init(0, 0, distance))
    game.bodies = [target]
    game.celestials = []
    game.ensurePhysicalActors()
    return try launchEquippedClockFixture(&game, launch: launch)
  }

  @inline(never)
  private static func launchEquippedClockFixture(_ game: inout Game, launch: Bool) throws -> Game {
    if launch {
      let launched = game.launchGameplayMissile(targetBodyID: 70)
      try #require(launched)
    }
    return game
  }

  static func opening(_ game: Game, until end: Double = 0.1) throws -> GameplayOrdnanceOpening {
    let ownedPreparationRequired1 = game.prepareGameplayOrdnanceFrame(until: end)
    let frame = try #require(ownedPreparationRequired1)
    try #require(frame.entries.count == 1)
    return try #require(frame.entries.first)
  }

  @inline(never)
  static func advanceReference(_ game: inout Game) {
    game.advanceGameplayOrdnance(allowEnemyECM: false)
  }

  static func advanceClock(_ game: inout Game, to end: Double) {
    game.commander.flightSimulation.advancePhysicalTime(
      end - game.storedFlightSimulation().physicalTime)
  }

  static func state(_ game: Game, entry: GameplayOrdnanceOpening) throws -> OrdnanceState {
    let ordnanceActualCheck1 = game.bodies.first { $0.physical?.identity == entry.actor }?.physical?.ordnance
    return try #require(ordnanceActualCheck1)
  }

  static func alignSurface(_ game: inout Game, bodyID: Int) throws {
    let indexCandidate = game.bodies.firstIndex { $0.id == bodyID }
    let index = try #require(indexCandidate)
    game.bodies[index].orientation = .init()
    game.bodies[index].rotation = 0
    let body = game.bodies[index]
    let aim = Game.nativePlayerSurfaceAim(from: .init(0, 0, -1000), mesh: game.gameplayMesh(for: body))
    game.bodies[index].position = Vector3(0, 0, 70) - aim
  }

  @inline(never)
  static func mission(launch: Bool = true) throws -> (Game, UUID) {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    var target = game.bodies[index]
    target.orientation = .init()
    target.rotation = 0
    target.rotationRate = 0
    let npc = try #require(target.scriptNPC)
    let ownedPreparationRequired2 = game.scriptModel(npc.fit.definition.model, fit: npc.fit)
    let mesh = try #require(ownedPreparationRequired2)
    // This authored hull has quadrilateral faces. The production triangle-only
    // surface aim deliberately falls back to the origin for this topology.
    // Measure the actual root entry; placing its centre at 70 starts inside it.
    target.position = .init(0, 0, 0)
    let measured = GameplayRaycast.nearest(origin: .init(0, 0, -1000), direction: .init(0, 0, 1),
      maxDistance: 2000, bodies: [target], meshOverrides: [target.id: mesh])
    let surface = try #require(measured)
    try #require(surface.target == .body(target.id) && surface.point.z < 0)
    target.position = Vector3(0, 0, 70) - surface.point
    game.bodies = [target] + game.bodies.filter { $0.nativeStationIdentity != nil }
    game.celestials = []
    if launch {
      let launched = game.launchGameplayMissile(targetBodyID: target.id)
      try #require(launched)
    }
    return (game, instance)
  }

  @inline(never)
  static func requirePositiveMissionSlice(_ game: Game, entry: GameplayOrdnanceOpening) throws {
    let opening = game
    let prepared = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(prepared)
    try #require(slice.contact?.selectedTargetBody?.scriptNPC != nil && slice.contact?.victimPart == nil)
    try #require(slice.attainedEnd > slice.context.physicalTime && slice.attainedEnd <= 0.1)
    let ordnanceActualCheck2 = game.currentNewtNativeCommanderMatches(opening) && game.bodies == opening.bodies
    #expect(ordnanceActualCheck2)
    let ordnanceActualCheck3 = game.storedFlightSimulation().physicalTime == opening.storedFlightSimulation().physicalTime
    #expect(ordnanceActualCheck3)
  }

  static func nativeLeg(_ game: inout Game, delta: Double = 0.1) throws -> CurrentNewtNativeOrdnanceLeg {
    let missileCandidate = game.bodies.first { $0.energy > 0 && $0.physical?.ordnance != nil }
    let missile = try #require(missileCandidate)
    let actor = try #require(missile.physical?.identity)
    let openingClock = game.storedFlightSimulation()
    let openingBodies = game.bodies
    let preparedPath = game.prepareCurrentNewtOuterMotion(delta: delta)
    let path = try #require(preparedPath)
    // The real T0 preparation may select control intent, but supplies no
    // future simulation clock, actor state or completed endpoint Game.
    let ordnanceActualCheck4 = game.storedFlightSimulation() == openingClock && game.bodies == openingBodies
    try #require(ordnanceActualCheck4)
    let ownedPreparationRequired3 = game.prepareCurrentNewtNPCFrame(path)
    let npcFrame = try #require(ownedPreparationRequired3)
    let ownedPreparationRequired4 = game.prepareGameplayOrdnanceFrame(until: path.endTime)
    let frame = try #require(ownedPreparationRequired4)
    let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
    let openingCandidate = game.beginCurrentNewtNativeSegment(interval, playerMotion: path.motion,
      playerEnd: try #require(path.state(at: path.endTime)), npcFrame: npcFrame)
    let opening = try #require(openingCandidate)
    let ownedPreparationRequired5 = game.currentNewtMechanicalPlan(interval)
    let mechanics = try #require(ownedPreparationRequired5)
    let ownedPreparationRequired6 = game.prepareCurrentNewtNativeQueryScene(
      opening: opening, mechanics: mechanics, ordnanceFrame: frame)
    let scene = try #require(ownedPreparationRequired6)
    guard case .prepared(let leg) = game.prepareCurrentNewtNativeOrdnanceLeg(in: scene, actor: actor) else {
      Issue.record("Actual source did not produce a native leg"); throw SaveError.invalidCommander
    }
    return leg
  }

  /// Same real clock/mechanical owners as G1's candidate, with the original
  /// admitted NPC/player paths. No predicted Game is installed as an endpoint.
  @discardableResult
  static func attainNativeFrontier(_ game: inout Game, leg: CurrentNewtNativeOrdnanceLeg) throws -> CurrentNewtEndBirths? {
    let start = leg.scene.motion.opening.interval.start
    let end = leg.attainedEnd
    if end == start { return nil }
    let ordnanceActualCheck5 = leg.scene.motion.opening.npcFrame
    let npcFrame = try #require(ordnanceActualCheck5)
    let path = npcFrame.path
    let ownedPreparationRequired7 = game.prefixCurrentNewtNativeQueryScene(leg.scene, through: end, trajectory: path)
    let scene = try #require(ownedPreparationRequired7)
    let ownedPreparationRequired8 = game.prepareCurrentNewtNativeContact(in: scene)
    let physical = try #require(ownedPreparationRequired8)
    try #require(physical.resolution.impacts.isEmpty)
    var candidate = game
    candidate.commander.flightSimulation.advancePhysicalTime(end - start)
    let application = candidate.retainCurrentNewtNativeMechanics(physical)
    let retained = try #require(application)
    try #require(retained.result.acceptedDuration == end - start && retained.effects.isEmpty)
    try #require(candidate.storedFlightSimulation().physicalTime == end)
    game = candidate
    return retained.births
  }

  static func newtMissile(distance: Double) throws -> Game {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let targetCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate)
    let model = game.modelPose(of: target)
    let aim = Game.nativePlayerSurfaceAim(from: .init(0, 0, -1000), mesh: game.gameplayMesh(for: target))
    var observer = model
    observer.position = model.systemPoint(aim) - model.orientation.z * distance
    NativePagedSalvageFixture.moveObserver(&game, to: observer)
    let launched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
    return game
  }

  static func zeroMission() throws -> (Game, UUID) {
    var (game, instance) = try mission(launch: false)
    let targetCandidate2 = game.bodies.first { $0.scriptNPC != nil }
    let target = try #require(targetCandidate2)
    let model = game.modelPose(of: target)
    let npc = try #require(target.scriptNPC)
    let fittedMesh = game.scriptModel(npc.fit.definition.model, fit: npc.fit)
    let mesh = try #require(fittedMesh)
    try #require(!mesh.vertices.isEmpty)
    let middle = mesh.vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(mesh.vertices.count))
    var observer = model
    observer.position = model.systemPoint(middle) - model.orientation.z * NativeMissileMuzzleDescription.distance
    NativePagedSalvageFixture.moveObserver(&game, to: observer)
    let launched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
    return (game, instance)
  }

  static func impactSlice(_ game: inout Game, entry: GameplayOrdnanceOpening,
    tinyPrefix: Bool) throws -> GameplayOrdnancePreparedSlice
  {
    let ownedPreparationRequired9 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    var slice = try #require(ownedPreparationRequired9)
    try #require(slice.contact != nil && slice.attainedEnd > 0)
    if tinyPrefix {
      // Derive the suffix from the genuine first hit. Its earlier prefix is
      // actually retained through the same owner before the refusal is arranged.
      let leadingEnd = slice.attainedEnd - 2e-9
      let ordnanceActualCheck6 = leadingEnd > game.storedFlightSimulation().physicalTime
      try #require(ordnanceActualCheck6)
      let ownedPreparationRequired10 = try game.prepareGameplayOrdnanceSlice(entry, until: leadingEnd)
      let leading = try #require(ownedPreparationRequired10)
      try #require(leading.contact == nil && leading.attainedEnd == leadingEnd)
      OrdnanceClockFixture.advanceClock(&game, to: leading.attainedEnd)
      let leadingClock = game.storedFlightSimulation()
      let appliedLeading = try game.retainPreparedGameplayOrdnance(leading)
      let acceptedLeading = try #require(appliedLeading)
      try #require(acceptedLeading.motionRetained)
      let ordnanceActualCheck7 = acceptedLeading.applying(to: leadingClock) == game.storedFlightSimulation()
      try #require(ordnanceActualCheck7)
      let ownedPreparationRequired11 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
      slice = try #require(ownedPreparationRequired11)
      let actualPrefix = slice.attainedEnd - game.storedFlightSimulation().physicalTime
      try #require(actualPrefix > 1e-10 && actualPrefix < 1e-8)
      try #require(slice.contact != nil)
    }
    return slice
  }

  /// Malformed current allocator/ledger inputs exercise refusal, not saved authority.
  static func refuseNextHit(_ game: inout Game, allocatorEdge: Bool) throws {
    if allocatorEdge {
      let ordnanceActualCheck8 = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(game.storedFlightSimulation())) as? [String: Any]
      var object = try #require(ordnanceActualCheck8)
      object["nextIncident"] = NSNumber(value: UInt64.max - 1)
      game.commander.flightSimulation = try JSONDecoder().decode(FlightSimulationState.self,
        from: JSONSerialization.data(withJSONObject: object))
      let ordnanceActualCheck9 = game.storedFlightSimulation().valid
      try #require(ordnanceActualCheck9)
    } else {
      let ordnanceActualCheck10 = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(game.commander.crimeLedger)) as? [String: Any]
      var object = try #require(ordnanceActualCheck10)
      object["lastIncidentID"] = NSNumber(value: game.storedFlightSimulation().nextIncident)
      game.commander.crimeLedger = try JSONDecoder().decode(CrimeLedger.self,
        from: JSONSerialization.data(withJSONObject: object))
    }
  }
}

struct GameplayOrdnanceSharedClockTests {
  @Test func realReleaseBirthCohortPreservesAnUnrelatedClearProjectileWithoutInventingPodMotion() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let disabled = try releaseDamagedEMPBoundary(&game)
    try #require(disabled)
    let ordnanceActualCheck11 = game.bodies.first { $0.physical?.empSource != nil }?.physical?.empSource
    let logical = try #require(ordnanceActualCheck11)
    var exercised = false
    try withEMPUnitWriter(&game) { current, publish, _ in
      for _ in 0..<320 {
        let record = try #require(current.commander.savedEMPState?.records[logical])
        let stock = try #require(record.hull.body.physical?.currentNewtKitStock)
        let now = current.storedFlightSimulation().physicalTime
        if let actuation = stock.actuation, actuation.unlockAt > now, actuation.unlockAt <= now + 0.1 {
          let targetCandidate3 = current.bodies.first { $0.physical?.empSource == logical }
          let target = try #require(targetCandidate3)
          let model = current.modelPose(of: target)
          var observer = model
          observer.position = model.position - model.orientation.z * 1800
          NativePagedSalvageFixture.moveObserver(&current, to: observer)
          let launched = current.launchGameplayMissile(targetBodyID: target.id)
          try #require(launched)
          let leg = try OrdnanceClockFixture.nativeLeg(&current, delta: actuation.unlockAt - now)
          try #require(leg.contact == nil && leg.attainedEnd == actuation.unlockAt)
          let birthResult = try OrdnanceClockFixture.attainNativeFrontier(&current, leg: leg)
          let births = try #require(birthResult)
          let podCandidate = current.bodies.first {
            $0.physical?.currentNewtKitReceipt?.issue == stock.issue
          }
          let pod = try #require(podCandidate)
          let actor = try #require(pod.physical?.identity)
          try #require(births.actors.contains(actor) && births.matchesNewtBirths(current))
          #expect(pod.physical?.currentNewtKitReceipt?.releasedAt == leg.attainedEnd)
          let before = current
          let missing = try current.retainCurrentNewtNativeOrdnance(leg)
          let ordnanceActualCheck12 = missing == nil && current.currentNewtNativeCommanderMatches(before) && current.bodies == before.bodies
          #expect(ordnanceActualCheck12)
          var changed = current
          let indexCandidate2 = changed.bodies.firstIndex { $0.physical?.identity == actor }
          let index = try #require(indexCandidate2)
          changed.bodies[index].position.x += 1
          let invalidBefore = changed
          let invalid = try changed.retainCurrentNewtNativeOrdnance(leg, admittedAtBoundary: births)
          #expect(invalid == nil && changed.currentNewtNativeCommanderMatches(invalidBefore) && changed.bodies == invalidBefore.bodies)
          let flight = current.storedFlightSimulation()
          let application = try current.retainCurrentNewtNativeOrdnance(leg, admittedAtBoundary: births)
          let retained = try #require(application)
          #expect(retained.motionRetained && retained.update.hit == nil && retained.clockEffects.isEmpty)
          #expect(retained.applying(to: flight) == current.storedFlightSimulation())
          #expect(current.bodies.first { $0.physical?.identity == actor } == pod)
          #expect(current.storedFlightSimulation().physicalTime == actuation.unlockAt)
          exercised = true
          return
        }
        try empUnitFrame(&current, publish: publish)
      }
    }
    #expect(exercised)
  }

  @Test func sourceSealedClearSubsetCannotRetainTheUnattainedRestOfItsQueryWindow() throws {
    var game = try OrdnanceClockFixture.newtMissile(distance: 1800)
    try verifySourceSealedClearSubsetCannotRetainTheUnattainedRestOfItsQueryWindow(&game)
  }

  @inline(never)
  private func verifySourceSealedClearSubsetCannotRetainTheUnattainedRestOfItsQueryWindow(_ game: inout Game) throws {
    let full = try OrdnanceClockFixture.nativeLeg(&game)
    try #require(full.contact == nil)
    let start = game.storedFlightSimulation().physicalTime
    let end = start + (full.attainedEnd - start) * 0.5
    let ownedPreparationRequired12 = game.prefixCurrentNewtNativeOrdnanceLeg(full, through: end)
    let prefix = try #require(ownedPreparationRequired12)
    #expect(prefix.scene === full.scene && prefix.opening === full.opening && prefix.attainedEnd == end)
    try OrdnanceClockFixture.attainNativeFrontier(&game, leg: prefix)
    let flight = game.storedFlightSimulation()
    let result = try game.retainCurrentNewtNativeOrdnance(prefix)
    let retained = try #require(result)
    #expect(retained.motionRetained && retained.update.hit == nil)
    let ordnanceActualCheck13 = game.storedFlightSimulation().physicalTime == end && end < full.attainedEnd
    #expect(ordnanceActualCheck13)
    let ordnanceActualCheck14 = retained.applying(to: flight) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck14)
    let once = game
    let unearned = try game.retainCurrentNewtNativeOrdnance(full)
    let ordnanceActualCheck15 = unearned == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck15)
  }

  @Test func actualNativeClearRetainsOnlyTheRealCommonMoverAndOriginalPath() throws {
    var game = try OrdnanceClockFixture.newtMissile(distance: 1800)
    try verifyActualNativeClearRetainsOnlyTheRealCommonMoverAndOriginalPath(&game)
  }

  @inline(never)
  private func verifyActualNativeClearRetainsOnlyTheRealCommonMoverAndOriginalPath(_ game: inout Game) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    try #require(leg.contact == nil)
    let before = game
    let early = try game.retainCurrentNewtNativeOrdnance(leg)
    let ordnanceActualCheck16 = early == nil && game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck16)
    try OrdnanceClockFixture.attainNativeFrontier(&game, leg: leg)
    let flight = game.storedFlightSimulation()
    let applied = try game.retainCurrentNewtNativeOrdnance(leg)
    let retained = try #require(applied)
    let state = try OrdnanceClockFixture.state(game, entry: leg.opening)
    #expect(retained.motionRetained && retained.clockEffects.isEmpty && retained.update.hit == nil)
    let ordnanceActualCheck17 = leg.opening.matchesCurrentState(state, at: leg.attainedEnd)
    #expect(ordnanceActualCheck17)
    let ordnanceActualCheck18 = retained.applying(to: flight) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck18)
    let ordnanceActualCheck19 = game.storedFlightSimulation().physicalTime == leg.attainedEnd
    #expect(ordnanceActualCheck19)
    let once = game
    let duplicate = try game.retainCurrentNewtNativeOrdnance(leg)
    let ordnanceActualCheck20 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck20)
  }

  @Test func genuineNativeNewtImpactUsesTheClosedOrdinaryEffectAtItsActualFrontier() throws {
    var game = try OrdnanceClockFixture.newtMissile(distance: 60)
    try verifyGenuineNativeNewtImpactUsesTheClosedOrdinaryEffectAtItsActualFrontier(&game)
  }

  @inline(never)
  private func verifyGenuineNativeNewtImpactUsesTheClosedOrdinaryEffectAtItsActualFrontier(_ game: inout Game) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    let contact = try #require(leg.contact)
    let ordnanceActualCheck21 = contact.upperPhysicalTime > leg.scene.motion.opening.interval.start
    try #require(ordnanceActualCheck21)
    try OrdnanceClockFixture.attainNativeFrontier(&game, leg: leg)
    let flight = game.storedFlightSimulation()
    var reference = game
    let directEffect = reference.applyNativeOrdnanceCurveHit(contact)
    let expected = try #require(directEffect)
    let applied = try game.retainCurrentNewtNativeOrdnance(leg)
    let retained = try #require(applied)
    #expect(retained.motionRetained && retained.update.termination == .impact)
    #expect(retained.update.position == contact.native.centre && retained.update.incident == expected.incident)
    let firstMatch = game.bodies.first { $0.physical?.identity == contact.target.actor }
      == reference.bodies.first { $0.physical?.identity == contact.target.actor }
    #expect(firstMatch)
    let ordnanceActualCheck22 = retained.applying(to: flight) == reference.storedFlightSimulation()
    #expect(ordnanceActualCheck22)
    let ordnanceActualCheck23 = game.storedFlightSimulation().physicalTime == contact.upperPhysicalTime
    #expect(ordnanceActualCheck23)
    #expect(try OrdnanceClockFixture.state(game, entry: leg.opening).lastUpdatedAt == contact.upperPhysicalTime)
    let once = game
    let duplicate = try game.retainCurrentNewtNativeOrdnance(leg)
    let ordnanceActualCheck24 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck24)
  }

  @Test func genuineZeroTimeMissionOverlapUsesTypedProofAndProjectsItsEventsOnce() throws {
    var (game, _) = try OrdnanceClockFixture.zeroMission()
    try verifyGenuineZeroTimeMissionOverlapUsesTypedProofAndProjectsItsEventsOnce(&game)
  }

  @inline(never)
  private func verifyGenuineZeroTimeMissionOverlapUsesTypedProofAndProjectsItsEventsOnce(_ game: inout Game) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    let contact = try #require(leg.contact)
    let start = game.storedFlightSimulation().physicalTime
    try #require(contact.lowerPhysicalTime == start && contact.upperPhysicalTime == start)
    try #require(contact.native.lowerTime == 0 && contact.native.upperTime == 0)
    let before = game
    let oldSequences = Set(before.commander.scriptState.pendingEvents.map(\.sequence))
    let applied = try game.retainCurrentNewtNativeOrdnance(leg)
    let retained = try #require(applied)
    try verifyZeroTimeMissionEffect(&game, leg: leg, contact: contact, start: start,
      before: before, oldSequences: oldSequences, retained: retained)
  }

  @inline(never)
  private func verifyZeroTimeMissionEffect(
    _ game: inout Game, leg: CurrentNewtNativeOrdnanceLeg, contact: CurrentNewtOrdnanceCurveContact,
    start: Double, before: Game, oldSequences: Set<UInt64>, retained: GameplayOrdnanceRetention
  ) throws {
    #expect(retained.motionRetained && retained.update.termination == .impact)
    let ordnanceActualCheck25 = game.storedFlightSimulation().physicalTime == start && retained.update.position == contact.native.centre
    #expect(ordnanceActualCheck25)
    let ordnanceActualCheck26 = retained.applying(to: before.storedFlightSimulation()) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck26)
    try #require(retained.clockEffects.count == 1)
    guard case .mission(let effect) = retained.clockEffects[0] else {
      Issue.record("Zero-time mission contact bypassed its typed mission owner"); return
    }
    #expect(effect.incident == retained.update.incident)
    #expect(effect.incident.physicalTime == start && retained.update.incident?.physicalTime == start)
    let ordnanceActualCheck27 = effect.incident.origin == leg.opening.state.origin
    #expect(ordnanceActualCheck27)
    let events = game.commander.scriptState.pendingEvents.filter { !oldSequences.contains($0.sequence) }
    #expect(events.filter { $0.kind == "actor.damaged" }.count == 1)
    #expect(events.filter { $0.kind == "actor.destroyed" }.count == 1)
    #expect(Set(events.map(\.sequence)).count == events.count)
    let once = game
    let duplicate = try game.retainCurrentNewtNativeOrdnance(leg)
    let ordnanceActualCheck28 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck28)
    let ordnanceActualCheck29 = game.commander.scriptState.pendingEvents == once.commander.scriptState.pendingEvents
    #expect(ordnanceActualCheck29)
  }

  @Test func fullMissionQueueRefusesGenuineZeroContactWithoutAnyMutationOrClockCredit() throws {
    var (game, instance) = try OrdnanceClockFixture.zeroMission()
    try verifyFullMissionQueueRefusesGenuineZeroContactWithoutAnyMutationOrClockCredit(&game, instance: instance)
  }

  @inline(never)
  private func verifyFullMissionQueueRefusesGenuineZeroContactWithoutAnyMutationOrClockCredit(_ game: inout Game, instance: UUID) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    try #require(leg.contact?.native.upperTime == 0)
    for _ in game.commander.scriptState.pendingEvents.count..<4096 {
      game.emitScriptEvent("capacity.probe", values: [:], only: instance, drain: false)
    }
    let before = game
    do {
      _ = try game.retainCurrentNewtNativeOrdnance(leg)
      Issue.record("Full real mission event queue admitted a zero-time contact")
    } catch let error as ScriptMissionEventCapacityError {
      #expect(error == .insufficientCapacity)
    }
    let ordnanceActualCheck30 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck30)
    let ordnanceActualCheck31 = game.scriptWorldSave == before.scriptWorldSave && game.message == before.message
    #expect(ordnanceActualCheck31)
    let ordnanceActualCheck32 = game.dischargeAudio.events == before.dischargeAudio.events
    #expect(ordnanceActualCheck32)
  }

  @Test(arguments: [false, true])
  func lateNativeAllocatorOrLedgerRefusalPublishesNoContactOrPartialState(allocatorEdge: Bool) throws {
    var game = try OrdnanceClockFixture.newtMissile(distance: 60)
    try verifyLateNativeAllocatorOrLedgerRefusalPublishesNoContactOrPartialState(&game, allocatorEdge: allocatorEdge)
  }

  @inline(never)
  private func verifyLateNativeAllocatorOrLedgerRefusalPublishesNoContactOrPartialState(_ game: inout Game, allocatorEdge: Bool) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    try #require(leg.contact != nil)
    try OrdnanceClockFixture.attainNativeFrontier(&game, leg: leg)
    try OrdnanceClockFixture.refuseNextHit(&game, allocatorEdge: allocatorEdge)
    let before = game
    let applied = try game.retainCurrentNewtNativeOrdnance(leg)
    let retained = try #require(applied)
    #expect(!retained.motionRetained && retained.update.hit == nil && retained.update.incident == nil)
    let ordnanceActualCheck33 = retained.clockEffects.isEmpty && retained.applying(to: before.storedFlightSimulation())
      == before.storedFlightSimulation()
    #expect(ordnanceActualCheck33)
    let ordnanceActualCheck34 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck34)
    let ordnanceActualCheck35 = game.scriptWorldSave == before.scriptWorldSave && game.message == before.message
    #expect(ordnanceActualCheck35)
    let ordnanceActualCheck36 = game.nextBodyID == before.nextBodyID && game.energy == before.energy
    #expect(ordnanceActualCheck36)
    let ordnanceActualCheck37 = game.dischargeAudio.events == before.dischargeAudio.events
    #expect(ordnanceActualCheck37)
  }

  @Test func changedNativeClearSceneOrSourceCannotReuseAnEarlierLeg() throws {
    var game = try OrdnanceClockFixture.newtMissile(distance: 1800)
    try verifyChangedNativeClearSceneOrSourceCannotReuseAnEarlierLeg(&game)
  }

  @inline(never)
  private func verifyChangedNativeClearSceneOrSourceCannotReuseAnEarlierLeg(_ game: inout Game) throws {
    let leg = try OrdnanceClockFixture.nativeLeg(&game)
    try #require(leg.contact == nil)
    try OrdnanceClockFixture.attainNativeFrontier(&game, leg: leg)
    let targetCandidate4 = game.bodies.firstIndex { $0.physical?.currentNewtKitStock != nil }
    let target = try #require(targetCandidate4)
    let missileCandidate2 = game.bodies.firstIndex { $0.physical?.identity == leg.opening.actor }
    let missile = try #require(missileCandidate2)
    for change in 0..<4 {
      var invalid = game
      switch change {
      case 0: invalid.bodies[target].position.x += 1
      case 1: invalid.bodies[target].physical?.catalogueShipID = "SH005"
      case 2: invalid.bodies[missile].physical?.attackOrigin = nil
      default: invalid.nativeStationRuntimeEpoch = UUID()
      }
      let before = invalid
      let result = try invalid.retainCurrentNewtNativeOrdnance(leg)
      let ordnanceActualCheck38 = result == nil && invalid.currentNewtNativeCommanderMatches(before) && invalid.bodies == before.bodies
      #expect(ordnanceActualCheck38)
      let ordnanceActualCheck39 = invalid.scriptWorldSave == before.scriptWorldSave
      #expect(ordnanceActualCheck39)
    }
  }

  @Test(arguments: [false, true])
  func realCurrentClockTargetLossAndECMSettleWithoutAnInventedGuidanceStep(ecm: Bool) throws {
    var game = try OrdnanceClockFixture.game()
    try verifyRealCurrentClockTargetLossAndECMSettleWithoutAnInventedGuidanceStep(&game, ecm: ecm)
  }

  @inline(never)
  private func verifyRealCurrentClockTargetLossAndECMSettleWithoutAnInventedGuidanceStep(_ game: inout Game, ecm: Bool) throws {
    if !ecm {
      let targetCandidate5 = game.bodies.firstIndex { $0.id == 70 }
      let target = try #require(targetCandidate5)
      game.bodies[target].energy = 0
    } else {
      let ordnanceActualCheck40 = game.storedFlightSimulation().player
      let player = try #require(ordnanceActualCheck40)
      let activated = game.activateOrdnanceECM(emitter: player)
      try #require(activated)
    }
    let entry = try OrdnanceClockFixture.opening(game)
    let before = game
    let pulses = ecm ? [try #require(game.activeECMActivation)] : []
    let applied = game.retainCurrentNewtNativeOrdnanceBoundary(entry, activeECM: pulses)
    let retained = try #require(applied)
    #expect(retained.motionRetained && retained.update.termination == (ecm ? .ecm : .targetLost))
    #expect(retained.update.position == entry.state.position && retained.update.hit == nil)
    let ordnanceActualCheck41 = game.storedFlightSimulation().physicalTime == before.storedFlightSimulation().physicalTime
    #expect(ordnanceActualCheck41)
    let ordnanceActualCheck42 = retained.applying(to: before.storedFlightSimulation()) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck42)
    let once = game
    let duplicate = game.retainCurrentNewtNativeOrdnanceBoundary(entry, activeECM: pulses)
    let ordnanceActualCheck43 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck43)
  }

  @Test(arguments: [86_400.0, 604_800.0])
  func actualCareerMissileSamplingJumpNeedsBothEndpointClockBounds(birthTime: Double) throws {
    let game = try OrdnanceClockFixture.game(birthTime: birthTime)
    try verifyActualCareerMissileSamplingJumpNeedsBothEndpointClockBounds(game, birthTime: birthTime)
  }

  @inline(never)
  private func verifyActualCareerMissileSamplingJumpNeedsBothEndpointClockBounds(_ game: Game, birthTime: Double) throws {
    let entry = try OrdnanceClockFixture.opening(game, until: birthTime + 0.1)
    #expect(entry.state.origin.emittedAt == birthTime)
    let q = birthTime.ulp
    let a = q * (0.5 - 1.0 / 16)
    let b = q * (0.5 + 1.0 / 16)
    let left = try #require(entry.state(at: birthTime + a))
    let right = try #require(entry.state(at: birthTime + b))
    let leg = try #require(entry.guidanceLeg(at: birthTime))
    let jump = (right.position - left.position).length
    let physicalTravel = leg.velocity.length * (b - a)
    let seconds = try #require(entry.clockSamplingTimeError(start: birthTime, end: birthTime + q))
    let positionError = (leg.velocity.length.nextUp * seconds).nextUp
    #expect(jump > physicalTravel)
    #expect(jump <= physicalTravel + 2 * positionError)
    let ordnanceActualCheck44 = game.storedFlightSimulation().physicalTime == birthTime
    #expect(ordnanceActualCheck44)
  }

  @Test(arguments: [false, true])
  func actualCareerSamplingCannotClearASkippedThinSourceOrTargetCrossing(movingTarget: Bool) throws {
    let start = 86_400.0
    let game = try OrdnanceClockFixture.game(birthTime: start)
    let entry = try OrdnanceClockFixture.opening(game, until: start + 0.1)
    let window = try #require(NativeCurveClockWindow(start: start, end: start.nextUp))
    let initial = try #require(entry.state(at: start))
    let next = try #require(entry.state(at: start.nextUp))
    let displacement = next.position - initial.position
    try #require(displacement.x == 0 && displacement.y == 0 && displacement.z > 0)
    let middle = initial.position + displacement * 0.5
    let h = Vector3(0.1, 0.1, displacement.z / 8)
    let mesh = Mesh(vertices: [.init(-h.x, -h.y, -h.z), .init(h.x, -h.y, -h.z),
      .init(h.x, h.y, -h.z), .init(-h.x, h.y, -h.z), .init(-h.x, -h.y, h.z),
      .init(h.x, -h.y, h.z), .init(h.x, h.y, h.z), .init(-h.x, h.y, h.z)],
      faces: [[0, 3, 2], [0, 2, 1], [4, 5, 6], [4, 6, 7],
        [0, 1, 5], [0, 5, 4], [3, 7, 6], [3, 6, 2],
        [0, 4, 7], [0, 7, 3], [1, 2, 6], [1, 6, 5]])
    // Same closed box, with each original quad split along its own diagonal.
    // Preserve the adjacent-clock thickness; polygon cutoffs are not the oracle.
    let hull = try PreparedHull(mesh: mesh)
    #expect(hull.isClosed && hull.triangleCount == 12)
    let leg = try #require(entry.guidanceLeg(at: start))
    let seconds = try #require(entry.clockSamplingTimeError(start: start, end: window.end))
    let error = (leg.velocity.length.nextUp * seconds).nextUp
    // The real producer skips over this thin solid between adjacent absolute
    // clocks. Neither source nor target roles may claim a continuous clear.
    let result = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: window.duration, pointSpeed: movingTarget ? 0 : leg.velocity.length.nextUp,
      targetPointSpeed: movingTarget ? leg.velocity.length.nextUp : 0,
      pointAt: { elapsed in
        movingTarget ? .init(0, 0, 0) : entry.state(at: start + elapsed).map { $0.position - middle }
      }, targetAt: { elapsed in
        if !movingTarget { return .init() }
        return entry.state(at: start + elapsed).map { .init(position: $0.position - middle) }
      }, pointSamplingError: movingTarget ? 0 : error, targetSamplingError: movingTarget ? error : 0,
      clockWindow: window)
    guard case .refused(let report) = result else {
      Issue.record("Actual absolute-clock jump was promoted to a clear or contact"); return
    }
    #expect(report.failure == .unproven)
  }

  @Test func actualCareerMissileWitnessUsesTheRepresentableRetainedFrontier() throws {
    let start = 86_400.0
    let game = try OrdnanceClockFixture.game(birthTime: start)
    let entry = try OrdnanceClockFixture.opening(game, until: start + 0.1)
    let window = try #require(NativeCurveClockWindow(start: start, end: start + 0.1))
    let initial = entry.state.position
    let leg = try #require(entry.guidanceLeg(at: start))
    let centre = initial + leg.velocity * 0.04
    let hull = try PreparedHull(mesh: Mesh(vertices: [.init(-1, -1, -1), .init(1, -1, -1),
      .init(1, 1, -1), .init(-1, 1, -1), .init(-1, -1, 1), .init(1, -1, 1),
      .init(1, 1, 1), .init(-1, 1, 1)],
      faces: [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]))
    let seconds = try #require(entry.clockSamplingTimeError(start: start, end: window.end))
    let result = HullSweepSafety.firstCurrentNewtSphereCurveContact(target: hull, radius: 0,
      duration: window.duration, pointSpeed: leg.velocity.length.nextUp, targetPointSpeed: 0,
      pointAt: { entry.state(at: start + $0)?.position }, targetAt: { _ in .init(position: centre) },
      pointSamplingError: (leg.velocity.length.nextUp * seconds).nextUp, clockWindow: window)
    guard case .contact(let native, _) = result else {
      Issue.record("Real career missile did not retain a native representable witness"); return
    }
    let upper = try #require(native.upperPhysicalTime)
    let lower = try #require(native.lowerPhysicalTime)
    let actual = try #require(entry.state(at: upper))
    #expect(upper > start && upper <= window.end && lower >= start && lower <= upper)
    #expect(upper - start == native.upperTime && start + native.upperTime == upper)
    #expect(native.centre == actual.position)
    #expect(native.targetPose.position == centre)
  }

  @Test func actualOpeningAndT0QueryAreInertAndFullRetentionMatchesTheOriginalOwner() throws {
    var game = try OrdnanceClockFixture.game()
    try verifyActualOpeningAndT0QueryAreInertAndFullRetentionMatchesTheOriginalOwner(&game)
  }

  @inline(never)
  private func verifyActualOpeningAndT0QueryAreInertAndFullRetentionMatchesTheOriginalOwner(_ game: inout Game) throws {
    try verifyActualOpening(&game)
  }

  @inline(never)
  private func verifyActualOpening(_ game: inout Game) throws {
    let before = game
    let entry = try OrdnanceClockFixture.opening(game)
    let ownedPreparationRequired13 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired13)
    #expect(entry.state.origin.emittedAt == 0 && entry.state.lastUpdatedAt == 0)
    #expect(entry.actor == entry.state.origin.ordnance && entry.body.physical?.ordnance == entry.state)
    #expect(slice.contact == nil && slice.attainedEnd == 0.1)
    let ordnanceActualCheck45 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck45)
    let ordnanceActualCheck46 = game.scriptWorldSave == before.scriptWorldSave
    #expect(ordnanceActualCheck46)
    let ordnanceActualCheck47 = game.scriptSimulationSave.randomState == before.scriptSimulationSave.randomState
    #expect(ordnanceActualCheck47)
    let ordnanceActualCheck48 = game.missionLoopCounter == before.missionLoopCounter
    #expect(ordnanceActualCheck48)
    // An actual copy of the opening is used only as the old-path test control.
    var reference = before
    OrdnanceClockFixture.advanceClock(&reference, to: 0.1)
    OrdnanceClockFixture.advanceReference(&reference)
    try verifyOriginalTrajectory(&game, entry: entry, slice: slice, reference: reference)
  }

  @inline(never)
  private func verifyOriginalTrajectory(
    _ game: inout Game, entry: GameplayOrdnanceOpening, slice: GameplayOrdnancePreparedSlice,
    reference: Game
  ) throws {
    let expected = try OrdnanceClockFixture.state(reference, entry: entry)
    let displacement = expected.position - entry.state.position
    let first = try #require(entry.state(at: 0.025))
    let second = try #require(entry.state(at: 0.075))
    #expect((first.position - (entry.state.position + displacement * 0.25)).length < 1e-8)
    #expect((second.position - (entry.state.position + displacement * 0.75)).length < 1e-8)
    try retainOriginalTrajectory(&game, entry: entry, slice: slice, reference: reference, expected: expected)
  }

  @inline(never)
  private func retainOriginalTrajectory(
    _ game: inout Game, entry: GameplayOrdnanceOpening, slice: GameplayOrdnancePreparedSlice,
    reference: Game, expected: OrdnanceState
  ) throws {
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let flight = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(try OrdnanceClockFixture.state(game, entry: entry) == expected)
    let ordnanceActualCheck49 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck49)
    let ordnanceActualCheck50 = retained.applying(to: flight) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck50)
    let once = game
    let duplicate = try game.retainPreparedGameplayOrdnance(slice)
    let ordnanceActualCheck51 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck51)
  }

  @Test func threeAttainedPrefixesConsumeOneOriginalTrajectoryWithoutGuidanceRecalculation() throws {
    var game = try OrdnanceClockFixture.game()
    try verifyThreeAttainedPrefixesConsumeOneOriginalTrajectoryWithoutGuidanceRecalculation(&game)
  }

  @inline(never)
  private func verifyThreeAttainedPrefixesConsumeOneOriginalTrajectoryWithoutGuidanceRecalculation(_ game: inout Game) throws {
    let entry = try OrdnanceClockFixture.opening(game)
    var reference = game
    OrdnanceClockFixture.advanceClock(&reference, to: 0.1)
    OrdnanceClockFixture.advanceReference(&reference)
    for end in [0.025, 0.075, 0.1] {
      let ownedPreparationRequired14 = try game.prepareGameplayOrdnanceSlice(entry, until: end)
      let slice = try #require(ownedPreparationRequired14)
      #expect(slice.opening === entry && slice.contact == nil)
      OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
      let flight = game.storedFlightSimulation()
      let applied = try game.retainPreparedGameplayOrdnance(slice)
      let retained = try #require(applied)
      let state = try OrdnanceClockFixture.state(game, entry: entry)
      let sample = try #require(entry.state(at: end))
      #expect(entry.matchesCurrentState(state, at: end))
      #expect(!entry.matchesCurrentState(state, at: end + 0.001))
      #expect(state.position == sample.position && state.direction == sample.direction)
      #expect(state.propulsionTravel == sample.propulsionTravel && state.lastUpdatedAt == end)
      let ordnanceActualCheck52 = retained.applying(to: flight) == game.storedFlightSimulation()
      #expect(ordnanceActualCheck52)
    }
    #expect(try OrdnanceClockFixture.state(game, entry: entry)
      == OrdnanceClockFixture.state(reference, entry: entry))
    let ordnanceActualCheck53 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck53)
  }

  @Test func realT1BirthGetsNoEarlierMotionOrBorrowedOpeningMembership() throws {
    var game = try OrdnanceClockFixture.game(launch: false)
    try verifyRealT1BirthGetsNoEarlierMotionOrBorrowedOpeningMembership(&game)
  }

  @inline(never)
  private func verifyRealT1BirthGetsNoEarlierMotionOrBorrowedOpeningMembership(_ game: inout Game) throws {
    let ownedPreparationRequired15 = game.prepareGameplayOrdnanceFrame(until: 0.1)
    let original = try #require(ownedPreparationRequired15)
    try #require(original.entries.isEmpty)
    OrdnanceClockFixture.advanceClock(&game, to: 0.1)
    let launched = game.launchGameplayMissile(targetBodyID: 70)
    try #require(launched)
    let entry = try OrdnanceClockFixture.opening(game)
    #expect(entry.state.origin.emittedAt == 0.1 && entry.state.lastUpdatedAt == 0.1)
    #expect(entry.trajectory.legs.isEmpty && entry.state(at: 0.05) == nil)
    let ownedPreparationRequired16 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let zero = try #require(ownedPreparationRequired16)
    let before = game
    let applied = try game.retainPreparedGameplayOrdnance(zero)
    #expect(applied == nil && original.entries.isEmpty)
    let ordnanceActualCheck54 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck54)
    #expect(try OrdnanceClockFixture.state(game, entry: entry) == entry.state)
  }

  @Test func nativeFirstHitIsPreparedBeforeClockAndRetainedAtItsRealPrefixOnlyOnce() throws {
    var game = try OrdnanceClockFixture.game(distance: 1800)
    try verifyNativeFirstHitIsPreparedBeforeClockAndRetainedAtItsRealPrefixOnlyOnce(&game)
  }

  @inline(never)
  private func verifyNativeFirstHitIsPreparedBeforeClockAndRetainedAtItsRealPrefixOnlyOnce(_ game: inout Game) throws {
    let blocker = try exactCombatFixtureBody(&game, id: 71, position: .init(0, 0, 90))
    game.bodies.append(blocker)
    try OrdnanceClockFixture.alignSurface(&game, bodyID: 71)
    let entry = try OrdnanceClockFixture.opening(game)
    let before = game
    let ownedPreparationRequired17 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired17)
    try #require(slice.contact?.hit.target == .body(71))
    try #require(slice.attainedEnd > 0 && slice.attainedEnd < 0.1)
    let ordnanceActualCheck55 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck55)
    var reference = before
    OrdnanceClockFixture.advanceClock(&reference, to: 0.1)
    OrdnanceClockFixture.advanceReference(&reference)
    try verifyRetainedNativeFirstHit(&game, entry: entry, before: before, slice: slice, reference: reference)
  }

  @inline(never)
  private func verifyRetainedNativeFirstHit(
    _ game: inout Game, entry: GameplayOrdnanceOpening, before: Game,
    slice: GameplayOrdnancePreparedSlice, reference: Game
  ) throws {
    let originalImpact = try OrdnanceClockFixture.state(reference, entry: entry)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let clock = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(retained.update.hit?.target == .body(71) && retained.update.termination == .impact)
    #expect(retained.motionRetained && originalImpact.termination == .impact)
    let actual = try OrdnanceClockFixture.state(game, entry: entry)
    #expect(actual.lastUpdatedAt == slice.attainedEnd && actual.lastUpdatedAt < slice.requestedEnd)
    #expect(actual.position == slice.proposed.position && actual.propulsionTravel == slice.proposed.propulsionTravel)
    #expect((retained.update.position - originalImpact.position).length < 1e-7)
    let ordnanceActualCheck56 = game.bodies.first { $0.id == 71 }?.energy == reference.bodies.first { $0.id == 71 }?.energy
    #expect(ordnanceActualCheck56)
    #expect(retained.update.incident?.physicalTime == slice.attainedEnd)
    let ordnanceActualCheck57 = game.bodies.first { $0.id == 70 }?.energy == before.bodies.first { $0.id == 70 }?.energy
    #expect(ordnanceActualCheck57)
    let ordnanceActualCheck58 = retained.applying(to: clock) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck58)
    try #require(retained.clockEffects.count == 1)
    var wrong = clock
    wrong.advancePhysicalTime(0.001)
    #expect(retained.applying(to: wrong) == nil)
    var wrongPose = clock
    wrongPose.pose.position.x += 1
    #expect(retained.applying(to: wrongPose) == nil)
    let once = game
    let duplicate = try game.retainPreparedGameplayOrdnance(slice)
    let ordnanceActualCheck59 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck59)
  }

  @Test func interveningGeometryOrEpochChangeRefusesWithoutImpactOrCursorMutation() throws {
    for changeEpoch in [false, true] {
      var game = try OrdnanceClockFixture.game(distance: 90)
      try OrdnanceClockFixture.alignSurface(&game, bodyID: 70)
      let entry = try OrdnanceClockFixture.opening(game)
      let ownedPreparationRequired18 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
      let slice = try #require(ownedPreparationRequired18)
      try #require(slice.contact != nil)
      OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
      if changeEpoch { game.nativeStationRuntimeEpoch = UUID() }
      else {
        let indexCandidate3 = game.bodies.firstIndex { $0.id == 70 }
        let index = try #require(indexCandidate3)
        game.bodies[index].position.x += 1000
      }
      let before = game
      let refused = try game.retainPreparedGameplayOrdnance(slice)
      let ordnanceActualCheck60 = refused == nil && game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
      #expect(ordnanceActualCheck60)
      let ordnanceActualCheck61 = game.scriptWorldSave == before.scriptWorldSave
      #expect(ordnanceActualCheck61)
    }
  }

  @Test func actualECMActivationEndsTheMissileWithoutCommittingItsPreparedMotion() throws {
    var game = try OrdnanceClockFixture.game()
    try verifyActualECMActivationEndsTheMissileWithoutCommittingItsPreparedMotion(&game)
  }

  @inline(never)
  private func verifyActualECMActivationEndsTheMissileWithoutCommittingItsPreparedMotion(_ game: inout Game) throws {
    let entry = try OrdnanceClockFixture.opening(game)
    let ownedPreparationRequired19 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired19)
    let ordnanceActualCheck62 = game.storedFlightSimulation().player
    let player = try #require(ordnanceActualCheck62)
    let activated = game.activateOrdnanceECM(emitter: player)
    try #require(activated)
    let ordnanceActualCheck63 = game.activeECMActivation
    let pulse = try #require(ordnanceActualCheck63)
    var reference = game
    OrdnanceClockFixture.advanceClock(&reference, to: 0.1)
    var controlState = entry.state
    let ownedPreparationRequired20 = reference.gameplayContext()
    let context = try #require(ownedPreparationRequired20)
    let control = reference.advanceOrdnance(bodyID: entry.body.id, state: &controlState,
      context: context, activeECM: [pulse])
    OrdnanceClockFixture.advanceClock(&game, to: 0.1)
    let flight = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice, activeECM: [pulse])
    let retained = try #require(applied)
    let state = try OrdnanceClockFixture.state(game, entry: entry)
    #expect(state == controlState && retained.update == control)
    #expect(state.position == entry.state.position && state.lastUpdatedAt == entry.state.lastUpdatedAt)
    #expect(retained.clockEffects.isEmpty && retained.applying(to: flight) == flight)
  }

  @Test func genuineMissionImpactDestructionProjectsOnceAndReturnsTheActualAllocation() throws {
    var (game, _) = try OrdnanceClockFixture.mission()
    try verifyGenuineMissionImpactDestructionProjectsOnceAndReturnsTheActualAllocation(&game)
  }

  @inline(never)
  private func verifyGenuineMissionImpactDestructionProjectsOnceAndReturnsTheActualAllocation(_ game: inout Game) throws {
    try verifyMissionImpact(&game)
  }

  @inline(never)
  private func verifyMissionImpact(_ game: inout Game) throws {
    let entry = try OrdnanceClockFixture.opening(game)
    let before = game
    let ownedPreparationRequired21 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired21)
    let target = try #require(slice.contact?.selectedTargetBody)
    try #require(target.scriptNPC != nil && slice.contact?.victimPart == nil)
    #expect((slice.contact?.hit.distance ?? 0) > 0)
    #expect(slice.attainedEnd > slice.context.physicalTime && slice.attainedEnd <= 0.1)
    let ordnanceActualCheck64 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck64)
    var reference = before
    OrdnanceClockFixture.advanceClock(&reference, to: slice.attainedEnd)
    OrdnanceClockFixture.advanceReference(&reference)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let clock = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(retained.update.termination == .impact && retained.update.incident?.victim == target.physical?.identity)
    let ordnanceActualCheck65 = game.bodies.first { $0.id == target.id }?.energy == 0
    #expect(ordnanceActualCheck65)
    let ordnanceActualCheck66 = retained.applying(to: clock) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck66)
    try #require(retained.clockEffects.count == 1)
    guard case .mission(let effect) = retained.clockEffects[0] else {
      Issue.record("Mission contact bypassed its native mission allocation owner")
      return
    }
    #expect(effect.incident == retained.update.incident)
    let oldSequences = Set(before.commander.scriptState.pendingEvents.map(\.sequence))
    let events = game.commander.scriptState.pendingEvents.filter { !oldSequences.contains($0.sequence) }
    let referenceEvents = reference.commander.scriptState.pendingEvents.filter {
      !oldSequences.contains($0.sequence)
    }
    let actor = try #require(target.missionActorID)
    let damaged = events.filter { $0.kind == "actor.damaged" }
    let destroyed = events.filter { $0.kind == "actor.destroyed" }
    #expect(damaged.count == 1 && destroyed.count == 1)
    let allSatisfied = events.allSatisfy {
      $0.instance == target.missionInstanceID && $0.values["actor_id"] == .string(actor.uuidString)
    }
    #expect(allSatisfied)
    #expect(Set(events.map(\.sequence)).count == events.count && events == referenceEvents)
    let ordnanceActualCheck67 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck67)
    let ordnanceActualCheck68 = game.commander.crimeLedger == reference.commander.crimeLedger
    #expect(ordnanceActualCheck68)
    let ordnanceActualCheck69 = game.commander.credits == reference.commander.credits && game.commander.kills == reference.commander.kills
    #expect(ordnanceActualCheck69)
    var wrong = clock
    _ = wrong.allocateIncident()
    #expect(effect.applying(to: wrong) == nil)
    let once = game
    let duplicate = try game.retainPreparedGameplayOrdnance(slice)
    let ordnanceActualCheck70 = duplicate == nil && game.currentNewtNativeCommanderMatches(once) && game.bodies == once.bodies
    #expect(ordnanceActualCheck70)
    let ordnanceActualCheck71 = game.commander.scriptState.pendingEvents == once.commander.scriptState.pendingEvents
    #expect(ordnanceActualCheck71)
  }

  @Test func fullMissionQueueKeepsTheOriginalRetryRollbackAndPublishesNoImpact() throws {
    for tinyPrefix in [false, true] {
      var (game, instance) = try OrdnanceClockFixture.mission()
      try verifyFullMissionQueueRefusal(&game, instance: instance, tinyPrefix: tinyPrefix)
    }
  }

  @inline(never)
  private func verifyFullMissionQueueRefusal(_ game: inout Game, instance: UUID, tinyPrefix: Bool) throws {
    let entry = try OrdnanceClockFixture.opening(game)
    let slice = try OrdnanceClockFixture.impactSlice(&game, entry: entry, tinyPrefix: tinyPrefix)
    for _ in game.commander.scriptState.pendingEvents.count..<4096 {
      game.emitScriptEvent("capacity.probe", values: [:], only: instance, drain: false)
    }
    let ordnanceActualCheck72 = game.commander.scriptState.pendingEvents.count == 4096
    try #require(ordnanceActualCheck72)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let before = game
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(retained.update.hit == nil && retained.update.incident == nil)
    #expect(retained.update.termination == nil && retained.clockEffects.isEmpty)
    #expect(!retained.motionRetained)
    #expect(try OrdnanceClockFixture.state(game, entry: entry) == slice.before)
    if !tinyPrefix { #expect(try OrdnanceClockFixture.state(game, entry: entry) == entry.state) }
    let ordnanceActualCheck73 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck73)
    let ordnanceActualCheck74 = retained.applying(to: before.storedFlightSimulation()) == before.storedFlightSimulation()
    #expect(ordnanceActualCheck74)
  }

  @Test func t0MissionCapacityRefusalIsReadonlyAndCannotAdvanceTheRealClock() throws {
    var (game, instance) = try OrdnanceClockFixture.mission()
    try verifyT0MissionCapacityRefusalIsReadonlyAndCannotAdvanceTheRealClock(&game, instance: instance)
  }

  @inline(never)
  private func verifyT0MissionCapacityRefusalIsReadonlyAndCannotAdvanceTheRealClock(_ game: inout Game, instance: UUID) throws {
    try verifyMissionCapacity(&game, instance: instance)
  }

  @inline(never)
  private func verifyMissionCapacity(_ game: inout Game, instance: UUID) throws {
    let entry = try OrdnanceClockFixture.opening(game)
    try OrdnanceClockFixture.requirePositiveMissionSlice(game, entry: entry)
    for _ in game.commander.scriptState.pendingEvents.count..<4096 {
      game.emitScriptEvent("capacity.probe", values: [:], only: instance, drain: false)
    }
    let before = game
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    }
    let ordnanceActualCheck75 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck75)
    let ordnanceActualCheck76 = game.scriptWorldSave == before.scriptWorldSave
    #expect(ordnanceActualCheck76)
    let ordnanceActualCheck77 = game.storedFlightSimulation().physicalTime == 0
    #expect(ordnanceActualCheck77)
  }

  @Test func lostTargetPreparationDoesNotCleanUpUntilTheActualPrefixIsRetained() throws {
    var game = try OrdnanceClockFixture.game()
    try verifyLostTargetPreparationDoesNotCleanUpUntilTheActualPrefixIsRetained(&game)
  }

  @inline(never)
  private func verifyLostTargetPreparationDoesNotCleanUpUntilTheActualPrefixIsRetained(_ game: inout Game) throws {
    let indexCandidate4 = game.bodies.firstIndex { $0.id == 70 }
    let index = try #require(indexCandidate4)
    game.bodies[index].energy = 0
    let before = game
    let entry = try OrdnanceClockFixture.opening(game)
    let ownedPreparationRequired22 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired22)
    #expect(slice.proposed.termination == .targetLost && slice.attainedEnd == 0.1)
    let ordnanceActualCheck78 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck78)
    var reference = before
    OrdnanceClockFixture.advanceClock(&reference, to: 0.1)
    OrdnanceClockFixture.advanceReference(&reference)
    OrdnanceClockFixture.advanceClock(&game, to: 0.1)
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(retained.motionRetained && retained.update.termination == .targetLost)
    #expect(try OrdnanceClockFixture.state(game, entry: entry)
      == OrdnanceClockFixture.state(reference, entry: entry))
    let ordnanceActualCheck79 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck79)
  }

  @Test func finiteRangeEndsAtItsOriginalBoundaryWithoutBorrowingTheRemainingOuterTime() throws {
    var game = try OrdnanceClockFixture.game(distance: 20000)
    try verifyFiniteRangeEndsAtItsOriginalBoundaryWithoutBorrowingTheRemainingOuterTime(&game)
  }

  @inline(never)
  private func verifyFiniteRangeEndsAtItsOriginalBoundaryWithoutBorrowingTheRemainingOuterTime(_ game: inout Game) throws {
    OrdnanceClockFixture.advanceClock(&game, to: 7.5)
    game.advanceGameplayOrdnance(allowEnemyECM: false)
    let entry = try OrdnanceClockFixture.opening(game, until: 7.6)
    let ownedPreparationRequired23 = try game.prepareGameplayOrdnanceSlice(entry, until: 7.6)
    let slice = try #require(ownedPreparationRequired23)
    try #require(slice.proposed.termination == .rangeExpired)
    try #require(slice.attainedEnd > 7.5 && slice.attainedEnd < 7.6)
    #expect(entry.state(at: 7.6) == nil)
    var reference = game
    OrdnanceClockFixture.advanceClock(&reference, to: 7.6)
    OrdnanceClockFixture.advanceReference(&reference)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let flight = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    let state = try OrdnanceClockFixture.state(game, entry: entry)
    let expected = try OrdnanceClockFixture.state(reference, entry: entry)
    #expect(state == expected)
    #expect(state.valid && state.propulsionTravel == OrdnanceProfile.standardMissile.range)
    #expect(state.lastUpdatedAt == slice.attainedEnd && retained.update.termination == .rangeExpired)
    let ordnanceActualCheck80 = retained.applying(to: flight) == flight && game.commander.kills == 0
    #expect(ordnanceActualCheck80)
  }

  @Test(arguments: [false, true], [false, true])
  func lateAllocatorOrLedgerRefusalCannotPublishPartialOrdinaryOrMissionState(
    mission: Bool, allocatorEdge: Bool
  ) throws {
    for tinyPrefix in [false, true] {
      var game = mission ? try OrdnanceClockFixture.mission().0 : try OrdnanceClockFixture.game(distance: 90)
      try verifyLateRefusal(&game, mission: mission, allocatorEdge: allocatorEdge, tinyPrefix: tinyPrefix)
    }
  }

  @inline(never)
  private func verifyLateRefusal(
    _ game: inout Game, mission: Bool, allocatorEdge: Bool, tinyPrefix: Bool
  ) throws {
    if !mission { try OrdnanceClockFixture.alignSurface(&game, bodyID: 70) }
    game.gameplayCombatTrace = .init()
    let entry = try OrdnanceClockFixture.opening(game)
    let slice = try OrdnanceClockFixture.impactSlice(&game, entry: entry, tinyPrefix: tinyPrefix)
    // The source preflight was genuine. The refusal is introduced only afterward.
    try OrdnanceClockFixture.refuseNextHit(&game, allocatorEdge: allocatorEdge)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let before = game
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let refused = try #require(applied)
    #expect(!refused.motionRetained && refused.clockEffects.isEmpty)
    #expect(refused.update.hit == nil && refused.update.incident == nil)
    let ordnanceActualCheck81 = game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies
    #expect(ordnanceActualCheck81)
    let ordnanceActualCheck82 = game.scriptWorldSave == before.scriptWorldSave && game.message == before.message
    #expect(ordnanceActualCheck82)
    let ordnanceActualCheck83 = game.nextBodyID == before.nextBodyID && game.energy == before.energy
    #expect(ordnanceActualCheck83)
    let ordnanceActualCheck84 = game.frontShield == before.frontShield && game.rearShield == before.rearShield
    #expect(ordnanceActualCheck84)
    let ordnanceActualCheck85 = game.gameplayCombatTrace?.incidents == before.gameplayCombatTrace?.incidents
    #expect(ordnanceActualCheck85)
    let ordnanceActualCheck86 = game.dischargeAudio.events == before.dischargeAudio.events
    #expect(ordnanceActualCheck86)
    let ordnanceActualCheck87 = game.scriptSimulationSave.randomState == before.scriptSimulationSave.randomState
    #expect(ordnanceActualCheck87)
    let ordnanceActualCheck88 = refused.applying(to: before.storedFlightSimulation()) == before.storedFlightSimulation()
    #expect(ordnanceActualCheck88)
  }

  @Test(arguments: [false, true])
  func realNPCMissilePlayerSurvivalAndFatalHitMatchTheOriginalOwner(fatal: Bool) throws {
    var game = try OrdnanceClockFixture.game(launch: false)
    try verifyRealNPCMissilePlayerSurvivalAndFatalHitMatchTheOriginalOwner(&game, fatal: fatal)
  }

  @inline(never)
  private func verifyRealNPCMissilePlayerSurvivalAndFatalHitMatchTheOriginalOwner(_ game: inout Game, fatal: Bool) throws {
    let mesh = game.commander.playerMesh
    let surface = try #require(mesh.faces.lazy.compactMap { face -> Vector3? in
      guard face.count == 3, face.allSatisfy(mesh.vertices.indices.contains) else { return nil }
      let a = mesh.vertices[face[0]], b = mesh.vertices[face[1]], c = mesh.vertices[face[2]]
      let center = (a + b + c) * (1 / 3.0)
      return center.finite && center.z > 0 && (b - a).cross(c - a).length > 0 ? center : nil
    }.first)
    let indexCandidate5 = game.bodies.firstIndex { $0.id == 70 }
    let index = try #require(indexCandidate5)
    game.bodies[index].position = surface.unit * (surface.length + 64)
    // Same declared one-round controlled NPC source as the existing launcher oracle.
    game.bodies[index].missiles = 1
    game.frontShield = fatal ? 0 : 255
    game.rearShield = fatal ? 0 : 255
    if fatal { game.energy = 1 }
    let launched = game.launchGameplayNPCMissile(bodyID: 70)
    try #require(launched)
    let entry = try OrdnanceClockFixture.opening(game)
    let ownedPreparationRequired24 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired24)
    try #require(slice.contact?.hit.target == .player && slice.attainedEnd > 0)
    var reference = game
    OrdnanceClockFixture.advanceClock(&reference, to: slice.attainedEnd)
    OrdnanceClockFixture.advanceReference(&reference)
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let clock = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    let ordnanceActualCheck89 = retained.motionRetained && (game.energy <= 0) == fatal
    #expect(ordnanceActualCheck89)
    let ordnanceActualCheck90 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck90)
    let ordnanceActualCheck91 = game.energy == reference.energy && game.frontShield == reference.frontShield
    #expect(ordnanceActualCheck91)
    let ordnanceActualCheck92 = game.rearShield == reference.rearShield
    #expect(ordnanceActualCheck92)
    let ordnanceActualCheck93 = retained.applying(to: clock) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck93)
    let ordnanceActualCheck94 = game.storedFlightSimulation().nextIncident - clock.nextIncident == (fatal ? 2 : 1)
    #expect(ordnanceActualCheck94)
  }

  @Test func twoRealMissilesRetainInterceptionWithoutShipKillOrLaterProjectileMotion() throws {
    var game = try OrdnanceClockFixture.game(distance: 90, launch: false)
    try verifyTwoRealMissilesRetainInterceptionWithoutShipKillOrLaterProjectileMotion(&game)
  }

  @inline(never)
  private func verifyTwoRealMissilesRetainInterceptionWithoutShipKillOrLaterProjectileMotion(_ game: inout Game) throws {
    let ownerCandidate = game.bodies.firstIndex { $0.id == 70 }
    let owner = try #require(ownerCandidate)
    var orientation = Basis3()
    orientation.rotate(pitch: .pi / 2, roll: 0, yaw: 0)
    game.bodies[owner].orientation = orientation
    game.bodies[owner].missiles = 1
    let playerLaunch = game.launchGameplayMissile(targetBodyID: 70)
    let npcLaunch = game.launchGameplayNPCMissile(bodyID: 70)
    try #require(playerLaunch && npcLaunch)
    let ownedPreparationRequired25 = game.prepareGameplayOrdnanceFrame(until: 0.1)
    let frame = try #require(ownedPreparationRequired25)
    let entryCandidate = frame.entries.first {
      $0.state.origin.owner == game.storedFlightSimulation().player
    }
    let entry = try #require(entryCandidate)
    let interceptedCandidate = frame.entries.first { $0.actor != entry.actor }
    let intercepted = try #require(interceptedCandidate)
    let ownedPreparationRequired26 = try game.prepareGameplayOrdnanceSlice(entry, until: 0.1)
    let slice = try #require(ownedPreparationRequired26)
    try #require(slice.contact?.hit.target == .body(intercepted.body.id) && slice.attainedEnd > 0)
    var reference = game
    OrdnanceClockFixture.advanceClock(&reference, to: slice.attainedEnd)
    var controlState = entry.state
    let ownedPreparationRequired27 = reference.gameplayContext()
    let context = try #require(ownedPreparationRequired27)
    let expected = reference.advanceOrdnance(bodyID: entry.body.id, state: &controlState, context: context)
    let indexCandidate6 = reference.bodies.firstIndex { $0.id == entry.body.id }
    let index = try #require(indexCandidate6)
    reference.bodies[index].physical?.ordnance = controlState
    OrdnanceClockFixture.advanceClock(&game, to: slice.attainedEnd)
    let clock = game.storedFlightSimulation()
    let applied = try game.retainPreparedGameplayOrdnance(slice)
    let retained = try #require(applied)
    #expect(retained.motionRetained && retained.update == expected)
    #expect(retained.update.incident?.outcome == .ordnanceInterception)
    let ordnanceActualCheck95 = game.currentNewtNativeCommanderMatches(reference) && game.bodies == reference.bodies
    #expect(ordnanceActualCheck95)
    let ordnanceActualCheck96 = game.commander.kills == 0 && retained.applying(to: clock) == game.storedFlightSimulation()
    #expect(ordnanceActualCheck96)
    let targetState = try OrdnanceClockFixture.state(game, entry: intercepted)
    #expect(targetState == intercepted.state)
  }
}
