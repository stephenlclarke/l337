import Foundation
import Testing

@testable import L337Core

@inline(never)
private func acceptedGalleryDispatch(_ fixture: OriginalSealedDispatchFixture) async throws
  -> (GameRuntime, UUID)
{
  let runtime = try await fixture.runtime(at: .salamander)
  let id = try await fixture.accept(runtime)
  return try await requireAcceptedGalleryDispatch(fixture, runtime: runtime, id: id)
}

@inline(never)
private func requireAcceptedGalleryDispatch(
  _ fixture: OriginalSealedDispatchFixture, runtime: GameRuntime, id: UUID
) async throws -> (GameRuntime, UUID) {
  let game = await runtime.snapshot()
  let state = try #require(game.commander.scriptState.instances[id])
  _ = try fixture.originalCargoBaseline(game.commander, sealedTonnes: 1)
  #expect(game.docked && game.nativeStationDockEvidenceIsCurrent && game.commander.valid)
  #expect(state.contract?.station == NativeOriginalSealedDispatchOrigin.station(for: .salamander))
  #expect(state.courier?.issue.originalOrigin?.receipt == game.commander.nativeStations?.ledger.currentDock)
  return (runtime, id)
}

@inline(never)
private func requireActualDockDurabilityAndResources(_ game: Game) {
  let opening = game
  let durable = game.requiresScriptDurability
  #expect(durable)
  #expect(game.currentNewtNativeCommanderMatches(opening))
  let energy = game.nativeStartupEnergy()
  let front = game.nativeStartupFrontShield()
  let rear = game.nativeStartupRearShield()
  #expect(game.energy == energy && energy == game.commander.performance.energy)
  #expect(game.frontShield == front && front == game.commander.shieldCapacity)
  #expect(game.rearShield == rear && rear == game.commander.rearShieldCapacity)
  #expect(game.currentNewtNativeCommanderMatches(opening))
}

private func selectDispatchForReading(_ game: inout Game, id: UUID) throws -> GalleryMission {
  game.openGallery()
  try #require(game.screen == .gallery)
  game.gallery.selection = try #require(game.missionCatalogue.firstIndex { $0.savedInstance == id })
  game.gallery.detail = true
  game.pinGallerySelection()
  return try #require(game.selectedGalleryMission)
}

@Test func actualOriginalDispatchCustodyIsReadableWithoutTrialOrServiceAuthority() async throws {
  let fixture = try OriginalSealedDispatchFixture()
  defer { fixture.files.clean() }
  let (runtime, id) = try await acceptedGalleryDispatch(fixture)
  try await readAcceptedDispatch(fixture, runtime: runtime, id: id)
}

@inline(never)
private func readAcceptedDispatch(
  _ fixture: OriginalSealedDispatchFixture, runtime: GameRuntime, id: UUID
) async throws {
  var game = await runtime.snapshot()
  let disk = try Data(contentsOf: fixture.save)
  let opening = game
  requireActualDockDurabilityAndResources(game)
  let state = try #require(opening.commander.scriptState.instances[id])
  let custody = try #require(state.courier)
  let job = try #require(state.contract)
  let row = try selectDispatchForReading(&game, id: id)
  #expect(row.status == .active && row.savedInstance == id && row.trialDigest == nil)
  #expect(game.commander.scriptState.instances[row.savedInstance!]?.courier?.item == custody.item)
  #expect(row.briefing.hasPrefix(job.offer.briefing) && row.briefing.contains("Sealed dispatch / H0 / Untimed"))
  let systems = Universe.systemsIncludingPlugh(number: job.offer.destinationGalaxy)
  let destination = systems[job.offer.destinationSystem].name
  #expect(row.destination == "Galaxy \(job.offer.destinationGalaxy + 1), " + destination)
  #expect(row.briefing.contains("Protected hold: 1t") && row.briefing.contains("Sealed Dispatch Receiving Officer"))
  #expect(row.briefing.contains(String(custody.item.uuidString.prefix(8))))
  #expect(!row.briefing.contains(custody.item.uuidString) && !row.briefing.contains(job.station.key))
  #expect(row.milestones.map(\.title) == fixture.pack.manifest.mission.milestones)
  #expect(row.milestones[0].state == "Complete" && row.milestones[1].state == "Upcoming")
  #expect(!game.canTrialSelectedMission && !game.canRetrySelectedGalleryEntry)
  #expect(game.campaignImmediateOwner == nil && game.selectedCampaignAssignments.isEmpty)
  #expect(game.scriptCourierAdmission == nil)
  #expect(game.galleryDetailLines(width: 480, font: GameTypography.scale).contains { $0.contains("Protected hold") })
  game.galleryKey("pagedown")
  #expect(game.currentNewtNativeCommanderMatches(opening))
  #expect(try Data(contentsOf: fixture.save) == disk)
  await runtime.key("screen:8")
  await runtime.key("0")
  game = await runtime.snapshot()
  try #require(!game.docked)
  let flying = game
  let flightBytes = try Data(contentsOf: fixture.save)
  let inFlight = try selectDispatchForReading(&game, id: id)
  #expect(inFlight.status == .active && inFlight.savedInstance == id && inFlight.trialDigest == nil)
  #expect(inFlight.milestones[0].state == "Complete" && inFlight.milestones[1].state == "Upcoming")
  #expect(inFlight.briefing.contains("Held") && game.commander.scriptState.instances[id]?.courier?.terminal == nil)
  #expect(!game.canTrialSelectedMission && !game.canRetrySelectedGalleryEntry)
  #expect(game.currentNewtNativeCommanderMatches(flying))
  #expect(try Data(contentsOf: fixture.save) == flightBytes)
}

@Test func actualOriginalAbandonmentHistoryKeepsSelectionThroughCatalogueReplacement() async throws {
  let fixture = try OriginalSealedDispatchFixture()
  defer { fixture.files.clean() }
  let (runtime, id) = try await acceptedGalleryDispatch(fixture)
  let issued = await runtime.snapshot()
  let baseline = try fixture.originalCargoBaseline(issued.commander, sealedTonnes: 1)
  try await fixture.contact(runtime, action: "Abandon")
  await fixture.confirm(runtime)
  var game = await runtime.snapshot()
  let before = game.commander
  let state = try #require(before.scriptState.instances[id])
  let bytes = try Data(contentsOf: fixture.save)
  let row = try selectDispatchForReading(&game, id: id)
  #expect(state.outcome == .abandoned && state.courier?.terminal?.cause == .abandoned)
  #expect(state.courier?.terminal?.item == issued.commander.scriptState.instances[id]?.courier?.item)
  #expect(state.courier?.terminal?.amount == 0 && before.credits == issued.commander.credits)
  #expect(before.scriptState.savedClueJournal == nil && before.cargoTonnes == baseline)
  #expect(row.status == .failed && row.objective.contains("abandoned"))
  #expect(row.briefing.contains("Paid: 0.0 CR") && row.briefing.contains("Abandoned"))
  #expect(row.milestones[0].state == "Complete" && row.milestones[1].state == "Upcoming")
  #expect(row.savedInstance == id && row.trialDigest == nil)
  let pinned = game.gallerySelectedEntryIdentity
  game.replaceMissionPacks(try .checked([]))
  #expect(game.gallerySelectedEntryIdentity == pinned)
  #expect(game.selectedGalleryMission?.savedInstance == id)
  game.galleryKey("return")
  game.galleryKey("escape")
  #expect(game.commander == before && game.commander.scriptState.instances[id] == state)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}

@Test func genuineOriginalMainArrivalAndConfirmedDeliveryProjectSeparateMilestones() async throws {
  let fixture = try OriginalSealedDispatchFixture()
  defer { fixture.files.clean() }
  let (runtime, id) = try await acceptedGalleryDispatch(fixture)
  let issued = await runtime.snapshot()
  let baseline = try fixture.originalCargoBaseline(issued.commander, sealedTonnes: 1)
  let terms = try #require(issued.commander.scriptState.instances[id]?.contract?.offer.courier)
  try await fixture.travel(runtime, path: terms.path)
  var game = await runtime.snapshot()
  let job = try #require(game.commander.scriptState.instances[id]?.contract)
  let ownedPreparationRequired1 = game.originalSealedDispatchReceiver(for: job)
  let arrival = try #require(ownedPreparationRequired1)
  #expect(game.acceptsNativeMainStationArrivalContext(arrival))
  let arrivalCommander = game.commander
  let arrivalBytes = try Data(contentsOf: fixture.save)
  let arrived = try selectDispatchForReading(&game, id: id)
  #expect(arrived.status == .active && arrived.savedInstance == id)
  #expect(arrived.milestones.map(\.title) == ["Collect original sealed record", "Confirm receiving officer handoff"])
  #expect(arrived.milestones[0].state == "Complete" && arrived.milestones[1].state == "Upcoming")
  #expect(game.commander.scriptState.instances[id]?.courier?.terminal == nil && game.commander.cargoTonnes == baseline + 1)
  #expect(game.commander.scriptState.savedClueJournal == nil && game.commander == arrivalCommander)
  #expect(try Data(contentsOf: fixture.save) == arrivalBytes)
  let arrivalPage = game.scriptGalleryPageIdentity
  try await fixture.contact(runtime, action: "Deliver")
  await fixture.confirm(runtime)
  game = await runtime.snapshot()
  let delivered = game.commander
  let state = try #require(delivered.scriptState.instances[id])
  let bytes = try Data(contentsOf: fixture.save)
  let row = try selectDispatchForReading(&game, id: id)
  let deliveryPage = game.scriptGalleryPageIdentity
  // Selection keeps the same saved mission; its changed controls invalidate the arrival page.
  #expect(deliveryPage.entry == arrivalPage.entry)
  #expect(deliveryPage.targets != arrivalPage.targets && deliveryPage != arrivalPage)
  #expect(row.status == .complete && row.savedInstance == id && row.completed == 2)
  #expect(row.milestones[0].title == "Collect original sealed record" && row.milestones[0].state == "Complete")
  #expect(row.milestones[1].title == "Confirm receiving officer handoff" && row.milestones[1].state == "Complete")
  #expect(row.objective.contains("actual receiving officer handoff") && row.objective.contains("once"))
  #expect(row.briefing.contains(String(format: "Paid: %.1f CR", Double(terms.reward) / 10)))
  #expect(
    state.courier?.terminal?.cause == .delivered
    && state.completionReceipt?.cause?.nativeMainDock == arrival.receipt)
  #expect(delivered.credits == arrivalCommander.credits + terms.reward && delivered.cargoTonnes == baseline)
  #expect(
    delivered.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID]?.clueID == "sealed-dispatch-family-trace")
  #expect(game.commander == delivered && game.commander.valid)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}
