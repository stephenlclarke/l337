import Foundation

private final class NativeC01LaneRepairAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  var c01LaneRepairQualifiedSeconds: Double {
    glassMeridianMission?.savedGlassMeridian?.laneRepair?.progress.reduce(0) {
      $0 + $1.seconds
    } ?? 0
  }

  mutating func advanceC01LaneRepairWork(
    from start: NativeC01LaneRepairEndpoint?, publish: ScriptPublisher?
  ) {
    let end = c01LaneRepairEndpoint()
    let attained: Bool
    var intervalResult: NativeC01LaneRepairIntervalResult
    if let start, let end {
      if !start.sameAuthority(end) {
        attained = false
        intervalResult = .authorityRefused
      } else if NativeC01LaneRepair.credit(before: 0, start: start.time, end: end.time) == nil {
        attained = false
        intervalResult = .clockRefused
      } else {
        intervalResult = c01LaneRepairAttained(from: start, to: end)
        attained = intervalResult == .attained
      }
    } else {
      attained = false
      intervalResult = start == nil ? .missingStart : .missingEnd
    }
    if attained, let start, let end {
      intervalResult = observeC01LaneRepairWork(start: start, end: end)
        ? .credited : .observerRefused
    }
    c01LaneRepairWorkRuntime.lastIntervalResult = intervalResult
    guard let publish else { return }
    let checkpoint = c01LaneRepairWorkRuntime.dirty
      && (c01LaneRepairQualifiedSeconds - c01LaneRepairWorkRuntime.publishedSeconds >= 0.5
        || c01LaneRepairWorkRuntime.arm == nil || paused || !screen.isFlight)
    var finish = false
    if attained, let arm = c01LaneRepairWorkRuntime.arm?.binding,
      let state = glassMeridianMission?.savedGlassMeridian?.laneRepair,
      let progress = state.progress.first(where: { $0.target == arm.target })
    {
      finish = progress.seconds >= NativeC01LaneRepair.qualifiedSeconds - 1e-8
        && !state.receipts.contains(where: { $0.target == arm.target })
    }
    let attempt = NativeC01LaneRepairAttempt(self)
    do {
      let admission = try attempt.game.prepareC01LaneRepair()
      guard checkpoint || finish || admission else { return }
      if finish, let start, let end {
        try attempt.game.completeC01LaneRepair(from: start, to: end)
      }
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
      c01LaneRepairWorkRuntime.publishedSeconds = c01LaneRepairQualifiedSeconds
      c01LaneRepairWorkRuntime.dirty = false
    } catch {
      c01LaneRepairWorkRuntime.reason =
        "MEASURED WORK RETAINED - SAVE PENDING; ORIGINAL STANDARD AND STAGE NOT COMMITTED"
    }
  }

  private mutating func observeC01LaneRepairWork(
    start: NativeC01LaneRepairEndpoint, end: NativeC01LaneRepairEndpoint
  ) -> Bool {
    guard let arm = c01LaneRepairWorkRuntime.arm?.binding, start.arm == arm.operation,
      var mission = glassMeridianMission, mission.revision < UInt64(Int64.max) - 1,
      var opening = mission.savedGlassMeridian, var state = opening.laneRepair,
      let index = state.progress.firstIndex(where: { $0.target == arm.target }),
      var segment = state.progress[index].segments.last, segment.arm == arm,
      !state.receipts.contains(where: { $0.target == arm.target }),
      segment.intervals < UInt64(Int64.max) - 1,
      start.time >= (segment.last ?? arm.physicalTime),
      let credit = NativeC01LaneRepair.credit(
        before: state.progress[index].seconds, start: start.time, end: end.time)
    else { return false }
    let didCredit = credit > 0
    if didCredit {
      segment.first = segment.first ?? start.time
      segment.last = end.time
      segment.seconds += credit
      segment.intervals += 1
      segment.lastRange = end.range
      segment.lastSpeed = end.speed
      segment.lastAim = end.aim
      state.progress[index].segments[state.progress[index].segments.count - 1] = segment
      opening.laneRepair = state
      mission.savedGlassMeridian = opening
      mission.revision += 1
      commander.scriptState.instances[mission.id] = mission
      c01LaneRepairWorkRuntime.dirty = true
    }
    c01LaneRepairWorkRuntime.reason = String(
      format: "%@ CALIBRATION %.2f /20s", arm.target.rawValue.uppercased(),
      state.progress[index].seconds)
    return didCredit
  }

  private mutating func completeC01LaneRepair(
    from start: NativeC01LaneRepairEndpoint, to end: NativeC01LaneRepairEndpoint
  ) throws {
    guard let arm = c01LaneRepairWorkRuntime.arm?.binding, start.sameAuthority(end),
      start.arm == arm.operation, end.arm == arm.operation,
      NativeC01LaneRepair.credit(before: 0, start: start.time, end: end.time) != nil,
      var mission = glassMeridianMission, mission.revision < UInt64(Int64.max) - 1,
      var opening = mission.savedGlassMeridian, var state = opening.laneRepair,
      var standard = opening.timingStandard, standard.held, opening.surveyor?.held == true,
      state.installation == nil, standard.capture?.operation == state.source.standard,
      !state.receipts.contains(where: { $0.target == arm.target }),
      let progress = state.progress.first(where: { $0.target == arm.target }),
      abs(progress.seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8,
      (progress.completionArm ?? progress.segments.last?.arm) == arm,
      commander.equipmentOwnerID == state.source.owner,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let confirmation = NativeC01LaneRepairConfirmation(
      arm: arm, start: start.time, end: end.time,
      startRange: start.range, endRange: end.range, startSpeed: start.speed, endSpeed: end.speed,
      startAim: start.aim, endAim: end.aim)
    let history = try NativeC01LaneRepair.history(progress, confirmation: confirmation)
    state.receipts.append(.init(
      operation: NativeC01LaneRepair.calibrationOperation(
        source: state.source, target: arm.target, history: history),
      target: arm.target, actor: end.actor, history: history, confirmation: confirmation,
      sequence: sequence, physicalTime: end.time))
    let beforeCargo = commander.checkedCargoTonnes
    if state.receipts.count == NativeC01LaneRepair.Target.allCases.count {
      for target in NativeC01LaneRepair.Target.allCases {
        guard c01LaneRepairActor(source: state.source, target: target) != nil else {
          throw SaveError.invalidCommander
        }
      }
      let calibrations = NativeC01LaneRepair.Target.allCases.compactMap { target in
        state.receipts.first(where: { $0.target == target })?.operation
      }
      let use = NativeC01TimingStandardUse(
        operation: NativeC01LaneRepair.installationOperation(
          source: state.source, calibrations: calibrations),
        mission: mission.id, permission: state.source.permission, owner: state.source.owner,
        standard: state.source.standard, recorder: state.source.recorder,
        calibrations: calibrations, sequence: sequence, physicalTime: end.time)
      state.installation = use
      standard.used = use
      opening.timingStandard = standard
      mission.milestones.insert(5)
      mission.receipts.formUnion([NativeC01LaneRepair.receipt, "rebuild-lane"])
      mission.journal.append(
        "All three original Lareria relay calibrations confirmed. The same one-tonne timing standard was installed once; the original8kg recorder remains aboard. Clinic escort is the next stage; no arrival, payment or final clue has been granted.")
    }
    guard NativeC01LaneRepairSave.shapeValid(state) else { throw SaveError.invalidCommander }
    opening.laneRepair = state
    mission.savedGlassMeridian = opening
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.receipts.insert(NativeC01LaneRepair.receipt + "." + arm.target.rawValue)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    if state.installation != nil {
      guard let beforeCargo, let afterCargo = commander.checkedCargoTonnes,
        afterCargo == beforeCargo - 1
      else { throw SaveError.invalidCommander }
    }
    c01LaneRepairWorkRuntime.arm = nil
    c01LaneRepairWorkRuntime.dirty = true
    c01LaneRepairWorkRuntime.reason = state.installation == nil
      ? "RELAY CALIBRATED - ORIGINAL STANDARD RETAINED FOR REMAINING RELAYS"
      : "THREE RELAYS CONFIRMED - ORIGINAL STANDARD INSTALLED; RECORDER RETAINED"
  }
}
