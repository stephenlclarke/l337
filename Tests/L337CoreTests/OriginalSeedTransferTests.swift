import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

private let originalSeedTransferFamily = "l337.wayfarer-service/seed-transfer"

private struct OriginalSeedTransferBoardFixture {
  let native: WayfarerSeedTransferNativeFixture
  init() throws { native = try WayfarerSeedTransferNativeFixture() }

  func review(
    _ runtime: GameRuntime,
    request: String, publication: String? = nil, file: StaticString = #fileID, line: UInt = #line,
    matching predicate: (WayfarerColdChainBoardAction) -> Bool
  ) async throws -> WayfarerColdChainBoardReview {
    let beforeOpen = seedBoardOpenEvidence(await runtime.snapshot())
    await runtime.key("contracts-open")
    let index: Int
    let selection: Int
    do {
      let game = await runtime.snapshot()
      let board = game.contractBoard
      let match = board.rows.firstIndex {
        $0.coldChain?.digest == native.pack.digest
          && $0.coldChain.map { predicate($0.action) } == true
      }
      index = try #require(
        match,
        Comment(
          rawValue: match == nil
            ? seedBoardLookupEvidence(
              request: request, file: file, line: line, digest: native.pack.digest,
              beforeOpen: beforeOpen, game: game, publication: publication)
            : ""))
      selection = board.selection
    }
    // Release the lookup snapshot before subsequent native input, as in the original helper.
    for _ in 0..<abs(index - selection) {
      await runtime.key(index < selection ? "up" : "down")
    }
    await runtime.key("return")
    let game = await runtime.snapshot()
    try #require(game.contractBoard.detail && game.contractBoard.action == .back)
    return try #require(game.contractBoard.coldChainQuote)
  }

  func confirm(_ runtime: GameRuntime) async {
    await runtime.key("right")
    await runtime.key("return")
  }

  func pickup(
    _ runtime: GameRuntime, lot: String, file: StaticString = #fileID, line: UInt = #line
  ) async throws -> UUID {
    let quote = try await review(runtime, request: "pickup lot=\(lot)", file: file, line: line) {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    let offer = try #require(quote.offer)
    await confirm(runtime)
    let game = await runtime.snapshot()
    let id = try #require(
      game.commander.scriptState.instances.values.first {
        $0.savedWayfarerColdChain?.unit == offer.stockUnit
          && $0.definition == originalSeedTransferFamily
      }?.id)
    try #require(
      game.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer != nil)
    return id
  }
}

/// Failure-only formatting limits. No live mission state or ordinary board matching is changed.
private enum SeedBoardEvidenceLimit {
  static let scalarBytes = 256
  static let dockBytes = 2048
  static let rows = 32
  static let instances = 4
  static let sources = 4
  static let units = 8
  static let packs = 16
  static let payloads = 8
  static let custodyBytes = 16384
  static let custodyNodes = 2048
  static let custodyDepth = 16
  static let custodyChildren = 128
  static let custodyScalarBytes = 512
  static let custodyStringBytes = 16384
  static let outputBytes = 131072
}

private func seedEvidencePrefix(_ value: String, limit: Int) -> String {
  guard value.utf8.count > limit else { return value }
  var retained = ""
  var bytes = 0
  for scalar in value.unicodeScalars {
    let next = String(scalar)
    guard bytes + next.utf8.count <= limit else { break }
    retained += next
    bytes += next.utf8.count
  }
  return retained
}

private func seedEvidenceText(_ value: String, limit: Int = SeedBoardEvidenceLimit.scalarBytes)
  -> String
{
  let total = value.utf8.count
  guard total > limit else { return value }
  let retained = seedEvidencePrefix(value, limit: limit)
  return retained
    + " [truncated totalUTF8Bytes=\(total) retainedUTF8Bytes=\(retained.utf8.count) limit=\(limit)]"
}

private struct SeedBoardEvidenceSection {
  let total: Int
  var records: [[String: Any]]
  var value: [String: Any] {
    [
      "total": total, "retained": records.count, "truncated": records.count < total,
      "records": records,
    ]
  }
}

/// The closed custody schema is inspected before JSONEncoder is allowed to traverse it.
/// Limit every stored string/collection, traversal depth and total nodes; never encode an
/// oversized leaf first and then rely on cutting the log. UUID is a fixed-size scalar.
private func seedCustodyEvidence(_ custody: WayfarerColdChainCustody) -> [String: Any] {
  var visited = 0
  var stringBytes = 0
  func fits(_ value: Any, depth: Int) -> Bool {
    guard depth <= SeedBoardEvidenceLimit.custodyDepth,
      visited < SeedBoardEvidenceLimit.custodyNodes
    else { return false }
    visited += 1
    if let text = value as? String {
      let count = text.utf8.count
      guard count <= SeedBoardEvidenceLimit.custodyScalarBytes,
        stringBytes <= SeedBoardEvidenceLimit.custodyStringBytes - count
      else { return false }
      stringBytes += count
      return true
    }
    if value is UUID { return true }
    let mirror = Mirror(reflecting: value)
    guard mirror.children.count <= SeedBoardEvidenceLimit.custodyChildren else { return false }
    for child in mirror.children {
      guard fits(child.value, depth: depth + 1) else { return false }
    }
    return true
  }
  let permitted = fits(custody, depth: 0)
  var result: [String: Any] = [
    "encodingSkipped": !permitted, "preflightComplete": permitted, "visitedNodes": visited,
    "nodeLimit": SeedBoardEvidenceLimit.custodyNodes,
    "depthLimit": SeedBoardEvidenceLimit.custodyDepth,
    "childrenLimit": SeedBoardEvidenceLimit.custodyChildren,
    "scalarUTF8Limit": SeedBoardEvidenceLimit.custodyScalarBytes,
    "visitedStringUTF8Bytes": stringBytes,
    "totalStringUTF8Limit": SeedBoardEvidenceLimit.custodyStringBytes,
    "encodedUTF8Limit": SeedBoardEvidenceLimit.custodyBytes,
  ]
  guard permitted else {
    result["truncated"] = true
    result["reason"] =
      "custody input exceeds traversal/string/collection limit; full encoded size unknown"
    return result
  }
  do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let bytes = try encoder.encode(custody)
    let kept = seedEvidencePrefix(
      String(decoding: bytes, as: UTF8.self), limit: SeedBoardEvidenceLimit.custodyBytes)
    result["totalEncodedBytes"] = bytes.count
    result["retainedEncodedBytes"] = kept.utf8.count
    result["truncated"] = bytes.count > kept.utf8.count
    result["jsonIsPartial"] = bytes.count > kept.utf8.count
    result["json"] = kept
  } catch {
    result["truncated"] = true
    result["error"] = seedEvidenceText(String(describing: error))
  }
  return result
}

/// Assertion context only. Read retained values and existing read-only UI/dock getters.
private func seedBoardOpenEvidence(_ game: borrowing Game) -> [String: String] {
  [
    "screen": seedEvidenceText(String(describing: game.screen)), "paused": String(game.paused),
    "docked": String(game.docked), "mainStation": String(game.dockedAtMainStation),
    "nativeStationBoardContext": String(game.nativeStationBoardContext != nil),
    "nativeUtilityServiceContext": String(game.nativeUtilityServiceContext != nil),
    "showroomTrading": String(game.showroom.trading), "message": seedEvidenceText(game.message),
    "galaxy": String(game.commander.galaxy), "system": String(game.commander.system),
    "actualMainDockCurrent": String(game.nativeMainStationDockEvidenceIsCurrent),
    "mainDock": seedEvidenceText(
      String(describing: game.commander.nativeStations?.currentMainDock),
      limit: SeedBoardEvidenceLimit.dockBytes),
    "selection": String(game.contractBoard.selection), "detail": String(game.contractBoard.detail),
    "boardAction": seedEvidenceText(String(describing: game.contractBoard.action)),
    "rowCount": String(game.contractBoard.rows.count),
  ]
}

private func seedBoardLookupEvidence(
  request: String, file: StaticString, line: UInt, digest: String,
  beforeOpen: [String: String], game: borrowing Game, publication: String?
) -> String {
  let rows = SeedBoardEvidenceSection(
    total: game.contractBoard.rows.count,
    records: game.contractBoard.rows.prefix(SeedBoardEvidenceLimit.rows).enumerated().map {
      index, row in
      [
        "index": String(index), "key": seedEvidenceText(row.key),
        "title": seedEvidenceText(row.title),
        "reason": seedEvidenceText(row.reason ?? "none"),
        "digest": seedEvidenceText(row.coldChain?.digest ?? "none"),
        "action": seedEvidenceText(row.coldChain.map { String(describing: $0.action) } ?? "none"),
      ]
    })
  let instances: SeedBoardEvidenceSection = game.withReadOnlyScriptState { engine in
    let states = engine.instances.values.filter {
      $0.definition == originalSeedTransferFamily
        || $0.savedWayfarerColdChain?.definition.isSeedTransfer == true
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    return .init(
      total: states.count,
      records: states.prefix(SeedBoardEvidenceLimit.instances).map { state in
        let keys = state.payloads.keys.sorted()
        let payloads = SeedBoardEvidenceSection(
          total: keys.count,
          records: keys.prefix(SeedBoardEvidenceLimit.payloads).map {
            ["key": seedEvidenceText($0), "tonnes": String(state.payloads[$0] ?? 0)]
          })
        return [
          "instance": state.id.uuidString, "digest": seedEvidenceText(state.digest),
          "definition": seedEvidenceText(state.definition),
          "outcome": String(describing: state.outcome), "revision": String(state.revision),
          "suspension": seedEvidenceText(state.suspension ?? "none"),
          "custody": state.savedWayfarerColdChain.map(seedCustodyEvidence) ?? ["notRetained": true],
          "payloads": payloads.value,
          "completionSequence": state.completionReceipt.map { String($0.sequence) } ?? "none",
          "flightSeconds": String(engine.flightSeconds),
        ]
      })
  }
  let stocks: SeedBoardEvidenceSection = game.withReadOnlyScriptState { engine in
    let sources =
      (engine.savedWayfarerColdChainStock?.sources.values.filter {
        $0.digest == digest || $0.definition.isSeedTransfer
      } ?? []).sorted { $0.identity.uuidString < $1.identity.uuidString }
    return .init(
      total: sources.count,
      records: sources.prefix(SeedBoardEvidenceLimit.sources).map { source in
        let units = source.units.values.sorted { $0.id.uuidString < $1.id.uuidString }
        return [
          "source": source.identity.uuidString, "digest": seedEvidenceText(source.digest),
          "units": SeedBoardEvidenceSection(
            total: units.count,
            records: units.prefix(SeedBoardEvidenceLimit.units).map {
              [
                "unit": $0.id.uuidString, "status": $0.status.rawValue,
                "instance": $0.instance?.uuidString ?? "none",
              ]
            }
          ).value,
        ]
      })
  }
  let installed = SeedBoardEvidenceSection(
    total: game.scriptPacks.count,
    records: game.scriptPacks.prefix(SeedBoardEvidenceLimit.packs).map {
      ["definition": seedEvidenceText($0.manifest.stateID), "digest": seedEvidenceText($0.digest)]
    })
  // This priority preserves seed custody/stock first when an unusually large board exceeds the
  // final message budget. Count every omitted record rather than cutting serialized JSON.
  var sections = [rows, installed, stocks, instances]
  let names = ["rows", "installedPacks", "seedStock", "seedInstances"]
  let prefix = "W03 ordinary board lookup: "
  let afterOpen = seedBoardOpenEvidence(game)
  let fallback =
    "request=" + seedEvidenceText(request) + " callSite=" + seedEvidenceText("\(file):\(line)")
    + " truncated=true totals="
    + sections.indices.map { "\(names[$0]):\(sections[$0].total)" }.joined(separator: ",")
  var outputTruncated = false
  while true {
    var evidence: [String: Any] = [
      "request": seedEvidenceText(request), "callSite": seedEvidenceText("\(file):\(line)"),
      "expectedDigest": seedEvidenceText(digest), "beforeOpen": beforeOpen,
      "objectivePublicationRefusal": seedEvidenceText(publication ?? "not-observed", limit: 12288),
      "afterOpen": afterOpen,
      "outputUTF8Limit": SeedBoardEvidenceLimit.outputBytes,
      "outputBudgetTruncated": outputTruncated,
      "scalarUTF8Limit": SeedBoardEvidenceLimit.scalarBytes,
      "dockUTF8Limit": SeedBoardEvidenceLimit.dockBytes,
    ]
    for index in sections.indices { evidence[names[index]] = sections[index].value }
    do {
      let bytes = try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys])
      if prefix.utf8.count + bytes.count <= SeedBoardEvidenceLimit.outputBytes {
        return prefix + String(decoding: bytes, as: UTF8.self)
      }
    } catch {
      return prefix + "encoding-error=" + seedEvidenceText(String(describing: error)) + " "
        + fallback
    }
    guard let index = sections.firstIndex(where: { !$0.records.isEmpty }) else {
      return prefix + "output-budget-exceeded; retained=0; " + fallback
    }
    sections[index].records.removeLast()
    outputTruncated = true
  }
}

// These are formatter inputs only. They are never installed on the live runtime observer.
private func verifySeedEndpointEvidenceFormatting() {
  let absent = ScriptProcurementFixture.endpointBirthFailureEvidence(
    endpoint: nil, observations: [], context: "targetID=nil")
  #expect(absent.contains("endpoint=[not-observed]") && absent.contains("producer=[not-observed]"))
  let observation = GameplayEncounterBirthDiagnostic.Observation(
    openingDecision: 7, decision: 8, admitted: 1, time: 12.5, requests: [], receipts: [])
  let retained = ScriptProcurementFixture.endpointBirthFailureEvidence(
    endpoint: "stage=endpoint-query actor=formatter-only component=fixture budget=1 result=refused",
    observations: [observation], context: "status=AUTO\nfixture")
  #expect(retained.contains("stage=endpoint-query actor=formatter-only component=fixture"))
  #expect(
    retained.contains("budget=1 result=refused") && retained.contains("time=12.5,decisions=7->8"))
  #expect(retained.contains("retainedObservations=1") && retained.contains("producerWindow=last"))
  #expect(!retained.contains("\n") && retained.contains("status=AUTO?fixture"))
  let limited = ScriptProcurementFixture.endpointBirthFailureEvidence(
    endpoint: String(repeating: "x", count: 20000), observations: [],
    context: String(repeating: "y", count: 10000))
  #expect(limited.contains("endpointBytes=20000 endpointTruncated=true"))
  #expect(limited.contains("contextBytes=10000 contextTruncated=true"))
  #expect(limited.utf8.count < 16384 + 8192 + 512)
}

struct OriginalSeedTransferTests {
  @Test func productionSeedProfileTermsAndNamedCustodiansDeduplicateExactContent() throws {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let pack = fixture.pack
    let terms = try #require(pack.manifest.coldChain)
    #expect(pack.manifest.stateID == originalSeedTransferFamily && terms.isSeedTransfer)
    #expect(terms.instanceDefinition == originalSeedTransferFamily)
    #expect(
      terms.source.system == 241 && terms.objective.system == 85 && terms.receiver.system == 85)
    #expect(terms.route == [241, 85] && terms.stockUnits == 6 && terms.tonnes == 3)
    #expect(terms.maximumActive == 3 && terms.hazardTier == 0 && terms.rewardNative == 6050)
    #expect(terms.flightAllowance == 2700)
    #expect(terms.sourceCustodian?.name == "Custodian Lysa Verin")
    #expect(terms.receiverCustodian?.name == "Custodian Oren Hale")
    #expect(terms.sourceCustodian?.id != terms.receiverCustodian?.id)
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(library.errors.isEmpty && library.packs.filter { $0.digest == pack.digest }.count == 1)
    #expect(library.packs.first?.digest == pack.digest)
  }

  @Test func actualSeedBoardBackThreeTonneReviewAndRedockKeepOriginalConsignment() async throws {
    let fixture = try OriginalSeedTransferBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let first = try await fixture.review(runtime, request: "pickup review before first acceptance")
    {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(first.allowed)
    let before = await runtime.snapshot()
    let detail = Display.contractDetailRows(before, width: before.viewportWidth).joined(
      separator: "\n")
    #expect(detail.contains("Celalen -> Cedamar") && detail.contains("605.0 CR"))
    #expect(
      detail.contains("3t") && detail.contains("passenger berths: 0") && detail.contains("2700"))
    #expect(detail.contains("Custodian Lysa Verin") && detail.contains("Custodian Oren Hale"))
    #expect(detail.contains("explicitly authored") && detail.contains("not a measured journey"))
    // A copied capacity input checks the UI guard only; it supplies no native cargo purchase proof.
    var onlyTwo = before
    onlyTwo.commander.cargo[0] = onlyTwo.commander.standardCargoCapacity - 2
    #expect(!onlyTwo.wayfarerColdChainReview(first.row).allowed)
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == before.commander)
    let reopened = try await fixture.review(
      runtime, request: "pickup reopened action=\(first.row.action)"
    ) { $0 == first.row.action }
    #expect(reopened.row.key == first.row.key && reopened.offer?.id == first.offer?.id)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    let redocked = try await fixture.review(
      runtime, request: "pickup after redock action=\(first.row.action)"
    ) { $0 == first.row.action }
    #expect(redocked.row.key == first.row.key && redocked.offer?.id != first.offer?.id)
    var stale = await runtime.snapshot()
    #expect(throws: (any Error).self) { try stale.confirmWayfarerColdChainBoard(first) }
    try await runtime.save(to: fixture.native.save)
    try await runtime.load(from: fixture.native.save, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let loaded = try await fixture.review(
      runtime, request: "pickup after reload action=\(first.row.action)"
    ) { $0 == first.row.action }
    #expect(loaded.row.key == first.row.key && loaded.offer?.id != redocked.offer?.id)
    #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  }

  @Test func actualSeedBoardNamedReceptionPaysItsOwnClueOnceAcrossTwoLots() async throws {
    let fixture = try OriginalSeedTransferBoardFixture()
    defer { fixture.native.files.clean() }
    verifySeedEndpointEvidenceFormatting()
    try await verifySeedPublicationRefusalControls()
    let endpoint = GameplayEncounterBirthDiagnostic()
    try #require(endpoint.endpointRefusal == nil && endpoint.observations.isEmpty)
    let runtime = try await fixture.native.runtime(endpointDiagnostic: endpoint)
    let first = try await fixture.pickup(runtime, lot: "first")
    let second = try await fixture.pickup(runtime, lot: "second")
    let source = await runtime.snapshot()
    #expect(
      source.commander.scriptState.instances[first]?.payloads["wayfarer-sealed-seed-lot"] == 3)
    let premature = try await fixture.review(
      runtime, request: "premature objective instance=\(first)"
    ) { $0 == .objective(first) }
    #expect(!premature.allowed)
    try await fixture.native.arrive(runtime, path: [241, 85])
    var originalAward: ScriptCompletionReceipt?
    for (index, id) in [first, second].enumerated() {
      let objective = try await fixture.review(
        runtime, request: "objective lot=\(index) instance=\(id)"
      ) { $0 == .objective(id) }
      try #require(objective.allowed, Comment(rawValue: objective.issues.joined(separator: "; ")))
      // Fresh first-only slots belong to this ordinary right/return confirmation, not earlier flight.
      await runtime.beginScriptRefusalObservation()
      await fixture.confirm(runtime)
      let objectivePublication = await runtime.finishSeedPublicationRefusalObservation()
      let verified = await runtime.snapshot()
      #expect(verified.commander.credits == source.commander.credits + 6050 * index)
      let receiving = try await fixture.review(
        runtime, request: "receive lot=\(index) instance=\(id)", publication: objectivePublication
      ) { $0 == .receive(id) }
      try #require(receiving.allowed, Comment(rawValue: receiving.issues.joined(separator: "; ")))
      await fixture.confirm(runtime)
      let paid = await runtime.snapshot()
      #expect(paid.commander.scriptState.instances[id]?.outcome == .complete)
      #expect(
        paid.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer?.acceptance
          != nil)
      #expect(paid.commander.credits == source.commander.credits + 6050 * (index + 1))
      let award = try #require(
        paid.commander.scriptState.savedClueJournal?.awards[originalSeedTransferFamily])
      #expect(award.clueID == "exchange-service-seed-transfer")
      #expect(
        ScriptClueTrustCatalog.production.pin(for: award.completion)?.digest
          == fixture.native.pack.digest)
      #expect(
        paid.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.stateID]
          == nil)
      if index == 0 {
        originalAward = award.completion
        #expect(paid.message.contains("SENN:"))
      } else {
        #expect(award.completion == originalAward)
      }
      #expect(paid.commander.scriptState.savedClueJournal?.awards.count == 1)
    }
    #expect(
      await runtime.snapshot().commander.scriptState.instances[first]?.payloads.isEmpty == true)
  }
}
