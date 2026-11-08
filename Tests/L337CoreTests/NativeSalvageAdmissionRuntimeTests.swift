import Foundation
import Testing

@testable import L337Core

private enum NativeSalvageReleaseProducer: Hashable, Sendable {
  case generated, emp
}

/// Shares genuine setup only; every scenario receives its own Game value.
private actor NativeSalvageReleaseSnapshot {
  static let shared = NativeSalvageReleaseSnapshot()
  private var setups: [NativeSalvageReleaseProducer: Task<Game, Error>] = [:]

  func game(producer: NativeSalvageReleaseProducer = .generated) async throws -> Game {
    let task: Task<Game, Error>
    if let setup = setups[producer] {
      task = setup
    } else {
      // Inherit the first caller's Testing context. Install before suspension so
      // concurrent callers share the same success or failure, with no retry/reset.
      let created = Task<Game, Error> {
        switch producer {
        case .generated: try await NativeSalvageAdmissionTestFixture.makeReleased()
        case .emp: try await NativeSalvageAdmissionTestFixture.makeEMPReleased()
        }
      }
      setups[producer] = created
      task = created
    }
    return try await task.value
  }
}

enum NativeSalvageAdmissionTestFixture {
  /// Original generated source, real Tab target and the actor's actual saved writer.
  /// The first release remains inside the original finite cutting-frame budget.
  static func released() async throws -> Game {
    try await NativeSalvageReleaseSnapshot.shared.game()
  }

  fileprivate static func makeReleased() async throws -> Game {
    let (game, site) = try NativePagedSalvageFixture.game()
    return try await release(game, wreck: site.identity)
  }

  static func empReleased() async throws -> Game {
    try await NativeSalvageReleaseSnapshot.shared.game(producer: .emp)
  }

  fileprivate static func makeEMPReleased() async throws -> Game {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    return try await release(game, wreck: source.identity)
  }

  private static func release(_ input: Game, wreck: WreckIdentity) async throws -> Game {
    var game = input
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == wreck })
    let metadata = try #require(body.physical?.salvage)
    let section = try #require(game.workSurface(for: body, metadata: metadata)?.section)
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: section)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game)
    let file = folder.appendingPathComponent("commander.json")
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var released = await runtime.snapshot()
    for _ in 0..<2000 {
      released = await NativePagedSalvageFixture.advanceHeldWork(runtime, delta: 0.02)
      if released.commander.alienStorageState?.current.salvage.native.works.values.contains(
        where: { $0.releases == 1 }) == true
      {
        break
      }
    }
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    try #require(native.native.works.values.contains { $0.releases == 1 })
    try #require(native.pending.values.contains { $0.binding != nil })
    let published = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(published.savedAlienStorageReference == released.commander.savedAlienStorageReference)
    let disk = try #require(published.alienStorageState?.current.salvage)
    #expect(Set(disk.pending.keys) == Set(native.pending.keys))
    for pending in native.pending.values {
      #expect(disk.pending[pending.lot.identity]?.lot.loot == pending.lot.loot)
      #expect(disk.pending[pending.lot.identity]?.lot.content == pending.lot.content)
    }
    // Existing nonthrowing assertions remain visible in the first caller's context.
    // Refuse a successful shared result if any publication comparison failed.
    guard published.savedAlienStorageReference == released.commander.savedAlienStorageReference,
      Set(disk.pending.keys) == Set(native.pending.keys),
      native.pending.values.allSatisfy({ pending in
        disk.pending[pending.lot.identity]?.lot.loot == pending.lot.loot
          && disk.pending[pending.lot.identity]?.lot.content == pending.lot.content
      }),
      released.pendingNewSaveDestination == nil, released.newCommanderSaveReceipt == nil
    else { throw SaveError.invalidCommander }
    return released
  }

  /// A controlled cold parking boundary retains the original physically observed lot.
  /// No pending record or successful admission is fabricated for the negative checks.
  static func parked(_ input: Game, insideParent: Bool = false)
    throws -> (Game, AlienNativeSalvageIndex.Pending)
  {
    var game = input
    let native = try #require(game.commander.alienStorageState?.current.salvage)
    let original = try #require(
      native.pending.values.filter { $0.binding != nil }.sorted {
        $0.lot.identity.lot < $1.lot.identity.lot
      }.first)
    let binding = try #require(original.binding)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == binding })
    if insideParent {
      let parent = try #require(
        game.bodies.first {
          $0.physical?.salvage?.wreck == original.lot.identity.section.wreck
            && $0.physical?.payload == nil
        })
      // Deliberately invalid physical placement is a negative geometry input.
      game.bodies[index].position = parent.position
    }
    let observed = game.observeNativeSalvageMotion(game.bodies[index])
    try #require(observed)
    let parked = game.flushNativeSalvageMotion(parking: [binding])
    try #require(parked)
    game.bodies.removeAll { $0.physical?.identity == binding }
    let pending = try #require(
      game.commander.alienStorageState?.current.salvage.pending[original.lot.identity])
    try #require(pending.offer == nil && pending.binding == nil)
    return (game, pending)
  }

  static func offered(_ input: Game, insideParent: Bool = false)
    throws -> (Game, AlienNativeSalvageIndex.Pending, SpawnRequest)
  {
    var (game, pending) = try parked(input, insideParent: insideParent)
    let context = try #require(game.gameplayContext())
    let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
      system: context.system, visit: context.visit)
    let spawn = try #require(allocated)
    let before = game.commander.salvageLedger
    let beforeWorld = try #require(game.commander.alienStorageState?.current.snapshot)
    let staged = game.stageNativeSalvageOffer(pending, spawn: spawn, context: context)
    try #require(staged)
    #expect(game.commander.salvageLedger == before)
    let afterWorld = try #require(game.commander.alienStorageState?.current.snapshot)
    #expect(
      afterWorld.sources == beforeWorld.sources && afterWorld.receipts == beforeWorld.receipts)
    #expect(
      afterWorld.attachments == beforeWorld.attachments
        && afterWorld.upgrades == beforeWorld.upgrades)
    #expect(
      afterWorld.commands == beforeWorld.commands && afterWorld.revision == beforeWorld.revision)
    #expect(
      afterWorld.world.filter { $0.id != pending.record }
        == beforeWorld.world.filter { $0.id != pending.record })
    return (game, pending, NativeSalvageOffer.request(lot: pending.lot, spawn: spawn))
  }

  static func changedRequest(
    _ original: SpawnRequest, identity: SpawnIdentity? = nil, position: Vector3? = nil,
    velocity: Vector3? = nil, orientation: Basis3? = nil, metadata: SalvageTargetMetadata? = nil,
    payload: PayloadIdentity? = nil
  ) -> SpawnRequest {
    var changed = SpawnRequest(
      identity: identity ?? original.identity, population: original.population, hull: original.hull,
      position: position ?? original.position, orientation: orientation ?? original.orientation,
      velocity: velocity ?? original.velocity, npc: original.npc, rock: original.rock,
      payload: payload ?? original.payload, priority: original.priority,
      salvage: metadata ?? original.salvage)
    changed.catalogueShipID = original.catalogueShipID
    changed.energy = original.energy
    changed.angularVelocity = original.angularVelocity
    return changed
  }

  static func changedContext(_ original: EncounterContext, mismatch: String) -> EncounterContext {
    var player = original.player
    if mismatch == "context player" {
      let identity = ActorIdentity(
        system: player.identity.system, visit: player.identity.visit,
        entity: player.identity.entity + 1)
      player = .init(
        identity: identity, hull: player.hull, position: player.position,
        orientation: player.orientation, velocity: player.velocity, energy: player.energy,
        maximumEnergy: player.maximumEnergy,
        maximumSpeedUnitsPerSecond: player.maximumSpeedUnitsPerSecond,
        legal: player.legal, npc: player.npc, rock: player.rock, payload: player.payload)
    }
    return .init(
      system: mismatch == "context system" ? .init(galaxy: 7, system: 255) : original.system,
      seed: original.seed, government: original.government,
      visit: original.visit + (mismatch == "context visit" ? 1 : 0),
      revision: original.revision + (mismatch == "context revision" ? 1 : 0),
      physicalTime: original.physicalTime + (mismatch == "context time" ? 0.01 : 0),
      anchors: original.anchors, player: player, actors: original.actors,
      protection: original.protection, budget: original.budget,
      perceptionRadius: original.perceptionRadius,
      depletedRocks: original.depletedRocks, miningPresence: original.miningPresence)
  }
}

struct NativeSalvageAdmissionRuntimeTests {
  @Test func genuineNativeReleaseAdmitsOnlyActualSafeActorsAndMovesThemInItsReleaseFrame()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    let bound = native.pending.values.filter { $0.binding != nil }
    #expect(!bound.isEmpty && bound.count <= native.pending.count)
    for pending in bound {
      let binding = try #require(pending.binding)
      let body = try #require(released.bodies.first { $0.physical?.identity == binding })
      let world = released.commander.flightSimulation.pose.systemPoint(body.position)
      #expect((world - pending.lot.position - pending.lot.velocity * 0.02).length < 1e-7)
      #expect(released.currentSalvageLot(for: body)?.identity == pending.lot.identity)
      #expect(pending.offer == nil)
    }
    #expect(released.commander.nativeSalvageSceneIsConsistent(released.bodies, docked: false))
    let (offered, pending, request) = try NativeSalvageAdmissionTestFixture.offered(released)
    var readmitted = offered
    let context = try #require(readmitted.gameplayContext())
    let parent = try #require(
      context.actors.first {
        $0.salvage?.wreck == pending.lot.identity.section.wreck && $0.payload == nil
      })
    let parentBounds = try #require(parent.salvage?.bounds)
    let parentRadius = parentBounds.radius + parentBounds.center.length
    #expect(
      (request.position - parent.position).length < parentRadius + pending.lot.halfExtents.length
        + 8)
    let clears = readmitted.releasedFragmentClearsParent(request, parent: parent, context: context)
    #expect(clears)
    let receipts = readmitted.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: false)], intents: []))
    #expect(receipts.count == 1 && receipts[0].refusal == nil && receipts[0].actor != nil)
    // This is only a private admission proposal. Production alone commits offer->binding
    // and publishes the candidate through the writer; the test grants no custody.
  }

  @Test func nativeOfferCannotBypassExactParentProtectionMeshPlayerOrOtherActorChecks()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    for mismatch in [
      "unoffered", "unoffered allocated", "changed position", "changed bounds", "protected parent",
      "wrong wreck",
      "stale parent", "foreign parent", "unbound parent", "unrelated obstacle", "cargo sibling",
      "inside mesh",
      "player",
    ] {
      var (game, pending, request) = try NativeSalvageAdmissionTestFixture.offered(
        released, insideParent: mismatch == "inside mesh")
      let index = try #require(
        game.bodies.firstIndex {
          $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
            && $0.physical?.payload == nil
        })
      switch mismatch {
      case "unoffered":
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          identity: .init(
            system: request.identity.system, visit: request.identity.visit,
            sequence: UInt64.max - 1, member: 0, producer: .salvage))
      case "unoffered allocated":
        let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
          system: request.identity.system, visit: request.identity.visit)
        let identity = try #require(allocated)
        request = NativeSalvageAdmissionTestFixture.changedRequest(request, identity: identity)
      case "changed position":
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request, position: request.position + .init(0.01, 0, 0))
      case "changed bounds":
        let metadata = try #require(request.salvage)
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          metadata: .init(
            category: metadata.category, ownership: metadata.ownership, claimant: nil,
            wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
            bounds: .init(center: .init(0, 0, 0), radius: 0.1), workSurfaces: []))
      case "protected parent": game.bodies[index].navalTarget = true
      case "wrong wreck":
        let metadata = try #require(game.bodies[index].physical?.salvage)
        let system = game.systemIdentity
        game.bodies[index].physical?.salvage = .init(
          category: metadata.category, ownership: metadata.ownership, claimant: nil,
          wreck: .init(system: system, site: 89, lineage: 99), section: nil,
          lot: nil, bounds: metadata.bounds, workSurfaces: metadata.workSurfaces)
      case "stale parent", "foreign parent", "unbound parent":
        let physical = try #require(game.bodies[index].physical)
        let system =
          mismatch == "foreign parent"
          ? SystemIdentity(galaxy: 7, system: 255) : physical.identity.system
        let identity: ActorIdentity
        if mismatch == "unbound parent" {
          let allocated = game.commander.flightSimulation.allocateActor()
          identity = try #require(allocated)
        } else {
          identity = .init(
            system: system, visit: physical.identity.visit + (mismatch == "stale parent" ? 1 : 0),
            entity: physical.identity.entity)
        }
        game.bodies[index].physical = .init(
          identity: identity, population: physical.population, npc: physical.npc,
          velocity: physical.velocity, laserCooldown: physical.laserCooldown,
          rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
          emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
          deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
          spawnIdentity: physical.spawnIdentity,
          blocksNavalEncounter: physical.blocksNavalEncounter,
          catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
          empSource: physical.empSource, empCrewPod: physical.empCrewPod,
          suspendedNPCIntention: physical.suspendedNPCIntention)
      case "unrelated obstacle":
        try addBlocker(&game, at: request.position)
      case "cargo sibling":
        try addBlocker(&game, at: request.position, metadata: request.salvage)
      case "player":
        var pose = game.commander.flightSimulation.pose
        pose.position = request.position
        NativePagedSalvageFixture.moveObserver(&game, to: pose)
      default: break
      }
      let context = try #require(game.gameplayContext())
      let before = game.commander
      let bodies = game.bodies
      let receipts = game.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: [request], atomic: false)], intents: []))
      #expect(
        receipts.count == 1 && receipts[0].refusal == .unsafePosition && receipts[0].actor == nil)
      #expect(game.commander == before && game.bodies == bodies)
      #expect(
        game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity]?.lot
          == pending.lot)
    }
  }

  @Test func refusedNativePlacementDiscardsPrivateOfferAndPreservesEveryReleasedLot()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    var (game, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    var pose = game.commander.flightSimulation.pose
    pose.position = pending.lot.position
    NativePagedSalvageFixture.moveObserver(&game, to: pose)
    let before = game.commander
    let bodies = game.bodies
    game.admitPendingNativeSalvage()
    #expect(game.commander == before && game.bodies == bodies)
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity])
    #expect(retained.lot == pending.lot && retained.binding == nil && retained.offer == nil)
    let fresh = try await NativeSalvageAdmissionTestFixture.empReleased()
    #expect(fresh.commander == released.commander && fresh.bodies == released.bodies)
  }

  @Test func fullActualCargoPopulationLeavesOriginalNativeCustodyAndAllocatorUntouched()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    var (game, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    let initial = try #require(game.gameplayContext())
    let planet = (initial.player.position - initial.anchors.planet.position).unit
    let sun = (initial.player.position - initial.anchors.sun.position).unit
    var outward = (planet + sun).unit
    if outward.length == 0 {
      let axis = abs(planet.y) < 0.8 ? Vector3(0, 1, 0) : Vector3(1, 0, 0)
      outward = planet.cross(axis).unit
    }
    for index in 0..<PopulationClass.cargo.maximum {
      let context = try #require(game.gameplayContext())
      if context.budget.active[.cargo, default: 0] == PopulationClass.cargo.maximum { break }
      let request = SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit, sequence: UInt64(91000 + index), member: 0,
          producer: .provider),
        population: .cargo, hull: .cargo,
        position: initial.player.position + outward * Double(8000 + index * 500),
        orientation: .init(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
        priority: .ordinary)
      let receipts = game.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: [request], atomic: false)], intents: []))
      try #require(receipts.count == 1 && receipts[0].refusal == nil && receipts[0].actor != nil)
    }
    let full = try #require(game.gameplayContext())
    try #require(full.budget.active[.cargo, default: 0] == PopulationClass.cargo.maximum)
    let before = game.commander
    let bodies = game.bodies
    game.admitPendingNativeSalvage()
    #expect(game.commander == before && game.bodies == bodies)
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity])
    #expect(retained.lot == pending.lot && retained.offer == nil && retained.binding == nil)
    // A staged offer still cannot bypass the actual common population gate.
    let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
      system: full.system, visit: full.visit)
    let spawn = try #require(allocated)
    let staged = game.stageNativeSalvageOffer(retained, spawn: spawn, context: full)
    try #require(staged)
    let offered = game.commander
    let receipts = game.admitEncounterPlan(
      .init(
        system: full.system, visit: full.visit, revision: full.revision,
        batches: [
          .init(
            requests: [NativeSalvageOffer.request(lot: retained.lot, spawn: spawn)], atomic: false)
        ],
        intents: []))
    #expect(
      receipts.count == 1 && receipts[0].refusal == .populationLimit && receipts[0].actor == nil)
    #expect(game.commander == offered && game.bodies == bodies)
  }

  @Test func nativeSectionNeverFallsBackToAnOriginalOrdinaryOffer() async throws {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    var game = released
    let current = try #require(game.commander.alienStorageState?.current.salvage)
    let pending = try #require(current.pending.values.first { $0.binding != nil })
    let inspection = try #require(
      current.native.plans.values.first {
        $0.plan.section == pending.lot.identity.section
      })
    let section = try #require(current.native.sectionProfiles[inspection.id])
    let parentBody = try #require(
      game.bodies.first {
        $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
          && $0.physical?.payload == nil
      })
    let physical = try #require(parentBody.physical)
    var old = SalvageLedger(seed: inspection.seed)
    var remaining = section.workSeconds
    var operation: UInt64 = 0
    while remaining > 0 {
      let elapsed = min(1, remaining)
      operation += 1
      let produced = old.advance(
        wreck: inspection.plan.section.wreck, section: section,
        pose: game.modelPose(of: parentBody),
        velocity: physical.velocity, angularVelocity: physical.angularVelocity, tool: .cutter,
        elapsed: elapsed, operation: operation, conditions: NativePagedSalvageFixture.permitted,
        source: inspection.plan.source)
      remaining -= elapsed
      if remaining == 0 {
        guard case .released = produced else { throw SaveError.invalidCommander }
      } else {
        guard case .progress = produced else { throw SaveError.invalidCommander }
      }
    }
    let context = try #require(game.gameplayContext())
    let requests = old.spawnRequests(context: context)
    let request = try #require(requests.first { $0.payload == .salvage(pending.lot.identity) })
    try #require(old.offeredLot(for: request.identity) != nil)
    // This deliberately stale composite is a negative input: an old original
    // producer cannot reclaim a section that current native custody already owns.
    game.commander.salvageLedger = old
    let parent = try #require(context.actors.first { $0.identity == physical.identity })
    let before = game.commander
    let bodies = game.bodies
    let clears = game.releasedFragmentClearsParent(request, parent: parent, context: context)
    #expect(!clears)
    #expect(game.commander == before && game.bodies == bodies)
  }

  private func addBlocker(
    _ game: inout Game, at position: Vector3, metadata: SalvageTargetMetadata? = nil
  ) throws {
    let context = try #require(game.gameplayContext())
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: 90001, member: 0,
        producer: .provider),
      population: .cargo, hull: .cargo, position: position + .init(2000, 2000, 2000),
      orientation: .init(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
      priority: .ordinary, salvage: metadata)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: false)], intents: []))
    let actor = try #require(receipts.first?.actor)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    // A genuinely allocated unrelated actor is moved into the way only as a
    // negative collision input. It is never used to establish successful release.
    game.bodies[index].position = game.commander.flightSimulation.pose.shipPoint(position)
  }
}

extension GameRuntime {
  /// Exercise the actual admission path without injecting custody, actors or geometry.
  fileprivate func attemptPendingSalvageForGeometryCacheTest() -> Game {
    game.admitPendingNativeSalvage()
    return game
  }
}

extension NativeSalvageAdmissionRuntimeTests {
  @Test func actualEMPReleaseKeepsCurrentCustodyAcrossNoWriteReloadAndReadmission() async throws {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    let original = try #require(released.commander.alienStorageState?.current.salvage)
    let pending = try #require(original.pending.values.first { $0.binding != nil })
    let parent = try #require(
      released.bodies.first {
        $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
          && $0.physical?.payload == nil
      })
    let source = try #require(parent.physical?.empSource)
    let record = try #require(released.commander.savedEMPState?.records[source])
    let wreck = try #require(original.native.wrecks[record.wreck])
    #expect(wreck.source == .emp(actor: source, sequence: record.sequence))
    #expect(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    #expect(released.salvageSites.isEmpty)
    let inspection = try #require(original.native.inspections[pending.lot.identity.section])
    let cycle = try #require(original.native.works[inspection.id])
    #expect(cycle.inspection == .fresh(inspection.id) && cycle.releases == 1)

    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: released)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let persisted = try #require(saved.commander.alienStorageState?.current.salvage)
    let files = try currentFiles(in: folder)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(loaded.nativeSalvageWork == nil)
    #expect(try currentFiles(in: folder) == files)
    let restored = try #require(loaded.commander.alienStorageState?.current.salvage)
    #expect(Set(restored.pending.keys) == Set(original.pending.keys))
    for old in persisted.pending.values {
      #expect(restored.pending[old.lot.identity]?.lot == old.lot)
      #expect(restored.pending[old.lot.identity]?.binding == old.binding)
    }
    for old in original.pending.values {
      #expect(restored.pending[old.lot.identity]?.record == old.record)
      #expect(restored.pending[old.lot.identity]?.lot.loot == old.lot.loot)
      #expect(restored.pending[old.lot.identity]?.lot.content == old.lot.content)
    }

    let (parked, parkedLot) = try NativeSalvageAdmissionTestFixture.parked(loaded)
    let oldBinding = try #require(restored.pending[parkedLot.lot.identity]?.binding)
    // Mutate only negative inputs to this actual current EMP release. Exercise
    // the production pending-lot path, not just a separately staged offer.
    for mismatch in ["wrong source", "protected parent", "player blocked", "retained mismatch"] {
      var refused = parked
      let index = try #require(
        refused.bodies.firstIndex { $0.physical?.identity == parent.physical?.identity })
      let retainedParent = try #require(
        refused.commander.alienStorageState?.current.salvage.native.wrecks[
          parkedLot.lot.identity.section.wreck])
      let physical = try #require(refused.bodies[index].physical)
      try #require(retainedParent.binding == physical.identity)
      switch mismatch {
      case "wrong source": refused.bodies[index].physical?.catalogueShipID = "SH001"
      case "protected parent":
        refused.bodies[index].navalTarget = true
        let context = try #require(refused.gameplayContext())
        try #require(context.protection.protectedActors.contains(physical.identity))
        let bounds = try #require(physical.salvage?.bounds)
        try #require(
          (parkedLot.lot.position - refused.modelPose(of: refused.bodies[index]).position).length
            < bounds.radius + bounds.center.length + parkedLot.lot.halfExtents.length + 8)
      case "player blocked":
        var pose = refused.commander.flightSimulation.pose
        pose.position = parkedLot.lot.position
        NativePagedSalvageFixture.moveObserver(&refused, to: pose)
        let radius = try #require(refused.commander.playerMesh.vertices.map(\.length).max())
        try #require(
          (parkedLot.lot.position - refused.commander.flightSimulation.pose.position).length
            <= radius + parkedLot.lot.halfExtents.length + 8)
      default:
        let allocated = refused.commander.flightSimulation.allocateActor()
        let actor = try #require(allocated)
        try #require(actor != retainedParent.binding)
        // Preserve every physical field except the deliberately wrong actor.
        // The existing retained wreck is never rebound to this negative input.
        refused.bodies[index].physical = .init(
          identity: actor, population: physical.population, npc: physical.npc,
          velocity: physical.velocity, laserCooldown: physical.laserCooldown,
          rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
          emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
          deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
          spawnIdentity: physical.spawnIdentity,
          blocksNavalEncounter: physical.blocksNavalEncounter,
          catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
          empSource: physical.empSource, empCrewPod: physical.empCrewPod,
          currentNewtKitStock: physical.currentNewtKitStock,
          currentNewtKitReceipt: physical.currentNewtKitReceipt,
          suspendedNPCIntention: physical.suspendedNPCIntention)
      }
      let beforeAttempt = refused
      let beforeRefusal = refused.commander
      let beforeBodies = refused.bodies
      refused.admitPendingNativeSalvage()
      #expect(refused.commander == beforeRefusal && refused.bodies == beforeBodies)
      try expectCurrentAdmissionRefusalPreservesState(refused, before: beforeAttempt)
      let denied = try #require(
        refused.commander.alienStorageState?.current.salvage.pending[parkedLot.lot.identity])
      #expect(denied.lot == parkedLot.lot && denied.binding == nil && denied.offer == nil)
      #expect(!refused.bodies.contains { $0.physical?.payload == .salvage(parkedLot.lot.identity) })
      #expect(try currentFiles(in: folder) == files)
    }

    let readmission = GameRuntime(game: parked)
    try await readmission.save(to: file)
    // The existing one-frame readmission is a bounded first-binding transition.
    // Its oracle uses the real unbound lot and parent BEFORE that frame, rather
    // than the already advanced parent or a moved/synthetic successful fragment.
    let preFrame = await readmission.snapshot()
    let preFrameCustody = try #require(preFrame.commander.alienStorageState?.current.salvage)
    let unbound = try #require(preFrameCustody.pending[parkedLot.lot.identity])
    try #require(unbound.lot == parkedLot.lot && unbound.binding == nil && unbound.offer == nil)
    let admissionParent = try #require(
      preFrame.bodies.first { $0.physical?.identity == parent.physical?.identity })
    let admissionPhysical = try #require(admissionParent.physical)
    let metadata = try #require(admissionPhysical.salvage)
    let catalogue = try #require(admissionPhysical.catalogueShipID)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: catalogue))
    let hull = try PreparedHull(mesh: profile.mesh)
    let admissionPose = preFrame.modelPose(of: admissionParent)
    let broadOverlap = (unbound.lot.position - admissionPose.position).length
      < metadata.bounds.radius + metadata.bounds.center.length + unbound.lot.halfExtents.length + 8
    let clearance = HullSweepSafety.validatePlacement(
      center: unbound.lot.position, radius: unbound.lot.halfExtents.length,
      hull: hull, pose: admissionPose, requiredClearance: 8)
    try #require(broadOverlap && clearance.safe && (clearance.minimumSampledClearance ?? -.infinity) > 8)
    let admitted = await readmission.advance(delta: 0.02)
    let current = try #require(admitted.commander.alienStorageState?.current.salvage)
    let rebound = try #require(current.pending[parkedLot.lot.identity])
    let binding = try #require(rebound.binding)
    let body = try #require(admitted.bodies.first { $0.physical?.identity == binding })
    let firstBindings = current.pending.values.filter {
      preFrameCustody.pending[$0.lot.identity]?.binding == nil && $0.binding != nil
    }
    #expect(firstBindings.contains { $0.lot.identity == unbound.lot.identity })
    #expect(
      abs(admitted.commander.flightSimulation.physicalTime
        - preFrame.commander.flightSimulation.physicalTime - 0.02) < 1e-7)
    let advancedParent = try #require(
      admitted.bodies.first { $0.physical?.identity == admissionPhysical.identity })
    #expect(
      (admitted.modelPose(of: advancedParent).position - admissionPose.position
        - admissionPhysical.velocity * 0.02).length < 1e-7)
    #expect(broadOverlap && clearance.safe && (clearance.minimumSampledClearance ?? -.infinity) > 8)
    #expect(binding != oldBinding && rebound.offer == nil)
    #expect(rebound.lot.identity == parkedLot.lot.identity)
    #expect(rebound.lot.loot == parkedLot.lot.loot && rebound.lot.content == parkedLot.lot.content)
    let age = admitted.commander.flightSimulation.physicalTime - rebound.physicalTime
    let world = admitted.commander.flightSimulation.pose.systemPoint(body.position)
    #expect((world - rebound.lot.position - rebound.lot.velocity * age).length < 1e-7)
    #expect(admitted.currentSalvageLot(for: body)?.identity == parkedLot.lot.identity)
    #expect(
      admitted.bodies.filter { $0.physical?.payload == .salvage(parkedLot.lot.identity) }.count
        == 1)
    #expect(Set(current.pending.keys) == Set(original.pending.keys))
    #expect(admitted.commander.cargo == loaded.commander.cargo)
    try expectEMPInventoryProperty(
      #require(loaded.commander.equipmentInventory),
      #require(admitted.commander.equipmentInventory))
    #expect(admitted.commander.credits == loaded.commander.credits)
    #expect(admitted.commander.nativeSalvageSceneIsConsistent(admitted.bodies, docked: false))
  }

  @Test func actualEMPUnsafeAdmissionKeepsOnlyLocalGeometryAcrossRealParentMotion() async throws {
    var released = try await NativeSalvageAdmissionTestFixture.empReleased()
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    let selected = try #require(
      native.pending.values.filter { $0.binding != nil }.sorted {
        $0.lot.identity.lot < $1.lot.identity.lot
      }.first)
    let binding = try #require(selected.binding)
    let fragment = try #require(released.bodies.firstIndex { $0.physical?.identity == binding })
    let parent = try #require(
      released.bodies.first {
        $0.physical?.salvage?.wreck == selected.lot.identity.section.wreck
          && $0.physical?.payload == nil
      })
    let catalogue = try #require(parent.physical?.catalogueShipID)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: catalogue))
    let section = try #require(
      profile.sections.first { $0.index == selected.lot.identity.section.section })
    // Put an already released fragment on its actual source face only as a negative
    // collision input. The positive release and custody came from real cutter work.
    let surface = released.modelPose(of: parent).systemPoint(section.localPosition)
    released.bodies[fragment].position = released.commander.flightSimulation.pose.shipPoint(surface)
    let (parked, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: parked)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let files = try currentFiles(in: folder)
    try await runtime.load(from: file, persistMigrations: false)
    let original = await runtime.snapshot()
    #expect(original.commander == saved.commander && original.bodies == saved.bodies)
    try #require(original.salvageAdmissionGeometry[catalogue] == nil)
    #expect(try currentFiles(in: folder) == files)
    let first = await runtime.attemptPendingSalvageForGeometryCacheTest()
    let cached = try #require(first.salvageAdmissionGeometry[catalogue])
    #expect(
      cached.mesh.vertices == profile.mesh.vertices && cached.mesh.faces == profile.mesh.faces)
    #expect(first.salvageAdmissionGeometry.count <= 128)
    #expect(first.commander == original.commander && first.bodies == original.bodies)
    try expectCurrentAdmissionRefusalPreservesState(first, before: original)
    #expect(first.nextBodyID == original.nextBodyID)
    #expect(first.gameplayRevision == original.gameplayRevision)
    let initialPose = original.modelPose(of: parent)
    let initialProof = HullSweepSafety.validatePlacement(
      center: pending.lot.position, radius: pending.lot.halfExtents.length, hull: cached.hull,
      pose: initialPose, requiredClearance: 8)
    try #require(!initialProof.safe)
    let repeated = await runtime.attemptPendingSalvageForGeometryCacheTest()
    let retained = try #require(repeated.salvageAdmissionGeometry[catalogue])
    #expect(
      retained.mesh.vertices == cached.mesh.vertices && retained.mesh.faces == cached.mesh.faces)
    #expect(retained.hull.triangleCount == cached.hull.triangleCount)
    #expect(repeated.commander == original.commander && repeated.bodies == original.bodies)
    try expectCurrentAdmissionRefusalPreservesState(repeated, before: original)
    #expect(repeated.nextBodyID == original.nextBodyID)
    #expect(try currentFiles(in: folder) == files)
    let moved = await runtime.advance(delta: 0.02)
    // The actual frame may publish electrical receipts; direct admission attempts
    // must preserve whichever complete current generation that frame produced.
    let motionFiles = try currentFiles(in: folder)
    let movingParent = try #require(moved.bodies.first { $0.id == parent.id })
    let movingPose = moved.modelPose(of: movingParent)
    try #require(movingPose != initialPose)
    let movingProof = HullSweepSafety.validatePlacement(
      center: pending.lot.position, radius: pending.lot.halfExtents.length, hull: retained.hull,
      pose: movingPose, requiredClearance: 8)
    try #require(!movingProof.safe)
    #expect(movingProof.minimumSampledClearance != initialProof.minimumSampledClearance)
    let afterMotion = await runtime.attemptPendingSalvageForGeometryCacheTest()
    let movingCache = try #require(afterMotion.salvageAdmissionGeometry[catalogue])
    #expect(
      movingCache.mesh.vertices == profile.mesh.vertices
        && movingCache.mesh.faces == profile.mesh.faces)
    #expect(afterMotion.salvageAdmissionGeometry.count <= 128)
    #expect(afterMotion.commander == moved.commander && afterMotion.bodies == moved.bodies)
    try expectCurrentAdmissionRefusalPreservesState(afterMotion, before: moved)
    #expect(afterMotion.nextBodyID == moved.nextBodyID)
    #expect(try currentFiles(in: folder) == motionFiles)
  }

  @Test func actualEMPParentDeathPreservesReleasedCurrentCustodyAndReadmitsItsFragments()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.empReleased()
    var (game, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    let parent = try #require(
      game.bodies.first {
        $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
          && $0.physical?.payload == nil
      })
    let before = try #require(game.commander.alienStorageState?.current.salvage)
    let observedCycle = game.nativeSalvageWork?.cycle
    let player = try #require(game.commander.flightSimulation.player)
    let allocated = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocated)
    // Controlled lethal damage tests the native death boundary, not weapon cadence or cost.
    let applied = game.applyCombatHit(
      .init(target: .body(parent.id), distance: parent.position.length, point: parent.position),
      origin: origin, kind: .laser, damage: parent.energy + 1, laser: .pulse)
    try #require(applied != nil)
    game.commander.crimeLedger.finishEmission(origin.emissionID)
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.id == parent.id })
    let dead = try #require(game.commander.alienStorageState?.current.salvage)
    #expect(dead.native.wrecks[pending.lot.identity.section.wreck]?.destroyedAt != nil)
    let originalWreck = try #require(before.native.wrecks[pending.lot.identity.section.wreck])
    let deadWreck = try #require(dead.native.wrecks[pending.lot.identity.section.wreck])
    #expect(deadWreck.id == originalWreck.id && deadWreck.source == originalWreck.source)
    #expect(deadWreck.owner == originalWreck.owner && deadWreck.seed == originalWreck.seed)
    #expect(deadWreck.bornAt == originalWreck.bornAt && deadWreck.binding == nil)
    #expect(Set(dead.native.wrecks.keys) == Set(before.native.wrecks.keys))
    #expect(Set(dead.native.inspections.keys) == Set(before.native.inspections.keys))
    #expect(Set(dead.native.works.keys) == Set(before.native.works.keys))
    for (inspectionID, old) in before.native.works {
      // Death may flush the already observed hot cycle before sealing it.
      let expected: NativeSalvageWorkCycle
      if let observedCycle, observedCycle.id == old.id { expected = observedCycle }
      else { expected = old }
      let retained = try #require(dead.native.works[inspectionID])
      #expect(retained.inspection == expected.inspection && retained.beganAt == expected.beganAt)
      #expect(retained.releases == expected.releases && retained.lastRelease == expected.lastRelease)
      #expect(retained.lastOperation == expected.lastOperation && retained.destroyedAt != nil)
    }
    #expect(Set(dead.pending.keys) == Set(before.pending.keys))
    for old in before.pending.values { #expect(dead.pending[old.lot.identity]?.lot == old.lot) }
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let files = try currentFiles(in: folder)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(try currentFiles(in: folder) == files)
    let admitted = await runtime.advance(delta: 0.02)
    let current = try #require(admitted.commander.alienStorageState?.current.salvage)
    let rebound = try #require(current.pending[pending.lot.identity]?.binding)
    let body = try #require(admitted.bodies.first { $0.physical?.identity == rebound })
    #expect(admitted.currentSalvageLot(for: body)?.identity == pending.lot.identity)
    #expect(Set(current.pending.keys) == Set(before.pending.keys))
    for old in before.pending.values {
      #expect(current.pending[old.lot.identity]?.record == old.record)
      #expect(current.pending[old.lot.identity]?.lot.loot == old.lot.loot)
      #expect(current.pending[old.lot.identity]?.lot.content == old.lot.content)
    }
    #expect(!admitted.bodies.contains { $0.id == parent.id })
    #expect(current.native.wrecks[pending.lot.identity.section.wreck] == deadWreck)
    #expect(Set(current.native.wrecks.keys) == Set(dead.native.wrecks.keys))
    #expect(current.native.inspections == dead.native.inspections)
    #expect(current.native.works == dead.native.works && admitted.nativeSalvageWork == nil)
    #expect(admitted.commander.credits == loaded.commander.credits)
    #expect(admitted.commander.cargo == loaded.commander.cargo)
    try expectEMPInventoryProperty(
      #require(loaded.commander.equipmentInventory),
      #require(admitted.commander.equipmentInventory))
    #expect(admitted.commander.nativeSalvageSceneIsConsistent(admitted.bodies, docked: false))
  }

  /// Direct refusal may warm immutable local geometry, but it cannot commit any
  /// allocator, pending record, property or world change, even for invalid input.
  private func expectCurrentAdmissionRefusalPreservesState(
    _ after: borrowing Game, before: borrowing Game
  ) throws {
    let statePreserved = after.commander == before.commander && after.bodies == before.bodies
    #expect(statePreserved)
    let allocatorPreserved = after.nextBodyID == before.nextBodyID
      && after.gameplayRevision == before.gameplayRevision
      && after.commander.salvageLedger == before.commander.salvageLedger
    #expect(allocatorPreserved)
    let physicalStatePreserved = after.commander.flightSimulation == before.commander.flightSimulation
      && after.commander.savedEMPState == before.commander.savedEMPState
    #expect(physicalStatePreserved)
    let propertyPreserved = after.commander.credits == before.commander.credits
      && after.commander.cargo == before.commander.cargo
      && after.commander.equipmentInventory == before.commander.equipmentInventory
    #expect(propertyPreserved)
    let flightPreserved = after.docked == before.docked && after.paused == before.paused
      && after.screen == before.screen && after.systemIdentity == before.systemIdentity
      && after.jumpCountdown == before.jumpCountdown
    #expect(flightPreserved)
    let workPreserved = after.nativeSalvageWork?.cycle == before.nativeSalvageWork?.cycle
      && after.nativeSalvageWork?.actor == before.nativeSalvageWork?.actor
      && after.nativeSalvageWork?.plan == before.nativeSalvageWork?.plan
    #expect(workPreserved)
    let guidancePreserved = after.workGuidance?.parent == before.workGuidance?.parent
      && after.workGuidance?.velocity == before.workGuidance?.velocity
      && after.workGuidance?.angularVelocity == before.workGuidance?.angularVelocity
      && after.workBraking?.velocity == before.workBraking?.velocity
      && after.workBraking?.angularVelocity == before.workBraking?.angularVelocity
    #expect(guidancePreserved)
    let original = try #require(before.commander.alienStorageState?.current)
    let retained = try #require(after.commander.alienStorageState?.current)
    #expect(retained.snapshot == original.snapshot)
    #expect(Set(retained.salvage.pending.keys) == Set(original.salvage.pending.keys))
    for old in original.salvage.pending.values {
      let current = try #require(retained.salvage.pending[old.lot.identity])
      #expect(current.record == old.record && current.lot == old.lot)
      #expect(current.physicalTime == old.physicalTime)
      #expect(current.offer == old.offer && current.binding == old.binding)
    }
    // A deliberately mismatched parent can make the input scene invalid. Refusal
    // must preserve that truth, not silently repair or bless the scene.
    let sceneTruthPreserved =
      after.commander.nativeSalvageSceneIsConsistent(after.bodies, docked: false)
        == before.commander.nativeSalvageSceneIsConsistent(before.bodies, docked: false)
    #expect(sceneTruthPreserved)
  }

  private func currentFiles(in folder: URL) throws -> [String: Data] {
    var files: [String: Data] = [:]
    let enumerator = try #require(
      FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator {
      if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        files[String(url.path.dropFirst(folder.path.count + 1))] = try Data(contentsOf: url)
      }
    }
    return files
  }
}
