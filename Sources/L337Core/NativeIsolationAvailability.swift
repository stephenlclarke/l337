import Foundation

enum NativeIsolationAdmission {
  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == NativeIsolationWorkParent.stateID
      || pack.digest == NativeIsolationWorkParent.digest
      || pack.manifest.stateID == NativeIsolationWorkPack.stateID
      || pack.digest == NativeIsolationWorkPack.digest
  }
}

extension Game {
  /// Availability rejoins real existing state. It never creates the native permission.
  func isolationContentUnavailable(_ pack: borrowing ScriptPack) -> String? {
    if pack.manifest.stateID == NativeIsolationWorkParent.stateID
      || pack.digest == NativeIsolationWorkParent.digest
    {
      guard NativeIsolationWorkParent.matches(pack) else {
        return "Restore the approved original Lerr isolation contract."
      }
      guard let parent = isolationWorkParentMission,
        parent.definition == NativeIsolationWorkParent.stateID,
        parent.digest == pack.digest, parent.savedIsolationWorkParent != nil
      else { return "Use Station Contracts at Lerr's actual Avenor berth to review the loan." }
      return nil
    }
    guard NativeIsolationWorkPack.matches(pack) else {
      return "Restore the approved original Renas isolation source."
    }
    guard let child = isolationWorkChild, child.definition == NativeIsolationWorkPack.stateID,
      child.digest == pack.digest, let source = child.savedIsolationWork,
      let parent = commander.isolationInstance(source.permission.parent),
      parent.outcome == .active, parent.suspension == nil,
      let authority = try? NativeIsolationWorkParentAuthority.resolve(
        parentID: parent.id, commander: commander).authority,
      let programmer = try? authority.programmer(in: commander),
      source.permission.matches(authority, programmer: programmer.serial)
    else { return "The original held programmer and actual Lerr authorization are required." }
    return nil
  }
}
