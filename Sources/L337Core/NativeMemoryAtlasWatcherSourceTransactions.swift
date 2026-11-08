import Foundation

/// File-private live facts cannot be decoded or constructed by a board, pack or retained record.
fileprivate struct NativeMemoryAtlasWatcherQuoteFacts: Sendable {
  let source: NativeMemoryAtlasWatcherSourceRecord
  let instance: ScriptInstance
  let arrival: NativeMainStationArrivalContext
  let inventory: OwnedEquipmentInventory
  let resources: CommanderSnapshot
  let eventCursor: UInt64
  let physicalTime: Double
  let calendarSeconds: Double
  let cargoTonnes: Int
  let capacityTonnes: Int
}

struct NativeMemoryAtlasWatcherSourceQuote: Sendable {
  fileprivate let facts: NativeMemoryAtlasWatcherQuoteFacts
  var original: UUID { facts.source.original }
  var sourceRevision: UInt64 { facts.source.sourceRevision }
}

/// The record can consume this proof, but only the actual source transaction can construct it.
struct NativeMemoryAtlasWatcherSourceTransfer: Sendable {
  let before: NativeMemoryAtlasWatcherSourceRecord
  let transfer: NativeMemoryAtlasWatcherSourceRecord.Transfer

  fileprivate init(
    before: NativeMemoryAtlasWatcherSourceRecord,
    collection: NativeMemoryAtlasReferenceCollection, actual: EquipmentIssueReceipt
  ) throws {
    guard before.shapeValid, before.custody == .available, before.sourceRevision == 1,
      actual.operation == .issued, actual.command == collection.facts.issueCommand,
      actual.source == collection.facts.source,
      actual.originalItems == [before.original], actual.affectedItems == [before.original],
      actual.consumedItems.isEmpty, actual.displacements.isEmpty,
      collection.facts.issuer == before.issuer, collection.facts.original == before.original
    else { throw EquipmentIssueError.identityMismatch }
    self.before = before
    transfer = .init(beforeSourceRevision: 1, afterSourceRevision: 2, collection: collection)
  }
}

/// Only the source transaction in this file can authorize its one intermediate kernel issue.
struct NativeMemoryAtlasWatcherIssuePermit: Sendable {
  private let source: NativeMemoryAtlasWatcherSourceRecord
  private let command: UUID
  private let inventoryRevision: UInt64
  private let caseRevision: UInt64

  fileprivate init(facts: NativeMemoryAtlasWatcherQuoteFacts, command: UUID) {
    source = facts.source
    self.command = command
    inventoryRevision = facts.inventory.revision
    caseRevision = facts.instance.revision
  }

  func permits(
    _ definition: ScriptGearDefinition, fields: [String: ScriptValue], command: UUID,
    state: borrowing ScriptInstance, candidate: borrowing Commander
  ) -> Bool {
    // Read the actual borrowed values before && creates its deferred RHS closures.
    // One owned inventory projection supplies both identity and revision; no Commander copy.
    let currentSource = candidate.savedMemoryAtlasWatcherSource
    let currentInventory = candidate.equipmentInventory
    let currentCaseID = state.id
    let currentCaseRevision = state.revision
    let hasNoIssues = state.gearIssues.isEmpty
    return definition.id == source.resource && definition.name == source.name
      && definition.quantity == 1 && definition.loan && definition.mount == nil
      && definition.returnPolicy == "all" && fields == ["fit": .bool(false)]
      && command == self.command && currentCaseID == source.caseID
      && currentCaseRevision == caseRevision && hasNoIssues
      && currentSource == source
      && currentInventory?.owner == source.owner
      && currentInventory?.revision == inventoryRevision
  }
}

extension Game {
  func memoryAtlasWatcherSourceQuote() -> NativeMemoryAtlasWatcherSourceQuote? {
    guard !paused, !isMissionTrial, trialTitle == nil, scriptDurabilityAvailable,
      NativeMemoryAtlasWatcherSource.canonicalNodeInstalled,
      systemIdentity == NativeMemoryAtlasWatcherSource.world, currentSystem.name == "Reris",
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander),
      let source = commander.savedMemoryAtlasWatcherSource,
      source.custody == .available, source.sourceRevision == 1,
      let instance = commander.withReadOnlyScriptState({ $0.instances[source.caseID] }),
      instance.suspension == nil, NativeMemoryAtlasSave.prefixValid(instance),
      let state = instance.savedMemoryAtlas,
      state.collection == nil, instance.gearIssues.isEmpty,
      scriptPacks.contains(where: NativeMemoryAtlasDefinition.matches),
      let inventory = commander.equipmentInventory, inventory.owner == source.owner,
      inventory.activeHull == commander.hullInstanceID,
      inventory.revision < UInt64(Int64.max) - 1, instance.revision < UInt64(Int64.max) - 1,
      let arrival = nativeMainStationArrivalContext(for: source.station),
      acceptsNativeMainStationArrivalContext(arrival),
      arrival.receipt.station == state.acceptance.dock.station,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let used = commander.checkedCargoTonnes, used >= 0,
      used < commander.standardCargoCapacity
    else { return nil }
    let added = used.addingReportingOverflow(NativeMemoryAtlasWatcherSource.cargoTonnes)
    guard !added.overflow, added.partialValue <= commander.standardCargoCapacity else { return nil }
    // This is a read-only capacity check. Never issue an item or advance source/case/event here.
    return .init(facts: .init(
      source: source, instance: instance, arrival: arrival, inventory: inventory,
      resources: CommanderSnapshot(commander.contractQuoteResources),
      eventCursor: commander.scriptState.nextEvent,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds,
      cargoTonnes: used, capacityTonnes: commander.standardCargoCapacity))
  }

  /// Called by the original C25 Confirm candidate. GameRuntime alone publishes the whole candidate.
  mutating func collectMemoryAtlasWatcherSource(_ quote: NativeMemoryAtlasWatcherSourceQuote) throws {
    guard let current = memoryAtlasWatcherSourceQuote(),
      quote.facts.source == current.facts.source,
      quote.facts.instance == current.facts.instance,
      quote.facts.arrival == current.facts.arrival,
      quote.facts.inventory == current.facts.inventory,
      quote.facts.resources.value == current.facts.resources.value,
      quote.facts.eventCursor == current.facts.eventCursor,
      quote.facts.physicalTime == current.facts.physicalTime,
      quote.facts.calendarSeconds == current.facts.calendarSeconds,
      quote.facts.cargoTonnes == current.facts.cargoTonnes,
      quote.facts.capacityTonnes == current.facts.capacityTonnes
    else { throw EquipmentIssueError.staleObligation }
    let facts = current.facts
    var candidate = self
    var staged = commander
    var instance = facts.instance
    guard var state = instance.savedMemoryAtlas else { throw EquipmentIssueError.staleObligation }
    let command = UUID()
    let actual = try candidate.issueScriptGearWithReceipt(
      NativeMemoryAtlasWatcherSource.gear, fields: ["fit": .bool(false)], command: command,
      state: &instance, candidate: &staged,
      memoryAtlasPermit: .init(facts: facts, command: command))
    guard let actual, let inventory = staged.equipmentInventory,
      inventory.owner == facts.inventory.owner, inventory.activeHull == facts.inventory.activeHull,
      inventory.revision == facts.inventory.revision + 1,
      let original = inventory.items.first(where: { $0.id == facts.source.original }),
      inventory.items == facts.inventory.items + [original],
      original.node == facts.source.node, original.location == nil, original.component == nil,
      original.preferredSlot == nil, original.boundHull == nil,
      original.retainedLegacyState == nil, original.nativeRepairLoopCondition == nil,
      original.provenance == .missionIssue(mission: facts.source.caseID,
        resource: facts.source.resource, index: 0, packDigest: facts.source.packDigest),
      staged.savedMemoryAtlasWatcherSource == facts.source,
      staged.scriptState.nextEvent == facts.eventCursor,
      staged.flightSimulation.physicalTime == facts.physicalTime,
      staged.scriptState.calendarSeconds == facts.calendarSeconds,
      staged.credits == commander.credits, staged.cargo == commander.cargo,
      staged.checkedCargoTonnes == facts.cargoTonnes + NativeMemoryAtlasWatcherSource.cargoTonnes,
      staged.standardCargoCapacity == facts.capacityTonnes
    else { throw EquipmentIssueError.identityMismatch }
    let sequence = facts.eventCursor + 1
    let collectionFacts = NativeMemoryAtlasReferenceCollection.Facts(
      issueCommand: actual.receipt.command, source: actual.receipt.source,
      issuer: facts.source.issuer, original: original.id, carrier: facts.inventory.activeHull,
      dock: facts.arrival.receipt,
      beforeInventoryRevision: facts.inventory.revision, afterInventoryRevision: inventory.revision,
      beforeCaseRevision: facts.instance.revision, afterCaseRevision: facts.instance.revision + 1,
      eventSequence: sequence, beforeCargoTonnes: facts.cargoTonnes,
      afterCargoTonnes: facts.cargoTonnes + NativeMemoryAtlasWatcherSource.cargoTonnes,
      capacityTonnes: facts.capacityTonnes, physicalTime: facts.physicalTime,
      calendarSeconds: facts.calendarSeconds)
    let collection = try NativeMemoryAtlasReferenceCollection(
      actual: actual.receipt, facts: collectionFacts, acceptance: state.acceptance)
    let verified = try NativeMemoryAtlasWatcherSourceTransfer(
      before: facts.source, collection: collection, actual: actual.receipt)
    staged.savedMemoryAtlasWatcherSource = try facts.source.recording(verified)
    state.collection = collection
    instance.savedMemoryAtlas = state
    instance.receipts.insert(NativeMemoryAtlasDefinition.collectReceipt)
    instance.milestones.insert(1)
    instance.journal.append(NativeMemoryAtlasDefinition.collectionDialogue)
    instance.revision = collectionFacts.afterCaseRevision
    instance.acknowledge(sequence)
    staged.scriptState.nextEvent = sequence
    staged.scriptState.instances[instance.id] = instance
    guard NativeMemoryAtlasWatcherSourceSave.validateClaims(staged),
      staged.equipmentStateValid, staged.nativePeople == commander.nativePeople,
      staged.nativeStations == commander.nativeStations,
      staged.flightSimulation == commander.flightSimulation,
      staged.scriptState.savedClueJournal == commander.scriptState.savedClueJournal
    else { throw EquipmentIssueError.invalidBudget }
    candidate.commander = staged
    self = candidate
  }
}
