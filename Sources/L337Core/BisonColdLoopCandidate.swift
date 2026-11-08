import Foundation

/// Authenticated b442 proposed moving mechanisms over exact f775/8bf baselines. There is
/// no runtime selector, activation or physical conversion here.
struct BisonColdLoopCandidate: Sendable {
  static let folderName = "BisonColdLoopCandidate"
  static let baselineSourceCommit = "8bf154948fa0609e1bf01776959bb2fbbe6432dd"
  static let passageSourceCommit = "f7755ce0cc0226360afc341760c2c9e418443f93"
  static let sourceCommit = "b442f551ad3bb7a4b53e70b13b47d979c0f1f753"
  static let passageManifestSHA256 = "f8c7a5859772a3447d0bc51a601222369029fc061c3101ee1b0c903b00cc7823"
  static let sourceManifestSHA256 = "ab783db42da613c4b63b7387ec0a2253b18b16ae2fbe90f0a39eb46ab326b49c"
  static let parentSourceCommit = "dd85bac509a0de7d98723918bcff5ec1eeafd024"
  static let assetPins: [String: BisonCommissioningCandidateV3.AssetPin] = [
    "ADOPTED-CRITERIA.json": .init(bytes: 1696, sha256: "1ef1d0dddb0f6c5b79366a8f90fbee97285a9d898ba8a4f19c35258313478e78"),
    "INPUTS.json": .init(bytes: 5252, sha256: "a8fd5d97a3c46770dbb4762464097ef2d556cb354de95f192763c77c8fdc809e"),
    "PRIMARY-SOURCE-NOTES.json": .init(bytes: 2495, sha256: "8e2ba88681125b672cdc9f3f11b7b818a6aea764e8cde6afcbabdbdef062f17c"),
    "finite-operation-requirements.json": .init(bytes: 3010, sha256: "7d0cf64a60f9af435b936be839c41569224ee7838b017840037421189addc416"),
    "cold-loop-design.json": .init(bytes: 6113, sha256: "b9b9c51a41f3fc2fef75bb8575ded23192be50fcf62f9e217731ebb6fde5de62"),
    "cold-loop-results.json": .init(bytes: 27697, sha256: "88f4bd9ddcda205b12ae246854fed22f16d94d48c3cf365b27ef967463ebfa37"),
    "cold-layout.json": .init(bytes: 65697, sha256: "e69e9bcb643a94777c05f8b4727cfaa607e1da9503ef0866fc16164c5d81028d"),
    "cold-source-delta.json": .init(bytes: 13964, sha256: "d9904fa044c3b8edc92cdcf98a0474e6b71c97f7e80a2a4e283dda65de0bc2f4"),
    "changed-load-controls.json": .init(bytes: 4352, sha256: "afc0e4a9256bbeae3d729e221a67f39706d15db6dd28430394f4bad49aa7e7a0"),
    "connected-passage-source.json": .init(bytes: 21910, sha256: "284c1c1512589721943a6475c834cdb0e34bab016f0e7c59ba1210f6b95caa95"),
    "connected-load-controls.json": .init(bytes: 4501, sha256: "efd31db8c84daba9123e1f2a8ef928d66f5bdec8592dcd92a9b5a9264f13403a"),
    "connected-passage-inputs.json": .init(bytes: 840, sha256: "0a3a01a74fd460f12efb0a7c5ad78f31f8436370811d8f617489642de7af7443"),
    "connected-passage-criteria.json": .init(bytes: 2126, sha256: "4d060987173cbd8a5690c1c245d59a1b7d24522766c5e073368ef6296c512ade"),
    "connected-passage-exact-delta.json": .init(bytes: 7740, sha256: "1caab3445a9c512c56e340306a9db0d10310263981a89c8efa6cd8cc1bbe987f"),
    "mechanism-source.json": .init(bytes: 100996, sha256: "d008b997143cc5d5d1b9d50ecbd7c0bfd9531e3db248e296ba09d51c64d4a633"),
    "moving-body-references.json": .init(bytes: 8401, sha256: "b0259908b9b1d45d8adc0f9727073467dbd3211e2a4dc03032290579820e34d4"),
    "mechanism-load-controls.json": .init(bytes: 4699, sha256: "4caa10e22d6eeb24e0c605806f5936a076b8da60b9465005718f82eb53961732"),
    "mechanism-inputs.json": .init(bytes: 1296, sha256: "48383b2be54ac1c2841fa092ff417698769a29d5f529ff6bc78861782548bb69"),
    "mechanism-criteria.json": .init(bytes: 3058, sha256: "f29b217f5626f4830ade98cc93e7faaf4daca2a55ac12b8de26d3897fc7c017e"),
    "mechanism-exact-delta.json": .init(bytes: 5237, sha256: "bacabd3268aa3004df8de0792ea5fa8a5f21159253b1228cb84387046152a93e"),
  ]
  let parent: BisonBedFeedCandidateV4
  let inputs: Inputs
  let criteria: Criteria
  let primaryNotes: PrimaryNotes
  let operation: Operation
  let design: Design
  let results: Results
  let layout: Layout
  let delta: Delta
  let passageBaseline: PassageDelta
  let passageContacts: BisonBedFeedCandidateV4.Contacts
  let mechanismInputs: MechanismInputs
  let mechanismCriteria: MechanismCriteria
  let mechanismExactDelta: MechanismExactDelta
  let movingBodyReferences: MovingBodyReferences
  let passageInputs: PassageInputs
  let passageCriteria: PassageCriteria
  let passageExactDelta: PassageExactDelta
  let contacts: BisonBedFeedCandidateV4.Contacts

  private init(parent: BisonBedFeedCandidateV4, inputs: Inputs,
    criteria: Criteria, primaryNotes: PrimaryNotes, operation: Operation, design: Design,
    results: Results, layout: Layout, delta: Delta, passageBaseline: PassageDelta,
    passageContacts: BisonBedFeedCandidateV4.Contacts, mechanismInputs: MechanismInputs,
    mechanismCriteria: MechanismCriteria, mechanismExactDelta: MechanismExactDelta,
    movingBodyReferences: MovingBodyReferences, passageInputs: PassageInputs,
    passageCriteria: PassageCriteria, passageExactDelta: PassageExactDelta, contacts: BisonBedFeedCandidateV4.Contacts) {
    self.parent = parent
    self.inputs = inputs
    self.criteria = criteria
    self.primaryNotes = primaryNotes
    self.operation = operation
    self.design = design
    self.results = results
    self.layout = layout
    self.delta = delta
    self.passageBaseline = passageBaseline
    self.passageContacts = passageContacts
    self.mechanismInputs = mechanismInputs
    self.mechanismCriteria = mechanismCriteria
    self.mechanismExactDelta = mechanismExactDelta
    self.movingBodyReferences = movingBodyReferences
    self.passageInputs = passageInputs
    self.passageCriteria = passageCriteria
    self.passageExactDelta = passageExactDelta
    self.contacts = contacts
  }

  static func resourceFolder() throws -> URL {
    guard let folder = Bundle.module.url(forResource: folderName, withExtension: nil) else {
      throw Refusal.resourceSet
    }
    return folder
  }

  /// Explicit source folder only. No default directory, runtime interpolation,
  /// missing-data fallback. Bundling requires the separate proposed resource hook.
  static func load(from folder: URL, parent: BisonBedFeedCandidateV4) throws -> Self {
    let assets = try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: assetPins)
    return try decode(assets, parent: parent)
  }

  static func decode(_ assets: [String: Data], parent: BisonBedFeedCandidateV4) throws -> Self {
    guard Set(assets.keys) == Set(assetPins.keys) else { throw Refusal.resourceSet }
    for (name, pin) in assetPins {
      guard let data = assets[name], data.count == pin.bytes, ScriptPackLibrary.hash(data) == pin.sha256 else {
        throw Refusal.resourceIdentity(name)
      }
    }
    guard BisonBedFeedCandidateV4.sourceCommit == parentSourceCommit, !parent.sourceQualifiedForBirth else {
      throw Refusal.parentRevision
    }
    let decoder = JSONDecoder()
    func read<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
      guard let data = assets[name] else { throw Refusal.resourceSet }
      return try decoder.decode(type, from: data)
    }
    let value = try Self(parent: parent,
      inputs: read(Inputs.self, "INPUTS.json"),
      criteria: read(Criteria.self, "ADOPTED-CRITERIA.json"), primaryNotes: read(PrimaryNotes.self, "PRIMARY-SOURCE-NOTES.json"),
      operation: read(Operation.self, "finite-operation-requirements.json"), design: read(Design.self, "cold-loop-design.json"),
      results: read(Results.self, "cold-loop-results.json"), layout: read(Layout.self, "cold-layout.json"),
      delta: read(Delta.self, "mechanism-source.json"),
      passageBaseline: read(PassageDelta.self, "connected-passage-source.json"),
      passageContacts: read(BisonBedFeedCandidateV4.Contacts.self, "connected-load-controls.json"),
      mechanismInputs: read(MechanismInputs.self, "mechanism-inputs.json"),
      mechanismCriteria: read(MechanismCriteria.self, "mechanism-criteria.json"),
      mechanismExactDelta: read(MechanismExactDelta.self, "mechanism-exact-delta.json"),
      movingBodyReferences: read(MovingBodyReferences.self, "moving-body-references.json"),
      passageInputs: read(PassageInputs.self, "connected-passage-inputs.json"),
      passageCriteria: read(PassageCriteria.self, "connected-passage-criteria.json"),
      passageExactDelta: read(PassageExactDelta.self, "connected-passage-exact-delta.json"),
      contacts: read(BisonBedFeedCandidateV4.Contacts.self, "mechanism-load-controls.json"))
    guard value.structuralSourceCoherence else { throw Refusal.incoherentDefinition }
    return value
  }

  enum RuntimeDimension: String, CaseIterable, Equatable, Sendable {
    case materialsAndCO2ConductivityAt185K, bodyPadAndCoreTransport, continuousFluidPropertiesAndPhase
    case manufacturedPoreCoverage, pumpValveControlAndFlow, momentumConservingQuietTransition, coolantChargeAndStartup
  }
  enum Refusal: Error, Equatable {
    case resourceSet, resourceIdentity(String), parentRevision, incoherentDefinition
    case unsupportedRuntimeDimension(RuntimeDimension)
  }
  func requireRuntimeSupport(_ dimension: RuntimeDimension) throws -> Never {
    throw Refusal.unsupportedRuntimeDimension(dimension)
  }
  var sourceQualifiedForBirth: Bool { parent.sourceQualifiedForBirth }
}
