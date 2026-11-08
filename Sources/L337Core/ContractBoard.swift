import Foundation

public enum ContractBoardAction: String, Codable, Sendable, CaseIterable {
  case accept = "Accept"
  case decline = "Decline"
  case back = "Back"
}
public struct ContractBoardRow: Sendable {
  public let board: String
  private let offerStorage: [ScriptContractOffer]
  public var offer: ScriptContractOffer? { offerStorage.first }
  public let title: String
  public let reason: String?
  var finance: ScriptFinanceRow?
  var people: NativePeopleStationRow?
  var provider: ProviderContractRow?
  var repairLoop: WayfarerRepairLoopBoardRow?
  var coldChain: WayfarerColdChainBoardRow?
  var survey: NativeOriginalSurveyAction?
  var inquiry: NativeC01InquiryPhase?
  var glassMeridian: NativeGlassMeridianAction?
  var wayfarerInduction: NativeWayfarerInductionAction?
  var inductionCapacityUnit: UUID?
  var inductionClinicReference: UUID?
  var inductionWorkshopReference: UUID?
  var inductionSeedReference: UUID?
  var flightReception: NativeFlightReceptionAction?
  var defensiveFlight: NativeDefensiveFlightAction?
  var safeGunnery: NativeSafeGunneryAction?
  var measuredExtraction: NativeMeasuredExtractionAction?
  var recordRecovery: WayfarerRecordRecoveryAction?
  var identifiedSalvage: NativeIdentifiedSalvageAction?
  var utility: NativeUtilityAction?
  var underTow: NativeUnderTowAction?
  var borrowedVoice: NativeBorrowedVoiceAction?
  var quietChoir: NativeQuietChoirAction?
  var memoryAtlas: NativeMemoryAtlasAction?
  var publicRecord: NativePublicRecordAction?
  var signedPassageOpening: NativeSignedPassageOpeningAction?
  var assemblyOfOrbits: NativeAssemblyOfOrbitsAction?
  var isolationWorkParent: NativeIsolationWorkParentAction?
  var hollowManifest: NativeHollowManifestAction?

  init(
    board: String,
    offer: ScriptContractOffer?,
    title: String,
    reason: String?,
    finance: ScriptFinanceRow? = nil,
    people: NativePeopleStationRow? = nil,
    provider: ProviderContractRow? = nil,
    repairLoop: WayfarerRepairLoopBoardRow? = nil,
    coldChain: WayfarerColdChainBoardRow? = nil,
    survey: NativeOriginalSurveyAction? = nil,
    inquiry: NativeC01InquiryPhase? = nil,
    glassMeridian: NativeGlassMeridianAction? = nil,
    wayfarerInduction: NativeWayfarerInductionAction? = nil,
    inductionCapacityUnit: UUID? = nil,
    inductionClinicReference: UUID? = nil,
    inductionWorkshopReference: UUID? = nil,
    inductionSeedReference: UUID? = nil,
    flightReception: NativeFlightReceptionAction? = nil,
    defensiveFlight: NativeDefensiveFlightAction? = nil,
    safeGunnery: NativeSafeGunneryAction? = nil,
    measuredExtraction: NativeMeasuredExtractionAction? = nil,
    recordRecovery: WayfarerRecordRecoveryAction? = nil,
    identifiedSalvage: NativeIdentifiedSalvageAction? = nil,
    utility: NativeUtilityAction? = nil,
    underTow: NativeUnderTowAction? = nil,
    borrowedVoice: NativeBorrowedVoiceAction? = nil,
    quietChoir: NativeQuietChoirAction? = nil,
    memoryAtlas: NativeMemoryAtlasAction? = nil,
    publicRecord: NativePublicRecordAction? = nil,
    signedPassageOpening: NativeSignedPassageOpeningAction? = nil,
    assemblyOfOrbits: NativeAssemblyOfOrbitsAction? = nil,
    isolationWorkParent: NativeIsolationWorkParentAction? = nil,
    hollowManifest: NativeHollowManifestAction? = nil
  ) {
    self.board = board
    if let offer { offerStorage = [offer] } else { offerStorage = [] }
    self.title = title
    self.reason = reason
    self.finance = finance
    self.people = people
    self.provider = provider
    self.repairLoop = repairLoop
    self.coldChain = coldChain
    self.survey = survey
    self.inquiry = inquiry
    self.glassMeridian = glassMeridian
    self.wayfarerInduction = wayfarerInduction
    self.inductionCapacityUnit = inductionCapacityUnit
    self.inductionClinicReference = inductionClinicReference
    self.inductionWorkshopReference = inductionWorkshopReference
    self.inductionSeedReference = inductionSeedReference
    self.flightReception = flightReception
    self.defensiveFlight = defensiveFlight
    self.safeGunnery = safeGunnery
    self.measuredExtraction = measuredExtraction
    self.recordRecovery = recordRecovery
    self.identifiedSalvage = identifiedSalvage
    self.utility = utility
    self.underTow = underTow
    self.borrowedVoice = borrowedVoice
    self.quietChoir = quietChoir
    self.memoryAtlas = memoryAtlas
    self.publicRecord = publicRecord
    self.signedPassageOpening = signedPassageOpening
    self.assemblyOfOrbits = assemblyOfOrbits
    self.isolationWorkParent = isolationWorkParent
    self.hollowManifest = hollowManifest
  }
  public var key: String {
    if let utility { return utility.utilityKey }
    if let underTow { return underTow.key }
    if let borrowedVoice { return borrowedVoice.key }
    if let quietChoir { return quietChoir.key }
    if let memoryAtlas { return memoryAtlas.key }
    if let publicRecord { return publicRecord.key }
    if let signedPassageOpening { return signedPassageOpening.key }
    if let assemblyOfOrbits { return assemblyOfOrbits.key }
    if let isolationWorkParent { return isolationWorkParent.key }
    if let hollowManifest { return hollowManifest.key }
    if let key = wayfarerInduction?.key {
      return key + (inductionCapacityUnit.map { "/unit/" + $0.uuidString } ?? "")
        + (inductionClinicReference.map { "/clinic/" + $0.uuidString } ?? "")
        + (inductionWorkshopReference.map { "/workshop/" + $0.uuidString } ?? "")
        + (inductionSeedReference.map { "/seed/" + $0.uuidString } ?? "")
    }
    if inquiry == .requestCase { return NativeC01InquiryBoard.requestKey }
    if let key = glassMeridian?.key { return key }
    if let key = flightReception?.key { return key }
    if let key = defensiveFlight?.key { return key }
    if let key = safeGunnery?.key { return key }
    if let key: String = measuredExtraction?.key { return key }
    if let key: String = recordRecovery?.key { return key }
    if let key: String = identifiedSalvage?.key { return key }
    if let key: String = survey?.key { return key }
    if let key: String = repairLoop?.key { return key }
    if let key: String = coldChain?.key { return key }
    if let key: String = provider?.key { return key }
    if let key: String = people?.key { return key }
    if let key: String = finance?.key { return key }
    return board + "/" + (offer?.id.uuidString ?? "unavailable")
  }
}
public struct ContractScreenSave: Codable, Sendable, Equatable {
  public let selection: String?
  public let detail: Bool
  public let action: ContractBoardAction
  public let scroll: Int
  public let previous: Screen
  var valid: Bool {
    (selection?.count ?? 0) <= 512 && (0...100000).contains(scroll) && previous != .contracts
  }
}
private indirect enum ContractBoardReview: Sendable {
  case contract(ContractAcceptanceQuote)
  case finance(ScriptFinanceQuote)
  case people(NativePeopleStationQuote)
  case provider(ProviderContractQuote)
  case repairLoop(WayfarerRepairLoopBoardReview)
  case coldChain(WayfarerColdChainBoardReview)
  case survey(NativeOriginalSurveyReview)
  case inquiry(NativeC01InquiryRequestReview)
  case glassMeridian(NativeGlassMeridianReview)
  case wayfarerInduction(NativeWayfarerInductionReview)
  case flightReception(NativeFlightReceptionReview)
  case safeGunnery(NativeSafeGunneryReview)
  case defensiveFlight(NativeDefensiveFlightReview)
  case measuredExtraction(NativeMeasuredExtractionReview)
  case recordRecovery(WayfarerRecordRecoveryReview)
  case identifiedSalvage(NativeIdentifiedSalvageReview)
  case utility(NativeUtilityBoardReview)
  case underTow(NativeUnderTowReview)
  case borrowedVoice(NativeBorrowedVoiceReview)
  case quietChoir(NativeQuietChoirReview)
  case memoryAtlas(NativeMemoryAtlasReview)
  case publicRecord(NativePublicRecordReview)
  case signedPassageOpening(NativeSignedPassageOpeningReview)
  case assemblyOfOrbits(NativeAssemblyOfOrbitsReview)
  case isolationWorkParent(NativeIsolationWorkParentReview)
  case hollowManifest(NativeHollowManifestReview)
}

public struct ContractBoardUI: Sendable {
  public var selection = 0
  public var detail = false
  public var action: ContractBoardAction = .back
  public var scroll = 0
  public var rows: [ContractBoardRow] = []
  private var review: ContractBoardReview?
  var presentationGeneration = UUID()
  public var quote: ContractAcceptanceQuote? {
    get {
      guard case .contract(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .contract(newValue)
      } else if case .contract(_)? = review {
        review = nil
      }
    }
  }
  var financeQuote: ScriptFinanceQuote? {
    get {
      guard case .finance(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .finance(newValue)
      } else if case .finance(_)? = review {
        review = nil
      }
    }
  }
  var publicRecordQuote: NativePublicRecordReview? {
    get {
      guard case .publicRecord(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .publicRecord(newValue)
      } else if case .publicRecord(_)? = review {
        review = nil
      }
    }
  }
  var signedPassageOpeningQuote: NativeSignedPassageOpeningReview? {
    get {
      guard case .signedPassageOpening(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .signedPassageOpening(newValue)
      } else if case .signedPassageOpening(_)? = review {
        review = nil
      }
    }
  }
  var memoryAtlasQuote: NativeMemoryAtlasReview? {
    get {
      guard case .memoryAtlas(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .memoryAtlas(newValue)
      } else if case .memoryAtlas(_)? = review {
        review = nil
      }
    }
  }
  var quietChoirQuote: NativeQuietChoirReview? {
    get {
      guard case .quietChoir(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .quietChoir(newValue)
      } else if case .quietChoir(_)? = review {
        review = nil
      }
    }
  }
  var borrowedVoiceQuote: NativeBorrowedVoiceReview? {
    get {
      guard case .borrowedVoice(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .borrowedVoice(newValue)
      } else if case .borrowedVoice(_)? = review {
        review = nil
      }
    }
  }
  var underTowQuote: NativeUnderTowReview? {
    get {
      guard case .underTow(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .underTow(newValue)
      } else if case .underTow(_)? = review {
        review = nil
      }
    }
  }
  var assemblyOfOrbitsQuote: NativeAssemblyOfOrbitsReview? {
    get {
      guard case .assemblyOfOrbits(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .assemblyOfOrbits(newValue)
      } else if case .assemblyOfOrbits(_)? = review {
        review = nil
      }
    }
  }
  var inquiryQuote: NativeC01InquiryRequestReview? {
    get {
      guard case .inquiry(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .inquiry(newValue)
      } else if case .inquiry(_)? = review {
        review = nil
      }
    }
  }
  var reviewToken = UUID()
  var peopleQuote: NativePeopleStationQuote? {
    get {
      guard case .people(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .people(newValue)
      } else if case .people(_)? = review {
        review = nil
      }
    }
  }
  var providerQuote: ProviderContractQuote? {
    get {
      guard case .provider(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .provider(newValue)
      } else if case .provider(_)? = review {
        review = nil
      }
    }
  }
  var repairLoopQuote: WayfarerRepairLoopBoardReview? {
    get {
      guard case .repairLoop(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .repairLoop(newValue)
      } else if case .repairLoop(_)? = review {
        review = nil
      }
    }
  }
  var coldChainQuote: WayfarerColdChainBoardReview? {
    get {
      guard case .coldChain(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .coldChain(newValue)
      } else if case .coldChain(_)? = review {
        review = nil
      }
    }
  }
  var previous: Screen = .status
  var restoredSelection: String?
  var surveyQuote: NativeOriginalSurveyReview? {
    get {
      guard case .survey(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .survey(newValue)
      } else if case .survey(_)? = review {
        review = nil
      }
    }
  }
  var wayfarerInductionQuote: NativeWayfarerInductionReview? {
    get {
      guard case .wayfarerInduction(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .wayfarerInduction(newValue)
      } else if case .wayfarerInduction(_)? = review {
        review = nil
      }
    }
  }
  var glassMeridianQuote: NativeGlassMeridianReview? {
    get {
      guard case .glassMeridian(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .glassMeridian(newValue)
      } else if case .glassMeridian(_)? = review {
        review = nil
      }
    }
  }
  var defensiveFlightQuote: NativeDefensiveFlightReview? {
    get {
      guard case .defensiveFlight(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .defensiveFlight(newValue)
      } else if case .defensiveFlight(_)? = review {
        review = nil
      }
    }
  }
  var safeGunneryQuote: NativeSafeGunneryReview? {
    get {
      guard case .safeGunnery(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .safeGunnery(newValue)
      } else if case .safeGunnery(_)? = review {
        review = nil
      }
    }
  }
  var flightReceptionQuote: NativeFlightReceptionReview? {
    get {
      guard case .flightReception(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .flightReception(newValue)
      } else if case .flightReception(_)? = review {
        review = nil
      }
    }
  }
  var measuredExtractionQuote: NativeMeasuredExtractionReview? {
    get {
      guard case .measuredExtraction(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .measuredExtraction(newValue)
      } else if case .measuredExtraction(_)? = review {
        review = nil
      }
    }
  }
  var recordRecoveryQuote: WayfarerRecordRecoveryReview? {
    get {
      guard case .recordRecovery(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .recordRecovery(newValue)
      } else if case .recordRecovery(_)? = review {
        review = nil
      }
    }
  }
  var identifiedSalvageQuote: NativeIdentifiedSalvageReview? {
    get {
      guard case .identifiedSalvage(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .identifiedSalvage(newValue)
      } else if case .identifiedSalvage(_)? = review {
        review = nil
      }
    }
  }
  var utilityQuote: NativeUtilityBoardReview? {
    get {
      guard case .utility(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .utility(newValue)
      } else if case .utility(_)? = review {
        review = nil
      }
    }
  }
  var isolationWorkParentQuote: NativeIsolationWorkParentReview? {
    get {
      guard case .isolationWorkParent(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .isolationWorkParent(newValue)
      } else if case .isolationWorkParent(_)? = review {
        review = nil
      }
    }
  }
  var hollowManifestQuote: NativeHollowManifestReview? {
    get {
      guard case .hollowManifest(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .hollowManifest(newValue)
      } else if case .hollowManifest(_)? = review {
        review = nil
      }
    }
  }
  public init() {}
  var selected: ContractBoardRow? { rows.indices.contains(selection) ? rows[selection] : nil }
  var save: ContractScreenSave {
    .init(
      selection: selected?.key ?? restoredSelection, detail: detail, action: action, scroll: scroll,
      previous: previous)
  }
}
extension Game {
  mutating func openContractBoard() {
    guard docked, dockedAtMainStation || nativeStationBoardContext != nil || nativeUtilityServiceContext != nil, !paused,
      ![Screen.title, .demo, .gameOver, .help, .secret, .mission, .handoff].contains(screen),
      !showroom.trading
    else {
      notify("CONTRACTS REQUIRE AN ACTUAL AUTHORISED STATION DOCK")
      return
    }
    var candidate = self
    if screen != .contracts { candidate.contractBoard.previous = screen }
    var failures: [String: String] = [:]
    for pack in scriptPacks
    where contractBoardStation(for: pack) != nil && pack.manifest.board != nil
      && scriptUnavailable(pack) == nil
    {
      do { _ = try candidate.ensureContractBoard(pack) } catch {
        failures[pack.digest] = String(error.localizedDescription.prefix(512))
      }
    }
    candidate.prepareWayfarerRepairLoopBoard(failures: &failures)
    candidate.prepareWayfarerColdChainBoard(failures: &failures)
    candidate.refreshContractRows(failures: failures)
    candidate.screen = .contracts
    candidate.contractBoard.detail = false
    candidate.contractBoard.quote = nil
    candidate.contractBoard.financeQuote = nil
    candidate.contractBoard.peopleQuote = nil
    candidate.contractBoard.providerQuote = nil
    candidate.contractBoard.repairLoopQuote = nil
    candidate.contractBoard.coldChainQuote = nil
    candidate.contractBoard.surveyQuote = nil
    candidate.contractBoard.wayfarerInductionQuote = nil
    candidate.contractBoard.inquiryQuote = nil
    candidate.contractBoard.glassMeridianQuote = nil
    candidate.contractBoard.flightReceptionQuote = nil
    candidate.contractBoard.measuredExtractionQuote = nil
    candidate.contractBoard.recordRecoveryQuote = nil
    candidate.contractBoard.identifiedSalvageQuote = nil
    candidate.contractBoard.utilityQuote = nil
    candidate.contractBoard.underTowQuote = nil
    candidate.contractBoard.signedPassageOpeningQuote = nil
    candidate.contractBoard.publicRecordQuote = nil
    candidate.contractBoard.borrowedVoiceQuote = nil
    candidate.contractBoard.quietChoirQuote = nil
    candidate.contractBoard.memoryAtlasQuote = nil
    candidate.contractBoard.assemblyOfOrbitsQuote = nil
    candidate.contractBoard.isolationWorkParentQuote = nil
    candidate.contractBoard.hollowManifestQuote = nil
    candidate.gallery.providerIntent = nil
    candidate.contractBoard.presentationGeneration = UUID()
    publishContractBoard(&candidate)
  }
  // Reserve the publication copy only after row quotes finish their acceptance simulations.
  private mutating func publishContractBoard(_ candidate: inout Game) {
    self = candidate
  }
  mutating func refreshContractRows(
    failures: [String: String] = [:], restoring save: ContractScreenSave? = nil
  ) {
    let selected = save?.selection ?? contractBoard.selected?.key ?? contractBoard.restoredSelection
    var rows =
      financeRows + nativePeopleRows + providerContractRows + originalSurveyRows
      + wayfarerInductionRows
      + c01InquiryRequestRows
      + underTowRows
      + borrowedVoiceRows
      + quietChoirRows
      + memoryAtlasRows
      + publicRecordRows
      + signedPassageOpeningRows
      + assemblyOfOrbitsRows
      + glassMeridianRows
      + flightReceptionRows
      + safeGunneryRows
      + defensiveFlightRows
      + measuredExtractionRows
      + recordRecoveryRows
      + identifiedSalvageRows
      + wayfarerColdChainRows(failures: failures)
      + wayfarerRepairLoopRows(failures: failures)
      + nativeUtilityRows
      + isolationWorkParentRows
      + hollowManifestRows
    for pack in scriptPacks.sorted(by: {
      ($0.manifest.id, $0.manifest.version, $0.digest) < (
        $1.manifest.id, $1.manifest.version, $1.digest
      )
    }) {
      guard let origin = contractBoardStation(for: pack),
        let definition = pack.manifest.board else { continue }
      let key = pack.digest + "/" + definition.id + "/" + origin.key
      if let reason = failures[pack.digest] ?? scriptUnavailable(pack) {
        rows.append(.init(board: key, offer: nil, title: definition.title, reason: reason))
      } else if let board = commander.contracts.boards[key],
        board.revision == (try? contractRevision(definition, pack: pack))
      {
        for offer in board.offers where offer.status == .available {
          let quote = contractAcceptanceQuote(board: key, offer: offer.id)
          rows.append(
            .init(board: key, offer: offer, title: offer.title, reason: quote.issues.first))
        }
      }
    }
    contractBoard.rows = rows
    contractBoard.restoredSelection = nil
    contractBoard.selection =
      selected.flatMap { key in rows.firstIndex { $0.key == key } }
      ?? min(contractBoard.selection, max(0, rows.count - 1))
    if let save {
      contractBoard.detail = save.detail && contractBoard.selected != nil
      contractBoard.action = save.action
      contractBoard.scroll = save.scroll
      contractBoard.previous = save.previous
      refreshSelectedContractQuote()
      if contractBoard.quote?.pledge != nil || contractBoard.financeQuote != nil
        || contractBoard.peopleQuote != nil || contractBoard.providerQuote != nil
        || contractBoard.coldChainQuote != nil || contractBoard.repairLoopQuote != nil
        || contractBoard.surveyQuote != nil || contractBoard.wayfarerInductionQuote != nil
        || contractBoard.inquiryQuote != nil
        || contractBoard.underTowQuote != nil
        || contractBoard.borrowedVoiceQuote != nil
        || contractBoard.quietChoirQuote != nil
        || contractBoard.memoryAtlasQuote != nil
        || contractBoard.publicRecordQuote != nil
        || contractBoard.signedPassageOpeningQuote != nil
        || contractBoard.assemblyOfOrbitsQuote != nil
        || contractBoard.glassMeridianQuote != nil
        || contractBoard.flightReceptionQuote != nil
        || contractBoard.safeGunneryQuote != nil
        || contractBoard.defensiveFlightQuote != nil
        || contractBoard.measuredExtractionQuote != nil
        || contractBoard.recordRecoveryQuote != nil
        || contractBoard.identifiedSalvageQuote != nil || contractBoard.utilityQuote != nil
        || contractBoard.isolationWorkParentQuote != nil
        || contractBoard.hollowManifestQuote != nil
      {
        contractBoard.action = .back
      }
    }
  }
  @inline(never)
  mutating func refreshSelectedContractQuote() {
    contractBoard.reviewToken = UUID()
    if refreshSpecializedContractQuote() { return }
    if let row = contractBoard.selected, let offer = row.offer {
      let quote = withReadOnlyStoredGame {
        $0.contractAcceptanceQuote(board: row.board, offer: offer.id)
      }
      contractBoard.quote = quote
    } else {
      contractBoard.quote = nil
    }
  }
  // Specialized review buffers retire before the ordinary acceptance preview begins.
  @inline(never)
  private mutating func refreshSpecializedContractQuote() -> Bool {
    if let action = contractBoard.selected?.publicRecord {
      contractBoard.publicRecordQuote = publicRecordReview(action)
      return true
    }
    if let action = contractBoard.selected?.hollowManifest {
      contractBoard.hollowManifestQuote = hollowManifestReview(action)
      return true
    }
    contractBoard.hollowManifestQuote = nil
    if let action = contractBoard.selected?.borrowedVoice {
      contractBoard.borrowedVoiceQuote = borrowedVoiceReview(action)
      return true
    }
    if let action = contractBoard.selected?.quietChoir {
      contractBoard.quietChoirQuote = quietChoirReview(action)
      return true
    }
    if let action = contractBoard.selected?.memoryAtlas {
      contractBoard.memoryAtlasQuote = memoryAtlasReview(action)
      return true
    }
    if let action = contractBoard.selected?.signedPassageOpening {
      contractBoard.signedPassageOpeningQuote = signedPassageOpeningReview(action)
      return true
    }
    if let action = contractBoard.selected?.assemblyOfOrbits {
      contractBoard.assemblyOfOrbitsQuote = assemblyOfOrbitsReview(action)
      return true
    }
    if let action = contractBoard.selected?.underTow {
      contractBoard.underTowQuote = underTowReview(action)
      return true
    }
    contractBoard.underTowQuote = nil
    contractBoard.signedPassageOpeningQuote = nil
    contractBoard.publicRecordQuote = nil
    contractBoard.borrowedVoiceQuote = nil
    contractBoard.quietChoirQuote = nil
    contractBoard.memoryAtlasQuote = nil
    contractBoard.assemblyOfOrbitsQuote = nil
    if let action = contractBoard.selected?.utility {
      contractBoard.utilityQuote = nativeUtilityReview(action)
      return true
    }
    contractBoard.utilityQuote = nil
    if let action = contractBoard.selected?.isolationWorkParent {
      contractBoard.isolationWorkParentQuote = isolationWorkParentReview(action)
      return true
    }
    contractBoard.isolationWorkParentQuote = nil
    contractBoard.hollowManifestQuote = nil
    if let action = contractBoard.selected?.wayfarerInduction {
      contractBoard.wayfarerInductionQuote = wayfarerInductionReview(
        action, prepareClinicQuote: true, prepareWorkshopQuote: true, prepareSeedQuote: true,
        prepareCharterAudit: true)
      return true
    }
    if contractBoard.selected?.inquiry == .requestCase {
      contractBoard.inquiryQuote = c01InquiryRequestReview()
      return true
    }
    contractBoard.inquiryQuote = nil
    if let action = contractBoard.selected?.glassMeridian {
      contractBoard.glassMeridianQuote = glassMeridianReview(action)
      return true
    }
    if let action = contractBoard.selected?.defensiveFlight {
      contractBoard.defensiveFlightQuote = defensiveFlightReview(action)
      return true
    }
    if let action = contractBoard.selected?.safeGunnery {
      contractBoard.safeGunneryQuote = safeGunneryReview(action)
      return true
    }
    if let action = contractBoard.selected?.flightReception {
      contractBoard.flightReceptionQuote = flightReceptionReview(action)
      return true
    }
    if let action = contractBoard.selected?.measuredExtraction {
      contractBoard.measuredExtractionQuote = measuredExtractionReview(action)
      return true
    }
    if let action = contractBoard.selected?.recordRecovery {
      contractBoard.recordRecoveryQuote = recordRecoveryReview(action)
      return true
    }
    if let action = contractBoard.selected?.identifiedSalvage {
      contractBoard.identifiedSalvageQuote = identifiedSalvageReview(action)
      return true
    }
    contractBoard.wayfarerInductionQuote = nil
    contractBoard.glassMeridianQuote = nil
    contractBoard.flightReceptionQuote = nil
    contractBoard.measuredExtractionQuote = nil
    contractBoard.recordRecoveryQuote = nil
    contractBoard.identifiedSalvageQuote = nil
    if let action = contractBoard.selected?.survey {
      contractBoard.surveyQuote = originalSurveyReview(action)
      return true
    }
    contractBoard.surveyQuote = nil
    if let row = contractBoard.selected?.repairLoop {
      contractBoard.repairLoopQuote = wayfarerRepairLoopReview(row)
      return true
    }
    contractBoard.repairLoopQuote = nil
    if let row = contractBoard.selected?.coldChain {
      contractBoard.coldChainQuote = wayfarerColdChainReview(row)
      return true
    }
    contractBoard.coldChainQuote = nil
    if let row = contractBoard.selected?.provider {
      contractBoard.providerQuote = .init(
        row: row, issues: contractBoard.selected?.reason.map { [$0] } ?? [])
      return true
    }
    contractBoard.providerQuote = nil
    if let row = contractBoard.selected?.people {
      contractBoard.peopleQuote = nativePeopleQuote(row)
      return true
    }
    contractBoard.peopleQuote = nil
    if let row = contractBoard.selected?.finance {
      contractBoard.financeQuote = financeQuote(for: row)
      return true
    }
    contractBoard.financeQuote = nil
    return false
  }
  mutating func contractBoardKey(_ key: String) {
    let previous = scriptContractPageIdentity
    defer { finishContractNavigation(from: previous) }
    applyContractBoardKey(key)
  }

  // Action-local quotes must not remain on the stack while page identity validates custody.
  @inline(never)
  private mutating func applyContractBoardKey(_ key: String) {
    if key == "escape" {
      if contractBoard.detail {
        contractBoard.detail = false
        contractBoard.quote = nil
        contractBoard.financeQuote = nil
        contractBoard.peopleQuote = nil
        contractBoard.providerQuote = nil
        contractBoard.repairLoopQuote = nil
        contractBoard.coldChainQuote = nil
        contractBoard.inquiryQuote = nil
        contractBoard.utilityQuote = nil
      contractBoard.underTowQuote = nil
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
      contractBoard.assemblyOfOrbitsQuote = nil
      contractBoard.isolationWorkParentQuote = nil
      contractBoard.hollowManifestQuote = nil
        gallery.providerIntent = nil
      } else {
        screen = contractBoard.previous
      }
      return
    }
    if key == "contract-refresh" {
      openContractBoard()
      return
    }
    if !contractBoard.detail {
      if key == "up" || key == "down" {
        contractBoard.selection = max(
          0, min(contractBoard.rows.count - 1, contractBoard.selection + (key == "up" ? -1 : 1)))
      }
      if key == "return", contractBoard.selected != nil {
        contractBoard.detail = true
        contractBoard.action = .back
        contractBoard.scroll = 0
        refreshSelectedContractQuote()
      }
      return
    }
    applyContractDetailKey(key)
  }

  // Detail confirmation buffers are not needed while opening a review from the list.
  @inline(never)
  private mutating func applyContractDetailKey(_ key: String) {
    if ["left", "right", "tab"].contains(key) {
      let actions = ContractBoardAction.allCases
      let index = actions.firstIndex(of: contractBoard.action)!
      contractBoard.action = actions[(index + (key == "left" ? 2 : 1)) % 3]
    }
    if ["up", "down", "pageup", "pagedown"].contains(key) {
      scrollContractDetail(key)
    }
    guard key == "return" else { return }
    if contractBoard.action == .back {
      contractBoard.detail = false
      contractBoard.quote = nil
      contractBoard.financeQuote = nil
      contractBoard.peopleQuote = nil
      contractBoard.providerQuote = nil
      contractBoard.repairLoopQuote = nil
      contractBoard.coldChainQuote = nil
      contractBoard.inquiryQuote = nil
      contractBoard.surveyQuote = nil
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
      contractBoard.measuredExtractionQuote = nil
      contractBoard.recordRecoveryQuote = nil
      contractBoard.identifiedSalvageQuote = nil
      contractBoard.utilityQuote = nil
      contractBoard.underTowQuote = nil
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
      contractBoard.assemblyOfOrbitsQuote = nil
      contractBoard.isolationWorkParentQuote = nil
      contractBoard.hollowManifestQuote = nil
      gallery.providerIntent = nil
      return
    }
    do {
      if let completion = try confirmContractDetailAction() {
        finishContractDetailConfirmation(completion)
      }
    } catch {
      openContractBoard()
      notify(String(error.localizedDescription.prefix(512)))
    }
  }

  private enum ContractDetailCompletion {
    case borrowedVoice
    case quietChoir
    case memoryAtlas
    case publicRecord
    case signedPassageOpening
    case underTow
    case assemblyOfOrbits
    case utility
    case isolationWorkParent

    case hollowManifest
    case wayfarerInduction
    case glassMeridian
    case inquiry
    case defensiveFlight
    case safeGunnery
    case flightReception
    case measuredExtraction
    case recordRecovery
    case identifiedSalvage
    case survey
    case repairLoop
    case coldChain
    case people
    case finance
    case ordinary
  }

  // Return before refreshing rows: native quotes can validate and encode loss witnesses.
  @inline(never)
  private mutating func confirmContractDetailAction() throws -> ContractDetailCompletion? {
    if let action = contractBoard.selected?.publicRecord {
      guard contractBoard.action == .accept, let quote = contractBoard.publicRecordQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Sol's current Public Record case; Back changes nothing.") }
      try confirmPublicRecord(quote)
      return .publicRecord
    }
    if let action = contractBoard.selected?.hollowManifest {
      guard contractBoard.action == .accept, let quote = contractBoard.hollowManifestQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Toren's current original commission.") }
      try confirmHollowManifest(quote)
      return .hollowManifest
    }
    if let action = contractBoard.selected?.borrowedVoice {
      guard contractBoard.action == .accept, let quote = contractBoard.borrowedVoiceQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Dain's current Borrowed Voice investigation; Back changes nothing.") }
      try confirmBorrowedVoice(quote)
      return .borrowedVoice
    }
    if let action = contractBoard.selected?.quietChoir {
      guard contractBoard.action == .accept, let quote = contractBoard.quietChoirQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Holt's current Quiet Choir investigation; Back changes nothing.") }
      try confirmQuietChoir(quote)
      return .quietChoir
    }
    if let action = contractBoard.selected?.memoryAtlas {
      guard contractBoard.action == .accept, let quote = contractBoard.memoryAtlasQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Vale's current The Memory Atlas commission; Back changes nothing.") }
      try confirmMemoryAtlas(quote)
      return .memoryAtlas
    }
    if let action = contractBoard.selected?.signedPassageOpening {
      guard contractBoard.action == .accept, let quote = contractBoard.signedPassageOpeningQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Senn's current Signed Passage commission; Back changes nothing.") }
      try confirmSignedPassageOpening(quote)
      return .signedPassageOpening
    }
    if let action = contractBoard.selected?.assemblyOfOrbits {
      guard contractBoard.action == .accept, let quote = contractBoard.assemblyOfOrbitsQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Voss's current Assembly action; Back changes nothing.") }
      try confirmAssemblyOfOrbits(quote)
      return .assemblyOfOrbits
    }
    if let action = contractBoard.selected?.underTow {
      guard contractBoard.action == .accept, let quote = contractBoard.underTowQuote,
        quote.action == action, quote.allowed
      else { throw MissionPackError("Review Penn's current Under Tow action; Back changes nothing.") }
      try confirmUnderTow(quote)
      return .underTow
    }
    if let action = contractBoard.selected?.isolationWorkParent {
      guard contractBoard.action == .accept,
        let quote = contractBoard.isolationWorkParentQuote, quote.action == action, quote.allowed
      else { throw MissionPackError("Review Lerr's current isolation action; Back changes nothing.") }
      try confirmIsolationWorkParent(quote)
      return .isolationWorkParent
    }
    if let action = contractBoard.selected?.utility {
      guard contractBoard.action == .accept, let review = contractBoard.utilityQuote,
        review.action == action, let quote = review.quote, review.allowed
      else {
        throw MissionPackError("Review the current utility operation and choose Confirm or Back.")
      }
      try confirmNativeUtility(quote)
      return .utility
    }
    if let action = contractBoard.selected?.wayfarerInduction {
      guard contractBoard.action == .accept, let quote = contractBoard.wayfarerInductionQuote,
        quote.action == action, quote.allowed
      else {
        throw MissionPackError("Review the current induction action and choose Confirm or Back.")
      }
      try confirmWayfarerInduction(quote)
      return .wayfarerInduction
    }
    if contractBoard.selected?.inquiry == .requestCase {
      guard contractBoard.action == .accept,
        let quote = contractBoard.inquiryQuote, quote.allowed
      else { throw MissionPackError("Review the current inquiry request and choose Confirm or Back.") }
      try confirmC01InquiryRequest(quote)
      return .inquiry
    }
    if let action = contractBoard.selected?.glassMeridian {
      guard action == .accept || action == .auditReservations || action.isC01Completion,
        contractBoard.action == .accept,
        let quote = contractBoard.glassMeridianQuote, quote.action == action
      else {
        throw MissionPackError("Read the current investigation; Back preserves it.")
      }
      try confirmGlassMeridian(quote)
      return .glassMeridian
    }
    if let action = contractBoard.selected?.defensiveFlight {
      guard contractBoard.action == .accept, let quote = contractBoard.defensiveFlightQuote,
        quote.action == action
      else { throw MissionPackError("Review defensive flight and choose Confirm or Back.") }
      try confirmDefensiveFlight(quote)
      return .defensiveFlight
    }
    if let action = contractBoard.selected?.safeGunnery {
      guard contractBoard.action == .accept, let quote = contractBoard.safeGunneryQuote,
        quote.action == action
      else { throw MissionPackError("Review safe gunnery and choose Confirm or Back.") }
      try confirmSafeGunnery(quote)
      return .safeGunnery
    }
    if let action = contractBoard.selected?.flightReception {
      guard contractBoard.action == .accept, let quote = contractBoard.flightReceptionQuote,
        quote.action == action
      else { throw MissionPackError("Review the practice and choose Confirm or Back.") }
      try confirmFlightReception(quote)
      return .flightReception
    }
    if let action = contractBoard.selected?.measuredExtraction {
      guard contractBoard.action == .accept, let quote = contractBoard.measuredExtractionQuote,
        quote.action == action
      else {
        throw MissionPackError("Review the extraction operation and choose Confirm or Back.")
      }
      try confirmMeasuredExtraction(quote)
      return .measuredExtraction
    }
    if let action = contractBoard.selected?.recordRecovery {
      guard contractBoard.action == .accept, let quote = contractBoard.recordRecoveryQuote,
        quote.action == action
      else { throw MissionPackError("Review the depot operation and choose Confirm or Back.") }
      try confirmRecordRecovery(quote)
      return .recordRecovery
    }
    if let action = contractBoard.selected?.identifiedSalvage {
      guard contractBoard.action == .accept, let quote = contractBoard.identifiedSalvageQuote,
        quote.action == action
      else { throw MissionPackError("Review the depot operation and choose Confirm or Back.") }
      try confirmIdentifiedSalvage(quote)
      return .identifiedSalvage
    }
    if let action = contractBoard.selected?.survey {
      guard contractBoard.action == .accept, let quote = contractBoard.surveyQuote,
        quote.action == action
      else { throw MissionPackError("Review the survey and choose Confirm or Back.") }
      try confirmOriginalSurvey(quote)
      return .survey
    }
    if let row = contractBoard.selected?.repairLoop {
      guard contractBoard.action == .accept, let quote = contractBoard.repairLoopQuote,
        quote.row == row
      else {
        throw MissionPackError("Review the native service and choose Confirm or Back.")
      }
      try confirmWayfarerRepairLoopBoard(quote)
      return .repairLoop
    }
    if let row = contractBoard.selected?.coldChain {
      guard contractBoard.action == .accept, let quote = contractBoard.coldChainQuote,
        quote.row == row
      else {
        throw MissionPackError("Review the native service and choose Confirm or Back.")
      }
      try confirmWayfarerColdChainBoard(quote)
      return .coldChain
    }
    if contractBoard.selected?.provider != nil {
      if contractBoard.action == .decline {
        gallery.providerIntent = nil
        contractBoard.detail = false
        contractBoard.providerQuote = nil
      } else {
        try stageProviderContractIntent()
      }
      return nil
    }
    if let row = contractBoard.selected?.people {
      guard contractBoard.action == .accept, let quote = contractBoard.peopleQuote,
        quote.row == row
      else {
        throw MissionPackError("Review the person transfer and choose Confirm or Back.")
      }
      try confirmNativePeople(quote)
      return .people
    }
    if let row = contractBoard.selected?.finance {
      guard let quote = contractBoard.financeQuote, quote.row == row else {
        throw MissionPackError("Review the financial terms before confirming.")
      }
      try confirmFinance(quote, declining: contractBoard.action == .decline)
      return .finance
    }

    guard let row = contractBoard.selected, let offer = row.offer else {
      throw MissionPackError("This provider is unavailable.")
    }
    if contractBoard.action == .accept {
      guard let quote = contractBoard.quote else {
        throw MissionPackError("Review this offer before accepting.")
      }
      _ = try confirmContract(quote)
      notify(
        quote.pledge == nil
          ? "CONTRACT ACCEPTED - SEE MISSION GALLERY"
          : quote.pledge.map({ OriginalMutualContribution.matches($0.declaration) }) == true
            ? "CEDAMAR ORBITAL RELIEF RESERVE RECEIVED 500.0 CR - NO CASH REWARD"
            : "DONATION COMPLETE - LOCAL STANDING RECORDED")
    } else {
      guard scriptDurabilityAvailable else {
        throw MissionPackError("Choose a writable commander save before declining a contract offer.")
      }
      try declineContract(board: row.board, offer: offer.id)
      notify("OFFER DECLINED")
    }
    return .ordinary
  }

  @inline(never)
  private mutating func finishContractDetailConfirmation(_ completion: ContractDetailCompletion) {
    refreshContractRows()
    contractBoard.detail = false
    switch completion {
    case .hollowManifest:
      contractBoard.hollowManifestQuote = nil
    case .borrowedVoice:
      contractBoard.borrowedVoiceQuote = nil
    case .quietChoir:
      contractBoard.quietChoirQuote = nil
    case .memoryAtlas:
      contractBoard.memoryAtlasQuote = nil
    case .publicRecord:
      contractBoard.publicRecordQuote = nil
    case .signedPassageOpening:
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
    case .isolationWorkParent:
      contractBoard.isolationWorkParentQuote = nil
      contractBoard.hollowManifestQuote = nil
    case .utility:
      contractBoard.utilityQuote = nil
      contractBoard.underTowQuote = nil
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
      contractBoard.assemblyOfOrbitsQuote = nil
    case .wayfarerInduction:
      contractBoard.wayfarerInductionQuote = nil
    case .inquiry:
      contractBoard.inquiryQuote = nil
    case .glassMeridian:
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
    case .defensiveFlight:
      contractBoard.defensiveFlightQuote = nil
    case .safeGunnery:
      contractBoard.safeGunneryQuote = nil
    case .flightReception:
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
    case .measuredExtraction:
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
      contractBoard.measuredExtractionQuote = nil
    case .recordRecovery:
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
      contractBoard.measuredExtractionQuote = nil
      contractBoard.recordRecoveryQuote = nil
    case .identifiedSalvage:
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
      contractBoard.measuredExtractionQuote = nil
      contractBoard.recordRecoveryQuote = nil
      contractBoard.identifiedSalvageQuote = nil
      contractBoard.utilityQuote = nil
      contractBoard.underTowQuote = nil
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
      contractBoard.assemblyOfOrbitsQuote = nil
      contractBoard.isolationWorkParentQuote = nil
      contractBoard.hollowManifestQuote = nil
    case .survey:
      contractBoard.surveyQuote = nil
    case .repairLoop:
      contractBoard.repairLoopQuote = nil
    case .coldChain:
      contractBoard.repairLoopQuote = nil
      contractBoard.coldChainQuote = nil
    case .people:
      contractBoard.peopleQuote = nil
      notify("PERSON TRANSFER RECORDED")
    case .finance:
      contractBoard.financeQuote = nil
      notify("FINANCIAL DECISION RECORDED")
    case .underTow:
      contractBoard.underTowQuote = nil
      contractBoard.signedPassageOpeningQuote = nil
      contractBoard.publicRecordQuote = nil
      contractBoard.borrowedVoiceQuote = nil
      contractBoard.quietChoirQuote = nil
      contractBoard.memoryAtlasQuote = nil
    case .assemblyOfOrbits:
      contractBoard.assemblyOfOrbitsQuote = nil
    case .ordinary:
      contractBoard.quote = nil
    }
  }

  private mutating func scrollContractDetail(_ key: String) {
    let count = Display.contractDetailRows(self, width: viewportWidth).count
    let visible = ContractBoardLayout(width: viewportWidth, height: viewportHeight).detailCount
    let window = ScrollWindow(count: count, visible: visible, offset: contractBoard.scroll)
    contractBoard.scroll = window.moved(key == "up" || key == "pageup" ? -4 : 4)
  }
  public var activeContractSummary: [String] {
    return commander.scriptState.instances.values.filter {
        $0.outcome == .active && $0.contract != nil
      }
      .sorted { $0.id.uuidString < $1.id.uuidString }.map { instance in
        let job = instance.contract!
        let name = Universe.systemsIncludingPlugh(number: job.station.galaxy)[job.station.system]
          .name
        let late = job.deadline.map { commander.scriptState.clock(job.clock) >= $0 } ?? false
        return job.offer.title + " / " + name + (late ? " / OVERDUE" : " / ACTIVE")
      }
  }
  mutating func contractClick(x: Double, y: Double) {
    guard screen == .contracts, !paused, x.isFinite, y.isFinite,
      x >= 0, y >= 0, x <= viewportWidth, y <= viewportHeight
    else { return }
    let layout = ContractBoardLayout(width: viewportWidth, height: viewportHeight)
    let point = ScreenPoint(x, y)
    if contractBoard.detail {
      if let action = layout.actions.first(where: { $0.1.contains(point) })?.0 {
        contractBoard.action = action
        contractBoardKey("return")
      }
    } else if layout.refresh.contains(point) {
      openContractBoard()
    } else if x >= layout.left && x <= layout.left + layout.width && y >= layout.listTop
      && y < layout.listBottom
    {
      let start = max(0, contractBoard.selection - layout.listCount + 1)
      let index = start + Int((y - layout.listTop) / layout.listRow)
      if contractBoard.rows.indices.contains(index) {
        contractBoard.selection = index
        contractBoardKey("return")
      }
    }
  }
}
extension GameRuntime {
  public func contractClick(x: Double, y: Double, expectedOffer: UUID?, detail: Bool, epoch: UUID) {
    guard game.screen == .contracts, game.ecmControl.epoch == epoch,
      game.contractBoard.selected?.finance == nil,
      game.contractBoard.selected?.people == nil,
      game.contractBoard.detail == detail, game.contractBoard.quote?.offer == expectedOffer
    else { return }
    nativeCommand { $0.contractClick(x: x, y: y) }
  }
  public func contractScroll(_ amount: Int) {
    guard game.screen == .contracts else { return }
    game.contractBoardKey(amount < 0 ? "up" : "down")
  }
}
