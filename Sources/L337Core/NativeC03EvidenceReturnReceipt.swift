import Foundation

/// Actual data/kit intake history. Native receiving and equipment kernels, not these saved
/// facts, must supply original custody and actual acceptance before receipt construction.
struct NativeC03EvidenceReturnReceipt: Codable, Equatable, Sendable {
  struct Facts: Codable, Equatable, Sendable {
    let mission: UUID
    let owner: UUID
    let remedy: UUID
    let recipient: UUID
    let receivingOperation: UUID
    let dock: NativeMainStationDockReceipt
    let register: UUID
    let registerHash: String
    let registerTransfer: UUID
    let crewLog: UUID
    let crewLogHash: String
    let crewLogTransfer: UUID
    let originalKit: UUID
    let itemHash: String
    let issueCommand: UUID
    let equipmentCommand: UUID
    let equipmentSource: EquipmentIssueSource
    let carrier: UUID
    let beforeInventoryRevision: UInt64
    let afterInventoryRevision: UInt64
    let beforeCaseRevision: UInt64
    let afterCaseRevision: UInt64
    let sequence: UInt64
    let physicalTime: Double
    let calendarSeconds: Double
    let epoch: UUID
  }
  static let receipt = "hollow-manifest-evidence-kit-returned"
  static let authoredReceipt = "l337.hollow-manifest/return-equipment"
  static let dialogue =
    "TOREN: The kit is back with the laboratory. The original seal and custody register will remain available to the crews."
  let operation: UUID
  let facts: Facts

  init(receiving: NativeC03EvidenceIntakeReceipt, equipment: EquipmentIssueReceipt,
    facts: Facts) throws
  {
    guard receiving.operation == facts.receivingOperation, receiving.recipient == facts.recipient,
      receiving.preparation.equipmentReceipt == equipment,
      receiving.preparation.review.pin.owner == facts.owner,
      receiving.preparation.review.pin.missionID == facts.mission,
      receiving.preparation.review.log.kit.serial == facts.originalKit,
      receiving.preparation.review.log.kit.issueCommand == facts.issueCommand,
      receiving.preparation.review.log.kit.carrier == facts.carrier,
      receiving.preparation.review.log.kit.inventoryRevision == facts.beforeInventoryRevision,
      receiving.preparation.inventory.revision == facts.afterInventoryRevision,
      receiving.preparation.flight.physicalTime == facts.physicalTime,
      receiving.preparation.calendar == facts.calendarSeconds,
      receiving.preparation.review.epoch == facts.epoch,
      receiving.preparation.review.arrival.receipt == facts.dock,
      receiving.preparation.review.register.contents.serial == facts.register,
      receiving.preparation.review.log.contents.serial == facts.crewLog,
      receiving.preparation.review.register.transfer == facts.registerTransfer,
      receiving.preparation.review.log.transfer == facts.crewLogTransfer,
      facts.registerHash == (try? NativeFlightReception.hash(receiving.preparation.review.register.contents)),
      facts.crewLogHash == (try? NativeFlightReception.hash(receiving.preparation.review.log.contents)),
      facts.itemHash == (try? NativeFlightReception.hash(receiving.preparation.review.item)),
      equipment.command == facts.equipmentCommand, equipment.source == facts.equipmentSource,
      equipment.operation == .returned, equipment.originalItems == [facts.originalKit],
      equipment.affectedItems == [facts.originalKit], equipment.consumedItems.isEmpty,
      equipment.displacements.isEmpty else { throw EquipmentIssueError.identityMismatch }
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func identity(_ facts: Facts) throws -> UUID {
    guard facts.equipmentSource.mission == facts.mission,
      facts.equipmentSource.resource == NativeHollowManifestKitDefinition.resource,
      facts.equipmentSource.packDigest == NativeHollowManifestCommission.digest
    else { throw SaveError.invalidCommander }
    for digest in [facts.registerHash, facts.crewLogHash, facts.itemHash] {
      guard digest.utf8.count == 64, ScriptCompletionReceipt.validDigest(digest)
      else { throw SaveError.invalidCommander }
    }
    return ScriptIdentity.uuid("c03-original-evidence-kit-return-v1:\(try NativeFlightReception.hash(facts))")
  }

  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    let f = facts
    guard let file = state.caseFile, let remedy = file.remedy,
      remedy.valid(in: state), operation == (try? Self.identity(f)),
      f.mission == state.birth.input.mission, f.owner == state.birth.input.owner,
      f.remedy == remedy.operation, f.recipient == remedy.facts.recipient,
      f.recipient == state.laboratory?.facts.issuer,
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestKitDefinition.returnLocation,
      f.register == file.ledger.facts.register, f.registerHash == file.ledger.facts.registerHash,
      f.registerTransfer == file.ledger.facts.registerTransfer,
      f.crewLog == file.ledger.facts.crewLog, f.crewLogHash == file.ledger.facts.crewLogHash,
      f.crewLogTransfer == file.ledger.facts.crewLogTransfer,
      f.originalKit == remedy.facts.originalKit, f.issueCommand == remedy.facts.issueCommand,
      f.equipmentSource == state.laboratory?.facts.issueSource,
      f.beforeInventoryRevision >= remedy.facts.inventoryRevision,
      f.beforeInventoryRevision < UInt64(Int64.max) - 1,
      f.afterInventoryRevision == f.beforeInventoryRevision + 1,
      f.beforeCaseRevision >= remedy.facts.afterCaseRevision,
      f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1,
      f.sequence > remedy.facts.sequence, f.sequence < state.nextSourceSequence,
      f.physicalTime.isFinite, f.physicalTime >= remedy.facts.physicalTime, f.physicalTime <= 1e12,
      f.calendarSeconds.isFinite, f.calendarSeconds >= remedy.facts.calendarSeconds,
      f.calendarSeconds >= f.dock.calendarSeconds, f.calendarSeconds <= 1e12,
      state.custodyRegister?.holder(in: state) == .institutionalRecipient(f.recipient)
    else { return false }
    return true
  }

  /// Current native station/recipient source must reciprocally validate its actual device,
  /// original data records and loaded physical stock. IDs/hashes alone are not intake proof.
  func valid(commander: borrowing Commander) -> Bool {
    let f = facts
    guard let instance = commander.scriptState.instances[f.mission],
      let state = instance.savedHollowManifest, valid(in: state),
      instance.revision >= f.afterCaseRevision, let world = commander.nativeStations,
      world.mainStations.contains(f.dock.station), f.dock.sequence < world.nextMainDockSequence,
      f.dock.actor.visit <= commander.flightSimulation.visit,
      let inventory = commander.equipmentInventory, inventory.owner == f.owner,
      inventory.revision >= f.afterInventoryRevision,
      !inventory.items.contains(where: { $0.id == f.originalKit }),
      let issue = instance.gearIssues[NativeHollowManifestKitDefinition.resource],
      issue.status == .returned, issue.items == [f.originalKit], issue.consumed.isEmpty,
      issue.source == f.equipmentSource,
      let custody = commander.nativePeople, let source = custody.hollowManifestCrew,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      source.crewLogHolder == .institutionalRecipient(f.recipient),
      source.registration.crewLog.serial == f.crewLog,
      let access = source.crewLogAccess, access.operation == f.crewLogTransfer,
      access.facts.originalKit == f.originalKit,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: f.calendarSeconds,
        current: commander.scriptState.calendarSeconds)
    else { return false }
    return true
  }
}
