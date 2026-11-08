import Foundation

/// Shared work for one actual outer interval, including refinements and zero
/// boundaries. A new query cannot silently reset an already spent allowance.
struct CurrentNewtNativeQueryBudget {
  var remaining = HullSweepBudget.standard
  var pairs = 0

  mutating func debit(_ work: CurrentNewtOrdnanceQueryWork) -> Bool {
    guard work.candidatePairs >= 0, work.distanceQueries >= 0,
      work.triangleTests >= 0, work.nodeVisits >= 0,
      work.candidatePairs <= Int.max - pairs
    else { return false }
    pairs += work.candidatePairs
    remaining.distanceQueries -= work.distanceQueries
    remaining.triangleTests -= work.triangleTests
    remaining.nodeVisits -= work.nodeVisits
    return pairs <= AsteroidImpactPolicy.maximumCandidatePairs
      && remaining.distanceQueries >= 0 && remaining.triangleTests >= 0 && remaining.nodeVisits >= 0
  }
}

/// Native-owner preparation only. The real interval owner still advances and
/// atomically retains the exact selected clock, mechanics and ordnance effects.
struct CurrentNewtNativeStep {
  let scene: CurrentNewtNativeQueryScene
  let physics: CurrentNewtPreparedNativeContact?
  let projectiles: [CurrentNewtNativeOrdnanceLeg]
  let zeroContact: CurrentNewtNativeOrdnanceLeg?
}

extension Game {
  func prepareCurrentNewtNativeStep(
    original: CurrentNewtOuterMotion, trajectory: CurrentNewtOuterMotion,
    npcFrame: CurrentNewtNPCFrame, ordnanceFrame: GameplayOrdnanceFrame,
    budget: inout CurrentNewtNativeQueryBudget
  ) -> CurrentNewtNativeStep? {
    let start = storedFlightSimulation().physicalTime
    let remaining = CurrentNewtMechanicalInterval(start: start, end: original.endTime)
    var end = nextCurrentNewtMechanicalEndpoint(in: remaining) ?? original.endTime
    let active = ordnanceFrame.entries.filter { entry in
      bodies.contains { $0.physical?.identity == entry.actor && $0.energy > 0 }
    }
    for entry in active {
      guard let guidance = entry.guidanceLeg(at: start), guidance.endTime > start else {
        return nil
      }
      end = min(end, guidance.endTime)
    }
    guard end > start else { return nil }
    let interval = CurrentNewtMechanicalInterval(start: start, end: end)
    let rate =
      trajectory.approval == nil
      ? 0
      : 2 * min(1, trajectory.motion.acceleration.length / workLimits.acceleration)
    guard let motion = trajectory.subrange(interval), let playerEnd = trajectory.state(at: end),
      let opening = beginCurrentNewtNativeSegment(
        interval, playerMotion: motion,
        playerEnd: playerEnd, workEnergyRate: rate, npcFrame: npcFrame),
      let mechanics = currentNewtMechanicalPlan(interval),
      let baseScene = prepareCurrentNewtNativeQueryScene(
        opening: opening, mechanics: mechanics,
        ordnanceFrame: active.isEmpty ? nil : ordnanceFrame)
    else { return nil }
    var projectiles: [CurrentNewtNativeOrdnanceLeg] = []
    for entry in active {
      switch prepareCurrentNewtNativeOrdnanceLeg(
        in: baseScene, actor: entry.actor,
        budget: budget.remaining)
      {
      case .prepared(let leg):
        guard budget.debit(leg.work) else { return nil }
        projectiles.append(leg)
      case .refused(_, let work):
        _ = budget.debit(work)
        return nil
      }
    }
    let contacts = projectiles.compactMap { $0.contact }
    if !contacts.isEmpty {
      guard
        let selected = CurrentNewtContactChronology.earliest(
          contacts.map {
            .init(lower: $0.lowerPhysicalTime, upper: $0.upperPhysicalTime)
          })
      else { return nil }
      let first = contacts[selected]
      if first.upperPhysicalTime == start {
        guard first.native.lowerTime == 0, first.native.upperTime == 0,
          let leg = projectiles.first(where: { $0.contact === first })
        else { return nil }
        return .init(scene: baseScene, physics: nil, projectiles: [], zeroContact: leg)
      }
      guard first.upperPhysicalTime > start, first.upperPhysicalTime <= end else { return nil }
      end = first.upperPhysicalTime
    }
    guard
      let scene = prefixCurrentNewtNativeQueryScene(
        baseScene, through: end,
        trajectory: trajectory)
    else { return nil }
    var prefixes: [CurrentNewtNativeOrdnanceLeg] = []
    for leg in projectiles {
      guard let prefix = prefixCurrentNewtNativeOrdnanceLeg(leg, through: end) else { return nil }
      prefixes.append(prefix)
    }
    projectiles = prefixes
    var work = CurrentNewtOrdnanceQueryWork(
      candidatePairs: 0, distanceQueries: 0,
      triangleTests: 0, nodeVisits: 0)
    let physics = prepareCurrentNewtNativeContact(
      in: scene, budget: budget.remaining,
      maximumPairs: max(0, AsteroidImpactPolicy.maximumCandidatePairs - budget.pairs),
      report: &work)
    guard budget.debit(work), let physics else { return nil }
    // Impulse-changing rigid-body paths and projectile crossings need a joint
    // simultaneous response. Keep that unqualified interaction explicit;
    // neither path may be replaced by its unaffected endpoint chord.
    guard projectiles.isEmpty || physics.resolution.impacts.isEmpty else { return nil }
    return .init(scene: scene, physics: physics, projectiles: projectiles, zeroContact: nil)
  }

}
