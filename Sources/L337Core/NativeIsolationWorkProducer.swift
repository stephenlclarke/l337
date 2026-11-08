import Foundation

/// An attained-step input can only be obtained from the actual pair in this file.
struct NativeIsolationWorkSample: Sendable {
  let epoch: UUID
  let job: UUID
  let source: UUID
  let actors: [ActorIdentity]
  let contacts: [NativeIsolationContact]
  let accounts: [NativeIsolationEnergyAccounts]
  let producerSequence: UInt64
  let time: Double
  let endpoint: NativeIsolationWorkEndpoint?
  fileprivate init(
    epoch: UUID, job: UUID, source: UUID, actors: [ActorIdentity], contacts: [NativeIsolationContact],
    accounts: [NativeIsolationEnergyAccounts], producerSequence: UInt64, time: Double,
    endpoint: NativeIsolationWorkEndpoint?
  ) {
    self.epoch = epoch
    self.job = job
    self.source = source
    self.actors = actors
    self.contacts = contacts
    self.accounts = accounts
    self.producerSequence = producerSequence
    self.time = time
    self.endpoint = endpoint
  }
}

private final class NativeIsolationWorkAttempt {
  var game: Game
  init(_ original: borrowing Game) { game = copy original }
}

extension Game {
  @inline(never)
  func isolationWorkSample() -> NativeIsolationWorkSample? {
    guard !paused, !docked, !isMissionTrial, screen.isFlight,
      let child = isolationWorkChild, child.suspension == nil,
      let state = child.savedIsolationWork,
      state.modules.count == 2
    else { return nil }
    var actors: [ActorIdentity] = []
    for module in state.modules {
      guard module.admission != nil, module.loss == nil,
        let body = bodies.first(where: {
          $0.missionActorID == NativeIsolationWorkPack.actor(job: child.id, role: module.role)
        }), isolationWorkRole(body) == module.role, let actor = body.physical?.identity
      else { return nil }
      actors.append(actor)
    }
    guard Set(actors).count == 2 else { return nil }
    return .init(
      epoch: nativeStationRuntimeEpoch,
      job: child.id, source: state.source, actors: actors, contacts: state.modules.map(\.contact),
      accounts: state.modules.map(\.accounts), producerSequence: state.producerSequence,
      time: commander.flightSimulation.physicalTime, endpoint: isolationWorkEndpoint())
  }

  /// Physics/accounting commits before any writer attempt. Only contact transitions are proposals.
  mutating func advanceIsolationWork(
    from start: NativeIsolationWorkSample?, publish: ScriptPublisher?
  ) {
    observeIsolationWorkStationLoss()
    let end = isolationWorkSample()
    var measured: NativeIsolationWorkEndpoint?
    if let start, let end {
      measured = observeIsolationWorkStep(start: start, end: end)
    }
    if isolationWorkRuntime.arm != nil && end?.endpoint == nil {
      interruptIsolationWork()
    }
    let failed = isolationWorkFailure != nil
    guard let publish, isolationWorkRuntime.dirty || failed else { return }
    let time = commander.flightSimulation.physicalTime
    let checkpoint =
      time - isolationWorkRuntime.publishedTime >= 0.5
      || (start?.endpoint != nil && isolationWorkRuntime.arm == nil) || paused || !screen.isFlight
    var transition = false
    if let measured, let state = isolationWorkChild?.savedIsolationWork,
      let module = state.modules.first(where: { $0.role == measured.arm.authority.role })
    {
      transition =
        module.verification == nil
        && (module.opening == nil && abs(module.history.seconds(.work) - 20) < 1e-8
          || module.opening != nil && abs(module.history.seconds(.observation) - 1) < 1e-8)
    }
    guard checkpoint || transition || failed else { return }
    let attempt = NativeIsolationWorkAttempt(self)
    do {
      try attempt.game.failIsolationWorkIfNeeded()
      if transition, let measured { try attempt.game.stageIsolationWorkTransition(at: measured) }
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      attempt.game.isolationWorkRuntime.dirty = false
      attempt.game.isolationWorkRuntime.publishedTime = time
      try publish(&attempt.game)
      self = attempt.game
    } catch {
      isolationWorkRuntime.reason =
        "ATTAINED TRANSFER/WORK RETAINED - SAVE PENDING; CONTACT CHANGE NEEDS A FRESH MEASUREMENT"
    }
  }

  /// Credits no off-scene time. Both bodies, contact revisions and endpoints must span this step.
  private mutating func observeIsolationWorkStep(
    start: NativeIsolationWorkSample, end: NativeIsolationWorkSample
  ) -> NativeIsolationWorkEndpoint? {
    guard start.epoch == end.epoch, end.epoch == nativeStationRuntimeEpoch,
      start.job == end.job, start.source == end.source, start.actors == end.actors,
      start.contacts == end.contacts, start.accounts == end.accounts,
      start.producerSequence == end.producerSequence,
      let elapsed = NativeIsolationWorkEnvelope.interval(start: start.time, end: end.time),
      var child = isolationWorkChild, child.id == start.job,
      var state = child.savedIsolationWork, state.producerSequence == start.producerSequence,
      state.producerSequence < UInt64(Int64.max) - 1,
      child.revision < UInt64(Int64.max) - 1
    else { return nil }
    let sequence = state.producerSequence + 1
    var endpoint: NativeIsolationWorkEndpoint?
    if let before = start.endpoint, let after = end.endpoint, before.arm == after.arm,
      before.time == start.time, after.time == end.time,
      isolationWorkRuntime.arm == after.arm
    {
      endpoint = after
    }
    do {
      for index in state.modules.indices {
        var module = state.modules[index]
        guard module.accounts == start.accounts[index], module.contact == start.contacts[index]
        else { return nil }
        let before = module.accounts
        let transferred = try module.accounts.transfer(seconds: elapsed, contact: module.contact)
        if case .connected = module.contact { module.connectedSeconds += elapsed }
        let meter = NativeIsolationMeterEvidence(
          actor: start.actors[index], peer: start.actors[1 - index], sequence: sequence,
          start: start.time, end: end.time, contact: module.contact, before: before,
          after: module.accounts, transferred: transferred)
        guard meter.valid else { return nil }
        module.binding = start.actors[index]
        module.lastMeter = meter
        if let endpoint, endpoint.arm.authority.role == module.role,
          endpoint.arm.authority.actor == meter.actor, module.verification == nil
        {
          let phase: NativeIsolationMeasurementPhase = module.opening == nil ? .work : .observation
          if let proof = isolationMeasurementProof(module: module, meter: meter) {
            let previous = module.history.seconds(phase)
            // A bounded history refusal must not undo an attained native energy transfer.
            var history = module.history
            if (try? history.record(
              authority: endpoint.arm.authority, phase: phase, proof: proof,
              start: start.time, end: end.time,
              range: endpoint.range, speed: endpoint.speed, aim: endpoint.aim)) != nil
            {
              module.history = history
            }
            if phase == .observation, previous == 0, module.history.seconds(phase) > 0 {
              module.observationFirst = meter
            }
          }
        }
        state.modules[index] = module
      }
      state.producerSequence = sequence
      state.localSeconds += elapsed
      guard state.shapeValid else { return nil }
      child.savedIsolationWork = state
      child.revision += 1
      commander.scriptState.instances[child.id] = child
      isolationWorkRuntime.dirty = true
      return endpoint
    } catch { return nil }
  }

  private func isolationMeasurementProof(
    module: NativeIsolationWorkModule, meter: NativeIsolationMeterEvidence
  ) -> NativeIsolationProofKind? {
    guard let opening = module.opening else {
      return NativeIsolationProofKind.connectedReading(meter)
    }
    guard meter.valid, module.contact == opening.change.after,
      meter.contact == opening.change.after, meter.transferred == 0,
      meter.sequence > opening.meter.sequence, meter.start >= opening.meter.end,
      meter.end > opening.meter.end, meter.before == opening.meter.after,
      meter.after == opening.meter.after,
      opening.change.proof.matchesIsolatedAccounts(meter.after)
    else { return nil }
    return opening.change.proof
  }

  /// Called only after the private attained producer above supplied a fresh endpoint and meter.
  private mutating func stageIsolationWorkTransition(at endpoint: NativeIsolationWorkEndpoint)
    throws
  {
    guard isolationWorkRuntime.arm == endpoint.arm,
      let fresh = isolationWorkEndpoint(), fresh.arm == endpoint.arm, fresh.time == endpoint.time,
      var child = isolationWorkChild, child.id == endpoint.arm.job,
      var state = child.savedIsolationWork,
      let index = state.modules.firstIndex(where: { $0.role == endpoint.arm.authority.role }),
      var parent = commander.scriptState.instances[state.permission.parent],
      let meter = state.modules[index].lastMeter, meter.end == endpoint.time,
      meter.actor == endpoint.arm.authority.actor,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    var module = state.modules[index]
    guard module.verification == nil else { throw SaveError.invalidCommander }
    if let opening = module.opening {
      guard let first = module.observationFirst else { throw SaveError.invalidCommander }
      let observations = module.history.segments.filter { $0.phase == .observation }
      let hash = try NativeFlightReception.hash(observations)
      let operation = try NativeIsolationVerification.identity(
        opening: opening.operation, authority: endpoint.arm.authority, observation: hash,
        first: first, last: meter, sequence: sequence, proof: opening.change.proof)
      let receipt = NativeIsolationVerification(
        operation: operation, sequence: sequence, authority: endpoint.arm.authority,
        opening: opening.operation, geometry: opening.geometry, workHistory: opening.workHistory,
        observationHistory: hash, first: first, last: meter, proof: opening.change.proof)
      guard receipt.valid(opened: opening, history: module.history) else {
        throw SaveError.invalidCommander
      }
      module.verification = receipt
      isolationWorkRuntime.arm = nil
      isolationWorkRuntime.reason =
        "CONTACT OPEN; SEPARATE NATIVE METER CONFIRMED ZERO FLOW ("
        + opening.change.proof.rawValue + ")."
    } else {
      guard module.contact == .connected, meter.contact == module.contact,
        let proof = NativeIsolationProofKind.connectedReading(meter), proof.permitsOpening(meter)
      else { throw SaveError.invalidCommander }
      let work = module.history.segments.filter { $0.phase == .work }
      let hash = try NativeFlightReception.hash(work)
      let operation = try NativeIsolationWorkOpening.identity(
        authority: endpoint.arm.authority, history: hash, meter: meter, revision: 1,
        sequence: sequence, proof: proof, epoch: endpoint.arm.epoch)
      let change = NativeIsolationContactChange(
        epoch: endpoint.arm.epoch, source: state.source, module: module.module,
        supply: module.supply, load: module.load, before: module.contact,
        after: .latchedOpen(operation: operation, revision: 1), proof: proof)
      let receipt = NativeIsolationWorkOpening(
        operation: operation, sequence: sequence, authority: endpoint.arm.authority,
        geometry: try NativeIsolationWorkSource.geometryHash, workHistory: hash, contactRevision: 1,
        meter: meter, change: change)
      guard receipt.valid(history: module.history) else { throw SaveError.invalidCommander }
      // This is the native circuit switch, consumed by every subsequent transfer step.
      // The candidate is published before any later zero-flow observation can be credited.
      module.opening = receipt
      module.contact = change.after
      isolationWorkRuntime.reason =
        "CONTACT OPEN - KEEP THE ORIGINAL SURFACE IN VIEW FOR 1s ZERO-FLOW VERIFICATION."
    }
    state.modules[index] = module
    guard state.shapeValid else { throw SaveError.invalidCommander }
    child.savedIsolationWork = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[child.id] = child
    commander.scriptState.instances[parent.id] = parent
  }
}
