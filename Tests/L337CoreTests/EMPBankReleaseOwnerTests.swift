import Foundation
import Testing

@testable import L337Core

func fixturePublisher(_ file: URL) -> ScriptPublisher {
  { candidate in try GameRuntime.writeCommander(&candidate, to: file) }
}

struct EMPPreparedBankOwner: Sendable {
  let purchase: EMPModulePurchaseFixture
  let actor: ActorIdentity
}

/// A controlled paid unit scene; native acceptance uses paidEMPNativeFixture and the800-frame helper.
func preparedEMPBankOwner(power: Int = 0, close: Bool = false) async throws -> EMPPreparedBankOwner {
  let purchase = try await EMPModulePurchaseFixture(useOwnedStarter: true)
  do {
    let initial = await purchase.runtime.snapshot()
    let ownedPreparationRequired1 = initial.currentEMPPlayerModule()
    let original = try #require(ownedPreparationRequired1)
    #expect(original.empGrades == .base && original.empBank?.remaining == 0)
    for step in 0..<power {
      let before = await purchase.runtime.snapshot()
      let context = try await purchase.context(.power)
      let receipt = try await purchase.runtime.purchaseEMPModuleUpgrade(context)
      let after = await purchase.runtime.snapshot()
      #expect(receipt.module == original.id && receipt.before.power == step && receipt.after.power == step + 1)
      #expect(receipt.paidPrice == EMPModuleGradePolicy.offer(axis: .power, next: step + 1)?.price)
      #expect(after.commander.credits == before.commander.credits - receipt.paidPrice)
    }
    let bought = await purchase.runtime.snapshot()
    let ownedPreparationRequired2 = bought.currentEMPPlayerModule()?.empBank?.remaining == 0
    try #require(ownedPreparationRequired2)
    let ownedPreparationRequired3 = bought.currentEMPPlayerModule()?.empGrades?.power == power
    try #require(ownedPreparationRequired3)
    let disk = try NativeSaveTestFixture.readVersionedCommander(from: purchase.file)
    #expect(disk.fittedEquipment(at: .utility(.empPirateBlaster)) == bought.currentEMPPlayerModule())
    await purchase.runtime.key("0")
    let actor = try await purchase.runtime.scriptCommand { game in
      // Original unit initialization is complete before live earning. No later actor removal.
      try prepareEMPUnitScene(&game)
      try insertEMPUnitTarget(&game)
      game.bodies[0].physical?.velocity = .init(0, 0, 0)
      game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
      game.bodies[0].rotationRate = 0
      if close { game.bodies[0].position = .init(0, 0, 200) }
      game.selectFlightTool(.empPirateBlaster)
      try requireEMPUnitBasicElectricalSource(game)
      return try #require(game.bodies[0].physical?.identity)
    }
    var game = await purchase.runtime.snapshot()
    for _ in 0..<256 {
      if game.currentEMPPlayerModule()?.empBank?.remaining == 8 { break }
      await purchase.runtime.setControls(empUnitAim(game, actor: actor))
      let start = game.commander.flightSimulation.physicalTime
      game = await purchase.runtime.advance(delta: 0.1)
      try #require(game.commander.flightSimulation.physicalTime == start + 0.1 && !game.docked && game.screen != .gameOver)
    }
    let ownedPreparationRequired4 = game.currentEMPPlayerModule()?.empBank?.remaining == 8
    try #require(ownedPreparationRequired4)
    await purchase.runtime.setControls(empUnitAim(game, actor: actor, fire: true))
    game = await purchase.runtime.advance(delta: 0.1)
    let charge = try #require(game.commander.savedEMPCharge)
    try #require(charge.phase == .charging && charge.target == actor)
    for _ in 0..<99 {
      await purchase.runtime.setControls(empUnitAim(game, actor: actor, fire: true))
      game = await purchase.runtime.advance(delta: 0.1)
      try #require(!game.docked && game.screen != .gameOver)
    }
    try #require(game.commander.savedEMPCharge?.phase == .charging)
    #expect(abs(game.commander.flightSimulation.physicalTime - charge.startedAt - 9.9) < 1e-8)
    return .init(purchase: purchase, actor: actor)
  } catch { purchase.clean(); throw error }
}

private func observedFailingEMPPublisher(file: URL, marker: URL) -> ScriptPublisher {
  { candidate in
    var bytes = (try? Data(contentsOf: marker)) ?? Data()
    bytes.append(1)
    try bytes.write(to: marker)
    try GameRuntime.writeCommander(&candidate, to: file)
  }
}

struct EMPBankReleaseOwnerTests {
  @Test func earned000RealWriterAndBank8NoMain8() async throws {
    let ready = try await preparedEMPBankOwner()
    defer { ready.purchase.clean() }
    var game = await ready.purchase.runtime.snapshot()
    let item = try #require(game.currentEMPPlayerModule())
    let history = game.commander.equipmentPurchaseHistory
    let publish = fixturePublisher(ready.purchase.file)
    try empUnitFrame(&game, controls: empUnitAim(game, actor: ready.actor, fire: true), publish: publish, finish: false)
    let result = try #require(game.currentEMPPulseBeforeResult())
    let body = try #require(game.bodies.first { $0.physical?.identity == ready.actor })
    try expectEMPPrimaryLaw(result, body: body)
    if result.player != nil { try expectEMPSelfLaw(result, game: game) }
    // The checked closing header would fail if the emitter silently took an unaccounted main8.
    let main = try #require(game.postedEMPPlayerElectrical())
    let interval = try #require(game.empPlayerElectricalInterval)
    #expect(main == interval.closing && main.remaining > 0)
    let beforeBank = try #require(item.empBank)
    #expect(game.currentEMPPlayerModule()?.empBank?.remaining == beforeBank.remaining - 8)
    #expect(game.currentEMPPlayerModule()?.empBank?.lastDischarge == result.charge)
    #expect(game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == 1)
    game.finishEMPPlayerElectricalInterval(publish: publish)
    #expect(game.commander.savedPlayerElectrical == main)
    try expectEMPModuleProperty(item, #require(game.currentEMPPlayerModule()))
    #expect(game.commander.equipmentPurchaseHistory == history)
    let pointer = try Data(contentsOf: ready.purchase.file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: ready.purchase.file)
    #expect(saved.savedPlayerElectrical == main)
    #expect(saved.fittedEquipment(at: .utility(.empPirateBlaster)) == game.currentEMPPlayerModule())
    let cold = GameRuntime()
    try await cold.load(from: ready.purchase.file, persistMigrations: false)
    #expect(await cold.snapshot().commander.savedPlayerElectrical == main)
    #expect(await cold.snapshot().commander.equipmentPurchaseHistory == history)
    #expect(try Data(contentsOf: ready.purchase.file) == pointer)
  }

  @Test func realWarmupECMOcclusionRefusal() async throws {
    for fault in ["ecm", "mesh", "weapon"] {
      let ready = try await preparedEMPBankOwner()
      defer { ready.purchase.clean() }
      var game = await ready.purchase.runtime.snapshot()
      if fault == "ecm" {
        try game.commander.grantEquipment("E.C.M. System", at: .utility(.ecm), provenance: .grant("real ECM owner refusal"))
        game.ecm()
        let activation = try #require(game.commander.savedEMPCharge?.cancellingECM)
        #expect(activation.emitter == game.commander.flightSimulation.player)
      } else if fault == "mesh" {
        game.bodies.append(.init(id: 99, hull: .asteroid, position: .init(0, 0, 300)))
        game.nextBodyID = max(100, game.nextBodyID); game.ensurePhysicalActors()
      } else { game.selectFlightTool(.salvageCutter) }
      var control = game
      let controls = empUnitAim(game, actor: ready.actor, fire: true)
      try empUnitFrame(&game, controls: controls, publish: fixturePublisher(ready.purchase.file), finish: false)
      try empUnitFrame(&control, controls: controls, publish: nil, finish: false)
      #expect(game.commander == control.commander && game.bodies == control.bodies)
      #expect(game.currentEMPPulseBeforeResult() == nil && game.commander.savedEMPState == nil)
      #expect(game.currentEMPPlayerModule()?.empBank?.remaining == 8)
      #expect(game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.isEmpty)
      if fault == "mesh" {
        let contact = try game.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1), range: Game.empRange, radius: 0, includePlayer: false)
        try #require(contact?.hit.target == .body(99))
        #expect(game.commander.savedEMPCharge?.phase == .released)
      } else { #expect(game.commander.savedEMPCharge?.phase == .cancelled) }
      game.finishEMPPlayerElectricalInterval(publish: fixturePublisher(ready.purchase.file))
      control.finishEMPPlayerElectricalInterval(publish: nil)
      #expect(game.commander == control.commander)
    }
  }

  @Test func writerFailurePreservesAttainedFacts() async throws {
    let purchase = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { purchase.clean() }
    await purchase.runtime.key("0")
    var game = await purchase.runtime.snapshot()
    let block = purchase.folder.appendingPathComponent("blocked")
    try Data([1]).write(to: block)
    let bad = block.appendingPathComponent("commander.json")
    let marker = purchase.folder.appendingPathComponent("attempts")
    let failing = observedFailingEMPPublisher(file: bad, marker: marker)
    let pointer = try Data(contentsOf: purchase.file)
    try empUnitFrame(&game, publish: failing, finish: false)
    let attained = game.commander.savedPlayerElectrical
    try #require((attained?.remaining ?? 0) > 0)
    game.finishEMPPlayerElectricalInterval(publish: failing)
    #expect(game.commander.savedPlayerElectrical == attained && game.currentEMPPlayerModule()?.empBank?.remaining == 0)
    #expect(game.currentEMPPlayerModule()?.empBank?.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(try Data(contentsOf: marker).count == 1)
    let once = game.commander
    game.finishEMPPlayerElectricalInterval(publish: failing)
    let replayUnchanged = try (game.commander == once && Data(contentsOf: marker).count == 1)
    #expect(replayUnchanged)
    #expect(try Data(contentsOf: purchase.file) == pointer)
    let ready = try await preparedEMPBankOwner()
    defer { ready.purchase.clean() }
    var release = await ready.purchase.runtime.snapshot()
    var control = release
    let releaseBlock = ready.purchase.folder.appendingPathComponent("blocked")
    try Data([1]).write(to: releaseBlock)
    let releaseMarker = ready.purchase.folder.appendingPathComponent("attempts")
    let releaseFail = observedFailingEMPPublisher(file: releaseBlock.appendingPathComponent("commander.json"), marker: releaseMarker)
    let beforeFile = try Data(contentsOf: ready.purchase.file)
    let controls = empUnitAim(release, actor: ready.actor, fire: true)
    try empUnitFrame(&release, controls: controls, publish: releaseFail, finish: false)
    try empUnitFrame(&control, controls: controls, publish: nil, finish: false)
    #expect(try Data(contentsOf: releaseMarker).count == 1)
    #expect(release.commander == control.commander && release.bodies == control.bodies)
    #expect(release.dischargeAudio.events == control.dischargeAudio.events)
    #expect(release.currentEMPPulseBeforeResult() == nil && release.commander.savedEMPCharge?.phase == .released)
    #expect(release.currentEMPPlayerModule()?.empBank?.remaining == 8)
    release.finishEMPPlayerElectricalInterval(publish: releaseFail)
    #expect(try Data(contentsOf: releaseMarker).count == 1)
    #expect(try Data(contentsOf: ready.purchase.file) == beforeFile)
  }

  @Test func nilWriterReplayAndSubnormalHeadroom() async throws {
    let purchase = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { purchase.clean() }
    await purchase.runtime.key("0")
    var game = await purchase.runtime.snapshot()
    try empUnitFrame(&game, publish: nil, finish: false)
    let main = game.commander.savedPlayerElectrical
    game.finishEMPPlayerElectricalInterval(publish: nil)
    #expect(game.commander.savedPlayerElectrical == main && game.currentEMPPlayerModule()?.empBank?.remaining == 0)
    let once = game.commander
    game.finishEMPPlayerElectricalInterval(publish: fixturePublisher(purchase.file))
    #expect(game.commander == once)
    let tinyPurchase = try await EMPModulePurchaseFixture(useOwnedStarter: true)
    defer { tinyPurchase.clean() }
    await tinyPurchase.runtime.key("0")
    var tiny = await tinyPurchase.runtime.snapshot()
    try #require(tiny.commander.flightSimulation.physicalTime == 0)
    let full = try #require(ElectricalReserve(capacity: tiny.commander.performance.energy,
      recharge: tiny.commander.performance.recharge * tiny.commander.energyRechargeMultiplier, at: 0))
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(full)) as? [String: Any])
    object["remaining"] = Double.leastNonzeroMagnitude
    // A current, valid pre-existing tiny balance; only the actual accepted subnormal step can earn.
    tiny.commander.savedPlayerElectrical = try JSONDecoder().decode(ElectricalReserve.self, from: JSONSerialization.data(withJSONObject: object))
    try #require(tiny.commander.savedPlayerElectrical?.valid == true)
    try empUnitFrame(&tiny, delta: Double.leastNonzeroMagnitude, publish: fixturePublisher(tinyPurchase.file), finish: false)
    let attained = try #require(tiny.postedEMPPlayerElectrical())
    tiny.finishEMPPlayerElectricalInterval(publish: fixturePublisher(tinyPurchase.file))
    #expect(tiny.commander.savedPlayerElectrical == attained && attained.remaining > 0)
    #expect(tiny.currentEMPPlayerModule()?.empBank?.remaining == 0)
    let ready = try await preparedEMPBankOwner()
    defer { ready.purchase.clean() }
    var release = await ready.purchase.runtime.snapshot()
    try empUnitFrame(&release, controls: empUnitAim(release, actor: ready.actor, fire: true), publish: nil)
    #expect(release.commander.savedEMPCharge?.phase == .released && release.currentEMPPulseBeforeResult() == nil)
    #expect(release.currentEMPPlayerModule()?.empBank?.remaining == 8 && release.dischargeAudio.events.isEmpty)
    let cursor = release.commander.flightSimulation.nextEmission
    try empUnitFrame(&release, controls: empUnitAim(release, actor: ready.actor, fire: true), publish: nil)
    #expect(release.commander.flightSimulation.nextEmission == cursor)
  }

  @Test func currentFitIdentityGradesRevisionRefuse() async throws {
    for mode in ["held", "revision", "paid-dock"] {
      let purchase = try await EMPModulePurchaseFixture(useOwnedStarter: true)
      defer { purchase.clean() }
      await purchase.runtime.key("0")
      var game = await purchase.runtime.snapshot()
      let item = try #require(game.currentEMPPlayerModule())
      try empUnitFrame(&game, publish: fixturePublisher(purchase.file), finish: false)
      let attained = game.commander.savedPlayerElectrical
      if mode == "held" {
        try game.commander.storeEquipment(item, expectedRevision: #require(game.commander.equipmentInventory?.revision))
      } else if mode == "revision" {
        try game.commander.grantEquipment("Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("late actual inventory revision"))
      } else {
        game.dock()
        try #require(game.docked)
        game.screen = .equipment
        let runtime = GameRuntime(game: game, saveURL: purchase.file)
        try await runtime.save(to: purchase.file)
        let context = try game.empModulePurchaseContext(module: item.id, axis: .power)
        let receipt = try await runtime.purchaseEMPModuleUpgrade(context)
        game = await runtime.snapshot()
        #expect(receipt.before == .base && receipt.after.power == 1)
        // Real paid shop change includes docking; no isolated grade-only predicate claim.
      }
      game.finishEMPPlayerElectricalInterval(publish: fixturePublisher(purchase.file))
      #expect(game.commander.savedPlayerElectrical == attained && game.empPlayerElectricalInterval == nil)
      let physical = try #require(game.commander.equipmentInventory?.items.first { $0.id == item.id })
      #expect(physical.empBank?.remaining == 0)
      let fired = game.fireEMPPirateBlaster()
      #expect(!fired && game.currentEMPPulseBeforeResult() == nil)
    }
  }

  @Test func paidCurrentLoadoutEarnsTwoFullStockPulsesAndPreservesOriginalPeople() async throws {
    let (fixture, actor) = try await paidCurrentFullStockEMPFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let original = try #require(game.bodies.first { $0.physical?.identity == actor })
    let catalogue = try #require(original.physical?.catalogueShipID)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: catalogue))
    try #require(catalogue == EMPUnitTargetCatalogue.ordinary)
    let stock = try #require(NPCResources.stock(source.performance))
    let resources = try #require(original.physical?.npc?.resources)
    try #require(resources == stock && resources.profile == .nativeHull)
    try #require(original.energy == source.performance.energy && resources.electrical == nil)
    try #require(resources.frontShield == stock.frontCapacity)
    try #require(resources.rearShield == stock.rearCapacity)
    try #require(EMPState.declaredNativeCrewCount(source.ship) == 1)
    try #require(original.physical?.empSource == nil && game.commander.savedEMPState == nil)
    let hardware = try #require(game.commander.equipmentInventory)
    let history = try #require(game.commander.equipmentPurchaseHistory)
    let ownedPreparationRequired5 = game.currentEMPPlayerModule()
    let weapon = try #require(ownedPreparationRequired5)
    try #require(weapon.empBank?.remaining == 0 && weapon.empGrades?.power == 3)
    let profile = try EMPPulseProfile.resolve(for: game.commander)
    try #require(profile.energyStage == 1 && profile.power == 384 && profile.energyCost == 8)
    try #require(stock.energyCapacity + stock.rearCapacity > profile.power)
    let credits = game.commander.credits
    let cargo = game.commander.cargo
    let legal = game.commander.legal
    let kills = game.commander.kills
    let player = try #require(game.commander.flightSimulation.player)
    try #require(!original.hostile && original.physical?.npc?.firstAggressor == nil)
    try #require(original.physical?.npc?.legal.wanted == false)
    let baselineLaw = try JSONDecoder().decode(EMPTestAttackLedger.self,
      from: JSONEncoder().encode(game.commander.crimeLedger))
    try #require(baselineLaw.attacks.filter {
      ($0.owner == player && $0.victim == actor) || ($0.owner == actor && $0.victim == player)
    }.isEmpty)
    let run: EMPNativePulseRun
    do {
      run = try await disableNativeEMPActor(actor, game: &game) { scene in
        let result = try #require(scene.currentEMPPulseBeforeResult())
        let actual = try #require(scene.bodies.first { $0.physical?.identity == actor })
        try #require(result.charge.target == actor && result.primary.contactPower == profile.power)
        try #require(result.primary.electrical.remaining == stock.energyCapacity)
        try #require(result.primary.frontShield == stock.frontCapacity)
        try #require(result.primary.rearShield == stock.rearCapacity)
        try #require(result.primary.hullEnergy == source.performance.energy)
        try #require(!scene.isEMPDisabled(actual) && actual.physical?.empSource == nil)
        let positive = try #require(actual.physical?.npc?.resources?.electrical)
        try #require(positive.remaining > 0 && positive.disabledAt == nil)
        #expect(scene.commander.savedEMPState == nil)
        #expect(actual.energy == original.energy)
        #expect(actual.physical?.npc?.ordinaryCargo == original.physical?.npc?.ordinaryCargo)
        let firstTime = try #require(result.charge.endedAt)
        let law = try JSONDecoder().decode(EMPTestAttackLedger.self,
          from: JSONEncoder().encode(scene.commander.crimeLedger))
        let assaults = law.attacks.filter { $0.owner == player && $0.victim == actor }
        try #require(assaults.count == 1)
        let assault = try #require(assaults.first)
        #expect(assault.unlawful && !assault.authorityAction && assault.lastAttack == firstTime)
        #expect(scene.commander.legal == min(255, legal + 8))
        #expect(actual.physical?.npc?.firstAggressor == player)
        #expect(actual.physical?.npc?.intention == .engage(player) && actual.hostile)
        // Observe genuine return fire during the existing native refill; this grants no attack.
        scene.gameplayCombatTrace = .init()
      }
    } catch {
      let current = game.bodies.first { $0.physical?.identity == actor }
      let remaining = current?.physical?.npc?.resources
      let pulses = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
      Issue.record(Comment(rawValue: "Paid full-stock EMP source=\(catalogue) actor=\(actor)"
        + " time=\(game.commander.flightSimulation.physicalTime) emissions=\(pulses)"
        + " visible=\(current != nil) reserve=\(String(describing: remaining?.electrical))"
        + " shields=\(String(describing: remaining?.frontShield))"
        + "/\(String(describing: remaining?.rearShield))"))
      throw error
    }
    try #require(run.pulses.count == 2 && (0...800).contains(run.remainingFrames))
    let first = try #require(run.pulses.first)
    let last = try #require(run.pulses.last)
    let firstFront = first.primary.contactOffset.dot(first.primary.modelForward) >= 0
    let lastFront = last.primary.contactOffset.dot(last.primary.modelForward) >= 0
    try #require(firstFront == lastFront)
    let shield = lastFront ? last.primary.frontShield : last.primary.rearShield
    try #require(last.primary.electrical.remaining > 0)
    try #require(last.primary.contactPower == profile.power)
    try #require(last.primary.contactPower - shield >= last.primary.electrical.remaining)
    let firstTime = try #require(first.charge.endedAt)
    let lastTime = try #require(last.charge.endedAt)
    try #require(lastTime - firstTime > 10 && first.emissionID < last.emissionID)
    let lawAtZero = game.commander.crimeLedger
    let legalAtZero = game.commander.legal
    let finalLaw = try JSONDecoder().decode(EMPTestAttackLedger.self,
      from: JSONEncoder().encode(lawAtZero))
    let assaults = finalLaw.attacks.filter { $0.owner == player && $0.victim == actor }
    try #require(assaults.count == 1)
    let assault = try #require(assaults.first)
    #expect(assault.unlawful && !assault.authorityAction && assault.lastAttack == lastTime)
    // Each real pulse starts its own ten-second assault window; zero adds no extra offence.
    #expect(legalAtZero == min(255, legal + 16))
    let returns = finalLaw.attacks.filter { $0.owner == actor }
    try #require(returns.count == 1)
    let returnWindow = try #require(returns.first)
    #expect(returnWindow.victim == player && !returnWindow.unlawful && !returnWindow.authorityAction)
    let trace = try #require(game.gameplayCombatTrace)
    let retaliation = try #require(trace.incidents.last {
      $0.origin.owner == actor && $0.victim == player
        && ($0.outcome == .hit || $0.outcome == .targetedLaunch)
    })
    let record = try #require(game.commander.savedEMPState?.records[actor])
    #expect(retaliation.kind == .laser || retaliation.kind == .missile)
    #expect(retaliation.physicalTime > firstTime && retaliation.physicalTime == returnWindow.lastAttack)
    #expect(retaliation.origin.emissionID > first.emissionID)
    #expect(retaliation.origin.emissionID < last.emissionID && retaliation.id < record.disableIncident.id)
    #expect(record.disableIncident.origin.emissionID == last.emissionID)
    #expect(trace.incidents.filter { $0.id == record.disableIncident.id } == [record.disableIncident])
    try await verifyActualEMPZero(&game, original: original, expectedWindows: 1,
      hardware: hardware, history: history, weapon: weapon,
      credits: credits, cargo: cargo, legal: legal, kills: kills)
    #expect(game.commander.crimeLedger == lawAtZero && game.commander.legal == legalAtZero)
  }
}
