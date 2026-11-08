import AppKit
import CryptoKit
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import L337Core
@testable import L337Mac

@MainActor
struct SH023AssembledSourceQualificationTests {
  private struct Pin: Decodable {
    let path: String
    let bytes: Int
    let sha256: String
  }

  private struct Part: Decodable {
    let name: String
    let faceStart: Int
    let faceCount: Int
  }

  private struct Document: Decodable {
    let id: String
    let nativeDesign: ShipDesign
    let parts: [Part]?
  }

  private struct Ownership: Decodable {
    struct Original: Decodable {
      let originalPartRanges: [Part]
    }
    let parts: Original
    let candidateParts: [Part]
  }

  private struct Camera: Decodable {
    let name: String
    let pitch: Double
    let yaw: Double
    let style: ShipDisplayStyle
  }

  private struct Views: Decodable {
    let commonDisplayScale: Double
    let cameraZDisplayUnits: Double
    let focalPixels: Double
    let views: [Camera]
  }

  private struct Ray: Decodable {
    struct Hit: Decodable {
      let part: Int
      let distance: Double
    }
    let name: String
    let origin: [Double]
    let direction: [Double]
    let limit: Double
    let rule: String
    let sourcePart: Int?
    let hits: [String: Hit?]
  }

  private struct Witness: Decodable {
    let rays: [Ray]
    let isolatedWells: [Ray]
    let sourceTolerance: Double
    let referenceTriangleTests: Int
    let isolatedTriangleTests: Int
  }

  private struct Binding: Decodable {
    let assets: [String: Pin]
  }

  private func read<T: Decodable>(_ name: String, from binding: Binding, as type: T.Type) throws -> T {
    let pin = try #require(binding.assets[name])
    let url = URL(fileURLWithPath: pin.path)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    try #require(values.isRegularFile == true && values.isSymbolicLink != true)
    try #require(values.fileSize == pin.bytes && pin.bytes > 0 && pin.bytes <= 8 * 1024 * 1024)
    let bytes = try Data(contentsOf: url)
    try #require(bytes.count == pin.bytes)
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try #require(digest == pin.sha256)
    return try JSONDecoder().decode(type, from: bytes)
  }

  private func draw(
    _ meshes: [Mesh], camera: Camera, projection: Views, game: borrowing Game
  ) throws -> CGImage {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 3072, height: 1024)
    var body = SpaceBody(id: -1, hull: .cobra, position: .init(0, 0, projection.cameraZDisplayUnits))
    body.orientation.rotate(pitch: camera.pitch, roll: 0, yaw: camera.yaw)
    for (index, mesh) in meshes.enumerated() {
      frame.flightClip = .init(x: Double(index * 1024 + 16), y: 64, width: 992, height: 920)
      let lens = FlightProjection(
        center: .init(Double(index * 1024 + 512), 524), focal: projection.focalPixels)
      let clipped = mesh.vertices.filter { vertex in
        let point = body.modelVector(vertex) + body.position
        let screen = lens.point(point)
        return point.z < 1 || screen.x < frame.flightClip.x || screen.x > frame.flightClip.maxX - 1
          || screen.y < frame.flightClip.y || screen.y > frame.flightClip.maxY - 1
      }
      #expect(clipped.isEmpty, "Clipped SH023 model in \(camera.name), column \(index)")
      let before = frame.graphics.count
      Display.draw(body, game: game, into: &frame, projection: lens, mesh: mesh, screen: .front)
      #expect(frame.graphics.count > before)
    }
    frame.flightClip = frame.canvas
    frame.label("OWN ORIGINAL", 24, 20, scale: 2, ink: .cyan)
    frame.label("REJECTED 500", 1048, 20, scale: 2, ink: .yellow)
    frame.label("CANDIDATE 512", 2072, 20, scale: 2, ink: .white)
    return try #require(imageForFrame(frame, width: 3072, height: 1024))
  }

  private func write(_ image: CGImage, to url: URL) throws {
    let data = try #require(CFDataCreateMutable(nil, 0))
    let destination = try #require(
      CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    let bytes = data as Data
    try #require(bytes.count <= 8 * 1024 * 1024)
    try bytes.write(to: url, options: .withoutOverwriting)
  }

  private func checkRays(
    _ witness: Witness, keys: [String], meshes: [Mesh], parts: [[Part]], output: URL
  ) throws {
    var rows: [[String: Any]] = []
    var isolatedRows: [[String: Any]] = []
    let zero = Vector3(0, 0, 0)
    var referenceVisible: Set<Int> = []
    try #require(witness.rays.count == 53 && witness.referenceTriangleTests == 104728)
    try #require(witness.isolatedWells.count == 4 && witness.isolatedTriangleTests == 240)
    try #require(witness.sourceTolerance == 1e-8)
    for (asset, mesh) in meshes.enumerated() {
      let ids = parts[asset].indices
      try #require(ids.count == 27)
      let bodies = ids.map { SpaceBody(id: $0 + 1, hull: .cobra, position: zero) }
      var overrides: [Int: Mesh] = [:]
      var nextFace = 0
      for index in ids {
        let part = parts[asset][index]
        let end = part.faceStart + part.faceCount
        try #require(part.faceStart == nextFace && part.faceCount > 0 && end <= mesh.faces.count)
        overrides[index + 1] = Mesh(
          vertices: mesh.vertices, faces: Array(mesh.faces[part.faceStart..<end]),
          preserveWinding: true)
        nextFace = end
      }
      try #require(nextFace == mesh.faces.count)
      for ray in witness.rays {
        try #require(ray.origin.count == 3 && ray.direction.count == 3)
        let origin = Vector3(ray.origin[0], ray.origin[1], ray.origin[2])
        let direction = Vector3(ray.direction[0], ray.direction[1], ray.direction[2])
        let hit = GameplayRaycast.nearest(
          origin: origin, direction: direction, maxDistance: ray.limit,
          bodies: bodies, meshOverrides: overrides)
        let complete = GameplayRaycast.nearest(
          origin: origin, direction: direction, maxDistance: ray.limit,
          bodies: [SpaceBody(id: 1, hull: .cobra, position: zero)], meshOverrides: [1: mesh])
        let actualPart: Int?
        if case .body(let id) = hit?.target { actualPart = id - 1 } else { actualPart = nil }
        let expected = ray.hits[keys[asset]] ?? nil
        let source = ray.hits["reference"] ?? nil
        #expect(actualPart == expected?.part, "\(keys[asset]) \(ray.name) nearest part")
        if let hit, let expected, let complete {
          #expect(abs(hit.distance - expected.distance) <= witness.sourceTolerance)
          #expect(abs(hit.distance - complete.distance) <= witness.sourceTolerance)
        } else {
          #expect(hit == nil && expected == nil && complete == nil)
        }
        if asset == 0, ray.rule == "floor", let part = ray.sourcePart, let source,
          source.part == part, abs(source.distance - 0.1) <= witness.sourceTolerance
        {
          referenceVisible.insert(part)
        }
        if asset == 0 && ray.rule == "clearance" { #expect(hit == nil, "\(ray.name)") }
        if asset == 0 && ray.rule == "obstruction" {
          #expect(actualPart == ray.sourcePart, "\(ray.name) must see the fixed original prong")
        }
        if asset == 2 {
          if ray.rule == "clearance" {
            #expect(hit == nil, "\(ray.name) is blocked by the candidate")
          } else if ray.rule == "obstruction" || (ray.sourcePart != nil && source?.part == ray.sourcePart) {
            #expect(actualPart == source?.part, "\(ray.name) changed the original nearest surface")
            if let hit, let source {
              #expect(abs(hit.distance - source.distance) <= witness.sourceTolerance)
            }
          }
        }
        if let well = ray.sourcePart, [16, 17].contains(well) {
          let obstruction = try #require(source)
          #expect(obstruction.part != well)
          #expect(actualPart == obstruction.part, "\(ray.name) original assembled obstruction")
          if let hit { #expect(abs(hit.distance - obstruction.distance) <= witness.sourceTolerance) }
        }
        var row: [String: Any] = ["asset": keys[asset], "ray": ray.name]
        if let actualPart, let hit {
          row["part"] = actualPart
          row["distance"] = hit.distance
        }
        rows.append(row)
      }
      for ray in witness.isolatedWells {
        let well = try #require(ray.sourcePart)
        try #require([16, 17].contains(well) && ray.origin.count == 3 && ray.direction.count == 3)
        let origin = Vector3(ray.origin[0], ray.origin[1], ray.origin[2])
        let direction = Vector3(ray.direction[0], ray.direction[1], ray.direction[2])
        let hit = GameplayRaycast.nearest(
          origin: origin, direction: direction, maxDistance: ray.limit,
          bodies: [bodies[well]], meshOverrides: overrides)
        let expected = ray.hits[keys[asset]] ?? nil
        let source = ray.hits["reference"] ?? nil
        var row: [String: Any] = ["asset": keys[asset], "ray": ray.name, "isolatedPart": well]
        if ray.rule == "isolated-floor" {
          let actual = try #require(hit)
          let original = try #require(source)
          #expect(actual.target == .body(well + 1) && expected?.part == well && original.part == well)
          #expect(abs(actual.distance - original.distance) <= witness.sourceTolerance)
          #expect(abs(actual.distance - (expected?.distance ?? 0)) <= witness.sourceTolerance)
          row["distance"] = actual.distance
        } else {
          #expect(ray.rule == "isolated-mouth" && hit == nil && expected == nil && source == nil)
        }
        isolatedRows.append(row)
      }
    }
    let result: [String: Any] = [
      "queries": rows, "sourceVisibleWellParts": referenceVisible.sorted(),
      "isolatedWellQueries": isolatedRows, "exteriorFloorCoverage": "10 of 12; 16 and 17 unresolved",
    ]
    try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
      .write(to: output, options: .withoutOverwriting)
    #expect(referenceVisible == Set([1, 2, 3, 4, 6, 7, 8, 9, 14, 15]))
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["L337_SH023_QUALIFICATION_INPUT"] != nil))
  func originalRejectedAndClosedCandidateShareCamerasAndAssembledSourceWitnesses() throws {
    let environment = ProcessInfo.processInfo.environment
    let input = try #require(environment["L337_SH023_QUALIFICATION_INPUT"])
    let output = URL(fileURLWithPath: try #require(environment["L337_SH023_QUALIFICATION_OUTPUT"]))
    let binding = try JSONDecoder().decode(Binding.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
    let keys = ["reference", "rejected", "candidate"]
    let designs = try keys.map { try read($0, from: binding, as: Document.self) }
    let source = try read("criteria", from: binding, as: Ownership.self)
    let projection = try read("features", from: binding, as: Views.self)
    let witness = try read("witness", from: binding, as: Witness.self)
    try #require(designs.allSatisfy { $0.id == "SH023" && $0.nativeDesign.valid })
    try #require(designs.map { $0.nativeDesign.faces.count } == [964, 500, 512])
    try #require(projection.views.count == 8 && projection.commonDisplayScale == 53.74123318059566)
    try #require(projection.cameraZDisplayUnits == 400 && projection.focalPixels == 1200)
    let raw = designs.map { $0.nativeDesign.rawMesh }
    for (index, mesh) in raw.enumerated() {
      let count = (designs[index].nativeDesign.faceTextures ?? []).filter { $0.texture >= 0 }.count
      try #require(count > 0 && mesh.faceTextures.compactMap { $0 }.count == count)
      for asset in Set(mesh.faceTextures.compactMap({ $0?.asset })) {
        try #require(ShipTextureAssets.pixels(for: asset) != nil)
      }
    }
    let display = raw.map { mesh in
      Mesh(
        vertices: mesh.vertices.map { $0 * projection.commonDisplayScale }, faces: mesh.faces,
        details: mesh.details, materials: mesh.materials, faceMaterials: mesh.faceMaterials,
        faceTextures: mesh.faceTextures, preserveWinding: true)
    }
    let cameras = projection.views + projection.views.suffix(2).map {
      Camera(name: $0.name + "-shaded", pitch: $0.pitch, yaw: $0.yaw, style: .shadedPanels)
    }
    var game = Game(executive: false)
    game.screen = .front
    for camera in cameras {
      game.commander.shipDisplayStyle = camera.style
      let image = try draw(display, camera: camera, projection: projection, game: game)
      try write(image, to: output.appendingPathComponent(camera.name + ".png"))
    }
    let candidateParts = try #require(designs[2].parts)
    try checkRays(witness, keys: keys, meshes: raw,
      parts: [source.parts.originalPartRanges, source.candidateParts, candidateParts],
      output: output.appendingPathComponent("assembled-rays.json"))
  }

  @Test func defaultLoaderRetainsOnlyTheTwoAuthoredPeregrineRoles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let runtime = GameRuntime(game: Game(executive: false))
    await runtime.loadMissionPacks(directory: root.appendingPathComponent("mission-packs"))
    let errors = await runtime.loadDefaultScriptPacks(directory: root.appendingPathComponent("script-packs"))
    #expect(errors.isEmpty, "\(errors)")
    var game = await runtime.snapshot()
    let source = try OriginalFleetCurrentHullSource(id: "SH023")
    let design = try #require(OriginalScriptedPeregrine.design)
    let ship = try #require(ShipCatalogue.ship("SH023"))
    #expect(source.model.nativeDesign == ship.nativeDesign && source.nativeTriangles == 512)
    #expect(source.model.sourceSHA256 ==
      "5997060c2e36909aff5de387bd6d6a5676a13679ddeeedc66e2fafecd4d01b40")
    #expect(source.engineering.dryMassKilograms == 101208)
    #expect(abs(source.envelope.dimensions.z - 40) <= 1e-8)
    #expect(OriginalDetailedHullStage.blocksRuntime(ship.id) && ShipCatalogue.rawMesh(ship.id) == nil)
    let reference = OriginalScopedScriptedHull.peregrine.reference
    let hash = OriginalScriptedPeregrine.geometrySHA256
    #expect(!ScriptNPCModel.referenceValid(reference))
    let expected = [
      (ScriptPackLibrary.bundledCorridorDefenceDirectory, OriginalCorridorDefence.digest,
       OriginalCorridorDefence.npc),
      (ScriptPackLibrary.bundledVerifiedWarrantDirectory, OriginalVerifiedWarrant.digest,
       OriginalVerifiedWarrant.npc),
    ]
    for (directory, digest, definition) in expected {
      let pack = try ScriptPackLibrary.read(directory)
      try #require(pack.digest == digest && pack.manifest.npcs == [definition])
      #expect(pack.models[reference] == design)
      #expect(game.scriptPacks.contains { $0.manifest.stateID == pack.manifest.stateID && $0.digest == digest })
      let npc = try game.makeScriptNPC(definition, pack: pack, identity: UUID())
      #expect(npc.fit.models == [reference: hash])
      var body = SpaceBody(id: -1, hull: .cobra, position: .init(0, 0, 400))
      body.scriptNPC = npc
      #expect(!OriginalDetailedHullStage.blocksRuntime(body))
      let mesh = try #require(game.scriptNPCMesh(body))
      #expect(mesh.faces == design.faces && mesh.vertices == source.mesh.vertices)
      game.commander.scriptState.geometry[hash] = ship.design
      #expect(game.scriptNPCMesh(body) == nil && game.scriptNPCDisplayMesh(body) == nil)
      game.commander.scriptState.geometry[hash] = design
    }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let edited = root.appendingPathComponent("edited-pack")
    try FileManager.default.copyItem(at: ScriptPackLibrary.bundledVerifiedWarrantDirectory, to: edited)
    let script = edited.appendingPathComponent("scripts/main.lua")
    var bytes = try Data(contentsOf: script)
    bytes.append(Data("\n-- Changed pack identity.\n".utf8))
    try bytes.write(to: script)
    #expect(throws: MissionPackError.self) { try ScriptPackLibrary.read(edited) }
  }
}
