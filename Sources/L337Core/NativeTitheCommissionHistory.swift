import Foundation

/// Retained native evidence for the original Tithe offer. Reading history grants no commission.
struct NativeTitheCommissionHistory: Equatable, Sendable {
  static let requiredDistinctSystems = 5
  static let requiredOrdinarySales = 2

  let visitedSystems: Set<SystemIdentity>
  let firstSale: NativeFirstCommoditySale?
  let secondSale: NativeSecondCommoditySale?
  let atRakenorMainBerth: Bool

  var hasRequiredVisitHistory: Bool { visitedSystems.count >= Self.requiredDistinctSystems }

  var retainedOrdinarySaleCount: Int {
    guard firstSale != nil else { return 0 }
    return secondSale == nil ? 1 : 2
  }

  private init(
    visitedSystems: Set<SystemIdentity>, firstSale: NativeFirstCommoditySale?,
    secondSale: NativeSecondCommoditySale?, atRakenorMainBerth: Bool
  ) {
    self.visitedSystems = visitedSystems
    self.firstSale = firstSale
    self.secondSale = secondSale
    self.atRakenorMainBerth = atRakenorMainBerth
  }

  static func current(in game: borrowing Game) throws -> Self {
    guard !game.isMissionTrial, game.trialTitle == nil,
      let owner = game.commander.equipmentOwnerID,
      game.commander.flightSimulation.valid, game.commander.nativeStationStateValid,
      let world = game.commander.nativeStations, world.ledger.world == owner,
      NativeFirstCommoditySaleSave.validateClaims(game.commander),
      NativeSecondCommoditySaleSave.validateClaims(game.commander)
    else { throw SaveError.invalidCommander }

    let visit = game.commander.flightSimulation.visit
    let calendar = game.commander.scriptState.calendarSeconds
    let observations = world.mainObservations
    guard observations.count <= NativeMainStationIdentity.maximumCount,
      observations.allSatisfy({
        $0.valid && $0.station.world == owner && $0.actor.visit <= visit
          && $0.calendarSeconds <= calendar
      })
    else { throw SaveError.invalidCommander }

    return .init(
      visitedSystems: Set(observations.map(\.station.system)),
      firstSale: game.commander.scriptState.firstNativeCommoditySale,
      secondSale: game.commander.scriptState.secondNativeCommoditySale,
      atRakenorMainBerth: isAtRakenorMainBerth(in: game))
  }

  private static func isAtRakenorMainBerth(in game: borrowing Game) -> Bool {
    guard game.systemIdentity == SystemIdentity(galaxy: 6, system: 105) else { return false }
    return game.nativeMainStationDockEvidenceIsCurrent
  }
}
