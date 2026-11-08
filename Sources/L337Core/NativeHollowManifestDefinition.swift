import Foundation

/// Closed authored content only. This declaration grants no native permission or stage evidence.
struct NativeHollowManifestDefinition: Codable, Sendable, Equatable {
  static let logicalSourceID = "l337.hollow-manifest"
  static let authoredSchema = "l337-mission-design/1"
  static let authoredVersion = "1.0.0"
  static let authoringCommit = "c70110b292077588a0855fb48127adfb1b611c9d"
  static let definitionSHA256 = "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a"
  static let terminalStage = "complete"
  static let issuerContactName = "Nia Toren"
  static let laboratoryContactName = "Marek Iven"
  static let issuer = SystemIdentity(galaxy: 1, system: 120)
  static let freighterWorld = SystemIdentity(galaxy: 1, system: 113)
  static let laboratoryWorld = SystemIdentity(galaxy: 1, system: 27)
  static let carrierWorld = SystemIdentity(galaxy: 1, system: 182)
  static let registerWorld = SystemIdentity(galaxy: 1, system: 34)
  static let requiresPriorOrdinaryCommoditySale = true
  static let inspectionKitID = "inspection-kit"
  static let inspectionKitMassTonnes = 1
  static let kitAcquireStage = NativeHollowManifestStage.analyseSeals
  static let kitReturnStage = NativeHollowManifestStage.returnEquipment
  static let terminalRewardTenths = 56_000
  static let terminalRewardReceipt = "l337.hollow-manifest/final-payment"
  static let completionClueID = "manifest-hidden-imprint"
  static let completionClueReceipt = "l337.unwritten-route/clue/manifest-hidden-imprint"

  let schema: String
  let sourceID: String
  let version: String

  init(schema: String, sourceID: String, version: String) {
    self.schema = schema
    self.sourceID = sourceID
    self.version = version
  }

  var valid: Bool {
    schema == Self.authoredSchema && sourceID == Self.logicalSourceID
      && version == Self.authoredVersion
  }

  func validate() throws {
    guard valid else { throw MissionPackError("Unsupported Hollow Manifest authored declaration.") }
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: FieldKey.self)
    guard Set(fields.allKeys.map(\.stringValue)) == Set(["schema", "sourceID", "version"])
    else { throw MissionPackError("Unknown or missing Hollow Manifest declaration field.") }
    self.init(
      schema: try fields.decode(String.self, forKey: .init("schema")),
      sourceID: try fields.decode(String.self, forKey: .init("sourceID")),
      version: try fields.decode(String.self, forKey: .init("version")))
    try validate()
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: FieldKey.self)
    try fields.encode(schema, forKey: .init("schema"))
    try fields.encode(sourceID, forKey: .init("sourceID"))
    try fields.encode(version, forKey: .init("version"))
  }

  private struct FieldKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
  }
}

enum NativeHollowManifestStage: String, CaseIterable, Codable, Sendable, Equatable {
  case accept
  case inspectFreighters = "inspect-freighters"
  case analyseSeals = "analyse-seals"
  case followCarrier = "follow-carrier"
  case recoverRegister = "recover-register"
  case rescueCrew = "rescue-crew"
  case reconstructLedger = "reconstruct-ledger"
  case chooseRemedy = "choose-remedy"
  case returnEquipment = "return-equipment"
  case closeCase = "close-case"

  var location: SystemIdentity {
    switch self {
    case .accept, .returnEquipment, .closeCase: NativeHollowManifestDefinition.issuer
    case .inspectFreighters, .reconstructLedger: NativeHollowManifestDefinition.freighterWorld
    case .analyseSeals, .chooseRemedy: NativeHollowManifestDefinition.laboratoryWorld
    case .followCarrier, .rescueCrew: NativeHollowManifestDefinition.carrierWorld
    case .recoverRegister: NativeHollowManifestDefinition.registerWorld
    }
  }

  var authoredEvent: String {
    switch self {
    case .accept, .analyseSeals, .reconstructLedger, .returnEquipment, .closeCase:
      "mission_contact_confirmed"
    case .inspectFreighters, .followCarrier: "entity_scan_completed"
    case .recoverRegister: "mission_item_recovered"
    case .rescueCrew: "escort_arrived"
    case .chooseRemedy: "mission_choice_confirmed"
    }
  }

  var requiredTargets: [String] {
    switch self {
    case .accept: ["toren-commission"]
    case .inspectFreighters: ["freighter-seal-a", "freighter-seal-b"]
    case .analyseSeals: ["seal-laboratory"]
    case .followCarrier: ["wake-one", "wake-two", "wake-three"]
    case .recoverRegister: ["custody-register"]
    case .rescueCrew: ["evacuation-launch"]
    case .reconstructLedger: ["ledger-reconstruction"]
    case .chooseRemedy: ["manifest-remedy"]
    case .returnEquipment: ["inspection-kit-return"]
    case .closeCase: ["manifest-payment"]
    }
  }

  var next: String {
    switch self {
    case .accept: NativeHollowManifestStage.inspectFreighters.rawValue
    case .inspectFreighters: NativeHollowManifestStage.analyseSeals.rawValue
    case .analyseSeals: NativeHollowManifestStage.followCarrier.rawValue
    case .followCarrier: NativeHollowManifestStage.recoverRegister.rawValue
    case .recoverRegister: NativeHollowManifestStage.rescueCrew.rawValue
    case .rescueCrew: NativeHollowManifestStage.reconstructLedger.rawValue
    case .reconstructLedger: NativeHollowManifestStage.chooseRemedy.rawValue
    case .chooseRemedy: NativeHollowManifestStage.returnEquipment.rawValue
    case .returnEquipment: NativeHollowManifestStage.closeCase.rawValue
    case .closeCase: NativeHollowManifestDefinition.terminalStage
    }
  }

  var receiptID: String { NativeHollowManifestDefinition.logicalSourceID + "/" + rawValue }

  /// Declared hold changes only; the native custody transaction must retain the original kit identity.
  var inspectionKitDeltaTonnes: Int {
    switch self {
    case .analyseSeals: 1
    case .returnEquipment: -1
    default: 0
    }
  }
}
