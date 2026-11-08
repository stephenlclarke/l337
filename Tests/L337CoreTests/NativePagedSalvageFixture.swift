import Darwin
import Foundation
import Testing

@testable import L337Core

/// Fixed real-world input derived from the current authored world seed and
/// ordinary director draws. It grants no actor, equipment, stock or custody.
/// Source arithmetic predicts inbound SH029 at decisions 2 and 4; actual
/// fixtures still require the original producer, writer, receipt and issued kit.
/// The calculation's complete input/draw evidence is retained with the handoff.
enum NativeNewtOrdinaryBirthScenario {
  static let galaxy = 2
  static let system = 49
  static let worldKey = "G03-S049"
  static let worldName = "Elaseith"
  static let authoringSeed = "lanterns-between-the-tides-2026"
  static let seedA: UInt16 = 62093
  static let seedB: UInt16 = 27497
  static let seedC: UInt16 = 10730
  static let gameplaySeed: UInt64 = 266689206364650
  static let firstDeadline = 8.406566373599553
  static let secondDeadline = 18.960933973761776
  static let thirdDeadline = 27.19518349088841
  static let fourthDeadline = 36.87149100884258
  static var systemIdentity: SystemIdentity { .init(galaxy: galaxy, system: system) }
}

enum NativePagedSalvageFixture {
  static var firingControls: Controls {
    var controls = Controls()
    controls.fire = true
    return controls
  }

  static let permitted = SalvageWorkConditions(
    toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
    resourcesAvailable: true, ownershipAuthorized: true)

  /// Foreign ordinary history is created through its actual original producer,
  /// collector and settlement APIs. It confers no new native source or property.
  static func fullOrdinaryLedger(
    starting: SalvageLedger = .init(), initialOperation: UInt64 = 0,
    retainedWrecks: Int = 0, retainedPlans: Int = 0, retainedPartial: Int = 0
  ) throws -> SalvageLedger {
    var ledger = starting
    let system = SystemIdentity(galaxy: 7, system: 255)
    var operation = initialOperation
    var cargo = Array(repeating: 0, count: 17)
    func wreck(_ ordinal: Int) -> WreckIdentity {
      .init(system: system, site: UInt32(ordinal + 10000), lineage: 991)
    }
    let section = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: ["computer-core"], sourceFaceIndex: 0)
    for ordinal
      in 0..<(SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory
      + SalvageLedger.maximumPending)
    {
      operation += 1
      let result = ledger.advance(
        wreck: wreck(ordinal), section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1,
        operation: operation, conditions: permitted)
      guard case .released(let lots) = result, lots.count == 1 else {
        throw SaveError.invalidCommander
      }
      if ordinal < SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory {
        let receipt = ledger.collect(
          lot: lots[0].identity, cargo: &cargo, freeTonnes: 100,
          apertureHalfExtents: .init(16, 16, 16), hasScoops: true,
          approachAllowed: true, protection: .init())
        #expect(receipt == .collected(lots[0]))
        if ordinal < SalvageLedger.maximumSettlements {
          let proposal = try #require(
            ledger.prepareSettlement(
              command: UUID(), items: [lots[0].identity], action: .sell))
          let observedSettlement = ledger.commitSettlement(proposal)
          #expect(observedSettlement == .committed(proposal))
        }
      }
    }
    let firstPlan =
      SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory
      + SalvageLedger.maximumPending
    let source = SalvageLootSource(
      roles: [.asteroid], legalValue: 0, economy: 0, technology: 0, ownership: .abandoned)
    for ordinal in firstPlan..<(firstPlan + SalvageLedger.maximumPlans - retainedPlans) {
      let observedInspection = ledger.inspectLoot(
        wreck: wreck(ordinal), section: section, source: source)
      #expect(observedInspection != nil)
    }
    let firstPartial = firstPlan + SalvageLedger.maximumPlans - retainedPlans
    for ordinal in firstPartial..<(firstPartial + SalvageLedger.maximumPartial - retainedPartial) {
      operation += 1
      let observedWorkResult = ledger.advance(
        wreck: wreck(ordinal), section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0.1,
        operation: operation, conditions: permitted)
      #expect(
        observedWorkResult == .progress(seconds: 0.1, required: 1))
    }
    let firstMotion = firstPartial + SalvageLedger.maximumPartial - retainedPartial
    for ordinal in firstMotion..<(SalvageLedger.maximumWrecks - retainedWrecks) {
      let observedWreckUpdate = ledger.updateWreck(
        identity: wreck(ordinal),
        motion: .init(
          pose: .init(position: .init(Double(ordinal), 0, 0)), velocity: .init(0, 0, 0),
          angularVelocity: .init(0, 0, 0), energy: 10))
      #expect(
        observedWreckUpdate)
    }
    let encodedLedger = try JSONEncoder().encode(ledger)
    let decodedLedger = try JSONDecoder().decode(SalvageLedger.self, from: encodedLedger)
    #expect(decodedLedger == ledger)
    #expect(ledger.pendingLots.count == SalvageLedger.maximumPending)
    #expect(ledger.inventory.count == SalvageLedger.maximumInventory)
    let observedWreckUpdate2 = ledger.updateWreck(
      identity: wreck(SalvageLedger.maximumWrecks),
      motion: .init(
        pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 10))
    #expect(
      !observedWreckUpdate2)
    return ledger
  }

  /// Source identity from the existing grant-backed EMP unit boundary. This is
  /// an actually disabled and emptied ordinary hull, never a generated SalvageSite.
  struct EMPWorkSource {
    let identity: WreckIdentity
    let actor: ActorIdentity
    let sequence: UInt64
    let section: WreckSectionIdentity
  }

  private struct EMPOrdinaryHistory: Decodable {
    let motions: [WreckIdentity: SalvageWreckMotion]
    let lastOperation: UInt64?
  }

  @inline(never)
  static func equippedNewtStowedGame() throws -> Game {
    var game = try preparedEMPUnitEquipmentGame()
    game.launch()
    try requireActualLaunchSnapshotPolicy(game)
    let previousDiagnostic = game.nativeEncounterBirthDiagnostic
    let prepared = try finishEquippedNewtStowedGame(&game)
    #expect(prepared.nativeEncounterBirthDiagnostic === previousDiagnostic)
    return prepared
  }

  @inline(never)
  private static func preparedEMPUnitEquipmentGame() throws -> Game {
    var game = Game(executive: false)
    expectStartupResourcePolicy(game)
    try configureEMPUnitGame(&game)
    try game.commander.prepareEquipment(legacy: false)
    try grantEMPUnitEquipment(&game)
    expectStartupResourcePolicy(game)
    return game
  }

  @inline(never)
  private static func configureEMPUnitGame(_ game: inout Game) throws {
    let ownedStartupCheck7 = game.nativeQueryStoredShipID() == "SH025"
    try #require(ownedStartupCheck7)
    let fitting = try #require(OriginalFleetR3Fitting.contract(for: ShipCatalogue.ship(game.nativeQueryStoredShipID())!)?.fitting)
    try #require(fitting.utilityMounts == 3)
    let ownedStartupCheck8 = game.nativeStartupNativePerformance().workTools?.contains(.salvageCutter) == true
    try #require(ownedStartupCheck8)
    // Use the actual original world and its derived seed together. Published
    // Bison habitat excludes this galaxy; no ordinary source is suppressed.
    game.commander.galaxy = NativeNewtOrdinaryBirthScenario.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: NativeNewtOrdinaryBirthScenario.galaxy)
    game.commander.system = NativeNewtOrdinaryBirthScenario.system
    game.selectedSystem = NativeNewtOrdinaryBirthScenario.system
    game.market = MarketItem.at(game.currentSystem)
    let ownedStartupCheck9 = game.commanderGalaxy == NativeNewtOrdinaryBirthScenario.galaxy
      && game.currentSystem.name == NativeNewtOrdinaryBirthScenario.worldName
    try #require(ownedStartupCheck9)
    let ownedStartupCheck10 = game.gameplaySeed == NativeNewtOrdinaryBirthScenario.gameplaySeed
    try #require(ownedStartupCheck10)
    game.energy = game.nativeStartupEnergy()
    game.frontShield = game.nativeStartupFrontShield()
    game.rearShield = game.nativeStartupRearShield()
    game.commander.fuel = game.nativeStartupFuelCapacity()
  }

  @inline(never)
  private static func grantEMPUnitEquipment(_ game: inout Game) throws {
    for (name, slot) in [
      (Equipment.empPirateBlaster, ComponentFittingSlot.utility(.empPirateBlaster)),
      ("Salvage Cutter", .utility(.salvageCutter)), ("Fuel Scoops", .utility(.fuelScoops)),
      ("Targeting: Salvage Module", .targetingSalvage),
      (TargetingTier.military.equipmentName, .targetingCore),
    ] {
      try game.commander.grantEquipment(name, at: slot, provenance: .grant("EMP regression"))
    }
  }

  // Compare the concrete read path with the unchanged public policy on actual
  // fresh and actually fitted states. No extra Game/UUID/actor is constructed.
  @inline(never)
  private static func expectStartupResourcePolicy(_ game: Game) {
    let energy = game.nativeStartupEnergy()
    let front = game.nativeStartupFrontShield()
    let rear = game.nativeStartupRearShield()
    let fuel = game.nativeStartupFuelCapacity()
    let energyMatches = energy == game.commander.performance.energy
    let frontMatches = front == game.commander.shieldCapacity
    let rearMatches = rear == game.commander.rearShieldCapacity
    let fuelMatches = fuel == game.commander.fuelCapacity
    #expect(energyMatches && frontMatches && rearMatches && fuelMatches)
    let opening = game
    let tier = game.nativeStationAutoTargetingTier()
    let docking = game.nativeStationAutoHasDocking()
    let xyzzy = game.nativeStationAutoXYZzyActive()
    let targeting = game.nativeStationAutoTargetFlag()
    let ecm = game.nativeStationAutoHasECM()
    let mounts = game.nativeStationAutoLaserMounts()
    let performance = game.nativeFramePerformance()
    let energyRate = game.nativeFrameEnergyRecharge()
    let frontRate = game.nativeFrameFrontRecharge()
    let rearRate = game.nativeFrameRearRecharge()
    let stationAutoOwnedCheck1 = tier == game.commander.targetingTier && docking == game.commander.hasAutomaticDocking
    #expect(stationAutoOwnedCheck1)
    let stationAutoOwnedCheck2 = xyzzy == game.commander.xyzzyActive && targeting == game.commander.autoTarget
    #expect(stationAutoOwnedCheck2)
    let stationAutoOwnedCheck3 = ecm == (game.commander.fittedEquipment(at: .utility(.ecm)) != nil)
    #expect(stationAutoOwnedCheck3)
    let stationAutoOwnedCheck4 = mounts == game.commander.laserMounts && performance == game.commander.performance
    #expect(stationAutoOwnedCheck4)
    let stationAutoOwnedCheck5 = energyRate == game.commander.energyRechargeMultiplier
    #expect(stationAutoOwnedCheck5)
    let stationAutoOwnedCheck6 = frontRate == game.commander.frontShieldRecharge && rearRate == game.commander.rearShieldRecharge
    #expect(stationAutoOwnedCheck6)
    let stationAutoOwnedCheck7 = game.currentNewtNativeCommanderMatches(opening)
    #expect(stationAutoOwnedCheck7)
  }

  @inline(never)
  private static func requireActualLaunchSnapshotPolicy(_ game: Game) throws {
    let opening = game
    let flight = game.storedFlightSimulation()
    let nativeLaunchOwnedCheck18 = !game.docked && flight.visit == 1
    try #require(nativeLaunchOwnedCheck18)
    let nativeLaunchOwnedCheck19 = game.gameplayContext()
    let context = try #require(nativeLaunchOwnedCheck19)
    for body in game.bodies {
      let original = originalLaunchSnapshot(body: body, pose: flight.pose,
        physicalTime: context.physicalTime, protection: context.protection)
      let projected = NPCPersistenceSnapshot.capture(body: body, pose: flight.pose,
        physicalTime: context.physicalTime, protection: context.protection)
      #expect(projected == original)
    }
    let nativeLaunchOwnedCheck20 = game.currentNewtNativeCommanderMatches(opening) && game.bodies == opening.bodies
    #expect(nativeLaunchOwnedCheck20)
    let nativeLaunchOwnedCheck21 = game.scriptWorldSave == opening.scriptWorldSave
    #expect(nativeLaunchOwnedCheck21)
  }

  @inline(never)
  private static func originalLaunchSnapshot(
    body: SpaceBody, pose: ShipPose, physicalTime: Double, protection: MissionProtection
  ) -> NPCPersistenceSnapshot? {
    guard let physical = body.physical, var npc = physical.npc,
      physical.empSource == nil, physical.empCrewPod == nil,
      !body.navalTarget, body.blackjackRole == nil, body.blackjackIdentity == nil,
      !physical.blocksNavalEncounter, physical.rock == nil, physical.payload == nil,
      physical.ordnance == nil, physical.salvage == nil,
      !protection.protectedActors.contains(physical.identity),
      pose.position.finite, pose.orientation.validRotation
    else { return nil }
    if npc.intention == nil, let suspended = physical.suspendedNPCIntention {
      npc.intention = suspended
    }
    let snapshot = NPCPersistenceSnapshot(
      actor: physical.identity, population: physical.population, hull: body.hull,
      position: pose.systemPoint(body.position),
      orientation: body.orientation.transformed(by: pose.orientation),
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      rotation: body.rotation, rotationRate: body.rotationRate,
      energy: body.energy, missiles: body.missiles, ecmEnabled: body.ecmEnabled,
      hostile: body.hostile, laserCooldown: physical.laserCooldown,
      catalogueShipID: physical.catalogueShipID, npc: npc, physicalTime: physicalTime,
      currentNewtKitStock: physical.currentNewtKitStock)
    return snapshot.valid ? snapshot : nil
  }

  @inline(never)
  private static func finishEquippedNewtStowedGame(_ game: inout Game) throws -> Game {
    try prepareEMPUnitScene(&game)
    return try prepareEquippedNewtAfterUnitScene(&game)
  }

  @inline(never)
  private static func prepareEquippedNewtAfterUnitScene(_ game: inout Game) throws -> Game {
    let anchors = try placeEquippedNewtUnitScene(&game)
    let kitSource = try #require(CurrentNewtKitSource.current)
    let previousDiagnostic = game.nativeEncounterBirthDiagnostic
    game.nativeEncounterBirthDiagnostic = GameplayEncounterBirthDiagnostic()
    defer { game.nativeEncounterBirthDiagnostic = previousDiagnostic }
    try withEMPUnitWriter(&game) { scene, publish, _ in
      let publish = try #require(publish)
      try prepareEquippedNewtThroughWriter(&scene, publish: publish, anchors: anchors, kitSource: kitSource)
    }
    game.selectFlightTool(.empPirateBlaster)
    let nativeLaunchOwnedCheck15 = game.commander.savedEMPState == nil && game.commander.savedEMPCharge == nil
    try #require(nativeLaunchOwnedCheck15)
    let nativeLaunchOwnedCheck16 = game.bodies.first?.physical?.currentNewtKitStock?.phase == .stowed
    try #require(nativeLaunchOwnedCheck16)
    let nativeLaunchOwnedCheck17 = game.commander.valid
    try #require(nativeLaunchOwnedCheck17)
    // Restore before copying the return value; defer only cleans throwing exits.
    game.nativeEncounterBirthDiagnostic = previousDiagnostic
    return game
  }

  @inline(never)
  private static func prepareEquippedNewtThroughWriter(
    _ scene: inout Game, publish: @escaping ScriptPublisher, anchors: SystemAnchors, kitSource: CurrentNewtKitSource
  ) throws {
    let nativeLaunchOwnedCheck4 = scene.currentEMPPlayerModule()
    let module = try #require(nativeLaunchOwnedCheck4)
    let history = scene.nativeStationAutoPurchaseHistory()
    try advanceEquippedNewtBankAndBirth(&scene, publish: publish, anchors: anchors, kitSource: kitSource)
    try verifyEquippedNewtBirthAndAim(&scene, publish: publish, anchors: anchors,
      kitSource: kitSource, module: module, history: history)
  }

  @inline(never)
  private static func advanceEquippedNewtBankAndBirth(
    _ scene: inout Game, publish: @escaping ScriptPublisher, anchors: SystemAnchors, kitSource: CurrentNewtKitSource
  ) throws {
    // Share the existing bank-preparation allowance with actual ordinary birth.
    for _ in 0..<256 {
      let ready = equippedNewtBankIsReady(scene)
      let born = equippedNewtBirthIsPresent(scene, kitSource: kitSource)
      if ready && born { break }
      try empUnitFrame(&scene, publish: publish)
      if !born { try observeFirstEquippedNewtBirth(scene, anchors: anchors, kitSource: kitSource) }
    }
  }

  @inline(never)
  private static func equippedNewtBankIsReady(_ scene: Game) -> Bool {
    scene.currentEMPPlayerModule()?.empBank?.remaining == 8
  }

  @inline(never)
  private static func equippedNewtBirthIsPresent(_ scene: Game, kitSource: CurrentNewtKitSource) -> Bool {
    scene.bodies.contains {
      $0.physical?.catalogueShipID == "SH029"
        && $0.physical?.currentNewtKitStock?.issue.configuration == kitSource.configuration
    }
  }

  @inline(never)
  private static func observeFirstEquippedNewtBirth(
    _ scene: Game, anchors: SystemAnchors, kitSource: CurrentNewtKitSource
  ) throws {
    guard let body = scene.bodies.first(where: {
      $0.physical?.currentNewtKitStock?.issue.configuration == kitSource.configuration
    }) else { return }

    let physical = try #require(body.physical)
    let stock = try #require(physical.currentNewtKitStock)
    let time = scene.storedFlightSimulation().physicalTime
    // The fixed real producer is the inbound trader at the actual arrival
    // anchor. Its T1 admission cannot consume the preceding frame's motion.
    let heading = (anchors.station.position - anchors.arrival).unit
    let pose = scene.modelPose(of: body)
    try #require(stock.issue.issuedAt == time && stock.observedAt == time)
    #expect((pose.position - anchors.arrival).length < 1e-7)
    #expect((pose.orientation.z - heading).length < 1e-7)
    #expect((physical.velocity - heading * 60).length < 1e-7)
    #expect(physical.angularVelocity == .init(0, 0, 0) && body.rotation == 0)
    #expect(body.rotationRate == 0 && physical.laserCooldown == 0)
    #expect(stock.phase == .stowed && stock.actuation == nil && stock.receipt == nil)
    #expect(stock.work.loweredFraction == 0 && stock.work.rodMetres == 0
      && stock.work.rodVelocity == 0 && stock.work.guideWorkJoules == 0
      && stock.work.ejectionWorkJoules == 0)
  }

  @inline(never)
  private static func verifyEquippedNewtBirthAndAim(
    _ scene: inout Game, publish: @escaping ScriptPublisher, anchors: SystemAnchors,
    kitSource: CurrentNewtKitSource, module: OwnedEquipmentItem, history: EquipmentPurchaseHistory?
  ) throws {
    let index = try verifiedEquippedNewtBirthIndex(scene, kitSource: kitSource, module: module, history: history)
    aimExistingEquippedNewt(&scene, index: index)
    try openEMPUnitHeader(&scene, publish: publish)
  }

  @inline(never)
  private static func verifiedEquippedNewtBirthIndex(
    _ scene: Game, kitSource: CurrentNewtKitSource, module: OwnedEquipmentItem,
    history: EquipmentPurchaseHistory?
  ) throws -> Int {
    let indexCandidate = scene.bodies.firstIndex {
      $0.physical?.catalogueShipID == "SH029"
        && $0.physical?.currentNewtKitStock?.issue.configuration == kitSource.configuration
    }
    let index = try #require(indexCandidate, indexCandidate == nil ? equippedNewtBirthFailure(scene) : nil)
    let nativeLaunchOwnedCheck5 = scene.bodies[index].physical
    let physical = try #require(nativeLaunchOwnedCheck5)
    let spawn = try #require(physical.spawnIdentity)
    let stock = try #require(physical.currentNewtKitStock)
    let nativeLaunchOwnedCheck6 = scene.commander.encounterDirector
    let director = try #require(nativeLaunchOwnedCheck6)
    try #require(spawn.producer == .ambient && spawn.member == 0)
    try #require(spawn.system == NativeNewtOrdinaryBirthScenario.systemIdentity && spawn.visit == 1)
    try #require(spawn.sequence == 2 && director.decisionCount == 2 && director.admittedCount > 0)
    try #require(!director.pendingRequests.contains { $0.identity == spawn })
    try #require(stock.issue.birthActor == physical.identity && stock.issue.birthSpawn == spawn)
    let observed = try #require(scene.nativeEncounterBirthDiagnostic?.observations)
    #expect(observed.contains { observation in
      observation.time == stock.issue.issuedAt && observation.decision == spawn.sequence
        && observation.requests.contains {
          $0.identity == spawn && $0.catalogueShipID == "SH029"
            && $0.configuration == kitSource.configuration
        }
        && observation.receipts.contains {
          $0.request == spawn && $0.actor == physical.identity && $0.refusal == nil
        }
    })
    try #require(stock.issue.person == .init(source: physical.identity, ordinal: 0))
    try #require(stock.issue.personProfile == kitSource.personProfile && kitSource.matches(stock.issue))
    let nativeLaunchOwnedCheck7 = kitSource.matches(stock, at: scene.storedFlightSimulation().physicalTime)
    try #require(nativeLaunchOwnedCheck7)
    let nativeLaunchOwnedCheck8 = scene.commander.npcPersistence.logicalIdentity(for: physical.identity)
    let logical = try #require(nativeLaunchOwnedCheck8)
    let nativeLaunchOwnedCheck9 = scene.commander.npcPersistence.snapshot(for: logical)
    let snapshot = try #require(nativeLaunchOwnedCheck9)
    try #require(snapshot.currentNewtKitStock == stock)
    try #require(stock.phase == .stowed && stock.remaining == 1 && stock.actuation == nil && stock.receipt == nil)
    let nativeLaunchOwnedCheck10 = scene.empPulseEligible(scene.bodies[index])
    try #require(nativeLaunchOwnedCheck10)
    let nativeLaunchOwnedCheck11 = scene.currentEMPPlayerModule()
    let ready = try #require(nativeLaunchOwnedCheck11)
    let nativeLaunchOwnedCheck12 = ready.empBank?.remaining == 8 && (scene.commander.savedPlayerElectrical?.remaining ?? 0) > 0
    try #require(nativeLaunchOwnedCheck12)
    #expect(ready.id == module.id && ready.empGrades == module.empGrades)
    let nativeLaunchOwnedCheck13 = scene.nativeStationAutoPurchaseHistory() == history
    #expect(nativeLaunchOwnedCheck13)
    let nativeLaunchOwnedCheck14 = scene.commander.savedEMPState == nil
    try #require(nativeLaunchOwnedCheck14)
    return index
  }

  @inline(never)
  private static func aimExistingEquippedNewt(_ scene: inout Game, index: Int) {
    // Only array order changes for the existing unit aim helper; the actor is already born.
    scene.bodies.swapAt(0, index)
    let body = scene.bodies[0]
    let model = scene.modelPose(of: body)
    let aim = Game.nativePlayerSurfaceAim(from: .init(0, 0, -1000), mesh: scene.gameplayMesh(for: body))
    var observer = model
    observer.position = model.systemPoint(aim) - model.orientation.z * 1000
    moveObserver(&scene, to: observer)
  }

  @inline(never)
  private static func equippedNewtBirthFailure(_ scene: Game) -> Comment {
    let flight = scene.storedFlightSimulation()
    let director = scene.commander.encounterDirector
    let module = scene.currentEMPPlayerModule()
    let context = scene.gameplayContext()
    let pending = director?.pendingRequests.prefix(32).map {
      "spawn=\($0.identity),ship=\($0.catalogueShipID ?? "nil"),kit=\($0.currentNewtKitConfiguration ?? "nil")"
    }.joined(separator: ";") ?? "nil"
    let bodies = scene.bodies.prefix(32).map {
      "id=\($0.id),ship=\($0.physical?.catalogueShipID ?? "nil"),spawn=\(String(describing: $0.physical?.spawnIdentity))"
        + ",stock=\($0.physical?.currentNewtKitStock?.issue.configuration ?? "nil"),energy=\($0.energy)"
    }.joined(separator: ";")
    return Comment(rawValue: "No source-equipped ordinary SH029 birth in the existing bank-preparation allowance."
      + " time=\(flight.physicalTime) visit=\(flight.visit) paused=\(scene.paused) docked=\(scene.docked) screen=\(scene.screen)"
      + " bank=\(String(describing: module?.empBank)) electrical=\(String(describing: scene.commander.savedPlayerElectrical?.remaining))"
      + " sourceQualified=\(String(describing: CurrentNewtKitSource.current?.sourceQualifiedForBirth))"
      + " decision=\(String(describing: director?.decisionCount)) admitted=\(String(describing: director?.admittedCount))"
      + " deadline=\(String(describing: director?.nextDecisionTime)) pending=[\(pending)]"
      + " region=\(String(describing: context.map { EncounterGeography.region(at: $0.player.position, anchors: $0.anchors) }))"
      + " protection=\(String(describing: context?.protection)) budget=\(String(describing: context?.budget))"
      + " actualDecisions=[\(scene.nativeEncounterBirthDiagnostic?.detail() ?? "nil")] bodyCount=\(scene.bodies.count) bodies=[\(bodies)]")
  }

  @inline(never)
  private static func placeEquippedNewtUnitScene(_ game: inout Game) throws -> SystemAnchors {
    let nativeLaunchOwnedCheck1 = game.storedFlightSimulation().visit == 1
    try #require(nativeLaunchOwnedCheck1)
    let nativeLaunchOwnedCheck2 = game.storedFlightSimulation().anchors
    let anchors = try #require(nativeLaunchOwnedCheck2)
    let observer = ShipPose(
      position: (anchors.arrival + anchors.station.position) * 0.5,
      orientation: game.storedFlightSimulation().pose.orientation)
    moveObserver(&game, to: observer)
    let nativeLaunchOwnedCheck3 = game.gameplayContext()
    let context = try #require(nativeLaunchOwnedCheck3)
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    try #require(EncounterGeography.region(at: context.player.position, anchors: context.anchors) == .tradeLane)
    try #require(EncounterGeography.safe(context.anchors.arrival, context: context, civilianEntry: true))
    try #require(source.permitsAmbientTrader(context: context, position: context.anchors.arrival))
    return anchors
  }

  static func empGame(fullOrdinaryPools: Bool = false) throws -> (Game, EMPWorkSource) {
    var game = try equippedNewtStowedGame()
    return try finishEMPGame(&game, fullOrdinaryPools: fullOrdinaryPools)
  }

  @inline(never)
  private static func finishEMPGame(
    _ game: inout Game, fullOrdinaryPools: Bool
  ) throws -> (Game, EMPWorkSource) {
    try #require(game.commander.shipID == "SH025")
    try #require(try releaseDamagedEMPBoundary(&game))
    let disabledCandidate = game.bodies.first { $0.physical?.empSource != nil }
    let disabled = try #require(disabledCandidate)
    let source = try #require(disabled.physical?.empSource)
    try ejectScheduledEMPCrewBoundary(&game, source: source)
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let bodyCandidate = game.bodies.first {
      $0.physical?.empSource == source && $0.physical?.salvage?.wreck == record.wreck
    }
    let body = try #require(bodyCandidate)
    try #require(body.physical?.npc == nil && body.physical?.catalogueShipID == "SH029")
    let metadata = try #require(body.physical?.salvage)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH029"))
    try #require(!profile.sourceRoles.contains(.thargoid) && game.salvageSites.isEmpty)
    // Retain through the real EMP source validator before filling unrelated history.
    // No section inspection, plan or work budget is introduced by this setup.
    let retainedSource = game.retainNativeSalvageWreck(body)
    try #require(retainedSource)
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[record.wreck])
    try #require(retained.source == .emp(actor: source, sequence: record.sequence))
    if fullOrdinaryPools {
      let history = try JSONDecoder().decode(
        EMPOrdinaryHistory.self, from: JSONEncoder().encode(game.commander.salvageLedger))
      try #require(history.motions.count == 1 && history.motions[record.wreck] != nil)
      let seed = game.commander.salvageLedger.nativeInspectionSeed
      game.commander.salvageLedger = try fullOrdinaryLedger(
        starting: game.commander.salvageLedger,
        initialOperation: history.lastOperation ?? 0, retainedWrecks: history.motions.count)
      try #require(game.commander.salvageLedger.nativeInspectionSeed == seed)
    }
    let model = game.modelPose(of: body)
    for section in profile.sections {
      var candidate = game
      let surface = model.systemPoint(section.localPosition)
      let normal = model.orientation.apply(section.normal).unit
      var basis = Basis3()
      basis.z = normal * -1
      let up = abs(basis.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
      basis.x = up.cross(basis.z).unit
      basis.y = basis.z.cross(basis.x).unit
      moveObserver(&candidate, to: .init(position: surface + normal * 200, orientation: basis))
      guard let hit = try candidate.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0,
        includePlayer: false), hit.hit.target == .body(body.id),
        (candidate.commander.flightSimulation.pose.systemPoint(hit.hit.point) - surface).length < 0.001,
        let actualBody = candidate.bodies.first(where: { $0.id == body.id }),
        candidate.workSurface(for: actualBody, metadata: metadata)?.section
          == WreckSectionIdentity(wreck: record.wreck, section: section.index)
      else { continue }
      candidate.selectFlightTool(.salvageCutter)
      try NativeSaveTestFixture.prepareCurrentPolicy(&candidate)
      try #require(candidate.nativeSalvageWork == nil)
      try #require(candidate.commander.alienStorageState?.current.salvage.native.plans.isEmpty == true)
      return (candidate, .init(
        identity: record.wreck, actor: source, sequence: record.sequence,
        section: .init(wreck: record.wreck, section: section.index)))
    }
    throw SaveError.invalidCommander
  }

  /// A real deterministic site is admitted by the production encounter path.
  /// Human compatibility fixtures omit scoops and use the original manifest section.
  /// Only the observer is positioned for a verified visible catalogue face.
  static func game(
    fullOrdinaryPools: Bool = false, humanCargo: Bool = false, requireReserved: Bool = false
  ) throws -> (Game, SalvageSite) {
    for system in 0..<256 {
      var game = Game(executive: false)
      // Keep the genuine current starter and its owned hull identity before fitting.
      try #require(game.commander.shipID == "SH025")
      game.commander.fuel = game.commander.fuelCapacity
      game.energy = game.commander.performance.energy
      game.frontShield = game.commander.shieldCapacity
      game.rearShield = game.commander.rearShieldCapacity
      game.commander.system = system
      try game.commander.prepareEquipment(legacy: false)
      try game.commander.grantEquipment(
        "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("native cutter test"))
      if !humanCargo {
        try game.commander.grantEquipment(
          "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("native cutter test"))
      }
      try game.commander.grantEquipment(
        "Targeting: Basic", at: .targetingCore, provenance: .grant("native cutter test"))
      try game.commander.grantEquipment(
        "Targeting: Salvage Module", at: .targetingSalvage, provenance: .grant("native cutter test")
      )
      game.launch()
      game.speed = 0
      guard
        let site = game.salvageSites.first(where: {
          guard let profile = SalvageCatalogue.profile(catalogueShipID: $0.catalogueShipID)
          else { return false }
          if humanCargo {
            return !profile.sourceRoles.contains(.thargoid)
              && (profile.sourceRoles.contains(.commercialTrader)
                || profile.sourceRoles.contains(.militaryCapital))
              && !game.salvageSites.contains {
                SalvageCatalogue.profile(catalogueShipID: $0.catalogueShipID)?.sourceRoles.contains(
                  .thargoid) == true
              }
          }
          return profile.sourceRoles.contains(.thargoid)
        }), let profile = SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID)
      else { continue }
      if fullOrdinaryPools { game.commander.salvageLedger = try fullOrdinaryLedger() }
      for section in profile.sections where !humanCargo || section.index == 1 {
        if requireReserved {
          let source = SalvageLootSource(
            roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
            technology: game.currentSystem.technology, ownership: .abandoned)
          let plan = SalvageLootProfiles.plan(
            section: .init(wreck: site.identity, section: section.index),
            seed: game.commander.salvageLedger.nativeInspectionSeed, source: source)
          guard
            plan.items.contains(where: {
              if case .technology(let id, _, _, _) = $0.content {
                return AlienModuleDefinition.isAttachmentDefinition(id)
              }
              return false
            })
          else { continue }
        }
        let surface = site.position + site.orientation.apply(section.localPosition)
        let normal = site.orientation.apply(section.normal).unit
        var basis = Basis3()
        basis.z = normal * -1
        let up = abs(basis.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
        basis.x = up.cross(basis.z).unit
        basis.y = basis.z.cross(basis.x).unit
        if humanCargo {
          moveObserver(
            &game,
            to: cargoObserverPose(
              .init(position: site.position, orientation: site.orientation), section: section))
        } else {
          moveObserver(&game, to: .init(position: surface + normal * 200, orientation: basis))
        }
        game.activateNearbySalvageSites()
        guard let body = game.bodies.first(where: { $0.physical?.salvage?.wreck == site.identity }),
          let hit = try game.nearestMissionCollision(
            from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0,
            includePlayer: false),
          hit.hit.target == .body(body.id),
          (game.commander.flightSimulation.pose.systemPoint(hit.hit.point) - surface).length < 0.001
        else { continue }
        try NativeSaveTestFixture.prepareCurrentPolicy(&game)
        return (game, site)
      }
    }
    throw SaveError.invalidCommander
  }

  static func moveObserver(_ game: inout Game, to pose: ShipPose) {
    let old = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      let model = game.modelPose(of: game.bodies[index])
      game.bodies[index].position = pose.shipPoint(model.position)
      game.bodies[index].orientation = model.orientation.relative(to: pose.orientation)
      game.bodies[index].rotation = 0
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        old.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
  }

  /// Unit observer setup for the unchanged Cargo 1 face, along local -Y toward +Y.
  /// The parent and independent fragments keep their actual canonical world motion.
  static func cargoObserverPose(_ model: ShipPose, section: SalvageSectionProfile) -> ShipPose {
    var basis = Basis3()
    basis.x = model.orientation.x
    basis.y = model.orientation.z * -1
    basis.z = model.orientation.y
    return .init(
      position: model.systemPoint(section.localPosition) - basis.z * 200, orientation: basis)
  }

  /// Enter through the same Tab selection path that seals the real autopilot target.
  /// Approach and cutting time remain in each caller's original finite frame loops.
  static func engageSalvageTarget(
    _ game: inout Game, body: SpaceBody, section: WreckSectionIdentity
  ) throws {
    let actor = try #require(body.physical?.identity)
    game.workTargetFilter = .salvage
    let wasHeld = game.flightTrigger.held
    let wasSuspended = game.workFireSuspended
    game.key("tab")
    try #require(game.autoPilot.targetID == body.id && game.autoPilot.targetActor == actor)
    try #require(game.autoTargetBody?.physical?.identity == actor)
    try #require(game.workGuidance?.parent == actor)
    try #require(game.workGuidance?.mode == .hold(.salvage))
    try #require(game.workGuidance?.surface.section == section)
    try #require(game.workFireSuspended == (wasSuspended || wasHeld))
    try #require(!game.flightTrigger.pressPending && game.selectedToolActivity == nil)
  }

  /// Release and press Return at real readiness inside the caller's existing frame budget.
  /// This sends input only; there are no setup ticks or forced controller transitions.
  static func advanceHeldWork(_ runtime: GameRuntime, delta: Double) async -> Game {
    let before = await runtime.snapshot()
    if before.workGuidance?.holding == true && before.workFireSuspended {
      await runtime.setControls(.init())
      await runtime.key("return")
      await runtime.setControls(firingControls)
    }
    return await runtime.advance(delta: delta)
  }

  static func folder() throws -> URL {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    let url = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
