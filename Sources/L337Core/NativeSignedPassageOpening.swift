import Foundation

/// Current historical commission only; no original stock, serial or custody is created.
struct NativeSignedPassageOpeningRecord: Codable, Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let acceptance: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let trade: UUID
  let eventSequence: UInt64
  let physicalTime: Double
  let calendarSeconds: Double

  var valid: Bool {
    mission == NativeSignedPassageOpening.mission(owner: owner)
      && acceptance == NativeSignedPassageOpening.operation(mission: mission, dock: dock)
      && inventoryRevision < UInt64(Int64.max)
      && dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == NativeSignedPassageOpening.issuer
      && eventSequence > 0 && eventSequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarSeconds.isFinite && calendarSeconds >= dock.calendarSeconds
      && calendarSeconds <= 1e12
  }
}

struct NativeSignedPassageOpeningState: Codable, Equatable, Sendable {
  let opening: NativeSignedPassageOpeningRecord

  init(opening: NativeSignedPassageOpeningRecord) throws {
    guard opening.valid else { throw SaveError.invalidCommander }
    self.opening = opening
  }

  var valid: Bool { opening.valid }
}

/// Original C38 opening only. Later measured and receiving stages are separate native work.
enum NativeSignedPassageOpening {
  static let sourceID = NativeSignedPassageOpening.Reward.source
  static let missionID = "courier"
  static let stateID = "l337.contract/courier"
  static let version = "1.0.0"
  static let sourceSHA256 = "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3"
  static let issuer = NativeSignedPassageOpening.Stage.accept.world
  static let issuerName = NativeSignedPassageOpening.Stage.accept.location
  static let contactRole = "Dispatcher Evi Senn"
  static let acceptance = "courier-accept"
  // Byte/hash prediction from the current ScriptWire framing; G1 must verify with the reader.
  static let digest = "12c6eb5fe201d8cad7ccaab6036c1704e40b93e0c7df9a576d0134b04a38f79d"
  static let manifestSHA256 = "cd021318ebfe0951eab3d3013697c9f745a434cd8f4ec8c8568d793299c9fe9b"
  static let moduleSHA256 = "69768637ce54385c22450d9b90f02e7a41efbf4ab939611908b909de11f30b0e"
  static let briefing = [
    "SENN: Departure is a promise. Delivery is the receiver taking this exact consignment.",
    NativeSignedPassageOpening.Stage.accept.dialogue,
  ]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("signed-passage-opening-v1:\(owner)")
  }

  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == stateID { return true }
    if instance.digest == digest { return true }
    return instance.savedNativeSignedPassageOpening != nil
  }

  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID || pack.digest == digest
  }

  static func matches(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
      && ScriptPackLibrary.hash(pack.manifestBytes) == manifestSHA256
      && ScriptPackLibrary.hash(pack.source) == moduleSHA256 && pack.entryBytes == pack.source
      && pack.models.isEmpty && pack.resourceBytes.isEmpty
      && pack.manifest.board == nil && pack.manifest.providerContract == nil
      && pack.manifest.courier == nil
      && pack.manifest.equipment == nil && pack.manifest.encounters == nil
      && pack.manifest.npcs == nil && pack.manifest.modules == nil && pack.manifest.trial == nil
      && pack.manifest.handlers.count == 1
      && pack.manifest.handlers.first?.event == "mission.accepted"
      && pack.manifest.handlers.first?.function == "accepted"
      && Set(pack.manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
      && pack.manifest.mission.milestones == NativeSignedPassageOpening.Stage.allCases.map(\.objective)
  }

  /// Identifies this actual historical acceptance, never an item or collection.
  static func operation(mission: UUID, dock: NativeMainStationDockReceipt) -> UUID {
    ScriptIdentity.uuid("signed-passage-contact-v1:\(mission):accept:\(dock.sequence)")
  }

  /// Maps the retained native acceptance; this is not a live source capability.
  static func authoredReceipt(event: String, target: String, instance: borrowing ScriptInstance)
    -> String?
  {
    guard event == "mission_contact_confirmed", target == "accept-verified",
      marked(instance), prefixValid(instance), instance.journal == briefing,
      let saved = instance.savedNativeSignedPassageOpening,
      instance.hasAcknowledged(saved.opening.eventSequence)
    else { return nil }
    return "l337.courier/accept"
  }

  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else { return }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
    else { throw MissionPackError("Restore the original Signed Passage commission.") }
  }

  /// Only the original acceptance prefix exists; reading cannot qualify a physical stage.
  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativeSignedPassageOpening.marked(instance) else { return true }
    guard instance.definition == NativeSignedPassageOpening.stateID,
      instance.version == NativeSignedPassageOpening.version,
      instance.digest == NativeSignedPassageOpening.digest,
      let state = instance.savedNativeSignedPassageOpening, state.valid,
      instance.id == state.opening.mission, instance.outcome == .active,
      instance.revision < UInt64(Int64.max),
      instance.receipts == [NativeSignedPassageOpening.acceptance], instance.milestones == [0],
      instance.contract == nil, instance.completionReceipt == nil, instance.gearIssues.isEmpty,
      instance.payloads.isEmpty, instance.timers.isEmpty, instance.dialogue == nil,
      instance.choiceReceipts.isEmpty, instance.conversationReceipts.isEmpty,
      instance.ownedEncounters.isEmpty, instance.campaignParent == nil,
      instance.campaignChildren.isEmpty, instance.data == .object([:]),
      instance.journal.count <= NativeSignedPassageOpening.briefing.count,
      instance.journal == Array(NativeSignedPassageOpening.briefing.prefix(instance.journal.count))
    else { return false }
    return true
  }

  enum Stage: String, CaseIterable, Sendable {
    case accept = "accept"
    case collectReference = "collect-reference"
    case survey = "survey"
    case fieldWork = "field-work"
    case independentWitness = "independent-witness"
    case chooseSettlement = "choose-settlement"
    case applySettlement = "apply-settlement"
    case returnAndAudit = "return-and-audit"
    case closeCase = "close-case"

    var world: SystemIdentity {
      switch self {
      case .accept: .init(galaxy: 0, system: 49)
      case .collectReference: .init(galaxy: 0, system: 49)
      case .survey: .init(galaxy: 0, system: 160)
      case .fieldWork: .init(galaxy: 0, system: 34)
      case .independentWitness: .init(galaxy: 0, system: 2)
      case .chooseSettlement: .init(galaxy: 0, system: 2)
      case .applySettlement: .init(galaxy: 0, system: 34)
      case .returnAndAudit: .init(galaxy: 0, system: 49)
      case .closeCase: .init(galaxy: 0, system: 49)
      }
    }

    var location: String {
      switch self {
      case .accept: "Neron"
      case .collectReference: "Neron"
      case .survey: "Lalen"
      case .fieldWork: "Illalis"
      case .independentWitness: "Aetaria"
      case .chooseSettlement: "Aetaria"
      case .applySettlement: "Illalis"
      case .returnAndAudit: "Neron"
      case .closeCase: "Neron"
      }
    }

    var objective: String {
      switch self {
      case .accept: "Accept Signed Passage at Neron."
      case .collectReference: "Collect the identified one-tonne reference instrument from Dispatcher Evi Senn."
      case .survey: "Observe three actual receiving cradles and compare allocation time with receipt-signing time."
      case .fieldWork: "Move the same identified source-owned test crate through two actual cradle transfers under the onboard reference."
      case .independentWitness: "Verify actual safe transit and living reception of the independent receiving witness to the archive berth."
      case .chooseSettlement: "At the actual witness receiving station, choose the settlement with the arrived authorised operator delegates."
      case .applySettlement: "Verify both independent proofs for the selected settlement."
      case .returnAndAudit: "Return the reference instrument and confirm all physical receiving and settlement receipts."
      case .closeCase: "Confirm successful completion, the recorded settlement and the once-only fee."
      }
    }

    var dialogue: String {
      switch self {
      case .accept: "Dispatcher Evi Senn: An orbital receiving service repeatedly loses custody of a harmless calibration shipment during carrier handoffs. Review the complete survey, loan and receiving requirements before confirming."
      case .collectReference: "Dispatcher Evi Senn: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity."
      case .survey: "SENN: Departure is a promise. Delivery is the receiver taking this exact consignment."
      case .fieldWork: "TOREN: A receipt cannot arrive before its receiving cradle exists."
      case .independentWitness: "SENN: The witness must arrive and examine the same custody chain."
      case .chooseSettlement: "Dispatcher Evi Senn: Your physical release-before-receive interlock evidence is ready. Our arrived delegates have the signed mandate to choose here. Either use independently signed receiving locks or create a shared bounded custody register. Compare the actual tests and consequences before confirming; closing this view chooses neither."
      case .applySettlement: "Dispatcher Evi Senn: The selected plan must work in the physical system. A statement or unrelated kill cannot supply either proof."
      case .returnAndAudit: "Dispatcher Evi Senn: The loan is returned. Check the actual observations, living witness reception and both selected settlement proofs before closing the case."
      case .closeCase: "Dispatcher Evi Senn: The independent audit is complete. Your fee is 4300 CR. The operators retain the chosen settlement and their original records.\n\nDispatcher Evi Senn: The audit has left one anomaly that belongs to neither side. An early receiving receipt has an inward-curved watermark for a destination absent from all freight charts. It is preserved in your journal for the AI at PLUGH."
      }
    }
  }

  enum Reward {
    static let source = "l337.courier"
    static let tenths = 43_000
    static let paymentReceipt = "l337.courier/final-payment"
    static let clue = "courier-empty-destination"
    static let clueReceipt = "l337.unwritten-route/clue/courier-empty-destination"
    static let clueJournal = "An early receiving receipt has an inward-curved watermark for a destination absent from all freight charts."
  }

  enum Reference {
    static let logicalResource = "courier-reference"
    static let name = "Signed Passage Reference Instrument"
    static let node = EquipmentNodeID(family: .init("courier-reference"), key: name)
    static let cargoTonnes = 1
    static let purchaseNode = EquipmentPurchaseNode(
      id: node, displayName: name, policy: .acquisitionOnly)

    /// A genuine future native issuer chooses the original physical resource and serial.
    static func gear(for source: EquipmentIssueSource) -> ScriptGearDefinition {
      .init(id: source.resource, name: name, quantity: 1, loan: true,
        mount: nil, returnPolicy: "all")
    }

    /// Inventory mass only, never test-crate custody, carrier permission, atomic receiving or witness authority.
    static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
      inventory?.items.filter { $0.node == node }.count ?? 0
    }
  }
}

extension ScriptPackLibrary {
  static var bundledSignedPassageDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-signed-passage")
  }
}

extension Game {
  /// Lua may record only the two original briefing lines during the real acceptance event.
  /// Actual original reference stock, crate handoffs and living reception belong to native transactions.
  func validateSignedPassageOpeningScriptCommand(_ fields: [String: ScriptValue],
    event: ScriptEvent, pack: ScriptPack, state: borrowing ScriptInstance,
    candidate: borrowing Commander) throws
  {
    let protected = NativeSignedPassageOpening.applies(pack)
    if !protected, !NativeSignedPassageOpening.marked(state) { return }
    guard NativeSignedPassageOpening.matches(pack),
      NativeSignedPassageOpening.prefixValid(state),
      let saved = state.savedNativeSignedPassageOpening,
      scriptDispatching, event.kind == "mission.accepted", event.instance == state.id,
      event.sequence == saved.opening.eventSequence,
      candidate.scriptState.pendingEvents.contains(event),
      candidate.scriptState.instances[state.id]?.savedNativeSignedPassageOpening == saved,
      Set(fields.keys) == ["op", "text"], fields["op"]?.string == "journal.append",
      NativeSignedPassageOpening.briefing.indices.contains(state.journal.count),
      fields["text"]?.string == NativeSignedPassageOpening.briefing[state.journal.count]
    else { throw MissionPackError("Use the original Signed Passage contact, custody and physical-stage transactions.") }
  }
}
