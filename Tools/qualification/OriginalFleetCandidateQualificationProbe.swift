import CryptoKit
import Foundation
import Testing

@testable import L337Core

/// G1 explicitly composes this probe into its isolated L337CoreTests source view.
/// It is not a production source, default CI test, actor issuer or adoption approval.
struct OriginalFleetCandidateQualificationProbe {
  private struct Pin: Decodable {
    let file: String
    let bytes: Int
    let sha256: String
    let sourcePath: String?
    let sourceSHA256: String?
  }
  private struct Job: Decodable {
    let id: String
    let objectKind: String
    let r3SHA256: String
    let candidate: Pin
    let reference: Pin
    let criteria: Pin
  }
  private struct Input: Decodable {
    let schemaVersion: Int
    let kind: String
    let status: String
    let sourcePlanSHA256: String
    let jobs: [Job]
    let acceptedHulls: Int
    let runtimeActivation: Bool
  }
  private struct Part: Decodable {
    let name: String
    let vertexStart: Int
    let vertexCount: Int
    let faceStart: Int
    let faceCount: Int
  }
  private struct Parts: Decodable {
    let names: [String]
    let originalPartRanges: [Part]
    let exactFixedIndices: [Int]
  }
  private struct Criteria: Decodable {
    let id: String
    let objectKind: String
    let r3SHA256: String
    let parts: Parts
    let candidateParts: [Part]
  }
  private enum Failure: Error { case invalidInput(String) }
  private struct Edge: Hashable { let a: Int; let b: Int }

  private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  private func read(_ root: URL, _ pin: Pin, expectedFile: String) throws -> Data {
    guard pin.file == expectedFile, (1...(8 * 1024 * 1024)).contains(pin.bytes) else {
      throw Failure.invalidInput("Invalid inspection asset path/bound")
    }
    let url = root.appendingPathComponent(pin.file)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw Failure.invalidInput("Inspection asset is not a regular file")
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: pin.bytes + 1) ?? Data()
    guard data.count == pin.bytes, digest(data) == pin.sha256 else {
      throw Failure.invalidInput("Inspection asset bytes/hash changed")
    }
    return data
  }
  private func end(_ start: Int, _ count: Int, limit: Int) throws -> Int {
    let (value, overflow) = start.addingReportingOverflow(count)
    guard !overflow, start >= 0, count > 0, value <= limit else {
      throw Failure.invalidInput("Component range outside own native model")
    }
    return value
  }
  private func model(_ root: URL, _ pin: Pin, id: String, prefix: String) throws -> OriginalFleetShowroomModel {
    let data = try read(root, pin, expectedFile: prefix + "/" + id + ".json")
    let sourcePath = try #require(pin.sourcePath)
    let sourceSHA = try #require(pin.sourceSHA256)
    return try OriginalFleetShowroomModels.decode(data, entry: .init(
      id: id, file: pin.file, bytes: pin.bytes, sha256: pin.sha256,
      sourcePath: sourcePath, sourceSHA256: sourceSHA))
  }
  private func check(_ job: Job, root: URL) throws -> [String: Any] {
    let source = try #require(OriginalFleetR3Data.contract(for: job.id))
    try #require(source.sourceSHA256 == job.r3SHA256)
    let original = try OriginalFleetShowroomModels.model(for: job.id)
    let reference = try model(root, job.reference, id: job.id, prefix: "references")
    try #require(reference.sourcePath == original.sourcePath && reference.sourceSHA256 == original.sourceSHA256)
    try #require(reference.coordinateUnits == original.coordinateUnits && reference.nativeDesign == original.nativeDesign)
    let candidate = try model(root, job.candidate, id: job.id, prefix: "candidates")
    try #require(candidate.sourcePath == "actual-run/candidates/" + job.id + ".json")
    try #require(candidate.coordinateUnits == original.coordinateUnits)
    try #require(candidate.nativeDesign.valid) // Actual native material/appearance/UV decoder path.
    let design = candidate.nativeDesign
    var triangles = 0
    for face in design.faces {
      try #require(face.count >= 3)
      triangles += face.count - 2 // Policy counts fan triangles, never source polygons.
      try #require(triangles <= 512)
    }
    try #require(design.faces.allSatisfy { $0.count == 3 })
    var directed: [Edge: Int] = [:]
    var used = Set<Int>()
    for face in design.faces {
      for index in face { used.insert(index) }
      for i in 0..<3 { directed[Edge(a: face[i], b: face[(i + 1) % 3]), default: 0] += 1 }
      let p = face.map { Vector3(design.vertices[$0][0], design.vertices[$0][1], design.vertices[$0][2]) }
      try #require((p[1] - p[0]).cross(p[2] - p[0]).length > 0)
    }
    try #require(used == Set(design.vertices.indices))
    try #require(directed.allSatisfy { edge, count in
      count == 1 && directed[Edge(a: edge.b, b: edge.a)] == 1
    })
    try #require(design.vertices.count <= 1536)
    let criteriaData = try read(root, job.criteria, expectedFile: "criteria/" + job.id + ".json")
    let criteria = try JSONDecoder().decode(Criteria.self, from: criteriaData)
    try #require(criteria.id == job.id && criteria.objectKind == job.objectKind && criteria.r3SHA256 == job.r3SHA256)
    try #require(criteria.parts.names == criteria.candidateParts.map(\.name))
    var vertexEnd = 0
    var faceEnd = 0
    for part in criteria.candidateParts {
      try #require(part.vertexStart == vertexEnd && part.faceStart == faceEnd)
      vertexEnd = try end(part.vertexStart, part.vertexCount, limit: design.vertices.count)
      faceEnd = try end(part.faceStart, part.faceCount, limit: design.faces.count)
    }
    try #require(vertexEnd == design.vertices.count && faceEnd == design.faces.count)
    for index in criteria.parts.exactFixedIndices {
      try #require(criteria.candidateParts.indices.contains(index) && criteria.parts.originalPartRanges.indices.contains(index))
      let part = criteria.candidateParts[index]
      let old = criteria.parts.originalPartRanges[index]
      let v1 = try end(part.vertexStart, part.vertexCount, limit: design.vertices.count)
      let o1 = try end(old.vertexStart, old.vertexCount, limit: reference.nativeDesign.vertices.count)
      let f1 = try end(part.faceStart, part.faceCount, limit: design.faces.count)
      let q1 = try end(old.faceStart, old.faceCount, limit: reference.nativeDesign.faces.count)
      try #require(Array(design.vertices[part.vertexStart..<v1]) == Array(reference.nativeDesign.vertices[old.vertexStart..<o1]))
      let faces = design.faces[part.faceStart..<f1].map { $0.map { $0 - part.vertexStart } }
      let oldFaces = reference.nativeDesign.faces[old.faceStart..<q1].map { $0.map { $0 - old.vertexStart } }
      try #require(faces == oldFaces)
      let materials = try #require(design.faceMaterials)
      let oldMaterials = try #require(reference.nativeDesign.faceMaterials)
      try #require(Array(materials[part.faceStart..<f1]) == Array(oldMaterials[old.faceStart..<q1]))
      let uv = try #require(design.faceTextures)
      let oldUV = try #require(reference.nativeDesign.faceTextures)
      try #require(Array(uv[part.faceStart..<f1]) == Array(oldUV[old.faceStart..<q1]))
    }
    let binding = try #require(OriginalFleetPhysicalData.registrations[job.id])
    let record = try OriginalFleetPhysicalData.record(for: job.id) // Real source-record validation, not file presence.
    try #require(record.validates(source: binding))
    let raw = candidate.displayMesh
    try #require(raw.faces == design.faces && raw.materials == design.rawMesh.materials)
    let scale = binding.calibration.metresPerSourceUnit
    let physical = Mesh(vertices: raw.vertices.map { $0 * scale }, faces: raw.faces,
      details: raw.details, materials: raw.materials, faceMaterials: raw.faceMaterials,
      faceTextures: raw.faceTextures, preserveWinding: true)
    _ = try OriginalHullEnvelope(vertices: physical.vertices)
    // AABB/envelope and dry source-record checks are NOT continuous/occupied physical fidelity.
    try #require(OriginalDetailedHullStage.blocksRuntime(job.id))
    try #require(OriginalFleetRuntimeHullSource.source(for: job.id) == nil)
    let expectedRefusal: OriginalFleetCurrentHullSource.Failure
    if job.objectKind == "ship" {
      expectedRefusal = .inconsistentNativeSource(job.id)
    } else {
      try #require(job.id == "SH161" && job.objectKind == "station")
      expectedRefusal = .missingCurrentContract(job.id)
    }
    do {
      _ = try OriginalFleetCurrentHullSource(id: job.id, model: candidate)
      throw Failure.invalidInput("Unqualified cached provenance entered current hull source")
    } catch let refusal as OriginalFleetCurrentHullSource.Failure {
      try #require(refusal == expectedRefusal)
    }
    return ["id": job.id, "objectKind": job.objectKind, "fanTriangles": triangles,
      "status": "NATIVE_INPUT_SOURCE_CHECKS_ONLY_NOT_ADOPTION", "continuousFidelity": "UNISSUED",
      "physicalScope": "Original dry-source record only; occupied/loaded/system facts unissued",
      "candidateSHA256": job.candidate.sha256, "runtimeActivation": false]
  }

  @Test func cached55UseActualNativeDecodeMeshAndCalibrationWithoutAdoption() throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try #require(environment["L337_FLEET_QUALIFICATION_INPUT_ROOT"])
    let expected = try #require(environment["L337_FLEET_QUALIFICATION_MANIFEST_SHA256"])
    let reportPath = try #require(environment["L337_FLEET_QUALIFICATION_REPORT_ROOT"])
    let root = URL(fileURLWithPath: path, isDirectory: true)
    let report = URL(fileURLWithPath: reportPath, isDirectory: true)
    try #require(!FileManager.default.fileExists(atPath: report.path))
    let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath()
    let reportCanonical = report.resolvingSymlinksInPath().standardizedFileURL.path
    let inputCanonical = root.resolvingSymlinksInPath().standardizedFileURL.path
    try #require(reportCanonical != inputCanonical && !reportCanonical.hasPrefix(inputCanonical + "/"))
    try #require(reportCanonical != sourceRoot.path && !reportCanonical.hasPrefix(sourceRoot.path + "/"))
    let inputURL = root.appendingPathComponent("manifest.json")
    let values = try inputURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    try #require(values.isRegularFile == true && values.isSymbolicLink != true)
    let handle = try FileHandle(forReadingFrom: inputURL)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: 262145) ?? Data()
    try #require(data.count <= 262144 && digest(data) == expected)
    let input = try JSONDecoder().decode(Input.self, from: data)
    try #require(input.schemaVersion == 1 && input.kind == "original-fleet-candidate-qualification-inputs")
    try #require(input.status == "UNQUALIFIED_INSPECTION_INPUTS_ONLY" && input.acceptedHulls == 0 && !input.runtimeActivation)
    try #require(input.sourcePlanSHA256 == "2847c68d4328956b776cf89217b8b42c35990b4b0fea87bac39247fafe3dc01f")
    let ids = ["SH125","SH124","SH161","SH021","SH048","SH071","SH072","SH073","SH087","SH086","SH088","SH089","SH092","SH105","SH106","SH066","SH128","SH136","SH137","SH138","SH139","SH063","SH165","SH167","SH163","SH169","SH170","SH142","SH148","SH168","SH050","SH051","SH096","SH020","SH049","SH097","SH157","SH158","SH159","SH160","SH015","SH022","SH023","SH024","SH107","SH166","SH082","SH151","SH010","SH011","SH149","SH152","SH153","SH154","SH155"]
    try #require(input.jobs.count == 55 && Set(input.jobs.map(\.id)) == Set(ids))
    var observations: [[String: Any]] = []
    var failures = 0
    for job in input.jobs {
      do { observations.append(try check(job, root: root)) }
      catch {
        failures += 1
        observations.append(["id": job.id, "status": "REFUSED", "error": String(describing: error)])
      }
    }
    try FileManager.default.createDirectory(at: report, withIntermediateDirectories: false)
    let result: [String: Any] = ["status": "ACTUAL_NATIVE_INPUT_PROBE_ONLY_FIDELITY_AND_ADOPTION_UNQUALIFIED",
      "rows": observations, "failures": failures, "acceptedHulls": 0, "runtimeActivation": false]
    let encoded = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    try encoded.write(to: report.appendingPathComponent("native-input-report.json"), options: .withoutOverwriting)
    #expect(failures == 0)
  }
}
