import Foundation

/// Current r3 inputs are separate from the older staged fleet definitions.
/// This adapter grants no blueprint, owned hull, crew or carried equipment.
enum OriginalBisonActivation {
  enum Failure: Error { case invalidSource }

  struct Source: Sendable {
    let ship: CatalogueShip
    let game: ShipPerformance
    let minimumTechnology: Int
    let profileID: String
    let requiredCrewIncludingCommander: Int
    let intrinsicCrewPlaces: Int
    let equipmentUnits: Int
    let sourceSHA256: String

    fileprivate init(ship: CatalogueShip, registration: Registration) {
      self.ship = ship
      game = registration.game
      minimumTechnology = registration.minimumTechnology
      profileID = registration.profileID
      requiredCrewIncludingCommander = registration.crew
      intrinsicCrewPlaces = registration.crew
      equipmentUnits = registration.equipmentUnits
      sourceSHA256 = registration.sourceSHA256
    }
  }

  fileprivate struct Registration: Sendable {
    let id: String
    let name: String
    let profileID: String
    let sourceSHA256: String
    let minimumTechnology: Int
    let crew: Int
    let equipmentUnits: Int
    let game: ShipPerformance
  }

  private static let markI = registered(
    "SH005", resourceSHA256: "a1592e007d95c8608f5bcc893d3ecf450fa94e9b4437d15f5fddc593f4d6e9fb",
    minimumTechnology: 9)
  private static let markII = registered(
    "SH006", resourceSHA256: "1fcf843a53ef11d4b0f6c503219cebfebf81ef6b97051a9b395ddbd4acec46c8",
    minimumTechnology: 11)

  private static func registered(
    _ id: String, resourceSHA256: String, minimumTechnology: Int
  ) -> Registration {
    guard let contract = OriginalFleetR3Data.contract(for: id), contract.family == "bison",
      contract.playerFlyable, contract.purchasePolicy == .blueprintFabrication,
      contract.acquisition?.requiresPhysicalIntake == true,
      let game = contract.performance, let crew = contract.accommodation,
      let fitting = contract.fitting, !fitting.roleKitIncluded,
      crew.initialPurchasedCabins == 0, crew.operatingCrew == crew.intrinsicCrewPlaces
    else { preconditionFailure("The Bison R3 contract is incomplete") }
    return .init(
      id: id, name: contract.name, profileID: "PROJECT-BISON-R3-" + id,
      sourceSHA256: resourceSHA256, minimumTechnology: minimumTechnology,
      crew: crew.operatingCrew, equipmentUnits: fitting.equipmentUnits, game: game)
  }

  static func contains(_ id: String) -> Bool { id == "SH005" || id == "SH006" }

  private static func registration(for id: String) -> Registration? {
    switch id {
    case "SH005": markI
    case "SH006": markII
    default: nil
    }
  }

  /// Called by the loader with the digest of the bytes it actually decoded.
  /// No catalogue lookup or mesh cache may run during catalogue construction.
  static func resolve(_ retained: CatalogueShip, resourceSHA256: String) throws -> CatalogueShip {
    guard let expected = registration(for: retained.id),
      resourceSHA256 == expected.sourceSHA256, matchesCore(retained, expected: expected),
      retained.catalogue.mechanicsStatus == .pending,
      retained.catalogue.purchasePolicy == .pendingFabrication,
      !retained.catalogue.normalPurchaseEligible
    else { throw Failure.invalidSource }
    return CatalogueShip(
      id: retained.id, name: retained.name, shipClass: retained.shipClass,
      appearances: retained.appearances, evidence: retained.evidence, refit: retained.refit,
      model: retained.model, modelSource: retained.modelSource, dimensions: retained.dimensions,
      geometryContext: retained.geometryContext, profiles: retained.profiles, game: retained.game,
      catalogue: deliveredMetadata(retained.catalogue, source: expected), design: retained.design,
      nativeHull: retained.nativeHull, nativeDesign: retained.nativeDesign,
      nativeCombat: retained.nativeCombat)
  }

  /// Runtime callers receive the canonical value from the authenticated loader.
  /// A ready flag or an arbitrary caller-supplied CatalogueShip cannot create this value.
  static func source(for id: String) -> Source? {
    guard let expected = registration(for: id), let ship = ShipCatalogue.ship(id),
      matchesCore(ship, expected: expected), ship.catalogue.mechanicsStatus == .ready,
      ship.catalogue.purchasePolicy == .blueprintFabrication,
      ship.catalogue.normalPurchaseEligible
    else { return nil }
    return .init(ship: ship, registration: expected)
  }

  private static func matchesCore(_ ship: CatalogueShip, expected: Registration) -> Bool {
    let metadata = ship.catalogue
    guard ship.id == expected.id, ship.name == expected.name, ship.game == expected.game,
      ship.nativeHull == nil, ship.nativeCombat == nil, ship.nativeDesign != nil,
      metadata.family == "bison", metadata.objectKind == .ship, metadata.origin == .human,
      metadata.primaryType == .transporter, metadata.primaryRole == .transporter,
      metadata.roleWeights.count == 1, metadata.roleWeights[0].role == .transporter,
      metadata.roleWeights[0].weight == 4, metadata.access == .normal, metadata.playerFlyable,
      metadata.minimumBuildTechLevel == expected.minimumTechnology, !metadata.isCapital,
      metadata.collectionMilestone == .blueprintAndFabrication,
      metadata.damagePolicy == .destructible, metadata.discoveryEligible,
      metadata.encounterMode == .natural, metadata.placementStatus == .declared,
      metadata.rarity == .uncommon, metadata.galaxies == [0, 6, 7],
      metadata.regions == [.tradeLane, .deepSpace], ship.profiles.count == 1,
      let profile = ship.profiles.first, profile.id == expected.profileID,
      profile.group == "project-refit-v1"
    else { return false }
    let fields = profile.fields
    guard Set(fields.map(\.key)).count == fields.count else { return false }
    func number(_ key: String) -> Double? { fields.first { $0.key == key }?.number }
    return number("required_crew_including_commander") == Double(expected.crew)
      && number("reserved_crew_accommodation") == Double(expected.crew)
      && number("equipment_capacity_units") == Double(expected.equipmentUnits)
      && number("cargo_tonnes") == Double(expected.game.cargo)
      && number("usable_cargo_after_fit") == Double(expected.game.cargo)
      && number("initial_charter_passenger_berths") == 0
      && number("fitted_passenger_berths") == 0 && number("passengers_aboard") == 0
      && number("free_passenger_places") == 0 && number("hold_used_by_cabins") == 0
  }

  private static func deliveredMetadata(
    _ old: ShipCatalogueMetadata, source: Registration
  ) -> ShipCatalogueMetadata {
    .init(
      schemaVersion: old.schemaVersion, family: old.family, aliases: old.aliases,
      objectKind: old.objectKind, origin: old.origin, primaryType: old.primaryType,
      primaryRole: old.primaryRole, roleWeights: old.roleWeights, access: old.access,
      playerFlyable: old.playerFlyable, normalPurchaseEligible: true,
      purchasePolicy: .blueprintFabrication, minimumBuildTechLevel: old.minimumBuildTechLevel,
      isCapital: old.isCapital, capitalSubtype: old.capitalSubtype,
      collectionMilestone: old.collectionMilestone, damagePolicy: old.damagePolicy,
      habitat: old.habitat, discoveryEligible: old.discoveryEligible,
      encounterMode: old.encounterMode, mechanicsStatus: .ready,
      placementStatus: old.placementStatus, rarity: old.rarity, galaxies: old.galaxies,
      regions: old.regions, authoredSystems: old.authoredSystems,
      basis: source.id + " current adopted r3 source " + source.sourceSHA256
        + ". Natural transporter admission retains declared galaxies, regions and weights. "
        + "Fabrication requires a same-ID paid EMP, empty-section cut and physical sample receipt, a current living "
        + "main-station provider and paid exchange. Capacity grants no carried items or crew.")
  }

  static func naturalSources(
    context: borrowing EncounterContext, position: Vector3, decisionRegion: EncounterRegion
  ) -> [Source] {
    var sources: [Source] = []
    let region = EncounterGeography.region(at: position, anchors: context.anchors)
    for id in ["SH005", "SH006"] {
      guard let candidate = source(for: id), candidate.ship.catalogue.readyForNaturalEncounters,
        candidate.ship.catalogue.galaxies.contains(context.system.galaxy),
        candidate.ship.catalogue.regions.contains(decisionRegion),
        candidate.ship.catalogue.regions.contains(region)
      else { continue }
      sources.append(candidate)
    }
    return sources
  }

  /// Birth requires stock. Persistence retains actual damaged/partly spent readings.
  /// Other native producers keep their existing admission owners and policies.
  static func matchesRequest(
    _ request: borrowing SpawnRequest, context: borrowing EncounterContext
  ) -> Bool {
    guard let id = request.catalogueShipID, contains(id) else { return true }
    guard let source = source(for: id) else { return false }
    let producer = request.identity.producer
    guard producer == .ambient || producer == .persistence else {
      return true
    }
    guard request.identity.system == context.system, request.identity.visit == context.visit,
      request.identity.sequence > 0, request.identity.sequence < UInt64.max,
      request.identity.member == 0,
      request.hull == .cobra, request.population == .civilian, request.priority == .ordinary,
      request.rock == nil, request.payload == nil, request.salvage == nil,
      let npc = request.npc, npc.role == .trader, let resources = npc.resources,
      matchesResources(resources, game: source.game)
    else { return false }
    if request.identity.producer == .persistence {
      return request.energy.map { $0.isFinite && $0 > 0 && $0 <= source.game.energy } == true
    }
    let region = EncounterGeography.region(at: context.player.position, anchors: context.anchors)
    guard source.ship.catalogue.galaxies.contains(context.system.galaxy),
      source.ship.catalogue.regions.contains(region),
      source.ship.catalogue.regions.contains(
        EncounterGeography.region(at: request.position, anchors: context.anchors)),
      request.energy == nil, npc.legalProvenance == .generated,
      npc.cargoProvenance == .generated, npc.routeProvenance == .generated,
      let stock = NPCResources.stock(source.game)
    else { return false }
    return resources == stock
  }

  static func matchesNativeBody(
    _ body: borrowing SpaceBody, context: borrowing EncounterContext,
    commander: borrowing Commander
  ) -> Bool {
    guard let id = body.physical?.catalogueShipID, contains(id) else { return true }
    guard let source = source(for: id), body.hull == .cobra,
      body.scriptNPC == nil, body.scriptShot == nil, body.missionInstanceID == nil,
      body.missionActorID == nil, body.blackjackIdentity == nil, body.blackjackRole == nil,
      body.nativeStationIdentity == nil, let physical = body.physical,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.identity.visit > 0, physical.identity.entity > 1,
      let spawn = physical.spawnIdentity, spawn.system == physical.identity.system,
      spawn.visit == physical.identity.visit, spawn.sequence > 0, spawn.sequence < UInt64.max,
      spawn.member == 0, physical.rock == nil, physical.payload == nil,
      physical.ordnance == nil, physical.empCrewPod == nil, body.energy.isFinite,
      body.energy >= 0, body.energy <= source.game.energy
    else { return false }
    if physical.empSource != nil || spawn.producer == .emp {
      return matchesEMPHull(body, source: source, commander: commander)
    }
    guard spawn.producer == .ambient || spawn.producer == .persistence,
      physical.population == .civilian, physical.salvage == nil,
      let npc = physical.npc, npc.role == .trader, let resources = npc.resources
    else { return false }
    return matchesResources(resources, game: source.game)
  }

  /// Existing EMP custody carries the original native source through crew departure.
  /// Historical snapshots identify lineage; their pose/energy is not the current reading.
  private static func matchesEMPHull(
    _ body: borrowing SpaceBody, source: Source, commander: borrowing Commander
  ) -> Bool {
    guard let physical = body.physical,
      let original = physical.empSource, let spawn = physical.spawnIdentity,
      spawn.producer == .emp, let record = commander.nativeEMPCustodyRecord(for: original),
      !record.isRecovered, record.source == original, record.sequence == spawn.sequence,
      record.hull.binding == physical.identity, record.hull.body.id == body.id,
      record.hull.body.physical?.identity == physical.identity,
      record.hull.body.physical?.catalogueShipID == source.ship.id,
      record.custody.original.body.hull == body.hull,
      let originalPhysical = record.custody.original.body.physical,
      originalPhysical.catalogueShipID == source.ship.id,
      let originalNPC = originalPhysical.npc, originalNPC.role == .trader,
      let originalResources = originalNPC.resources,
      matchesResources(originalResources, game: source.game)
    else { return false }
    if let npc = physical.npc {
      guard physical.population == .civilian, npc.role == .trader,
        let resources = npc.resources
      else { return false }
      return matchesResources(resources, game: source.game)
    }
    return record.crewAboard == 0 && physical.population == .wreck
  }

  private static func matchesResources(_ value: NPCResources, game: ShipPerformance) -> Bool {
    guard value.valid, value.profile == .nativeHull, let stock = NPCResources.stock(game) else {
      return false
    }
    return value.energyCapacity == stock.energyCapacity
      && value.energyRecharge == stock.energyRecharge
      && value.frontCapacity == stock.frontCapacity && value.rearCapacity == stock.rearCapacity
      && value.shieldRecharge == stock.shieldRecharge && value.heatCapacity == stock.heatCapacity
      && value.heatCooling == stock.heatCooling && value.fuelCapacity == stock.fuelCapacity
  }

  /// Same authored native mesh as rendering/collision. This derives no mass.
  static func collisionRadius(for id: String) -> Double? {
    guard source(for: id) != nil, let mesh = ShipCatalogue.rawMesh(id),
      let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0
    else { return nil }
    return radius
  }
}
