import Foundation

extension Game {
  /// Call at the real current frontier BEFORE culling/removing either member or
  /// clearing visit bindings. Finite active hardware brakes locally; no offscreen
  /// force, future pose, reattachment or source-clock replay is manufactured.
  mutating func prepareCurrentNewtForActorRemoval(_ actors: Set<ActorIdentity>) -> Bool {
    let parents = bodies.compactMap { body -> ActorIdentity? in
      guard let physical = body.physical, let stock = physical.currentNewtKitStock,
        stock.phase != .stowed, stock.interruptedAt == nil else { return nil }
      var podLeaving = false
      if let receipt = stock.receipt,
        let record = commander.savedEMPState?.records[receipt.issue.person.source],
        let pod = record.pods.first(where: { $0.body.physical?.currentNewtKitReceipt == receipt }),
        let binding = pod.binding {
        podLeaving = actors.contains(binding)
      }
      guard actors.contains(physical.identity) || podLeaving else { return nil }
      return physical.identity
    }
    var candidate = self
    for parent in parents {
      guard candidate.interruptCurrentNewtMechanismForRemoval(parent) else { return false }
    }
    self = candidate
    return true
  }

  private mutating func interruptCurrentNewtMechanismForRemoval(_ parent: ActorIdentity) -> Bool {
    let time = commander.flightSimulation.physicalTime
    guard let source = CurrentNewtKitSource.current,
      let index = bodies.firstIndex(where: { $0.physical?.identity == parent }),
      var stock = bodies[index].physical?.currentNewtKitStock,
      let a = stock.actuation, stock.observedAt == time, source.matches(stock, at: time),
      let logical = bodies[index].physical?.empSource,
      var record = commander.savedEMPState?.records[logical], record.hull.binding == parent,
      record.hull.body.physical?.currentNewtKitStock == stock,
      let load = currentNewtKitLoad(for: bodies[index]) else { return false }
    if stock.interruptedAt != nil || (stock.phase == .released
      && stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0) { return true }
    let before = currentNewtBodyState(bodies[index])
    guard let cell = currentNewtCellComponentContract(for: bodies[index]),
      let parts = source.components(stock: stock, at: time, parent: before, load: load, cell: cell),
      let mass = source.loadedMechanicalMass(stock: stock, load: load, cell: cell) else { return false }
    guard let stopped = CurrentNewtKitBrake.retainedState(components: parts, mass: mass,
      before: before, maximumAngularSpeed: source.maximumAngularSpeed) else { return false }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: stock.work.loweredFraction,
      rodMetres: stock.work.rodMetres, rodVelocity: 0,
      guideWorkJoules: stock.work.guideWorkJoules, ejectionWorkJoules: stock.work.ejectionWorkJoules)
    guard stock.interrupt(at: time, stoppedAt: time, work: work,
      charges: source.charges(at: time, actuation: a, work: work,
        serviceCapturedAt: stock.serviceCapturedAt)) else { return false }
    bodies[index].physical?.velocity = stopped.velocity
    bodies[index].physical?.angularVelocity = stopped.angularVelocity
    bodies[index].physical?.currentNewtKitStock = stock
    record.hull = .init(body: bodies[index], pose: commander.flightSimulation.pose, time: time)
    commander.savedEMPState?.records[logical] = record
    return true
  }
}
