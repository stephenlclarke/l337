import Foundation
import Testing

@testable import L337Core

/// Exact bundled fictional content only. These checks issue no case, consent or observation.
struct NativeCharterArchivePublishedContentTests {
  private var directory: URL {
    ScriptPackLibrary.bundledCourierDirectory
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("MissionPacks/native-unwritten-route")
  }

  private func bytes(_ name: String) throws -> Data {
    try ScriptPackLibrary.readFile(name, in: directory)
  }

  private func verifyResourceSizeBoundary() throws {
    let names = ["charter-archive-observations.json", "recovery-policy.json",
      "charter-calibration-models.json", "charter-archive-registry.json"]
      + ["a", "b", "c", "d", "e", "f"].map { "charter-archive-models-\($0).json" }
    for name in names {
      let raw = try Data(contentsOf: directory.appendingPathComponent(name))
      #expect(raw.count <= 262144)
      #expect(try bytes(name) == raw)
    }
    // Exercise the real regular-file reader on both sides of its existing limit.
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("charter-resource-bound-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let url = temporary.appendingPathComponent("boundary.json")
    var permitted = Data("{}".utf8)
    permitted.append(Data(repeating: 32, count: 262142))
    try permitted.write(to: url)
    #expect(try ScriptPackLibrary.readFile("boundary.json", in: temporary) == permitted)
    permitted.append(32)
    try permitted.write(to: url)
    #expect(throws: MissionPackError.self) {
      try ScriptPackLibrary.readFile("boundary.json", in: temporary)
    }
  }

  @Test func approvedPublishedCorpusLoadsAllCanonicalSourcesAndC01Content() throws {
    try verifyResourceSizeBoundary()
    let content = try NativeC01CharterArchiveApproval.load()
    #expect(content.archive.publication == .publishedSource)
    #expect(content.calibration.publication == .publishedSource)
    let registry = try NativeCharterArchiveRegistryApproval.load()
    let catalog = ScriptBaseClueCatalog.sources.sorted { $0.sourceID < $1.sourceID }
    #expect(registry.sources.map(\.sourceID) == catalog.map(\.sourceID))
    #expect(registry.sources.map(\.clueID) == catalog.map(\.clueID))
    #expect(registry.sources.count == 64)
    let records = registry.sources.flatMap(\.observations)
    #expect(records.count == 192 && Set(records.map(\.recordID)).count == 192)
    let meridian = try #require(registry.source(for: "l337.glass-meridian"))
    #expect(meridian.archiveSHA256 == content.archiveSHA256)
    #expect(meridian.calibrationSHA256 == content.calibrationSHA256)
    #expect(registry.provenance.corpusRevision ==
      "canonical64-charter-source-proposals-v4-explicit-specification-context")
  }

  @Test func publishedNonC01RolesKeepConsentSignaturesAndIndependenceUnissued() throws {
    var count = 0
    for suffix in ["a", "b", "c", "d", "e", "f"] {
      let root = try #require(JSONSerialization.jsonObject(
        with: bytes("charter-archive-models-\(suffix).json")) as? [String: Any])
      #expect(root["publication"] as? String == "published-source")
      let groups = try #require(root["sourceGroups"] as? [String: [String: Any]])
      for group in groups.values {
        let roles = try #require(group["archiveDeclarations"] as? [[String: Any]])
        for role in roles {
          let signature = try #require(role["signatureApproval"] as? [String: Any])
          let consent = try #require(role["consentProposal"] as? [String: Any])
          let basis = try #require(role["independenceBasis"] as? [String: Any])
          #expect(signature["state"] as? String == "UNISSUED")
          #expect(consent["state"] as? String == "UNISSUED")
          #expect(basis["state"] as? String == "UNISSUED_REQUIRES_SUBSTANTIVE_SOURCE_REVIEW")
          let allowed = try #require(basis["allowedInput"] as? [String])
          #expect(!allowed.contains { $0.hasSuffix("/continuityCalibration") })
          let context = try #require(basis["publicSpecificationContext"] as? [String: Any])
          #expect(context["evidenceAuthority"] as? String ==
            "None. Actual input/channel provenance, case/measurement ownership, writer custody, signatures, consent and input independence remain separately required and unissued by this proposal.")
          count += 1
        }
      }
    }
    #expect(count == 189)
  }

  @Test func publishedC01PinsRefuseChangedArchiveAndCalibrationBytes() throws {
    let resources: [(String, NativeC01CharterArchiveApproval.Resource)] = [
      ("charter-archive-observations.json", .archive), ("recovery-policy.json", .calibration),
    ]
    for (name, resource) in resources {
      let original = try bytes(name)
      try NativeC01CharterArchiveApproval.validateResourceBytes(original, for: resource)
      var changed = original
      changed.append(32)
      #expect(throws: NativeC01CharterArchiveApproval.Failure.self) {
        try NativeC01CharterArchiveApproval.validateResourceBytes(changed, for: resource)
      }
    }
  }

  @Test func registryCandidateRefusesUnpublishedUnknownMissingAndDuplicateClaims() throws {
    let original = try bytes("charter-archive-registry.json")
    try NativeCharterArchiveRegistryApproval.validateCandidateBytes(original)
    let root = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    let sources = try #require(root["sources"] as? [[String: Any]])
    var unpublished = root
    unpublished["publication"] = "prospective"
    var unknown = root
    unknown["unissuedAuthority"] = true
    var missing = root
    missing["sources"] = Array(sources.dropLast())
    var duplicate = root
    var changedSources = sources
    var records = try #require(changedSources[0]["observations"] as? [[String: Any]])
    records[1]["recordID"] = records[0]["recordID"]
    changedSources[0]["observations"] = records
    duplicate["sources"] = changedSources
    for changed in [unpublished, unknown, missing, duplicate] {
      let data = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
      #expect(throws: NativeCharterArchiveRegistryApproval.Failure.self) {
        try NativeCharterArchiveRegistryApproval.validateCandidateBytes(data)
      }
    }
  }
}
