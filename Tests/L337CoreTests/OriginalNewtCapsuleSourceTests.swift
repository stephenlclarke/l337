import Foundation
import Testing

@testable import L337Core

struct OriginalNewtCapsuleSourceTests {
  @Test func currentNewtResourceLoadsWithoutGrantingAnOrdinaryShipOrNativeCapsule() throws {
    let ship = try #require(ShipCatalogue.ship("SH040"))
    let source = try #require(OriginalFleetR3Data.contract(for: ship.id))
    let entry = try #require(OriginalDetailedHullStage.registration(for: ship.id))
    let native = try #require(ship.nativeDesign)
    let performance = try #require(ship.game)
    #expect(ship.name == "Newt Escape Pod" && ship.catalogue.family == "newt-escape-pod")
    #expect(ship.name == source.name && ship.game == source.performance)
    #expect(ship.catalogue.objectKind == .capsule && ship.catalogue.origin == .human)
    #expect(ship.design.vertices.count == 256 && ship.design.faces.count == 415)
    #expect(native.vertices.count == 48 && native.faces.count == 92)
    #expect(entry.sourceNativeFaces == 92 && entry.metresPerSourceUnit == "60/19")
    #expect(ship.design.materials?.isEmpty == false && native.materials?.isEmpty == false)
    #expect(ship.catalogue.aliases?.isEmpty == true && ship.profiles.count == 2)
    #expect(ship.profiles.allSatisfy {
      ["original-r3-source-stage", "project-refit-v1"].contains($0.group)
    })
    #expect(performance.fuel == 0 && performance.jump == 0 && performance.spool == 0)
    #expect(performance.cargo == 0 && performance.missiles == 0 && performance.facings == 0)
    #expect(!performance.valid(purchasePolicy: .never))
    #expect(OriginalDetailedHullStage.hasPendingCapsuleStatistics(ship))
    #expect(ship.catalogue.mechanicsStatus == .pending && ship.catalogue.placementStatus == .pending)
    #expect(ship.catalogue.purchasePolicy == .never && !ship.catalogue.normalPurchaseEligible)
    #expect(!ship.catalogue.playerFlyable && !ship.catalogue.discoveryEligible)
    #expect(!ship.catalogue.readyForNaturalEncounters && ship.catalogue.roleWeights.isEmpty)
    #expect(ship.nativeHull == nil && ship.nativeCombat == nil)
    #expect(OriginalFleetR3Fitting.contract(for: ship) == nil)
    #expect(throws: (any Error).self) { try ShipAccommodationProfile(ship: ship) }
    #expect(OriginalDetailedHullStage.blocksRuntime(ship.id))
    #expect(ShipCatalogue.rawMesh(ship.id) == nil)
    #expect(OriginalFleetRuntimeHullSource.source(for: ship.id) == nil)
    #expect(SalvageCatalogue.empProfile(catalogueShipID: ship.id) == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: ship.id, sourceFaces: 92))
    { try OriginalDetailedHullStage.requireRuntime(ship.id) }
    let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH040.toml"))
    try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
    var changed = bytes
    changed.append(0)
    #expect(throws: (any Error).self) {
      try OriginalDetailedHullStage.authenticate(ship, bytes: changed)
    }
  }

  @Test func defaultLoaderResolvesGenuineGlassMeridianClockToCryostasisShell() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let runtime = GameRuntime(game: Game(executive: false))
    await runtime.loadMissionPacks(directory: directory.appendingPathComponent("mission-packs"))
    let errors = await runtime.loadDefaultScriptPacks(directory: directory.appendingPathComponent("script-packs"))
    #expect(!errors.contains { $0.hasPrefix("Bundled Glass Meridian:") })
    var game = await runtime.snapshot()
    let pack = try #require(game.scriptPacks.first { $0.digest == NativeGlassMeridian.digest })
    let expectedPacks = [
      (ScriptPackLibrary.bundledGlassMeridianDirectory, NativeGlassMeridian.digest),
      (ScriptPackLibrary.bundledOriginalRescueDirectory, NativeOriginalRescueJourney.digest),
      (ScriptPackLibrary.bundledOrbitalOutlookDirectory, NativeOrbitalOutlookJourney.digest),
      (ScriptPackLibrary.bundledOriginalSurveyDirectory, NativeOriginalSurvey.digest),
    ]
    for (directory, digest) in expectedPacks {
      let bundled = try ScriptPackLibrary.read(directory)
      #expect(bundled.digest == digest, "Unexpected digest for \(bundled.manifest.id)")
      let model = try #require(bundled.models["catalogue:SH040"])
      let canonical = try ScriptPackLibrary.canonicalGeometry(model)
      #expect(ScriptPackLibrary.hash(canonical) ==
        "be0d091a6bbf5f1af265eae4b94381fe0f049b8c4593005378b45b791f1b7461")
      #expect(game.scriptPacks.contains {
        $0.manifest.id == bundled.manifest.id && $0.digest == digest
      })
    }
    let clock = try #require(pack.manifest.npcs?.first { $0.id == NativeGlassMeridian.markerID })
    #expect(NativeGlassMeridian.clockDefinitionValid(clock))
    let encounters = try #require(pack.manifest.encounters)
    let clockEncounters = NativeGlassMeridian.encounters
    for (index, position) in [Vector3(-5000, 0, 20000), Vector3(5000, 0, 24000)].enumerated() {
      let encounter = try #require(encounters.first { $0.id == clockEncounters[index] })
      let actor = try #require(encounter.actors.first)
      #expect(encounter.galaxy == 0 && encounter.system == 185 && encounter.actors.count == 1)
      #expect(actor.id == NativeGlassMeridian.targets[index] && actor.npc == clock.id && !actor.hostile)
      #expect(Vector3(actor.x, actor.y, actor.z) == position)
    }
    let source = try #require(OriginalCryostasisCapsule.source)
    #expect(pack.models[clock.model] == source.collisionDesign)
    let npc = try game.makeScriptNPC(clock, pack: pack, identity: UUID())
    var body = SpaceBody(id: -1, hull: .cobra, position: .init(-5000, 0, 20000))
    body.scriptNPC = npc
    #expect(!OriginalDetailedHullStage.blocksRuntime(body))
    let collision = try #require(game.scriptNPCMesh(body))
    let display = try #require(game.scriptNPCDisplayMesh(body))
    #expect(collision.vertices.count == 48 && collision.faces.count == 92)
    #expect(collision.opticalEnclosure == nil && display.opticalEnclosure?.paneFace == 38)
    #expect(display.vertices.count == 256 && display.faces.count == 415)
    #expect(Array(display.vertices.prefix(48)) == collision.vertices)
    #expect(abs((collision.vertices.map(\.z).max() ?? 0) - (collision.vertices.map(\.z).min() ?? 0) - 2.4) < 1e-12)
    #expect(game.commander.scriptState.geometry[source.collisionSHA256] == source.collisionDesign)
    #expect(game.commander.scriptState.geometry.values.allSatisfy { $0.vertices.count != 256 })
    body.position = .init(0, 0, 400)
    game.screen = .front
    game.commander.shipDisplayStyle = .shadedPanels
    game.bodies = [body]
    var validFrame = Frame()
    validFrame.rasterizeGraphics = false
    Display.draw(body, game: game, into: &validFrame, screen: .front)
    #expect(!validFrame.shipPanels.isEmpty)
    let rayOrigin = Vector3(0, 0, 396)
    let rayDirection = Vector3(0, 0, 1)
    let validScene = GameplayRaycast.prepareOcclusionScene(game)
    let hit = try #require(GameplayRaycast.nearest(
      origin: rayOrigin, direction: rayDirection, maxDistance: 8, scene: validScene))
    #expect(hit.target == .body(body.id) && abs(hit.distance - 2.8) < 1e-10)
    game.commander.scriptState.geometry[source.collisionSHA256] = try #require(ShipCatalogue.ship("SH040")).design
    #expect(game.scriptModel(clock.model, fit: npc.fit) == nil)
    #expect(game.scriptNPCDisplayMesh(body) == nil)
    var forgedFrame = Frame()
    forgedFrame.rasterizeGraphics = false
    Display.draw(body, game: game, into: &forgedFrame, screen: .front)
    #expect(forgedFrame.graphics.isEmpty)
    let forgedScene = GameplayRaycast.prepareOcclusionScene(game)
    #expect(GameplayRaycast.nearest(
      origin: rayOrigin, direction: rayDirection, maxDistance: 8, scene: forgedScene) == nil)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    try await checkGenuineRescueCapsuleFits(collisionSHA256: source.collisionSHA256)
  }

  private func checkGenuineRescueCapsuleFits(collisionSHA256: String) async throws {
    let fixture = try NativeOriginalRescueFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let state = try await fixture.accept(runtime)
    try await fixture.launch(runtime)
    let game = await runtime.snapshot()
    let custody = try #require(game.commander.nativePeople)
    let mission = try #require(game.commander.scriptState.instances[state.mission])
    let encounter = try #require(mission.ownedEncounters[NativeOriginalRescueJourney.encounterID])
    #expect(mission.digest == fixture.pack.digest && encounter.admitted)
    for alias in NativeOriginalRescueJourney.aliases {
      let actor = try #require(encounter.actors[alias])
      let fit = try #require(actor.body.scriptNPC?.fit)
      #expect(fit.models == ["catalogue:SH040": collisionSHA256])
    }
    #expect(NativeOriginalRescueJourney.validSource(
      custody.originalRescue, custody: custody, commander: game.commander))
  }

  @Test(arguments: ["foreign-id", "foreign-origin", "ordinary-kind", "nonzero-jump", "wrong-fit", "missing-native"])
  func onlyTheExactPendingNewtCanUseTheCapsuleStatisticsPath(condition: String) throws {
    let ship = try #require(ShipCatalogue.ship("SH040"))
    try #require(OriginalDetailedHullStage.hasPendingCapsuleStatistics(ship))
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    switch condition {
    case "foreign-id": object["id"] = "SH999"
    case "foreign-origin":
      var metadata = try #require(object["catalogue"] as? [String: Any])
      metadata["origin"] = "alien"
      object["catalogue"] = metadata
    case "ordinary-kind":
      var metadata = try #require(object["catalogue"] as? [String: Any])
      metadata["objectKind"] = "ship"
      object["catalogue"] = metadata
    case "nonzero-jump":
      var game = try #require(object["game"] as? [String: Any])
      game["jump"] = 1
      object["game"] = game
    case "wrong-fit":
      var profiles = try #require(object["profiles"] as? [[String: Any]])
      let index = try #require(profiles.firstIndex { $0["group"] as? String == "project-refit-v1" })
      var fields = try #require(profiles[index]["fields"] as? [[String: Any]])
      let field = try #require(fields.firstIndex { $0["key"] as? String == "equipment_capacity_units" })
      fields[field]["number"] = 1
      profiles[index]["fields"] = fields
      object["profiles"] = profiles
    case "missing-native": object.removeValue(forKey: "nativeDesign")
    default:
      Issue.record("Unknown controlled pending capsule source condition")
      return
    }
    let changed = try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!OriginalDetailedHullStage.hasPendingCapsuleStatistics(changed))
    #expect(throws: (any Error).self) { try OriginalDetailedHullStage.resolvePending(changed) }
    #expect(OriginalDetailedHullStage.hasPendingCapsuleStatistics(ship))
    #expect(ship.game?.jump == 0 && ship.catalogue.purchasePolicy == .never)
  }
}
