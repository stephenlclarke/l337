import Foundation

/// Current original-property projection, never a second item or a saved live permission.
struct NativeUnderTowReferenceBinding: Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let source: EquipmentIssueSource
  let issueCommand: UUID
  let original: UUID
  fileprivate init(mission: UUID, inventory: OwnedEquipmentInventory,
    collection: NativeUnderTowReferenceCollection)
  {
    self.mission = mission
    owner = inventory.owner
    carrier = inventory.activeHull
    inventoryRevision = inventory.revision
    source = collection.facts.source
    issueCommand = collection.facts.issueCommand
    original = collection.facts.original
  }
}

enum NativeUnderTowCustody {
  static func resolve(instance: ScriptInstance, commander: borrowing Commander) throws
    -> NativeUnderTowReferenceBinding
  {
    guard commander.withReadOnlyScriptState({ $0.instances[instance.id] }) == instance,
      NativeUnderTowSave.prefixValid(instance), instance.outcome == .active,
      instance.suspension == nil, let state = instance.savedUnderTow,
      let collection = state.collection, let inventory = commander.equipmentInventory,
      inventory.owner == state.acceptance.owner,
      inventory.activeHull == commander.hullInstanceID,
      inventory.revision >= collection.facts.afterInventoryRevision,
      let issue = instance.gearIssues[NativeUnderTowReferenceDefinition.resource],
      issue.valid(for: instance), issue.savedGearVersion == 2, issue.status == .issued,
      issue.kind == .module(NativeUnderTowReferenceDefinition.name), issue.loan,
      !issue.returnRemaining, issue.source == collection.facts.source,
      issue.items == [collection.facts.original], issue.consumed.isEmpty,
      issue.displacements?.isEmpty == true, issue.legacyMissingItems?.isEmpty ?? true,
      let obligation = issue.obligation,
      (try? commander.equipmentIssueObligations())?.contains(obligation) == true,
      let item = inventory.items.first(where: { $0.id == collection.facts.original }),
      inventory.items.filter({ $0.node == NativeUnderTowReferenceDefinition.node }) == [item],
      item.node == NativeUnderTowReferenceDefinition.node, item.location == nil,
      item.component == nil, item.preferredSlot == nil, item.boundHull == nil,
      item.retainedLegacyState == nil, item.nativeRepairLoopCondition == nil,
      item.provenance == .missionIssue(mission: instance.id,
        resource: NativeUnderTowReferenceDefinition.resource, index: 0, packDigest: instance.digest),
      let tonnes = commander.checkedCargoTonnes,
      tonnes >= NativeUnderTowReferenceDefinition.cargoTonnes,
      tonnes <= commander.standardCargoCapacity
    else { throw EquipmentIssueError.staleObligation }
    return .init(mission: instance.id, inventory: inventory, collection: collection)
  }
}
