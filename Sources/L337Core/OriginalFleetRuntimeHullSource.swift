import Foundation

/// Immutable current mechanics and calibrated collision geometry, retained outside frame loops.
/// This resolves existing admitted sources; it grants no population, purchase, crew or mass loading.
enum OriginalFleetRuntimeHullSource {
  struct Source: Sendable {
    let ship: CatalogueShip
    let contract: OriginalFleetR3Contract
    let mesh: Mesh
    let envelope: OriginalHullEnvelope
    let engineering: OriginalFleetPhysicalRecord?

    var performance: ShipPerformance { contract.performance! }

    func permitsAmbientTrader(context: borrowing EncounterContext, position: Vector3) -> Bool {
      permitsAmbient(role: .trader, context: context, position: position)
    }

    func permitsAmbient(
      role: ShipCatalogueRole, context: borrowing EncounterContext, position: Vector3
    ) -> Bool {
      guard ship.catalogue.readyForNaturalEncounters,
        ship.catalogue.encounterWeight(for: role) > 0,
        ship.catalogue.galaxies.contains(context.system.galaxy),
        ship.catalogue.regions.contains(
          EncounterGeography.region(at: context.player.position, anchors: context.anchors)),
        ship.catalogue.regions.contains(
          EncounterGeography.region(at: position, anchors: context.anchors)),
        // EncounterContext carries no live technology evidence for habitat-bound sources.
        ship.catalogue.habitat == nil
      else { return false }
      return true
    }
  }

  private static let sources: [String: Source] = Dictionary(
    uniqueKeysWithValues: ShipCatalogue.all.compactMap { ship -> (String, Source)? in
      guard !OriginalDetailedHullStage.blocksRuntime(ship.id),
        let current = OriginalFleetR3Data.contract(for: ship.id), current.objectKind == .ship,
        current.name == ship.name, current.family == ship.catalogue.family,
        current.origin.catalogueOrigin == ship.catalogue.origin,
        let performance = current.performance, performance == ship.game,
        (try? ShipAccommodationProfile(ship: ship)) != nil,
        let mesh = ShipCatalogue.rawMesh(ship.id),
        mesh.faces.reduce(0, { $0 + max(0, $1.count - 2) }) <= 512,
        let envelope = try? OriginalHullEnvelope(vertices: mesh.vertices)
      else { return nil }
      let physical = ship.physicalSourceContract
      if OriginalFleetPhysicalData.registrations[ship.id] != nil && physical?.engineering == nil {
        return nil
      }
      return (ship.id, .init(
        ship: ship, contract: current, mesh: mesh, envelope: envelope,
        engineering: physical?.engineering))
    })

  static func source(for id: String) -> Source? { sources[id] }

  /// Consume an existing draw and declared role weights; unavailable roles produce no actor.
  static func naturalSource(
    role: ShipCatalogueRole, context: borrowing EncounterContext, positions: [Vector3], draw: UInt64
  ) -> Source? {
    guard role == .pirate || role == .miner, !positions.isEmpty else { return nil }
    var pool: [(Source, Int)] = []
    var total = 0
    for id in sources.keys.sorted() {
      guard let source = sources[id] else { continue }
      var permitsEveryPosition = true
      for position in positions {
        if !source.permitsAmbient(role: role, context: context, position: position) {
          permitsEveryPosition = false
          break
        }
      }
      guard permitsEveryPosition else { continue }
      let weight = source.ship.catalogue.encounterWeight(for: role)
      let (next, overflow) = total.addingReportingOverflow(weight)
      guard weight > 0, !overflow else { return nil }
      pool.append((source, weight))
      total = next
    }
    guard total > 0 else { return nil }
    var choice = draw % UInt64(total)
    for (source, weight) in pool {
      if choice < UInt64(weight) { return source }
      choice -= UInt64(weight)
    }
    return nil
  }

  static func matchesAmbientNonTrader(
    _ request: borrowing SpawnRequest, context: borrowing EncounterContext
  ) -> Bool {
    guard request.identity.producer == .ambient, let npc = request.npc,
      npc.role == .pirate || npc.role == .miner
    else { return true }
    let role: ShipCatalogueRole = npc.role == .pirate ? .pirate : .miner
    guard let id = request.catalogueShipID, let source = source(for: id),
      request.hull == (npc.role == .pirate ? .sidewinder : .cobra),
      request.population == (npc.role == .pirate ? .pirate : .civilian),
      request.priority == .ordinary,
      npc.legalProvenance == .generated, npc.cargoProvenance == .generated,
      npc.routeProvenance == .generated, request.energy == nil,
      request.rock == nil, request.payload == nil,
      source.permitsAmbient(role: role, context: context, position: request.position),
      let stock = NPCResources.stock(source.performance)
    else { return false }
    return npc.resources == stock
  }

  /// Ambient stock is produced from the same current contract used by its mesh and flight rates.
  /// Persisted, mission and EMP actors retain their distinct source owners.
  static func matchesAmbientTrader(
    _ request: borrowing SpawnRequest, context: borrowing EncounterContext
  ) -> Bool {
    guard request.identity.producer == .ambient, request.npc?.role == .trader
    else { return true }
    guard let id = request.catalogueShipID else { return false }
    guard !OriginalBisonActivation.contains(id) else { return true }
    guard let source = source(for: id), request.hull == .cobra,
      request.population == .civilian, request.priority == .ordinary,
      let npc = request.npc, npc.role == .trader,
      npc.legalProvenance == .generated, npc.cargoProvenance == .generated,
      npc.routeProvenance == .generated, request.energy == nil,
      request.rock == nil, request.payload == nil,
      source.permitsAmbientTrader(context: context, position: request.position),
      let stock = NPCResources.stock(source.performance)
    else { return false }
    return npc.resources == stock
  }
}
