import Foundation

extension Commander {
  /// Return one small COW instance handle without materializing the whole engine.
  func isolationInstance(_ id: UUID) -> ScriptInstance? {
    withReadOnlyScriptState { $0.instances[id] }
  }

  func isolationParentInstance() -> ScriptInstance? {
    withReadOnlyScriptState { engine in
      engine.instances.values.first(where: NativeIsolationWorkParent.marked)
    }
  }
}

extension Game {
  var isolationWorkPageFacts: [String] {
    guard let action = contractBoard.selected?.isolationWorkParent else { return [] }
    let quote = contractBoard.isolationWorkParentQuote
    return [
      action.key,
      quote?.reviewToken.uuidString ?? "unreviewed",
      quote?.epoch.uuidString ?? "unavailable-runtime",
      quote?.owner?.uuidString ?? "unavailable-owner",
      quote?.carrier?.uuidString ?? "unavailable-carrier",
      quote?.inventoryRevision.map(String.init) ?? "unavailable-inventory",
      quote?.parentRevision.map(String.init) ?? "unaccepted",
      quote?.sourceRevision.map(String.init) ?? "unavailable-source",
      quote?.issues.joined(separator: "\n") ?? "unreviewed",
    ]
  }
}
