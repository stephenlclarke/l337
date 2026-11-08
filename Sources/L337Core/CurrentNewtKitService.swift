import Foundation

/// A projection at an actual free-pod/archive/capture clock. It is not saved as
/// replacement custody and cannot change the immutable unlock receipt.
struct CurrentNewtKitServiceObservation: Sendable {
  let kitID: UUID
  let observedAt: Double
  let electricalJoules: Double
  let oxygenKilograms: Double
  let sorbentCapacityKilogramsCO2: Double
  let exhausted: Bool
}

extension CurrentNewtKitSource {
  func service(_ receipt: CurrentNewtKitReceipt, observedAt time: Double)
    -> CurrentNewtKitServiceObservation?
  {
    guard matches(receipt), time.isFinite, time >= receipt.releasedAt else { return nil }
    let elapsed = time - receipt.releasedAt
    let electrical = max(0, receipt.remainingCharges.electricalJoules - continuousPowerWatts * elapsed)
    let oxygen = max(0, receipt.remainingCharges.oxygenKilograms - oxygenKgPerSecond * elapsed)
    let sorbent = max(0, receipt.remainingCharges.sorbentCapacityKilogramsCO2
      - carbonDioxideKgPerSecond * elapsed)
    guard [electrical, oxygen, sorbent].allSatisfy(\.isFinite) else { return nil }
    return .init(kitID: receipt.issue.kitID, observedAt: time,
      electricalJoules: electrical, oxygenKilograms: oxygen,
      sorbentCapacityKilogramsCO2: sorbent,
      exhausted: electrical == 0 || oxygen == 0 || sorbent == 0)
  }
}
