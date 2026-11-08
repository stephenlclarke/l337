import Foundation

extension Game {
  /// A sampled crew delay starts the actual mechanism. This runs only at a real
  /// native endpoint; no future state or fixture request can issue stock here.
  mutating func armCurrentNewtMechanisms(at time: Double) {
    guard time == commander.flightSimulation.physicalTime,
      let state = commander.savedEMPState else { return }
    for logical in state.sources {
      guard var record = commander.savedEMPState?.records[logical], !record.terminal,
        !record.isRecovered, let parent = record.hull.binding,
        let index = bodies.firstIndex(where: { $0.physical?.identity == parent }),
        isEMPDisabled(bodies[index]), bodies[index].physical?.empSource == logical,
        var stock = bodies[index].physical?.currentNewtKitStock,
        let source = CurrentNewtKitSource.source(for: stock.issue),
        stock.phase == .stowed, source.matches(stock, at: time),
        record.hull.body.physical?.currentNewtKitStock == stock,
        stock.issue.person.source == logical,
        record.crewOutcome(ordinal: stock.issue.person.ordinal) == .aboard,
        let episode = record.disableEpisodes.last,
        let sampled = episode.ejections.first(where: { $0.ordinal == stock.issue.person.ordinal }),
        sampled.emittedAt == nil, time == episode.incident.physicalTime + sampled.delay,
        time + source.dropDuration < episode.deadline,
        let load = currentNewtKitLoad(for: bodies[index]),
        source.loadModel?.matches(load, selectedPerson: stock.issue.person) == true
      else { continue }
      let actuation = CurrentNewtKitStock.Actuation(source: logical, sequence: record.sequence,
        parent: parent, initialParent: currentNewtBodyState(bodies[index]), load: load,
        startedAt: time, unlockAt: time + source.dropDuration,
        completeAt: time + source.duration, deadline: episode.deadline)
      guard source.matches(actuation, issue: stock.issue),
        stock.beginActuation(actuation, work: source.work(at: time, actuation: actuation),
          charges: source.charges(at: time, actuation: actuation))
      else { continue }
      bodies[index].physical?.currentNewtKitStock = stock
      record.hull = .init(body: bodies[index], pose: commander.flightSimulation.pose, time: time)
      commander.savedEMPState?.records[logical] = record
    }
  }

  /// Admit the independent physical cell and transfer the actual person at the
  /// accepted unlock endpoint. Every mutation commits in the same candidate.
  mutating func releaseCurrentNewtKitsAtCurrentClock() {
    guard let state = commander.savedEMPState else { return }
    for logical in state.sources {
      releaseCurrentNewtKit(source: logical)
    }
  }

  private mutating func releaseCurrentNewtKit(source logical: ActorIdentity) {
    guard let context = gameplayContext(),
      var record = commander.savedEMPState?.records[logical], !record.terminal, !record.isRecovered,
      let parent = record.hull.binding,
      let parentIndex = bodies.firstIndex(where: { $0.physical?.identity == parent }),
      var stock = bodies[parentIndex].physical?.currentNewtKitStock,
      let source = CurrentNewtKitSource.source(for: stock.issue),
      stock.phase == .actuating, stock.interruptedAt == nil,
      stock.observedAt == context.physicalTime, let a = stock.actuation,
      context.physicalTime == a.unlockAt, context.physicalTime < a.deadline,
      source.matches(stock, at: context.physicalTime),
      stock.work == source.work(at: a.unlockAt, actuation: a),
      record.hull.body.physical?.currentNewtKitStock == stock,
      record.crewOutcome(ordinal: stock.issue.person.ordinal) == .aboard,
      let load = currentNewtKitLoad(for: bodies[parentIndex]), load.samePhysicalInventory(as: a.load),
      let motion = source.motion(a, at: a.unlockAt),
      source.matchesState(currentNewtBodyState(bodies[parentIndex]), motion.parent),
      let profile = bodies[parentIndex].physical?.catalogueShipID.flatMap({
        SalvageCatalogue.empProfile(catalogueShipID: $0)
      })
    else { return }
    var delivered = false
    defer {
      // Unlock is conditional on this same-turn admission. A refusal leaves the
      // latch closed and the real attained lowering/work intact, permanently.
      if !delivered { interruptCurrentNewtRelease(logical: logical, parent: parent, at: context.physicalTime) }
    }
    let request = CurrentNewtPodReleaseRequest(issue: stock.issue, actuation: a,
      system: context.system, visit: context.visit, revision: context.revision,
      physicalTime: context.physicalTime, loadAtRelease: load,
      parent: motion.parent, pod: motion.pod, parentMass: motion.parentMass,
      podMass: motion.podMass, energyJoules: stock.work.guideWorkJoules
        + stock.work.ejectionWorkJoules, remainingCharges: stock.charges)
    var candidate = self
    let admission = candidate.admitCurrentOccupiedNewtPod(request)
    guard let actor = admission.actor, admission.refusal == nil,
      let podIndex = candidate.bodies.firstIndex(where: { $0.physical?.identity == actor }),
      let receipt = candidate.bodies[podIndex].physical?.currentNewtKitReceipt,
      receipt.issue == stock.issue, receipt.remainingCharges == stock.charges,
      stock.release(receipt),
      record.recordCrewEjection(ordinal: stock.issue.person.ordinal, at: context.physicalTime)
    else { return }
    candidate.bodies[parentIndex].physical?.currentNewtKitStock = stock
    record.pods.append(.init(body: candidate.bodies[podIndex],
      pose: candidate.commander.flightSimulation.pose, time: context.physicalTime))
    record.nextEjectionAt = record.disableEpisodes.last?.ejections.filter {
      record.crewOutcome(ordinal: $0.ordinal) == .aboard
    }.map { record.currentCrewDisableIncident.physicalTime + $0.delay }.min()
      ?? record.crewDeadline ?? context.physicalTime
    let native = record.crewAboard == 0
      && (profile.sourceRoles.contains(.thargoid)
        || candidate.commander.alienStorageState?.current.salvage.native.wrecks[record.wreck] != nil)
    if record.crewAboard == 0 {
      candidate.bodies[parentIndex].physical?.npc = nil
      candidate.bodies[parentIndex].physical?.blocksNavalEncounter = false
      candidate.bodies[parentIndex].physical?.population = .wreck
      candidate.bodies[parentIndex].hostile = false
      candidate.bodies[parentIndex].physical?.salvage = .init(category: .wreck,
        ownership: .abandoned, claimant: nil, wreck: record.wreck, section: nil, lot: nil,
        bounds: profile.bounds, workSurfaces: profile.surfaces(wreck: record.wreck))
      guard native || candidate.commander.salvageLedger.updateWreck(identity: record.wreck,
        motion: .init(pose: candidate.modelPose(of: candidate.bodies[parentIndex]),
          velocity: motion.parent.velocity, angularVelocity: motion.parent.angularVelocity,
          energy: candidate.bodies[parentIndex].energy)) else { return }
      candidate.notify("CREW EJECTED - UNOCCUPIED SALVAGE")
    }
    record.hull = .init(body: candidate.bodies[parentIndex],
      pose: candidate.commander.flightSimulation.pose, time: context.physicalTime)
    candidate.commander.savedEMPState?.records[logical] = record
    guard record.valid else { return }
    if native {
      guard candidate.retainNativeSalvageWreck(candidate.bodies[parentIndex]) else { return }
    }
    self = candidate
    delivered = true
  }

  private mutating func interruptCurrentNewtRelease(logical: ActorIdentity,
    parent: ActorIdentity, at time: Double) {
    guard let index = bodies.firstIndex(where: { $0.physical?.identity == parent }),
      var stock = bodies[index].physical?.currentNewtKitStock,
      let source = CurrentNewtKitSource.source(for: stock.issue),
      stock.phase == .actuating, stock.interruptedAt == nil,
      let a = stock.actuation, time == a.unlockAt, stock.observedAt == time,
      var record = commander.savedEMPState?.records[logical]
    else { return }
    let work = CurrentNewtKitStock.WorkState(loweredFraction: stock.work.loweredFraction,
      rodMetres: stock.work.rodMetres, rodVelocity: 0,
      guideWorkJoules: stock.work.guideWorkJoules,
      ejectionWorkJoules: stock.work.ejectionWorkJoules)
    guard stock.interrupt(at: time, stoppedAt: time, work: work,
      charges: source.charges(at: time, actuation: a, work: work)) else { return }
    bodies[index].physical?.currentNewtKitStock = stock
    record.hull = .init(body: bodies[index], pose: commander.flightSimulation.pose, time: time)
    commander.savedEMPState?.records[logical] = record
  }
}
