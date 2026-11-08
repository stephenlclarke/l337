import Foundation

extension CurrentNewtKitSource {
  /// Reconstruct the historical source boundary; agreeing saved copies do not
  /// prove that their pose, tensor, work or remaining charge is physically possible.
  func matches(_ request: CurrentNewtPodReleaseRequest, liveParent: State) -> Bool {
    guard request.physicalTime == request.actuation.unlockAt,
      request.system == request.actuation.parent.system,
      request.visit == request.actuation.parent.visit,
      let expected = occupiedUnlockMotion(issue: request.issue, actuation: request.actuation,
        loadAtRelease: request.loadAtRelease),
      matchesState(liveParent, expected.parent)
    else { return false }
    return matchesUnlockFacts(parent: request.parent, pod: request.pod,
      parentMass: request.parentMass, podMass: request.podMass,
      energyJoules: request.energyJoules, charges: request.remainingCharges, expected: expected)
  }

  func matches(_ receipt: CurrentNewtKitReceipt, observedAt time: Double) -> Bool {
    guard receipt.structurallyValid, time.isFinite, time >= receipt.releasedAt,
      receipt.releasedAt == receipt.actuation.unlockAt,
      let expected = occupiedUnlockMotion(issue: receipt.issue, actuation: receipt.actuation,
        loadAtRelease: receipt.loadAtRelease)
    else { return false }
    return matchesUnlockFacts(parent: receipt.parent, pod: receipt.pod,
      parentMass: receipt.parentMass, podMass: receipt.podMass,
      energyJoules: receipt.energyJoules, charges: receipt.remainingCharges, expected: expected)
  }

  /// Source callers which validate a historical receipt without a later service
  /// observation use its own immutable handoff time.
  func matches(_ receipt: CurrentNewtKitReceipt) -> Bool {
    matches(receipt, observedAt: receipt.releasedAt)
  }

  /// Attached travel has a source clock; later independent powered work does not.
  /// A valid charge balance alone cannot move the rack ahead of its actual time.
  func matchesAttachedObservation(
    stock: CurrentNewtKitStock, state: State, at time: Double
  ) -> Bool {
    guard stock.phase == .actuating, stock.interruptedAt == nil,
      stock.observedAt == time, let actuation = stock.actuation,
      time <= actuation.unlockAt, matches(stock, at: time),
      stock.work == work(at: time, actuation: actuation),
      let expected = motion(actuation, at: time)
    else { return false }
    return matchesState(state, expected.parent)
  }

  func matchesState(_ actual: State, _ expected: State) -> Bool {
    guard actual.structurallyValid, expected.structurallyValid else { return false }
    let positionScale = max(1, max(actual.pose.position.length, expected.pose.position.length))
    let positionTolerance = max(1e-9, 128 * Double.ulpOfOne * positionScale)
    return (actual.pose.position - expected.pose.position).length <= positionTolerance
      && (actual.pose.orientation.x - expected.pose.orientation.x).length <= 1e-9
      && (actual.pose.orientation.y - expected.pose.orientation.y).length <= 1e-9
      && (actual.pose.orientation.z - expected.pose.orientation.z).length <= 1e-9
      && (actual.velocity - expected.velocity).length <= 1e-8
      && (actual.angularVelocity - expected.angularVelocity).length <= 1e-10
  }

  private func occupiedUnlockMotion(
    issue: CurrentNewtKitIssue, actuation: CurrentNewtKitStock.Actuation,
    loadAtRelease: CurrentNewtKitLoad
  ) -> Motion? {
    guard matches(issue), matches(actuation, issue: issue),
      let model = loadModel, model.matches(actuation.load, selectedPerson: issue.person),
      loadAtRelease.samePhysicalInventory(as: actuation.load),
      let expected = motion(actuation, at: actuation.unlockAt)
    else { return nil }
    return expected
  }

  private func matchesUnlockFacts(
    parent: State, pod: State, parentMass: Mass, podMass: Mass,
    energyJoules: Double, charges: CurrentNewtKitStock.Charges, expected: Motion
  ) -> Bool {
    matchesState(parent, expected.parent) && matchesState(pod, expected.pod)
      && matchesMass(parentMass, expected.parentMass) && matchesMass(podMass, expected.podMass)
      && energyJoules.isFinite && energyJoules > 0
      && abs(energyJoules - expected.workJoules) <= 1e-6
      && matchesCharges(charges, expected.charges)
  }
}
