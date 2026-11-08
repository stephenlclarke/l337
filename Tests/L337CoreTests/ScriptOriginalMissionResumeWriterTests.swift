import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct ScriptOriginalMissionResumeWriterTests {
  @Test func genuineSealedDispatchResumeRequiresBoundWriterAndPersistsSameCustodyAfterRetry()
    async throws
  {
    let f = try OriginalSealedDispatchFixture()
    defer { f.files.clean() }
    // The calibrated starter cannot fit Salamander. Earn and pay for the actual smaller hull.
    // One existing physical root keeps every acquisition, docking and refusal on f.save.
    let storage = NativeStationTestStorage(root: f.files.root)
    try #require(storage.url == f.save)
    let runtime = try await NativeOkapiAcquisitionJourneyFixture.purchasedRuntime(storage: storage)
    let owned = await runtime.snapshot()
    let owner = try #require(owned.commander.equipmentOwnerID)
    let station = OriginalStationSite.salamander.identity(world: owner)
    let source = try #require(NativeStationSource.binding(for: station))
    try #require(owned.commander.shipID == "SH029" && owned.commander.nativeCrewMissing == 0)
    try #require(source.geometry.docking.fits(owned.commander.playerMesh))
    // Close the actual captured-person custody before launch. The original acquisition
    // deliberately retains it, and launching with those cargo units incurs the normal law.
    let capturedPeople = try #require(owned.commander.nativePeople)
    let captives = capturedPeople.heldCaptives.map(\.person)
    try #require(!captives.isEmpty,
      "The actual acquisition must retain captured crew before this care transfer.")
    try #require(owned.nativeMainStationDockEvidenceIsCurrent)
    try #require(owned.commander.legal == 0,
      "Pre-care legal status is \(owned.commander.legal), cargo is \(owned.commander.cargo).")
    try #require(owned.commander.cargo[CommodityIdentity.slaves.rawValue] == captives.count)
    try await NativePeopleTestFixture.confirm(runtime, row: .care(.capturedCrew))
    let cared = await runtime.snapshot()
    let receipt = try #require(cared.commander.nativePeople?.transfers.last)
    try #require(receipt.kind == .care && Set(receipt.members) == Set(captives))
    try #require(receipt.dock != nil && receipt.dock == owned.commander.nativeStations?.currentMainDock)
    try #require(cared.commander.nativePeople?.heldCaptives.isEmpty == true)
    try #require(cared.commander.nativePeople?.admissions == capturedPeople.admissions)
    let caredPeople = try #require(cared.commander.nativePeople)
    try #require(Array(caredPeople.transfers.dropLast()) == capturedPeople.transfers)
    var expectedCargo = owned.commander.cargo
    expectedCargo[CommodityIdentity.slaves.rawValue] -= captives.count
    try #require(cared.commander.cargo == expectedCargo)
    try #require(cared.commander.credits == owned.commander.credits)
    try #require(cared.commander.legal == owned.commander.legal)
    try #require(cared.commander.equipmentInventory == owned.commander.equipmentInventory)
    try #require(cared.commander.hullInstanceID == owned.commander.hullInstanceID)
    try #require(cared.commander.nativeCrewMissing == 0)
    try #require(cared.commander.savedEMPState == owned.commander.savedEMPState)
    try #require(cared.commander.fleetBlueprintAcquisition(for: "SH029")
      == owned.commander.fleetBlueprintAcquisition(for: "SH029"))
    for commodity in [CommodityIdentity.slaves, .narcotics, .firearms] {
      try #require(cared.commander.cargo[commodity.rawValue] == 0,
        "Actual launch cargo retains \(commodity.name): \(cared.commander.cargo).")
    }
    // Paid navigation provides whole-galaxy route knowledge. Every hop still obeys actual fuel.
    try await NativeOkapiAcquisitionJourneyFixture.purchasePaidEquipment(
      NavigationTier.military.equipmentName, runtime: runtime)
    await runtime.procurementRefuel()
    let ready = await runtime.snapshot()
    try #require(ready.commander.navigationTier == .military)
    let path = try #require(NavigationGraph(game: ready).path(from: ready.commander.system,
      to: OriginalStationSite.salamander.system.system, fuel: ready.commander.availableJumpFuel,
      scoring: 0))
    let installed = f.files.root.appendingPathComponent("resume-library", isDirectory: true)
    try await runtime.installScriptPack(
      from: ScriptPackLibrary.bundledSealedDispatchDirectory, destination: installed)
    let flightDiagnostic = ScriptProcurementFlightDiagnostic(label: "owned-sealed-resume")
    try await ScriptProcurementFixture.travel(runtime, path: path, diagnostic: flightDiagnostic,
      verifyDeparture: true,
      selectionDiagnostic: .init(label: "earned Okapi route to Salamander"))
    // Travel leaves the final leg's spent fuel untouched. Buy the next departure's
    // fuel at the genuine main berth before moving to Salamander's mission source.
    let turnaround = await runtime.snapshot()
    try #require(turnaround.nativeMainStationDockEvidenceIsCurrent)
    try #require(turnaround.commander.fuel < turnaround.commander.fuelCapacity,
      "Actual arrival fuel is \(turnaround.commander.fuel)/\(turnaround.commander.fuelCapacity).")
    try await runtime.procurementRefuelForTurnaround(
      expectedSystem: OriginalStationSite.salamander.system.system)
    try await f.dock(runtime, at: .salamander)
    let arrived = await runtime.snapshot()
    try #require(arrived.nativeStationDockEvidenceIsCurrent && !arrived.dockedAtMainStation)
    try #require(arrived.commander.hullInstanceID == owned.commander.hullInstanceID)
    try #require(arrived.commander.fleetBlueprintAcquisition(for: "SH029")
      == owned.commander.fleetBlueprintAcquisition(for: "SH029"))
    try #require(arrived.commander.fuel == arrived.commander.fuelCapacity)
    try #require(arrived.commander.legal == 0)
    let id = try await f.accept(runtime)
    let accepted = await runtime.snapshot()
    let original = try #require(accepted.commander.scriptState.instances[id])
    try #require(original.outcome == .active && original.courier != nil)
    try #require(original.suspension == nil)
    let missing = f.files.root.appendingPathComponent("missing-library", isDirectory: true)
    // The actual unavailable-content reader creates the suspension. No test writes
    // a case, package, suspension flag or fake receiving/source receipt.
    await runtime.loadScriptPacks(directory: missing)
    try #require(await runtime.snapshot().commander.scriptState.instances[id]?.suspension != nil)
    try await runtime.save(to: f.save)
    try await runtime.installScriptPack(
      from: ScriptPackLibrary.bundledSealedDispatchDirectory, destination: installed)
    let restoredContent = await runtime.snapshot()
    let suspended = try #require(restoredContent.commander.scriptState.instances[id])
    try #require(suspended.suspension != nil && suspended.outcome == .active)
    try #require(restoredContent.scriptPack(for: suspended)?.digest == f.pack.digest)
    try #require(restoredContent.commander.scriptState.pendingEvents.isEmpty)
    #expect(suspended.courier == original.courier && suspended.contract == original.contract)

    // This is an actual accepted snapshot with content restored, but deliberately
    // no save URL. It cannot silently publish a resumed case in memory.
    let unbound = GameRuntime(game: restoredContent)
    let unboundBefore = await unbound.snapshot()
    try #require(!unboundBefore.scriptDurabilityAvailable && unboundBefore.requiresScriptDurability)
    try #require(unboundBefore.commander.scriptState.instances[id]?.suspension != nil)
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    await #expect(throws: MissionPackError.self) { try await unbound.resumeScriptMission(id) }
    let denied = await unbound.snapshot()
    #expect(denied.commander == unboundBefore.commander)
    #expect(denied.scriptWorldSave == unboundBefore.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent()) == files)

    let before = await runtime.snapshot()
    let held = try f.files.blockWrites("sealed-dispatch-resume")
    await #expect(throws: (any Error).self) { try await runtime.resumeScriptMission(id) }
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.scriptWorldSave == before.scriptWorldSave)
    #expect(refused.commander.scriptState.instances[id]?.suspension == suspended.suspension)
    try f.files.restoreWrites(held, files: files)
    try await runtime.resumeScriptMission(id)
    let resumed = await runtime.snapshot()
    let instance = try #require(resumed.commander.scriptState.instances[id])
    try #require(instance.suspension == nil && instance.outcome == .active)
    #expect(instance.courier == suspended.courier && instance.contract == suspended.contract)
    #expect(instance.receipts == suspended.receipts && instance.milestones == suspended.milestones)
    #expect(instance.completionReceipt == nil)
    #expect(resumed.commander.scriptState.pendingEvents.isEmpty)
    #expect(resumed.commander.credits == before.commander.credits)
    #expect(resumed.commander.cargo == before.commander.cargo)
    #expect(resumed.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(resumed.commander.nativePeople == before.commander.nativePeople)
    #expect(resumed.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(OriginalServiceReservationPolicy.activeCount(resumed.commander.scriptState)
      == OriginalServiceReservationPolicy.activeCount(before.commander.scriptState))
    let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(saved == resumed.commander && world.consistent(with: saved))
    let cold = GameRuntime(game: Game(executive: false), saveURL: f.save)
    await cold.loadScriptPacks(directory: installed)
    try await cold.load(from: f.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    let reloaded = try #require(loaded.commander.scriptState.instances[id])
    try #require(loaded.scriptPack(for: reloaded)?.digest == f.pack.digest)
    #expect(reloaded.suspension == nil && reloaded.outcome == .active)
    #expect(reloaded.courier == suspended.courier && reloaded.contract == suspended.contract)
    #expect(loaded.commander == resumed.commander)
    // Repeating a successful resume does not accept a second package or settle it.
    try await cold.resumeScriptMission(id)
    #expect(await cold.snapshot().commander == loaded.commander)
  }
}
