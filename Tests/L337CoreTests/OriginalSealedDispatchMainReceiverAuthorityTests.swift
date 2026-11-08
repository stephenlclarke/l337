import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalSealedDispatchMainReceiverAuthorityTests {
  @Test(arguments: [false, true])
  func booleanMainDockCannotMintOriginalDeliveryAuthorityAtCorrectDestination(
    originalOrigin: Bool
  ) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime: GameRuntime
    if originalOrigin {
      runtime = try await fixture.runtime(at: .salamander)
    } else {
      runtime = try await fixture.runtime()
    }
    let id = try await fixture.accept(runtime)
    let terms = try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    try await fixture.contact(runtime, action: "Deliver")
    let arrived = await runtime.snapshot()
    let dialogue = try #require(arrived.scriptPresentedDialogue)
    let arrival = try #require(arrived.commander.nativeStations?.currentMainDock)
    try #require(arrived.nativeMainStationDockEvidenceIsCurrent)
    #expect(arrived.commander.galaxy == terms.generation.origin.galaxy)
    #expect(arrived.commander.system == terms.destination)

    // Keep the correct destination and dock flags. Neither flags nor retained data grant arrival.
    for retainReceipt in [false, true] {
      var unproved = arrived
      unproved.nativeMainStationDockEvidence = nil
      if !retainReceipt { unproved.commander.nativeStations?.currentMainDock = nil }
      let before = unproved.commander
      #expect(unproved.docked && unproved.dockedAtMainStation)
      #expect(unproved.commander.system == terms.destination)
      let unprovedState = try #require(unproved.commander.scriptState.instances[id])
      #expect(!unproved.courierDialogueStationIsCurrent(unprovedState, contact: dialogue.id))
      #expect(throws: (any Error).self) {
        try unproved.confirmCourierDialogue(id, dialogue: dialogue)
      }
      #expect(unproved.commander == before && unproved.scriptCourierAdmission == nil)
    }

    // The fixture's actual MAIN entry and real writer remain the positive authority.
    await fixture.confirm(runtime)
    let delivered = await runtime.snapshot()
    let state = try #require(delivered.commander.scriptState.instances[id])
    let completion = try #require(state.completionReceipt)
    #expect(state.outcome == .complete && state.courier?.terminal?.amount == terms.reward)
    #expect(delivered.commander.credits == arrived.commander.credits + terms.reward)
    #expect(completion.cause?.nativeMainDock == arrival)
    #expect(completion.committed.nativeMainDock == arrival)
    #expect(delivered.commander.contractsValid && delivered.commander.valid)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: fixture.save)
    #expect(persisted.scriptState.instances[id]?.completionReceipt?.cause?.nativeMainDock == arrival)

    for form in ["missing", "null", "ownerWorld", "resource", "sequence", "visit", "calendar"] {
      var raw = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
      var terminal = try #require(raw["completionReceipt"] as? [String: Any])
      let cause = try #require(terminal["cause"] as? [String: Any])
      var receipt = try #require(cause["nativeMainDock"] as? [String: Any])
      if form == "ownerWorld" {
        let foreign = UUID().uuidString
        receipt["commanderOwner"] = foreign
        var station = try #require(receipt["station"] as? [String: Any])
        station["world"] = foreign
        receipt["station"] = station
      } else if form == "resource" {
        var station = try #require(receipt["station"] as? [String: Any])
        station["resource"] = UUID().uuidString
        receipt["station"] = station
      } else if form == "sequence" {
        receipt["sequence"] = try #require(delivered.commander.nativeStations?.nextMainDockSequence)
      } else if form == "visit" {
        var actor = try #require(receipt["actor"] as? [String: Any])
        actor["visit"] = delivered.commander.flightSimulation.visit + 1
        receipt["actor"] = actor
      } else if form == "calendar" {
        receipt["calendarSeconds"] = try #require(completion.cause?.calendarSeconds) + 1
      }
      // Change both historical copies to test owner/world joins beyond copy equality.
      for key in ["cause", "committed"] {
        var context = try #require(terminal[key] as? [String: Any])
        if form == "missing" { context.removeValue(forKey: "nativeMainDock") }
        else if form == "null" { context["nativeMainDock"] = NSNull() }
        else { context["nativeMainDock"] = receipt }
        terminal[key] = context
      }
      raw["completionReceipt"] = terminal
      let data = try JSONSerialization.data(withJSONObject: raw)
      do {
        let altered = try JSONDecoder().decode(ScriptInstance.self, from: data)
        var historical = delivered.commander
        historical.scriptState.instances[id] = altered
        #expect(!historical.contractsValid)
      } catch {
        // A closed decoder may reject malformed retained receipt data before owner validation.
      }
    }
    var replay = delivered
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander.credits == delivered.commander.credits)
    #expect(replay.commander.scriptState.savedClueJournal == delivered.commander.scriptState.savedClueJournal)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander.contractsValid)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.completionReceipt == completion)
  }
}
