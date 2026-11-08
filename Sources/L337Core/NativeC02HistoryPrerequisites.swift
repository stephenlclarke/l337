import Foundation

enum NativeC02HistoryPrerequisites {
  static let authoredCommit = "c70110b292077588a0855fb48127adfb1b611c9d"
  static let authoredDefinitionSHA256 = "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60"
  static let logicalSourceID = "l337.quiet-choir"
  static let minimumDistinctSystems = 4
}

/// Actual travel/identification history only. This is NOT Captain Holt, a contact, a paid
/// entitlement, mission approval, birth, native source, current sighting or acceptance right.
/// It is never saved and cannot be constructed from caller counts, catalogue art or names.
final class NativeC02HistoryReview: Sendable {
  let owner: UUID
  let visited: [NativeMainStationIdentity]
  let identification: FleetDiscoveryEvidence?
  private let snapshot: CommanderSnapshot
  private let epoch: UUID

  private init(game: borrowing Game, owner: UUID, visited: [NativeMainStationIdentity],
    identification: FleetDiscoveryEvidence?)
  {
    self.owner = owner
    self.visited = visited
    self.identification = identification
    snapshot = CommanderSnapshot(game.commander)
    epoch = game.nativeStationRuntimeEpoch
  }

  var distinctSystems: Int { Set(visited.map(\.system)).count }
  var historyRequirementsMet: Bool {
    distinctSystems >= NativeC02HistoryPrerequisites.minimumDistinctSystems && identification != nil
  }
  var issues: [String] {
    var values: [String] = []
    if distinctSystems < NativeC02HistoryPrerequisites.minimumDistinctSystems {
      values.append("Visit four different systems before reviewing Holt's investigation.")
    }
    if identification == nil {
      values.append("Identify a real Larvaal vessel with Identification targeting.")
    }
    return values
  }

  func isCurrent(in game: borrowing Game) -> Bool {
    guard !game.isMissionTrial, game.trialTitle == nil else { return false }
    guard epoch == game.nativeStationRuntimeEpoch else { return false }
    return snapshot.value == game.commander
  }

  @inline(never)
  static func current(in game: borrowing Game) throws -> NativeC02HistoryReview {
    guard !game.isMissionTrial, game.trialTitle == nil,
      let owner = game.commander.equipmentOwnerID,
      game.commander.flightSimulation.valid,
      game.commander.nativeStationStateValid,
      NativeFleetDiscoverySave.validateClaims(game.commander),
      let world = game.commander.nativeStations, world.valid,
      world.ledger.world == owner
    else { throw SaveError.invalidCommander }
    // These registrations are made by actual native system entry. Repeated launches or
    // returns to the same system do not create more distinct destinations. Map coordinates,
    // a visit counter and station names alone never enter this history.
    let visited = world.mainStations.sorted {
      ($0.system.galaxy, $0.system.system) < ($1.system.galaxy, $1.system.system)
    }
    var qualifying: [FleetDiscoveryEvidence] = []
    if let discovery = game.commander.scriptState.savedFleetDiscovery {
      guard discovery.owner == owner else { throw SaveError.invalidCommander }
      for entry in discovery.entries.values {
        guard let proof = entry.identification,
          let catalogue = ShipCatalogue.ship(proof.ship)?.catalogue,
          catalogue.objectKind == .ship, catalogue.origin == .alien,
          catalogue.family.hasPrefix("larvaal-"), proof.owner == owner,
          proof.kind == .identification, proof.valid else { continue }
        qualifying.append(proof)
      }
    }
    let identified = qualifying.sorted {
      ($0.physicalTime, $0.ship) < ($1.physicalTime, $1.ship)
    }.first
    return .init(game: game, owner: owner, visited: visited, identification: identified)
  }
}

extension Game {
  func quietChoirHistoryReview() throws -> NativeC02HistoryReview {
    try NativeC02HistoryReview.current(in: self)
  }
}
