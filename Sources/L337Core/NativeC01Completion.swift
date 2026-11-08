import Foundation

enum NativeC01EvidenceChoice: String, Codable, Sendable, CaseIterable {
  case publicReport = "c01-publish-full-safety-report"
  case arbitration = "c01-crew-arbitration"
  var label: String {
    switch self {
    case .publicReport: "Publish the full safety report"
    case .arbitration: "Submit the ledger to crew arbitration"
    }
  }
}

/// Descriptive history only. Live receiving offers are issued in the native board file.
struct NativeC01CompletionSource: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let permission: UUID
  let capture: UUID
  let marker: UUID
  let recorderActor: ActorIdentity
  let installation: UUID
  let clinicArrival: UUID
  let clinicReception: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let inventoryFingerprint: String
  let historyPresent: Bool
  let historyRevision: UInt64
  let historyFingerprint: String
  let missionRevision: UInt64
  let nextEvent: UInt64
  let funds: Int
  let physicalTime: Double
  let epoch: UUID

  var shapeValid: Bool {
    dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && dock.station.system == SystemIdentity(galaxy: 0, system: 7)
      && recorderActor.system == NativeC01Surveyor.location && recorderActor.entity > 1
      && recorderActor.entity < UInt64(Int64.max)
      && recorderActor.visit > 0 && recorderActor.visit < UInt64(Int64.max)
      && inventoryRevision < UInt64(Int64.max) && historyRevision < UInt64(Int64.max)
      && [missionRevision, nextEvent]
        .allSatisfy { $0 < UInt64(Int64.max) - 1 }
      && (historyPresent || historyRevision == 0)
      && ScriptCompletionReceipt.validDigest(inventoryFingerprint)
      && ScriptCompletionReceipt.validDigest(historyFingerprint)
      && (0...4_294_967_295).contains(funds)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }

  var wire: ScriptValue {
    .object([
      "mission": NativeC01Completion.uuid(mission), "owner": NativeC01Completion.uuid(owner),
      "permission": NativeC01Completion.uuid(permission), "capture": NativeC01Completion.uuid(capture),
      "marker": NativeC01Completion.uuid(marker), "recorderActor": NativeC01Completion.actor(recorderActor),
      "installation": NativeC01Completion.uuid(installation),
      "clinicArrival": NativeC01Completion.uuid(clinicArrival),
      "clinicReception": NativeC01Completion.uuid(clinicReception),
      "dock": NativeC01Completion.dock(dock), "carrier": NativeC01Completion.uuid(carrier),
      "inventoryRevision": .integer(Int64(inventoryRevision)),
      "inventoryFingerprint": .string(inventoryFingerprint), "historyPresent": .bool(historyPresent),
      "historyRevision": .integer(Int64(historyRevision)), "historyFingerprint": .string(historyFingerprint),
      "missionRevision": .integer(Int64(missionRevision)), "nextEvent": .integer(Int64(nextEvent)),
      "funds": .integer(Int64(funds)), "physicalTime": .number(physicalTime == 0 ? 0 : physicalTime),
      "epoch": NativeC01Completion.uuid(epoch), "definition": .string(NativeGlassMeridian.stateID),
      "version": .string(NativeGlassMeridian.version), "digest": .string(NativeGlassMeridian.digest),
    ])
  }
}

struct NativeC01DispositionReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let source: NativeC01CompletionSource
  let consent: UUID
  let choice: ScriptChoiceReceipt
}

struct NativeC01RecorderArchive: Codable, Sendable, Equatable {
  let operation: UUID
  let source: NativeC01CompletionSource
  let disposition: UUID
  let consent: UUID
  let sequence: UInt64
  let revision: UInt64
}

struct NativeC01PaymentHistory: Codable, Sendable, Equatable {
  let operation: UUID
  let archive: UUID
  let amount: Int
  let creditsBefore: Int
  let creditsAfter: Int
}

struct NativeC01TerminalHistory: Codable, Sendable, Equatable {
  let operation: UUID
  let archive: UUID
  let payment: NativeC01PaymentHistory
  let sequence: UInt64
  let revision: UInt64
  let journalCount: Int
  let journalFingerprint: String
  let clinicLosses: [UUID]
  let clinicDispositionRevision: UInt64
}

struct NativeC01PostTerminalClinicLoss: Codable, Sendable, Equatable {
  let operation: UUID
  let terminal: UUID
  let loss: UUID
  let sourceDisposition: UUID
  let ordinal: Int
  let sequence: UInt64
  let beforeRevision: UInt64
  let afterRevision: UInt64
  let physicalTime: Double
}

struct NativeC01CompletionState: Codable, Sendable, Equatable {
  let disposition: NativeC01DispositionReceipt
  var terminal: NativeC01TerminalHistory?
  var postTerminalClinicLoss: NativeC01PostTerminalClinicLoss?
}

enum NativeC01Completion {
  static let group = "meridian-disposition"
  static let dialogue = "c01-release-evidence"
  static let choiceReceipt = "c01-release-evidence"
  static let finalReceipt = "c01-close-case"
  static let archiveReceipt = "c01-original-recorder-archived"
  static let paymentReceipt = "c01-final-payment"
  static let finalTarget = "meridian-payment"
  static let payment = 48_000
  static let sourceID = "l337.glass-meridian"
  static let localReceipts: Set<String> = [
    choiceReceipt, group, finalReceipt, archiveReceipt, paymentReceipt, finalTarget,
  ]
  // Original authored identities stay separate from the engine's local receipt namespace.
  static let originalReceipts = [
    "l337.glass-meridian/release-evidence": choiceReceipt,
    "l337.glass-meridian/close-case": finalReceipt,
    "l337.glass-meridian/original-recorder-archived": archiveReceipt,
    "l337.glass-meridian/final-payment": paymentReceipt,
  ]
  static let casualtyJournal =
    "An actual clinic source Harrier was destroyed. Its registered hull and native crew casualty are recorded; no replacement was created and no escort arrival was granted."
  static let clueText =
    "The recovered timing standard contains an interval that none of the lane clocks measured. Inside that interval, a curved trace repeats eight times."

  static func uuid(_ value: UUID) -> ScriptValue { .string(value.uuidString) }
  static func system(_ value: SystemIdentity) -> ScriptValue {
    .object(["galaxy": .integer(Int64(value.galaxy)), "system": .integer(Int64(value.system))])
  }
  static func actor(_ value: ActorIdentity) -> ScriptValue {
    .object(["system": system(value.system), "visit": .integer(Int64(value.visit)),
      "entity": .integer(Int64(value.entity))])
  }
  static func dock(_ value: NativeMainStationDockReceipt) -> ScriptValue {
    .object([
      "station": .object(["world": uuid(value.station.world), "system": system(value.station.system),
        "resource": uuid(value.station.resource)]),
      "actor": actor(value.actor), "commanderOwner": uuid(value.commanderOwner),
      "sequence": .integer(Int64(value.sequence)),
      "calendarSeconds": .number(value.calendarSeconds == 0 ? 0 : value.calendarSeconds),
    ])
  }
  static func hash(_ domain: String, _ fields: [String: ScriptValue], limit: Int = 65536) throws -> String {
    ScriptPackLibrary.hash(try ScriptWire.encode([
      .string(domain), .integer(1), .object(fields),
    ], limit: limit))
  }
  static func operation(_ domain: String, _ fields: [String: ScriptValue]) throws -> UUID {
    ScriptIdentity.uuid(try hash(domain, fields))
  }
  static func dispositionOperation(
    source: NativeC01CompletionSource, consent: UUID, choice: NativeC01EvidenceChoice,
    sequence: UInt64, revision: UInt64
  ) throws -> UUID {
    try operation("elite.c01.completion.disposition.v1", [
      "source": source.wire, "consent": uuid(consent), "choice": .string(choice.rawValue),
      "label": .string(choice.label), "group": .string(group), "dialogue": .string(dialogue),
      "sequence": .integer(Int64(sequence)), "revision": .integer(Int64(revision)),
    ])
  }
  static func archiveOperation(
    source: NativeC01CompletionSource, consent: UUID, disposition: UUID,
    sequence: UInt64, revision: UInt64
  ) throws -> UUID {
    try operation("elite.c01.completion.archive.v1", [
      "source": source.wire, "consent": uuid(consent), "disposition": uuid(disposition),
      "sequence": .integer(Int64(sequence)), "revision": .integer(Int64(revision)),
    ])
  }
  static func paymentOperation(archive: UUID, before: Int, after: Int) throws -> UUID {
    try operation("elite.c01.completion.payment.v1", [
      "archive": uuid(archive), "amount": .integer(Int64(payment)),
      "creditsBefore": .integer(Int64(before)), "creditsAfter": .integer(Int64(after)),
    ])
  }
  static func terminalOperation(
    archive: UUID, payment: UUID, sequence: UInt64, revision: UInt64,
    journalCount: Int, journalFingerprint: String, clinicLosses: [UUID], clinicRevision: UInt64
  ) throws -> UUID {
    try operation("elite.c01.completion.terminal.v1", [
      "archive": uuid(archive), "payment": uuid(payment), "sequence": .integer(Int64(sequence)),
      "revision": .integer(Int64(revision)), "journalCount": .integer(Int64(journalCount)),
      "journalFingerprint": .string(journalFingerprint), "clinicLosses": .array(clinicLosses.map(uuid)),
      "clinicDispositionRevision": .integer(Int64(clinicRevision)),
    ])
  }
  static func postTerminalOperation(
    terminal: UUID, loss: NativeC01ClinicHullLoss, sequence: UInt64, before: UInt64, after: UInt64
  ) throws -> UUID {
    try operation("elite.c01.completion.postterminal-clinic-loss.v1", [
      "terminal": uuid(terminal), "loss": uuid(loss.operation),
      "sourceDisposition": uuid(loss.sourceDisposition), "ordinal": .integer(Int64(loss.ordinal)),
      "sequence": .integer(Int64(sequence)), "beforeRevision": .integer(Int64(before)),
      "afterRevision": .integer(Int64(after)), "physicalTime": .number(loss.physicalTime),
    ])
  }
  static func journalHash(_ entries: [String]) throws -> String {
    guard entries.count <= 512, entries.allSatisfy({ $0.utf8.count <= 12000 }) else {
      throw SaveError.invalidCommander
    }
    let hashes = try entries.enumerated().map { index, text in
      ScriptValue.string(try hash("elite.c01.completion.terminal-journal-entry.v1", [
        "index": .integer(Int64(index)), "text": .string(text),
      ], limit: 16384))
    }
    return try hash("elite.c01.completion.terminal-journal.v1", [
      "count": .integer(Int64(entries.count)), "entries": .array(hashes),
    ])
  }

  /// Shape selection only. Complete source validation belongs to the outer save seam.
  static func milestones(_ state: borrowing NativeGlassMeridianState) -> Set<Int> {
    if state.completion?.terminal != nil { return Set(0...8) }
    if state.completion != nil { return Set(0...7) }
    if state.clinicEscort?.arrival != nil { return Set(0...6) }
    if state.laneRepair?.installation != nil { return Set(0...5) }
    if state.timingStandard?.capture != nil { return Set(0...4) }
    if state.reservationCase?.audit != nil { return Set(0...3) }
    if state.surveyor?.capture != nil { return Set(0...2) }
    return state.readings.count == 2 ? [0, 1] : [0]
  }
  static func losses(_ state: NativeC01ClinicEscortState) -> [NativeC01ClinicHullLoss] {
    state.parkedLosses + state.launches.compactMap(\.loss)
  }
  static func selectedJournal(_ choice: NativeC01EvidenceChoice) -> String {
    let destination = choice == .publicReport ? "the public safety report" : "crew arbitration"
    return "Captain Venn received your choice: \(choice.label). The complete ledger is preserved for \(destination). Final payment and the clue require the same original 8kg recorder at Avenor archive receiving."
  }
  static func finalJournal(_ choice: NativeC01EvidenceChoice) -> String {
    "Captain Venn archived the same original 8kg recorder and received the completed lane-safety report. The selected outcome is \(choice.label). You received 4,800 CR, a public lane-safety commendation and The missing instant in your journal."
  }
  static func rumour(_ choice: NativeC01EvidenceChoice, complete: Bool) -> String {
    if complete {
      return "The Glass Meridian: \(choice.label). A public lane-safety commendation records the completed investigation."
    }
    let destination = choice == .publicReport ? "the public safety report" : "crew arbitration"
    return "The Glass Meridian: \(choice.label). Venn received the complete ledger for \(destination)."
  }
}
