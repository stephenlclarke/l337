import Foundation

extension Game {
  /// The actual custody operator calls this in its same candidate before removing
  /// the physical pod. Stop the retained rods by an internal inelastic brake:
  /// their linear/angular momentum goes into the real parent, never disappears.
  mutating func interruptCurrentNewtDriveForCapture(
    _ receipt: CurrentNewtKitReceipt, at time: Double
  ) -> Bool {
    guard time == commander.flightSimulation.physicalTime,
      let source = CurrentNewtKitSource.source(for: receipt.issue), source.matches(receipt, observedAt: time),
      var record = commander.savedEMPState?.records[receipt.issue.person.source],
      let podIndex = record.podIndex(for: receipt.issue.person.ordinal),
      let podActor = record.pods[podIndex].binding,
      let pod = bodies.first(where: { $0.physical?.identity == podActor }),
      currentOccupiedNewtPodHasCurrentCustody(pod),
      pod.physical?.currentNewtKitReceipt == receipt,
      pod.physical?.empCrewPod == receipt.issue.person
    else { return false }
    if record.hull.binding == nil {
      return observeCurrentNewtArchiveForCapture(receipt, at: time)
    }
    guard let parentActor = record.hull.binding,
      let parentIndex = bodies.firstIndex(where: { $0.physical?.identity == parentActor }),
      var stock = bodies[parentIndex].physical?.currentNewtKitStock,
      stock.receipt == receipt, stock.phase == .released, stock.observedAt == time,
      source.matches(stock, at: time),
      currentNewtParentOwner(body: bodies[parentIndex], stock: stock) == record.source,
      record.hull.body.physical?.currentNewtKitStock == stock,
      let load = currentNewtKitLoad(for: bodies[parentIndex])
    else { return false }
    if stock.interruptedAt != nil || (stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0) {
      return true
    }
    let before = currentNewtBodyState(bodies[parentIndex])
    guard let components = source.components(stock: stock, at: time, parent: before, load: load),
      let momentum = CurrentNewtComponentMechanics.momentum(components, about: before.pose.position),
      let mass = source.loadedParentMass(work: stock.work, load: load)
    else { return false }
    guard let stopped = CurrentNewtKitBrake.retainedState(components: components,
      mass: mass, before: before, maximumAngularSpeed: source.maximumAngularSpeed)
    else { return false }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: stock.work.loweredFraction,
      rodMetres: stock.work.rodMetres, rodVelocity: 0,
      guideWorkJoules: stock.work.guideWorkJoules,
      ejectionWorkJoules: stock.work.ejectionWorkJoules)
    guard stopped.structurallyValid,
      stock.interrupt(at: time, stoppedAt: time, work: work,
        charges: source.charges(at: time, actuation: receipt.actuation, work: work)),
      let afterParts = source.components(stock: stock, at: time, parent: stopped, load: load),
      let after = CurrentNewtComponentMechanics.momentum(afterParts, about: before.pose.position),
      (momentum.linearMomentum - after.linearMomentum).length
        <= 1e-8 * max(1, momentum.linearMomentum.length),
      (momentum.angularMomentum - after.angularMomentum).length
        <= 1e-8 * max(1, momentum.angularMomentum.length),
      after.kineticEnergyJoules <= momentum.kineticEnergyJoules
        + 1e-8 * max(1, momentum.kineticEnergyJoules)
    else { return false }
    bodies[parentIndex].physical?.velocity = stopped.velocity
    bodies[parentIndex].physical?.angularVelocity = stopped.angularVelocity
    bodies[parentIndex].physical?.currentNewtKitStock = stock
    record.hull = .init(body: bodies[parentIndex], pose: commander.flightSimulation.pose, time: time)
    commander.savedEMPState?.records[record.source] = record
    return true
  }
}

extension Game {
  /// Call AFTER the same private candidate has recorded actual captured custody
  /// and the unbound pod archive, before publishing that candidate.
  mutating func sealCurrentNewtCapturedService(
    _ receipt: CurrentNewtKitReceipt, at time: Double
  ) -> Bool {
    guard time == commander.flightSimulation.physicalTime,
      let source = CurrentNewtKitSource.source(for: receipt.issue), source.matches(receipt, observedAt: time),
      var record = commander.savedEMPState?.records[receipt.issue.person.source],
      let podIndex = record.podIndex(for: receipt.issue.person.ordinal),
      record.pods[podIndex].binding == nil, record.pods[podIndex].physicalTime == time,
      let capturedActor = record.pods[podIndex].body.physical?.identity,
      record.pods[podIndex].body.physical?.empCrewPod == receipt.issue.person,
      record.pods[podIndex].body.physical?.currentNewtKitReceipt == receipt,
      !bodies.contains(where: { $0.physical?.identity == capturedActor }),
      commander.nativePeople?.admissions.filter({
        $0.person == .emp(receipt.issue.person) && $0.origin == .rescuedPod
          && $0.physicalTime == time && $0.actor == capturedActor
      }).count == 1
    else { return false }
    let parentIndex: Int?
    var stock: CurrentNewtKitStock
    if let parentActor = record.hull.binding {
      guard let index = bodies.firstIndex(where: { $0.physical?.identity == parentActor }),
        let current = bodies[index].physical?.currentNewtKitStock,
        currentNewtParentOwner(body: bodies[index], stock: current) == record.source,
        current == record.hull.body.physical?.currentNewtKitStock
      else { return false }
      parentIndex = index
      stock = current
    } else {
      guard record.hull.physicalTime == time,
        let current = record.hull.body.physical?.currentNewtKitStock,
        current.interruptedAt != nil || current.work.rodMetres == source.stroke,
        current.work.rodVelocity == 0,
        !bodies.contains(where: { $0.physical?.currentNewtKitStock?.issue.kitID == current.issue.kitID })
      else { return false }
      parentIndex = nil
      stock = current
    }
    guard stock.receipt == receipt, stock.phase == .released, stock.observedAt == time,
      source.matches(stock, at: time), stock.serviceCapturedAt == nil,
      stock.captureService(at: time) else { return false }
    if let parentIndex {
      bodies[parentIndex].physical?.currentNewtKitStock = stock
      record.hull = .init(body: bodies[parentIndex], pose: commander.flightSimulation.pose, time: time)
    } else {
      record.hull.body.physical?.currentNewtKitStock = stock
    }
    commander.savedEMPState?.records[record.source] = record
    return true
  }
}
