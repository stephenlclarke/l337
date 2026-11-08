import Foundation

/// Historical reconciliation evidence only. The actual Game producer must read the
/// original held documents at the real current Garrivek contact before this is created.
struct NativeC03LedgerReconstructionReceipt: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let contact: UUID
    let dock: NativeMainStationDockReceipt
    let inspections: [UUID]
    let master: UUID
    let register: UUID
    let registerHash: String
    let registerTransfer: UUID
    let crewSourceRegistration: UUID
    let crewLog: UUID
    let crewLogHash: String
    let crewLogTransfer: UUID
    let originalCareTransfer: UUID
    let originalKit: UUID
    let issueCommand: UUID
    let carrier: UUID
    let inventoryRevision: UInt64
    let sequence: UInt64
    let beforeCaseRevision: UInt64
    let afterCaseRevision: UInt64
    let physicalTime: Double
    let calendarSeconds: Double
    let epoch: UUID
  }

  static let receipt = "hollow-manifest-ledger-reconstructed"
  static let authoredReceipt = "l337.hollow-manifest/reconstruct-ledger"
  static let dialogue =
    "TOREN: The warehouse dates, recalled master and transfer register now agree. We can identify every false claim without inventing an accusation or silencing a witness."
  let operation: UUID
  let facts: Facts

  fileprivate init(facts: Facts) throws {
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func contact(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c03-garrivek-auditor-v1:\(owner)")
  }
  static func identity(_ facts: Facts) throws -> UUID {
    guard facts.inspections.count == 2, facts.registerHash.utf8.count == 64,
      facts.crewLogHash.utf8.count == 64, ScriptCompletionReceipt.validDigest(facts.registerHash),
      ScriptCompletionReceipt.validDigest(facts.crewLogHash) else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-ledger-reconstruction-v1:\(try NativeFlightReception.hash(facts))")
  }

  /// Pure historical state joins, never current held-kit access or a contact capability.
  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    let f = facts
    guard operation == (try? Self.identity(f)), f.mission == state.birth.input.mission,
      f.owner == state.birth.input.owner, f.contact == Self.contact(owner: f.owner),
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestDefinition.freighterWorld,
      f.inspections.count == 2, f.inspections == state.inspections.map(\.operation),
      f.master == state.birth.master.id, let register = state.custodyRegister,
      let recovery = register.recovery, let laboratory = state.laboratory,
      let crew = state.crewSource, let access = state.crewLogAccess, access.valid(in: state),
      f.crewSourceRegistration == crew.registration,
      f.crewLog == access.facts.document, f.crewLogHash == access.facts.documentHash,
      f.crewLogTransfer == access.operation, f.originalCareTransfer == access.facts.careTransfer,
      f.beforeCaseRevision >= access.facts.afterCaseRevision,
      f.physicalTime >= access.facts.physicalTime,
      f.calendarSeconds >= access.facts.calendarSeconds,
      f.register == register.origin.contents.serial,
      f.registerHash == (try? NativeFlightReception.hash(register.origin.contents)),
      f.registerTransfer == recovery.operation,
      f.originalKit == recovery.facts.originalKit, f.originalKit == laboratory.facts.originalKit,
      f.issueCommand == laboratory.facts.issueCommand,
      f.inventoryRevision >= recovery.facts.inventoryRevision,
      f.inventoryRevision < UInt64(Int64.max),
      f.sequence > crew.sequence, f.sequence < state.nextSourceSequence,
      f.beforeCaseRevision > 0, f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1,
      f.physicalTime.isFinite, f.physicalTime <= 1e12,
      f.physicalTime >= recovery.facts.readout.physicalTime,
      f.calendarSeconds.isFinite, f.calendarSeconds <= 1e12,
      f.calendarSeconds >= f.dock.calendarSeconds
    else { return false }
    return true
  }

  /// Cross-owner history is retained after legitimate later movement. Current access is
  /// checked separately by the producer; this never calls broader Commander validity.
  func valid(commander: borrowing Commander) -> Bool {
    let f = facts
    guard let instance = commander.scriptState.instances[f.mission],
      let state = instance.savedHollowManifest, valid(in: state),
      f.afterCaseRevision <= instance.revision,
      let world = commander.nativeStations, world.mainStations.contains(f.dock.station),
      f.dock.sequence < world.nextMainDockSequence,
      f.dock.actor.visit <= commander.flightSimulation.visit,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: f.calendarSeconds,
        current: commander.scriptState.calendarSeconds),
      let custody = commander.nativePeople, let source = custody.hollowManifestCrew,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      source.registration.operation == f.crewSourceRegistration,
      source.registration.crewLog.serial == f.crewLog,
      f.crewLogHash == (try? NativeFlightReception.hash(source.registration.crewLog)),
      let access = source.crewLogAccess, access.operation == f.crewLogTransfer,
      access.facts.careTransfer == f.originalCareTransfer,
      access.facts.originalKit == f.originalKit, access.facts.issueCommand == f.issueCommand,
      access.facts.inventoryRevision <= f.inventoryRevision,
      access.facts.physicalTime <= f.physicalTime
    else { return false }
    return true
  }
}

/// Later remedy/return/closure receipts belong to this case file. The source state's
/// immutable case-file field is preserved by every ordinary native retention operation.
struct NativeC03CaseFile: Codable, Equatable, Sendable {
  let ledger: NativeC03LedgerReconstructionReceipt
  let remedy: NativeC03RemedyReceipt?
  let evidenceReturn: NativeC03EvidenceReturnReceipt?
  let closure: NativeC03CaseClosureReceipt?

  var sequences: [UInt64] {
    [ledger.facts.sequence]
      + [remedy?.facts.sequence, evidenceReturn?.facts.sequence, closure?.facts.sourceSequence].compactMap { $0 }
  }
  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    guard ledger.valid(in: state) else { return false }
    if let remedy, !remedy.valid(in: state) { return false }
    if let evidenceReturn, !evidenceReturn.valid(in: state) { return false }
    if let closure { return closure.valid(in: state) }
    return true
  }
  func valid(commander: borrowing Commander) -> Bool {
    guard ledger.valid(commander: commander) else { return false }
    if let remedy, !remedy.valid(commander: commander) { return false }
    if let evidenceReturn, !evidenceReturn.valid(commander: commander) { return false }
    if let closure { return closure.valid(commander: commander) }
    return true
  }
  func preservesHistory(of earlier: NativeC03CaseFile) -> Bool {
    ledger == earlier.ledger && (earlier.remedy == nil || remedy == earlier.remedy)
      && (earlier.evidenceReturn == nil || evidenceReturn == earlier.evidenceReturn)
      && (earlier.closure == nil || closure == earlier.closure)
  }
  func choosing(_ receipt: NativeC03RemedyReceipt) throws -> NativeC03CaseFile {
    guard remedy == nil, evidenceReturn == nil, closure == nil,
      receipt.facts.ledger == ledger.operation else { throw SaveError.invalidCommander }
    return .init(ledger: ledger, remedy: receipt, evidenceReturn: nil, closure: nil)
  }
  func returningEvidence(_ receipt: NativeC03EvidenceReturnReceipt) throws -> NativeC03CaseFile {
    guard evidenceReturn == nil, closure == nil, let remedy, receipt.facts.remedy == remedy.operation
    else { throw SaveError.invalidCommander }
    return .init(ledger: ledger, remedy: remedy, evidenceReturn: receipt, closure: nil)
  }
  func closing(_ receipt: NativeC03CaseClosureReceipt) throws -> NativeC03CaseFile {
    guard closure == nil, let evidenceReturn, receipt.facts.evidenceReturn == evidenceReturn.operation
    else { throw SaveError.invalidCommander }
    return .init(ledger: ledger, remedy: remedy, evidenceReturn: evidenceReturn, closure: receipt)
  }
}

final class NativeC03LedgerReconstructionReview: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let arrival: NativeMainStationArrivalContext
  let register: NativeC03HeldRegisterData
  let log: NativeC03HeldCrewLog
  let source: NativeC03CrewSourceState
  let epoch: UUID
  fileprivate init(pin: NativeHollowManifestInstalledCase, arrival: NativeMainStationArrivalContext,
    register: NativeC03HeldRegisterData, log: NativeC03HeldCrewLog,
    source: NativeC03CrewSourceState, epoch: UUID)
  {
    self.pin = pin
    self.arrival = arrival
    self.register = register
    self.log = log
    self.source = source
    self.epoch = epoch
  }
}

extension Game {
  func hollowManifestLedgerReview() throws -> NativeC03LedgerReconstructionReview {
    guard !isMissionTrial, trialTitle == nil, screen == .contracts,
      systemIdentity == NativeHollowManifestDefinition.freighterWorld,
      let instance = hollowManifestMission, instance.outcome == .active,
      instance.suspension == nil, instance.milestones == [0, 1, 2, 3, 4, 5],
      let state = instance.savedHollowManifest, state.caseFile == nil,
      let source = commander.nativePeople?.hollowManifestCrew,
      case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity)
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    let register = try hollowManifestHeldRegisterData()
    let log = try hollowManifestHeldCrewLog()
    guard register.kit == log.kit, register.contents.master == log.contents.master,
      register.contents.seals == log.contents.seals,
      register.contents.recordedCargo == log.contents.recordedCargo,
      register.contents.insuranceDeclaration == log.contents.insuranceDeclaration,
      register.contents.crewWereToldContents == log.contents.crewWereToldContents,
      acceptsHollowManifestInstalledCase(pin), acceptsNativeMainStationArrivalContext(arrival)
    else { throw SaveError.invalidCommander }
    return .init(pin: pin, arrival: arrival, register: register, log: log,
      source: source, epoch: nativeStationRuntimeEpoch)
  }

  @inline(never)
  mutating func reconstructHollowManifestLedger(_ review: NativeC03LedgerReconstructionReview) throws {
    let current = try hollowManifestLedgerReview()
    guard acceptsHollowManifestInstalledCase(review.pin), review.arrival == current.arrival,
      review.register.kit == current.register.kit, review.log.kit == current.log.kit,
      review.register.transfer == current.register.transfer, review.log.transfer == current.log.transfer,
      review.register.contents == current.register.contents, review.log.contents == current.log.contents,
      review.source == current.source, review.epoch == current.epoch,
      let access = current.source.crewLogAccess, let instance = hollowManifestMission,
      let state = instance.savedHollowManifest,
      state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1,
      commander.scriptState.calendarSeconds.isFinite, commander.scriptState.calendarSeconds >= 0
    else { throw SaveError.invalidCommander }
    let facts = NativeC03LedgerReconstructionReceipt.Facts(mission: instance.id,
      owner: current.pin.owner, contact: NativeC03LedgerReconstructionReceipt.contact(owner: current.pin.owner),
      dock: current.arrival.receipt, inspections: state.inspections.map(\.operation),
      master: state.birth.master.id, register: current.register.contents.serial,
      registerHash: try NativeFlightReception.hash(current.register.contents),
      registerTransfer: current.register.transfer, crewSourceRegistration: current.source.registration.operation,
      crewLog: current.log.contents.serial, crewLogHash: try NativeFlightReception.hash(current.log.contents),
      crewLogTransfer: current.log.transfer, originalCareTransfer: access.facts.careTransfer,
      originalKit: current.log.kit.serial, issueCommand: current.log.kit.issueCommand,
      carrier: current.log.kit.carrier, inventoryRevision: current.log.kit.inventoryRevision,
      sequence: state.nextSourceSequence, beforeCaseRevision: instance.revision,
      afterCaseRevision: instance.revision + 1, physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch)
    let receipt = try NativeC03LedgerReconstructionReceipt(facts: facts)
    var selected = instance
    selected.savedHollowManifest = try state.retainingReconstruction(receipt)
    selected.receipts.insert(NativeC03LedgerReconstructionReceipt.receipt)
    selected.milestones.insert(6)
    selected.journal.append(NativeC03LedgerReconstructionReceipt.dialogue)
    selected.revision = facts.afterCaseRevision
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard receipt.valid(commander: candidate), NativeHollowManifestSave.validateClaims(candidate),
      candidate.nativePeople == commander.nativePeople,
      candidate.equipmentInventory == commander.equipmentInventory,
      candidate.credits == commander.credits, candidate.cargo == commander.cargo,
      acceptsHollowManifestInstalledCase(review.pin)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}

extension NativeHollowManifestState {
  func retainingReconstruction(_ receipt: NativeC03LedgerReconstructionReceipt) throws -> Self {
    guard shapeValid, phase == .admitted, caseFile == nil, crewSource != nil,
      receipt.facts.sequence == nextSourceSequence, nextSourceSequence < UInt64(Int64.max) - 1
    else { throw Failure.invalidState }
    let candidate = Self(birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory,
      wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: .init(ledger: receipt, remedy: nil, evidenceReturn: nil, closure: nil))
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}
