import Foundation

/// Closed current C01 timing-standard validation inside the current reservation envelope.
enum NativeC01TimingStandardSave {
  static func decodeClosed(_ data: Data) throws -> NativeC01TimingStandardState {
    guard data.count <= 262_144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw SaveError.invalidCommander }
    let state = try JSONDecoder().decode(NativeC01TimingStandardState.self, from: data)
    guard shapeValid(state),
      (object as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)))
    else { throw SaveError.invalidCommander }
    return state
  }

  static func shapeValid(_ state: borrowing NativeC01TimingStandardState) -> Bool {
    guard state.source.valid else { return false }
    if let capture = state.capture {
      let radius = NativeC01TimingStandard.Part.standard.design.rawMesh.vertices.map(\.length)
        .max()!
      guard capture.source == state.source,
        capture.operation == NativeC01TimingStandard.operation(source: state.source),
        capture.missionRevision < UInt64(Int64.max) - 1,
        NativeC01TimingStandard.original(capture.marker, source: state.source, part: .standard),
        capture.marker.presence == .present, capture.marker.body.energy > 0,
        capture.marker.body.position == capture.point,
        let physical = capture.marker.body.physical,
        NativeC01TimingStandard.nativeValid(physical, source: state.source, part: .standard),
        capture.collector.entity == 0, capture.collector.system == NativeC01TimingStandard.location,
        capture.collector.visit == physical.identity.visit,
        capture.scoop.node == EquipmentRuntimeCatalog.node(for: "Fuel Scoops"),
        capture.scoop.location?.hull == capture.carrier,
        capture.scoop.location?.slot == "utility.fuelScoops",
        capture.inventoryRevision < UInt64(Int64.max),
        capture.startTime.isFinite, capture.startTime >= state.source.physicalTime,
        capture.physicalTime.isFinite, capture.physicalTime > capture.startTime,
        capture.physicalTime - capture.startTime <= 0.1 + 1e-9,
        NativeC01Surveyor.approachAllowed(
          point: capture.point, radius: radius, speed: capture.relativeSpeed)
      else { return false }

    }
    if let used = state.used {
      guard let capture = state.capture, state.loss == nil,
        used.mission == state.source.mission, used.permission == state.source.permission,
        used.owner == state.source.owner, used.standard == capture.operation,
        used.recorder == state.source.recorder, used.calibrations.count == 3,
        Set(used.calibrations).count == 3,
        used.sequence > 0, used.sequence < UInt64(Int64.max),
        used.physicalTime.isFinite, used.physicalTime >= capture.physicalTime,
        used.physicalTime <= 1e12
      else { return false }
    }
    guard let loss = state.loss else { return true }
    let sourceTime = state.source.physicalTime
    guard loss.physicalTime.isFinite,
      loss.physicalTime >= (state.capture?.physicalTime ?? sourceTime),
      loss.energy.isFinite, loss.collector.entity == 0,
      loss.collector.visit >= state.source.visit
    else { return false }
    switch loss.kind {
    case .standardDestroyed:
      guard state.capture == nil, loss.escapePod == nil, let actor = loss.actor,
        actor.presence == .destroyed, actor.body.energy == 0,
        NativeC01TimingStandard.original(actor, source: state.source, part: .standard),
        let physical = actor.body.physical,
        NativeC01TimingStandard.nativeValid(physical, source: state.source, part: .standard),
        loss.collector.system == NativeC01TimingStandard.location,
        loss.collector.visit == physical.identity.visit
      else { return false }
    case .carrierDestroyed:
      guard let capture = state.capture, loss.actor == nil, loss.escapePod == nil,
        loss.carrier == capture.carrier, loss.energy <= 0
      else { return false }
    case .escape:
      guard let capture = state.capture, loss.actor == nil, loss.carrier == capture.carrier,
        loss.energy > 0, let pod = loss.escapePod,
        pod.node == EquipmentRuntimeCatalog.node(for: "Escape Pod"),
        pod.location?.hull == loss.carrier, pod.location?.slot == "utility.escapePod"
      else { return false }
    }
    return true
  }

  static func historyJoins(
    _ state: borrowing NativeC01TimingStandardState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard shapeValid(state), mission.id == state.source.mission,
      mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version,
      let opening = mission.savedGlassMeridian, let audit = opening.reservationCase?.audit,
      let recorder = opening.surveyor?.capture,
      opening.permission.operation == state.source.permission,
      opening.permission.owner == state.source.owner,
      commander.equipmentOwnerID == state.source.owner,
      audit.operation == state.source.audit, recorder.operation == state.source.recorder,
      state.source.physicalTime >= audit.physicalTime,
      state.source.visit >= audit.pin.dock.actor.visit,
      state.source.visit <= commander.flightSimulation.visit,
      state.source.physicalTime <= commander.flightSimulation.physicalTime,
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening),
      NativeC01SurveyorSave.valid(mission, commander: commander),
      NativeC01ReservationAuditSave.valid(mission, commander: commander)
    else { return false }
    return true
  }

  /// Joins historical facts to retained native actors. It never grants a live token.
  static func valid(
    _ state: borrowing NativeC01TimingStandardState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard historyJoins(state, mission: mission, commander: commander),
      carrierLossJoins(state, recorder: mission.savedGlassMeridian?.surveyor),
      let group = mission.ownedEncounters[NativeC01TimingStandard.encounter],
      group.valid, group.admitted, group.galaxy == 0, group.system == 162,
      Set(group.actors.keys) == Set(NativeC01TimingStandard.Part.allCases.map(\.rawValue))
    else { return false }
    var identities: Set<ActorIdentity> = []
    for part in NativeC01TimingStandard.Part.allCases {
      guard let actor = group.actors[part.rawValue],
        NativeC01TimingStandard.original(actor, source: state.source, part: part),
        let physical = actor.body.physical,
        NativeC01TimingStandard.nativeValid(physical, source: state.source, part: part),
        identities.insert(physical.identity).inserted,
        physical.identity.visit <= commander.flightSimulation.visit,
        physical.identity.entity < commander.flightSimulation.nextActor,
        (physical.spawnIdentity?.sequence ?? UInt64.max) < commander.flightSimulation.nextSpawn
      else { return false }
      if part == .standard {
        if state.capture != nil {
          guard actor.presence == .outside else { return false }
        } else if state.loss?.kind == .standardDestroyed {
          guard actor == state.loss?.actor else { return false }
        } else {
          guard actor.presence == .present || actor.presence == .unloaded else { return false }
        }
      }
    }
    if let capture = state.capture {
      let expectedMilestones: Set<Int> = state.used == nil
        ? [0, 1, 2, 3, 4]
        : mission.savedGlassMeridian.map { NativeC01Completion.milestones($0) } ?? []
      guard mission.milestones == expectedMilestones,
        [NativeC01TimingStandard.receipt, NativeC01TimingStandard.target, "recover-standard"]
          .allSatisfy({ mission.receipts.contains($0) }),
        capture.missionRevision < mission.revision,
        capture.physicalTime <= commander.flightSimulation.physicalTime,
        let current = group.actors[NativeC01TimingStandard.target],
        current.identity == capture.marker.identity,
        current.body.physical?.identity == capture.marker.body.physical?.identity,
        equipmentHistoryValid(capture.scoop, owner: state.source.owner, commander: commander)
      else { return false }

    } else {
      guard mission.milestones == [0, 1, 2, 3],
        [NativeC01TimingStandard.receipt, NativeC01TimingStandard.target, "recover-standard"]
          .allSatisfy({ !mission.receipts.contains($0) })
      else { return false }
    }
    if let used = state.used {
      guard let lane = mission.savedGlassMeridian?.laneRepair, lane.installation == used,
        NativeC01LaneRepairSave.shapeValid(lane),
        lane.source.standard == state.capture?.operation,
        lane.source.permission == state.source.permission, lane.source.owner == state.source.owner,
        used.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    if let loss = state.loss {
      guard loss.physicalTime <= commander.flightSimulation.physicalTime,
        loss.collector.visit <= commander.flightSimulation.visit
      else { return false }
      if let pod = loss.escapePod {
        guard equipmentHistoryValid(pod, owner: state.source.owner, commander: commander),
          commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false
        else { return false }
      }
    }
    return true
  }

  /// Both originals leave one carrier in the same real destruction/escape transaction.
  /// A source-side standard destruction is independent and must not erase recorder custody.
  static func carrierLossJoins(
    _ state: borrowing NativeC01TimingStandardState,
    recorder: NativeC01SurveyorState?
  ) -> Bool {
    guard let capture = state.capture else { return true }
    if let used = state.used {
      return state.loss == nil
        && (recorder?.loss.map({ $0.physicalTime >= used.physicalTime }) ?? true)
    }
    let own = state.loss
    let prior = recorder?.loss
    let ownCarrierLoss = own.map { $0.kind == .carrierDestroyed || $0.kind == .escape } ?? false
    guard ownCarrierLoss || prior != nil else { return true }
    guard let own, let prior, prior.physicalTime >= capture.physicalTime,
      own.physicalTime == prior.physicalTime, own.carrier == prior.carrier,
      own.collector == prior.collector, own.energy == prior.energy
    else { return false }
    switch prior.kind {
    case .recorderDestroyed: return false
    case .carrierDestroyed: return own.kind == .carrierDestroyed && own.escapePod == nil
    case .escape: return own.kind == .escape && own.escapePod == prior.escapePod
    }
  }

  private static func equipmentHistoryValid(
    _ item: EquipmentPurchaseItem, owner: UUID, commander: borrowing Commander
  ) -> Bool {
    if let history = commander.savedEquipmentPurchaseHistory {
      for receipt in history.paid where receipt.binding.request.newItem == item.id {
        return history.owner == owner && receipt.owner == owner && receipt.node == item.node
          && item.provenance == .paid(owner: owner, transaction: receipt.transaction)
      }
    }
    switch item.provenance {
    case .paid, .legacyUnknown: return false
    case .standard, .grant, .recovered, .reward, .earned, .xyzzy, .missionIssue: return true
    }
  }
}

extension NativeC01TimingStandardSave {
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("timingStandard"), !root.keys.contains("nativeC01TimingStandard")
    else { throw SaveError.invalidCommander }
    func check(_ object: [String: Any], embedded: Bool) throws {
      let values: [Any]
      if let raw = object["instances"] as? [String: Any], raw.count <= 128 {
        values = Array(raw.values)
      } else if let raw = object["instances"] as? [Any], raw.count <= 256,
        raw.count.isMultiple(of: 2)
      {
        values = stride(from: 1, to: raw.count, by: 2).map { raw[$0] }
      } else if object["instances"] == nil {
        values = []
      } else {
        throw SaveError.invalidCommander
      }
      for value in values {
        guard let mission = value as? [String: Any], !mission.keys.contains("timingStandard"),
          !mission.keys.contains("nativeC01TimingStandard")
        else { throw SaveError.invalidCommander }
        guard let opening = mission["savedGlassMeridian"] as? [String: Any],
          opening.keys.contains("timingStandard")
        else { continue }
        guard NativeC01ReservationAuditSave.contains(schema), !embedded,
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["digest"] as? String == NativeGlassMeridian.digest,
          mission["version"] as? String == NativeGlassMeridian.version,
          let leaf = opening["timingStandard"] as? [String: Any],
          NativeGlassMeridianSave.boundedFields(opening)
        else { throw SaveError.invalidCommander }
        _ = try decodeClosed(JSONSerialization.data(withJSONObject: leaf))
      }
    }
    try check(root, embedded: part != .missions)
    if let saved = root["savedScriptState"] as? [String: Any] {
      try check(saved, embedded: true)
    }
  }
}
