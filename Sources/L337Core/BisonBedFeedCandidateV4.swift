import Foundation

/// Distinct dd85 source extension over reviewed8fba. It reads conditional
/// definitions, never operating mass, apparatus observations or native receipts.
struct BisonBedFeedCandidateV4: Sendable {
  static let configurationID = "SH005-finite-bed-feed-source-v4"
  static let sourceCommit = "dd85bac509a0de7d98723918bcff5ec1eeafd024"
  static let sourceManifestSHA256 = "ef82791d7a01ce1f04e397baf527d35919475d8435642cf7c72c8b83428ed3fc"
  static let parentSourceCommit = "8fba148f2272e02ebd13377fc08f6487dc1f0c9e"
  static let thermalBaseCommit = "a81bba23c8114fd6441f01fe7afaa53d749be5fc"
  static let folderName = "BisonBedFeedCandidate"
  static let assetPins: [String: BisonCommissioningCandidateV3.AssetPin] = [
    "ADOPTED-CRITERIA.json": .init(bytes: 1047, sha256: "c263d20e29518fe05b5f17180b38c9c383733e355466b3bab793aca578a81b11"),
    "EXACT-DELTA.json": .init(bytes: 2286, sha256: "0d28d14bacdfb20c6b978d9438d5958783a74503470c165b0906a545bcdb45c1"),
    "INPUTS.json": .init(bytes: 5131, sha256: "6012815ca370bae63f8953e030abfeae49850e5f15dbfe152f1220c10bb20b72"),
    "PRIMARY-SOURCE-NOTES.json": .init(bytes: 1353, sha256: "b268fede7aeab064af1009123d7c78bd507b7670f632ee841fc67550fb4eb4cb"),
    "bed-feed-design.json": .init(bytes: 4015, sha256: "13eaddb1bad8461fadcdccd5da65103f869dace23f36e79d0c26042046d81023"),
    "bed-feed-results.json": .init(bytes: 12591, sha256: "10853a75e688ab55ef919640ee63e1b14fa3238d527f3b9ef7d922c9d942305b"),
    "candidate-source.json": .init(bytes: 2503, sha256: "37bd629c38ab3ee06f342590053c3d47c067ff41f25a7b27fd2de7c52cd147be"),
    "changed-load-controls.json": .init(bytes: 4255, sha256: "f837c13e5cfe040f7d04af7f6143b3d6914e9001554f8dc7c902162c358a88e7"),
    "rigid-source-delta.json": .init(bytes: 7414, sha256: "5d0f03909e4c7899a40dac0f18a8a03e39b68afb0a18c293a9023997b3bbc84f"),
  ]
  let parent: BisonCommissioningCandidateV3
  let header: Header
  let inputs: Inputs
  let primaryNotes: PrimaryNotes
  let design: Design
  let results: Results
  let rigid: Rigid
  let exactDelta: Delta
  let criteria: Criteria
  let contacts: Contacts

  private init(parent: BisonCommissioningCandidateV3, header: Header, inputs: Inputs,
    primaryNotes: PrimaryNotes, design: Design, results: Results, rigid: Rigid,
    exactDelta: Delta, criteria: Criteria, contacts: Contacts) {
    self.parent = parent
    self.header = header
    self.inputs = inputs
    self.primaryNotes = primaryNotes
    self.design = design
    self.results = results
    self.rigid = rigid
    self.exactDelta = exactDelta
    self.criteria = criteria
    self.contacts = contacts
  }
  static func resourceFolder() throws -> URL {
    guard let folder = Bundle.module.url(forResource: folderName, withExtension: nil) else { throw Refusal.resourceSet }
    return folder
  }
  static func load() throws -> Self {
    let folder = try resourceFolder()
    // Reuse the reviewed read-only regular-file/set checks. Each decoder still
    // verifies its own immutable pins, so arbitrary reader pins grant nothing.
    let assets = try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: assetPins)
    let parent = try BisonCommissioningCandidateV3.load()
    return try decode(assets, parent: parent)
  }
  static func decode(_ assets: [String: Data], parent: BisonCommissioningCandidateV3) throws -> Self {
    guard Set(assets.keys) == Set(assetPins.keys) else { throw Refusal.resourceSet }
    for (name, pin) in assetPins {
      guard let data = assets[name], data.count == pin.bytes, ScriptPackLibrary.hash(data) == pin.sha256 else {
        throw Refusal.resourceIdentity(name)
      }
    }
    guard BisonCommissioningCandidateV3.sourceCommit == parentSourceCommit,
      parent.header.id == BisonCommissioningCandidateV3.configurationID, !parent.sourceQualifiedForBirth else {
      throw Refusal.parentRevision
    }
    let decoder = JSONDecoder()
    func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
      guard let data = assets[name] else { throw Refusal.resourceSet }
      return try decoder.decode(type, from: data)
    }
    let value = try Self(parent: parent, header: decode(Header.self, "candidate-source.json"),
      inputs: decode(Inputs.self, "INPUTS.json"), primaryNotes: decode(PrimaryNotes.self, "PRIMARY-SOURCE-NOTES.json"),
      design: decode(Design.self, "bed-feed-design.json"), results: decode(Results.self, "bed-feed-results.json"),
      rigid: decode(Rigid.self, "rigid-source-delta.json"), exactDelta: decode(Delta.self, "EXACT-DELTA.json"),
      criteria: decode(Criteria.self, "ADOPTED-CRITERIA.json"), contacts: decode(Contacts.self, "changed-load-controls.json"))
    guard value.structuralSourceCoherence else { throw Refusal.incoherentDefinition }
    return value
  }
}
