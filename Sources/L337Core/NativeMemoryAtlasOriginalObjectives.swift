/// Original C25 story/gallery data. Testimony is not an instrument reading; neither this
/// source sequence nor a journal group grants native measurements, consent or progress.
enum NativeMemoryAtlasOriginalStage: String, CaseIterable, Sendable {
  case accept
  case collectReference = "collect-reference"
  case survey
  case fieldWork = "field-work"
  case independentWitness = "independent-witness"
  case chooseSettlement = "choose-settlement"
  case applySettlement = "apply-settlement"
  case returnAndAudit = "return-and-audit"
  case closeCase = "close-case"

  var world: SystemIdentity {
    let system: Int
    switch self {
    case .accept, .collectReference, .returnAndAudit, .closeCase: system = 80
    case .survey: system = 130
    case .fieldWork, .applySettlement: system = 8
    case .independentWitness, .chooseSettlement: system = 174
    }
    return .init(galaxy: 0, system: system)
  }

  var location: String {
    switch self {
    case .accept, .collectReference, .returnAndAudit, .closeCase: "Reris"
    case .survey: "Nedasen"
    case .fieldWork, .applySettlement: "Cemalis"
    case .independentWitness, .chooseSettlement: "Ledanor"
    }
  }

  var objective: String {
    switch self {
    case .accept: "Accept The Memory Atlas at Reris."
    case .collectReference: "Collect the identified one-tonne reference instrument from Agent Mara Vale."
    case .survey: "Observe three actual orbital landmarks independently of the consented travel diaries."
    case .fieldWork: "Compare two landmark instruments with the onboard reference watcher."
    case .independentWitness: "Verify actual safe transit and living reception of the consenting diary custodian to the archive receiving berth."
    case .chooseSettlement: "At the actual witness receiving station, choose the settlement with the arrived authorised operator delegates."
    case .applySettlement: "Verify both independent proofs for the selected settlement."
    case .returnAndAudit: "Return the reference instrument and confirm all physical receiving and settlement receipts."
    case .closeCase: "Confirm successful completion, the recorded settlement and the once-only fee."
    }
  }

  var dialogue: String {
    switch self {
    case .accept: "Agent Mara Vale: A navigation publisher has combined voluntary travel diaries with instrument surveys and now presents memories as exact route measurements. Review the complete survey, loan and receiving requirements before confirming."
    case .collectReference: "Agent Mara Vale: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity."
    case .survey: "ORR: A beautiful memory is not a measured approach vector."
    case .fieldWork: "VALE: Keep consent attached to testimony and uncertainty attached to measurements."
    case .independentWitness: "VALE: The custodian decides which memories become public."
    case .chooseSettlement: "Agent Mara Vale: Your measurement and testimony separation evidence is ready. Our arrived delegates have the signed mandate to choose here. Either publish a separated evidence-and-memory atlas or keep the diaries with their custodians. Compare the actual tests and consequences before confirming; closing this view chooses neither."
    case .applySettlement: "Agent Mara Vale: The selected plan must work in the physical system. A statement or unrelated kill cannot supply either proof."
    case .returnAndAudit: "Agent Mara Vale: The loan is returned. Check the actual observations, living witness reception and both selected settlement proofs before closing the case."
    case .closeCase: "Agent Mara Vale: The independent audit is complete. Your fee is 7200 CR. The operators retain the chosen settlement and their original records.\n\nAgent Mara Vale: The audit has left one anomaly that belongs to neither side. Three unrelated diaries contain the same inward curve around a place none of their authors visited. It is preserved in your journal for the AI at PLUGH."
    }
  }

  func requiredTargets(for settlement: NativeMemoryAtlasSettlement? = nil) -> [String]? {
    switch self {
    case .accept: ["accept-verified"]
    case .collectReference: ["collect-reference-verified"]
    case .survey: ["memory-atlas-survey-1", "memory-atlas-survey-2", "memory-atlas-survey-3"]
    case .fieldWork: ["memory-atlas-work-port", "memory-atlas-work-starboard"]
    case .independentWitness: ["memory-atlas-witness-received"]
    case .chooseSettlement: ["memory-atlas-settlement-choice"]
    case .applySettlement: settlement?.requiredTargets
    case .returnAndAudit: ["return-and-audit-verified"]
    case .closeCase: ["close-case-verified"]
    }
  }

  var authoredEvent: String {
    switch self {
    case .accept, .collectReference, .returnAndAudit, .closeCase: "mission_contact_confirmed"
    case .survey: "entity_scan_completed"
    case .fieldWork, .applySettlement: "mission_action_confirmed"
    case .independentWitness: "escort_arrived"
    case .chooseSettlement: "mission_choice_confirmed"
    }
  }

  var choices: [String] {
    self == .chooseSettlement ? NativeMemoryAtlasSettlement.allCases.map(\.title) : []
  }

  var next: Self? {
    switch self {
    case .accept: .collectReference
    case .collectReference: .survey
    case .survey: .fieldWork
    case .fieldWork: .independentWitness
    case .independentWitness: .chooseSettlement
    case .chooseSettlement: .applySettlement
    case .applySettlement: .returnAndAudit
    case .returnAndAudit: .closeCase
    case .closeCase: nil
    }
  }

  /// Presentation grouping from physical-v2, not a new state machine or completion rule.
  /// Co-located stages may share one panel while retaining each real atomic receipt.
  var journalPhase: NativeMemoryAtlasJournalPhase {
    switch self {
    case .accept, .collectReference, .survey: .establishEvidence
    case .fieldWork: .compareInstruments
    case .independentWitness, .chooseSettlement: .reviewIndependentEvidence
    case .applySettlement, .returnAndAudit, .closeCase: .verifySettlement
    }
  }

  var receipt: String { NativeMemoryAtlasOriginalReward.source + "/" + rawValue }
}

/// Player-facing wording for the profile's four journal groups, never a skip control.
enum NativeMemoryAtlasJournalPhase: CaseIterable, Equatable, Sendable {
  case establishEvidence, compareInstruments, reviewIndependentEvidence, verifySettlement
  var title: String {
    switch self {
    case .establishEvidence: "Establish the evidence"
    case .compareInstruments: "Compare the instruments"
    case .reviewIndependentEvidence: "Review the independent evidence"
    case .verifySettlement: "Verify the settlement"
    }
  }
}

enum NativeMemoryAtlasSettlement: String, CaseIterable, Sendable {
  case separatedAtlas = "plan-a"
  case privateCustody = "plan-b"

  var title: String {
    switch self {
    case .separatedAtlas: "Publish a separated evidence-and-memory atlas"
    case .privateCustody: "Keep the diaries with their custodians"
    }
  }

  var requiredTargets: [String] {
    switch self {
    case .separatedAtlas: ["memory-atlas-plan-a-physical-proof", "memory-atlas-plan-a-receiving-proof"]
    case .privateCustody: ["memory-atlas-plan-b-physical-proof", "memory-atlas-plan-b-receiving-proof"]
    }
  }

  var objective: String {
    switch self {
    case .separatedAtlas: "Verify independent measurement labels and each contributor's consent."
    case .privateCustody: "Verify restricted custody and publish only measured hazard corrections."
    }
  }

  var dialogue: String {
    switch self {
    case .separatedAtlas: "ORR: Let readers see where testimony ends and the instrument begins."
    case .privateCustody: "VALE: Privacy does not require keeping an unsafe chart in circulation."
    }
  }

  var gossip: String { "The Memory Atlas: " + title + "." }
}

enum NativeMemoryAtlasOriginalReward {
  static let source = "l337.memory-atlas"
  static let tenths = 72_000
  static let paymentReceipt = "l337.memory-atlas/final-payment"
  static let clue = "memory-atlas-trace"
  static let clueReceipt = "l337.unwritten-route/clue/memory-atlas-trace"
  static let clueJournal = "Three unrelated diaries contain the same inward curve around a place none of their authors visited."
}
