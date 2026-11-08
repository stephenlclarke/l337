import Foundation
import Testing

@testable import L337Core

// Controlled ordinary combat with a qualified current player source.
// No helper constructs a C01 root, Birth, Entry, permit or accepted-destruction transport.
private func combatRequire<T>(_ value: T?) throws -> T {
  try #require(value)
}
private func combatGame(position: Vector3 = .init(0, 0, -3000)) throws -> Game {
  // Qualify the actual initial source before any physical performance getter.
  let shipID = "SH025"
  try OriginalDetailedHullStage.requireRuntime(shipID)
  let ship = try combatRequire(ShipCatalogue.ship(shipID))
  let source = try combatRequire(OriginalFleetR3Fitting.contract(for: ship))
  let performance = try combatRequire(source.performance)
  try #require(ship.id == shipID && shipID == NewCommanderDefaults.shipID)
  try #require(ship.name == "Peregrine Mk V" && ship.catalogue.playerFlyable)
  try #require(ship.game == performance && performance.valid)
  var game = Game(executive: false)
  // This is controlled initial ownership, not a hull transfer or earned acquisition.
  try #require(game.commander.shipID == shipID)
  try #require(
    game.commander.equipmentInventory == nil && game.commander.equipmentPurchaseHistory == nil)
  try game.commander.prepareEquipment(legacy: false)
  game.commander.fuel = game.commander.fuelCapacity
  game.commander.credits = 1000
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = position
  try #require(game.commander.shipID == shipID && game.commander.nativePerformance == performance)
  try #require(game.commander.equipmentOwnerID != nil && game.commander.hullInstanceID != nil)
  try #require(game.commander.valid && game.commander.flightSimulation.valid)
  return game
}
@discardableResult
private func combatBody(
  _ game: inout Game, id: Int = 10, hull: Hull = .cobra, role: NPCRole? = .trader,
  legal: LegalRecord = .init(), position: Vector3 = .init(0, 0, 1000), energy: Double = 40
) throws -> ActorIdentity {
  let identity = try combatRequire(game.commander.flightSimulation.allocateActor())
  var body = SpaceBody(id: id, hull: hull, position: position)
  body.energy = energy
  body.physical = .init(
    identity: identity, population: role == .police ? .police : .civilian,
    npc: role.map {
      .init(role: $0, legal: legal, origin: game.systemIdentity, destination: game.systemIdentity)
    })
  game.bodies.append(body)
  return identity
}
private func combatPlayerOrigin(_ game: inout Game) throws -> AttackOrigin {
  let player = try combatRequire(game.commander.flightSimulation.player)
  return try combatRequire(game.makeAttackOrigin(owner: player))
}
private func combatBodyHit(_ game: Game, id: Int = 10) throws -> GameplayHit {
  let body = try combatRequire(game.bodies.first { $0.id == id })
  return .init(target: .body(id), distance: body.position.length, point: body.position)
}

struct NativeC01InquiryRejectedCombatConservationTests {
  // Negative C01-authority coverage only. A missing root cannot exercise the
  // private accepted C01 transport or genuine nonempty-root retirement path.
  @Test(arguments: ["prior-visit", "missing-victim", "invalid-damage"])
  func rejectedNativeHitConservesFullRetainedAndPhysicalState(form: String) throws {
    var game = try combatGame()
    try combatBody(&game)
    let origin = try combatPlayerOrigin(&game)
    if form == "prior-visit" {
      // Real visit transition makes the real previously emitted origin stale.
      game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    }
    // Finish ordinary actor/station adoption before the conservation snapshot.
    game.ensurePhysicalActors()
    game.gameplayCombatTrace = .init()
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    let hit = form == "missing-victim"
      ? GameplayHit(target: .body(999), distance: 1, point: .init(0, 0, 1))
      : try combatBodyHit(game)
    let commander = game.commander
    let bodies = game.bodies
    let celestials = game.celestials
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    let traceEpoch = game.gameplayCombatTrace?.epoch
    let incidents = game.gameplayCombatTrace?.incidents
    let dropped = game.gameplayCombatTrace?.dropped
    #expect(game.applyCombatHit(hit, origin: origin, kind: .laser,
      damage: form == "invalid-damage" ? Double.nan : 10000) == nil)
    #expect(game.commander == commander)
    #expect(game.bodies == bodies && game.celestials == celestials)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.gameplayCombatTrace?.epoch == traceEpoch)
    #expect(game.gameplayCombatTrace?.incidents == incidents)
    #expect(game.gameplayCombatTrace?.dropped == dropped)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    // These are actual reviewed C01 hooks, not a simulated accepted callback.
    #expect(game.prepareC01InquiryDestroyedRemoval().isEmpty)
    try game.captureC01InquiryCurrentLife()
    let currentBody = try #require(game.bodies.first { $0.id == 10 })
    #expect(!game.c01InquiryRequiresNativeParking(beforeRemoving: currentBody))
    #expect(game.commander == commander)
    #expect(game.bodies == bodies && game.celestials == celestials)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.gameplayCombatTrace?.epoch == traceEpoch)
    #expect(game.gameplayCombatTrace?.incidents == incidents)
    #expect(game.gameplayCombatTrace?.dropped == dropped)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }

  @Test func ordinaryAcceptedDeathRemainsAttainedThroughAbsentRootLifecyclePreflight() throws {
    var game = try combatGame()
    let victim = try combatBody(&game, energy: 40)
    let origin = try combatPlayerOrigin(&game)
    game.gameplayCombatTrace = .init()
    let hit = try combatBodyHit(game)
    let firstHit = game.applyCombatHit(
      hit, origin: origin, kind: .laser, damage: 10000, laser: .pulse)
    let first = try #require(firstHit)
    #expect(first.outcome == .hit && first.victim == victim)
    let dead = try #require(game.bodies.first { $0.id == 10 })
    let deaths = try #require(game.gameplayCombatTrace).incidents.filter {
      $0.outcome == .destruction && $0.victim == victim
    }
    #expect(deaths.count == 1)
    let destruction = try #require(deaths.first)
    #expect(dead.energy == 0 && dead.physical?.deathOrigin == origin)
    #expect(dead.physical?.deathIncidentID == destruction.id)
    #expect(destruction.origin == origin && dead.destroyedByPlayer == true)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    // Snapshot the attained real ordinary death, never a hand-authored energy0 body.
    let commander = game.commander
    let bodies = game.bodies
    let celestials = game.celestials
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    let traceEpoch = game.gameplayCombatTrace?.epoch
    let incidents = game.gameplayCombatTrace?.incidents
    let dropped = game.gameplayCombatTrace?.dropped
    #expect(game.prepareC01InquiryDestroyedRemoval().isEmpty)
    try game.captureC01InquiryCurrentLife()
    #expect(!game.c01InquiryRequiresNativeParking(beforeRemoving: dead))
    #expect(game.commander == commander)
    #expect(game.bodies == bodies && game.celestials == celestials)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.gameplayCombatTrace?.epoch == traceEpoch)
    #expect(game.gameplayCombatTrace?.incidents == incidents)
    #expect(game.gameplayCombatTrace?.dropped == dropped)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }
}

extension NativeC01InquiryRejectedCombatConservationTests {
  @Test func ordinaryCleanupRetiresRealDeathWithoutReattributionOrCounterReplay() throws {
    var game = try combatGame()
    let victim = try combatBody(&game, energy: 40)
    let origin = try combatPlayerOrigin(&game)
    game.gameplayCombatTrace = .init()
    let hit = try combatBodyHit(game)
    let firstHit = game.applyCombatHit(
      hit, origin: origin, kind: .laser, damage: 10000, laser: .pulse)
    let first = try #require(firstHit)
    #expect(first.outcome == .hit && first.victim == victim)
    let deceased = try #require(game.bodies.first { $0.id == 10 })
    let trace = try #require(game.gameplayCombatTrace)
    let deaths = trace.incidents.filter { $0.outcome == .destruction && $0.victim == victim }
    #expect(deaths.count == 1)
    let death = try #require(deaths.first)
    #expect(deceased.energy == 0 && deceased.destroyedByPlayer == true)
    #expect(deceased.physical?.deathOrigin == origin && death.origin == origin)
    #expect(deceased.physical?.deathIncidentID == death.id)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
    let incidentCounter = game.commander.flightSimulation.nextIncident
    let emissionCounter = game.commander.flightSimulation.nextEmission
    let physicalTime = game.commander.flightSimulation.physicalTime
    let kills = game.commander.kills
    let credits = game.commander.credits
    let legal = game.commander.legal
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    #expect(kills == 1)

    // Exercise the actual cleanup owner, including its absent-root C01 hook.
    // Legitimate cargo/persistence retirement may change other Commander fields.
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.id == deceased.id || $0.physical?.identity == victim })
    #expect(game.commander.flightSimulation.nextIncident == incidentCounter)
    #expect(game.commander.flightSimulation.nextEmission == emissionCounter)
    #expect(game.commander.flightSimulation.physicalTime == physicalTime)
    #expect(game.commander.kills == kills && game.commander.credits == credits)
    #expect(game.commander.legal == legal)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.gameplayCombatTrace?.epoch == trace.epoch)
    #expect(game.gameplayCombatTrace?.incidents == trace.incidents)
    #expect(game.gameplayCombatTrace?.dropped == trace.dropped)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)

    // A second cleanup cannot replace the accepted cause, charge counters,
    // award credit again, or change the settled world and player state.
    let settledCommander = game.commander
    let settledBodies = game.bodies
    let settledCelestials = game.celestials
    let settledBodyID = game.nextBodyID
    let settledRevision = game.gameplayRevision
    let settledEpoch = game.nativeStationRuntimeEpoch
    game.resolveDestroyed()
    #expect(game.commander == settledCommander)
    #expect(game.bodies == settledBodies && game.celestials == settledCelestials)
    #expect(game.nextBodyID == settledBodyID && game.gameplayRevision == settledRevision)
    #expect(game.nativeStationRuntimeEpoch == settledEpoch)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.gameplayCombatTrace?.epoch == trace.epoch)
    #expect(game.gameplayCombatTrace?.incidents == trace.incidents)
    #expect(game.gameplayCombatTrace?.dropped == trace.dropped)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }
}
