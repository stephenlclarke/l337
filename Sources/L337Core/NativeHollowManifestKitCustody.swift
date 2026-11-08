import Foundation

/// Fresh original-loan projection. It owns no equipment and cannot be decoded into live custody.
struct NativeHollowManifestKitBinding: Equatable, Sendable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let source: EquipmentIssueSource
  let issueCommand: UUID
  let serial: UUID

  fileprivate init(
    mission: UUID, owner: UUID, carrier: UUID, inventoryRevision: UInt64,
    source: EquipmentIssueSource, issueCommand: UUID, serial: UUID
  ) {
    self.mission = mission
    self.owner = owner
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
    self.source = source
    self.issueCommand = issueCommand
    self.serial = serial
  }
}

enum NativeHollowManifestKitCustody {
  static func resolve(instance: ScriptInstance, commander: borrowing Commander) throws
    -> NativeHollowManifestKitBinding
  {
    guard commander.withReadOnlyScriptState({ $0.instances[instance.id] }) == instance,
      instance.outcome == .active, instance.suspension == nil,
      NativeHollowManifestCommission.prefixValid(instance),
      let state = instance.savedHollowManifest, let lab = state.laboratory,
      let inventory = commander.equipmentInventory, inventory.owner == state.birth.input.owner,
      let issue = instance.gearIssues[NativeHollowManifestKitDefinition.resource],
      issue.status == .issued, issue.consumed.isEmpty, issue.valid(for: instance),
      let obligation = issue.obligation,
      (try? commander.equipmentIssueObligations())?.contains(obligation) == true,
      issue.items == [lab.facts.originalKit], obligation.source == lab.facts.issueSource,
      let item = inventory.items.first(where: { $0.id == lab.facts.originalKit }),
      item.node == NativeHollowManifestKitDefinition.node, item.location == nil,
      item.component == nil, item.nativeRepairLoopCondition == nil,
      item.provenance == .missionIssue(
        mission: instance.id, resource: NativeHollowManifestKitDefinition.resource,
        index: 0, packDigest: instance.digest)
    else { throw EquipmentIssueError.staleObligation }
    return .init(
      mission: instance.id, owner: inventory.owner, carrier: inventory.activeHull,
      inventoryRevision: inventory.revision, source: obligation.source,
      issueCommand: lab.facts.issueCommand, serial: item.id)
  }
}
