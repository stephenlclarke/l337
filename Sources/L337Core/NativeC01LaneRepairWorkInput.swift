import Foundation

/// Only explicit current input can mint this transient capability; decoded arm facts cannot.
final class NativeC01LaneRepairLiveArm: Sendable {
  let binding: NativeC01LaneRepairArm
  fileprivate init(_ binding: NativeC01LaneRepairArm) { self.binding = binding }
}

extension Game {
  mutating func interruptC01LaneRepairWork() {
    c01LaneRepairWorkRuntime.review = nil
    c01LaneRepairWorkRuntime.arm = nil
    c01LaneRepairWorkRuntime.reason = "Calibration stopped; measured partial work is retained."
  }

  mutating func handleC01LaneRepairWorkKey(_ key: String) -> Bool {
    let active = c01LaneRepairWorkRuntime.review != nil || c01LaneRepairWorkRuntime.arm != nil
    if active && ["escape", "k", "pause", "pause-toggle"].contains(key) {
      interruptC01LaneRepairWork()
      if key == "escape" { return true }
    }
    guard key == "return" else { return false }
    if let review = c01LaneRepairWorkRuntime.review {
      do { try confirmC01LaneRepairWork(review) } catch {
        interruptC01LaneRepairWork()
        notify("RELAY OR ORIGINAL STANDARD CHANGED - SELECT AND REVIEW AGAIN")
      }
      return true
    }
    guard !docked, !paused, screen == .front, energy > 0, !playerEMPDisabled,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.laneRepair,
      state.installation == nil,
      let body = bodies.first(where: { $0.id == weaponsTargetID }),
      let target = c01LaneRepairTarget(body), let actor = body.physical?.identity
    else { return false }
    guard !state.receipts.contains(where: { $0.target == target }),
      let carrier = commander.hullInstanceID, let revision = commander.equipmentInventory?.revision,
      scriptDurabilityAvailable
    else {
      notify("RELAY ALREADY CALIBRATED OR ORIGINAL STANDARD UNAVAILABLE")
      return true
    }
    interruptFlightTool()
    c01LaneRepairWorkRuntime.review = .init(
      nonce: UUID(), mission: mission.id, revision: mission.revision, target: target,
      actor: actor, carrier: carrier, inventoryRevision: revision, epoch: nativeStationRuntimeEpoch)
    c01LaneRepairWorkRuntime.reason =
      "RETURN ARMS 20s CALIBRATION / ESC CANCELS. Third relay installs the same1t standard; recorder stays aboard."
    return true
  }

  private mutating func confirmC01LaneRepairWork(_ quote: NativeC01LaneRepairReview) throws {
    guard !docked, !paused, screen == .front, energy > 0, !playerEMPDisabled,
      scriptDurabilityAvailable, quote.epoch == nativeStationRuntimeEpoch,
      quote.carrier == commander.hullInstanceID,
      quote.inventoryRevision == commander.equipmentInventory?.revision,
      let player = commander.flightSimulation.player,
      var mission = glassMeridianMission, mission.id == quote.mission,
      mission.revision == quote.revision, mission.revision < UInt64(Int64.max) - 1,
      var opening = mission.savedGlassMeridian, var state = opening.laneRepair,
      state.installation == nil, opening.timingStandard?.held == true,
      opening.surveyor?.held == true, commander.equipmentOwnerID == state.source.owner,
      let actor = c01LaneRepairActor(source: state.source, target: quote.target),
      actor.body.physical?.identity == quote.actor,
      !state.receipts.contains(where: { $0.target == quote.target })
    else { throw SaveError.invalidCommander }
    let arm = NativeC01LaneRepairArm(
      operation: quote.nonce, mission: mission.id, permission: state.source.permission,
      standard: state.source.standard, target: quote.target, actor: quote.actor, player: player,
      owner: state.source.owner, carrier: quote.carrier, inventoryRevision: quote.inventoryRevision,
      epoch: quote.epoch, physicalTime: commander.flightSimulation.physicalTime)
    let index: Int
    if let existing = state.progress.firstIndex(where: { $0.target == quote.target }) {
      index = existing
    } else {
      state.progress.append(.init(target: quote.target))
      index = state.progress.count - 1
    }
    if abs(state.progress[index].seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8 {
      // Retain all measured20s unchanged. A new live arm must attain its own confirmation frame.
      state.progress[index].completionArm = arm
    } else {
      if state.progress[index].segments.last?.intervals == 0 {
        state.progress[index].segments.removeLast()
      }
      guard state.progress[index].segments.count < NativeC01LaneRepair.maximumSegments else {
        throw SaveError.invalidCommander
      }
      state.progress[index].segments.append(.init(arm: arm))
    }
    guard NativeC01LaneRepairSave.shapeValid(state) else { throw SaveError.invalidCommander }
    opening.laneRepair = state
    mission.savedGlassMeridian = opening
    mission.revision += 1
    commander.scriptState.instances[mission.id] = mission
    cancelAutoTarget()
    interruptFlightTool()
    c01LaneRepairWorkRuntime.review = nil
    c01LaneRepairWorkRuntime.arm = NativeC01LaneRepairLiveArm(arm)
    c01LaneRepairWorkRuntime.reason =
      "ARMED: original work face50-150m / relative<=1m/s / aim<=2deg. No standard consumed yet."
  }
}
