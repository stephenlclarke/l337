import Foundation

enum NativeC01LaneRepairSave {
  static func decodeClosed(_ data: Data) throws -> NativeC01LaneRepairState {
    guard data.count <= 1_048_576 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw SaveError.invalidCommander }
    let state = try JSONDecoder().decode(NativeC01LaneRepairState.self, from: data)
    guard shapeValid(state),
      (object as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)))
    else { throw SaveError.invalidCommander }
    return state
  }

  static func shapeValid(_ state: borrowing NativeC01LaneRepairState) -> Bool {
    guard state.source.valid, state.progress.count <= 3, state.receipts.count <= 3,
      Set(state.progress.map(\.target)).count == state.progress.count,
      Set(state.receipts.map(\.target)).count == state.receipts.count
    else { return false }
    for progress in state.progress {
      guard progressValid(progress, source: state.source) else { return false }
    }
    var sequences: Set<UInt64> = []
    for receipt in state.receipts {
      guard let progress = state.progress.first(where: { $0.target == receipt.target }),
        abs(progress.seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8,
        let last = progress.segments.last, last.intervals > 0, let end = last.last,
        confirmationValid(receipt.confirmation, progress: progress),
        receipt.actor == receipt.confirmation.arm.actor, receipt.physicalTime.isFinite,
        receipt.physicalTime == receipt.confirmation.end,
        receipt.physicalTime >= end, receipt.physicalTime <= 1e12,
        receipt.sequence > 0, receipt.sequence < UInt64(Int64.max),
        sequences.insert(receipt.sequence).inserted,
        let history = try? NativeC01LaneRepair.history(progress, confirmation: receipt.confirmation),
        history == receipt.history,
        receipt.operation == NativeC01LaneRepair.calibrationOperation(
          source: state.source, target: receipt.target, history: history)
      else { return false }
    }
    if let use = state.installation {
      let receipts = state.receipts
      let ordered = NativeC01LaneRepair.Target.allCases.compactMap { target in
        receipts.first(where: { $0.target == target })?.operation
      }
      guard state.receipts.count == 3, ordered.count == 3, use.calibrations == ordered,
        use.mission == state.source.mission, use.permission == state.source.permission,
        use.owner == state.source.owner, use.standard == state.source.standard,
        use.recorder == state.source.recorder,
        use.operation == NativeC01LaneRepair.installationOperation(
          source: state.source, calibrations: ordered),
        use.sequence == state.receipts.map(\.sequence).max(),
        use.physicalTime == state.receipts.map(\.physicalTime).max()
      else { return false }
    } else if state.receipts.count == 3 {
      // The third receipt and use of the original standard are one publication.
      return false
    }
    return true
  }

  private static func progressValid(
    _ progress: NativeC01LaneRepairProgress, source: NativeC01LaneRepairSource
  ) -> Bool {
    guard progress.segments.count <= NativeC01LaneRepair.maximumSegments,
      progress.seconds.isFinite,
      (0...(NativeC01LaneRepair.qualifiedSeconds + 1e-8)).contains(progress.seconds)
    else { return false }
    var previous = source.physicalTime
    var operations: Set<UUID> = []
    for segment in progress.segments {
      let arm = segment.arm
      guard arm.mission == source.mission, arm.permission == source.permission,
        arm.standard == source.standard, arm.owner == source.owner, arm.target == progress.target,
        arm.actor.system == NativeC01LaneRepair.location,
        arm.player.system == NativeC01LaneRepair.location,
        arm.actor.visit >= source.visit, arm.player.visit == arm.actor.visit,
        arm.actor.entity > 1, arm.player.entity == 0,
        arm.inventoryRevision < UInt64(Int64.max), operations.insert(arm.operation).inserted,
        arm.physicalTime.isFinite, arm.physicalTime >= previous, arm.physicalTime <= 1e12,
        segment.seconds.isFinite, segment.seconds >= 0,
        segment.intervals < UInt64(Int64.max)
      else { return false }
      if segment.intervals == 0 {
        guard segment.seconds == 0, segment.first == nil, segment.last == nil,
          segment.lastRange == nil, segment.lastSpeed == nil, segment.lastAim == nil
        else { return false }
        previous = arm.physicalTime
      } else {
        guard let first = segment.first, let last = segment.last,
          first.isFinite, last.isFinite, first >= arm.physicalTime, last > first, last <= 1e12,
          segment.seconds > 0, segment.seconds <= last - first + 1e-8,
          let range = segment.lastRange, let speed = segment.lastSpeed, let aim = segment.lastAim,
          NativeC01LaneRepair.qualifies(range: range, speed: speed, aim: aim)
        else { return false }
        previous = last
      }
    }
    if let arm = progress.completionArm {
      guard abs(progress.seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8,
        (progress.segments.last?.intervals ?? 0) > 0,
        arm.mission == source.mission, arm.permission == source.permission,
        arm.standard == source.standard, arm.owner == source.owner, arm.target == progress.target,
        arm.actor.system == NativeC01LaneRepair.location,
        arm.player.system == NativeC01LaneRepair.location,
        arm.actor.visit >= source.visit, arm.player.visit == arm.actor.visit,
        arm.actor.entity > 1, arm.player.entity == 0,
        arm.inventoryRevision < UInt64(Int64.max), !operations.contains(arm.operation),
        arm.physicalTime.isFinite, arm.physicalTime >= previous, arm.physicalTime <= 1e12
      else { return false }
    }
    return true
  }

  private static func confirmationValid(
    _ value: NativeC01LaneRepairConfirmation, progress: NativeC01LaneRepairProgress
  ) -> Bool {
    guard let last = progress.segments.last, let creditedEnd = last.last,
      (progress.completionArm ?? last.arm) == value.arm,
      value.start.isFinite, value.end.isFinite, value.start >= value.arm.physicalTime,
      value.end > value.start, value.end <= 1e12,
      value.end - value.start <= NativeC01LaneRepair.maximumPhysicalInterval,
      value.end >= creditedEnd,
      NativeC01LaneRepair.qualifies(
        range: value.startRange, speed: value.startSpeed, aim: value.startAim),
      NativeC01LaneRepair.qualifies(
        range: value.endRange, speed: value.endSpeed, aim: value.endAim)
    else { return false }
    return true
  }

  // Finish the owned capture read before entering deeper historical validators.
  @inline(never)
  private static func standardCaptureHistoryJoins(
    _ state: borrowing NativeC01LaneRepairState,
    standard: borrowing NativeC01TimingStandardState, commander: borrowing Commander
  ) -> Bool {
    guard let capture = standard.capture,
      capture.operation == state.source.standard,
      state.source.visit >= capture.collector.visit,
      state.source.visit <= commander.flightSimulation.visit,
      state.source.physicalTime >= capture.physicalTime,
      state.source.physicalTime <= commander.flightSimulation.physicalTime
    else { return false }
    return true
  }

  @inline(never)
  static func historyJoins(
    _ state: borrowing NativeC01LaneRepairState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard shapeValid(state), sourceHistoryJoins(state, mission: mission, commander: commander),
      NativeC01SurveyorSave.valid(mission, commander: commander),
      NativeC01ReservationAuditSave.valid(mission, commander: commander)
    else { return false }
    return timingHistoryJoins(mission, commander: commander)
  }

  @inline(never)
  private static func sourceHistoryJoins(
    _ state: borrowing NativeC01LaneRepairState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard mission.id == state.source.mission,
      mission.definition == NativeGlassMeridian.stateID, mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version,
      let opening = mission.savedGlassMeridian,
      opening.permission.operation == state.source.permission,
      opening.permission.owner == state.source.owner,
      commander.equipmentOwnerID == state.source.owner,
      opening.reservationCase?.audit?.operation == state.source.audit,
      opening.surveyor?.capture?.operation == state.source.recorder,
      let standard = opening.timingStandard,
      standardCaptureHistoryJoins(state, standard: standard, commander: commander),
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening)
    else { return false }
    return true
  }

  @inline(never)
  private static func timingHistoryJoins(
    _ mission: borrowing ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard let standard = mission.savedGlassMeridian?.timingStandard else { return false }
    return NativeC01TimingStandardSave.valid(standard, mission: mission, commander: commander)
  }

  static func valid(
    _ state: borrowing NativeC01LaneRepairState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard historyJoins(state, mission: mission, commander: commander),
      let opening = mission.savedGlassMeridian,
      let group = mission.ownedEncounters[NativeC01LaneRepair.encounter], group.valid, group.admitted,
      group.galaxy == 0, group.system == 91,
      Set(group.actors.keys) == Set(NativeC01LaneRepair.Target.allCases.map(\.rawValue))
    else { return false }
    var identities: Set<ActorIdentity> = []
    for target in NativeC01LaneRepair.Target.allCases {
      guard let actor = group.actors[target.rawValue],
        NativeC01LaneRepair.original(actor, source: state.source, target: target),
        let physical = actor.body.physical,
        NativeC01LaneRepair.nativeValid(physical, source: state.source, target: target),
        identities.insert(physical.identity).inserted,
        physical.identity.visit <= commander.flightSimulation.visit,
        physical.identity.entity < commander.flightSimulation.nextActor,
        (physical.spawnIdentity?.sequence ?? UInt64.max) < commander.flightSimulation.nextSpawn
      else { return false }
    }
    for progress in state.progress {
      if let arm = progress.completionArm {
        guard arm.actor.visit <= commander.flightSimulation.visit,
          arm.actor.entity < commander.flightSimulation.nextActor,
          arm.physicalTime <= commander.flightSimulation.physicalTime
        else { return false }
      }
      for segment in progress.segments {
        let physicalTime = commander.flightSimulation.physicalTime
        guard segment.arm.actor.visit <= commander.flightSimulation.visit,
          segment.arm.physicalTime <= commander.flightSimulation.physicalTime,
          segment.last.map({ $0 <= physicalTime }) ?? true
        else { return false }
      }
    }
    for receipt in state.receipts {
      guard receipt.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(receipt.sequence),
        receipt.physicalTime <= commander.flightSimulation.physicalTime,
        receipt.actor.visit <= commander.flightSimulation.visit,
        mission.receipts.contains(NativeC01LaneRepair.receipt + "." + receipt.target.rawValue)
      else { return false }
    }
    if let use = state.installation {
      let expected = NativeC01Completion.milestones(opening)
      guard mission.milestones == expected,
        mission.receipts.contains(NativeC01LaneRepair.receipt),
        mission.receipts.contains("rebuild-lane"),
        opening.timingStandard?.used == use, opening.timingStandard?.loss == nil,
        use.physicalTime <= commander.flightSimulation.physicalTime,
        opening.surveyor?.loss.map({ $0.physicalTime >= use.physicalTime }) ?? true
      else { return false }
    } else {
      guard mission.milestones == [0, 1, 2, 3, 4],
        !mission.receipts.contains(NativeC01LaneRepair.receipt),
        !mission.receipts.contains("rebuild-lane"), opening.timingStandard?.used == nil
      else { return false }
    }
    return true
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("laneRepair"), !root.keys.contains("nativeC01LaneRepair")
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
        guard let mission = value as? [String: Any], !mission.keys.contains("laneRepair"),
          !mission.keys.contains("nativeC01LaneRepair")
        else { throw SaveError.invalidCommander }
        guard let opening = mission["savedGlassMeridian"] as? [String: Any],
          opening.keys.contains("laneRepair")
        else { continue }
        guard NativeC01ReservationAuditSave.contains(schema), !embedded,
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["digest"] as? String == NativeGlassMeridian.digest,
          mission["version"] as? String == NativeGlassMeridian.version,
          let leaf = opening["laneRepair"] as? [String: Any],
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
