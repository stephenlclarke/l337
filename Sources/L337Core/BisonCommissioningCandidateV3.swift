import Foundation

/// Exact independent engineering source. It supplies definitions only; the
/// existing v2 source and actual private UNOBSERVED journal remain separate.
struct BisonCommissioningCandidateV3: Sendable {
  static let configurationID = "SH005-finite-commissioning-candidate-v3"
  static let sourceCommit = "8fba148f2272e02ebd13377fc08f6487dc1f0c9e"
  static let parentSourceCommit = "a81bba23c8114fd6441f01fe7afaa53d749be5fc"
  static let sourceManifestSHA256 = "b6d177b5365615818e3f1fdcf884618ac92bbeeccdb2b8c4933f6823774ffd45"
  static let parentSourceManifestSHA256 = "5f303add9d854b89881217cf3443082f5d783d34fdcd383b9888ee090566595c"
  static let folderName = "BisonCommissioningCandidate"
  struct AssetPin: Sendable {
    let bytes: Int
    let sha256: String
  }
  static let assetPins: [String: AssetPin] = [
    "CARRIER-REVIEW-INPUTS.json": .init(bytes: 1673, sha256: "634cb00517ade81d3785775a0d448356f649f0ba918098d32c05b577c140fee3"),
    "ADOPTED-CRITERIA.json": .init(bytes: 1182, sha256: "1460d4dfad9dae08c2d54ea3dcdd7cd92f6a0204b84c62dd6215303b8654d3e9"),
    "INPUTS.json": .init(bytes: 3621, sha256: "5b680b4c7d7d837c6a3538ee4cfdc8ab2631527ade4e58885d2bfb439cdd8264"),
    "candidate-source.json": .init(bytes: 4274, sha256: "7232192333a5be2f0f17e554669f5a3c0ebbf039b7c66190205c5ead217e9b23"),
    "changed-load-contact-results.json": .init(bytes: 4420, sha256: "cece3a51c4eacbae20b1901aa1f34b416519214e6371ffcd8c406a8a56f05c3e"),
    "finite-operation-requirements.json": .init(bytes: 6275, sha256: "4b27bcc08467c9159ccb7e67348cae7baca23d939357129fd9245695d04e515a"),
    "material-cavity-candidate.json": .init(bytes: 14568, sha256: "f82ab776c13b30ac128e0f5c0411bb6815c04304382d80900c8b8eafb95dee32"),
    "material-moment-fit.json": .init(bytes: 6020, sha256: "7d823e0af929b462bfa2d83608b471c7bdafdfe868e569e8a3b89b94c4a77973"),
    "radiator-source-patch.json": .init(bytes: 1878, sha256: "7955278721725babe2c1458c1ffa0874ffb8e2a7c2911b29adfb1c3ef50b4385"),
    "source-physical-delta.json": .init(bytes: 1629, sha256: "1568bf7a9092c1c2c9fd46b33077a6b5b4fb39d267c15b592e98d9ae53c8f671"),
    "thermal-design.json": .init(bytes: 8600, sha256: "71008ed226ec826ea5992fb5407f78c07146cc38217e42ff43e016a14a8ec3fc"),
    "thermal-results.json": .init(bytes: 3926, sha256: "e0b1b1dc9f1d26ed53e153f9019b10c706ae17f1ed43e2ddb2d1f9f5a3a80727"),
  ]
  let header: Header
  let inputs: Inputs
  let carrierReviewInputs: CarrierReviewInputs
  let material: Material
  let momentFit: MomentFit
  let physicalDelta: PhysicalDelta
  let radiator: Radiator
  let thermal: Thermal
  let thermalBudget: ThermalBudget
  let finiteOperations: FiniteOperations
  let contactReference: ContactReference
  let adoptedCriteria: AdoptedCriteria
  let baseDeclarations: BaseDeclarations

  private init(header: Header, inputs: Inputs, carrierReviewInputs: CarrierReviewInputs, material: Material, momentFit: MomentFit,
    physicalDelta: PhysicalDelta, radiator: Radiator, thermal: Thermal, thermalBudget: ThermalBudget,
    finiteOperations: FiniteOperations, contactReference: ContactReference,
    adoptedCriteria: AdoptedCriteria, baseDeclarations: BaseDeclarations) {
    self.header = header
    self.inputs = inputs
    self.carrierReviewInputs = carrierReviewInputs
    self.material = material
    self.momentFit = momentFit
    self.physicalDelta = physicalDelta
    self.radiator = radiator
    self.thermal = thermal
    self.thermalBudget = thermalBudget
    self.finiteOperations = finiteOperations
    self.contactReference = contactReference
    self.adoptedCriteria = adoptedCriteria
    self.baseDeclarations = baseDeclarations
  }

  static func resourceFolder() throws -> URL {
    guard let folder = Bundle.module.url(forResource: folderName, withExtension: nil) else { throw Refusal.resourceSet }
    return folder
  }

  static func load() throws -> Self {
    let folder = try resourceFolder()
    let assets = try readAssets(from: folder)
    let base = try readBaseSource()
    return try decode(assets, baseSourceBytes: base)
  }

  static func readAssets(from folder: URL,
    expectedPins: [String: AssetPin] = BisonCommissioningCandidateV3.assetPins) throws -> [String: Data] {
    let facts = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard facts.isDirectory == true, facts.isSymbolicLink != true else { throw Refusal.resourceSet }
    let files = try FileManager.default.contentsOfDirectory(at: folder,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard files.count == expectedPins.count, Set(files.map(\.lastPathComponent)) == Set(expectedPins.keys) else {
      throw Refusal.resourceSet
    }
    var result: [String: Data] = [:]
    for file in files {
      let name = file.lastPathComponent
      guard let pin = expectedPins[name] else { throw Refusal.resourceSet }
      let facts = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == pin.bytes else {
        throw Refusal.resourceIdentity(name)
      }
      result[name] = try Data(contentsOf: file)
    }
    return result
  }

  static func readBaseSource() throws -> Data {
    let file = OriginalFleetPhysicalData.folder.appendingPathComponent(CurrentBisonWideShoePhysicalSource.resourceFileName)
    guard CurrentNewtKitSource.authenticResource(at: file) else { throw Refusal.unavailableBase }
    return try Data(contentsOf: file)
  }

  static func decode(_ assets: [String: Data], baseSourceBytes: Data) throws -> Self {
    guard Set(assets.keys) == Set(assetPins.keys) else { throw Refusal.resourceSet }
    for (name, pin) in assetPins {
      guard let data = assets[name], data.count == pin.bytes, ScriptPackLibrary.hash(data) == pin.sha256 else {
        throw Refusal.resourceIdentity(name)
      }
    }
    guard baseSourceBytes.count == CurrentBisonWideShoePhysicalSource.sourceByteCount,
      ScriptPackLibrary.hash(baseSourceBytes) == CurrentBisonWideShoePhysicalSource.sourceSHA256,
      let base = CurrentNewtKitSource.bison, base.sourceSHA256 == CurrentBisonWideShoePhysicalSource.sourceSHA256,
      base.configuration == CurrentBisonWideShoePhysicalSource.configurationID,
      base.originalNativeCrew == 12, base.selectedPersonOrdinal == 7 else { throw Refusal.unavailableBase }
    let decoder = JSONDecoder()
    func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
      guard let data = assets[name] else { throw Refusal.resourceSet }
      return try decoder.decode(type, from: data)
    }
    let result = try Self(header: decode(Header.self, "candidate-source.json"),
      inputs: decode(Inputs.self, "INPUTS.json"),
      carrierReviewInputs: decode(CarrierReviewInputs.self, "CARRIER-REVIEW-INPUTS.json"), material: decode(Material.self, "material-cavity-candidate.json"),
      momentFit: decode(MomentFit.self, "material-moment-fit.json"),
      physicalDelta: decode(PhysicalDelta.self, "source-physical-delta.json"),
      radiator: decode(Radiator.self, "radiator-source-patch.json"), thermal: decode(Thermal.self, "thermal-design.json"),
      thermalBudget: decode(ThermalBudget.self, "thermal-results.json"),
      finiteOperations: decode(FiniteOperations.self, "finite-operation-requirements.json"),
      contactReference: decode(ContactReference.self, "changed-load-contact-results.json"),
      adoptedCriteria: decode(AdoptedCriteria.self, "ADOPTED-CRITERIA.json"),
      baseDeclarations: decoder.decode(BaseDeclarations.self, from: baseSourceBytes))
    guard result.coherentDefinitions else { throw Refusal.incoherentDefinition }
    return result
  }
}
