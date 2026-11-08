import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalStationDispatchTests {
  @Test func originalSitesExposeAuthoredDispatchWithoutRemovedHalfDrawGate() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    for site in [OriginalStationSite.salamander, .frog, .dhole] {
      let runtime = try await fixture.runtime(at: site)
      let actual = await runtime.snapshot()
      let ownedPreparationRequired1 = actual.nativeOriginalSealedDispatchOrigin(for: fixture.pack)
      let origin = try #require(ownedPreparationRequired1)
      #expect(origin.station == NativeOriginalSealedDispatchOrigin.station(for: site))
      #expect(origin.isCurrent(in: actual, pack: fixture.pack))
      #expect(NativeOriginalSealedDispatchOrigin.matches(origin.facts, station: origin.station))
      let (key, _) = try await fixture.offer(runtime)
      let board = try #require(await runtime.snapshot().commander.contracts.boards[key])
      #expect(board.offers.compactMap { $0.courier?.row } == [1, 3, 5])
      #expect(board.station == origin.station && board.valid)
      var unproved = actual
      unproved.invalidateNativeStationAuthority()
      #expect(!origin.isCurrent(in: unproved, pack: fixture.pack))
      unproved.nativeStationDockEvidence = nil
      #expect(unproved.nativeOriginalSealedDispatchOrigin(for: fixture.pack) == nil)
      let foreign = site.identity(world: UUID())
      let owner = try #require(actual.commander.equipmentOwnerID)
      #expect(OriginalStationSite.site(for: foreign, owner: owner) == nil)
      #expect(!NativeOriginalSealedDispatchOrigin.matches(
        origin.facts, station: .init(galaxy: 0, system: 237, stationClass: origin.station.stationClass)))
      var roleOnly = actual
      roleOnly.nativeStationDockEvidence = nil
      #expect(roleOnly.nativeOriginalSealedDispatchOrigin(for: fixture.pack) == nil)
    }
    #expect(OriginalStationSite.remoteUtility.sealedDispatchDefinition == nil)
    #expect(NativeOriginalSealedDispatchOrigin.station(for: .remoteUtility) == nil)
    let main = try await fixture.runtime()
    #expect(await main.snapshot().nativeOriginalSealedDispatchOrigin(for: fixture.pack) == nil)
    #expect(await main.snapshot().nativeMainStationDockEvidenceIsCurrent)
  }

  @Test(arguments: [OriginalStationSite.salamander, .frog, .dhole])
  func actualStationBoardCachesAndDeclinesWithoutPacketOrResourceEffects(site: OriginalStationSite)
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: site)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let (key, offer) = try await fixture.offer(runtime)
    let generated = await runtime.snapshot()
    let board = try #require(generated.commander.contracts.boards[key])
    let ownedPreparationRequired2 = generated.nativeOriginalSealedDispatchOrigin(for: fixture.pack)
    let origin = try #require(ownedPreparationRequired2)
    #expect(board.station == origin.station && board.courierGeneration?.origin == origin.station)
    #expect(generated.commander.scriptState.instances.isEmpty && generated.commander.cargoTonnes == baseline)
    try await openDispatchReview(runtime, key: key, offer: offer.id)
    let review = await runtime.snapshot()
    #expect(review.contractBoard.detail && review.contractBoard.action == .back)
    let detail = Display.contractDetailRows(review, width: 800).joined(separator: "\n")
    #expect(detail.contains("1t") && detail.contains("Untimed") && detail.contains("H0"))
    await runtime.key("escape")
    let cached = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
    let reopened = await runtime.snapshot()
    #expect(cached == key && reopened.commander == generated.commander)
    try await runtime.declineContract(board: key, offer: offer.id)
    let declined = await runtime.snapshot()
    var expected = generated.commander
    expected.contracts.boards[key]?.offers[0].status = .declined
    #expect(declined.commander == expected)
    #expect(declined.commander.scriptState.instances.isEmpty && declined.commander.cargoTonnes == baseline)
    let again = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
    let refreshed = await runtime.snapshot()
    #expect(again == key && refreshed.commander == expected)
    #expect(declined.commander.contracts.boards[key]?.offers.filter { $0.status == .available }.count == 2)
  }

  @Test(arguments: [OriginalStationSite.salamander, .frog, .dhole])
  func actualOriginalConfirmAndReloadPreserveFrozenIdentitiesAndOneTonnePacket(site: OriginalStationSite)
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: site)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let (key, offer) = try await fixture.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let unavailable = await runtime.contractAcceptanceQuote(board: "storage-unavailable", offer: UUID())
    try verifyDispatchReviewStorage(quote, unavailable: unavailable)
    try await openDispatchReview(runtime, key: key, offer: offer.id)
    let before = await runtime.snapshot()
    let acquisition = try #require(before.commander.fleetBlueprintAcquisition(for: "SH029"))
    let hull = before.commander.hullInstanceID
    #expect(before.commander.shipID == "SH029" && before.commander.nativeCrewMissing == 0)
    let ownedPreparationRequired3 = before.nativeOriginalSealedDispatchOrigin(for: fixture.pack)
    let origin = try #require(ownedPreparationRequired3)
    #expect(before.contractBoard.quote?.allowed == true && before.contractBoard.detail)
    if site == .salamander {
      let button = try #require(ContractBoardLayout(width: before.viewportWidth, height: before.viewportHeight)
        .actions.first { $0.0 == .accept }?.1)
      await runtime.scriptPageClick(x: button.x + 4, y: button.y + 4, expected: before.scriptPagePresentation)
    } else {
      await runtime.key("right")
      await runtime.key("return")
    }
    let accepted = await runtime.snapshot()
    let id = Game.contractJobIdentity(offer.id)
    let state = try #require(accepted.commander.scriptState.instances[id])
    let job = try #require(state.contract)
    let custody = try #require(state.courier)
    #expect(job.offer == offer && job.station == origin.station && job.boardKey == key)
    #expect(job.offer.courier == quote.courier?.terms && job.deadline == nil)
    #expect(custody.issue.originalOrigin == origin.facts && custody.issue.station == origin.station)
    #expect(custody.item == ScriptCourierCustody.itemIdentity(id) && custody.terminal == nil)
    #expect(state.payloads[ScriptCourierCustody.payloadKey] == 1 && accepted.commander.cargoTonnes == baseline + 1)
    #expect(
      accepted.commander.credits == before.commander.credits
      && accepted.commander.cargo == before.commander.cargo)
    #expect(accepted.commander.fuel == before.commander.fuel)
    #expect(accepted.commander.flightSimulation == before.commander.flightSimulation)
    #expect(accepted.commander.equipmentInventory == before.commander.equipmentInventory)
    var acceptedOnly = before.commander
    acceptedOnly.contracts = accepted.commander.contracts
    acceptedOnly.scriptState = accepted.commander.scriptState
    #expect(accepted.commander == acceptedOnly)
    #expect(accepted.docked && !accepted.dockedAtMainStation && accepted.commander.valid)
    let repeated = try await runtime.confirmContract(quote)
    let replayed = await runtime.snapshot()
    #expect(repeated == id && replayed.commander == accepted.commander)
    try await runtime.save(to: fixture.save)
    let files = try dispatchSaveFiles(fixture.save.deletingLastPathComponent())
    var loading = Game(executive: false)
    loading.scriptPacks = [fixture.pack]
    let restored = GameRuntime(game: loading)
    try await restored.load(from: fixture.save, persistMigrations: false)
    let cold = await restored.snapshot()
    #expect(cold.commander == accepted.commander && cold.commander.scriptState.instances[id] == state)
    #expect(cold.commander.hullInstanceID == hull)
    #expect(cold.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
    #expect(cold.commander.nativePeople == before.commander.nativePeople)
    #expect(cold.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(!origin.isCurrent(in: cold, pack: fixture.pack))
    #expect(cold.commander.nativeStations?.ledger.currentDock == origin.facts.receipt)
    await #expect(throws: (any Error).self) { try await restored.confirmContract(quote) }
    #expect(try dispatchSaveFiles(fixture.save.deletingLastPathComponent()) == files)
    await restored.key("contracts-open")
    let reopened = await restored.snapshot()
    var expected = cold.commander
    expected.contracts.boards = reopened.commander.contracts.boards
    #expect(reopened.commander == expected && reopened.commander.scriptState.instances[id] == state)
    #expect(reopened.contractBoard.rows.filter { $0.board == key && $0.offer != nil }.count == 3)
    #expect(reopened.commander.contracts.boards[key]?.revision == job.boardRevision + 1)
  }

  @Test(arguments: ["hour", "legal", "epoch", "main-unproved", "cash", "cargo"])
  func staleActualReviewsCannotAccept(reason: String) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let (key, offer) = try await fixture.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed)
    let captured = quote.resources
    let original = await runtime.snapshot()
    var stale = original
    switch reason {
    case "hour":
      stale.commander.scriptState.calendarSeconds += 3600
      stale.commander.scriptState.missionCalendar?.seconds += 3600
      // Original boards are untimed. The hour alone does not invalidate their frozen offers.
      let afterHour = stale.contractAcceptanceQuote(board: key, offer: offer.id)
      #expect(afterHour.allowed && afterHour.courier == quote.courier)
      stale.invalidateNativeStationAuthority()
      stale.nativeStationDockEvidence = nil
    case "legal":
      stale.commander.legal = 51
      let fresh = stale.contractAcceptanceQuote(board: key, offer: offer.id)
      #expect(fresh.allowed) // Property capture changes; the removed legal source gate stays removed.
    case "epoch": stale.ecmControl = ECMControl()
    case "cash": stale.commander.credits += 1
    case "cargo": stale.commander.cargo[0] += 1
    default:
      stale.nativeStationDockEvidence = nil
      stale.nativeMainStationDockEvidence = nil
    }
    #expect(quote.resources == captured)
    let before = stale.commander
    let bodies = stale.bodies
    #expect(throws: (any Error).self) { try stale.confirmContract(quote) }
    #expect(stale.commander == before && stale.bodies == bodies)
    #expect(stale.commander.scriptState.instances.isEmpty && stale.commander.cargoTonnes == before.cargoTonnes)
    #expect(await runtime.snapshot().commander == original.commander)
  }

  @Test(arguments: ["accept", "decline", "abandon", "debrief"])
  func failedActualWriterConservesWholeCommanderSceneAndPreviousFiles(action: String) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .salamander)
    let (key, offer) = try await fixture.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    var id: UUID?
    if action == "abandon" || action == "debrief" {
      id = try await runtime.confirmContract(quote)
      if action == "debrief" {
        let terms = try #require(await runtime.snapshot().commander.scriptState.instances[id!]?.contract?.offer.courier)
        try await fixture.travel(runtime, path: terms.path)
      }
      try await fixture.contact(runtime, action: action == "debrief" ? "Deliver" : "Abandon")
      await runtime.key("left")
    }
    try await runtime.save(to: fixture.save)
    let before = await runtime.snapshot()
    let files = try dispatchSaveFiles(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites(action)
    if action == "accept" {
      await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    } else if action == "decline" {
      await #expect(throws: (any Error).self) { try await runtime.declineContract(board: key, offer: offer.id) }
    } else {
      await runtime.key("return")
    }
    let failed = await runtime.snapshot()
    #expect(
      failed.commander == before.commander
      && failed.bodies == before.bodies
      && failed.nextBodyID == before.nextBodyID)
    #expect(failed.scriptPresentedDialogue == before.scriptPresentedDialogue && failed.scriptCourierAdmission == nil)
    #expect(try dispatchSaveFiles(blocked) == files)
    #expect(try Data(contentsOf: fixture.save.deletingLastPathComponent()) == Data([1]))
    try fixture.files.restoreWrites(blocked, files: files)
    if action == "accept" { _ = try await runtime.confirmContract(quote) }
    else if action == "decline" { try await runtime.declineContract(board: key, offer: offer.id) }
    else { await runtime.key("return") }
    let retried = await runtime.snapshot()
    #expect(retried.commander != before.commander && retried.commander.valid)
    if let id {
      let state = try #require(retried.commander.scriptState.instances[id])
      #expect(state.outcome == (action == "debrief" ? .complete : .abandoned))
      #expect(state.courier?.terminal?.cause == (action == "debrief" ? .delivered : .abandoned))
      #expect(state.payloads[ScriptCourierCustody.payloadKey, default: 0] == 0)
      if action == "abandon" {
        #expect(state.courier?.terminal?.amount == 0 && retried.commander.credits == before.commander.credits)
        #expect(retried.commander.scriptState.savedClueJournal == nil)
      }
      await runtime.key("return")
      #expect(await runtime.snapshot().commander == retried.commander)
    }
  }

  @Test func genuineOriginalMainDoorwayAndDebriefConfirmPayExactlyOnce() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime)
    let issued = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let terms = try #require(issued.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    let arrived = await runtime.snapshot()
    let job = try #require(arrived.commander.scriptState.instances[id]?.contract)
    let ownedPreparationRequired4 = arrived.originalSealedDispatchReceiver(for: job)
    let receiver = try #require(ownedPreparationRequired4)
    #expect(arrived.acceptsNativeMainStationArrivalContext(receiver))
    #expect(arrived.commander.scriptState.instances[id]?.outcome == .active && arrived.commander.cargoTonnes == baseline + 1)
    #expect(arrived.commander.scriptState.instances[id]?.courier?.terminal == nil)
    try await fixture.contact(runtime, action: "Deliver")
    let review = await runtime.snapshot()
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == review.commander)
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    let state = try #require(done.commander.scriptState.instances[id])
    #expect(state.outcome == .complete && state.courier?.terminal?.cause == .delivered)
    #expect(state.courier?.terminal?.item == issued.courier?.item && state.courier?.terminal?.amount == terms.reward)
    #expect(state.completionReceipt?.cause?.nativeMainDock == receiver.receipt)
    #expect(state.completionReceipt?.committed.nativeMainDock == receiver.receipt)
    #expect(done.commander.credits == arrived.commander.credits + (320 + 90 * (terms.path.count - 1)) * 10)
    #expect(done.commander.cargoTonnes == baseline && state.payloads[ScriptCourierCustody.payloadKey, default: 0] == 0)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID]?.clueID
        == "sealed-dispatch-family-trace")
    #expect(done.commander.valid && done.commander.contractsValid)
    let receipt = try #require(state.completionReceipt)
    #expect(receipt.digest == fixture.pack.digest)
    #expect(ScriptClueTrustCatalog.production.pin(for: receipt)?.sourceID == OriginalSealedDispatch.stateID)
    // Mutated content and receipt inputs exercise trust only; none is installed as an outcome.
    let alteredDirectory = fixture.files.root.appendingPathComponent("altered-dispatch")
    try FileManager.default.copyItem(
      at: ScriptPackLibrary.bundledSealedDispatchDirectory, to: alteredDirectory)
    let module = alteredDirectory.appendingPathComponent(fixture.pack.manifest.module)
    var bytes = try Data(contentsOf: module)
    bytes.append(Data("\n-- This copy has no production clue approval.\n".utf8))
    try bytes.write(to: module)
    let altered = try ScriptPackLibrary.read(alteredDirectory)
    #expect(altered.manifest.stateID == fixture.pack.manifest.stateID && altered.digest != fixture.pack.digest)
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
    for (field, value) in [
      ("definition", "l337.contract/other"), ("version", "1.0.1"),
      ("digest", altered.digest), ("causeKind", "mission.accepted"),
    ] {
      var changed = object
      changed[field] = value
      let foreign = try JSONDecoder().decode(
        ScriptCompletionReceipt.self, from: JSONSerialization.data(withJSONObject: changed))
      #expect(ScriptClueTrustCatalog.production.pin(for: foreign) == nil)
    }
    var paidOnly = arrived.commander
    paidOnly.contracts = done.commander.contracts
    paidOnly.scriptState = done.commander.scriptState
    paidOnly.credits += terms.reward
    #expect(done.commander == paidOnly)
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    replay.resolveCourierTerminals()
    #expect(
      replay.commander.credits == done.commander.credits
      && replay.commander.contracts == done.commander.contracts)
    #expect(replay.commander.scriptState.instances[id] == state && replay.commander.cargoTonnes == baseline)
    #expect(replay.commander.scriptState.savedClueJournal == done.commander.scriptState.savedClueJournal)
    #expect(replay.commander.equipmentInventory == done.commander.equipmentInventory && replay.commander.valid)
    try await runtime.save(to: fixture.save)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: fixture.save)
    #expect(persisted.scriptState.instances[id] == state)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.commander == done.commander && cold.commander.contractsValid)
    #expect(!cold.acceptsNativeMainStationArrivalContext(receiver))
  }

  @Test func booleanMainDockCannotMintDeliveryAuthority() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let id = try await fixture.accept(runtime)
    let terms = try #require(await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    try await fixture.contact(runtime, action: "Deliver")
    let actual = await runtime.snapshot()
    let shown = try #require(actual.scriptPresentedDialogue)
    for keepReceipt in [false, true] {
      var flags = actual
      flags.nativeMainStationDockEvidence = nil
      if !keepReceipt { flags.commander.nativeStations?.currentMainDock = nil }
      let before = flags.commander
      let state = try #require(flags.commander.scriptState.instances[id])
      #expect(flags.docked && flags.dockedAtMainStation && flags.commander.system == terms.destination)
      #expect(!flags.courierDialogueStationIsCurrent(state, contact: shown.id))
      #expect(throws: (any Error).self) { try flags.confirmCourierDialogue(id, dialogue: shown) }
      #expect(flags.commander == before && flags.scriptCourierAdmission == nil)
      #expect(flags.commander.scriptState.instances[id]?.courier?.item == state.courier?.item)
      #expect(flags.commander.scriptState.savedClueJournal == nil)
    }
  }

  @Test func temporarilyUnprovedMainSuspendsWithoutLosingPacketOrFailing() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime)
    let terms = try #require(await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    try await fixture.contact(runtime, action: "Deliver")
    let actual = await runtime.snapshot()
    let shown = try #require(actual.scriptPresentedDialogue)
    var unavailable = actual
    unavailable.nativeMainStationDockEvidence = nil
    let before = unavailable.commander
    unavailable.resolveCourierTerminals()
    #expect(unavailable.commander == before)
    #expect(throws: (any Error).self) { try unavailable.confirmCourierDialogue(id, dialogue: shown) }
    #expect(unavailable.commander.scriptState.instances[id]?.outcome == .active)
    #expect(
      unavailable.commander.scriptState.instances[id]?.courier?.terminal == nil
      && unavailable.commander.cargoTonnes == baseline + 1)
    #expect(unavailable.commander == before)
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }

  @Test(arguments: [false, true])
  func actualNativeDeparturePreservesOriginalUntimedCustodyWithoutPayment(galaxy: Bool) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog, galaxyReady: galaxy)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime)
    let accepted = await runtime.snapshot()
    let state = try #require(accepted.commander.scriptState.instances[id])
    let terms = try #require(state.contract?.offer.courier)
    if galaxy {
      await runtime.nativeCommand { $0.screen = .status }
      await runtime.key("0")
      try #require(await runtime.snapshot().docked == false)
      await runtime.key("g")
    } else {
      try await fixture.travel(runtime, path: Array(terms.path.prefix(2)))
    }
    let departed = await runtime.snapshot()
    #expect(departed.systemIdentity != accepted.systemIdentity)
    #expect(departed.commander.galaxy == (galaxy ? (accepted.commander.galaxy + 1) & 7 : accepted.commander.galaxy))
    #expect(departed.commander.scriptState.instances[id]?.courier == state.courier)
    #expect(departed.commander.scriptState.instances[id]?.outcome == .active && departed.commander.cargoTonnes == baseline + 1)
    #expect(departed.commander.scriptState.instances[id]?.contract?.deadline == nil)
    #expect(
      departed.commander.credits == accepted.commander.credits
      && departed.commander.scriptState.savedClueJournal == nil)
    #expect(departed.commander.valid)
    if galaxy { #expect(!departed.commander.equipment.contains("Galactic Hyperdrive")) }
    _ = await runtime.advance(delta: 0.1)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.courier == state.courier)
    try await runtime.save(to: fixture.save)
    let saved = await runtime.snapshot()
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == saved.commander)
  }

  @Test func failedNativeOriginalTerminalWriterKeepsPacketUntilFreshQualifiedRetry() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime)
    try await fixture.contact(runtime, action: "Abandon")
    await runtime.key("left")
    let before = await runtime.snapshot()
    let item = before.commander.scriptState.instances[id]?.courier?.item
    let bytes = try dispatchSaveFiles(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("terminal")
    await runtime.key("return")
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.bodies == before.bodies)
    #expect(failed.commander.scriptState.instances[id]?.courier?.item == item && failed.commander.cargoTonnes == baseline + 1)
    #expect(try dispatchSaveFiles(blocked) == bytes)
    #expect(try Data(contentsOf: fixture.save.deletingLastPathComponent()) == Data([1]))
    try fixture.files.restoreWrites(blocked, files: bytes)
    // Reopen the actual source contact; a failed publication never supplies a replacement packet.
    await runtime.key("escape")
    try await fixture.contact(runtime, action: "Abandon")
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    let terminal = try #require(done.commander.scriptState.instances[id]?.courier?.terminal)
    #expect(terminal.item == item && terminal.cause == .abandoned && terminal.amount == 0)
    #expect(done.commander.scriptState.instances[id]?.outcome == .abandoned && done.commander.cargoTonnes == baseline)
    #expect(done.commander.credits == before.commander.credits && done.commander.scriptState.savedClueJournal == nil)
    #expect(done.commander.valid)
    await runtime.key("dispatch-test-no-op")
    #expect(await runtime.snapshot().commander == done.commander)
  }

  @Test(arguments: ["owner", "packet", "origin", "destination", "receipt", "seed", "profile",
    "legal", "reputation", "source", "duplicate", "early-terminal"])
  func currentOriginalDispatchForgeriesCannotValidateSourceCustodyOrTerminal(reason: String) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let id = try await fixture.accept(runtime)
    let actual = await runtime.snapshot()
    let state = try #require(actual.commander.scriptState.instances[id])
    if reason == "legal" || reason == "reputation" {
      // Removed policy storage must be refused at the actual closed contract envelope, including null.
      let removedValues: [Any] = [51, NSNull()]
      for value in removedValues {
        let encoded = try JSONEncoder().encode(actual.commander.contracts)
        let decoded = try JSONSerialization.jsonObject(with: encoded)
        var object = try #require(decoded as? [String: Any])
        object[reason == "legal" ? "acceptedLegal" : "acceptedReputation"] = value
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: SaveError.self) { try JSONDecoder().decode(ScriptContractState.self, from: data) }
      }
    } else {
      try verifyDispatchForgery(actual, id: id, state: state, reason: reason)
    }
    #expect(await runtime.snapshot().commander == actual.commander)
  }

  @Test(arguments: ["boards", "jobs"])
  func currentContractCollectionsAndRemovedKeysRefuseBeforeInvalidChildren(field: String) throws {
    if field == "boards" {
      let invalid = "this child must never decode as a contract board"
      let oversized = ["boards": Dictionary(uniqueKeysWithValues: (0...128).map { ("oversize-\($0)", invalid) })]
      let data = try JSONSerialization.data(withJSONObject: oversized)
      do {
        _ = try JSONDecoder().decode(ScriptContractState.self, from: data)
        Issue.record("Oversized current board collection decoded")
      } catch SaveError.invalidCommander {
        // The bound guard ran before attempting any malformed board child.
      } catch {
        Issue.record("Oversized collection reached malformed children: \(error)")
      }
      let admitted = try JSONSerialization.data(withJSONObject: ["boards": ["one": invalid]])
      #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScriptContractState.self, from: admitted) }
    } else {
      let removedValues: [Any] = [["this removed job must never decode"], NSNull()]
      for value in removedValues {
        let bytes = try JSONSerialization.data(withJSONObject: ["boards": [:], "jobs": value])
        #expect(throws: SaveError.self) { try JSONDecoder().decode(ScriptContractState.self, from: bytes) }
      }
    }
    let empty = try JSONDecoder().decode(ScriptContractState.self, from: Data("{\"boards\":{}}".utf8))
    #expect(empty.valid && empty.boards.isEmpty)
  }

  @Test func actualDestinationTombstoneCannotMintOriginalDeliveryOrPaymentAfterLoad() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let id = try await fixture.accept(runtime)
    let terms = try #require(await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    try await fixture.contact(runtime, action: "Deliver")
    let receiverReview = await runtime.snapshot()
    let dialogue = try #require(receiverReview.scriptPresentedDialogue)
    await runtime.nativeCommand { $0.screen = .status }
    await runtime.key("0")
    let before = await runtime.snapshot()
    let job = try #require(before.commander.scriptState.instances[id]?.contract)
    let owner = try #require(before.commander.equipmentOwnerID)
    let destination = try #require(before.commander.nativeStations?.mainStations.first {
      $0.world == owner && $0.system == before.systemIdentity
    })
    let main = try #require(before.bodies.first { $0.id == 0 && $0.hull == .station })
    #expect(main.physical?.identity == before.commander.flightSimulation.anchors?.station.identity)
    #expect(before.commander.scriptState.stationResources[destination.key]?.identity == destination.resource)
    // Explicit terminal-condition fixture: ordinary player weapons cannot destroy the immune MAIN.
    await runtime.nativeCommand { game in
      guard let index = game.bodies.firstIndex(where: { $0.id == 0 && $0.hull == .station }) else { return }
      game.bodies[index].energy = 0
      game.resolveDestroyed()
    }
    let dead = await runtime.snapshot()
    #expect(!dead.bodies.contains { $0.id == 0 && $0.hull == .station })
    #expect(dead.commander.scriptState.stationResources[destination.key]?.destroyed == true)
    if case .destroyed(let identity) = dead.nativeOriginalMainStationDestination {
      #expect(identity == destination)
    } else {
      Issue.record("The actual destination MAIN resource did not retain its terminal identity")
    }
    #expect(dead.originalSealedDispatchReceiver(for: job) == nil)
    #expect(dead.commander.scriptState.instances[id]?.outcome == .active)
    #expect(dead.commander.scriptState.instances[id]?.courier == before.commander.scriptState.instances[id]?.courier)
    #expect(dead.commander.credits == before.commander.credits && dead.commander.scriptState.savedClueJournal == nil)
    #expect(dead.commander.valid && dead.scriptWorldSave.consistent(with: dead.commander))
    var flags = dead
    flags.dock(atMainStation: true)
    let state = try #require(flags.commander.scriptState.instances[id])
    #expect(!flags.courierDialogueStationIsCurrent(state, contact: OriginalSealedDispatch.definition.deliveryContact))
    let flagCommander = flags.commander
    #expect(throws: (any Error).self) { try flags.confirmCourierDialogue(id, dialogue: dialogue) }
    #expect(flags.commander == flagCommander)
    try await runtime.save(to: fixture.save)
    let saved = await runtime.snapshot()
    try await runtime.load(from: fixture.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.commander == saved.commander && cold.commander.credits == before.commander.credits)
    #expect(cold.commander.scriptState.stationResources[destination.key]?.destroyed == true)
    #expect(cold.originalSealedDispatchReceiver(for: job) == nil)
    #expect(!cold.bodies.contains { $0.id == 0 && $0.hull == .station })
    await runtime.key("dispatch-test-no-op")
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.courier == state.courier)
  }
}

private func openDispatchReview(_ runtime: GameRuntime, key: String, offer: UUID) async throws {
  await runtime.key("contracts-open")
  let board = await runtime.snapshot().contractBoard
  let index = try #require(board.rows.firstIndex { $0.board == key && $0.offer?.id == offer })
  for _ in 0..<abs(index - board.selection) { await runtime.key(index < board.selection ? "up" : "down") }
  await runtime.key("return")
  let game = await runtime.snapshot()
  #expect(game.screen == .contracts && MissionUIAction.contracts.isEnabled(in: game))
  #expect(game.contractBoard.quote?.board == key && game.contractBoard.quote?.offer == offer)
}

private func verifyDispatchReviewStorage(
  _ quote: ContractAcceptanceQuote, unavailable: ContractAcceptanceQuote
) throws {
  #expect(quote.allowed && !unavailable.allowed)
  var ui = ContractBoardUI()
  #expect(ui.quote == nil)
  ui.quote = quote
  #expect(ui.quote?.board == quote.board && ui.quote?.offer == quote.offer)
  #expect(ui.quote?.resources == quote.resources && ui.quote?.issues == quote.issues)
  #expect(ui.quote?.epoch == quote.epoch && ui.quote?.reviewToken == quote.reviewToken)
  #expect(ui.quote?.courier == quote.courier)
  let changed = UUID()
  ui.quote?.reviewToken = changed
  #expect(ui.quote?.reviewToken == changed && quote.reviewToken != changed)
  #expect(ui.quote?.resources == quote.resources && ui.quote?.courier == quote.courier)
  ui.quote = unavailable
  #expect(ui.quote?.reviewToken == unavailable.reviewToken && ui.quote?.allowed == false)
  ui.quote = nil
  #expect(ui.quote == nil)
  ui.quote = quote
  #expect(ui.quote?.reviewToken == quote.reviewToken)
  ui.quote = nil
  #expect(ui.quote == nil)
}

private func verifyDispatchForgery(_ game: Game, id: UUID, state: ScriptInstance, reason: String) throws {
  var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
  var job = try #require(raw["contract"] as? [String: Any])
  var offer = try #require(job["offer"] as? [String: Any])
  var terms = try #require(offer["courier"] as? [String: Any])
  var custody = try #require(raw["courier"] as? [String: Any])
  var issue = try #require(custody["issue"] as? [String: Any])
  if ["owner", "origin", "receipt", "source"].contains(reason) {
    var facts = try #require(issue["originalOrigin"] as? [String: Any])
    var receipt = try #require(facts["receipt"] as? [String: Any])
    if reason == "owner" { receipt["commanderOwner"] = UUID().uuidString }
    else if reason == "receipt" { receipt["sequence"] = 0 }
    else {
      var station = try #require(receipt["station"] as? [String: Any])
      station[reason == "origin" ? "world" : "key"] = reason == "origin" ? UUID().uuidString : "foreign-source"
      receipt["station"] = station
    }
    facts["receipt"] = receipt
    issue["originalOrigin"] = facts
    custody["issue"] = issue
  } else if reason == "packet" { custody["item"] = UUID().uuidString }
  else if reason == "destination" { offer["destinationSystem"] = (state.contract!.offer.destinationSystem + 1) % 256 }
  else if reason == "seed" {
    var generation = try #require(terms["generation"] as? [String: Any])
    generation["initialState"] = 0
    terms["generation"] = generation
  } else if reason == "profile" {
    var declaration = try #require(terms["declaration"] as? [String: Any])
    declaration["profile"] = "foreign-profile"
    terms["declaration"] = declaration
  } else if reason == "early-terminal" {
    job["settled"] = true
    job["settlementOutcome"] = "abandoned"
    job["settlementAmount"] = 0
    job["settledAt"] = state.contract!.acceptedAt - 1
  } else {
    raw["id"] = UUID().uuidString // Duplicate original custody under a second instance identity.
  }
  offer["courier"] = terms
  job["offer"] = offer
  raw["contract"] = job
  raw["courier"] = custody
  let data = try JSONSerialization.data(withJSONObject: raw)
  do {
    let forged = try JSONDecoder().decode(ScriptInstance.self, from: data)
    var commander = game.commander
    if reason == "duplicate" { commander.scriptState.instances[forged.id] = forged }
    else { commander.scriptState.instances[id] = forged }
    #expect(!commander.valid && !commander.contractsValid)
  } catch is DecodingError {
    // A typed child refused malformed source/custody data before Commander validation.
  } catch SaveError.invalidCommander {
    // A closed current source/custody envelope refused the altered data.
  }
  #expect(game.commander.scriptState.instances[id] == state)
}

private func dispatchSaveFiles(_ root: URL) throws -> [String: Data] {
  let entries = try #require(FileManager.default.enumerator(atPath: root.path))
  var files: [String: Data] = [:]
  for case let relative as String in entries {
    let url = root.appendingPathComponent(relative)
    if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      files[relative] = try Data(contentsOf: url)
    }
  }
  return files
}
