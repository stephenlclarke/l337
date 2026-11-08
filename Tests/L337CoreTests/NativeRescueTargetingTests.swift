import Foundation
import Testing

@testable import L337Core

struct NativeRescueTargetingTests {
  @Test func tabActuallySelectsAndAutomaticallyCollectsOneOriginalProtectedPod() async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let game = try NativePeopleTestFixture.podApproach()
    let podCandidate = game.bodies.first { $0.physical?.empCrewPod != nil }
    let pod = try #require(podCandidate)
    let person = try #require(pod.physical?.empCrewPod)
    let actor = try #require(pod.physical?.identity)
    let kitReceipt = try #require(pod.physical?.currentNewtKitReceipt)
    let kitStock = try #require(
      game.commander.savedEMPState?.records[person.source]?.hull.body.physical?.currentNewtKitStock)
    try #require(kitStock.phase == .released && kitStock.receipt == kitReceipt)
    let kitSource = try #require(CurrentNewtKitSource.current)
    #expect(kitSource.matchesCharges(kitReceipt.remainingCharges,
      kitSource.charges(at: kitReceipt.releasedAt, actuation: kitReceipt.actuation)))
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    await runtime.key("tab")
    #expect(await runtime.snapshot().workGuidance?.parent == actor)
    #expect(await runtime.snapshot().workGuidance?.mode == .autoScoop(.salvage))
    for _ in 0..<6000 {
      if await runtime.snapshot().commander.rescuedPodTonnes > 0 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let collected = await runtime.snapshot()
    let admission = try #require(collected.commander.nativePeople?.heldPods.first)
    #expect(admission.person == .emp(person) && admission.actor == actor)
    #expect(
      collected.commander.cargo == game.commander.cargo && collected.commander.rescuedPodTonnes == 1
    )
    #expect(
      collected.commander.accommodation.people.isEmpty
        && collected.commander.accommodation.fitted.isEmpty)
    #expect(!collected.bodies.contains { $0.physical?.empCrewPod == person })
    let record = try #require(collected.commander.savedEMPState?.records[person.source])
    let podIndex = try #require(record.podIndex(for: person.ordinal))
    #expect(record.pods[podIndex].binding == nil)
    #expect(!collected.commander.worldOwnedPod(person))
    #expect(record.pods[podIndex].body.physical?.currentNewtKitReceipt == kitReceipt)
    let capturedStock = try #require(record.hull.body.physical?.currentNewtKitStock)
    #expect(capturedStock.issue == kitStock.issue && capturedStock.receipt == kitReceipt)
    #expect(capturedStock.charges.doesNotExceed(kitReceipt.remainingCharges))
    #expect(capturedStock.observedAt >= kitReceipt.releasedAt)
    #expect(capturedStock.serviceCapturedAt == admission.physicalTime)
    #expect(record.pods[podIndex].physicalTime == admission.physicalTime)
    #expect(kitSource.matchesCharges(capturedStock.charges,
      kitSource.charges(at: capturedStock.observedAt, actuation: kitReceipt.actuation,
        work: capturedStock.work, serviceCapturedAt: capturedStock.serviceCapturedAt)))
    #expect(collected.commander.valid)
    let emitted = try #require(record.podEjectionLowerBound(for: person.ordinal))
    try #require(emitted > record.disableIncident.physicalTime)
    let encoded = try JSONEncoder().encode(admission)
    var fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    fields["physicalTime"] = emitted - 0.0001
    let early = try JSONDecoder().decode(
      NativePeopleAdmission.self,
      from: JSONSerialization.data(withJSONObject: fields))
    #expect(!early.valid(commander: collected.commander))
    var forged = collected.commander
    let admissionIndexCandidate = forged.savedNativePeopleCustody?.admissions.firstIndex { $0.person == .emp(person) }
    let admissionIndex = try #require(admissionIndexCandidate)
    forged.savedNativePeopleCustody?.admissions[admissionIndex] = early
    #expect(!forged.nativePeopleStateValid && !forged.valid)
    for _ in 0..<40 { _ = await runtime.advance(delta: 0.05) }
    #expect(
      await runtime.snapshot().commander.nativePeople?.admissions.filter {
        $0.person == .emp(person)
      }.count == 1)
    #expect(await runtime.snapshot().bodies.contains { $0.physical?.empCrewPod == person } == false)
    var stationGame = await runtime.snapshot()
    try NativePeopleTestFixture.station(&stationGame)
    let receiver = GameRuntime(game: stationGame, saveURL: storage.url)
    try await ScriptFinanceTestFixture.enterMain(receiver)
    let cash = await receiver.snapshot().commander.credits
    try await NativePeopleTestFixture.confirm(receiver, row: .care(.rescuedPod))
    let received = await receiver.snapshot()
    #expect(received.commander.rescuedPodTonnes == 0 && received.commander.nativeCaptiveCount == 0)
    #expect(received.commander.nativePeople?.transfers.last?.members == [.emp(person)])
    #expect(received.commander.nativePeople?.transfers.last?.kind == .care)
    #expect(received.commander.credits == cash && received.commander.valid)
    let closedRecord = try #require(received.commander.savedEMPState?.records[person.source])
    #expect(closedRecord.pods[podIndex].body.physical?.currentNewtKitReceipt == kitReceipt)
    let closedStock = try #require(closedRecord.hull.body.physical?.currentNewtKitStock)
    #expect(closedStock.issue == kitStock.issue && closedStock.receipt == kitReceipt)
    #expect(closedStock.charges.doesNotExceed(capturedStock.charges))
    #expect(closedStock.serviceCapturedAt == capturedStock.serviceCapturedAt)
    #expect(closedRecord.pods[podIndex].physicalTime == admission.physicalTime)
    #expect(kitSource.matchesCharges(closedStock.charges,
      kitSource.charges(at: closedStock.observedAt, actuation: kitReceipt.actuation,
        work: closedStock.work, serviceCapturedAt: closedStock.serviceCapturedAt)))
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let restored = await reader.snapshot()
    let restoredRecord = try #require(restored.commander.savedEMPState?.records[person.source])
    #expect(restoredRecord.pods[podIndex].body.physical?.currentNewtKitReceipt == kitReceipt)
    #expect(restoredRecord.hull.body.physical?.currentNewtKitStock == closedStock)
    #expect(restored.commander.nativePeople == received.commander.nativePeople)
    #expect(restored.commander.valid && !restored.commander.worldOwnedPod(person))
  }

  @Test(arguments: ["module", "scoops", "hold", "core", "foreign"])
  func actualPodColourAndSelectionKeepIndependentHardwareAndCustodyRules(reason: String) throws {
    var game = try NativePeopleTestFixture.podApproach()
    let indexCandidate = game.bodies.firstIndex { $0.physical?.empCrewPod != nil }
    let index = try #require(indexCandidate)
    if reason == "module" { try game.commander.removeFittedEquipment("Targeting: Salvage Module") }
    if reason == "scoops" { try game.commander.removeFittedEquipment("Fuel Scoops") }
    if reason == "core" {
      try game.commander.removeFittedEquipment(TargetingTier.military.equipmentName)
    }
    if reason == "hold" { game.commander.cargo[0] = game.commander.standardCargoCapacity }
    if reason == "foreign" {
      let original = try #require(game.bodies[index].physical?.empCrewPod)
      game.bodies[index].physical?.empCrewPod = .init(source: original.source, ordinal: 255)
    }
    let body = game.bodies[index]
    let context = try #require(game.gameplayContext())
    let candidate = try #require(
      game.workTargetCandidate(for: body, context: context, frontVisible: true))
    let decision = WorkTargetSelection.evaluate(
      candidate, system: context.system, visit: context.visit,
      capabilities: game.workTargetCapabilities)
    #expect(decision.mode == nil)
    #expect(
      game.targetColourCue(for: body, context: context)
        == (reason == "foreign" ? .ordinary : .recoverable))
    #expect(game.commander.nativePeople == nil && game.commander.cargo[3] == 0)
  }

  @Test func failedAutomaticCollectionPreservesLivePodAndRecoverableController() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = GameRuntime(game: try NativePeopleTestFixture.podApproach(), saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    await runtime.key("tab")
    let parent = try #require(await runtime.snapshot().workGuidance?.parent)
    try storage.blockWriter()
    for _ in 0..<6000 {
      if await runtime.snapshot().message.contains("CAPTURE NOT SAVED") { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let failed = await runtime.snapshot()
    #expect(failed.message.contains("SAVE TO RETRY"))
    #expect(failed.commander.nativePeople == nil)
    let containsMatch = failed.bodies.contains { $0.physical?.identity == parent }
    #expect(containsMatch)
    #expect(failed.workGuidance?.parent == parent)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await runtime.save(to: storage.url)
    for _ in 0..<400 {
      if await runtime.snapshot().commander.rescuedPodTonnes > 0 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    #expect(await runtime.snapshot().commander.rescuedPodTonnes == 1)
  }
}
