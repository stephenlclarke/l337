import Foundation
import Testing

@testable import L337Core

struct EMPPlayerElectricalPostingTests {
  @Test func actualBaseEMPChargingReachesExactlyOneShotWithBoundWriter() async throws {
    let fixture = try await EMPModulePurchaseFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let original = try EMPBankOwnershipFixture.item(initial.commander)
    let history = try #require(initial.commander.equipmentPurchaseHistory)
    let owner = try #require(initial.commander.equipmentOwnerID)
    try #require(EMPModuleGrades.hasPaidBase(original, owner: owner, history: history))
    try #require(original.empGrades == .base && original.empBank?.remaining == 0)
    try #require(original.empBank?.capacity == 8 && original.empBank?.lastDischarge == nil)
    try #require(initial.commander.savedPlayerElectrical == nil)
    try #require(initial.commander.energyRechargeMultiplier == 1)
    await fixture.runtime.key("0")
    let launched = await fixture.runtime.snapshot()
    try #require(!launched.docked && launched.screen.isFlight && !launched.paused)
    await fixture.runtime.setControls(Controls())
    var previousTime = launched.commander.flightSimulation.physicalTime
    var charged: Game?
    // A failing test bound, not a promise of readiness or extra native journey preparation.
    for _ in 0..<256 {
      let frame = await fixture.runtime.advance(delta: 0.1)
      try #require(!frame.docked && frame.screen.isFlight && !frame.paused && frame.energy > 0)
      let now = frame.commander.flightSimulation.physicalTime
      try #require(now > previousTime)
      previousTime = now
      let item = try EMPBankOwnershipFixture.item(frame.commander)
      let bank = try #require(item.empBank)
      #expect(item.id == original.id && item.empGrades == .base)
      #expect(item.provenance == original.provenance && item.component == original.component)
      #expect(frame.commander.equipmentPurchaseHistory == history)
      #expect(bank.capacity == 8 && bank.remaining >= 0 && bank.remaining <= 8)
      #expect(bank.physicalTime == now && bank.lastDischarge == nil)
      #expect(frame.commander.savedEMPCharge == nil)
      #expect(!frame.dischargeAudio.events.contains { $0.tool == .empPirateBlaster })
      if bank.remaining == 8 {
        charged = frame
        break
      }
    }
    let live = try #require(charged, "Actual owner did not earn exactly one shot within 256 frames")
    let liveItem = try EMPBankOwnershipFixture.item(live.commander)
    let main = try #require(live.commander.savedPlayerElectrical)
    try #require(main.valid && main.remaining > 0 && main.disabledAt == nil)
    #expect(main.physicalTime == live.commander.flightSimulation.physicalTime)
    #expect(liveItem.empBank?.remaining == 8 && liveItem.empGrades == .base)
    #expect(live.empPlayerElectricalInterval == nil)
    // No explicit save here: these bytes must come from the successful P5 publication.
    let pointer = try Data(contentsOf: fixture.file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: fixture.file)
    let savedItem = try EMPBankOwnershipFixture.item(saved)
    #expect(savedItem == liveItem)
    #expect(saved.savedPlayerElectrical == main)
    #expect(saved.equipmentPurchaseHistory == history)
    #expect(saved.flightSimulation.physicalTime == live.commander.flightSimulation.physicalTime)
    let cold = GameRuntime()
    try await cold.load(from: fixture.file, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(try EMPBankOwnershipFixture.item(restored.commander) == liveItem)
    #expect(restored.commander.savedPlayerElectrical == main)
    #expect(restored.commander.equipmentPurchaseHistory == history)
    #expect(restored.empPlayerElectricalInterval == nil)
    #expect(try Data(contentsOf: fixture.file) == pointer)
  }
}


/// These are controlled owner slices, not native flight acceptance.
private func freshEMPPostingUnit() async throws -> (EMPModulePurchaseFixture, Game) {
  let fixture = try await EMPModulePurchaseFixture()
  await fixture.runtime.key("0")
  let game = await fixture.runtime.snapshot()
  try #require(!game.docked && game.commander.savedPlayerElectrical == nil)
  try #require(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
  return (fixture, game)
}

extension EMPPlayerElectricalPostingTests {
  @Test func firstNilBindZeroAndGetterReadOnly() async throws {
    let (fixture, initial) = try await freshEMPPostingUnit()
    defer { fixture.clean() }
    var game = initial
    let publish: ScriptPublisher = { candidate in try GameRuntime.writeCommander(&candidate, to: fixture.file) }
    try empUnitFrame(&game, publish: publish, finish: false)
    let interval = try #require(game.empPlayerElectricalInterval)
    let main = try #require(game.postedEMPPlayerElectrical())
    #expect(interval.opening == nil && interval.generated == interval.recharge * interval.acceptedDelta)
    #expect(main.remaining == interval.generated && main.remaining < main.capacity)
    let before = game.commander
    #expect(game.postedEMPPlayerElectrical() == main && game.postedEMPPlayerElectrical() == main)
    #expect(game.commander == before)
    game.finishEMPPlayerElectricalInterval(publish: publish)
    #expect(game.postedEMPPlayerElectrical() == nil && game.empPlayerElectricalInterval == nil)
    var ordinary = try missionGearGame()
    ordinary.launch()
    try empUnitFrame(&ordinary, publish: nil)
    #expect(ordinary.commander.savedPlayerElectrical == nil && ordinary.postedEMPPlayerElectrical() == nil)
  }

  @Test func missingPlayerSkipNoAuthority() async throws {
    var game = try missionGearGame()
    try game.commander.grantEquipment(Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
      provenance: .grant("missing actual player unit boundary"))
    let writer = try EMPUnitWriter()
    defer { writer.clean() }
    let main = game.commander.savedPlayerElectrical
    let bank = game.currentEMPPlayerModule()?.empBank
    try #require(game.docked && game.commander.flightSimulation.player == nil)
    game.tick(delta: 0.1, controls: Controls(), nativeSalvagePublish: writer.publish)
    game.finishEMPPlayerElectricalInterval(publish: writer.publish)
    #expect(game.commander.flightSimulation.player == nil)
    #expect(game.commander.savedPlayerElectrical == main && game.currentEMPPlayerModule()?.empBank == bank)
    #expect(game.empPlayerElectricalInterval == nil && game.postedEMPPlayerElectrical() == nil)
  }

  @Test func acceptedOncePostNoGapOrUpgradeFill() async throws {
    let (fixture, initial) = try await freshEMPPostingUnit()
    defer { fixture.clean() }
    var game = initial
    let publish = fixturePublisher(fixture.file)
    try empUnitFrame(&game, publish: publish)
    let now = game.commander.flightSimulation.physicalTime
    var old = try #require(ElectricalReserve(capacity: game.commander.performance.energy,
      recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier, at: 0))
    let drained = old.drain(old.capacity - 1, at: 0)
    try #require(drained)
    // Existing saved state is behind the actual clock; it is not a generation entitlement.
    try #require(now > old.physicalTime)
    game.commander.savedPlayerElectrical = old
    try empUnitFrame(&game, publish: publish, finish: false)
    let synchronized = try #require(game.postedEMPPlayerElectrical())
    #expect(synchronized.remaining == 1 && game.empPlayerElectricalInterval?.generated == 0)
    game.postEMPPlayerElectricalInterval()
    #expect(game.commander.savedPlayerElectrical == synchronized && game.postedEMPPlayerElectrical() == nil)
    game.finishEMPPlayerElectricalInterval(publish: publish)
    try game.commander.grantEquipment("Extra Energy Unit", at: .energy, provenance: .grant("current capacity/rate boundary"))
    try empUnitFrame(&game, publish: publish, finish: false)
    #expect(game.postedEMPPlayerElectrical()?.remaining == 1)
    #expect(game.empPlayerElectricalInterval?.generated == 0)
    game.finishEMPPlayerElectricalInterval(publish: publish)
    let synchronizedMain = try #require(game.commander.savedPlayerElectrical)
    try empUnitFrame(&game, publish: publish, finish: false)
    let accepted = try #require(game.postedEMPPlayerElectrical())
    try #require(accepted.remaining > synchronizedMain.remaining)
    try #require((game.empPlayerElectricalInterval?.generated ?? 0) > 0)
    game.postEMPPlayerElectricalInterval()
    #expect(game.commander.savedPlayerElectrical == accepted && game.postedEMPPlayerElectrical() == nil)
    game.finishEMPPlayerElectricalInterval(publish: publish)
  }

  @Test func originalDeadlineEqualityAndPartialOverlap() async throws {
    for crossing in [false, true] {
      let (fixture, initial) = try await freshEMPPostingUnit()
      defer { fixture.clean() }
      var game = initial
      let start = game.commander.flightSimulation.physicalTime
      try #require(start == 0)
      var reserve = try #require(ElectricalReserve(capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier, at: start))
      let drained = reserve.drain(reserve.capacity, at: start)
      try #require(drained)
      game.commander.savedPlayerElectrical = reserve // Explicit pre-existing UNIT disabled episode.
      let publish = fixturePublisher(fixture.file)
      for _ in 0..<479 { try empUnitFrame(&game, delta: 0.0625, publish: publish) }
      if crossing {
        try empUnitFrame(&game, delta: 0.03125, publish: publish)
        try empUnitFrame(&game, delta: 0.0625, publish: publish, finish: false)
        let actual = try #require(game.postedEMPPlayerElectrical())
        #expect(actual.disabledAt == nil && actual.remaining == 0.03125 * reserve.recharge)
        #expect(game.empPlayerElectricalInterval?.generated == 0.03125 * reserve.recharge)
      } else {
        try empUnitFrame(&game, delta: 0.0625, publish: publish, finish: false)
        #expect(game.commander.flightSimulation.physicalTime == 30)
        #expect(game.postedEMPPlayerElectrical()?.remaining == 0)
        #expect(game.postedEMPPlayerElectrical()?.disabledAt == start)
        #expect(game.postedEMPPlayerElectrical()?.recoveryAt == 30)
      }
      game.finishEMPPlayerElectricalInterval(publish: publish)
    }
  }

  @Test func ordinaryDockPreservesEscapeReplaces() async throws {
    let (fixture, initial) = try await freshEMPPostingUnit()
    defer { fixture.clean() }
    var game = initial
    let publish = fixturePublisher(fixture.file)
    try empUnitFrame(&game, publish: publish)
    let main = game.commander.savedPlayerElectrical
    game.dock() // Existing controlled UNIT docking boundary; no journey acceptance claim.
    try #require(game.docked)
    #expect(game.commander.savedPlayerElectrical == main)
    game.launch()
    try #require(!game.docked)
    #expect(game.commander.savedPlayerElectrical == main)
    try game.commander.grantEquipment("Escape Pod", at: .utility(.escapePod), provenance: .grant("current escape owner"))
    let owner = game.commander.equipmentOwnerID
    game.escapePod()
    try #require(game.docked && game.commander.valid)
    #expect(game.commander.equipmentOwnerID == owner)
    #expect(game.commander.savedEMPCharge == nil && game.commander.savedPlayerElectrical == nil)
    #expect(game.empPlayerElectricalInterval == nil)
    #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) == nil)
  }

  @Test func lateMandatoryDebitBeforeOptional() async throws {
    let ready = try await preparedEMPBankOwner(power: 2, close: true)
    defer { ready.purchase.clean() }
    try await ready.purchase.runtime.scriptCommand { game in
      let main = game.commander.savedPlayerElectrical
      let hull = game.energy
      game.applyDamage(game.frontShield, front: true)
      #expect(game.commander.savedPlayerElectrical == main && game.energy == hull)
    }
    var game = await ready.purchase.runtime.snapshot()
    let publish = fixturePublisher(ready.purchase.file)
    try empUnitFrame(&game, controls: empUnitAim(game, actor: ready.actor, fire: true), publish: publish, finish: false)
    let result = try #require(game.currentEMPPulseBeforeResult())
    try expectEMPSelfLaw(result, game: game)
    let before = try #require(result.player)
    let interval = try #require(game.empPlayerElectricalInterval)
    try #require(game.playerEMPDisabled && game.postedEMPPlayerElectrical()?.remaining == 0)
    #expect(interval.mandatoryDebited == before.electrical.remaining)
    let attained = game.commander.savedPlayerElectrical
    game.finishEMPPlayerElectricalInterval(publish: publish)
    #expect(game.commander.savedPlayerElectrical == attained && game.empPlayerElectricalInterval == nil)
    #expect(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
    let once = game.commander
    game.finishEMPPlayerElectricalInterval(publish: publish)
    #expect(game.commander == once)
    let disk = try NativeSaveTestFixture.readVersionedCommander(from: ready.purchase.file)
    #expect(disk.savedPlayerElectrical == attained)
  }
}
