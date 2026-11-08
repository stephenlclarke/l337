import Foundation
import Testing

@testable import L337Core

struct NativePagedSalvageRuntimeTests {
  @Test func genuineGeneratedInspectionAndWorkBypassEveryFullOrdinaryLifetimePool() async throws {
    var (game, site) = try NativePagedSalvageFixture.game(fullOrdinaryPools: true)
    let original = game.commander.salvageLedger
    #expect(original.wreckMotion(for: site.identity) == nil)
    let wreck = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(wreck.source == .generated(site) && wreck.seed == original.nativeInspectionSeed)
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let hot = try #require(game.nativeSalvageWork)
    let expected = SalvageLootProfiles.plan(
      section: hot.plan.section, seed: original.nativeInspectionSeed, source: hot.plan.source)
    #expect(hot.plan == expected && hot.cycle.currentWorkSeconds == 0.1)
    #expect(hot.cycle.releases == 0 && hot.cycle.progress.nextLot == 0)
    #expect(game.commander.salvageLedger == original)
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(observedWorkFlush)
    #expect(game.commander.salvageLedger == original)
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    try snapshot.validate()
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let observedDecodedSnapshot = try AlienStoragePageCodec.decode(
      reference: archive.reference, expectedOwner: snapshot.owner, rootData: archive.rootData,
      from: pages)
    #expect(
      observedDecodedSnapshot == snapshot)
    let allSatisfied = pages.pages.values.allSatisfy { $0.count <= AlienStoragePageCodec.maximumPageBytes }
    #expect(allSatisfied)
    let bodyCandidate = game.bodies.first {
      $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
    }
    let body = try #require(bodyCandidate)
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: hot.plan.section)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var released = await runtime.snapshot()
    for _ in 0..<2000 {
      released = await NativePagedSalvageFixture.advanceHeldWork(runtime, delta: 0.02)
      if released.commander.alienStorageState?.current.salvage.native.works[
        hot.cycle.inspection.id]?.releases == 1
      {
        break
      }
    }
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    #expect(native.native.works[hot.cycle.inspection.id]?.releases == 1)
    #expect(!native.pending.isEmpty && native.pending.count <= 8)
    #expect(released.commander.salvageLedger.pendingLots == original.pendingLots)
    #expect(released.commander.salvageLedger.inventory == original.inventory)
    // Actual native spawn admission shares only the original producer sequence.
    // Compare the complete old semantic ledger after accounting for that one allocator.
    var actualFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(released.commander.salvageLedger))
        as? [String: Any])
    let oldFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    actualFields["sequence"] = oldFields["sequence"]
    let retained = try JSONDecoder().decode(
      SalvageLedger.self, from: JSONSerialization.data(withJSONObject: actualFields))
    #expect(retained == original)
    #expect(native.native.plans[hot.cycle.inspection.id]?.plan == expected)
    #expect(native.native.works[hot.cycle.inspection.id]?.currentWorkSeconds == 0)

  }

  @Test func originalInspectionPartialBudgetAndActualMovingPoseSurviveNativeSaveAndNoWriteReload()
    async throws
  {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    game.selectFlightTool(.salvageCutter)
    let original = game.commander.salvageLedger
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    let worked = await runtime.advance(delta: 0.1)
    let hot = try #require(worked.nativeSalvageWork)
    try await runtime.save(to: file)
    let ready = await runtime.snapshot()
    let snapshot = try #require(ready.commander.alienStorageState?.current.snapshot)
    let native = try NativeSalvagePlanView(snapshot.world)
    let cycle = try #require(native.works[hot.cycle.inspection.id])
    #expect(cycle.currentWorkSeconds == 0.1 && cycle.releases == 0)
    #expect(native.plans[hot.cycle.inspection.id]?.plan == hot.plan)
    #expect(ready.commander.salvageLedger == original)
    let bodyCandidate2 = ready.bodies.first {
      $0.physical?.salvage?.wreck == source.identity && $0.physical?.payload == nil
    }
    let body = try #require(bodyCandidate2)
    #expect(native.wrecks[source.identity]?.motion.pose == ready.modelPose(of: body))
    #expect(snapshot.sources.isEmpty && snapshot.attachments.isEmpty && snapshot.upgrades.isEmpty)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let kitRecord = try #require(ready.commander.savedEMPState?.records[source.actor])
    let kit = try #require(kitRecord.hull.body.physical?.currentNewtKitStock)
    let receiptCandidate = kitRecord.pods.compactMap { $0.body.physical?.currentNewtKitReceipt }
      .first { $0.issue.kitID == kit.issue.kitID }
    let receipt = try #require(receiptCandidate)
    try #require(kit.phase == .released && kit.remaining == 0 && kit.receipt == receipt)
    try #require(CurrentNewtKitSave.hasClaims(ready.commander))
    try #require(ready.commander.usesAlienStorageSaveVersion && !snapshot.world.isEmpty)
    #expect(pointer.schemaVersion == CurrentNewtKitSave.alienVersion)
    var expectedDisk = ready.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: ready.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: ready.systemIdentity)
    let observedDiskCommander = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(observedDiskCommander == expectedDisk)
    let liveCareers = ready.commander.wantedCareers.careers
    #expect(observedDiskCommander.wantedCareers.careers.count == liveCareers.count)
    for (identity, career) in liveCareers {
      var expectedCareer = career
      if identity.system == ready.systemIdentity { expectedCareer.binding = nil }
      #expect(observedDiskCommander.wantedCareers.careers[identity] == expectedCareer)
    }
    try await runtime.load(from: file, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander == ready.commander && restored.bodies == ready.bodies)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
    #expect(restored.nativeSalvageWork == nil)
  }

  @Test
  func actualActorWriterRefusalRetainsCompletedBudgetAndRetryMovesReleasedFragmentsInTheSameFrame()
    async throws
  {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    let bodyCandidate3 = game.bodies.first { $0.physical?.salvage?.wreck == source.identity }
    let body = try #require(bodyCandidate3)
    game.selectFlightTool(.salvageCutter)
    let metadata = try #require(body.physical?.salvage)
    let originalSurface = game.workSurface(for: body, metadata: metadata)
    let originalSection = try #require(originalSurface?.section)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: originalSection)
    let folder = try NativePagedSalvageFixture.folder()
    let preserved = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: preserved)
    }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    try FileManager.default.moveItem(at: folder, to: preserved)
    try Data("writer blocked".utf8).write(to: folder)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var refused = await runtime.snapshot()
    for _ in 0..<2000 {
      refused = await NativePagedSalvageFixture.advanceHeldWork(runtime, delta: 0.02)
      if refused.message == "SALVAGE SAVE FAILED - COMPLETED WORK RETAINED" { break }
    }
    #expect(refused.message == "SALVAGE SAVE FAILED - COMPLETED WORK RETAINED")
    let hot = try #require(refused.nativeSalvageWork)
    #expect(hot.cycle.currentWorkSeconds == hot.section.workSeconds && hot.cycle.releases == 0)
    #expect(refused.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    #expect(refused.commander.alienStorageState?.current.salvage.pending.isEmpty == true)
    #expect(
      !refused.bodies.contains {
        $0.physical?.payload.map { if case .salvage = $0 { true } else { false } } == true
      })
    let observedFileBytes2 = try Data(
      contentsOf: preserved.appendingPathComponent("commander.json"))
    #expect(observedFileBytes2 == bytes)
    var noWriterGame = refused
    // A new actor invalidates scene authority. Retain the completed budget at the
    // genuine cold value boundary, then reacquire it in that actor's own epoch.
    let observedWorkFlush2 = noWriterGame.flushNativeSalvageWork()
    #expect(observedWorkFlush2)
    let control = GameRuntime(game: noWriterGame)
    await control.setControls(NativePagedSalvageFixture.firingControls)
    let noWriter = await control.advance(delta: 0.02)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: preserved, to: folder)
    // The original ordinary producer is an independent custody/content oracle.
    // It uses the actual retained parent pose, without granting any scene admission.
    let emissionPlayerPose = refused.commander.flightSimulation.pose
    let releaseBodyCandidate = refused.bodies.first { $0.physical?.identity == hot.actor }
    let releaseBody = try #require(releaseBodyCandidate)
    let releasePhysical = try #require(releaseBody.physical)
    var oracle = SalvageLedger(seed: hot.seed)
    let inspected = oracle.inspectLoot(
      wreck: hot.plan.section.wreck, section: hot.section, source: hot.plan.source)
    #expect(inspected == hot.plan)
    var remaining = hot.section.workSeconds
    var operation: UInt64 = 0
    var expectedLots: [SalvageLot] = []
    while remaining > 0 {
      let elapsed = min(1, remaining)
      operation += 1
      let result = oracle.advance(
        wreck: hot.plan.section.wreck, section: hot.section,
        pose: refused.modelPose(of: releaseBody), velocity: releasePhysical.velocity,
        angularVelocity: releasePhysical.angularVelocity, tool: .cutter,
        elapsed: elapsed, operation: operation,
        conditions: NativePagedSalvageFixture.permitted, source: hot.plan.source)
      remaining -= elapsed
      if remaining == 0 {
        guard case .released(let lots) = result else { throw SaveError.invalidCommander }
        expectedLots = lots
      } else {
        guard case .progress = result else { throw SaveError.invalidCommander }
      }
    }
    #expect(!expectedLots.isEmpty)
    let originalRelease = try oracle.exportNativeSection(hot.plan.section)
    let retry = await runtime.advance(delta: 0.02)
    // The completed budget spends no second cutter work, energy or heat. Guidance
    // and ordinary frame recharge still run identically in both actual simulations.
    #expect(abs(retry.energy - noWriter.energy) < 1e-8)
    #expect(abs(retry.laserHeat - noWriter.laserHeat) < 1e-8)
    let native = try #require(retry.commander.alienStorageState?.current.salvage)
    let cycle = try #require(native.native.works[hot.cycle.inspection.id])
    #expect(cycle.releases == 1 && cycle.currentWorkSeconds == 0 && !cycle.damagedTechnology)
    #expect(cycle.progress == originalRelease.progress)
    #expect(!native.pending.isEmpty && native.pending.count <= 8)
    #expect(Set(native.pending.keys) == Set(expectedLots.map(\.identity)))
    for lot in expectedLots {
      let pending = try #require(native.pending[lot.identity])
      #expect(pending.lot.content == lot.content && pending.lot.loot == lot.loot)
      #expect(pending.lot.massKg == lot.massKg && pending.lot.halfExtents == lot.halfExtents)
      // Durable physical admission observes a world/local/world projection before movement.
      // Unbound custody has no body observation and retains the original producer position.
      let expectedPosition =
        pending.binding == nil
        ? lot.position
        : emissionPlayerPose.systemPoint(emissionPlayerPose.shipPoint(lot.position))
      #expect(pending.lot.position == expectedPosition && pending.lot.velocity == lot.velocity)
      #expect(pending.offer == nil)
    }
    let containsMatch = native.pending.values.contains { $0.binding != nil }
    #expect(containsMatch)
    for pending in native.pending.values {
      guard let binding = pending.binding else {
        // A released lot can await safe placement without becoming a fake body.
        #expect(!retry.bodies.contains { $0.physical?.payload == .salvage(pending.lot.identity) })
        continue
      }
      let releasedCandidate = retry.bodies.first { $0.physical?.identity == binding }
      let released = try #require(releasedCandidate)
      let position = retry.commander.flightSimulation.pose.systemPoint(released.position)
      #expect((position - pending.lot.position - pending.lot.velocity * 0.02).length < 1e-7)
      #expect(retry.currentSalvageLot(for: released)?.identity == pending.lot.identity)
    }
    let after = await runtime.advance(delta: 0.02)
    #expect(
      after.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .releases == 1)
    #expect(
      after.commander.alienStorageState?.current.salvage.pending.count == native.pending.count)
  }

  @Test func nativeActualDeathPreservesThePartialInspectionAndNeverReadmitsTheGeneratedParent()
    throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    let observedCutterResult2 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult2)
    let indexCandidate = game.bodies.firstIndex {
      $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
    }
    let index = try #require(indexCandidate)
    let player = try #require(game.commander.flightSimulation.player)
    let allocatedAttackOrigin = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocatedAttackOrigin)
    let before = game.bodies[index]
    let hit = GameplayHit(
      target: .body(before.id), distance: before.position.length, point: before.position)
    let observedCombatResult = game.applyCombatHit(
      hit, origin: origin, kind: .laser, damage: before.energy + 1, laser: .pulse)
    #expect(
      observedCombatResult != nil)
    game.commander.crimeLedger.finishEmission(origin.emissionID)
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.id == before.id })
    let native = try #require(game.commander.alienStorageState?.current.salvage.native)
    #expect(native.wrecks[site.identity]?.destroyedAt != nil)
    #expect(native.wrecks[site.identity]?.motion.energy.map { $0 <= 0 } == true)
    let containsMatch2 = native.depletedSections.contains { $0.wreck == site.identity }
    #expect(containsMatch2)
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    game.activateNearbySalvageSites()
    #expect(game.commander.alienStorageState?.current.snapshot == snapshot)
    #expect(!game.bodies.contains { $0.physical?.salvage?.wreck == site.identity })
    #expect(game.commander.salvageLedger.wreckMotion(for: site.identity) == nil)
  }
}

extension NativePagedSalvageRuntimeTests {
  @Test func actualCurrentHumanGeneratedCutKeepsItsPartialBudgetAcrossNoWriteReload()
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game(humanCargo: true)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    #expect(!profile.sourceRoles.contains(.thargoid))
    let sectionCandidate = profile.sections.first { $0.index == 1 }
    let section = try #require(sectionCandidate)
    let identity = WreckSectionIdentity(wreck: site.identity, section: section.index)
    let parentCandidate = game.bodies.first {
      $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
    }
    let parent = try #require(parentCandidate)
    let physical = try #require(parent.physical)
    #expect(physical.spawnIdentity?.producer == .derelicts)
    #expect(physical.catalogueShipID == site.catalogueShipID && physical.empSource == nil)
    #expect(physical.npc == nil && physical.salvage == site.metadata)
    #expect(physical.velocity.length > 0 && physical.angularVelocity.length > 0)
    #expect(game.salvageSites.contains(site))
    #expect(game.commander.salvageLedger.progress(identity) == 0)
    let cargo = game.commander.cargo
    let inventory = game.commander.equipmentInventory
    let credits = game.commander.credits
    game.selectFlightTool(.salvageCutter)
    let cut = game.fireSalvageCutter(delta: 0.1)
    try #require(cut)
    #expect(game.commander.salvageLedger.progress(identity) == 0.1)
    #expect(game.nativeSalvageWork == nil && game.commander.alienStorageState == nil)
    #expect(game.commander.cargo == cargo && game.commander.equipmentInventory == inventory)
    #expect(game.commander.credits == credits)

    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let moved = await runtime.advance(delta: 0.02)
    let movingParentCandidate = moved.bodies.first { $0.physical?.identity == physical.identity }
    let movingParent = try #require(movingParentCandidate)
    #expect(moved.modelPose(of: movingParent) != game.modelPose(of: parent))
    #expect(moved.commander.salvageLedger.progress(identity) == 0.1)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    var loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(try Data(contentsOf: file) == bytes)
    #expect(loaded.salvageSites == saved.salvageSites && loaded.salvageSites.contains(site))
    #expect(loaded.commander.salvageLedger.progress(identity) == 0.1)
    let restoredParentCandidate = loaded.bodies.first { $0.physical?.identity == physical.identity }
    let restoredParent = try #require(restoredParentCandidate)
    #expect(restoredParent.physical?.spawnIdentity == physical.spawnIdentity)
    #expect(restoredParent.physical?.salvage == site.metadata)
    let continued = loaded.fireSalvageCutter(delta: 0.1)
    try #require(continued)
    #expect(loaded.commander.salvageLedger.progress(identity) == 0.2)
    #expect(loaded.nativeSalvageWork == nil && loaded.commander.alienStorageState == nil)
    #expect(loaded.commander.cargo == cargo && loaded.commander.equipmentInventory == inventory)
    #expect(loaded.commander.credits == credits)
  }

  @Test func genuineCullRevisitAndReloadPreserveTheExactRetainedMotionAndPartialBudget()
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    let observedCutterResult4 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult4)
    let hot = try #require(game.nativeSalvageWork)
    let parentCandidate2 = game.bodies.first { $0.physical?.salvage?.wreck == site.identity }
    let parent = try #require(parentCandidate2)
    let actor = try #require(parent.physical?.identity)
    let pose = game.commander.flightSimulation.pose
    game.tick(delta: 0.1)
    let movedCandidate = game.bodies.first { $0.physical?.identity == actor }
    let moved = try #require(movedCandidate)
    #expect((game.modelPose(of: moved).position - game.modelPose(of: parent).position).length > 0)
    NativePagedSalvageFixture.moveObserver(
      &game, to: .init(position: pose.position + .init(50000, 0, 0), orientation: pose.orientation))
    game.tick(delta: 0.02)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    let parked = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(parked.binding == nil && parked.destroyedAt == nil)
    #expect(
      game.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .currentWorkSeconds == 0.1)
    NativePagedSalvageFixture.moveObserver(&game, to: pose)
    game.activateNearbySalvageSites()
    let returnedCandidate = game.bodies.first { $0.physical?.salvage?.wreck == site.identity }
    let returned = try #require(returnedCandidate)
    #expect(returned.physical?.identity != actor)
    #expect((game.modelPose(of: returned).position - parked.motion.pose.position).length < 1e-8)
    #expect(
      (game.modelPose(of: returned).orientation.x - parked.motion.pose.orientation.x).length < 1e-8)
    #expect(returned.energy == parked.motion.energy)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let ready = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == ready.commander && loaded.bodies == ready.bodies)
    #expect(
      loaded.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .currentWorkSeconds == 0.1)
    let observedFileBytes3 = try Data(contentsOf: file)
    #expect(observedFileBytes3 == bytes)
    let anchors = try #require(loaded.commander.flightSimulation.anchors)
    let expectedSites = SalvageSites.generate(anchors: anchors, seed: loaded.gameplaySeed)
    #expect(loaded.salvageSites == expectedSites && expectedSites.contains(site))
    #expect(!loaded.salvageHUDLines.isEmpty)
    let loadedView = try #require(loaded.commander.alienStorageState?.current.salvage.native)
    let originalInspection = try #require(loadedView.inspections[hot.plan.section])
    let originalCycle = try #require(loadedView.works[hot.cycle.inspection.id])
    let loadedParentCandidate = loaded.bodies.first { $0.physical?.salvage?.wreck == site.identity }
    let loadedParent = try #require(loadedParentCandidate)
    let loadedActor = try #require(loadedParent.physical?.identity)
    let observer = loaded.commander.flightSimulation.pose
    var revisiting = loaded
    NativePagedSalvageFixture.moveObserver(
      &revisiting,
      to: .init(position: observer.position + .init(50000, 0, 0), orientation: observer.orientation)
    )
    revisiting.tick(delta: 0.02)
    #expect(!revisiting.bodies.contains { $0.physical?.identity == loadedActor })
    let retained = try #require(
      revisiting.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(retained.binding == nil && retained.destroyedAt == nil)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.inspections[hot.plan.section]
        == originalInspection)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]
        == originalCycle)
    NativePagedSalvageFixture.moveObserver(&revisiting, to: observer)
    revisiting.activateNearbySalvageSites()
    let admitted = revisiting.bodies.filter {
      $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
    }
    #expect(admitted.count == 1)
    let returnedAfterLoad = try #require(admitted.first)
    let returnedPose = revisiting.modelPose(of: returnedAfterLoad)
    #expect(returnedAfterLoad.physical?.identity != loadedActor)
    #expect((returnedPose.position - retained.motion.pose.position).length < 1e-8)
    #expect((returnedPose.orientation.x - retained.motion.pose.orientation.x).length < 1e-8)
    #expect((returnedPose.orientation.y - retained.motion.pose.orientation.y).length < 1e-8)
    #expect((returnedPose.orientation.z - retained.motion.pose.orientation.z).length < 1e-8)
    #expect(returnedAfterLoad.energy == retained.motion.energy)
    #expect(returnedAfterLoad.physical?.velocity == retained.motion.velocity)
    #expect(returnedAfterLoad.physical?.angularVelocity == retained.motion.angularVelocity)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]
        == originalCycle)
    #expect(revisiting.commander.salvageLedger == loaded.commander.salvageLedger)
    let observedFileBytes4 = try Data(contentsOf: file)
    #expect(observedFileBytes4 == bytes)
  }

  @Test func coldSceneCensusRejectsMissingDuplicateAndReboundNativeWreckActors() throws {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    let observedPosePersistence = game.persistSalvagePoses()
    #expect(observedPosePersistence)
    let bodyCandidate4 = game.bodies.first { $0.physical?.salvage?.wreck == source.identity }
    let body = try #require(bodyCandidate4)
    #expect(
      game.commander.nativeSalvageSceneIsConsistent(
        game.bodies, docked: false, atColdBoundary: true))
    let missing = game.bodies.filter { $0.id != body.id }
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(missing, docked: false, atColdBoundary: true))
    var duplicate = body
    duplicate.id = game.nextBodyID + 1
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        game.bodies + [duplicate], docked: false, atColdBoundary: true))
    var rebound = body
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let originalPhysical = try #require(body.physical)
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(originalPhysical)) as? [String: Any])
    fields["identity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(actor))
    rebound.physical = try JSONDecoder().decode(
      PhysicalActorState.self, from: JSONSerialization.data(withJSONObject: fields))
    let replacement = game.bodies.map { $0.id == body.id ? rebound : $0 }
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        replacement, docked: false, atColdBoundary: true))
    var moved = body
    moved.position.x += 1
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        game.bodies.map { $0.id == body.id ? moved : $0 }, docked: false, atColdBoundary: true))
  }
}

extension NativePagedSalvageRuntimeTests {
  @Test(arguments: ["save", "dock", "arrival", "galactic"])
  func invalidActualMotionRefusesColdBoundariesWithoutLosingTheHotSession(boundary: String)
    async throws
  {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    if boundary == "galactic" {
      // The authentic EMP unit scene occupies all three utility mounts. Store
      // its retained weapon through the normal inventory path before fitting
      // this case's existing drive; the source, hardware and bank remain owned.
      let inventory = try #require(game.commander.equipmentInventory)
      let emp = try #require(game.currentEMPPlayerModule())
      try game.commander.storeEquipment(emp, expectedRevision: inventory.revision)
      let storedInventory = try #require(game.commander.equipmentInventory)
      let storedCandidate = storedInventory.items.first { $0.id == emp.id }
      let stored = try #require(storedCandidate)
      #expect(stored == emp.moved(to: nil))
      #expect(Set(storedInventory.items.map(\.id)) == Set(inventory.items.map(\.id)))
      try game.commander.grantEquipment(
        "Galactic Hyperdrive", at: .utility(.galacticHyperdrive),
        provenance: .grant("cold boundary test"))
    }
    let observedNPCRefusals = game.persistNPCStates()
    #expect(observedNPCRefusals.isEmpty)
    let observedPosePersistence2 = game.persistSalvagePoses()
    #expect(observedPosePersistence2)
    let observedCutterResult5 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult5)
    let indexCandidate2 = game.bodies.firstIndex {
      $0.physical?.salvage?.wreck == source.identity && $0.physical?.payload == nil
    }
    let index = try #require(indexCandidate2)
    game.bodies[index].physical?.angularVelocity = .init(.infinity, 0, 0)
    let original = game.commander
    let work = try #require(game.nativeSalvageWork)
    let originalScreen = game.screen
    switch boundary {
    case "save":
      let folder = try NativePagedSalvageFixture.folder()
      defer { try? FileManager.default.removeItem(at: folder) }
      let file = folder.appendingPathComponent("commander.json")
      // Exercise the actual native save barrier while this hot epoch is still
      // current, before checking the actor's separate refused value handoff.
      #expect(game.nativeSalvageHotWorkIsCurrent(work))
      #expect(throws: SaveError.invalidCommander) {
        _ = try GameRuntime.prepareNativeSaveState(game)
      }
      let runtime = GameRuntime(game: game)
      let before = await runtime.snapshot()
      var refused = false
      do { try await runtime.save(to: file) } catch { refused = true }
      #expect(refused && !FileManager.default.fileExists(atPath: file.path))
      let after = await runtime.snapshot()
      #expect(after.commander == before.commander)
      #expect(after.nativeSalvageWork?.cycle == work.cycle && after.bodies == before.bodies)
      return
    case "dock": game.dock()
    case "arrival": game.arrive()
    case "galactic": game.galacticJump()
    default: throw SaveError.invalidCommander
    }
    #expect(game.commander == original && game.screen == originalScreen && !game.docked)
    #expect(game.nativeSalvageWork?.cycle == work.cycle)
    #expect(game.commander.alienStorageState?.current.salvage.pending.isEmpty == true)
  }
}
