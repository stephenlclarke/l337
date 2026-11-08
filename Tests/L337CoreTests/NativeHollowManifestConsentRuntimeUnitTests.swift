import Foundation
import Testing

@testable import L337Core

/// Actual producer-backed fixtures must succeed before negative assertions. Controlled location
/// is NOT a flown journey; no consent, source State, life gate, pin or receipt is injected here.
struct NativeHollowManifestConsentRuntimeUnitTests {
  @Test func pendingRequestSurvivesGenuineReadmissionOfTheSameOriginalCaptain() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let request = try await sendActualRequest(runtime)
    let review = await runtime.snapshot()
    await runtime.scriptPageKey("escape", expected: review.scriptPagePresentation)
    var game = await runtime.snapshot()
    let initial = try #require(game.hollowManifestMission?.savedHollowManifest)
    let player = try #require(game.commander.flightSimulation.player)
    let source = try game.hollowManifestConsentSource(slot: request.requestAdmission.slot)
    try #require(source.player == player && request.reply == nil)
    // Controlled scene turnover, not a flown journey. Retain the real originals first; the
    // existing native visit/admission producers must allocate and join their fresh addresses.
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    try game.restoreScriptActors()
    let current = try game.hollowManifestConsentSource(slot: request.requestAdmission.slot)
    try #require(current.player != player)
    try #require(current.admission.reference.revision > request.requestAdmission.revision)
    try #require(current.admission.original.actor != source.admission.original.actor)
    #expect(current.life.original == source.life.original)
    #expect(current.life.pin.state.birth == initial.birth)
    #expect(current.life.pin.state.consents.first?.request == request.request)
    #expect(current.life.pin.state.consents.first?.reply == nil)
    let other = try #require(game.c03LiveRouteInputs().originals.first {
      $0.slot != request.requestAdmission.slot
    })
    game.cancelAutoTarget()
    game.weaponsTargetID = other.owned.body.id
    let rebound = GameRuntime(game: game, saveURL: commission.files.save)
    try await rebound.save(to: commission.files.save)
    let wrongCaptain = await rebound.advance(delta: 0.05)
    #expect(wrongCaptain.hollowManifestMission?.savedHollowManifest?.consents.first?.reply == nil)
    try await rebound.scriptCommand { candidate in
      candidate.cancelAutoTarget()
      candidate.weaponsTargetID = current.owned.body.id
    }
    let beforeStep = await rebound.snapshot()
    #expect(beforeStep.hollowManifestMission?.savedHollowManifest?.consents.first?.reply == nil)
    let received = await rebound.advance(delta: 0.05)
    let history = try #require(received.hollowManifestMission?.savedHollowManifest?.consents.first)
    let reply = try #require(history.reply)
    #expect(history.request == request.request && history.requestAdmission == request.requestAdmission)
    #expect(history.replyAdmission == current.admission.reference)
    #expect(reply.decision == .granted && reply.physicalTime > request.request.physicalTime)
    #expect(history.revocation == nil)
    #expect(received.commander.credits == beforeStep.commander.credits)
    #expect(received.commander.equipmentInventory == beforeStep.commander.equipmentInventory)
    #expect(received.hollowManifestMission?.milestones == [0])
  }

  @Test func bothOriginalSealsNeedPriorGrantsAndSeparateActualMeasuredFrames() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let initial = await runtime.snapshot()
    let missionID = try #require(initial.hollowManifestMission).id
    for (index, slot) in NativeHollowManifestState.Slot.allCases.enumerated() {
      try await runtime.scriptCommand { game in
        // Controlled camera setup only. The actual source and nearest complete collision scene
        // must resolve the real original seal; no measurement or stage history is injected.
        let id = try aimAtActualHollowManifestSeal(&game, slot: slot)
        game.cancelAutoTarget()
        game.weaponsTargetID = id
        game.speed = 0
      }
      let aimed = await runtime.snapshot()
      #expect(aimed.hollowManifestInspectionSample() == nil)
      let request = try await sendActualRequest(runtime)
      let shown = await runtime.snapshot()
      await runtime.scriptPageKey("escape", expected: shown.scriptPagePresentation)
      let granted = await runtime.advance(delta: 0.05)
      let grantedState = try #require(granted.hollowManifestMission?.savedHollowManifest)
      let consent = try #require(grantedState.consents.first { $0.request == request.request })
      try #require(consent.reply?.decision == .granted)
      // The grant arrives after this frame's scan commit. It cannot backfill its start sample.
      #expect(grantedState.inspections.count == index)
      try #require(granted.hollowManifestInspectionSample() != nil)
      let scanned = await runtime.advance(delta: 0.05)
      let state = try #require(scanned.hollowManifestMission?.savedHollowManifest)
      try #require(state.inspections.count == index + 1)
      let inspection = try #require(state.inspections.first { $0.facts.admission.slot == slot })
      #expect(inspection.facts.evidence == .nativeSnapshotPair)
      #expect(inspection.facts.request == request.request.operation)
      #expect(inspection.facts.reply == consent.reply?.operation)
      #expect(inspection.facts.first.surfaceRanges.count == 12)
      #expect(inspection.facts.last.surfaceRanges.count == 12)
      #expect(inspection.facts.last.physicalTime > inspection.facts.first.physicalTime)
      #expect(inspection.facts.lastFrame == inspection.facts.firstFrame + 1)
      #expect(inspection.valid(in: state))
      let stored = try ScriptSaveStore.read(
        Data(contentsOf: commission.files.save), from: commission.files.save).0
      #expect(stored.scriptState.instances[missionID]?.savedHollowManifest?.inspections
        == state.inspections)
      let repeated = await runtime.advance(delta: 0.05)
      #expect(repeated.hollowManifestMission?.savedHollowManifest?.inspections == state.inspections)
      #expect(repeated.commander.credits == initial.commander.credits)
    }
    let complete = await runtime.snapshot()
    #expect(complete.hollowManifestMission?.milestones == [0, 1])
    #expect(complete.hollowManifestMission?.outcome == .active)
    #expect(complete.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    #expect(complete.hollowManifestMission?.gearIssues.isEmpty == true)
    #expect(complete.hollowManifestMission?.completionReceipt == nil)
  }

  @Test func bothOrdinaryHandoffRenderPathsKeepTheGenuineBlackjackFallback() {
    var game = Game(executive: false)
    game.screen = .handoff
    #expect(game.hollowManifestConsentReview == nil)
    #expect(Display.render(game) == Display.blackjackHandoff(game, width: 768, height: 768))
    for size in [512.0, 768.0, 1512.0] {
      #expect(Display.presentation(game, width: size, height: size)
        == Display.blackjackHandoff(game, width: size, height: size))
    }
  }

  @Test func bothRenderPathsPresentTheActualOriginalCaptainReview() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let original = try #require(game.c03LiveRouteInputs().originals.first)
    game.screen = .front
    game.weaponsTargetID = original.owned.body.id
    let runtime = GameRuntime(game: game)
    await runtime.missionUICommand(
      .init(action: .originalSealConsent, game: game, presentation: game.scriptPagePresentation))
    let shown = await runtime.snapshot()
    try #require(shown.screen == .handoff && shown.hollowManifestConsentReview != nil)
    #expect(Display.render(shown)
      == Display.hollowManifestConsentHandoff(shown, width: 768, height: 768))
    for size in [512.0, 768.0, 1512.0] {
      let frame = Display.presentation(shown, width: size, height: size)
      #expect(frame == Display.hollowManifestConsentHandoff(shown, width: size, height: size))
      #expect(frame.responsive && frame.canvas.width == size && frame.canvas.height == size)
      #expect(frame.labels.contains { $0.text == "ORIGINAL FREIGHTER CAPTAIN" })
    }
    #expect(shown.commander == game.commander)
  }

  @Test func epochChangeClearsTheActualReviewAndRejectsItsPaintedConfirm() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let front = await runtime.snapshot()
    let menu = MissionUIIntent(
      action: .originalSealConsent, game: front, presentation: front.scriptPagePresentation)
    try #require(menu.isCurrent(in: front))
    await runtime.missionUICommand(menu)
    let shown = await runtime.snapshot()
    try #require(shown.hollowManifestConsentReview?.requestAvailable == true)
    await runtime.nativeCommand { game in
      game.nativeC03AttainedMotion = .refused(.unsupportedScene)
      game.nativeStationRuntimeEpoch = UUID()
    }
    let invalidated = await runtime.snapshot()
    #expect(invalidated.hollowManifestConsentReview == nil)
    if case .some = invalidated.nativeC03AttainedMotion {
      Issue.record("An epoch change retained an old C03 motion result.")
    }
    if case .some = invalidated.nativeC03MotionPending {
      Issue.record("An epoch change retained an old C03 motion sample.")
    }
    #expect(invalidated.commander == shown.commander)
    await runtime.scriptPageKey("return", expected: shown.scriptPagePresentation)
    await runtime.missionUICommand(menu)
    let refused = await runtime.snapshot()
    #expect(refused.commander == shown.commander && refused.hollowManifestConsentReview == nil)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.consents.isEmpty == true)
  }

  @Test func requestWriterRefusalUsesItsOwnTransactionAndPreservesTheReviewForRetry() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let front = await runtime.snapshot()
    await runtime.missionUICommand(
      .init(action: .originalSealConsent, game: front, presentation: front.scriptPagePresentation))
    let shown = await runtime.snapshot()
    try #require(shown.hollowManifestConsentReview?.requestAvailable == true)
    await runtime.scriptPageKey("right", expected: shown.scriptPagePresentation)
    let chosen = await runtime.snapshot()
    try #require(chosen.hollowManifestConsentReview?.button == .request)
    let directory = commission.files.save.deletingLastPathComponent()
    let backup = commission.files.root.appendingPathComponent("before-request-save")
    let bytes = try Data(contentsOf: commission.files.save)
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked request writer".utf8).write(to: directory)
    await runtime.scriptPageKey("return", expected: chosen.scriptPagePresentation)
    let refused = await runtime.snapshot()
    #expect(refused.message == "REQUEST NOT COMMITTED - REVIEW THE CURRENT CONTACT AND SAVE")
    #expect(refused.commander == chosen.commander && refused.bodies == chosen.bodies)
    #expect(refused.hollowManifestConsentReview?.nonce == chosen.hollowManifestConsentReview?.nonce)
    #expect(refused.hollowManifestConsentReview?.button == .request)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.consents.isEmpty == true)
    #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    await runtime.scriptPageKey("return", expected: refused.scriptPagePresentation)
    let sent = await runtime.snapshot()
    let requests = try #require(sent.hollowManifestMission?.savedHollowManifest?.consents)
    #expect(requests.count == 1 && requests[0].reply == nil && requests[0].revocation == nil)
    #expect(sent.hollowManifestConsentReview?.historical == requests[0])
    #expect(sent.commander.credits == chosen.commander.credits)
    #expect(sent.commander.equipmentInventory == chosen.commander.equipmentInventory)
  }

  @Test func ordinaryForeignTargetCannotBecomeAnOriginalCaptainContact() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.screen = .front
    game.weaponsTargetID = game.bodies[index].id
    let before = game.commander
    #expect(throws: NativeHollowManifestConsentFailure.self) {
      try game.makeHollowManifestConsentReview()
    }
    #expect(game.commander == before)
  }

  @Test func genuineReviewDefaultsBackAndCannotIssueARequestOrCaptainReply() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    let original = try #require(inputs.originals.first)
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = original.owned.body.id
    let before = game.commander
    let bodies = game.bodies
    let review = try game.makeHollowManifestConsentReview()
    #expect(review.button == .back && review.slot == original.slot)
    #expect(review.historical == nil)
    #expect(throws: NativeHollowManifestConsentFailure.requestUnavailable) {
      try game.prepareHollowManifestConsentRequest(review)
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func absentRealTargetingItemIsAnOpenContractIssueWithoutAReplacementUUID() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    let original = try #require(inputs.originals.first)
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    try #require(game.commander.fittedEquipment(at: .targetingCore) == nil)
    game.screen = .front
    game.weaponsTargetID = original.owned.body.id
    let before = game.commander
    let review = try game.makeHollowManifestConsentReview()
    #expect(
      !review.requestAvailable
        && review.issues.contains { $0.contains("current equipment cannot send") })
    game.screen = .handoff
    #expect(throws: NativeHollowManifestConsentFailure.requestUnavailable) {
      try game.prepareHollowManifestConsentRequest(review.selecting(.request))
    }
    #expect(game.commander == before)
    #expect(game.commander.fittedEquipment(at: .targetingCore) == nil)
  }

  @Test func explicitMenuOpensOnlyThePaintedReviewAndBackLeavesNoSourceEffects() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    let original = try #require(inputs.originals.first)
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = original.owned.body.id
    let before = game.commander
    let runtime = GameRuntime(game: game)
    let intent = MissionUIIntent(
      action: .originalSealConsent, game: game,
      presentation: game.scriptPagePresentation)
    try #require(intent.isCurrent(in: game))
    await runtime.missionUICommand(intent)
    let shown = await runtime.snapshot()
    try #require(shown.screen == .handoff && shown.hollowManifestConsentReview?.button == .back)
    guard case .hollowManifestConsent? = shown.scriptPagePresentation.page else {
      Issue.record("Explicit consent review must have its own painted page identity")
      return
    }
    #expect(shown.commander == before)
    await runtime.scriptPageKey("return", expected: shown.scriptPagePresentation)
    let closed = await runtime.snapshot()
    #expect(closed.screen == .front && closed.hollowManifestConsentReview == nil)
    #expect(closed.commander == before)
  }

  @Test func capturedMenuIntentRejectsAChangedPhysicalTarget() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = inputs.originals[0].owned.body.id
    let intent = MissionUIIntent(
      action: .originalSealConsent, game: game,
      presentation: game.scriptPagePresentation)
    try #require(intent.isCurrent(in: game))
    game.weaponsTargetID = inputs.originals[1].owned.body.id
    #expect(!intent.isCurrent(in: game))
    let runtime = GameRuntime(game: game)
    await runtime.missionUICommand(intent)
    let after = await runtime.snapshot()
    #expect(after.screen == .front && after.hollowManifestConsentReview == nil)
  }

  @Test func oldPaintedReviewCannotClickAReopenedContact() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = inputs.originals[0].owned.body.id
    let runtime = GameRuntime(game: game)
    await runtime.missionUICommand(
      .init(
        action: .originalSealConsent, game: game,
        presentation: game.scriptPagePresentation))
    let first = await runtime.snapshot()
    try #require(first.hollowManifestConsentReview != nil)
    await runtime.scriptPageKey("escape", expected: first.scriptPagePresentation)
    let front = await runtime.snapshot()
    await runtime.missionUICommand(
      .init(
        action: .originalSealConsent, game: front,
        presentation: front.scriptPagePresentation))
    let second = await runtime.snapshot()
    try #require(second.hollowManifestConsentReview != nil)
    #expect(first.scriptPagePresentation != second.scriptPagePresentation)
    await runtime.scriptPageClick(
      x: second.viewportWidth * 0.7,
      y: second.viewportHeight - 40, expected: first.scriptPagePresentation)
    let after = await runtime.snapshot()
    #expect(after.screen == .handoff)
    #expect(after.hollowManifestConsentReview?.nonce == second.hollowManifestConsentReview?.nonce)
    #expect(after.commander == second.commander)
  }

  @Test func heldFlightFireCannotOpenAnImplicitConsentMode() async throws {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = inputs.originals[0].owned.body.id
    let intent = MissionUIIntent(
      action: .originalSealConsent, game: game,
      presentation: game.scriptPagePresentation)
    try #require(intent.isCurrent(in: game))
    let runtime = GameRuntime(game: game)
    var held = Controls()
    held.fire = true
    await runtime.setControls(held)
    await runtime.missionUICommand(intent)
    let after = await runtime.snapshot()
    #expect(after.screen == .front && after.hollowManifestConsentReview == nil)
    #expect(after.commander == game.commander)
  }

  @Test(arguments: [false, true])
  func noPendingReplyDoesNotFlushUnrelatedWorkOrPublishACommander(noCurrentContact: Bool)
    async throws
  {
    var (game, commission) = try await actualHollowManifestFreighterRootFixture()
    defer { commission.clean() }
    let inputs = game.c03LiveRouteInputs()
    try #require(inputs.pin != nil && inputs.originals.count == 2)
    game.screen = .front
    game.weaponsTargetID = inputs.originals[0].owned.body.id
    try #require((try game.makeHollowManifestConsentReview()).historical == nil)
    if noCurrentContact {
      game.weaponsTargetID = nil
      try #require(game.informationTargetBody == nil)
    }
    // Existing unrelated work publication seam: the old unconditional scriptCommand would
    // publish and clear this dirty flag even though consent has no new fact to retain.
    game.inductionUtilityWorkRuntime.dirty = true
    let before = game.commander
    let bodies = game.bodies
    let bytes = try Data(contentsOf: commission.files.save)
    let runtime = GameRuntime(game: game, saveURL: commission.files.save)
    await runtime.beginScriptRefusalObservation()
    await runtime.receiveHollowManifestConsentAfterPhysics(
      delta: 0.1, startTime: game.commander.flightSimulation.physicalTime - 0.1,
      startPlayer: game.commander.flightSimulation.player)
    let after = await runtime.snapshot()
    #expect(after.inductionUtilityWorkRuntime.dirty)
    #expect(after.commander == before && after.bodies == bodies)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
    #expect(await runtime.scriptRefusalObservationDetail() == nil)
  }

  /// Requires the current genuine issuer purchase; test budget is labelled by the shared fixture.
  private func paidContactRuntime() async throws -> (
    runtime: GameRuntime, commission: HollowManifestCommissionFixture
  ) {
    let actual = try await actualHollowManifestFreighterRootFixture(targeting: .basic)
    do {
      var game = actual.game
      let inputs = game.c03LiveRouteInputs()
      try #require(inputs.pin != nil && inputs.originals.count == 2)
      let item = try #require(game.commander.fittedEquipment(at: .targetingCore))
      let paid = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
      try #require(item.node.key == TargetingTier.basic.equipmentName)
      try #require(paid.binding.request.newItem == item.id && paid.node == item.node)
      game.screen = .front
      game.cancelAutoTarget()
      game.weaponsTargetID = inputs.originals[0].owned.body.id
      try #require(game.informationTargetBody?.id == inputs.originals[0].owned.body.id)
      let runtime = GameRuntime(game: game, saveURL: actual.commission.files.save)
      try await runtime.save(to: actual.commission.files.save)
      return (runtime, actual.commission)
    } catch {
      actual.commission.clean()
      throw error
    }
  }

  private func sendActualRequest(_ runtime: GameRuntime) async throws
    -> NativeHollowManifestState.Consent
  {
    let front = await runtime.snapshot()
    try #require(front.screen == .front)
    let review = try front.makeHollowManifestConsentReview()
    try #require(review.requestAvailable && review.historical == nil)
    await runtime.missionUICommand(
      .init(
        action: .originalSealConsent, game: front,
        presentation: front.scriptPagePresentation))
    let shown = await runtime.snapshot()
    try #require(shown.hollowManifestConsentReview?.button == .back)
    await runtime.scriptPageKey("right", expected: shown.scriptPagePresentation)
    let chosen = await runtime.snapshot()
    try #require(chosen.hollowManifestConsentReview?.button == .request)
    await runtime.scriptPageKey("return", expected: chosen.scriptPagePresentation)
    let sent = await runtime.snapshot()
    let consent = try #require(sent.hollowManifestConsentReview?.historical)
    try #require(sent.screen == .handoff && consent.reply == nil && consent.revocation == nil)
    try #require(
      consent.request.targetingEquipment == sent.commander.fittedEquipment(at: .targetingCore)?.id)
    return consent
  }

  @Test func actualPaidItemAndExplicitRequestNeedLaterFlightContactForEachCaptainReply()
    async throws
  {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let initial = await runtime.snapshot()
    let receipts = try #require(initial.hollowManifestMission?.receipts)
    let milestones = try #require(initial.hollowManifestMission?.milestones)
    for slot in NativeHollowManifestState.Slot.allCases {
      try await runtime.scriptCommand { game in
        let source = try game.hollowManifestConsentSource(slot: slot)
        game.cancelAutoTarget()
        game.weaponsTargetID = source.owned.body.id
        try #require(game.informationTargetBody?.id == source.owned.body.id)
      }
      let pending = try await sendActualRequest(runtime)
      let review = await runtime.snapshot()
      let waiting = await runtime.advance(delta: 0.1)
      #expect(
        waiting.commander.flightSimulation.physicalTime
          == review.commander.flightSimulation.physicalTime)
      #expect(waiting.hollowManifestConsentReview?.historical == pending)
      await runtime.scriptPageKey("escape", expected: waiting.scriptPagePresentation)
      let granted = await runtime.advance(delta: 0.1)
      let history = try #require(
        granted.hollowManifestMission?.savedHollowManifest?.consents
          .first { $0.request.operation == pending.request.operation })
      let reply = try #require(history.reply)
      #expect(reply.decision == .granted && reply.physicalTime > pending.request.physicalTime)
      #expect(history.request == pending.request && history.revocation == nil)
      let stored = try ScriptSaveStore.read(
        Data(contentsOf: commission.files.save),
        from: commission.files.save)
      let mission = try #require(granted.hollowManifestMission).id
      #expect(
        stored.0.scriptState.instances[mission]?.savedHollowManifest?.consents
          .contains(history) == true)
      let repeated = await runtime.advance(delta: 0.1)
      #expect(
        repeated.hollowManifestMission?.savedHollowManifest?.consents.contains(history) == true)
      #expect(repeated.hollowManifestMission?.receipts == receipts)
      #expect(repeated.hollowManifestMission?.milestones == milestones)
    }
    let both = await runtime.snapshot()
    #expect(both.hollowManifestMission?.savedHollowManifest?.consents.count == 2)
  }

  @Test func alreadyRepliedCaptainDoesNotFlushUnrelatedPendingWork() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let pending = try await sendActualRequest(runtime)
    let review = await runtime.snapshot()
    await runtime.scriptPageKey("escape", expected: review.scriptPagePresentation)
    var granted = await runtime.advance(delta: 0.1)
    try #require(
      granted.hollowManifestMission?.savedHollowManifest?.consents
        .first { $0.request == pending.request }?.reply?.decision == .granted)
    granted.inductionUtilityWorkRuntime.dirty = true
    let bytes = try Data(contentsOf: commission.files.save)
    let idle = GameRuntime(game: granted, saveURL: commission.files.save)
    await idle.receiveHollowManifestConsentAfterPhysics(
      delta: 0.1,
      startTime: granted.commander.flightSimulation.physicalTime - 0.1,
      startPlayer: granted.commander.flightSimulation.player)
    let after = await idle.snapshot()
    #expect(after.inductionUtilityWorkRuntime.dirty)
    #expect(after.commander == granted.commander && after.bodies == granted.bodies)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
  }

  @Test(arguments: ["target", "body", "epoch", "zero-step", "wrong-start-player"])
  func genuinePendingReplyPreflightAndInstallRefuseStaleOrInactiveInput(reason: String)
    async throws
  {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    _ = try await sendActualRequest(runtime)
    let review = await runtime.snapshot()
    await runtime.scriptPageKey("escape", expected: review.scriptPagePresentation)
    var game = await runtime.snapshot()
    let start = game.commander.flightSimulation
    // Run actual native physics and capture but stop before the actor's consent receive.
    game.tick(delta: 0.1)
    try game.persistScriptActorsChecked()
    try game.restoreScriptActors()
    let prepared = try #require(
      game.prepareHollowManifestConsentReply(
        delta: 0.1,
        startTime: start.physicalTime, startPlayer: start.player))
    if reason == "zero-step" || reason == "wrong-start-player" {
      let delta = reason == "zero-step" ? 0.0 : 0.1
      let player = reason == "wrong-start-player" ? nil : start.player
      #expect(
        try game.prepareHollowManifestConsentReply(
          delta: delta,
          startTime: start.physicalTime, startPlayer: player) == nil)
      game.inductionUtilityWorkRuntime.dirty = true
      let unchanged = game.commander
      let bodies = game.bodies
      let bytes = try Data(contentsOf: commission.files.save)
      let idle = GameRuntime(game: game, saveURL: commission.files.save)
      await idle.beginScriptRefusalObservation()
      await idle.receiveHollowManifestConsentAfterPhysics(
        delta: delta,
        startTime: start.physicalTime, startPlayer: player)
      let after = await idle.snapshot()
      #expect(after.inductionUtilityWorkRuntime.dirty)
      #expect(after.commander == unchanged && after.bodies == bodies)
      #expect(try Data(contentsOf: commission.files.save) == bytes)
      #expect(await idle.scriptRefusalObservationDetail() == nil)
      return
    }
    if reason == "target" {
      game.cancelAutoTarget()
      game.weaponsTargetID = nil
    } else if reason == "epoch" {
      game.nativeStationRuntimeEpoch = UUID()
    } else {
      let target = try #require(game.informationTargetBody)
      let index = try #require(game.bodies.firstIndex { $0.id == target.id })
      game.bodies[index].position.x += 1
    }
    let before = game.commander
    let bodies = game.bodies
    #expect(throws: (any Error).self) { try game.installHollowManifestConsentReply(prepared) }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func actualReplyWriterFailureKeepsTheRequestAndEarlierPhysicalStep() async throws {
    let (runtime, commission) = try await paidContactRuntime()
    defer { commission.clean() }
    let pending = try await sendActualRequest(runtime)
    let shown = await runtime.snapshot()
    await runtime.scriptPageKey("escape", expected: shown.scriptPagePresentation)
    let before = await runtime.snapshot()
    let directory = commission.files.save.deletingLastPathComponent()
    let backup = commission.files.root.appendingPathComponent("before-reply-save")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked reply writer".utf8).write(to: directory)
    await runtime.beginScriptRefusalObservation()
    let refused = await runtime.advance(delta: 0.1)
    try #require(
      refused.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    try #require(
      try refused.prepareHollowManifestConsentReply(
        delta: 0.1,
        startTime: before.commander.flightSimulation.physicalTime,
        startPlayer: before.commander.flightSimulation.player) != nil)
    #expect(
      refused.hollowManifestMission?.savedHollowManifest?.consents
        .first { $0.request == pending.request }?.reply == nil)
    let diagnostic = try #require(await runtime.scriptRefusalObservationDetail())
    #expect(diagnostic.contains("publication="))
    #expect(refused.message == "CAPTAIN REPLY NOT RETAINED - SAVE FAILED")
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    let retried = await runtime.advance(delta: 0.1)
    #expect(
      retried.hollowManifestMission?.savedHollowManifest?.consents
        .first { $0.request == pending.request }?.reply?.decision == .granted)
  }

}
