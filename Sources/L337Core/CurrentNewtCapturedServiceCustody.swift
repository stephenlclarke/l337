import Foundation

extension Commander {
  /// Publication and current load use the existing historical people admission,
  /// exact captured pod archive and original kit. A timestamp/charge copy is not custody.
  @inline(never)
  var currentNewtCapturedServiceCustodyValid: Bool {
    withUnsafePointer(to: self) { commander in
      CurrentNewtCapturedServiceCustody.validate(at: commander)
    }
  }
}

/// Each query reads the original live children; this is not a stored custody certificate.
private enum CurrentNewtCapturedServiceCustody {
  @inline(never)
  static func validate(at commander: UnsafePointer<Commander>) -> Bool {
    guard let emp = Commander.nativeCapturedServiceEMP(at: commander) else { return true }
    for record in emp.records.values {
      guard validate(record, at: commander) else { return false }
    }
    return true
  }

  @inline(never)
  private static func validate(_ record: borrowing EMPHullRecord, at commander: UnsafePointer<Commander>) -> Bool {
    guard let stock = record.hull.body.physical?.currentNewtKitStock else { return true }
    guard let receipt = stock.receipt else {
      if stock.serviceCapturedAt != nil { return false }
      return true
    }
    let person = receipt.issue.person
    let admissions = Commander.nativeCapturedServiceAdmissions(person, at: commander)
    guard let index = record.podIndex(for: person.ordinal),
      record.source == person.source, stock.issue == receipt.issue,
      let podActor = record.pods[index].body.physical?.identity,
      record.pods[index].body.physical?.empCrewPod == person,
      record.pods[index].body.physical?.currentNewtKitReceipt == receipt
    else { return false }
    if let capturedAt = stock.serviceCapturedAt {
      guard capturedAt.isFinite, capturedAt >= receipt.releasedAt,
        capturedAt <= stock.observedAt, stock.observedAt <= Commander.nativeCapturedServicePhysicalTime(at: commander),
        record.pods[index].physicalTime == capturedAt, record.pods[index].binding == nil,
        admissions.count == 1, let admission = admissions.first,
        admission.origin == .rescuedPod, admission.actor == podActor,
        admission.physicalTime == capturedAt, !Commander.nativeCapturedServiceWorldOwnedPod(person, at: commander),
        let source = CurrentNewtKitSource.current,
        let service = source.service(receipt, observedAt: capturedAt),
        service.kitID == stock.issue.kitID
      else { return false }
    } else if !admissions.isEmpty { return false }
    return true
  }
}
