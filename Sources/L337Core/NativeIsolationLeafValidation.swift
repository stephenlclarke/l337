import Foundation

enum NativeIsolationLeafValidation {
  /// Structural validation only. Live permission, equipment custody, real native
  /// work and settlement joins remain separate commander-level validators.
  static func valid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeIsolationWorkParent.marked(instance) {
      guard instance.definition == NativeIsolationWorkParent.stateID,
        instance.version == NativeIsolationWorkParent.version,
        instance.digest == NativeIsolationWorkParent.digest,
        let parent = instance.savedIsolationWorkParent, parent.parent == instance.id,
        parent.digest == instance.digest,
        parent.source == NativeIsolationWorkParent.source(owner: parent.owner),
        parent.issuer == NativeIsolationProgrammerDefinition.issuer(owner: parent.owner),
        parent.issue.original == NativeIsolationProgrammerDefinition.serial(parent: instance.id),
        parent.issue.source
          == EquipmentIssueSource(
            mission: instance.id, resource: NativeIsolationProgrammerDefinition.resource,
            packDigest: instance.digest),
        parent.acceptance.valid, parent.acceptance.commanderOwner == parent.owner,
        parent.acceptance.station.system == NativeIsolationWorkSource.issuerLocation,
        parent.sequence > 0, parent.sequence < UInt64(Int64.max),
        parent.inventoryRevision < UInt64(Int64.max),
        parent.physicalTime.isFinite, (0...1e12).contains(parent.physicalTime),
        ScriptCompletionReceipt.validDigest(parent.terms), instance.payloads.isEmpty
      else { return false }
      if let terminal = parent.terminal, !terminal.shapeValid(proof: parent) { return false }
    }
    if NativeIsolationWorkPack.marked(instance) {
      guard instance.definition == NativeIsolationWorkPack.stateID,
        instance.version == NativeIsolationWorkPack.version,
        instance.digest == NativeIsolationWorkPack.digest,
        let source = instance.savedIsolationWork, source.shapeValid, source.job == instance.id,
        instance.payloads.isEmpty
      else { return false }
    }
    return true
  }
}
