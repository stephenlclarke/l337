import Foundation
import Testing

@testable import L337Core

private func electricalGame() throws -> Game {
  var game = try empFixture()
  game.bodies[0].physical?.velocity = .init(0, 0, 0)
  game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
  game.bodies[0].rotationRate = 0
  return game
}

/// Controlled unit slice; full native owner acceptance uses GameRuntime.
private func releaseElectricalPulse(
  _ game: inout Game, beforeRelease: ((inout Game) throws -> Void)? = nil
) throws {
  try withEMPUnitWriter(&game) { scene, publish, file in
    _ = try emitEMPUnitPulse(&scene, publish: publish, beforeRelease: beforeRelease)
  }
}

/// Only these three local self-disable tests use this paid/basic-energy setup.
private struct EMPSelfDisableFixture: Sendable {
  let purchase: EMPModulePurchaseFixture
  let actor: ActorIdentity
  var runtime: GameRuntime { purchase.runtime }
  init(mining: Bool = false, speed: Double = 0, rearShield: Double? = nil) async throws {
    let transaction = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    purchase = transaction
    do {
      let first = await transaction.runtime.snapshot()
      let base = try #require(first.currentEMPPlayerModule())
      #expect(base.empGrades == .base && base.empBank?.remaining == 0)
      let history = try #require(first.commander.equipmentPurchaseHistory)
      let baseReceipt = try #require(history.paid.first { $0.binding.request.newItem == base.id })
      #expect(baseReceipt.owner == first.commander.equipmentOwnerID && baseReceipt.node == EMPModuleGradePolicy.node)
      #expect(baseReceipt.price == 30000)
      guard case .paid(let buyer, let operation) = base.provenance else { throw SaveError.invalidCommander }
      #expect(buyer == baseReceipt.owner && operation == baseReceipt.transaction)
      #expect(first.commander.credits == baseReceipt.binding.snapshot.funds - baseReceipt.price)
      for (step, price) in [(1, 30000), (2, 60000)] {
        let before = await transaction.runtime.snapshot()
        let context = try await transaction.context(.power)
        let receipt = try await transaction.runtime.purchaseEMPModuleUpgrade(context)
        let after = await transaction.runtime.snapshot()
        #expect(receipt.paidPrice == price && receipt.module == base.id)
        #expect(receipt.after.power == step && receipt.before.power == step - 1)
        #expect(receipt.resultingRevision == receipt.sourceInventoryRevision + 1)
        #expect(after.commander.credits == before.commander.credits - price)
      }
      let beforeRecharge = await transaction.runtime.snapshot()
      let rechargeContext = try await transaction.context(.recharge)
      let rechargeReceipt = try await transaction.runtime.purchaseEMPModuleUpgrade(rechargeContext)
      let afterRecharge = await transaction.runtime.snapshot()
      #expect(rechargeReceipt.module == base.id && rechargeReceipt.axis == .recharge)
      #expect(rechargeReceipt.before == .init(power: 2, capacity: 0, recharge: 0))
      #expect(rechargeReceipt.after == .init(power: 2, capacity: 0, recharge: 1))
      #expect(rechargeReceipt.paidPrice == 15000)
      #expect(rechargeReceipt.resultingRevision == rechargeReceipt.sourceInventoryRevision + 1)
      #expect(afterRecharge.commander.credits == beforeRecharge.commander.credits - 15000)
      #expect(afterRecharge.commander.equipmentPurchaseHistory == history)
      let bought = await transaction.runtime.snapshot()
      let item = try #require(bought.currentEMPPlayerModule())
      try #require(
        item.id == base.id && item.empGrades?.indices == .init(power: 2, capacity: 0, recharge: 1))
      #expect(item.empGrades?.paid.last == rechargeReceipt)
      try #require(item.empBank?.capacity == 8 && item.empBank?.remaining == 0 && item.empBank?.lastDischarge == nil)
      #expect(bought.commander.equipmentPurchaseHistory == history)
      let disk = try NativeSaveTestFixture.readVersionedCommander(from: transaction.file)
      #expect(disk.fittedEquipment(at: .utility(.empPirateBlaster)) == item)
      let cold = GameRuntime()
      let pointer = try Data(contentsOf: transaction.file)
      try await cold.load(from: transaction.file, persistMigrations: false)
      #expect(await cold.snapshot().commander.fittedEquipment(at: .utility(.empPirateBlaster)) == item)
      #expect(try Data(contentsOf: transaction.file) == pointer)
      await transaction.runtime.key("0")
      actor = try await transaction.runtime.scriptCommand { game in
        // Original controlled UNIT initialization, before any live earning frames.
        try prepareEMPUnitScene(&game)
        game.speed = speed
        try insertEMPUnitTarget(&game)
        game.bodies[0].position = .init(0, 0, 200)
        game.bodies[0].physical?.velocity = .init(0, 0, 0)
        game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
        game.bodies[0].rotationRate = 0
        if let rearShield { game.rearShield = rearShield }
        try game.commander.grantEquipment("Energy Bomb", at: .utility(.energyBomb), provenance: .grant("EMP self-disable boundary"))
        if mining {
          try game.commander.grantEquipment("Targeting: Mining Module", at: .targetingMining, provenance: .grant("EMP propulsion boundary"))
          try game.commander.grantEquipment(
            LaserKind.mining.equipmentName, at: .laser(.front),
            provenance: .grant("EMP propulsion boundary"))
          try #require(game.commander.laser(on: .front) == .mining)
        }
        game.selectFlightTool(.empPirateBlaster)
        try requireEMPUnitBasicElectricalSource(game)
        try #require(EMPPulseProfile.resolve(for: game.commander).power == 128)
        return try #require(game.bodies[0].physical?.identity)
      }
      var scene = await transaction.runtime.snapshot()
      for _ in 0..<256 {
        if scene.currentEMPPlayerModule()?.empBank?.remaining == 8 { break }
        await transaction.runtime.setControls(empUnitAim(scene, actor: actor))
        let start = scene.commander.flightSimulation.physicalTime
        scene = await transaction.runtime.advance(delta: 0.1)
        try #require(scene.commander.flightSimulation.physicalTime == start + 0.1 && !scene.docked && scene.screen != .gameOver)
      }
      try #require(scene.currentEMPPlayerModule()?.empBank?.remaining == 8)
      try #require((scene.commander.savedPlayerElectrical?.remaining ?? 0) > 0)
      let readyDisk = try NativeSaveTestFixture.readVersionedCommander(from: transaction.file)
      #expect(readyDisk.savedPlayerElectrical == scene.commander.savedPlayerElectrical)
      #expect(readyDisk.fittedEquipment(at: .utility(.empPirateBlaster)) == scene.currentEMPPlayerModule())
      await transaction.runtime.setControls(empUnitAim(scene, actor: actor, fire: true))
      scene = await transaction.runtime.advance(delta: 0.1)
      let charge = try #require(scene.commander.savedEMPCharge)
      try #require(charge.phase == .charging && charge.target == actor)
      for _ in 0..<99 {
        await transaction.runtime.setControls(empUnitAim(scene, actor: actor, fire: true))
        scene = await transaction.runtime.advance(delta: 0.1)
        try #require(!scene.docked && scene.screen != .gameOver)
      }
      try #require(scene.commander.savedEMPCharge?.phase == .charging)
      #expect(abs(scene.commander.flightSimulation.physicalTime - charge.startedAt - 9.9) < 1e-8)
    } catch { transaction.clean(); throw error }
  }
  func clean() { purchase.clean() }
  func clearNormalShield() async throws {
    try await runtime.scriptCommand { game in
      let hull = game.energy
      let main = game.commander.savedPlayerElectrical
      game.applyDamage(game.frontShield, front: true)
      #expect(game.frontShield == 0 && game.energy == hull && game.commander.savedPlayerElectrical == main)
    }
  }
  func release() async throws -> (Game, EMPPulseBeforeResult, Double) {
    let before = await runtime.snapshot()
    let accepted = min(0.1, 0.1)
    await runtime.setControls(empUnitAim(before, actor: actor, fire: true))
    let scene = await runtime.advance(delta: 0.1)
    try #require(scene.commander.flightSimulation.physicalTime == before.commander.flightSimulation.physicalTime + accepted)
    let result = try #require(scene.currentEMPPulseBeforeResult())
    let selfBefore = try #require(result.player)
    let shield = selfBefore.contactPoint.z >= 0 ? selfBefore.frontShield : selfBefore.rearShield
    try #require(
      selfBefore.electrical.remaining > 0
        && selfBefore.contactPower - shield >= selfBefore.electrical.remaining,
      Comment(rawValue: "EMP self premise power=\(selfBefore.contactPower) shield=\(shield)"
        + " remaining=\(selfBefore.electrical.remaining) capacity=\(selfBefore.electrical.capacity)"
        + " recharge=\(selfBefore.electrical.recharge) time=\(selfBefore.electrical.physicalTime)"))
    try expectEMPSelfLaw(result, game: scene)
    try #require(scene.playerEMPDisabled && scene.commander.savedPlayerElectrical?.disabledAt == result.charge.endedAt)
    #expect(scene.currentEMPPlayerModule()?.empBank?.remaining == 0)
    #expect(scene.currentEMPPlayerModule()?.empBank?.lastDischarge == result.charge)
    #expect(scene.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == 1)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: purchase.file)
    #expect(saved.savedPlayerElectrical == scene.commander.savedPlayerElectrical)
    #expect(saved.fittedEquipment(at: .utility(.empPirateBlaster)) == scene.currentEMPPlayerModule())
    return (scene, result, accepted)
  }
}
struct EMPElectricalRuntimeTests {
  @Test func chargingUsesRealSimulationSecondsAndRepeatedTriggerDoesNotRestartIt() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let target = try #require(scene.bodies[0].physical?.identity)
      let start = scene.commander.flightSimulation.physicalTime
      let began = scene.fireEMPPirateBlaster()
      try #require(began)
      let charge = scene.commander.savedEMPCharge
      let firedAgain = scene.fireEMPPirateBlaster()
      #expect(!firedAgain && scene.commander.savedEMPCharge == charge)
      for _ in 0..<99 { try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target, fire: true), publish: publish) }
      #expect(scene.commander.savedEMPCharge?.phase == .charging && scene.commander.savedEMPState == nil)
      #expect(scene.bodies.first { $0.physical?.identity == target }?.physical?.npc?.resources?.electrical == nil)
      try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target, fire: true), publish: publish, finish: false)
      #expect(abs(scene.commander.flightSimulation.physicalTime - start - 10) < 1e-8)
      let result = try #require(scene.currentEMPPulseBeforeResult())
      let body = try #require(scene.bodies.first { $0.physical?.identity == target })
      try expectEMPPrimaryLaw(result, body: body)
      #expect(body.physical?.empSource == nil && body.physical?.npc?.resources?.electrical != nil)
      #expect(scene.dischargeAudio.events.last?.tool == .empPirateBlaster)
      try #require(scene.postedEMPPlayerElectrical() != nil)
      #expect(scene.currentEMPPlayerModule()?.empBank?.remaining == 0)
      scene.finishEMPPlayerElectricalInterval(publish: publish)
    }
  }

  @Test func shieldedIncomingFireDoesNotLatchTheNextManualEMPCharge() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let target = try #require(scene.bodies[0].physical?.identity)
      let first = try emitEMPUnitPulse(&scene, publish: publish).charge
      try #require(scene.dischargeAudio.events.count == 1)
      for _ in 0..<17 { try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target), publish: publish) }
      try #require(scene.commander.savedEMPCharge == nil && scene.fireCooldown == 0)
      try earnEMPUnitBank(&scene, publish: publish, file: file)
      try #require(scene.workGuidance == nil && scene.workBraking == nil && scene.frontShield > 1)
      let shield = scene.frontShield
      let hull = scene.energy
      scene.applyDamage(1, front: true)
      #expect(scene.frontShield == shield - 1 && scene.energy == hull && !scene.workFireSuspended)
      try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target, fire: true), publish: publish)
      let second = try #require(scene.commander.savedEMPCharge)
      #expect(second.phase == .charging && second.target == target)
      #expect(second.weapon == first.weapon && second.owner == first.owner && second.hull == first.hull)
      #expect(second.startedAt >= first.startedAt + 10)
      #expect(scene.dischargeAudio.events.count == 1 && !scene.workFireSuspended)
      #expect(!scene.docked && scene.screen != .gameOver)
    }
  }

  @Test func realAttributedECMPreventsReleaseAfterItsTransientFieldExpires() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let began = scene.fireEMPPirateBlaster()
      try #require(began)
      try scene.commander.grantEquipment("E.C.M. System", at: .utility(.ecm), provenance: .grant("EMP ECM boundary"))
      let emitter = try #require(scene.commander.flightSimulation.player)
      let bank = scene.currentEMPPlayerModule()?.empBank?.remaining
      scene.ecm()
      try #require(scene.ecmFrames > 0)
      let cancellation = try #require(scene.commander.savedEMPCharge?.cancellingECM)
      #expect(cancellation.emitter == emitter && scene.commander.savedEMPCharge?.phase == .cancelled)
      let count = scene.ecmControl.events.count
      for _ in 0..<101 { try empUnitFrame(&scene, controls: empUnitAim(scene, fire: true), publish: publish) }
      #expect(scene.ecmFrames == 0 && scene.commander.savedEMPCharge?.phase == .cancelled)
      #expect(scene.commander.savedEMPCharge?.cancellingECM == cancellation)
      #expect(scene.commander.savedEMPState == nil && scene.dischargeAudio.events.isEmpty)
      #expect(scene.ecmControl.events.count == count && scene.currentEMPPlayerModule()?.empBank?.remaining == bank)
      #expect(scene.currentEMPPulseBeforeResult() == nil)
    }
  }

  @Test func releaseRevalidatesCurrentWeaponAndRealNearestOccludingMeshWithoutCost() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let began = scene.fireEMPPirateBlaster()
      try #require(began)
      let actor = try #require(scene.commander.savedEMPCharge?.target)
      for _ in 0..<99 { try empUnitFrame(&scene, controls: empUnitAim(scene, actor: actor, fire: true), publish: publish) }
      scene.bodies.append(.init(id: 99, hull: .asteroid, position: .init(0, 0, 300)))
      scene.nextBodyID = max(100, scene.nextBodyID)
      scene.ensurePhysicalActors()
      var control = scene
      let controls = empUnitAim(scene, actor: actor, fire: true)
      try empUnitFrame(&scene, controls: controls, publish: publish, finish: false)
      try empUnitFrame(&control, controls: controls, publish: nil, finish: false)
      let contact = try scene.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1), range: Game.empRange, radius: 0, includePlayer: false)
      try #require(contact?.hit.target == .body(99))
      #expect(scene.commander.savedEMPCharge?.phase == .released)
      #expect(scene.commander == control.commander && scene.bodies == control.bodies)
      #expect(scene.energy == control.energy && scene.laserHeat == control.laserHeat)
      #expect(scene.commander.flightSimulation.nextEmission == control.commander.flightSimulation.nextEmission)
      #expect(scene.commander.savedEMPState == nil && scene.commander.savedPlayerElectrical == control.commander.savedPlayerElectrical)
      #expect(scene.dischargeAudio.events.isEmpty && scene.currentEMPPulseBeforeResult() == nil)
      scene.finishEMPPlayerElectricalInterval(publish: publish)
      control.finishEMPPlayerElectricalInterval(publish: nil)
      #expect(scene.commander == control.commander)
    }
  }

  @Test func primaryUsesOnlyTheStruckShieldThenElectricalReserveAndNeverHullEnergy() throws {
    var game = try electricalGame()
    let actor = try #require(game.bodies[0].physical?.identity)
    try releaseElectricalPulse(&game) { scene in
      let i = try #require(scene.bodies.firstIndex { $0.physical?.identity == actor })
      let contact = try scene.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: EMPPulseProfile.resolve(for: scene.commander).range, radius: 0, includePlayer: false)
      let hit = try #require(contact?.hit)
      try #require(hit.target == .body(scene.bodies[i].id))
      let front = (hit.point - scene.bodies[i].position).dot(scene.bodies[i].modelVector(.init(0, 0, 1))) >= 0
      scene.bodies[i].physical?.npc?.resources?.frontShield = front ? 7 : 90
      scene.bodies[i].physical?.npc?.resources?.rearShield = front ? 90 : 7
    }
    let result = try #require(game.currentEMPPulseBeforeResult())
    let target = try #require(game.bodies.first { $0.physical?.identity == actor })
    try expectEMPPrimaryLaw(result, body: target)
    let front = result.primary.contactOffset.dot(result.primary.modelForward) >= 0
    let shield = front ? result.primary.frontShield : result.primary.rearShield
    try #require(shield > 0 && shield < result.primary.contactPower)
    try #require((target.physical?.npc?.resources?.electrical?.remaining ?? 0) > 0)
    #expect(target.physical?.empSource == nil && game.commander.savedEMPState == nil)
    #expect(result.primary.contactPower == 32)
    #expect(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
    #expect(game.laserHeat == 18 && game.fireCooldown == 1.5)
  }

  @Test func onlyRealZeroDisablesAndDeadlineReturnsCurrentHullAndRemainingOriginalPeople() throws {
    var game = try electricalGame()
    let actor = try #require(game.bodies[0].physical?.identity)
    try releaseElectricalPulse(&game) { scene in
      let index = try #require(scene.bodies.firstIndex { $0.physical?.identity == actor })
      var resources = try #require(scene.bodies[index].physical?.npc?.resources)
      resources.frontShield = 0; resources.rearShield = 0
      let now = scene.commander.flightSimulation.physicalTime
      var reserve = try #require(ElectricalReserve(capacity: resources.energyCapacity, recharge: resources.electricalRecharge, at: now))
      let damaged = reserve.drain(resources.energyCapacity - 5, at: now)
      try #require(damaged)
      resources.electrical = reserve
      scene.bodies[index].physical?.npc?.resources = resources
    }
    let result = try #require(game.currentEMPPulseBeforeResult())
    let original = try #require(game.bodies.first { $0.physical?.identity == actor })
    try expectEMPPrimaryLaw(result, body: original)
    let source = try #require(game.bodies[0].physical?.empSource)
    let disabled = try #require(game.commander.savedEMPState?.records[source])
    #expect(disabled.crewAboard == disabled.crewTotal && !disabled.isRecovered)
    #expect(
      game.isEMPDisabled(game.bodies[0])
        && game.targetColourCue(for: game.bodies[0]) == .recoverable)
    // No ejection tick occurs in this boundary test; recovery must use the exact
    // current damaged craft, not its original stock capacity or condition.
    game.bodies[0].energy = original.energy - 3
    let updated = game.persistEMPState()
    try #require(updated)
    game.commander.flightSimulation.advancePhysicalTime(30)
    game.advanceEMPActors()
    #expect(game.isEMPDisabled(game.bodies[0]))
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceEMPActors()
    let recovered = try #require(game.commander.savedEMPState?.records[source])
    let body = try #require(
      game.bodies.first { $0.physical?.identity == original.physical?.identity })
    #expect(
      recovered.isRecovered && !recovered.terminal && recovered.crewAboard == disabled.crewTotal)
    #expect(body.energy == original.energy - 3 && body.physical?.empSource == nil)
    #expect(body.physical?.salvage == nil && !game.isEMPDisabled(body))
    #expect(game.commander.npcPersistence.binding(for: source) == body.physical?.identity)
    #expect(game.commander.npcPersistence.terminalReason(for: source) == nil)
    #expect(body.physical?.npc?.ordinaryCargo == original.physical?.npc?.ordinaryCargo)
    #expect(game.commander.valid)
  }

  @Test func reserveUpgradeClampsWithoutRefillingAndDisabledRechargeWaitsForItsOriginalDeadline()
    throws
  {
    var reserve = try #require(ElectricalReserve(capacity: 100, recharge: 2, at: 0))
    let drained = reserve.drain(80, at: 0)
    try #require(drained)
    let upgraded = reserve.advance(to: 0, capacity: 200, recharge: 4)
    #expect(upgraded && reserve.remaining == 20)
    let zero = reserve.drain(20, at: 1)
    #expect(zero && reserve.disabledAt == 1)
    let progressed = reserve.advance(to: 30, capacity: 200, recharge: 4)
    #expect(progressed && reserve.remaining == 0 && reserve.recoveryAt == 31)
    let early = reserve.recover(at: 30)
    #expect(!early && reserve.disabledAt == 1)
    let recovered = reserve.recover(at: 32)
    #expect(recovered && reserve.remaining == 4 && reserve.disabledAt == nil)
    #expect(reserve.valid)
  }
}

extension EMPElectricalRuntimeTests {
  @Test func realTargetCentredSplashCanDisablePlayerWithoutHullDamageAndBombStillWorks() async throws {
    let fixture = try await EMPSelfDisableFixture(rearShield: 32)
    defer { fixture.clean() }
    try await fixture.clearNormalShield()
    let (disabled, result, _) = try await fixture.release()
    try expectEMPSelfLaw(result, game: disabled)
    #expect(disabled.commander.savedPlayerElectrical?.remaining == 0)
    try await fixture.runtime.scriptCommand { game in
      let emission = game.commander.flightSimulation.nextEmission
      game.fireCooldown = 0
      game.fireLaser(); game.beginHyperspace()
      #expect(game.commander.flightSimulation.nextEmission == emission && game.jumpCountdown == nil)
    }
    let beforeBomb = await fixture.runtime.snapshot()
    try #require(beforeBomb.energy > 180)
    await fixture.runtime.key("energy-bomb")
    let after = await fixture.runtime.snapshot()
    #expect(after.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
    #expect(after.energy > 0 && after.commander.valid)
  }

  @Test func actualOwnedEscapeClearsWarmupAndItsOldContextOnlyOnSuccessfulEscape() throws {
    var game = try electricalGame()
    try game.commander.grantEquipment(
      "Escape Pod", at: .utility(.escapePod),
      provenance: .grant("EMP emergency escape boundary"))
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    let owner = game.commander.equipmentOwnerID
    game.escapePod()
    #expect(game.docked && game.commander.valid)
    #expect(game.commander.equipmentOwnerID == owner)
    #expect(game.commander.savedEMPCharge == nil && game.commander.savedPlayerElectrical == nil)
    #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) == nil)
    game.launch()
    #expect(!game.docked && game.commander.valid && !game.playerEMPDisabled)
  }

  @Test func newElectricalFieldsCannotBeErasedByLegacyHeaderOrRawDecoding() throws {
    for key in ["savedPlayerElectrical", "savedEMPCharge"] {
      let bytes = try JSONSerialization.data(withJSONObject: [key: NSNull()])
      #expect(throws: SaveError.self) { try ElectricalVersionedSave.rejectFields(bytes) }
    }
    for key in ["electrical", "legacyElectricalRecharge"] {
      let bytes = try JSONSerialization.data(withJSONObject: [
        "bodies": [["physical": ["npc": ["resources": [key: NSNull()]]]]]
      ])
      #expect(throws: SaveError.self) { try ElectricalVersionedSave.rejectFields(bytes) }
    }
    try ElectricalVersionedSave.rejectFields(
      try JSONSerialization.data(withJSONObject: [
        "savedScriptState": ["data": ["electrical": 4]],
        "bodies": [["scriptNPC": ["data": ["electrical": 7]]]],
      ]))
  }
}

extension EMPElectricalRuntimeTests {
  @Test func actualSelfDisableAndTabCannotRestartPoweredWorkUntilEarnedRecovery() async throws {
    let fixture = try await EMPSelfDisableFixture(mining: true, speed: 1)
    defer { fixture.clean() }
    try await fixture.clearNormalShield()
    let (disabled, _, _) = try await fixture.release()
    let momentum = disabled.flightWorldVelocity
    try #require(disabled.energy > 180)
    await fixture.runtime.key("energy-bomb")
    let actor = try await fixture.runtime.scriptCommand { game in
      let anchors = try #require(game.commander.flightSimulation.anchors)
      game.miningFields = MiningFields.generate(anchors: anchors, seed: game.gameplaySeed)
      let rock = try #require(game.miningFields.first?.rocks.first)
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      var body = SpaceBody(id: 80, hull: .asteroid, position: .init(0, 0, 1500))
      body.energy = rock.energy
      body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
      game.bodies.append(body); game.nextBodyID = max(81, game.nextBodyID)
      game.key("f")
      try #require(game.workTargetFilter == .mining)
      return actor
    }
    let attained = await fixture.runtime.snapshot()
    let controlFile = fixture.purchase.folder.appendingPathComponent("control.json")
    let control = GameRuntime(game: attained, saveURL: controlFile)
    try await control.save(to: controlFile)
    await fixture.runtime.key("tab")
    await fixture.runtime.setControls(Controls()); await control.setControls(Controls())
    for _ in 0..<10 {
      let game = await fixture.runtime.advance(delta: 0.1)
      let reference = await control.advance(delta: 0.1)
      #expect(game.playerEMPDisabled && game.workGuidance == nil && game.workBraking == nil)
      #expect(game.lastAppliedWorkMotion == nil)
      #expect(game.commander.flightSimulation.pose == reference.commander.flightSimulation.pose)
      #expect((game.flightWorldVelocity - momentum).length < 1e-8)
      #expect(game.energy == reference.energy && game.commander == reference.commander)
    }
    var game = await fixture.runtime.snapshot()
    for _ in 0..<301 {
      if !game.playerEMPDisabled { break }
      game = await fixture.runtime.advance(delta: 0.1)
    }
    try #require(!game.playerEMPDisabled && game.screen != .gameOver)
    await fixture.runtime.key("tab")
    try #require(await fixture.runtime.snapshot().workGuidance?.parent == actor)
    let powered = await fixture.runtime.advance(delta: 0.1)
    #expect(powered.lastAppliedWorkMotion != nil)
  }

  @Test func cockpitReportsElectricalPowerHullAndActualWarmupSeparately() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let began = scene.fireEMPPirateBlaster()
      try #require(began)
      let target = try #require(scene.commander.savedEMPCharge?.target)
      try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target, fire: true), publish: publish)
      let charging = Display.cockpit(scene, width: 768, height: 768)
      #expect(charging.labels.contains { $0.text.contains("EMP CHARGE: 9.9 S") })
      for _ in 0..<99 { try empUnitFrame(&scene, controls: empUnitAim(scene, actor: target, fire: true), publish: publish) }
      try #require(scene.currentEMPPulseBeforeResult() != nil)
      let frame = Display.cockpit(scene, width: 768, height: 768)
      #expect(frame.labels.contains { $0.text == "Hull" })
      #expect(frame.labels.contains { $0.text.contains("POWER:") })
      let body = try #require(scene.bodies.first { $0.id == 42 })
      let fields = TargetTelemetry.fields(facts: scene.telemetryFacts(for: body), tier: .military,
        targetIsShip: true, observerGalaxy: scene.commander.galaxy)
      #expect(fields.contains { $0.label == "Electrical power" })
    }
  }
}

extension EMPElectricalRuntimeTests {
  @Test func selfDisabledSpinKeepsItsActualInertiaUntilPositiveEarnedPowerReturns() async throws {
    let fixture = try await EMPSelfDisableFixture()
    defer { fixture.clean() }
    try await fixture.clearNormalShield()
    await fixture.runtime.key("v"); await fixture.runtime.key("spin:cw")
    let before = await fixture.runtime.snapshot()
    try #require(before.spin.actualRate == 0 && before.spin.commandedRate > 0)
    let (disabled, _, accepted) = try await fixture.release()
    let inertia = disabled.spin.actualRate
    let command = disabled.spin.commandedRate
    #expect(inertia == min(command, SpinControl.responseRate * accepted))
    try #require(inertia > 0 && inertia < command)
    try #require(disabled.energy > 180)
    await fixture.runtime.key("energy-bomb")
    await fixture.runtime.setControls(Controls())
    var game = await fixture.runtime.snapshot()
    for _ in 0..<301 {
      if !game.playerEMPDisabled { break }
      game = await fixture.runtime.advance(delta: 0.1)
      if game.playerEMPDisabled { #expect(game.spin.actualRate == inertia && game.spin.commandedRate == command) }
    }
    try #require(!game.playerEMPDisabled && game.screen != .gameOver)
    #expect(game.spin.actualRate > inertia && game.spin.actualRate <= command)
  }
}

extension EMPElectricalRuntimeTests {
  @Test func lateUnrelatedNPCPersistenceRefusalRollsBackTheWholeZeroPowerPulse() throws {
    var game = try electricalGame()
    try withEMPUnitWriter(&game) { scene, publish, file in
      let began = scene.fireEMPPirateBlaster()
      try #require(began)
      let actor = try #require(scene.commander.savedEMPCharge?.target)
      for _ in 0..<99 { try empUnitFrame(&scene, controls: empUnitAim(scene, actor: actor, fire: true), publish: publish) }
      let now = scene.commander.flightSimulation.physicalTime
      scene.bodies.append(.init(id: 99, hull: .cobra, position: .init(4000, 1000, 9000)))
      scene.nextBodyID = max(100, scene.nextBodyID)
      scene.ensurePhysicalActors()
      let bad = try #require(scene.bodies.firstIndex { $0.id == 99 })
      let ship = try #require(ShipCatalogue.nativeShip(.cobra))
      let native = try #require(ship.game)
      scene.bodies[bad].physical?.catalogueShipID = ship.id
      var badResources = try #require(NPCResources.stock(native))
      // Real advance refuses this future NPC cursor before its normal hull clamp.
      // This unrelated invalid snapshot is a unit fault, never player earning authority.
      badResources.electrical = try #require(ElectricalReserve(capacity: badResources.energyCapacity,
        recharge: badResources.electricalRecharge, at: now + 1))
      scene.bodies[bad].physical?.npc?.resources = badResources
      scene.bodies[bad].energy = native.energy * 2
      let primary = try #require(scene.bodies.firstIndex { $0.physical?.identity == actor })
      var resources = try #require(scene.bodies[primary].physical?.npc?.resources)
      resources.frontShield = 0; resources.rearShield = 0
      var reserve = try #require(ElectricalReserve(capacity: resources.energyCapacity,
        recharge: resources.electricalRecharge, at: now))
      let damaged = reserve.drain(resources.energyCapacity - 5, at: now)
      try #require(damaged)
      resources.electrical = reserve
      scene.bodies[primary].physical?.npc?.resources = resources
      try #require(scene.commander.valid)
      let context = try #require(scene.gameplayContext())
      try #require(NPCPersistenceSnapshot.capture(body: scene.bodies[bad], pose: scene.commander.flightSimulation.pose,
        physicalTime: now, protection: context.protection) == nil)
      var control = scene
      let controls = empUnitAim(scene, actor: actor, fire: true)
      try empUnitFrame(&scene, controls: controls, publish: publish, finish: false)
      try empUnitFrame(&control, controls: controls, publish: nil, finish: false)
      let actualBad = try #require(scene.bodies.first { $0.id == 99 })
      try #require(actualBad.energy == native.energy * 2)
      try #require((actualBad.physical?.npc?.resources?.electrical?.physicalTime ?? 0) > scene.commander.flightSimulation.physicalTime)
      try #require(NPCPersistenceSnapshot.capture(body: actualBad, pose: scene.commander.flightSimulation.pose,
        physicalTime: scene.commander.flightSimulation.physicalTime, protection: context.protection) == nil)
      #expect(scene.commander.savedEMPCharge?.phase == .released && scene.commander == control.commander)
      #expect(scene.bodies == control.bodies && scene.scriptSimulationSave.randomState == control.scriptSimulationSave.randomState)
      #expect(scene.dischargeAudio.epoch == control.dischargeAudio.epoch && scene.dischargeAudio.events == control.dischargeAudio.events)
      #expect(scene.energy == control.energy && scene.laserHeat == control.laserHeat)
      #expect(scene.commander.savedEMPState == nil && scene.commander.savedPlayerElectrical == control.commander.savedPlayerElectrical)
      #expect(scene.currentEMPPlayerModule()?.empBank?.remaining == 8 && scene.currentEMPPulseBeforeResult() == nil)
      #expect(scene.message == "EMP RELEASE REFUSED - TARGET OR EQUIPMENT CHANGED")
      scene.finishEMPPlayerElectricalInterval(publish: publish)
      control.finishEMPPlayerElectricalInterval(publish: nil)
      #expect(scene.commander == control.commander)
    }
  }
}
