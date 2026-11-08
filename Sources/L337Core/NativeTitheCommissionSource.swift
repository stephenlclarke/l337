import Foundation

/// Neither Codable nor a memberwise initializer can turn archive DATA into this capability.
final class NativeTitheCommissionContact: Sendable {
  let record: NativeTitheCommissionDeskRecord
  let arrival: NativeMainStationArrivalContext
  let epoch: UUID

  private init(record: NativeTitheCommissionDeskRecord, arrival: NativeMainStationArrivalContext) {
    self.record = record
    self.arrival = arrival
    epoch = arrival.runtimeEpoch
  }
}

enum NativeTitheCommissionContactSource {
  static let unavailable =
    "Voss's original Rakenor desk has no issued native source or contact. A berth, saved record or mission description cannot issue the commission."

  /// Exact source boundary: NativeStationServices supplies a live berth, not a Voss desk.
  /// The pinned story supplies dialogue/warning only. No adopted desk exists in this base.
  static func current(in game: borrowing Game) -> NativeTitheCommissionContact? { nil }

  /// A later source producer must join its genuine issuance history here as well as above.
  /// Matching a claimed UUID, role or station is deliberately insufficient.
  static func recognizesHistorical(
    _ record: NativeTitheCommissionDeskRecord, commander: borrowing Commander
  ) -> Bool { false }
}

extension NativeTitheCommissionHistory {
  /// Choose five real retained observations, including this exact current Rakenor arrival.
  static func acceptanceObservations(in game: borrowing Game,
    at arrival: NativeMainStationArrivalContext) throws -> [NativeMainStationObservation]
  {
    let history = try NativeTitheCommissionHistory.current(in: game)
    guard history.hasRequiredVisitHistory, history.retainedOrdinarySaleCount == requiredOrdinarySales,
      history.atRakenorMainBerth, game.acceptsNativeMainStationArrivalContext(arrival),
      let world = game.commander.nativeStations, world.valid,
      Set(world.mainObservations.map { $0.actor.visit }).count == world.mainObservations.count,
      let current = world.mainObservations.first(where: {
        $0.station == arrival.receipt.station && $0.actor == arrival.receipt.actor
      })
    else { throw SaveError.invalidCommander }
    var result = [current]
    var systems: Set<SystemIdentity> = [current.station.system]
    for observation in world.mainObservations.sorted(by: {
      ($0.station.system.galaxy, $0.station.system.system)
        < ($1.station.system.galaxy, $1.station.system.system)
    }) where result.count < requiredDistinctSystems {
      if systems.insert(observation.station.system).inserted { result.append(observation) }
    }
    guard result.count == requiredDistinctSystems else { throw SaveError.invalidCommander }
    return result.sorted {
      ($0.station.system.galaxy, $0.station.system.system)
        < ($1.station.system.galaxy, $1.station.system.system)
    }
  }
}
