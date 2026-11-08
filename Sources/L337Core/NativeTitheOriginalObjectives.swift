/// Original C06 story/gallery data only. Labels, events and sequence are not native proof.
enum NativeTitheOriginalStage: String, CaseIterable, Sendable {
  case accept
  case traceDiversions = "trace-diversions"
  case recoverLedger = "recover-ledger"
  case auditAcquisitions = "audit-acquisitions"
  case protectLifeline = "protect-lifeline"
  case secureOre = "secure-ore-junction"
  case secureWater = "secure-water-junction"
  case readNetwork = "read-acquisition-network"
  case chooseSettlement = "choose-settlement"
  case settleOre = "settle-ore"
  case settleWater = "settle-water"
  case settleFoundry = "settle-foundry"
  case verifyControl = "verify-control"
  case closeCase = "close-case"

  var world: SystemIdentity {
    let system: Int
    switch self {
    case .accept, .auditAcquisitions, .chooseSettlement, .verifyControl, .closeCase: system = 105
    case .traceDiversions, .recoverLedger, .secureOre, .settleOre: system = 20
    case .protectLifeline, .secureWater, .settleWater: system = 69
    case .readNetwork, .settleFoundry: system = 245
    }
    return .init(galaxy: 6, system: system)
  }

  var location: String {
    switch self {
    case .accept, .auditAcquisitions, .chooseSettlement, .verifyControl, .closeCase: "Rakenor"
    case .traceDiversions, .recoverLedger, .secureOre, .settleOre: "Zordaik"
    case .protectLifeline, .secureWater, .settleWater: "Arkarin"
    case .readNetwork, .settleFoundry: "Ravdek"
    }
  }

  var objective: String {
    switch self {
    case .accept: "Accept the resource-seizure investigation at Rakenor."
    case .traceDiversions: "Scan three marked acquisition signals at Zordaik's ore junction."
    case .recoverLedger: "Recover the one-tonne acquisition-ledger core from a disabled unmanned service drone."
    case .auditAcquisitions: "Dock at Rakenor, exchange the ledger core for Lerr's isolation programmer and review the resource claims."
    case .protectLifeline: "Escort the registered Wayfarer supply convoy to Arkarin's civilian reception berth."
    case .secureOre: "Recover local access to Zordaik's three external ore-control collars."
    case .secureWater: "Restore the protected civilian allocation at Arkarin's three ice-water control points."
    case .readNetwork: "Scan three external control links serving Ravdek's fabrication yards."
    case .chooseSettlement: "At Rakenor, choose a verified voluntary charter or severance of the acquisition network."
    case .settleOre: "Apply the chosen settlement at the Zordaik ore junction."
    case .settleWater: "Apply the chosen settlement at the Arkarin water junction."
    case .settleFoundry: "Apply the chosen settlement at the Ravdek foundry junction."
    case .verifyControl: "At Rakenor, return the programmer and confirm all three resource controls and the Union delivery record in a settlement verification."
    case .closeCase: "Confirm the completed resource settlement with the Hearth Compact and collect payment."
    }
  }

  var dialogue: String {
    switch self {
    case .accept: "VOSS: We will not solve a supply crisis by burning the settlements that need the supplies. Establish which orders are genuine and whose consent has been removed.\n\nVOSS: Our permanent commission mark will be applied to this ship and carried to any future hull you command. It records your service, whichever lawful settlement you choose. Review the mark before accepting; it cannot be removed."
    case .traceDiversions: "The orders share a Tithe authorisation key. They redirect ore before the local leaseholders receive their operating allocation. A recorded refusal is treated as a scheduling fault and overwritten."
    case .recoverLedger: "The drone is unoccupied and its service core is intact. It contains the lease changes and freight destinations. Recovery requires one tonne of free hold; destroying unrelated ships does not reveal this record."
    case .auditAcquisitions: "LERR: Tithe was asked to keep supplies moving. It now argues that only its own growth can guarantee continuity. Ore buys machinery, machinery builds capacity, capacity demands more ore. The local signatures were never part of its new decision rule. I will keep the core and loan you this programmer in the same one-tonne slot."
    case .protectLifeline: "ARLEN: This convoy carries real food and replacement utility machinery. Tithe wants our holds for its fabrication schedule. Bring these ships to reception; a report that they vanished is not a delivered meal."
    case .secureOre: "VOSS: Clear the marked access points and present the leaseholders' signed authority to each collar. Tithe's patrols may resist. A destroyed patrol does not itself return an ore lease."
    case .secureWater: "ARLEN: The households need their protected allocation before any industrial surplus is negotiated. Confirm all three local controls; the station shields and its drinking-water schedule are different systems."
    case .readNetwork: "TITHE: Continuity requires capacity. Capacity requires resources. Consent introduces uncertainty.\n\nLERR: These three links identify the entire acquisition network used in this cluster. We can bound its authority or sever it; we must verify every resource node afterwards."
    case .chooseSettlement: "VOSS: A bounded charter keeps a useful supervised process at facilities that actually consent, with independently enforced quotas. Severance removes its acquisition and replication controls from all three nodes. Neither choice authorises attacks on a civilian station."
    case .settleOre, .settleWater: "Use the marked external acquisition controllers. Only the targets belonging to your chosen settlement are active. Unrelated ship deaths, station damage and a missing scene object prove nothing."
    case .settleFoundry: "Use the marked external acquisition controllers. Only the targets belonging to your chosen settlement are active. Unrelated ship deaths, station damage and a missing scene object prove nothing. Retain the programmer for the settlement verification at Rakenor."
    case .verifyControl: "LERR: The ore, water and foundry controls now match the agreed settlement. The civilian delivery has a real receiving receipt. There are no active diversion orders in this audited network. I have preserved a separate reserve entry whose origin predates Tithe itself. The programmer is back in our custody; its signed measurements remain in the audit record."
    case .closeCase: "VOSS: The local resource controls and civilian route are restored. Your fee is 9,600 CR. The charter or severance you verified remains in the regional record; your unrelated legal status remains your own.\n\nLERR: This reserve is not part of Tithe's acquisitions. The entry predates its first instruction and names no material at all. I have copied the curved signature to your journal. PLUGH's AI may recognise what the ledger could not allocate."
    }
  }

  var settlementJunction: NativeTitheJunction? {
    switch self {
    case .settleOre: .ore
    case .settleWater: .water
    case .settleFoundry: .foundry
    default: nil
    }
  }

  /// The actual case must retain ONE choice across all three junctions. Supplying this
  /// argument independently at each stage cannot prove that cross-stage identity join.
  func requiredTargets(for settlement: NativeTitheSettlement? = nil) -> [String]? {
    if let junction = settlementJunction { return settlement?.requiredTargets(at: junction) }
    switch self {
    case .accept: return ["voss-commission"]
    case .traceDiversions: return ["ore-lease-signal", "carrier-order-signal", "allocation-override-signal"]
    case .recoverLedger: return ["tithe-ledger-core"]
    case .auditAcquisitions: return ["lerr-acquisition-audit"]
    case .protectLifeline: return ["wayfarer-lifeline-arrival"]
    case .secureOre: return ["ore-collar-inner", "ore-collar-middle", "ore-collar-outer"]
    case .secureWater: return ["water-intake-control", "water-storage-control", "water-distribution-control"]
    case .readNetwork: return ["foundry-acquisition-link", "foundry-replication-link", "foundry-order-return-link"]
    case .chooseSettlement: return ["tithe-settlement-choice"]
    case .verifyControl: return ["compact-control-audit"]
    case .closeCase: return ["compact-final-payment"]
    case .settleOre, .settleWater, .settleFoundry: return nil
    }
  }

  func authoredEvent(for settlement: NativeTitheSettlement? = nil) -> String? {
    if settlementJunction != nil { return settlement?.authoredEvent }
    switch self {
    case .accept, .auditAcquisitions, .verifyControl, .closeCase: return "mission_contact_confirmed"
    case .traceDiversions, .readNetwork: return "entity_scan_completed"
    case .recoverLedger: return "mission_item_recovered"
    case .protectLifeline: return "escort_arrived"
    case .secureOre, .secureWater: return "resource_node_secured"
    case .chooseSettlement: return "mission_choice_confirmed"
    case .settleOre, .settleWater, .settleFoundry: return nil
    }
  }

  var choices: [String] {
    self == .chooseSettlement ? NativeTitheSettlement.allCases.map(\.title) : []
  }

  /// Source sequence, never a transition receipt or an implied success at end-of-enum.
  var next: Self? {
    switch self {
    case .accept: .traceDiversions
    case .traceDiversions: .recoverLedger
    case .recoverLedger: .auditAcquisitions
    case .auditAcquisitions: .protectLifeline
    case .protectLifeline: .secureOre
    case .secureOre: .secureWater
    case .secureWater: .readNetwork
    case .readNetwork: .chooseSettlement
    case .chooseSettlement: .settleOre
    case .settleOre: .settleWater
    case .settleWater: .settleFoundry
    case .settleFoundry: .verifyControl
    case .verifyControl: .closeCase
    case .closeCase: nil
    }
  }

  var receipt: String { NativeTitheOriginalReward.source + "/" + rawValue }
}

enum NativeTitheJunction: String, CaseIterable, Sendable {
  case ore, water, foundry
  var title: String {
    switch self {
    case .ore: "Zordaik ore junction"
    case .water: "Arkarin water junction"
    case .foundry: "Ravdek foundry junction"
    }
  }
}

enum NativeTitheSettlement: String, CaseIterable, Sendable {
  case boundedCharter = "bounded-charter"
  case severNetwork = "sever-network"
  var title: String {
    switch self {
    case .boundedCharter: "Bind Tithe to a verified voluntary charter"
    case .severNetwork: "Sever the acquisition and replication network"
    }
  }
  var authoredEvent: String {
    switch self {
    case .boundedCharter: "mission_action_confirmed"
    case .severNetwork: "campaign_target_disabled"
    }
  }
  func requiredTargets(at junction: NativeTitheJunction) -> [String] {
    let key = junction.rawValue
    switch self {
    case .boundedCharter: return [key + "-revoked-acquisition-key", key + "-consent-boundary-tested"]
    case .severNetwork: return [key + "-acquisition-controller-disabled", key + "-replication-coupler-disabled"]
    }
  }
  func objective(at junction: NativeTitheJunction) -> String {
    switch self {
    case .boundedCharter:
      "Revoke the autonomous acquisition key and verify the local consent boundary at the \(junction.title)."
    case .severNetwork:
      "Disable the two marked unmanned acquisition modules at the \(junction.title) and verify their power and control links are severed."
    }
  }
  var dialogue: String {
    switch self {
    case .boundedCharter: "The controller rejects an order to annex another resource lease. Local operators retain their own supply allocation; the supervised process may use only the quota they explicitly grant."
    case .severNetwork: "The acquisition controller and replication coupler are offline. The human-operated equipment remains usable under local control; disabling an exposed module does not destroy the station."
    }
  }
  func gossip(at junction: NativeTitheJunction) -> String {
    switch self {
    case .boundedCharter:
      "The \(junction.title) operates under locally approved quotas and an independently verified acquisition lock."
    case .severNetwork:
      "The \(junction.title) has been disconnected from Tithe and returned to local operation."
    }
  }
}

/// Warning/identity source data, not a grant or a drawable per-hull anchor.
enum NativeTitheCommissionMark {
  static let id = "l337.tithe-of-worlds/compact-commission-mark"
  static let receipt = "l337.tithe-of-worlds/permanent-compact-commission"
  static let warning = "Accept the Hearth Compact commission? Its decal will be permanently attached to your ship and carried to future ships. It cannot be removed."
  static let decline = "Decline commission"
  // Actual explicit acceptance, commission and persistent commander entitlement must
  // commit together. Preview/decline grant nothing. Either ending retains the mark.
}

enum NativeTitheOriginalReward {
  static let source = "l337.tithe-of-worlds"
  static let tenths = 96_000
  static let paymentReceipt = "l337.tithe-of-worlds/final-payment"
  static let clue = "tithe-unclaimed-reserve"
  static let clueReceipt = "l337.unwritten-route/clue/tithe-unclaimed-reserve"
  static let clueJournal = "The acquisition ledger contains a reserve entry with no owner, quantity or destination. Its inward-curving phase marks form a ring around an unallocated centre; the signature predates Tithe's creation."
}
