import Foundation

/// A real accepted native interval supplied by G1's single outer-frame owner.
/// This is not Codable and cannot be restored or supplied by a save.
struct CurrentNewtMechanicalInterval: Sendable {
  let start: Double
  let end: Double
  var valid: Bool { start.isFinite && end.isFinite && start >= 0 && end > start && end - start <= 0.1 + 1e-9 }
}

struct CurrentNewtMechanicalProposal: Sendable {
  let actor: ActorIdentity
  let before: CurrentNewtKitReceipt.BodyState
  let after: CurrentNewtKitReceipt.BodyState
  let beforeMass: CurrentNewtKitReceipt.MassProperties
  let afterMass: CurrentNewtKitReceipt.MassProperties
}

/// Actual native contact owner returns its retained endpoint/refusal. Empty stop
/// times on refusal mean no internal mechanical displacement was accepted.
struct CurrentNewtMechanicalContactResult: Sendable {
  let admitted: Bool
  let stoppedAt: [ActorIdentity: Double]
  let drives: [CurrentNewtDriveOutcome]
}

struct CurrentNewtMechanicalSegmentResult: Sendable {
  let acceptedDuration: Double
  let proposals: Int
  let interrupted: [ActorIdentity]
  let released: [CurrentNewtKitReceipt]
}

extension Game {
  /// Only validated existing kit clocks can split an already accepted outer interval.
  func nextCurrentNewtMechanicalEndpoint(in interval: CurrentNewtMechanicalInterval) -> Double? {
    guard interval.valid, let source = CurrentNewtKitSource.current,
      let state = commander.savedEMPState else { return nil }
    var next: Double?
    for record in state.records.values where !record.terminal && !record.isRecovered {
      guard let stock = record.hull.body.physical?.currentNewtKitStock,
        source.matches(stock, at: interval.start), stock.interruptedAt == nil,
        stock.phase == .released || (record.crewAboard > 0
          && record.aboardOrdinals.contains(stock.issue.person.ordinal))
      else { continue }
      let events: [Double]
      if let a = stock.actuation {
        events = source.mechanicalEndpoints(a)
      } else {
        guard let episode = record.disableEpisodes.last,
          let person = episode.ejections.first(where: { $0.ordinal == stock.issue.person.ordinal })
        else { continue }
        let due = episode.incident.physicalTime + person.delay
        let start = max(episode.incident.physicalTime, due)
        guard start + source.dropDuration < episode.deadline else { continue }
        events = [start]
      }
      for event in events where event > interval.start + 1e-9 && event <= interval.end {
        next = next.map { min($0, event) } ?? event
      }
    }
    return next
  }

  /// Consume the SAME plan prepared at T0. The callback retains the one real
  /// native result; no source-clock reconstruction creates a second motion leg.
  mutating func advanceCurrentNewtMechanicalSegment(
    _ plan: CurrentNewtMechanicalPlan,
    contact: (inout Game, CurrentNewtMechanicalPlan) -> CurrentNewtMechanicalContactResult
  ) -> CurrentNewtMechanicalSegmentResult {
    let interval = plan.interval
    let refused = CurrentNewtMechanicalSegmentResult(acceptedDuration: 0,
      proposals: plan.proposals.count, interrupted: [], released: [])
    guard interval.valid, commander.flightSimulation.physicalTime == interval.end,
      plan.owners.allSatisfy({ owner in
        bodies.first(where: { $0.physical?.identity == owner.parent })?
          .physical?.currentNewtKitStock == owner.stock
          && commander.savedEMPState?.records[owner.logical]?.hull.body.physical?
            .currentNewtKitStock == owner.stock
      }) else { return refused }
    let contacts = contact(&self, plan)
    // A global refusal credits no future observation, work, release or arming.
    guard let updates = currentNewtMechanicalStockUpdates(contacts, for: plan),
      plan.owners.allSatisfy({ owner in
        guard let body = bodies.first(where: { $0.physical?.identity == owner.parent }),
          body.physical?.currentNewtKitStock == owner.stock,
          currentNewtKitLoad(for: body)?.samePhysicalInventory(as: owner.load) == true
        else { return false }
        guard let proposal = plan.proposals.first(where: { $0.actor == owner.parent }),
          contacts.stoppedAt[owner.parent] == nil else { return true }
        return CurrentNewtKitSource.current?.matchesState(currentNewtBodyState(body), proposal.after) == true
      }) else { return refused }
    var interrupted: [ActorIdentity] = []
    for owner in plan.owners {
      // All fallible projection and state joins have completed before publication.
      guard let index = bodies.firstIndex(where: { $0.physical?.identity == owner.parent }),
        let stock = updates[owner.parent],
        var record = commander.savedEMPState?.records[owner.logical] else { return refused }
      if owner.stock.interruptedAt == nil && stock.interruptedAt != nil { interrupted.append(owner.parent) }
      bodies[index].physical?.currentNewtKitStock = stock
      record.hull = .init(body: bodies[index], pose: commander.flightSimulation.pose, time: interval.end)
      commander.savedEMPState?.records[owner.logical] = record
    }
    armCurrentNewtMechanisms(at: interval.end)
    let before = Set(bodies.compactMap { $0.physical?.currentNewtKitReceipt?.issue.kitID })
    releaseCurrentNewtKitsAtCurrentClock()
    let released = bodies.compactMap { $0.physical?.currentNewtKitReceipt }
      .filter { !before.contains($0.issue.kitID) }
    return .init(acceptedDuration: interval.end - interval.start, proposals: plan.proposals.count,
      interrupted: interrupted, released: released)
  }

  func currentNewtBodyState(_ body: SpaceBody) -> CurrentNewtKitReceipt.BodyState {
    .init(pose: modelPose(of: body), velocity: body.physical?.velocity ?? .init(0, 0, 0),
      angularVelocity: body.physical?.angularVelocity ?? .init(0, 0, 0))
  }
}

/// Actual attached-rack path. Evaluating this non-Codable scene never advances
/// a stock, body, archive or clock; G3 can bound the nonlinear path itself.
struct CurrentNewtMechanicalContactScene: Sendable {
  let interval: CurrentNewtMechanicalInterval
  let actor: ActorIdentity
  let before: [CurrentNewtKitComponent]
  let proposed: [CurrentNewtKitComponent]
  let stock: CurrentNewtKitStock
  let load: CurrentNewtKitLoad
  /// Lipschitz bound for every source point over this exact attached interval.
  let maximumWorldPointSpeed: Double
  let maximumAngularSpeed: Double

  func pointSpeedBound(relativeTo reference: Vector3) -> Double? {
    guard let source = CurrentNewtKitSource.current, let a = stock.actuation,
      let parent = source.motion(a, at: interval.start)?.parent else { return nil }
    return source.attachedPointSpeedBound(actuation: a, components: before,
      parent: parent, relativeTo: reference)
  }

  func components(at time: Double) -> [CurrentNewtKitComponent]? {
    guard time >= interval.start, time <= interval.end,
      let source = CurrentNewtKitSource.current, let a = stock.actuation,
      let motion = source.motion(a, at: time) else { return nil }
    return source.components(stock: stock, work: source.work(at: time, actuation: a),
      at: time, parent: motion.parent, load: load)
  }
}

extension Game {
  func currentNewtMechanicalContactScene(_ proposal: CurrentNewtMechanicalProposal,
    interval: CurrentNewtMechanicalInterval) -> CurrentNewtMechanicalContactScene?
  {
    guard interval.valid, commander.flightSimulation.physicalTime == interval.start,
      let source = CurrentNewtKitSource.current,
      let body = bodies.first(where: { $0.physical?.identity == proposal.actor }),
      let logical = body.physical?.empSource,
      let record = commander.savedEMPState?.records[logical], record.hull.binding == proposal.actor,
      let stock = body.physical?.currentNewtKitStock, stock.phase == .actuating,
      stock.interruptedAt == nil, stock.observedAt == interval.start,
      record.hull.body.physical?.currentNewtKitStock == stock,
      let a = stock.actuation, source.matches(stock, at: interval.start),
      let load = currentNewtKitLoad(for: body), load.samePhysicalInventory(as: a.load),
      source.matchesState(currentNewtBodyState(body), proposal.before),
      let expected = source.motion(a, at: interval.end),
      source.matchesState(expected.parent, proposal.after),
      let before = source.components(stock: stock, at: interval.start, parent: proposal.before, load: load),
      let proposed = source.components(stock: stock, work: source.work(at: interval.end, actuation: a),
        at: interval.end, parent: proposal.after, load: load)
    else { return nil }
    guard let bound = source.attachedPointSpeedBound(actuation: a, components: before,
      parent: proposal.before) else { return nil }
    return .init(interval: interval, actor: proposal.actor, before: before, proposed: proposed,
      stock: stock, load: load, maximumWorldPointSpeed: bound,
      maximumAngularSpeed: source.maximumAngularSpeed)
  }
}
