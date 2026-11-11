import Foundation
import Testing

@testable import L337Core

/// Controlled remote location, NOT a flown route. Bootstrap, swept native berth entry,
/// ordinary purchase, board confirmation and current writer use their real producers.
/// No trade, item, stock, acceptance or live contact receipt is injected. UNRUN.
final class AssemblyOpeningFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime

  // Keep this fixture in its caller's isolation through the async setup and service calls.
  init(buy: Bool = true, isolation: isolated (any Actor)? = #isolation) async throws {
    let storage = try ScriptFreightFixture()
    files = storage
    var ready = false
    defer { if !ready { storage.clean() } }
    try FileManager.default.createDirectory(
      at: storage.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: storage.save)
    let born = await boot.snapshot()
    try #require(born.nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
    try game.departOrdinarySimulation()
    let issuer = NativeAssemblyOfOrbitsDefinition.issuer
    game.commander.galaxy = issuer.galaxy
    game.commander.system = issuer.system
    game.selectedSystem = issuer.system
    game.systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledAssemblyOfOrbitsDirectory)]
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    runtime = GameRuntime(game: game, saveURL: storage.save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.systemIdentity == issuer && arrived.assemblyOfOrbitsPack != nil)
    if buy { try await Self.buyOne(runtime) }
    try await runtime.save(to: storage.save)
    ready = true
  }

  func clean() { files.clean() }

  static func buyOne(_ runtime: GameRuntime) async throws {
    let before = await runtime.snapshot()
    let index = try #require(before.market.indices.first {
      Commodity.all[$0].unit == "t" && before.market[$0].quantity > 0
        && before.market[$0].price > 0 && before.commander.availableCredits >= before.market[$0].price
    })
    try #require(before.stationAllowsMarketServices)
    await runtime.nativeCommand { game in
      game.screen = .buy
      game.selection = index
    }
    await runtime.key("return")
    let after = await runtime.snapshot()
    try #require(after.commander.cargo[index] == before.commander.cargo[index] + 1)
    try #require(after.market[index].quantity == before.market[index].quantity - 1)
    try #require(after.commander.credits == before.commander.credits - before.market[index].price)
    try #require(NativeAssemblyOfOrbitsTrade.current(in: after.commander) != nil)
    // A genuine purchase alone qualifies; sale-only consumers retain their old contract.
    try #require(after.commander.scriptState.firstNativeCommoditySale == nil)
  }

  func review(
    _ action: NativeAssemblyOfOrbitsAction, isolation: isolated (any Actor)? = #isolation
  ) async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.assemblyOfOrbits == action }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.assemblyOfOrbits == action)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.assemblyOfOrbitsQuote?.action == action)
    return detail
  }

  func confirm(
    _ action: NativeAssemblyOfOrbitsAction, isolation: isolated (any Actor)? = #isolation
  ) async throws -> Game {
    let detail = try await review(action)
    try #require(detail.contractBoard.assemblyOfOrbitsQuote?.allowed == true)
    await runtime.key("right")
    await runtime.key("return")
    let result = await runtime.snapshot()
    let instance = try #require(result.assemblyOfOrbitsMission)
    if action == .collectReference { try #require(instance.savedAssemblyOfOrbits?.collection != nil) }
    return result
  }
}

struct NativeAssemblyOfOrbitsUnitTests {
  @Test func purchaseOnlyCommissionAndSeparateOriginalCollectionSurviveCurrentColdLoad() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review(.accept)
    try #require(preview.contractBoard.assemblyOfOrbitsQuote?.allowed == true)
    let inventory = try #require(preview.commander.equipmentInventory)
    try #require(preview.assemblyOfOrbitsMission == nil)
    await fixture.runtime.key("right")
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let commission = try #require(accepted.assemblyOfOrbitsMission)
    let acceptance = try #require(commission.savedAssemblyOfOrbits)
    #expect(acceptance.collection == nil && commission.gearIssues.isEmpty)
    #expect(commission.receipts == [NativeAssemblyOfOrbitsDefinition.acceptReceipt])
    #expect(commission.milestones == [0] && commission.journal == NativeAssemblyOfOrbitsDefinition.briefing)
    #expect(accepted.commander.equipmentInventory == inventory)
    #expect(accepted.commander.credits == preview.commander.credits)
    #expect(accepted.commander.cargo == preview.commander.cargo)
    #expect(accepted.commander.scriptState.savedClueJournal == preview.commander.scriptState.savedClueJournal)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(accepted.commander))
    let acceptedCold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(acceptedCold.scriptState.instances[commission.id]?.savedAssemblyOfOrbits == acceptance)

    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.assemblyOfOrbitsMission)
    let state = try #require(instance.savedAssemblyOfOrbits)
    let collection = try #require(state.collection)
    let loan = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: collected.commander)
    #expect(state.acceptance == acceptance.acceptance && instance.id == commission.id)
    #expect(instance.milestones == [0, 1] && instance.receipts.count == 2)
    #expect(instance.outcome == .active && instance.completionReceipt == nil)
    #expect(collection.facts.original == NativeAssemblyReferenceDefinition.serial(mission: instance.id))
    #expect(collection.facts.afterCargoTonnes == collection.facts.beforeCargoTonnes + 1)
    #expect(collection.facts.afterInventoryRevision == inventory.revision + 1)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.cargo == accepted.commander.cargo)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(collected.commander))
    try await fixture.runtime.save(to: fixture.files.save)
    let cold = try ScriptSaveStore.read(Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    let coldInstance = try #require(cold.scriptState.instances[instance.id])
    #expect(coldInstance.savedAssemblyOfOrbits == state)
    #expect(try NativeAssemblyOfOrbitsCustody.resolve(instance: coldInstance, commander: cold) == loan)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    let loadedInstance = try #require(loaded.assemblyOfOrbitsMission)
    #expect(loadedInstance.savedAssemblyOfOrbits == state)
    #expect(loaded.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(try NativeAssemblyOfOrbitsCustody.resolve(instance: loadedInstance, commander: loaded.commander) == loan)
    #expect(loaded.nativeStationRuntimeEpoch != collected.nativeStationRuntimeEpoch)
    #expect(!loaded.assemblyOfOrbitsReview(.collectReference).allowed)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(loaded.commander))
  }

  @Test func noTradeBackAndStalePurchaseReviewCannotAccept() async throws {
    let fixture = try await AssemblyOpeningFixture(buy: false)
    defer { fixture.clean() }
    let blocked = try await fixture.review(.accept)
    #expect(blocked.contractBoard.assemblyOfOrbitsQuote?.allowed == false)
    #expect(blocked.assemblyOfOrbitsMission == nil)
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.commander == blocked.commander)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    try await AssemblyOpeningFixture.buyOne(fixture.runtime)
    _ = try await fixture.review(.accept)
    await fixture.runtime.key("right")
    let chosen = await fixture.runtime.snapshot()
    let quote = try #require(chosen.contractBoard.assemblyOfOrbitsQuote)
    try #require(quote.allowed)
    try await AssemblyOpeningFixture.buyOne(fixture.runtime)
    let changed = await fixture.runtime.snapshot()
    var stale = changed
    // Restore only the old transient screen for this negative check; no source is injected.
    stale.screen = .contracts
    stale.contractBoard = chosen.contractBoard
    let unchanged = stale.commander
    #expect(throws: MissionPackError.self) { try stale.confirmAssemblyOfOrbits(quote) }
    #expect(stale.commander == unchanged && stale.assemblyOfOrbitsMission == nil)
    let accepted = try await fixture.confirm(.accept)
    #expect(accepted.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.collection == nil)
  }

  @Test func actualWriterRefusalRetainsIssuerOriginalAndRetriesOnce() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    for action in [NativeAssemblyOfOrbitsAction.accept, .collectReference] {
      _ = try await fixture.review(action)
      await fixture.runtime.key("right")
      let before = await fixture.runtime.snapshot()
      let quote = try #require(before.contractBoard.assemblyOfOrbitsQuote)
      try #require(quote.allowed)
      let directory = fixture.files.save.deletingLastPathComponent()
      let files = try ScriptFinanceTestFixture.files(directory)
      let held = try fixture.files.blockWrites("assembly-" + action.rawValue)
      await #expect(throws: (any Error).self) {
        try await fixture.runtime.scriptCommand { candidate in
          // A producer error is a test failure, not mistaken for the expected writer refusal.
          do { try candidate.confirmAssemblyOfOrbits(quote) }
          catch { Issue.record(error); throw error }
        }
      }
      let refused = await fixture.runtime.snapshot()
      #expect(refused.commander == before.commander)
      #expect(try ScriptFinanceTestFixture.files(held) == files)
      #expect(try Data(contentsOf: directory) == Data([1]))
      try fixture.files.restoreWrites(held, files: files)
      await fixture.runtime.key("return")
      let committed = await fixture.runtime.snapshot()
      let instance = try #require(committed.assemblyOfOrbitsMission)
      if action == .accept {
        #expect(instance.savedAssemblyOfOrbits?.collection == nil && instance.gearIssues.isEmpty)
      } else {
        let state = try #require(instance.savedAssemblyOfOrbits?.collection)
        #expect(instance.gearIssues.count == 1)
        #expect(state.facts.afterInventoryRevision == state.facts.beforeInventoryRevision + 1)
        _ = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: committed.commander)
      }
      #expect(committed.commander.credits == before.commander.credits)
      #expect(committed.commander.cargo == before.commander.cargo)
      #expect(committed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
      #expect(NativeAssemblyOfOrbitsSave.validateClaims(committed.commander))
      var repeated = before
      repeated.commander = committed.commander
      #expect(throws: MissionPackError.self) { try repeated.confirmAssemblyOfOrbits(quote) }
      #expect(repeated.commander == committed.commander)
    }
  }

  @Test func genuineIssueCommandCannotMasqueradeAsTheOrdinaryTrade() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.assemblyOfOrbitsMission)
    let state = try #require(instance.savedAssemblyOfOrbits)
    let issue = try #require(state.collection)
    let original = state.acceptance
    try #require(original.ordinaryTrade != issue.facts.issueCommand)
    // Deliberately false causal link made from two ACTUAL operation identities.
    let wrong = NativeAssemblyAcceptanceFacts(mission: original.mission, owner: original.owner,
      carrier: original.carrier, inventoryRevision: original.inventoryRevision, dock: original.dock,
      ordinaryTrade: issue.facts.issueCommand, eventSequence: original.eventSequence,
      physicalTime: original.physicalTime, calendarSeconds: original.calendarSeconds)
    var falseState = try NativeAssemblyOfOrbitsState(acceptance: wrong)
    falseState.collection = issue
    try #require(falseState.shapeValid)
    var invalid = collected
    invalid.commander.scriptState.instances[instance.id]?.savedAssemblyOfOrbits = falseState
    #expect(!NativeAssemblyOfOrbitsSave.validateClaims(invalid.commander))
    let directory = fixture.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    #expect(throws: (any Error).self) {
      try GameRuntime.writeCommander(&invalid, to: fixture.files.save)
    }
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(collected.commander))
  }

  @Test func genericAcceptanceAndCommandsCannotGrantCustodyProgressOrPayment() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.assemblyOfOrbitsPack)
    let before = game.commander
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.assemblyOfOrbitsMission == nil)
    let accepted = try await fixture.confirm(.accept)
    let instance = try #require(accepted.assemblyOfOrbitsMission)
    let saved = try #require(instance.savedAssemblyOfOrbits)
    // This replay uses the real historical sequence but is NOT a pending live event.
    let event = ScriptEvent(sequence: saved.acceptance.eventSequence,
      kind: "mission.accepted", instance: instance.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("success")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(2)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(77000)]),
      .object(["op": .string("payload.add"), "id": .string("false-reference"), "tonnes": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeAssemblyOfOrbitsDefinition.briefing[0])]),
    ]
    for command in commands {
      var state = instance
      var candidate = accepted.commander
      #expect(throws: (any Error).self) {
        try accepted.applyScriptCommand(command, event: event, pack: pack, state: &state, candidate: &candidate)
      }
      #expect(state == instance && candidate == accepted.commander)
    }
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(accepted.commander))
  }
}
