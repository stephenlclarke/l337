import Foundation

extension Game {
  func hollowManifestContentUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeHollowManifestCommission.matches(pack) else {
      return "Restore the current original Hollow Manifest source."
    }
    guard let instance = hollowManifestMission,
      instance.definition == NativeHollowManifestCommission.stateID,
      instance.digest == pack.digest, instance.savedHollowManifest != nil,
      NativeHollowManifestSave.validateClaims(commander)
    else { return "Use Nia Toren's actual commission review at Narargan in Galaxy 2." }
    return nil
  }

  var hollowManifestPageFacts: [String] {
    guard let action = contractBoard.selected?.hollowManifest else { return [] }
    let quote = contractBoard.hollowManifestQuote
    let source = hollowManifestMission
    return [
      action.key, quote?.reviewToken.uuidString ?? "unreviewed",
      quote?.epoch.uuidString ?? "no-runtime", quote?.owner?.uuidString ?? "no-owner",
      quote?.carrier?.uuidString ?? "no-carrier",
      quote?.inventoryRevision.map(String.init) ?? "no-inventory",
      quote?.digest ?? "no-source", source?.id.uuidString ?? "unaccepted",
      source.map { String($0.revision) } ?? "unaccepted",
      source?.savedHollowManifest.map { String($0.nextSourceSequence) } ?? "no-source-history",
      quote?.issues.joined(separator: "\n") ?? "unreviewed",
    ]
  }
}

enum NativeHollowManifestLeafValidation {
  /// Structural predicate only. Root must also invoke the complete current commander claims.
  static func valid(_ instance: borrowing ScriptInstance) -> Bool {
    guard NativeHollowManifestCommission.marked(instance) else { return true }
    return NativeHollowManifestCommission.prefixValid(instance)
  }
}
