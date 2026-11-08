/// Ledger C04 original story/gallery data, not the historical NativeC04 Shattered Wake
/// filename prefix. No label, event or next value supplies a native operation or proof.
enum NativeBorrowedVoiceOriginalStage: String, CaseIterable, Sendable {
  case accept
  case verifyDistress = "verify-distress"
  case collectVerifier = "collect-verifier"
  case meetDispatcher = "meet-dispatcher"
  case protectDispatcher = "protect-dispatcher"
  case chooseOperation = "choose-operation"
  case interceptOrders = "intercept-orders"
  case auditAccess = "audit-access"
  case restoreChannels = "restore-channels"
  case closeCase = "close-case"

  var world: SystemIdentity {
    let system: Int
    switch self {
    case .accept, .chooseOperation, .closeCase: system = 20
    case .verifyDistress, .interceptOrders, .restoreChannels: system = 137
    case .collectVerifier, .meetDispatcher, .protectDispatcher: system = 56
    case .auditAccess: system = 129
    }
    return .init(galaxy: 2, system: system)
  }

  var location: String {
    switch self {
    case .accept, .chooseOperation, .closeCase: "Taledea"
    case .verifyDistress, .interceptOrders, .restoreChannels: "Ilasaeli"
    case .collectVerifier, .meetDispatcher, .protectDispatcher: "Noserin"
    case .auditAccess: "Aiven"
    }
  }

  var objective: String {
    switch self {
    case .accept: "Accept the rescue-channel investigation at Taledea."
    case .verifyDistress: "Compare the three marked distress beacons with their local casualty sensors at Ilasaeli."
    case .collectVerifier: "Dock at Noserin and collect Ivo Renn's one-tonne independent verifier."
    case .meetDispatcher: "At Noserin, use the private rescue terminal to confirm Neris Sol's account of the duplicate enrollment."
    case .protectDispatcher: "Escort Sol's marked Harrier from the maintenance refuge to Noserin station."
    case .chooseOperation: "Return to Taledea and choose how to isolate the infiltrating operator."
    case .interceptOrders: "At Ilasaeli, carry out the selected operation and obtain its authenticated proof."
    case .auditAccess: "Dock at Aiven and return the verifier with the authenticated record to Ivo Renn."
    case .restoreChannels: "Rekey the three marked rescue beacons at Ilasaeli and confirm a clean service test."
    case .closeCase: "Dock at Taledea, confirm the restored rescue network and collect the agreed fee."
    }
  }

  var dialogue: String {
    switch self {
    case .accept: "DAIN: These calls use a genuine rescue key. I cannot tell the tenders to ignore it until we can distinguish a victim from an imitation. Take measurements first. An accusation will not keep anyone alive."
    case .verifyDistress: "Two calls advertise occupied wrecks but have no cabin heat, escape telemetry or life signs. A third service beacon matches an actual casualty. All three were signed with the same operator key; only the empty calls contain a second enrollment stamp."
    case .collectVerifier: "RENN: This verifier listens without identifying your position to the rescue network. One tonne of free hold is enough. I will keep it here until you have room. Return it with the signed access record; I need the physical clock to prove when the key was used."
    case .meetDispatcher: "SOL: I am speaking from the maintenance refuge, through Renn's isolated link. I cancelled a relief shift that I had never booked. The account remained active after I went off duty. I saved the enrollment challenge before they shut me out. Bring my Harrier to a protected berth here at Noserin before you challenge that account."
    case .protectDispatcher: "SOL: I will follow you from the maintenance refuge to rescue control. Stay with my Harrier until the station confirms the protected berth. If the ship is lost, the station rescue tug will recover my emergency capsule; the protected extraction can resume once I am back at the refuge."
    case .chooseOperation: "DAIN: Sol is safe. We can revoke the key openly and obtain its frozen access audit, stopping the false calls now. Or use an unoccupied decoy and a passive receiver to identify the syndicate's observer before revoking it. Both protect the tenders. We will not use a real casualty as bait."
    case .interceptOrders: "Use the independent verifier at the marked service nodes. Only the targets for your chosen operation are active. Destroying an observer or an unrelated ship does not produce a verified access record."
    case .auditAccess: "RENN: The physical clock and enrollment challenge agree. This account has been selling live rescue movements under Sol's name. Rescue control can revoke its credentials and submit the signed record to the local hearing. I have kept the unrelated patient records sealed."
    case .restoreChannels: "Each beacon accepts its own new key and passes a local test. The old duplicate account can no longer issue calls. The rescue tenders receive a route containing genuine casualties and no observer subscriptions."
    case .closeCase: "DAIN: Sol is safe, the duplicate account is closed and the tenders are answering real calls again. Your fee is 7,200 CR. The hearing receives the authenticated record; your chosen disclosure policy protects the witness.\n\nRENN: One reply is not in either operator's access record. Its phase curls around an empty centre, and its timestamp precedes the challenge. It is not evidence against Sol or the observer. I have copied the anomaly to your journal; PLUGH's AI may recognise its shape."
    }
  }

  /// The actual case owns the retained choice. Unset interception is unresolved;
  /// neither its authored summary nor an empty requirement list can replace branch proof.
  func requiredTargets(for operation: NativeBorrowedVoiceOperation? = nil) -> [String]? {
    switch self {
    case .accept: ["dain-commission"]
    case .verifyDistress: ["empty-beacon-one", "empty-beacon-two", "occupied-service-beacon"]
    case .collectVerifier: ["renn-verifier-handover"]
    case .meetDispatcher: ["sol-witness-statement"]
    case .protectDispatcher: ["sol-protected-arrival"]
    case .chooseOperation: ["rescue-operation-choice"]
    case .interceptOrders: operation?.requiredTargets
    case .auditAccess: ["renn-access-audit"]
    case .restoreChannels: ["rekey-beacon-one", "rekey-beacon-two", "rekey-service-beacon"]
    case .closeCase: ["dain-payment"]
    }
  }

  var authoredEvent: String {
    switch self {
    case .accept, .collectVerifier, .meetDispatcher, .auditAccess, .closeCase: "mission_contact_confirmed"
    case .verifyDistress: "entity_scan_completed"
    case .protectDispatcher: "escort_arrived"
    case .chooseOperation: "mission_choice_confirmed"
    case .interceptOrders, .restoreChannels: "mission_action_confirmed"
    }
  }

  var choices: [String] {
    self == .chooseOperation ? NativeBorrowedVoiceOperation.allCases.map(\.title) : []
  }

  var next: Self? {
    switch self {
    case .accept: .verifyDistress
    case .verifyDistress: .collectVerifier
    case .collectVerifier: .meetDispatcher
    case .meetDispatcher: .protectDispatcher
    case .protectDispatcher: .chooseOperation
    case .chooseOperation: .interceptOrders
    case .interceptOrders: .auditAccess
    case .auditAccess: .restoreChannels
    case .restoreChannels: .closeCase
    case .closeCase: nil
    }
  }

  var receipt: String { NativeBorrowedVoiceOriginalReward.source + "/" + rawValue }
}

enum NativeBorrowedVoiceOperation: String, CaseIterable, Sendable {
  case openRevocation = "open-revocation"
  case quietDecoy = "quiet-decoy"

  var title: String {
    switch self {
    case .openRevocation: "Revoke the compromised key openly"
    case .quietDecoy: "Identify the observer with an empty decoy"
    }
  }

  var requiredTargets: [String] {
    switch self {
    case .openRevocation: ["key-revocation-ack", "frozen-access-audit"]
    case .quietDecoy: ["unoccupied-decoy-armed", "observer-receipt-recovered"]
    }
  }

  var objective: String {
    switch self {
    case .openRevocation: "Confirm key revocation at the Ilasaeli rescue relay, then use the verifier to download its frozen signed audit."
    case .quietDecoy: "Arm the empty decoy beacon, then retrieve the observer's signed handshake from the passive receiver at Ilasaeli."
    }
  }

  var dialogue: String {
    switch self {
    case .openRevocation: "The network revokes the duplicate key and isolates its queued calls. The frozen audit contains a paid subscription to rescue positions, signed by the second operator account. The tenders are rerouted through the spare channel."
    case .quietDecoy: "The empty decoy advertises a service outage without passenger or patient data. A syndicate observer answers it. Your passive receiver records its paid subscription handshake; rescue control then revokes the duplicate key. The observer need not be destroyed or pursued."
    }
  }

  var gossip: String {
    switch self {
    case .openRevocation: "The compromised rescue key was revoked publicly; the signed access audit is available to affected crews. Sol's location remains confidential."
    case .quietDecoy: "A protected rescue operation exposed the syndicate's subscription account. The witness and the passive receiver's position remain confidential."
    }
  }
}

enum NativeBorrowedVoiceOriginalReward {
  static let source = "l337.borrowed-voice"
  static let tenths = 72_000
  static let paymentReceipt = "l337.borrowed-voice/final-payment"
  static let clue = "voice-unclaimed-channel"
  static let clueReceipt = "l337.unwritten-route/clue/voice-unclaimed-channel"
  static let clueJournal = "The independent verifier recorded a reply before its verification challenge could have transmitted. Its curved phase trace folds around a quiet centre, as though the receiver were inside a larger listening ring."
}
