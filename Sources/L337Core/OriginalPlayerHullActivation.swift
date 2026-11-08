import Foundation

/// Common fit projection for individually authenticated original player-hull activations.
enum OriginalPlayerHullActivation {
  enum Failure: Error { case missingStandardFit, invalidCatalogue }

  static let resourceSHA256: [String: String] = [
    "SH002": "042d9d9530341f4a7941fbecf483edc891700313d196d9dbbd763eae23889225",
    "SH003": "f2ac23aa3b7df524b0425f27e97e80277fbd501751fa4131be26bb86f70c8fb5",
    "SH004": "0e3362cebc552a63e8670e35d9124266fcf5db337312cb8be7eb1f19e4afe6f3",
    "SH012": "21bc51b0e9526cf85c0b3d825e24e3cb899dbf15ac6dc7ffdd5885f38380b47c",
    "SH018": "7f58accbbe2b13deaeed84c6ad913801ac947d2ccf3e1a1189d9cde18222d63e",
    "SH019": "b37924110f28d2b0d541af5b7de2feb7c386254350afe6f4a8c162af471169ac",
    "SH027": "6c206e271dbdb23c620c12808092f1e64439180e1fedfc4e7bec6bd81f646771",
    "SH029": "ecf10abbdaed31818297c0658daa7ffa542214411ab285b2c9e429e3b1ea5ade",
    "SH030": "1eacb3cd5655ea96e02e38252543e98b060c97d83df11fd44ade3afb5c980ea3",
    "SH031": "13e4d6b94a801c84dd89b9f4af9c8ba21151a33782b7e9a98c03ef503302772f",
    "SH032": "0023556a6c7a00481cdc10461eaf5b3ef4b9477e0c4f1919442e108fe0a94d9f",
    "SH033": "1988405e8771bf509d9a22811cf36dea4433d4a1dca451e3bf64fd55b9e385b5",
    "SH035": "53dc4125b7fa2b1d2789796ccfc24b0ccd20ab5ad0cda73f0a4f8f42c7d44af6",
    "SH061": "f3177e424313874098556204aa0be6f62096ee0412bcac9175bcc6a76db9f71d",
    "SH103": "146700ac1cd4d7990ba64a19399d0875af52d36545edd668431d9f81edd9c17e",
    "SH108": "5975818748faca138454ab9f7d274034391bfbe4159729a9a738927405d26b7d",
  ]

  static func authenticateBaseline(_ ship: CatalogueShip, bytes: Data) throws {
    guard let expected = resourceSHA256[ship.id] else { return }
    guard ScriptPackLibrary.hash(bytes) == expected else { throw Failure.invalidCatalogue }
  }

  /// Closed per-ID routing; a family name or runtime-ready flag never selects an adapter.
  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    if OriginalDetailedHullStage.blocksRuntime(retained.id) {
      return try OriginalDetailedHullStage.resolvePending(retained)
    }
    switch retained.id {
    case "SH002": return try OriginalGyrfalconAssaultActivation.resolve(retained)
    case "SH003", "SH004": return try OriginalGyrfalconFamilyActivation.resolve(retained)
    case "SH007": return try OriginalImpalaVoyagerActivation.resolve(retained)
    case "SH012": return try OriginalSableLinerActivation.resolve(retained)
    case "SH018": return try OriginalOnagerActivation.resolve(retained)
    case "SH019": return try OriginalGazelleExplorerActivation.resolve(retained)
    case "SH027": return try OriginalIbexActivation.resolve(retained)
    case "SH030": return try OriginalSparrowhawkActivation.resolve(retained)
    case "SH031": return try OriginalKiteInterceptorActivation.resolve(retained)
    case "SH032", "SH033": return try OriginalPantherFamilyActivation.resolve(retained)
    case "SH035": return try OriginalStagLinerActivation.resolve(retained)
    case "SH103": return try OriginalRedtailMkIIIActivation.resolve(retained)
    case "SH108": return try OriginalBesraActivation.resolve(retained)
    case "SH029": return try OriginalOkapiActivation.resolve(retained)
    case "SH061": return try OriginalSaigaActivation.resolve(retained)
    default: return retained
    }
  }

  static func resolve(
    _ retained: CatalogueShip, definition: OriginalFleetDefinition,
    physical: OriginalHullPhysicalContract
  ) throws -> CatalogueShip {
    guard retained.id == definition.id, physical.id == definition.id,
      physical.specificationSHA256 == definition.sourceSHA256,
      let role = ShipCatalogueRole(rawValue: definition.role),
      [ShipCatalogueRole.trader, .military, .leisure, .bountyHunter].contains(role),
      let type = ShipCatalogueType(rawValue: definition.role), definition.playerFlyable,
      definition.purchasePolicy == "blueprintFabrication",
      let performance = definition.nativePerformance,
      let current = OriginalFleetR3Data.contract(for: definition.id),
      current.sourceSHA256 == definition.sourceSHA256, current.performance == performance,
      let accommodation = current.accommodation, let fitting = current.fitting,
      retained.name == current.name, retained.catalogue.family == current.family,
      retained.game == performance, retained.nativeDesign == physical.model.nativeDesign,
      OriginalFleetR3Fitting.contract(for: retained) != nil
    else { throw Failure.invalidCatalogue }
    let id = definition.id
    let specificationSHA256 = definition.sourceSHA256
    let ship = CatalogueShip(
      id: id, name: definition.name, shipClass: retained.shipClass, appearances: "L337",
      evidence: "Original specification " + specificationSHA256,
      refit: retained.refit, model: "L337-" + id, modelSource: "Original L337",
      dimensions: [
        physical.envelope.dimensions.x, physical.envelope.dimensions.y,
        physical.envelope.dimensions.z,
      ],
      geometryContext:
        physical.unitBasis + " No showroom normalization in physical geometry. "
        + physical.model.sourcePath + " / " + physical.model.sourceSHA256,
      profiles: [
        standardProfile(
          performance: performance, definition: definition,
          accommodation: accommodation, fitting: fitting)
      ],
      game: performance,
      catalogue: metadata(from: retained.catalogue, definition: definition, role: role, type: type),
      design: retained.design, nativeHull: retained.nativeHull,
      nativeDesign: physical.model.nativeDesign, nativeCombat: retained.nativeCombat)
    guard
      ship.catalogue.valid(shipID: id, performance: performance, nativeCombat: ship.nativeCombat),
      ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles)
    else { throw Failure.invalidCatalogue }
    return ship
  }

  private static func metadata(
    from retained: ShipCatalogueMetadata, definition: OriginalFleetDefinition,
    role: ShipCatalogueRole, type: ShipCatalogueType
  ) -> ShipCatalogueMetadata {
    .init(
      schemaVersion: retained.schemaVersion, family: definition.family, aliases: retained.aliases,
      objectKind: .ship, origin: .human, primaryType: type,
      primaryRole: role,
      roleWeights: [.init(role: role, weight: 1)], access: .normal, playerFlyable: true,
      normalPurchaseEligible: true, purchasePolicy: .blueprintFabrication,
      minimumBuildTechLevel: retained.minimumBuildTechLevel, isCapital: false, capitalSubtype: nil,
      collectionMilestone: .blueprintAndFabrication, damagePolicy: .destructible,
      habitat: retained.habitat, discoveryEligible: true, encounterMode: retained.encounterMode,
      mechanicsStatus: .ready, placementStatus: retained.placementStatus, rarity: retained.rarity,
      galaxies: retained.galaxies, regions: retained.regions,
      authoredSystems: retained.authoredSystems,
      basis:
        "Original " + definition.id + " " + definition.name
        + " " + role.rawValue + " and blueprint-fabrication policy. "
        + "Existing project placement, rarity and fabrication technology policy retained; "
        + "catalogue eligibility does not grant discovery, a blueprint or a fabricated hull.")
  }

  private static func standardProfile(
    performance p: ShipPerformance, definition: OriginalFleetDefinition,
    accommodation: OriginalFleetR3Contract.Accommodation, fitting: OriginalFleetR3Contract.Fitting
  ) -> ShipProfile {
    let basis = "Current R3 " + definition.sourcePath + " / " + definition.sourceSHA256
    func field(_ key: String, _ label: String, _ value: Double, _ unit: String) -> ShipSpec {
      .init(
        key: key, label: label, text: String(format: "%.4g", value) + " " + unit,
        number: value, unit: unit, status: "current original authored", basis: basis)
    }
    let fields: [ShipSpec] = [
      field("cargo_tonnes", "Empty cargo capacity", Double(p.cargo), "t"),
      field("maximum_speed_project_units", "Maximum speed", p.speed, "project units/s"),
      field("acceleration_project_units_per_second_squared", "Acceleration", p.acceleration, "project units/s^2"),
      field("hull_energy", "Hull energy", p.energy, "native energy units"),
      field("energy_recharge_per_second", "Energy recharge", p.recharge, "native energy units/s"),
      field("fore_shield_max", "Forward shield", p.shield, "native energy units"),
      field("aft_shield_max", "Aft shield", p.shield, "native energy units"),
      field("fore_shield_recharge_per_second", "Forward shield recharge", p.shieldRecharge, "native energy units/s"),
      field("aft_shield_recharge_per_second", "Aft shield recharge", p.shieldRecharge, "native energy units/s"),
      field("roll_radians_per_second", "Roll", p.roll, "rad/s"),
      field("pitch_radians_per_second", "Pitch", p.pitch, "rad/s"),
      field("yaw_radians_per_second", "Yaw", p.yaw, "rad/s"),
      field("fuel_capacity_tenths_ly", "Fuel tank", Double(p.fuel), "0.1 LY"),
      field("hyperspace_range_ly", "Maximum jump", p.jump, "LY"),
      field("jump_spool_seconds", "Jump charge", p.spool, "s"),
      field("missile_capacity", "Missile capacity", Double(p.missiles), "missiles"),
      field("laser_facing_mask", "Compatible laser facing mask", Double(p.facings), "mask"),
      field("cargo_expansion_tonnes", "Cargo expansion", Double(p.cargoExpansion), "t"),
      field("hull_price_credits", "Hull price", Double(p.price), "CR"),
      field("hold_used_by_cabins", "Bare cabin hold", 0, "t"),
      field("usable_cargo_after_fit", "Bare usable cargo", Double(p.cargo), "t"),
      field("required_crew_including_commander", "Operating crew", Double(accommodation.operatingCrew), "people"),
      field("reserved_crew_accommodation", "Intrinsic crew places", Double(accommodation.intrinsicCrewPlaces), "people"),
      field("equipment_capacity_units", "Equipment budget", Double(fitting.equipmentUnits), "equipment units"),
      field("initial_charter_passenger_berths", "Initial purchased berths", 0, "berths"),
      field("utility_mounts", "Utility mounts", Double(fitting.utilityMounts), "mounts"),
    ]
    return .init(
      id: "L337-PLAYER-" + definition.id, title: definition.name + " current bare specification",
      group: "project-refit-v1",
      context: basis + ". Empty intrinsic places and compatibility do not install crew, cabins or paid role kit.",
      fields: fields)
  }
}
