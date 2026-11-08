import AppKit
import CryptoKit
import Foundation
import ImageIO
import TOMLDecoder
import Testing
import UniformTypeIdentifiers

@testable import L337Core
@testable import L337Mac

// Explicit isolated formal qualification source view only; never a production actor issuer.
@MainActor
struct SH058SuccessorFormalQualificationTests {
  private let criteriaSHA = "d5eb36879b678ca262824e023cedb8c85c848da529cfb386c65bb34252787d3c"
  private let originalSHA = "13ef038a1ab17ffb777bd43f6a63b0a973bbea8bfd6076248cc14f8f1d49b2b8"
  private struct Pin: Decodable { let path: String; let bytes: Int; let sha256: String }
  private struct Input: Decodable {
    let phase: String
    let sourceID: String
    let sourceRoot: String
    let criteria: Pin
    let originalNative: Pin
    let originalDetailed: Pin
    let detailedParts: Pin
    let currentResource: Pin
    let successorSource: Pin
    let referenceProgram: Pin
    let expected: Pin
    let roleManifests: [Pin]
    let outputDirectory: String
  }
  private struct RenderCall: Decodable {
    let callID: String; let product: String; let view: String
    let style: ShipDisplayStyle; let camera: String; let output: String
  }
  private struct CollisionCall: Decodable {
    let callID: String; let product: String; let kind: String; let literalSourceFaceIndex: Int?; let feature: String?
    enum CodingKeys: String, CodingKey { case callID, product, literalSourceFaceIndex, feature; case kind = "class" }
  }
  private struct Requirements: Decodable {
    let materials: [String]; let textures: [String]; let sourceDeviationAllowance: String
  }
  private struct Engineering: Decodable {
    let totalReferenceQueries: Int; let totalSUTQueries: Int
    let totalReferenceTrianglePredicates: Int; let totalSUTTriangleCalls: Int
    let totalQueries: Int; let totalTriangleCalls: Int
  }
  private struct Criteria: Decodable {
    let schema: String; let sourceID: String; let numericalWorkAuthorized: Bool
    let renderSchedule: [RenderCall]; let collisionSchedule: [CollisionCall]
    let engineering: Engineering
    let sourceRequirements: Requirements
  }
  private struct Ray: Decodable {
    let origin: [Double]; let direction: [Double]; let range: Double; let radius: Double
  }
  private struct Witness: Decodable {
    let callID: String; let product: String; let kind: String; let faceIDs: [Int]
    let ray: Ray; let expectedDistance: Double?; let nearestFaceIDs: [Int]
    let comparisonTolerance: Double
  }
  private struct Camera: Decodable {
    let id: String; let right: [Double]; let up: [Double]; let eyeAxis: [Double]; let distance: Double
  }
  private struct Accounting: Decodable {
    let referenceQueries: Int; let referenceTrianglePredicates: Int
    let completedReferenceQueries: Int; let completedReferenceTrianglePredicates: Int
    let pointProjectionEvaluations: Int; let plannedSUTQueries: Int
    let plannedSUTTriangleCalls: Int; let totalPlannedQueries: Int; let totalPlannedTriangleCalls: Int
  }
  private struct AnalyticControl: Decodable { let id: String; let passed: Bool }
  private struct Expected: Decodable {
    let schema: String; let sourceID: String; let criteriaSHA256: String
    let originalSHA256: String; let referenceProgramSHA256: String
    let witnesses: [Witness]; let cameras: [Camera]; let analyticControls: [AnalyticControl]
    let accounting: Accounting
    let successorDesign: ShipDesign
    let successorVertexOrigins: [VertexOrigin]
    let opaqueCanopyFaces: [Int]
    let successorFeatureFaces: [String: Int]
  }
  private struct Original: Decodable { let nativeDesign: ShipDesign }
  private struct Detailed: Decodable { let design: ShipDesign }
  private struct SourcePart: Decodable { let name: String; let vertexStart: Int; let vertexCount: Int }
  private struct DetailedParts: Decodable { let design: [SourcePart] }
  private struct VertexOrigin: Decodable {
    enum Kind: String, Decodable { case originalNative, originalDetailed, computedBox }
    let kind: Kind
    let part: String
    let sourceIndex: Int?
  }
  private struct RenderIdentity {
    let callID: String
    let pixels: Data
    let format: [Int]
    let graphics: [Graphic]
    let worldGraphics: [Graphic]
  }
  private struct Edge: Hashable { let a: Int; let b: Int }
  private enum Failure: Error { case invalid(String) }

  private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  private func read(_ pin: Pin, maximum: Int = 8 * 1024 * 1024) throws -> Data {
    let url = URL(fileURLWithPath: pin.path)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true,
      (1...maximum).contains(pin.bytes)
    else { throw Failure.invalid("Input type or byte bound") }
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let bytes = try file.read(upToCount: pin.bytes + 1) ?? Data()
    guard bytes.count == pin.bytes, digest(bytes) == pin.sha256 else {
      throw Failure.invalid("Immutable input changed")
    }
    return bytes
  }
  private func vector(_ values: [Double]) throws -> Vector3 {
    guard values.count == 3, values.allSatisfy(\.isFinite) else {
      throw Failure.invalid("Nonfinite or invalid vector")
    }
    return .init(values[0], values[1], values[2])
  }
  private func topology(_ design: ShipDesign, faces: Int) throws {
    try #require(design.valid && design.faces.count == faces && design.vertices.count <= 1536)
    var edges: [Edge: Int] = [:]
    var used: Set<Int> = []
    for face in design.faces {
      try #require(face.count == 3 && face.allSatisfy { design.vertices.indices.contains($0) })
      let points = try face.map { try vector(design.vertices[$0]) }
      try #require((points[1] - points[0]).cross(points[2] - points[0]).length > 0)
      for index in face { used.insert(index) }
      for index in 0..<3 {
        edges[.init(a: face[index], b: face[(index + 1) % 3]), default: 0] += 1
      }
    }
    // Indices are never welded by position: independently closed/overlapping components remain distinct.
    try #require(used == Set(design.vertices.indices))
    try #require(edges.allSatisfy { edge, count in
      count == 1 && edges[.init(a: edge.b, b: edge.a)] == 1
    })
  }
  private func coordinatesMatch(_ actual: [Double], _ expected: [Double], kind: VertexOrigin.Kind) -> Bool {
    guard actual.count == 3 && expected.count == 3,
      actual.allSatisfy(\.isFinite) && expected.allSatisfy(\.isFinite) else { return false }
    if kind != .computedBox { return actual == expected }
    return zip(actual, expected).allSatisfy { abs($0.0 - $0.1) <= 1e-10 }
  }

  private func compareIndependentSuccessor(
    _ actual: ShipDesign, expected: ShipDesign, original: ShipDesign,
    detailed: ShipDesign, parts: [SourcePart], origins: [VertexOrigin]
  ) throws {
    try #require(actual.vertices.count == expected.vertices.count && actual.faces == expected.faces)
    try #require(origins.count == actual.vertices.count)
    try #require(actual.vertices.count >= original.vertices.count && actual.faces.count == 364)
    try #require(Array(actual.vertices.prefix(original.vertices.count)) == original.vertices)
    try #require(Array(actual.faces.prefix(original.faces.count)) == original.faces)
    let braces = parts.filter { $0.name == "raised command beam bridge centre brace" }
    let housings = parts.filter { $0.name == "instrumentation housing" }
    try #require(braces.count == 1 && housings.count == 2)
    let copiedParts = ["ROOF_BRACE": braces[0], "HOUSING_0": housings[0], "HOUSING_1": housings[1]]
    let boxes: Set<String> = ["DECK", "POST_NEG_X_NEG_Z", "POST_NEG_X_POS_Z", "POST_POS_X_NEG_Z",
      "POST_POS_X_POS_Z", "HOUSING_POST_0", "HOUSING_POST_1"]
    var copiedIndices: [String: Set<Int>] = [:]
    var computedCounts: [String: Int] = [:]
    for index in actual.vertices.indices {
      let origin = origins[index]
      switch origin.kind {
      case .originalNative:
        try #require(index < original.vertices.count && origin.part == "ORIGINAL_NATIVE")
        try #require(origin.sourceIndex == index)
        try #require(expected.vertices[index] == original.vertices[index])
      case .originalDetailed:
        try #require(index >= original.vertices.count)
        let part = try #require(copiedParts[origin.part])
        let sourceIndex = try #require(origin.sourceIndex)
        try #require(part.vertexCount > 0 && part.vertexStart >= 0)
        try #require(sourceIndex >= part.vertexStart && sourceIndex < part.vertexStart + part.vertexCount)
        try #require(detailed.vertices.indices.contains(sourceIndex))
        try #require(copiedIndices[origin.part, default: []].insert(sourceIndex).inserted)
        try #require(expected.vertices[index] == detailed.vertices[sourceIndex])
      case .computedBox:
        try #require(index >= original.vertices.count && boxes.contains(origin.part) && origin.sourceIndex == nil)
        computedCounts[origin.part, default: 0] += 1
      }
      try #require(coordinatesMatch(actual.vertices[index], expected.vertices[index], kind: origin.kind),
        "Independent successor vertex: \(index), \(origin.kind), \(origin.part)")
    }
    try #require(Set(computedCounts.keys) == boxes && computedCounts.values.allSatisfy { $0 == 8 })
    for (name, part) in copiedParts {
      try #require(copiedIndices[name] == Set(part.vertexStart..<(part.vertexStart + part.vertexCount)))
    }
    // Genuine source probes exercise exact-copy rejection without contact or renderer calls.
    for (kind, point) in [(VertexOrigin.Kind.originalNative, original.vertices[0]),
      (.originalDetailed, detailed.vertices[braces[0].vertexStart])] {
      var changed = point
      changed[0] = point[0].nextUp
      try #require(changed[0] != point[0] && abs(changed[0] - point[0]) <= 1e-10)
      #expect(coordinatesMatch(point, point, kind: kind))
      #expect(!coordinatesMatch(changed, point, kind: kind))
    }
    let boxIndex = try #require(origins.firstIndex { $0.kind == .computedBox })
    let boxPoint = expected.vertices[boxIndex]
    var arithmeticProbe = boxPoint
    arithmeticProbe[0] = boxPoint[0].nextUp
    try #require(arithmeticProbe[0] != boxPoint[0] && abs(arithmeticProbe[0] - boxPoint[0]) <= 1e-10)
    #expect(coordinatesMatch(arithmeticProbe, boxPoint, kind: .computedBox))
    let encoder = JSONEncoder()
    let actualObject = try JSONSerialization.jsonObject(with: encoder.encode(actual))
    let expectedObject = try JSONSerialization.jsonObject(with: encoder.encode(expected))
    var actualFields = try #require(actualObject as? [String: Any])
    var expectedFields = try #require(expectedObject as? [String: Any])
    actualFields.removeValue(forKey: "vertices")
    expectedFields.removeValue(forKey: "vertices")
    try #require((actualFields as NSDictionary).isEqual(expectedFields), "Independent exact topology/material/UV/source fields")
  }

  private func pendingRefusals(_ input: Input, resource: CatalogueShip) throws {
    try #require(OriginalDetailedHullStage.blocksRuntime("SH058"))
    #expect(throws: OriginalDetailedHullStage.Failure.physicalBudgetUnissued("SH058")) {
      try OriginalDetailedHullStage.requireRuntime("SH058")
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH058") == nil)
    #expect(ShipCatalogue.rawMesh("SH058") == nil)
    #expect(SalvageCatalogue.empProfile(catalogueShipID: "SH058") == nil)
    #expect(!ScriptNPCModel.referenceValid("catalogue:SH058"))
    #expect(throws: (any Error).self) { try ScriptPackLibrary.currentCatalogueNPCDesign("SH058") }
    var game = Game(executive: false)
    let before = game.commander
    let bodies = game.bodies
    #expect(game.shipTradeQuote(for: resource) == nil)
    #expect(throws: (any Error).self) { try game.commander.projectedEquipmentTransfer(to: "SH058") }
    #expect(game.commander == before && game.bodies == bodies)
    try #require(input.roleManifests.count == 2)
    var seen: Set<String> = []
    for pin in input.roleManifests {
      let manifest = try TOMLDecoder().decode(ScriptManifest.self, from: read(pin))
      let definition = try #require(manifest.npcs?.first { $0.model == "catalogue:SH058" })
      try #require(["pell-return-package", "w05-flight-recorder"].contains(definition.id))
      try #require(seen.insert(definition.id).inserted)
      #expect(definition.scale == 0.2 && definition.speed == 0 && definition.acceleration == 0)
      #expect(definition.pitch == 0 && definition.yaw == 0 && definition.roll == 0)
      #expect(definition.missiles == 0 && definition.fuel == 0 && !definition.ecm)
      #expect(definition.bounty == 0 && definition.drive == nil)
      #expect((definition.lasers ?? []).isEmpty && (definition.components ?? []).isEmpty)
      #expect(!definition.valid) // Exact pending-source refusal; no actor/pack/receipt is forged.
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func nonactorSuccessorSourceCollisionAndRenderingUseFrozenIndependentSourceExpectations() throws {
    let environment = ProcessInfo.processInfo.environment
    // The executor binds this fresh run-owned directory before any input/model preflight.
    let outputPath = try #require(environment["L337_SH058_FORMAL_OUTPUT_DIRECTORY"])
    let storage = try SH058FileOperationJournalStorage(freshDirectory: outputPath,
      sourceRoot: FileManager.default.currentDirectoryPath)
    let output = storage.directory
    let journal = SH058OperationJournal(storage: storage)
    var queries = 0
    var primitiveCalls = 0
    var completed: Set<String> = []
    var activeOperation = "formal-entry"
    var activeProduct = "none"
    var activeStage = "preflight-input"
    var drawAttempts = 0, drawsCompleted = 0
    var imageAttempts = 0, imagesReturned = 0, imagesCompleted = 0
    var pngAttempts = 0, pngsCompleted = 0
    var completedDrawSlots: [String] = []
    var completedImageSlots: [String] = []
    var completedRenderSlots: [String] = []
    var comparedPairs: [String] = []
    var queriesCompleted = 0, triangleCallsCompleted = 0
    var queryIntentPublished = false
    var lastCompletedQuery: String?
    func checkpoint() throws {
      let progress: [String: Any] = ["operation": activeOperation, "product": activeProduct,
        "stage": activeStage,
        "triangleProgress": queryIntentPublished ? "CURRENT_QUERY_UNKNOWN_COUNTERS_ARE_COMPLETED_QUERY_PREFIX" : "COMPLETED_QUERY_PREFIX",
        "lastCompletedQueryID": lastCompletedQuery.map { $0 as Any } ?? NSNull(),
        "currentQueryIntent": queryIntentPublished,
        "totalRayQueries": queries, "totalTriangleCalls": primitiveCalls,
        "completedSUTQueries": queriesCompleted, "completedSUTTriangleCalls": triangleCallsCompleted,
        "drawAttempts": drawAttempts, "drawsCompleted": drawsCompleted,
        "imageAttempts": imageAttempts, "imagesReturned": imagesReturned, "imagesCompleted": imagesCompleted,
        "pngAttempts": pngAttempts, "pngsCompleted": pngsCompleted,
        "completedDrawSlotIDs": completedDrawSlots, "completedImageSlotIDs": completedImageSlots,
        "completedRenderSlotIDs": completedRenderSlots, "comparedPairIDs": comparedPairs,
        "sourceID": "SH058", "admission": false]
      try journal.checkpoint(progress)
    }
    try checkpoint()
    let inputPath = try #require(environment["L337_SH058_FORMAL_INPUT"])
    let inputSHA = try #require(environment["L337_SH058_FORMAL_INPUT_SHA256"])
    let inputFile = try FileHandle(forReadingFrom: URL(fileURLWithPath: inputPath))
    defer { try? inputFile.close() }
    let raw = try inputFile.read(upToCount: 262_145) ?? Data()
    try #require(raw.count <= 262_144 && digest(raw) == inputSHA)
    let input = try JSONDecoder().decode(Input.self, from: raw)
    try #require(input.phase == "PRODUCTION_COMPARISON" && input.sourceID == "SH058")
    try #require(URL(fileURLWithPath: input.outputDirectory).resolvingSymlinksInPath().path == output.path)
    try #require(URL(fileURLWithPath: input.sourceRoot).resolvingSymlinksInPath().path ==
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath).resolvingSymlinksInPath().path)
    activeStage = "preflight-criteria-and-reference"
    try checkpoint()
    let criteriaBytes = try read(input.criteria)
    try #require(digest(criteriaBytes) == criteriaSHA)
    let criteria = try JSONDecoder().decode(Criteria.self, from: criteriaBytes)
    try #require(criteria.schema == "SH058_SUCCESSOR_PHASED_FORMAL_V3" && criteria.sourceID == "SH058")
    // The criterion is an authoring proposal, never a source/actor/execution permission token.
    try #require(!criteria.numericalWorkAuthorized)
    try #require(criteria.renderSchedule.count == 36 && criteria.collisionSchedule.count == 239)
    try #require(Set(criteria.renderSchedule.map(\.callID)).count == 36)
    try #require(Set(criteria.collisionSchedule.map(\.callID)).count == 239)
    let referenceBytes = try read(input.expected)
    let expected = try JSONDecoder().decode(Expected.self, from: referenceBytes)
    try #require(expected.schema == "SH058_SUCCESSOR_EXPECTED_V3" && expected.sourceID == "SH058")
    try #require(expected.criteriaSHA256 == criteriaSHA && expected.originalSHA256 == originalSHA)
    let referenceProgram = try read(input.referenceProgram)
    try #require(digest(referenceProgram) == expected.referenceProgramSHA256)
    try #require(expected.analyticControls.count == 12 && expected.analyticControls.allSatisfy(\.passed))
    try #require(Set(expected.analyticControls.map(\.id)) == Set((0..<12).map { String(format: "ANALYTIC_%02d", $0) }))
    try #require(expected.accounting.referenceQueries == 251 && expected.accounting.referenceTrianglePredicates == 12849)
    try #require(expected.accounting.completedReferenceQueries == 251 && expected.accounting.completedReferenceTrianglePredicates == 12849)
    try #require(expected.accounting.pointProjectionEvaluations <= 12849 * 262)
    try #require(expected.accounting.plannedSUTQueries == 239 && expected.accounting.plannedSUTTriangleCalls == 12836)
    try #require(expected.accounting.totalPlannedQueries == 490 && expected.accounting.totalPlannedTriangleCalls == 25685)
    try #require(criteria.engineering.totalQueries == 490 && criteria.engineering.totalTriangleCalls == 25685)
    queries = expected.accounting.referenceQueries // Frozen prior reference work, not work rerun here.
    primitiveCalls = expected.accounting.referenceTrianglePredicates
    activeStage = "preflight-original-resource-and-model"
    try checkpoint()
    let originalBytes = try read(input.originalNative)
    try #require(digest(originalBytes) == originalSHA)
    // Product data is a distinct object/decoder from the independent Decimal reference loader.
    let original = try TOMLDecoder().decode(Original.self, from: originalBytes).nativeDesign
    let resourceBytes = try read(input.currentResource)
    let resource = try TOMLDecoder().decode(CatalogueShip.self, from: resourceBytes)
    try #require(resource.id == "SH058" && resource.name == "Muskox")
    try OriginalDetailedHullStage.authenticate(resource, bytes: resourceBytes)
    activeStage = "preflight-showroom-model"
    try checkpoint()
    let current = try OriginalFleetShowroomModels.model(for: "SH058")
    let contract = try #require(OriginalFleetR3Data.contract(for: "SH058"))
    let registration = try #require(OriginalDetailedHullStage.registration(for: "SH058"))
    let successorBytes = try read(input.successorSource)
    let selectedSource = try TOMLDecoder().decode(Original.self, from: successorBytes).nativeDesign
    try #require(current.sourceSHA256 == input.successorSource.sha256)
    try #require(current.sourcePath == "docs/fleet-design-v2/successors/SH058-support-v1.toml")
    try #require(current.coordinateUnits == "metres" && current.nativeDesign.faces.count == 364)
    try #require(registration.sourceNativeFaces == 364 && registration.nativeSourceSHA256 == current.sourceSHA256)
    try #require(contract.referencedGeometrySHA256 == originalSHA)
    try #require(contract.id == "SH058" && contract.name == "Muskox" && contract.family == "muskox")
    try #require(resource.game == contract.performance && !resource.catalogue.playerFlyable)
    try #require(!resource.catalogue.normalPurchaseEligible && resource.catalogue.purchasePolicy == .pendingFabrication)
    try #require(registration.physicalRecordSHA256 == nil)
    try #require(registration.physicalStatus == "UNISSUED_SOURCE_MOMENT_CONSISTENCY_STOP")
    try #require(OriginalFleetPhysicalData.registrations["SH058"] == nil)
    #expect(throws: OriginalFleetPhysicalData.Failure.unissued("SH058")) {
      try OriginalFleetPhysicalData.record(for: "SH058")
    }
    #expect(throws: OriginalFleetPhysicalData.Failure.unissued("SH058")) {
      try OriginalFleetCurrentHullSource(id: "SH058")
    }
    try #require(Set(original.materials?.map(\.name) ?? []) == Set(criteria.sourceRequirements.materials))
    try #require(Set(original.textures?.map(\.asset) ?? []) == Set(criteria.sourceRequirements.textures))
    try #require(criteria.sourceRequirements.sourceDeviationAllowance == "Only declared new opaque deck/four base posts/two housing posts and exact detailed brace/two housing transplants, plus lower canopy material/UV replacement. Original native vertices/faces and every unaffected field remain exact. New source-derived coordinates allow <=1e-10 metre serialization/IEEE arithmetic discrepancy, not a shape/clearance/physics deviation. All topology/material/UV/source metadata exact. No historical support claim or physical authority.")
    try #require(resource.nativeHull == nil && resource.nativeCombat == nil)
    let resourceDesign = try #require(resource.nativeDesign)
    try #require(resourceDesign == selectedSource && resourceDesign == current.nativeDesign)
    let detailed = try TOMLDecoder().decode(Detailed.self, from: read(input.originalDetailed)).design
    let detailedParts = try JSONDecoder().decode(DetailedParts.self, from: read(input.detailedParts)).design
    activeStage = "preflight-source-comparison"
    try checkpoint()
    try compareIndependentSuccessor(current.nativeDesign, expected: expected.successorDesign, original: original,
      detailed: detailed, parts: detailedParts, origins: expected.successorVertexOrigins)
    try #require(!expected.opaqueCanopyFaces.isEmpty)
    try #require(expected.opaqueCanopyFaces.allSatisfy { original.faces.indices.contains($0) })
    try #require(expected.opaqueCanopyFaces.allSatisfy { current.nativeDesign.faceMaterials?[$0] == 1 })
    try topology(original, faces: 244)
    try topology(current.nativeDesign, faces: 364)
    try #require(current.displayMesh.vertices == current.nativeDesign.rawMesh.vertices)
    try #require(current.displayMesh.faces == current.nativeDesign.faces)
    activeStage = "preflight-pending-refusals"
    try checkpoint()
    try pendingRefusals(input, resource: resource)

    activeStage = "preflight-scaled-mesh"
    try checkpoint()
    let scaled = Mesh(
      vertices: current.displayMesh.vertices.map { $0 * 0.2 }, faces: current.displayMesh.faces,
      details: current.displayMesh.details, materials: current.displayMesh.materials,
      faceMaterials: current.displayMesh.faceMaterials, faceTextures: current.displayMesh.faceTextures,
      preserveWinding: true)
    let meshes: [String: Mesh] = ["ORIGINAL_NATIVE": original.rawMesh, "CURRENT_NATIVE": current.displayMesh, "CURRENT_NATIVE_0_2": scaled]
    let schedule = Dictionary(uniqueKeysWithValues: criteria.collisionSchedule.map { ($0.callID, $0) })
    try #require(expected.witnesses.count == 239 && Set(expected.witnesses.map(\.callID)) == Set(schedule.keys))
    var collisionResults: [[String: Any]] = []
    for witness in expected.witnesses {
      activeOperation = witness.callID
      activeProduct = witness.product
      activeStage = "collision-preflight"
      try checkpoint()
      let slot = try #require(schedule[witness.callID])
      try #require(slot.product == witness.product && slot.kind == witness.kind && completed.insert(witness.callID).inserted)
      let mesh = try #require(meshes[witness.product])
      let isolated = witness.kind == "ISOLATED_ORIGINAL_FACE_CONTROL" || witness.kind == "ISOLATED_SUCCESSOR_FEATURE_CONTROL"
      let requiredFaces = isolated ? 1 : (witness.product == "ORIGINAL_NATIVE" ? 244 : 364)
      try #require(witness.faceIDs.count == requiredFaces && Set(witness.faceIDs).count == requiredFaces)
      if witness.kind == "ISOLATED_ORIGINAL_FACE_CONTROL" {
        let index = try #require(slot.literalSourceFaceIndex)
        try #require(witness.faceIDs == [index])
      } else if witness.kind == "ISOLATED_SUCCESSOR_FEATURE_CONTROL" {
        let feature = try #require(slot.feature)
        let index = try #require(expected.successorFeatureFaces[feature])
        try #require(witness.faceIDs == [index])
      } else { try #require(witness.faceIDs == Array(0..<requiredFaces)) }
      try #require(witness.faceIDs.allSatisfy { mesh.faces.indices.contains($0) })
      try #require(queries < 490 && queries < 494)
      queries += 1
      queryIntentPublished = true
      activeStage = "collision-query-intent"
      try checkpoint()
      let origin = try vector(witness.ray.origin)
      let direction = try vector(witness.ray.direction)
      try #require(abs(direction.length - 1) <= 1e-14)
      try #require(witness.ray.range.isFinite && witness.ray.range > 0 && witness.ray.radius.isFinite && witness.ray.radius >= 0)
      try #require(abs(witness.comparisonTolerance - (1e-8 + witness.ray.range * 1e-10)) <= 1e-20)
      var hits: [(Double, Int)] = []
      for faceIndex in witness.faceIDs {
        try #require(primitiveCalls < 25685 && primitiveCalls < 120536)
        activeStage = "production-triangle-kernel"
        primitiveCalls += 1 // Immediately before EVERY real production triangle-kernel call.
        // Keep exact in-memory accounting; no per-triangle disk publication.
        let face = mesh.faces[faceIndex]
        let hit = ScriptSweptCollision.triangle(
          origin: origin, direction: direction, range: witness.ray.range, radius: witness.ray.radius,
          a: mesh.vertices[face[0]], b: mesh.vertices[face[1]], c: mesh.vertices[face[2]])
        triangleCallsCompleted += 1
        if let hit { try #require(hit.isFinite); hits.append((hit, faceIndex)) }
      }
      queriesCompleted += 1
      lastCompletedQuery = witness.callID
      queryIntentPublished = false
      activeStage = "collision-result-comparison"
      try checkpoint()
      let actual = hits.map(\.0).min()
      try #require((actual == nil) == (witness.expectedDistance == nil), "SH058 collision class: \(witness.callID)")
      if let wanted = witness.expectedDistance, let actual {
        try #require(abs(actual - wanted) <= witness.comparisonTolerance, "SH058 nearest distance: \(witness.callID); actual=\(actual), expected=\(wanted)")
        let actualTies = Set(hits.filter { abs($0.0 - actual) <= witness.comparisonTolerance }.map(\.1))
        try #require(actualTies == Set(witness.nearestFaceIDs), "SH058 nearest ties: \(witness.callID)")
      } else { try #require(witness.nearestFaceIDs.isEmpty) }
      collisionResults.append(["callID": witness.callID, "product": witness.product, "passed": true])
    }
    try #require(completed == Set(schedule.keys) && queries == 490 && primitiveCalls == 25685)
    let cameras = Dictionary(uniqueKeysWithValues: expected.cameras.map { ($0.id, $0) })
    let views = ["FRONT_POS_Z", "REAR_NEG_Z", "PORT_NEG_X", "STARBOARD_POS_X", "DORSAL_POS_Y", "VENTRAL_NEG_Y"]
    try #require(Set(cameras.keys) == Set(views))
    let expectedPairs = Set(["ORIGINAL_NATIVE", "CURRENT_NATIVE"].flatMap { product in
      views.flatMap { view in ShipDisplayStyle.allCases.map { product + ":" + view + ":" + $0.rawValue } }
    })
    try #require(Set(criteria.renderSchedule.map { $0.product + ":" + $0.view + ":" + $0.style.rawValue }) == expectedPairs)
    var renderIDs: Set<String> = []
    var renderResults: [[String: Any]] = []
    var originals: [String: RenderIdentity] = [:] // At most18 x4MiB pixels; release each matched pair.
    var pairResults: [[String: Any]] = []
    var game = Game(executive: false)
    game.commander.shipDisplayStyle = .shadedPanels
    let before = game.commander
    let bodiesBefore = game.bodies
    for call in criteria.renderSchedule {
      activeOperation = call.callID
      activeProduct = call.product
      activeStage = "render-transform-and-clip"
      try checkpoint()
      try #require(renderIDs.count < 36 && renderIDs.insert(call.callID).inserted)
      try #require(call.camera == "SOURCE_DECLARED_ENVELOPE_FIXED_CAMERA")
      let camera = try #require(cameras[call.view])
      let source = try #require(meshes[call.product])
      let right = try vector(camera.right), up = try vector(camera.up), axis = try vector(camera.eyeAxis)
      let projected = Mesh(
        vertices: source.vertices.map { .init($0.dot(right), $0.dot(up), camera.distance - $0.dot(axis)) },
        faces: source.faces, details: source.details, materials: source.materials,
        faceMaterials: source.faceMaterials, faceTextures: source.faceTextures, preserveWinding: true)
      let projection = FlightProjection(center: .init(512, 512), focal: 1024)
      let clip = CanvasRect(x: 64, y: 64, width: 896, height: 896)
      try #require(projected.vertices.allSatisfy { $0.z >= 1 && clip.contains(projection.point($0)) }, "SH058 fixed camera clip: \(call.callID)")
      var frame = Frame()
      frame.responsive = true
      frame.rasterizeGraphics = false
      frame.canvas = .init(x: 0, y: 0, width: 1024, height: 1024)
      frame.flightClip = clip
      game.commander.shipDisplayStyle = call.style
      // Nil-physical render carrier only, as existing paired inspection. Explicit mesh prevents any hull lookup.
      let carrier = SpaceBody(id: -1, hull: .cobra, position: .init(0, 0, 0))
      try #require(carrier.physical == nil)
      activeStage = "Display.draw"
      drawAttempts += 1
      try checkpoint()
      Display.draw(carrier, game: game, into: &frame, projection: projection, mesh: projected, screen: .front)
      drawsCompleted += 1
      completedDrawSlots.append(call.callID)
      try #require(!frame.graphics.isEmpty)
      activeStage = "imageForFrame"
      imageAttempts += 1
      try checkpoint()
      let result = imageForFrame(frame, width: 1024, height: 1024) // Exactly one call per charged slot.
      imagesReturned += 1
      let image = try #require(result)
      imagesCompleted += 1
      completedImageSlots.append(call.callID)
      activeStage = "existing-image-pixel-and-line-identity"
      try checkpoint()
      let provider = try #require(image.dataProvider)
      let pixelStorage = try #require(provider.data)
      let pixels = pixelStorage as Data
      try #require(image.width == 1024 && image.height == 1024 && image.bitsPerComponent == 8 && image.bitsPerPixel == 32)
      try #require(pixels.count == image.bytesPerRow * image.height && pixels.count <= 4 * 1024 * 1024)
      let format = [image.width, image.height, image.bitsPerComponent, image.bitsPerPixel, image.bytesPerRow,
        Int(image.bitmapInfo.rawValue), Int(image.alphaInfo.rawValue), image.colorSpace?.numberOfComponents ?? -1,
        Int(image.colorSpace?.model.rawValue ?? -1)]
      let pairID = call.view + "__" + call.style.rawValue
      if call.product == "ORIGINAL_NATIVE" {
        try #require(!originals.keys.contains(pairID) && originals.count < 18)
        originals[pairID] = .init(callID: call.callID, pixels: pixels, format: format,
          graphics: frame.graphics, worldGraphics: frame.worldGraphics)
      } else {
        try #require(call.product == "CURRENT_NATIVE")
        let originalImage = try #require(originals[pairID], "Missing SH058 original image: \(pairID)")
        activeStage = "exact-original-current-pair-comparison"
        try checkpoint()
        try #require(originalImage.format == format)
        // Declared support/trim changes are expected; images need independent visual review.
        try #require(!comparedPairs.contains(pairID))
        comparedPairs.append(pairID)
        pairResults.append(["pairID": pairID, "originalCallID": originalImage.callID,
          "currentCallID": call.callID, "originalPixelSHA256": digest(originalImage.pixels),
          "successorPixelSHA256": digest(pixels), "declaredSourceDifferences": true,
          "pixelEqualityRequired": false, "visualReview": "PENDING"])
        originals.removeValue(forKey: pairID)
      }
      activeStage = "PNG-encoding"
      pngAttempts += 1
      try checkpoint()
      let data = NSMutableData()
      let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
      CGImageDestinationAddImage(destination, image, nil)
      try #require(CGImageDestinationFinalize(destination))
      pngsCompleted += 1
      try #require(call.output == URL(fileURLWithPath: call.output).lastPathComponent && call.output.hasSuffix(".png"))
      activeStage = "PNG-file-write"
      try checkpoint()
      try (data as Data).write(to: output.appendingPathComponent(call.output), options: .withoutOverwriting)
      completedRenderSlots.append(call.callID)
      renderResults.append(["callID": call.callID, "product": call.product, "view": call.view,
        "style": call.style.rawValue, "file": call.output, "sha256": digest(data as Data)])
    }
    try #require(renderIDs.count == 36 && drawAttempts == 36 && drawsCompleted == 36)
    try #require(imageAttempts == 36 && imagesReturned == 36 && imagesCompleted == 36)
    try #require(pngAttempts == 36 && pngsCompleted == 36 && completedRenderSlots.count == 36)
    let requiredPairs = Set(views.flatMap { view in ShipDisplayStyle.allCases.map { view + "__" + $0.rawValue } })
    try #require(Set(comparedPairs) == requiredPairs && comparedPairs.count == 18 && originals.isEmpty)
    activeStage = "final-pending-refusals"
    activeOperation = "final-pending-refusals"
    activeProduct = "none"
    try checkpoint()
    game.commander.shipDisplayStyle = before.shipDisplayStyle
    #expect(game.commander == before)
    #expect(game.bodies == bodiesBefore)
    try pendingRefusals(input, resource: resource)
    let result: [String: Any] = [
      "status": "SUCCESSOR_NONACTOR_ASSERTIONS_ONLY_VISUAL_R3_PHYSICAL_ROLE_REVIEW_PENDING_NO_ADMISSION",
      "criteriaSHA256": criteriaSHA, "expectedSHA256": input.expected.sha256,
      "originalSHA256": originalSHA, "referenceProgramSHA256": expected.referenceProgramSHA256,
      "totalRayQueries": queries, "totalTriangleCalls": primitiveCalls,
      "renderCalls": 36, "collision": collisionResults, "renders": renderResults,
      "originalSuccessorPairs": pairResults,
      "drawAttempts": drawAttempts, "drawsCompleted": drawsCompleted,
      "imageAttempts": imageAttempts, "imagesReturned": imagesReturned, "imagesCompleted": imagesCompleted,
      "pngAttempts": pngAttempts, "pngsCompleted": pngsCompleted,
      "scaledRenders": "DEFERRED_TO_REAL_ROLE_PHASE", "runtimeActivation": false,
      "renderCarrier": "Nil-physical Display.draw inspection adaptor; explicit own mesh every call. Cobra supplies only existing renderer ink fallback, never SH058 source identity/admission. Source palette/UV are checked from exact native material fields; actual images require independent visual review.",
      "R3OpaqueSupport": "REQUIRES_INDEPENDENT_SOURCE_FEATURE_AND_VISUAL_REVIEW; contact occupancy is not intent",
      "roleAdmission": "BLOCKED", "currentWriter": "BLOCKED", "acceptedHulls": 0,
    ]
    activeStage = "formal-receipt-write"
    try checkpoint()
    let receipt = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
    try receipt.write(to: output.appendingPathComponent("formal-receipt.json"), options: .withoutOverwriting)
    activeStage = "formal-return"
    try checkpoint()
  }
}
