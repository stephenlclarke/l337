import Foundation

/// Current original-property projection, never a second item or a saved live permission.
struct NativeAssemblyReferenceBinding: Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let source: EquipmentIssueSource
  let issueCommand: UUID
  let original: UUID
  fileprivate init(mission: UUID, inventory: OwnedEquipmentInventory,
    collection: NativeAssemblyReferenceCollection)
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

enum NativeAssemblyOfOrbitsCustody {
  static func resolve(instance: ScriptInstance, commander: borrowing Commander) throws
    -> NativeAssemblyReferenceBinding
  {
    guard commander.withReadOnlyScriptState({ $0.instances[instance.id] }) == instance,
      NativeAssemblyOfOrbitsSave.prefixValid(instance), instance.outcome == .active,
      instance.suspension == nil, let state = instance.savedAssemblyOfOrbits,
      let collection = state.collection, let inventory = commander.equipmentInventory,
      inventory.owner == state.acceptance.owner,
      inventory.activeHull == commander.hullInstanceID,
      inventory.revision >= collection.facts.afterInventoryRevision,
      let issue = instance.gearIssues[NativeAssemblyReferenceDefinition.resource],
      issue.valid(for: instance), issue.savedGearVersion == 2, issue.status == .issued,
      issue.kind == .module(NativeAssemblyReferenceDefinition.name), issue.loan,
      !issue.returnRemaining, issue.source == collection.facts.source,
      issue.items == [collection.facts.original], issue.consumed.isEmpty,
      issue.displacements?.isEmpty == true, issue.legacyMissingItems?.isEmpty ?? true,
      let obligation = issue.obligation,
      (try? commander.equipmentIssueObligations())?.contains(obligation) == true,
      let item = inventory.items.first(where: { $0.id == collection.facts.original }),
      inventory.items.filter({ $0.node == NativeAssemblyReferenceDefinition.node }) == [item],
      item.node == NativeAssemblyReferenceDefinition.node, item.location == nil,
      item.component == nil, item.preferredSlot == nil, item.boundHull == nil,
      item.retainedLegacyState == nil, item.nativeRepairLoopCondition == nil,
      item.provenance == .missionIssue(mission: instance.id,
        resource: NativeAssemblyReferenceDefinition.resource, index: 0, packDigest: instance.digest),
      let tonnes = commander.checkedCargoTonnes,
      tonnes >= NativeAssemblyReferenceDefinition.cargoTonnes,
      tonnes <= commander.standardCargoCapacity
    else { throw EquipmentIssueError.staleObligation }
    return .init(mission: instance.id, inventory: inventory, collection: collection)
  }
}
