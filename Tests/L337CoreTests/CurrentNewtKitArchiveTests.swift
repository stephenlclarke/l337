import Foundation
import Testing

@testable import L337Core

struct CurrentNewtKitArchiveTests {
  @Test func actualEquippedBirthKeepsItsStowedKitAcrossCurrentPublicationAndColdRead() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bornCandidate = game.bodies.first { $0.physical?.currentNewtKitStock?.phase == .stowed }
    let born = try #require(bornCandidate)
    let stock = try #require(born.physical?.currentNewtKitStock)
    let actor = try #require(born.physical?.identity)
    try #require(
      stock.issue.birthActor == actor && stock.issue.birthSpawn == born.physical?.spawnIdentity)
    try #require(game.commander.savedEMPState == nil && stock.remaining == 1)
    let property = game.commander.equipmentInventory
    let history = game.commander.equipmentPurchaseHistory
    let storage = game.commander.alienStorageState?.current.snapshot
    try checkStowedProjection(game, body: born)
    let files = try NativeStationTestStorage()
    defer { try? FileManager.default.removeItem(at: files.root) }

    try GameRuntime.writeCommander(&game, to: files.url)
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let pointerBytes = try Data(contentsOf: files.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let alien = storage != nil
    #expect(
      pointer.schemaVersion
        == (alien ? CurrentNewtKitSave.alienVersion : CurrentNewtKitSave.version))
    let (cold, world) = try ScriptSaveStore.read(pointerBytes, from: files.url)
    #expect(cold == prepared.commander && world == prepared.game.scriptWorldSave)
    #expect(world.consistent(with: cold))
    #expect(cold.equipmentInventory == property && cold.equipmentPurchaseHistory == history)
    #expect(cold.alienStorageState?.current.snapshot == storage)
    #expect(cold.usesAlienStorageSaveVersion == alien)
    #expect(cold.npcPersistence.unboundSnapshots[actor]?.currentNewtKitStock == stock)
    #expect(
      world.bodies.first { $0.physical?.identity == actor }?.physical?.currentNewtKitStock == stock)
    #expect(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.currentNewtKitStock == stock)

    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: files.url)
    let originalWorld = try Data(contentsOf: directory.appendingPathComponent("world.json"))
    let decodedWorld = try #require(
      JSONSerialization.jsonObject(with: originalWorld) as? [String: Any])
    // Establish that the rehashed JSON control still loads before making each native mutation.
    let control = try copiedArchive(
      files, label: "reencoded-control", pointer: pointer,
      world: JSONSerialization.data(withJSONObject: decodedWorld, options: [.sortedKeys]))
    let controlRead = try ScriptSaveStore.read(Data(contentsOf: control), from: control)
    #expect(controlRead.0 == cold && controlRead.1 == world)

    let downgraded = ScriptSavePointer(
      format: pointer.format,
      schemaVersion: ScriptSaveStore.featurePublicationSchema(cold, alien: alien),
      generation: pointer.generation, hashes: pointer.hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(JSONEncoder().encode(downgraded), from: files.url)
    }
    for misplaced in [false, true] {
      var object = decodedWorld
      var bodies = try #require(object["bodies"] as? [[String: Any]])
      let indexCandidate = bodies.firstIndex { body in
        let physical = body["physical"] as? [String: Any]
        let raw = physical?["currentNewtKitStock"] as? [String: Any]
        let issue = raw?["issue"] as? [String: Any]
        return issue?["kitID"] as? String == stock.issue.kitID.uuidString
      }
      let index = try #require(indexCandidate)
      var physical = try #require(bodies[index]["physical"] as? [String: Any])
      if misplaced {
        object["currentNewtKitStock"] = physical.removeValue(forKey: "currentNewtKitStock")
      } else {
        physical["currentNewtKitStock"] = NSNull()
      }
      bodies[index]["physical"] = physical
      object["bodies"] = bodies
      let file = try copiedArchive(
        files, label: misplaced ? "misplaced" : "null",
        pointer: pointer,
        world: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
      let rejected = try Data(contentsOf: file)
      #expect(throws: (any Error).self) { try ScriptSaveStore.read(rejected, from: file) }
      #expect(try Data(contentsOf: file) == rejected)
    }
    #expect(try Data(contentsOf: files.url) == pointerBytes)
    #expect(try Data(contentsOf: directory.appendingPathComponent("world.json")) == originalWorld)
    let unchanged = try ScriptSaveStore.read(pointerBytes, from: files.url)
    #expect(unchanged.0 == cold && unchanged.1 == world)
  }

  private func checkStowedProjection(_ game: Game, body: SpaceBody) throws {
    let componentsCandidate = try game.currentNewtGeometryComponents(for: body)
    let components = try #require(componentsCandidate)
    let containsMatch = components.contains { $0.displayMesh == nil }
    try #require(containsMatch)
    let containsMatch2 = components.contains { $0.displayMesh?.opticalEnclosure != nil }
    try #require(containsMatch2)
    let mountedCandidate = components.first {
      $0.id != "SH029-bare-carrier" && !$0.id.hasPrefix("pod:") && $0.displayMesh != nil
    }
    let mounted = try #require(mountedCandidate)
    let mesh = try #require(mounted.displayMesh)
    let bare = try #require(components.first { $0.id == "SH029-bare-carrier" }?.displayMesh)
    var preview = game
    preview.screen = .front
    let layout = CockpitLayout(game: preview, width: 1024, height: 768)
    func emptyFrame() -> Frame {
      var frame = Frame()
      frame.responsive = true
      frame.rasterizeGraphics = false
      frame.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
      frame.flightClip = layout.flightClip
      return frame
    }
    for style in ShipDisplayStyle.allCases {
      preview.commander.shipDisplayStyle = style
      var actual = emptyFrame()
      Display.draw(body, game: preview, into: &actual, projection: layout.projection)
      var bareFrame = emptyFrame()
      Display.draw(body, game: preview, into: &bareFrame, projection: layout.projection, mesh: bare)
      if style == .shadedPanels {
        #expect(actual.shipPanels.count > bareFrame.shipPanels.count)
        // Independent world-point projection catches a second parent transform or rotation.
        let vertices = mesh.vertices.map {
          preview.commander.flightSimulation.pose.shipPoint(mounted.pose.systemPoint($0))
        }
        let faces = mesh.faces.filter { face in
          let a = vertices[face[0]]
          let b = vertices[face[1]]
          let c = vertices[face[2]]
          return (b - a).cross(c - a).dot(a) < 0
        }
        let polygonCandidate = faces.map {
          ShipProjection.polygon($0, vertices: vertices, projection: layout.projection)
        }.first { $0.count >= 3 }
        let polygon = try #require(polygonCandidate)
        let containsMatch3 = actual.shipPanels.contains { panel in
          panel.vertices.count == polygon.count
            && zip(panel.vertices, polygon).allSatisfy { pair in
              abs(pair.0.x - pair.1.x) < 1e-7 && abs(pair.0.y - pair.1.y) < 1e-7
            }
        }
        #expect(containsMatch3)
      } else {
        #expect(actual.shipLines.count > bareFrame.shipLines.count)
      }
      let presentation = Display.presentation(preview, width: 1024, height: 768)
      let contribution = try #require(actual.graphics.last)
      #expect(presentation.worldGraphics.contains(contribution))
    }
    let indexCandidate2 = preview.bodies.firstIndex { $0.id == body.id }
    let index = try #require(indexCandidate2)
    preview.bodies[index].physical?.catalogueShipID = "SH005"
    var refused = emptyFrame()
    Display.draw(
      preview.bodies[index], game: preview, into: &refused, projection: layout.projection)
    #expect(refused.graphics.isEmpty)
  }

  private func copiedArchive(
    _ files: NativeStationTestStorage, label: String, pointer: ScriptSavePointer, world: Data
  ) throws -> URL {
    let copy = files.root.appendingPathComponent(label, isDirectory: true)
    try FileManager.default.copyItem(at: files.directory, to: copy)
    let file = copy.appendingPathComponent(files.url.lastPathComponent)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    try world.write(to: generation.appendingPathComponent("world.json"), options: .atomic)
    var hashes = pointer.hashes
    hashes["world.json"] = ScriptPackLibrary.hash(world)
    let changed = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    try JSONEncoder().encode(changed).write(to: file, options: .atomic)
    return file
  }
}
