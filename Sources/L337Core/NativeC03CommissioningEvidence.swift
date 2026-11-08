import Foundation

/// Fresh input to the original Toren commission. Only actual acceptance and its writer may
/// install the resulting birth. The evidence and the prepared birth authorize no actors.
struct NativeC03CommissioningEvidence: Equatable, Sendable {
  let arrival: NativeMainStationArrivalContext
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let sale: NativeFirstCommoditySale
  let physicalTime: Double

  private init(
    arrival: NativeMainStationArrivalContext, owner: UUID, carrier: UUID,
    inventoryRevision: UInt64, sale: NativeFirstCommoditySale, physicalTime: Double
  ) {
    self.arrival = arrival
    self.owner = owner
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
    self.sale = sale
    self.physicalTime = physicalTime
  }

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("hollow-manifest-commission-v1:\(owner)")
  }

  static func operation(owner: UUID, mission: UUID, dock: NativeMainStationDockReceipt) -> UUID {
    ScriptIdentity.uuid("hollow-manifest-contact-v1:\(owner):\(mission):\(dock.sequence)")
  }

  static func current(in game: borrowing Game) -> Self? {
    guard !game.isMissionTrial, game.trialTitle == nil,
      game.systemIdentity == NativeHollowManifestDefinition.issuer,
      let dock = game.commander.nativeStations?.currentMainDock,
      let arrival = game.nativeMainStationArrivalContext(for: dock.station),
      game.commander.flightSimulation.valid, game.commander.equipmentStateValid,
      let inventory = game.commander.equipmentInventory,
      inventory.owner == arrival.receipt.commanderOwner,
      inventory.owner == game.commander.equipmentOwnerID,
      inventory.activeHull == game.commander.hullInstanceID,
      let sale = game.commander.scriptState.firstNativeCommoditySale,
      NativeFirstCommoditySaleSave.validateClaims(game.commander),
      sale.dock.sequence <= dock.sequence, sale.dock.actor.visit <= dock.actor.visit,
      sale.dock.calendarSeconds <= dock.calendarSeconds
    else { return nil }
    return .init(
      arrival: arrival, owner: inventory.owner, carrier: inventory.activeHull,
      inventoryRevision: inventory.revision, sale: sale,
      physicalTime: game.commander.flightSimulation.physicalTime)
  }

  /// Prepare the existing reviewed birth without modifying the game. Confirm must separately
  /// enforce the actual contact review, installed pack, unaccepted case and atomic publication.
  func prepareBirth(in game: borrowing Game) throws -> NativeHollowManifestSourceBirth {
    guard Self.current(in: game) == self else { throw SaveError.invalidCommander }
    let mission = Self.mission(owner: owner)
    return try .preparing(.init(
      mission: mission, owner: owner,
      commission: Self.operation(owner: owner, mission: mission, dock: arrival.receipt),
      carrier: carrier, inventoryRevision: inventoryRevision, dock: arrival.receipt,
      sale: sale, physicalTime: physicalTime, firstSourceSequence: 1))
  }
}
