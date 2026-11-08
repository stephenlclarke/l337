import Foundation

/// Current inquiry DATA encoding. Native source/world/envelope authorization belongs to its owner.
enum NativeC01InquirySave {
  static let version = 139
  static let alienVersion = 140

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.savedC01Inquiry != nil
  }

  static func publicationVersion(_ commander: borrowing Commander, alien: Bool) -> Int? {
    guard hasClaims(commander) else { return nil }
    return alien ? alienVersion : version
  }

  /// Raw DATA admission only. This issues no source/world authorization or live capability.
  static func validateFields(
    _ data: Data, location: ScriptSaveJSONPreflight.InquiryArchiveLocation, schema: Int?
  ) throws -> NativeC01InquiryState? {
    let currentMissions = contains(schema) && location == .missions
    let extracted = try ScriptSaveJSONPreflight.extractInquiryData(
      data, location: location, permitsRoot: currentMissions)
    guard currentMissions else { return nil }
    guard let extracted else { throw SaveError.invalidCommander }
    return try decodeData(extracted)
  }

  /// Outer retained-source/world checks only. Accepted trajectories, geometry,
  /// final verification and live writer acknowledgements remain native-owner gates.
  @inline(never)
  static func retainedSourceAndWorldValid(
    _ commander: borrowing Commander, world: borrowing ScriptWorldSave
  ) -> Bool {
    if case .none = commander.scriptState.savedC01Inquiry {
      return NativeC01InquiryScene.currentLifeMatches(nil, world: world, commander: commander)
    }
    return presentRetainedSourceAndWorldValid(
      commander.scriptState.savedC01Inquiry!, commander: commander, world: world)
  }

  @inline(never)
  private static func presentRetainedSourceAndWorldValid(
    _ state: borrowing NativeC01InquiryState, commander: borrowing Commander,
    world: borrowing ScriptWorldSave
  ) -> Bool {
    guard state.owner == commander.equipmentOwnerID,
      NativeC01InquiryScene.currentLifeMatches(copy state, world: world, commander: commander)
    else { return false }
    do {
      return try NativeC01InquiryOperatorRetainedSource.validate(state)
    } catch {
      return false
    }
  }

  static func decodeData(_ data: Data) throws -> NativeC01InquiryState {
    try ScriptSaveJSONPreflight.validateInquiryData(data)
    let state: NativeC01InquiryState
    do {
      state = try JSONDecoder().decode(NativeC01InquiryState.self, from: data)
    } catch is DecodingError {
      // Malformed archive DATA has a public save error; direct DTO decoding retains its own errors.
      throw SaveError.invalidCommander
    }
    // Existing nested native Codable types can ignore unknown keys. The current DATA
    // representation must retain every field after a closed decode and re-encode.
    let encoder = JSONEncoder()
    let retained = try JSONSerialization.jsonObject(with: encoder.encode(state))
    guard let original = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (original as NSDictionary).isEqual(retained)
    else { throw SaveError.invalidCommander }
    return state
  }

  static func encodeData(_ state: NativeC01InquiryState) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(state)
    try ScriptSaveJSONPreflight.validateInquiryData(data)
    return data
  }
}

extension ScriptSaveJSONPreflight {
  enum InquiryArchiveLocation: Equatable { case pointer, commander, missions, contracts, world }

  /// Extract only the native missions-root field before Foundation can collapse duplicate keys.
  /// The current envelope owner supplies permission after it has checked the actual schema.
  static func extractInquiryData(
    _ data: Data, location: InquiryArchiveLocation, permitsRoot: Bool = false
  ) throws -> Data? {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context
    switch location {
    case .missions: context = .missions
    case .pointer, .commander: context = .commander
    case .contracts: context = .contracts
    case .world: context = .world
    }
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.extract(context: context, permitsRoot: permitsRoot)
  }

  static func validateCommodityTradeArchive(
    _ data: Data, location: InquiryArchiveLocation, permitsRoot: Bool,
    field: String = NativeFirstCommodityTradeSave.field
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context
    switch location {
    case .missions: context = .missions
    case .pointer, .commander: context = .commander
    case .contracts: context = .contracts
    case .world: context = .world
    }
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.validateTradeArchive(context: context, permitsRoot: permitsRoot, field: field)
  }

  /// Conservative Under Tow presence only. Existing lexical bounds and duplicate-key checks
  /// run before an absent optional feature can skip a whole Foundation object graph.
  static func underTowArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .underTow)
  }

  /// Conservative Assembly presence only, sharing the same bounded lexical stream.
  static func assemblyOfOrbitsArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .assemblyOfOrbits)
  }

  /// Conservative original C38 presence in the existing bounded lexical stream.
  static func nativeSignedPassageOpeningArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .signedPassageOpening)
  }

  /// Conservative original C25 presence in the existing bounded lexical stream.
  static func memoryAtlasArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .memoryAtlas)
  }

  /// Reuse the bounded lexical stream before decoding any current kit carrier.
  static func validateCurrentNewtKitFields(
    _ data: Data, location: InquiryArchiveLocation, permitsClaims: Bool
  ) throws -> Bool {
    try validate(data)
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    let context: NativeC01InquiryLexicalInput.Context =
      location == .commander ? .commander : location == .world ? .world : .opaque
    return try lexical.validateNewtArchive(context: context, permitsClaims: permitsClaims)
  }

  static func extractMemoryAtlasWatcherSource(
    _ data: Data, location: InquiryArchiveLocation, permitsRoot: Bool
  ) throws -> Data? {
    try validate(data)
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.extractWatcherSource(
      context: location == .commander ? .commander : .opaque, permitsRoot: permitsRoot)
  }

  /// Bison archive markers are independent of the existing feature envelopes.
  static func validateBisonJournalFields(_ data: Data, location: BisonUnitJournalSave.Location) throws {
    try validate(data)
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    try lexical.validateBisonArchive(location: location)
  }

  /// Conservative original C02 presence in the existing bounded lexical stream.
  static func quietChoirArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .quietChoir)
  }

  /// Conservative original C04 presence in the existing bounded lexical stream.
  static func borrowedVoiceArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .borrowedVoice)
  }

  static func titheCommissionArchiveMayContainClaims(
    _ data: Data, part: ScriptFreightVersionedSave.Part
  ) throws -> Bool {
    try validate(data)
    let context: NativeC01InquiryLexicalInput.Context =
      part == .missions ? .missions : part == .commander ? .commander : .contracts
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    return try lexical.originalArchiveMayContainClaims(context: context, archive: .titheCommission)
  }

  static func validateCommodityTradeData(_ data: Data) throws {
    try validate(data)
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    try lexical.validateTrade()
  }

  /// Preserve keys and numeric token kinds before decoding the closed inquiry DATA graph.
  static func validateInquiryData(_ data: Data) throws {
    guard data.count <= 33_554_432 else { throw SaveError.invalidCommander }
    try validate(data)
    var lexical = NativeC01InquiryLexicalInput(bytes: Array(data))
    try lexical.validate()
  }
}

/// Streaming field checks share the existing structural limits; no decoded value graph is kept.
private struct NativeC01InquiryLexicalInput {
  let bytes: [UInt8]
  private var cursor = 0
  private let keyDecoder = JSONDecoder()
  private var permitsRoot = false
  private var extracted: Data?
  private var validatingTradeArchive = false
  private var tradeArchiveField = NativeFirstCommodityTradeSave.field
  private var permitsTradeRoot = false
  private var foundTradeRoot = false
  private var validatingNewtArchive = false
  private var permitsNewtClaims = false
  private var foundNewtClaims = false
  private var bisonLocation: BisonUnitJournalSave.Location?
  private var extractingWatcherSource = false
  private var permitsWatcherRoot = false
  private var watcherSource: Data?
  private var queriedOriginalArchive: OriginalArchive?
  private var checkingOriginalArchive: Bool { queriedOriginalArchive != nil }
  private var foundOriginalMarker = false

  /// Closed presence selection only; neither branch decodes data or supplies authority.
  enum OriginalArchive: Equatable {
    case underTow, assemblyOfOrbits, signedPassageOpening, memoryAtlas, quietChoir, borrowedVoice, titheCommission

    func matchesMetadata(_ marker: String) -> Bool {
      switch self {
      case .underTow:
        marker == NativeUnderTowDefinition.stateID || marker == NativeUnderTowDefinition.digest
      case .assemblyOfOrbits:
        marker == NativeAssemblyOfOrbitsDefinition.stateID || marker == NativeAssemblyOfOrbitsDefinition.digest
      case .borrowedVoice:
        marker == NativeBorrowedVoiceDefinition.stateID || marker == NativeBorrowedVoiceDefinition.digest
      case .titheCommission:
        marker == NativeTitheCommissionDefinition.stateID || marker == NativeTitheCommissionDefinition.digest
      case .quietChoir:
        marker == NativeQuietChoirDefinition.stateID || marker == NativeQuietChoirDefinition.digest
      case .memoryAtlas:
        marker == NativeMemoryAtlasDefinition.stateID || marker == NativeMemoryAtlasDefinition.digest
      case .signedPassageOpening:
        marker == NativeSignedPassageOpening.stateID || marker == NativeSignedPassageOpening.digest
      }
    }

    func matchesKey(_ key: String) -> Bool {
      switch self {
      case .underTow: key == NativeUnderTowSave.field || key == "underTow"
      case .assemblyOfOrbits: key == NativeAssemblyOfOrbitsSave.field || key == "assemblyOfOrbits"
      case .borrowedVoice:
        key == NativeBorrowedVoiceSave.field || key == "borrowedVoice"
      case .titheCommission:
        key == NativeTitheCommissionSave.field || key == "titheCommission" || key == "titheCommissionMarkEntitlement"
      case .quietChoir:
        key == NativeQuietChoirSave.field || key == "quietChoir"
      case .memoryAtlas:
        key == NativeMemoryAtlasSave.field || key == "memoryAtlas"
      case .signedPassageOpening:
        key == NativeSignedPassageOpeningSave.field || key == "signedPassageOpening"
      }
    }
  }

  /// Every retained-source object is closed before a Foundation object graph is made.
  enum WatcherObject: Equatable {
    case record, initialization, transfer, collection, facts, issueSource
    case dock, station, actor, system, node, family

    var fields: [String: WatcherField] {
      switch self {
      case .record:
        return [
          "adoptionRevision": .integer, "sourceRevision": .integer,
          "owner": .text, "issuer": .text, "caseID": .text, "original": .text,
          "station": .object(.station), "resource": .text, "name": .text,
          "node": .object(.node), "quantity": .integer, "cargoTonnes": .integer,
          "heldOnly": .boolean, "loan": .boolean, "returnPolicy": .text,
          "packVersion": .text, "packDigest": .text,
          "initialization": .object(.initialization), "custody": .text,
          "transfer": .object(.transfer),
        ]
      case .initialization:
        return ["dock": .object(.dock), "eventSequence": .integer,
          "physicalTime": .number, "calendarSeconds": .number]
      case .transfer:
        return ["beforeSourceRevision": .integer, "afterSourceRevision": .integer,
          "collection": .object(.collection)]
      case .collection: return ["operation": .text, "facts": .object(.facts)]
      case .facts:
        return [
          "issueCommand": .text, "source": .object(.issueSource), "issuer": .text,
          "original": .text, "carrier": .text, "dock": .object(.dock),
          "beforeInventoryRevision": .integer, "afterInventoryRevision": .integer,
          "beforeCaseRevision": .integer, "afterCaseRevision": .integer,
          "eventSequence": .integer, "beforeCargoTonnes": .integer,
          "afterCargoTonnes": .integer, "capacityTonnes": .integer,
          "physicalTime": .number, "calendarSeconds": .number,
        ]
      case .issueSource: return ["mission": .text, "resource": .text, "packDigest": .text]
      case .dock:
        return ["station": .object(.station), "actor": .object(.actor),
          "commanderOwner": .text, "sequence": .integer, "calendarSeconds": .number]
      case .station: return ["world": .text, "system": .object(.system), "resource": .text]
      case .actor: return ["system": .object(.system), "visit": .integer, "entity": .integer]
      case .system: return ["galaxy": .integer, "system": .integer]
      case .node: return ["family": .object(.family), "key": .text]
      case .family: return ["rawValue": .text]
      }
    }

    var requiredKeys: Set<String> {
      switch self {
      case .record: return NativeMemoryAtlasWatcherSourceSave.rawRecordKeys.subtracting(["transfer"])
      case .initialization: return NativeMemoryAtlasWatcherSourceSave.rawInitializationKeys
      case .transfer: return NativeMemoryAtlasWatcherSourceSave.rawTransferKeys
      default: return Set(fields.keys)
      }
    }
  }

  enum WatcherField {
    case object(WatcherObject), text, integer, number, boolean

    func accepts(_ token: UInt8) -> Bool {
      switch self {
      case .object: return token == 123
      case .text: return token == 34
      case .integer, .number: return token == 45 || (48...57).contains(token)
      case .boolean: return token == 116 || token == 102
      }
    }
  }

  enum Context: Equatable {
    case inquiry, commodityTrade, titheCommission, opaque, commander, missions, embeddedMissions, world, bodies, body, physical, spawn
    case newtEMP, newtRecords, newtRecord, newtObject, newtObjects, newtCustody, newtLeaf
    case newtNPC, newtNPCEntries, newtNPCEntry, newtSnapshot
    case newtDirector, newtRequests, newtRequest
    case watcherSource(WatcherObject)
    case instances, instance, contract, offer, contracts, boards, board, offers

    var watcherObject: WatcherObject? {
      if case .watcherSource(let object) = self { return object }
      return nil
    }

    func child(for key: String) -> Self {
      switch (self, key) {
      case (.commander, "encounterDirector"): return .newtDirector
      case (.newtDirector, "pendingRequests"): return .newtRequests
      case (.commander, "savedEMPState"): return .newtEMP
      case (.commander, "savedNPCPersistence"): return .newtNPC
      case (.newtEMP, "records"): return .newtRecords
      case (.newtRecord, "hull"): return .newtObject
      case (.newtRecord, "pods"): return .newtObjects
      case (.newtObject, "body"): return .body
      case (.newtNPC, "entries"): return .newtNPCEntries
      case (.newtNPCEntry, "snapshot"): return .newtSnapshot
      case (.newtRecord, "savedCurrentTrafficTransfer"): return .newtSnapshot
      case (.newtRecord, "custody"): return .newtCustody
      case (.newtCustody, "traffic"): return .newtSnapshot
      case (.newtCustody, "original"): return .newtObject
      case (.commander, "savedScriptState"): return .embeddedMissions
      case (.commander, "savedContracts"): return .contracts
      case (.missions, "instances"), (.embeddedMissions, "instances"): return .instances
      case (.instance, "contract"): return .contract
      case (.instance, NativeTitheCommissionSave.field): return .titheCommission
      case (.contract, "offer"): return .offer
      case (.contracts, "boards"): return .boards
      case (.board, "offers"): return .offers
      case (.world, "bodies"): return .bodies
      case (.body, "physical"): return .physical
      case (.physical, "spawnIdentity"): return .spawn
      default:
        switch self {
        case .inquiry: return .inquiry
        case .commodityTrade: return .commodityTrade
        case .titheCommission: return .titheCommission
        case .watcherSource(let object):
          if let field = object.fields[key], case .object(let nested) = field {
            return .watcherSource(nested)
          }
          return self
        case .newtLeaf: return .newtLeaf
        case .newtRecords: return .newtRecord
        case .newtNPCEntries: return .newtNPCEntry
        case .instances: return .instance
        case .boards: return .board
        case .offers: return .offer
        case .bodies: return .body
        default: return .opaque
        }
      }
    }

    var element: Self {
      switch self {
      case .newtRequests: return .newtRequest
      case .newtRecords: return .newtRecord
      case .newtNPCEntries: return .newtNPCEntry
      case .newtObjects: return .newtObject
      case .instances: return .instance
      case .boards: return .board
      case .offers: return .offer
      case .bodies: return .body
      default: return self
      }
    }
  }

  init(bytes: [UInt8]) { self.bytes = bytes }

  // Closed DATA integer leaves plus the existing actor/system/resource integer leaves they embed.
  private static let integerFields: Set<String> = [
    "benchCycleOrdinal", "bodyID", "challengeOrdinal", "generation", "headBackFaceIndex",
    "nativeFaceIndex", "offsetDegrees", "ordinal", "supportFrontFaceIndex",
    "appliedControlRevision", "caseOrdinal", "caseRevision", "commandSequence", "cycle",
    "dutyRevision", "incidentID", "inventoryRevision", "nativeOrder", "nextCaseOrdinal",
    "outputCount", "placementCandidate", "priorCaseRevision", "pulseSequence",
    "qualifiedStepCount", "referenceEndSequence", "referenceStartSequence", "revision",
    "sequence", "sourceRevision", "visit", "entity", "member", "galaxy", "system",
    "bountyTenths", "value", "id", "index", "detent", "appliedDetent", "emissionID",
  ]
  private static let titheIntegerFields: Set<String> = [
    "inventoryRevision", "sequence", "visit", "entity", "galaxy", "system",
  ]
  private static let tradeIntegerFields: Set<String> = [
    "commodity", "calendarOperation", "unitPrice", "quantity", "stock", "cargo", "credits",
    "sequence", "visit", "entity", "galaxy", "system",
  ]
  private static let floatingFields: Set<String> = [
    "activationPhysicalTime", "admissionPhysicalTime", "aimDegrees", "areaSquareMetres",
    "clockEnd", "clockLabel", "clockStart", "energy", "lower", "massKilograms",
    "maxAimDegrees", "maxSurfaceRangeNative", "metresPerWorldUnit", "minSurfaceRangeNative",
    "physicalTime", "surfaceRangeNative", "upper", "usedD", "x", "y", "z",
    "calendarSeconds", "emittedAt",
  ]
  // Policy revisions and UUID identities have string spellings in other closed DATA objects.
  private static let textOrIntegerFields: Set<String> = ["revision", "id"]

  private static let newtIntegerFields: Set<String> = [
    "sequence", "visit", "entity", "member", "galaxy", "system", "ordinal",
    "commodity", "quantity", "missiles", "fuel", "fuelCapacity",
  ]

  private static let watcherIntegerFields: Set<String> = [
    "adoptionRevision", "sourceRevision", "quantity", "cargoTonnes", "beforeSourceRevision",
    "afterSourceRevision", "eventSequence", "beforeInventoryRevision", "afterInventoryRevision",
    "beforeCaseRevision", "afterCaseRevision", "beforeCargoTonnes", "afterCargoTonnes",
    "capacityTonnes", "sequence", "visit", "entity", "galaxy", "system",
  ]

  mutating func validateNewtArchive(context: Context, permitsClaims: Bool) throws -> Bool {
    validatingNewtArchive = true
    permitsNewtClaims = permitsClaims
    whitespace()
    guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    try value(field: nil, context: context)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
    return foundNewtClaims
  }

  mutating func validateBisonArchive(location: BisonUnitJournalSave.Location) throws {
    bisonLocation = location
    let context: Context = location == .commander || location == .pointer ? .commander
      : location == .world ? .world : .opaque
    whitespace()
    guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    try value(field: nil, context: context)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
  }

  mutating func extractWatcherSource(context: Context, permitsRoot: Bool) throws -> Data? {
    extractingWatcherSource = true
    permitsWatcherRoot = permitsRoot
    whitespace()
    guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    try value(field: nil, context: context)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
    return watcherSource
  }

  mutating func validateTradeArchive(context: Context, permitsRoot: Bool, field: String) throws -> Bool {
    guard field == NativeFirstCommodityTradeSave.field || field == NativeSecondCommoditySaleSave.field
    else { throw SaveError.invalidCommander }
    tradeArchiveField = field
    validatingTradeArchive = true
    permitsTradeRoot = permitsRoot
    whitespace()
    guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    try value(field: nil, context: context)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
    return foundTradeRoot
  }

  mutating func originalArchiveMayContainClaims(context: Context, archive: OriginalArchive) throws -> Bool {
    queriedOriginalArchive = archive
    _ = try extract(context: context, permitsRoot: false)
    return foundOriginalMarker
  }

  mutating func validateTrade() throws {
    try value(field: nil, context: .commodityTrade)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
  }

  mutating func validate() throws {
    try value(field: nil, context: .inquiry)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
  }

  mutating func extract(context: Context, permitsRoot: Bool) throws -> Data? {
    self.permitsRoot = permitsRoot
    whitespace()
    guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    try value(field: nil, context: context)
    whitespace()
    guard cursor == bytes.count else { throw SaveError.invalidCommander }
    return extracted
  }

  private mutating func whitespace() {
    while cursor < bytes.count && [9, 10, 13, 32].contains(bytes[cursor]) { cursor += 1 }
  }

  private mutating func take(_ byte: UInt8) -> Bool {
    whitespace()
    guard cursor < bytes.count && bytes[cursor] == byte else { return false }
    cursor += 1
    return true
  }

  private mutating func value(field: String?, context: Context) throws {
    whitespace()
    guard cursor < bytes.count else { throw SaveError.invalidCommander }
    if checkingOriginalArchive && context == .instances {
      guard bytes[cursor] == 123 || bytes[cursor] == 91 else { throw SaveError.invalidCommander }
    }
    if checkingOriginalArchive && context == .instance {
      guard bytes[cursor] == 123 else { throw SaveError.invalidCommander }
    }
    if context == .inquiry && field == "words" {
      _ = try exactWords()
      return
    }
    let integer = (context == .newtLeaf && (field.map(Self.newtIntegerFields.contains) ?? false))
      || (context == .inquiry && (field.map(Self.integerFields.contains) ?? false))
      || (context == .commodityTrade && (field.map(Self.tradeIntegerFields.contains) ?? false))
      || (context == .titheCommission && (field.map(Self.titheIntegerFields.contains) ?? false))
      || (context.watcherObject != nil && (field.map(Self.watcherIntegerFields.contains) ?? false))
    let floating = context == .inquiry && (field.map(Self.floatingFields.contains) ?? false)
    if context == .inquiry && (field == "lowerBits" || field == "upperBits") {
      guard bytes[cursor] == 34 else { throw SaveError.invalidCommander }
    }
    switch bytes[cursor] {
    case 123: try object(context: context)
    case 91: try array(context: context)
    case 34:
      if integer && !(field.map(Self.textOrIntegerFields.contains) ?? false) {
        throw SaveError.invalidCommander
      }
      if checkingOriginalArchive && (field == "definition" || field == "digest") {
        let marker = try string(decodeKey: true)
        if queriedOriginalArchive?.matchesMetadata(marker) == true {
          foundOriginalMarker = true
        }
      } else {
        _ = try string(decodeKey: false)
      }
    case 45, 48...57: try number(integer: integer)
    case 116:
      guard !integer && !floating else { throw SaveError.invalidCommander }
      try literal(Array("true".utf8))
    case 102:
      guard !integer && !floating else { throw SaveError.invalidCommander }
      try literal(Array("false".utf8))
    case 110 where context != .inquiry && context != .commodityTrade && context != .newtLeaf
      && context != .titheCommission
      && context.watcherObject == nil:
      try literal(Array("null".utf8))
    default:
      // Every optional inquiry DATA field is omitted, rather than represented by null.
      throw SaveError.invalidCommander
    }
  }

  private mutating func object(context: Context) throws {
    guard take(123) else { throw SaveError.invalidCommander }
    var keys: Set<String> = []
    let watcher = context.watcherObject
    let watcherFields = watcher?.fields
    if take(125) {
      guard watcher == nil else { throw SaveError.invalidCommander }
      return
    }
    while true {
      let key = try string(decodeKey: true)
      guard keys.insert(key).inserted, take(58) else { throw SaveError.invalidCommander }
      if let watcherFields {
        whitespace()
        guard let field = watcherFields[key], cursor < bytes.count, field.accepts(bytes[cursor])
        else { throw SaveError.invalidCommander }
      }
      if checkingOriginalArchive {
        guard context != .instances || keys.count <= 128 else { throw SaveError.invalidCommander }
        if queriedOriginalArchive?.matchesKey(key) == true { foundOriginalMarker = true }
      }
      if validatingNewtArchive && key == "serviceCapturedAt" && context != .newtLeaf {
        // This is stock history, never an independent commander, pod or custody claim.
        throw SaveError.invalidCommander
      }
      if (validatingNewtArchive || bisonLocation != nil) && key == BisonUnitJournalSave.journalField {
        guard context == .commander, bisonLocation == nil || bisonLocation == .commander else {
          throw SaveError.invalidCommander
        }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        // The exact typed namespace owns its requests. Duplicate-key/depth
        // checks remain active; full leaf re-encoding rejects discarded fields.
        let previousNewtMode = validatingNewtArchive
        validatingNewtArchive = false
        try value(field: nil, context: .opaque)
        validatingNewtArchive = previousNewtMode
        guard cursor - start <= 4_194_304 else { throw SaveError.invalidCommander }
        try BisonUnitJournalSave.validateLeaf(Data(bytes[start..<cursor]))
      } else if (validatingNewtArchive || bisonLocation != nil) && key == BisonUnitJournalSave.checkpointField {
        guard context == .commander || context == .world,
          bisonLocation == nil || bisonLocation == .pointer || bisonLocation == .world else {
          throw SaveError.invalidCommander
        }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        let previousNewtMode = validatingNewtArchive
        validatingNewtArchive = false
        try value(field: nil, context: .opaque)
        validatingNewtArchive = previousNewtMode
        guard cursor - start <= CurrentNewtKitSave.maximumLeafBytes else { throw SaveError.invalidCommander }
        try BisonUnitJournalSave.validateCheckpointLeaf(Data(bytes[start..<cursor]))
      } else if validatingNewtArchive && key == "currentNewtKitConfiguration" {
        guard permitsNewtClaims, context == .newtRequest else { throw SaveError.invalidCommander }
        let selector = try string(decodeKey: true)
        guard !selector.isEmpty, selector.utf8.count <= 256 else { throw SaveError.invalidCommander }
        foundNewtClaims = true
      } else if validatingNewtArchive && CurrentNewtKitSave.fields.contains(key) {
        guard permitsNewtClaims,
          (context == .physical && key != "currentNewtKitConfiguration")
            || (context == .newtSnapshot && key == "currentNewtKitStock")
        else { throw SaveError.invalidCommander }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        try value(field: nil, context: .newtLeaf)
        guard cursor - start <= CurrentNewtKitSave.maximumLeafBytes else {
          throw SaveError.invalidCommander
        }
        try CurrentNewtKitSave.validateLeaf(Data(bytes[start..<cursor]), field: key)
        foundNewtClaims = true
      } else if checkingOriginalArchive && queriedOriginalArchive == .titheCommission
        && key == NativeTitheCommissionSave.field
      {
        guard context == .instance else { throw SaveError.invalidCommander }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        try value(field: nil, context: .titheCommission)
        guard cursor - start <= NativeTitheCommissionSave.maximumLeafBytes else {
          throw SaveError.invalidCommander
        }
      } else if extractingWatcherSource && key == NativeMemoryAtlasWatcherSourceSave.field {
        guard context == .commander, permitsWatcherRoot, watcherSource == nil else {
          throw SaveError.invalidCommander
        }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        try value(field: nil, context: .watcherSource(.record))
        guard cursor - start <= NativeMemoryAtlasWatcherSourceSave.maximumLeafBytes else {
          throw SaveError.invalidCommander
        }
        watcherSource = Data(bytes[start..<cursor])
      } else if validatingTradeArchive && key == tradeArchiveField
        && context != .opaque && context != .commodityTrade
      {
        guard context == .missions, permitsTradeRoot, !foundTradeRoot else {
          throw SaveError.invalidCommander
        }
        foundTradeRoot = true
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        try value(field: nil, context: .commodityTrade)
        guard cursor - start <= 32768 else { throw SaveError.invalidCommander }
      } else if !validatingTradeArchive && !checkingOriginalArchive && !extractingWatcherSource
        && !validatingNewtArchive && bisonLocation == nil
        && key == "savedC01Inquiry"
        && context != .opaque && context != .inquiry
      {
        guard context == .missions, permitsRoot, extracted == nil else {
          throw SaveError.invalidCommander
        }
        whitespace()
        let start = cursor
        guard cursor < bytes.count, bytes[cursor] == 123 else { throw SaveError.invalidCommander }
        try value(field: nil, context: .inquiry)
        guard cursor - start <= 33_554_432 else { throw SaveError.invalidCommander }
        extracted = Data(bytes[start..<cursor])
      } else if context == .inquiry && key == "phaseSeconds" {
        throw SaveError.invalidCommander
      } else if context == .inquiry && key == "offset" {
        _ = try exactDyadic()
      } else if context == .inquiry && key == "phase" {
        whitespace()
        if cursor < bytes.count && bytes[cursor] == 123 {
          let phase = try exactDyadic()
          guard phase < .period else { throw SaveError.invalidCommander }
        } else {
          // The inquiry case phase is a raw String enum, not an oscillator phase.
          try value(field: key, context: .inquiry)
        }
      } else {
        try value(field: key, context: context.child(for: key))
      }
      if take(125) {
        guard watcher?.requiredKeys.isSubset(of: keys) ?? true else {
          throw SaveError.invalidCommander
        }
        return
      }
      guard take(44) else { throw SaveError.invalidCommander }
    }
  }

  /// Every actual phase/offset path uses the same closed bounded DATA scalar.
  private mutating func exactDyadic() throws -> NativeC01InquiryExactDyadic {
    guard take(123), try string(decodeKey: true) == "words", take(58) else {
      throw SaveError.invalidCommander
    }
    let value = try exactWords()
    guard take(125) else { throw SaveError.invalidCommander }
    return value
  }

  private mutating func exactWords() throws -> NativeC01InquiryExactDyadic {
    guard take(91) else { throw SaveError.invalidCommander }
    var words: [UInt64] = []
    words.reserveCapacity(NativeC01InquiryExactDyadic.wordCount)
    for index in 0..<NativeC01InquiryExactDyadic.wordCount {
      if index > 0 { guard take(44) else { throw SaveError.invalidCommander } }
      // Decode one bounded JSON String scalar, never a saved object or array graph.
      let word = try string(decodeKey: true)
      guard word.utf8.count == 16,
        word.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
        let value = UInt64(word, radix: 16)
      else { throw SaveError.invalidCommander }
      words.append(value)
    }
    guard take(93) else { throw SaveError.invalidCommander }
    // The actual owner enforces its unused bits and exact exclusive 4 + binary64 .1 bound.
    return try NativeC01InquiryExactDyadic(littleEndianWords: words)
  }

  private mutating func array(context: Context) throws {
    guard take(91) else { throw SaveError.invalidCommander }
    if take(93) { return }
    var count = 0
    while true {
      let originalInstances = checkingOriginalArchive && context == .instances
      if originalInstances {
        guard count < 256 else { throw SaveError.invalidCommander }
      }
      // UUID dictionaries use alternating key/value array elements in current Codable.
      let element: Context = originalInstances && count.isMultiple(of: 2)
        ? .opaque : context.element
      try value(field: nil, context: element)
      count += 1
      if take(93) {
        guard !originalInstances || count.isMultiple(of: 2) else { throw SaveError.invalidCommander }
        return
      }
      guard take(44) else { throw SaveError.invalidCommander }
    }
  }

  private mutating func string(decodeKey: Bool) throws -> String {
    whitespace()
    let start = cursor
    guard take(34) else { throw SaveError.invalidCommander }
    var escaped = false
    while cursor < bytes.count {
      let byte = bytes[cursor]
      cursor += 1
      guard byte >= 32 else { throw SaveError.invalidCommander }
      if escaped {
        escaped = false
      } else if byte == 92 {
        escaped = true
      } else if byte == 34 {
        if !decodeKey { return "" }
        // A single string token retains each occurrence, including escaped-equivalent keys.
        return try keyDecoder.decode(String.self, from: Data(bytes[start..<cursor]))
      }
    }
    throw SaveError.invalidCommander
  }

  private mutating func literal(_ token: [UInt8]) throws {
    guard token.count <= bytes.count - cursor,
      bytes[cursor..<(cursor + token.count)].elementsEqual(token)
    else { throw SaveError.invalidCommander }
    cursor += token.count
  }

  private mutating func number(integer: Bool) throws {
    if bytes[cursor] == 45 { cursor += 1 }
    guard cursor < bytes.count else { throw SaveError.invalidCommander }
    if bytes[cursor] == 48 {
      cursor += 1
    } else {
      guard (49...57).contains(bytes[cursor]) else { throw SaveError.invalidCommander }
      digits()
    }
    var integral = true
    if cursor < bytes.count && bytes[cursor] == 46 {
      integral = false
      cursor += 1
      let start = cursor
      digits()
      guard cursor > start else { throw SaveError.invalidCommander }
    }
    if cursor < bytes.count && [69, 101].contains(bytes[cursor]) {
      integral = false
      cursor += 1
      if cursor < bytes.count && [43, 45].contains(bytes[cursor]) { cursor += 1 }
      let start = cursor
      digits()
      guard cursor > start else { throw SaveError.invalidCommander }
    }
    guard !integer || integral else { throw SaveError.invalidCommander }
    guard cursor == bytes.count || [9, 10, 13, 32, 44, 93, 125].contains(bytes[cursor]) else {
      throw SaveError.invalidCommander
    }
  }

  private mutating func digits() {
    while cursor < bytes.count && (48...57).contains(bytes[cursor]) { cursor += 1 }
  }
}

/// Decoded staging DATA for the current inquiry envelope. Neither preparation nor
/// its feature namespace grants claim approval, world restoration or a native binding.
struct NativeC01InquiryArchiveComposition {
  let chunks: [String: Data]
  let commander: Commander
  let featureSchema: Int
  let hasInquiryClaims: Bool
  let hasTradeClaims: Bool
  let hasWatcherClaims: Bool
  let hasNewtClaims: Bool
  let hasSecondClaims: Bool

  private struct C03HeaderOwner: Decodable {
    struct Inventory: Decodable { let owner: UUID }
    let savedEquipmentInventory: Inventory?
  }

  static func prepare(_ pointer: ScriptSavePointer, from url: URL) throws -> Self? {
    let c03Envelope = NativeC03PublicationNamespace.contains(pointer.schemaVersion)
    let secondEnvelope = NativeSecondCommoditySaleSave.contains(pointer.schemaVersion)
    let newtEnvelope = CurrentNewtKitSave.contains(pointer.schemaVersion)
    let tradeEnvelope = NativeFirstCommodityTradeSave.contains(pointer.schemaVersion)
    let watcherEnvelope = NativeMemoryAtlasWatcherEnvelope.contains(pointer.schemaVersion)
    guard NativeC01InquirySave.contains(pointer.schemaVersion) || tradeEnvelope || watcherEnvelope
      || newtEnvelope || secondEnvelope || c03Envelope
    else { return nil }
    let alien = pointer.schemaVersion == NativeC03PublicationNamespace.alienVersion
      || pointer.schemaVersion == NativeSecondCommoditySaleSave.alienVersion
      || pointer.schemaVersion == CurrentNewtKitSave.alienVersion
      || pointer.schemaVersion == NativeC01InquirySave.alienVersion
      || pointer.schemaVersion == NativeFirstCommodityTradeSave.alienVersion
      || pointer.schemaVersion == NativeMemoryAtlasWatcherEnvelope.alienVersion
    var names: Set<String> = ["commander.json", "missions.json", "world.json", "contracts.json"]
    if alien { names.insert(AlienStorageVersionedSave.rootName) }
    guard pointer.format == "elite-script-save", Set(pointer.hashes.keys) == names,
      pointer.valueCodec == ScriptValueStorage.codec,
      ["commander", "gallery"].contains(pointer.scope ?? ""),
      UUID(uuidString: pointer.generation)?.uuidString == pointer.generation
    else { throw SaveError.invalidCommander }
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    var limits = [
      ("commander.json", 4_194_304), ("missions.json", 134_217_728),
      ("world.json", 8_388_608), ("contracts.json", 134_217_728),
    ]
    if alien {
      limits.append((AlienStorageVersionedSave.rootName, AlienStoragePageCodec.maximumRootBytes))
    }
    var chunks: [String: Data] = [:]
    var c03Owner: UUID?
    var c03Publications: [NativeC03PublicationPreflight.Publication] = []
    for (name, limit) in limits {
      let location = directory.appendingPathComponent(name)
      let properties = try location.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard properties.isRegularFile == true, properties.isSymbolicLink != true,
        (properties.fileSize ?? Int.max) <= limit
      else { throw SaveError.invalidCommander }
      let data = try CommanderSaveInput.read(
        from: location, maximumBytes: limit, denySymbolicLinks: true)
      guard data.count <= limit, ScriptPackLibrary.hash(data) == pointer.hashes[name] else {
        throw SaveError.invalidCommander
      }
      // Scan exact hash-pinned raw bytes before any enclosing Foundation decode.
      let c03Part: ScriptFreightVersionedSave.Part = name == "missions.json" ? .missions
        : name == "commander.json" ? .commander : .contracts
      let publications = try NativeC03PublicationPreflight.validate(
        data, part: c03Part, schema: pointer.schemaVersion,
        currentSchema: alien ? NativeC03PublicationNamespace.alienVersion
          : NativeC03PublicationNamespace.version, owner: c03Owner)
      c03Publications.append(contentsOf: publications)
      let inquiryLocation: ScriptSaveJSONPreflight.InquiryArchiveLocation =
        name == "missions.json" ? .missions
        : name == "commander.json" ? .commander
        : name == "contracts.json" ? .contracts : .world
      let secondSchema: Int?
      if c03Envelope {
        let found = try ScriptSaveJSONPreflight.validateCommodityTradeArchive(
          data, location: inquiryLocation, permitsRoot: inquiryLocation == .missions,
          field: NativeSecondCommoditySaleSave.field)
        secondSchema = found
          ? (alien ? NativeSecondCommoditySaleSave.alienVersion : NativeSecondCommoditySaleSave.version)
          : nil
      } else { secondSchema = pointer.schemaVersion }
      try NativeSecondCommoditySaleSave.validateFields(
        data, location: inquiryLocation, schema: secondSchema)
      try CurrentNewtKitSave.validateFields(
        data, location: inquiryLocation,
        schema: secondEnvelope || c03Envelope
          ? (alien ? CurrentNewtKitSave.alienVersion : CurrentNewtKitSave.version)
          : pointer.schemaVersion)
      try NativeMemoryAtlasWatcherEnvelope.validateFields(
        data, location: inquiryLocation,
        schema: newtEnvelope || secondEnvelope || c03Envelope
          ? (alien ? NativeMemoryAtlasWatcherEnvelope.alienVersion : NativeMemoryAtlasWatcherEnvelope.version)
          : pointer.schemaVersion,
        requireClaims: !newtEnvelope && !secondEnvelope && !c03Envelope)
      if watcherEnvelope || newtEnvelope || secondEnvelope || c03Envelope {
        let found = try ScriptSaveJSONPreflight.validateCommodityTradeArchive(
          data, location: inquiryLocation, permitsRoot: inquiryLocation == .missions)
        if found {
          try NativeFirstCommodityTradeSave.validateFields(data, location: inquiryLocation,
            schema: alien ? NativeFirstCommodityTradeSave.alienVersion : NativeFirstCommodityTradeSave.version)
        }
      } else {
        try NativeFirstCommodityTradeSave.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
      }
      if tradeEnvelope || watcherEnvelope || newtEnvelope || secondEnvelope || c03Envelope {
        let inquiry = try ScriptSaveJSONPreflight.extractInquiryData(
          data, location: inquiryLocation, permitsRoot: inquiryLocation == .missions)
        if let inquiry { _ = try NativeC01InquirySave.decodeData(inquiry) }
      } else {
        _ = try NativeC01InquirySave.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
      }
      if name == "missions.json" {
        try NativeUnderTowSave.validateFields(data, part: .missions)
        try NativeBorrowedVoiceSave.validateFields(data, part: .missions)
        try NativeTitheCommissionSave.validateFields(data, part: .missions)
        try NativeQuietChoirSave.validateFields(data, part: .missions)
        try NativeMemoryAtlasSave.validateFields(data, part: .missions)
        try NativeSignedPassageOpeningSave.validateFields(data, part: .missions)
        try NativeAssemblyOfOrbitsSave.validateFields(data, part: .missions)
        try NativeIsolationWorkParentSave.validateFields(data, part: .missions)
        try NativeIsolationWorkSave.validateFields(data, part: .missions)
      } else if name == "commander.json" {
        try NativeUnderTowSave.validateFields(data, part: .commander)
        try NativeBorrowedVoiceSave.validateFields(data, part: .commander)
        try NativeTitheCommissionSave.validateFields(data, part: .commander)
        try NativeQuietChoirSave.validateFields(data, part: .commander)
        try NativeMemoryAtlasSave.validateFields(data, part: .commander)
        try NativeSignedPassageOpeningSave.validateFields(data, part: .commander)
        try NativeAssemblyOfOrbitsSave.validateFields(data, part: .commander)
        try NativeIsolationWorkParentSave.validateFields(data, part: .commander)
        try NativeIsolationWorkSave.validateFields(data, part: .commander)
      } else {
        try NativeUnderTowSave.validateFields(data, part: .contracts)
        try NativeBorrowedVoiceSave.validateFields(data, part: .contracts)
        try NativeTitheCommissionSave.validateFields(data, part: .contracts)
        try NativeQuietChoirSave.validateFields(data, part: .contracts)
        try NativeMemoryAtlasSave.validateFields(data, part: .contracts)
        try NativeSignedPassageOpeningSave.validateFields(data, part: .contracts)
        try NativeAssemblyOfOrbitsSave.validateFields(data, part: .contracts)
        try NativeIsolationWorkParentSave.validateFields(data, part: .contracts)
        try NativeIsolationWorkSave.validateFields(data, part: .contracts)
      }
      if name == "commander.json" {
        c03Owner = try ScriptValueStorage.decoder(typed: true)
          .decode(C03HeaderOwner.self, from: data).savedEquipmentInventory?.owner
      }
      chunks[name] = data
    }
    guard let header = chunks["commander.json"], let missions = chunks["missions.json"],
      let contracts = chunks["contracts.json"]
    else { throw SaveError.invalidCommander }
    var commander = try ScriptValueStorage.decoder(typed: true).decode(Commander.self, from: header)
    guard alien == commander.usesAlienStorageSaveVersion,
      c03Owner == nil || c03Owner == commander.equipmentOwnerID
    else { throw SaveError.invalidCommander }
    if alien {
      guard let rootHash = pointer.hashes[AlienStorageVersionedSave.rootName] else {
        throw SaveError.invalidCommander
      }
      try AlienStorageVersionedSave.hydrate(&commander, rootHash: rootHash, directory: directory)
    }
    let missionsDecoder = ScriptValueStorage.decoder(typed: true)
    commander.scriptState = try missionsDecoder.decode(ScriptEngineState.self, from: missions)
    commander.contracts = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptContractState.self, from: contracts)
    guard c03Envelope == NativeHollowManifestSave.hasClaims(commander) else {
      throw SaveError.invalidCommander
    }
    for publication in c03Publications {
      guard NativeC03PublicationNamespace.matches(publication, commander: commander) else {
        throw SaveError.invalidCommander
      }
    }
    guard c03Publications.count == (c03Envelope ? 1 : 0),
      NativeC03PublicationPreflight.validateClaims(commander)
    else { throw SaveError.invalidCommander }
    let semantic = JSONEncoder()
    let hasInquiry = NativeC01InquirySave.hasClaims(commander)
    guard (c03Envelope ? NativeHollowManifestSave.hasClaims(commander)
      : secondEnvelope ? NativeSecondCommoditySaleSave.hasClaims(commander)
      : newtEnvelope ? CurrentNewtKitSave.hasClaims(commander)
      : watcherEnvelope ? NativeMemoryAtlasWatcherEnvelope.hasClaims(commander)
      : tradeEnvelope ? NativeFirstCommodityTradeSave.hasClaims(commander) : hasInquiry),
      try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432
    else { throw SaveError.invalidCommander }
    // This selects raw feature validators from retained claims. Their full logical
    // and physical predicates must still pass before the current reader can return.
    return .init(chunks: chunks, commander: commander,
      featureSchema: ScriptSaveStore.featurePublicationSchema(commander, alien: alien),
      hasInquiryClaims: hasInquiry,
      hasTradeClaims: NativeFirstCommodityTradeSave.hasClaims(commander),
      hasWatcherClaims: NativeMemoryAtlasWatcherEnvelope.hasClaims(commander),
      hasNewtClaims: CurrentNewtKitSave.hasClaims(commander),
      hasSecondClaims: NativeSecondCommoditySaleSave.hasClaims(commander))
  }
}
