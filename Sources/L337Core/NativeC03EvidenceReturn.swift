import Foundation

final class NativeC03EvidenceReturnReview: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let arrival: NativeMainStationArrivalContext
  let register: NativeC03HeldRegisterData
  let log: NativeC03HeldCrewLog
  let item: OwnedEquipmentItem
  let issue: ScriptGearIssue
  let epoch: UUID
  fileprivate init(pin: NativeHollowManifestInstalledCase, arrival: NativeMainStationArrivalContext,
    register: NativeC03HeldRegisterData, log: NativeC03HeldCrewLog, item: OwnedEquipmentItem,
    issue: ScriptGearIssue, epoch: UUID)
  {
    self.pin = pin
    self.arrival = arrival
    self.register = register
    self.log = log
    self.item = item
    self.issue = issue
    self.epoch = epoch
  }
}

/// Actual existing equipment-kernel output, still unpublished. Preparing this neither
/// removes the live kit nor transfers data. The real receiving owner must consume it.
final class NativeC03EquipmentReturnPreparation: Sendable {
  let review: NativeC03EvidenceReturnReview
  let inventory: OwnedEquipmentInventory
  let returnedIssue: ScriptGearIssue
  let equipmentReceipt: EquipmentIssueReceipt
  let flight: FlightSimulationState
  let calendar: Double
  private let snapshot: CommanderSnapshot
  private let bodies: [SpaceBody]

  fileprivate init(game: borrowing Game, review: NativeC03EvidenceReturnReview,
    inventory: OwnedEquipmentInventory, returnedIssue: ScriptGearIssue, receipt: EquipmentIssueReceipt)
  {
    self.review = review
    self.inventory = inventory
    self.returnedIssue = returnedIssue
    equipmentReceipt = receipt
    flight = game.commander.flightSimulation
    calendar = game.commander.scriptState.calendarSeconds
    snapshot = CommanderSnapshot(game.commander)
    bodies = game.bodies
  }

  func isCurrent(in game: borrowing Game) -> Bool {
    guard review.epoch == game.nativeStationRuntimeEpoch else { return false }
    guard bodies == game.bodies else { return false }
    return snapshot.value == game.commander
  }
}

/// NO factory until the actual Narargan institutional data/device receiver, original
/// physical stock and loaded-mass transfer source are implemented and qualified. Private
/// construction cannot be replaced by a dock, recipient name, selected world or case tag.
final class NativeC03EvidenceIntakeReceipt: Sendable {
  let operation: UUID
  let recipient: UUID
  let preparation: NativeC03EquipmentReturnPreparation
  let expectedWorld: NativeStationWorld
  let selectedWorld: NativeStationWorld
  private init(operation: UUID, recipient: UUID, preparation: NativeC03EquipmentReturnPreparation,
    expectedWorld: NativeStationWorld, selectedWorld: NativeStationWorld)
  {
    self.operation = operation
    self.recipient = recipient
    self.preparation = preparation
    self.expectedWorld = expectedWorld
    self.selectedWorld = selectedWorld
  }

  fileprivate func isCurrent(in game: borrowing Game) -> Bool {
    guard preparation.isCurrent(in: game) else { return false }
    return expectedWorld == game.commander.nativeStations
  }
}

extension Game {
  func hollowManifestEvidenceReturnReview() throws -> NativeC03EvidenceReturnReview {
    guard !isMissionTrial, trialTitle == nil, screen == .contracts,
      systemIdentity == NativeHollowManifestKitDefinition.returnLocation,
      let instance = hollowManifestMission, instance.outcome == .active, instance.suspension == nil,
      instance.milestones == [0, 1, 2, 3, 4, 5, 6, 7],
      let file = instance.savedHollowManifest?.caseFile,
      file.remedy != nil, file.evidenceReturn == nil, file.valid(commander: commander),
      case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity),
      let issue = instance.gearIssues[NativeHollowManifestKitDefinition.resource]
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    // Capture real held contents BEFORE the equipment settlement removes its original.
    let register = try hollowManifestHeldRegisterData()
    let log = try hollowManifestHeldCrewLog()
    guard register.kit == log.kit, issue.status == .issued, issue.consumed.isEmpty,
      issue.items == [log.kit.serial], issue.displacements?.isEmpty == true,
      let inventory = commander.equipmentInventory,
      let item = inventory.items.first(where: { $0.id == log.kit.serial }),
      inventory.items.filter({ $0.id == log.kit.serial }) == [item],
      item.node == NativeHollowManifestKitDefinition.node, item.location == nil,
      acceptsHollowManifestInstalledCase(pin), acceptsNativeMainStationArrivalContext(arrival)
    else { throw EquipmentIssueError.staleObligation }
    return .init(pin: pin, arrival: arrival, register: register, log: log,
      item: item, issue: issue, epoch: nativeStationRuntimeEpoch)
  }

  /// Real existing returnOriginals kernel on private scratch; never a manual item deletion,
  /// replacement loan, released loan or live equipment/data mutation.
  @inline(never)
  func prepareHollowManifestEquipmentReturn(_ review: NativeC03EvidenceReturnReview) throws
    -> NativeC03EquipmentReturnPreparation
  {
    let current = try hollowManifestEvidenceReturnReview()
    guard acceptsHollowManifestInstalledCase(review.pin), review.arrival == current.arrival,
      review.register.kit == current.register.kit, review.log.kit == current.log.kit,
      review.register.contents == current.register.contents, review.log.contents == current.log.contents,
      review.register.transfer == current.register.transfer, review.log.transfer == current.log.transfer,
      review.item == current.item, review.issue == current.issue, review.epoch == current.epoch,
      var selected = hollowManifestMission, let before = commander.equipmentInventory,
      before.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let command = ScriptIdentity.uuid(
      "c03-original-kit-return-v1:\(selected.id):\(review.pin.state.nextSourceSequence):\(review.log.transfer)")
    var scratch = commander
    let applied = try settleScriptGearWithReceipt(review.issue, release: false, command: command,
      state: &selected, candidate: &scratch)
    guard let inventory = scratch.equipmentInventory,
      let issue = selected.gearIssues[NativeHollowManifestKitDefinition.resource],
      inventory.owner == before.owner, inventory.activeHull == before.activeHull,
      inventory.revision == before.revision + 1,
      inventory.items == before.items.filter({ $0.id != review.log.kit.serial }),
      applied.receipt.operation == .returned, applied.receipt.originalItems == [review.log.kit.serial],
      applied.receipt.affectedItems == [review.log.kit.serial], applied.receipt.consumedItems.isEmpty,
      applied.receipt.displacements.isEmpty, issue.status == .returned,
      scratch.credits == commander.credits, scratch.cargo == commander.cargo
    else { throw EquipmentIssueError.identityMismatch }
    return .init(game: self, review: review, inventory: inventory,
      returnedIssue: issue, receipt: applied.receipt)
  }

  /// The real recipient's selected state must already hold the SAME original data and
  /// physical kit. Publish that state, data holders and actual returned inventory together.
  @inline(never)
  mutating func returnHollowManifestEvidence(_ receiving: NativeC03EvidenceIntakeReceipt) throws {
    let prepared = receiving.preparation
    let review = prepared.review
    let current = try hollowManifestEvidenceReturnReview()
    guard receiving.isCurrent(in: self), acceptsHollowManifestInstalledCase(review.pin),
      review.arrival == current.arrival, review.item == current.item, review.issue == current.issue,
      review.register.kit == current.register.kit, review.log.kit == current.log.kit,
      review.register.contents == current.register.contents, review.log.contents == current.log.contents,
      review.register.transfer == current.register.transfer, review.log.transfer == current.log.transfer,
      review.epoch == current.epoch,
      receiving.recipient == NativeHollowManifestKitDefinition.issuer(owner: review.pin.owner),
      let instance = hollowManifestMission, let state = instance.savedHollowManifest,
      let file = state.caseFile, let remedy = file.remedy,
      var custody = commander.nativePeople, var source = custody.hollowManifestCrew,
      source.crewLogHolder == .originalInspectionKit(review.log.kit.serial),
      state.nextSourceSequence < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let facts = NativeC03EvidenceReturnReceipt.Facts(mission: instance.id, owner: review.pin.owner,
      remedy: remedy.operation, recipient: receiving.recipient, receivingOperation: receiving.operation,
      dock: review.arrival.receipt, register: review.register.contents.serial,
      registerHash: try NativeFlightReception.hash(review.register.contents), registerTransfer: review.register.transfer,
      crewLog: review.log.contents.serial, crewLogHash: try NativeFlightReception.hash(review.log.contents),
      crewLogTransfer: review.log.transfer, originalKit: review.log.kit.serial,
      itemHash: try NativeFlightReception.hash(review.item), issueCommand: review.log.kit.issueCommand,
      equipmentCommand: prepared.equipmentReceipt.command, equipmentSource: prepared.equipmentReceipt.source,
      carrier: review.log.kit.carrier, beforeInventoryRevision: review.log.kit.inventoryRevision,
      afterInventoryRevision: prepared.inventory.revision, beforeCaseRevision: instance.revision,
      afterCaseRevision: instance.revision + 1, sequence: state.nextSourceSequence,
      physicalTime: prepared.flight.physicalTime, calendarSeconds: prepared.calendar, epoch: review.epoch)
    let receipt = try NativeC03EvidenceReturnReceipt(receiving: receiving,
      equipment: prepared.equipmentReceipt, facts: facts)
    source.crewLogHolder = .institutionalRecipient(receiving.recipient)
    custody.hollowManifestCrew = source
    var selected = instance
    selected.savedHollowManifest = try state.retainingCaseFile(file.returningEvidence(receipt))
    selected.gearIssues[NativeHollowManifestKitDefinition.resource] = prepared.returnedIssue
    selected.receipts.insert(NativeC03EvidenceReturnReceipt.receipt)
    selected.milestones.insert(8)
    selected.journal.append(NativeC03EvidenceReturnReceipt.dialogue)
    selected.revision = facts.afterCaseRevision
    var candidate = commander
    candidate.nativeStations = receiving.selectedWorld
    candidate.savedEquipmentInventory = prepared.inventory
    candidate.mirrorFittedEquipment()
    candidate.savedNativePeopleCustody = custody
    candidate.scriptState.instances[instance.id] = selected
    guard receipt.valid(commander: candidate), NativeHollowManifestSave.validateClaims(candidate),
      candidate.nativeStationStateValid, custody.valid(commander: candidate),
      receiving.selectedWorld.ledger == receiving.expectedWorld.ledger,
      receiving.selectedWorld.poses == receiving.expectedWorld.poses,
      receiving.selectedWorld.mainStations == receiving.expectedWorld.mainStations,
      receiving.selectedWorld.mainObservations == receiving.expectedWorld.mainObservations,
      receiving.selectedWorld.nextMainDockSequence == receiving.expectedWorld.nextMainDockSequence,
      receiving.selectedWorld.currentMainDock == receiving.expectedWorld.currentMainDock,
      receiving.selectedWorld.arkFuel == receiving.expectedWorld.arkFuel,
      receiving.selectedWorld.clockOrigin == receiving.expectedWorld.clockOrigin,
      receiving.selectedWorld.adapterRevision == receiving.expectedWorld.adapterRevision,
      receiving.selectedWorld.geometryRevision == receiving.expectedWorld.geometryRevision,
      candidate.credits == commander.credits, candidate.cargo == commander.cargo,
      candidate.flightSimulation == commander.flightSimulation,
      NativeHollowManifestKitDefinition.occupiedTonnes(in: prepared.inventory) == 0,
      acceptsHollowManifestInstalledCase(review.pin)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}
