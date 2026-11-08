/// Original C02 objective source for the native mission and its gallery. These values are
/// not receipts, progress, paid access or native authority. Generic events cannot advance it.
enum NativeC02OriginalStage: String, CaseIterable, Sendable {
  case accept = "accept"
  case calibrate = "calibrate"
  case recoverCollector = "recover-collector"
  case interpret = "interpret"
  case repairProbe = "repair-probe"
  case listen = "listen"
  case exposeImitation = "expose-imitation"
  case rendezvous = "rendezvous"
  case closeCase = "close-case"

  var world: SystemIdentity {
    switch self {
    case .accept: .init(galaxy: 3, system: 40)
    case .calibrate: .init(galaxy: 3, system: 249)
    case .recoverCollector: .init(galaxy: 3, system: 78)
    case .interpret: .init(galaxy: 3, system: 109)
    case .repairProbe: .init(galaxy: 3, system: 184)
    case .listen: .init(galaxy: 3, system: 127)
    case .exposeImitation: .init(galaxy: 3, system: 132)
    case .rendezvous: .init(galaxy: 3, system: 40)
    case .closeCase: .init(galaxy: 3, system: 40)
    }
  }

  var location: String {
    switch self {
    case .accept: "Omdogan"
    case .calibrate: "Lobagom"
    case .recoverCollector: "Lodogom"
    case .interpret: "Balmabol"
    case .repairProbe: "Balgodan"
    case .listen: "Dalonom"
    case .exposeImitation: "Fobolan"
    case .rendezvous: "Omdogan"
    case .closeCase: "Omdogan"
    }
  }

  var objective: String {
    switch self {
    case .accept: "Accept Holt's signal investigation at Omdogan."
    case .calibrate: "Scan three reference emitters at Lobagom to separate receiver drift from outside interference."
    case .recoverCollector: "Recover a one-tonne phase collector from the damaged mining relay at Lodogom."
    case .interpret: "Dock at Balmabol and let Mara Vale reconstruct the signal."
    case .repairProbe: "Deliver the loaned repair culture to the stranded Larvaal Probe at Balgodan."
    case .listen: "Listen at three safe positions around the Larvaal gathering at Dalonom."
    case .exposeImitation: "Locate and silence the counterfeit emitter at Fobolan."
    case .rendezvous: "Transmit the corrected reply at Omdogan and choose a rendezvous protocol."
    case .closeCase: "Dock at Omdogan and confirm the completed signal accord."
    }
  }

  var dialogue: String {
    switch self {
    case .accept: "HOLT: Our miners are losing their bearings. I will not order an attack on the basis of interference. Find out whether someone is calling, warning or hiding."
    case .calibrate: "The receiver is stable. The interference contains a deliberate pause after every third pulse, repeated across all three bands."
    case .recoverCollector: "A passive collector has recorded the missing phase information. The relay is dead, but its sealed recorder can be recovered without disabling any ship."
    case .interpret: "VALE: This is a gathering call. Each pause leaves room for a reply from a missing companion. Someone has copied the loud part and omitted the listening interval."
    case .repairProbe: "The jade shell opens around the damaged resonator. The repair culture bridges a broken fold; the probe answers with a short gold pulse."
    case .listen: "Three listening positions reveal an empty place in the call. The missing voice should be near Fobolan, where the repeated signal never pauses."
    case .exposeImitation: "Human freight seals surround the emitter. Present its copied certificate to make the smugglers abandon it, or disable the exposed transmitter. Destroying unrelated ships proves nothing."
    case .rendezvous: "VALE: We can publish the narrow-band greeting for civilian receivers, or establish a supervised relay while both sides learn its limits."
    case .closeCase: "HOLT: The miners have clean guidance channels. The Larvaal vessels have a safe gathering frequency. Your fee is 6,400 CR; the passive resonance filter is ready for fitting.\n\nVALE: One voice answered from outside the gathering. The Larvaal listeners do not recognise it. Its pauses form a pattern like a map. I have preserved the reply in your journal."
    }
  }

  var authoredEvent: String {
    switch self {
    case .accept: "mission_contact_confirmed"
    case .calibrate: "entity_scan_completed"
    case .recoverCollector: "mission_item_recovered"
    case .interpret: "mission_contact_confirmed"
    case .repairProbe: "mission_action_confirmed"
    case .listen: "entity_scan_completed"
    case .exposeImitation: "mission_action_confirmed"
    case .rendezvous: "mission_choice_confirmed"
    case .closeCase: "mission_contact_confirmed"
    }
  }

  var requiredTargets: [String] {
    switch self {
    case .accept: ["holt-commission"]
    case .calibrate: ["reference-low", "reference-mid", "reference-high"]
    case .recoverCollector: ["phase-collector"]
    case .interpret: ["vale-analysis"]
    case .repairProbe: ["probe-culture-transfer"]
    case .listen: ["choir-near", "choir-above", "choir-aft"]
    case .exposeImitation: ["counterfeit-emitter-disabled"]
    case .rendezvous: ["choir-protocol"]
    case .closeCase: ["choir-payment"]
    }
  }

  /// Authored sequence only. A next value grants no transition without genuine sources.
  var next: Self? {
    switch self {
    case .accept: .calibrate
    case .calibrate: .recoverCollector
    case .recoverCollector: .interpret
    case .interpret: .repairProbe
    case .repairProbe: .listen
    case .listen: .exposeImitation
    case .exposeImitation: .rendezvous
    case .rendezvous: .closeCase
    case .closeCase: nil
    }
  }

  var receipt: String { NativeC02HistoryPrerequisites.logicalSourceID + "/" + rawValue }

  var choices: [String] {
    switch self {
    case .exposeImitation: NativeC02ImitationApproach.allCases.map(\.title)
    case .rendezvous: NativeC02RendezvousProtocol.allCases.map(\.title)
    default: []
    }
  }
}

/// Both approaches must genuinely silence the same original counterfeit transmitter.
/// Selecting a label alone never proves shutdown, component damage or a source loss.
enum NativeC02ImitationApproach: CaseIterable, Sendable {
  case demandShutdown, disableTransmitter
  var title: String {
    switch self {
    case .demandShutdown: "Broadcast the forged certificate and demand shutdown"
    case .disableTransmitter: "Disable the unmanned transmitter"
    }
  }
}

enum NativeC02RendezvousProtocol: CaseIterable, Sendable {
  case civilianGreeting, supervisedRelay
  var title: String {
    switch self {
    case .civilianGreeting: "Publish the civilian greeting"
    case .supervisedRelay: "Establish a supervised listening relay"
    }
  }
}

enum NativeC02OriginalReward {
  static let tenths = 64_000
  static let paymentReceipt = "l337.quiet-choir/final-payment"
  static let clue = "choir-silent-voice"
  static let clueReceipt = "l337.unwritten-route/clue/choir-silent-voice"
  static let clueJournal = "The restored Larvaal call contains a reply from beyond the gathering. Its pauses describe a curve, but no Larvaal vessel claims the voice."
  // Real terminal, payment and clue commit together. Optional compatible filter fitting
  // may wait; it must neither delay the clue nor issue another payment.
}
