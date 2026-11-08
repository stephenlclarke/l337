import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalImpalaVoyagerUnitTests {
  private func retained(_ id: String = "SH007") throws -> CatalogueShip {
    try TOMLDecoder().decode(CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH007"))
    let model = try OriginalFleetShowroomModels.model(for: "SH007")
    let contract = try OriginalHullPhysicalContract.impalaVoyager.get()
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-10.15, -4.4, -21.39))
    #expect(contract.envelope.maximum == .init(10.15, 6.976, 20))
    #expect(contract.nativeTriangles == 264)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(id: String = "SH007", units: String? = "metres",
      path: String? = nil, hash: String? = nil) -> OriginalFleetShowroomModel
    {
      .init(id: id, sourcePath: path ?? model.sourcePath,
        sourceSHA256: hash ?? model.sourceSHA256, coordinateUnits: units,
        nativeDesign: model.nativeDesign)
    }
    for invalid in [changed(id: "SH008"), changed(units: nil), changed(units: "showroom"),
      changed(path: "other.toml"), changed(hash: String(repeating: "0", count: 64))]
    {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let other = try #require(OriginalFleetDefinitionData.definition(for: "SH008"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: other, model: model)
    }
  }

  @Test func exactR3SourceReplacesOlderValuesWithoutClaimingReadyAcquisition() throws {
    let ship = try #require(ShipCatalogue.ship("SH007"))
    let definition = try #require(ship.originalDefinition)
    let game = try #require(ship.game)
    #expect(ship == (try retained()))
    #expect(game == definition.nativePerformance)
    #expect(game.cargo == 60 && game.cargoExpansion == 15 && game.speed == 38)
    #expect(game.energy == 260 && game.recharge == 3.8 && game.acceleration == 11)
    #expect(game.fuel == 140 && game.jump == 12 && game.missiles == 4 && game.facings == 3)
    #expect(game.price == 319000 && game.shield == 220 && game.shieldRecharge == 1.7)
    #expect(definition.sourceSHA256 == OriginalImpalaVoyagerActivation.specificationSHA256)
    #expect(definition.sourcePath == "fleet-design-v2/ships/SH007.toml")
    #expect(!definition.runtimeReady && !definition.integrationBlockers.isEmpty)
    #expect(ship.catalogue.purchasePolicy == .pendingFabrication)
    #expect(ship.catalogue.mechanicsStatus == .pending && !ship.catalogue.normalPurchaseEligible)
    #expect(ship.catalogue.minimumBuildTechLevel == 14)
    let policy = ship.catalogue
    #expect(policy.family == "impala" && policy.primaryRole == .leisure
      && policy.primaryType == .leisure && policy.roleWeights.isEmpty)
    #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
    #expect(policy.placementStatus == .pending && policy.encounterMode == .authored)
    #expect(policy.galaxies.isEmpty && policy.regions.isEmpty
      && (policy.authoredSystems?.isEmpty ?? true))
    #expect(policy.valid(shipID: ship.id, performance: game, nativeCombat: ship.nativeCombat))
    #expect(NativeFleetDiscovery(owner: UUID()).readout(for: ship.id)
      == ["Collection: unknown; no native encounter recorded"])
    #expect(game.workTools?.isEmpty == true)
    #expect(OriginalImpalaVoyagerActivation.validEffectiveCargo(ship))
    #expect(!ship.profiles.contains { $0.group == "project-refit-v1" })
    // These are authored source budgets, not installed crew, cabins or role equipment.
    func fact(_ table: String, _ key: String) -> OriginalFleetValue? {
      guard case .object(let fields)? = definition.authored[table] else { return nil }
      return fields[key]
    }
    #expect(fact("accommodation", "minimumOperatingCrewIncludingCommander") == .integer(2))
    #expect(fact("accommodation", "intrinsicCrewPlaces") == .integer(2))
    #expect(fact("accommodation", "initialPurchasedCabins") == .integer(0))
    #expect(fact("fitting", "equipmentBudgetUnits") == .integer(26))
    #expect(fact("fitting", "roleKitIncludedInBareHull") == .boolean(false))
  }

  @Test func nativeMetresAndCurrentSourceCodecRetainOwnGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH007"))
    let physical = try OriginalHullPhysicalContract.impalaVoyager.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id  // Controlled geometry query; no acquisition or owned-fit claim.
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 146 && mesh.faces.count == 264)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign)
    #expect(ship.design.faces.reduce(0) { $0 + max(0, $1.count - 2) } == 5044)
    #expect(ship.design != ship.nativeDesign)
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
    let data = try JSONEncoder().encode(ship)
    let decoded = try JSONDecoder().decode(CatalogueShip.self, from: data)
    #expect(decoded == ship && OriginalImpalaVoyagerActivation.authenticates(decoded))
    // Detailed authored height11.44 and native LOD height11.376 remain their actual
    // different envelopes; no metadata number rescales the physical native mesh.
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [20.3, 11.44, 41.39]) {
      #expect(abs(actual - expected) < 1e-9)
    }
  }

  @Test(arguments: [13, 14])
  func pendingFabricationAtTechnologyBoundaryCannotChangeOwnedProperty(level: Int) throws {
    // Use an actual original world of the stated displayed technology for this
    // controlled quote preview. This fixture claims no flown arrival or SH007 title.
    var game = Game(executive: false)
    var found = false
    for galaxy in 0..<8 {
      let systems = Universe.systemsIncludingPlugh(number: galaxy)
      if let system = systems.first(where: { $0.technology == level }) {
        game.systems = systems
        game.commander.galaxy = galaxy
        game.commander.system = system.id
        game.selectedSystem = system.id
        found = true
        break
      }
    }
    try #require(found && game.currentSystem.technology == level)
    game.screen = .showroom
    game.showroom.selection = "SH007"
    game.showroom.trading = true
    let before = game.commander
    let bodies = game.bodies
    let quote = try #require(game.shipTradeQuote)
    #expect(quote.purchase == 3190000)
    #expect(!quote.allowed && quote.issues.contains("Fabrication for this hull is not yet available."))
    #expect(quote.issues.contains("Impala fabrication requires TL14.") == (level == 13))
    game.confirmShipTrade()
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.commander.shipID != "SH007" && game.showroom.trading)
  }

  @Test func malformedAndForeignProfilesCannotSupplyBareCargoOrSourceAuthority() throws {
    let ship = try retained()
    let encoded = try JSONEncoder().encode(ship)
    let original = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    for alteration in ["missing", "wrong-group", "duplicate-profile", "duplicate-field", "wrong-unit"] {
      var object = original
      var profiles = try #require(object["profiles"] as? [[String: Any]])
      var profile = try #require(profiles.first)
      switch alteration {
      case "missing": profiles = []
      case "wrong-group":
        profile["group"] = "project-refit-v1"
        profiles = [profile]
      case "duplicate-profile": profiles.append(profile)
      default:
        var fields = try #require(profile["fields"] as? [[String: Any]])
        if alteration == "duplicate-field" { fields.append(try #require(fields.first)) }
        else { fields[0]["unit"] = "t" }
        profile["fields"] = fields
        profiles = [profile]
      }
      object["profiles"] = profiles
      let invalid = try JSONDecoder().decode(CatalogueShip.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!OriginalImpalaVoyagerActivation.authenticates(invalid))
      #expect(!OriginalImpalaVoyagerActivation.validEffectiveCargo(invalid))
      #expect(throws: (any Error).self) { try OriginalImpalaVoyagerActivation.resolve(invalid) }
    }
    let source = try String(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH007.toml"),
      encoding: .utf8)
    for value in ["nan", "inf", "-1"] {
      let invalidText = source.replacingOccurrences(of: "number = 60,", with: "number = " + value + ",")
      try #require(invalidText != source)
      let invalid = try TOMLDecoder().decode(CatalogueShip.self, from: Data(invalidText.utf8))
      #expect(!OriginalImpalaVoyagerActivation.validEffectiveCargo(invalid))
    }
    let foreign = try retained("SH008")
    #expect(!OriginalImpalaVoyagerActivation.validEffectiveCargo(foreign))
    #expect(try OriginalImpalaVoyagerActivation.resolve(foreign) == foreign)
  }

  @Test func allOtherCatalogueLoadsRetainTheirExistingPerIDProjection() throws {
    let loaded = try ShipCatalogue.load(from: ShipCatalogue.folder)
    #expect(loaded.count == ShipCatalogue.all.count)
    for other in loaded where other.id != "SH007" {
      let raw = try retained(other.id)
      let expected = try OriginalPlayerHullActivation.resolve(raw)
      #expect(other == expected)
    }
  }
}
