import Foundation

enum NativeC01InquiryLifecycleFailure: Error, Equatable, Sendable {
  case invalidRoot, sourceMismatch, missingBody, unsettledDestruction, unsupportedTransition
  case revisionOverflow
}

enum NativeC01InquiryLifecycleCapture: Equatable, Sendable {
  case notInquiry, retained
  case refused(NativeC01InquiryLifecycleFailure)
}

/// DATA comparisons only. Neither function issues accepted combat or a binding.
enum NativeC01InquiryLifecycleFacts {
  static func matchesBinding(
    _ binding: NativeC01InquiryFixtureBinding, bodyID: Int, actor: ActorIdentity, spawn: SpawnIdentity
  ) -> Bool {
    binding.bodyID == bodyID && binding.actor == actor && binding.spawn == spawn
  }
  static func terminalStampMatches(
    _ incident: CombatIncident, incidentID: UInt64?, origin: AttackOrigin?
  ) -> Bool {
    incident.outcome == .destruction && incident.id > 0
      && incident.id == incidentID && incident.origin == origin
  }
}

private struct NativeC01InquiryLifeAddress {
  let row: Int
  let part: Int
}

extension Game {
  /// Called only by the actual accepted destruction owner. The body death origin
  /// exists here, but applyBodyHit writes deathIncidentID after this callback returns.
  mutating func recordC01InquiryAcceptedDestruction(
    _ accepted: NativeC01InquiryAcceptedDestruction
  ) -> NativeC01InquiryLifecycleCapture {
    guard let root = commander.scriptState.savedC01Inquiry else { return .notInquiry }
    do {
      guard let body = bodies.first(where: { $0.id == accepted.bodyID }),
        let address = try c01LifeAddress(body, root: root)
      else { return .notInquiry }
      guard accepted.system == systemIdentity,
        accepted.visit == commander.flightSimulation.visit,
        accepted.revision == gameplayRevision, accepted.nativeEpoch == nativeStationRuntimeEpoch,
        accepted.incident.outcome == .destruction,
        accepted.incident.physicalTime == commander.flightSimulation.physicalTime,
        accepted.incident.victim == accepted.actor,
        body.physical?.identity == accepted.actor,
        body.physical?.spawnIdentity == accepted.spawn,
        body.energy == 0, body.physical?.deathOrigin == accepted.incident.origin
      else { throw NativeC01InquiryLifecycleFailure.sourceMismatch }
      let life = root.fixtureLifecycle[address.row]
      let previous = life.c01Parts[address.part]
      switch previous.presence {
      case .present: break
      case .destroyed(let existing):
        guard existing == accepted.incident else {
          throw NativeC01InquiryLifecycleFailure.unsettledDestruction
        }
        return .retained
      case .parked, .removed:
        throw NativeC01InquiryLifecycleFailure.unsupportedTransition
      }
      var parts = life.c01Parts
      parts[address.part] = try c01CapturedPart(body, previous: previous,
        presence: .destroyed(accepted.incident))
      let revision = try c01LifeNextRevision(life.revision)
      let retirement = life.retirement ?? .init(operation: accepted.operation, revision: revision,
        physicalTime: accepted.incident.physicalTime,
        cause: .partDestroyed(part: c01PartKind(address.part), incidentID: accepted.incident.id))
      var rows = root.fixtureLifecycle
      rows[address.row] = life.c01Replacing(parts, revision: revision, retirement: retirement)
      try c01InstallLifeRows(rows, root: root)
      return .retained
    } catch let failure as NativeC01InquiryLifecycleFailure {
      return .refused(failure)
    } catch {
      return .refused(.invalidRoot)
    }
  }

  /// The existing deferred set consumes these IDs before both its destroyed
  /// filter and final removeAll. A per-body continue would not protect the body.
  mutating func prepareC01InquiryDestroyedRemoval() -> Set<Int> {
    guard commander.scriptState.savedC01Inquiry != nil else { return [] }
    var deferred = Set<Int>()
    for body in bodies where body.energy <= 0 {
      guard let root = commander.scriptState.savedC01Inquiry else { return deferred }
      do {
        guard let address = try c01LifeAddress(body, root: root) else { continue }
        let life = root.fixtureLifecycle[address.row]
        let previous = life.c01Parts[address.part]
        try c01RequireCompletedDestruction(body, part: previous)
        let captured = try c01CapturedPart(body, previous: previous, presence: previous.presence)
        if captured != previous {
          var parts = life.c01Parts
          parts[address.part] = captured
          var rows = root.fixtureLifecycle
          rows[address.row] = life.c01Replacing(parts,
            revision: try c01LifeNextRevision(life.revision), retirement: life.retirement)
          try c01InstallLifeRows(rows, root: root)
        }
      } catch {
        if c01HasClaim(body, root: root) { deferred.insert(body.id) }
      }
    }
    return deferred
  }

  /// Latest physical DATA only. No phase integration, body admission, parking,
  /// rebind, birth, missing-body death inference or historical-case rewrite.
  mutating func captureC01InquiryCurrentLife() throws {
    guard let root = commander.scriptState.savedC01Inquiry else { return }
    guard root.shapeValid, root.owner == commander.equipmentOwnerID else {
      throw NativeC01InquiryLifecycleFailure.invalidRoot
    }
    var rows = root.fixtureLifecycle
    for index in rows.indices {
      let life = rows[index]
      var parts = life.c01Parts
      for slot in parts.indices {
        let part = parts[slot]
        let matches = bodies.filter { c01ClaimsBinding($0, binding: part.binding) }
        switch part.presence {
        case .present:
          guard matches.count == 1, let body = matches.first else {
            throw NativeC01InquiryLifecycleFailure.missingBody
          }
          guard body.energy > 0 else { throw NativeC01InquiryLifecycleFailure.unsettledDestruction }
          _ = try c01LifeAddress(body, root: root)
          parts[slot] = try c01CapturedPart(body, previous: part, presence: part.presence)
        case .destroyed:
          guard matches.count <= 1 else { throw NativeC01InquiryLifecycleFailure.sourceMismatch }
          if let body = matches.first {
            _ = try c01LifeAddress(body, root: root)
            try c01RequireCompletedDestruction(body, part: part)
            parts[slot] = try c01CapturedPart(body, previous: part, presence: part.presence)
          }
        case .parked, .removed:
          guard matches.isEmpty else { throw NativeC01InquiryLifecycleFailure.unsupportedTransition }
        }
      }
      if parts != life.c01Parts {
        rows[index] = life.c01Replacing(parts,
          revision: try c01LifeNextRevision(life.revision), retirement: life.retirement)
      }
    }
    // Orphan source tags cannot become ordinary fallback actors.
    for body in bodies where c01Tagged(body) {
      guard try c01LifeAddress(body, root: root) != nil else {
        throw NativeC01InquiryLifecycleFailure.sourceMismatch
      }
    }
    if rows != root.fixtureLifecycle { try c01InstallLifeRows(rows, root: root) }
  }

  func c01InquiryRequiresNativeParking(beforeRemoving body: SpaceBody) -> Bool {
    guard let root = commander.scriptState.savedC01Inquiry else { return false }
    return body.energy > 0 && c01HasClaim(body, root: root)
  }

  private func c01Tagged(_ body: SpaceBody) -> Bool {
    body.physical?.spawnIdentity?.producer.rawValue == "c01Inquiry"
  }

  private func c01ClaimsBinding(_ body: SpaceBody, binding: NativeC01InquiryFixtureBinding) -> Bool {
    body.physical?.identity == binding.actor || body.physical?.spawnIdentity == binding.spawn
      || (binding.actor.system == systemIdentity
        && binding.actor.visit == commander.flightSimulation.visit && body.id == binding.bodyID)
  }

  private func c01HasClaim(_ body: SpaceBody, root: NativeC01InquiryState) -> Bool {
    c01Tagged(body) || root.fixtureLifecycle.contains { life in
      life.c01Parts.contains { c01ClaimsBinding(body, binding: $0.binding) }
    }
  }

  private func c01LifeAddress(
    _ body: SpaceBody, root: NativeC01InquiryState
  ) throws -> NativeC01InquiryLifeAddress? {
    var matches: [NativeC01InquiryLifeAddress] = []
    for (row, life) in root.fixtureLifecycle.enumerated() {
      for (slot, part) in life.c01Parts.enumerated()
      where c01ClaimsBinding(body, binding: part.binding) {
        matches.append(.init(row: row, part: slot))
      }
    }
    if matches.isEmpty && !c01Tagged(body) { return nil }
    guard matches.count == 1, let address = matches.first, c01Tagged(body),
      root.shapeValid, root.owner == commander.equipmentOwnerID,
      let physical = body.physical, let spawn = physical.spawnIdentity,
      NativeC01InquiryLifecycleFacts.matchesBinding(
        root.fixtureLifecycle[address.row].c01Parts[address.part].binding,
        bodyID: body.id, actor: physical.identity, spawn: spawn),
      bodies.filter({ c01ClaimsBinding($0,
        binding: root.fixtureLifecycle[address.row].c01Parts[address.part].binding) }).count == 1,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      body.scriptNPC == nil, body.scriptShot == nil,
      body.missionActorID == nil, body.missionInstanceID == nil,
      physical.npc == nil, physical.ordnance == nil, physical.payload == nil,
      physical.rock == nil, physical.empSource == nil, physical.empCrewPod == nil,
      physical.catalogueShipID == nil
    else { throw NativeC01InquiryLifecycleFailure.sourceMismatch }
    return address
  }

  private func c01CapturedPart(
    _ body: SpaceBody, previous: NativeC01InquiryPartLife,
    presence: NativeC01InquiryFixturePresence
  ) throws -> NativeC01InquiryPartLife {
    guard let physical = body.physical, let spawn = physical.spawnIdentity,
      // Capture must refuse a future retained time rather than normalize it backward.
      commander.flightSimulation.physicalTime >= previous.physicalTime,
      NativeC01InquiryLifecycleFacts.matchesBinding(previous.binding,
        bodyID: body.id, actor: physical.identity, spawn: spawn)
    else { throw NativeC01InquiryLifecycleFailure.sourceMismatch }
    let camera = commander.flightSimulation.pose
    let part = NativeC01InquiryPartLife(binding: previous.binding,
      pose: .init(position: camera.systemPoint(body.position),
        orientation: body.orientation.transformed(by: camera.orientation)),
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      energy: body.energy, physicalTime: commander.flightSimulation.physicalTime,
      presence: presence, bindingHistory: previous.bindingHistory)
    guard part.shapeValid else { throw NativeC01InquiryLifecycleFailure.sourceMismatch }
    return part
  }

  private func c01RequireCompletedDestruction(_ body: SpaceBody, part: NativeC01InquiryPartLife) throws {
    guard body.energy == 0, case .destroyed(let incident) = part.presence,
      incident.victim == body.physical?.identity,
      NativeC01InquiryLifecycleFacts.terminalStampMatches(incident,
        incidentID: body.physical?.deathIncidentID, origin: body.physical?.deathOrigin)
    else { throw NativeC01InquiryLifecycleFailure.unsettledDestruction }
  }

  private mutating func c01InstallLifeRows(
    _ rows: [NativeC01InquiryFixtureLife], root: NativeC01InquiryState
  ) throws {
    let updated = NativeC01InquiryState(owner: root.owner, nextCaseOrdinal: root.nextCaseOrdinal,
      institutionalSource: root.institutionalSource, caseRecord: root.caseRecord,
      priorCases: root.priorCases, fixtureLifecycle: rows)
    guard updated.shapeValid else { throw NativeC01InquiryLifecycleFailure.invalidRoot }
    commander.scriptState.savedC01Inquiry = updated
  }

  private func c01LifeNextRevision(_ previous: UInt64) throws -> UInt64 {
    let (next, overflow) = previous.addingReportingOverflow(1)
    guard !overflow, next > 0, next < UInt64(Int64.max) else {
      throw NativeC01InquiryLifecycleFailure.revisionOverflow
    }
    return next
  }

  private func c01PartKind(_ slot: Int) -> NativeC01InquiryFixtureGeometry.Part {
    switch slot { case 0: .support; case 1: .head0; case 2: .head1; default: .head2 }
  }
}

private extension NativeC01InquiryFixtureLife {
  var c01Parts: [NativeC01InquiryPartLife] { [support, head0, head1, head2] }
  func c01Replacing(
    _ parts: [NativeC01InquiryPartLife], revision: UInt64,
    retirement: NativeC01InquiryFixtureRetirement?
  ) -> Self {
    .init(caseID: caseID, fixture: fixture, revision: revision,
      support: parts[0], head0: parts[1], head1: parts[2], head2: parts[3],
      modelSnapshot: modelSnapshot, retirement: retirement)
  }
}
