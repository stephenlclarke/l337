import Foundation

/// Existing native observations supply only a sufficient lower bound, not all travel history.
/// This fixed mission consumer creates no new visit ledger, station, route or receipt.
enum NativeBorrowedVoiceTravelHistory {
  static let minimumDistinctSystems = 5

  static func current(in game: borrowing Game, at arrival: NativeMainStationArrivalContext) throws
    -> [NativeMainStationObservation]
  {
    let visit = game.commander.flightSimulation.visit
    let calendar = game.commander.scriptState.calendarSeconds
    guard !game.isMissionTrial, game.trialTitle == nil,
      game.acceptsNativeMainStationArrivalContext(arrival),
      game.commander.equipmentStateValid, game.commander.flightSimulation.valid,
      let owner = game.commander.equipmentOwnerID,
      let system = game.commander.flightSimulation.system, system == game.systemIdentity,
      game.commander.flightSimulation.anchors?.system == system,
      game.commander.flightSimulation.anchors?.station.identity.visit == visit,
      game.commander.nativeStationStateValid, let world = game.commander.nativeStations,
      world.valid, world.ledger.world == owner,
      calendar.isFinite, (0...1e12).contains(calendar),
      world.mainObservations.count <= NativeMainStationIdentity.maximumCount,
      Set(world.mainObservations.map(\.actor.visit)).count == world.mainObservations.count,
      world.mainObservations.allSatisfy({ $0.valid && $0.station.world == owner
        && $0.actor.visit <= visit && $0.calendarSeconds <= calendar }),
      let current = world.mainObservations.first(where: {
        $0.station == arrival.receipt.station && $0.actor == arrival.receipt.actor
      })
    else { throw SaveError.invalidCommander }
    var selected = [current]
    var systems: Set<SystemIdentity> = [current.station.system]
    let observations = world.mainObservations.sorted {
      ($0.station.system.galaxy, $0.station.system.system)
        < ($1.station.system.galaxy, $1.station.system.system)
    }
    for observation in observations where selected.count < minimumDistinctSystems {
      if systems.insert(observation.station.system).inserted { selected.append(observation) }
    }
    guard selected.count == minimumDistinctSystems else {
      throw MissionPackError("Five distinct visited systems cannot yet be verified from retained native history.")
    }
    return selected.sorted {
      ($0.station.system.galaxy, $0.station.system.system)
        < ($1.station.system.galaxy, $1.station.system.system)
    }
  }

  /// A revisit replaces the latest live station observation. Saved acceptance is history,
  /// so later observations need not equal its old actor. Use the existing historical joins.
  static func historical(_ facts: borrowing NativeBorrowedVoiceAcceptanceFacts,
    commander: borrowing Commander) -> Bool
  {
    guard facts.shapeValid, let world = commander.nativeStations,
      facts.owner == commander.equipmentOwnerID,
      facts.physicalTime <= commander.flightSimulation.physicalTime,
      facts.calendarSeconds <= commander.scriptState.calendarSeconds
    else { return false }
    let visit = commander.flightSimulation.visit
    let observations = facts.visited
    return observations.allSatisfy {
      world.mainStations.contains($0.station) && $0.actor.visit <= visit
    }
  }
}
