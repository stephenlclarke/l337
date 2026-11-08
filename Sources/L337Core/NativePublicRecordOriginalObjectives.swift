/// Exact original C37 story values, not observer consent, routing measurements, evidence versions or receiving authority.
enum NativePublicRecordOriginalStage: String, CaseIterable, Sendable {
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
    case .accept: .init(galaxy: 4, system: 12)
    case .collectReference: .init(galaxy: 4, system: 12)
    case .survey: .init(galaxy: 4, system: 166)
    case .fieldWork: .init(galaxy: 4, system: 24)
    case .independentWitness: .init(galaxy: 4, system: 3)
    case .chooseSettlement: .init(galaxy: 4, system: 3)
    case .applySettlement: .init(galaxy: 4, system: 24)
    case .returnAndAudit: .init(galaxy: 4, system: 12)
    case .closeCase: .init(galaxy: 4, system: 12)
    }
  }

  var location: String {
    switch self {
    case .accept: "Fenias"
    case .collectReference: "Fenias"
    case .survey: "Fenel"
    case .fieldWork: "Heroeth"
    case .independentWitness: "Voron"
    case .chooseSettlement: "Voron"
    case .applySettlement: "Heroeth"
    case .returnAndAudit: "Fenias"
    case .closeCase: "Fenias"
    }
  }

  var objective: String {
    switch self {
    case .accept: "Accept Public Record at Fenias."
    case .collectReference: "Collect the identified one-tonne reference instrument from Dispatcher Neris Sol."
    case .survey: "Observe three actual cargo-routing decisions under the source observers consent."
    case .fieldWork: "Compare two external route controllers with the original public recorder; freeze the independently measured evidence version."
    case .independentWitness: "Verify actual safe transit and living reception of the consenting technical witness to the newsroom receiving berth."
    case .chooseSettlement: "At the actual witness receiving station, choose the settlement with the arrived authorised operator delegates."
    case .applySettlement: "Verify both independent proofs for the selected settlement."
    case .returnAndAudit: "Return the reference instrument and confirm all physical receiving and settlement receipts."
    case .closeCase: "Confirm successful completion, the recorded settlement and the once-only fee."
    }
  }

  var dialogue: String {
    switch self {
    case .accept: "Dispatcher Neris Sol: An orbital news service wants to report a dangerous cargo-routing fault, but its sponsor owns the only accepted recording instrument. Review the complete survey, loan and receiving requirements before confirming."
    case .collectReference: "Dispatcher Neris Sol: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity."
    case .survey: "SOL: A story that cannot survive an independent reading is not ready to publish."
    case .fieldWork: "TOREN: Keep the sponsor's record beside the independent one. Disagreement is evidence, not a verdict."
    case .independentWitness: "SOL: The witness chooses what to disclose and must actually arrive safely."
    case .chooseSettlement: "Dispatcher Neris Sol: Your right-of-reply without evidence mutation evidence is ready. Our arrived delegates have the signed mandate to choose here. Either release the complete anonymised evidence set or use a witnessed right-of-reply hearing. Compare the actual tests and consequences before confirming; closing this view chooses neither."
    case .applySettlement: "Dispatcher Neris Sol: The selected plan must work in the physical system. A statement or unrelated kill cannot supply either proof."
    case .returnAndAudit: "Dispatcher Neris Sol: The loan is returned. Check the actual observations, living witness reception and both selected settlement proofs before closing the case."
    case .closeCase: "Dispatcher Neris Sol: The independent audit is complete. Your fee is 6300 CR. The operators retain the chosen settlement and their original records.\n\nDispatcher Neris Sol: The audit has left one anomaly that belongs to neither side. The independent recorder captures a curved phase boundary outside the cargo controllers' published operating bands. It is preserved in your journal for the AI at PLUGH."
    }
  }
}

enum NativePublicRecordOriginalReward {
  static let source = "l337.public-record"
  static let tenths = 63_000
  static let paymentReceipt = "l337.public-record/final-payment"
  static let clue = "public-record-trace"
  static let clueReceipt = "l337.unwritten-route/clue/public-record-trace"
  static let clueJournal = "The independent recorder captures a curved phase boundary outside the cargo controllers' published operating bands."
}
