import Foundation
import Testing

@testable import L337Core

private func empNativeFlight() throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
    provenance: .grant("EMP native boundary regression"))
  try fitEliteEMPTestEnergy(&game)
  game.launch()
  try #require(!game.docked && game.commander.valid)
  game.speed = 0
  game.selectFlightTool(.empPirateBlaster)
  return game
}

/// Complete the actual countdown and native arrival; selecting a chart destination never edits the system.
private func empTravel(to destination: Int, game: inout Game) throws {
  let origin = game.commander.system
  try #require(destination != origin)
  game.selectedSystem = destination
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  let outward = (game.commander.flightSimulation.pose.position - station.position).unit
  try #require(outward.finite && outward.length > 0)
  for frame in 0..<200 where game.massLocked {
    let direction = game.commander.flightSimulation.pose.shipVector(outward)
    var controls = Controls()
    controls.throttle = 1
    controls.yaw = max(
      -1,
      min(
        1,
        atan2(direction.x, direction.z)
          / max(0.001, game.commander.performance.yaw * 0.1)))
    controls.pitch = max(
      -1,
      min(
        1,
        atan2(direction.y, hypot(direction.x, direction.z))
          / max(0.001, game.commander.performance.pitch * 0.1)))
    game.tick(delta: 0.1, controls: controls)
    let continuingFlight = game.screen != .gameOver && !game.docked
    var failureDetails = ""
    if !continuingFlight {
      let flight = game.commander.flightSimulation
      let emp = game.commander.savedEMPState?.records.values.first
      failureDetails =
        "EMP travel stopped: origin=\(origin), destination=\(destination), frame=\(frame), "
        + "time=\(flight.physicalTime), pose=\(flight.pose), screen=\(game.screen), "
        + "docked=\(game.docked), energy=\(game.energy), "
        + "shields=\(game.frontShield)/\(game.rearShield), "
        + "temperature=\(game.cabinTemperature), altitude=\(game.altitude), "
        + "message=\(game.message), speed=\(game.speed), outward=\(outward), "
        + "station=\(station.position), stationRange=\((flight.pose.position - station.position).length), "
        + "throttle=\(controls.throttle), pitch=\(controls.pitch), yaw=\(controls.yaw), "
        + "sampledEMPRecord=\(String(describing: emp?.source)), "
        + "empCrew=\(String(describing: emp?.crewAboard)), "
        + "empDeadline=\(String(describing: emp?.crewDeadline)), "
        + "empRecovered=\(String(describing: emp?.isRecovered)), "
        + "retainedPlayerThreatEvidence=\(empRetainedPlayerThreatEvidence(game))"
    }
    try #require(continuingFlight, Comment(rawValue: failureDetails))
  }
  let freeToJump = !game.massLocked
  try #require(freeToJump)
  let fuel = game.commander.fuel
  let debit = game.commander.jumpFuelCost(
    distance: game.currentSystem.distance(to: game.targetSystem))
  try #require(!game.commander.unlimitedFuel && debit > 0 && debit <= fuel)
  game.beginHyperspace()
  let countdown = try #require(game.jumpCountdown)
  try #require(countdown.isFinite && countdown > 0)
  for _ in 0..<(Int(ceil(countdown / 0.1)) + 2) where game.jumpCountdown != nil {
    game.tick(delta: 0.1)
  }
  try #require(game.commander.system == destination && game.jumpCountdown == nil)
  #expect(game.commander.fuel < fuel)
  #expect(game.commander.fuel == fuel - debit)
  #expect(game.commander.flightSimulation.system == game.systemIdentity)
}

private struct EMPTravelThreatLedger: Decodable {
  struct Window: Decodable {
    let owner: ActorIdentity
    let victim: ActorIdentity
    let lastAttack: Double
    let unlawful: Bool
    let authorityAction: Bool
  }
  let attacks: [Window]
}

/// Failure-only retained windows are threat evidence, not a per-hit damage or fatal-hit history.
private func empRetainedPlayerThreatEvidence(_ game: borrowing Game) -> String {
  guard let player = game.commander.flightSimulation.player else {
    return "unavailable: no player identity"
  }
  do {
    let bytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let ledger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: bytes)
    let windows = ledger.attacks.filter { $0.victim == player }.sorted {
      $0.lastAttack == $1.lastAttack
        ? $0.owner.entity < $1.owner.entity : $0.lastAttack > $1.lastAttack
    }.prefix(4)
    var evidence: [String] = []
    for window in windows {
      let body = game.bodies.first { $0.physical?.identity == window.owner }
      evidence.append(
        "owner=\(window.owner), lastAttack=\(window.lastAttack), unlawful=\(window.unlawful), "
          + "authorityAction=\(window.authorityAction), "
          + "currentRole=\(String(describing: body?.physical?.npc?.role)), "
          + "currentSpawnProducer=\(String(describing: body?.physical?.spawnIdentity?.producer)), "
          + "currentPosition=\(String(describing: body?.position))")
    }
    return "[" + evidence.joined(separator: "; ") + "]"
  } catch {
    return "unavailable: \(error)"
  }
}

private func empOtherSystem(_ game: Game) throws -> Int {
  let reachable = game.knownSystems.filter {
    let distance = game.currentSystem.distance(to: $0)
    return $0.id != game.commander.system && $0.id != Plugh.systemID
      && distance > 0 && distance <= game.commander.maximumJumpDistance
      && game.commander.jumpFuelCost(distance: distance) <= game.commander.fuel
  }.sorted {
    let left = game.currentSystem.distance(to: $0)
    let right = game.currentSystem.distance(to: $1)
    return left == right ? $0.id < $1.id : left < right
  }
  return try #require(reachable.first?.id)
}

private func empRoundTrip(
  _ game: inout Game, directory: URL
) async throws {
  let origin = game.commander.system
  let destination = try empOtherSystem(game)
  try empTravel(to: destination, game: &game)
  game.dock()
  try #require(game.docked && game.commander.system == destination)
  let file = directory.appendingPathComponent("between-systems.json")
  let returnSystem = try #require(game.systems.first { $0.id == origin })
  let returnDistance = game.currentSystem.distance(to: returnSystem)
  let returnDebit = game.commander.jumpFuelCost(distance: returnDistance)
  try #require(returnDistance <= game.commander.jumpCap && returnDebit > 0)
  let needsFuel = game.commander.fuel < returnDebit
  if needsFuel {
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
  }
  let writer = GameRuntime(game: game)
  try await writer.save(to: file)
  if needsFuel {
    let beforePurchase = await writer.snapshot()
    let fuelItem = Equipment.all[beforePurchase.selection]
    let price = beforePurchase.shopPrice(fuelItem)
    try #require(fuelItem.name == "Fuel" && price > 0)
    try #require(
      !beforePurchase.commander.unlimitedCash
        && beforePurchase.commander.availableCredits >= price)
    let context = try #require(beforePurchase.equipmentPurchaseContext)
    let result = await writer.equipmentTransaction(.purchase(context))
    try #require(result.applied)
    let refuelled = await writer.snapshot()
    #expect(refuelled.commander.fuel == refuelled.commander.fuelCapacity)
    #expect(refuelled.commander.credits == beforePurchase.commander.credits - price)
    try #require(refuelled.commander.fuel >= returnDebit)
  }
  let published = await writer.snapshot()
  let reader = GameRuntime()
  try await reader.load(from: file, persistMigrations: false)
  game = await reader.snapshot()
  #expect(game.commander.fuel == published.commander.fuel)
  #expect(game.commander.credits == published.commander.credits)
  try #require(game.docked && game.commander.system == destination)
  try #require(game.commander.fuel >= returnDebit)
  game.launch()
  try #require(!game.docked)
  try empTravel(to: origin, game: &game)
  game.dock()
  try #require(game.docked && game.commander.system == origin)
  game.launch()
  try #require(!game.docked && game.commander.system == origin)
  for _ in 0..<5 { game.tick(delta: 0.1) }
}

struct EMPTravelAndSecurityTests {
  @Test func actualHyperspaceDockReloadAndReturnRetainOneNativeHullAndItsOriginalPeople()
    async throws
  {
    var game = try empNativeFlight()
    let scenarioStart = game.commander.flightSimulation.physicalTime
    try withEMPUnitWriter(&game) { scene, publish, file in
      try earnEMPUnitBank(&scene, publish: publish, file: file)
      try #require(scene.fireCooldown <= 0)
    }
    let nativeIndex = try #require(game.bodies.firstIndex {
      $0.id == 1 && $0.physical?.npc?.role == .trader && $0.physical?.catalogueShipID == "SH025"
    })
    let fresh = game.bodies[nativeIndex]
    let catalogueID = try #require(fresh.physical?.catalogueShipID)
    let currentSource = try #require(OriginalFleetRuntimeHullSource.source(for: catalogueID))
    let catalogue = currentSource.ship
    let native = currentSource.performance
    try #require(native.valid && (catalogue.nativeHull == nil || catalogue.nativeHull == fresh.hull))
    var worn = try #require(fresh.physical?.npc?.resources)
    try #require(worn == NPCResources.stock(native) && worn.profile == .nativeHull)
    try #require(worn.electrical == nil)
    // Controlled existing nonfatal condition, with current source terms and identity retained.
    worn.frontShield = 0
    worn.rearShield = 0
    let beforeCommander = game.commander
    let beforeBodies = game.bodies
    let beforeEnergy = game.energy
    let beforeShields = (game.frontShield, game.rearShield)
    let beforeBodyCursor = game.nextBodyID
    let beforeRandom = game.scriptSimulationSave.randomState
    let beforeTime = game.time
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(
      ElectricalReserve(capacity: worn.energyCapacity, recharge: native.recharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(
      drained && reserve.remaining == 1 && reserve.disabledAt == nil && reserve.physicalTime == now)
    worn.electrical = reserve
    try #require(worn.valid)
    var expectedBody = fresh
    expectedBody.physical?.npc?.resources = worn
    game.bodies[nativeIndex].physical?.npc?.resources = worn
    var expectedBodies = beforeBodies
    expectedBodies[nativeIndex] = expectedBody
    try #require(game.bodies == expectedBodies && game.commander == beforeCommander)
    try #require(
      game.energy == beforeEnergy && game.frontShield == beforeShields.0
        && game.rearShield == beforeShields.1)
    try #require(game.nextBodyID == beforeBodyCursor && game.time == beforeTime)
    try #require(game.scriptSimulationSave.randomState == beforeRandom)
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10)
    // The real first emission, including empty-bank earning, must keep this original wound below80.
    try #require(1 + (native.recharge + native.shieldRecharge) * (pulse.warmup + 0.5) < pulse.power)
    let original = game.bodies[nativeIndex]
    try #require(original.physical?.catalogueShipID == catalogueID)
    try #require(original.physical?.empSource == nil && game.commander.savedEMPState == nil)
    try #require(!game.isEMPDisabled(original))
    let actor = try #require(original.physical?.identity)
    let emissionsBefore = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
    let nativeRun = try await disableNativeEMPActor(actor, game: &game)
    try #require(nativeRun.pulses.count == 1)
    let firstRelease = try #require(nativeRun.pulses.first?.charge.endedAt)
    try #require(firstRelease - now < 39.5)
    try #require(1 + (native.recharge + native.shieldRecharge) * (firstRelease - now) < pulse.power)
    try #require(game.commander.flightSimulation.physicalTime - scenarioStart <= 800 * 0.1 + 1e-8)
    try #require(
      game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == emissionsBefore
        + 1)
    let released = try #require(game.commander.savedEMPCharge)
    let releasedAt = try #require(released.endedAt)
    try #require(
      released.phase == .released && abs(releasedAt - released.startedAt - pulse.warmup) < 1e-8)
    let source = try #require(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let disabled = try #require(game.commander.savedEMPState?.records[source])
    try #require(disabled.hull.body.physical?.catalogueShipID == catalogueID)
    let expectedRecoveryDeadline = disabled.disableIncident.physicalTime + 30
    try #require(disabled.crewDeadline == expectedRecoveryDeadline)
    for _ in 0..<30 { game.tick(delta: 0.1) }
    let empPersistenceResult = game.persistEMPState()
    try #require(empPersistenceResult)
    let before = try #require(game.commander.savedEMPState?.records[source])
    try #require(before.originalBodyID == fresh.id && before.originalSpawn == fresh.physical?.spawnIdentity)
    expectOriginalEMPCrewConserved(before)
    #expect(before.crewCaptures.isEmpty && before.lostCrewCount == 0)
    let people = Set(before.pods.compactMap { $0.body.physical?.empCrewPod })
    let legal = game.commander.legal
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try await empRoundTrip(&game, directory: directory)
    let after = try #require(game.commander.savedEMPState?.records[source])
    #expect(after.source == before.source && after.wreck == before.wreck)
    #expect(after.custody == before.custody && after.disableIncident == before.disableIncident)
    #expect(after.cargo == before.cargo && after.legal == before.legal)
    #expect(game.commander.legal >= legal)
    #expect(after.crewTotal == before.crewTotal)
    expectOriginalEMPCrewConserved(after)
    let survivingPeople = Set(after.pods.compactMap { $0.body.physical?.empCrewPod })
    #expect(people.isSubset(of: survivingPeople))
    let hulls = nativeEMPHulls(game, source: source)
    try #require(hulls.count == 1)
    #expect(hulls[0].physical?.identity != before.hull.binding)
    #expect(hulls[0].hull == original.hull && hulls[0].energy >= before.hull.body.energy)
    #expect(hulls[0].physical?.catalogueShipID == before.hull.body.physical?.catalogueShipID)
    try #require(after.crewDeadline == expectedRecoveryDeadline)
    if after.crewAboard > 0 {
      let deadlineReached = game.commander.flightSimulation.physicalTime >= expectedRecoveryDeadline
      #expect(after.isRecovered == deadlineReached)
      #expect(game.isEMPDisabled(hulls[0]) == !deadlineReached)
      #expect(hulls[0].physical?.npc?.role == original.physical?.npc?.role)
      let electrical = try #require(hulls[0].physical?.npc?.resources?.electrical)
      if deadlineReached {
        #expect(hulls[0].physical?.empSource == nil)
        #expect(electrical.remaining > 0 && electrical.disabledAt == nil)
      } else {
        #expect(hulls[0].physical?.empSource == source)
        #expect(electrical.remaining == 0 && electrical.disabledAt != nil)
      }
    } else {
      #expect(!after.isRecovered && game.isEMPDisabled(hulls[0]))
      #expect(hulls[0].physical?.npc == nil)
      #expect(hulls[0].physical?.velocity == before.hull.body.physical?.velocity)
      #expect(hulls[0].physical?.angularVelocity == before.hull.body.physical?.angularVelocity)
    }
    #expect(
      !game.bodies.contains {
        $0.id == before.originalBodyID && $0.hull == original.hull
          && $0.physical?.spawnIdentity == before.originalSpawn && $0.physical?.empSource == nil
      })
    let admittedPeople = game.bodies.compactMap { $0.physical?.empCrewPod }.filter {
      $0.source == source
    }
    #expect(Set(admittedPeople).count == admittedPeople.count)
    #expect(Set(admittedPeople).isSubset(of: survivingPeople))
    let returned = directory.appendingPathComponent("returned.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: returned)
    try await runtime.load(from: returned, persistMigrations: false)
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    let reloaded = await runtime.snapshot()
    #expect(nativeEMPHulls(reloaded, source: source).count == 1)
    let retained = try #require(reloaded.commander.savedEMPState?.records[source])
    expectOriginalEMPCrewConserved(retained)
    #expect(Set(retained.pods.compactMap { $0.body.physical?.empCrewPod }) == survivingPeople)
    #expect(retained.disableEpisodes == after.disableEpisodes)
    #expect(reloaded.commander.savedEMPState?.records[source]?.cargo == before.cargo)
  }

  @Test("Current stock retains its actual reserve after two earned real pulses")
  func fullStockCurrentSourceRemainsPoweredAfterTwoEarnedRealPulses() async throws {
    var game = try empNativeFlight()
    let original = try #require(game.bodies.first {
      $0.id == 1 && $0.physical?.npc?.role == .trader && $0.physical?.catalogueShipID == "SH025"
    })
    let actor = try #require(original.physical?.identity)
    let npc = try #require(original.physical?.npc)
    let resources = try #require(npc.resources)
    let player = try #require(game.commander.flightSimulation.player)
    let catalogueID = try #require(original.physical?.catalogueShipID)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: catalogueID))
    let crew = try ShipAccommodationProfile(ship: source.ship).operatingCrew
    try #require(resources == NPCResources.stock(source.performance) && resources.profile == .nativeHull)
    try #require(original.energy == source.performance.energy && resources.electrical == nil)
    try #require(original.physical?.empSource == nil && game.commander.savedEMPState == nil)
    let hardware = try #require(game.commander.equipmentInventory)
    let history = try #require(game.commander.equipmentPurchaseHistory)
    let weapon = try #require(game.currentEMPPlayerModule())
    let credits = game.commander.credits
    let cargo = game.commander.cargo
    let legal = game.commander.legal
    let kills = game.commander.kills
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10 && resources.energyCapacity > pulse.power)
    let start = game.commander.flightSimulation.physicalTime
    let emissions = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
    let run = try await disableNativeEMPActor(actor, game: &game, stopAfterEmissions: 2) { scene in
      try Self.establishNativeCobraRetaliation(actor, player: player,
        emissionsBefore: emissions, legalBefore: legal, game: &scene)
    }
    try verifyFullStockCobraAfterPulses(&game, original: original, actor: actor, npc: npc,
      player: player, catalogueID: catalogueID, crew: crew, hardware: hardware, history: history,
      weapon: weapon, credits: credits, cargo: cargo, legal: legal, kills: kills,
      pulse: pulse, startedAt: start, emissionsBefore: emissions, run: run)
  }

  // Establish a real pre-disable attack after the first unlawful EMP pulse, preserving its law.
  @inline(never)
  private static func establishNativeCobraRetaliation(
    _ actor: ActorIdentity, player: ActorIdentity, emissionsBefore: Int, legalBefore: Int,
    game: inout Game
  ) throws {
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(game.commander.flightSimulation.player == player)
    try #require(body.energy > 0 && !game.isEMPDisabled(body) && body.hostile)
    try #require(body.position.length > 0 && body.position.length < 1500)
    try #require(game.commander.legal > legalBefore)
    try #require(
      game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == emissionsBefore
        + 1)
    try #require(body.physical?.npc?.intention == .engage(player))
    let remaining = try #require(body.physical?.npc?.resources?.electrical?.remaining)
    try #require(remaining > 0)
    let emission = game.commander.flightSimulation.nextEmission
    let shields = game.frontShield + game.rearShield
    let energy = game.energy
    let legal = game.commander.legal
    // Same native beam and damage as one 0.1-second ordinary Cobra enemyAction step.
    game.emitLegacyNPCBeam(bodyID: body.id, damage: 0.1 * 6 * 2, energyMultiplier: 2)
    try #require(game.commander.flightSimulation.nextEmission == emission + 1)
    try #require(game.frontShield + game.rearShield < shields || game.energy < energy)
    try #require(game.commander.legal == legal)
    let bytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let ledger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: bytes)
    let windows = ledger.attacks.filter { $0.owner == actor }
    try #require(windows.count == 1)
    let window = try #require(windows.first)
    try #require(window.victim == player)
    try #require(window.lastAttack == game.commander.flightSimulation.physicalTime)
  }

  @inline(never)
  private func verifyFullStockCobraAfterPulses(
    _ game: inout Game, original: SpaceBody, actor: ActorIdentity, npc: NPCState,
    player: ActorIdentity, catalogueID: String, crew: Int,
    hardware: OwnedEquipmentInventory, history: EquipmentPurchaseHistory,
    weapon: OwnedEquipmentItem, credits: Int, cargo: [Int], legal: Int, kills: Int,
    pulse: EMPPulseProfile, startedAt: Double, emissionsBefore: Int, run: EMPNativePulseRun
  ) throws {
    try #require((0...800).contains(run.remainingFrames) && run.pulses.count == 2)
    let first = run.pulses[0]
    let last = run.pulses[1]
    let firstTime = try #require(first.charge.endedAt)
    let lastTime = try #require(last.charge.endedAt)
    try #require(lastTime - firstTime > 30)
    try #require(game.commander.flightSimulation.physicalTime - startedAt <= 800 * 0.1 + 1e-8)
    #expect(game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == emissionsBefore + 2)
    #expect(first.primary.electrical.remaining == original.physical?.npc?.resources?.energyCapacity)
    #expect(first.primary.contactPower == pulse.power && last.primary.contactPower == pulse.power)
    try #require(last.primary.electrical.remaining > pulse.power)
    let actual = try #require(game.bodies.first { $0.physical?.identity == actor })
    try expectEMPPrimaryLaw(last, body: actual)
    let reserve = try #require(actual.physical?.npc?.resources?.electrical)
    #expect(reserve.remaining > 0 && reserve.disabledAt == nil && !game.isEMPDisabled(actual))
    #expect(actual.physical?.empSource == nil && actual.physical?.salvage == nil)
    #expect(game.commander.savedEMPState == nil && crew > 0)
    #expect(!game.bodies.contains { $0.physical?.empCrewPod?.source == actor })
    #expect(actual.hull == original.hull && actual.energy == last.primary.hullEnergy)
    #expect(actual.physical?.catalogueShipID == catalogueID)
    #expect(actual.physical?.npc?.ordinaryCargo == npc.ordinaryCargo && actual.physical?.npc?.legal == npc.legal)
    #expect(actual.physical?.npc?.firstAggressor == player && actual.hostile)
    try expectEMPInventoryProperty(hardware, #require(game.commander.equipmentInventory))
    try expectEMPModuleProperty(weapon, #require(game.currentEMPPlayerModule()))
    #expect(game.commander.equipmentPurchaseHistory == history)
    #expect(game.commander.credits == credits && game.commander.cargo == cargo && game.commander.kills == kills)
    #expect(game.commander.legal > legal && !game.docked && game.screen != .gameOver)
    let ledger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: JSONEncoder().encode(game.commander.crimeLedger))
    let attacks = ledger.attacks.filter { $0.owner == actor }
    try #require(attacks.count == 1)
    #expect(attacks.allSatisfy { $0.victim == player && $0.lastAttack.isFinite && $0.lastAttack <= lastTime })
  }

  @Test func aHealthyAssignedOfficerTakesOneRealShieldFirstPulseWithoutInventedZeroOrCrew() async throws {
    var game = try empNativeFlight()
    game.advanceGameplayEncounters(delta: 0.1); game.advanceGameplayEncounters(delta: 0.1)
    let officer = try #require(game.bodies.first { $0.physical?.spawnIdentity?.producer == .security && $0.physical?.npc?.role == .police })
    let actor = try #require(officer.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let original = try #require(officer.physical?.npc?.resources)
    let deployment = try #require(StationPoliceSource.current())
    try #require(officer.physical?.catalogueShipID == deployment.source.ship.id
      && officer.hull == deployment.source.ship.nativeHull)
    try #require(original.energyCapacity == deployment.stock.energyCapacity
      && officer.energy == deployment.source.performance.energy)
    try #require(original.frontShield == deployment.stock.frontShield
      && original.rearShield == deployment.stock.rearShield && original.electrical == nil)
    try #require(original == deployment.stock)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let legal = game.commander.legal
    let cash = game.commander.credits
    let kills = game.commander.kills
    let hardware = try #require(game.commander.equipmentInventory)
    let history = game.commander.equipmentPurchaseHistory
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10)
    let run = try await disableNativeEMPActor(actor, game: &game, stopAfterFirstEmission: true)
    try #require(run.pulses.count == 1)
    let result = run.pulses[0]
    #expect(result.charge.player == player && result.charge.target == actor)
    let ended = try #require(result.charge.endedAt)
    #expect(abs(ended - result.charge.startedAt - pulse.warmup) < 1e-8)
    #expect(game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == 1)
    let actual = try #require(game.bodies.first { $0.physical?.identity == actor })
    try expectEMPPrimaryLaw(result, body: actual)
    let resources = try #require(actual.physical?.npc?.resources)
    #expect(resources.electrical?.remaining == original.energyCapacity
      && resources.electrical?.disabledAt == nil)
    #expect(actual.energy == result.primary.hullEnergy && actual.physical?.npc?.role == .police)
    #expect(actual.physical?.npc?.firstAggressor == player)
    #expect(actual.physical?.empSource == nil && actual.physical?.salvage == nil)
    #expect(game.commander.savedEMPState == nil && !game.isEMPDisabled(actual))
    #expect(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    #expect(game.commander.legal > legal && game.commander.credits == cash && game.commander.kills == kills)
    try expectEMPInventoryProperty(hardware, #require(game.commander.equipmentInventory))
    #expect(game.commander.equipmentPurchaseHistory == history)
    #expect(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
    #expect(game.currentEMPPlayerModule()?.empBank?.lastDischarge == result.charge)
    try #require(game.frontShield > 0 && game.rearShield > 0 && !game.playerEMPDisabled)
    #expect(game.laserHeat == pulse.heatCost && game.fireCooldown == pulse.cooldown)
    #expect(!game.docked && game.screen != .gameOver && game.commander.valid)
  }

  @Test(arguments: [false, true])
  func actualAssignedSecurityShipRetainsSourceAndLawThroughEjectionOrDeathAndRoundTrip(
    lethal: Bool
  ) async throws {
    let paid = try await paidEMPNativeFixture()
    defer { paid.clean() }
    var game = await paid.runtime.snapshot()
    // Calm security creates its own patrol request at the real station exit; the runtime
    // admits and acknowledges it, then the next security update assigns the actual actor.
    game.advanceGameplayEncounters(delta: 0.1)
    game.advanceGameplayEncounters(delta: 0.1)
    let officer = try #require(
      game.bodies.first {
        $0.physical?.spawnIdentity?.producer == .security && $0.physical?.npc?.role == .police
      })
    let actor = try #require(officer.physical?.identity)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let expectedCatalogue = try #require(officer.physical?.catalogueShipID)
    try #require(expectedCatalogue == StationPoliceSource.catalogueID && officer.hull == .viper)
    let nativeDefinition = try #require(ShipCatalogue.ship(expectedCatalogue)?.game)
    try #require(nativeDefinition.valid
      && ShipCatalogue.ship(expectedCatalogue)?.nativeHull == officer.hull)
    let assignment = try #require(
      game.commander.stationSecurity.assignments.first {
        $0.actor == actor
      })
    // This custody scenario retains a genuinely admitted officer with existing, nonfatal power damage.
    let officerIndex = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    var worn = try #require(game.bodies[officerIndex].physical?.npc?.resources)
    let frontOverflow = worn.absorb(worn.frontShield, front: true)
    let rearOverflow = worn.absorb(worn.rearShield, front: false)
    try #require(frontOverflow == 0 && rearOverflow == 0)
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(
      ElectricalReserve(capacity: worn.energyCapacity, recharge: worn.electricalRecharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(drained && reserve.remaining == 1 && reserve.disabledAt == nil)
    worn.electrical = reserve
    game.bodies[officerIndex].physical?.npc?.resources = worn
    try #require(game.bodies[officerIndex].energy == officer.energy
      && officer.energy == nativeDefinition.energy)
    try #require(
      game.bodies[officerIndex].physical?.empSource == nil && game.commander.savedEMPState == nil)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let legal = game.commander.legal
    try await disableNativeEMPActor(actor, game: &game)
    let source = try #require(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let proof = try #require(game.commander.savedEMPState?.records[source])
    let expectedRecoveryDeadline = proof.disableIncident.physicalTime + 30
    try #require(proof.crewDeadline == expectedRecoveryDeadline)
    try #require(proof.hull.body.physical?.catalogueShipID == expectedCatalogue)
    #expect(proof.custody.kind == .police && proof.custody.assignment?.actor == assignment.actor)
    #expect(proof.custody.assignment?.actor == actor && proof.custody.valid)
    #expect(proof.custody.traffic != nil)
    #expect(proof.originalSpawn?.producer == .security)
    #expect(proof.disableIncident.victim == actor && proof.disableIncident.victimRole == .police)
    #expect(game.commander.legal > legal)
    if lethal {
      let body = try #require(game.bodies.first { $0.physical?.empSource == source })
      let player = try #require(game.commander.flightSimulation.player)
      let originResult = game.makeAttackOrigin(owner: player)
      let origin = try #require(originResult)
      _ = game.applyCombatHit(
        .init(target: .body(body.id), distance: body.position.length, point: body.position),
        origin: origin, kind: .laser, damage: 10000)
      game.resolveDestroyed()
      let dead = try #require(game.commander.savedEMPState?.records[source])
      #expect(dead.terminal && dead.lostCrewCount == dead.crewTotal && dead.pods.isEmpty)
      #expect(dead.hull.body.physical?.deathOrigin == origin)
    } else {
      for _ in 0..<40 { game.tick(delta: 0.1) }
      let retained = try #require(game.commander.savedEMPState?.records[source])
      expectOriginalEMPCrewConserved(retained)
      #expect(!retained.isRecovered && retained.lostCrewCount == 0 && retained.crewCaptures.isEmpty)
    }
    let before = try #require(game.commander.savedEMPState?.records[source])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try await empRoundTrip(&game, directory: directory)
    let after = try #require(game.commander.savedEMPState?.records[source])
    #expect(after.custody == before.custody && after.disableIncident == before.disableIncident)
    #expect(after.cargo == before.cargo && after.legal == before.legal)
    #expect(after.terminal == lethal && after.lostCrewCount == before.lostCrewCount)
    expectOriginalEMPCrewConserved(after)
    let beforePeople = Set(before.pods.compactMap { $0.body.physical?.empCrewPod })
    let afterPeople = Set(after.pods.compactMap { $0.body.physical?.empCrewPod })
    #expect(beforePeople.isSubset(of: afterPeople))
    #expect(nativeEMPHulls(game, source: source).count == (lethal ? 0 : 1))
    if !lethal {
      let current = try #require(nativeEMPHulls(game, source: source).first)
      #expect(current.physical?.catalogueShipID == expectedCatalogue)
      #expect(current.hull == officer.hull && current.physical?.identity == after.hull.binding)
      try #require(after.crewDeadline == expectedRecoveryDeadline)
      if after.crewAboard > 0 {
        let deadlineReached =
          game.commander.flightSimulation.physicalTime >= expectedRecoveryDeadline
        #expect(after.isRecovered == deadlineReached)
        #expect(game.isEMPDisabled(current) == !deadlineReached)
        #expect(current.physical?.npc?.role == officer.physical?.npc?.role)
        let electrical = try #require(current.physical?.npc?.resources?.electrical)
        if deadlineReached {
          #expect(current.physical?.empSource == nil)
          #expect(electrical.remaining > 0 && electrical.disabledAt == nil)
        } else {
          #expect(current.physical?.empSource == source)
          #expect(electrical.remaining == 0 && electrical.disabledAt != nil)
        }
      } else {
        #expect(!after.isRecovered && game.isEMPDisabled(current))
        #expect(current.physical?.empSource == source && current.physical?.npc == nil)
      }
    }
    let livePods = game.bodies.compactMap { $0.physical?.empCrewPod }
    let liveSourcePeople = Set(livePods.filter { $0.source == source })
    #expect(liveSourcePeople.isSubset(of: afterPeople))
    #expect(!game.bodies.contains { $0.physical?.spawnIdentity == before.originalSpawn })
    for _ in 0..<20 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == after.pods.count)
    #expect(game.commander.savedEMPState?.records[source]?.lostCrewCount == before.lostCrewCount)
  }
}
