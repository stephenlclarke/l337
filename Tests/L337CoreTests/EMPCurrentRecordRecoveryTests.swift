import Foundation
import Testing

@testable import L337Core

struct EMPCurrentRecordRecoveryTests {
  @Test(arguments: [
    "current", "wrong-profile", "unknown-fuel", "missile-overflow", "missing-source", "unknown-source",
    "pending-capsule", "pending-platform", "pending-station", "pending-probe", "pending-factory",
  ])
  func storedNPCRequiresCurrentSourceWithoutInventingPreHitReserve(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    var body = SpaceBody(id: game.nextBodyID, hull: .cobra, position: .init(0, 0, 1000))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .civilian, npc: npc, catalogueShipID: source.ship.id)
    let original = EMPStoredObject(body: body, pose: ShipPose(), time: 0)
    try #require(original.valid && original.body.physical?.npc?.resources?.electrical == nil)
    switch condition {
    case "wrong-profile":
      body.physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
    case "unknown-fuel": body.physical?.npc?.resources?.fuel = nil
    case "missile-overflow": body.missiles = source.performance.missiles + 1
    case "missing-source": body.physical?.catalogueShipID = nil
    case "unknown-source": body.physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    case "pending-capsule": body.physical?.catalogueShipID = "SH040"
    case "pending-platform": body.physical?.catalogueShipID = "SH156"
    case "pending-station": body.physical?.catalogueShipID = "SH161"
    case "pending-probe": body.physical?.catalogueShipID = "SH162"
    case "pending-factory": body.physical?.catalogueShipID = "SH164"
    case "current": break
    default:
      Issue.record("Unknown controlled stored EMP source condition")
      return
    }
    try #require(body.physical?.npc?.resources?.valid == true)
    let stored = EMPStoredObject(body: body, pose: ShipPose(), time: 0)
    #expect(stored.valid == (condition == "current"))
    #expect(original.valid && original.body.physical?.npc?.resources?.electrical == nil)
    // An NPC-free object has no NPC resource issuer; no reserve is fabricated.
    // An actual pending catalogue claim still cannot become physical source authority.
    body.physical?.npc = nil
    let object = EMPStoredObject(body: body, pose: ShipPose(), time: 0)
    let expected = !condition.hasPrefix("pending-")
    #expect(object.valid == expected)
    let restored = try JSONDecoder().decode(EMPStoredObject.self, from: JSONEncoder().encode(object))
    #expect(restored == object && restored.valid == expected)
  }

  @Test(arguments: ["current", "missing-reserve", "wrong-profile", "missing-source", "unknown-source"])
  func recoveryRequiresActualCurrentDisabledReserve(condition: String) async throws {
    let paid = try await paidEMPNativeFixture()
    defer { paid.clean() }
    var game = await paid.runtime.snapshot()
    let current = try #require(StationPoliceSource.current())
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .police, origin: game.systemIdentity, destination: game.systemIdentity)
    var worn = current.stock
    worn.frontShield = 0
    worn.rearShield = 0
    worn.fuel = 0
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(ElectricalReserve(
      capacity: worn.energyCapacity, recharge: worn.energyRecharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(drained)
    worn.electrical = reserve
    npc.resources = worn
    var body = SpaceBody(id: id, hull: .viper, position: .init(0, 0, 1000))
    body.energy = current.source.performance.energy - 3
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .police, npc: npc, blocksNavalEncounter: true,
      catalogueShipID: current.source.ship.id)
    game.bodies.append(body)
    _ = try await disableNativeEMPActor(actor, game: &game)
    let key = try #require(game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let disabled = try #require(game.commander.nativeEMPCustodyRecord(for: key))
    try #require(disabled.valid && !disabled.isRecovered && disabled.crewAboard > 0)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    switch condition {
    case "missing-reserve": game.bodies[index].physical?.npc?.resources?.electrical = nil
    case "wrong-profile":
      game.bodies[index].physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: worn.energyCapacity))
    case "missing-source": game.bodies[index].physical?.catalogueShipID = nil
    case "unknown-source": game.bodies[index].physical?.catalogueShipID = "UNKNOWN-CURRENT-SOURCE"
    case "current": break
    default:
      Issue.record("Unknown controlled EMP recovery condition")
      return
    }
    var malformed = disabled
    malformed.hull.body = game.bodies[index]
    #expect(malformed.valid == (condition == "current"))
    let deadline = try #require(disabled.crewDeadline)
    let delta = deadline + 1 - game.commander.flightSimulation.physicalTime
    try #require(delta > 0)
    game.commander.flightSimulation.advancePhysicalTime(delta)
    let before = game
    game.recoverEMPHulls()
    if condition == "current" {
      let recovered = try #require(game.commander.nativeEMPCustodyRecord(for: key))
      try #require(recovered.isRecovered && recovered.valid)
      let actual = try #require(recovered.hull.body.physical?.npc?.resources)
      let electrical = try #require(actual.electrical)
      #expect(electrical.disabledAt == nil && electrical.remaining > 0)
      #expect(actual.fuel == 0 && actual.frontShield == 0 && actual.rearShield == 0)
      #expect(recovered.hull.body.energy == disabled.hull.body.energy)
      #expect(recovered.crewAboard == disabled.crewAboard && recovered.crewTotal == disabled.crewTotal)
      var missing = recovered
      missing.hull.body.physical?.npc?.resources?.electrical = nil
      #expect(!missing.valid)
    } else {
      #expect(game.commander == before.commander && game.bodies == before.bodies)
      #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
      #expect(game.commander.savedEMPState?.records[key] == disabled)
    }
  }
}
