import Foundation
import Testing

@testable import L337Core

/// Genuine complete preceding producers, followed by a labelled controlled remote scene.
/// No original archive, data, kit, source, admission or recovery receipt is injected.
func actualHollowRegisterRuntime() async throws -> (
  runtime: GameRuntime, commission: HollowManifestCommissionFixture
) {
  let (wake, commission) = try await actualHollowWakeRuntime()
  do {
    for mark in NativeC03WakeGeometry.Mark.allCases {
      let selected = try await selectActualHollowWake(wake, mark: mark)
      try #require(selected.hollowManifestWakeTarget != nil)
      await wake.missionUICommand(.init(
        action: .originalWakeScan, game: selected, presentation: selected.scriptPagePresentation))
      try #require(await wake.snapshot().hollowManifestMission?.savedHollowManifest?
        .wakeTrail?.observations.count == mark.index + 1)
    }
    var game = await wake.snapshot()
    try #require(game.hollowManifestMission?.milestones == [0, 1, 2, 3])
    try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister == nil)
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    // Controlled remote scene, not earned travel. Existing kit/data/source facts still come
    // only from their genuine producers. The archive must use a NEW real native admission.
    let world = NativeHollowManifestDefinition.registerWorld
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.speed = 0
    game.screen = .front
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let source = try #require(try game.retainedMissionActorAdmissionSources().first {
      $0.encounterID == NativeC03RegisterState.encounter
    })
    let template = try #require(source.actors.first)
    try #require(source.mode == .prepared && source.actors.count == 1)
    let condition = try #require(template.retainedNativeCondition)
    let resources = try #require(condition.resources)
    try #require(condition.hasFuelScoops == false && resources.valid && resources.profile == .nativeHull)
    try #require(resources.energyCapacity == 16 && resources.energyCapacity == template.maximumHullEnergy)
    try #require(template.canonicalBody.energy == resources.energyCapacity)
    let before = game.commander.flightSimulation
    try game.restoreScriptActors()
    let record = try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    try #require(record.recovery == nil && record.sourceContents == record.origin.contents)
    try #require(record.holder == .originalArchive(record.origin.archive))
    try #require(game.commander.flightSimulation.nextActor == before.nextActor + 1)
    try #require(game.commander.flightSimulation.nextSpawn == before.nextSpawn + 1)
    try #require(game.commander.flightSimulation.physicalTime == before.physicalTime)
    let body = try #require(game.bodies.first { $0.physical?.identity == record.latest?.actor })
    try #require(body.physical?.npc?.resources == resources)
    try #require(body.physical?.npc?.hasFuelScoops == false)
    try #require(NativeHollowManifestSave.validateClaims(game.commander))
    let runtime = GameRuntime(game: game, saveURL: commission.files.save)
    try await runtime.save(to: commission.files.save)
    return (runtime, commission)
  } catch {
    commission.clean()
    throw error
  }
}

func selectActualHollowRegister(_ runtime: GameRuntime) async throws -> Game {
  try await runtime.scriptCommand { game in
    let record = try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let admission = try #require(record.latest)
    let body = try #require(game.bodies.first {
      $0.physical?.identity == admission.actor && $0.missionActorID == admission.logicalActor
    })
    let previous = game.commander.flightSimulation.pose
    let centre = body.modelPoint(NativeC03RegisterGeometry.componentPosition
      + .init(0, 0, NativeC03RegisterGeometry.plateHeight + 0.035))
    let normal = body.modelVector(.init(0, 0, 1))
    var pose = ShipPose(position: previous.systemPoint(centre + normal * 100))
    pose.orientation.z = previous.orientation.apply(normal * -1)
    pose.orientation.y = previous.orientation.apply(body.modelVector(.init(0, 1, 0)))
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.rotateScriptNPCVelocities(from: previous, to: pose)
    game.screen = .front
    game.speed = 0
    game.cancelAutoTarget()
    game.weaponsTargetID = body.id
    _ = try #require(try NativeC03RegisterProbe.measure(
      in: game, bodyID: body.id, component: admission.component))
  }
  return await runtime.snapshot()
}

private func recoverActualHollowRegister(_ runtime: GameRuntime) async throws -> Game {
  var selected = await runtime.snapshot()
  if selected.hollowManifestRegisterTarget == nil {
    selected = try await selectActualHollowRegister(runtime)
  }
  try #require(selected.hollowManifestRegisterTarget != nil)
  await runtime.missionUICommand(.init(
    action: .originalRegisterRecovery, game: selected, presentation: selected.scriptPagePresentation))
  let recovered = await runtime.snapshot()
  _ = try #require(recovered.hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery)
  return recovered
}

struct NativeC03RegisterRuntimeUnitTests {
  @Test func actualNativeArchiveTransfersOneOriginalIntoTheHeldKitWithoutExtraCargoOrReward() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    let before = try #require(selected.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    #expect(throws: (any Error).self) { try selected.hollowManifestHeldRegisterData() }
    let after = try await recoverActualHollowRegister(runtime)
    let record = try #require(after.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let held = try after.hollowManifestHeldRegisterData()
    #expect(record.origin == before.origin && record.admissions == before.admissions)
    #expect(record.sourceContents == nil && record.holder == .originalInspectionKit(held.kit.serial))
    #expect(held.contents == before.origin.contents && held.transfer == record.recovery?.operation)
    #expect(after.commander.equipmentInventory == selected.commander.equipmentInventory)
    #expect(after.commander.cargo == selected.commander.cargo && after.commander.cargoTonnes == selected.commander.cargoTonnes)
    #expect(after.commander.credits == selected.commander.credits)
    #expect(after.commander.flightSimulation == selected.commander.flightSimulation)
    #expect(after.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(after.hollowManifestMission?.outcome == .active && after.hollowManifestMission?.completionReceipt == nil)
    #expect(after.hollowManifestMission?.receipts.contains(NativeC03RegisterState.receipt) == true)
    let committed = after.commander
    let bytes = try Data(contentsOf: commission.files.save)
    await runtime.key("original-register-recover")
    #expect(await runtime.snapshot().commander == committed)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
  }

  @Test func currentOnlyColdLoadRetainsExactContentsAndCannotReissueAnEmptiedArchive() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recoverActualHollowRegister(runtime)
    let original = try recovered.hollowManifestHeldRegisterData()
    var shell = Game(executive: false)
    shell.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledHollowManifestDirectory)]
    let cold = GameRuntime(game: shell, saveURL: commission.files.save)
    try await cold.load(from: commission.files.save)
    let loaded = await cold.snapshot()
    let actual = try loaded.hollowManifestHeldRegisterData()
    #expect(actual.contents == original.contents && actual.transfer == original.transfer)
    #expect(actual.kit.serial == original.kit.serial)
    #expect(loaded.hollowManifestMission?.savedHollowManifest?.custodyRegister?.sourceContents == nil)
    let before = loaded.commander
    await cold.key("original-register-recover")
    #expect(await cold.snapshot().commander == before)
  }

  @Test func wrongTargetPageAndInventoryEpochRefuseBeforeAnyCustodyMove() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    let queued = MissionUIIntent(
      action: .originalRegisterRecovery, game: selected, presentation: selected.scriptPagePresentation)
    try #require(queued.isCurrent(in: selected))
    await runtime.nativeCommand { $0.weaponsTargetID = 0 }
    let wrong = await runtime.snapshot()
    #expect(!queued.isCurrent(in: wrong))
    await runtime.missionUICommand(queued)
    #expect(await runtime.snapshot().commander == wrong.commander)
    var page = selected
    page.screen = .status
    #expect(!queued.isCurrent(in: page))
    var inventory = selected
    let owned = try #require(inventory.commander.equipmentInventory)
    // Negative-only epoch change; no equipment, data or positive receipt is constructed.
    inventory.commander.equipmentInventory = try .init(
      owner: owned.owner, activeHull: owned.activeHull, revision: owned.revision + 1, items: owned.items)
    #expect(!queued.isCurrent(in: inventory))
    #expect(selected.hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery == nil)
  }

  @Test func missingKitGeometryDeadFaceAndExcessSurfaceMotionCannotGrantData() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    try #require(selected.hollowManifestRegisterTarget != nil)
    let record = try #require(selected.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let admission = try #require(record.latest)
    let index = try #require(selected.bodies.firstIndex { $0.physical?.identity == admission.actor })
    let kit = try #require(selected.hollowManifestMission?.savedHollowManifest?.laboratory?.facts.originalKit)
    for failure in 0..<4 {
      var broken = selected
      switch failure {
      case 0:
        let inventory = try #require(broken.commander.equipmentInventory)
        broken.commander.equipmentInventory = try .init(
          owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision + 1,
          items: inventory.items.filter { $0.id != kit })
      case 1:
        broken.commander.scriptState.geometry.removeValue(forKey: admission.faceGeometry)
      case 2:
        broken.bodies[index].scriptNPC?.components[NativeC03RegisterGeometry.component]?.energy = 0
      default:
        broken.bodies[index].physical?.angularVelocity = broken.modelPose(of: broken.bodies[index]).orientation.z * 10
      }
      let before = broken.commander
      #expect(throws: (any Error).self) { try broken.recoverHollowManifestRegister() }
      #expect(broken.commander == before)
      #expect(broken.hollowManifestMission?.savedHollowManifest?.custodyRegister == record)
    }
  }

  @Test func realWriterRefusalPreservesBothHoldersAndRetryMovesTheOriginalOnce() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let selected = try await selectActualHollowRegister(runtime)
    let bytes = try Data(contentsOf: commission.files.save)
    let directory = commission.files.save.deletingLastPathComponent()
    let parked = directory.appendingPathExtension("parked")
    try FileManager.default.moveItem(at: directory, to: parked)
    defer {
      if FileManager.default.fileExists(atPath: parked.path) {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.moveItem(at: parked, to: directory)
      }
    }
    try Data("writer-refusal".utf8).write(to: directory)
    await runtime.missionUICommand(.init(
      action: .originalRegisterRecovery, game: selected, presentation: selected.scriptPagePresentation))
    let refused = await runtime.snapshot()
    #expect(refused.commander == selected.commander)
    let record = try #require(refused.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    #expect(record.sourceContents == record.origin.contents && record.holder == .originalArchive(record.origin.archive))
    #expect(throws: (any Error).self) { try refused.hollowManifestHeldRegisterData() }
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: parked, to: directory)
    #expect(try Data(contentsOf: commission.files.save) == bytes)
    let recovered = try await recoverActualHollowRegister(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    #expect(held.contents == record.origin.contents)
    #expect(recovered.hollowManifestMission?.savedHollowManifest?.custodyRegister?.sourceContents == nil)
  }

  @Test func genuineRevisitPreservesSingleKitContentsAndFreshEmptyArchiveAddress() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    var game = try await recoverActualHollowRegister(runtime)
    let before = try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let data = try game.hollowManifestHeldRegisterData()
    let old = try #require(before.latest)
    try game.persistScriptActorsChecked(unloading: true)
    try game.departOrdinarySimulation()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.speed = 0
    game.resetCelestialFlight()
    try #require(game.beginGameplayVisit(arriving: true))
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let flight = game.commander.flightSimulation
    try game.restoreScriptActors()
    let after = try #require(game.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    let next = try #require(after.latest)
    #expect(after.origin == before.origin && after.recovery == before.recovery)
    #expect(next.actor != old.actor && next.actor.visit > old.actor.visit)
    #expect(next.revision == old.revision + 1 && next.component == old.component)
    #expect(game.commander.flightSimulation.nextActor == flight.nextActor + 1)
    #expect(game.commander.flightSimulation.nextSpawn == flight.nextSpawn + 1)
    #expect(after.sourceContents == nil && after.holder == .originalInspectionKit(data.kit.serial))
    #expect(try game.hollowManifestHeldRegisterData().contents == data.contents)
    let returned = GameRuntime(game: game, saveURL: commission.files.save)
    try await returned.save(to: commission.files.save)
    let selected = try await selectActualHollowRegister(returned)
    #expect(selected.hollowManifestRegisterTarget == nil)
    let commander = selected.commander
    await returned.key("original-register-recover")
    #expect(await returned.snapshot().commander == commander)
  }
}
