import Foundation
import Testing

@testable import L337Core

struct NativeFleetObserverSourceTests {
  @Test(arguments: [
    "current-full", "current-spent", "wrong-profile", "unknown-fuel", "missile-overflow", "negative-missiles",
    "invalid-pool",
  ], [TargetingTier.identification, .military])
  func selectedObservationRequiresTheCurrentNPCResourceSource(condition: String, tier: TargetingTier) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let stock = try #require(NPCResources.stock(source.performance))
    try #require(source.ship.catalogue.discoveryEligible && source.ship.nativeHull == .viper)
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    try game.commander.grantEquipment(
      tier.equipmentName, at: .targetingCore,
      provenance: .grant("fleet observer unit boundary"))
    game.launch()
    game.viewportWidth = 512
    game.viewportHeight = 518
    try #require(!game.docked && game.screen == .front)
    try #require(game.commander.targetingTier == tier)
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .police, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = stock
    var body = SpaceBody(id: id, hull: .viper, position: .init(0, 0, 1000))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .police, npc: npc, catalogueShipID: source.ship.id)
    // A controlled unit scene selects one real current hull; it issues no ordinary spawn receipt.
    game.bodies = [body]
    game.autoPilot.cycle(
      [body], frontIDs: [id], signature: "fleet-observer-current-source",
      origin: game.commander.flightSimulation.player)
    try #require(game.autoTargetBody?.physical?.identity == actor)
    let context = try #require(game.gameplayContext())
    try #require(context.actors.contains { $0.identity == actor })
    let collision = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 2000,
      radius: 0, includePlayer: false)
    let contact = try #require(collision)
    try #require(contact.hit.target == .body(id))
    try #require(game.commander.scriptState.savedFleetDiscovery == nil)
    var control = game
    control.observeSelectedFleetDiscovery()
    let observed = try #require(control.commander.scriptState.savedFleetDiscovery)
    try #require(observed.valid && observed.entries[source.ship.id]?.identification?.actor == actor)
    let progress = NativeFleetDiscoveryProgress(commander: control.commander)
    #expect(progress.encountered == 1 && progress.total == 167 && progress.label == "Seen 1/167")
    var cold = control.commander
    cold.scriptState.savedFleetDiscovery = try JSONDecoder().decode(
      NativeFleetDiscovery.self, from: JSONEncoder().encode(observed))
    #expect(NativeFleetDiscoveryProgress(commander: cold) == progress)
    var foreign = Game(executive: false)
    try foreign.commander.prepareEquipment(legacy: false)
    try #require(foreign.commander.equipmentOwnerID != control.commander.equipmentOwnerID)
    foreign.commander.scriptState.savedFleetDiscovery = observed
    #expect(NativeFleetDiscoveryProgress(commander: foreign.commander).encountered == 0)
    var future = control.commander
    future.flightSimulation.physicalTime = -1
    #expect(NativeFleetDiscoveryProgress(commander: future).encountered == 0)
    switch condition {
    case "current-spent":
      game.bodies[0].physical?.npc?.resources?.frontShield *= 0.5
      game.bodies[0].physical?.npc?.resources?.rearShield *= 0.75
    case "wrong-profile":
      game.bodies[0].physical?.npc?.resources = try #require(
        NPCResources.legacyEnergyOnly(maximumEnergy: stock.energyCapacity))
    case "unknown-fuel": game.bodies[0].physical?.npc?.resources?.fuel = nil
    case "missile-overflow": game.bodies[0].missiles = source.performance.missiles + 1
    case "negative-missiles": game.bodies[0].missiles = -1
    case "invalid-pool": game.bodies[0].physical?.npc?.resources?.frontShield = -1
    case "current-full": break
    default:
      Issue.record("Unknown controlled fleet observer source condition")
      return
    }
    let before = game
    let accepted = condition == "current-full" || condition == "current-spent"
    let currentNPC = try #require(game.bodies[0].physical?.npc)
    #expect(NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
      catalogueShipID: source.ship.id, hull: game.bodies[0].hull, npc: currentNPC,
      missiles: game.bodies[0].missiles) == accepted)
    if condition == "negative-missiles" {
      try #require(currentNPC.resources?.valid == true)
      #expect(game.telemetryFacts(for: game.bodies[0]).resources == nil)
    }
    let information = try #require(game.information(for: game.bodies[0]))
    let hardwareLabels = ["Missiles", "ECM equipped", "ECM active"]
    if tier == .military {
      let expected = accepted
        ? [String(before.bodies[0].missiles), before.bodies[0].ecmEnabled ? "Yes" : "No",
          before.ecmFrames > 0 && before.enemyECMSource == before.bodies[0].id ? "Yes" : "No"]
        : ["Unknown", "Unknown", "Unknown"]
      for (label, value) in zip(hardwareLabels, expected) {
        #expect(information.fields.first { $0.label == label }?.value == value)
      }
      if condition == "current-full" {
        // Direct projection of one malformed copy of this existing real source control.
        // This grants no actor/history and checks projection before discovery runs.
        var negative = game
        negative.bodies[0].missiles = -1
        let negativeBefore = negative
        let hidden = try #require(negative.information(for: negative.bodies[0]))
        for label in hardwareLabels {
          #expect(hidden.fields.first { $0.label == label }?.value == "Unknown")
        }
        #expect(negative.commander == negativeBefore.commander && negative.bodies == negativeBefore.bodies)
        #expect(negative.time == negativeBefore.time && negative.gameplayRevision == negativeBefore.gameplayRevision)
      }
    } else {
      #expect(!information.fields.contains { hardwareLabels.contains($0.label) })
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
    #expect(game.ecmFrames == before.ecmFrames && game.enemyECMSource == before.enemyECMSource)
    game.observeSelectedFleetDiscovery()
    if accepted {
      #expect(game.commander.scriptState.savedFleetDiscovery == observed)
      #expect(NativeFleetDiscoveryProgress(commander: game.commander) == progress)
      game.observeSelectedFleetDiscovery()
      #expect(NativeFleetDiscoveryProgress(commander: game.commander) == progress)
      var expected = before.commander
      expected.scriptState.savedFleetDiscovery = observed
      #expect(game.commander == expected)
    } else {
      #expect(game.commander == before.commander)
      #expect(game.commander.scriptState.savedFleetDiscovery == nil)
      #expect(NativeFleetDiscoveryProgress(commander: game.commander).encountered == 0)
    }
    #expect(game.bodies == before.bodies)
    #expect(game.time == before.time && game.gameplayRevision == before.gameplayRevision)
    #expect(game.autoPilot.targetID == before.autoPilot.targetID)
    #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
    #expect(game.autoPilot.status == before.autoPilot.status)
  }
}
