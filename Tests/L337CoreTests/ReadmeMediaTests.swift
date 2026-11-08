import Foundation
import Testing

@testable import L337Core

struct ReadmeMediaTests {
  @Test func completeTapeUsesTheActualGalleryAndIncludesExactlyOneAndAHalfTurns() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let manifest =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: root.appendingPathComponent("docs/ships/manifest.json")))
      as? [String: Any]
    let ids = try #require(manifest?.keys.sorted())
    #expect(ReadmeMedia.galleryShipIDs == ids)
    #expect(ids.count == 171 && Set(ids).count == ids.count)
    let angles = ReadmeMedia.galleryAngles
    #expect(angles.count == 37)
    #expect(angles.first == 0)
    #expect(abs(try #require(angles.last) - 3 * .pi) < 1e-12)
    #expect(zip(angles, angles.dropFirst()).allSatisfy { $0.0 < $0.1 })
    #expect(abs(angles[24] - 2 * .pi) < 1e-12)
    #expect(ReadmeMedia.frameCount == 6375)
    #expect(abs(ReadmeMedia.duration - 640.38) < 1e-9)
  }

  @Test(arguments: ShipCatalogue.all.map(\.id))
  func everyGalleryCardUsesItsRealMeshAndNameAtTheActualRotationEndpoints(id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let mesh = try #require(ship.previewMesh)
    let game = Game(executive: false)
    let commander = game.commander
    let screen = game.screen
    let bodies = game.bodies
    for angle in [0.0, Double.pi, 3 * Double.pi] {
      let frame = try Display.galleryShipPresentation(
        game, shipID: id, angle: angle, width: 1024, height: 768)
      #expect(frame.hasShipSurfaces)
      #expect(
        frame.labels.map(\.text) == [
          "SHIP GALLERY", id + " - " + ship.name, "1.5 FULL ROTATIONS",
        ])
      #expect(!frame.rasterizeGraphics && frame.responsive)
      #expect(
        frame.labels.allSatisfy {
          $0.bounds.x >= 0 && $0.bounds.maxX <= frame.canvas.width
            && $0.bounds.y >= 0 && $0.bounds.maxY <= frame.canvas.height
        })
      var reference = Frame()
      reference.responsive = true
      reference.rasterizeGraphics = false
      reference.canvas = frame.canvas
      reference.flightClip = frame.flightClip
      var presentation = game
      presentation.screen = .front
      presentation.commander.shipDisplayStyle = .shadedPanels
      var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
      body.orientation.rotate(pitch: 0.3, roll: 0.15, yaw: angle)
      Display.draw(
        body, game: presentation, into: &reference,
        projection: .init(center: .init(512, 768 * 0.47), focal: 768 * 1.15),
        mesh: mesh, screen: .front)
      #expect(
        frame.graphics == reference.graphics && frame.worldGraphics == reference.worldGraphics)
    }
    #expect(game.screen == screen && game.commander == commander && game.bodies == bodies)
  }

  @Test func galleryExportRefusesMissingShipsAndNonfiniteAngles() {
    for (id, angle) in [("SH999", 0.0), ("SH002", Double.nan), ("SH002", .infinity)] {
      #expect(throws: ShipFileError.self) {
        try Display.galleryShipPresentation(
          Game(executive: false), shipID: id, angle: angle, width: 1024, height: 768)
      }
    }
  }

  @Test func introductionUsesAnOrdinaryLaunchAndExactTraderSource() async throws {
    var game = try await ReadmeMedia.introductionCommander()
    #expect(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
    game.screen = .status
    try ReadmeMedia.launchIntroductionFlight(&game)
    #expect(!game.docked && game.screen == .front)
    let trader = try #require(game.bodies.first { $0.id == 1 })
    #expect(trader.physical?.catalogueShipID == "SH029")
    #expect(game.commander.shipID == "SH025")
    #expect(trader.physical?.npc?.routeProvenance == .generated)
    #expect(trader.position == Vector3(-35, 10, 320))
    #expect(!game.gameplayMesh(for: trader).faces.isEmpty)
  }

  @Test func captureUsesFourOriginalHullsRealTrackingDamageAndVisibleHitFeedback() async throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/readme-capture")
    let manifest = try Data(contentsOf: directory.appendingPathComponent("manifest.toml"))
    for composition in ReadmeMedia.CaptureComposition.allCases {
      let game = try await ReadmeMedia.dockingUnderAttackScene(
        sourceDirectory: directory, composition: composition)
      #expect(try Data(contentsOf: directory.appendingPathComponent("manifest.toml")) == manifest)
      #expect(!game.docked && game.screen == .front && game.laserFlash == 0)
      let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
      #expect(abs(station.entrancePosition.x) < 1 && abs(station.entrancePosition.y) < 1)
      #expect(station.entrancePosition.z > 0)
      #expect(station.entranceNormal.z < -0.99)
      // The fresh camera starts aligned with the aperture. During actual tracking,
      // the station rolls around its outward axis, which points toward the camera.
      let elapsed = game.commander.flightSimulation.physicalTime
      #expect(elapsed > 0 && elapsed <= 1.2 + 1e-9)
      #expect(station.rotationRate == 0.3)
      let phase = elapsed * 0.3
      #expect(abs(station.rotation - phase) < 1e-9)
      let expectedUp = Vector3(sin(phase), cos(phase), 0)
      #expect((station.entranceUp - expectedUp).length < 1e-7)
      let attackers = game.bodies.filter { $0.scriptNPC != nil }
      #expect(attackers.count == 4 && Set(attackers.compactMap(\.missionActorID)).count == 4)
      let references = Set(attackers.compactMap { $0.scriptNPC?.fit.definition.model })
      #expect(references == Set(ReadmeMedia.captureShipIDs.map { "catalogue:" + $0 }))
      for body in attackers {
        #expect(body.hostile && body.position.z > 0 && body.position.z < station.entrancePosition.z)
        let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: body.id))
        #expect(descriptor.encounterAdmitted && descriptor.presence == "present")
        let npc = try #require(body.scriptNPC)
        let id = String(npc.fit.definition.model.dropFirst("catalogue:".count))
        let ship = try #require(ShipCatalogue.ship(id))
        let original = try #require(ship.originalDefinition)
        #expect(ship.name == original.name && original.approvedMeshAvailable)
        let fitted = try ScriptPackLibrary.currentCatalogueNPCDesign(id)
        let native = try #require(ship.nativeDesign)
        #expect(fitted.faces == native.faces && fitted.license == "MIT")
        let hash = try #require(npc.fit.models[npc.fit.definition.model])
        let expectedHash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(fitted))
        #expect(hash == expectedHash)
        #expect(game.commander.scriptState.geometry[hash] == fitted)
        let mesh = try #require(game.scriptNPCMesh(body))
        #expect(mesh.vertices == fitted.rawMesh.vertices && mesh.vertices.count > 50)
        #expect(mesh.faces == fitted.faces)
        #expect(npc.fit.definition.scale == 1)
        #expect(abs(body.orientation.z.dot(body.position.unit * -1)) < 0.99)
        let weapon = try #require(npc.fit.definition.lasers?.first { $0.id == "forward" })
        let gun = try #require(npc.guns[weapon.id])
        #expect(npc.shots > 0 && gun.cooldown > weapon.interval - 0.05)
        #expect(gun.aim != nil && (weapon.trackingRate ?? 0) > 0)
        #expect(body.energy < npc.fit.definition.energy)
        #expect(gun.heat > 0 && gun.heat <= weapon.maximumHeat)
        let range = try #require(gun.beamRange)
        let muzzle = body.position + body.orientation.apply(weapon.muzzle)
        let direction = body.orientation.apply(gun.aim ?? weapon.direction).unit
        let aimPoint = Game.nativePlayerSurfaceAim(from: muzzle, mesh: game.commander.playerMesh)
        #expect(direction.dot((aimPoint - muzzle).unit) > 0.999)
        let actual = try game.nearestMissionCollision(
          from: muzzle, direction: direction, range: weapon.range, radius: 0,
          excludingBodyIDs: [body.id], includePlayer: true)
        let contact = try #require(actual)
        #expect(contact.hit.target == .player && abs(contact.hit.distance - range) < 1e-6)
      }
      #expect(game.frontShield < game.commander.shieldCapacity && game.energy > 0)
      let storedImpact = try #require(game.playerImpactFeedback)
      #expect(game.visiblePlayerImpactFeedback == storedImpact)
      let frame = Display.presentation(game, width: 1024, height: 768)
      #expect(frame.labels.contains { $0.text == "FORE SHIELD HIT" || $0.text == "HULL HIT" })
    }
  }
}
