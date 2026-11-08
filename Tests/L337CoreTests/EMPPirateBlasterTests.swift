import Foundation
import Testing

@testable import L337Core

/// Default ordinary target for controlled EMP unit scenes. Explicit two-person,
/// alien and police cases retain their own original source requirements.
enum EMPUnitTargetCatalogue {
  static let ordinary = "SH029"
  /// Current declared two-person source for controlled custody and capacity unit scenes.
  static let twoPerson = "SH004"
}

/// Real owned equipment and an ordinary catalogue-backed actor, not a pre-disabled or synthetic wreck.
func empFixture(catalogue: String = EMPUnitTargetCatalogue.ordinary, hostile: Bool = false, police: Bool = false) throws
  -> Game
{
  var game = Game(executive: false)
  // Keep the initial starter, whose current fit supports the three required utility devices.
  try #require(game.commander.shipID == "SH025")
  let fitting = try #require(OriginalFleetR3Fitting.contract(for: game.commander.ship)?.fitting)
  try #require(fitting.utilityMounts == 3)
  try #require(game.commander.nativePerformance.workTools?.contains(.salvageCutter) == true)
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.commander.fuel = game.commander.fuelCapacity
  try game.commander.prepareEquipment(legacy: false)
  for (name, slot) in [
    (Equipment.empPirateBlaster, ComponentFittingSlot.utility(.empPirateBlaster)),
    ("Salvage Cutter", .utility(.salvageCutter)), ("Fuel Scoops", .utility(.fuelScoops)),
    ("Targeting: Salvage Module", .targetingSalvage),
    (TargetingTier.military.equipmentName, .targetingCore),
  ] {
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("EMP regression"))
  }
  game.launch()
  try prepareEMPUnitScene(&game)
  try withEMPUnitWriter(&game) { scene, publish, file in
    try earnEMPUnitBank(&scene, publish: publish, file: file)
  }
  try insertEMPUnitTarget(&game, catalogue: catalogue, hostile: hostile, police: police)
  game.selectFlightTool(.empPirateBlaster)
  try #require(game.commander.valid)
  return game
}

struct EMPPirateBlasterTests {
  @Test func realMeshHitDisablesWithoutDamageOrRewardAndRepeatedHitsAreIdempotent() throws {
    var game = try empFixture()
    let before = game.commander
    let original = game.bodies[0]
    try #require(try releaseDamagedEMPBoundary(&game))
    let result = try #require(game.currentEMPPulseBeforeResult())
    let disabled = try #require(game.bodies.first { $0.id == original.id })
    try expectEMPPrimaryLaw(result, body: disabled)
    let source = try #require(disabled.physical?.empSource)
    let record = try #require(game.commander.savedEMPState?.records[source])
    let boundary = record.custody.original.body
    #expect(record.valid && game.commander.valid)
    #expect(disabled.physical?.identity == original.physical?.identity)
    #expect(disabled.position == boundary.position && disabled.orientation == boundary.orientation)
    #expect(disabled.physical?.velocity == boundary.physical?.velocity)
    #expect(disabled.physical?.angularVelocity == boundary.physical?.angularVelocity)
    #expect(disabled.physical?.npc?.resources?.fuel == boundary.physical?.npc?.resources?.fuel)
    #expect(disabled.physical?.npc?.resources?.electrical?.remaining == 0)
    #expect(game.commander.credits == before.credits && game.commander.kills == before.kills)
    #expect(game.commander.cargo == before.cargo && disabled.destroyedByPlayer == nil)
    #expect(game.laserHeat == Game.empHeatCost && game.fireCooldown == Game.empCooldown)
    #expect(record.disableIncident.kind == .emp && record.disableIncident.outcome == .hit)
    #expect(record.disableIncident.victim == original.physical?.identity)
    #expect(game.commander.legal > before.legal)
    #expect(record.crewAboard == record.crewTotal && record.pods.isEmpty)
    let cutterFired = game.fireSalvageCutter(delta: 0.1)
    #expect(!cutterFired)
    game.fireCooldown = 0
    game.advanceEMPCharge(triggerHeld: false)
    try withEMPUnitWriter(&game) { scene, publish, file in
      try earnEMPUnitBank(&scene, publish: publish, file: file)
    }
    let stillDisabled = try #require(game.bodies.first { $0.id == original.id })
    try #require(game.isEMPDisabled(stillDisabled) && game.currentEMPPlayerModule()?.empBank?.remaining == 8)
    try #require(game.postedEMPPlayerElectrical() != nil)
    let once = game.commander
    let remaining = game.energy
    let empFired = game.fireEMPPirateBlaster()
    #expect(!empFired)
    #expect(game.commander == once && game.energy == remaining)
    #expect(!game.message.contains("DESTROYED") && game.dischargeAudio.events.last?.tool == .empPirateBlaster)
  }

  @Test(arguments: [false, true])
  func missAndActualOccludingMeshCannotDisableTheShip(occluded: Bool) throws {
    var game = try empFixture()
    if occluded {
      game.bodies.append(.init(id: 99, hull: .asteroid, position: .init(0, 0, 350)))
      game.nextBodyID = 100
      game.ensurePhysicalActors()
    } else {
      game.bodies[0].position.x = 1500
    }
    try #require(game.currentEMPPlayerModule()?.empBank?.remaining == 8 && game.postedEMPPlayerElectrical() != nil)
    let before = game.commander
    let bodies = game.bodies
    let energy = game.energy
    let empResult = game.fireEMPPirateBlaster()
    #expect(!empResult)
    #expect(game.commander == before && game.bodies == bodies && game.energy == energy)
    #expect(game.commander.savedEMPState == nil)
  }

  @Test func disabledPropulsionCoastsAndActualFuelledJumpRefusesWithoutSpendingFuel() throws {
    var game = try empFixture()
    let target = game.bodies[0]
    let destination = try #require(target.physical?.npc?.destination)
    let fuel = try #require(target.physical?.npc?.resources?.fuel)
    var available = game
    let jumpResult = available.initiateNPCJump(bodyID: target.id, destination: destination)
    #expect(jumpResult)
    let actor = try #require(target.physical?.identity)
    let spent = try #require(
      available.commander.npcPersistence.snapshot(for: actor)?.npc.resources?.fuel)
    #expect(spent < fuel && !available.bodies.contains { $0.id == target.id })
    #expect(available.commander.npcPersistence.terminalReason(for: actor) == .jumped)
    let empResult = try releaseDamagedEMPBoundary(&game)
    #expect(empResult)
    let before = game.commander
    let jumpResult2 = game.initiateNPCJump(bodyID: target.id, destination: destination)
    #expect(!jumpResult2)
    #expect(game.commander == before)
    let position = game.commander.flightSimulation.pose.systemPoint(game.bodies[0].position)
    let velocity = try #require(game.bodies[0].physical?.velocity)
    let angular = try #require(game.bodies[0].physical?.angularVelocity)
    game.tick(delta: 0.1)
    let coast = try #require(game.bodies.first { $0.id == target.id })
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(coast.position) - position - velocity * 0.1)
        .length < 1e-7)
    #expect(coast.physical?.velocity == velocity && coast.physical?.angularVelocity == angular)
    #expect(coast.physical?.npc?.resources?.fuel == fuel)
  }

  @Test func ordinaryPoliceAreNotImmuneAndTheirRealSourceAndAssaultAreRetained() throws {
    var game = try empFixture(police: true)
    try #require(game.bodies[0].physical?.blocksNavalEncounter == true)
    let before = game.commander.legal
    let empResult = try releaseDamagedEMPBoundary(&game)
    #expect(empResult)
    let record = try #require(game.commander.savedEMPState?.records.values.first)
    #expect(record.custody.kind == .police && record.custody.valid && record.valid)
    #expect(record.custody.original.body.physical?.npc?.role == .police)
    #expect(record.disableIncident.victimRole == .police && game.commander.legal > before)
    let logical = record.custody.logical
    #expect(logical == record.disableIncident.victim)
    #expect(logical == record.custody.original.body.physical?.identity)
    #expect(game.commander.npcPersistence.snapshot(for: logical) == nil)
    #expect(game.commander.npcPersistence.binding(for: logical) == nil)
    #expect(game.commander.npcPersistence.logicalIdentity(for: logical) == nil)
  }

  @Test func missionProtectedAndAlienModelsCannotBecomeHumanDerelicts() throws {
    for alien in [false, true] {
      var game = try empFixture(catalogue: alien ? "SH123" : EMPUnitTargetCatalogue.ordinary)
      if !alien { game.bodies[0].physical?.npc?.role = .mission }
      try #require(game.currentEMPPlayerModule()?.empBank?.remaining == 8 && game.postedEMPPlayerElectrical() != nil)
      let before = game.commander
      let bodies = game.bodies
      let empResult = game.fireEMPPirateBlaster()
      #expect(!empResult)
      #expect(game.commander == before && game.bodies == bodies)
      #expect(game.commander.savedEMPState == nil)
    }
  }

  @Test func fullActorCapacityKeepsEveryActualCrewMemberAboardUntilPodsAreAdmitted() throws {
    var game = try empFixture(catalogue: EMPUnitTargetCatalogue.twoPerson)
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let empResult = try releaseDamagedEMPBoundary(&game)
    #expect(empResult)
    let source = try #require(game.bodies[0].physical?.empSource)
    let crew = try #require(game.commander.savedEMPState?.records[source]?.crewTotal)
    try #require(crew == 2)
    for i in 0..<128 {
      game.bodies.append(
        .init(id: 100 + i, hull: .cargo, position: .init(10_000 + Double(i) * 100, 0, 0)))
    }
    game.nextBodyID = 228
    game.ensurePhysicalActors()
    let record = try #require(game.commander.savedEMPState?.records[source])
    let episode = try #require(record.disableEpisodes.last)
    let lastDelay = try #require(episode.ejections.map(\.delay).max())
    try #require(lastDelay < 30)
    game.commander.flightSimulation.advancePhysicalTime(lastDelay + 0.001)
    game.advanceEMPActors()
    let blocked = try #require(game.commander.savedEMPState?.records[source])
    #expect(blocked.crewAboard == crew && blocked.pods.isEmpty)
    #expect(game.bodies.first { $0.physical?.empSource == source }?.physical?.npc != nil)
    game.bodies.removeAll { $0.id >= 100 }
    for _ in 0..<40 { game.tick(delta: 0.1) }
    let abandoned = try #require(game.commander.savedEMPState?.records[source])
    #expect(abandoned.crewAboard == 0 && abandoned.pods.count == crew)
    #expect(Set(abandoned.pods.compactMap { $0.body.physical?.empCrewPod }).count == crew)
    let hull = try #require(game.bodies.first { $0.physical?.empSource == source })
    #expect(hull.physical?.npc == nil && hull.physical?.salvage?.ownership == .abandoned)
    let pods = game.bodies.filter { $0.physical?.empCrewPod?.source == source }
    #expect(
      pods.count == crew && pods.allSatisfy { $0.physical?.salvage?.category == .occupiedPod })
    let people = abandoned.pods
    for _ in 0..<20 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == people.count)
    #expect(game.commander.valid)
  }
}
