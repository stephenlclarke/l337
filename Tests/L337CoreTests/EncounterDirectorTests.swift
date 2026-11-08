import Foundation
import Testing

@testable import L337Core

func ecologyActor(
  _ entity: UInt64, role: NPCRole? = nil, position: Vector3 = .init(0, 0, 6000),
  energy: Double = 100, cargo: [CommodityAmount] = [], intention: NPCAction? = nil,
  aggressor: ActorIdentity? = nil, rock: RockIdentity? = nil, payload: PayloadIdentity? = nil
) -> ActorSnapshot {
  let system = SystemIdentity(galaxy: 0, system: 7)
  var npc = role.map { NPCState(role: $0, origin: system, destination: system) }
  npc?.ordinaryCargo = cargo
  npc?.intention = intention
  npc?.firstAggressor = aggressor
  return .init(
    identity: .init(system: system, visit: 1, entity: entity),
    hull: role == .police ? .viper : .cobra,
    position: position, orientation: .init(), velocity: .init(0, 0, 0), energy: energy,
    maximumEnergy: 100, maximumSpeedUnitsPerSecond: 144, legal: .init(), npc: npc,
    rock: rock, payload: payload, ordinaryCargo: cargo)
}

func ecologyContext(
  time: Double = 0, seed: UInt64 = 1, government: Int = 0,
  position: Vector3 = .init(0, 0, 6000), actors: [ActorSnapshot] = [],
  protection: MissionProtection = .init(), budget: AdmissionBudget = .init(),
  playerCargo: [CommodityAmount] = []
) -> EncounterContext {
  let system = SystemIdentity(galaxy: 0, system: 7)
  let station = StationAnchor(
    identity: .init(system: system, visit: 1, entity: 1),
    position: .init(0, 0, 0), orientation: .init(), exitPosition: .init(0, 0, 600),
    exitDirection: .init(0, 0, 1))
  let anchors = SystemAnchors(
    system: system, station: station, arrival: .init(0, 0, 12000),
    planet: .init(position: .init(20000, 0, 0), radius: 1000),
    sun: .init(position: .init(50000, 0, 0), radius: 1000))
  return .init(
    system: system, seed: seed, government: government, visit: 1, revision: 1,
    physicalTime: time, anchors: anchors,
    player: ecologyActor(0, position: position, cargo: playerCargo),
    actors: actors, protection: protection, budget: budget, perceptionRadius: 3000)
}

@Test func encounterDeadlinePartitionAndSaveReplayProduceIdenticalRequests() throws {
  let start = ecologyContext()
  var whole = EncounterDirector(context: start)
  #expect((8...12).contains(whole.nextDecisionTime))
  let expected = whole.advance(context: ecologyContext(time: 120))
  var partitioned = EncounterDirector(context: start)
  var batches: [SpawnBatch] = []
  for time in 1...120 {
    batches += partitioned.advance(context: ecologyContext(time: Double(time))).batches
  }
  #expect(batches == expected.batches)
  #expect(partitioned.decisionCount == whole.decisionCount)
  #expect(partitioned.nextDecisionTime == whole.nextDecisionTime)
  let data = try JSONEncoder().encode(partitioned)
  var restored = try JSONDecoder().decode(EncounterDirector.self, from: data)
  #expect(restored == partitioned)
  #expect(
    restored.advance(context: ecologyContext(time: 160))
      == partitioned.advance(context: ecologyContext(time: 160)))
}

@Test func encounterSuppressionAndBudgetDenialDoNotAccumulateBurstsOrAdmitActors() {
  let start = ecologyContext()
  var director = EncounterDirector(context: start)
  var protection = MissionProtection()
  protection.suppressAmbientShips = true
  let suppressed = director.advance(context: ecologyContext(time: 120, protection: protection))
  #expect(
    suppressed.batches.isEmpty && director.decisionCount >= 10 && director.pendingRequests.isEmpty)
  let resumed = director.advance(context: ecologyContext(time: 120))
  #expect(resumed.batches.isEmpty && director.admittedCount == 0)
  var budget = AdmissionBudget()
  budget.total = 128
  #expect(director.advance(context: ecologyContext(time: 240, budget: budget)).batches.isEmpty)
  #expect(director.advance(context: ecologyContext(time: 240)).batches.isEmpty)
}

@Test func encounterReceiptsOnlyCountActualAdmissionAndIgnoreDuplicates() {
  var director = EncounterDirector(context: ecologyContext())
  let plan = director.advance(context: ecologyContext(time: 120))
  let requests = plan.batches.flatMap(\.requests)
  #expect(!requests.isEmpty && director.admittedCount == 0)
  let receipts = requests.enumerated().map { index, request in
    SpawnReceipt(
      request: request.identity,
      actor: index == 0
        ? .init(system: request.identity.system, visit: request.identity.visit, entity: 100) : nil,
      refusal: index == 0 ? nil : .reservedCapacity)
  }
  director.acknowledge(receipts: receipts)
  director.acknowledge(receipts: receipts)
  #expect(director.admittedCount == 1 && director.pendingRequests.isEmpty)
  #expect(director.advance(context: ecologyContext(time: 120)).batches.isEmpty)
}

@Test func encounterPacksAreAtomicBoundedSeparatedAndRespectSharedReserves() {
  var director = EncounterDirector(context: ecologyContext())
  var budget = AdmissionBudget()
  budget.maximum = 20
  let context = ecologyContext(time: 120, budget: budget)
  let plan = director.advance(context: context)
  let requests = plan.batches.flatMap(\.requests)
  #expect(requests.count <= 8)
  #expect(Set(requests.map(\.identity)).count == requests.count)
  for batch in plan.batches {
    if batch.requests.first?.population == .pirate {
      #expect(batch.atomic && (2...5).contains(batch.requests.count))
      #expect(
        batch.requests.allSatisfy {
          ($0.position - context.player.position).length > context.perceptionRadius
        })
    }
    for request in batch.requests {
      #expect(request.priority == .ordinary)
      #expect(
        EncounterGeography.safe(
          request.position, context: context, civilianEntry: request.population == .civilian))
    }
  }
  budget.active[.pirate] = 7
  var full = EncounterDirector(context: ecologyContext())
  let constrained = full.advance(context: ecologyContext(time: 120, budget: budget))
  #expect(!constrained.batches.contains { $0.requests.first?.population == .pirate })
}

@Test func encounterSeededA11SamplesRetainGovernmentGeographyAndLawfulDeepSpaceRisk() {
  func pirateCount(government: Int, position: Vector3) -> Int {
    (1...1000).reduce(0) { total, seed in
      let initial = ecologyContext(seed: UInt64(seed), government: government, position: position)
      var director = EncounterDirector(context: initial)
      return total
        + director.advance(
          context: ecologyContext(
            time: 12, seed: UInt64(seed), government: government,
            position: position)
        ).batches.flatMap(\.requests).filter { $0.population == .pirate }.count
    }
  }
  let anarchyLane = pirateCount(government: 0, position: .init(0, 0, 6000))
  let corporateLane = pirateCount(government: 7, position: .init(0, 0, 6000))
  let anarchyStation = pirateCount(government: 0, position: .init(0, 0, 0))
  let corporateDeep = pirateCount(government: 7, position: .init(0, 15000, 6000))
  #expect(anarchyLane > corporateLane * 4)
  #expect(anarchyLane > anarchyStation * 4)
  #expect(corporateDeep > 0 && corporateDeep < corporateLane)
}

@Test func encounterGeographyUsesSegmentsPriorityAndRigidCoordinateTransforms() {
  let anchors = ecologyContext().anchors
  #expect(
    EncounterGeography.region(at: anchors.station.position, anchors: anchors) == .stationSecurity)
  #expect(EncounterGeography.region(at: .init(0, 0, 6000), anchors: anchors) == .tradeLane)
  #expect(EncounterGeography.region(at: .init(32000, 0, 0), anchors: anchors) == .miningBand)
  #expect(EncounterGeography.region(at: .init(0, 15000, 6000), anchors: anchors) == .deepSpace)
  #expect(
    EncounterGeography.distanceToSegment(.init(20, 4, 0), from: .init(0, 0, 0), to: .init(10, 0, 0))
      == sqrt(116))
  #expect(
    EncounterGeography.distanceToSegment(.init(0, 3, 4), from: .init(0, 0, 0), to: .init(0, 0, 0))
      == 5)
  func transform(_ value: Vector3) -> Vector3 {
    value.rotated(pitch: 0.4, roll: 0.7, yaw: -0.3) + .init(500, 600, 700)
  }
  let station = StationAnchor(
    identity: anchors.station.identity, position: transform(anchors.station.position),
    orientation: .init(), exitPosition: transform(anchors.station.exitPosition),
    exitDirection: anchors.station.exitDirection)
  let moved = SystemAnchors(
    system: anchors.system, station: station, arrival: transform(anchors.arrival),
    planet: .init(position: transform(anchors.planet.position), radius: anchors.planet.radius),
    sun: .init(position: transform(anchors.sun.position), radius: anchors.sun.radius))
  for position in [Vector3(0, 0, 6000), .init(32000, 0, 0), .init(0, 15000, 6000)] {
    #expect(
      EncounterGeography.region(at: position, anchors: anchors)
        == EncounterGeography.region(at: transform(position), anchors: moved))
  }
}

@Test func actualAmbientPirateAndMinerProducerRequiresCurrentPublishedNativeSourceAndStock() throws {
  var director = EncounterDirector(context: ecologyContext())
  let context = ecologyContext(time: 120)
  let requests = director.advance(context: context).batches.flatMap(\.requests)
  let pirates = requests.filter { $0.npc?.role == .pirate }
  try #require(!pirates.isEmpty)
  try #require(requests.contains { $0.npc?.role == .trader })
  for request in requests {
    let npc = try #require(request.npc)
    if npc.role == .trader {
      #expect(OriginalFleetRuntimeHullSource.matchesAmbientTrader(request, context: context))
      var missingSource = request
      missingSource.catalogueShipID = nil
      #expect(!OriginalFleetRuntimeHullSource.matchesAmbientTrader(missingSource, context: context))
      // Current physical routing does not empty the ordinary generated manifest.
      #expect(!npc.ordinaryCargo.isEmpty && npc.cargoProvenance == .generated)
      continue
    }
    try #require(npc.role == .pirate || npc.role == .miner)
    let id = try #require(request.catalogueShipID)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: id))
    let role: ShipCatalogueRole = npc.role == .pirate ? .pirate : .miner
    #expect(source.permitsAmbient(role: role, context: context, position: request.position))
    #expect(npc.resources == NPCResources.stock(source.performance))
    #expect(OriginalFleetRuntimeHullSource.matchesAmbientNonTrader(request, context: context))
    var missing = request
    missing.catalogueShipID = nil
    #expect(!OriginalFleetRuntimeHullSource.matchesAmbientNonTrader(missing, context: context))
    var pending = request
    pending.catalogueShipID = "SH067"
    #expect(!OriginalFleetRuntimeHullSource.matchesAmbientNonTrader(pending, context: context))
    var noStock = npc
    noStock.resources = nil
    let altered = SpawnRequest(
      identity: request.identity, population: request.population, hull: request.hull,
      position: request.position, orientation: request.orientation, velocity: request.velocity,
      npc: noStock, rock: request.rock, payload: request.payload, priority: request.priority,
      catalogueShipID: id)
    #expect(!OriginalFleetRuntimeHullSource.matchesAmbientNonTrader(altered, context: context))
  }
}

@Test func actualSecondTraderProposalDoesNotRequireAnUnavailablePeregrineSource() throws {
  let world = try Universe.originalWorld(galaxy: 0, system: 2)
  try #require(world.name == "Aetaria" && world.governmentID == 6)
  #expect(OriginalFleetRuntimeHullSource.source(for: "SH025") == nil)
  // Controlled proposal geography, not an installed actor or a replay of the native fixture.
  let system = SystemIdentity(galaxy: 0, system: 2)
  let station = StationAnchor(
    identity: .init(system: system, visit: 1, entity: 1),
    position: .init(0, 0, 0), orientation: .init(), exitPosition: .init(0, 0, 600),
    exitDirection: .init(0, 0, 1))
  let anchors = SystemAnchors(
    system: system, station: station, arrival: .init(0, 0, 12000),
    planet: .init(position: .init(20000, 0, 0), radius: 1000),
    sun: .init(position: .init(50000, 0, 0), radius: 1000))
  let player = ActorSnapshot(
    identity: .init(system: system, visit: 1, entity: 0), hull: .cobra,
    position: .init(0, 0, 6000), orientation: .init(), velocity: .init(0, 0, 0),
    energy: 100, maximumEnergy: 100, maximumSpeedUnitsPerSecond: 144,
    legal: .init(), npc: nil, rock: nil, payload: nil)
  func context(_ time: Double) -> EncounterContext {
    .init(system: system, seed: 268890839879961, government: world.governmentID,
      visit: 1, revision: 1, physicalTime: time, anchors: anchors, player: player,
      actors: [], protection: .init(), budget: .init(), perceptionRadius: 6000)
  }
  let live = context(21.10000000000003)
  try #require(EncounterGeography.safe(anchors.arrival, context: live, civilianEntry: true))
  let qualified = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
  try #require(qualified.permitsAmbientTrader(context: live, position: anchors.arrival))
  var director = EncounterDirector(context: context(0))
  let plan = director.advance(context: live)
  let request = try #require(plan.batches.flatMap(\.requests).first {
    $0.identity.sequence == 2 && $0.npc?.role == .trader
  })
  let id = try #require(request.catalogueShipID)
  #expect(id != "SH025")
  #expect(request.identity.system == system && request.identity.visit == 1)
  #expect(request.identity.producer == .ambient && request.identity.member == 0)
  #expect(request.position == anchors.arrival && request.hull == .cobra)
  #expect(request.population == .civilian && request.priority == .ordinary)
  #expect(request.npc?.legalProvenance == .generated)
  #expect(request.npc?.cargoProvenance == .generated && request.npc?.routeProvenance == .generated)
  if let bison = OriginalBisonActivation.source(for: id) {
    #expect(request.npc?.resources == NPCResources.stock(bison.game))
    #expect(OriginalBisonActivation.matchesRequest(request, context: live))
  } else {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: id))
    #expect(source.permitsAmbientTrader(context: live, position: request.position))
    #expect(request.npc?.resources == NPCResources.stock(source.performance))
    #expect(OriginalFleetRuntimeHullSource.matchesAmbientTrader(request, context: live))
  }
  if let configuration = request.currentNewtKitConfiguration {
    let kit = try #require(CurrentNewtKitSource.current)
    #expect(configuration == kit.configuration && id == "SH029")
    #expect(kit.permitsBirth(request, context: live))
  }
  #expect(director.decisionCount == 2 && director.nextDecisionTime == 32.0028885295538)
  #expect(director.admittedCount == 0 && director.pendingRequests.contains(request))
}
