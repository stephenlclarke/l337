import Foundation

/// These comparisons validate saved/proposed facts. The caller must also join
/// the actual birth, installed parent stock and current physical source.
enum CurrentOccupiedNewtValidation {
  static func releaseRequest(
    _ request: CurrentNewtPodReleaseRequest, matches stock: CurrentNewtKitStock
  ) -> Bool {
    guard stock.structurallyValid, stock.phase == .actuating, stock.remaining == 1,
      stock.receipt == nil, let actuation = stock.actuation,
      request.issue == stock.issue, request.actuation == actuation,
      request.system == actuation.parent.system, request.visit == actuation.parent.visit,
      request.physicalTime.isFinite, stock.observedAt <= request.physicalTime,
      request.physicalTime == actuation.unlockAt,
      request.physicalTime < actuation.deadline,
      request.parent.structurallyValid, request.pod.structurallyValid,
      request.parentMass.structurallyValid, request.podMass.structurallyValid,
      request.energyJoules.isFinite, request.energyJoules > 0,
      request.remainingCharges.doesNotExceed(stock.charges)
    else { return false }
    return true
  }

  static func receipt(
    _ receipt: CurrentNewtKitReceipt, matches stock: CurrentNewtKitStock
  ) -> Bool {
    stock.structurallyValid && stock.phase == .released && stock.remaining == 0
      && stock.issue == receipt.issue && stock.actuation == receipt.actuation
      && stock.receipt == receipt && stock.charges.doesNotExceed(receipt.remainingCharges)
      && stock.observedAt >= receipt.releasedAt
      && receipt.structurallyValid
  }

  /// Supply each retained parent issue once, including already consumed stock.
  /// The same hardware/person cannot be duplicated in a second source record.
  static func issuesAreUnique(_ issues: [CurrentNewtKitIssue]) -> Bool {
    issues.allSatisfy(\.structurallyValid)
      && Set(issues.map(\.kitID)).count == issues.count
      && Set(issues.map(\.person)).count == issues.count
  }

  static func currentLoad(
    _ load: CurrentNewtKitLoad, body: SpaceBody, record: borrowing EMPHullRecord
  ) -> Bool {
    guard load.structurallyValid, let physical = body.physical,
      let catalogue = physical.catalogueShipID,
      let r3 = OriginalFleetR3Data.contract(for: catalogue),
      let npc = physical.npc, let resources = npc.resources,
      load.catalogueShipID == catalogue, load.r3SHA256 == r3.sourceSHA256,
      load.cargo == npc.ordinaryCargo, load.cargoProvenance == npc.cargoProvenance,
      load.resources == resources, load.missiles == body.missiles,
      load.ecmEnabled == body.ecmEnabled, load.hasFuelScoops == npc.hasFuelScoops,
      let issue = physical.currentNewtKitStock?.issue
    else { return false }
    let aboardOrdinals = record.aboardOrdinals
    let expected = issue.birthLoad.people.filter { aboardOrdinals.contains($0.identity.ordinal) }
    return load.people.count == expected.count
      && load.people.allSatisfy { person in expected.contains(person) }
  }

}
