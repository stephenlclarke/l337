import Foundation

/// Read-only finite observation of cells commissioned at actual configured birth.
/// Exhaustion is reported; it does not invent a death, transfer or custody event.
struct CurrentNewtCarrierCellObservation: Sendable {
  let kitID: UUID
  let observedAt: Double
  let componentID: String
  let originalOccupant: EMPCrewIdentity?
  let electricalJoules: Double
  let oxygenKilograms: Double
  let sorbentCapacityKilogramsCO2: Double
  let commissionedPressurePascals: Double
  let commissionedTemperatureKelvin: Double
  let transferSealClosed: Bool
  let exhausted: Bool
}

extension CurrentNewtKitSource {
  func carrierCells(issue: CurrentNewtKitIssue, load: CurrentNewtKitLoad, at time: Double)
    -> [CurrentNewtCarrierCellObservation]? {
    guard matches(issue), let service = carrierCellService, let cells = issue.carrierCells,
      time.isFinite, time >= issue.issuedAt, loadModel?.matchesInventory(load) == true,
      load.people.allSatisfy({ issue.birthLoad.people.contains($0) }),
      cells.count == originalNativeCrew else { return nil }
    let elapsed = time - issue.issuedAt
    return cells.enumerated().map { ordinal, cell in
      let electrical = max(0, cell.electricalJoules - service.continuousWatts * elapsed)
      let oxygen = max(0, cell.oxygenKilograms - service.oxygenKgPerSecond * elapsed)
      let sorbent = max(0, cell.sorbentCapacityKilogramsCO2 - service.carbonDioxideKgPerSecond * elapsed)
      // The selected person is in the sole Newt from birth. Their ordinary cell
      // remains commissioned, charged and empty; it is not a second escape pod.
      let person = ordinal == selectedPersonOrdinal ? nil : load.people.first {
        $0.identity.ordinal == ordinal
      }?.identity
      return .init(kitID: issue.kitID, observedAt: time, componentID: cell.componentID,
        originalOccupant: person, electricalJoules: electrical, oxygenKilograms: oxygen,
        sorbentCapacityKilogramsCO2: sorbent, commissionedPressurePascals: cell.pressurePascals,
        commissionedTemperatureKelvin: cell.temperatureKelvin, transferSealClosed: cell.transferSealClosed,
        exhausted: electrical == 0 || oxygen == 0 || sorbent == 0)
    }
  }
}
