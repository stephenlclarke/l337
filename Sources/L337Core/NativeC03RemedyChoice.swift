import Foundation

enum NativeC03RemedyChoice: String, Codable, Equatable, Sendable, CaseIterable {
  case publicDisclosure, restitutionTribunal
  var title: String {
    switch self {
    case .publicDisclosure: "Publish the complete custody ledger"
    case .restitutionTribunal: "Submit the case to the restitution tribunal"
    }
  }
}

/// Real institutional filing/publication must supply this receipt. No factory exists until
/// its native receiving owner and preserved-evidence record are actually implemented.
/// A choice, dock, office name or historical case receipt cannot construct one.
final class NativeC03CaseOfficeReceipt: Sendable {
  let operation: UUID
  let recipient: UUID
  let choice: NativeC03RemedyChoice
  let ledger: UUID
  let ledgerHash: String
  let expectedWorld: NativeStationWorld
  let selectedWorld: NativeStationWorld
  private let snapshot: CommanderSnapshot
  private let bodies: [SpaceBody]
  private let epoch: UUID

  private init(game: borrowing Game, operation: UUID, recipient: UUID,
    choice: NativeC03RemedyChoice, ledger: UUID, ledgerHash: String,
    expectedWorld: NativeStationWorld, selectedWorld: NativeStationWorld)
  {
    self.operation = operation
    self.recipient = recipient
    self.choice = choice
    self.ledger = ledger
    self.ledgerHash = ledgerHash
    self.expectedWorld = expectedWorld
    self.selectedWorld = selectedWorld
    snapshot = CommanderSnapshot(game.commander)
    bodies = game.bodies
    epoch = game.nativeStationRuntimeEpoch
  }

  fileprivate func isCurrent(in game: borrowing Game) -> Bool {
    guard epoch == game.nativeStationRuntimeEpoch else { return false }
    guard bodies == game.bodies else { return false }
    guard expectedWorld == game.commander.nativeStations else { return false }
    return snapshot.value == game.commander
  }
}

struct NativeC03RemedyReceipt: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let ledger: UUID
    let ledgerHash: String
    let choice: NativeC03RemedyChoice
    let recipient: UUID
    let recipientOperation: UUID
    let dock: NativeMainStationDockReceipt
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
  static let receipt = "hollow-manifest-remedy-chosen"
  static let authoredReceipt = "l337.hollow-manifest/choose-remedy"
  static let dialogue =
    "IVEN: Publish the full ledger to stop new claims immediately, or lodge it with the restitution tribunal so the crews receive compensation first. The evidence is preserved in either case."
  let operation: UUID
  let facts: Facts

  fileprivate init(actual: NativeC03CaseOfficeReceipt, facts: Facts) throws {
    guard actual.operation == facts.recipientOperation, actual.recipient == facts.recipient,
      actual.choice == facts.choice, actual.ledger == facts.ledger,
      actual.ledgerHash == facts.ledgerHash else { throw SaveError.invalidCommander }
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func identity(_ facts: Facts) throws -> UUID {
    guard facts.ledgerHash.utf8.count == 64, ScriptCompletionReceipt.validDigest(facts.ledgerHash)
    else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-original-remedy-v1:\(try NativeFlightReception.hash(facts))")
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    let f = facts
    guard let ledger = state.caseFile?.ledger, ledger.valid(in: state),
      operation == (try? Self.identity(f)), f.mission == state.birth.input.mission,
      f.owner == state.birth.input.owner, f.ledger == ledger.operation,
      f.ledgerHash == (try? NativeFlightReception.hash(ledger)),
      f.recipient == state.laboratory?.facts.issuer,
      f.recipient == NativeHollowManifestKitDefinition.issuer(owner: f.owner),
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestDefinition.laboratoryWorld,
      f.originalKit == ledger.facts.originalKit, f.issueCommand == ledger.facts.issueCommand,
      f.inventoryRevision >= ledger.facts.inventoryRevision, f.inventoryRevision < UInt64(Int64.max),
      f.sequence > ledger.facts.sequence, f.sequence < state.nextSourceSequence,
      f.beforeCaseRevision >= ledger.facts.afterCaseRevision,
      f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1,
      f.physicalTime.isFinite, f.physicalTime >= ledger.facts.physicalTime, f.physicalTime <= 1e12,
      f.calendarSeconds.isFinite, f.calendarSeconds >= ledger.facts.calendarSeconds,
      f.calendarSeconds >= f.dock.calendarSeconds, f.calendarSeconds <= 1e12
    else { return false }
    return true
  }

  /// Actual receiving owner must additionally validate its preserved institutional record
  /// in G1's full case/save graph. The saved operation ID alone is never acceptance proof.
  func valid(commander: borrowing Commander) -> Bool {
    let f = facts
    guard let instance = commander.scriptState.instances[f.mission],
      let state = instance.savedHollowManifest, valid(in: state),
      f.afterCaseRevision <= instance.revision, let world = commander.nativeStations,
      world.mainStations.contains(f.dock.station), f.dock.sequence < world.nextMainDockSequence,
      f.dock.actor.visit <= commander.flightSimulation.visit,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: f.calendarSeconds,
        current: commander.scriptState.calendarSeconds)
    else { return false }
    return true
  }

  var journal: [String] { [Self.dialogue, facts.choice.title] }
}

final class NativeC03RemedyReview: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let arrival: NativeMainStationArrivalContext
  let choice: NativeC03RemedyChoice
  let ledger: NativeC03LedgerReconstructionReceipt
  let kit: NativeHollowManifestKitBinding
  let registerTransfer: UUID
  let logTransfer: UUID
  let epoch: UUID
  fileprivate init(pin: NativeHollowManifestInstalledCase, arrival: NativeMainStationArrivalContext,
    choice: NativeC03RemedyChoice, ledger: NativeC03LedgerReconstructionReceipt,
    kit: NativeHollowManifestKitBinding, registerTransfer: UUID, logTransfer: UUID, epoch: UUID)
  {
    self.pin = pin
    self.arrival = arrival
    self.choice = choice
    self.ledger = ledger
    self.kit = kit
    self.registerTransfer = registerTransfer
    self.logTransfer = logTransfer
    self.epoch = epoch
  }
}

extension Game {
  func hollowManifestRemedyReview(_ choice: NativeC03RemedyChoice) throws -> NativeC03RemedyReview {
    guard !isMissionTrial, trialTitle == nil, screen == .contracts,
      systemIdentity == NativeHollowManifestDefinition.laboratoryWorld,
      let instance = hollowManifestMission, instance.outcome == .active, instance.suspension == nil,
      instance.milestones == [0, 1, 2, 3, 4, 5, 6],
      let file = instance.savedHollowManifest?.caseFile, file.remedy == nil,
      file.valid(commander: commander),
      case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity)
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    let register = try hollowManifestHeldRegisterData()
    let log = try hollowManifestHeldCrewLog()
    guard register.kit == log.kit, register.transfer == file.ledger.facts.registerTransfer,
      log.transfer == file.ledger.facts.crewLogTransfer,
      acceptsHollowManifestInstalledCase(pin), acceptsNativeMainStationArrivalContext(arrival)
    else { throw SaveError.invalidCommander }
    return .init(pin: pin, arrival: arrival, choice: choice, ledger: file.ledger, kit: log.kit,
      registerTransfer: register.transfer, logTransfer: log.transfer, epoch: nativeStationRuntimeEpoch)
  }

  @inline(never)
  mutating func confirmHollowManifestRemedy(_ review: NativeC03RemedyReview,
    receiving: NativeC03CaseOfficeReceipt) throws
  {
    let current = try hollowManifestRemedyReview(review.choice)
    guard acceptsHollowManifestInstalledCase(review.pin), review.arrival == current.arrival,
      review.ledger == current.ledger, review.kit == current.kit,
      review.registerTransfer == current.registerTransfer, review.logTransfer == current.logTransfer,
      review.epoch == current.epoch, receiving.isCurrent(in: self),
      receiving.choice == current.choice, receiving.ledger == current.ledger.operation,
      receiving.ledgerHash == (try? NativeFlightReception.hash(current.ledger)),
      receiving.recipient == NativeHollowManifestKitDefinition.issuer(owner: current.pin.owner),
      let instance = hollowManifestMission, let state = instance.savedHollowManifest,
      let file = state.caseFile, state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let facts = NativeC03RemedyReceipt.Facts(mission: instance.id, owner: current.pin.owner,
      ledger: current.ledger.operation, ledgerHash: try NativeFlightReception.hash(current.ledger),
      choice: current.choice, recipient: receiving.recipient, recipientOperation: receiving.operation,
      dock: current.arrival.receipt, originalKit: current.kit.serial, issueCommand: current.kit.issueCommand,
      carrier: current.kit.carrier, inventoryRevision: current.kit.inventoryRevision,
      sequence: state.nextSourceSequence, beforeCaseRevision: instance.revision,
      afterCaseRevision: instance.revision + 1, physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch)
    let receipt = try NativeC03RemedyReceipt(actual: receiving, facts: facts)
    var selected = instance
    selected.savedHollowManifest = try state.retainingCaseFile(file.choosing(receipt))
    selected.receipts.insert(NativeC03RemedyReceipt.receipt)
    selected.milestones.insert(7)
    selected.journal += receipt.journal
    selected.revision = facts.afterCaseRevision
    var candidate = commander
    candidate.nativeStations = receiving.selectedWorld
    candidate.scriptState.instances[instance.id] = selected
    guard receipt.valid(commander: candidate), NativeHollowManifestSave.validateClaims(candidate),
      candidate.nativeStationStateValid,
      receiving.selectedWorld.ledger == receiving.expectedWorld.ledger,
      receiving.selectedWorld.poses == receiving.expectedWorld.poses,
      receiving.selectedWorld.stationInertia == receiving.expectedWorld.stationInertia,
      receiving.selectedWorld.mainStations == receiving.expectedWorld.mainStations,
      receiving.selectedWorld.mainObservations == receiving.expectedWorld.mainObservations,
      receiving.selectedWorld.nextMainDockSequence == receiving.expectedWorld.nextMainDockSequence,
      receiving.selectedWorld.currentMainDock == receiving.expectedWorld.currentMainDock,
      receiving.selectedWorld.arkFuel == receiving.expectedWorld.arkFuel,
      receiving.selectedWorld.clockOrigin == receiving.expectedWorld.clockOrigin,
      receiving.selectedWorld.adapterRevision == receiving.expectedWorld.adapterRevision,
      receiving.selectedWorld.geometryRevision == receiving.expectedWorld.geometryRevision,
      candidate.nativePeople == commander.nativePeople,
      candidate.equipmentInventory == commander.equipmentInventory,
      candidate.credits == commander.credits, candidate.cargo == commander.cargo,
      acceptsHollowManifestInstalledCase(review.pin)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}

extension NativeHollowManifestState {
  func retainingCaseFile(_ file: NativeC03CaseFile) throws -> Self {
    guard shapeValid, phase == .admitted, let old = caseFile, file != old,
      file.preservesHistory(of: old), file.sequences.count == old.sequences.count + 1,
      Set(file.sequences).subtracting(old.sequences) == [nextSourceSequence],
      nextSourceSequence < UInt64(Int64.max) - 1 else { throw Failure.invalidState }
    let candidate = Self(birth: birth, phase: phase, nextSourceSequence: nextSourceSequence + 1,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory,
      wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource, crewLogAccess: crewLogAccess, caseFile: file)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}
