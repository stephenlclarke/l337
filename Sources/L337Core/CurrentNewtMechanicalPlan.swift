import Foundation

/// Pure planning at the actual segment start. No future clock, stock, body or
/// archive is installed until the one native contact result is retained.
struct CurrentNewtMechanicalPlan: Sendable {
  struct Owner: Sendable {
    let logical: ActorIdentity
    let parent: ActorIdentity
    let stock: CurrentNewtKitStock
    let load: CurrentNewtKitLoad
    let state: CurrentNewtKitReceipt.BodyState
    let mass: CurrentNewtKitReceipt.MassProperties
    let components: [CurrentNewtKitComponent]
    let cell: CurrentNewtCellComponentContract
  }

  /// Resolve only the exact issue-selected definitions before entering the
  /// owning planning frame. Definitions alone grant no stock or birth rights.
  struct ResolvedSources: Sendable {
    private let configurations: [String: CurrentNewtKitSource]

    @inline(never)
    init?(issues: [CurrentNewtKitIssue]) {
      if issues.isEmpty {
        // Preserve the original no-stock cold lookup and empty-plan behavior.
        if let source = CurrentNewtKitSource.current {
          configurations = [source.configuration: source]
        } else {
          configurations = [:]
        }
        return
      }
      var resolved: [String: CurrentNewtKitSource] = [:]
      for issue in issues {
        guard let source = CurrentNewtKitSource.source(for: issue) else { return nil }
        resolved[issue.configuration] = source
      }
      configurations = resolved
    }

    func source(for issue: CurrentNewtKitIssue) -> CurrentNewtKitSource? {
      guard let source = configurations[issue.configuration],
        source.configuration == issue.configuration, source.sourceSHA256 == issue.sourceSHA256,
        source.parentCatalogueID == issue.birthLoad.catalogueShipID else { return nil }
      return source
    }
  }

  let interval: CurrentNewtMechanicalInterval
  let owners: [Owner]
  let proposals: [CurrentNewtMechanicalProposal]
  let drives: [CurrentNewtDrivePlan]
  let coasts: [CurrentNewtCoastPlan]
  let interruptions: [ActorIdentity]
}

extension Game {
  @inline(never)
  func currentNewtMechanicalPlan(_ interval: CurrentNewtMechanicalInterval)
    -> CurrentNewtMechanicalPlan?
  {
    guard interval.valid, storedFlightSimulation().physicalTime == interval.start else { return nil }
    let issues = bodies.compactMap { $0.physical?.currentNewtKitStock?.issue }
    guard let sources = CurrentNewtMechanicalPlan.ResolvedSources(issues: issues) else { return nil }
    return currentNewtMechanicalPlanAfterSource(interval, sources: sources)
  }

  @inline(never)
  private func currentNewtMechanicalPlanAfterSource(
    _ interval: CurrentNewtMechanicalInterval, sources: CurrentNewtMechanicalPlan.ResolvedSources
  ) -> CurrentNewtMechanicalPlan? {
    var owners: [CurrentNewtMechanicalPlan.Owner] = []
    var proposals: [CurrentNewtMechanicalProposal] = []
    var drives: [CurrentNewtDrivePlan] = []
    var coasts: [CurrentNewtCoastPlan] = []
    var interruptions: [ActorIdentity] = []
    for body in bodies {
      guard let physical = body.physical, let stock = physical.currentNewtKitStock else { continue }
      guard let source = sources.source(for: stock.issue) else { return nil }
      let logical: ActorIdentity
      let recovered: Bool
      if let current = physical.empSource {
        logical = current
        recovered = false
      } else {
        if stock.phase == .stowed { continue }
        guard let current = nativeMechanicalStoredNPCPersistence().logicalIdentity(for: physical.identity),
          current == stock.issue.birthActor else { return nil }
        logical = current
        recovered = true
      }
      guard let record = nativeMechanicalStoredEMPState()?.records[logical], !record.terminal,
        record.isRecovered == recovered, record.hull.binding == physical.identity,
        recovered || record.disableEpisodes.contains(where: { $0.actorBindings.contains(physical.identity) }),
        !recovered || stock.interruptedAt != nil
          || (stock.phase == .released && (stock.work.rodMetres == source.stroke
            || stock.actuation?.parent == physical.identity)),
        record.hull.body.physical?.currentNewtKitStock == stock,
        source.matches(stock, at: interval.start),
        stock.actuation == nil || stock.observedAt == interval.start,
        let load = currentNewtKitLoad(for: body), source.loadModel?.matchesInventory(load) == true,
        let cell = currentNewtCellComponentContract(for: body),
        let components = source.components(stock: stock, at: interval.start,
          parent: currentNewtBodyState(body), load: load, cell: cell),
        let mass = source.loadedMechanicalMass(stock: stock, load: load, cell: cell)
      else { return nil }
      if let a = stock.actuation {
        guard a.source == record.source, a.sequence == record.sequence,
          stock.interruptedAt != nil || (stock.phase == .released && stock.work.rodMetres == source.stroke)
            || a.parent == physical.identity else { return nil }
      }
      let owner = CurrentNewtMechanicalPlan.Owner(logical: logical, parent: physical.identity,
        stock: stock, load: load, state: currentNewtBodyState(body), mass: mass, components: components, cell: cell)
      owners.append(owner)
      if stock.phase == .stowed || stock.interruptedAt != nil
        || (stock.phase == .released && stock.work.rodMetres == source.stroke) {
        guard let current = currentNewtCoastPlans(owner: owner, record: record, interval: interval)
        else { return nil }
        coasts += current
        continue
      }
      guard let a = stock.actuation else { return nil }
      if stock.phase == .actuating {
        // A changed physical load stops the mechanism. Do not replay momentum
        // from its old sealed mass distribution or silently skip the owner.
        guard load.samePhysicalInventory(as: a.load) else {
          guard let coast = CurrentNewtCoastPlan.afterLoadChange(owner: owner,
            interval: interval, source: source) else { return nil }
          interruptions.append(physical.identity)
          coasts.append(coast)
          continue
        }
        guard interval.end <= a.unlockAt + 1e-9,
          let before = source.motion(a, at: interval.start),
          let after = source.motion(a, at: interval.end),
          source.matchesAttachedObservation(stock: stock, state: currentNewtBodyState(body), at: interval.start)
        else { return nil }
        proposals.append(.init(actor: physical.identity, before: before.parent,
          after: after.parent, beforeMass: before.assemblyMass, afterMass: after.assemblyMass))
      } else {
        guard let receipt = stock.receipt, source.matches(receipt) else { return nil }
        guard let pod = bodies.first(where: { $0.physical?.identity == receipt.podActor }),
          pod.physical?.currentNewtKitReceipt == receipt,
          let parentComponents = source.components(stock: stock, at: interval.start,
            parent: currentNewtBodyState(body), load: load),
          let podComponents = source.components(receipt: receipt, at: interval.start,
            pod: currentNewtBodyState(pod)),
          let parentMass = source.loadedParentMass(work: stock.work, load: load)
        else { return nil }
        drives.append(.init(issue: stock.issue, actuation: a, interval: interval,
          parentActor: physical.identity, podActor: receipt.podActor,
          receipt: receipt, load: load, parent: currentNewtBodyState(body),
          pod: currentNewtBodyState(pod), parentMass: parentMass, podMass: source.podMass,
          parentComponents: parentComponents, podComponents: podComponents, work: stock.work,
          maximumForceNewtons: source.maximumForceNewtons,
          maximumGuideFrictionNewtons: source.maximumGuideFrictionNewtons,
          maximumAdditionalWorkJoules: min(stock.charges.ejectionMechanicalJoules,
            source.ejectWork - stock.work.ejectionWorkJoules),
          maximumAvailableMechanicalJoules: stock.charges.ejectionMechanicalJoules,
          strokeLimitMetres: source.stroke, targetRelativeSpeedMetresPerSecond: source.releaseSpeed))
      }
    }
    guard Set(owners.map(\.parent)).count == owners.count,
      Set(owners.map { $0.stock.issue.kitID }).count == owners.count,
      Set(coasts.map(\.actor)).count == coasts.count,
      !coasts.contains(where: { coast in
        proposals.contains { $0.actor == coast.actor }
          || drives.contains { $0.parentActor == coast.actor || $0.podActor == coast.actor }
      }) else { return nil }
    return .init(interval: interval, owners: owners, proposals: proposals,
      drives: drives, coasts: coasts, interruptions: interruptions)
  }
}

extension CurrentNewtKitSource {
  func loadedMechanicalMass(stock: CurrentNewtKitStock, load: CurrentNewtKitLoad,
    cell: CurrentNewtCellComponentContract? = nil) -> Mass? {
    guard let parent = loadedParentMass(work: stock.work, load: load) else { return nil }
    if stock.phase == .released { return parent }
    let currentPod: Mass
    if let cell {
      guard cell.kitID == stock.issue.kitID, cell.sourceSHA256 == sourceSHA256 else { return nil }
      currentPod = cell.mass
    } else {
      guard load.people.contains(where: { $0.identity == stock.issue.person }) else { return nil }
      currentPod = podMass
    }
    return CurrentNewtKitMass.combined([parent,
      CurrentNewtKitMass.translated(currentPod, by: podOrigin)])
  }

  func loadedParentMass(work: CurrentNewtKitStock.WorkState, load: CurrentNewtKitLoad) -> Mass? {
    guard validWork(work), let model = loadModel, model.matchesInventory(load),
      let extra = model.masses(load), let people = currentParentPeople(load) else { return nil }
    let p = phase(work: work, at: 0, actuation: nil, interrupted: true)
    return CurrentNewtKitMass.combined(
      Array(movingMasses(p, people: people.map(\.massInCarrier)).dropLast()).map(\.properties) + extra)
  }
}

extension Game {
  /// G1 calls this SAME pure validator on the retained preflight result before
  /// clock credit, then the accepted segment calls it before any stock commit.
  func validateCurrentNewtMechanicalResult(_ result: CurrentNewtMechanicalContactResult,
    for plan: CurrentNewtMechanicalPlan) -> Bool
  {
    currentNewtMechanicalStockUpdates(result, for: plan) != nil
  }

  /// Pure projected stock values. Native preflight and accepted application use
  /// these same rules, so invalid work cannot fail halfway through publication.
  func currentNewtMechanicalStockUpdates(_ result: CurrentNewtMechanicalContactResult,
    for plan: CurrentNewtMechanicalPlan) -> [ActorIdentity: CurrentNewtKitStock]?
  {
    guard plan.interval.valid, result.admitted,
      result.drives.count == plan.drives.count,
      Set(result.drives.map(\.kitID)).count == result.drives.count,
      Set(plan.drives.map { $0.issue.kitID }).count == plan.drives.count,
      result.stoppedAt.allSatisfy({ actor, time in
        (plan.owners.contains { $0.parent == actor }
          || plan.drives.contains { $0.podActor == actor })
          && time.isFinite && time >= plan.interval.start && time <= plan.interval.end
      }) else { return nil }
    if plan.owners.isEmpty { return result.drives.isEmpty && result.stoppedAt.isEmpty ? [:] : nil }
    guard result.drives.allSatisfy({ outcome in
      guard let drive = plan.drives.first(where: { $0.issue.kitID == outcome.kitID }),
        let source = CurrentNewtKitSource.source(for: drive.issue),
        outcome.valid(for: drive), source.validWork(outcome.work),
        outcome.impulseOnPod.length <= drive.maximumForceNewtons
          * ((outcome.interruptedAt ?? plan.interval.end) - plan.interval.start) + 1e-6,
        outcome.work.rodMetres - drive.work.rodMetres <= drive.targetRelativeSpeedMetresPerSecond
          * (plan.interval.end - plan.interval.start) + 1e-9
      else { return false }
      if let stopped = result.stoppedAt[drive.parentActor] ?? result.stoppedAt[drive.podActor],
        outcome.interruptedAt != stopped { return false }
      return outcome.interruptedAt == nil || outcome.work.rodVelocity == 0
    }) else { return nil }
    var updates: [ActorIdentity: CurrentNewtKitStock] = [:]
    for owner in plan.owners {
      guard let source = CurrentNewtKitSource.source(for: owner.stock.issue) else { return nil }
      var stock = owner.stock
      if stock.phase == .stowed {
        guard updates[owner.parent] == nil else { return nil }
        updates[owner.parent] = stock
        continue
      }
      guard let a = stock.actuation else { return nil }
      var work = stock.work
      var stop: Double?
      if plan.interruptions.contains(owner.parent) {
        stop = plan.interval.start
      } else if let outcome = result.drives.first(where: { $0.kitID == stock.issue.kitID }) {
        work = outcome.work
        stop = outcome.interruptedAt
      } else if plan.proposals.contains(where: { $0.actor == owner.parent }) {
        stop = result.stoppedAt[owner.parent]
        work = source.work(at: stop ?? plan.interval.end, actuation: a, interruptedAt: stop)
      }
      if let stop {
        work = .init(loweredFraction: work.loweredFraction, rodMetres: work.rodMetres,
          rodVelocity: 0, guideWorkJoules: work.guideWorkJoules,
          ejectionWorkJoules: work.ejectionWorkJoules)
        guard stock.interrupt(at: plan.interval.end, stoppedAt: stop, work: work,
          charges: source.charges(at: plan.interval.end, actuation: a, work: work,
            serviceCapturedAt: stock.serviceCapturedAt)) else { return nil }
      } else {
        guard stock.observe(at: plan.interval.end, work: work,
          charges: source.charges(at: plan.interval.end, actuation: a, work: work,
            serviceCapturedAt: stock.serviceCapturedAt)) else { return nil }
      }
      guard source.matches(stock, at: plan.interval.end), updates[owner.parent] == nil else { return nil }
      updates[owner.parent] = stock
    }
    return updates
  }
}
