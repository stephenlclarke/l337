import Foundation

/// These constructors belong to the native interval owner in this file. Saved
/// DTOs and collision callers cannot supply clock legs or a completed witness.
private enum CurrentNewtNativeBoundaryEvent: Sendable {
  case birth(CurrentNewtKitReceipt)
  case ordnance(GameplayOrdnanceRetention)

  func applying(to before: FlightSimulationState) -> FlightSimulationState? {
    switch self {
    case .birth(let receipt):
      guard receipt.structurallyValid, receipt.releasedAt == before.physicalTime else { return nil }
      var next = before
      guard next.allocateActor() == receipt.podActor else { return nil }
      return next
    case .ordnance(let receipt):
      return receipt.motionRetained ? receipt.applying(to: before) : nil
    }
  }
}

private struct CurrentNewtNativeClockLeg: Sendable {
  let beforeBoundary: FlightSimulationState
  let boundaryEvents: [CurrentNewtNativeBoundaryEvent]
  var boundaryBirths: [CurrentNewtKitReceipt] {
    boundaryEvents.compactMap {
      if case .birth(let receipt) = $0 { return receipt }
      return nil
    }
  }
  let opening: CurrentNewtNativeSegmentOpening
  let trajectory: CurrentNewtOuterMotion
  let afterClock: FlightSimulationState
  let afterMotion: FlightSimulationState
  let resolution: CurrentNewtNativeContactResolution
  let result: CurrentNewtMechanicalSegmentResult
  let impactEffects: [NativeDebrisImpactClockEffect]
  let ordnanceEffects: [GameplayOrdnanceRetention]
  let afterBodies: [SpaceBody]
}

/// A legacy effect phase selected by the real native clock owner. Only that
/// owner can join the original decision to its actual completed interval.
// Synchronous local recorder; it never leaves the simulation owner or enters a Task.
final class CurrentNewtLegacyEffectContext {
  let decision: LegacyNPCFlightDecision
  let plan: SelectedNPCBeamPlan?
  let evidence: CurrentNewtNativeClockEvidence
  let admittedAtEnd: CurrentNewtEndBirths?
  private(set) var acceptedCombat: NativeCombatHitClockEffect?
  private(set) var acceptedMission: NativeMissionBeamClockEffect?

  func recordAccepted(_ effect: NativeCombatHitClockEffect) { acceptedCombat = effect }
  func recordAccepted(_ effect: NativeMissionBeamClockEffect) { acceptedMission = effect }

  fileprivate init(
    decision: LegacyNPCFlightDecision, plan: SelectedNPCBeamPlan?,
    evidence: CurrentNewtNativeClockEvidence, admittedAtEnd: CurrentNewtEndBirths?
  ) {
    self.decision = decision
    self.plan = plan
    self.evidence = evidence
    self.admittedAtEnd = admittedAtEnd
  }
}

final class CurrentNewtNativeClockEvidence: Sendable {
  private let original: CurrentNewtOuterMotion
  private let originalBodies: [SpaceBody]
  private let selectedBeamPlans: [ActorIdentity: SelectedNPCBeamPlan]
  private let legs: [CurrentNewtNativeClockLeg]
  private let endTime: Double
  private let terminalEvents: [CurrentNewtNativeBoundaryEvent]
  private var terminalBirths: [CurrentNewtKitReceipt] {
    terminalEvents.compactMap {
      if case .birth(let receipt) = $0 { return receipt }
      return nil
    }
  }
  var npcFrame: CurrentNewtNPCFrame? { legs.first?.opening.npcFrame }
  var completedOuterInterval: Bool { endTime == original.endTime }
  var attainedDuration: Double {
    completedOuterInterval ? original.motion.duration : endTime - original.startTime
  }

  fileprivate init(
    original: CurrentNewtOuterMotion, originalBodies: [SpaceBody],
    selectedBeamPlans: [ActorIdentity: SelectedNPCBeamPlan], legs: [CurrentNewtNativeClockLeg],
    endTime: Double, terminalEvents: [CurrentNewtNativeBoundaryEvent]
  ) {
    self.original = original
    self.originalBodies = originalBodies
    self.selectedBeamPlans = selectedBeamPlans
    self.legs = legs
    self.endTime = endTime
    self.terminalEvents = terminalEvents
  }

  /// Rebuild the closing flight state from actual pure clock legs, selected
  /// native motion and individual occupied-pod birth receipts. A copied closing
  /// pose/counter snapshot alone cannot satisfy this chain.
  @inline(never)
  func verifiedFinalFlight(
    from start: FlightSimulationState, usedD: Double, epoch: UUID
  ) -> FlightSimulationState? {
    guard !legs.isEmpty, original.startTime == start.physicalTime,
      usedD.isFinite, usedD > 0, usedD <= original.motion.duration + 1e-9,
      endTime <= original.endTime, endTime == start.physicalTime + usedD,
      original.motion.start == start.pose,
      original.epoch == epoch
    else { return nil }
    var expected = start
    for leg in legs {
      let interval = leg.opening.interval
      guard expected == leg.beforeBoundary else { return nil }
      for event in leg.boundaryEvents {
        guard let next = event.applying(to: expected) else { return nil }
        expected = next
      }
      guard interval.valid, leg.trajectory.rootMotion === original,
        leg.opening.before.nativeStationRuntimeEpoch == epoch,
        leg.opening.before.storedFlightSimulation() == expected,
        interval.start == expected.physicalTime, interval.end <= endTime,
        leg.trajectory.subrange(interval) == leg.opening.playerMotion,
        leg.trajectory.state(at: interval.end) == leg.opening.playerEnd,
        leg.resolution.admitted, leg.resolution.player.structurallyValid,
        leg.result.acceptedDuration == interval.end - interval.start
      else { return nil }
      expected.advancePhysicalTime(interval.end - interval.start)
      guard expected == leg.afterClock else { return nil }
      expected.pose = leg.opening.playerEnd.pose
      for effect in leg.impactEffects {
        guard let applied = effect.applying(to: expected) else { return nil }
        expected = applied
      }
      if leg.resolution.player.pose != leg.opening.playerEnd.pose {
        guard let player = expected.player, leg.resolution.stoppedAt[player] != nil else {
          return nil
        }
      }
      expected.pose = leg.resolution.player.pose
      for receipt in leg.result.released {
        guard receipt.structurallyValid, receipt.releasedAt == interval.end,
          expected.allocateActor() == receipt.podActor
        else { return nil }
      }
      for receipt in leg.ordnanceEffects {
        guard receipt.motionRetained, let next = receipt.applying(to: expected) else { return nil }
        expected = next
      }
      guard expected == leg.afterMotion else { return nil }
    }
    guard expected.physicalTime == endTime else { return nil }
    for event in terminalEvents {
      guard let next = event.applying(to: expected) else { return nil }
      expected = next
    }
    return expected
  }

  /// Join a sealed actual opening geometry snapshot to this owner's real
  /// retained endpoints. Later admission must come from Game's actual census,
  /// never from a caller-supplied actor set or a copied closing flight value.
  @inline(never)
  func retainedSceneMatches(
    opening: FlightSimulationState, bodies: [SpaceBody], epoch: UUID,
    current game: Game, admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> Bool {
    guard let first = legs.first,
      (opening == first.beforeBoundary && bodies == originalBodies)
        || (opening == first.opening.before.storedFlightSimulation()
          && bodies == first.opening.before.bodies),
      opening.physicalTime == original.startTime,
      completedOuterInterval, terminalEvents.isEmpty,
      let closing = legs.last?.afterMotion, let retained = legs.last?.afterBodies,
      verifiedFinalFlight(from: first.beforeBoundary, usedD: attainedDuration, epoch: epoch)
        == closing,
      game.nativeStationRuntimeEpoch == epoch,
      game.storedFlightSimulation().physicalTime == closing.physicalTime,
      game.storedFlightSimulation().pose == closing.pose,
      game.storedFlightSimulation().system == closing.system,
      game.storedFlightSimulation().visit == closing.visit,
      game.storedFlightSimulation().player == closing.player,
      admittedAtEnd?.matches(game) ?? true
    else { return false }
    return retainedBodiesMatch(
      retained, closing: closing, current: game, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func retainedBodiesMatch(
    _ retained: [SpaceBody], closing: FlightSimulationState, current game: Game,
    admittedAtEnd: CurrentNewtEndBirths?
  ) -> Bool {
    let retainedActors = retained.compactMap { $0.physical?.identity }
    let currentActors = game.bodies.compactMap { $0.physical?.identity }
    let additions = admittedAtEnd?.allActors ?? []
    guard retainedActors.count == retained.count, currentActors.count == game.bodies.count,
      Set(retainedActors).count == retained.count, Set(currentActors).count == game.bodies.count,
      Set(retainedActors).isDisjoint(with: additions),
      Set(currentActors) == Set(retainedActors).union(additions)
    else { return false }
    for before in retained {
      guard let physical = before.physical,
        let body = game.bodies.first(where: { $0.physical?.identity == physical.identity }),
        body.id == before.id, body.hull == before.hull,
        body.missionActorID == before.missionActorID,
        body.missionInstanceID == before.missionInstanceID,
        body.scriptNPC?.fit == before.scriptNPC?.fit,
        body.physical?.catalogueShipID == physical.catalogueShipID,
        body.physical?.spawnIdentity == physical.spawnIdentity,
        body.physical?.currentNewtKitStock == physical.currentNewtKitStock,
        body.physical?.currentNewtKitReceipt == physical.currentNewtKitReceipt
      else { return false }
      let expected = Game.modelPose(of: before, player: closing.pose)
      let actual = game.modelPose(of: body)
      guard (expected.position - actual.position).length < 1e-7,
        (expected.orientation.x - actual.orientation.x).length < 1e-7,
        (expected.orientation.y - actual.orientation.y).length < 1e-7,
        (expected.orientation.z - actual.orientation.z).length < 1e-7
      else { return false }
    }
    return true
  }

  @inline(never)
  func legacyEffectContext(
    for actor: ActorIdentity, path: CurrentNewtOuterMotion,
    admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> CurrentNewtLegacyEffectContext? {
    guard completedOuterInterval, path === original,
      let decision = legs.first?.opening.npcFrame?.entries[actor]?.legacy
    else { return nil }
    return .init(
      decision: decision, plan: selectedBeamPlans[actor], evidence: self,
      admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  func selectedLegacyBeamPlan(for actor: ActorIdentity, path: CurrentNewtOuterMotion)
    -> SelectedNPCBeamPlan?
  {
    guard path === original else { return nil }
    return selectedBeamPlans[actor]
  }

  /// Original per-body legacy effect geometry, derived from the actual first
  /// opening and its once-selected paths. This is never a caller's pose map.
  @inline(never)
  func selectedLegacyBeamModelPoses(
    geometry: MissionCollisionQueryGeometry, source: ActorIdentity, current game: Game,
    admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> [ActorIdentity: ShipPose]? {
    guard validatesSelectedBeamGeometry(geometry, closing: game, admittedAtEnd: admittedAtEnd)
    else { return nil }
    return selectedLegacyBeamModelPosesAfterValidation(
      geometry: geometry, source: source, current: game, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func selectedLegacyBeamModelPosesAfterValidation(
    geometry: MissionCollisionQueryGeometry, source: ActorIdentity, current game: Game,
    admittedAtEnd: CurrentNewtEndBirths?
  ) -> [ActorIdentity: ShipPose]? {
    guard let first = legs.first, let frame = first.opening.npcFrame,
      let entry = frame.entries[source], let legacy = entry.legacy,
      let sourceIndex = first.opening.before.bodies.firstIndex(where: {
        $0.physical?.identity == source
      }), let live = game.bodies.first(where: { $0.physical?.identity == source }),
      live.energy > 0, !game.isEMPDisabled(live), live.scriptNPC == nil,
      live.physical?.npc?.intention == legacy.intention,
      live.blackjackIdentity == legacy.blackjackIdentity
    else { return nil }
    let opening = first.opening.before
    let camera = opening.storedFlightSimulation().pose
    let projected = opening.currentNewtPostCameraBodies(original)
    var result: [ActorIdentity: ShipPose] = [:]
    for (index, body) in opening.bodies.enumerated() {
      guard let actor = body.physical?.identity, result[actor] == nil else { return nil }
      var pose = Game.modelPose(of: body, player: camera)
      if index <= sourceIndex {
        if !original.workMode {
          guard projected.indices.contains(index), projected[index].physical?.identity == actor
          else { return nil }
          pose = Game.modelPose(of: projected[index], player: original.motion.end)
        }
        if let prior = frame.entries[actor]?.legacy { pose.position = prior.worldEnd }
      }
      if body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil {
        guard let retained = game.bodies.first(where: { $0.physical?.identity == actor })
        else { return nil }
        pose = game.modelPose(of: retained)
      }
      result[actor] = pose
    }
    let receipts = legs.flatMap { $0.boundaryBirths + $0.result.released }
    for receipt in receipts where result[receipt.podActor] == nil {
      guard let born = game.bodies.first(where: { $0.physical?.identity == receipt.podActor }),
        born.physical?.currentNewtKitReceipt == receipt,
        (try? game.currentNewtGeometryComponents(for: born)) != nil
      else { return nil }
      result[receipt.podActor] = game.modelPose(of: born)
    }
    if let admittedAtEnd {
      guard let additions = admittedAtEnd.modelPoses(in: game) else { return nil }
      for (actor, pose) in additions {
        guard result[actor] == nil else { return nil }
        result[actor] = pose
      }
    }
    return result
  }

  /// New native mechanism components use their actual retained physical phase.
  /// A released pod cannot also remain attached in a captured older compound.
  /// Every actor comes from the real opening, a recorded release or actual T1 admission.
  @inline(never)
  func selectedLegacyBeamComponents(
    geometry: MissionCollisionQueryGeometry, source: ActorIdentity, current game: Game,
    admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> [ActorIdentity: [CurrentNewtKitComponent]]? {
    guard
      selectedLegacyBeamModelPoses(
        geometry: geometry, source: source,
        current: game, admittedAtEnd: admittedAtEnd) != nil
    else { return nil }
    return selectedLegacyBeamComponentsAfterPoses(current: game, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func selectedLegacyBeamComponentsAfterPoses(
    current game: Game, admittedAtEnd: CurrentNewtEndBirths?
  ) -> [ActorIdentity: [CurrentNewtKitComponent]]? {
    guard let opening = legs.first?.opening.before else { return nil }
    let originalActors = Set(opening.bodies.compactMap { $0.physical?.identity })
    let born = Set(legs.flatMap { $0.boundaryBirths + $0.result.released }.map(\.podActor))
    let admitted = admittedAtEnd?.allActors ?? []
    var result: [ActorIdentity: [CurrentNewtKitComponent]] = [:]
    for body in game.bodies {
      guard let physical = body.physical else { return nil }
      guard physical.currentNewtKitStock != nil || physical.currentNewtKitReceipt != nil
      else { continue }
      guard
        originalActors.contains(physical.identity) || born.contains(physical.identity)
          || admitted.contains(physical.identity),
        let parts = try? game.currentNewtGeometryComponents(for: body)
      else { return nil }
      result[physical.identity] = parts
    }
    return result
  }

  @inline(never)
  func validatesSelectedBeamGeometry(
    _ geometry: MissionCollisionQueryGeometry, closing game: Game,
    admittedAtEnd: CurrentNewtEndBirths? = nil
  ) -> Bool {
    geometry.isForPath(original)
      && retainedSceneMatches(
        opening: geometry.openingFlight, bodies: geometry.openingBodies, epoch: geometry.epoch,
        current: game, admittedAtEnd: admittedAtEnd)
  }

  /// Timing-standard capture keeps the original whole-world census gates.
  /// Only the occupied pods actually issued in these accepted legs may appear.
  /// Any contact or disappearance makes this frame ineligible for capture.
  @inline(never)
  func timingStandardMotion(
    from opening: FlightSimulationState, bodies before: [SpaceBody],
    path: CurrentNewtOuterMotion, closing game: Game
  ) -> HullSceneMotion? {
    guard completedOuterInterval, terminalBirths.isEmpty, path === original,
      verifiedFinalFlight(
        from: opening, usedD: original.motion.duration,
        epoch: game.nativeStationRuntimeEpoch) == game.storedFlightSimulation(),
      game.bodies == legs.last?.afterBodies,
      legs.allSatisfy({
        $0.impactEffects.isEmpty && $0.resolution.stoppedAt.isEmpty
          && $0.ordnanceEffects.isEmpty
          && $0.boundaryEvents.allSatisfy {
            if case .birth = $0 { return true }
            return false
          }
      }), terminalEvents.isEmpty,
      game.storedFlightSimulation().pose == original.motion.end
    else { return nil }
    return timingStandardCensus(before: before, current: game)
  }

  @inline(never)
  private func timingStandardCensus(before: [SpaceBody], current game: Game) -> HullSceneMotion? {
    let initial = before.filter { $0.energy > 0 }
    let current = game.bodies.filter { $0.energy > 0 }
    let initialActors = initial.compactMap { $0.physical?.identity }
    let currentActors = current.compactMap { $0.physical?.identity }
    let births = legs.flatMap { $0.boundaryBirths + $0.result.released }
    guard initialActors.count == initial.count, currentActors.count == current.count,
      Set(initialActors).count == initial.count, Set(currentActors).count == current.count,
      Set(births.map(\.podActor)).count == births.count,
      Set(initialActors).isDisjoint(with: Set(births.map(\.podActor))),
      Set(currentActors) == Set(initialActors).union(births.map(\.podActor))
    else { return nil }
    for old in initial {
      guard let actor = old.physical?.identity,
        let body = current.first(where: { $0.physical?.identity == actor }),
        body.id == old.id, body.energy == old.energy
      else { return nil }
    }
    for receipt in births {
      guard
        current.contains(where: {
          $0.physical?.identity == receipt.podActor && $0.physical?.currentNewtKitReceipt == receipt
        })
      else { return nil }
    }
    for body in current
    where body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil {
      guard (try? game.currentNewtGeometryComponents(for: body)) != nil else { return nil }
    }
    return original.motion
  }
}

/// A prepared contact selection remains inert until the native clock leg and
/// mover consume it. G3 owns the source-qualified force/contact preparation.
struct CurrentNewtPreparedNativeContact: Sendable {
  let motion: CurrentNewtNativeSegmentPlan
  let resolution: CurrentNewtNativeContactResolution
}

struct CurrentNewtNativeIntervalResult: Sendable {
  let evidence: CurrentNewtNativeClockEvidence?
  let fullMotionAttained: Bool
}

extension Game {
  @inline(never)
  mutating func advanceCurrentNewtNativeInterval(
    _ original: CurrentNewtOuterMotion, npcFrame suppliedNPCFrame: CurrentNewtNPCFrame? = nil
  ) -> CurrentNewtNativeIntervalResult {
    guard var npcFrame = suppliedNPCFrame ?? prepareCurrentNewtNPCFrame(original),
      npcFrame.path === original, npcFrame.epoch == nativeStationRuntimeEpoch,
      npcFrame.opening == storedFlightSimulation()
    else { return .init(evidence: nil, fullMotionAttained: false) }
    var trajectory = original
    var fullMotionAttained = true
    var legs: [CurrentNewtNativeClockLeg] = []
    var pendingEvents: [CurrentNewtNativeBoundaryEvent] = []
    var queryBudget = CurrentNewtNativeQueryBudget()
    guard let ordnanceFrame = prepareGameplayOrdnanceFrame(until: original.endTime) else {
      return .init(evidence: nil, fullMotionAttained: false)
    }
    let startFlight = storedFlightSimulation()
    let startBodies = bodies
    var selectedBeamPlans: [ActorIdentity: SelectedNPCBeamPlan] = [:]
    while storedFlightSimulation().physicalTime < original.endTime {
      let beforeBoundary = storedFlightSimulation()
      let existing = Set(bodies.compactMap { $0.physical?.currentNewtKitReceipt?.issue.kitID })
      // Each attained cursor is visited once. These owners settle only real due
      // starts/unlocks and consume no fictional positive-time leg.
      armCurrentNewtMechanisms(at: beforeBoundary.physicalTime)
      releaseCurrentNewtKitsAtCurrentClock()
      let boundaryBirths = bodies.compactMap { $0.physical?.currentNewtKitReceipt }
        .filter { !existing.contains($0.issue.kitID) }
      pendingEvents.append(contentsOf: boundaryBirths.map { .birth($0) })
      let pulses = ecmFrames > 0 ? activeECMActivation.map { [$0] } ?? [] : []
      // Due terminal owners run at the attained cursor before guidance lookup.
      // They retain actual effects, without inventing positive elapsed time.
      for entry in ordnanceFrame.entries {
        let before = storedFlightSimulation()
        var candidate = self
        if let receipt = candidate.retainCurrentNewtNativeOrdnanceBoundary(entry, activeECM: pulses)
        {
          guard receipt.motionRetained,
            receipt.applying(to: before) == candidate.storedFlightSimulation()
          else {
            return currentNewtIntervalResult(
              original, opening: startFlight, openingBodies: startBodies,
              selectedBeamPlans: selectedBeamPlans, legs: legs,
              terminalEvents: pendingEvents, fullMotionAttained: false)
          }
          self = candidate
          pendingEvents.append(.ordnance(receipt))
        }
      }
      if legs.isEmpty && !pendingEvents.isEmpty {
        guard let selected = prepareCurrentNewtNPCFrame(original) else {
          return currentNewtIntervalResult(
            original, opening: startFlight, openingBodies: startBodies,
            selectedBeamPlans: selectedBeamPlans, legs: legs,
            terminalEvents: pendingEvents, fullMotionAttained: false)
        }
        npcFrame = selected
      }
      guard screen != .gameOver,
        let step = prepareCurrentNewtNativeStep(
          original: original, trajectory: trajectory, npcFrame: npcFrame,
          ordnanceFrame: ordnanceFrame, budget: &queryBudget)
      else {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      if let zero = step.zeroContact {
        var candidate = self
        let before = storedFlightSimulation()
        guard let receipt = try? candidate.retainCurrentNewtNativeOrdnance(zero, activeECM: pulses),
          receipt.motionRetained,
          receipt.applying(to: before) == candidate.storedFlightSimulation()
        else {
          return currentNewtIntervalResult(
            original, opening: startFlight, openingBodies: startBodies,
            selectedBeamPlans: selectedBeamPlans, legs: legs,
            terminalEvents: pendingEvents, fullMotionAttained: false)
        }
        self = candidate
        pendingEvents.append(.ordnance(receipt))
        if settleCurrentNewtFatalOutcome() {
          return currentNewtIntervalResult(
            original, opening: startFlight, openingBodies: startBodies,
            selectedBeamPlans: selectedBeamPlans, legs: legs,
            terminalEvents: pendingEvents, fullMotionAttained: false)
        }
        continue
      }
      guard let prepared = step.physics,
        validateCurrentNewtMechanicalResult(
          prepared.motion.mechanicalResult(prepared.resolution), for: prepared.motion.mechanics),
        let nextNPCFrame = npcFrame.continuing(
          after: prepared.resolution, at: prepared.motion.opening.interval.end)
      else {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      let opening = prepared.motion.opening
      let interval = opening.interval
      let end = interval.end
      let playerEnd = opening.playerEnd
      if legs.isEmpty {
        let legacyEntries = npcFrame.entries.values.filter { $0.legacy != nil }
        if !legacyEntries.isEmpty {
          do {
            // Capture after genuine T0 boundary births, before the first
            // positive leg. No future Game or guessed original scene is used.
            let geometry = try prepareSelectedNPCBeamGeometry(for: original)
            for entry in legacyEntries {
              guard let decision = entry.legacy else { continue }
              let firing: Bool
              switch decision.driver {
              case .ordinaryPlayerEngagement: firing = decision.end.length < 1500
              case .blackjack:
                let cooldown =
                  bodies.first(where: { $0.physical?.identity == entry.actor })?
                  .blackjackLaserCooldown ?? 0
                firing =
                  decision.start.length < 1500
                  && max(0, cooldown - original.motion.duration) == 0
              }
              if firing {
                guard let plan = prepareSelectedLegacyNPCBeam(entry: entry, geometry: geometry)
                else { throw NativeMissionImpactError.staleProof }
                selectedBeamPlans[entry.actor] = plan
              }
            }
          } catch {
            return currentNewtIntervalResult(
              original, opening: startFlight, openingBodies: startBodies,
              selectedBeamPlans: selectedBeamPlans, legs: legs,
              terminalEvents: pendingEvents, fullMotionAttained: false)
          }
        }
      }
      // Source/contact preparation above reads the real T0 Game. Retention
      // publishes this same-clock transition atomically, including its clock,
      // so a late kernel refusal cannot expose an unretained positive leg.
      var attained = self
      attained.commander.flightSimulation.advancePhysicalTime(end - interval.start)
      let afterClock = attained.storedFlightSimulation()
      var pureClock = opening.before.storedFlightSimulation()
      pureClock.advancePhysicalTime(end - interval.start)
      guard pureClock == afterClock, afterClock.physicalTime == end else {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      guard let mechanical = attained.retainCurrentNewtNativeMechanics(prepared),
        attained.storedFlightSimulation().physicalTime == end,
        attained.nativeStationRuntimeEpoch == original.epoch
      else {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      var receipts: [GameplayOrdnanceRetention] = []
      var births = mechanical.births
      var ordnanceAccepted = true
      for leg in step.projectiles {
        let before = attained.storedFlightSimulation()
        guard
          let receipt = try? attained.retainCurrentNewtNativeOrdnance(
            leg, activeECM: pulses, admittedAtBoundary: births), receipt.motionRetained,
          receipt.applying(to: before) == attained.storedFlightSimulation()
        else {
          ordnanceAccepted = false
          break
        }
        receipts.append(receipt)
        for effect in receipt.clockEffects {
          switch effect {
          case .combat(let combat):
            guard let updated = births.accepting(combat, in: attained) else {
              ordnanceAccepted = false
              break
            }
            births = updated
          case .mission:
            if !births.matchesNewtBirths(attained) { ordnanceAccepted = false }
          }
        }
        if !ordnanceAccepted { break }
      }
      guard ordnanceAccepted else {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      self = attained
      legs.append(
        .init(
          beforeBoundary: legs.last?.afterMotion ?? startFlight, boundaryEvents: pendingEvents,
          opening: opening, trajectory: trajectory, afterClock: afterClock,
          afterMotion: storedFlightSimulation(), resolution: prepared.resolution,
          result: mechanical.result,
          impactEffects: mechanical.effects, ordnanceEffects: receipts, afterBodies: bodies))
      pendingEvents = []
      npcFrame = nextNPCFrame
      if settleCurrentNewtFatalOutcome() {
        return currentNewtIntervalResult(
          original, opening: startFlight, openingBodies: startBodies,
          selectedBeamPlans: selectedBeamPlans, legs: legs,
          terminalEvents: pendingEvents, fullMotionAttained: false)
      }
      if prepared.resolution.player != playerEnd {
        guard let player = storedFlightSimulation().player,
          prepared.resolution.stoppedAt[player] != nil
        else {
          return currentNewtIntervalResult(
            original, opening: startFlight, openingBodies: startBodies,
            selectedBeamPlans: selectedBeamPlans, legs: legs,
            terminalEvents: pendingEvents, fullMotionAttained: false)
        }
        fullMotionAttained = false
        if end < original.endTime {
          guard let coast = trajectory.coasting(from: prepared.resolution.player, at: end) else {
            return currentNewtIntervalResult(
              original, opening: startFlight, openingBodies: startBodies,
              selectedBeamPlans: selectedBeamPlans, legs: legs,
              terminalEvents: pendingEvents, fullMotionAttained: false)
          }
          trajectory = coast
        }
      }
    }
    return currentNewtIntervalResult(
      original, opening: startFlight, openingBodies: startBodies,
      selectedBeamPlans: selectedBeamPlans, legs: legs,
      terminalEvents: pendingEvents, fullMotionAttained: fullMotionAttained)
  }

  /// The original outer tail settles death after ordinary combat. A native
  /// retained fatal frontier must settle it here before another clock leg.
  private mutating func settleCurrentNewtFatalOutcome() -> Bool {
    guard energy <= 0 else { return screen == .gameOver }
    spin.stop(immediate: true)
    screen = .gameOver
    notify("GAME OVER")
    return true
  }

  @inline(never)
  private func currentNewtIntervalResult(
    _ original: CurrentNewtOuterMotion, opening: FlightSimulationState,
    openingBodies: [SpaceBody], selectedBeamPlans: [ActorIdentity: SelectedNPCBeamPlan],
    legs: [CurrentNewtNativeClockLeg],
    terminalEvents: [CurrentNewtNativeBoundaryEvent],
    fullMotionAttained: Bool
  ) -> CurrentNewtNativeIntervalResult {
    let evidence = CurrentNewtNativeClockEvidence(
      original: original, originalBodies: openingBodies, selectedBeamPlans: selectedBeamPlans,
      legs: legs,
      endTime: storedFlightSimulation().physicalTime, terminalEvents: terminalEvents)
    guard
      evidence.verifiedFinalFlight(
        from: opening, usedD: evidence.attainedDuration,
        epoch: original.epoch) == storedFlightSimulation()
    else { return .init(evidence: nil, fullMotionAttained: false) }
    return .init(
      evidence: evidence,
      fullMotionAttained: fullMotionAttained && evidence.completedOuterInterval)
  }
}
