import AppKit
import CryptoKit
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import L337Core
@testable import L337Mac

/// Explicit G1 test-source view only. Neither model is installed in a catalogue or actor.
@MainActor
struct OriginalFleetPairedRendererProbe {
  private struct Pin: Decodable { let path: String; let bytes: Int; let sha256: String }
  private struct Inputs: Decodable { let candidate: Pin; let reference: Pin; let criteria: Pin }
  private struct Row: Decodable {
    let id: String
    let name: String
    let family: String
    let objectKind: String
    let passedPreparedInputs: Inputs
  }
  private struct First: Decodable {
    let rows: [Row]
    let actualNativeReport: Pin
    let actualPreparedManifest: Pin
    let terminal: Pin
    let actualAudit: Pin
  }
  private struct Asset: Decodable {
    let file: String
    let bytes: Int
    let sha256: String
    let sourcePath: String?
    let sourceSHA256: String?
  }
  private struct Job: Decodable {
    let id: String
    let candidate: Asset
    let reference: Asset
    let criteria: Asset
  }
  private struct Prepared: Decodable { let jobs: [Job] }
  private struct Document: Decodable {
    let id: String
    let sourcePath: String
    let sourceSHA256: String
    let coordinateUnits: String?
    let nativeDesign: ShipDesign
  }
  private struct Part: Decodable {
    let name: String
    let vertexStart: Int
    let vertexCount: Int
    let faceStart: Int
    let faceCount: Int
  }
  private struct Parts: Decodable { let names: [String]; let originalPartRanges: [Part] }
  private struct Criteria: Decodable { let id: String; let parts: Parts; let candidateParts: [Part] }
  private struct View {
    let name: String
    let pitch: Double
    let yaw: Double
    let style: ShipDisplayStyle
  }
  private enum Failure: Error { case invalid(String) }
  private let firstSHA = "8d2e6a7f21600065fe8901efe03b74ad45230f528aaa0243e99420495532453d"
  private let dependencySHA = "bc340a863b97fd4ae99da161104e86add0e1d216460c11336306e58cd1f9757b"

  private func digest(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }
  private func read(_ pin: Pin, maximum: Int = 8 * 1024 * 1024) throws -> Data {
    guard (1...maximum).contains(pin.bytes) else { throw Failure.invalid("Input bound") }
    let url = URL(fileURLWithPath: pin.path)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw Failure.invalid("Input must be a regular non-symlink file")
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let bytes = try handle.read(upToCount: pin.bytes + 1) ?? Data()
    guard bytes.count == pin.bytes, digest(bytes) == pin.sha256 else {
      throw Failure.invalid("Input changed: " + pin.path)
    }
    return bytes
  }
  private func document(_ bytes: Data, id: String, asset: Asset) throws -> Document {
    let value = try JSONDecoder().decode(Document.self, from: bytes)
    try requireIdentity(value, id: id, asset: asset)
    return value
  }
  private func requireIdentity(_ value: Document, id: String, asset: Asset) throws {
    guard value.id == id, value.sourcePath == asset.sourcePath,
      value.sourceSHA256 == asset.sourceSHA256
    else { throw Failure.invalid("Cross-member or provenance mismatch") }
  }
  private func matches(_ pin: Pin, _ asset: Asset, suffix: String) -> Bool {
    pin.bytes == asset.bytes && pin.sha256 == asset.sha256
      && pin.path.hasSuffix("/" + suffix) && asset.file == suffix
  }
  private func displayMesh(_ raw: Mesh, scale: Double) -> Mesh {
    // One reference-origin scale is shared by both sides; never use showroomNormalised.
    Mesh(vertices: raw.vertices.map { $0 * scale }, faces: raw.faces, details: raw.details,
      materials: raw.materials, faceMaterials: raw.faceMaterials, faceTextures: raw.faceTextures,
      preserveWinding: true)
  }
  private func requireTextures(_ mesh: Mesh, design: ShipDesign) throws {
    let declaredMapped = (design.faceTextures ?? []).filter { $0.texture >= 0 }.count
    guard mesh.faceTextures.compactMap({ $0 }).count >= declaredMapped else {
      throw Failure.invalid("Declared original UV/texture mappings did not resolve")
    }
    for asset in Set(mesh.faceTextures.compactMap { $0?.asset }) {
      guard ShipTextureAssets.pixels(for: asset) != nil else {
        throw Failure.invalid("Required native texture missing: " + asset)
      }
    }
  }
  private func measure(_ mesh: Mesh, faces: Range<Int>) throws -> [String: Any] {
    guard faces.lowerBound >= 0, faces.upperBound <= mesh.faces.count else {
      throw Failure.invalid("Own component face range")
    }
    var area = 0.0
    var volume = 0.0
    var uvArea = 0.0
    var materialAreas: [Int: Double] = [:]
    var texturedFaces = 0
    for index in faces {
      let face = mesh.faces[index]
      guard face.count >= 3 else { throw Failure.invalid("Face arity") }
      let texture = mesh.faceTextures.indices.contains(index) ? mesh.faceTextures[index] : nil
      if texture != nil { texturedFaces += 1 }
      for fan in 1..<(face.count - 1) {
        let a = mesh.vertices[face[0]]
        let b = mesh.vertices[face[fan]]
        let c = mesh.vertices[face[fan + 1]]
        let triangleArea = (b - a).cross(c - a).length / 2
        area += triangleArea
        volume += a.dot(b.cross(c)) / 6
        if mesh.faceMaterials.indices.contains(index) {
          materialAreas[mesh.faceMaterials[index], default: 0] += triangleArea
        }
        if let texture {
          let uv = texture.uv
          guard uv.count == face.count else { throw Failure.invalid("UV range") }
          let p = uv[0], q = uv[fan], r = uv[fan + 1]
          uvArea += abs((q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])) / 2
        }
      }
    }
    guard [area, volume, uvArea].allSatisfy(\.isFinite) else {
      throw Failure.invalid("Nonfinite descriptive surface measurement")
    }
    return ["surfaceAreaSourceUnitsSquared": area, "signedVolumeSourceUnitsCubed": volume,
      "UVTriangleAreaSum": uvArea, "texturedFaces": texturedFaces,
      "materialSurfaceAreas": materialAreas.keys.sorted().map { key -> [String: Any] in
        ["index": key, "name": mesh.materials[key].name, "area": materialAreas[key]!]
      }, "scope": "All faces in own range; descriptive only, no tolerance or fidelity/physical PASS"]
  }
  private func components(_ mesh: Mesh, parts: [Part]) throws -> [[String: Any]] {
    try parts.enumerated().map { index, part in
      let (end, overflow) = part.faceStart.addingReportingOverflow(part.faceCount)
      guard !overflow, part.faceStart >= 0, part.faceCount > 0, end <= mesh.faces.count else {
        throw Failure.invalid("Own component range overflow")
      }
      return ["index": index, "name": part.name, "vertexStart": part.vertexStart,
        "vertexCount": part.vertexCount, "faceStart": part.faceStart, "faceCount": part.faceCount,
        "measurement": try measure(mesh, faces: part.faceStart..<end)]
    }
  }
  private func frame(reference: Mesh, candidate: Mesh, view: View, game: borrowing Game) throws -> (Frame, [Int]) {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 2048, height: 1024)
    var body = SpaceBody(id: -1, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: view.pitch, roll: 0, yaw: view.yaw)
    var clippedVertices: [Int] = []
    for (index, mesh) in [reference, candidate].enumerated() {
      frame.flightClip = .init(x: Double(index * 1024 + 16), y: 64, width: 992, height: 920)
      let projection = FlightProjection(center: .init(Double(index * 1024 + 512), 524), focal: 1200)
      let clip = frame.flightClip
      var outside = 0
      for vertex in mesh.vertices {
        let point = body.modelVector(vertex) + body.position
        let projected = projection.point(point)
        if point.z < 1 || projected.x < clip.x || projected.x > clip.maxX - 1
          || projected.y < clip.y || projected.y > clip.maxY - 1 { outside += 1 }
      }
      clippedVertices.append(outside)
      let count = frame.graphics.count
      Display.draw(body, game: game, into: &frame, projection: projection, mesh: mesh, screen: .front)
      guard frame.graphics.count > count else { throw Failure.invalid("Native renderer emitted no geometry") }
    }
    frame.flightClip = frame.canvas
    frame.label("OWN ORIGINAL REFERENCE", 24, 20, scale: 2, ink: .cyan)
    frame.label("ACTUAL CACHED CANDIDATE", 1048, 20, scale: 2, ink: .yellow)
    frame.label("SAME CAMERA AND ORIGIN SCALE / INSPECTION ONLY", 24, 998, scale: 2, ink: .white)
    return (frame, clippedVertices)
  }

  @Test func actual55PairedOwnSourceRendererAndFeatureEvidenceWithoutAdoption() throws {
    let environment = ProcessInfo.processInfo.environment
    let firstPath = try #require(environment["L337_FLEET_RENDER_FIRST"])
    let outputPath = try #require(environment["L337_FLEET_RENDER_OUTPUT_ROOT"])
    let dependencyPath = try #require(environment["L337_FLEET_C36_DEPENDENCY"])
    let firstBytes = try read(.init(path: firstPath, bytes: 486939, sha256: firstSHA), maximum: 1024 * 1024)
    let input = try JSONDecoder().decode(First.self, from: firstBytes)
    let rawFirst = try #require(JSONSerialization.jsonObject(with: firstBytes) as? [String: Any])
    let rawRows = try #require(rawFirst["rows"] as? [[String: Any]])
    let output = URL(fileURLWithPath: outputPath, isDirectory: true).resolvingSymlinksInPath().standardizedFileURL
    try #require(!FileManager.default.fileExists(atPath: output.path))
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath()
    let protectedRoots = [source.path, URL(fileURLWithPath: firstPath).deletingLastPathComponent().path,
      URL(fileURLWithPath: input.actualPreparedManifest.path).deletingLastPathComponent().path,
      URL(fileURLWithPath: input.terminal.path).deletingLastPathComponent().path,
      URL(fileURLWithPath: input.actualNativeReport.path).deletingLastPathComponent().path]
    for protected in protectedRoots {
      try #require(output.path != protected && !output.path.hasPrefix(protected + "/"))
    }
    let ids = ["SH125","SH124","SH161","SH021","SH048","SH071","SH072","SH073","SH087","SH086","SH088","SH089","SH092","SH105","SH106","SH066","SH128","SH136","SH137","SH138","SH139","SH063","SH165","SH167","SH163","SH169","SH170","SH142","SH148","SH168","SH050","SH051","SH096","SH020","SH049","SH097","SH157","SH158","SH159","SH160","SH015","SH022","SH023","SH024","SH107","SH166","SH082","SH151","SH010","SH011","SH149","SH152","SH153","SH154","SH155"]
    try #require(input.rows.count == 55 && Set(input.rows.map(\.id)) == Set(ids))
    // Authenticate the passed evidence and all165 raw assets before decoding any model.
    _ = try read(input.terminal)
    _ = try read(input.actualAudit)
    let nativeReport = try read(input.actualNativeReport)
    let native = try #require(JSONSerialization.jsonObject(with: nativeReport) as? [String: Any])
    try #require(native["failures"] as? Int == 0 && native["acceptedHulls"] as? Int == 0)
    let prepared = try JSONDecoder().decode(Prepared.self, from: read(input.actualPreparedManifest))
    try #require(prepared.jobs.count == 55 && Set(prepared.jobs.map(\.id)) == Set(ids))
    let dependency = try read(.init(path: dependencyPath, bytes: 2532, sha256: dependencySHA))
    var blobs: [String: Data] = [:]
    var rawBytes = 0
    for row in input.rows {
      for pin in [row.passedPreparedInputs.candidate, row.passedPreparedInputs.reference, row.passedPreparedInputs.criteria] {
        let bytes = try read(pin)
        rawBytes += bytes.count
        try #require(rawBytes <= 128 * 1024 * 1024)
        blobs[pin.path] = bytes
        let protected = URL(fileURLWithPath: pin.path).deletingLastPathComponent().resolvingSymlinksInPath().path
        try #require(output.path != protected && !output.path.hasPrefix(protected + "/"))
      }
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    var emitted: [[String: Any]] = []
    var written = 0
    func record(_ relative: String, _ bytes: Data) throws {
      guard bytes.count <= 8 * 1024 * 1024, written + bytes.count <= 126 * 1024 * 1024 else {
        throw Failure.invalid("Existing 8MiB asset/128MiB total output budget")
      }
      try bytes.write(to: output.appendingPathComponent(relative), options: .withoutOverwriting)
      written += bytes.count
      emitted.append(["file": relative, "bytes": bytes.count, "sha256": digest(bytes)])
    }
    let views: [View] = [
      .init(name: "front", pitch: 0, yaw: 0, style: .shadedPanels),
      .init(name: "rear", pitch: 0, yaw: .pi, style: .shadedPanels),
      .init(name: "left", pitch: 0, yaw: .pi / 2, style: .shadedPanels),
      .init(name: "right", pitch: 0, yaw: -.pi / 2, style: .shadedPanels),
      .init(name: "top", pitch: .pi / 2, yaw: 0, style: .shadedPanels),
      .init(name: "bottom", pitch: -.pi / 2, yaw: 0, style: .shadedPanels),
      .init(name: "forward-oblique-wire", pitch: 0.35, yaw: 0.65, style: .whiteWireframe),
      .init(name: "rear-oblique-wire", pitch: -0.35, yaw: .pi + 0.65, style: .whiteWireframe),
    ]
    let firstFamily = ["SH157", "SH158", "SH159", "SH160", "SH161"]
    let order = firstFamily + ids.filter { !firstFamily.contains($0) }
    var game = Game(executive: false)
    game.screen = .front
    for id in order {
      let row = try #require(input.rows.first { $0.id == id })
      let job = try #require(prepared.jobs.first { $0.id == id })
      let rawRow = try #require(rawRows.first { $0["id"] as? String == id })
      let pins = row.passedPreparedInputs
      try #require(matches(pins.candidate, job.candidate, suffix: "candidates/" + id + ".json"))
      try #require(matches(pins.reference, job.reference, suffix: "references/" + id + ".json"))
      try #require(matches(pins.criteria, job.criteria, suffix: "criteria/" + id + ".json"))
      let candidate = try document(try #require(blobs[pins.candidate.path]), id: id, asset: job.candidate)
      let reference = try document(try #require(blobs[pins.reference.path]), id: id, asset: job.reference)
      if id == "SH157" {
        // Real-input negative regression reuses this decoded model, not another model pass.
        var rejectedCrossMember = false
        do { try requireIdentity(candidate, id: "SH158", asset: job.candidate) }
        catch Failure.invalid(_) { rejectedCrossMember = true }
        try #require(rejectedCrossMember)
      }
      try #require(candidate.coordinateUnits == reference.coordinateUnits)
      let criteriaBytes = try #require(blobs[pins.criteria.path])
      let criteria = try JSONDecoder().decode(Criteria.self, from: criteriaBytes)
      try #require(criteria.id == id && criteria.parts.names == criteria.candidateParts.map(\.name))
      let originalMesh = reference.nativeDesign.rawMesh
      let candidateMesh = candidate.nativeDesign.rawMesh
      try requireTextures(originalMesh, design: reference.nativeDesign)
      try requireTextures(candidateMesh, design: candidate.nativeDesign)
      let radius = try #require(originalMesh.vertices.map(\.length).max())
      try #require(radius.isFinite && radius > 0)
      let commonScale = 100 / radius
      try #require(commonScale.isFinite && commonScale > 0)
      let left = displayMesh(originalMesh, scale: commonScale)
      let right = displayMesh(candidateMesh, scale: commonScale)
      var actualViews: [[String: Any]] = []
      for view in views {
        game.commander.shipDisplayStyle = view.style
        let (pairedFrame, clipped) = try frame(reference: left, candidate: right, view: view, game: game)
        actualViews.append(["name": view.name, "pitch": view.pitch, "yaw": view.yaw,
          "style": view.style.rawValue, "referenceClippedVertices": clipped[0],
          "candidateClippedVertices": clipped[1], "clippingIsNotFidelityPASS": true])
        let image = try #require(imageForFrame(pairedFrame, width: 2048, height: 1024))
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        try record(id + "-" + view.name + ".png", data as Data)
      }
      var evidence: [String: Any] = ["id": id, "name": row.name, "objectKind": row.objectKind,
        "sourceRow": rawRow, "criteria": try JSONSerialization.jsonObject(with: criteriaBytes),
        "candidateSHA256": pins.candidate.sha256, "referenceSHA256": pins.reference.sha256,
        "criteriaSHA256": pins.criteria.sha256, "referenceOriginRadius": radius,
        "commonDisplayScale": commonScale,
        "candidateOriginRadius": try #require(candidateMesh.vertices.map(\.length).max()),
        "cameraZDisplayUnits": 400, "focalPixels": 1200,
        "canvas": [2048, 1024], "perSidePixels": [1024, 1024], "originTranslation": [0, 0, 0],
        "referenceMeasurements": try measure(originalMesh, faces: originalMesh.faces.indices),
        "candidateMeasurements": try measure(candidateMesh, faces: candidateMesh.faces.indices),
        "candidateComponents": try components(candidateMesh, parts: criteria.candidateParts),
        "referenceComponents": try components(originalMesh, parts: criteria.parts.originalPartRanges),
        "views": actualViews,
        "continuousFidelity": "UNISSUED_NO_METRIC_OR_TOLERANCE_NO_AUTOMATIC_PASS",
        "physical": "Dry-source input PASS retained; authentic installed/occupied/loaded/system inputs UNISSUED",
        "adoption": "UNISSUED; cached derivative provenance and runtime pending guards retained",
        "acceptedHulls": 0, "runtimeActivation": false]
      if let units = reference.coordinateUnits { evidence["coordinateUnits"] = units }
      else { evidence["coordinateUnits"] = NSNull() }
      if criteria.parts.originalPartRanges.isEmpty {
        evidence["referencePartOwnership"] = "UNISSUED in frozen descriptor; no inferred partition or substitute"
      }
      try record(id + "-features.json", JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]))
      print("Paired actual renderer emitted " + id + ": 8 PNG + own-source feature measurements; no adoption")
    }
    let result: [String: Any] = ["status": "ACTUAL_RENDERER_WITNESSES_AND_DESCRIPTIVE_FEATURES_ONLY",
      "inputFIRSTSHA256": firstSHA, "reusedNativeInputReportSHA256": input.actualNativeReport.sha256,
      "preparedManifestSHA256": input.actualPreparedManifest.sha256, "firstFamily": firstFamily,
      "rows": order, "files": emitted, "renderer": "Real Display.draw -> Frame -> NativeGraphics.imageForFrame CPU Quartz",
      "continuousFidelity": "UNISSUED", "installedOccupiedLoadedPhysical": "UNISSUED", "adoption": "UNISSUED",
      "C36ProviderDependency": try JSONSerialization.jsonObject(with: dependency),
      "acceptedHulls": 0, "runtimeActivation": false]
    try #require(emitted.count == 495)
    let bytes = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    try #require(bytes.count <= 2 * 1024 * 1024 && written + bytes.count <= 128 * 1024 * 1024)
    try bytes.write(to: output.appendingPathComponent("renderer-manifest.json"), options: .withoutOverwriting)
  }
}
