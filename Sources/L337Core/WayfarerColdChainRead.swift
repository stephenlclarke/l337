import Foundation

struct WayfarerColdChainPackHeader {
  let digest: String
  let title: String
  let definition: WayfarerColdChainDefinition
}

struct WayfarerColdChainRowHeader {
  let instanceID: UUID
  let row: WayfarerColdChainBoardRow
  let title: String
}

extension Game {
  /// Only the first installed digest is considered, including a refused first match.
  /// Both the pack and its storage remain borrowed for this synchronous callback.
  @inline(never)
  func withWayfarerInstalledPack<Result>(
    digest: String, _ read: (borrowing ScriptPack) throws -> Result
  ) rethrows -> Result? {
    try scriptPacks.withUnsafeBufferPointer { storage in
      for index in storage.indices {
        let result: Result? = try Self.withBorrowedPointee(storage.baseAddress! + index) { pack in
          guard pack.digest == digest else { return nil }
          return .some(try read(pack))
        }
        if let result { return .some(result) }
      }
      return nil
    }
  }

  @inline(never)
  func wayfarerColdChainPackHeaders() -> [WayfarerColdChainPackHeader] {
    scriptPacks.withUnsafeBufferPointer { storage in
      var headers: [WayfarerColdChainPackHeader] = []
      for index in storage.indices {
        Self.withBorrowedPointee(storage.baseAddress! + index) { pack in
          guard let definition = pack.manifest.coldChain else { return }
          headers.append(
            .init(digest: pack.digest, title: pack.manifest.mission.title, definition: definition))
        }
      }
      return headers
    }
  }

  @inline(never)
  func wayfarerColdChainBoardDefinition(_ digest: String) -> WayfarerColdChainDefinition? {
    withWayfarerInstalledPack(digest: digest) { pack -> WayfarerColdChainDefinition? in
      guard let terms = pack.manifest.coldChain, scriptUnavailable(pack) == nil else { return nil }
      return terms
    } ?? nil
  }

  @inline(never)
  func wayfarerColdChainProviderMatches(_ digest: String, definition: WayfarerColdChainDefinition)
    -> Bool
  {
    withWayfarerInstalledPack(digest: digest) { pack in
      pack.manifest.coldChain == definition && scriptUnavailable(pack) == nil
    } == true
  }

  @inline(never)
  func wayfarerColdChainPickupAction(_ terms: WayfarerColdChainDefinition)
    -> WayfarerColdChainBoardAction
  {
    let source = withReadOnlyCommander { $0.equipmentOwnerID }.map {
      WayfarerColdChainStockSource.identity(owner: $0, terms: terms).uuidString
    }
    guard let source else { return .unavailable }
    return withReadOnlyScriptState { engine in
      guard let stock = engine.savedWayfarerColdChainStock?.sources[source],
        let unit = stock.units.values.filter({ $0.status == .available })
          .sorted(by: { $0.id.uuidString < $1.id.uuidString }).first
      else { return .unavailable }
      return .pickup(source: source, unit: unit.id)
    }
  }

  @inline(never)
  func wayfarerColdChainActiveRowHeaders() -> [WayfarerColdChainRowHeader] {
    withReadOnlyScriptState { engine in
      let headers: [WayfarerColdChainRowHeader] = engine.instances.values.compactMap { state in
        guard state.outcome == .active, let custody = state.savedWayfarerColdChain else {
          return nil
        }
        let action: WayfarerColdChainBoardAction
        if state.suspension != nil,
          WayfarerColdChainSave.pendingExpiry(state, engine: engine) != nil
        {
          action = .retryExpiry(state.id)
        } else {
          action = custody.objective == nil ? .objective(state.id) : .receive(state.id)
        }
        return .init(
          instanceID: state.id, row: .init(digest: state.digest, action: action),
          title: (custody.definition.isSeedTransfer
            ? "Seed-bank consignment: " : "Cold-chain sample: ")
            + (custody.objective == nil ? "verify arrival" : "receive and pay"))
      }
      // Sort the same instance identities after projection; no complete instance array
      // remains on the stack when the caller enters its full row review.
      return headers.sorted {
        $0.instanceID.uuidString < $1.instanceID.uuidString
      }
    }
  }

  @inline(never)
  func wayfarerColdChainReviewCustody(_ id: UUID, digest: String) -> WayfarerColdChainCustody? {
    withReadOnlyScriptState { engine in
      guard let state = engine.instances[id], state.digest == digest,
        state.outcome == .active, state.suspension == nil
      else { return nil }
      return state.savedWayfarerColdChain
    }
  }

  @inline(never)
  func wayfarerColdChainPickupFits(_ tonnes: Int) -> Bool {
    withReadOnlyCommander { commander in
      guard let occupied = commander.checkedCargoTonnes,
        tonnes <= commander.standardCargoCapacity,
        occupied <= commander.standardCargoCapacity - tonnes,
        commander.withReadOnlyScriptState({ $0.instances.count }) < 128
      else { return false }
      return true
    }
  }

  @inline(never)
  func wayfarerColdChainHasPendingExpiry(_ id: UUID, digest: String) -> Bool {
    withReadOnlyScriptState { engine in
      guard let state = engine.instances[id], state.digest == digest,
        state.suspension != nil
      else { return false }
      return WayfarerColdChainSave.pendingExpiry(state, engine: engine) != nil
    }
  }

  @inline(never)
  func wayfarerColdChainQuoteSource(_ sourceID: String) -> WayfarerColdChainStockSource? {
    withReadOnlyScriptState { engine in
      guard let ledger = engine.savedWayfarerColdChainStock,
        ledger.owner == withReadOnlyCommander({ $0.equipmentOwnerID })
      else { return nil }
      return ledger.sources[sourceID]
    }
  }
}
