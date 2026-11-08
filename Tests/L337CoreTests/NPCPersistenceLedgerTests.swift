import Foundation
import Testing

@testable import L337Core

private func persistenceExpect(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation)
{
  #expect(condition, sourceLocation: sourceLocation)
}

private func persistenceRequire<T>(_ value: T?) throws -> T { try #require(value) }

private func persistenceBody(_ entity: UInt64 = 2, visit: UInt64 = 1) throws -> SpaceBody {
  var body = SpaceBody(id: Int(entity), hull: .cobra, position: .init(10, 20, 30), hostile: true)
  body.orientation.rotate(pitch: 0.1, roll: 0.2, yaw: 0.3)
  body.rotation = 0.7
  body.rotationRate = 0.2
  body.energy = 34
  body.missiles = 1
  body.ecmEnabled = true
  var npc = NPCState(
    role: .pirate, legal: .init(value: 20, bountyTenths: 130),
    firstAggressor: crimeTestID(50), intention: .engage(crimeTestID(60)),
    origin: crimeTestSystem, destination: .init(galaxy: 0, system: 9),
    ordinaryCargo: [
      .init(commodity: .gold, quantity: 17), .init(commodity: .narcotics, quantity: 2),
    ],
    legalProvenance: .recorded, cargoProvenance: .generated, routeProvenance: .inferredLocal)
  // Controlled damaged pools on the current source, never fabricated hull capacities.
  let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH025"))
  var resources = try persistenceRequire(NPCResources.stock(source.performance))
  resources.frontShield = 17
  resources.rearShield = 23
  resources.laserHeat = 51
  resources.fuel = 13
  resources.scoopRemainder = 0.3
  npc.resources = resources
  npc.hasFuelScoops = true
  body.physical = .init(
    identity: crimeTestID(entity, visit: visit), population: .pirate, npc: npc,
    velocity: .init(4, 5, 6), laserCooldown: 0.45,
    catalogueShipID: "SH025", angularVelocity: .init(0.01, 0.02, 0.03))
  return body
}

private func persistenceSnapshot(_ entity: UInt64 = 2, time: Double = 10) throws
  -> NPCPersistenceSnapshot
{
  try persistenceRequire(
    NPCPersistenceSnapshot.capture(
      body: try persistenceBody(entity), pose: ShipPose(), physicalTime: time, protection: .init()))
}

private func persistenceRoundtrip(_ ledger: NPCPersistenceLedger) throws -> NPCPersistenceLedger {
  try JSONDecoder().decode(NPCPersistenceLedger.self, from: JSONEncoder().encode(ledger))
}

private func persistenceContext(_ time: Double, radius: Double) -> EncounterContext {
  let context = crimeTestContext(time)
  return .init(
    system: context.system, seed: context.seed, government: context.government,
    visit: context.visit, revision: context.revision, physicalTime: time,
    anchors: context.anchors, player: context.player, actors: context.actors,
    protection: context.protection, budget: context.budget, perceptionRadius: radius)
}

struct NPCPersistenceLedgerTests {
  @Test func outOfRangeRetentionAndWorldUpdatesReenterWithoutAllocatingRepeatedOffers() throws {
    var ledger = NPCPersistenceLedger()
    var snapshot = try persistenceSnapshot()
    snapshot.position = .init(0, 0, 20000)
    _ = ledger.capture(snapshot, protection: .init())
    ledger.cull(actor: snapshot.actor)
    let far = ledger
    for time in [10.0, 11, 12] {
      persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(time)).isEmpty)
    }
    #expect(ledger == far && ledger.unboundSnapshots == [snapshot.actor: snapshot])
    snapshot.position = .init(0, 0, 10000)
    snapshot.physicalTime = 13
    snapshot.energy = 36
    snapshot.rotation = 0.9
    snapshot.npc.resources?.frontShield = 19
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    let edge = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(13)).first)
    #expect(edge.position == snapshot.position && edge.energy == 36 && edge.npc == snapshot.npc)
    snapshot.position.z = 10001
    snapshot.physicalTime = 14
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(14)).isEmpty)
    ledger = try persistenceRoundtrip(ledger)
    snapshot.position = .init(0, 0, 2000)
    snapshot.physicalTime = 15
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    let near = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(15)).first)
    #expect(near.identity == edge.identity && near.position == snapshot.position)
    #expect(ledger.unboundSnapshots[snapshot.actor]?.rotation == 0.9)
    for radius in [0, -1, Double.nan, .infinity] {
      let before = ledger
      persistenceExpect(
        ledger.pendingSpawnRequests(context: persistenceContext(15, radius: radius)).isEmpty)
      #expect(ledger == before)
    }
  }

  @Test func unboundUpdatesRejectBoundTerminalStaleOrChangedActorWithoutMutation() throws {
    var ledger = NPCPersistenceLedger()
    let original = try persistenceSnapshot()
    _ = ledger.capture(original, protection: .init())
    #expect(ledger.unboundSnapshots.isEmpty)
    let bound = ledger
    persistenceExpect(!ledger.updateUnbound(logicalIdentity: original.actor, snapshot: original))
    #expect(ledger == bound)
    ledger.cull(actor: original.actor)
    let unbound = ledger
    var invalids = [original, original, original, original]
    invalids[0].actor = crimeTestID(99)
    invalids[1].actor = .init(system: .init(galaxy: 0, system: 9), visit: 1, entity: 2)
    invalids[2].physicalTime = 9
    invalids[3].energy = .nan
    for invalid in invalids {
      persistenceExpect(!ledger.updateUnbound(logicalIdentity: original.actor, snapshot: invalid))
      #expect(ledger == unbound)
    }
    persistenceExpect(!ledger.updateUnbound(logicalIdentity: crimeTestID(99), snapshot: original))
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    let rebound = try persistenceRequire(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(100), refusal: nil)
      ]).first)
    persistenceExpect(ledger.terminal(actor: rebound.actor, reason: .destroyed))
    let terminal = ledger
    #expect(ledger.unboundSnapshots.isEmpty)
    persistenceExpect(
      !ledger.updateUnbound(logicalIdentity: original.actor, snapshot: rebound.snapshot))
    #expect(ledger == terminal && ledger.valid)
  }

  @Test func actualBodyCaptureRetainsWorldPoseResourcesAndCatalogueAcrossCodableRoundtrip() throws {
    let body = try persistenceBody()
    var pose = ShipPose(position: .init(1000, 2000, 3000))
    pose.orientation.rotate(pitch: 0.4, roll: -0.3, yaw: 0.6)
    let snapshot = try persistenceRequire(
      NPCPersistenceSnapshot.capture(
        body: body, pose: pose, physicalTime: 12.5, protection: .init()))
    #expect(snapshot.position == pose.systemPoint(body.position))
    #expect(snapshot.orientation == body.orientation.transformed(by: pose.orientation))
    #expect(snapshot.npc == body.physical?.npc && snapshot.energy == 34)
    #expect(snapshot.missiles == 1 && snapshot.ecmEnabled && snapshot.hostile)
    #expect(snapshot.laserCooldown == 0.45 && snapshot.catalogueShipID == "SH025")
    #expect(snapshot.rotation == 0.7 && snapshot.rotationRate == 0.2)
    #expect(
      snapshot.velocity == .init(4, 5, 6) && snapshot.angularVelocity == .init(0.01, 0.02, 0.03))
    var ledger = NPCPersistenceLedger()
    persistenceExpect(ledger.capture(snapshot, protection: .init()) == .registered(snapshot.actor))
    let decoded = try persistenceRoundtrip(ledger)
    #expect(decoded == ledger && decoded.snapshot(for: snapshot.actor) == snapshot && decoded.valid)
  }

  @Test func cullRebindNewActorRestoresExactDamageConsumablesAndRenderedPoseOnce() throws {
    var ledger = NPCPersistenceLedger()
    let original = try persistenceSnapshot()
    _ = ledger.capture(original, protection: .init())
    ledger.cull(actor: original.actor)
    ledger = try persistenceRoundtrip(ledger)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(100)).first)
    #expect(
      request.energy == 34 && request.npc == original.npc && request.position == original.position)
    #expect(
      request.identity.producer == .persistence && request.payload == nil && request.rock == nil)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(100), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    #expect(rebind.logicalIdentity == original.actor && rebind.actor == crimeTestID(100))
    var pose = ShipPose(position: .init(-900, 300, 400))
    pose.orientation.rotate(pitch: -0.2, roll: 0.5, yaw: 0.8)
    var restored = try persistenceBody(100)
    restored.energy = 100
    restored.missiles = 4
    restored.ecmEnabled = false
    persistenceExpect(rebind.restore(body: &restored, pose: pose))
    #expect(restored.energy == 34 && restored.missiles == 1 && restored.ecmEnabled)
    #expect(restored.physical?.npc == original.npc && restored.physical?.laserCooldown == 0.45)
    let actualWorld = pose.orientation.apply(restored.modelVector(.init(0, 0, 1)))
    let originalWorld = try persistenceBody().modelVector(.init(0, 0, 1))
    #expect((actualWorld - originalWorld).length < 1e-10)
    #expect((pose.systemPoint(restored.position) - original.position).length < 1e-10)
    persistenceExpect(ledger.acknowledge(receipts: [receipt, receipt]).isEmpty)
    persistenceExpect(ledger.capture(original, protection: .init()) == .refused(.staleActor))
    var updated = rebind.snapshot
    updated.energy = 12
    updated.missiles = 0
    updated.ecmEnabled = false
    updated.npc.resources?.fuel = 2
    updated.physicalTime = 101
    persistenceExpect(ledger.capture(updated, protection: .init()) == .updated(original.actor))
    ledger.cull(actor: rebind.actor)
    let retry = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(102)).first)
    #expect(
      retry.energy == 12 && retry.npc?.resources?.fuel == 2 && retry.identity != request.identity)
    let next = ledger.acknowledge(receipts: [
      .init(request: retry.identity, actor: crimeTestID(101), refusal: nil)
    ])
    #expect(next.first?.snapshot.missiles == 0 && next.first?.snapshot.ecmEnabled == false)
    #expect(ledger.livingCount == 1 && ledger.count == 1 && ledger.valid)
  }

  @Test func admissionRefusalReplayWrongVisitAndOldOfferNeverDuplicateOrRefill() throws {
    var ledger = NPCPersistenceLedger()
    _ = ledger.capture(try persistenceSnapshot(), protection: .init())
    ledger.cull(actor: crimeTestID(2))
    let context = crimeTestContext(10)
    let request = try persistenceRequire(ledger.pendingSpawnRequests(context: context).first)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: nil, refusal: .unsafePosition)
      ]).isEmpty)
    ledger = try persistenceRoundtrip(ledger)
    persistenceExpect(ledger.pendingSpawnRequests(context: context) == [request])
    persistenceExpect(
      ledger.pendingSpawnRequests(
        context: crimeTestContext(10, budget: .init(active: [.pirate: 8], total: 8))
      ).isEmpty)
    persistenceExpect(ledger.pendingSpawnRequests(context: context) == [request])
    for actor in [crimeTestID(100, visit: 2), crimeTestID(2)] {
      persistenceExpect(
        ledger.acknowledge(receipts: [.init(request: request.identity, actor: actor, refusal: nil)])
          .isEmpty)
    }
    ledger.resetPhysicalBindings(system: crimeTestSystem)
    let next = try persistenceRequire(ledger.pendingSpawnRequests(context: context).first)
    #expect(next.identity != request.identity && next.npc == request.npc)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(100), refusal: nil)
      ]).isEmpty)
    let receipt = SpawnReceipt(request: next.identity, actor: crimeTestID(101), refusal: nil)
    persistenceExpect(ledger.acknowledge(receipts: [receipt, receipt]).count == 1)
    persistenceExpect(ledger.pendingSpawnRequests(context: context).isEmpty && ledger.valid)
  }

  @Test func capacityRefusalIsAtomicAndTerminalEntriesNeverEvictOrReleaseExtraShips() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...129 {
      persistenceExpect(
        ledger.capture(try persistenceSnapshot(entity), protection: .init())
          == .registered(crimeTestID(entity)))
    }
    let full = ledger
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init()) == .refused(.capacity))
    #expect(ledger == full && ledger.count == 128)
    persistenceExpect(ledger.terminal(actor: crimeTestID(2), reason: .destroyed))
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init()) == .refused(.capacity))
    ledger.depart(system: .init(galaxy: 0, system: 88))
    #expect(ledger.count == 128)
    ledger.depart(system: crimeTestSystem)
    #expect(ledger.count == 0 && ledger.system == nil && ledger.valid)
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(2), protection: .init()) == .refused(.staleActor))
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init())
        == .registered(crimeTestID(130)))
  }

  @Test func outOfOrderReceiptsBindOnceAndRetiredPhysicalActorCannotBecomeAnotherShip() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...3 {
      _ = ledger.capture(try persistenceSnapshot(entity), protection: .init())
      ledger.cull(actor: crimeTestID(entity))
    }
    let requests = ledger.pendingSpawnRequests(context: crimeTestContext(10))
    let receipts: [SpawnReceipt] = [
      .init(request: requests[1].identity, actor: crimeTestID(101), refusal: nil),
      .init(request: requests[0].identity, actor: crimeTestID(100), refusal: nil),
    ]
    let accepted = ledger.acknowledge(receipts: receipts)
    #expect(accepted.map(\.actor.entity) == [100, 101])
    persistenceExpect(ledger.terminal(actor: crimeTestID(101), reason: .destroyed))
    ledger.cull(actor: crimeTestID(100))
    let next = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(11)).first)
    let before = ledger
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: next.identity, actor: crimeTestID(101), refusal: nil)
      ]).isEmpty)
    #expect(ledger == before && ledger.valid)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: next.identity, actor: crimeTestID(102), refusal: nil)
      ]).count == 1)
    #expect(ledger.logicalIdentity(for: crimeTestID(102)) == crimeTestID(2))
  }

  @Test func allocatorOrderStaleTimeAndWrongSystemUpdatesCannotOverwriteActualState() throws {
    var ledger = NPCPersistenceLedger()
    let first = try persistenceSnapshot(10)
    _ = ledger.capture(first, protection: .init())
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(9), protection: .init()) == .refused(.staleActor))
    _ = ledger.capture(try persistenceSnapshot(11), protection: .init())
    var update = first
    update.energy = 21
    update.physicalTime = 11
    persistenceExpect(ledger.capture(update, protection: .init()) == .updated(first.actor))
    let before = ledger
    persistenceExpect(ledger.capture(first, protection: .init()) == .refused(.staleTime))
    var other = try persistenceSnapshot(12)
    other.actor = .init(system: .init(galaxy: 0, system: 9), visit: 1, entity: 12)
    persistenceExpect(ledger.capture(other, protection: .init()) == .refused(.wrongSystem))
    #expect(ledger == before)
    ledger.cull(actor: crimeTestID(99))
    ledger.resetPhysicalBindings(system: other.actor.system)
    #expect(ledger == before && ledger.logicalIdentity(for: first.actor) == first.actor)
  }

  @Test func missionProtectedAndNonShipBodiesAreExcludedWithoutOrdinaryFallbacks() throws {
    let ordinary = try persistenceBody()
    var variants: [SpaceBody] = []
    var body = ordinary
    body.navalTarget = true
    variants.append(body)
    body = ordinary
    body.blackjackIdentity = UUID()
    variants.append(body)
    body = ordinary
    body.physical?.npc?.role = .mission
    variants.append(body)
    body = ordinary
    body.physical?.population = .mission
    variants.append(body)
    body = ordinary
    body.physical?.payload = .wreck(crimeTestID(80), lot: 0)
    variants.append(body)
    body = ordinary
    body.physical = nil
    variants.append(body)
    body = ordinary
    body.hull = .cargo
    variants.append(body)
    body = ordinary
    body.energy = 0
    variants.append(body)
    for variant in variants {
      #expect(
        NPCPersistenceSnapshot.capture(
          body: variant, pose: .init(), physicalTime: 10, protection: .init()) == nil)
    }
    let protection = MissionProtection(protectedActors: [crimeTestID(2)])
    #expect(
      NPCPersistenceSnapshot.capture(
        body: ordinary, pose: .init(), physicalTime: 10, protection: protection) == nil)
    var ledger = NPCPersistenceLedger()
    let snapshot = try persistenceSnapshot()
    persistenceExpect(ledger.capture(snapshot, protection: protection) == .refused(.protectedActor))
    #expect(ledger.count == 0 && ledger.valid)
    _ = ledger.capture(snapshot, protection: .init())
    ledger.cull(actor: snapshot.actor)
    persistenceExpect(
      ledger.pendingSpawnRequests(context: crimeTestContext(10, protection: protection)).isEmpty)
    persistenceExpect(
      ledger.pendingSpawnRequests(
        context: crimeTestContext(10, protection: .init(suppressAmbientShips: true))
      ).isEmpty)
  }

  @Test func allTerminalReasonsSurviveReloadAndStalePhysicalReplaysCannotResurrect() throws {
    for reason in [NPCTerminalReason.destroyed, .docked, .jumped, .expired] {
      var ledger = NPCPersistenceLedger()
      let snapshot = try persistenceSnapshot()
      _ = ledger.capture(snapshot, protection: .init())
      persistenceExpect(ledger.terminal(actor: snapshot.actor, reason: reason))
      persistenceExpect(!ledger.terminal(actor: snapshot.actor, reason: reason))
      ledger = try persistenceRoundtrip(ledger)
      ledger.cull(actor: snapshot.actor)
      ledger.resetPhysicalBindings(system: crimeTestSystem)
      persistenceExpect(
        ledger.pendingSpawnRequests(context: crimeTestContext(20, visit: 2)).isEmpty)
      persistenceExpect(ledger.capture(snapshot, protection: .init()) == .refused(.staleActor))
      #expect(
        ledger.count == 1 && ledger.livingCount == 0 && ledger.binding(for: snapshot.actor) == nil
          && ledger.valid)
    }
  }

  @Test func dockAndNewVisitRetainExactSnapshotWithoutHiddenRechargeOrCoordinateReset() throws {
    var ledger = NPCPersistenceLedger()
    let snapshot = try persistenceSnapshot()
    _ = ledger.capture(snapshot, protection: .init())
    ledger.resetPhysicalBindings(system: crimeTestSystem)
    let old = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    ledger = try persistenceRoundtrip(ledger)
    let next = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10000, visit: 5)).first)
    #expect(next.identity.visit == 5 && next.identity != old.identity)
    #expect(next.position == snapshot.position && next.orientation == snapshot.orientation)
    #expect(next.npc == snapshot.npc && next.energy == snapshot.energy)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: old.identity, actor: crimeTestID(50), refusal: nil)
      ]).isEmpty)
    let accepted = ledger.acknowledge(receipts: [
      .init(request: next.identity, actor: crimeTestID(51, visit: 5), refusal: nil)
    ])
    #expect(
      accepted.first?.logicalIdentity == snapshot.actor
        && accepted.first?.snapshot.physicalTime == 10)
    #expect(accepted.first?.snapshot.laserCooldown == 0.45 && ledger.valid)
  }

  @Test func policeReservePopulationCapsAndSuppressionUseCurrentAdmissionBudget() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...12 {
      var snapshot = try persistenceSnapshot(entity)
      if entity == 12 {
        snapshot.population = .police
        snapshot.npc.role = .police
      }
      _ = ledger.capture(snapshot, protection: .init())
      ledger.cull(actor: snapshot.actor)
    }
    let limited = crimeTestContext(10, budget: .init(active: [.pirate: 7], total: 7))
    let requests = ledger.pendingSpawnRequests(context: limited)
    #expect(requests.count == 2 && requests.map(\.population) == [.pirate, .police])
    let suppressed = crimeTestContext(10, protection: .init(suppressAmbientShips: true))
    persistenceExpect(
      ledger.pendingSpawnRequests(context: suppressed).map(\.population) == [.police])
    let full = crimeTestContext(10, budget: .init(total: 128))
    persistenceExpect(ledger.pendingSpawnRequests(context: full).isEmpty)
    let reserved = crimeTestContext(10, budget: .init(total: 116))
    persistenceExpect(ledger.pendingSpawnRequests(context: reserved).map(\.population) == [.police])
    #expect(ledger.livingCount == 11 && ledger.valid)
  }

  @Test func invalidSnapshotAndMismatchedRestoreRefuseWithoutMutation() throws {
    let original = try persistenceSnapshot()
    var ledger = NPCPersistenceLedger()
    let capacity = try persistenceRequire(original.npc.resources).energyCapacity
    for invalidEnergy in [Double.nan, -1, 0, capacity + 1] {
      var invalid = original
      invalid.energy = invalidEnergy
      persistenceExpect(ledger.capture(invalid, protection: .init()) == .refused(.invalidSnapshot))
    }
    #expect(ledger.count == 0 && ledger.system == nil)
    _ = ledger.capture(original, protection: .init())
    ledger.cull(actor: original.actor)
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(9)).isEmpty)
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(.nan)).isEmpty)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    let rebind = try persistenceRequire(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(30), refusal: nil)
      ]).first)
    var mismatch = try persistenceBody(31)
    let before = mismatch
    persistenceExpect(!rebind.restore(body: &mismatch, pose: .init()))
    #expect(mismatch == before)
    var invalidPose = ShipPose()
    invalidPose.orientation.x = .init(0, 0, 0)
    #expect(
      NPCPersistenceSnapshot.capture(
        body: try persistenceBody(), pose: invalidPose, physicalTime: 10, protection: .init()) == nil)
  }
}

extension NPCPersistenceLedgerTests {
  @Test func currentDeclaredNativeBindingRejectsMatchingWrongTagBeforeCaptureAndRebind() throws {
    let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let hull = try persistenceRequire(source.ship.nativeHull)
    let stock = try persistenceRequire(NPCResources.stock(source.performance))
    try #require(hull == .viper && stock.fuel != nil)
    var npc = NPCState(role: .police, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = stock
    var body = SpaceBody(id: 2, hull: hull, position: .init(10, 20, 30))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: crimeTestID(2), population: .police, npc: npc, catalogueShipID: source.ship.id)
    let snapshot = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: body, pose: .init(), physicalTime: 10, protection: .init()))
    try #require(snapshot.valid && snapshot.hull == hull && snapshot.npc.resources == stock)
    let cold = try JSONDecoder().decode(
      NPCPersistenceSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(cold == snapshot && cold.valid)
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(cold, protection: .init()) == .registered(cold.actor))
    ledger.cull(actor: cold.actor)
    ledger = try persistenceRoundtrip(ledger)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    try #require(request.hull == hull && request.catalogueShipID == source.ship.id)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    let acknowledged = ledger
    var target = SpaceBody(id: 30, hull: hull, position: .init(40, 50, 60))
    target.energy = stock.energyCapacity
    target.missiles = 0
    target.physical = .init(
      identity: crimeTestID(30), population: .police, npc: npc, catalogueShipID: source.ship.id)
    for wrong in [Hull.cobra, .sidewinder] {
      try #require(wrong != hull)
      var invalid = snapshot
      invalid.hull = wrong
      #expect(!invalid.valid)
      let invalidCold = try JSONDecoder().decode(
        NPCPersistenceSnapshot.self, from: JSONEncoder().encode(invalid))
      #expect(invalidCold == invalid && !invalidCold.valid)
      #expect(ledger.capture(invalidCold, protection: .init()) == .refused(.invalidSnapshot))
      #expect(ledger == acknowledged)
      var wrongBody = target
      wrongBody.hull = wrong
      let unchanged = wrongBody
      try #require(wrongBody.hull == invalidCold.hull)
      try #require(wrongBody.physical?.identity == rebind.actor)
      try #require(wrongBody.physical?.catalogueShipID == invalidCold.catalogueShipID)
      #expect(NPCPersistenceSnapshot.capture(
        body: wrongBody, pose: .init(), physicalTime: 20, protection: .init()) == nil)
      let wrongRebind = NPCRebind(
        logicalIdentity: rebind.logicalIdentity, actor: rebind.actor, snapshot: invalidCold)
      #expect(!wrongRebind.restore(body: &wrongBody, pose: .init()))
      #expect(wrongBody == unchanged && ledger == acknowledged)
    }
    #expect(rebind.restore(body: &target, pose: .init()))
    #expect(target.position == snapshot.position && target.orientation == snapshot.orientation)
    #expect(target.energy == snapshot.energy && target.missiles == snapshot.missiles)
    #expect(target.physical?.npc == snapshot.npc && target.physical?.npc?.resources == stock)
    #expect(target.physical?.catalogueShipID == source.ship.id && ledger == acknowledged)
  }

  @Test func rebindRefusesDistinctPhysicalOwnersBeforeAnyBodyMutation() throws {
    let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let stock = try persistenceRequire(NPCResources.stock(source.performance))
    let hull = try persistenceRequire(source.ship.nativeHull)
    var npc = NPCState(role: .pirate, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = stock
    npc.resources?.fuel = 0
    var originalBody = SpaceBody(id: 2, hull: hull, position: .init(10, 20, 30))
    originalBody.energy = 1
    originalBody.missiles = 0
    originalBody.physical = .init(
      identity: crimeTestID(2), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    let snapshot = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: originalBody, pose: .init(), physicalTime: 10, protection: .init()))
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(snapshot, protection: .init()) == .registered(snapshot.actor))
    ledger.cull(actor: snapshot.actor)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    let acknowledged = ledger
    var target = SpaceBody(id: 30, hull: originalBody.hull, position: .init(40, 50, 60))
    target.energy = stock.energyCapacity
    target.physical = .init(
      identity: crimeTestID(30), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    var protectedTargets = Array(repeating: target, count: 6)
    protectedTargets[0].physical?.npc = nil
    protectedTargets[1].physical?.empSource = crimeTestID(50)
    protectedTargets[2].physical?.blocksNavalEncounter = true
    protectedTargets[3].physical?.rock = .init(system: crimeTestSystem, field: 1, rock: 1)
    protectedTargets[4].physical?.payload = .wreck(crimeTestID(50), lot: 1)
    protectedTargets[5].blackjackIdentity = UUID(uuidString: "00000000-0000-0000-0000-000000000006")
    try #require(protectedTargets[5].blackjackRole == nil
      && protectedTargets[5].blackjackIdentity != nil)
    for var protected in protectedTargets {
      try #require(protected.hull == snapshot.hull && protected.physical?.identity == receipt.actor)
      try #require(protected.physical?.catalogueShipID == snapshot.catalogueShipID)
      let before = protected
      #expect(!rebind.restore(body: &protected, pose: .init()))
      #expect(protected == before && protected.physical == before.physical)
      #expect(ledger == acknowledged)
    }
    #expect(rebind.restore(body: &target, pose: .init()))
    #expect(target.position == snapshot.position && target.energy == snapshot.energy)
    #expect(target.physical?.npc == snapshot.npc && target.missiles == snapshot.missiles)
    #expect(target.physical?.catalogueShipID == source.ship.id && ledger == acknowledged)
  }

  @Test func currentCatalogueRequiresKnownFuelAndRetainsEmptyTankAcrossColdRebind() throws {
    let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let stock = try persistenceRequire(NPCResources.stock(source.performance))
    let hull = try persistenceRequire(source.ship.nativeHull)
    try #require(stock.fuel == source.performance.fuel && source.performance.fuel > 0)
    var npc = NPCState(role: .pirate, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = stock
    var body = SpaceBody(id: 2, hull: hull, position: .init(10, 20, 30))
    body.energy = stock.energyCapacity
    body.missiles = 0
    body.physical = .init(
      identity: crimeTestID(2), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    let full = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: body, pose: .init(), physicalTime: 10, protection: .init()))
    #expect(full.npc.resources?.fuel == source.performance.fuel)
    body.physical?.npc?.resources?.fuel = 0
    let empty = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: body, pose: .init(), physicalTime: 10, protection: .init()))
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(empty, protection: .init()) == .registered(empty.actor))
    ledger.cull(actor: empty.actor)
    let before = ledger
    var missing = empty
    missing.npc.resources?.fuel = nil
    #expect(missing.npc.resources?.valid == true && !missing.valid)
    #expect(ledger.capture(missing, protection: .init()) == .refused(.invalidSnapshot))
    let updatedMissing = ledger.updateUnbound(logicalIdentity: empty.actor, snapshot: missing)
    #expect(!updatedMissing)
    #expect(ledger == before)
    var missingBody = body
    missingBody.physical?.npc?.resources?.fuel = nil
    let beforeBody = missingBody
    #expect(NPCPersistenceSnapshot.capture(
      body: missingBody, pose: .init(), physicalTime: 10, protection: .init()) == nil)
    #expect(missingBody == beforeBody)
    ledger = try persistenceRoundtrip(ledger)
    #expect(ledger.snapshot(for: empty.actor) == empty)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    #expect(request.npc?.resources?.fuel == 0)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    var restored = SpaceBody(id: 30, hull: body.hull, position: .init(0, 0, 0))
    restored.physical = .init(
      identity: crimeTestID(30), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    #expect(rebind.restore(body: &restored, pose: .init()))
    #expect(restored.physical?.npc?.resources == empty.npc.resources)
    #expect(restored.physical?.npc?.resources?.fuel == 0)
    #expect(restored.energy == empty.energy && restored.missiles == empty.missiles)
    #expect(restored.physical?.catalogueShipID == source.ship.id)
  }

  @Test func currentCatalogueCargoCountsOnlyTonneAllocationAndRejectsOverflowBeforeMutation() throws {
    let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let stock = try persistenceRequire(NPCResources.stock(source.performance))
    let hull = try persistenceRequire(source.ship.nativeHull)
    let capacity = source.performance.cargo
    try #require(capacity > 1 && capacity < Int.max)
    try #require(CommodityIdentity.food.unit == "t" && CommodityIdentity.alloys.unit == "t")
    try #require(CommodityIdentity.gold.unit != "t")
    var npc = NPCState(role: .pirate, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = stock
    npc.resources?.frontShield = 0
    npc.resources?.fuel = 0
    npc.ordinaryCargo = [.init(commodity: .food, quantity: capacity - 1),
      .init(commodity: .alloys, quantity: 1), .init(commodity: .gold, quantity: 63)]
    var body = SpaceBody(id: 2, hull: hull, position: .init(10, 20, 30))
    body.energy = 1
    body.missiles = 0
    body.physical = .init(
      identity: crimeTestID(2), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    let original = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: body, pose: .init(), physicalTime: 10, protection: .init()))
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(original, protection: .init()) == .registered(original.actor))
    ledger.cull(actor: original.actor)
    let before = ledger
    let invalidManifests: [[CommodityAmount]] = [
      [.init(commodity: .food, quantity: capacity + 1)],
      [.init(commodity: .food, quantity: capacity), .init(commodity: .food, quantity: 1)],
      [.init(commodity: .food, quantity: Int.max / 17)],
    ]
    for manifest in invalidManifests {
      let validManifest = manifest.allSatisfy(\.valid)
      try #require(validManifest)
      var invalid = original
      invalid.npc.ordinaryCargo = manifest
      #expect(!invalid.valid)
      #expect(ledger.capture(invalid, protection: .init()) == .refused(.invalidSnapshot))
      let updatedInvalid = ledger.updateUnbound(logicalIdentity: original.actor, snapshot: invalid)
      #expect(!updatedInvalid)
      #expect(ledger == before)
      var invalidBody = body
      invalidBody.physical?.npc?.ordinaryCargo = manifest
      let originalBody = invalidBody
      #expect(NPCPersistenceSnapshot.capture(
        body: invalidBody, pose: .init(), physicalTime: 10, protection: .init()) == nil)
      #expect(invalidBody == originalBody)
    }
    ledger = try persistenceRoundtrip(ledger)
    #expect(ledger.snapshot(for: original.actor) == original)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    #expect(request.npc?.ordinaryCargo == npc.ordinaryCargo)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    var restored = SpaceBody(id: 30, hull: body.hull, position: .init(0, 0, 0))
    restored.physical = .init(
      identity: crimeTestID(30), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    #expect(rebind.restore(body: &restored, pose: .init()))
    #expect(restored.physical?.npc?.ordinaryCargo == npc.ordinaryCargo)
    #expect(restored.physical?.npc?.resources == npc.resources && restored.energy == 1)
    #expect(restored.missiles == 0 && restored.physical?.catalogueShipID == source.ship.id)
  }

  @Test func currentCatalogueMissileCapacityRejectsOverflowAndPreservesSpentPoolsAcrossColdRebind() throws {
    let source = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let stock = try persistenceRequire(NPCResources.stock(source.performance))
    let hull = try persistenceRequire(source.ship.nativeHull)
    try #require(source.performance.missiles > 0 && source.performance.missiles < Int.max)
    var npc = NPCState(role: .pirate, origin: crimeTestSystem, destination: crimeTestSystem)
    npc.resources = stock
    var body = SpaceBody(id: 2, hull: hull, position: .init(10, 20, 30))
    body.energy = stock.energyCapacity
    body.missiles = source.performance.missiles
    body.physical = .init(
      identity: crimeTestID(2), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    let maximum = try persistenceRequire(NPCPersistenceSnapshot.capture(
      body: body, pose: .init(), physicalTime: 10, protection: .init()))
    #expect(maximum.valid && maximum.missiles == source.performance.missiles)
    #expect(NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
      catalogueShipID: source.ship.id, hull: hull, npc: npc, missiles: body.missiles))
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(maximum, protection: .init()) == .registered(maximum.actor))
    ledger.cull(actor: maximum.actor)
    let before = ledger
    for count in [Int.min, -1, source.performance.missiles + 1, Int.max] {
      var invalid = maximum
      invalid.missiles = count
      // Exercise the source boundary itself, before snapshot.valid's separate invariants.
      #expect(!NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
        catalogueShipID: source.ship.id, hull: hull, npc: invalid.npc, missiles: count))
      #expect(!invalid.valid)
      #expect(ledger.capture(invalid, protection: .init()) == .refused(.invalidSnapshot))
      let updatedInvalid = ledger.updateUnbound(logicalIdentity: maximum.actor, snapshot: invalid)
      #expect(!updatedInvalid)
      #expect(ledger == before)
      var invalidBody = body
      invalidBody.missiles = count
      let originalBody = invalidBody
      #expect(NPCPersistenceSnapshot.capture(
        body: invalidBody, pose: .init(), physicalTime: 10, protection: .init()) == nil)
      #expect(invalidBody == originalBody)
    }
    var spent = maximum
    spent.missiles = 0
    spent.energy = 1
    spent.npc.resources?.frontShield = 0
    spent.npc.resources?.fuel = 0
    #expect(NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
      catalogueShipID: source.ship.id, hull: hull, npc: spent.npc, missiles: 0))
    let updatedSpent = ledger.updateUnbound(logicalIdentity: maximum.actor, snapshot: spent)
    #expect(updatedSpent)
    ledger = try persistenceRoundtrip(ledger)
    #expect(ledger.snapshot(for: maximum.actor) == spent)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    #expect(request.catalogueShipID == source.ship.id && request.energy == 1)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    var restored = SpaceBody(id: 30, hull: body.hull, position: .init(0, 0, 0))
    restored.energy = stock.energyCapacity
    restored.missiles = source.performance.missiles
    restored.physical = .init(
      identity: crimeTestID(30), population: .pirate, npc: npc, catalogueShipID: source.ship.id)
    #expect(rebind.restore(body: &restored, pose: .init()))
    #expect(restored.missiles == 0 && restored.energy == 1 && restored.physical?.npc == spent.npc)
    #expect(restored.physical?.catalogueShipID == source.ship.id)
  }

  @Test func acknowledgedRebindCannotReplaceAnAdmittedHullSourceOrEraseItsIdentity() throws {
    let original = try persistenceSnapshot()
    var ledger = NPCPersistenceLedger()
    #expect(ledger.capture(original, protection: .init()) == .registered(original.actor))
    ledger.cull(actor: original.actor)
    ledger = try persistenceRoundtrip(ledger)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(20)).first)
    try #require(request.catalogueShipID == original.catalogueShipID)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(30), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    let acknowledged = ledger
    let other = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let otherStock = try persistenceRequire(NPCResources.stock(other.performance))
    let mismatchedIDs: [String?] = [other.ship.id, nil, "SH067"]
    for id in mismatchedIDs {
      var body = try persistenceBody(30)
      body.physical?.catalogueShipID = id
      if id == other.ship.id { body.physical?.npc?.resources = otherStock }
      try #require(body.hull == original.hull && body.physical?.identity == receipt.actor)
      let before = body
      #expect(!rebind.restore(body: &body, pose: .init()))
      #expect(body == before && body.physical == before.physical && ledger == acknowledged)
    }
    var matching = try persistenceBody(30)
    matching.energy = 1
    matching.physical?.npc?.resources?.frontShield = 0
    #expect(rebind.restore(body: &matching, pose: .init()))
    #expect(matching.physical?.catalogueShipID == original.catalogueShipID)
    #expect(matching.energy == original.energy && matching.physical?.npc == original.npc)
    #expect(ledger == acknowledged)
  }

  @Test func currentHullSnapshotsPreserveConsumedPoolsButRejectUnknownPendingAndBorrowedCapacities() throws {
    let original = try persistenceSnapshot()
    let current = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let expected = try persistenceRequire(NPCResources.stock(current.performance))
    let actual = try persistenceRequire(original.npc.resources)
    #expect(original.valid && actual.energyCapacity == expected.energyCapacity)
    #expect(actual.frontCapacity == expected.frontCapacity && actual.fuelCapacity == expected.fuelCapacity)
    #expect(actual.frontShield == 17 && actual.rearShield == 23 && actual.laserHeat == 51)
    #expect(actual.fuel == 13 && actual.scoopRemainder == 0.3 && original.energy == 34)
    var invalid: [NPCPersistenceSnapshot] = []
    var changed = original
    changed.catalogueShipID = "SH999"
    invalid.append(changed)
    changed = original
    changed.catalogueShipID = "SH067"
    invalid.append(changed)
    changed = original
    changed.npc.resources = nil
    invalid.append(changed)
    let other = try persistenceRequire(OriginalFleetRuntimeHullSource.source(for: "SH031"))
    let borrowed = try persistenceRequire(NPCResources.stock(other.performance))
    try #require(borrowed.energyCapacity != expected.energyCapacity)
    changed = original
    changed.npc.resources = borrowed
    invalid.append(changed)
    changed = original
    changed.npc.resources = NPCResources.legacyEnergyOnly(maximumEnergy: expected.energyCapacity)
    invalid.append(changed)
    var ledger = NPCPersistenceLedger()
    let before = ledger
    for snapshot in invalid {
      #expect(!snapshot.valid)
      #expect(ledger.capture(snapshot, protection: .init()) == .refused(.invalidSnapshot))
      #expect(ledger == before)
    }
    #expect(ledger.capture(original, protection: .init()) == .registered(original.actor))
    let cold = try persistenceRoundtrip(ledger)
    #expect(cold.valid && cold == ledger && cold.snapshot(for: original.actor) == original)
  }
}
