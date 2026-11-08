import Foundation

extension Commander {
  var ordinaryCommodityAmounts: [CommodityAmount] {
    var amounts: [CommodityAmount] = []
    for commodity in CommodityIdentity.allCases {
      let reserved =
        commodity == .firearms ? markedFirearms : commodity == .slaves ? nativeCaptiveCount : 0
      let quantity = max(0, cargo[commodity.rawValue] - reserved)
      if quantity > 0 { amounts.append(.init(commodity: commodity, quantity: quantity)) }
    }
    return amounts
  }
}

extension SpaceBody {
  @inline(never)
  func nativeLaunchHasSpawn() -> Bool {
    withUnsafePointer(to: physical) { stored in stored.pointee?.spawnIdentity != nil }
  }

  @inline(never)
  func nativeLaunchHasRock() -> Bool {
    withUnsafePointer(to: physical) { stored in stored.pointee?.rock != nil }
  }

  @inline(never)
  func nativeLaunchHasPayload() -> Bool {
    withUnsafePointer(to: physical) { stored in stored.pointee?.payload != nil }
  }

  @inline(never)
  func nativeLaunchHasOrdnance() -> Bool {
    withUnsafePointer(to: physical) { stored in stored.pointee?.ordnance != nil }
  }

  @inline(never)
  func nativeLaunchHasSalvage() -> Bool {
    withUnsafePointer(to: physical) { stored in stored.pointee?.salvage != nil }
  }

  @inline(never)
  func nativeLaunchNPC() -> NPCState? {
    withUnsafePointer(to: physical) { stored in stored.pointee?.npc }
  }

  @inline(never)
  func nativeLaunchPopulation() -> PopulationClass? {
    withUnsafePointer(to: physical) { stored in stored.pointee?.population }
  }

  @inline(never)
  func nativeLaunchLaserCooldown() -> Double? {
    withUnsafePointer(to: physical) { stored in stored.pointee?.laserCooldown }
  }

  @inline(never)
  func nativeLaunchBlocksNavalEncounter() -> Bool? {
    withUnsafePointer(to: physical) { stored in stored.pointee?.blocksNavalEncounter }
  }

  @inline(never)
  func nativeLaunchSuspendedIntention() -> NPCAction? {
    withUnsafePointer(to: physical) { stored in stored.pointee?.suspendedNPCIntention }
  }

}

extension Game {
  var systemIdentity: SystemIdentity {
    storedSystemIdentity()
  }

  var gameplaySeed: UInt64 {
    UInt64(currentSystem.seed.a) << 32 | UInt64(currentSystem.seed.b) << 16
      | UInt64(currentSystem.seed.c)
  }

  @discardableResult
  @inline(never)
  mutating func beginGameplayVisit(arriving: Bool, freshLaunchTrafficID: Int? = nil) -> Bool {
    guard prepareGameplayVisit(arriving: arriving) else { return false }
    ensurePhysicalActors(freshLaunchTrafficID: freshLaunchTrafficID)
    return finishGameplayVisit()
  }

  @inline(never)
  private mutating func prepareGameplayVisit(arriving: Bool) -> Bool {
    do { try migrateMiningPresence(legacyMissing: false) } catch { return false }
    commander.savedEMPCharge = nil
    if var state = commander.savedEMPState {
      for source in state.records.keys {
        state.records[source]?.hull.binding = nil
        for i in state.records[source]!.pods.indices {
          state.records[source]?.pods[i].binding = nil
        }
      }
      commander.savedEMPState = state
    }
    invalidateNativeStationAuthority()
    activeECMActivation = nil
    let oldPlayer = storedFlightSimulation().player
    commander.flightSimulation.enter(systemIdentity, arriving: arriving)
    if let oldPlayer, let player = storedFlightSimulation().player {
      commander.stationSecurity.rebindPlayer(from: oldPlayer, to: player)
    }
    let flight = storedFlightSimulation()
    commander.crimeLedger.beginVisit(system: systemIdentity, visit: flight.visit)
    if let anchors = flight.anchors {
      celestials = [
        .init(
          kind: .planet, position: flight.pose.shipPoint(anchors.planet.position),
          radius: anchors.planet.radius),
        .init(
          kind: .sun, position: flight.pose.shipPoint(anchors.sun.position),
          radius: anchors.sun.radius),
      ]
      rebuildMiningFields()
      rebuildSalvageSites()
    }
    commander.miningLedger.resetPhysicalBindings(system: systemIdentity)
    commander.cargoDebrisLedger.resetPhysicalBindings(system: systemIdentity)
    commander.salvageLedger.resetPhysicalBindings(system: systemIdentity)
    commander.npcPersistence.resetPhysicalBindings(system: systemIdentity)
    commander.resetWantedCareerBindings(system: systemIdentity)
    gameplayRevision &+= 1
    return true
  }

  @inline(never)
  private mutating func finishGameplayVisit() -> Bool {
    _ = persistNPCStates()
    do { try prepareNativeCrimboVisit() } catch { return false }
    if commander.npcPersistence.restoreWantedCareers(
      commander.wantedCareers, system: systemIdentity)
    {
      advanceUnboundNPCs()
    }
    admitPersistentNPCs()
    _ = persistNPCStates()
    if let context = gameplayContext() {
      commander.encounterDirector = EncounterDirector(context: context)
    }
    return true
  }

  /// Called only for the actual new launch or hyperspace-arrival body before first capture.
  @inline(never)
  private mutating func initializeNativeLaunchDisposition(bodyID: Int) {
    let flight = storedFlightSimulation()
    guard let opening = nativeLaunchDispositionOpening(bodyID: bodyID, flight: flight) else { return }
    guard let plan = resolveNativeLaunchDisposition(opening, flight: flight) else {
      bodies.remove(at: opening.index)
      return
    }
    retainNativeLaunchDisposition(plan)
  }

  private final class NativeLaunchOpening {
    let index: Int
    let actor: ActorIdentity
    let npc: NPCState
    init(index: Int, actor: ActorIdentity, npc: NPCState) {
      self.index = index; self.actor = actor; self.npc = npc
    }
  }

  @inline(never)
  private func nativeLaunchDispositionOpening(bodyID: Int, flight: FlightSimulationState) -> NativeLaunchOpening? {
    bodies.withUnsafeBufferPointer { stored in
      for index in stored.indices {
        let body = stored.baseAddress!.advanced(by: index)
        if body.pointer(to: \.id)!.pointee == bodyID {
          return nativeLaunchEligibleOpening(body.pointee, index: index, visit: flight.visit)
        }
      }
      return nil
    }
  }

  @inline(never)
  private func nativeLaunchEligibleOpening(
    _ body: borrowing SpaceBody, index: Int, visit: UInt64
  ) -> NativeLaunchOpening? {
    guard body.hull == .sidewinder, !body.navalTarget,
      body.missionInstanceID == nil, body.blackjackRole == nil,
      body.blackjackIdentity == nil, body.nativeGeometryHasPhysical(),
      !body.nativeLaunchHasSpawn(), body.nativeGeometryCatalogueID() == nil,
      body.nativeGeometryEMPSource() == nil, body.nativeGeometryCrew() == nil,
      !body.nativeLaunchHasRock(), !body.nativeLaunchHasPayload(),
      !body.nativeLaunchHasOrdnance(), !body.nativeLaunchHasSalvage(),
      body.nativeGeometryIdentity()!.system == systemIdentity, body.nativeGeometryIdentity()!.visit == visit,
      let npc = body.nativeLaunchNPC(), npc.routeProvenance == .inferredLocal
    else { return nil }
    return .init(index: index, actor: body.nativeGeometryIdentity()!, npc: npc)
  }

  private final class NativeLaunchPlan {
    let index: Int
    let npc: NPCState
    let catalogue: String
    let hull: Hull?
    let energy: Double
    let hostile: Bool
    let pose: ShipPose
    let time: Double
    let protection: MissionProtection
    init(index: Int, npc: NPCState, catalogue: String, hull: Hull?, energy: Double,
      hostile: Bool, pose: ShipPose, time: Double, protection: MissionProtection) {
      self.index = index; self.npc = npc; self.catalogue = catalogue; self.hull = hull
      self.energy = energy; self.hostile = hostile; self.pose = pose; self.time = time
      self.protection = protection
    }
  }

  @inline(never)
  private func nativeLaunchBodyPosition(at index: Int) -> Vector3 {
    bodies.withUnsafeBufferPointer { stored in
      stored.baseAddress!.advanced(by: index).pointer(to: \.position)!.pointee
    }
  }

  @inline(never)
  private func nativeLaunchBodyMissiles(at index: Int) -> Int {
    bodies.withUnsafeBufferPointer { stored in
      stored.baseAddress!.advanced(by: index).pointer(to: \.missiles)!.pointee
    }
  }

  @inline(never)
  private mutating func resolveNativeLaunchDisposition(
    _ opening: NativeLaunchOpening, flight: FlightSimulationState
  ) -> NativeLaunchPlan? {
    var npc = opening.npc
    let position = flight.pose.systemPoint(nativeLaunchBodyPosition(at: opening.index))
    guard let player = flight.player, let station = flight.anchors?.station.identity,
      let context = gameplayContext(),
      let disposition = AmbientEncounterPolicy.nativeLaunch(
        actor: opening.actor, seed: gameplaySeed,
        government: currentSystem.government, role: npc.role),
      let source = NativeFleetLaunchSource.resolve(
        role: npc.role, actor: opening.actor, seed: gameplaySeed,
        context: context, position: position),
      let stock = NPCResources.stock(source.performance),
      (try? ShipAccommodationProfile(ship: source.ship)) != nil,
      nativeLaunchBodyMissiles(at: opening.index) <= source.performance.missiles,
      nativeLaunchGeometryIsSafe(
        source: source, actor: opening.actor, position: position, context: context)
    else { return nil }
    npc.resources = stock
    npc.legal = disposition.legalOverride ?? npc.legal
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    npc.intention = disposition.hostile ? .engage(player) : .dock(station)
    return .init(index: opening.index, npc: npc, catalogue: source.ship.id,
      hull: source.ship.nativeHull, energy: stock.energyCapacity, hostile: disposition.hostile,
      pose: flight.pose, time: context.physicalTime, protection: context.protection)
  }

  @inline(never)
  private mutating func retainNativeLaunchDisposition(_ plan: NativeLaunchPlan) {
    // This is the same unpublished candidate body, held in an Array CoW value
    // so the active frame never binds a complete inline SpaceBody or physical.
    var current = bodies
    current[plan.index].physical?.catalogueShipID = plan.catalogue
    current[plan.index].physical?.npc = plan.npc
    if let hull = plan.hull { current[plan.index].hull = hull }
    current[plan.index].energy = plan.energy
    current[plan.index].hostile = plan.hostile
    guard Self.nativeLaunchCandidateCanPersist(current, plan: plan) else {
      bodies.remove(at: plan.index)
      return
    }
    bodies = current
  }

  @inline(never)
  private static func nativeLaunchCandidateCanPersist(
    _ current: borrowing [SpaceBody], plan: NativeLaunchPlan
  ) -> Bool {
    current.withUnsafeBufferPointer { stored in
      NPCPersistenceSnapshot.capture(body: stored.baseAddress!.advanced(by: plan.index).pointee,
        pose: plan.pose, physicalTime: plan.time, protection: plan.protection) != nil
    }
  }

  /// Legacy/native encounter creators are adopted before their first attack.
  @inline(never)
  mutating func ensurePhysicalActors(freshLaunchTrafficID: Int? = nil) {
    adoptNativePhysicalActors()
    if let freshLaunchTrafficID { initializeNativeLaunchDisposition(bodyID: freshLaunchTrafficID) }
    do { try populateNativeStations() } catch {
      notify("ORIGINAL STATION ADMISSION UNAVAILABLE", voiced: false)
    }
  }

  // Release completed adoption buffers before station admission enters its own geometry checks.
  @inline(never)
  private mutating func adoptNativePhysicalActors() {
    let flightSystem = storedFlightSimulation().system
    let currentSystem = nativePhysicalAdoptionSystemIdentity()
    if flightSystem != currentSystem {
      let destination = nativePhysicalAdoptionSystemIdentity()
      commander.flightSimulation.enter(destination, arriving: false)
    }
    let flight = storedFlightSimulation()
    for index in bodies.indices {
      guard nativePhysicalActorNeedsAdoption(at: index) else { continue }
      adoptNativePhysicalActor(at: index, flight: flight)
    }
  }

  // The one body projection used for eligibility ends before identity allocation/construction.
  @inline(never)
  private mutating func nativePhysicalActorNeedsAdoption(at index: Int) -> Bool {
    bodies.withUnsafeBufferPointer { stored in
      Self.nativePhysicalActorIsUnbound(stored.baseAddress!.advanced(by: index).pointee)
    }
  }

  @inline(never)
  private static func nativePhysicalActorIsUnbound(_ body: borrowing SpaceBody) -> Bool {
    guard case .none = body.physical else { return false }
    guard case .none = body.scriptShot else { return false }
    guard case .none = body.nativeStationIdentity else { return false }
    return true
  }

  @inline(never)
  private mutating func adoptNativePhysicalActor(at index: Int, flight: FlightSimulationState) {
    let identity: ActorIdentity?
    if bodies[index].id == 0 && bodies[index].hull == .station {
      identity = flight.anchors?.station.identity
    } else {
      identity = commander.flightSimulation.allocateActor()
    }
    guard let identity else { return }
    let physical = bodies.withUnsafeBufferPointer { stored in
      nativePhysicalActorState(for: stored.baseAddress!.advanced(by: index).pointee, identity: identity)
    }
    bodies[index].physical = physical
  }

  /// The same native adoption policy serves fresh mission admissions without allocating identities.
  func nativePhysicalActorState(
    for body: borrowing SpaceBody, identity: ActorIdentity, spawnIdentity: SpawnIdentity? = nil,
    velocity: Vector3 = .init(0, 0, 0)
  ) -> PhysicalActorState {
    let role = legacyNPCRole(body)
    var npc = role.map {
      NPCState(role: $0, origin: systemIdentity, destination: systemIdentity)
    }
    npc?.routeProvenance = .inferredLocal
    npc?.resources = NPCResources.legacyEnergyOnly(
      maximumEnergy: nativePhysicalActorMaximumEnergy(body))
    if [.constrictor, .thargoid, .thargon].contains(body.hull) {
      npc?.legal = .init(value: 64, bountyTenths: body.nativeNavalCombat?.bounty ?? 0)
      npc?.legalProvenance = .recorded
    }
    if body.hostile, let player = storedFlightSimulation().player {
      npc?.intention = .engage(player)
    }
    return .init(
      identity: identity, population: population(of: body, role: role), npc: npc,
      velocity: velocity, spawnIdentity: spawnIdentity, blocksNavalEncounter: body.hull == .viper)
  }

  @inline(never)
  private func nativePhysicalActorMaximumEnergy(_ body: borrowing SpaceBody) -> Double {
    if let energy = body.scriptNPC?.fit.definition.energy { return energy }
    if body.blackjackRole != nil { return BlackjackTarget.energy }
    return body.nativeNavalCombat?.energy ?? 100
  }

  private func legacyNPCRole(_ body: borrowing SpaceBody) -> NPCRole? {
    if body.missionInstanceID != nil { return .mission }
    guard body.hull.isTargetShip else { return nil }
    if body.hull == .viper { return .police }
    if body.blackjackRole != nil { return .mission }
    if body.navalTarget { return .mission }
    if [.constrictor, .thargoid, .thargon].contains(body.hull) { return .mission }
    return body.hostile ? .pirate : .trader
  }

  private func population(of body: borrowing SpaceBody, role: NPCRole?) -> PopulationClass {
    switch body.hull {
    case .asteroid: return .asteroid
    case .cargo: return .cargo
    case .missile: return .projectile
    case .station: return .mission
    default: break
    }
    switch role {
    case .police: return .police
    case .pirate: return .pirate
    case .mission: return .mission
    default: return .civilian
    }
  }

  func gameplayContext() -> EncounterContext? {
    let flight = storedFlightSimulation()
    guard let playerID = flight.player, let canonical = flight.anchors else { return nil }
    let anchors = Self.gameplayAnchors(bodies, flight: flight, canonical: canonical)
    let actors = Self.gameplayActors(bodies, pose: flight.pose)
    return Self.finishGameplayContext(
      self, flight: flight, playerID: playerID, anchors: anchors, actors: actors)
  }

  // Station and actor projection finish before the later protection/player/mining phases.
  @inline(never)
  private static func gameplayAnchors(
    _ bodies: borrowing [SpaceBody], flight: FlightSimulationState, canonical: SystemAnchors
  ) -> SystemAnchors {
    for index in bodies.indices where bodies[index].id == 0 && bodies[index].hull == .station {
      return projectedGameplayAnchors(bodies[index], flight: flight, canonical: canonical)
    }
    return canonical
  }

  @inline(never)
  static func projectedGameplayAnchors(
    _ station: borrowing SpaceBody, flight: FlightSimulationState, canonical: SystemAnchors
  ) -> SystemAnchors {
    var orientation = Basis3()
    orientation.x = flight.pose.orientation.apply(station.modelVector(.init(1, 0, 0)))
    orientation.y = flight.pose.orientation.apply(station.modelVector(.init(0, 1, 0)))
    orientation.z = flight.pose.orientation.apply(station.modelVector(.init(0, 0, 1)))
    let normal = flight.pose.orientation.apply(station.entranceNormal)
    return .init(
      system: canonical.system,
      station: .init(
        identity: canonical.station.identity,
        position: flight.pose.systemPoint(station.position), orientation: orientation,
        exitPosition: flight.pose.systemPoint(station.entrancePosition) + normal * 400,
        exitDirection: normal),
      arrival: canonical.arrival, planet: canonical.planet, sun: canonical.sun)
  }

  // Borrow each actual body in order; missing physical state retains the original omission rule.
  @inline(never)
  private static func gameplayActors(_ bodies: borrowing [SpaceBody], pose: ShipPose)
    -> [ActorSnapshot]
  {
    var actors: [ActorSnapshot] = []
    for index in bodies.indices {
      if let actor = gameplayActor(bodies[index], pose: pose) { actors.append(actor) }
    }
    return actors
  }

  @inline(never)
  private static func gameplayActor(_ body: borrowing SpaceBody, pose: ShipPose) -> ActorSnapshot? {
    guard let physical = body.physical else { return nil }
    let limits = gameplayActorLimits(body, physical: physical)
    return projectedGameplayActor(body, physical: physical, pose: pose, limits: limits)
  }

  @inline(never)
  private static func gameplayActorLimits(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState
  ) -> (energy: Double, speed: Double) {
    let native: ShipPerformance? = physical.catalogueShipID.flatMap {
      ShipCatalogue.ship($0)?.game
    }
    let maximumEnergy = gameplayActorMaximumEnergy(body, physical: physical, native: native)
    let maximumSpeed = gameplayActorMaximumSpeed(body, native: native)
    return (maximumEnergy, maximumSpeed)
  }

  @inline(never)
  private static func gameplayActorMaximumEnergy(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState, native: ShipPerformance?
  ) -> Double {
    if let identity = body.nativeStationIdentity {
      return NativeStationSource.binding(for: identity)?.maximumEnergy ?? .nan
    }
    if let maximum = body.scriptNPC?.fit.definition.energy { return maximum }
    if let maximum = physical.npc?.resources?.energyCapacity { return maximum }
    if let maximum = native?.energy { return maximum }
    if let maximum = body.nativeNavalCombat?.energy { return maximum }
    return 100
  }

  @inline(never)
  private static func gameplayActorMaximumSpeed(
    _ body: borrowing SpaceBody, native: ShipPerformance?
  ) -> Double {
    if let maximum = body.scriptNPC?.fit.definition.speed { return maximum }
    if let speed = native?.speed { return speed * 18 }
    if body.isAegisPrototype, let speed = body.nativeNavalCombat?.speed { return speed * 18 }
    let speed = ShipCatalogue.nativeShip(body.hull)?.game?.speed ?? 20
    return speed * 18
  }

  @inline(never)
  private static func projectedGameplayActor(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState, pose: ShipPose,
    limits: (energy: Double, speed: Double)
  ) -> ActorSnapshot {
    let maximumEnergy = limits.energy
    let maximumSpeed = limits.speed
    let legal: LegalRecord = physical.npc?.legal ?? LegalRecord()
    let cargo: [CommodityAmount] = physical.npc?.ordinaryCargo ?? []
    var orientation = Basis3()
    orientation.x = pose.orientation.apply(body.orientation.x)
    orientation.y = pose.orientation.apply(body.orientation.y)
    orientation.z = pose.orientation.apply(body.orientation.z)
    return ActorSnapshot(
      identity: physical.identity, hull: body.hull,
      position: pose.systemPoint(body.position), orientation: orientation,
      velocity: physical.velocity, energy: body.energy,
      maximumEnergy: maximumEnergy, maximumSpeedUnitsPerSecond: maximumSpeed,
      legal: legal, npc: physical.npc,
      rock: physical.rock, payload: physical.payload,
      ordinaryCargo: cargo,
      catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
      salvage: physical.salvage)
  }

  @inline(never)
  private static func finishGameplayContext(
    _ game: borrowing Game, flight: FlightSimulationState, playerID: ActorIdentity,
    anchors: SystemAnchors, actors: [ActorSnapshot]
  ) -> EncounterContext {
    let scene = Self.gameplayProtectionAndBudget(game.bodies)
    let player = Self.gameplayPlayer(game, flight: flight, playerID: playerID)
    let miningPresence = Self.gameplayMiningPresence(game)
    let depleted = Self.depletedGameplayRocks(game)
    return .init(
      system: game.storedSystemIdentity(),
      seed: Self.gameplayContextSeed(game),
      government: Self.gameplayCurrentSystem(game).government,
      visit: flight.visit, revision: game.gameplayRevision, physicalTime: flight.physicalTime,
      anchors: anchors, player: player, actors: actors, protection: scene.protection,
      budget: scene.budget, perceptionRadius: 6000, depletedRocks: depleted,
      miningPresence: miningPresence)
  }

  @inline(never)
  private static func gameplayProtectionAndBudget(_ bodies: borrowing [SpaceBody])
    -> (protection: MissionProtection, budget: AdmissionBudget)
  {
    var protection = MissionProtection()
    for index in bodies.indices {
      if !bodies[index].gameplayProtectionReasons.isEmpty,
        let identity = bodies[index].physical?.identity
      {
        protection.protectedActors.insert(identity)
      }
    }
    for index in bodies.indices {
      if bodies[index].physical?.blocksNavalEncounter == true {
        protection.blocksNavalEncounter = true
        break
      }
    }
    var budget = AdmissionBudget(total: bodies.count)
    for index in bodies.indices where bodies[index].id != 0 {
      if let population = bodies[index].physical?.population {
        budget.active[population, default: 0] += 1
      }
      if let stock = bodies[index].physical?.currentNewtKitStock, stock.remaining == 1 {
        budget.total += 1
        budget.active[.cargo, default: 0] += 1
      }
    }
    return (protection, budget)
  }

  @inline(never)
  private static func gameplayPlayer(
    _ game: borrowing Game, flight: FlightSimulationState, playerID: ActorIdentity
  ) -> ActorSnapshot {
    return ActorSnapshot(
      identity: playerID, hull: .cobra, position: flight.pose.position,
      orientation: flight.pose.orientation,
      velocity: Self.currentFlightWorldVelocity(game),
      energy: game.energy,
      maximumEnergy: game.withReadOnlyCommander { Self.gameplayPlayerMaximumEnergy($0) },
      maximumSpeedUnitsPerSecond: game.withReadOnlyCommander {
        Self.gameplayPlayerMaximumSpeed($0)
      },
      legal: .init(
        value: game.withReadOnlyCommander { Self.gameplayPlayerLegal($0) },
        bountyTenths: WantedCareerLedger.playerReward(
          legal: game.withReadOnlyCommander { Self.gameplayPlayerLegal($0) })), npc: nil, rock: nil,
      payload: nil,
      ordinaryCargo: game.withReadOnlyCommander { Self.gameplayPlayerCargo($0) },
      catalogueShipID: game.withReadOnlyCommander { Self.gameplayPlayerShipID($0) }
    )
  }

  @inline(never)
  private static func gameplayPlayerMaximumEnergy(_ commander: borrowing Commander) -> Double {
    commander.performance.energy
  }

  @inline(never)
  private static func gameplayPlayerMaximumSpeed(_ commander: borrowing Commander) -> Double {
    commander.performance.speed * 18
  }

  @inline(never)
  private static func gameplayPlayerLegal(_ commander: borrowing Commander) -> Int {
    min(255, commander.legal)
  }

  @inline(never)
  private static func gameplayPlayerCargo(_ commander: borrowing Commander) -> [CommodityAmount] {
    commander.ordinaryCommodityAmounts
  }

  @inline(never)
  private static func gameplayPlayerShipID(_ commander: borrowing Commander) -> String {
    commander.shipID
  }

  @inline(never)
  private static func gameplaySystemIndex(_ commander: borrowing Commander) -> Int {
    commander.system
  }

  @inline(never)
  private static func gameplayGalaxy(_ commander: borrowing Commander) -> Int {
    commander.galaxy
  }

  @inline(never)
  private static func gameplayCurrentSystem(_ game: borrowing Game) -> StarSystem {
    game.systems[game.withReadOnlyCommander { Self.gameplaySystemIndex($0) }]
  }

  @inline(never)
  private static func gameplayContextSeed(_ game: borrowing Game) -> UInt64 {
    UInt64(Self.gameplayCurrentSystem(game).seed.a) << 32
      | UInt64(Self.gameplayCurrentSystem(game).seed.b) << 16
      | UInt64(Self.gameplayCurrentSystem(game).seed.c)
  }

  @inline(never)
  private static func gameplayMiningLedger(_ commander: borrowing Commander) -> MiningLedger {
    commander.miningLedger
  }

  @inline(never)
  private static func gameplayMiningPresence(_ game: borrowing Game) -> MiningScenePresence {
    let ledger = game.withReadOnlyCommander { Self.gameplayMiningLedger($0) }
    return .init(
      ringPresent: ledger.ringPresence(
        system: Self.gameplayCurrentSystem(game),
        galaxy: game.withReadOnlyCommander { Self.gameplayGalaxy($0) }),
      includingLegacy: ledger.retainsLegacyFields)
  }

  @inline(never)
  private static func gameplayRockIsDepleted(
    _ rock: RockIdentity, commander: borrowing Commander
  ) -> Bool {
    commander.miningLedger.isDepleted(rock)
  }

  @inline(never)
  private static func depletedGameplayRocks(_ game: borrowing Game) -> Set<RockIdentity> {
    var depleted = Set<RockIdentity>()
    for field in game.miningFields {
      for rock in field.rocks {
        let identity = rock.identity
        if game.withReadOnlyCommander({ Self.gameplayRockIsDepleted(identity, commander: $0) }) {
          depleted.insert(identity)
        }
      }
    }
    return depleted
  }
}
