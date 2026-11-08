import Foundation

/// New station deployment policy; catalogue role and ambient placement stay unchanged.
enum StationPoliceSource {
  static let catalogueID = "SH031"

  static func current() -> (source: OriginalFleetRuntimeHullSource.Source, stock: NPCResources)? {
    guard let source = OriginalFleetRuntimeHullSource.source(for: catalogueID),
      source.ship.nativeHull == .viper, ShipCatalogue.nativeShip(.viper)?.id == catalogueID,
      let stock = NPCResources.stock(source.performance), stock.valid
    else { return nil }
    return (source, stock)
  }

  static func matchesFresh(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard let current = current(), request.identity.producer == .security,
      request.identity.system == context.system, request.identity.visit == context.visit,
      request.population == .police, request.priority == .police,
      request.hull == current.source.ship.nativeHull, request.catalogueShipID == catalogueID,
      request.recoveredSecuritySource == nil, request.energy == nil,
      request.rock == nil, request.payload == nil, request.salvage == nil,
      request.angularVelocity == .init(0, 0, 0)
    else { return false }
    let npc = NPCState(
      role: .police, origin: context.system, destination: context.system,
      legalProvenance: .generated, cargoProvenance: .generated,
      routeProvenance: .generated, resources: current.stock)
    return request.npc == npc
  }

  /// EMP custody requires an explicit current source and its declared native binding.
  static func empCatalogueID(for body: SpaceBody) -> String? {
    guard let id = body.physical?.catalogueShipID,
      let current = OriginalFleetRuntimeHullSource.source(for: id),
      current.ship.nativeHull == nil || current.ship.nativeHull == body.hull
    else { return nil }
    return id
  }
}

extension Game {
  func securitySpawnSourceIsValid(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard request.identity.producer == .security else { return request.recoveredSecuritySource == nil }
    guard request.population == .police, request.npc?.role == .police,
      request.identity.system == context.system, request.identity.visit == context.visit,
      request.priority == .police
    else { return false }
    if let source = request.recoveredSecuritySource {
      return matchesRecoveredPolice(request, source: source, context: context)
    }
    return StationPoliceSource.matchesFresh(request, context: context)
      && commander.stationSecurity.ownsPendingLaunch(request, context: context)
  }

  private func matchesRecoveredPolice(
    _ request: SpawnRequest, source: ActorIdentity, context: EncounterContext
  ) -> Bool {
    guard source.system == context.system, request.identity.member == 0,
      let record = commander.nativeEMPCustodyRecord(for: source),
      record.isRecovered, !record.terminal, record.custody.kind == .police,
      record.hull.binding == nil, record.savedOrdinaryTerminal == nil,
      record.activeTrafficTransfer == nil, commander.npcPersistence.snapshot(for: source) == nil,
      record.hull.physicalTime <= context.physicalTime,
      let physical = record.hull.body.physical, let npc = physical.npc,
      npc.role == .police, physical.population == .police,
      let id = physical.catalogueShipID,
      record.custody.original.body.physical?.catalogueShipID == id,
      let current = OriginalFleetRuntimeHullSource.source(for: id),
      current.ship.nativeHull == record.hull.body.hull
    else { return false }
    let body = record.hull.body
    let condition = NPCPersistenceSnapshot(
      actor: physical.identity, population: physical.population, hull: body.hull,
      position: body.position, orientation: body.orientation,
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      rotation: body.rotation, rotationRate: body.rotationRate,
      energy: body.energy, missiles: body.missiles, ecmEnabled: body.ecmEnabled,
      hostile: body.hostile, laserCooldown: physical.laserCooldown,
      catalogueShipID: id, npc: npc, physicalTime: record.hull.physicalTime)
    guard condition.valid else { return false }
    let expected = SpawnRequest(
      identity: request.identity, population: .police, hull: body.hull,
      position: body.position, orientation: body.orientation, velocity: physical.velocity,
      npc: npc, rock: nil, payload: nil, priority: .police, catalogueShipID: id,
      energy: body.energy, angularVelocity: physical.angularVelocity,
      recoveredSecuritySource: source)
    return request == expected
  }
}
