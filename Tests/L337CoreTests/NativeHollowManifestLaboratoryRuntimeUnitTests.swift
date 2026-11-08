import Foundation
import Testing

@testable import L337Core

/// Genuine producers after labelled controlled scenes/camera and the shared paid-item test
/// budget. No State, consent, scan, dock, kit or equipment receipt is injected.
func actualHollowLaboratoryRuntime() async throws -> (
  runtime: GameRuntime, commission: HollowManifestCommissionFixture
) {
  let actual = try await actualHollowManifestFreighterRootFixture(targeting: .basic)
  do {
    let runtime = GameRuntime(game: actual.game, saveURL: actual.commission.files.save)
    try await runtime.save(to: actual.commission.files.save)
    for slot in NativeHollowManifestState.Slot.allCases {
      try await runtime.scriptCommand { game in
        let id = try aimAtActualHollowManifestSeal(&game, slot: slot)
        game.cancelAutoTarget()
        game.weaponsTargetID = id
        game.speed = 0
      }
      let front = await runtime.snapshot()
      try #require(try front.makeHollowManifestConsentReview().requestAvailable)
      await runtime.missionUICommand(
        .init(action: .originalSealConsent, game: front, presentation: front.scriptPagePresentation))
      let review = await runtime.snapshot()
      try #require(review.hollowManifestConsentReview?.button == .back)
      await runtime.scriptPageKey("right", expected: review.scriptPagePresentation)
      let selected = await runtime.snapshot()
      try #require(selected.hollowManifestConsentReview?.button == .request)
      await runtime.scriptPageKey("return", expected: selected.scriptPagePresentation)
      let requested = await runtime.snapshot()
      let request = try #require(requested.hollowManifestConsentReview?.historical)
      try #require(request.reply == nil)
      await runtime.scriptPageKey("escape", expected: requested.scriptPagePresentation)
      let granted = await runtime.advance(delta: 0.05)
      try #require(granted.hollowManifestMission?.savedHollowManifest?.consents.first {
        $0.request == request.request
      }?.reply?.decision == .granted)
      let observed = await runtime.advance(delta: 0.05)
      try #require(observed.hollowManifestMission?.savedHollowManifest?.inspections.contains {
        $0.facts.admission.slot == slot
      } == true)
    }
    var game = await runtime.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0, 1])
    try #require(game.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    // Controlled remote flight scene, not earned travel. Retain the real originals before
    // leaving their scene, then obtain a new laboratory berth through actual swept entry.
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    let world = NativeHollowManifestDefinition.laboratoryWorld
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    try game.restoreScriptActors()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    let laboratory = GameRuntime(game: game, saveURL: actual.commission.files.save)
    for _ in 0..<100 {
      if await laboratory.snapshot().docked { break }
      _ = await laboratory.advance(delta: 0.05)
    }
    let arrived = await laboratory.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.systemIdentity == world)
    try #require(arrived.hollowManifestMission?.savedHollowManifest?.inspections.count == 2)
    try await laboratory.save(to: actual.commission.files.save)
    return (laboratory, actual.commission)
  } catch {
    actual.commission.clean()
    throw error
  }
}

func reviewActualHollowLaboratory(_ runtime: GameRuntime) async throws -> Game {
  await runtime.nativeCommand { game in
    game.openContractBoard()
    if let index = game.contractBoard.rows.firstIndex(where: { $0.hollowManifest == .laboratory }) {
      game.contractBoard.selection = index
    }
  }
  let board = await runtime.snapshot()
  try #require(board.contractBoard.selected?.hollowManifest == .laboratory)
  await runtime.scriptPageKey("return", expected: board.scriptPagePresentation)
  let shown = await runtime.snapshot()
  try #require(shown.contractBoard.detail && shown.contractBoard.action == .back)
  return shown
}

struct NativeHollowManifestLaboratoryRuntimeUnitTests {
  @Test func actualBerthAndConfirmIssueOnlyTheOriginalOneTonneLoanOnce() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let preview = try await reviewActualHollowLaboratory(runtime)
    try #require(preview.contractBoard.hollowManifestQuote?.allowed == true)
    try #require(preview.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    let bytes = try Data(contentsOf: commission.files.save)
    await runtime.scriptPageKey("escape", expected: preview.scriptPagePresentation)
    let back = await runtime.snapshot()
    #expect(back.commander == preview.commander)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
    let reviewed = try await reviewActualHollowLaboratory(runtime)
    await runtime.scriptPageKey("right", expected: reviewed.scriptPagePresentation)
    let chosen = await runtime.snapshot()
    try #require(chosen.contractBoard.action == .accept)
    let inventory = try #require(chosen.commander.equipmentInventory)
    await runtime.scriptPageKey("return", expected: chosen.scriptPagePresentation)
    let issued = await runtime.snapshot()
    let instance = try #require(issued.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let lab = try #require(state.laboratory)
    let serial = NativeHollowManifestKitDefinition.serial(mission: instance.id)
    let item = try #require(issued.commander.equipmentInventory?.items.first { $0.id == serial })
    #expect(lab.facts.originalKit == serial && lab.facts.inspections == state.inspections.map(\.operation))
    #expect(lab.facts.dock == chosen.commander.nativeStations?.currentMainDock)
    #expect(item.node == NativeHollowManifestKitDefinition.node && item.location == nil)
    #expect(issued.commander.equipmentInventory?.revision == inventory.revision + 1)
    #expect(issued.commander.cargoTonnes == chosen.commander.cargoTonnes + 1)
    #expect(issued.commander.credits == chosen.commander.credits)
    #expect(instance.milestones == [0, 1, 2] && instance.outcome == .active)
    #expect(instance.gearIssues[NativeHollowManifestKitDefinition.resource]?.status == .issued)
    let custody = try NativeHollowManifestKitCustody.resolve(instance: instance, commander: issued.commander)
    #expect(custody.serial == serial && custody.issueCommand == lab.facts.issueCommand)
    let restored = try ScriptSaveStore.read(
      Data(contentsOf: commission.files.save), from: commission.files.save).0
    #expect(restored.scriptState.instances[instance.id]?.savedHollowManifest?.laboratory == lab)
    #expect(try NativeHollowManifestKitCustody.resolve(instance: instance, commander: restored) == custody)
    await runtime.scriptPageKey("return", expected: issued.scriptPagePresentation)
    let repeated = await runtime.snapshot()
    #expect(repeated.hollowManifestMission?.savedHollowManifest?.laboratory == lab)
    #expect(repeated.commander.equipmentInventory == issued.commander.equipmentInventory)
    #expect(repeated.commander.credits == issued.commander.credits)
  }

  @Test func changedFreeHoldMakesAFormerlyAllowedLaboratoryQuoteRefuse() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let preview = try await reviewActualHollowLaboratory(runtime)
    try #require(preview.contractBoard.hollowManifestQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: preview.scriptPagePresentation)
    let selected = await runtime.snapshot()
    try #require(selected.contractBoard.action == .accept)
    try await runtime.scriptCommand { game in
      // Negative-only controlled cargo input; no earnings or acquisition is claimed.
      game.commander.cargo[0] = game.commander.standardCargoCapacity
      try #require(game.commander.valid)
    }
    let full = await runtime.snapshot()
    let bytes = try Data(contentsOf: commission.files.save)
    await runtime.scriptPageKey("return", expected: full.scriptPagePresentation)
    let refused = await runtime.snapshot()
    #expect(refused.commander == full.commander)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    #expect(refused.hollowManifestMission?.gearIssues.isEmpty == true)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
  }

  @Test func actualLaboratoryWriterRefusalKeepsOriginalObservationsForOneRetry() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let preview = try await reviewActualHollowLaboratory(runtime)
    try #require(preview.contractBoard.hollowManifestQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: preview.scriptPagePresentation)
    let chosen = await runtime.snapshot()
    try #require(chosen.contractBoard.action == .accept)
    let bytes = try Data(contentsOf: commission.files.save)
    let directory = commission.files.save.deletingLastPathComponent()
    let backup = commission.files.root.appendingPathComponent("before-laboratory-save")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked laboratory writer".utf8).write(to: directory)
    await runtime.scriptPageKey("return", expected: chosen.scriptPagePresentation)
    let refused = await runtime.snapshot()
    #expect(refused.commander == chosen.commander)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.inspections
      == chosen.hollowManifestMission?.savedHollowManifest?.inspections)
    #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    await runtime.scriptPageKey("return", expected: refused.scriptPagePresentation)
    let issued = await runtime.snapshot()
    try #require(issued.hollowManifestMission?.savedHollowManifest?.laboratory != nil)
    #expect(issued.hollowManifestMission?.gearIssues.count == 1)
    #expect(issued.commander.cargoTonnes == chosen.commander.cargoTonnes + 1)
    #expect(issued.commander.credits == chosen.commander.credits)
  }
}
